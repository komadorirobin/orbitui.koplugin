package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = H.root()
local Widget = H.widget()
local messages, deferred, calls, classes, discovered, backup_failure
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
package.loaded["core/orbitui_runtime"] = {
    install = function() calls[#calls + 1] = "resolver" end,
    classes = function() return classes end,
}
local function fixture()
    messages, deferred, calls, discovered = {}, {}, {}, {}
    loader.loaded_plugins = {}
    backup_failure = false
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
H.test("discovery prepares backup and resolver before component initialization", function()
    fixture()
    local class = dofile(root .. "/main.lua")
    H.eq(table.concat(calls, ","), "backup,resolver")
    local fm = instantiate(class)
    H.eq(table.concat(calls, ","), "backup,resolver,init:bookshelf,init:simpleui")
    H.eq(fm._orbitui_error, nil)
    fm:handleEvent{ handler = "onCloseDocument" }
    H.eq(calls[5], "close:bookshelf")
    H.eq(calls[6], "close:simpleui")
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
H.test("OrbitUI menu uses the shared update label and updater", function()
    fixture()
    local fm = instantiate(dofile(root .. "/main.lua"))
    local items = {}
    fm:addToMainMenu(items)
    local update_item = items.orbitui.sub_item_table[#items.orbitui.sub_item_table]
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
end)
H.finish()
