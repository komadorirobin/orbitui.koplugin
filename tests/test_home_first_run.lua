package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")

local function read(path)
    local root = os.getenv("ORBITUI_SIMPLEUI_TEST_ROOT") or "components/simpleui"
    local f = assert(io.open(root .. "/" .. path))
    local source = f:read("*a"); f:close(); return source
end
local function run(source, env)
    if setfenv then
        local chunk = assert(loadstring(source)); setfenv(chunk, env); return chunk()
    end
    return assert(load(source, "Home first-run regression", "t", env))()
end
local function fixture(done)
    local f = { data = { simpleui_onboarding_done = done, custom_layout = "kept" },
        messages = {}, notices = {}, errors = {}, closed = {}, logs = 0, onboarding = 0, refreshes = 0 }
    local engine = {}
    f.engine = engine
    local modules, env = {}, {}
    setmetatable(env, { __index = function(_, key)
        if key ~= "logger" then return _G[key] end
    end })
    env.package = { loaded = {} }
    local ui = {
        show = function(_, widget)
            if widget.name == "homescreen" then
                f.shown = widget
                if f.paint_error then error(f.paint_error, 0) end
            else
                f.messages[#f.messages + 1] = widget.text
                f.notices[#f.notices + 1] = widget
                if f.notify_error then error("notification failed", 0) end
            end
        end,
        close = function(_, widget)
            f.closed[#f.closed + 1] = widget
            if f.close_hook then f.close_hook(widget) end
            if f.close_error then error("close failed", 0) end
        end,
    }
    modules["ui/uimanager"] = ui
    modules["ui/widget/infomessage"] = { new = function(_, opts) return opts end }
    modules["infra/sui_core"] = {}
    modules["infra/sui_i18n"] = { translate = function(text) return text end }
    modules.logger = {
        info = function() f.logs = f.logs + 1 end,
        err = function(...) local args = {...}; f.errors[#f.errors + 1] = table.concat(args, " ") end,
    }
    modules["infra/sui_store"] = {
        get = function(_, key) return f.data[key] end,
        set = function(_, key, value) f.data[key] = value end,
    }
    modules["modules/module_bookorbit_want"] = { scheduleAutoRefresh = function()
        f.refreshes = f.refreshes + 1
    end }
    modules["screens/sui_onboarding"] = { show = function(callback)
        f.onboarding = f.onboarding + 1
        if f.after_error then error(f.after_error, 0) end
        if callback then callback() end
    end }
    modules["engines/sui_screen_engine"] = engine
    env.require = function(name)
        if name == "screens/sui_homescreen" then
            if f.load_hook then f.load_hook() end
            if f.load_error then error(f.load_error, 0) end
            if f.invalid_home then return f.invalid_home end
            if not modules[name] then modules[name] = run(read(name .. ".lua"), env) end
        elseif name == "infra/sui_screen_nav" and not modules[name] then
            modules[name] = run(read(name .. ".lua"), env)
        end
        return assert(modules[name], "Unexpected require: " .. name)
    end
    -- Execute the real generic open factory and the entire real Home facade;
    -- stub only the native widget constructor, painting and surrounding services.
    env.ScreenEngine = engine
    env._sget = function(_, key) return engine[key] end
    env._sset = function(_, key, value) engine[key] = value end
    env.closeStaleHomescreens = function() end
    env.UIManager = ui
    env.ScreenWidget = { new = function(_, opts)
        if f.build_error then error(f.build_error, 0) end
        opts.name = "homescreen"; return opts
    end }
    local source = read("engines/sui_screen_engine.lua")
    local start = assert(source:find("function ScreenEngine._open(", 1, true))
    run(source:sub(start, assert(source:find("\nend", start, true)) + 3), env)
    engine.rebuildAllLayouts = function() f.rebuilt = true end
    engine.closeScreen = function(id) f.closed_id = id end
    f.require, f.modules, f.ui, f.env = env.require, modules, ui, env
    return f
end

H.test("fresh Home runs its actual post-open hook without a global logger", function()
    local f = fixture(nil)
    local home = f.require("screens/sui_homescreen")
    H.eq(home, f.engine)
    local qa, goal = function() end, function() end
    local widget = assert(home.show(qa, goal))
    H.eq(widget, f.shown); H.eq(widget._on_qa_tap, qa); H.eq(widget._on_goal_tap, goal)
    H.eq(widget.instance.id, "hs"); H.eq(widget.instance.pfx, "simpleui_hs_")
    H.eq(f.onboarding, 1); H.eq(f.refreshes, 1); H.eq(f.logs, 1)
    H.eq(f.rebuilt, true); H.eq(#f.errors, 0); H.eq(f.env.logger, nil)
    H.eq(f.data.custom_layout, "kept"); H.eq(f.data.simpleui_onboarding_done, nil)
end)
H.test("explicit false and existing true onboarding states retain their behavior", function()
    for _, done in ipairs({ false, true }) do
        local f = fixture(done)
        assert(f.require("screens/sui_homescreen").show())
        H.eq(f.onboarding, done and 0 or 1); H.eq(f.refreshes, 1)
        H.eq(f.data.simpleui_onboarding_done, done)
    end
end)
H.test("host-owned no-op onboarding still opens Home without resetting preferences", function()
    local f = fixture(nil)
    f.modules["screens/sui_onboarding"].show = function() end
    assert(f.require("screens/sui_homescreen").show())
    H.eq(f.onboarding, 0); H.eq(f.data.custom_layout, "kept"); H.eq(#f.errors, 0)
end)
H.test("a failed first-run hook closes its partial Home and reports the actual cause", function()
    local f = fixture(nil)
    f.after_error = "first-run hook exploded"
    H.eq(f.require("screens/sui_homescreen").show(), nil)
    H.eq(f.closed[1], f.shown); H.eq(f.closed[1]._navbar_closing_intentionally, true)
    H.eq(f.engine._instance, nil); H.eq(#f.messages, 1)
    H.eq(f.notices[1]._navbar_closing_intentionally, true)
    assert(f.messages[1]:find(f.after_error, 1, true))
    assert(f.errors[1]:find("stack traceback", 1, true))
    H.eq(f.data.custom_layout, "kept"); H.eq(f.data.simpleui_onboarding_done, nil)
end)
H.test("constructor and initial show failures are caught without resetting saved data", function()
    for _, key in ipairs({ "build_error", "paint_error" }) do
        local f = fixture(true); f[key] = key .. " exploded"
        H.eq(f.require("screens/sui_homescreen").show(), nil)
        H.eq(f.engine._instance, nil)
        assert(f.messages[1]:find(f[key], 1, true))
        H.eq(f.data.custom_layout, "kept"); H.eq(f.data.simpleui_onboarding_done, true)
    end
end)
H.test("failed cleanup and notifications do not turn a Home failure into an uncaught error", function()
    local f = fixture(nil)
    f.after_error, f.close_error, f.notify_error = "actual cause", true, true
    H.eq(f.require("screens/sui_homescreen").show(), nil)
    H.eq(f.engine._instance, nil)
    assert(f.errors[1]:find("actual cause", 1, true)); H.eq(#f.errors, 2)
end)
H.test("cleanup never erases a replacement instance installed by a later close hook", function()
    local f = fixture(nil); local replacement = {}
    f.after_error = "actual cause"
    f.close_hook = function() f.engine._instance = replacement end
    H.eq(f.require("screens/sui_homescreen").show(), nil)
    H.eq(f.engine._instance, replacement)
end)
H.test("load errors retain their first real cause across LuaJIT previous-error retries", function()
    local f = fixture(nil); local nav = f.require("infra/sui_screen_nav")
    f.load_error = "module 'missing_dependency' not found"
    H.eq(nav.loadHome(), nil)
    assert(f.messages[1]:find("missing_dependency", 1, true))
    f.load_error = "loop or previous error loading module 'screens/sui_homescreen'"
    H.eq(nav.loadHome(), nil)
    assert(f.messages[2]:find("missing_dependency", 1, true))
    assert(f.errors[1]:find("stack traceback", 1, true))
    f.load_error = nil
    H.eq(nav.loadHome(), f.engine); H.eq(f.data.custom_layout, "kept")
end)
H.test("an invalid Home module is reported instead of silently ignored", function()
    local f = fixture(nil); f.invalid_home = {}
    H.eq(f.require("infra/sui_screen_nav").loadHome(), nil)
    assert(f.messages[1]:find("show", 1, true))
end)
H.test("only newly failed owned screen sentinels are removed", function()
    local f = fixture(nil); local sentinel = assert(io.tmpfile())
    local loaded = f.env.package.loaded
    loaded.external_plugin = sentinel
    f.load_hook = function()
        loaded["screens/sui_homescreen"] = sentinel
        loaded["engines/sui_screen_engine"] = sentinel
    end
    f.load_error = "screen dependency failed"
    H.eq(f.require("infra/sui_screen_nav").loadHome(), nil)
    H.eq(loaded["screens/sui_homescreen"], nil)
    H.eq(loaded["engines/sui_screen_engine"], nil)
    H.eq(loaded.external_plugin, sentinel)
    local valid = {}
    loaded["engines/sui_screen_engine"] = valid
    f.load_hook = nil
    H.eq(f.require("infra/sui_screen_nav").loadHome(), nil)
    H.eq(loaded["engines/sui_screen_engine"], valid)
    sentinel:close()
end)
H.test("real require failures can be retried without poisoned Home engine sentinels", function()
    local f = fixture(nil)
    local home, engine = "screens/sui_homescreen", "engines/sui_screen_engine"
    local old_home, old_engine = package.loaded[home], package.loaded[engine]
    local pre_home, pre_engine = package.preload[home], package.preload[engine]
    local original_require = f.require
    local ok, err = pcall(function()
        package.loaded[home], package.loaded[engine] = nil, nil
        package.preload[home] = function() return require(engine) end
        package.preload[engine] = function() error("real dependency load failure", 0) end
        f.env.package = package
        f.env.require = function(name)
            if name == home then return require(name) end
            return original_require(name)
        end
        local nav = original_require("infra/sui_screen_nav")
        H.eq(nav.loadHome(), nil)
        H.eq(package.loaded[home], nil); H.eq(package.loaded[engine], nil)
        assert(f.messages[1]:find("real dependency load failure", 1, true))
        package.preload[engine] = function() return f.engine end
        package.preload[home] = function() return original_require(home) end
        H.eq(nav.loadHome(), f.engine)
    end)
    package.loaded[home], package.loaded[engine] = old_home, old_engine
    package.preload[home], package.preload[engine] = pre_home, pre_engine
    assert(ok, err)
end)
H.test("screen reopen retains built-in and custom identities through the shared loader", function()
    local f = fixture(true)
    f.engine.showCustomScreen = function(id) f.custom = id end
    local nav = f.require("infra/sui_screen_nav")
    nav.reopen("hs"); assert(f.shown)
    nav.reopen("custom_2"); H.eq(f.custom, "custom_2")
end)
H.test("Home action and automatic entry points use the reporting loader", function()
    local qa = read("features/sui_quickactions.lua")
    local start = assert(qa:find('            id    = "homescreen",', 1, true))
    local home = qa:sub(start, assert(qa:find('            id    = "collections",', start, true)))
    assert(home:find('require("infra/sui_screen_nav").loadHome()', 1, true))
    assert(not home:find('pcall(require, "screens/sui_homescreen")', 1, true))
    assert(not read("infra/sui_patches.lua"):find('pcall(require, "screens/sui_homescreen")', 1, true))
end)
H.test("the actual Home action reports load failure without a generic duplicate toast", function()
    local f = fixture(nil); f.load_error = "missing screen dependency"
    f.env._simpleui_plugin = function() return nil end
    f.env.Config = { ICON = { ko_home = "home" } }
    f.env._ = function(text) return text end
    local qa = read("features/sui_quickactions.lua")
    local start = assert(qa:find('            id    = "homescreen",', 1, true))
    local finish = assert(qa:find('\n        },\n        {\n            id    = "collections",', start, true))
    local entry = run("return {\n" .. qa:sub(start, finish - 1) .. "\n}", f.env)
    entry.execute({ show_unavailable = function() error("duplicate generic toast") end })
    H.eq(#f.messages, 1); assert(f.messages[1]:find(f.load_error, 1, true))
end)

H.finish()
