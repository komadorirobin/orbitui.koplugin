local M = { menuLabel = "Uppdatera OrbitUI" }
local context, busy, started, available, check_error, active_panel, active_job
local _ = require("core/orbitui_i18n")

-- Independent implementation of the approved BookOrbit-inspired design. Keep
-- this lazy in an existing runtime path: old API-1 installers allow 2,000 files.
-- No BookOrbit widgets, code, assets or installed plugin are required.
function M.openPanel(options)
    local UI, Device = require("ui/uimanager"), require("device")
    local Screen, BB = Device.screen, require("ffi/blitbuffer")
    local Geom, Font = require("ui/geometry"), require("ui/font")
    local Frame = require("ui/widget/container/framecontainer")
    local Text = require("ui/widget/textboxwidget")
    local V, H = require("ui/widget/verticalgroup"), require("ui/widget/horizontalgroup")
    local VS, HS = require("ui/widget/verticalspan"), require("ui/widget/horizontalspan")
    local Button = require("ui/widget/button")
    local px = function(n) return math.max(1, Screen:scaleBySize(n)) end
    local Panel = require("ui/widget/focusmanager"):extend{ name = "orbitui_update_panel", modal = true }
    function Panel:active() return self.phase == "downloading" or self.phase == "verifying" or self.phase == "cancelling" end
    function Panel:close()
        if self.closed then return end
        if self:active() then self:cancel(); return end
        UI:close(self)
    end
    function Panel:cancel()
        if self.cancel_requested or not self:active() then return end
        self.cancel_requested = true
        if self.on_cancel then self.on_cancel() end
        self:setState("cancelling")
        if self.dismiss_callback then self.dismiss_callback() end
    end
    function Panel:onCloseWidget()
        self.closed = true
        if self:active() then self:cancel() end
        if self.backdrop then self.backdrop:free(); self.backdrop = nil end
        if self.on_close then self.on_close() end
        UI:setDirty("all", "ui")
    end
    function Panel:onSuspend() if self:active() then self:cancel() end end
    function Panel:onClose() self:close(); return true end
    function Panel:onOutside(_, gesture)
        if not self:active() and self.panel_rect and not self.panel_rect:contains(gesture.pos) then self:close() end
        return true -- Never forward modal taps to a book or underlying menu.
    end
    function Panel:onSetRotationMode() return self:onScreenResize() end
    function Panel:onScreenResize()
        if self.backdrop then self.backdrop:free(); self.backdrop = nil end
        self.covers_fullscreen = false
        self:rebuild(); UI:setDirty("all", "ui")
    end
    function Panel:setState(phase, fields)
        if self.closed then return end
        self.phase = phase
        for key, value in pairs(fields or {}) do self[key] = value end
        self:rebuild(); UI:setDirty(self, "ui")
    end
    function Panel:progressed(value)
        if self.closed or self.cancel_requested or not self:active() then return end
        if type(value) ~= "table" or value.phase ~= "downloading" and value.phase ~= "verifying" then return end
        local received, total = tonumber(value.received), tonumber(value.total)
        if not received or not total or received < 0 or total < 0 or received ~= received or total ~= total
                or received > 128 * 1048576 or total > 128 * 1048576 then return end
        local bucket = total > 0 and math.floor(math.min(1, received / total) * 20) or math.floor(received / 262144)
        local key = value.phase .. ":" .. bucket
        if key == self.progress_key or self.phase == "verifying" and value.phase ~= "verifying" then return end
        self.progress_key = key
        self:setState(value.phase, { received = received, total = total })
    end
    function Panel:rebuild(reserve_scrollbar)
        if self[1] then self[1]:free(); self[1] = nil end
        self.layout, self.buttons = {}, {}
        self.revision = (self.revision or 0) + 1
        local revision = self.revision
        local sw, sh = Screen:getWidth(), Screen:getHeight()
        local short = sh < px(420)
        local margin = math.min(px(16), math.floor(math.min(sw, sh) / 12))
        local width = math.max(1, math.min(px(460), sw - 2 * margin))
        local pad = math.min(px(short and 14 or 24), math.floor(width / 12))
        local border, inner = px(1), width - 2 * (pad + px(1))
        local text_width = inner
        local function space(height) return VS:new{ width = height } end
        local function text(copy, size, bold, color, w, max_height, background)
            local opts = { text = copy, width = w or text_width, face = Font:getFace("cfont", size),
                bold = bold, fgcolor = color or BB.COLOR_BLACK, bgcolor = background or BB.COLOR_WHITE,
                height_overflow_show_ellipsis = true }
            local widget = Text:new(opts)
            if max_height and widget:getSize().h > max_height then
                widget:free()
                opts.height, opts.height_adjust = max_height, false
                widget = Text:new(opts)
            end
            return widget
        end
        local function action(copy, callback, w, primary, no_border)
            local button = Button:new{ text = copy, width = w, height = px(26), padding_h = px(8), padding_v = px(9),
                margin = 0, bordersize = no_border and 0 or border, radius = px(24),
                background = primary and BB.COLOR_BLACK or nil,
                text_font_size = short and 14 or 16, callback = function()
                    if not self.closed and self.revision == revision then callback() end
                end }
            -- Native preselect inverts a rectangle, including the rounded
            -- corners. Paint a genuine dark pill instead; keep native input.
            if primary and button.label_widget then
                button.label_widget.fgcolor, button.label_widget.bgcolor = BB.COLOR_WHITE, BB.COLOR_BLACK
            end
            return button
        end
        local title, subtitle
        if self.phase == "available" then
            title = _("OrbitUI can be updated")
            subtitle = self.release.version:find("-", 1, true) and _("A new preview release is ready.") or _("A new stable release is ready.")
        elseif self.phase == "downloading" then title, subtitle = _("Updating OrbitUI"), string.format(_("Downloading %s"), self.release.version)
        elseif self.phase == "verifying" then title, subtitle = _("Checking the update"), _("The download is complete.")
        elseif self.phase == "cancelling" then title, subtitle = _("Cancelling the update…"), _("Your installed version is unchanged.")
        elseif self.phase == "installed" then title, subtitle = _("Ready to restart"), self.restart_text or string.format(_("OrbitUI %s is verified and ready."), self.release.version)
        else title, subtitle = _("The update did not finish"), _("Your installed version is unchanged.") end
        local header = H:new{ align = "top" }
        local close_width = not self:active() and px(36) or 0
        header[1] = text(title, short and 18 or 20, true, nil, inner - close_width, math.min(px(short and 38 or 58), math.floor(sh / 5)))
        if close_width > 0 then
            local close = action("×", function() self:close() end, close_width, false, true)
            header[#header + 1] = close; self.layout[#self.layout + 1] = { close }
        end
        local top = V:new{ align = "left", header, space(px(short and 4 or 6)),
            text(subtitle, 14, false, BB.COLOR_DARK_GRAY, nil, px(short and 28 or 46)), space(px(short and 10 or 18)) }
        local body = V:new{ align = "left" }
        local body_width = inner - (reserve_scrollbar and px(18) or 0)
        text_width = body_width
        local function append(widget) body[#body + 1] = widget end
        local function note(copy) append(text(copy, 14, false, BB.COLOR_DARK_GRAY)) end
        local buttons = {}
        local function addButton(copy, callback, primary) buttons[#buttons + 1] = { text = copy, callback = callback, primary = primary } end
        if self.phase == "available" then
            local rows = V:new{ align = "left" }
            local inset, roww = px(14), body_width - 2 * (px(14) + border)
            for index, row in ipairs{ { _("On your device"), self.current }, { _("New version"), self.release.version } } do
                local label_width = math.floor(roww * .48)
                local background = index == 2 and BB.COLOR_GRAY_E or BB.COLOR_WHITE
                local line = H:new{ align = "center", text(row[1], 14, false, BB.COLOR_DARK_GRAY, label_width, nil, background),
                    text(row[2], 14, index == 2, nil, roww - label_width, nil, background) }
                rows[#rows + 1] = Frame:new{ padding = inset, bordersize = 0, background = background,
                    radius = index == 2 and px(9) or nil, line }
            end
            append(Frame:new{ padding = 0, bordersize = border, color = BB.COLOR_LIGHT_GRAY, radius = px(11), rows })
            if self.release.notes then
                append(space(px(10)))
                local news = action(_("What's new") .. (self.news_open and "  −" or "  +"), function()
                    self.news_open = not self.news_open; self:setState(self.phase)
                end, body_width, false, true)
                append(news); self.layout[#self.layout + 1] = { news }
                if self.news_open then append(text(self.release.notes, 14, false, BB.COLOR_DARK_GRAY)); append(space(px(8))) end
            end
            append(space(px(15)))
            note(self.cancel_notice or _("Your settings and reading data are kept. The previous version is retained for rollback."))
            addButton(_("Later"), function() self:close() end)
            addButton(_("Update now"), function() if self.on_install then self.on_install(self) end end, true)
        elseif self.phase == "downloading" or self.phase == "verifying" then
            local pct = self.total and self.total > 0 and math.min(100, math.floor((self.received or 0) * 100 / self.total))
            if self.phase == "downloading" then
                note(pct and string.format(_("Downloading the update · %d%%"), pct) or _("Starting download…"))
            else note(_("Verifying package files")) end
            append(space(px(10)))
            if pct or self.phase == "verifying" then
                append(require("ui/widget/progresswidget"):new{ width = body_width, height = px(8),
                    percentage = (pct or 100) / 100, margin_h = 0, margin_v = 0, bordersize = 0, radius = px(4) })
            end
            append(space(px(10)))
            if self.phase == "downloading" and self.received and self.total and self.total > 0 then
                note(string.format(_("%.1f of %.1f MB"), self.received / 1048576, (self.total or 0) / 1048576))
            elseif self.phase == "downloading" and (self.received or 0) > 0 then
                note(string.format(_("%d KB downloaded"), math.floor(self.received / 1024)))
            elseif self.phase == "verifying" then note(_("Checking checksums and package contents.")) end
            append(space(px(18)))
            note(_("The running version will not change until you restart KOReader."))
            addButton(_("Cancel update"), function() self:cancel() end)
        elseif self.phase == "installed" then
            note(_("Restart KOReader to use the new version. You can also do this later."))
            addButton(_("Later"), function() self:close() end)
            addButton(_("Restart now"), function()
                self:close(); UI:scheduleIn(.1, function() UI:restartKOReader() end)
            end, true)
        elseif self.phase == "failed" then
            note(self.error_text or _("Could not prepare the update. Please try again."))
            append(space(px(12))); note(_("No settings or reading data have been changed."))
            addButton(_("Close"), function() self:close() end)
            if self.release then addButton(_("Try again"), function() if self.on_install then self.on_install(self) end end, true) end
        else note(_("Please wait while the background task stops.")) end
        local footer = V:new{ align = "left" }
        if #buttons > 0 then
            footer[#footer + 1] = space(px(short and 12 or 22))
            local stack = inner < px(270) and not short
            local row, focus = H:new{ align = "center" }, {}
            for index, spec in ipairs(buttons) do
                local w = stack and inner or math.floor((inner - (#buttons - 1) * px(10)) / #buttons)
                local b = action(spec.text, spec.callback, w, spec.primary)
                self.buttons[spec.text] = b
                if stack then
                    footer[#footer + 1] = b; if index < #buttons then footer[#footer + 1] = space(px(8)) end
                    self.layout[#self.layout + 1] = { b }
                else
                    if index > 1 then row[#row + 1] = HS:new{ width = px(10) } end
                    row[#row + 1], focus[#focus + 1] = b, b
                end
            end
            if not stack then footer[#footer + 1] = row; self.layout[#self.layout + 1] = focus end
        end
        local max_body = math.max(px(30), sh - 2 * (margin + pad + border) - top:getSize().h - footer:getSize().h)
        local content = body
        self.cropping_widget = nil
        if body:getSize().h > max_body then
            if not reserve_scrollbar then
                top:free(); body:free(); footer:free()
                return self:rebuild(true) -- Reserve the native bar, not a second horizontal scrollbar.
            end
            content = require("ui/widget/container/scrollablecontainer"):new{
                dimen = Geom:new{ w = inner, h = max_body }, show_parent = self, body }
            self.cropping_widget = content
        end
        self[1] = Frame:new{ padding = pad, bordersize = border, radius = px(16), background = BB.COLOR_WHITE,
            V:new{ align = "left", top, content, footer } }
        local size = self[1]:getSize()
        self.panel_rect = Geom:new{ x = math.floor((sw - size.w) / 2), y = math.max(margin, math.floor((sh - size.h) / 2)), w = size.w, h = size.h }
        self.dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh }
        self.ges_events.Outside = { require("ui/gesturerange"):new{ ges = "tap", range = self.dimen } }
        self.key_events.Close = {{ "Back" }, { "Esc" }}
        self.selected = { x = 1, y = 1 }
    end
    function Panel:paintTo(bb, x, y)
        if not self.backdrop and self.dimen.w * self.dimen.h * 4 <= 16 * 1024 * 1024 then
            self.backdrop = bb:copy()
            self.backdrop:lightenRect(0, 0, self.dimen.w, self.dimen.h)
        end
        if self.backdrop then bb:blitFrom(self.backdrop, 0, 0, 0, 0, self.dimen.w, self.dimen.h)
        else bb:paintRect(0, 0, self.dimen.w, self.dimen.h, BB.COLOR_LIGHT_GRAY) end
        self.covers_fullscreen = true
        self[1]:paintTo(bb, self.panel_rect.x + (x or 0), self.panel_rect.y + (y or 0))
    end
    local free = Panel.free
    function Panel:free(...)
        if self.backdrop then self.backdrop:free(); self.backdrop = nil end
        if free then return free(self, ...) end
    end
    function Panel:init() self.phase = self.phase or "available"; self:rebuild() end
    if active_panel and not active_panel.closed then active_panel:close() end
    local panel = Panel:new(options or {})
    active_panel = panel
    UI:show(panel)
    return panel
end

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
    M.openPanel{ phase = "installed", current = context.version, restart_text = text }
end

function M.runTask(operation, label, callback, options)
    local Trapper, UI = require("ui/trapper"), require("ui/uimanager")
    local function run()
        -- Native Trapper uses false to DROP the dismissing input. A quiet
        -- maintenance task must instead yield to and resend that first tap.
        -- nil is its invisible, resend-enabled mode; visible tasks stay modal.
        local trap = label
        if trap == false then trap = nil end
        local completed, result
        if not options or not options.cancelled() then completed, result = Trapper:dismissableRunInSubprocess(function()
            local ok, value = pcall(operation)
            if ok then return { ok = true, value = value } end
            local HTTP = require("core/orbitui_http")
            return { error = HTTP.message(value), http_error = HTTP.errorInfo(value) }
        end, trap, false) end
        if options and options.finish then options.finish() end
        UI:scheduleIn(0.1, function()
            callback(completed and result or { error = "Operation cancelled or interrupted", cancelled = true })
        end)
    end
    if Trapper:isWrapped() then UI:scheduleIn(0.1, function() Trapper:wrap(run) end)
    else Trapper:wrap(run) end
end

function M.install(release, panel)
    if busy or not context or panel and panel.closed then return end
    panel = panel or M.openPanel{ phase = "available", current = context.version, release = release }
    busy = true
    local current, OTA, UI = context, require("core/orbitui_ota"), require("ui/uimanager")
    local channel = OTA.progressChannel and OTA.progressChannel(current)
    local job = { panel = panel }; active_job = job
    panel.cancel_requested, panel.progress_key, panel.received, panel.total = false, nil, nil, nil
    panel.on_cancel = function() job.cancelled = true end
    panel.on_install = function() M.install(release, panel) end
    panel:setState("downloading")
    local function poll()
        if active_job ~= job or job.cancelled or panel.closed then return end
        if channel then
            local ok, value = pcall(channel.read)
            if ok and value then panel:progressed(value) end
            UI:scheduleIn(.25, poll)
        end
    end
    if channel then UI:scheduleIn(.25, poll) end
    M.runTask(function() return OTA.prepare(current, release, channel and channel.write) end, panel, function(result)
            if active_job ~= job then return end
            active_job = nil
            busy = false
            panel.dismiss_callback = nil
            if panel.closed then return end
            if job.cancelled or result and result.cancelled then
                panel.cancel_requested = false
                panel:setState("available", { cancel_notice = _("Update cancelled. Your installed version is unchanged.") })
                return
            end
            if not result or not result.ok or not result.value then
                panel:setState("failed", { error_text = tostring(result and result.error or _("No result")) })
                return
            end
            local ok, err = pcall(function()
                local Boot = require("orbitui_bootstrap")
                local state = Boot.state(current.root)
                assert(not state.pending and state.current == current.slot, "OrbitUI selection changed; restart before updating")
                Boot.activate(current.root, result.value.slot)
            end)
            if not ok then panel:setState("failed", { error_text = tostring(err) }); return end
            available = nil
            panel:setState("installed")
        end, { cancelled = function() return job.cancelled or panel.closed end,
            finish = function()
                if channel then UI:unschedule(poll); pcall(channel.close) end
            end })
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
                M.openPanel{ phase = "available", current = context.version, release = release,
                    on_install = function(panel) M.install(release, panel) end }
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
