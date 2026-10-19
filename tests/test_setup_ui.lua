package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_setup")
local Copy = require("core/orbitui_libraries").copy
local files, data, settings, books, queue, windows, hosts, redraws
local function store(values)
    return { data = values, readSetting = function(_, k) return values[k] end,
        saveSetting = function(_, k, v) values[k] = v end, delSetting = function(_, k) values[k] = nil end,
        flush = function() end }
end
package.loaded["datastorage"] = { getSettingsDir = function() return "/settings" end }
package.loaded["libs/libkoreader-lfs"] = {
    attributes = function(path) return files[path] end,
    mkdir = function(path) files[path] = "directory"; return true end,
}
-- lfs.dir returns names, not numeric indices.
package.loaded["libs/libkoreader-lfs"].dir = function()
    local names, index = {}, 0
    for path in pairs(files) do local name = path:match("^/settings/([^/]+)$"); if name then names[#names + 1] = name end end
    return function() index = index + 1; return names[index] end
end
package.loaded.luasettings = { open = function(_, path) H.eq(path, "/settings/orbitui/setup.lua"); return store(data) end }
package.loaded.logger = { warn = function() end }
local UI = {
    nextTick = function(_, fn) queue[#queue + 1] = fn end,
    show = function(_, widget) windows[#windows + 1] = widget end,
    close = function(_, widget) widget.closed = true; if widget.onCloseWidget then widget:onCloseWidget() end end,
}
package.loaded["ui/uimanager"] = UI
for _, name in ipairs({ "infomessage", "inputdialog", "pathchooser", "confirmbox" }) do
    package.loaded["ui/widget/" .. name] = { new = function(_, opts)
        opts.onShowKeyboard = function() end
        opts.getInputText = function(self) return self.input end
        return opts
    end }
end
package.loaded["lib/bookshelf_menu_host"] = {
    show = function(opts)
        opts._shim = { updateItems = function() end }; hosts[#hosts + 1] = opts; return opts
    end,
    close = function(host) if host._closed then return end; host._closed = true; host.close_callback() end,
}
package.loaded["lib/bookshelf_profiles"] = { config = function() return books.orbitui_libraries end }
package.loaded["lib/bookshelf_settings_store"] = {
    read = function(k) return books[k] end, save = function(k, v) books[k] = v end,
    delete = function(k) books[k] = nil end, flush = function() end,
}
package.loaded["modules/moduleregistry"] = {
    loadOrder = function() return settings.simpleui_hs_module_order or { "currently", "recent" } end,
    get = function(id) return { id = id } end, isEnabled = function() return true end,
}
package.loaded["infra/sui_config"] = {
    loadTabConfig = function() return settings.simpleui_bar_tabs end,
    effectiveMaxTabs = function() return 4 end, invalidateTabsCache = function() end,
    ACTION_BY_ID = { home = { label = "Library" }, homescreen = { label = "Home" }, history = { label = "History" },
        power = { label = "Power" }, sui_settings = { label = "Settings" } },
}
package.loaded["adapters/orbitui_libraries"] = {
    actionId = function(key) return "orbitui_library_" .. key end, changed = function() redraws = redraws + 1 end,
}
local function reset(existing, saved, existing_host)
    files, data, queue, windows, hosts, redraws = { ["/Books"] = "directory" }, saved or {}, {}, {}, {}, 0
    if existing then files["/settings/simpleui/sui_settings.lua"] = "file" end
    settings = { simpleui_bar_tabs = { "home", "homescreen", "power" }, simpleui_hs_book_close_target = "book_folder",
        secret = "kept", simpleui_layout = { pages = { { id = 3, modules = { "currently" } } } } }
    books = { orbitui_libraries = { version = 1, sections = {} }, bookshelf_private = "kept" }
    G_reader_settings = store({ home_dir = "/Books", start_with = "last", secret = "kept" })
    package.loaded["infra/sui_store"] = store(settings)
    package.loaded["infra/sui_store"].setNoFlush = function(_, k, v) settings[k] = v end
    package.loaded["adapters/orbitui_setup"] = nil
    local Setup = require("adapters/orbitui_setup"); Setup.prepare(existing_host); return Setup
end
local function drain()
    local pending = queue; queue = {}
    for _, fn in ipairs(pending) do fn() end
end
local function row(rows, text)
    for _, value in ipairs(rows) do if value.text == text or value.text_func and value.text_func() == text then return value end end
    error("Missing row: " .. text)
end

H.test("fresh startup is pending before default files exist, and auto-shows once only on FileManager", function()
    local Setup = reset()
    H.eq(data.setup.status, "pending")
    H.eq(data.appearance.preset, "native")
    Setup.started({ ui = { document = {} } }); drain(); H.eq(#hosts, 0)
    local owner = { ui = {} }; Setup.started(owner); drain(); H.eq(#hosts, 1)
    Setup.started(owner); drain(); H.eq(#hosts, 1)
    H.eq(G_reader_settings.data.start_with, "last")
    Setup.stopped(owner); H.eq(hosts[1]._closed, true)
end)
H.test("upgrades do not auto-show or replace preferences, manual guide defaults to keep", function()
    local Setup = reset(true)
    local before = Copy(settings)
    H.eq(data.setup.status, "kept")
    H.eq(data.appearance.preset, "classic")
    Setup.started({ ui = {} }); drain(); H.eq(#hosts, 0)
    local host = Setup.show()
    assert(row(host.item_table, "Start screen: Keep existing"))
    row(host.item_table, "Cancel (keep settings)").callback()
    assert(Model.equal(settings, before)); H.eq(G_reader_settings.data.start_with, "last")
end)
H.test("first OrbitUI install over standalone components uses neutral appearance without prompting", function()
    local Setup = reset(true, nil, false)
    H.eq(data.setup.status, "kept"); H.eq(data.appearance.preset, "native")
    Setup.started({ ui = {} }); drain(); H.eq(#hosts, 0)
    reset(true, Copy(data), true); H.eq(data.appearance.preset, "native")
end)
H.test("shelf presets stay in the setup draft until confirmation and are saved with the completion marker", function()
    local Setup = reset(true)
    local host = Setup.show()
    local choices = row(host.item_table, "Shelf preset: Keep existing").sub_item_table_func()
    row(choices, "Minimal bookshelf").callback(); H.eq(data.appearance.preset, "classic")
    row(host.item_table, "Cancel (keep settings)").callback(); H.eq(data.appearance.preset, "classic")
    host = Setup.show()
    choices = row(host.item_table, "Shelf preset: Keep existing").sub_item_table_func()
    row(choices, "Minimal bookshelf").callback()
    row(host.item_table, "Review and apply").callback()
    H.eq(data.appearance.preset, "classic")
    local confirm = windows[#windows]; assert(confirm.text:find("Minimal bookshelf", 1, true))
    confirm.ok_callback(); UI:close(confirm); drain()
    H.eq(data.appearance.preset, "minimal"); H.eq(data.setup.status, "complete")
    reset(true, Copy(data), true); H.eq(data.appearance.preset, "minimal")
end)
H.test("cancelled folder drafts never become stored sections and late picker callbacks are ignored", function()
    local Setup = reset(true)
    local host = Setup.show()
    local sections = row(host.item_table, "Library sections and folders").sub_item_table_func()
    row(sections, "Add library section").callback()
    local input = windows[#windows]; input.input = "Favourites"; input.buttons[1][2].callback()
    local picker = windows[#windows]
    row(host.item_table, "Cancel (keep settings)").callback()
    assert(picker.closed)
    picker.onConfirm("/Books")
    H.eq(#books.orbitui_libraries.sections, 0)
end)
H.test("review does not write, confirmation saves scoped settings and leaves private data and old pages alone", function()
    local Setup = reset()
    local host = Setup.show(nil, true)
    local sections = row(host.item_table, "Library sections and folders").sub_item_table_func()
    row(sections, "Add library section").callback()
    local input = windows[#windows]; input.input = "My books"; input.buttons[1][2].callback()
    windows[#windows].onConfirm("/Books")
    local bar = row(host.item_table, "Bottom bar").sub_item_table_func()
    row(bar, "My books").callback()
    row(host.item_table, "Review and apply").callback()
    H.eq(#books.orbitui_libraries.sections, 0); H.eq(data.setup.status, "pending")
    local confirm = windows[#windows]; assert(confirm.text:find("My books: /Books", 1, true))
    confirm.ok_callback(); UI:close(confirm); drain()
    H.eq(data.setup.status, "complete"); H.eq(redraws, 1)
    H.eq(books.orbitui_libraries.sections[1].label, "My books")
    H.eq(settings.simpleui_layout.pages[2].id, 3)
    H.eq(settings.simpleui_bar_tabs[4], "orbitui_library_section_1")
    H.eq(settings.simpleui_hs_book_close_target, "book_folder")
    H.eq(settings.secret, "kept"); H.eq(G_reader_settings.data.secret, "kept"); H.eq(books.bookshelf_private, "kept")
    H.eq(G_reader_settings.data.start_with, "homescreen_simpleui")
end)
H.test("teardown cancels pending startup; skip survives restart; pending survives generated files", function()
    local Setup = reset(); local owner = { ui = {} }
    Setup.started(owner); Setup.stopped(owner); drain(); H.eq(#hosts, 0)
    local host = Setup.show(); row(host.item_table, "Skip automatic setup").callback()
    Setup = reset(true, Copy(data)); Setup.started({ ui = {} }); drain(); H.eq(#hosts, 0)
    Setup = reset(true, { setup = { version = 1, status = "pending" } })
    Setup.started({ ui = {} }); drain(); H.eq(#hosts, 1)
end)
H.test("future setup schemas remain untouched and cannot be bypassed by retrying", function()
    local ok = pcall(reset, true, { setup = { version = 99, status = "pending" } })
    H.eq(ok, false); H.eq(data.setup.version, 99)
    H.eq(pcall(require("adapters/orbitui_setup").prepare), false)
end)
H.test("a late Apply after host teardown cannot commit a reviewed draft", function()
    local Setup = reset(); local owner = { ui = {} }
    Setup.started(owner); drain()
    row(hosts[1].item_table, "Review and apply").callback()
    local confirm = windows[#windows]
    confirm.ok_callback(); Setup.stopped(owner); drain()
    H.eq(data.setup.status, "pending"); H.eq(G_reader_settings.data.start_with, "last")
end)
H.test("opening a reader before the queued FileManager prompt defers setup", function()
    local Setup = reset()
    Setup.started({ ui = {} })
    local reader = { ui = { document = {} } }; Setup.started(reader)
    drain(); H.eq(#hosts, 0)
    Setup.stopped(reader); Setup.started({ ui = {} }); drain(); H.eq(#hosts, 1)
end)
H.test("automatic dialog failure does not crash startup or block a later manual attempt", function()
    local Setup = reset()
    local Menu = package.loaded["lib/bookshelf_menu_host"]
    local original = Menu.show
    Menu.show = function() error("dialog failed") end
    Setup.started({ ui = {} }); drain()
    Menu.show = original
    H.eq(data.setup.status, "pending")
    assert(windows[#windows].text:find("could not open", 1, true))
    assert(Setup.show())
end)
H.test("Swedish setup labels translate and other locales use English without changing IDs", function()
    local Setup = reset(true)
    G_reader_settings.data.language = "sv_SE"
    local host = Setup.show(); H.eq(host.title, "Ställ in OrbitUI")
    row(host.item_table, "Avbryt (behåll inställningarna)").callback()
    G_reader_settings.data.language = "de_DE"
    host = Setup.show(); H.eq(host.title, "OrbitUI setup")
    H.eq(data.setup.status, "kept")
end)
H.test("optional integration inspection works with no plugins and never loads clients or exposes credentials", function()
    reset(true)
    package.loaded.pluginloader = nil; package.loaded.bookshelf_folder_badge_providers = nil
    local Integrations = require("adapters/orbitui_integrations")
    for _, entry in ipairs(Integrations.entries()) do H.eq(entry.available, false) end
    package.loaded.pluginloader = { loaded_plugins = { bookorbit = { newClient = function() error("network forbidden") end } } }
    package.loaded.bookshelf_folder_badge_providers = { myanimelist = function() error("provider must not run") end }
    G_reader_settings.data.simpleui_hc_api_key = "SECRET-TOKEN"
    for _, entry in ipairs(Integrations.entries()) do H.eq(entry.available, true); assert(not entry.text:find("SECRET")) end
    for _, item in ipairs(Integrations.items()) do item.callback(); assert(not windows[#windows].text:find("SECRET")) end
end)
H.finish()
