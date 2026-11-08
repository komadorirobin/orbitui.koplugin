-- Real SimpleUI SettingsWindow, MenuTable, ListRow, input and navigation.
-- Only KOReader display/font/filesystem/network boundaries are substituted;
-- builder warnings and callbacks swallowed by native pcall must fail tests.
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local language, saved, warnings, notices, windows = "en", {}, {}, {}, {}
G_reader_settings = { readSetting = function(_, k) return k == "language" and language or saved[k] end }
local tr = require("core/orbitui_i18n")
local W = H.widget()
function W:getSize() return self.dimen or { w = self.width or 10, h = self.height or 20 } end
local VG, HG = W:extend{}, W:extend{}
function VG:getSize()
    local w, h = 0, 0
    for _, child in ipairs(self) do local d = child:getSize(); w = math.max(w, d.w); h = h + d.h end
    return { w = w, h = h }
end
function HG:getSize()
    local w, h = 0, 0
    for _, child in ipairs(self) do local d = child:getSize(); w = w + d.w; h = math.max(h, d.h) end
    return { w = w, h = h }
end
local Text = W:extend{}
function Text:init() assert(type(self.text) == "string", "native text must be a string") end
local Screen = { getWidth = function() return 1264 end, getHeight = function() return 1680 end,
    scaleBySize = function(_, n) return n end }
package.loaded.device = { screen = Screen, hasDPad = function() return false end,
    isTouchDevice = function() return true end }
for _, path in ipairs{
    "container/bottomcontainer", "container/centercontainer", "container/framecontainer",
    "container/inputcontainer", "container/leftcontainer", "container/rightcontainer",
    "linewidget", "overlapgroup", "verticalspan", "horizontalspan", "buttondialog", "eventlistener",
} do package.loaded["ui/widget/" .. path] = W end
package.loaded["ui/widget/verticalgroup"], package.loaded["ui/widget/horizontalgroup"] = VG, HG
package.loaded["ui/widget/textwidget"], package.loaded["ui/widget/textboxwidget"] = Text, Text
package.loaded["ui/geometry"], package.loaded["ui/gesturerange"] = W, W
package.loaded["ui/bidi"] = {}
package.loaded["ui/font"] = { getFace = function(_, _, size) return { size = size } end }
package.loaded["ui/size"] = { padding = { large = 10 }, line = { thin = 1 } }
package.loaded["ffi/blitbuffer"], package.loaded["ffi/util"] = {}, { template = function(s) return s end }
package.loaded.logger = { dbg = function() end, warn = function(...)
    warnings[#warnings + 1] = table.concat({...}, " ")
end }
package.loaded["ui/uimanager"] = { nextTick = function() end, setDirty = function() end }
package.loaded["infra/sui_backdrop"] = { RoundedFrame = W }
package.loaded["infra/sui_i18n"] = { translate = tr }
package.loaded["infra/sui_datenames"] = {}
package.loaded["features/sui_style"] = { FACE_REGULAR = "regular", FACE_ICONS = "icons",
    FS_BODY = 20, FS_DETAIL = 16, FS_CAPTION = 16, FS_TITLE = 24,
    COLOR = { text_primary = "black", text_dim = "gray", gray_strong = "gray" },
    accent = function(c) return c end, icon = function(s) return s end,
    selectionIcon = function(_, selected) return selected and "checked" or "unchecked" end }
package.loaded["infra/sui_core"] = {
    getPortraitDims = function() return 1264, 1680 end, getLandscapeFactor = function() return 1 end,
    makeAccentText = function(o) return Text:new(o) end,
    makeColoredText = function(o) return Text:new(o) end,
    runWithTapFeedback = function(_, fn) return fn() end,
}
package.loaded["infra/sui_config"] = { isNavpagerEnabled = function() return false end }
package.loaded["infra/sui_layout"] = { load = function() return { pages = {} } end }
package.loaded["features/dialogs/sui_bento_sheet"], package.loaded["infra/sui_bento"] = {}, {}
package.loaded["modules/moduleregistry"] = { list = function() return {} end }
package.loaded["infra/sui_store"] = {
    readSetting = function(_, k) return saved[k] end,
    saveSetting = function(_, k, v) saved[k] = v end,
}
package.loaded["core/orbitui_context"] = { notify = function(t) notices[#notices + 1] = t end }

local SUI = H.componentModule(root, "engines/sui_window")
package.loaded["engines/sui_window"] = SUI
-- Retain native new/_repaint/navigation/menu/rows/input, but intercept the
-- display attachment and final frame composition (not native text shaping).
function SUI:show() windows[#windows + 1] = self; self:_repaint(); return self end
function SUI:_maxPageHeight() return self._modal_h - 100 end
function SUI:_rebuildFrame(_, rows) self.rows = rows end
package.loaded["screens/sui_settings_window"] = H.componentModule(root, "screens/sui_settings_window")
local Settings = require("adapters/orbitui_dashboard_settings")
local Dashboard = require("adapters/orbitui_dashboard")
local Store = require("adapters/orbitui_module_store")
local StoreModel = require("core/orbitui_module_store")
local catalog, finish, requests, selected, verifications = {}, nil, 0, nil, 0
local source = { account = string.rep("a", 64), section = "collections", id = 7, title = "日常 · Slice of life" }
package.loaded["adapters/orbitui_bookorbit_rows"] = {
    catalog = function() return catalog, nil, #catalog > 0 and 1794132000 or nil end,
    refresh = function(_, opts) requests = requests + 1; finish = opts.on_done end,
    snapshot = function() return { files = {} } end, caption = function() return "Cached" end,
}
Store.store = function() return { catalog = function() return StoreModel.bundled() end,
    status = function() verifications = verifications + 1; return "missing" end } end
local function reset(lang)
    language, saved, warnings, notices, windows = lang or "en", {}, {}, {}, {}
    catalog, finish, requests, selected, verifications = {}, nil, 0, nil, 0
end
local function text(widget)
    if widget.text then return widget.text end
    for _, child in ipairs(widget) do local t = text(child); if t then return t end end
end
local function row(win, title)
    for _, widget in ipairs(win.rows) do if text(widget) == title then return widget end end
    error("Missing visible row: " .. title .. "; " .. table.concat(warnings, " / "))
end
local function tap(win, title)
    local r = row(win, title)
    assert(r[1].onTap, "Expected a tappable native row: " .. title)
    r[1]:onTap()
end
local function healthy(win, count)
    H.eq(#warnings, 0, table.concat(warnings, " / "))
    H.eq(#win.rows, count)
end
local function openSources()
    return package.loaded["screens/sui_settings_window"]:show(nil, {{ id = "nested_menu", params = {
        title = tr("BookOrbit shelves and smartscopes"), items_func = function(ctx)
            return {{ text = tr("BookOrbit shelves and smartscopes"), sub_item_table_func = function()
                return Settings.bookOrbitSources(ctx.repaint, function(s) selected = s end)
            end }}
        end,
    } }})
end
for _, lang in ipairs{ "en", "sv" } do
    H.test(lang .. ": opening the source submenu with an existing cache does not throw from native tap", function()
        reset(lang); catalog = { source }
        local win = openSources(); healthy(win, 1)
        tap(win, tr("BookOrbit shelves and smartscopes")); healthy(win, 4)
        tap(win, tr("Shelf") .. ": " .. source.title); H.eq(selected, source)
        H.eq(requests, 0)
    end)
    H.test(lang .. ": shelf refresh renders saved sources; back/reenter and selection do not crash", function()
        reset(lang)
        local win = openSources()
        tap(win, tr("BookOrbit shelves and smartscopes")); healthy(win, 3)
        tap(win, tr("Refresh shelves and smartscopes")); H.eq(requests, 1)
        catalog = { source,
            { account = source.account, section = "libraries", id = 2, title = "Books" },
            { account = source.account, section = "smart-scopes", id = 9, title = "Manga" } }
        finish{ ok = true }; healthy(win, 6)
        H.eq(#notices, 1); H.eq(notices[1], tr("BookOrbit sources refreshed. Select a source below."))
        notices = {} -- dismiss notification; list still has all three types
        row(win, tr("Library") .. ": Books"); row(win, tr("Smartscope") .. ": Manga")
        win:pop(); healthy(win, 1)
        tap(win, tr("BookOrbit shelves and smartscopes")); healthy(win, 6)
        tap(win, tr("Shelf") .. ": " .. source.title); H.eq(selected, source)
        win:close()
        win = openSources(); tap(win, tr("BookOrbit shelves and smartscopes")); healthy(win, 6)
        H.eq(requests, 1, "cached reopening must not request the network")
    end)
    H.test(lang .. ": module library renders bundled plugin, native submenu and details", function()
        reset(lang)
        Store.show(); local win = assert(windows[1], "Module window not shown")
        healthy(win, 2); H.eq(verifications, 1)
        local label = "Silverfish 2.0.0 · " .. tr("Desktop adapter test")
        tap(win, label); healthy(win, 3)
        row(win, tr("Information and test scope")); row(win, tr("Not installed")); row(win, tr("Install plugin"))
        package.loaded["ui/widget/textviewer"] = W
        local viewer
        package.loaded["ui/uimanager"].show = function(_, w) viewer = w end
        tap(win, tr("Information and test scope"))
        assert(viewer and viewer.text:find("Silverfish 2.0.0", 1, true), "native callback was swallowed")
        win:pop(); healthy(win, 2); H.eq(verifications, 1)
        win:close(); Store.show(); healthy(windows[2], 2); H.eq(verifications, 2)
    end)
    H.test(lang .. ": BookOrbit display menu builds both choices and persists the selected mode", function()
        reset(lang)
        assert(Settings.add({ kind = "bookorbit", source = source }, function() end, "simpleui_hs_"))
        local id = Dashboard.readConfig("simpleui_hs_").modules[1].id
        local win = Settings.show("simpleui_hs_", {}, id)
        tap(win, tr("Display")); healthy(win, 2)
        row(win, tr("Cover row")); tap(win, tr("Carousel")); healthy(win, 2)
        H.eq(Dashboard.readConfig("simpleui_hs_").modules[1].view, "carousel")
        tap(win, tr("Cover row")); H.eq(Dashboard.readConfig("simpleui_hs_").modules[1].view, "row")
    end)
end
H.finish()
