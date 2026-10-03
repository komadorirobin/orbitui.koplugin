local M = { menuLabel = "Uppdatera OrbitUI" }
local context, busy, started, available

function M.configure(value)
    assert(not context or context.root == value.root, "Another OrbitUI installation is already loaded")
    context = value
end

local function info(text)
    require("ui/uimanager"):show(require("ui/widget/infomessage"):new{ text = text })
end

local function previewEnabled()
    local value = G_reader_settings and G_reader_settings:readSetting("orbitui_update_preview")
    if value ~= nil then return value == true end
    return context and context.version:find("-", 1, true) ~= nil
end

local function setting(key, value)
    G_reader_settings:saveSetting(key, value)
    G_reader_settings:flush()
end

local function restartPrompt(text)
    local UI = require("ui/uimanager")
    UI:show(require("ui/widget/confirmbox"):new{
        text = text .. "\n\nRestart KOReader to load the complete version. The running code is unchanged until restart.",
        ok_text = "Restart", cancel_text = "Later",
        ok_callback = function() UI:scheduleIn(0.1, function() UI:restartKOReader() end) end,
    })
end

function M.runTask(operation, label, callback)
    local Trapper, UI = require("ui/trapper"), require("ui/uimanager")
    local function run()
        local completed, result = Trapper:dismissableRunInSubprocess(function()
            local ok, value = pcall(operation)
            return ok and { ok = true, value = value } or { error = tostring(value) }
        end, label, false)
        UI:scheduleIn(0.1, function()
            callback(completed and result or { error = "Operation cancelled or interrupted" })
        end)
    end
    if Trapper:isWrapped() then UI:scheduleIn(0.1, function() Trapper:wrap(run) end)
    else Trapper:wrap(run) end
end

function M.install(release)
    if busy then return end
    busy = true
    local current = context
    M.runTask(function() return require("core/orbitui_ota").prepare(current, release) end,
        "Downloading and verifying OrbitUI " .. release.version .. "...\nTap to cancel safely.", function(result)
            busy = false
            if not result or not result.ok or not result.value then
                info("OrbitUI was not updated. The current version is unchanged.\n\n" .. tostring(result and result.error or "No result"))
                return
            end
            local ok, err = pcall(require("orbitui_bootstrap").activate, current.root, result.value.slot)
            if not ok then info("Could not activate OrbitUI:\n" .. tostring(err)); return end
            available = nil
            restartPrompt("OrbitUI " .. result.value.version .. " is verified and ready.")
        end)
end

function M.check(quiet)
    if busy or not context then return end
    local Boot = require("orbitui_bootstrap")
    local state = Boot.state(context.root)
    if state.pending or state.current ~= context.slot then
        if not quiet then restartPrompt("An OrbitUI update or rollback is pending.") end
        return
    end
    local Network = require("ui/network/manager")
    local function check()
        if busy then return end
        busy = true
        local preview = previewEnabled()
        local label = "Checking OrbitUI releases..."
        if quiet then label = false end
        M.runTask(function() return require("core/orbitui_ota").check(preview) end,
            label, function(result)
                busy = false
                if not result or not result.ok then
                    if not quiet then info("Could not check OrbitUI updates:\n" .. tostring(result and result.error or "No result")) end
                    return
                end
                setting("orbitui_update_last_check", os.time())
                local release = result.value
                if not release then
                    if not quiet then info("No releases are available in this channel. Enable preview releases to receive alpha/beta builds.") end
                    return
                end
                if not require("core/orbitui_ota").newer(release.version, context.version) then
                    if not quiet then info("OrbitUI is up to date (" .. context.version .. ").") end
                    return
                end
                available = release.version
                if quiet then return end
                local UI = require("ui/uimanager")
                UI:show(require("ui/widget/confirmbox"):new{
                    text = "OrbitUI " .. release.version .. " is available.\n\nUpdate SimpleUI and Bookshelf together? Your settings and reading data are kept."
                        .. (release.version:find("-", 1, true) and "\n\nThis is an experimental preview release." or ""),
                    ok_text = "Download update",
                    ok_callback = function() UI:scheduleIn(0.1, function() M.install(release) end) end,
                })
            end)
    end
    if quiet then
        if Network:isOnline() then check() end
    else Network:runWhenOnline(check) end
end

function M.started()
    if not context or started then return end
    local ok, err = pcall(require("orbitui_bootstrap").healthy, context.root)
    if not ok then info("Could not confirm OrbitUI startup:\n" .. tostring(err)); return end
    started = true
    if context.notice then info(context.notice) end
    if G_reader_settings and G_reader_settings:isTrue("orbitui_update_auto") then
        local last = tonumber(G_reader_settings:readSetting("orbitui_update_last_check")) or 0
        if os.time() - last >= 86400 then
            require("ui/uimanager"):scheduleIn(5, function() M.check(true) end)
        end
    end
end

function M.show()
    if not context then info("OrbitUI updates are unavailable until OrbitUI has started."); return end
    if busy then info("An OrbitUI update operation is already running."); return end
    local UI = require("ui/uimanager")
    local Boot = require("orbitui_bootstrap")
    local state = Boot.state(context.root)
    local dialog
    local function close() UI:close(dialog) end
    dialog = require("ui/widget/buttondialog"):new{
        title = "OrbitUI " .. context.version,
        buttons = {
            {{ text = available and ("Update available: " .. available) or "Check for updates",
                callback = function() close(); M.check(false) end }},
            {{ text = (previewEnabled() and "[x] " or "[ ] ") .. "Include preview releases",
                callback = function() setting("orbitui_update_preview", not previewEnabled()); close(); M.show() end }},
            {{ text = (G_reader_settings:isTrue("orbitui_update_auto") and "[x] " or "[ ] ") .. "Check daily when online",
                callback = function() setting("orbitui_update_auto", not G_reader_settings:isTrue("orbitui_update_auto")); close(); M.show() end }},
            {{ text = "Restore previous OrbitUI version", enabled = state.previous ~= "none",
                callback = function()
                    close()
                    UI:show(require("ui/widget/confirmbox"):new{
                        text = "Restore the previous OrbitUI code? Settings and reading progress will not be reset.",
                        ok_text = "Restore",
                        ok_callback = function() UI:scheduleIn(0.1, function()
                            local ok, err = pcall(Boot.rollback, context.root)
                            if ok then restartPrompt("The previous OrbitUI version is selected.")
                            else info("Could not restore OrbitUI:\n" .. tostring(err)) end
                        end) end,
                    })
                end }},
            {{ text = "Close", callback = close }},
        },
    }
    UI:show(dialog)
end

function M.component(name, root)
    local function noop() end
    local function currentVersion()
        return dofile(root .. "/components/" .. name .. "/_meta.lua").version
    end
    if name == "simpleui" then
        return {
            menuLabel = M.menuLabel,
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
        menuLabel = M.menuLabel,
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
