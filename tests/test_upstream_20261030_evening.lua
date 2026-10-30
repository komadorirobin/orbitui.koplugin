package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
local function read(path)
    local f = assert(io.open(root .. "/components/simpleui/" .. path .. ".lua", "rb"))
    local s = f:read("*a"); f:close(); return s
end
local function part(s, first, last)
    local a = assert(s:find(first, 1, true), first)
    return s:sub(a, assert(s:find(last, a + #first, true), last) - 1)
end
local function run(s, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(s)), env)() end
    return assert(load(s, "evening merge", "t", env))()
end
local noop = function() end
local provider = read("modules/module_stats_provider")
local activity_code = part(provider, "local _activity     =", "-- Partial-invalidation flag")
local invalidation_code = part(provider, "function SP.invalidate(keep_status_counts)", "function SP.rescanBooks()")
local function activityFixture()
    local state = { year = 2026, month = 10, day = "2026-10-30", queries = {},
        rows = { { "01", "10", 0 }, { 5, 7, 0 } }, complete = true,
        books = { { date_finished = "2026-01-02" }, { date_finished = "2026-10-04", count = 3 },
            { date_finished = "2026-10-05", exclude_from_goals = true } } }
    local SP = { getFinishedBooks = function() return state.books, state.complete end,
        parseStamp = function(stamp) return tonumber(stamp:sub(1, 4)), tonumber(stamp:sub(6, 7)) end,
        invalidateStatusCounts = noop }
    run(activity_code .. invalidation_code, { SP = SP, logger = { warn = noop },
        rownum = function(v) return tonumber(v) or 0 end,
        package = { loaded = {} }, dropChartData = noop, dropChartHistory = noop,
        os = { time = os.time, date = function(fmt)
            if fmt == "*t" then return { year = state.year, month = state.month } end
            return state.day
        end } })
    local conn = { exec = function(_, sql)
        state.queries[#state.queries + 1] = sql
        if state.fail then error("database is locked") end
        if state.missing then return nil end
        return state.rows
    end }
    return SP, conn, state
end
H.test("monthly activity counts pages and non-excluded dated books without extra cache reads", function()
    local SP, conn, s = activityFixture()
    H.eq(SP.getYearActivity(nil), nil)
    local value = assert(SP.getYearActivity(conn, 2026))
    H.eq(value.total_pages, 12); H.eq(value.total_books, 4)
    H.eq(value.books[1], 1); H.eq(value.books[10], 3); H.eq(value.month, 10)
    H.eq(SP.getYearActivity(conn, 2026), value); H.eq(#s.queries, 1)
end)
H.test("busy and missing monthly queries retry rather than cache zero years", function()
    local SP, conn, s = activityFixture()
    s.fail = true; H.eq(SP.getYearActivity(conn, 2026), nil)
    s.fail = false; s.missing = true; H.eq(SP.getYearActivity(conn, 2026), nil)
    s.missing = false; s.rows = { { 1 }, { 5 } }; H.eq(SP.getYearActivity(conn, 2026), nil)
    s.rows = { { 0 }, { 0 } }; s.books = {}
    local value = assert(SP.getYearActivity(conn, 2026))
    H.eq(value.total_pages, 0); H.eq(value.total_books, 0); H.eq(#s.queries, 4)
end)
H.test("incomplete finished ledger remains retryable without installing partial chart totals", function()
    local SP, conn, s = activityFixture()
    s.complete = false; H.eq(SP.getYearActivity(conn, 2026), nil)
    s.complete = true; H.eq(SP.getYearActivity(conn, 2026).total_books, 4)
end)
H.test("partial invalidation keeps closed months but full invalidation rereads all months", function()
    local SP, conn, s = activityFixture()
    SP.getYearActivity(conn, 2026)
    s.rows = { { 10, 0 }, { 9, 0 } }; SP.invalidateTimeSeries()
    H.eq(SP.getYearActivity(conn, 2026).total_pages, 14)
    assert(s.queries[2]:find(tostring(os.time{ year = 2026, month = 10, day = 1, hour = 0 }), 1, true))
    s.rows = { { 1, 10, 0 }, { 8, 9, 0 } }; SP.invalidate()
    H.eq(SP.getYearActivity(conn, 2026).total_pages, 17)
    assert(s.queries[3]:find(tostring(os.time{ year = 2026, month = 1, day = 1, hour = 0 }), 1, true))
    s.books = {}; SP.invalidateBooks(); H.eq(SP.getYearActivity(conn, 2026).total_books, 0)
end)
H.test("future-year cache stays queryable after the calendar rolls into that year", function()
    local SP, conn, s = activityFixture()
    s.rows = { { 0 }, { 0 } }; s.books = {}; SP.getYearActivity(conn, 2027)
    s.year, s.month, s.day = 2027, 1, "2027-01-01"
    s.rows = { { 1, 0 }, { 6, 0 } }
    H.eq(SP.getYearActivity(conn, 2027).total_pages, 6); H.eq(#s.queries, 2)
end)
H.test("Insights retries unavailable activity in the same window and caches successful years", function()
    local attempts = 0
    local get = run(part(read("screens/sui_stats_windows"), "local function _riGetActivity(year)", "-- Years the books")
        .. "return _riGetActivity", { _ri_activity = {}, _withStatsDb = function(_, fn) return fn({}) end,
            require = function() return { getYearActivity = function()
                attempts = attempts + 1; if attempts > 1 then return { total_pages = 9 } end
            end } end })
    H.eq(get(2026), nil); H.eq(get(2026).total_pages, 9); get(2026); H.eq(attempts, 2)
end)
H.test("plural parser handles arithmetic numeric truth and rejects executable or malformed headers", function()
    local parse = run(part(read("infra/sui_i18n"), "local function parsePluralExpression", "local function parsePO")
        .. "return parsePluralExpression")
    local fn = assert(parse("plural=(n % 10 == 1 && n % 100 != 11) ? 0 : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? 1 : 2;"))
    for _, v in ipairs({ {1,0}, {2,1}, {5,2}, {11,2}, {21,0}, {22,1}, {112,2} }) do H.eq(fn(v[1]), v[2]) end
    H.eq(assert(parse("n == 1 ? 0 : (n > 2 ? 2 : 1)"))(1), 0)
    H.eq(assert(parse("!n || n / 2 + 1 == 3"))(4), 1)
    H.eq(assert(parse("n && 0"))(8), 0)
    for _, invalid in ipairs({ "n ? 1", "(n != 1", "n; os.execute('bad')", "unknown", "n +" }) do H.eq(parse(invalid), nil) end
end)
H.test("Dispatcher sinks the topmost live custom screen then restores it on success and failure", function()
    local s = read("infra/sui_patches")
    local code = s:sub((assert(s:find("do\n    local ok, Dispatcher = pcall(require, \"dispatcher\")", 1, true))))
    local fm, home, custom, popup = {}, {}, {}, {}
    local stack = { { widget = fm }, { widget = home }, { widget = custom } }
    local fail, calls = false, 0
    local dispatcher = { execute = function()
        calls = calls + 1; H.eq(stack[1].widget, custom)
        if fail then error("action failed") end
        stack[#stack + 1] = { widget = popup }
    end }
    local hs = { liveScreenIds = function() return { "hs", "custom" } end,
        getInstance = function(id) return id == "hs" and home or custom end }
    run(code, { M = {}, UIManager = { _window_stack = stack }, liveHS = function() return hs end,
        _materializeLazyListing = noop, logger = { warn = noop }, require = function() return dispatcher end })
    dispatcher:execute({}); H.eq(stack[3].widget, custom); H.eq(stack[4].widget, popup)
    fail = true; dispatcher:execute({}); H.eq(stack[3].widget, custom); H.eq(calls, 2)
end)
H.test("RGB capsule strokes stay clipped to buffer and blend colours rather than greys", function()
    local color = { getColorRGB32 = function(self) return self end, r = 180, g = 80, b = 20 }
    local paints = 0
    local aa = run(read("infra/sui_aa_paint"), { require = function(n)
        if n == "infra/sui_raster_cache" then return {} end
        H.eq(n, "ffi/blitbuffer"); return { ColorRGB32 = function(r, g, b) return { r = r, g = g, b = b } end }
    end })
    local bb = { getWidth = function() return 5 end, getHeight = function() return 4 end,
        getPixel = function(_, x, y)
            assert(x >= 0 and x < 5 and y >= 0 and y < 4)
            return { getColorRGB32 = function() return { r = 255, g = 255, b = 255 } end }
        end, setPixel = function(_, x, y, c)
            assert(x >= 1 and x <= 3 and y >= 1 and y <= 2)
            assert(c.r > c.g and c.g > c.b); paints = paints + 1
        end }
    aa.strokeCapsule(bb, -10, 1, 10, 1, 4, color, 1, 1, 3, 2); H.eq(paints, 6)
end)
H.test("passive toasts allow Home return while modal windows and stale generations still block it", function()
    local fm, stack, shown = {}, {}, 0
    local ui = { _simpleui_navigation_generation = 4 }
    local code = part(read("infra/sui_patches"), "local function _doShowHS", "-- Gate of the reopen step")
    local reopen = run(code .. "return _doShowHS", { UIManager = ui,
        isAppExiting = function() return false end, liveHS = function() return {} end,
        package = { loaded = {} }, UI = { getWindowStack = function() return stack end },
        _isTransientToast = function() return false end, _closeOrphanedPopups = noop,
        _showHSCold = function() shown = shown + 1 end, _carryDisplacedScreen = noop })
    stack = { { widget = fm }, { widget = { toast = true } } }
    reopen(fm, {}, "hs", 4); H.eq(shown, 1)
    reopen(fm, {}, "hs", 3); H.eq(shown, 1)
    stack[2].widget = { buttons = {} }; reopen(fm, {}, "hs", 4); H.eq(shown, 1)
end)
H.test("smoothed monthly lines preserve zeroes and never overshoot adjacent values", function()
    local code = part(read("engines/sui_stats_charts"), "local function smoothPoints", "-- The colour of a second line")
    local smooth = run(code .. "return smoothPoints", { LINE_STEPS = 8 })
    local xs, ys = { 0, 10, 20, 30, 40 }, { 8, 0, 0, 12, 3 }
    local points = smooth(xs, ys)
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local interval = math.min(4, math.floor(x / 10) + 1)
        assert(y >= math.min(ys[interval], ys[interval + 1]) - 1e-9)
        assert(y <= math.max(ys[interval], ys[interval + 1]) + 1e-9)
        if x >= 10 and x <= 20 then H.eq(y, 0) end
    end
    local one = smooth({ 2 }, { 5 }); H.eq(one[1], 2); H.eq(one[2], 5)
end)
H.test("monthly Insights labels translate to Swedish and English without changing native gettext", function()
    for _, lang in ipairs({ "sv", "en" }) do
        local i18n = run(read("infra/sui_i18n"), { require = function(n)
            if n == "logger" then return { warn = noop, info = noop } end
            if n == "util" then return { trim = function(s) return s:match("^%s*(.-)%s*$") end } end
            if n == "infra/sui_paths" then return { getPluginDir = function() return root .. "/components/simpleui/" end } end
            if n == "gettext" then return setmetatable({ ngettext = function(a, b, count) return count == 1 and a or b end },
                { __call = function(_, s) return s end }) end
            error(n)
        end, G_reader_settings = { readSetting = function() return lang end } })
        H.eq(i18n.translate("Books and pages"), lang == "sv" and "Böcker och sidor" or "Books and pages")
        H.eq(i18n.translate("By month"), lang == "sv" and "Per månad" or "By month")
        H.eq(i18n.ngettext("%d page", "%d pages", 2), lang == "sv" and "%d sidor" or "%d pages")
    end
end)
H.finish()
