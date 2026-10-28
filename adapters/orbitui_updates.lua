local M = { menuLabel = "Uppdatera OrbitUI" }
local context, busy, started, available, check_error
local _ = require("core/orbitui_i18n")

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
            if ok then return { ok = true, value = value } end
            local HTTP = require("core/orbitui_http")
            return { error = HTTP.message(value), http_error = HTTP.errorInfo(value) }
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
    if check_error and check_error.retry_at > os.time() then
        if not quiet then info(require("core/orbitui_http").message(check_error)) end
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
                    local err = result and result.http_error
                    check_error = err and err.kind == "rate_limit" and err or nil
                    if not quiet then info(_("Could not check OrbitUI updates:") .. "\n"
                        .. tostring(result and result.error or _("No result")) .. "\n\n"
                        .. _("Your installed OrbitUI version has not changed.")) end
                    return
                end
                check_error = nil
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

function M.checkExternal(retry)
    if busy or not context then return end
    local OTA = require("core/orbitui_ota")
    local ok, candidate = pcall(OTA.externalCandidate, context, retry)
    if not ok then
        if retry then info("External OrbitUI installation could not be verified. The current version is unchanged.\n\n" .. tostring(candidate)) end
        return
    end
    if not candidate then
        if retry then info("No newer external OrbitUI installation is available, or a restart is pending.") end
        return
    end
    busy = true
    local current = context
    M.runTask(function() return OTA.prepareExternal(current, candidate) end,
        "Verifying external OrbitUI " .. candidate.version .. "...\nTap to cancel safely.", function(result)
            busy = false
            if not result or not result.ok or not result.value then
                info("External OrbitUI installation was not activated. The current version is unchanged.\n\n"
                    .. tostring(result and result.error or "No result"))
                return
            end
            local activated, err = pcall(OTA.activateExternal, current, result.value)
            if not activated then info("Could not activate external OrbitUI update:\n" .. tostring(err)); return end
            restartPrompt("External OrbitUI " .. result.value.version .. " is verified and ready. The previous version is retained for rollback.")
        end)
end

function M.cleanStorage(after)
    if busy or not context or not started then
        if after then after() end
        return
    end
    busy = true
    local current = context
    M.runTask(function() return require("core/orbitui_ota").cleanup(current) end, false, function(result)
        busy = false
        local loaded, logger = pcall(require, "logger")
        if result and result.ok and result.value then
            if loaded and logger.warn and result.value.retained_unverified then
                logger.warn("OrbitUI kept old update versions: active/rollback runtime could not be verified")
            end
            if loaded and logger.info and result.value.bytes > 0 then
                logger.info("OrbitUI unused update cleanup:", result.value.removed, "versions;", result.value.bytes, "bytes")
            end
        elseif loaded and logger.warn then
            logger.warn("OrbitUI update cleanup was interrupted or unavailable; retained versions are unchanged")
        end
        if after then after() end
    end)
end

function M.started()
    if not context or started then return end
    local ok, err = pcall(require("orbitui_bootstrap").healthy, context.root)
    if not ok then info("Could not confirm OrbitUI startup:\n" .. tostring(err)); return end
    started = true
    context._orbitui_storage_ready = true
    if context.notice then info(context.notice) end
    require("ui/uimanager"):scheduleIn(1, function()
        M.cleanStorage(function()
            M.checkExternal(false)
            if G_reader_settings and G_reader_settings:isTrue("orbitui_update_auto") then
                local last = tonumber(G_reader_settings:readSetting("orbitui_update_last_check")) or 0
                if os.time() - last >= 86400 then
                    require("ui/uimanager"):scheduleIn(5, function() M.check(true) end)
                end
            end
        end)
    end)
end

function M.menuItems()
    if not context then return {{ text = M.menuLabel, callback = M.show }} end
    local Boot = require("orbitui_bootstrap")
    local state = Boot.state(context.root)
    return {
        { text = _("Installed:") .. " OrbitUI " .. context.version,
            enabled = false },
        { text_func = function()
                return available and (_("Update available:") .. " " .. available) or _("Check for updates")
            end,
            callback = function() M.check(false) end },
        { text = _("Include preview releases"), checked_func = previewEnabled,
            keep_menu_open = true,
            callback = function() setting("orbitui_update_preview", not previewEnabled()) end },
        { text = _("Check daily when online"),
            checked_func = function() return G_reader_settings:isTrue("orbitui_update_auto") end,
            keep_menu_open = true,
            callback = function() setting("orbitui_update_auto", not G_reader_settings:isTrue("orbitui_update_auto")) end },
        { text = _("Restore previous OrbitUI version"), enabled = state.previous ~= "none",
            callback = function()
                require("ui/uimanager"):show(require("ui/widget/confirmbox"):new{
                    text = _("Restore the previous OrbitUI code? Settings and reading progress will not be reset."),
                    ok_text = _("Restore"),
                    ok_callback = function() require("ui/uimanager"):scheduleIn(0.1, function()
                        if busy then info(_("An OrbitUI update operation is already running.")); return end
                        local ok, err = pcall(Boot.rollback, context.root)
                        if ok then restartPrompt(_("The previous OrbitUI version is selected."))
                        else info(_("Could not restore OrbitUI:") .. "\n" .. tostring(err)) end
                    end) end,
                })
            end },
        { text = _("Retry external installation"), enabled = context.slot ~= "factory" and not state.pending,
            callback = function()
                require("ui/uimanager"):show(require("ui/widget/confirmbox"):new{
                    text = _("Verify a newer OrbitUI ZIP installed by an app store or manually? Settings and reading progress are kept."),
                    ok_text = _("Verify"),
                    ok_callback = function() require("ui/uimanager"):scheduleIn(0.1, function() M.checkExternal(true) end) end,
                })
            end },
    }
end

function M.show()
    if not context then info(_("OrbitUI updates are unavailable until OrbitUI has started.")); return end
    if busy then info(_("An OrbitUI update operation is already running.")); return end
    local UI = require("ui/uimanager")
    local dialog
    local function close() UI:close(dialog) end
    local buttons = {}
    for _, item in ipairs(M.menuItems()) do
        local text = item.text_func and item.text_func() or item.text
        if item.checked_func then text = (item.checked_func() and "[x] " or "[ ] ") .. text end
        buttons[#buttons + 1] = {{ text = text, enabled = item.enabled,
            callback = function()
                close()
                if item.callback then item.callback() end
                if item.keep_menu_open then M.show() end
            end }}
    end
    buttons[#buttons + 1] = {{ text = _("Close"), callback = close }}
    dialog = require("ui/widget/buttondialog"):new{
        title = "OrbitUI " .. context.version,
        buttons = buttons,
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
        menuItems = M.menuItems,
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
