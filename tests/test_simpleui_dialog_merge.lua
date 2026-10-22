package.path = "./?.lua;./components/simpleui/?.lua;" .. package.path
local H = require("tests/helpers")
local calls, warnings, queue = {}, 0, {}
local function note(value) calls[#calls + 1] = value end
local UI = {
    close = function(_, widget) note("close:" .. widget.name); return "closed" end,
    scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end,
}
UI.show = function(_, widget, ...)
    note("show:" .. widget.name)
    if widget.fail then error("native failure", 0) end
    if widget.child then UI:show(widget.child) end
    return select("#", ...)
end
package.loaded["ui/uimanager"] = UI
package.loaded.logger = { warn = function() warnings = warnings + 1 end, dbg = function() end }
local Hooks = require("infra/sui_window_hooks")
local owner, other = {}, {}
local native_show, native_close = UI.show, UI.close
local widget = { name = "dialog", covers_fullscreen = true }

H.test("window steps preserve ordering, return values and native errors", function()
    Hooks.install(owner)
    local matches = 0
    Hooks.register{ id="late", point="show", order=20,
        match=function() matches=matches+1; return true end,
        before=function() note("late") end, after=function() note("after") end,
        settled=function() note("settled") end }
    Hooks.register{ id="early", point="show", order=10, before=function() note("early") end }
    Hooks.register{ id="bad", point="show", order=15, before=function() error("step failure") end }
    H.eq(UI:show(widget, 1, nil, 3), 3)
    H.eq(table.concat(calls, ","), "early,late,show:dialog,after,settled")
    H.eq(matches, 1); H.eq(warnings, 1)
    calls = {}; widget.fail = true
    local ok, err = pcall(UI.show, UI, widget)
    H.eq(ok, false); H.eq(err, "native failure")
    H.eq(table.concat(calls, ","), "early,late,show:dialog,settled")
    widget.fail = nil
    Hooks.uninstall(owner)
    H.eq(UI.show, native_show); H.eq(UI.close, native_close)
end)

H.test("reentrant show restores depth after errors and nonfullscreens bypass steps", function()
    Hooks.install(owner)
    local outer = {}
    Hooks.register{ id="depth", point="show", order=1,
        enter=function(ctx) outer[#outer + 1] = ctx.outermost end }
    widget.child = { name="child", covers_fullscreen=true }
    UI:show(widget); H.eq(outer[1], true); H.eq(outer[2], false)
    widget.child = nil; widget.fail = true
    pcall(UI.show, UI, widget); widget.fail = nil
    UI:show(widget); H.eq(outer[4], true)
    UI:show{ name="toast" }; H.eq(#outer, 4)
    Hooks.uninstall(owner)
end)

H.test("stale teardown and later third-party wrappers cannot remove live hooks", function()
    Hooks.install(owner); Hooks.install(other)
    local step_calls, third_calls = 0, 0
    Hooks.register{ id="test", point="show", order=1,
        before=function() step_calls=step_calls+1 end }
    local inner_show, inner_close = UI.show, UI.close
    UI.show = function(...) third_calls=third_calls+1; return inner_show(...) end
    UI.close = function(...) third_calls=third_calls+1; return inner_close(...) end
    local later_show, later_close = UI.show, UI.close
    Hooks.uninstall(owner)
    UI:show(widget); H.eq(step_calls, 1)
    Hooks.uninstall(other)
    H.eq(UI.show, later_show); H.eq(UI.close, later_close)
    UI:show(widget); UI:close(widget)
    H.eq(step_calls, 1); H.eq(third_calls, 3)
    Hooks.install(owner)
    Hooks.register{ id="test", point="show", order=1,
        before=function() step_calls=step_calls+1 end }
    UI:show(widget); H.eq(step_calls, 2); H.eq(third_calls, 4)
    Hooks.uninstall(owner)
    UI.show, UI.close = native_show, native_close
end)

H.test("intercepted dialog show and close preserve the original calls for fallback", function()
    Hooks.install(owner)
    local bypass = { name="owned" }
    Hooks.register{ id="proxy", point="show", order=1,
        intercept=function(w, p, orig)
            H.eq(p, owner); H.eq(orig, native_show)
            return w == bypass
        end }
    Hooks.register{ id="proxy", point="close", order=1,
        intercept=function(w) return w == bypass end }
    calls = {}; UI:show(bypass); UI:close(bypass); H.eq(#calls, 0)
    UI:show(widget); H.eq(UI:close(widget), "closed"); H.eq(#calls, 2)
    Hooks.uninstall(owner)
end)

local function read(path)
    local f = assert(io.open(path)); local text=f:read("*a"); f:close(); return text
end
local function section(text, first, last)
    local start = assert(text:find(first, 1, true))
    return text:sub(start, assert(text:find(last, start, true)) - 1)
end
local function run(text, env)
    env = setmetatable(env, { __index=_G })
    if setfenv then return setfenv(assert(loadstring(text)), env)() end
    return assert(load(text, "window integration", "t", env))()
end
local patches = read("components/simpleui/infra/sui_patches.lua")
H.test("registered navigation cancels scheduled Home restores after a destination opens", function()
    local steps, shown = {}, 0
    local env = {
        UIManager=UI, M={ isNavigationDestination=function(w) return w.destination end },
        WindowHooks={ POINT=Hooks.POINT, ORDER=Hooks.ORDER,
            register=function(step) steps[step.id]=step end },
        require=function() return {} end,
    }
    run(section(patches, "local function registerWindowSteps()", "-- Installs the window hooks")
        .. "\nregisterWindowSteps()", env)
    local nav = assert(steps.orbitui_navigation)
    H.eq(nav.match{destination=true}, true)
    H.eq(nav.match{}, nil)
    local reopen = run(section(patches, "local function _reopenScreen(ctx)", "-- \226\148\128\226\148\128 registration")
        .. "\nreturn _reopenScreen", {
        UIManager=UI, _handOverDisplacedScreen=function() return false end,
        _isReader=function() return false end, isAppExiting=function() return false end,
        liveFM=function() return {} end,
        _doShowHS=function(_, _, _, gen)
            if gen == (UI._simpleui_navigation_generation or 0) then shown=shown+1 end
        end,
    })
    UI._simpleui_navigation_generation = 0; queue={}
    reopen{widget={}, plugin=owner}; nav.enter(); queue[1]()
    H.eq(shown, 0)
    reopen{widget={}, plugin=owner}; queue[2](); H.eq(shown, 1)
end)

H.test("settings memoization invalidates through all persistent and no-flush aliases", function()
    local data, flushes, computed = {}, 0, 0
    package.loaded.datastorage = { getSettingsDir=function() return "/not-written" end }
    package.loaded.luasettings = { open=function()
        return { data=data, readSetting=function(_, k) return data[k] end,
            saveSetting=function(_, k, v) data[k]=v end,
            delSetting=function(_, k) data[k]=nil end,
            flush=function() flushes=flushes+1 end }
    end }
    local store = dofile("components/simpleui/infra/sui_store.lua")
    local cached = store.memoize(function() computed=computed+1; return store:get("choice") end)
    cached(); cached(); H.eq(computed, 1)
    for _, method in ipairs{"set", "saveSetting", "setNoFlush", "del", "delSetting", "delNoFlush"} do
        local generation = store:generation()
        store[method](store, "choice", method)
        H.eq(store:generation(), generation+1)
        local before=computed; cached(); cached(); H.eq(computed, before+1)
    end
    H.eq(flushes, 4)
    store:flush(); H.eq(flushes, 5)
end)

H.test("virtual path mapping is device gated, optional and retryable", function()
    local kobo, lookups, builds, fail = false, 0, 0, true
    package.loaded.device = { isKobo=function() return kobo end }
    local library = { virtual_to_real={} }
    function library:buildPathMappings()
        builds=builds+1
        if fail then error("provider busy") end
        self.virtual_to_real["KOBO_VIRTUAL://one"] = "/one"
    end
    function library:getVirtualPath(path)
        if path == "/one" then return "KOBO_VIRTUAL://one" end
    end
    package.loaded.pluginloader = { getPluginInstance=function(_, id)
        H.eq(id, "kobo_plugin"); lookups=lookups+1; return {virtual_library=library}
    end }
    local paths = dofile("components/simpleui/infra/sui_virtual_paths.lua")
    H.eq(paths.toVirtual("/one"), "/one"); H.eq(lookups, 0)
    kobo=true
    H.eq(paths.toVirtual("KOBO_VIRTUAL://one"), "KOBO_VIRTUAL://one"); H.eq(lookups, 0)
    H.eq(paths.toVirtual("/one"), "/one")
    fail=false
    H.eq(paths.toVirtual("/one"), "KOBO_VIRTUAL://one"); H.eq(builds, 2)
    H.eq(paths.toVirtual("/missing"), "/missing"); H.eq(builds, 2)
end)
H.finish()
