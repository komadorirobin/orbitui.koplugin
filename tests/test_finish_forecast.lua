local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_dashboard")
local function events(now, pages, days, count, seconds)
    local out, t = {}, os.date("*t", now)
    for day = 1, days or 3 do
        local stamp = os.time{ year = t.year, month = t.month, day = t.day - day, hour = 12 }
        for i = 1, count or 10 do out[#out + 1] = {
            page = #out + 1, start_time = stamp + i, duration = seconds or 60, total_pages = pages or 400 } end
    end
    return out
end
local fixed = os.time{ year = 2026, month = 11, day = 1, hour = 12 }
H.test("forecast uses this book's recent speed and all fourteen calendar days, not active days alone", function()
    local data = Model.finishForecast({ pages = 400, percent = .5 }, events(fixed), fixed)
    H.eq(data.phase, "ready"); H.eq(data.remaining_secs, 12000); H.eq(data.daily_secs, 1800 / 14)
    H.eq(data.days, 94); H.eq(data.sample_pages, 30); H.eq(data.active_days, 3)
    local t = os.date("*t", fixed)
    H.eq(data.date, os.date("%Y-%m-%d", os.time{ year = t.year, month = t.month, day = t.day + 94, hour = 12 }))
end)
H.test("calendar windows and dates use local midnight/noon across DST and year boundaries", function()
    local since, ending = Model.forecastWindow(fixed)
    H.eq(os.date("%Y-%m-%d %H:%M", since), "2026-10-18 00:00")
    H.eq(os.date("%Y-%m-%d %H:%M", ending), "2026-11-01 00:00")
    if os.getenv("TZ") == "Europe/Stockholm" then H.eq(ending - since, 14 * 86400 + 3600) end
    local newyear = os.time{ year = 2026, month = 12, day = 31, hour = 23 }
    local result = Model.finishForecast({ pages = 400, percent = .999 }, events(newyear), newyear)
    H.eq(result.date, "2027-01-01"); H.eq(result.days, 1)
end)
H.test("today, future and old events never inflate a complete-day forecast", function()
    local rows = events(fixed); local baseline = Model.finishForecast({ pages = 400, percent = .5 }, rows, fixed)
    for _, ts in ipairs{ fixed, fixed + 86400, fixed - 20 * 86400 } do
        rows[#rows + 1] = { page = 100, start_time = ts, duration = 80000, total_pages = 400 }
    end
    local result = Model.finishForecast({ pages = 400, percent = .5 }, rows, fixed)
    H.eq(result.remaining_secs, baseline.remaining_secs); H.eq(result.daily_secs, baseline.daily_secs)
end)
H.test("page layouts are not mixed for speed; their real reading time still contributes to daily pace", function()
    local rows = events(fixed, 800)
    local result = Model.finishForecast({ pages = 400, percent = .5 }, rows, fixed)
    H.eq(result.phase, "insufficient"); H.eq(result.remaining_secs, nil); H.eq(result.daily_secs, 1800 / 14)
    for _, row in ipairs(events(fixed, 400, 1)) do rows[#rows + 1] = row end
    result = Model.finishForecast({ pages = 400, percent = .5 }, rows, fixed)
    H.eq(result.phase, "ready"); H.eq(result.sample_pages, 10)
end)
H.test("insufficient samples can show reading time but cannot invent a date", function()
    for _, spec in ipairs{ { 1, 10, 60 }, { 3, 2, 60 }, { 3, 10, 1 } } do
        local result = Model.finishForecast({ pages = 400, percent = .5 }, events(fixed, 400, spec[1], spec[2], spec[3]), fixed)
        H.eq(result.phase, "insufficient"); H.eq(result.date, nil)
    end
    assert(Model.finishForecast({ pages = 400, percent = .5 }, events(fixed, 400, 1), fixed).remaining_secs)
end)
H.test("idle/repeated page time is capped and malformed rows cannot produce NaNs or false dates", function()
    local rows = events(fixed, 400, 3, 10, 9000)
    rows[#rows + 1] = { page = 1, start_time = fixed - 86400, duration = 9000, total_pages = 400 }
    rows[#rows + 1] = { page = 0 / 0, start_time = fixed - 86400, duration = 60, total_pages = 400 }
    rows[#rows + 1] = { page = 1, start_time = fixed - 86400, duration = math.huge, total_pages = 400 }
    local result = Model.finishForecast({ pages = 400, percent = .5 }, rows, fixed)
    H.eq(result.sample_pages, 30); H.eq(result.remaining_secs, 24000); H.eq(result.daily_secs, 3720 / 14)
    for _, pct in ipairs{ -.1, 1.1, math.huge, 0 / 0 } do H.eq(Model.finishForecast({ pages = 400, percent = pct }, rows, fixed).phase, "missing") end
end)
H.test("finished, paused, unread, missing, long-horizon and over-limit states are honest", function()
    H.eq(Model.finishForecast({ percent = 1 }, {}, fixed).phase, "finished")
    H.eq(Model.finishForecast({ percent = .5, status = "complete" }, {}, fixed).phase, "finished")
    H.eq(Model.finishForecast({ percent = .5, status = "abandoned" }, {}, fixed).phase, "onhold")
    H.eq(Model.finishForecast({ percent = 0 }, {}, fixed).phase, "unstarted")
    H.eq(Model.finishForecast({ percent = .5 }, {}, fixed).phase, "missing")
    H.eq(Model.finishForecast({ pages = 1000000, percent = .1 }, events(fixed, 1000000), fixed).phase, "distant")
    local many = {}; for i = 1, 4097 do many[i] = {} end
    local result = Model.finishForecast({ pages = 400, percent = .5 }, many, fixed)
    H.eq(result.phase, "limited"); H.eq(result.remaining_secs, nil)
end)

local UI, Shelves, owner, history, saved, attrs, payload, queue, queued, opens, closes, queries, reads, writes, frees, refreshes
local rows, broken, guard, db_pages, language, size_scale, native_sql, db_path
local file, md5 = "/books/current.epub", string.rep("a", 32)
local function columns(list)
    local result = { {}, {}, {}, {} }
    for _, event in ipairs(list) do
        result[1][#result[1] + 1] = event.page; result[2][#result[2] + 1] = event.start_time
        result[3][#result[3] + 1] = event.duration; result[4][#result[4] + 1] = event.total_pages
    end
    return result
end
local W = H.widget()
function W:getSize() return { w = self.w or self.width or 500, h = self.h or self.height or 20 } end
function W:free() frees = frees + 1 end
function W:paintTo(...) return "native", nil, select("#", ...) end
for _, name in ipairs{ "ui/widget/verticalgroup", "ui/widget/textboxwidget", "ui/widget/container/framecontainer", "lib/bookshelf_clip_container" } do package.loaded[name] = W end
package.loaded["ui/font"] = { getFace = function(_, _, size) assert(size <= 20, "Font:getFace already scales its size"); return { size = size } end }
package.loaded["infra/sui_store"] = { readSetting = function(_, key) return saved[key] end,
    saveSetting = function() writes = writes + 1; error("forecast must not write settings") end }
package.loaded["core/orbitui_context"] = { notify = function() end }
package.loaded.logger = { warn = function() end }
package.loaded.device = { screen_saver_mode = false, screen = { scaleBySize = function(_, n) return n * size_scale end } }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path) return attrs[path] end,
    symlinkattributes = function(path) return attrs[path] end }
package.loaded["infra/sui_config"] = { isStatsSyncGuarded = function() return guard end, getStatsDbPath = function() return db_path end,
    openStatsDB = function() error("shared opener may write indexes") end }
package.loaded.docsettings = {
    findSidecarFile = function(_, path) reads = reads + 1; H.eq(path, file); return "/sidecar.lua" end,
    openSettingsFile = function(path)
        reads = reads + 1; H.eq(path, "/sidecar.lua"); if broken == "sidecar" then error("corrupt settings") end
        return { readSetting = function(_, key) return payload[key] end }
    end,
    open = function() error("must not repair metadata") end, close = function() error("must not flush metadata") end,
}
local SQL = { open = function(path, mode)
    opens = opens + 1; H.eq(path, db_path); H.eq(mode, "ro")
    if broken == "open" then error("unavailable DB") end
    if native_sql then return native_sql.open(path, mode) end
    return { close = function() closes = closes + 1; if broken == "close" then error("close failure") end end,
        exec = function(_, sql)
            queries[#queries + 1] = sql
            assert(not sql:find("CREATE", 1, true) and not sql:find("UPDATE", 1, true) and not sql:find("INSERT", 1, true))
            if broken == "query" then error("busy DB") end
            if sql:find("SELECT id, pages", 1, true) then return { { 3 }, { db_pages } } end
            if sql:find("FROM page_stat_data", 1, true) then
                assert(sql:find("LIMIT 4097", 1, true)); assert(sql:find("start_time>=", 1, true))
                if broken == "changed" then attrs[db_path].size = 999 end
                return columns(rows)
            end
        end }
end }
package.loaded["lua-ljsqlite3/init"] = SQL
UI = { _simpleui_navigation_generation = 1,
    scheduleIn = function(_, delay, fn) assert(delay > 0); queue[#queue + 1] = fn; queued[#queued + 1] = fn end,
    unschedule = function(_, fn) for i = #queue, 1, -1 do if queue[i] == fn then table.remove(queue, i) end end end,
    isWidgetShown = function(_, w) return w == owner and not owner.hidden end,
    getTopmostVisibleWidget = function() return owner.covered and {} or owner end,
}
package.loaded["ui/uimanager"] = UI
local function fixture()
    owner, history, saved, queue, queued, queries = {}, {}, {}, {}, {}, {}
    opens, closes, reads, writes, frees, refreshes = 0, 0, 0, 0, 0, 0
    broken, guard, db_pages, language, size_scale, native_sql = nil, false, 400, "en", 1, nil
    db_path = "/statistics.sqlite3"
    attrs = { [file] = { mode = "file", size = 100, modification = 100 },
        [db_path] = { mode = "file", size = 100, modification = 100 },
        ["/sidecar.lua"] = { mode = "file", size = 100, modification = 100 } }
    payload = { percent_finished = .5, doc_pages = 400, partial_md5_checksum = md5, doc_props = { title = "Current book" }, summary = {} }
    rows = events(os.time())
    UI._simpleui_navigation_generation = 1; package.loaded.device.screen_saver_mode = false
    G_reader_settings = { readSetting = function(_, key, default) if key == "language" then return language end; return default end }
    package.loaded["adapters/orbitui_home_shelves"] = nil
    Shelves = require("adapters/orbitui_home_shelves")
    return Shelves.forecastModule()
end
local function ctx()
    return { pfx = "simpleui_hs_", current_fp = file, _screen_widget = owner,
        prefetched = { [file] = { title = "Custom title" } }, refresh_fn = function() refreshes = refreshes + 1 end }
end
local function drain() while #queue > 0 do table.remove(queue, 1)() end end
local function content(widget) return widget[1][1] end
H.test("registration, discovery, sizing and previews are lazy/off and never write placements", function()
    local mod = fixture(); local registered = {}
    Shelves.install{ register = function(def) registered[def.id] = def end }
    local def = registered.orbitui_finish_forecast
    H.eq(def.default_on, false); H.eq(def.needs.recent, 1); H.eq(def.needs.db, nil); H.eq(def.needs.stats, nil)
    H.eq(def.getHeight(), 180); H.eq(opens, 0); H.eq(reads, 0); H.eq(writes, 0); H.eq(#queue, 0)
    local preview = ctx(); preview.preview = true; mod.build(500, preview); drain()
    H.eq(opens, 0); H.eq(reads, 0)
end)
H.test("Home builds no synchronous data; deferred RO data refreshes once and warm builds do not query", function()
    local mod = fixture(); local c = ctx(); local widget = mod.build(500, c)
    H.eq(reads, 0); H.eq(opens, 0); H.eq(#queue, 1); H.eq(content(widget)[1].text, "Custom title")
    drain(); H.eq(opens, 1); H.eq(closes, 1); H.eq(refreshes, 1)
    H.eq(Shelves.forecastState(c.pfx, file).phase, "ready"); H.eq(writes, 0)
    local ready = mod.build(500, c); drain(); H.eq(opens, 1); assert(content(ready)[2].text:find("Around", 1, true))
    widget:free(); H.eq(Shelves.forecastState(c.pfx, file).phase, "ready")
    ready:free(); ready:free(); H.eq(frees, 2)
end)
H.test("RO handle closes on query, close and fingerprint failures; errors can explicitly retry", function()
    for _, failure in ipairs{ "open", "query", "close", "changed", "sidecar" } do
        local mod = fixture(); broken = failure; local c = ctx(); mod.build(500, c); drain()
        H.eq(Shelves.forecastState(c.pfx, file).phase, failure == "changed" and "changed" or "error")
        H.eq(closes, (failure == "open" or failure == "sidecar") and 0 or 1)
        broken = nil; mod.getMenuItems(c)[1].callback(); mod.build(500, c); drain()
        H.eq(Shelves.forecastState(c.pfx, file).phase, "ready")
    end
end)
H.test("sync, missing/unsafe metadata, injected checksum and unsupported pagination fail without writes", function()
    for _, failure in ipairs{ "sync", "metadata", "large", "symlink", "md5", "pages", "missingdb", "newfile" } do
        fixture()
        if failure == "sync" then guard = true elseif failure == "metadata" then attrs["/sidecar.lua"] = nil
        elseif failure == "large" then attrs["/sidecar.lua"].size = 600 * 1024
        elseif failure == "symlink" then attrs["/sidecar.lua"].mode = "link"
        elseif failure == "md5" then payload.partial_md5_checksum = "'; DROP TABLE book;--"
        elseif failure == "pages" then db_pages = 800 elseif failure == "newfile" then attrs[file].modification = 200 else attrs[db_path] = nil end
        local result = Shelves.forecastRead(file, os.time())
        H.eq(result.phase, failure == "sync" and "sync" or failure == "pages" and "pagination" or failure == "missingdb" and "unavailable" or failure == "newfile" and "changed" or "missing")
        H.eq(opens, failure == "pages" and 1 or 0); H.eq(writes, 0)
    end
end)
H.test("finished and unread state need no database; remote/no-book context cannot start a worker", function()
    local mod = fixture(); payload.percent_finished = 1; H.eq(Shelves.forecastRead(file, os.time()).phase, "finished"); H.eq(opens, 0)
    payload.percent_finished = 0; H.eq(Shelves.forecastRead(file, os.time()).phase, "unstarted"); H.eq(opens, 0)
    H.eq(Shelves.forecastRead("OPDS://remote", os.time()).phase, "empty")
    local c = ctx(); c.current_fp = "OPDS://remote"; mod.build(500, c); drain(); H.eq(opens, 0)
end)
H.test("canceled/dequeued jobs and old widget frees cannot affect replacement work", function()
    local mod = fixture(); local c = ctx(); local old = mod.build(500, c); local stale = queued[1]
    local current = mod.build(500, c); old:free(); stale(); H.eq(opens, 0); H.eq(#queue, 1)
    drain(); H.eq(opens, 1); H.eq(Shelves.forecastState(c.pfx, file).phase, "ready"); current:free()
end)
H.test("module previews cannot cancel an already mounted forecast or replace its lease", function()
    local mod = fixture(); local c = ctx(); mod.build(500, c)
    local preview = ctx(); preview.preview = true; mod.build(300, preview):free()
    drain(); H.eq(opens, 1); H.eq(Shelves.forecastState(c.pfx, file).phase, "ready")
end)
H.test("foreign modal, hidden/parked owner, page, dashboard page, target and navigation changes stop pending reads", function()
    for _, change in ipairs{ "modal", "hidden", "parked", "page", "dashboard", "target", "navigation" } do
        local mod = fixture(); local c = ctx(); c.orbitui_dashboard_hosted = true; c.height = 100
        mod.build(300, c)
        if change == "modal" then owner.covered = true elseif change == "hidden" then owner.hidden = true
        elseif change == "parked" then owner._parked = true elseif change == "page" then owner._current_page = 2
        elseif change == "dashboard" then owner._orbitui_dashboard_module_page = 2
        elseif change == "target" then c.current_fp = "/books/other.epub" else UI._simpleui_navigation_generation = 2 end
        drain(); H.eq(opens, 0); H.eq(Shelves.forecastState(c.pfx, file).phase, "paused")
    end
end)
H.test("suspend/rotation/teardown retire work and resume does not retry until explicit Refresh", function()
    for _, event in ipairs{ "onSuspend", "onSetRotationMode", "onScreenResize", "onShowingReader", "onTeardown" } do
        local mod = fixture(); local c = ctx(); mod.build(500, c); local stale = queued[1]
        Shelves.forecastEvent(event); stale(); Shelves.forecastEvent("onResume"); mod.build(500, c); drain(); H.eq(opens, 0)
        mod.getMenuItems(c)[1].callback(); mod.build(500, c); drain(); H.eq(opens, 1)
    end
end)
H.test("close/metadata invalidation, DB or sidecar change, expiry and midnight require fresh data", function()
    for _, change in ipairs{ "onCloseDocument", "onBookMetadataChanged", "db", "sidecar", "expiry", "midnight" } do
        local mod = fixture(); local c = ctx(); mod.build(500, c); drain(); local state = Shelves.forecastState(c.pfx, file)
        if change:sub(1, 2) == "on" then Shelves.forecastEvent(change)
        elseif change == "db" then attrs[db_path].size = 200 elseif change == "sidecar" then attrs["/sidecar.lua"].size = 200
        elseif change == "expiry" then state.expires = 0 else state.day = "1970-01-01" end
        mod.build(500, c); drain(); H.eq(opens, 2); H.eq(Shelves.forecastState(c.pfx, file).phase, "ready")
    end
end)
H.test("completed forecasts survive sleep/rotation without an unnecessary query or manual refresh", function()
    local mod = fixture(); local c = ctx(); mod.build(500, c); drain()
    for _, event in ipairs{ "onSuspend", "onSetRotationMode", "onScreenResize" } do
        Shelves.forecastEvent(event); Shelves.forecastEvent("onResume"); mod.build(500, c); drain()
        H.eq(Shelves.forecastState(c.pfx, file).phase, "ready"); H.eq(opens, 1)
    end
end)
H.test("dashboard proxy resolves its real owner and tiny/high-DPI layouts remain bounded with one font scaling", function()
    local mod = fixture(); size_scale = 2; language = "sv"; local c = ctx()
    c.orbitui_dashboard_hosted, c.height = true, 1; c._screen_widget = setmetatable({}, { __index = owner })
    c.prefetched[file].title = string.rep("漫畫", 100)
    local tiny = mod.build(1, c); H.eq(tiny.w, 1); H.eq(tiny.h, 1); drain(); H.eq(opens, 1)
    c.height = 140; local ready = mod.build(300, c); assert(content(ready)[2].text:find("Ungefär", 1, true))
    H.eq(ready.h, 140); for _, line in ipairs(content(ready)) do assert(line.height_adjust == false); assert(line.height_overflow_show_ellipsis) end
    H.eq(writes, 0)
end)
H.test("bounded states evict old placements and release their owner/job", function()
    local mod = fixture(); local c = ctx(); mod.build(500, c); local old = Shelves.forecastState(c.pfx, file); local stale = queued[1]
    for i = 1, 9 do Shelves.forecastState("custom" .. i, file) end
    H.eq(old.lease, nil); H.eq(old.job, nil); stale(); H.eq(opens, 0)
end)
H.test("unexpected provider failures settle into an error instead of leaving a frozen loading state", function()
    local mod = fixture(); local c = ctx(); local original = Shelves.forecastRead
    Shelves.forecastRead = function() error("unexpected filesystem failure") end
    mod.build(500, c); drain(); H.eq(Shelves.forecastState(c.pfx, file).phase, "error"); H.eq(refreshes, 1)
    Shelves.forecastRead = original
    mod.getMenuItems(c)[1].callback(); mod.build(500, c); drain(); H.eq(Shelves.forecastState(c.pfx, file).phase, "ready")
end)
H.test("explicit refresh under a SUI menu waits for visible paint, enqueues once and preserves native paint arguments/results", function()
    local mod = fixture(); local c = ctx(); mod.build(500, c); drain(); H.eq(opens, 1)
    owner.covered = true
    -- The native menu refresh rebuilds Home before it closes itself.
    mod.getMenuItems(c)[1].callback(); local refreshed = mod.build(500, c)
    H.eq(#queue, 0); refreshed:paintTo({}, nil, 2); H.eq(#queue, 0); H.eq(opens, 1)
    owner.covered = false
    local first, second, count = refreshed:paintTo({}, nil, 2)
    H.eq(first, "native"); H.eq(second, nil); H.eq(count, 3); H.eq(#queue, 1); H.eq(opens, 1)
    refreshed:paintTo({}, 1, 2); H.eq(#queue, 1); drain(); H.eq(opens, 2)
    -- Losing visibility after enqueue pauses it; merely painting again is not a retry.
    mod.getMenuItems(c)[1].callback(); local pending = mod.build(500, c); owner.covered = true; drain()
    owner.covered = false; pending:paintTo({}, 0, 0); drain(); H.eq(opens, 2)
    H.eq(Shelves.forecastState(c.pfx, file).phase, "paused")
end)

local native = os.getenv("ORBITUI_NATIVE_SQLITE_DIR")
local statistics = os.getenv("ORBITUI_NATIVE_STATISTICS")
if jit and native and statistics then
    package.path = native .. "/?.lua;" .. package.path
    local ffi = require("ffi")
    ffi.cdef[[void *malloc(size_t); void free(void *);]]
    package.loaded["ffi/posix_h"] = true
    ffi.loadlib = function(name, version) return ffi.load(jit.os == "OSX" and name or ("lib" .. name .. ".so." .. version)) end
    package.loaded["lua-ljsqlite3/init"] = nil
    local Native = require("lua-ljsqlite3/init"); package.loaded["lua-ljsqlite3/init"] = SQL
    local f = assert(io.open(statistics)); local source = f:read("*a"); f:close()
    local env = { ReaderStatistics = {}, Device = { canUseWAL = function() return false end }, DB_SCHEMA_VERSION = 20221111, string = string }
    for _, name in ipairs{ "SCHEMA", "INDEX", "VIEW_SCHEMA" } do
        local key = "STATISTICS_DB_PAGE_STAT_" .. (name == "VIEW_SCHEMA" and "VIEW_SCHEMA" or "DATA_" .. name)
        env[key] = assert(source:match("local " .. key .. " = %[%[(.-)%]%]"), key)
    end
    local body = assert(source:match("(function ReaderStatistics:createDB%b().-\nend)"))
    setfenv(assert(loadstring(body)), env)()
    local native_path
    H.test("real SQLite/native statistics schema: checksum selects the right book, excludes today and stays RO", function()
        fixture(); native_sql = Native
        local pipe = assert(io.popen("mktemp -d /tmp/orbitui-forecast.XXXXXX")); local dir = assert(pipe:read("*l")); assert(pipe:close())
        db_path = dir .. "/statistics.sqlite3"; native_path = db_path; attrs[db_path] = { mode = "file", size = 100, modification = 100 }
        local conn = Native.open(db_path)
        env.ReaderStatistics:createDB(conn)
        conn:exec(string.format("INSERT INTO book(id,title,authors,md5,pages,last_open) VALUES(3,'Target','A','%s',400,1),(4,'Other','B','%s',400,2)", md5, string.rep("b", 32)))
        local insert = conn:prepare("INSERT INTO page_stat_data VALUES(?,?,?,?,?)")
        for _, row in ipairs(rows) do insert:reset():bind(3, row.page, row.start_time, row.duration, row.total_pages):step() end
        insert:reset():bind(4, 99, rows[1].start_time, 90000, 400):step()
        insert:reset():bind(3, 99, os.time(), 90000, 400):step(); insert:close(); conn:close()
        local function bytes() local f = assert(io.open(db_path, "rb")); local b = f:read("*a"); f:close(); return b end
        local before = bytes(); local result = Shelves.forecastRead(file, os.time())
        H.eq(result.phase, "ready"); H.eq(result.remaining_secs, 12000); H.eq(result.daily_secs, 1800 / 14); H.eq(bytes(), before)
        local ro = Native.open(db_path, "ro"); H.eq(pcall(ro.exec, ro, "UPDATE book SET pages=1"), false); ro:close()
    end)
    H.test("native time-index query plan bounds the window; pagination, stale checksum and row cap never return partial predictions", function()
        native_sql = Native; db_path = native_path
        local conn = Native.open(db_path, "rw")
        local since, ending = Model.forecastWindow(os.time())
        local plan = conn:exec(string.format([[EXPLAIN QUERY PLAN SELECT page,start_time,duration,total_pages
            FROM page_stat_data INDEXED BY page_stat_data_start_time WHERE id_book=3 AND start_time>=%d AND start_time<%d
            ORDER BY start_time DESC LIMIT 4097]], since, ending))
        local details = table.concat(plan[4], " "); assert(details:find("page_stat_data_start_time", 1, true)); assert(details:find("start_time>? AND start_time<?", 1, true))
        conn:exec("UPDATE book SET pages=800 WHERE id=3")
        H.eq(Shelves.forecastRead(file, os.time()).phase, "pagination")
        conn:exec("UPDATE book SET pages=400 WHERE id=3")
        payload.partial_md5_checksum = string.rep("c", 32)
        H.eq(Shelves.forecastRead(file, os.time()).phase, "missing"); payload.partial_md5_checksum = md5
        local insert = conn:prepare("INSERT INTO page_stat_data VALUES(?,?,?,?,?)")
        conn:exec("BEGIN")
        for i = 1, 4097 do insert:reset():bind(3, 1, since + i, 1, 400):step() end
        conn:exec("COMMIT"); insert:close()
        local result = Shelves.forecastRead(file, os.time()); H.eq(result.phase, "limited"); H.eq(result.date, nil)
        conn:close()
    end)
end
H.finish()
