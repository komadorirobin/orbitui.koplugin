package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Updates = require("adapters/orbitui_updates")
local messages = {}
package.loaded["ui/uimanager"] = { show = function(_, msg) messages[#messages + 1] = msg.text end }
package.loaded["ui/widget/infomessage"] = { new = function(_, msg) return msg end }
H.test("both components use the shared OrbitUI update label", function()
    H.eq(Updates.menuLabel, "Uppdatera OrbitUI")
    for _, name in ipairs({ "bookshelf", "simpleui" }) do
        H.eq(Updates.component(name, "/dummy").menuLabel, Updates.menuLabel)
    end
end)
H.test("Bookshelf installation entry points cannot update a component", function()
    local updater = Updates.component("bookshelf", "/dummy")
    for _, method in ipairs({ "check", "checkBranch", "install", "installBranch", "installLatestStable" }) do
        updater[method]("https://unwanted.invalid/old-plugin.zip", "old", "new")
    end
    H.eq(#messages, 5)
    assert(messages[1]:find("OrbitUI", 1, true))
end)
H.test("SimpleUI channel changes and manual checks cannot install old packages", function()
    local updater = Updates.component("simpleui", "/dummy")
    updater.setSelectedBranch("beta")
    updater.checkForUpdates()
    updater._doManualCheck()
    updater._doManualBranchCheck()
    H.eq(#messages, 9)
    H.eq(updater.selectedBranch(), "Managed by OrbitUI")
end)
H.test("automatic component update paths do nothing", function()
    local before = #messages
    local b = Updates.component("bookshelf", "/dummy")
    local s = Updates.component("simpleui", "/dummy")
    b.checkBackground(function() error("unexpected callback") end)
    b.checkBranchBackground()
    s.scheduleAutoCheck()
    H.eq(s.build_update_banner_item(), nil)
    H.eq(#messages, before)
end)
H.test("Trapper uses its real return-value API and defers UI callbacks", function()
    local queue, delivered = {}, 0
    package.loaded["ui/uimanager"].scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end
    package.loaded["ui/trapper"] = {
        isWrapped = function() return false end,
        wrap = function(_, fn) fn() end,
        dismissableRunInSubprocess = function(_, fn, label, simple)
            H.eq(simple, false)
            H.eq(label, "Checking")
            return true, fn()
        end,
    }
    Updates.runTask(function() return { value = 4 } end, "Checking", function(result)
        assert(result.ok)
        H.eq(result.value.value, 4)
        delivered = delivered + 1
    end)
    H.eq(delivered, 0)
    H.eq(#queue, 1)
    queue[1]()
    H.eq(delivered, 1)
end)
H.test("cancellation never invokes installation activation", function()
    local queue, activated = {}, false
    local Boot = require("orbitui_bootstrap")
    local previous = Boot.activate
    Boot.activate = function() activated = true end
    package.loaded["ui/uimanager"].scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end
    package.loaded["ui/trapper"].dismissableRunInSubprocess = function() return false end
    Updates.configure{ root = "/test-orbitui", slot = "factory", version = "0.1.0-alpha.2" }
    Updates.install{ version = "0.1.0-alpha.3" }
    queue[1]()
    H.eq(activated, false)
    Boot.activate = previous
end)
H.finish()
