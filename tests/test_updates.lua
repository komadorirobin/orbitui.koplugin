package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Updates = require("adapters/orbitui_updates")
local messages = {}
package.loaded["ui/uimanager"] = { show = function(_, msg) messages[#messages + 1] = msg.text end }
package.loaded["ui/widget/infomessage"] = { new = function(_, msg) return msg end }
H.test("both components use the shared OrbitUI update label", function()
    H.eq(Updates.menuLabel, "Uppdatera OrbitUI")
    for _, name in ipairs({ "bookshelf", "simpleui" }) do
        H.eq(Updates.component(name, "/dummy").menuLabel, Updates.menuLabel)
    end
end)
H.test("Bookshelf installation entry points cannot update a component", function()
    local updater = Updates.component("bookshelf", "/dummy")
    for _, method in ipairs({ "check", "checkBranch", "install", "installBranch", "installLatestStable" }) do
        updater[method]("https://unwanted.invalid/old-plugin.zip", "old", "new")
    end
    H.eq(#messages, 5)
    assert(messages[1]:find("OrbitUI", 1, true))
end)
H.test("SimpleUI channel changes and manual checks cannot install old packages", function()
    local updater = Updates.component("simpleui", "/dummy")
    updater.setSelectedBranch("beta")
    updater.checkForUpdates()
    updater._doManualCheck()
    updater._doManualBranchCheck()
    H.eq(#messages, 9)
    H.eq(updater.selectedBranch(), "Managed by OrbitUI")
end)
H.test("automatic component update paths do nothing", function()
    local before = #messages
    local b = Updates.component("bookshelf", "/dummy")
    local s = Updates.component("simpleui", "/dummy")
    b.checkBackground(function() error("unexpected callback") end)
    b.checkBranchBackground()
    s.scheduleAutoCheck()
    H.eq(s.build_update_banner_item(), nil)
    H.eq(#messages, before)
end)
H.test("Trapper uses its real return-value API and defers UI callbacks", function()
    local queue, delivered = {}, 0
    package.loaded["ui/uimanager"].scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end
    package.loaded["ui/trapper"] = {
        isWrapped = function() return false end,
        wrap = function(_, fn) fn() end,
        dismissableRunInSubprocess = function(_, fn, label, simple)
            H.eq(simple, false)
            H.eq(label, "Checking")
            return true, fn()
        end,
    }
    Updates.runTask(function() return { value = 4 } end, "Checking", function(result)
        assert(result.ok)
        H.eq(result.value.value, 4)
        delivered = delivered + 1
    end)
    H.eq(delivered, 0)
    H.eq(#queue, 1)
    queue[1]()
    H.eq(delivered, 1)
end)
H.test("cancellation never invokes installation activation", function()
    local queue, activated = {}, false
    local Boot = require("orbitui_bootstrap")
    local previous = Boot.activate
    Boot.activate = function() activated = true end
    package.loaded["ui/uimanager"].scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end
    package.loaded["ui/trapper"].dismissableRunInSubprocess = function() return false end
    Updates.configure{ root = "/test-orbitui", slot = "factory", version = "0.1.0-alpha.2" }
    Updates.install{ version = "0.1.0-alpha.3" }
    queue[1]()
    H.eq(activated, false)
    Boot.activate = previous
end)
H.test("external installation also activates only in the deferred main-process callback", function()
    local U, queue, activated = dofile("adapters/orbitui_updates.lua"), {}, false
    local candidate = { slot = string.rep("b", 64), version = "1.0.2" }
    local previous = package.loaded["core/orbitui_ota"]
    package.loaded["core/orbitui_ota"] = {
        externalCandidate = function() return candidate end,
        prepareExternal = function() assert(not activated); return candidate end,
        activateExternal = function() activated = true end,
    }
    package.loaded["ui/uimanager"].scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end
    package.loaded["ui/widget/confirmbox"] = { new = function(_, msg) return msg end }
    local cancelled = true
    package.loaded["ui/trapper"].dismissableRunInSubprocess = function(_, fn)
        if cancelled then return false end
        return true, fn()
    end
    U.configure{ root = "/test-orbitui", slot = string.rep("a", 64), version = "1.0.1" }
    U.checkExternal(false)
    queue[1]()
    H.eq(activated, false)
    cancelled, queue = false, {}
    U.checkExternal(false)
    H.eq(activated, false)
    H.eq(#queue, 1)
    queue[1]()
    H.eq(activated, true)
    package.loaded["core/orbitui_ota"] = previous
end)
H.test("rate-limit errors survive Trapper safely and suppress new checks until their deadline", function()
    local U, queue, calls, messages_before = dofile("adapters/orbitui_updates.lua"), {}, 0, #messages
    local Boot = require("orbitui_bootstrap")
    local old_state, old_ota, old_time, old_settings = Boot.state, package.loaded["core/orbitui_ota"], os.time, G_reader_settings
    local now, fail, saved = 1000, true, {}
    os.time = function() return now end
    Boot.state = function() return { current = "factory", previous = "none" } end
    G_reader_settings = {
        readSetting = function(_, key) return saved[key] end,
        saveSetting = function(_, key, value) saved[key] = value end,
        flush = function() end,
    }
    package.loaded["ui/uimanager"].scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end
    package.loaded["ui/network/manager"] = {
        runWhenOnline = function(_, fn) fn() end, isOnline = function() return true end,
    }
    package.loaded["ui/trapper"].dismissableRunInSubprocess = function(_, fn)
        local result = fn()
        if fail then
            H.eq(type(result.error), "string")
            H.eq(result.http_error.retry_at, 1120)
            H.eq(result.http_error.body, nil)
            assert(not result.error:find("private", 1, true))
        end
        return true, result
    end
    package.loaded["core/orbitui_ota"] = { check = function()
        calls = calls + 1
        if fail then error({ orbitui_http_error = true, status = 403, kind = "rate_limit",
            retry_at = 1120, body = "private body" }) end
    end }
    U.configure{ root = "/test-orbitui", version = "0.1.0-beta.42", slot = "factory" }
    U.check(false); H.eq(calls, 1); queue[1](); queue = {}
    H.eq(#messages, messages_before + 1)
    assert(messages[#messages]:find("installed OrbitUI version has not changed", 1, true))
    U.check(true); H.eq(calls, 1); H.eq(#queue, 0)
    U.check(false); H.eq(calls, 1); H.eq(#messages, messages_before + 2)
    now, fail = 1120, false
    U.check(false); H.eq(calls, 2); queue[1]()
    H.eq(saved.orbitui_update_last_check, now)
    Boot.state, package.loaded["core/orbitui_ota"], os.time, G_reader_settings = old_state, old_ota, old_time, old_settings
end)
local function startupFixture(mode)
    local U = dofile("adapters/orbitui_updates.lua")
    local Boot = require("orbitui_bootstrap")
    local old_health, old_state = Boot.healthy, Boot.state
    local old_ota, old_logger, old_settings = package.loaded["core/orbitui_ota"], package.loaded.logger, G_reader_settings
    local f = { queue = {}, shown = {}, order = {}, warnings = 0, checks = 0, automatic = 0 }
    local context = { root = "/startup-orbitui", runtime = "/startup-orbitui/active", slot = string.rep("a", 64), version = "3.0.0" }
    f.context = context
    Boot.healthy = function()
        f.order[#f.order + 1] = "healthy"
        if mode == "health-failed" then error("cannot write health record") end
        f.healthy = true
    end
    Boot.state = function() return { current = context.slot, previous = string.rep("b", 64), pending = false } end
    G_reader_settings = { isTrue = function() return true end, readSetting = function(_, key)
        return key == "orbitui_update_last_check" and 0 or nil
    end }
    package.loaded.logger = { info = function() end, warn = function() f.warnings = f.warnings + 1 end }
    package.loaded["ui/uimanager"] = {
        scheduleIn = function(_, delay, fn) f.queue[#f.queue + 1] = { delay = delay, fn = fn } end,
        show = function(_, msg) f.shown[#f.shown + 1] = msg end,
    }
    package.loaded["ui/widget/confirmbox"] = { new = function(_, msg) return msg end }
    package.loaded["ui/trapper"] = {
        isWrapped = function() return false end,
        wrap = function(_, fn) fn() end,
        dismissableRunInSubprocess = function(_, fn, label)
            H.eq(label, false)
            if mode == "cancelled" then return false end
            return true, fn()
        end,
    }
    package.loaded["core/orbitui_ota"] = {
        cleanup = function(c)
            assert(f.healthy and c._orbitui_storage_ready, "cleanup ran before health confirmation")
            f.order[#f.order + 1] = "cleanup"
            if mode == "cleanup-failed" then error("storage unavailable") end
            return { removed = 1, bytes = 64, skipped = 0 }
        end,
        externalCandidate = function()
            f.checks = f.checks + 1; f.order[#f.order + 1] = "external"
        end,
    }
    U.check = function(quiet) assert(quiet); f.automatic = f.automatic + 1 end
    U.configure(context)
    f.restore = function()
        Boot.healthy, Boot.state = old_health, old_state
        package.loaded["core/orbitui_ota"], package.loaded.logger, G_reader_settings = old_ota, old_logger, old_settings
    end
    return U, f
end
H.test("storage cleanup waits for healthy startup and runs once before external/daily checks", function()
    local U, f = startupFixture()
    U.cleanStorage(); H.eq(#f.order, 0)
    U.started(); U.started()
    H.eq(#f.order, 1); H.eq(f.order[1], "healthy"); H.eq(#f.queue, 1)
    H.eq(f.queue[1].delay, 1); H.eq(f.checks, 0)
    f.queue[1].fn()
    H.eq(f.order[2], "cleanup"); H.eq(f.checks, 0)
    f.queue[2].fn()
    H.eq(f.order[3], "external"); H.eq(f.checks, 1)
    H.eq(f.queue[3].delay, 5); f.queue[3].fn(); H.eq(f.automatic, 1)
    U.started(); H.eq(#f.queue, 3)
    f.restore()
end)
H.test("failed startup confirmation never starts storage cleanup", function()
    local U, f = startupFixture("health-failed")
    U.started(); U.cleanStorage()
    H.eq(f.context._orbitui_storage_ready, nil)
    H.eq(#f.queue, 0); H.eq(#f.order, 1)
    assert(f.shown[1].text:find("Could not confirm OrbitUI startup", 1, true))
    f.restore()
end)
H.test("cleanup failure or cancellation cannot block startup or later update checks", function()
    for _, mode in ipairs({ "cleanup-failed", "cancelled" }) do
        local U, f = startupFixture(mode)
        U.started(); f.queue[1].fn(); f.queue[2].fn()
        H.eq(f.warnings, 1); H.eq(f.checks, 1)
        f.queue[3].fn(); H.eq(f.automatic, 1)
        assert(f.context._orbitui_storage_ready)
        f.restore()
    end
end)
H.test("a stale rollback confirmation cannot change selected code during cleanup", function()
    local U, f = startupFixture()
    local Boot, rollbacks = require("orbitui_bootstrap"), 0
    local old_rollback = Boot.rollback
    Boot.rollback = function() rollbacks = rollbacks + 1 end
    U.started()
    U.menuItems()[5].callback()
    local confirm = f.shown[#f.shown]
    f.queue[1].fn() -- Cleanup now owns the update-operation guard.
    confirm.ok_callback(); f.queue[3].fn()
    H.eq(rollbacks, 0)
    assert(f.shown[#f.shown].text:find("already running", 1, true))
    f.queue[2].fn() -- Completion releases the guard.
    confirm.ok_callback(); f.queue[#f.queue].fn()
    H.eq(rollbacks, 1)
    Boot.rollback = old_rollback
    f.restore()
end)
H.finish()
