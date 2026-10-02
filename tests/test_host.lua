package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Host = require("core/orbitui_host")
local Widget = H.widget()
local function fixture(reader)
    local calls = {}
    local classes = {}
    for _, name in ipairs({ "bookshelf", "simpleui" }) do
        local id = name
        classes[name] = Widget:extend{
            init = function(self)
                assert(self.ui.bookshelf and self.ui.simpleui)
                calls[#calls + 1] = "init:" .. id
            end,
            onCloseDocument = function(self, value)
                calls[#calls + 1] = id .. ":" .. value
            end,
        }
    end
    local owner = { ui = reader and { document = {} } or {} }
    local loader = { loaded_plugins = {} }
    Host.attach(owner, classes, loader, "/plugins/orbitui.koplugin")
    return owner, loader, calls
end
H.test("components initialize once in baseline order with early aliases", function()
    local owner, loader, calls = fixture()
    H.eq(table.concat(calls, ","), "init:bookshelf,init:simpleui")
    H.eq(#owner, 2)
    H.eq(owner.ui.bookshelf, owner[1])
    H.eq(loader.loaded_plugins.simpleui, owner[2])
    H.eq(owner[1].name, "filemanagerbookshelf")
    H.eq(owner[2].path, "/plugins/orbitui.koplugin/components/simpleui")
end)
H.test("reader aliases and names match KOReader's conventions", function()
    local owner = fixture(true)
    H.eq(owner[1].name, "readerbookshelf")
    H.eq(owner[2].ui, owner.ui)
end)
H.test("close-document events reach each component exactly once", function()
    local owner, _, calls = fixture()
    H.eq(Host.propagate(owner, { handler = "onCloseDocument", args = { "done" } }, error), false)
    H.eq(table.concat(calls, ","), "init:bookshelf,init:simpleui,bookshelf:done,simpleui:done")
end)
H.test("consumed gestures stop propagating", function()
    local owner, _, calls = fixture()
    owner[1].onGesture = function() calls[#calls + 1] = "consumed"; return true end
    owner[2].onGesture = function() error("must not run") end
    H.eq(Host.propagate(owner, { handler = "onGesture" }, error), true)
    H.eq(calls[3], "consumed")
end)
H.test("event arguments retain nil positions and the original payload", function()
    local owner = fixture()
    local payload, seen = {}, 0
    for _, instance in ipairs(owner) do
        instance.onProgress = function(_, ...)
            H.eq(select("#", ...), 4)
            local first, second, third, fourth = ...
            H.eq(first, nil)
            H.eq(second, payload)
            H.eq(third, 0)
            H.eq(fourth, nil)
            seen = seen + 1
        end
    end
    Host.propagate(owner, { handler = "onProgress", args = { nil, payload, 0, n = 4 } }, error)
    H.eq(seen, 2)
end)
H.test("one failing handler does not prevent the other from running", function()
    local owner, _, calls = fixture()
    local failures = 0
    owner[1].onCloseDocument = function() error("failure") end
    Host.propagate(owner, { handler = "onCloseDocument", args = { "done" } }, function() failures = failures + 1 end)
    H.eq(failures, 1)
    H.eq(calls[3], "simpleui:done")
end)
H.test("teardown never erases a newer host's loader aliases", function()
    local old, loader = fixture()
    local newer = { _orbitui_owned = true }
    loader.loaded_plugins.bookshelf = newer
    Host.detach(old, loader)
    H.eq(old.ui.bookshelf, nil)
    H.eq(loader.loaded_plugins.bookshelf, newer)
    H.eq(loader.loaded_plugins.simpleui, nil)
end)
H.test("existing host instances are not overwritten", function()
    local owner = { ui = { simpleui = {} } }
    H.eq(pcall(Host.attach, owner, { bookshelf = Widget, simpleui = Widget }, {}, "/root"), false)
    H.eq(owner.ui.bookshelf, nil)
    H.eq(#owner, 0)
end)
H.test("aborting a partial initialization drops aliases and event recipients", function()
    local owner, loader = fixture()
    local torn_down = 0
    owner[2].onTeardown = function() torn_down = torn_down + 1 end
    Host.abort(owner, loader)
    H.eq(torn_down, 1)
    H.eq(#owner, 0)
    H.eq(owner.ui.bookshelf, nil)
    H.eq(loader.loaded_plugins.simpleui, nil)
end)
H.finish()
