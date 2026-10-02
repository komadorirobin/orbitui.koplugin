local M = {}

function M.show()
    local UIManager = require("ui/uimanager")
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{
        text = "OrbitUI development build\n\nSimpleUI and Bookshelf are updated together as one OrbitUI package. Separate component updates are disabled.\n\nThis alpha is installed manually. A common OTA installer is not enabled yet. Restart KOReader after replacing the OrbitUI package.",
    })
end

function M.component(name, root)
    local function noop() end
    local function currentVersion()
        return dofile(root .. "/components/" .. name .. "/_meta.lua").version
    end
    if name == "simpleui" then
        return {
            hasUpdate = function() return false end,
            latestVersion = noop,
            selectedBranch = function() return "Managed by OrbitUI" end,
            setSelectedBranch = M.show,
            installedSource = function() return "orbitui" end,
            installedCommit = function() return "" end,
            scheduleAutoCheck = noop,
            build_update_banner_item = noop,
            checkForUpdates = M.show,
            _doManualCheck = M.show,
            _doManualBranchCheck = M.show,
        }
    end
    assert(name == "bookshelf", "Unknown component")
    return {
        pluginDir = function() return root .. "/components/bookshelf" end,
        getInstalledVersion = currentVersion,
        otherCopies = function() return {} end,
        getAvailableUpdate = noop,
        checkBackground = noop,
        checkBranchBackground = noop,
        gateOnConnection = function() return false end,
        composeBranchUrl = noop,
        offerReleasesPage = M.show,
        check = M.show,
        checkBranch = M.show,
        install = M.show,
        installBranch = M.show,
        installLatestStable = M.show,
    }
end

return M
