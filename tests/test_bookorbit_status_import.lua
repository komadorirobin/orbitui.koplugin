local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local saved, files, books, remote, settings, queue, calls, writes, opens, changed
local online, top, generation, owner, during, fail, native_busy, now, work_calls, after_read
local serialized, shadow = {}, {}
local base_time, real_time = os.time{ year = 2026, month = 11, day = 1, hour = 12 }, os.time
os.time = function(t) if t then return real_time(t) end return now or base_time end
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end
local UI = { getTopmostVisibleWidget = function() return top end,
    scheduleIn = function(_, delay, fn) queue[#queue + 1] = { delay = delay, fn = fn } end,
    unschedule = function(_, fn) for i = #queue, 1, -1 do if queue[i].fn == fn then table.remove(queue, i) end end end }
local store = { readSetting = function(_, key) return saved[key] end,
    saveSetting = function(_, key, value) saved[key] = copy(value) end }
package.loaded["infra/sui_store"] = store
package.loaded["ui/uimanager"] = UI
package.loaded["ui/network/manager"] = { isOnline = function() return online end }
package.loaded["ffi/sha2"] = { sha256 = function(s) return "test-hash:" .. s end }
package.loaded["apps/reader/readerui"] = {}
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path)
    local f = files[path]; if f then return { mode = "file", size = f.size, modification = f.mtime } end
end, symlinkattributes = function(path)
    if shadow[path] then return shadow[path] end
    local file = path:gsub("%.metadata%.lua$", "")
    if settings[file] then return { mode = "file", size = 200, modification = 100 } end
end }
local function openSettings(path)
    opens = opens + 1
    local data = assert(settings[path], path)
    local view = copy(data)
    return { data = view, readSetting = function(_, key) return view[key] end,
        saveSetting = function(_, key, value) view[key] = value end,
        flush = function()
            if fail == "flush" then return false end
            settings[path] = view; writes = writes + 1; return "/sidecar"
        end }
end
package.loaded.docsettings = { open = function() error("must not call destructive DocSettings:open") end,
    findSidecarFile = function(_, path) if settings[path] then return path .. ".metadata.lua" end end,
    openSettingsFile = function(path) return openSettings((path:gsub("%.metadata%.lua$", ""))) end }
package.loaded.dump = function(data) serialized[#serialized + 1] = copy(data); return tostring(#serialized) end
package.loaded.orbitui_bootstrap = { atomicWrite = function(path, body)
    if fail == "flush" then error("write failure") end
    local file = path:gsub("%.metadata%.lua$", "")
    settings[file] = serialized[tonumber(body:match("return (%d+)"))]; writes = writes + 1
end }
package.loaded["ui/widget/booklist"] = { setBookInfoCacheProperty = function(path, key, status)
    H.eq(key, "status"); changed[path] = status
end }
local client_key = "not-a-real-token"
local client = { server_url = "https://example.invalid/api/v1", username = "fixture", userkey = client_key }
function client:query(path, params) return { path = path, params = params } end
function client:request(method, query)
    H.eq(method, "GET"); H.eq(query.path, "/koreader/plugin/catalog/read-statuses")
    assert(self.subprocess_depth == 1, "must not nest a BookOrbit worker")
    local ids, items = {}, {}
    for raw in query.params.ids:gmatch("%d+") do
        local id = tonumber(raw); ids[#ids + 1] = id
        if remote[id] then items[#items + 1] = copy(remote[id]) end
    end
    assert(#ids > 0 and #ids <= 200)
    calls[#calls + 1] = ids
    if during then local f = during; during = nil; f() end
    if fail == "404" then return nil, 404 end
    if fail == "network" or (fail == "second" and #calls == 2) then return nil, 503 end
    if fail == "foreign" then items = { { id = 99999, status = "read" } } end
    if fail == "duplicate" then items[#items + 1] = items[1] end
    if fail == "dictionary" then items = { key = items[1] } end
    if fail == "version" then return { version = 2, items = items } end
    return { version = 1, items = items }
end
local plugin = { isLoggedIn = function() return true end,
    newClient = function()
        local c = copy(client); c.userkey = client_key; return setmetatable(c, { __index = client })
    end,
    getSyncCoordinatorStatus = function() return { current = native_busy and {}, pending_count = 0 } end }
package.loaded["core/orbitui_context"] = { plugin = function(name) H.eq(name, "bookorbit"); return plugin end,
    refresh = function() end, notify = function() end }
local manager = { generation = function() return generation end,
    session = function() return { books = copy(books) } end,
    commit = function(expected, fn)
        H.eq(expected, generation); local state = { books = copy(books) }; fn(state)
        books = state.books; generation = generation + 1; return generation
    end }
package.loaded.bookorbit_state_manager = manager
package.loaded["adapters/orbitui_updates"] = { runTask = function(task, label, callback)
    H.eq(label, false); work_calls = work_calls + 1
    UI:scheduleIn(.1, function()
        if fail == "cancel" then callback{ error = "interrupted" }; return end
        local ok, value = pcall(task)
        if after_read and #calls > 0 then local fn = after_read; after_read = nil; fn() end
        callback{ ok = ok, value = value }
    end)
end }
local Integration = require("adapters/orbitui_integrations")
local S = Integration.statusImport
local function step()
    local row = table.remove(queue, 1)
    assert(row, "missing work"); row.fn(); return row.delay
end
local function finish()
    local turns = 0
    while S.isRunning() do step(); turns = turns + 1; assert(turns < 3000) end
    return turns
end
local function path(i) return "/books/" .. i .. ".epub" end
local function digest(i) return string.format("%032x", i) end
local function reset(n)
    if owner then S.stopped(owner) end
    saved, files, books, remote, settings, queue, calls, changed = {}, {}, {}, {}, {}, {}, {}, {}
    writes, opens, work_calls, now, generation, after_read, shadow = 0, 0, 0, base_time, 1, nil, {}
    online, top, native_busy, during, fail, client_key = true, { name = "homescreen" }, false, nil, nil, "not-a-real-token"
    package.loaded["apps/reader/readerui"].instance = nil
    G_reader_settings = { readSetting = function() end }
    for i = 1, n or 1 do
        files[path(i)] = { size = 100, mtime = 50 }
        books[digest(i)] = { file = path(i), bookId = i, statusSynced = "reading", statusSyncedModified = "2026-10-29", statusSyncedKnown = true,
            ratingSynced = 3, statsWatermark = 800, annWatermark = "keep" }
        settings[path(i)] = { summary = { status = "reading", modified = "2026-10-29", rating = 3, note = "keep" },
            partial_md5_checksum = digest(i), percent_finished = .23, last_page = 27, last_xpointer = "keep-position", bookmarks = { "keep" } }
        remote[i] = { id = i, status = "read", updatedAt = "2026-10-31T12:00:00.000Z", finishedAt = "2026-10-30T00:00:00.000Z" }
    end
    owner = {}; S.started(owner)
end
local function enable() Integration.setBookOrbitEnabled("status", true) end
local function request(opts) local ok, err = S.request(opts or {}); assert(ok, tostring(err)); return finish() end
H.test("disabled by default: startup, settings and events do no link, sidecar or network work", function()
    reset(3000)
    for _, event in ipairs{ "onResume", "onCloseDocument", "onReaderReady" } do S.event(event) end
    local rows = S.items(); H.eq(#rows, 5); H.eq(#queue, 0); H.eq(work_calls, 0); H.eq(opens, 0); H.eq(#calls, 0)
    H.eq(rows[1].checked_func(), false)
end)
H.test("enabled foreground start only schedules; a 3000-match poll costs 15 bounded GETs off the paint path", function()
    reset(3000); enable()
    H.eq(#calls, 0); H.eq(opens, 0); H.eq(work_calls, 0); H.eq(#queue, 1); H.eq(queue[1].delay, 2)
    step(); finish()
    H.eq(#calls, 15); H.eq(writes, 3000); H.eq(S.last.changed, 3000)
    H.eq(S.last.error, nil)
    H.eq(changed[path(3000)], "complete")
    local book = books[digest(1)]
    H.eq(book.statusSynced, "complete"); H.eq(book.ratingSynced, 3); H.eq(book.statsWatermark, 800); H.eq(book.annWatermark, "keep")
    local ds = settings[path(1)]
    H.eq(ds.summary.modified, "2026-10-30"); H.eq(ds.summary.rating, 3); H.eq(ds.summary.note, "keep")
    H.eq(ds.percent_finished, .23); H.eq(ds.last_page, 27); H.eq(ds.last_xpointer, "keep-position"); H.eq(ds.bookmarks[1], "keep")
    H.eq(S.request(), false); H.eq(#calls, 15)
end)
H.test("publication yields after at most four sidecars and an unchanged poll writes no sidecars", function()
    reset(12); enable(); assert(S.request())
    step() -- delayed timer, coalesces with running work
    step() -- link worker
    step() -- GET worker and first apply slice
    H.eq(writes, 4)
    step(); H.eq(writes, 8)
    finish(); H.eq(writes, 12)
    now = now + 901; opens = 0; request(); H.eq(writes, 12); H.eq(S.last.changed, 0); H.eq(opens, 0)
end)
H.test("newer, same-day, undated existing and invalid dates remain local", function()
    for _, date in ipairs{ "2026-11-01", "2026-10-31", "2026-02-30", "bad", false } do
        reset(); enable(); settings[path(1)].summary.modified = date or nil
        request(); H.eq(writes, 0); H.eq(S.last.skipped, 1)
    end
    reset(); enable(); settings[path(1)].summary = {}; request(); H.eq(writes, 1)
end)
H.test("unknown/malformed responses and unsupported servers fail closed without last-success promotion", function()
    for _, mode in ipairs{ "404", "network", "foreign", "duplicate", "dictionary", "version", "cancel" } do
        reset(); enable(); fail = mode; request()
        H.eq(writes, 0); assert(S.last.error); H.eq(saved.simpleui_orbitui_bookorbit_status_result, nil)
    end
    for _, field in ipairs{ "status", "updatedAt", "finishedAt" } do
        reset(); enable(); remote[1][field] = "malformed"; request(); H.eq(writes, 0); assert(S.last.error)
    end
end)
H.test("neutral remote statuses do not reset local progress; mapping follows native status categories", function()
    for remote_status, expected in pairs{ unread = false, want_to_read = false, abandoned = "abandoned", on_hold = "abandoned",
            rereading = "reading", reading = "reading", skimmed = "complete" } do
        reset(); enable(); remote[1].status = remote_status
        request(); H.eq(settings[path(1)].summary.status, expected or "reading")
        H.eq(settings[path(1)].percent_finished, .23)
    end
end)
H.test("active or parked reader, pending Undo, changed sidecar/bytes and removed files are protected", function()
    local changes = {
        function() package.loaded["apps/reader/readerui"].instance = { document = { file = path(1) } } end,
        function() G_reader_settings.readSetting = function() return { account = { opening = { file = path(1), phase = "undo_pending" } } } end end,
        function() settings[path(1)].last_page = 40 end,
        function() settings[path(1)].summary.status = "abandoned" end,
        function() files[path(1)].mtime = 70 end,
        function() files[path(1)] = nil end,
    }
    for _, change in ipairs(changes) do reset(); enable(); after_read = change; request(); H.eq(writes, 0); H.eq(S.last.skipped, 1) end
end)
H.test("policy off/on, credentials, links, navigation and coordinator changes retire late results", function()
    for _, change in ipairs{
        function() Integration.setBookOrbitEnabled("status", false); Integration.setBookOrbitEnabled("status", true) end,
        function() client_key = "replacement" end,
        function() generation = generation + 1 end,
        function() S.event("onShowingReader") end,
        function() native_busy = true end,
        function() top = { name = "ReaderUI" } end,
    } do reset(); enable(); during = change; request(); H.eq(writes, 0); H.eq(S.last.error, "retired") end
end)
H.test("offline, busy native sync and unsupported clients never start a worker or turn on Wi-Fi", function()
    reset(); enable(); online = false; H.eq(select(2, S.request()), "offline"); H.eq(work_calls, 0)
    online = true; native_busy = true; H.eq(select(2, S.request()), "busy"); H.eq(work_calls, 0)
end)
H.test("ambiguous links, missing checksums and deleted/absent server entries are ignored, not guessed", function()
    reset(2); enable(); books[string.rep("a", 32)] = copy(books[digest(1)])
    settings[path(2)].partial_md5_checksum = "different"; request(); H.eq(writes, 0); H.eq(#calls, 1)
    reset(); enable(); remote[1] = nil; request(); H.eq(writes, 0); H.eq(S.last.error, nil)
end)
H.test("partial HTTP failures preserve completed batches and acknowledge their original canonical status", function()
    reset(201); enable(); fail = "second"; request()
    H.eq(writes, 200); H.eq(books[digest(1)].statusSynced, "complete")
    H.eq(settings[path(201)].summary.status, "reading"); H.eq(S.last.error, "network")
    H.eq(saved.simpleui_orbitui_bookorbit_status_result, nil)
end)
H.test("failed sidecar publication cannot advance the canonical baseline", function()
    reset(); enable(); fail = "flush"; request(); H.eq(writes, 0); H.eq(books[digest(1)].statusSynced, "reading")
    H.eq(S.last.error, "storage")
end)
H.test("existing temporary files and competing metadata locations are never overwritten or repaired", function()
    reset(); enable(); shadow[path(1) .. ".metadata.lua.tmp"] = { mode = "link" }; request()
    H.eq(writes, 0); H.eq(S.last.error, "storage")
    local DS = package.loaded.docsettings
    DS.getSidecarDir = function(_, file, location) return file .. "." .. location end
    DS.getSidecarFilename = function() return "metadata.epub.lua" end
    DS.isHashLocationEnabled = function() return false end
    reset(); enable(); shadow[path(1) .. ".dir/metadata.epub.lua"] = { mode = "file" }; request()
    H.eq(writes, 0); H.eq(opens, 0); H.eq(S.last.skipped, 1)
    DS.getSidecarDir, DS.getSidecarFilename, DS.isHashLocationEnabled = nil, nil, nil
end)
H.test("unchanged server status does not reverse an intentional unsynced local edit", function()
    reset(); enable(); remote[1].status = "reading"; settings[path(1)].summary.status = "complete"
    request(); H.eq(writes, 0); H.eq(opens, 0); H.eq(settings[path(1)].summary.status, "complete")
end)
if os.getenv("BOOKORBIT_STATUS_SOURCE") then
    H.test("the pinned native BookOrbit payload builder does not echo an imported completion", function()
        reset(); enable()
        books[digest(1)].reviewSyncedKnown, books[digest(1)].reviewSyncedNote = true, "keep"
        request()
        package.loaded.bookorbit_capabilities = {}
        local native = dofile(os.getenv("BOOKORBIT_STATUS_SOURCE") .. "/bookorbit_sidecar.lua")
        local summary = settings[path(1)].summary
        local payload = native.buildStatePayload(digest(1), books[digest(1)], {
            status = summary.status, status_modified = summary.modified, rating = summary.rating, review_note = summary.note,
        })
        H.eq(payload, nil)
    end)
end
H.test("status settings are bilingual and master switch preserves opt-in without touching foreign sync", function()
    reset(); enable(); saved.foreign_sync = true
    Integration.setBookOrbitEnabled("enabled", false); H.eq(S.request(), false)
    Integration.setBookOrbitEnabled("enabled", true); H.eq(Integration.bookOrbitEnabled("status"), true)
    H.eq(saved.foreign_sync, true)
    local _ = require("core/orbitui_i18n")
    H.eq(_("Automatic reading-status import", "sv"), "Hämta lässtatus automatiskt")
end)
os.time = real_time
H.finish()
