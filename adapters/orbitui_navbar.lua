-- Bookshelf owns its dock tree instead of using SimpleUI's navbar wrapper.
local M = {}
local _ = require("core/orbitui_i18n")
M.bookshelf_action = "orbitui_bookshelf"

function M.config(Config)
    local entry = { id = M.bookshelf_action, label = "Bookshelf", icon = "nerd:F02D" }
    Config.ACTION_BY_ID[entry.id] = entry
    Config.ALL_ACTIONS[#Config.ALL_ACTIONS + 1] = entry
    -- Defaults only: loadTabConfig still honours every explicitly saved bar.
    Config.DEFAULT_TABS = { "homescreen", entry.id, "sui_settings", "history", "power" }
    Config.NON_HOME_DEFAULTS = { entry.id, "sui_settings", "homescreen", "history", "power" }
    Config.homeLabel = function() return _("File browser") end
    Config.ACTION_BY_ID.home.label = _("File browser")
end

function M.changed()
    local Config = require("infra/sui_config")
    Config.invalidateTabsCache()
    local plugin = require("core/orbitui_context").plugin("simpleui")
    local bar = package.loaded["screens/sui_bottombar"]
    if plugin and bar then bar.rewrapAllWidgets(plugin) end
end

function M.hasAction(id)
    for _, value in ipairs(require("infra/sui_config").loadTabConfig()) do
        if value == id then return true end
    end
    return false
end

function M.setAction(id, enabled, replace)
    local Config = require("infra/sui_config")
    local tabs = require("core/orbitui_libraries").copy(Config.loadTabConfig())
    for i, value in ipairs(tabs) do
        if value == id then
            if enabled then return true end
            local min = Config.isNavpagerEnabled() and 1 or 2
            if #tabs <= min then return false, "minimum" end
            table.remove(tabs, i)
            Config.saveTabConfig(tabs); M.changed(); return true
        end
    end
    if not enabled then return true end
    if not Config.ACTION_BY_ID[id] then return false, "missing" end
    if replace then
        local found
        for i, value in ipairs(tabs) do if value == replace then tabs[i], found = id, true; break end end
        if not found then return false, "changed" end
    elseif #tabs < Config.effectiveMaxTabs() then tabs[#tabs + 1] = id
    else return false, "full" end
    Config.saveTabConfig(tabs); M.changed(); return true
end

local function refreshShelf()
    local Widget = package.loaded["lib/bookshelf_widget"]
    local shelf = Widget and Widget.live
    if not shelf then return end
    shelf._orbitui_navbar_pending = true
    local UIManager = require("ui/uimanager")
    if UIManager:isWidgetShown(shelf) then
        shelf:_rebuildIfSimpleUIContextChanged()
    end
end

function M.bottombar(module)
    local rewrap = module.rewrapAllWidgets
    module.rewrapAllWidgets = function(plugin)
        rewrap(plugin)
        if not (plugin and plugin._simpleui_suspended) then refreshShelf() end
    end
end

function M.widget(module)
    module.orbitui_status_tap = function(self, ges)
        if self._expanded then return false end -- keep tap-to-restore behaviour
        local strip = self._hero_status_strip
        -- Micro mode's explicit head Geom records its painted origin; its
        -- VerticalGroup text child need not have a dimen at all.
        return M.quickStatusTap(self, strip and strip.group and strip.group.dimen, ges)
    end
    local rebuild = module._rebuild
    local contextChanged = module._rebuildIfSimpleUIContextChanged
    module._rebuild = function(self, ...)
        rebuild(self, ...)
        self._orbitui_navbar_pending = nil
    end
    module._rebuildIfSimpleUIContextChanged = function(self)
        if not self._orbitui_navbar_pending then return contextChanged(self) end
        -- A hidden/warm shelf is reflowed on return, not raised over Home or
        -- the reader when a global setting changes.
        self:_rebuild()
        if self._startStatusTimer then self:_startStatusTimer() end
        require("ui/uimanager"):setDirty(self, "ui")
        return true
    end
end

-- Shared, lazily built controls live in this existing chrome adapter to retain
-- API-1's installed-path set. No Bookshelf-OS code/assets or private upvalues.
local QUICK_KEY = "simpleui_orbitui_status_quick_controls"
local quick, quick_generation, sleeping = nil, 0, false
local kinds = { "light", "wifi", "battery", "clock" }
local kind_labels = { light = "Screen light", wifi = "Wi-Fi", battery = "Battery", clock = "Time & date" }
local function ui() return require("ui/uimanager") end
local function device() return require("device") end
local function call(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
end
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function plugin(name)
    local ok, loader = pcall(require, "pluginloader")
    return ok and call(loader, "getPluginInstance", name) or nil
end
local function network()
    -- Core normally loads this during host startup. Cold require initializes
    -- it and can auto-restore Wi-Fi: a read-only status popup must not do that.
    local loaded = package.loaded["ui/network/manager"]
    return type(loaded) == "table" and loaded or nil
end
local function enabled()
    local store = require("infra/sui_store")
    return store:readSetting(QUICK_KEY) == true
end
local function topWidget()
    local top = call(ui(), "getTopmostVisibleWidget")
    return top and (top.widget or top)
end
local function rectCopy(rect)
    if not rect or not finite(rect.x) or not finite(rect.y) or not finite(rect.w)
            or not finite(rect.h) or rect.w <= 0 or rect.h <= 0 then return nil end
    return require("ui/geometry"):new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
end

function M.closeQuickControls()
    quick_generation = quick_generation + 1
    local old = quick
    quick = nil
    if old and old.dialog then ui():close(old.dialog) end
end

function M.quickControlsEvent(handler, owner)
    if handler == "onResume" then sleeping = false; return end
    if handler == "onSuspend" then sleeping = true end
    local closes = handler == "onSuspend" or handler == "onSetRotationMode"
        or handler == "onScreenResize" or handler == "onShowingReader"
        or handler == "onReaderReady" or handler == "onCloseDocument" or handler == "onExit"
    -- Either host can tear down while the other owns a parked-reader screen.
    if quick and (closes or (handler == "teardown" and (quick.owner == owner
            or not owner or quick.host == owner))) then M.closeQuickControls() end
end

-- Read only on opening/explicit refresh, never in a paint method or timer.
-- !hasWifiToggle's generic "true" is NOT evidence of an Android connection.
function M.quickControlsSnapshot()
    local dev, nm = device(), network()
    local pd = call(dev, "getPowerDevice")
    local data = { light = call(dev, "hasFrontlight") == true,
        warmth = call(dev, "hasNaturalLight") == true,
        battery = call(dev, "hasBattery") == true,
        wifi_toggle = call(dev, "hasWifiToggle") == true,
        android = call(dev, "isAndroid") == true, clock = true }
    data.light = data.light and pd ~= nil
    data.wifi = nm ~= nil and (data.wifi_toggle or (data.android and type(nm.openSettings) == "function"))
    if data.wifi_toggle and nm then
        data.wifi_on = call(nm, "isWifiOn")
        if data.wifi_on == true then data.connected = call(nm, "isConnected") end
    end
    if data.battery then
        local capacity = call(pd, "getCapacity")
        if finite(capacity) and capacity >= 0 and capacity <= 100 then data.capacity = capacity end
        data.charging = call(pd, "isCharging")
        data.charged = call(pd, "isCharged")
    end
    return data
end

local function isCurrent(state)
    if quick ~= state or state.generation ~= quick_generation or sleeping then return false end
    local dev, screen = device(), device().screen
    if dev.screen_saver_mode or dev.screen_saver_lock then return false end
    if state.width ~= screen:getWidth() or state.height ~= screen:getHeight() then return false end
    if state.navigation ~= (ui()._simpleui_navigation_generation or 0) then return false end
    local owner = state.owner
    if owner and (owner._closed or owner._suspended or owner._parked
            or call(ui(), "isWidgetShown", owner) ~= true) then return false end
    local top = topWidget()
    return not top or top == state.dialog
end

local function unavailable()
    require("core/orbitui_context").notify(_("This control is unavailable on this device."))
end
local function safely(action)
    local ok, result = pcall(action)
    if not ok or result == false then unavailable(); return false end
    return true
end

local function lightControls(dialog, width, current)
    local pd, dev = call(device(), "getPowerDevice"), device()
    local Slider = require("engines/sui_slider")
    local Font = require("ui/font")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local VerticalSpan = require("ui/widget/verticalspan")
    local scale = function(v) return dev.screen:scaleBySize(v) end
    local group, focus = VerticalGroup:new{ align = "left", not_focusable = true }, {}
    local function channel(label, min, max, read, write)
        local ok, value = pcall(read)
        if not ok or not finite(value) or not finite(min) or not finite(max) or max <= min then return end
        value = math.max(min, math.min(max, value))
        local slider, caption
        local function commit(v, dragging)
            if not current() then return end
            if not finite(v) then return end
            v = math.max(min, math.min(max, math.floor(v + .5)))
            if not safely(function() return write(v) end) then M.closeQuickControls(); return end
            local read_ok, actual = pcall(read)
            if not read_ok or not finite(actual) then M.closeQuickControls(); return end
            value = math.max(min, math.min(max, actual))
            slider:setValue(value)
            -- The knob already shows the native value. Let the dialog own
            -- painting; do not paint a foreign surface straight into its BB.
            if dragging then ui():setDirty(dialog, "fast", slider.dimen)
            else ui():setDirty(dialog, "ui", dialog.dimen) end
        end
        caption = Slider.Caption:new{ name = _(label), value = tostring(value), width = width,
            gap = scale(6), name_face = Font:getFace("smallinfofont"), name_bold = true }
        local controls = Slider.stepControls({ minus = function() commit(value - 1) end,
            plus = function() commit(value + 1) end }, scale)
        slider = Slider:new{ width = Slider.barWidth(width, controls), height = controls.height,
            min = min, max = max, value = value, face = Font:getFace("smallinfofont"),
            on_change = commit, on_release = function()
                if current() then ui():setDirty(dialog, "ui", slider.dimen) end
            end }
        group[#group + 1] = caption
        group[#group + 1] = Slider.row(controls, slider)
        group[#group + 1] = VerticalSpan:new{ width = scale(8) }
        focus[#focus + 1] = { controls.minus, controls.plus }
    end
    channel("Brightness", pd.fl_min, pd.fl_max,
        function() return pd:frontlightIntensity() end, function(v)
            local result = pd:setIntensity(v)
            call(pd, "updateResumeFrontlightState")
            return result
        end)
    if call(dev, "hasNaturalLight") == true then
        channel("Colour temperature", pd.fl_warmth_min, pd.fl_warmth_max,
            function() return pd:toNativeWarmth(pd:frontlightWarmth()) end,
            function(v) return pd:setWarmth(pd:fromNativeWarmth(v)) end)
    end
    return group, focus
end

function M.showQuickControls(kind, opts)
    opts = opts or {}
    if sleeping or device().screen_saver_mode or device().screen_saver_lock then return false end
    local owner = opts.owner or topWidget()
    -- Do not open a shelf shortcut over the real reader or an unrelated modal.
    if opts.owner and (owner ~= topWidget() or call(ui(), "isWidgetShown", owner) ~= true) then return false end
    local anchor = rectCopy(opts.anchor)
    M.closeQuickControls()
    local data = M.quickControlsSnapshot()
    if not kind_labels[kind] or not data[kind] then
        kind = data.light and "light" or data.wifi and "wifi" or data.battery and "battery" or "clock"
    end
    local screen = device().screen
    local host_plugin = opts.plugin or plugin("simpleui")
    local state = { generation = quick_generation, owner = owner, host = host_plugin and host_plugin.ui,
        width = screen:getWidth(), height = screen:getHeight(),
        navigation = ui()._simpleui_navigation_generation or 0 }
    quick = state
    local function current() return isCurrent(state) end
    local function guarded(action, close)
        return function()
            if not current() then return end
            if close then M.closeQuickControls() end
            return safely(action)
        end
    end
    local function reopen(target)
        -- Reuse the original owner, never the retired popup or a new top screen.
        ui():close(state.dialog)
        return M.showQuickControls(target, { owner = owner, anchor = anchor, plugin = opts.plugin })
    end
    local rows, tabs = {}, {}
    for _i, id in ipairs(kinds) do
        if data[id] then
            local target = id
            tabs[#tabs + 1] = { text = (kind == id and "• " or "") .. _(kind_labels[id]),
                callback = guarded(function() return reopen(target) end) }
            if #tabs == 2 then rows[#rows + 1], tabs = tabs, {} end
        end
    end
    if #tabs > 0 then rows[#rows + 1] = tabs end
    local title = _("Quick controls") .. " — " .. _(kind_labels[kind])
    local function row(label, action, enabled_row)
        rows[#rows + 1] = {{ text = _(label), enabled = enabled_row ~= false,
            callback = guarded(action, true) }}
    end
    if kind == "light" then
        row("More light settings…", function()
            ui():show(require("ui/widget/frontlightwidget"):new{})
        end)
        row(screen.night_mode and "Turn night mode off" or "Turn night mode on", function()
            ui():broadcastEvent(require("ui/event"):new("ToggleNightMode"))
        end)
    elseif kind == "wifi" then
        local status = data.wifi_toggle and (data.wifi_on == true and
            (data.connected == true and "Connected" or data.connected == false and "Not connected" or "Unknown")
            or data.wifi_on == false and "Wi-Fi is off" or "Unknown") or "Managed by Android"
        title = title .. "\n\n" .. _(status)
        local nm = network()
        if data.android then
            row("Wi-Fi settings…", function() return nm:openSettings() end, type(nm.openSettings) == "function")
        else
            local entry = call(nm, "getWifiToggleMenuTable")
            -- Delegate prompting, connectivity checks and real events to core.
            row("Connect / disconnect…", function()
                return entry.callback({ updateItems = function() end })
            end, entry and type(entry.callback) == "function" or false)
            row("Choose a network…", function()
                if call(nm, "isWifiOn") == true then return nm:reconnectOrShowNetworkMenu(nil, true) end
                return nm:toggleWifiOn(nil, true, true)
            end, type(nm.reconnectOrShowNetworkMenu) == "function" and type(nm.toggleWifiOn) == "function")
        end
    elseif kind == "battery" then
        title = title .. "\n\n" .. (data.capacity and tostring(data.capacity) .. "%" or _("Unknown"))
            .. " · " .. _(data.charged == true and "Fully charged" or data.charging == true and "Charging"
                or data.charging == false and "Not charging" or "Unknown")
        local stats = plugin("batterystat")
        row("Battery statistics", function() return stats:onShowBatteryStatistics() end,
            stats and type(stats.onShowBatteryStatistics) == "function" or false)
    else
        local datetime = require("datetime")
        title = title .. "\n\n" .. datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
            .. "\n" .. datetime.secondsToDate(os.time(), true)
        local stats = plugin("statistics")
        row("Reading calendar", function() return stats:onShowCalendarView() end,
            stats and type(stats.onShowCalendarView) == "function" or false)
    end
    rows[#rows + 1] = {
        { text = _("Refresh status"), callback = guarded(function() return reopen(kind) end) },
        { text = _("Close"), callback = guarded(M.closeQuickControls) },
    }
    local dialog = require("ui/widget/buttondialog"):new{
        title = title, buttons = rows,
        width = math.max(1, math.min(screen:getWidth() - 2 * screen:scaleBySize(12), screen:scaleBySize(440))),
        anchor = anchor and function() return anchor, true end or nil,
    }
    state.dialog = dialog
    local original_close = dialog.onCloseWidget
    function dialog:onCloseWidget(...)
        if quick == state then quick = nil; quick_generation = quick_generation + 1 end
        if original_close then return original_close(self, ...) end
    end
    for _i, event in ipairs({ "onSuspend", "onSetRotationMode", "onScreenResize", "onShowingReader" }) do
        dialog[event] = function()
            if quick == state then M.closeQuickControls() end
            return false
        end
    end
    if kind == "light" then
        local ok, group, focus = pcall(lightControls, dialog, dialog:getAddedWidgetAvailableWidth(), current)
        -- ButtonDialog scrolls its buttons but not added widgets. Keep the
        -- entire slider group within the actual screen, or retain native More.
        if ok and #group > 0 and dialog.movable:getSize().h + group:getSize().h + screen:scaleBySize(32)
                < screen:getHeight() then
            dialog:addWidget(group)
            local layout = {}
            for _i, controls in ipairs(focus) do layout[#layout + 1] = controls end
            for _i, buttons in ipairs(dialog.layout) do layout[#layout + 1] = buttons end
            dialog.layout = layout
        elseif ok and group.free then group:free() end
    end
    local QA = package.loaded["features/sui_quickactions"]
    if opts.plugin and QA and QA.trackIndicatorWhileOpen then
        QA.trackIndicatorWhileOpen(opts.plugin, "orbitui_quick_controls", dialog)
    end
    ui():show(dialog)
    return dialog
end

function M.quickControlsItems(close)
    return {
        { text = _("Open quick controls"), callback = function()
            if close then close() end
            M.showQuickControls()
        end },
        { text = _("Tap status fields for quick controls"),
            help_text = _("Optional on Home (SimpleUI) and Bookshelf. Tap a Home clock, battery, Wi-Fi or brightness field, or Bookshelf's status line. Existing long-press settings, custom gestures and full-screen return stay unchanged. You can also add the Quick controls action to your bar."),
            checked_func = enabled, callback = function()
                require("infra/sui_store"):saveSetting(QUICK_KEY, not enabled())
                M.closeQuickControls()
                local Topbar = package.loaded["screens/sui_topbar"]
                if Topbar then Topbar.invalidateDimCache() end
                local Engine = package.loaded["engines/sui_screen_engine"]
                if Engine then Engine.refreshAllLiveImmediate(false) end
            end },
    }
end

function M.quickStatusTap(owner, rect, ges)
    if not enabled() or not ges or ges.ges ~= "tap" or not ges.pos or not rect then return false end
    local Progress = package.loaded["lib/bookshelf_scan_progress"]
    if Progress and Progress.active() then return false end
    if not ges.pos:intersectWith(rect) then return false end
    return M.showQuickControls(nil, { owner = owner, anchor = rect }) ~= false
end

function M.hero(module)
    local tap = module.onTap
    module.onTap = function(self, arg, ges)
        local Widget = package.loaded["lib/bookshelf_widget"]
        local owner = Widget and Widget.live
        if owner and owner._hero_card == self and not owner._expanded
                and M.quickStatusTap(owner, self:getStatusStripDimen(), ges) then return true end
        return tap(self, arg, ges)
    end
end

function M.topbar(module)
    local previous = module.itemWidget
    module.itemWidget = function(key, content)
        if previous then content = previous(key, content) or content end
        local kind = ({ brightness = "light", wifi = "wifi", battery = "battery", clock = "clock" })[key]
        if not kind or not enabled() then return content end
        local size = content:getSize()
        local Geom = require("ui/geometry")
        local cell = require("ui/widget/container/inputcontainer"):new{
            dimen = Geom:new{ w = size.w, h = size.h }, content,
        }
        cell.ges_events = { QuickControls = { require("ui/gesturerange"):new{
            ges = "tap", range = function() return cell.dimen end,
        } } }
        local paint = cell.paintTo
        function cell:paintTo(...)
            local owner = topWidget()
            if owner and (owner.name == "homescreen" or owner.name == "filemanager") then
                self._orbitui_owner = owner
            end
            return paint(self, ...)
        end
        function cell:onQuickControls(arg, ges)
            if not enabled() or not self._orbitui_owner then return false end
            -- Home already owns its configured FM gesture routing. A corner
            -- action wins over this opt-in shortcut, just as it does on Shelf.
            local owner = self._orbitui_owner
            if owner ~= topWidget() or call(ui(), "isWidgetShown", owner) ~= true
                    or sleeping or device().screen_saver_mode or device().screen_saver_lock then return false end
            if ges and owner._fmGestureAction and owner:_fmGestureAction(ges) then return true end
            return M.showQuickControls(kind, { owner = self._orbitui_owner, anchor = self.dimen }) ~= false
        end
        return cell
    end
end

return M
