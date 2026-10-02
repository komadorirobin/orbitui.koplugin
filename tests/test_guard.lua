package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Guard = require("core/orbitui_guard")

H.test("enabled predecessors block initialization", function()
    local out = Guard.conflicts({ { name = "bookshelf" }, { name = "simpleui" } })
    H.eq(table.concat(out, ","), "bookshelf,simpleui")
end)
H.test("disabled predecessors do not block", function()
    H.eq(#Guard.conflicts({ { name = "bookshelf", disabled = true }, { name = "simpleui", disabled = true } }), 0)
end)
H.test("changing settings without restarting still blocks", function()
    H.eq(#Guard.conflicts({ { name = "simpleui", disabled = true } }, { { name = "simpleui" } }), 1)
end)
H.test("renamed copies and already-instantiated predecessors block", function()
    local out = Guard.conflicts({ { name = "bookshelf-backup" } }, nil, { simpleui = {} })
    H.eq(#out, 2)
    H.eq(#Guard.conflicts(nil, { { name = "renamed", onSimpleUIGoHomescreen = function() end } }), 1)
end)
H.test("owned aliases and unrelated plugins do not block", function()
    H.eq(#Guard.conflicts({ { name = "orbitui" }, { name = "statistics" } }, nil,
        { bookshelf = { _orbitui_owned = true } }), 0)
end)
H.test("discovery checks future plugins before their main.lua is loaded", function()
    package.loaded.pluginloader = {
        _discover = function() return { { name = "simpleui" } } end,
        enabled_plugins = { { name = "coverbrowser" } },
    }
    local ok, reason = Guard.check()
    H.eq(ok, nil)
    assert(reason:find("simpleui", 1, true))
end)
H.test("discovery failures are not silently treated as safe", function()
    package.loaded.pluginloader = { _discover = function() error("storage unavailable") end }
    H.eq(pcall(Guard.check), false)
end)
H.finish()
