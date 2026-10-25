package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_appearance")
local A = require("adapters/orbitui_appearance")
local data, fail, refreshes, shown, top = {}, false, 0
local store = {
    readSetting = function(_, key) return data[key] end,
    saveSetting = function(_, key, value) data[key] = value end,
    delSetting = function(_, key) data[key] = nil end,
    flush = function() if fail then fail = false; return false end end,
}
package.loaded["core/orbitui_context"] = { refresh = function() refreshes = refreshes + 1 end }
package.loaded["ui/uimanager"] = { show = function(_, widget) shown = widget end,
    getTopmostVisibleWidget = function() return top end }
package.loaded["ui/widget/confirmbox"] = { new = function(_, opts) return opts end }
local function reset(fresh)
    data, fail = { unrelated = { private = "kept" } }, false
    A.prepare(store, fresh)
end

H.test("new users default to shelf settings while existing OrbitUI keeps the classic policy", function()
    reset(true); H.eq(A.current(), "native"); H.eq(A.policy().bundles, nil)
    A.prepare(store, false); H.eq(A.current(), "native")
    reset(false); H.eq(A.current(), "classic"); H.eq(A.policy().face_out, "all")
    H.eq(data.unrelated.private, "kept")
end)
H.test("unknown schemas and failed first saves are not silently accepted", function()
    data = { appearance = { version = 99, preset = "classic" } }
    H.eq(pcall(A.prepare, store, true), false); H.eq(data.appearance.version, 99)
    data, fail = {}, true
    H.eq(pcall(A.prepare, store, true), false); H.eq(data.appearance, nil)
    A.prepare(store, true); H.eq(A.current(), "native")
    H.eq(pcall(Model.value, "invalid"), false)
end)

local prefs, tab, profile_prefs = { spine_face_out = "reading" }, {}, {}
local Profiles = {
    shelfSettings = function(_, id) return profile_prefs[id] or {} end,
    chip = function(profile, id) return profile.chips and profile.chips[id] end,
}
package.loaded["lib/bookshelf_profiles"] = Profiles
package.loaded["lib/bookshelf_tab_model"] = { getById = function() return tab end }
local f = assert(io.open("components/bookshelf/lib/bookshelf_widget.lua")); local source = f:read("*a"); f:close()
local body = assert(source:match("function BookshelfWidget:_spineFaceOut%(%)\n(.-)\nend\n"))
local env = setmetatable({ BookshelfSettings = { read = function(key) return prefs[key] end },
    TabModel = package.loaded["lib/bookshelf_tab_model"] }, { __index = _G })
package.loaded["lib/bookshelf_spine_shelf"] = { FACE_REASONS = { "favorites", "reading", "first", "unread", "recent" } }
local ss_file = assert(io.open("components/bookshelf/lib/bookshelf_spine_shelf.lua"))
local ss_source = ss_file:read("*a"); ss_file:close()
local face_for = assert(ss_source:match("(function SpineShelf.faceOutFor%(tab%).-)\nend\n")) .. "\nend"
local ss_env = setmetatable({ SpineShelf = package.loaded["lib/bookshelf_spine_shelf"],
    require = function(name)
        if name == "lib/bookshelf_settings_store" then
            return { read = function(key) return prefs[key] end }
        end
        return require(name)
    end }, { __index = _G })
if setfenv then local fn = assert(loadstring(face_for)); setfenv(fn, ss_env); fn()
else assert(load(face_for, "native face-out policy", "t", ss_env))() end
local code = "return function(self)\n" .. body .. "\nend"
local loader
if setfenv then loader = assert(loadstring(code)); setfenv(loader, env)
else loader = assert(load(code, "native face-out", "t", env)) end
local Widget = { _spineFaceOut = loader(), _isSpineMode = function() return true end,
    _spineCachedFetch = function(self) return self._spine_fetch_cache end,
    _spinePageFirsts = function(self) return self._spine_fetch_cache end,
    _rebuild = function(self) return self._spine_fetch_cache end,
    _profileShelfSettings = function(self) if self.profile then return Profiles.shelfSettings(self.profile, self.chip) end end,
}
A.widget(Widget)
require("adapters/orbitui_series_boxes").widget(Widget)
local function shelf(profile)
    return setmetatable({ profile = profile, chip = "books" }, { __index = Widget })
end
local editor, invalidations = {}, 0
package.loaded["lib/bookshelf_chip_editor"] = editor
package.loaded["lib/bookshelf_ornaments"] = { invalidate = function() invalidations = invalidations + 1 end }
H.test("switching restores native global chip and profile orientation without rewriting any choice", function()
    reset(false)
    local w = shelf(); tab.spine_face_out = false
    H.eq(w:_spineFaceOut(), "all"); A.select("native")
    H.eq(w:_spineFaceOut(), false); H.eq(editor.face_out_override, nil); H.eq(editor.series_boxes_external, false)
    tab.spine_face_out = nil; H.eq(w:_spineFaceOut(), "reading")
    tab.spine_face_out = "favorites"
    profile_prefs.books = { spine_face_out = { recent = 5 }, series_boxes = true }
    w.profile = { key = "custom" }
    H.eq(w:_spineFaceOut().recent, 5)
    A.select("minimal"); H.eq(w:_spineFaceOut(), "all"); H.eq(editor.series_boxes_external, true)
    H.eq(editor.ornament_frequency_override, 0)
    A.select("native"); H.eq(w:_spineFaceOut().recent, 5)
    H.eq(editor.ornament_frequency_override, nil)
    w._drilldown_path = { { kind = "series", payload = { _series_box = true } } }
    H.eq(w:_spineFaceOut(), "all")
    H.eq(prefs.spine_face_out, "reading"); H.eq(tab.spine_face_out, "favorites")
end)
H.test("native series toggles are profile-qualified and all/off presets remain reversible", function()
    reset(true)
    tab.series_boxes = true
    local w = shelf({ key = "custom" })
    profile_prefs.books = {}
    H.eq(w:_seriesBoxesEnabled(), false)
    H.eq(shelf():_seriesBoxesEnabled(), true)
    profile_prefs.books.series_boxes = true; H.eq(w:_seriesBoxesEnabled(), true)
    A.select("minimal"); H.eq(w:_seriesBoxesEnabled(), false)
    A.select("classic"); profile_prefs.books.series_boxes = false; H.eq(w:_seriesBoxesEnabled(), true)
    A.select("native"); H.eq(w:_seriesBoxesEnabled(), false)
    profile_prefs.books.series_boxes = true
    for _, kind in ipairs({ "series", "search", "opds_nav" }) do
        w._drilldown_path = { { kind = kind } }; H.eq(w:_seriesBoxesEnabled(), false)
    end
end)
H.test("cached boxed lists are discarded on active and parked shelves without clearing navigation", function()
    reset(false)
    local live, parked = shelf(), shelf()
    live:_spineCachedFetch(); parked:_rebuild()
    live._spine_fetch_cache, parked._spine_fetch_cache = { "boxed" }, { "boxed" }
    live._cursor, live._drilldown_path = 12, { { kind = "folder" } }
    package.loaded["lib/bookshelf_widget"] = { live = live }
    local before = refreshes
    local rebuilt = 0
    live._rebuildIfSimpleUIContextChanged = function(self) rebuilt = rebuilt + 1; self._orbitui_navbar_pending = nil end
    top = {}
    A.select("native")
    H.eq(live._spine_fetch_cache, nil); H.eq(live._orbitui_navbar_pending, true)
    H.eq(live._cursor, 12); H.eq(live._drilldown_path[1].kind, "folder")
    H.eq(parked:_spineCachedFetch(), nil); H.eq(refreshes, before + 1)
    H.eq(rebuilt, 0)
    top = live; A.refreshVisible(); H.eq(rebuilt, 1)
    top = {}; live._orbitui_navbar_pending = true; A.refreshVisible(); H.eq(rebuilt, 1)
    parked._spine_fetch_cache = { "native" }; H.eq(parked:_spineCachedFetch()[1], "native")
    A.select("minimal"); H.eq(parked:_rebuild(), nil)
    package.loaded["lib/bookshelf_widget"] = nil
end)
H.test("placement changes discard parked page maps once without changing navigation or deck order", function()
    reset(false)
    local Ornaments = require("core/orbitui_author_ornaments")
    local w = shelf(); w:_rebuild()
    w._cursor, w._drilldown_path = 20, { { kind = "series" } }
    w._spine_fetch_cache = { page_firsts = { 1, 12, 20 }, page_orn = { old = true } }
    Ornaments.setPlacements({ Manga = "random" })
    H.eq(w:_spinePageFirsts(), nil)
    H.eq(w._cursor, 20); H.eq(w._drilldown_path[1].kind, "series")
    local cached = { page_firsts = { 1, 10, 20 } }; w._spine_fetch_cache = cached
    Ornaments.setPlacements({ Manga = "random", Authors = "matched" })
    H.eq(w:_spinePageFirsts(), cached); H.eq(w:_spineCachedFetch(), cached)
    Ornaments.setPlacements({})
    H.eq(w:_rebuild(), nil)
end)
H.test("failed changes roll back and do not refresh; settings selection requires confirmation", function()
    reset(true)
    local before = refreshes
    fail = true; H.eq(A.select("classic"), nil); H.eq(A.current(), "native"); H.eq(refreshes, before)
    local rows = A.items(); rows[2].callback()
    H.eq(A.current(), "native"); assert(shown.text:find("not removed", 1, true))
    shown.ok_callback(); H.eq(A.current(), "classic"); H.eq(rows[2].checked_func(), true)
    H.eq(data.unrelated.private, "kept")
end)
H.test("preset menu updates its radio state after asynchronous confirmation", function()
    reset(true)
    local updates = 0
    package.loaded["lib/bookshelf_menu_host"] = { show = function(opts)
        opts._shim = { updateItems = function() updates = updates + 1 end }
        return opts
    end }
    local host = A.show()
    host.item_table[3].callback(); H.eq(updates, 0); H.eq(A.current(), "native")
    shown.ok_callback(); H.eq(updates, 1); H.eq(host.item_table[3].checked_func(), true)
    host.item_table[1].callback(); host._closed = true; shown.ok_callback(); H.eq(updates, 1)
end)

local seed_calls = 0
local Authors = require("core/orbitui_author_ornaments")
Authors.seed = function() seed_calls = seed_calls + 1 end
for _, name in ipairs({ "japan", "ukiyoe", "manga" }) do
    package.loaded["core/orbitui_" .. name .. "_ornaments"] = { seed = function() seed_calls = seed_calls + 1 end }
end
local Ornaments = require("adapters/orbitui_ornaments")
package.loaded["adapters/orbitui_addons"] = { ornaments = function() end }
H.test("no preset automatically installs artwork or deletes existing packs", function()
    reset(true)
    local existing = { { name = "User artwork" } }
    local orn = Ornaments.wrap("lib/bookshelf_ornaments", {
        dir = function() return "/ornaments" end, listAll = function() return existing, { "User pack" } end,
        frequency = function() return 3 end,
    }, "/plugin")
    H.eq(orn.listAll(), existing); H.eq(seed_calls, 0); H.eq(orn.frequency(), 3)
    A.select("minimal"); H.eq(orn.frequency(), 0); orn.listAll(); H.eq(seed_calls, 0)
    A.select("classic"); H.eq(orn.listAll(), existing); H.eq(seed_calls, 0)
    orn.listAll(); H.eq(seed_calls, 0)
    A.select("native"); H.eq(orn.listAll(), existing); H.eq(orn.frequency(), 3)
    A.select("classic"); orn.listAll(); H.eq(seed_calls, 0)
end)
H.test("minimal mode disables targeted ornaments too, while only classic shuffles once per session", function()
    reset(true)
    local shuffles = 0
    local deck = Ornaments.wrap("lib/bookshelf_ornament_deck", {
        fillHooks = function(env) H.eq(env.level, "off"); return { off = true } end,
        sync = function() end, shuffle = function() shuffles = shuffles + 1 end,
    }, "/plugin")
    local cards = { { name = "James Joyce.png", pack = "Authors" } }
    deck.sync(cards, "shelf"); H.eq(shuffles, 0)
    A.select("minimal")
    H.eq(deck.fillHooks({ level = "many", dealer = { cards = cards } }).off, true)
    deck.sync(cards, "shelf"); H.eq(shuffles, 0)
    A.select("classic"); deck.sync(cards, "shelf"); deck.sync(cards, "shelf"); H.eq(shuffles, 1)
    A.select("native"); A.select("classic"); deck.sync(cards, "shelf"); H.eq(shuffles, 1)
end)
H.test("Swedish labels and descriptions translate, other languages use English with stable IDs", function()
    G_reader_settings = { readSetting = function() return "sv_SE" end }
    H.eq(A.label("minimal"), "Avskalad bokhylla")
    assert(A.items()[1].help_text:find("hyllas", 1, true))
    G_reader_settings = { readSetting = function() return "fr_FR" end }
    H.eq(A.label("native"), "Shelf settings"); H.eq(Model.value("native").preset, "native")
end)
H.finish()
