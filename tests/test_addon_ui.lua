package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_addons")
local rows, dialogs, tasks, online, refreshes, notices = {}, {}, {}, true, 0, {}
local installed = { schema = 1, revision = 0, packs = {} }
local data = { { name = "Manga/A.png", pack = "Manga" }, { name = "Manga II/B.png", pack = "Manga II" },
    { name = "Manga III/C.png", pack = "Manga III" }, { name = "Own/D.png", pack = "Own" } }
local p = { id = "manga", name = "Manga", version = 1, description = "Manga", folders = { "Manga", "Manga II", "Manga III" },
    url = "https://example.invalid/not-used", size = 100 }
local adopted, active, toggles, placements = 0, 0, {}, 0
local s = {
    registry = function() return installed end,
    view = function() return { "/managed" }, function(_, _, root) return root ~= "/hidden" end,
        function(entry) return not (installed.packs.manga and installed.packs.manga.enabled == false and entry.pack:match("^Manga")) end end,
    catalog = function() return { packs = { p } } end,
    enable = function(_, key, enabled) installed.packs[key].enabled = enabled end,
    setPlacement = function(_, key, mode) installed.packs[key].placement = mode; placements = placements + 1 end,
    prepare = function() adopted = adopted + 1; return "plan" end,
    activate = function(_, plan) H.eq(plan, "plan"); active = active + 1 end,
    versionRoot = function() return "/managed" end,
}
package.loaded["core/orbitui_addons"] = { new = function() return s end, placement = Model.placement }
local made = {}
package.loaded["core/orbitui_addon_files"] = { attr = function() end, mkdir = function(path) made[#made + 1] = path end,
    json = function() return { bindings = {} } end }
package.loaded.datastorage = { getSettingsDir = function() return "/settings" end }
package.loaded["core/orbitui_i18n"] = nil
package.loaded["core/orbitui_context"] = { notify = function(text) notices[#notices + 1] = text end }
local warnings = {}
package.loaded.logger = { warn = function(_, err) warnings[#warnings + 1] = tostring(err) end }
package.loaded["adapters/orbitui_appearance"] = { changed = function() refreshes = refreshes + 1 end, refreshVisible = function() end }
package.loaded["ui/uimanager"] = { show = function(_, d) dialogs[#dialogs + 1] = d end, close = function() end }
for _, n in ipairs({ "confirmbox", "buttondialog" }) do package.loaded["ui/widget/" .. n] = { new = function(_, opts) return opts end } end
package.loaded["ui/network/manager"] = { runWhenOnline = function(_, fn) if online then fn() end end }
package.loaded["adapters/orbitui_updates"] = { runTask = function(operation, _, done) tasks[#tasks + 1] = { operation, done } end }
local sw = { isOff = function() return false end, isPackOff = function(pack) return pack == "Manga II" end,
    setOff = function(name, off) toggles[name] = off end, setPackOff = function(name, off) toggles[name] = off end }
package.loaded["lib/bookshelf_theme_pack"] = { switches = function() return sw end,
    invalidate = function() end, forgetChoice = function() end }
local orn = { roots = function() return { "/native" } end, dir = function() return "/native" end,
    invalidate = function() end, list = function() return data end, listFor = function() return data end,
    listAll = function() return data, { "Manga", "Manga II", "Manga III", "Own" } end }
package.loaded["lib/bookshelf_ornaments"] = orn
local A = require("adapters/orbitui_addons")
A.ornaments(orn, "/plugin")
H.test("ornament language follows the reader setting rather than the UI menu translator", function()
    local r = { info = "Original", info_source = "Original", info_en = "English", info_sv = "Svenska" }
    G_reader_settings = { readSetting = function() return "sv_SE" end }
    H.eq(orn.resolveInfo(r), "Svenska")
    G_reader_settings.readSetting = function() return "de" end
    H.eq(orn.resolveInfo(r), "English")
    G_reader_settings = nil
    H.eq(orn.resolveInfo(r), "English")
end)
H.test("fresh hosts create no stock artwork and managed roots are added without changing native roots", function()
    H.eq(#made, 0); orn.ensureTemplate(); H.eq(made[1], "/native")
    local roots = orn.roots(); H.eq(roots[1], "/native"); H.eq(roots[2], "/managed")
    assert(not orn.acceptFile("x", "x", "/hidden"))
    H.eq(orn.packGroup("Manga III"), "Manga"); H.eq(orn.packGroup("Own"), "Own")
end)
H.test("existing unmanaged folders open the add-on menu from Home in Swedish and English", function()
    local F = require("core/orbitui_addon_files")
    local attr, legacy = F.attr, s.legacy
    local languages = { en = "Local files; not managed", sv_SE = "Lokala filer; inte pakethanterade" }
    local menu
    package.loaded["lib/bookshelf_menu_host"] = { show = function(opts)
        menu = opts
        return { _shim = { liveItems = function() return menu.item_table end, updateItems = function() end } }
    end }
    s.legacy = { "/native", "/legacy" }
    for lang, status in pairs(languages) do
        G_reader_settings = { readSetting = function() return lang end }
        for _, root in ipairs(s.legacy) do
            for _, folder in ipairs(p.folders) do
                F.attr = function(path) if path == root .. "/" .. folder then return { mode = "directory" } end end
                H.eq(A.items()[2].text, "Manga - " .. status)
                local warning_count, notice_count = #warnings, #notices
                menu = nil
                A.show()
                assert(menu, "Add-on menu did not open over existing native artwork")
                H.eq(menu.item_table[2].text, "Manga - " .. status)
                H.eq(#warnings, warning_count); H.eq(#notices, notice_count)
                H.eq(next(installed.packs), nil); H.eq(adopted, 0); H.eq(active, 0)
                H.eq(#tasks, 0); H.eq(next(toggles), nil)
                menu.close_callback()
            end
        end
    end
    F.attr, s.legacy, G_reader_settings = attr, legacy, nil
end)
H.test("disabled add-ons are filtered from collection and themed shelves with stable list identities", function()
    H.eq(#orn.list(), 4); H.eq(orn.list(), orn.list())
    installed.packs.manga = { pack = p, enabled = false }
    A.changed()
    H.eq(#orn.list(), 1); H.eq(#orn.listFor("Some theme"), 1)
    H.eq(orn.list(), orn.listFor("Some theme"))
    H.eq(#orn.listAll(), 4)
end)
H.test("use on current shelf calls only captured native switches and enables the logical pack", function()
    A.use(p)
    H.eq(toggles["Manga/A.png"], false); H.eq(toggles["Manga II/B.png"], false)
    H.eq(toggles["Manga III/C.png"], false); H.eq(toggles["Own/D.png"], nil)
    H.eq(installed.packs.manga.enabled, true)
end)
H.test("Wi-Fi cancellation and cancelled downloads never activate prepared data", function()
    online = false; A.install(p); dialogs[#dialogs].ok_callback(); H.eq(#tasks, 0)
    online = true; A.install(p); dialogs[#dialogs].ok_callback(); H.eq(#tasks, 1)
    tasks[1][2]({ error = "cancelled" }); H.eq(active, 0)
    A.install(p); dialogs[#dialogs].ok_callback(); H.eq(#tasks, 2)
    local plan = tasks[2][1](); H.eq(adopted, 1); H.eq(active, 0)
    tasks[2][2]({ ok = true, value = plan }); H.eq(active, 1)
end)
H.test("catalog UI rebuilds its live rows after changes", function()
    local live
    package.loaded["lib/bookshelf_menu_host"] = { show = function(opts)
        live = opts.item_table
        return { _shim = { liveItems = function() return live end, updateItems = function() rows = live end } }
    end }
    A.show("/plugin"); installed.packs.manga.enabled = false; A.changed()
    assert(rows[2].text:find("Disabled", 1, true))
end)
H.test("placement menu defaults to matching, supports cancellation and covers all logical pack folders", function()
    local menu, updates = nil, 0
    package.loaded["lib/bookshelf_menu_host"] = { show = function(opts)
        menu = opts
        return { _shim = { updateItems = function() updates = updates + 1 end } }
    end }
    A.packMenu(p)
    local button
    for _, row in ipairs(dialogs[#dialogs].buttons) do
        if row[1].text == "Placement: Match books (default)" then button = row[1] end
    end
    assert(button); button.callback(); assert(menu, warnings[#warnings])
    H.eq(menu.title, "Placement: Manga")
    H.eq(#menu.item_table, 2); H.eq(menu.item_table[1].radio, true)
    assert(menu.item_table[1].checked_func()); assert(not menu.item_table[2].checked_func())
    menu.close_callback(); H.eq(placements, 0)
    A.placementMenu(p)
    menu.item_table[2].callback()
    H.eq(installed.packs.manga.enabled, false)
    H.eq(installed.packs.manga.placement, "random")
    assert(menu.item_table[2].checked_func()); assert(not menu.item_table[1].checked_func())
    H.eq(updates, 1)
    local Authors = require("core/orbitui_author_ornaments")
    for _, name in ipairs({ "Manga/Kaneda Motorcycle.png", "Manga II/Pochita.png", "Manga III/Stargazing Telescope.png" }) do
        H.eq(Authors.target({ name = name }), nil)
    end
    H.eq(Authors.target({ name = "Modernists/James Joyce.png" }), "james joyce")
    H.eq(toggles["Manga/A.png"], false); H.eq(toggles["Own/D.png"], nil)
    A.packMenu(p)
    local labelled = false
    for _, row in ipairs(dialogs[#dialogs].buttons) do labelled = labelled or row[1].text == "Placement: Random" end
    assert(labelled)
    menu.item_table[1].callback()
    H.eq(Authors.target({ name = "Manga/Kaneda Motorcycle.png" }), "series:akira")
    H.eq(installed.packs.manga.enabled, false)
end)

-- Real native browser logic, with drawing services stubbed (no pixel assertions).
local W = H.widget()
for _, n in ipairs({ "container/centercontainer", "container/framecontainer", "textboxwidget", "verticalgroup", "verticalspan", "widget" }) do
    package.loaded["ui/widget/" .. n] = W
end
package.loaded["ffi/blitbuffer"] = {}
package.loaded["ffi/util"] = { template = function(s, value) return (s:gsub("%%1", value)) end }
package.loaded.device = { screen = {} }; package.loaded["ui/font"] = {}; package.loaded["ui/geometry"] = W
package.loaded["ui/size"] = {}; package.loaded["lib/bookshelf_space"] = {}
package.loaded["lib/bookshelf_colour_text"] = W
package.loaded["lib/bookshelf_library_modal"] = W
package.loaded["ui/widget/infomessage"] = W
package.loaded["lib/bookshelf_i18n"] = { gettext = function(s) return s end }
local Browser = dofile("components/bookshelf/lib/bookshelf_ornament_browser.lua")
H.test("native ornament browser presents one Manga chip containing all old packs", function()
    local b = setmetatable({ chip = "Manga", opts = {} }, { __index = Browser })
    local chips = b:_chips()
    H.eq(#chips, 3); H.eq(chips[2].label, "Manga")
    H.eq(#b:_items(), 3)
    A.browser(Browser, "/plugin")
    H.eq(b:_addButton().label, "Ornament add-ons")
    H.eq(b:_items()[1].off, true)
    b:_toggle(b:_items()[1])
    H.eq(installed.packs.manga.enabled, true)
    H.eq(toggles["Manga/A.png"], false)
end)
H.finish()
