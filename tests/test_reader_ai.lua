local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local M = require("adapters/orbitui_book_panel")
local choice, writes, ui, R, calls, pending, language
local function fixture()
    choice, writes, calls, pending, language = nil, {}, {}, nil, "en"
    ui = { document = { file = "/books/current.epub" } }
    R = { instance = ui }; package.loaded["apps/reader/readerui"] = R
    package.loaded.pluginloader = nil
    G_reader_settings = { readSetting = function(_, key) if key == "language" then return language end; return choice end,
        saveSetting = function(_, key, value) writes[#writes + 1] = { key, value }; choice = value end }
    local xray = { ui = ui, showFullXRayMenu = function() calls[#calls + 1] = "xray-menu" end }
    local koa = { ui = ui, action_service = { getAction = function(_, scope, id)
        H.eq(scope, "book"); H.eq(id, "xray"); return { cache_as_xray = true }
    end }, showCacheActionPopup = function(_, action, id, callback)
        H.eq(action.cache_as_xray, true); H.eq(id, "xray"); calls[#calls + 1] = "scope-popup"; pending = callback
    end, executeBookLevelAction = function(_, id) H.eq(id, "xray"); calls[#calls + 1] = "explicit-action" end }
    return xray, koa
end
H.test("unset and invalid preferences use automatic priority without persisting or loading plugins", function()
    local x, k = fixture()
    H.eq(M.readerAIChoice(), "auto"); H.eq(M.readerAI(ui), nil)
    ui.koassistant = k; H.eq(M.readerAI(ui).id, "koassistant")
    ui.xray = x; H.eq(M.readerAI(ui).id, "xray")
    choice = "unknown"; H.eq(M.readerAI(ui).id, "xray")
    H.eq(#writes, 0); H.eq(#calls, 0)
end)
H.test("manual selection never silently falls back; Hide always hides", function()
    local x, k = fixture(); ui.xray, ui.koassistant = x, k
    choice = "koassistant"; H.eq(M.readerAI(ui).id, "koassistant")
    ui.koassistant = nil; assert(M.readerAI(ui).unavailable)
    H.eq(M.openReaderAI(ui, M.readerAI(ui)), false)
    choice = "xray"; H.eq(M.readerAI(ui).plugin, x)
    ui.xray = nil; assert(M.readerAI(ui).unavailable)
    choice = "off"; H.eq(M.readerAI(ui), nil); H.eq(#calls, 0)
end)
H.test("only already-active reader-owned complete plugin instances qualify", function()
    local x, k = fixture(); ui.xray, ui.koassistant = x, k
    x.disabled = true; H.eq(M.readerAI(ui).id, "koassistant")
    k._disabled = true; H.eq(M.readerAI(ui), nil)
    x.disabled = nil; x.ui = {}; H.eq(M.readerAI(ui), nil)
    x.ui = ui; x.showFullXRayMenu = nil; H.eq(M.readerAI(ui), nil)
    ui.document = nil; H.eq(M.readerAI(ui), nil)
end)
H.test("active PluginLoader lookup supports callable HandlerSandbox methods but never requires a plugin", function()
    local x, k = fixture()
    local function callable(fn) return setmetatable({}, { __call = function(_, ...) return fn(...) end }) end
    x.showFullXRayMenu = callable(x.showFullXRayMenu)
    package.loaded.pluginloader = { getPluginInstance = callable(function(_, id) return id == "xray" and x or k end) }
    local selected = M.readerAI(ui); H.eq(selected.plugin, x)
    assert(M.openReaderAI(ui, selected)); H.eq(calls[1], "xray-menu")
    package.loaded.pluginloader.getPluginInstance = function() error("unavailable loader") end
    H.eq(M.readerAI(ui), nil)
end)
H.test("KOAssistant opens its native scope/cache chooser and never executes AI on navigation", function()
    local _, k = fixture(); ui.koassistant = k
    assert(M.openReaderAI(ui, M.readerAI(ui)))
    H.eq(#calls, 1); H.eq(calls[1], "scope-popup"); H.eq(#writes, 0)
    pending(); H.eq(#calls, 2); H.eq(calls[2], "explicit-action")
end)
H.test("custom non-X-Ray or disabled actions cannot bypass the native scope/cache chooser", function()
    local _, k = fixture(); ui.koassistant = k
    for _, action in ipairs{ {}, { cache_as_xray = false }, { cache_as_xray = true, enabled = false } } do
        k.action_service.getAction = function() return action end
        H.eq(M.openReaderAI(ui, M.readerAI(ui)), false)
    end
    H.eq(#calls, 0)
end)
H.test("stale selection, switched provider, replaced reader and changed book cannot execute an action", function()
    for _, mutate in ipairs{
        function() R.instance = {} end,
        function() ui.document = { file = "/books/other.epub" } end,
        function() choice = "off" end,
        function() ui.koassistant = {} end,
    } do
        local _, k = fixture(); ui.koassistant = k
        assert(M.openReaderAI(ui, M.readerAI(ui))); mutate(); pending(); H.eq(#calls, 1)
    end
    local x = fixture(); ui.xray = x
    local old = M.readerAI(ui); ui.xray = { ui = ui, showFullXRayMenu = x.showFullXRayMenu }
    H.eq(M.openReaderAI(ui, old), false); H.eq(#calls, 0)
end)
H.test("radio choices write only the namespaced preference on an explicit tap", function()
    fixture(); language = "sv"
    local changed = 0
    local items = M.readerAIItems(function() changed = changed + 1 end)
    H.eq(#items, 6); H.eq(items[1].enabled, false)
    assert(items[3].checked_func()); assert(items[3].text:find("Automatiskt", 1, true))
    H.eq(#writes, 0)
    for i, value in ipairs{ "auto", "xray", "koassistant", "off" } do
        items[i + 2].callback(); H.eq(writes[i][1], "orbitui_reader_ai"); H.eq(writes[i][2], value)
        assert(items[i + 2].checked_func())
    end
    H.eq(changed, 4); H.eq(#calls, 0)
end)
H.finish()
