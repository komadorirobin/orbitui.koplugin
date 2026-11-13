-- Bookshelf owns its dock tree instead of using SimpleUI's navbar wrapper.
local M = {}
local _ = require("core/orbitui_i18n")
M.bookshelf_action = "orbitui_bookshelf"
M.default_tabs = { "homescreen", M.bookshelf_action, "history", "power" }

function M.config(Config)
    local entry = { id = M.bookshelf_action, label = _("Library"), icon = "nerd:F02D" }
    Config.ACTION_BY_ID[entry.id] = entry
    Config.ALL_ACTIONS[#Config.ALL_ACTIONS + 1] = entry
    -- Defaults only: loadTabConfig still honours every explicitly saved bar.
    Config.DEFAULT_TABS = M.default_tabs
    Config.DEFAULT_NUM_TABS = #M.default_tabs
    Config.NON_HOME_DEFAULTS = M.default_tabs
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

function M.actions(QA)
    if not QA.iterBuiltin then return end
    for action in QA.iterBuiltin() do
        if action.id == "sui_settings" then
            action.label = "OrbitUI"
            action.execute = function() return require("adapters/orbitui_settings").show() end
            break
        end
    end
end

local function savedTabs(Config)
    local tabs = require("infra/sui_store"):get("simpleui_bar_tabs")
    -- Keep unavailable actions in the saved sequence. Some may come back
    -- when a profile, plugin, or custom screen is enabled again.
    if type(tabs) ~= "table" or #tabs < (Config.isNavpagerEnabled() and 1 or 2)
            or #tabs > Config.effectiveMaxTabs() then
        tabs = Config.loadTabConfig()
    end
    return require("core/orbitui_libraries").copy(tabs)
end

function M.setAction(id, enabled, replace)
    local Config = require("infra/sui_config")
    local QA = require("features/sui_quickactions")
    local tabs, visible = savedTabs(Config), Config.loadTabConfig()
    for i, value in ipairs(tabs) do
        if value == id then
            if enabled then return true end
            local min = Config.isNavpagerEnabled() and 1 or 2
            local is_visible = false
            for _, action in ipairs(visible) do if action == id then is_visible = true; break end end
            if is_visible and #visible <= min then return false, "minimum" end
            table.remove(tabs, i)
            Config.saveTabConfig(tabs); M.changed(); return true
        end
    end
    if not enabled then return true end
    if not QA.isRegistered(id) and not QA.getCustomQAValid()[id] then return false, "missing" end
    if replace then
        local found
        for i, value in ipairs(tabs) do if value == replace then tabs[i], found = id, true; break end end
        if not found then return false, "changed" end
    elseif #tabs < Config.effectiveMaxTabs() then tabs[#tabs + 1] = id
    else return false, "full" end
    Config.saveTabConfig(tabs); M.changed(); return true
end

function M.moveAction(id, offset)
    if offset ~= -1 and offset ~= 1 then return false end
    local Config = require("infra/sui_config")
    local tabs, visible = savedTabs(Config), Config.loadTabConfig()
    local other
    for i, action in ipairs(visible) do if action == id then other = visible[i + offset]; break end end
    if not other then return false end
    local from, to
    for i, action in ipairs(tabs) do
        if action == id then from = i elseif action == other then to = i end
    end
    if not (from and to) then return false end
    tabs[from], tabs[to] = tabs[to], tabs[from]
    Config.saveTabConfig(tabs); M.changed(); return true
end

local function dockNotice(reason)
    local messages = {
        minimum = "Keep at least two dock shortcuts, or one with page arrows.",
        full = "The dock is full. Choose a shortcut to replace.",
    }
    require("core/orbitui_context").notify(_(messages[reason] or "The dock changed. Open the editor again."))
end

local function dockLabel(id)
    return require("features/sui_quickactions").getEntry(id).label
end

local function dockSlotPicker(title, choose, back)
    local UI, rows, panel = require("ui/uimanager"), {}
    for _, id in ipairs(require("infra/sui_config").loadTabConfig()) do
        local target = id
        rows[#rows + 1] = { title = dockLabel(target), action = function()
            UI:close(panel)
            choose(target)
        end }
    end
    panel = require("lib/bookshelf_library_modal").showSheet{
        title = title, back = back and _("Dock"), on_back = back and function() UI:close(panel); back() end,
        rows = rows,
    }
    return panel
end

function M.addShortcut(id, done)
    local ok, reason = M.setAction(id, true)
    if ok then
        if done then done() end
        return true
    end
    if reason ~= "full" then dockNotice(reason); return false end
    return dockSlotPicker(_("Replace a dock shortcut"), function(target)
        local replaced, failure = M.setAction(id, true, target)
        if not replaced then return dockNotice(failure) end
        if done then done() end
    end)
end

local function dockPicker(replace, back, done)
    local UI, Config, QA = require("ui/uimanager"), require("infra/sui_config"), require("features/sui_quickactions")
    local profiles = require("lib/bookshelf_profiles")
    local libraries = require("adapters/orbitui_libraries")
    local profile_actions, active = {}, {}
    for _, id in ipairs(Config.loadTabConfig()) do active[id] = true end
    for _, profile in ipairs(profiles.list(true)) do profile_actions[libraries.actionId(profile.key)] = profile end
    local device = require("device")
    local rows, seen, panel = {}, {}, nil
    local function available(id)
        if id == "frontlight" then return device:hasFrontlight() end
        if id == "bookshelf_prose" then return profiles.get("prose") ~= nil end
        if id == "bookshelf_comics" then return profiles.get("comics") ~= nil end
        if profile_actions[id] then return profiles.get(profile_actions[id].key) ~= nil end
        if QA.getBrowseMode(id) then return require("features/library/sui_library_browse").isEnabled() end
        return true
    end
    local function select(id, old)
        local ok, reason = M.setAction(id, true, old)
        if ok then
            done()
        elseif reason == "full" then
            dockSlotPicker(_("Replace a dock shortcut"), function(target) select(id, target) end, function()
                dockPicker(replace, back, done)
            end)
        else
            dockNotice(reason); back()
        end
    end
    local function customTarget(label, path, collection, old)
        local ids = require("core/orbitui_libraries").copy(QA.getCustomQAList())
        for _, id in ipairs(ids) do
            local cfg = QA.getCustomQAConfig(id)
            if (path and cfg.path == path) or (collection and cfg.collection == collection) then
                return select(id, old)
            end
        end
        local tabs = savedTabs(Config)
        if not old and #tabs >= Config.effectiveMaxTabs() then
            return dockSlotPicker(_("Replace a dock shortcut"), function(target)
                customTarget(label, path, collection, target)
            end, function() dockPicker(replace, back, done) end)
        end
        if old then
            local found
            for _, id in ipairs(tabs) do if id == old then found = true; break end end
            if not found then dockNotice("changed"); return back() end
        end
        if #ids >= Config.MAX_CUSTOM_QA then
            require("core/orbitui_context").notify(_("Your quick-action list is full."))
            return back()
        end
        local id = QA.nextCustomQAId()
        QA.saveCustomQAConfig(id, Config.sanitizeLabel(label) or label, path, collection)
        ids[#ids + 1] = id
        QA.saveCustomQAList(ids)
        QA.invalidateCustomQACache()
        return select(id, old)
    end
    local function pickFolder()
        local picker = require("ui/widget/pathchooser"):new{
            select_directory = true, select_file = false, show_files = false,
            path = G_reader_settings:readSetting("home_dir") or "/",
            onConfirm = function(path)
                UI:close(panel)
                if path ~= "/" then path = path:gsub("/+$", "") end
                customTarget(path:match("([^/]+)$") or _("File browser"), path, nil, replace)
            end,
        }
        UI:show(picker)
    end
    rows[1] = { title = _("Choose a folder…"), icon = "folder", action = pickFolder }
    local collections = Config.getNonFavoritesCollections()
    if #collections > 0 then
        rows[#rows + 1] = { title = _("Choose a collection…"), icon = "collections_bookmark", action = function()
            UI:close(panel)
            local choices, picker = {}
            for _, name in ipairs(collections) do
                local collection = name
                choices[#choices + 1] = { title = collection, action = function()
                    UI:close(picker); customTarget(collection, nil, collection, replace)
                end }
            end
            picker = require("lib/bookshelf_library_modal").showSheet{
                title = _("Choose a collection…"), back = _("Add shortcut"), rows = choices,
                on_back = function() UI:close(picker); dockPicker(replace, back, done) end,
            }
        end }
    end
    local function section(ids, label)
        local group = _(label)
        for _, id in ipairs(ids) do
            if not seen[id] and not active[id] and available(id) then
                local target = id
                rows[#rows + 1] = { title = dockLabel(target), group = group, action = function()
                    UI:close(panel); select(target, replace)
                end }
                group, seen[id] = nil, true
            end
        end
    end
    section({ "homescreen", M.bookshelf_action, "history", "collections", "home", "power", "sui_settings" }, "Common shortcuts")
    local library_ids = {}
    for _, profile in ipairs(profiles.list()) do library_ids[#library_ids + 1] = libraries.actionId(profile.key) end
    section(library_ids, "Libraries")
    section(Config.getCustomQAList(), "Your quick actions")
    section(QA.allIds(), "More destinations")
    panel = require("lib/bookshelf_library_modal").showSheet{
        title = _(replace and "Replace shortcut" or "Add shortcut"),
        back = _("Dock"), on_back = function() UI:close(panel); back() end, rows = rows,
    }
    return panel
end

function M.shortcutMenu(id, back)
    local UI, Config = require("ui/uimanager"), require("infra/sui_config")
    local QA = require("features/sui_quickactions")
    local dialog
    local function edit() return M.editDock(back) end
    local function button(label, action, enabled)
        return {{ text = _(label), enabled = enabled ~= false, callback = function()
            UI:close(dialog); action()
        end }}
    end
    local function done() if back then edit() end end
    local buttons = {
        button("Add shortcut", function() dockPicker(nil, edit, done) end),
        button("Replace shortcut", function() dockPicker(id, edit, done) end),
        button("Remove from dock", function()
            local ok, reason = M.setAction(id, false)
            if not ok then dockNotice(reason) end
            done()
        end, #Config.loadTabConfig() > (Config.isNavpagerEnabled() and 1 or 2)),
        button("Edit dock", edit),
    }
    if id == M.bookshelf_action then
        buttons[#buttons + 1] = button("Library shortcut", function()
            require("adapters/orbitui_settings").open("bookshelf_navigation", {
                return_label = _("Dock"), return_to = function() M.shortcutMenu(id, back) end,
            })
        end)
    elseif id == "bookshelf_prose" or id == "bookshelf_comics" or QA.bookshelfHoldEvent(id)
            or require("adapters/orbitui_libraries").navigationProfile(id) then
        buttons[#buttons + 1] = button("Open library start menu", function()
            local plugin = require("core/orbitui_context").plugin("simpleui")
            QA.holdExecute(id, { plugin = plugin, fm = plugin and plugin.ui })
        end)
    end
    buttons[#buttons + 1] = button("Cancel", done)
    dialog = require("ui/widget/buttondialog"):new{
        title = _("Dock") .. " · " .. dockLabel(id),
        buttons = buttons,
    }
    dialog._sui_keep_homescreen = true
    UI:show(dialog)
    return dialog
end

function M.editDock(back)
    local Config = require("infra/sui_config")
    local Window = require("engines/sui_window")
    local window
    local function showPicker(old)
        window:close()
        local function reopen() M.editDock(back) end
        return dockPicker(old, reopen, reopen)
    end
    local function chooseExistingDestination()
        window:close()
        return require("adapters/orbitui_settings").open("bookshelf_navigation", {
            return_label = _("Dock"), return_to = function() return M.editDock(back) end,
        })
    end
    window = Window:new{
        name = "orbitui_dock_settings", icon = "settings", title = _("Edit dock"),
        on_back = back, position = "bottom", auto_height = true,
        screens = { __root__ = function(ctx)
            local tabs, rows = Config.loadTabConfig(), {}
            local can_remove = #tabs > (Config.isNavpagerEnabled() and 1 or 2)
            for i, id in ipairs(tabs) do
                local action = id
                local function move(offset)
                    return function() if M.moveAction(action, offset) then ctx.repaint() end end
                end
                rows[#rows + 1] = Window.ArrangeCard{
                    inner_w = ctx.inner_w, title = dockLabel(action),
                    on_move_up = i > 1 and move(-1) or nil,
                    on_move_down = i < #tabs and move(1) or nil,
                    on_delete = can_remove and function()
                        local ok, reason = M.setAction(action, false)
                        if ok then ctx.repaint() else dockNotice(reason) end
                    end or nil,
                    delete_icon = "remove", show_chevron = true, on_tap = function() showPicker(action) end,
                }
            end
            if M.hasAction(M.bookshelf_action) then
                rows[#rows + 1] = Window.ListRow{ inner_w = ctx.inner_w, title = _("Library shortcut"),
                    subtitle = _("Choose where the library button leads."), show_chevron = true,
                    on_tap = chooseExistingDestination }
            end
            return rows
        end },
        screen_footers = { __root__ = function(ctx)
            return Window.CenteredButtonFooter(ctx, { text = _("Add shortcut"), on_tap = function() showPicker() end })
        end },
    }
    window:show()
    return window
end

function M.holdShortcut(id)
    if id then return M.shortcutMenu(id) end
    return M.editDock()
end

function M.menuItem(menu)
    return { text = _("Edit dock"), keep_menu_open = true, callback = function()
        M.editDock(menu and menu.refresh or nil)
    end }
end

local function dockHoldEnabled()
    return require("infra/sui_store"):nilOrTrue("simpleui_bar_settings_on_hold")
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
    module.orbitui_hold_shortcut = function(id)
        if not dockHoldEnabled() then return false end
        M.holdShortcut(id)
        return true
    end
    local rewrap = module.rewrapAllWidgets
    module.rewrapAllWidgets = function(plugin)
        rewrap(plugin)
        if not (plugin and plugin._simpleui_suspended) then refreshShelf() end
    end
end

function M.widget(module)
    module.orbitui_dock_hold_enabled = dockHoldEnabled
    module.orbitui_dock_hold = function(_, id) M.holdShortcut(id) end
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
        -- This controller owns the native dialog's exact identity/lifecycle.
        -- A SimpleUI action-sheet proxy would make every guarded action stale.
        sui_native = true, title = title, buttons = rows,
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
            help_text = _("Tap the clock, battery, Wi-Fi or brightness on Home, or the status line in Library. You can also add Quick controls to the dock."),
            checked_func = enabled, callback = function()
                require("infra/sui_store"):saveSetting(QUICK_KEY, not enabled())
                M.closeQuickControls()
                -- Status cells stay mounted while disabled and read the flag
                -- at dispatch time. No chrome/book/provider rebuild is needed.
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

function M.core(module)
    local previous = module.beforeGesture
    module.beforeGesture = function(owner, ges)
        if previous and previous(owner, ges) then return true end
        -- Only Home/custom screens delegate their configured FM gestures via
        -- _fmGestureAction. Do not override native file-manager/other routing.
        if not owner or owner.name ~= "homescreen" or not ges or ges.ges ~= "tap" or not ges.pos
                or ui()._input_gestures_disabled or not enabled() then return false end
        local function findCell(widget, depth)
            if type(widget) ~= "table" or depth > 8 then return end
            if widget._orbitui_status_cell then
                local rect = widget.dimen
                if widget._orbitui_owner == owner and rect and finite(rect.w) and finite(rect.h)
                        and rect.w > 0 and rect.h > 0 and ges.pos:intersectWith(rect) then return widget end
                return
            end
            for _, child in ipairs(widget) do
                local found = findCell(child, depth + 1)
                if found then return found end
            end
        end
        -- Search only the currently mounted topbar, not retired cells or body
        -- widgets. The cell keeps the same owner/custom-gesture/lifecycle guard.
        local cell = findCell(owner._navbar_topbar, 0)
        return cell and cell:onQuickControls(nil, ges) or false
    end
end

function M.topbar(module)
    local previous = module.itemWidget
    module.itemWidget = function(key, content)
        if previous then content = previous(key, content) or content end
        local kind = ({ brightness = "light", wifi = "wifi", battery = "battery", clock = "clock" })[key]
        if not kind then return content end
        local size = content:getSize()
        local Geom = require("ui/geometry")
        local cell = require("ui/widget/container/inputcontainer"):new{
            dimen = Geom:new{ w = size.w, h = size.h }, _orbitui_status_cell = true, content,
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
                    or owner._closed or owner._suspended or owner._parked
                    or sleeping or device().screen_saver_mode or device().screen_saver_lock then return false end
            if ges and owner._fmGestureAction and owner:_fmGestureAction(ges) then return true end
            return M.showQuickControls(kind, { owner = self._orbitui_owner, anchor = self.dimen }) ~= false
        end
        return cell
    end
end

return M
