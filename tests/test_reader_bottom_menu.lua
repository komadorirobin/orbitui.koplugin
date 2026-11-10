local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local W = H.widget()
local f, M, B, UI, prototype
local Event = { new = function(_, name) return { name = name, handler = "on" .. name } end }
local Dialog = { new = function(_, opts)
    opts.onShowConfigPanel = function(self, panel) self.panel_index = panel end
    opts.onCloseWidget = function(self) if self.close_callback then self.close_callback() end end
    return opts
end }
local function nativeShow(self)
    f.native = f.native + 1
    UI:show(Dialog:new{ close_callback = function() self.config_dialog = nil end })
    return true, "native", nil, "tail"
end
prototype = {
    onShowConfigMenu = nativeShow,
    onTapShowConfigMenu = function(self, ...)
        f.taps = f.taps + 1; f.args = { n = select("#", ...), ... }
        if self.activation_menu ~= "swipe" then return self:onShowConfigMenu() end
    end,
    onSwipeShowConfigMenu = function(self, ges, ...)
        f.swipes = f.swipes + 1; f.args = { n = select("#", ges, ...), ges, ... }
        if self.activation_menu ~= "tap" and ges.direction == "north" then return self:onShowConfigMenu() end
    end,
}
local ordinary = prototype
local function fixture()
    f = { stack = {}, writes = {}, events = {}, opened = 0, native = 0, taps = 0, swipes = 0,
        stop = 0, retired = 0, closed = 0 }
    G_reader_settings = { readSetting = function(_, key)
        if key == "orbitui_reader_bottom_panel" then return f.preference end
        if key == "language" then return "sv" end
    end, saveSetting = function(_, key, value) f.writes[#f.writes + 1] = key; f.preference = value end }
    UI = { show = function(_, w) f.stack[#f.stack + 1] = w end,
        close = function(_, w)
            for i = #f.stack, 1, -1 do if f.stack[i] == w then table.remove(f.stack, i) end end
            if w.onCloseWidget then w:onCloseWidget() end
        end,
        isWidgetShown = function(_, w) for _, item in ipairs(f.stack) do if item == w then return true end end; return false end,
        getTopmostVisibleWidget = function() return f.stack[#f.stack] end }
    package.loaded["ui/uimanager"], package.loaded["ui/event"] = UI, Event
    package.loaded.logger = { warn = function() f.warning = true end }
    f.ui = { document = { file = "/books/a.epub" }, doc_settings = {},
        handleEvent = function(_, event) f.events[#f.events + 1] = event.name end,
        registerTouchZones = function(_, zones) f.zones = zones end,
        keyselection = { stopHighlightIndicator = function(_, forced) H.eq(forced, true); f.stop = f.stop + 1 end } }
    f.config = setmetatable({ ui = f.ui, document = f.ui.document, activation_menu = "swipe_tap", last_panel_index = 3 }, { __index = prototype })
    f.ui.config = f.config; f.stack[1] = f.ui
    f.R = { instance = f.ui }; package.loaded["apps/reader/readerui"] = f.R
    package.loaded["adapters/orbitui_book_panel"] = nil; M = require("adapters/orbitui_book_panel")
    M._reader_tools = { show = function(ui)
        H.eq(ui, f.ui)
        if f.failure then error("renderer failed") end
        if f.empty then return end
        f.opened = f.opened + 1
        local w = { onCloseWidget = function() f.closed = f.closed + 1 end }
        UI:show(w); return w
    end, retire = function() f.retired = f.retired + 1 end, event = function() end }
    B = M.readerBottomMenu(); B.attach(f.ui)
    return f.config
end
local function closeTop() UI:close(UI:getTopmostVisibleWidget()) end
local function countEvent(name)
    local n = 0; for _, value in ipairs(f.events) do if value == name then n = n + 1 end end; return n
end
H.test("bottom gestures use OrbitUI by default without saving a preference or replacing native config/keyboard entry", function()
    local config = fixture()
    assert(M.readerBottomEnabled()); H.eq(#f.writes, 0); H.eq(f.opened, 0)
    H.eq(config.onShowConfigMenu, prototype.onShowConfigMenu)
    assert(config:onTapShowConfigMenu()); H.eq(f.opened, 1); H.eq(f.native, 0)
    H.eq(f.stop, 1); H.eq(countEvent("DisableHinting"), 1); H.eq(countEvent("HandledAsSwipe"), 1)
    closeTop(); H.eq(f.closed, 1); H.eq(countEvent("RestoreHinting"), 1)
    assert(config:onSwipeShowConfigMenu{ direction = "north" }); H.eq(f.opened, 2); H.eq(f.native, 0)
end)
H.test("tap/swipe activation modes and non-north directions retain native semantics", function()
    for _, mode in ipairs{ "tap", "swipe", "swipe_tap" } do
        local config = fixture(); config.activation_menu = mode
        config:onTapShowConfigMenu()
        H.eq(f.opened, mode == "swipe" and 0 or 1)
        if f.opened > 0 then closeTop() end
        local before = f.opened
        for _, direction in ipairs{ "south", "east", "west" } do config:onSwipeShowConfigMenu{ direction = direction } end
        H.eq(f.opened, before); H.eq(f.native, 0)
        config:onSwipeShowConfigMenu{ direction = "north" }
        H.eq(f.opened, before + (mode == "tap" and 0 or 1))
    end
end)
H.test("an explicit off immediately delegates original callable handlers with exact arguments and return arity", function()
    local config = fixture(); B.detach(f.ui)
    local fn = ordinary.onTapShowConfigMenu
    config.onTapShowConfigMenu = setmetatable({}, { __call = function(_, ...) return fn(...) end })
    local original = config.onTapShowConfigMenu
    B.attach(f.ui); f.preference = false
    local function pack(...) return { n = select("#", ...), ... } end
    local result = pack(config:onTapShowConfigMenu("argument", nil, "last"))
    H.eq(result.n, 4); H.eq(result[2], "native"); H.eq(result[4], "tail")
    H.eq(f.args.n, 3); H.eq(f.args[1], "argument"); H.eq(f.args[3], "last")
    H.eq(f.native, 1); H.eq(f.opened, 0); H.eq(#f.events, 0)
    closeTop(); f.preference = true; config:onTapShowConfigMenu(); H.eq(f.opened, 1)
    B.detach(f.ui); H.eq(config.onTapShowConfigMenu, original)
end)
H.test("native Reading settings is an unwrapped escape hatch, not a recursive return to OrbitUI", function()
    local config = fixture(); config:onTapShowConfigMenu(); closeTop()
    config:onShowConfigMenu(); H.eq(f.native, 1); H.eq(f.opened, 1)
end)
H.test("repeat ReaderReady and rotation reuse one instance hook; suspend/resume never open a menu themselves", function()
    local config = fixture(); local handler = config.onTapShowConfigMenu
    B.attach(f.ui); H.eq(config.onTapShowConfigMenu, handler)
    M.readerToolsEvent("onScreenResize", f.ui); H.eq(config.onTapShowConfigMenu, handler)
    M.readerToolsEvent("onSuspend", f.ui); config:onTapShowConfigMenu(); H.eq(f.opened, 0)
    M.readerToolsEvent("onResume", f.ui); H.eq(f.opened, 0)
    config:onTapShowConfigMenu(); H.eq(f.opened, 1)
end)
H.test("foreign modals, parked readers and replaced reader/document/settings/config reject late gesture callbacks", function()
    for _, change in ipairs{
        function() UI:show{} end,
        function() f.stack = {} end,
        function() f.R.instance = {} end,
        function() f.ui.document = { file = "/books/b.epub" } end,
        function() f.ui.doc_settings = {} end,
        function() f.ui.config = {} end,
        function() f.ui.document.file = "/books/b.epub" end,
    } do
        local config = fixture(); local captured = config.onTapShowConfigMenu
        change(); captured(config); H.eq(f.opened, 0); H.eq(f.native, 0)
        f.preference = false; captured(config); H.eq(f.native, 0)
    end
end)
H.test("teardown restores inherited slots and preserves later third-party wrappers", function()
    local config = fixture(); local owned = config.onTapShowConfigMenu
    local foreign = function(...) return owned(...) end
    config.onTapShowConfigMenu = foreign
    M.readerToolsEvent("onTeardown", f.ui)
    H.eq(config.onTapShowConfigMenu, foreign); H.eq(rawget(config, "onSwipeShowConfigMenu"), nil)
    config:onTapShowConfigMenu(); H.eq(f.native, 1); H.eq(f.opened, 0)
    closeTop(); f.R.instance = {}; owned(config); H.eq(f.native, 1)
    config = fixture(); M.readerToolsEvent("onCloseDocument", f.ui)
    H.eq(rawget(config, "onTapShowConfigMenu"), nil); H.eq(rawget(config, "onSwipeShowConfigMenu"), nil)
end)
H.test("renderer failure restores hinting, retires partial owned work and falls back to the native menu", function()
    for _, mode in ipairs{ "failure", "empty" } do
        local config = fixture(); f[mode] = true
        assert(config:onTapShowConfigMenu()); H.eq(f.native, 1); H.eq(f.retired, 1)
        H.eq(countEvent("DisableHinting"), 1); H.eq(countEvent("RestoreHinting"), 1)
    end
end)
H.test("old sheet close cannot restore hinting on a replacement reader", function()
    local config = fixture(); config:onTapShowConfigMenu(); f.R.instance = {}; closeTop()
    H.eq(countEvent("RestoreHinting"), 0); H.eq(f.closed, 1)
end)
H.test("duplicate close restores native hinting at most once", function()
    local config = fixture(); config:onTapShowConfigMenu()
    local window = UI:getTopmostVisibleWidget(); closeTop(); window:onCloseWidget()
    H.eq(countEvent("RestoreHinting"), 1)
end)
H.test("only the new bottom-menu preference is written by its explicit switch", function()
    fixture(); local changed = 0
    local rows = M.readerPanelItems(function() changed = changed + 1 end)
    H.eq(#rows, 8); assert(rows[1].checked_func()); H.eq(#f.writes, 0)
    rows[1].callback(); H.eq(f.preference, false); assert(not rows[1].checked_func())
    H.eq(f.writes[1], "orbitui_reader_bottom_panel"); H.eq(changed, 1)
end)
H.test("incomplete or foreign config modules are never patched", function()
    fixture(); B.detach(f.ui)
    f.ui.config = {}; B.attach(f.ui); H.eq(f.ui.config.onTapShowConfigMenu, nil)
    f.ui.config = { ui = {}, onTapShowConfigMenu = ordinary.onTapShowConfigMenu, onSwipeShowConfigMenu = ordinary.onSwipeShowConfigMenu }
    B.attach(f.ui); H.eq(f.ui.config.onTapShowConfigMenu, ordinary.onTapShowConfigMenu)
end)

local native = os.getenv("ORBITUI_NATIVE_READER_CONFIG")
if native then
    local env = setmetatable({ require = function(name)
        if name == "ui/widget/configdialog" then return Dialog end
        if name == "ui/uimanager" then return setmetatable({}, { __index = function(_, key) return UI[key] end }) end
        if name == "ui/event" then return Event end
        if name == "device" then return { isTouchDevice = function() return true end } end
        if name == "ui/widget/container/inputcontainer" then return W end
        if name == "gettext" then return function(s) return s end end
        return {}
    end, G_defaults = { readSetting = function() return { x = 0, y = .9, w = 1, h = .1 } end } }, { __index = _G })
    if setfenv then prototype = setfenv(assert(loadfile(native)), env)()
    else prototype = assert(loadfile(native, "t", env))() end
    H.test("whole native ReaderConfig keeps all six native zones and routes tap/north-pan through the instance hook", function()
        local config = fixture(); config:initGesListener()
        H.eq(#f.zones, 6); H.eq(f.zones[1].id, "readerconfigmenu_tap")
        H.eq(f.zones[6].id, "readerconfigmenu_ext_pan")
        assert(f.zones[1].handler()); H.eq(f.opened, 1); closeTop()
        assert(f.zones[6].handler{ direction = "north" }); H.eq(f.opened, 2); closeTop()
        f.preference = false; f.zones[1].handler(); assert(config.config_dialog)
        H.eq(config.config_dialog.panel_index, 3); H.eq(f.opened, 2)
        closeTop(); H.eq(config.config_dialog, nil)
    end)
    H.test("whole native ShowConfigMenu escape keeps DisableHinting/HandledAsSwipe/RestoreHinting and last panel", function()
        local config = fixture(); config:onTapShowConfigMenu(); closeTop()
        config:onShowConfigMenu(); assert(config.config_dialog); H.eq(config.config_dialog.panel_index, 3)
        H.eq(f.opened, 1); H.eq(countEvent("DisableHinting"), 2); H.eq(countEvent("HandledAsSwipe"), 2)
        config.config_dialog.panel_index = 5; closeTop(); H.eq(config.last_panel_index, 5)
        H.eq(countEvent("RestoreHinting"), 2)
    end)
end
H.finish()
