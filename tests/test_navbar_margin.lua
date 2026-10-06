package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Integration = require("adapters/orbitui_ui")
local noop = function() end
local function source(path)
    local f = assert(io.open(path))
    local s = f:read("*a"); f:close(); return s
end
local function run(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then
        local fn = assert(loadstring(code)); setfenv(fn, env); return fn()
    end
    return assert(load(code, "navbar margin", "t", env))()
end
local function method(src, name, env)
    run(assert(src:match("(function " .. name .. "%b().-\nend)")), env)
end
local config_source = source("components/simpleui/infra/sui_config.lua")
local bar_source = source("components/simpleui/screens/sui_bottombar.lua")
local shelf_source = source("components/bookshelf/lib/bookshelf_widget.lua")
local engine_source = source("components/simpleui/engines/sui_screen_engine.lua")
local core_source = source("components/simpleui/infra/sui_core.lua")
local settings, Config, BB = {}, {}, {}
local Store = {
    get = function(_, key) return settings[key] end,
    set = function(_, key, v) settings[key] = v end,
    readSetting = function(_, key) return settings[key] end,
    nilOrTrue = function(_, key) return settings[key] ~= false end,
    isTrue = function(_, key) return settings[key] == true end,
}
local sw, sh, dpi = 1264, 1680, 2
local Screen = { getWidth = function() return sw end, getHeight = function() return sh end,
    scaleBySize = function(_, n) return n * dpi end }
run(assert(config_source:match("(%-%- Bottom Margin.-)\n%-%- Reading Stats Text Scale")), {
    M = Config, SUISettings = Store, math_max = math.max, math_min = math.min, math_floor = math.floor,
})
Config.getBarSizePct = function() return 100 end
Config.loadTabConfig = function() return { "home", "prose", "comics", "power" } end
Config.getIconScalePct = function() return 100 end
Config.getNavbarLabelScalePct = function() return 100 end
run(assert(bar_source:match("(local _dim = {}.-)\n%-%- Pagination bar helpers")), {
    M = BB, Config = Config, Screen = Screen, SUISettings = Store,
})
local Box = { new = function(_, args) return args end }
local UI, dirty, shown, stack = {}, {}, {}, {}
local UIManager = {
    isWidgetShown = function(_, w) return shown[w] == true end,
    setDirty = function(_, w) dirty[w] = (dirty[w] or 0) + 1 end,
}
local Topbar = { TOTAL_TOP_H = function() return 0 end }
settings.simpleui_topbar_enabled = false
BB.buildBarWidget = function() return {} end
BB.sepColor = function() return "gray" end
BB.resizePaginationButtons, BB.getPaginationIconSize = noop, function() return 24 end
UI.getContentHeight = function() return sh - BB.TOTAL_H() end
UI.getContentTop = function() return 0 end
UI.getWindowStack = function() return stack end
method(core_source, "M.wrapWithNavbar", {
    M = UI, _TB = function() return Topbar end, _BB = function() return BB end,
    Screen = Screen, SUISettings = Store, SUIStyle = { COLOR = {} },
    Geom = function() return Box end, FrameContainer = function() return Box end,
    OverlapGroup = function() return Box end,
})
method(core_source, "M.applyNavbarState", { M = UI, _TB = function() return Topbar end })
local calls = 0
BB.rebuildAllNavbars = function() calls = calls + 1; BB.invalidateDimCache() end
package.loaded["infra/sui_core"] = UI
package.loaded["infra/sui_patches"] = {}
package.loaded["ui/uimanager"] = UIManager
package.loaded["ui/widget/linewidget"] = Box
method(bar_source, "M.rewrapAllWidgets", {
    M = BB, Config = Config, UIManager = UIManager, logger = { warn = error },
})
Integration.wrap("screens/sui_bottombar", BB)

local fm, plugin = {}, { active_action = "comics", _registerTouchZones = noop }
plugin.ui = fm
local function context()
    if BB.TOTAL_H() == 0 then return nil end
    return { fm = fm, plugin = plugin, total_h = BB.TOTAL_H(),
        top_sp = BB.TOP_SP(), bot_sp = BB.BOT_SP(), bar_h = BB.BAR_H(),
        side_m = BB.SIDE_M(), sep_h = BB.SEP_H(), bottombar = BB,
        tabs = Config.loadTabConfig(), active_action = plugin.active_action }
end
local Shelf = {}
local env = { BookshelfWidget = Shelf, UIManager = UIManager,
    Geom = Box, OverlapGroup = Box, SIMPLEUI_USE_OFFICIAL_FOOTER = true,
    logger = { dbg = noop }, unpack = unpack or table.unpack }
for _, name in ipairs({ "_wrapWithSimpleUIBottomBar", "_simpleUIReservedBottom",
    "_simpleUIBarTopY", "_isInSimpleUIBottomBand", "_rebuildIfSimpleUIContextChanged" }) do
    method(shelf_source, "BookshelfWidget:" .. name, env)
end
function Shelf:_getSimpleUIBarContext() return context() end
function Shelf:_rebuild()
    self.builds = self.builds + 1
    self._simpleui_bar_ctx = self:_getSimpleUIBarContext()
    self.tree = self:_wrapWithSimpleUIBottomBar({ content = true })
end
function Shelf:_startStatusTimer() self.timers = self.timers + 1 end
Integration.wrap("lib/bookshelf_widget", Shelf)
local shelf = setmetatable({ width = sw, height = sh, builds = 0, timers = 0,
    profile_key = "comics", chip = "manga", _cursor = 21,
    _drilldown_path = { { folder = "/Manga/Series" } },
}, { __index = Shelf })
local home = { _navbar_inner = { dimen = { w = sw, h = 100 } }, _navbar_container = {} }
local function apply(pct)
    Config.setBottomMarginPct(pct)
    BB.invalidateDimCache()
    BB.rewrapAllWidgets(plugin)
end

H.test("normal navbar moves down as the saved margin decreases", function()
    stack = { { widget = home } }
    apply(100)
    local y = home._navbar_bar.overlap_offset[2]
    local old_h = home._navbar_content_h
    apply(0)
    H.eq(home._navbar_bar.overlap_offset[2] - y, 24)
    H.eq(home._navbar_content_h - old_h, 24)
    H.eq(Config.getBottomMarginPct(), 0)
    apply(300)
    H.eq(home._navbar_bar.overlap_offset[2], sh - 192 - 4 - 72)
end)

H.test("an embedded shelf under settings immediately adopts the same margin", function()
    package.loaded["lib/bookshelf_widget"] = Shelf
    Shelf.live = shelf; shown[shelf] = true
    shelf:_rebuild()
    stack = { { widget = home }, { widget = shelf }, { widget = { settings = true } } }
    apply(100)
    local bar = shelf.tree[#shelf.tree]
    local y, reserved, builds = bar.overlap_offset[2], shelf:_simpleUIReservedBottom(), shelf.builds
    apply(0)
    H.eq(shelf.builds, builds + 1)
    H.eq(shelf.tree[#shelf.tree].overlap_offset[2] - y, 24)
    H.eq(reserved - shelf:_simpleUIReservedBottom(), 24)
    H.eq(shelf:_simpleUIBarTopY(), shelf.tree[#shelf.tree].overlap_offset[2])
    H.eq(shelf:_isInSimpleUIBottomBand({ y = sh - BB.TOTAL_H() - 1 }), false)
    H.eq(shelf:_isInSimpleUIBottomBand({ y = sh - BB.TOTAL_H() }), true)
    H.eq(shelf.profile_key, "comics"); H.eq(shelf.chip, "manga"); H.eq(shelf._cursor, 21)
    H.eq(shelf._drilldown_path[1].folder, "/Manga/Series")
    H.eq(shelf._orbitui_navbar_pending, nil)
end)

H.test("a warm off-stack shelf defers work without raising itself over Home", function()
    shown[shelf] = false
    local builds, paints = shelf.builds, dirty[shelf]
    apply(100); apply(300)
    H.eq(shelf.builds, builds); H.eq(dirty[shelf], paints)
    H.eq(shelf._orbitui_navbar_pending, true)
    shown[shelf] = true
    H.eq(shelf:_rebuildIfSimpleUIContextChanged(), true)
    H.eq(shelf.builds, builds + 1)
    H.eq(shelf:_simpleUIReservedBottom(), BB.TOTAL_H())
    H.eq(shelf:_rebuildIfSimpleUIContextChanged(), false)
    H.eq(shelf.builds, builds + 1)
end)

H.test("a normal shelf rebuild consumes pending chrome work only once", function()
    shown[shelf] = false
    apply(0)
    local builds = shelf.builds
    shelf:_rebuild()
    H.eq(shelf._orbitui_navbar_pending, nil)
    H.eq(shelf:_rebuildIfSimpleUIContextChanged(), false)
    H.eq(shelf.builds, builds + 1)
end)

H.test("disabling and restoring the navbar also reflows the embedded shelf", function()
    shown[shelf] = true
    settings.simpleui_bar_enabled = false
    apply(100)
    H.eq(shelf._simpleui_bar_ctx, nil)
    H.eq(shelf.tree.content, true)
    H.eq(shelf:_simpleUIReservedBottom(), 0)
    settings.simpleui_bar_enabled = true
    apply(100)
    H.eq(shelf:_simpleUIReservedBottom(), BB.TOTAL_H())
end)

H.test("icon-only refreshes do not rebuild shelves; suspended and closed shelves are left alone", function()
    local builds = shelf.builds
    BB.rebuildAllNavbars(plugin)
    H.eq(shelf.builds, builds); H.eq(calls, 1)
    plugin._simpleui_suspended = true
    apply(0)
    H.eq(shelf.builds, builds)
    plugin._simpleui_suspended = nil
    Shelf.live = nil
    apply(100)
    H.eq(shelf.builds, builds)
end)

H.test("margin geometry scales in portrait and landscape without changing icon size", function()
    for _, size in ipairs({ { 1264, 1680, 2 }, { 1680, 1264, 2 }, { 600, 800, 1 } }) do
        sw, sh, dpi = size[1], size[2], size[3]
        apply(100)
        local y, icon = home._navbar_bar.overlap_offset[2], BB.ICON_SZ()
        apply(0)
        H.eq(home._navbar_bar.overlap_offset[2] - y, 12 * dpi)
        H.eq(BB.ICON_SZ(), icon)
    end
end)

local ScreenWidget = {}
method(engine_source, "ScreenWidget:_refreshImmediate", {
    ScreenWidget = ScreenWidget, UIManager = UIManager,
})
H.test("Home and custom-screen footer geometry follows a changed navbar without losing book caches", function()
    for _, id in ipairs({ "hs", "custom" }) do
        local cache, swaps, updates = {}, 0, 0
        local w = setmetatable({ _id = id, _navbar_container = {}, _layout_content_h = 1450,
            _navbar_content_h = 1474, _cached_books_state = cache,
            _initLayout = function(self)
                self._layout_content_h = self._navbar_content_h
                return { footer_height = self._navbar_content_h }
            end,
            _swapLayoutTree = function(self, tree)
                swaps = swaps + 1; self.tree = tree
            end,
            _updatePage = function(_, keep) H.eq(keep, true); updates = updates + 1 end,
        }, { __index = ScreenWidget })
        w:_refreshImmediate(true)
        H.eq(w.tree.footer_height, 1474); H.eq(swaps, 1); H.eq(updates, 1)
        H.eq(w._cached_books_state, cache)
        w:_refreshImmediate(true)
        H.eq(swaps, 1); H.eq(updates, 2)
        w._navbar_content_h = 1402
        w:_refreshImmediate(true)
        H.eq(w.tree.footer_height, 1402); H.eq(swaps, 2)
    end
end)
H.finish()
