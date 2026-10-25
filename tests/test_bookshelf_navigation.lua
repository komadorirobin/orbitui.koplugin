package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Copy = require("core/orbitui_libraries").copy
local values, books, queue, hosts, notices, opened, closed = {}, {}, {}, {}, {}, {}, {}
local Store = {
    get = function(_, k) return values[k] end,
    set = function(_, k, v) values[k] = v end,
    readSetting = function(_, k) return values[k] end,
    isTrue = function(_, k) return values[k] == true end,
    nilOrTrue = function(_, k) return values[k] ~= false end,
}
G_reader_settings = { readSetting = function(_, key) if key == "home_dir" then return "/books" end end }
local Widget = H.widget()
local UI = { nextTick = function(_, fn) queue[#queue + 1] = fn end,
    isWidgetShown = function(_, w) return w.shown end,
    show = function() end, close = function(_, w) closed[#closed + 1] = w end }
local deps = {
    ["ffi/blitbuffer"] = {}, ["datastorage"] = {}, ["infra/sui_store"] = Store,
    ["infra/sui_cover_cache"] = {}, ["infra/sui_lru"] = { new = function() return {} end },
    ["infra/sui_memory"] = { budgets = function() return { ref = 100, crop = 100 } end },
    ["infra/sui_backdrop"] = {}, ["infra/sui_text"] = {}, ["infra/sui_bento"] = {},
    ["infra/sui_paths"] = { getPluginDir = function() return "/orbitui/components/simpleui/" end },
    ["infra/sui_i18n"] = { translate = function(s) return s end, ngettext = function(s) return s end },
    ["util"] = {}, ["ffi/util"] = { template = function(s) return s end },
    ["logger"] = { warn = function() end, dbg = function() end },
    ["libs/libkoreader-lfs"] = { attributes = function() end },
    ["ui/uimanager"] = UI, ["ui/event"] = { new = function(_, name, key) return { name = name, key = key } end },
    ["ui/widget/verticalgroup"] = Widget, ["ui/widget/verticalspan"] = Widget,
    ["device"] = { screen = {} }, ["infra/sui_virtual_paths"] = {}, ["features/sui_style"] = {},
    ["infra/sui_core"] = { getOpenScreen = function() end,
        Notify = { toast = function(s) notices[#notices + 1] = s end } },
    ["lib/bookshelf_settings_store"] = { read = function(k) return books[k] end,
        save = function(k, v) books[k] = v end, flush = function() end },
}
for name, module in pairs(deps) do package.loaded[name] = module end
local Nav = require("adapters/orbitui_navbar")
local Libraries = require("adapters/orbitui_libraries")
local P = dofile("components/bookshelf/lib/bookshelf_profiles.lua")
package.loaded["lib/bookshelf_profiles"] = P
Libraries.profiles(P)
-- Load complete modules, not extracted config/registry functions. Native
-- rendering, event delivery and persistence are the explicit test boundaries.
local Config = dofile("components/simpleui/infra/sui_config.lua")
package.loaded["infra/sui_config"] = Config
require("adapters/orbitui_ui").wrap("infra/sui_config", Config)
local QA = dofile("components/simpleui/features/sui_quickactions.lua")
package.loaded["features/sui_quickactions"] = QA
Libraries.actions(QA)
package.loaded["lib/bookshelf_menu_host"] = {
    show = function(opts)
        opts._shim = { updateItems = function() end, closeMenu = function() opts._closed = true end }
        hosts[#hosts + 1] = opts; return opts
    end,
}
local Settings = require("adapters/orbitui_library_settings")
local Context = require("core/orbitui_context")
local bookshelf
Context.plugin = function(name) if name == "bookshelf" then return bookshelf end end
Context.notify = function(text) notices[#notices + 1] = text end
local function find(rows, text)
    for _, row in ipairs(rows) do
        if row.text == text or row.text_func and row.text_func() == text then return row end
    end
    error("Missing menu row: " .. text)
end
local function reset(tabs)
    values.simpleui_bar_tabs = Copy(tabs)
    values.orbitui_bookshelf_profile = nil
    Config.invalidateTabsCache(); hosts, notices, opened, closed = {}, {}, {}, {}
end
bookshelf = {
    onOpenBookshelfProfile = function(_, key)
        if key and not P.get(key) then return false end
        opened[#opened + 1] = { key = key }
        bookshelf._widget = { shown = true, profile_key = key, setProfile = function(self, value)
            self.profile_key = value
        end }
        return true
    end,
    onOpenBookshelfProfileStartMenu = function(self, key) return self:onOpenBookshelfProfile(key) end,
}
Libraries.classes(bookshelf)
UI.broadcastEvent = function(_, event)
    if event.name == "OpenBookshelfProfile" then return bookshelf:onOpenBookshelfProfile(event.key) end
    if event.name == "OpenBookshelfProse" then return bookshelf:onOpenBookshelfProfile("prose") end
    if event.name == "OpenBookshelfProfileStartMenu" then return bookshelf:onOpenBookshelfProfileStartMenu(event.key) end
    error("Unexpected event: " .. event.name)
end
package.loaded.dispatcher = { execute = function(_, actions)
    if actions.open_bookshelf_prose then return bookshelf:onOpenBookshelfProfile("prose") end
    error("Unexpected dispatcher action")
end }

H.test("a clean default exposes a real removable Bookshelf action without prose or comics", function()
    reset()
    H.eq(P.get("prose"), nil); H.eq(P.get("comics"), nil)
    H.eq(Config.loadTabConfig()[1], "homescreen"); H.eq(Config.loadTabConfig()[2], Nav.bookshelf_action)
    H.eq(QA.isRegistered(Nav.bookshelf_action), true); H.eq(QA.isInPlace(Nav.bookshelf_action), false)
    H.eq(QA.getEntry(Nav.bookshelf_action).label, "Bookshelf")
    QA.execute(Nav.bookshelf_action, {})
    H.eq(#opened, 1); H.eq(opened[1].key, nil); H.eq(#hosts, 0)
    assert(Nav.setAction(Nav.bookshelf_action, false))
    Config.invalidateTabsCache(); H.eq(Nav.hasAction(Nav.bookshelf_action), false)
    H.eq(#Config.loadTabConfig(), 4)
    H.eq(Config.homeLabel(), "File browser")
    H.eq(QA.getEntry("home").label, "File browser")
    values.simpleui_action_home_label = "My folders"
    H.eq(QA.getEntry("home").label, "My folders")
    values.simpleui_action_home_label = nil
end)
H.test("saved Bigme and Boox bars, custom labels and icons are not migrated or overwritten", function()
    reset({ "homescreen", "custom_qa_1", "bookshelf_comics", "power" })
    values.simpleui_qa_custom_qa_1 = { label = "Bibliotek", icon = "mine", dispatcher_action = "open_bookshelf_prose" }
    local before = Copy(values)
    H.eq(Config.loadTabConfig()[2], "custom_qa_1")
    H.eq(#Config.loadTabConfig(), 4); H.eq(Nav.hasAction(Nav.bookshelf_action), false)
    H.eq(values.simpleui_qa_custom_qa_1.icon, before.simpleui_qa_custom_qa_1.icon)
    H.eq(values.simpleui_qa_custom_qa_1.dispatcher_action, "open_bookshelf_prose")
end)
H.test("the photographed missing legacy dispatcher target opens repair instead of silently doing nothing", function()
    reset({ "homescreen", "custom_qa_1", "power" })
    QA.execute("custom_qa_1", {})
    H.eq(#opened, 0); H.eq(#hosts, 1); H.eq(hosts[1].title, "Bookshelf profile unavailable")
    assert(hosts[1].item_table[1].text:find("prose", 1, true))
    find(hosts[1].item_table, "Open Bookshelf").callback(hosts[1]._shim)
    H.eq(hosts[1]._closed, true); H.eq(#opened, 1); H.eq(opened[1].key, nil)
    H.eq(values.simpleui_qa_custom_qa_1.dispatcher_action, "open_bookshelf_prose")
end)
H.test("one destination picker opens any saved profile without a custom dispatcher action", function()
    reset()
    local key = P.add("Manga", "/manga")
    Libraries.actions(QA)
    find(Settings.destinationItems(), "Manga").callback()
    H.eq(Libraries.bookshelfTarget(), key)
    QA.execute(Nav.bookshelf_action, {})
    H.eq(opened[1].key, key)
    assert(QA.holdExecute(Nav.bookshelf_action, {}))
    H.eq(hosts[#hosts].title, "Bookshelf navigation")
    find(Settings.destinationItems(), "Bookshelf (no fixed profile)").callback()
    H.eq(Libraries.bookshelfTarget(), nil)
end)
H.test("profiles can be added directly as separate navigation buttons with their own chips", function()
    reset({ "homescreen", "power" })
    local manga = P.list()[2]
    find(Settings.sectionItems(manga.key), "Add to navigation bar").callback()
    H.eq(Config.loadTabConfig()[3], Libraries.actionId(manga.key))
    QA.execute(Libraries.actionId(manga.key), {})
    H.eq(opened[1].key, manga.key); H.eq(P.get(manga.key).chips[1].source.id, "/manga")
    find(Settings.sectionItems("library"), "Use for Bookshelf button").callback()
    H.eq(Libraries.bookshelfTarget(), "library"); H.eq(Nav.hasAction(Nav.bookshelf_action), true)
end)
H.test("full bars replace only the explicitly selected slot and duplicate additions are idempotent", function()
    reset({ "homescreen", "home", "sui_settings", "history", "power", "custom_qa_1" })
    Settings.addToBar(Nav.bookshelf_action)
    H.eq(#Config.loadTabConfig(), 6); H.eq(Nav.hasAction(Nav.bookshelf_action), false)
    local picker = hosts[#hosts]
    H.eq(picker.title, "Bar full: choose a button to replace")
    find(picker.item_table, "History").callback(picker._shim)
    H.eq(picker._closed, true); H.eq(Config.loadTabConfig()[4], Nav.bookshelf_action)
    H.eq(Config.loadTabConfig()[6], "custom_qa_1"); H.eq(#Config.loadTabConfig(), 6)
    Settings.addToBar(Nav.bookshelf_action); H.eq(#Config.loadTabConfig(), 6)
end)
H.test("missing and disabled configured profiles fail closed and remain repairable", function()
    reset()
    values.orbitui_bookshelf_profile = "deleted"
    QA.execute(Nav.bookshelf_action, {}); H.eq(#opened, 0)
    H.eq(hosts[1].title, "Bookshelf profile unavailable")
    H.eq(values.orbitui_bookshelf_profile, "deleted")
    P.edit("library", function(section) section.enabled = false end)
    values.orbitui_bookshelf_profile = "library"
    QA.execute(Nav.bookshelf_action, {}); H.eq(#opened, 0)
    H.eq(#Settings.destinationItems(), 2)
    P.edit("library", function(section) section.enabled = true end)
end)
H.test("bridge indicators prefer explicit profiles and preserve the generic Bookshelf slot", function()
    reset()
    local bridge = dofile("components/simpleui/sui_bookshelf_bridge.lua")
    Libraries.bridge(bridge)
    local key = P.list()[2].key
    Libraries.setBookshelfTarget(key)
    H.eq(bridge.profileForNavigation(Nav.bookshelf_action), key)
    H.eq(bridge.resolveProfileTab(key, { "homescreen", Nav.bookshelf_action }), Nav.bookshelf_action)
    H.eq(bridge.resolveProfileTab(key, { Nav.bookshelf_action, Libraries.actionId(key) }), Libraries.actionId(key))
    Libraries.setBookshelfTarget(nil)
    H.eq(bridge.resolveProfileTab(nil, { "homescreen", Nav.bookshelf_action }), Nav.bookshelf_action)
    H.eq(bridge.activateProfile("library", {}, { Nav.bookshelf_action }), Nav.bookshelf_action)
end)
H.test("an explicit destination wins after a parked reader restores a different shelf profile", function()
    reset()
    local key = P.list()[2].key
    Libraries.setBookshelfTarget(key)
    local original = bookshelf.onOpenBookshelfProfile
    bookshelf.onOpenBookshelfProfile = function(self, wanted)
        H.eq(wanted, key)
        self._widget = { shown = true, profile_key = "library", setProfile = function(widget, value)
            widget.profile_key = value
        end }
        return true
    end
    QA.execute(Nav.bookshelf_action, {})
    H.eq(bookshelf._widget.profile_key, "library", "do not bypass the native reader transition")
    local pending = queue; queue = {}
    for _, callback in ipairs(pending) do callback() end
    H.eq(bookshelf._widget.profile_key, key)
    bookshelf.onOpenBookshelfProfile = original
end)
H.test("new profile navigation supersedes an older deferred profile selection", function()
    reset()
    local key = P.list()[2].key
    Libraries.setBookshelfTarget(key); QA.execute(Nav.bookshelf_action, {})
    Libraries.setBookshelfTarget("library"); QA.execute(Nav.bookshelf_action, {})
    local pending = queue; queue = {}
    for _, callback in ipairs(pending) do callback() end
    H.eq(bookshelf._widget.profile_key, "library")
end)
H.test("valid legacy profile aliases keep working and minimum and navpager limits are respected", function()
    reset({ "homescreen", "power" })
    local config = Copy(P.config())
    local prose = Copy(config.sections[1]); prose.key, prose.label = "prose", "Prose"
    config.sections[#config.sections + 1] = prose; P.save(config); Libraries.actions(QA)
    QA.execute("custom_qa_1", {}); H.eq(opened[1].key, "prose"); H.eq(#hosts, 0)
    H.eq(Nav.setAction("power", false), false); H.eq(#Config.loadTabConfig(), 2)
    values.simpleui_bar_navpager_enabled = true
    assert(Nav.setAction("power", false)); H.eq(#Config.loadTabConfig(), 1)
    assert(Nav.setAction(Nav.bookshelf_action, true)); assert(Nav.setAction("history", true))
    assert(Nav.setAction("power", true)); H.eq(Nav.setAction("home", true), false)
end)

H.finish()
