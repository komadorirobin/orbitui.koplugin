package.path = "./?.lua;./components/simpleui/?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local file = assert(io.open("components/simpleui/" .. path))
    local text = file:read("*a"); file:close(); return text
end
local function run(text, env)
    setmetatable(env, { __index = _G })
    if setfenv then local fn = assert(loadstring(text)); setfenv(fn, env); return fn() end
    return assert(load(text, "SimpleUI 3.0 regression", "t", env))()
end
local function part(text, first, last)
    local start = assert(text:find(first, 1, true))
    return text:sub(start, assert(text:find(last, start, true)) - 1)
end
local noop = function() end
local data, fail
local store = {
    get = function(_, key) return data[key] end,
    set = function(_, key, value) data[key] = value end,
    setNoFlush = function(_, key, value)
        if fail then error("unwritable settings") end
        data[key] = value
    end,
    isTrue = function(_, key) return data[key] == true end,
    delNoFlush = function() error("must retain rollback keys") end,
    flush = noop,
}
local deps = {
    ["infra/sui_store"] = store,
    ["infra/sui_i18n"] = { translate = function(text) return text end },
    ["features/sui_style"] = { badgeChoice = function(value) return value end },
    ["features/library/sui_label_options"] = {},
    ["infra/sui_config"] = { setScaleByKey = function(n, key) store:setNoFlush(key, n) end },
    logger = { info = noop },
}
local CE = run(read("features/sui_cover_elements.lua"), {
    require = function(name) return assert(deps[name], name) end,
})
H.test("3.0 badge and folder migrations copy preferences and retain rollback keys", function()
    data = { simpleui_fc_overlay_pages = false, simpleui_fc_progress_mode = "none",
        simpleui_fc_new_mode = "ribbon", simpleui_fc_badge_scale = 130,
        simpleui_fc_folder_style = "quad", simpleui_fc_hide_spine = true,
        simpleui_fc_label_mode = "hidden", simpleui_fc_label_opacity = 46,
        simpleui_style_badge_new_type = "badge" }
    local old = {}; for key, value in pairs(data) do old[key] = value end
    CE.migrateLegacyBadges(); CE.migrateLegacyFolder()
    for key, value in pairs(old) do H.eq(data[key], value) end
    H.eq(data.simpleui_style_badge_pages_show, false)
    H.eq(data.simpleui_style_badge_progress_show, false)
    H.eq(data.simpleui_style_badge_new_type, "badge")
    H.eq(data.simpleui_style_badge_size, 130)
    H.eq(data.simpleui_style_folder_type, "quad")
    H.eq(data.simpleui_style_folder_stack_show, false)
    H.eq(data.simpleui_style_folder_name_show, false)
    H.eq(data.simpleui_style_folder_name_opacity, 46)
    data.simpleui_style_folder_type = "auto"
    CE.migrateLegacyFolder(); H.eq(data.simpleui_style_folder_type, "auto")
end)
local migrations = part(read("main.lua"), "        -- Settings migration v12:",
    "        -- Apply the saved UI font preference")
H.test("new migrations retry after failure and honor embedded deferral", function()
    data = { simpleui_fc_folder_style = "quad", simpleui_fc_overlay_pages = false }
    fail = true
    local imports = { ["features/sui_cover_elements"] = CE,
        ["features/library/sui_foldercovers"] = { migrateLegacyCaptions = noop } }
    local env = { SUISettings = store, require = function(name) return assert(imports[name]) end }
    run(migrations, env)
    H.eq(data.simpleui_settings_migrated_v12, nil)
    H.eq(data.simpleui_settings_migrated_v13, nil)
    fail = false; env.defer_defaults_until_settings_migrated = true
    run(migrations, env); H.eq(data.simpleui_settings_migrated_v13, nil)
    env.defer_defaults_until_settings_migrated = false
    run(migrations, env)
    H.eq(data.simpleui_settings_migrated_v12, true)
    H.eq(data.simpleui_settings_migrated_v13, true)
    H.eq(data.simpleui_fc_folder_style, "quad")
end)
H.test("new chart and session caches retry failed DB queries within the same day", function()
    local source = read("modules/module_stats_provider.lua")
    for _, spec in ipairs({
        { "function SP.getSessionRecords(", "-- Chart data", "fetchSessionRecords" },
        { "function SP.getChartData(", "-- Year data", "fetchChartData" },
        { "function SP.getYearData(", "-- Main entry point", "fetchYearData" },
    }) do
        local start = assert(source:find(spec[1], 1, true))
        local finish = assert(source:find("\nend", start, true)) + 3
        local attempts = 0
        local env = { SP = {}, RECORDS_WINDOW_DAYS = 90, [spec[3]] = function()
            attempts = attempts + 1
            if attempts == 1 then return false end
            return { recovered = true }
        end }
        run(source:sub(start, finish), env)
        local getter; for _, fn in pairs(env.SP) do getter = fn end
        H.eq(getter(nil), nil); H.eq(attempts, 0)
        H.eq(getter({}), nil)
        H.eq(getter({}).recovered, true)
        H.eq(getter({}).recovered, true); H.eq(attempts, 2)
    end
end)
H.test("new layout model activates through explicit width or movement edits", function()
    local source = read("infra/sui_layout.lua")
    local methods = part(source, "function LayoutService.setSpan(", "return LayoutService")
    local L = { findPage = function() return { modules = { "a", "b" } } end,
        pageSpans = function() return { "a", "b" }, { a = 3, b = 3 } end }
    local Bento = dofile("components/simpleui/infra/sui_bento.lua")
    run(methods, { LayoutService = L, Bento = Bento,
        require = function() return { isBentoAutofit = function() return true end, setBentoSpan = noop } end })
    local layout = { pages = {} }
    L.setSpan(layout, "home_", "a", 2); H.eq(layout.bento_model, 3)
    local other = {}; H.eq(other.bento_model, nil)
    L.move(other, "other_", "a", "right"); H.eq(other.bento_model, 3)
end)
H.test("missing session-query results remain retryable instead of becoming zero records", function()
    local source = read("modules/module_stats_provider.lua")
    local start = assert(source:find("local function fetchSessionRecords(", 1, true))
    local finish = assert(source:find("\nend", start, true)) + 3
    local fetch = run(source:sub(start, finish) .. "\nreturn fetchSessionRecords", {
        SESSION_GAP_SECS = 600, SESSION_MIN_SECS = 60,
        logger = { warn = noop }, rownum = function(value) return tonumber(value) or 0 end,
    })
    H.eq(fetch({ exec = function() return nil end }, 0), false)
    H.eq(fetch({ exec = function() error("database is locked") end }, 0), false)
    local good = fetch({ exec = function() return { {2}, {600}, {300}, {12}, {900} } end }, 0)
    H.eq(good.sessions, 2); H.eq(good.longest_secs, 600)
end)
H.test("renamed Reading Stats path retains its legacy module alias", function()
    local native = {}
    local result = run(read("modules/module_reading_stats.lua"), {
        require = function(name) H.eq(name, "modules/reading_stats/module_reading_stats"); return native end,
    })
    H.eq(result, native)
end)
H.test("new native-widget scope supports Lua 5.1 and preserves nil return values", function()
    local native = run(read("features/dialogs/sui_native_widgets.lua"), {
        table = {}, unpack = table.unpack or unpack,
        require = function(name)
            if name == "logger" then return { warn = noop } end
            return {}
        end,
    })
    local function values(a, b, c) H.eq(a, "one"); H.eq(b, nil); H.eq(c, "three"); return select("#", a, b, c) end
    H.eq(values(native.showOverWindows(function() return "one", nil, "three" end)), 3)
    local ok, err = pcall(native.showOverWindows, function() error("scoped error", 0) end)
    H.eq(ok, false); H.eq(err, "scoped error")
end)
H.test("night-mode hook keeps later wrappers and disables stale owners on teardown", function()
    local source = read("infra/sui_patches.lua")
    local helpers = part(source, "local function _acquireHooks", "-- Ensure the goal-tap")
    local code = part(source, 'local NIGHT_MODE_STATE =', '-- installAll / teardownAll')
    local ui, M, changes, native_calls = {}, {}, 0, 0
    function ui:ToggleNightMode() native_calls = native_calls + 1; return "native", nil, 3 end
    local env = { M = M, UIManager = ui, _live_plugin = {},
        SUISettings = { invalidateDerived = function() changes = changes + 1 end },
        SUIWallpaper = { onNightModeChanged = noop },
        _pack = function(...) return { n = select("#", ...), ... } end,
        _unpack = table.unpack or unpack,
        require = function() return { color = noop, secondaryColor = noop } end }
    run(helpers .. code, env)
    local owner, other = {}, {}
    M.patchNightMode(owner); M.patchNightMode(other)
    local inner = ui.ToggleNightMode
    ui.ToggleNightMode = function(...) return inner(...) end
    local external = ui.ToggleNightMode
    M.unpatchNightMode(owner); ui:ToggleNightMode(); H.eq(changes, 1)
    M.unpatchNightMode(other); H.eq(ui.ToggleNightMode, external)
    local a, b, c = ui:ToggleNightMode()
    H.eq(a, "native"); H.eq(b, nil); H.eq(c, 3); H.eq(changes, 1)
    M.patchNightMode(owner); ui:ToggleNightMode(); H.eq(changes, 2)
    M.unpatchNightMode(owner); H.eq(native_calls, 3)
end)
H.test("3.0 section labels stay fresh, scoped and restorable after hiding", function()
    local W = H.widget()
    local freed, hidden, scale = 0, false
    function W:getSize() return { w = 20, h = 12 } end
    function W:free() freed = freed + 1 end
    local deps = {
        ["infra/sui_config"] = {
            isLabelHidden = function() return hidden end,
            getSectionLabelScale = function(id, pfx)
                H.eq(id, "recent"); H.eq(pfx, "custom_"); return 1.5
            end,
        },
        ["features/sui_label_style"] = {
            color = function() return nil end, extraGap = function() return 0 end,
            signature = function() return "plain" end,
            makeText = function(opts) scale = opts.scale; return W:new(opts) end,
        },
        ["engines/sui_page_nav"] = {}, ["infra/sui_core"] = { PAD = 1, LABEL_PAD_BOT = 2 },
    }
    local labels = run(read("engines/sui_section_label.lua"), { require = function(name)
        return deps[name] or W
    end })
    local mod = { id = "recent", _section_label = "Recent", label = nil }
    local desc = labels.describe(mod, {})
    H.eq(desc.text, "Recent")
    local cache = {}
    local a = labels.get(cache, "recent", desc, 100, 1, nil, false, nil, "custom_")
    local b = labels.get(cache, "recent", desc, 100, 1, nil, false, nil, "custom_")
    assert(a ~= b); H.eq(next(cache), nil); H.eq(scale, 1.5)
    a:free(); b:free(); H.eq(freed, 2)
    hidden = true; H.eq(labels.describe(mod, {}), nil)
    hidden = false; H.eq(labels.describe(mod, {}).text, "Recent")
end)
H.finish()
