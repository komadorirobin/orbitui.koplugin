package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = H.root()
local Widget = H.widget()
local messages, deferred, calls, classes, discovered, backup_failure, setup_failure
local loader = { loaded_plugins = {}, enabled_plugins = {} }
loader._discover = function() return discovered end
package.loaded.pluginloader = loader
package.loaded["ui/widget/container/widgetcontainer"] = Widget
package.loaded["ui/widget/infomessage"] = { new = function(_, o) return o end }
package.loaded["ui/uimanager"] = {
    nextTick = function(_, fn) deferred[#deferred + 1] = fn end,
    show = function(_, item) messages[#messages + 1] = item.text end,
}
package.loaded.logger = { err = function() end }
package.loaded["core/orbitui_backup"] = { ensure = function()
    if backup_failure then error("cannot create backup") end
    calls[#calls + 1] = "backup"
end }
package.loaded["adapters/orbitui_setup"] = {
    prepare = function()
        if setup_failure then error("unsupported setup state") end
        calls[#calls + 1] = "setup:prepare"
    end,
    started = function() calls[#calls + 1] = "setup:started" end,
    stopped = function() calls[#calls + 1] = "setup:stopped" end,
}
package.loaded["core/orbitui_runtime"] = {
    install = function() calls[#calls + 1] = "resolver" end,
    classes = function() return classes end,
}
package.loaded["infra/sui_menu_hooks"] = { ORDER = { MENU_HIDE = 5 }, register = function() end }
local function fixture()
    messages, deferred, calls, discovered = {}, {}, {}, {}
    loader.loaded_plugins = {}
    backup_failure = false
    setup_failure = false
    classes = {}
    for _, name in ipairs({ "bookshelf", "simpleui" }) do
        local id = name
        classes[name] = Widget:extend{
            init = function() calls[#calls + 1] = "init:" .. id end,
            onCloseDocument = function() calls[#calls + 1] = "close:" .. id end,
        }
    end
end
local function instantiate(class, document)
    return class:new{ ui = { document = document, menu = { registerToMainMenu = function() end } } }
end
H.test("discovery snapshots settings then detects setup before loading components; guide starts only after attach", function()
    fixture()
    local class = dofile(root .. "/main.lua")
    H.eq(table.concat(calls, ","), "backup,setup:prepare,resolver")
    local fm = instantiate(class)
    H.eq(table.concat(calls, ","), "backup,setup:prepare,resolver,init:bookshelf,init:simpleui,setup:started")
    H.eq(fm._orbitui_error, nil)
    fm:handleEvent{ handler = "onCloseDocument" }
    H.eq(calls[7], "close:bookshelf")
    H.eq(calls[8], "close:simpleui")
end)
H.test("FileManager and reader each receive one component pair", function()
    fixture()
    local class = dofile(root .. "/main.lua")
    local fm, reader = instantiate(class), instantiate(class, {})
    assert(fm.ui.bookshelf ~= reader.ui.bookshelf)
    H.eq(reader.ui.bookshelf.name, "readerbookshelf")
    fm:handleEvent{ handler = "onTeardown" }
    H.eq(loader.loaded_plugins.bookshelf, reader.ui.bookshelf)
end)
H.test("one OrbitUI menu routes to settings; startup failures retain update access", function()
    fixture()
    local fm = instantiate(dofile(root .. "/main.lua"))
    local items = {}
    fm:addToMainMenu(items)
    H.eq(items.orbitui, nil)
    H.eq(items.orbitui_settings.text, "OrbitUI")
    H.eq(type(items.orbitui_settings.callback), "function")
    fm._orbitui_error = "test failure"
    fm:addToMainMenu(items)
    local update_item = items.orbitui_settings.sub_item_table[2]
    H.eq(update_item.text, "Uppdatera OrbitUI")
    H.eq(update_item.callback, require("adapters/orbitui_updates").show)
end)
H.test("conflicting installs neither back up nor load components", function()
    fixture()
    discovered = { { name = "simpleui" } }
    local class = dofile(root .. "/main.lua")
    local fm = instantiate(class)
    H.eq(#calls, 0)
    H.eq(#fm, 0)
    H.eq(fm.ui.simpleui, nil)
    deferred[1]()
    assert(messages[1]:find("simpleui", 1, true))
end)
H.test("failed backup prevents loading and altering legacy settings", function()
    fixture()
    backup_failure = true
    local fm = instantiate(dofile(root .. "/main.lua"))
    H.eq(#calls, 0)
    H.eq(#fm, 0)
    assert(fm._orbitui_error:find("backup", 1, true))
end)
H.test("partial initialization failure removes aliases and reports a restart", function()
    fixture()
    classes.simpleui.init = function() error("component error") end
    local fm = instantiate(dofile(root .. "/main.lua"))
    H.eq(#fm, 0)
    H.eq(fm.ui.bookshelf, nil)
    H.eq(loader.loaded_plugins.simpleui, nil)
    deferred[1]()
    assert(messages[1]:find("restart", 1, true))
    assert(not table.concat(calls, ","):find("setup:started", 1, true))
end)
H.test("unknown setup state blocks initialization before component defaults or a guide", function()
    fixture(); setup_failure = true
    local fm = instantiate(dofile(root .. "/main.lua"))
    H.eq(table.concat(calls, ","), "backup")
    H.eq(#fm, 0)
    assert(fm._orbitui_error:find("unsupported setup", 1, true))
end)
H.test("reader panel/reference menus and actions are reader-only and stay lazy on ready", function()
    fixture()
    local actions = {}
    package.loaded.dispatcher = { registerAction = function(_, id, action) actions[id] = action end }
    local class = dofile(root .. "/main.lua")
    local fm = instantiate(class)
    local items = {}; fm:addToMainMenu(items); H.eq(items.orbitui_reader_pins, nil)
    H.eq(items.orbitui_reader_panel, nil)
    local reader = instantiate(class, { file = "/books/test.epub" })
    reader.ui.doc_settings = { readSetting = function() error("no pin reads on ReaderReady") end }
    local tap, swipe, native = function() end, function() end, function() end
    reader.ui.config = { ui = reader.ui, onTapShowConfigMenu = tap, onSwipeShowConfigMenu = swipe, onShowConfigMenu = native }
    reader:onReaderReady()
    assert(reader.ui.config.onTapShowConfigMenu ~= tap and reader.ui.config.onSwipeShowConfigMenu ~= swipe)
    H.eq(reader.ui.config.onShowConfigMenu, native)
    assert(actions.orbitui_reader_pins.reader and actions.orbitui_pin_page.reader)
    assert(actions.orbitui_reader_panel.reader)
    H.eq(actions.orbitui_reader_panel.event, "OrbitUIReaderPanel")
    H.eq(require("adapters/orbitui_book_panel")._reader_tools, nil)
    items = {}; reader:addToMainMenu(items)
    H.eq(items.orbitui_reader_panel.sorting_hint, "tools")
    assert(type(items.orbitui_reader_panel.callback) == "function")
    H.eq(#items.orbitui_reader_pins.sub_item_table, 4)
    H.eq(items.orbitui_reader_pins.sub_item_table[4].enabled, false)
    reader._orbitui_error = "failed"
    items = {}; reader:addToMainMenu(items); H.eq(items.orbitui_reader_pins, nil)
    H.eq(items.orbitui_reader_panel, nil)
    reader:onTeardown(); H.eq(reader.ui.config.onTapShowConfigMenu, tap); H.eq(reader.ui.config.onSwipeShowConfigMenu, swipe)
end)
H.finish()
