package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Log = require("adapters/orbitui_reading_log")
local function day(y, m, d)
    return os.time{ year = y, month = m, day = d, hour = 12 }
end
local function key(stamp) return os.date("%Y-%m-%d", stamp) end
H.test("seven days include today; heatmap periods align and never overlap", function()
    local t = day(2026, 1, 2)
    local week = Log.weekEnding(t)
    H.eq(#week, 7); H.eq(key(week[1]), "2025-12-27"); H.eq(key(week[7]), "2026-01-02")
    local from, to = Log.calendarRange(t, 0)
    H.eq(key(from), "2025-10-13"); H.eq(key(to), "2026-01-04")
    local old_start, old_end = Log.calendarRange(t, 1)
    H.eq(os.date("%w", old_start), "1"); H.eq(key(old_end), "2025-10-12")
    H.eq(key(Log.weekEnding(day(2024, 3, 1))[6]), "2024-02-29")
end)
local sync, exists, mode, calls, closed = false, true, nil, 0, 0
local errors, sqls, bookRows
local db = {}
function db:exec(sql)
    H.eq(sql, "PRAGMA query_only=ON; PRAGMA busy_timeout=40;")
end
function db:close() closed = closed + 1 end
function db:prepare(sql)
    sqls[#sqls + 1] = sql
    return {
        rows = function()
            local index = 0
            return function()
                if errors then error("simulated query failure") end
                index = index + 1
                return bookRows[index]
            end
        end,
        close = function() end,
    }
end
package.loaded["infra/sui_config"] = { isStatsSyncGuarded = function() return sync end, getStatsDbPath = function() return "/stats" end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function() return exists and "file" or nil end }
package.loaded["lua-ljsqlite3/init"] = { open = function(path, access)
    H.eq(path, "/stats"); calls, mode = calls + 1, access
    return db
end }
package.loaded["infra/sui_stats_ledger"] = { get = function(conn)
    H.eq(conn, db)
    return {
        dailySeconds = function(_, from, to)
            H.eq(from, "2026-11-11"); H.eq(to, "2026-11-17")
            return { ["2026-11-17"] = 75, ["2026-11-16"] = 240 }
        end,
        activeDates = function() return { { "2026-11-16", 1 }, { "2026-11-17", 2 } } end,
    }
end }
package.loaded["infra/sui_streak"] = {
    getFrozenDatesInRange = function(_, to) H.eq(to, "2026-11-17"); return { "2026-11-15" } end,
    computeCurrentDayStreak = function(dates, opts)
        H.eq(#dates, 2); H.eq(opts.yesterday, "2026-11-16"); H.eq(opts.frozen_dates[1], "2026-11-15")
        return 3
    end,
    computeLongestDayStreak = function() return 5 end,
}
H.test("the weekly log uses bounded read-only queries and the shared streak rules", function()
    sqls, bookRows = {}, { { "2026-11-17", "75", "3", "Test book", "10" } }
    local log = assert(Log.read(day(2026, 11, 17)))
    H.eq(mode, "ro"); H.eq(log.seconds, 315); H.eq(log.pages, 10)
    H.eq(log.current, 3); H.eq(log.best, 5); H.eq(log.recent[1].title, "Test book")
    H.eq(log.recent[1].pages, 3)
    H.eq(#sqls, 1)
    assert(sqls[1]:find("LIMIT 6", 1, true))
    local records = assert(Log.readDay(day(2026, 11, 17)))
    H.eq(#records, 1); H.eq(records[1].secs, 75)
    assert(not sqls[2]:find("LIMIT", 1, true))
    H.eq(calls, 2); H.eq(closed, 2)
end)
H.test("sync and missing databases stay passive and an error closes the handle", function()
    sync = true
    local data, why = Log.readDay(day(2026, 11, 17))
    H.eq(data, nil); H.eq(why, "sync"); H.eq(calls, 2)
    sync, exists = false, false
    data, why = Log.readDay(day(2026, 11, 17))
    H.eq(data, nil); H.eq(why, "missing"); H.eq(calls, 2)
    exists, errors = true, true
    data, why = Log.readDay(day(2026, 11, 17))
    H.eq(data, nil); H.eq(why, "error"); H.eq(calls, 3); H.eq(closed, 3)
end)
H.finish()
