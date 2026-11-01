local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local function updates() return assert(loadfile(root .. "/adapters/orbitui_updates.lua"))() end
H.test("quiet tasks use native invisible-resend mode while visible cancellation remains modal", function()
    local calls, tasks = {}, {}
    package.loaded["ui/uimanager"] = { scheduleIn = function(_, _, fn) tasks[#tasks + 1] = fn end }
    package.loaded["ui/trapper"] = {
        isWrapped = function() return false end, wrap = function(_, fn) fn() end,
        dismissableRunInSubprocess = function(_, fn, label, simple)
            calls[#calls + 1] = { label = label, simple = simple }; return true, fn()
        end,
    }
    local U = updates()
    local result
    U.runTask(function() return 42 end, false, function(value) result = value end)
    H.eq(calls[1].label, nil); H.eq(calls[1].simple, false); H.eq(result, nil)
    tasks[1](); H.eq(result.value, 42)
    U.runTask(function() end, "Downloading", function() end)
    H.eq(calls[2].label, "Downloading")
end)

-- Optional full, unmodified native Trapper + TrapWidget. Only process/FD and
-- primitive drawing services are faked; their event/coroutine owners are real.
local native_trapper, native_widget = os.getenv("ORBITUI_NATIVE_TRAPPER_FILE"), os.getenv("ORBITUI_NATIVE_TRAP_WIDGET")
if native_trapper and native_widget then
    local function fixture()
        local f = { tasks = {}, events = {}, killed = 0, closed_fd = 0, callbacks = 0, clock = 0 }
        local UI = {}
        function UI:scheduleIn(delay, fn) f.tasks[#f.tasks + 1] = { at = f.clock + delay, fn = fn } end
        function UI:nextTick(fn) self:scheduleIn(0, fn) end
        function UI:unschedule(fn) for _, task in ipairs(f.tasks) do if task.fn == fn then task.cancelled = true end end end
        function UI:show(widget) f.trap = widget end
        function UI:close(widget) if f.trap == widget then f.trap = nil end end
        function UI:handleInputEvent(event) f.events[#f.events + 1] = event end
        function UI:preventStandby() end
        function UI:allowStandby() end
        function UI:forceRePaint() end
        local W = H.widget()
        function W:getWidth() return 20 end
        function W:getSize() return { w = 20, h = 20 } end
        function W:copy() return self end
        for _, name in ipairs({ "ui/widget/confirmbox", "ui/widget/infomessage", "ui/widget/container/bottomcontainer",
                "ui/widget/container/centercontainer", "ui/widget/container/framecontainer", "ui/geometry", "ui/gesturerange",
                "ui/widget/container/inputcontainer", "ui/widget/container/leftcontainer", "ui/widget/textboxwidget", "ui/widget/textwidget" }) do
            package.loaded[name] = W
        end
        package.loaded["ui/uimanager"] = UI
        package.loaded["ui/font"] = { getFace = function() return {} end }
        package.loaded["ui/size"] = { border = { default = 1 }, padding = { default = 2 } }
        package.loaded["ffi/blitbuffer"] = { COLOR_WHITE = 0 }
        package.loaded["device"] = { hasKeys = function() return false end, isTouchDevice = function() return true end,
            input = {}, screen = { getWidth = function() return 100 end, getHeight = function() return 100 end } }
        package.loaded["ui/event"] = { new = function(_, kind, event) return { handler = kind, args = { event } } end }
        package.loaded["string.buffer"] = { encode = function() return "encoded" end, decode = function() return { n = 1, { ok = true } } end }
        package.loaded["ffi/util"] = {
            runInSubProcess = function() return 12, 13 end,
            terminateSubProcess = function(pid) H.eq(pid, 12); f.killed = f.killed + 1 end,
            isSubProcessDone = function() return f.killed > 0 end,
            getNonBlockingReadSize = function() return 0 end,
            readAllFromFD = function(fd) H.eq(fd, 13); f.closed_fd = f.closed_fd + 1; return "" end,
        }
        package.loaded.logger = { warn = function(_, err) error(err or "native warning") end, dbg = function() end }
        package.loaded.gettext = function(s) return s end
        package.loaded["ui/widget/trapwidget"] = assert(loadfile(native_widget))()
        package.loaded["ui/trapper"] = assert(loadfile(native_trapper))()
        function f.tick()
            table.sort(f.tasks, function(a, b) return a.at < b.at end)
            local task = table.remove(f.tasks, 1)
            if task then f.clock = task.at; if not task.cancelled then task.fn() end; return true end
        end
        return f, updates()
    end
    for _, gesture in ipairs({ "Tap", "Hold", "Swipe", "PanRelease" }) do
        H.test("native quiet maintenance cancels and forwards the original " .. gesture .. " exactly once", function()
            local f, U = fixture()
            U.runTask(function() error("parent must not execute cleanup") end, false, function(result)
                H.eq(result.ok, nil); f.callbacks = f.callbacks + 1
            end)
            for _ = 1, 4 do if f.trap then break end; f.tick() end
            local trap = assert(f.trap, "native task did not create its widget")
            H.eq(trap.invisible, true); H.eq(trap.resend_event, true)
            local event = { ges = gesture:lower(), pos = { x = 75, y = 98 } }
            H.eq(trap["on" .. gesture .. "Dismiss"](trap, nil, event), true)
            H.eq(f.killed, 1); H.eq(#f.events, 0); H.eq(f.trap, nil)
            for _ = 1, 8 do if not f.tick() then break end end
            H.eq(#f.events, 1); H.eq(f.events[1].args[1], event); H.eq(f.callbacks, 1); H.eq(f.closed_fd, 1)
        end)
    end
    H.test("native visible download still consumes its cancellation tap", function()
        local f, U = fixture()
        U.runTask(function() end, "Downloading", function() f.callbacks = f.callbacks + 1 end)
        for _ = 1, 4 do if f.trap then break end; f.tick() end
        local trap = assert(f.trap)
        H.eq(trap.resend_event, false)
        trap:onTapDismiss(nil, { ges = "tap" })
        for _ = 1, 8 do if not f.tick() then break end end
        H.eq(#f.events, 0); H.eq(f.killed, 1); H.eq(f.callbacks, 1)
    end)
end
H.finish()
