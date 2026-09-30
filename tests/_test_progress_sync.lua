-- Progress prompts must finish closing before Android reader navigation.
package.path = "./?.lua;" .. package.path

local scheduled, instances, hooks, logs = {}, {}, {}, {}
local android, enabled = true, true
local ReaderUI = { instance = nil }
local modal_open = false
local ConfirmBox = {}
function ConfirmBox:new(options)
    assert(self == ConfirmBox, "use the original widget constructor")
    modal_open = true
    options.accept = function()
        options.ok_callback()
        modal_open = false
    end
    options.cancel = function()
        if options.cancel_callback then options.cancel_callback() end
        modal_open = false
    end
    return options
end

package.loaded["device"] = { isAndroid = function() return android end }
package.loaded["infra/sui_store"] = { nilOrTrue = function() return enabled end }
package.loaded["ui/uimanager"] = {
    scheduleIn = function(_self, delay, fn)
        assert(delay == 0.15, "allow Android's modal dispatch cycle to finish")
        scheduled[#scheduled + 1] = fn
    end,
}
package.loaded["apps/reader/readerui"] = ReaderUI
package.loaded["pluginloader"] = {
    getPluginInstance = function(_self, name) return instances[name] end,
}
package.loaded["userpatch"] = {
    registerPatchPluginFunc = function(name, fn)
        assert(not hooks[name], "do not register a hook twice")
        hooks[name] = fn
    end,
}
local function log(...) logs[#logs + 1] = { ... } end
package.loaded["logger"] = { dbg = log, info = log, warn = log, err = log }

local Sync = require("infra/sui_progress_sync")
local passed = 0
local function reset()
    Sync.teardown()
    android, enabled, modal_open = true, true, false
    scheduled, instances, logs = {}, {}, {}
    ReaderUI.instance = { document = { file = "/books/test.epub" } }
end
local function runScheduled()
    local fn = table.remove(scheduled, 1)
    assert(fn, "expected deferred navigation")
    fn()
    assert(#scheduled == 0, "callback must not be deferred twice")
end
local function test(name, fn)
    reset()
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    passed = passed + 1
end

local function makePlugin()
    -- Like BookOrbit's progress mixin, both methods share ConfirmBox.
    local ConfirmBox = ConfirmBox
    local plugin = { jumps = 0, successes = 0, continuations = 0 }
    function plugin:syncToProgress()
        assert(not modal_open, "navigation ran before ConfirmBox closed")
        self.jumps = self.jumps + 1
    end
    function plugin:getProgress(silent)
        if silent then return self:syncToProgress() end
        return ConfirmBox:new{
            ok_callback = function()
                self:syncToProgress()
                self.successes = self.successes + 1
            end,
            cancel_callback = function() self.cancelled = true end,
        }
    end
    function plugin:reconcileProgressBeforeBookSync()
        return ConfirmBox:new{
            ok_callback = function()
                self:syncToProgress()
                self.continuations = self.continuations + 1
            end,
        }
    end
    return plugin
end

test("BookOrbit acceptance closes the modal before navigation and success", function()
    local plugin = makePlugin()
    assert(Sync.patchTarget(plugin, "bookorbit"))
    local dialog = plugin:getProgress()
    dialog.accept()
    assert(not modal_open and plugin.jumps == 0 and plugin.successes == 0)
    runScheduled()
    assert(plugin.jumps == 1 and plugin.successes == 1)
end)

test("BookOrbit pre-upload reconciliation is deferred exactly once", function()
    local plugin = makePlugin()
    assert(Sync.patchTarget(plugin, "bookorbit"))
    assert(Sync.patchTarget(plugin, "bookorbit"))
    plugin:reconcileProgressBeforeBookSync().accept()
    assert(plugin.continuations == 0 and #scheduled == 1)
    runScheduled()
    assert(plugin.jumps == 1 and plugin.continuations == 1)
end)

test("separate ConfirmBox upvalues are both patched", function()
    local plugin = makePlugin()
    plugin.reconcileProgressBeforeBookSync = makePlugin().reconcileProgressBeforeBookSync
    Sync.patchTarget(plugin, "bookorbit")
    plugin:reconcileProgressBeforeBookSync().accept()
    runScheduled()
    plugin:getProgress().accept()
    runScheduled()
    assert(plugin.jumps == 2)
end)

test("existing KOSync workaround is preserved", function()
    local plugin = makePlugin()
    Sync.patchTarget(plugin, "kosync")
    plugin:getProgress().accept()
    assert(plugin.jumps == 0)
    runScheduled()
    assert(plugin.jumps == 1)
end)

test("silent and manual navigation without a prompt remains synchronous", function()
    local plugin = makePlugin()
    Sync.patchTarget(plugin, "bookorbit")
    plugin:getProgress(true)
    plugin:syncToProgress()
    assert(plugin.jumps == 2 and #scheduled == 0)
end)

test("rejecting the prompt does not navigate", function()
    local plugin = makePlugin()
    Sync.patchTarget(plugin, "bookorbit")
    plugin:getProgress().cancel()
    assert(plugin.cancelled and plugin.jumps == 0 and #scheduled == 0)
end)

test("unrelated ConfirmBox callbacks are not patched", function()
    Sync.patchTarget(makePlugin(), "bookorbit")
    local called = false
    ConfirmBox:new{ ok_callback = function() called = true end }.accept()
    assert(called and #scheduled == 0)
end)

test("class methods shared by multiple instances are not double wrapped", function()
    local class = makePlugin()
    local first = setmetatable({}, { __index = class })
    local second = setmetatable({}, { __index = class })
    Sync.patchTarget(first, "bookorbit")
    Sync.patchTarget(second, "bookorbit")
    second:getProgress().accept()
    runScheduled()
    assert(second.jumps == 1 and first.jumps == 0)
end)

test("plugins can be found through ReaderUI or PluginLoader", function()
    local kosync, bookorbit = makePlugin(), makePlugin()
    instances.bookorbit = bookorbit
    Sync.patchAll({ ui = { kosync = kosync } })
    kosync:getProgress().accept()
    runScheduled()
    bookorbit:getProgress().accept()
    runScheduled()
    assert(kosync.jumps == 1 and bookorbit.jumps == 1)
end)

test("late plugin loading is handled by both idempotent hooks", function()
    Sync.patchAll({ ui = {} })
    Sync.installHooks()
    Sync.installHooks()
    assert(hooks.kosync and hooks.bookorbit)
    for name, hook in pairs(hooks) do
        local plugin = makePlugin()
        hook(plugin)
        plugin:getProgress().accept()
        runScheduled()
        assert(plugin.jumps == 1, name)
    end
end)

test("non-Android platforms are untouched", function()
    android = false
    assert(not Sync.patchTarget(makePlugin(), "bookorbit"))
end)

test("disabled SimpleUI does not patch newly created plugins", function()
    enabled = false
    assert(not Sync.patchTarget(makePlugin(), "bookorbit"))
    local plugin = makePlugin()
    hooks.bookorbit(plugin)
    local ok = pcall(function() plugin:getProgress().accept() end)
    assert(not ok and #scheduled == 0, "original callback must remain synchronous")
end)

test("teardown restores shared upvalues and allows reinstall", function()
    local plugin = makePlugin()
    Sync.patchTarget(plugin, "bookorbit")
    Sync.teardown()
    local ok = pcall(function() plugin:getProgress().accept() end)
    assert(not ok and #scheduled == 0)
    modal_open = false
    assert(Sync.patchTarget(plugin, "bookorbit"))
    plugin:reconcileProgressBeforeBookSync().accept()
    runScheduled()
    assert(plugin.jumps == 1)
end)

for _, change in ipairs({ "reader", "document", "closed" }) do
    test("stale prompt is discarded after changing " .. change, function()
        local plugin = makePlugin()
        Sync.patchTarget(plugin, "bookorbit")
        local dialog = plugin:getProgress()
        if change == "reader" then
            ReaderUI.instance = { document = {} }
        elseif change == "document" then
            ReaderUI.instance.document = {}
        else
            ReaderUI.instance.tearing_down = true
        end
        dialog.accept()
        runScheduled()
        assert(plugin.jumps == 0 and plugin.successes == 0)
    end)
end

test("callback errors are logged instead of crashing the UI loop", function()
    local plugin = makePlugin()
    function plugin:syncToProgress() error("test navigation failure") end
    Sync.patchTarget(plugin, "bookorbit")
    plugin:getProgress().accept()
    runScheduled()
    assert(plugin.successes == 0)
    assert(tostring(logs[#logs][3]):find("test navigation failure", 1, true))
end)

test("unknown plugin and changed upstream method are skipped safely", function()
    assert(not Sync.patchTarget(makePlugin(), "unrelated"))
    assert(not Sync.patchTarget({ getProgress = function() end }, "bookorbit"))
end)

-- Optional compatibility check against an unmodified deployed BookOrbit mixin:
-- BOOKORBIT_PROGRESS_SYNC=/path/to/bookorbit_progress_sync.lua lua this_file
local deployed_source = os.getenv("BOOKORBIT_PROGRESS_SYNC")
if deployed_source then
    local UIManager = package.loaded["ui/uimanager"]
    local shown
    UIManager.show = function(_self, dialog) shown = dialog end
    UIManager.getElapsedTimeSinceBoot = function() return 1000 end
    package.loaded["ui/widget/confirmbox"] = ConfirmBox
    package.loaded["ui/widget/infomessage"] = { new = function(_self, options) return options end }
    package.loaded["ui/event"] = { new = function(_self, name, value) return { name, value } end }
    package.loaded["optmath"] = {
        roundPercent = function(value) return value end,
        round = function(value) return math.floor(value + 0.5) end,
    }
    package.loaded["ui/network/manager"] = {}
    package.loaded["ui/time"] = { s = function(value) return value end }
    package.loaded["util"] = {}
    package.loaded["ffi/util"] = { template = function(text) return text end }
    package.loaded["gettext"] = function(text) return text end
    package.loaded["bookorbit_state_manager"] = {}
    local Progress = dofile(deployed_source)
    local function realPlugin(position)
        local plugin = { SYNC_STRATEGY = { SILENT = 1, PROMPT = 2 } }
        Progress.install(plugin)
        plugin.ui = ReaderUI.instance
        plugin.ui.document.info = { has_pages = false }
        plugin.events, plugin.successes = {}, 0
        plugin.ui.handleEvent = function(_self, event)
            assert(not modal_open, "real plugin navigated before modal closed")
            plugin.events[#plugin.events + 1] = event
        end
        plugin.settings = { sync_forward = 2, sync_backward = 2 }
        plugin.pull_timestamp, plugin.last_page_turn_timestamp = 0, 1
        function plugin:isLoggedIn() return true end
        function plugin:getDocumentDigest() return "test-book" end
        function plugin:getLastPercent() return 0.1 end
        function plugin:getLastProgress() return "/body/DocFragment[1]/body" end
        function plugin:requestUpdateCheck() end
        function plugin:recordSyncSuccess() self.successes = self.successes + 1 end
        function plugin:newClient()
            return { getProgress = function()
                return { progress = position, percentage = 0.17, timestamp = 2, device = "web" }
            end }
        end
        return plugin
    end

    test("deployed BookOrbit automatic prompt uses deferred exact navigation", function()
        local position = "/body/DocFragment[6]/body/p[121]/st[1]/text().99"
        local plugin = realPlugin(position)
        Sync.patchTarget(plugin, "bookorbit")
        plugin:getProgress(false, false)
        shown.accept()
        assert(#plugin.events == 0 and plugin.successes == 0)
        runScheduled()
        assert(plugin.events[1][1] == "GotoXPointer" and plugin.events[1][2] == position)
        assert(plugin.successes == 1)
    end)

    test("deployed BookOrbit keeps percentage fallback after prompt", function()
        local plugin = realPlugin(nil)
        Sync.patchTarget(plugin, "bookorbit")
        plugin:getProgress(false, false)
        shown.accept()
        runScheduled()
        assert(plugin.events[1][1] == "GotoPercent" and plugin.events[1][2] == 17)
    end)

    test("deployed pre-upload prompt navigates before continuing the upload", function()
        local plugin = realPlugin("/body/DocFragment[6]/body")
        Sync.patchTarget(plugin, "bookorbit")
        local continuation
        local original_schedule = UIManager.scheduleIn
        UIManager.scheduleIn = function(_self, delay, fn)
            if delay == 0.1 then
                continuation = fn
            else
                original_schedule(UIManager, delay, fn)
            end
        end
        local done = false
        assert(plugin:reconcileProgressBeforeBookSync("test-book", function(skip_progress)
            assert(skip_progress == false and #plugin.events == 1)
            done = true
        end))
        shown.accept()
        assert(not continuation and not done and #plugin.events == 0)
        runScheduled()
        assert(not done and type(continuation) == "function")
        continuation()
        assert(done)
        UIManager.scheduleIn = original_schedule
    end)
end

Sync.teardown()
print("Progress sync: " .. passed .. " tests passed")
