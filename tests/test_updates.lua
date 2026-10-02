package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Updates = require("adapters/orbitui_updates")
local messages = {}
package.loaded["ui/uimanager"] = { show = function(_, msg) messages[#messages + 1] = msg.text end }
package.loaded["ui/widget/infomessage"] = { new = function(_, msg) return msg end }
H.test("Bookshelf installation entry points cannot update a component", function()
    local updater = Updates.component("bookshelf", "/dummy")
    for _, method in ipairs({ "check", "checkBranch", "install", "installBranch", "installLatestStable" }) do
        updater[method]("https://unwanted.invalid/old-plugin.zip", "old", "new")
    end
    H.eq(#messages, 5)
    assert(messages[1]:find("manually", 1, true))
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
H.finish()
