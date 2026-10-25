package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")

local function read(path)
    local root = os.getenv("ORBITUI_SIMPLEUI_TEST_ROOT") or "components/simpleui"
    local f = assert(io.open(root .. "/" .. path .. ".lua"))
    local source = f:read("*a"); f:close(); return source
end
local function run(source, name, env)
    if setfenv then
        local chunk = assert(loadstring(source, "@" .. name)); setfenv(chunk, env); return chunk()
    end
    return assert(load(source, "@" .. name, "t", env))()
end
local function fixture(done)
    local f = { gray = {}, shown = {}, logs = 0, onboarding = 0, refreshes = 0,
        data = { simpleui_onboarding_done = done, custom_layout = "kept" } }
    local Widget = {}
    function Widget:extend(fields)
        return setmetatable(fields or {}, { __index = self })
    end
    -- Native construction/rendering is outside this test. Crucially, do NOT
    -- extract the open factory or replace the engine: load its entire source.
    function Widget:new(opts) return self:extend(opts) end
    local deps = {
        device = { screen = { scaleBySize = function(_, n) return n end } },
        ["ui/font"] = { getFace = function() return {} end },
        ["ffi/blitbuffer"] = { gray = function(value)
            f.gray[#f.gray + 1] = value; return { gray = value }
        end, COLOR_WHITE = {} },
        ["ffi/util"] = { template = function(text) return text end },
        ["infra/sui_core"] = { PAD = 10, MOD_GAP = 10,
            makeQaTap = function() return f.qa end, makeGoalTap = function() return f.goal end },
        ["features/sui_style"] = { FACE_REGULAR = "font", FS_TITLE = 20, FS_SUBTITLE = 16 },
        ["infra/sui_i18n"] = { translate = function(text) return text end },
        ["infra/sui_store"] = {
            get = function(_, key) return f.data[key] end,
            set = function(_, key, value) f.data[key] = value end,
        },
        ["ui/uimanager"] = {
            show = function(_, widget) f.shown[#f.shown + 1] = widget end,
            close = function() end,
        },
        logger = { info = function() f.logs = f.logs + 1 end,
            err = function(...) error("Unexpected Home error: " .. table.concat({...}, " ")) end },
        ["modules/module_bookorbit_want"] = {
            scheduleAutoRefresh = function() f.refreshes = f.refreshes + 1 end,
        },
        ["screens/sui_onboarding"] = { show = function() f.onboarding = f.onboarding + 1 end },
        ["infra/sui_custom_screens"] = { get = function(id)
            return { id = id, pfx = id .. "_", layout_key = id .. "_layout", name = "Custom", icon = "star" }
        end },
    }
    for _, name in ipairs({
        "ui/widget/container/bottomcontainer", "ui/widget/button", "ui/widget/container/centercontainer",
        "ui/widget/overlapgroup", "ui/widget/container/framecontainer", "ui/geometry", "ui/gesturerange",
        "ui/widget/horizontalspan", "ui/widget/container/inputcontainer", "ui/widget/container/leftcontainer",
        "ui/widget/textwidget", "ui/widget/titlebar", "ui/widget/horizontalgroup", "ui/widget/verticalgroup",
        "ui/widget/verticalspan", "ui/widget/widget", "ui/widget/infomessage",
    }) do deps[name] = Widget end
    for _, name in ipairs({
        "ui/bidi", "infra/sui_config", "infra/sui_bento", "infra/sui_memory", "infra/sui_perf",
        "modules/moduleregistry", "ui/event", "screens/sui_bottombar", "engines/sui_section_label",
        "libs/libkoreader-lfs", "infra/sui_virtual_paths", "features/sui_wallpaper", "infra/sui_backdrop",
    }) do deps[name] = {} end
    local actual = { ["engines/sui_screen_engine"] = true, ["screens/sui_homescreen"] = true,
        ["infra/sui_screen_nav"] = true }
    local env = setmetatable({ package = { loaded = deps } }, { __index = function(_, key)
        -- Never inherit these helpers, even if another suite populated _G.
        if key ~= "Blitbuffer" and key ~= "logger" then return _G[key] end
    end })
    env.require = function(name)
        if not deps[name] and actual[name] then
            deps[name] = run(read(name), name .. ".lua", env)
        end
        return assert(deps[name], "Unexpected require: " .. name)
    end
    f.require, f.env = env.require, env
    f.qa, f.goal = function() end, function() end
    return f
end

H.test("the entire screen engine cold-loads without an ambient Blitbuffer", function()
    local f = fixture(nil)
    local engine = f.require("engines/sui_screen_engine")
    H.eq(type(engine), "table"); H.eq(type(engine._open), "function")
    H.eq(type(engine.showCustomScreen), "function"); H.eq(type(engine._cs_state), "table")
    H.eq(#engine.liveScreenIds(), 0); H.eq(#f.gray, 1); H.eq(f.gray[1], 0.08)
    H.eq(f.env.Blitbuffer, nil); H.eq(f.env.logger, nil)
    H.eq(f.require("engines/sui_screen_engine"), engine); H.eq(#f.gray, 1)
end)
H.test("whole-module Home loads and opens with fresh and existing settings", function()
    for _, done in ipairs({ false, true }) do
        local f = fixture(done)
        local home = assert(f.require("infra/sui_screen_nav").loadHome())
        H.eq(home, f.require("engines/sui_screen_engine"))
        local cached = {}; home._cached_books_state = cached; home._current_page = 3
        local widget = assert(home.show(f.qa, f.goal))
        H.eq(widget, f.shown[1]); H.eq(widget, home.getInstance("hs"))
        H.eq(widget._on_qa_tap, f.qa); H.eq(widget._on_goal_tap, f.goal)
        H.eq(widget.instance.id, "hs"); H.eq(widget.instance.pfx, "simpleui_hs_")
        H.eq(widget.instance.layout_key, "simpleui_layout")
        H.eq(widget._cached_books_state, cached); H.eq(widget._current_page, 3)
        H.eq(f.onboarding, done and 0 or 1); H.eq(f.logs, done and 0 or 1); H.eq(f.refreshes, 1)
        H.eq(f.data.custom_layout, "kept"); H.eq(f.data.simpleui_onboarding_done, done)
        H.eq(home.liveScreenIds()[1], "hs")
    end
    local f = fixture(nil)
    assert(f.require("screens/sui_homescreen").show())
    H.eq(f.onboarding, 1); H.eq(f.data.simpleui_onboarding_done, nil)
end)
H.test("cold-loaded custom screens retain their identity and generic callbacks", function()
    local f = fixture(true); local engine = f.require("engines/sui_screen_engine")
    local widget = assert(engine.showCustomScreen("custom_2"))
    H.eq(widget, engine.getInstance("custom_2")); H.eq(engine._instance, nil)
    H.eq(widget.instance.id, "custom_2"); H.eq(widget.instance.pfx, "custom_2_")
    H.eq(widget.instance.layout_key, "custom_2_layout"); H.eq(widget.instance.left_icon, "star")
    H.eq(widget._on_qa_tap, f.qa); H.eq(widget._on_goal_tap, f.goal)
    H.eq(engine.liveScreenIds()[1], "custom_2"); H.eq(f.onboarding, 0)
end)

H.finish()
