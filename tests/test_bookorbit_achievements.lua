local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;" .. package.path
local H = require("tests/helpers")
local Achievements
local cache_key = "simpleui_orbitui_bookorbit_achievements_cache"
local saved, tasks, requests, shown, online, plugin, client, key_file, notice
local token = "bok_" .. string.rep("a", 49)
local next_token = "bok_" .. string.rep("b", 49)
local screen = { scaleBySize = function(_, x) return x end, getWidth = function() return 600 end,
    getHeight = function() return 800 end }
local native = H.widget()
function native:getSize() return self.dimen or { w = self.w or self.width or 20, h = self.h or self.height or 20 } end
function native:paintTo() end
function native:free() end
function native:setText(value) self.text = value end
function native:onShowKeyboard() end
function native:getInputText() return self.input end
for _, path in ipairs({ "ui/widget/verticalgroup", "ui/widget/textboxwidget", "ui/widget/container/inputcontainer",
        "ui/widget/container/framecontainer", "ui/widget/container/topcontainer", "lib/bookshelf_clip_container",
        "ui/geometry", "ui/gesturerange",
        "ui/widget/infomessage", "ui/widget/inputdialog" }) do package.loaded[path] = native end
package.loaded["ui/font"] = { getFace = function() return {} end }
package.loaded["ui/uimanager"] = {
    scheduleIn = function(_, _, fn) tasks[#tasks + 1] = fn end,
    nextTick = function(_, fn) tasks[#tasks + 1] = fn end,
    getTopmostVisibleWidget = function() return shown end,
    isWidgetShown = function(_, w) return w == shown end,
    show = function(_, w) w.behind = shown; shown = w end,
    close = function(_, w) H.eq(w, shown); shown = w.behind end,
    setDirty = function() end,
}
package.loaded["ui/trapper"] = { wrap = function(_, fn) fn() end }
package.loaded["ui/network/manager"] = { isConnected = function() return online end }
package.loaded["device"] = { screen = screen }
package.loaded["infra/sui_store"] = { readSetting = function(_, k) return saved[k] end,
    saveSetting = function(_, k, v) saved[k] = v end }
package.loaded["core/orbitui_context"] = {
    plugin = function(name) H.eq(name, "bookorbit"); return plugin end,
    notify = function(text) notice = text end,
}
package.loaded.datastorage = { getSettingsDir = function() return "/sandbox/settings" end }
package.loaded.orbitui_bootstrap = {
    read = function(path, limit)
        H.eq(path, "/sandbox/settings/orbitui/bookorbit_achievements.key"); H.eq(limit, 128)
        return key_file
    end,
    atomicWrite = function(path, bytes)
        H.eq(path, "/sandbox/settings/orbitui/bookorbit_achievements.key")
        key_file = bytes
    end,
}
package.loaded["ffi/sha2"] = { sha256 = function(data)
    if data:find(next_token, 1, true) then return "hash-key-B" end
    if data:find(token, 1, true) then return "hash-key-A" end
    return data:find("different%-reader") and "hashB" or "hashA"
end }
package.loaded["logger"] = { warn = function(_, _, err) error(err) end }
package.loaded["lib/bookshelf_library_modal"] = {
    new = function(_, args)
        args.refresh = function(self) self.refreshes = (self.refreshes or 0) + 1 end
        return args
    end,
}
G_reader_settings = { readSetting = function(_, key) if key == "language" then return "sv_SE" end end }
local function catalogue()
    return { enabled = true, totalEarned = 3, totalAvailable = 5, categories = {
        { achievements = {
            { name = "Old", earned = true, awardedAt = "2026-10-12T12:30:00.000Z" },
            { name = "Progress", earned = false, currentProgress = 4, threshold = 12 },
            { name = "Newest", earned = true, awardedAt = "2026-11-17T12:30:00.000Z", description = "Read 40 books" },
        } },
        { achievements = {
            { name = "Middle", earned = true, awardedAt = "2026-11-16T12:30:00.000Z" },
            { name = "Secret name", description = "Secret detail", earned = false, hidden = true },
        } },
    } }
end
local function reset()
    saved, tasks, requests, shown, online, key_file, notice = {}, {}, {}, nil, true, nil, nil
    package.loaded.device.screen_saver_mode = false
    client = {
        username = "reader", userkey = "sync-only",
        request = function(self, method, path, body, headers)
            H.eq(method, "GET"); H.eq(path, "/achievements"); H.eq(self.username, nil); H.eq(self.userkey, nil)
            H.eq(body, nil); H.eq(headers["Accept-Language"], "sv")
            assert(headers["X-Api-Key"] == token or headers["X-Api-Key"] == next_token)
            requests[#requests + 1] = "catalogue"
            return catalogue()
        end,
        catalogDashboard = function(self)
            H.eq(self.username, "reader"); H.eq(self.userkey, "sync-only")
            requests[#requests + 1] = "dashboard"
            return { achievements = { earned = 3, total = 5,
                latest = { name = "Latest", awardedAt = "2026-11-17T12:30:00.000Z" },
                next = { name = "Next", threshold = 12, currentProgress = 4 } } }
        end,
        canForkSubprocess = function() return true end,
        runInSubprocess = function(_, fn)
            local body, err = fn()
            return true, { body = body, err = err }
        end,
    }
    plugin = { settings = { server_url = "https://example.invalid", username = "reader", userkey = "example-key" },
        newClient = function() return client end }
    package.loaded["adapters/orbitui_bookorbit_achievements"] = nil
    Achievements = require("adapters/orbitui_bookorbit_achievements")
end
local function drain()
    local count = 0
    while #tasks > 0 do
        count = count + 1
        assert(count < 20)
        table.remove(tasks, 1)()
    end
end
local function configure(value)
    local dialog = assert(Achievements.openKey())
    H.eq(dialog.input, ""); H.eq(dialog.text_type, "password")
    if value then
        dialog.input = value
        dialog.buttons[1][2].callback()
    else
        dialog.buttons[2][1].callback()
    end
    return dialog
end
local function observe(owner, done)
    shown = owner
    return { owner = owner, current = function() return shown == owner end, done = done or function() end }
end

H.test("normalises the full catalogue, sorts earned badges and shields locked secrets", function()
    reset()
    local data = assert(Achievements.fetch(client, "sv", token))
    H.eq(data.full, true); H.eq(data.earned, 3); H.eq(data.total, 5)
    H.eq(data.items[1].title, "Newest"); H.eq(data.items[2].title, "Middle"); H.eq(data.items[3].title, "Old")
    H.eq(data.items[4].progress, 4); H.eq(data.items[4].goal, 12)
    H.eq(data.items[5].secret, true); H.eq(data.items[5].title, nil); H.eq(data.items[5].description, nil)
    H.eq(#requests, 1)
end)

H.test("the installed plugin gets the summary directly and a rejected read key falls back to that summary", function()
    reset()
    local data = assert(Achievements.fetch(client, "sv"))
    H.eq(data.full, false); H.eq(data.earned, 3); H.eq(data.total, 5); H.eq(#data.items, 2)
    H.eq(data.items[1].title, "Latest"); H.eq(data.items[2].title, "Next")
    H.eq(#requests, 1); H.eq(requests[1], "dashboard")
    client.request = function() return nil, 401 end
    data = assert(Achievements.fetch(client, "sv", token))
    H.eq(data.issue, "key_rejected"); H.eq(data.full, false); H.eq(#requests, 2)
    client.request = function() return nil, 404 end
    data = assert(Achievements.fetch(client, "sv", token))
    H.eq(data.issue, "key_unavailable"); H.eq(data.full, false)
end)

H.test("rejects incomplete catalogue data and distinguishes absent summaries", function()
    reset()
    client.request = function()
        local data = catalogue()
        data.totalAvailable = data.totalAvailable + 1
        return data
    end
    local data, err = Achievements.fetch(client, "sv", token)
    H.eq(data, nil); H.eq(err, "error")
    client.request = function() return nil, 403 end
    client.catalogDashboard = function() return {} end
    H.eq(Achievements.fetch(client, "sv", token).status, "key_rejected")
    H.eq(Achievements.fetch(client, "sv").status, "no_summary")
end)

H.test("background reads coalesce, survive offline and are scoped to the BookOrbit account", function()
    reset()
    local owner, notified = {}, 0
    local observer = observe(owner, function(err) H.eq(err, nil); notified = notified + 1 end)
    saved.simpleui_orbitui_bookorbit_rows = false
    configure(token)
    H.eq(shown, owner)
    assert(Achievements.refresh(observer))
    assert(Achievements.refresh(observer))
    H.eq(#tasks, 1); H.eq(#requests, 0)
    drain()
    H.eq(notified, 1); H.eq(#requests, 1); H.eq(saved[cache_key].account, "hash-key-A")
    H.eq(Achievements.refresh(observer), false)
    online = false
    H.eq(Achievements.snapshot().items[1].title, "Newest")
    local started, err = Achievements.refresh(observer, true)
    H.eq(started, false); H.eq(err, "offline")
    plugin.settings.username = "different-reader"
    H.eq(Achievements.snapshot(), nil)
    saved.simpleui_orbitui_bookorbit_enabled = false
    local data, failure = Achievements.snapshot()
    H.eq(data, nil); H.eq(failure, "disabled")
end)

H.test("refresh keeps a cached view on transport errors and clears it when the server stops returning badges", function()
    reset()
    local observer = observe({})
    configure(token)
    assert(Achievements.refresh(observer)); drain()
    client.request = function() return nil, 503 end
    assert(Achievements.refresh(observer, true)); drain()
    H.eq(Achievements.snapshot().items[1].title, "Newest")
    configure(nil)
    client.catalogDashboard = function() return {} end
    assert(Achievements.refresh(observer, true)); drain()
    local data, failure = Achievements.snapshot()
    H.eq(data.items, nil); H.eq(failure, "no_summary")
end)

H.test("discard a background result after account switch and hide stale badges after authorization failure", function()
    reset()
    local o = observe({})
    assert(Achievements.refresh(o)); drain()
    client.catalogDashboard = function() return nil, 403 end
    assert(Achievements.refresh(o, true)); drain()
    local data, failure = Achievements.snapshot()
    H.eq(data.items, nil); H.eq(failure, "unauthorized")
    assert(Achievements.refresh(o, true))
    plugin.settings.username = "different-reader"
    drain()
    H.eq(Achievements.snapshot(), nil)
    H.eq(saved[cache_key].account, "hashA")
end)

H.test("leaving during a fetch lets the next visit retry immediately", function()
    reset()
    local owner = {}
    local observer = observe(owner)
    local fetch = client.runInSubprocess
    client.runInSubprocess = function(...)
        local completed, response = fetch(...)
        shown = nil
        return completed, response
    end
    assert(Achievements.refresh(observer)); drain()
    H.eq(Achievements.snapshot(), nil)
    client.runInSubprocess, shown = fetch, owner
    assert(Achievements.refresh(observer)); drain()
    H.eq(#requests, 2); H.eq(Achievements.snapshot().items[1].title, "Latest")
end)

H.test("key input never prefills a saved key and caches retire on key or account changes", function()
    reset()
    local o = observe({})
    local invalid = configure("not-a-key")
    assert(notice:find("bok_", 1, true)); H.eq(key_file, nil)
    invalid.buttons[1][1].callback()
    configure("  " .. token .. "  ")
    H.eq(key_file, "hashA\n" .. token .. "\n")
    H.eq(#requests, 0)
    assert(Achievements.refresh(o))
    configure(next_token)
    assert(Achievements.refresh(o))
    drain()
    H.eq(#requests, 1); H.eq(saved[cache_key].account, "hash-key-B")
    H.eq(Achievements.snapshot().full, true)
    plugin.settings.username = "different-reader"
    assert(Achievements.refresh(o)); drain()
    H.eq(requests[2], "dashboard"); H.eq(Achievements.snapshot().full, false)
    plugin.settings.username = "reader"
    configure(nil); H.eq(key_file, "")
    assert(Achievements.refresh(o)); drain()
    H.eq(requests[3], "dashboard"); H.eq(Achievements.snapshot().full, false)
end)

H.test("picker and hidden Home widgets stay passive; native and Dashboard taps reach the browser", function()
    reset()
    local descriptor
    Achievements.install({ register = function(d) descriptor = d end })
    H.eq(descriptor.default_on, false)
    H.eq(descriptor.category, "stats")
    descriptor.build(220, {}):paintTo()
    local owner = {}
    local widget = descriptor.build(220, { _screen_widget = owner })
    widget[1]:paintTo()
    H.eq(#tasks, 0)
    shown = owner
    widget[1]:paintTo()
    H.eq(#tasks, 1)
    H.eq(#requests, 0)
    widget[1]:free()
    drain()
    H.eq(#requests, 0)
    configure(token)
    assert(widget:onTapAchievements())
    local modal = shown
    drain()
    H.eq(modal.config.item_count(), 5)
    H.eq(modal.config.item_at(1).title, "Newest")
    modal.config.on_tab_change("earned"); H.eq(modal.config.item_count(), 3)
    modal.config.on_tab_change("remaining"); H.eq(modal.config.item_count(), 2)
    H.eq(modal.config.item_at(1).progress, 4)
    modal.config.on_cell_tap(modal.config.item_at(2))
    H.eq(shown.text:find("Secret name", 1, true), nil)
    require("adapters/orbitui_dashboard_sources").tapModule({ kind = "simpleui" }, descriptor, {})
    H.eq(shown.config.item_count(), 5)
end)
H.finish()
