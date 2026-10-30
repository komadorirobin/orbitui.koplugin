-- Complete shared adapter; only KOReader's widget/hardware boundary is stubbed.
-- Optional native ButtonDialog reference exercises its real layout/close API.
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local values, writes, locale = {}, 0, "en"
G_reader_settings = { readSetting = function(_, k) if k == "language" then return locale end end,
    isTrue = function(_, k) return values[k] == true end }
package.loaded["infra/sui_store"] = { readSetting = function(_, k) return values[k] end,
    saveSetting = function(_, k, v) values[k] = v; writes = writes + 1 end }
local W = H.widget()
function W:getSize()
    if self.dimen then return self.dimen end
    local width, height = 0, 0
    for _, child in ipairs(self) do local d = child:getSize(); width = math.max(width, d.w); height = height + d.h end
    return { w = self.width or width, h = self.height or height }
end
function W:paintTo(_, x, y) self.dimen = self:getSize(); self.dimen.x, self.dimen.y = x, y end
function W:free() self.freed = true end
function W:setText(t) self.text = t end
local Text = W:extend{}
function Text:getSize() return { w = math.min(self.max_width or self.width or 200, #self.text * 7), h = 20 } end
local Span = W:extend{}
function Span:getSize() return { w = 0, h = self.width or 0 } end
local HG = W:extend{}
function HG:getSize()
    local w, h = 0, 0
    for _, c in ipairs(self) do local d = c:getSize(); w = w + d.w; h = math.max(h, d.h) end
    return { w = self.width or w, h = self.height or h }
end
local width, height = 600, 800
local caps = { light = true, warmth = true, battery = true, wifi = true, android = false }
local screen = { getWidth = function() return width end, getHeight = function() return height end,
    scaleBySize = function(_, v) return v end, getSize = function() return { w = width, h = height } end }
local intensity, warmth, native_writes = 30, 450, 0
local power = { fl_min = 0, fl_max = 100, fl_warmth_min = 0, fl_warmth_max = 10,
    frontlightIntensity = function() return intensity end,
    setIntensity = function(_, v) intensity = v; native_writes = native_writes + 1 end,
    frontlightWarmth = function() return warmth end,
    toNativeWarmth = function(_, v) return v / 100 end,
    fromNativeWarmth = function(_, v) return v * 100 end,
    setWarmth = function(_, v) warmth = math.floor(v / 100) * 100; native_writes = native_writes + 1 end,
    getCapacity = function() return caps.capacity or 0 end,
    isCharging = function() return false end, isCharged = function() return caps.charged end }
local dev = { screen = screen, getPowerDevice = function() return power end,
    hasFrontlight = function() return caps.light end, hasNaturalLight = function() return caps.warmth end,
    hasBattery = function() return caps.battery end, hasWifiToggle = function() return caps.wifi end,
    isAndroid = function() return caps.android end, hasKeys = function() return false end,
    isTouchDevice = function() return true end }
package.loaded.device = dev
local function geom(o)
    function o:intersectWith(d) return self.x >= (d.x or 0) and self.x < (d.x or 0) + d.w
        and self.y >= (d.y or 0) and self.y < (d.y or 0) + d.h end
    return o
end
package.loaded["ui/geometry"] = { new = function(_, o) return geom(o) end }
local stack, events, hardware, shown = {}, {}, {}, 0
local host = { name = "homescreen" }
local function resetStack() stack = { host }; host._closed, host._suspended, host._parked = nil, nil, nil end
resetStack()
local UI = { show = function(_, w) stack[#stack + 1] = w; shown = shown + 1 end,
    close = function(_, w)
        for i = #stack, 1, -1 do if stack[i] == w then table.remove(stack, i) end end
        if not w.closed then w.closed = true; if w.onCloseWidget then w:onCloseWidget() end end
    end,
    isWidgetShown = function(_, w) for _, v in ipairs(stack) do if v == w then return true end end; return false end,
    getTopmostVisibleWidget = function() return stack[#stack] and { widget = stack[#stack] } end,
    setDirty = function() end, broadcastEvent = function(_, ev) events[#events + 1] = ev.handler end }
package.loaded["ui/uimanager"] = UI
package.loaded["ui/event"] = { new = function(_, name) return { handler = name } end }
package.loaded["ui/gesturerange"] = W
package.loaded["ui/font"] = { getFace = function() return {} end }
for path, class in pairs({ ["container/inputcontainer"] = W, ["container/centercontainer"] = W,
    ["container/framecontainer"] = W, ["container/movablecontainer"] = W,
    ["container/scrollablecontainer"] = W, verticalgroup = W, horizontalgroup = HG,
    verticalspan = Span, linewidget = W, textwidget = Text, textboxwidget = Text }) do
    package.loaded["ui/widget/" .. path] = class
end
local Dialog = W:extend{}
function Dialog:init()
    self.layout = { self.buttons[1] }; self.movable = W:new{ height = 260, width = self.width }
end
function Dialog:getAddedWidgetAvailableWidth() return self.width - 32 end
function Dialog:addWidget(group) self.added = group; self.layout = { self.buttons[1] } end
function Dialog:onCloseWidget() end
local native_dialog = os.getenv("ORBITUI_NATIVE_BUTTON_DIALOG")
if native_dialog then
    local Focus = W:extend{}
    function Focus:_init() self.ges_events, self.key_events = {}, {} end
    function Focus:mergeLayoutInVertical(other) for _, row in ipairs(other.layout or {}) do self.layout[#self.layout + 1] = row end end
    package.loaded["ui/widget/focusmanager"] = Focus
    package.loaded["ffi/blitbuffer"] = { COLOR_WHITE = 1, COLOR_GRAY = .5 }
    package.loaded["ui/size"] = { padding = { large = 8, default = 4, button = 4, buttontable = 4 },
        margin = { title = 4, default = 4 }, border = { window = 1 }, radius = { window = 3 }, line = { medium = 1 } }
    package.loaded.util = {}
    local Table = W:extend{}
    function Table:init() self.layout = self.buttons; self.height = #self.buttons * 42 end
    package.loaded["ui/widget/buttontable"] = Table
    Dialog = assert(loadfile(native_dialog))()
end
package.loaded["ui/widget/buttondialog"] = Dialog
local sliders = {}
local Slider = W:extend{}
Slider.Caption = W:extend{ height = 20 }
function Slider.Caption:setValue(v) self.value = v end
function Slider.Caption:refresh() end
function Slider:init() sliders[#sliders + 1] = self end
function Slider:setValue(v) self.value = v end
function Slider.stepControls(actions)
    return { minus = W:new{ callback = actions.minus }, plus = W:new{ callback = actions.plus }, height = 40 }
end
function Slider.barWidth(w) return w - 80 end
function Slider.row(c, s) return HG:new{ c.minus, s, c.plus } end
package.loaded["engines/sui_slider"] = Slider
local nm = { isWifiOn = function() hardware.read = (hardware.read or 0) + 1; return true end,
    isConnected = function() return false end, openSettings = function() hardware.android = true end,
    getWifiToggleMenuTable = function() return { callback = function(menu)
        hardware.toggle = true; menu:updateItems() end } end,
    reconnectOrShowNetworkMenu = function() hardware.choose = true end,
    toggleWifiOn = function() hardware.on = true end }
package.loaded["ui/network/manager"] = nm
local plugins = {}
package.loaded.pluginloader = { getPluginInstance = function(_, name) return plugins[name] end }
local notices = {}
package.loaded["core/orbitui_context"] = { notify = function(t) notices[#notices + 1] = t end }
local date_with_time
package.loaded.datetime = { secondsToHour = function(_, twelve) return twelve and "1:05 PM" or "13:05" end,
    secondsToDate = function(_, date_only) date_with_time = not date_only; return "Friday 30 October" end }
local M = require("adapters/orbitui_navbar")
local KEY = "simpleui_orbitui_status_quick_controls"
local function button(dialog, label)
    for _, row in ipairs(dialog.buttons) do for _, b in ipairs(row) do if b.text == label then return b end end end
    error("Missing button: " .. label)
end
local function reset()
    M.closeQuickControls(); M.quickControlsEvent("onResume"); resetStack()
    caps.light, caps.warmth, caps.battery, caps.wifi, caps.android = true, true, true, true, false
    caps.capacity, caps.charged = nil, nil
    UI._simpleui_navigation_generation = 0
    values[KEY], locale, dev.screen_saver_mode = nil, "en", nil
    hardware, events, sliders, plugins = {}, {}, {}, {}
end

H.test("default status gestures are unchanged; settings read/write only their own key", function()
    local before = writes
    local rows = M.quickControlsItems()
    H.eq(rows[2].checked_func(), false); H.eq(writes, before)
    rows[2].callback(); H.eq(rows[2].checked_func(), true); H.eq(writes, before + 1)
end)
H.test("capability gating never invents controls", function()
    reset(); caps.light, caps.battery, caps.wifi = false, false, false
    local d = M.showQuickControls("light"); H.eq(d.title, "Quick controls — Time & date\n\n13:05\nFriday 30 October")
    H.eq(#sliders, 0); H.eq(hardware.read, nil); H.eq(date_with_time, false)
end)
H.test("opening read-only status never cold-loads a network manager", function()
    reset(); package.loaded["ui/network/manager"] = nil
    package.preload["ui/network/manager"] = function() error("cold network side effect") end
    H.eq(M.quickControlsSnapshot().wifi, false)
    M.showQuickControls("battery"); H.eq(hardware.read, nil)
    package.loaded["ui/network/manager"], package.preload["ui/network/manager"] = nm, nil
end)
H.test("Android uses system settings and never infers connected from no-toggle shims", function()
    reset(); caps.wifi, caps.android = false, true
    local d = M.showQuickControls("wifi"); assert(d.title:find("Managed by Android", 1, true))
    H.eq(hardware.read, nil); button(d, "Wi-Fi settings…").callback()
    H.eq(hardware.android, true); H.eq(hardware.toggle, nil); H.eq(#events, 0)
end)
H.test("network is queried once on open, never scanned or optimistically broadcast", function()
    reset(); local d = M.showQuickControls("wifi")
    assert(d.title:find("Not connected", 1, true)); H.eq(hardware.read, 1)
    H.eq(hardware.choose, nil); H.eq(hardware.toggle, nil); H.eq(#events, 0)
    button(d, "Connect / disconnect…").callback(); H.eq(hardware.toggle, true); H.eq(#events, 0)
end)
H.test("network chooser delegates only on explicit click", function()
    reset(); local d = M.showQuickControls("wifi"); button(d, "Choose a network…").callback()
    H.eq(hardware.choose, true)
end)
H.test("missing native network actions remain disabled, never half-implemented", function()
    reset(); local old = nm.getWifiToggleMenuTable; nm.getWifiToggleMenuTable = nil
    local d = M.showQuickControls("wifi"); H.eq(button(d, "Connect / disconnect…").enabled, false)
    nm.getWifiToggleMenuTable = old
end)
H.test("brightness/warmth use native units, limits, readback and no saved UI migration", function()
    reset(); local before = writes; intensity, warmth = 30, 450
    local d = M.showQuickControls("light"); H.eq(#sliders, 2)
    H.eq(sliders[2].value, 4.5); sliders[2].on_change(8); H.eq(warmth, 800); H.eq(sliders[2].value, 8)
    sliders[1].on_change(999); H.eq(intensity, 100); sliders[1].on_change(-9); H.eq(intensity, 0)
    H.eq(writes, before); button(d, "Close").callback()
    local n = native_writes; sliders[1].on_change(80); H.eq(native_writes, n)
end)
H.test("no warmth hardware omits its slider; short screen retains native More", function()
    reset(); caps.warmth = false; M.showQuickControls("light"); H.eq(#sliders, 1)
    M.closeQuickControls(); height = 320
    local d = M.showQuickControls("light"); assert(not d.added and not d._added_widgets)
    assert(button(d, "More light settings…")); height = 800
end)
H.test("native failures and invalid readings remain unknown", function()
    reset(); local old = power.getCapacity; power.getCapacity = function() error("private diagnostic") end
    local d = M.showQuickControls("battery"); assert(d.title:find("Unknown", 1, true))
    power.getCapacity = old; H.eq(button(d, "Battery statistics").enabled, false)
    M.closeQuickControls(); caps.capacity = 101; H.eq(M.quickControlsSnapshot().capacity, nil)
end)
H.test("battery zero and charge status are valid; stats use the existing plugin", function()
    reset(); plugins.batterystat = { onShowBatteryStatistics = function() hardware.stats = true end }
    local d = M.showQuickControls("battery"); assert(d.title:find("0% · Not charging", 1, true))
    button(d, "Battery statistics").callback(); H.eq(hardware.stats, true)
end)
H.test("calendar and twelve-hour formatting reuse existing owners", function()
    reset(); values.twelve_hour_clock = true
    plugins.statistics = { onShowCalendarView = function() hardware.calendar = true end }
    local d = M.showQuickControls("clock"); assert(d.title:find("1:05 PM", 1, true))
    button(d, "Reading calendar").callback(); H.eq(hardware.calendar, true)
    values.twelve_hour_clock = nil
end)
H.test("tab changes replace exactly one popup and keep a copied anchor", function()
    reset(); local rect = { x = 10, y = 30, w = 70, h = 25 }
    local d = M.showQuickControls("battery", { owner = host, anchor = rect })
    rect.y = 900; local anchor = d.anchor(); H.eq(anchor.y, 30)
    button(d, "Wi-Fi").callback(); H.eq(#stack, 2); H.eq(d.closed, true)
    local current = stack[2]; button(d, "Close").callback(); H.eq(stack[2], current)
    button(current, "Refresh status").callback(); H.eq(#stack, 2)
end)
H.test("navigation, stale callbacks, covered owners and rotation cannot mutate hardware", function()
    reset(); local d = M.showQuickControls("light"); local n = native_writes
    UI._simpleui_navigation_generation = 1; sliders[1].on_change(2); H.eq(native_writes, n)
    button(d, "Turn night mode on").callback(); H.eq(#events, 0)
    M.closeQuickControls(); UI._simpleui_navigation_generation = 0
    d = M.showQuickControls("light"); width = 800; sliders[#sliders].on_change(3); H.eq(native_writes, n)
    width = 600; UI:show({}); button(d, "Turn night mode on").callback(); H.eq(#events, 0)
end)
H.test("suspend/resume, direct close and host teardown invalidate the panel", function()
    reset(); plugins.simpleui = { ui = host }
    local d = M.showQuickControls("light"); M.quickControlsEvent("onSuspend")
    H.eq(d.closed, true); H.eq(M.showQuickControls(), false)
    M.quickControlsEvent("onResume"); d = M.showQuickControls("light")
    UI:close(d); button(d, "Turn night mode on").callback(); H.eq(#events, 0)
    d = M.showQuickControls("light"); M.quickControlsEvent("teardown", host); H.eq(d.closed, true)
end)
H.test("night mode is the native event and double taps are inert", function()
    reset(); screen.night_mode = false
    local d = M.showQuickControls("light"); local b = button(d, "Turn night mode on")
    b.callback(); b.callback(); H.eq(#events, 1); H.eq(events[1], "ToggleNightMode")
end)
H.test("Bookshelf status respects opt-in, job Stop, geometry, gestures and expanded return", function()
    reset(); local shelf = { _hero_card = {}, name = "bookshelf" }; stack = { shelf }
    local rect = geom{ x = 10, y = 10, w = 200, h = 30 }
    local ges = { ges = "tap", pos = geom{ x = 20, y = 20 } }
    H.eq(M.quickStatusTap(shelf, rect, ges), false); values[KEY] = true
    package.loaded["lib/bookshelf_scan_progress"] = { active = function() return true end }
    H.eq(M.quickStatusTap(shelf, rect, ges), false)
    package.loaded["lib/bookshelf_scan_progress"] = nil
    H.eq(M.quickStatusTap(shelf, rect, { ges = "hold", pos = ges.pos }), false)
    H.eq(M.quickStatusTap(shelf, rect, ges), true); M.closeQuickControls()
    local Module = { _rebuild = function() end, _rebuildIfSimpleUIContextChanged = function() end }
    M.widget(Module)
    shelf._hero_status_strip = { group = { dimen = rect, {} }, idx = 1 }
    assert(Module.orbitui_status_tap(shelf, ges)); M.closeQuickControls()
    shelf._expanded = true
    H.eq(Module.orbitui_status_tap(shelf, ges), false)
end)
H.test("hero uses only the real live shelf, never shared book detail or a stale card", function()
    reset(); values[KEY] = true
    local fallbacks = 0
    local Hero = { onTap = function() fallbacks = fallbacks + 1; return false end }
    M.hero(Hero)
    local card = setmetatable({ getStatusStripDimen = function() return geom{ x = 0, y = 0, w = 200, h = 30 } end }, { __index = Hero })
    local shelf = { _hero_card = card, name = "bookshelf" }; stack = { shelf }
    package.loaded["lib/bookshelf_widget"] = { live = shelf }
    assert(card:onTap(nil, { ges = "tap", pos = geom{ x = 20, y = 20 } })); M.closeQuickControls()
    shelf._hero_card = {}; H.eq(card:onTap(nil, { ges = "tap", pos = geom{ x = 20, y = 20 } }), false)
    H.eq(fallbacks, 1); package.loaded["lib/bookshelf_widget"] = nil
end)
H.test("topbar preserves content and measurement; stale/nonpainted cells do not open", function()
    reset(); values[KEY] = true
    local Topbar = {}; M.topbar(Topbar)
    local content = W:new{ dimen = geom{ w = 100, h = 24 } }
    H.eq(Topbar.itemWidget("disk", content), content)
    local cell = Topbar.itemWidget("battery", content)
    H.eq(cell[1], content); H.eq(cell:getSize().w, 100); H.eq(cell:onQuickControls(), false)
    cell:paintTo(nil, 10, 10); assert(cell:onQuickControls()); M.closeQuickControls()
    host._fmGestureAction = function() return true end
    local before = shown; assert(cell:onQuickControls(nil, { ges = "tap" })); H.eq(shown, before)
    host._fmGestureAction = function() error("stale gesture must not run") end
    stack = { { name = "ReaderUI" } }; H.eq(cell:onQuickControls(nil, { ges = "tap" }), false)
    host._fmGestureAction = nil
end)
H.test("owned Swedish/English labels, help and errors are translated without exposing diagnostics", function()
    reset(); locale = "sv"; local d = M.showQuickControls("wifi")
    assert(d.title:find("Snabbkontroller", 1, true)); assert(button(d, "Anslut eller koppla från…"))
    local old = nm.openSettings; nm.openSettings = function() error("secret device error") end
    M.closeQuickControls(); caps.android = true; d = M.showQuickControls("wifi")
    button(d, "Wi-Fi-inställningar…").callback()
    H.eq(notices[#notices], "Den här kontrollen är inte tillgänglig på enheten.")
    nm.openSettings = old
    for _, row in ipairs(M.quickControlsItems()) do assert(not row.text:find("quick", 1, true)) end
end)
H.test("whole native Topbar builds host cells without losing its in-place label identities", function()
    reset(); values[KEY] = true
    for _, path in ipairs({ "leftcontainer", "rightcontainer" }) do
        package.loaded["ui/widget/container/" .. path] = W
    end
    package.loaded["ui/widget/overlapgroup"] = W
    package.loaded.logger = { warn = function() end }
    package.loaded["infra/sui_i18n"] = { translate = require("core/orbitui_i18n") }
    package.loaded["infra/sui_config"] = { getTopbarSizePct = function() return 100 end }
    package.loaded["infra/sui_backdrop"] = { contentColors = function() return "black" end }
    package.loaded["features/sui_style"] = { FS_TITLE = 22, FS_BODY = 18, FACE_REGULAR = "test", FACE_ICONS = "icons" }
    package.loaded["infra/sui_accent"] = {}
    package.loaded["screens/sui_bluetooth"] = {}
    package.loaded["ffi/blitbuffer"] = {}
    package.loaded["infra/sui_core"] = { SIDE_M = function() return 12 end,
        getUsableW = function(w) return w - 24 end, trackDimen = function(w) return w end }
    local Topbar = assert(loadfile(root .. "/components/simpleui/screens/sui_topbar.lua"))()
    M.topbar(Topbar)
    local bar = { zones = { left = { { key = "clock", label = "13:05" } },
        right = { { key = "battery", icon = "B", label = "55%" } } },
        surface = { strength = 0, border_sz = 0 }, shape = "test", labels = { "13:05", "55%" } }
    local widget = Topbar.buildTopbarWidget(bar)
    H.eq(#widget._sui_bar.labels, 2)
    H.eq(widget._sui_bar.labels[1].text, "13:05"); H.eq(widget._sui_bar.labels[2].text, "55%")
    -- root -> overlap -> left -> side group -> host cell -> unchanged content
    local cell = widget[1][1][1][1]
    H.eq(cell[1][1], widget._sui_bar.labels[1]); assert(cell.onQuickControls)
end)
H.test("whole native sliders/captions/focus rows support real units and guarded drag repaint", function()
    reset()
    -- Complete component widgets, with native drawing as the only omitted edge.
    function W:_init() self.ges_events, self.key_events = {}, {} end
    package.loaded.optmath = { round = function(v) return math.floor(v + .5) end }
    package.loaded["ui/widget/widget"] = W
    package.loaded["ui/widget/horizontalspan"] = W
    package.loaded["infra/sui_aa_paint"] = {}
    local Native = assert(loadfile(root .. "/components/simpleui/engines/sui_slider.lua"))()
    local created, new = {}, Native.new
    function Native:new(opts)
        local widget = new(self, opts); created[#created + 1] = widget; return widget
    end
    package.loaded["engines/sui_slider"] = Native
    intensity, warmth = 30, 400
    local d = M.showQuickControls("light"); H.eq(#created, 2)
    H.eq(created[2]:getValue(), 4)
    created[2].on_change(7, true); H.eq(warmth, 700); H.eq(created[2]:getValue(), 7)
    created[2].on_release(); H.eq(#d.layout[1], 2)
    M.closeQuickControls(); local before = native_writes
    created[1].on_change(1, true); created[1].on_release(); H.eq(native_writes, before)
    package.loaded["engines/sui_slider"] = Slider
end)
reset()
H.finish()
