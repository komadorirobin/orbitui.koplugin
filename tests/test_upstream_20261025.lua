package.path = "./?.lua;./components/simpleui/?.lua;" .. package.path
local H = require("tests/helpers")
local noop = function() end
local stored, saves, closes, busy, missing_signature, missing_pages = nil, 0, 0
local now = os.date("*t")
local yesterday = os.time{ year=now.year, month=now.month, day=now.day-1, hour=12 }
local day = os.date("%Y-%m-%d", yesterday)
local duration = 120
local conn = { close = noop }
function conn:prepare(sql)
    local rows
    if sql:find("COALESCE(MIN(start_time)", 1, true) then
        rows = missing_signature and {} or {{2, yesterday, yesterday+1}}
    elseif sql:find("GROUP BY d ORDER BY d", 1, true) then
        rows = sql:find(" AND start_time < ", 1, true)
            and {{day, duration, yesterday, yesterday+1, yesterday, 2}} or {}
    elseif sql:find("FROM book", 1, true) then
        rows = {{1, 300}}
    elseif sql:find("SELECT COUNT(*) FROM (", 1, true) then
        rows = missing_pages and {} or {{17}}
    else error("unhandled SQL: " .. sql) end
    return { close=function() closes=closes+1 end, rows=function()
        local index = 0
        return function()
            if busy then busy=false; error("database is busy") end
            index=index+1; return rows[index]
        end
    end }
end
local deps = {
    logger={warn=noop},
    ["infra/sui_config"]={openStatsDB=function() return conn end},
    luasettings={open=function() return {
        readSetting=function() return stored end,
        saveSetting=function(_, _, value) stored=value; saves=saves+1 end,
        flush=noop,
    } end},
}
local function run(text, env)
    setmetatable(env, {__index=_G})
    if setfenv then local fn=assert(loadstring(text)); setfenv(fn, env); return fn() end
    return assert(load(text, "October 25 merge regression", "t", env))()
end
local function read(path)
    local f=assert(io.open(path)); local text=f:read("*a"); f:close(); return text
end
local Ledger = run(read("components/simpleui/infra/sui_stats_ledger.lua"), {
    require=function(name) return assert(deps[name], name) end,
})
Ledger.setPath("/not-written/ledger")

H.test("daily ledger closes failed statements and retries without persisting an empty day", function()
    stored, saves, closes, busy = nil, 0, 0, true
    H.eq(Ledger.get(), nil); H.eq(saves, 0); H.eq(closes, 1)
    local snap=assert(Ledger.get())
    H.eq(snap:dailySeconds(day, day)[day], 120)
    H.eq(snap:yearTotals(tonumber(day:sub(1,4))), 1)
    H.eq(saves, 1)
end)

H.test("a missing signature result cannot replace a valid ledger with zeros", function()
    local before=stored
    missing_signature=true
    H.eq(Ledger.get(), nil); H.eq(stored, before); H.eq(saves, 1)
    missing_signature=false
    H.eq(assert(Ledger.get()):dailySeconds(day, day)[day], 120)
end)

H.test("missing page aggregates retry within the same snapshot", function()
    local snap=assert(Ledger.get())
    missing_pages=true
    H.eq(snap:pagesInYear(tonumber(os.date("%Y"))), nil)
    missing_pages=false
    H.eq(snap:pagesInYear(tonumber(os.date("%Y"))), 17)
end)

H.test("full invalidation rebuilds edited historical durations with unchanged row bounds", function()
    duration=300
    Ledger.invalidate()
    H.eq(assert(Ledger.get()):dailySeconds(day, day)[day], 300)
    H.eq(stored.days[1][2], 300)
end)

H.test("malformed persisted day rows are discarded and rebuilt from the database", function()
    stored.days[1][5]=nil
    Ledger.setPath("/not-written/retry-ledger")
    local snap=assert(Ledger.get())
    H.eq(snap:dailySeconds(day, day)[day], 300)
    H.eq(type(stored.days[1][5]), "number")
end)

local windows=read("components/simpleui/screens/sui_stats_windows.lua")
local function method(name)
    return assert(windows:match("(local function " .. name .. "%b().-)\nend\n")) .. "\nend\n"
end
H.test("Insights preserves both ends of a multi-year history", function()
    local get=run(method("_riGetYearRange") .. "return _riGetYearRange", {
        _getLedger=function() return {yearRange=function() return 2017, 2024 end} end,
    })
    H.eq(get().min_year, 2017); H.eq(get().max_year, 2024)
end)

H.test("Insights never caches missing-ledger or failed-page-query zero totals", function()
    local attempts=0
    local snapshot={yearTotals=function() return 4, 900 end,
        pagesInYear=function() if attempts>=3 then return 17 end end}
    local env={_ri_cache={}, _riGetMonthlyData=function() return {} end,
        _getLedger=function() attempts=attempts+1; if attempts>1 then return snapshot end end}
    local get=run(method("_riGetYearlyStats") .. method("_riGetOrFetchYear")
        .. "return _riGetOrFetchYear", env)
    H.eq(get(2026).yearly_stats.pages, 0); H.eq(env._ri_cache[2026], nil)
    H.eq(get(2026).yearly_stats.pages, 0); H.eq(env._ri_cache[2026], nil)
    H.eq(get(2026).yearly_stats.pages, 17)
    H.eq(get(2026).yearly_stats.pages, 17); H.eq(attempts, 3)
end)

H.test("the new deck relocation keeps the old main-file key when hosted", function()
    local src=read("components/bookshelf/lib/bookshelf_settings_store.lua")
    local body=assert(src:match("(local function _relocateAux%(s%).-)\nend\n")) .. "\nend"
    local deck={all={"custom", "order"}}
    local data={ornament_decks=deck}
    local copied, flushed
    local auxiliary={saveDeferred=function(_, v) copied=v end,
        flush=function() flushed=true end, path=function() return "aux" end}
    local relocate=run(body .. "\nreturn _relocateAux", {
        RELOCATED_FLAG="v3", LEFT_BEHIND={}, Paths={preserveLegacyOrnamentDecks=true},
        subStoreFor=function(k) if k=="ornament_decks" then return auxiliary end end,
        logger={dbg=noop},
    })
    local store={data=data, readSetting=function(_, k) return data[k] end,
        delSetting=function(_, k) data[k]=nil end,
        saveSetting=function(_, k, v) data[k]=v end, flush=noop}
    relocate(store)
    H.eq(copied, deck); H.eq(flushed, true); H.eq(data.ornament_decks, deck)
    H.eq(data.v3, true)
end)

H.test("hosted grid migration keeps legacy module sizes/pages without disabling the new grid", function()
    local Layout=run(read("components/bookshelf/lib/bookshelf_module_layout.lua"), {
        require=function(name)
            assert(name=="lib/bookshelf_module_grid")
            return dofile("components/bookshelf/lib/bookshelf_module_grid.lua")
        end,
    })
    require("adapters/orbitui_ui").wrap("lib/bookshelf_module_layout", Layout)
    local items={{id="clock", type="module", module="clock", size=2, page=1}}
    local boxes, changed=Layout.resolveFor(items, {cols=4,rows=4,cell_w=100,cell_h=100,gap=10}, {
        legacy=function() return {{id="clock", page=1, px_w=200, px_h=100}} end,
    })
    H.eq(changed, true); H.eq(#boxes, 1)
    H.eq(type(items[1].at), "table"); H.eq(items[1].size, 2); H.eq(items[1].page, 1)
end)

H.finish()
