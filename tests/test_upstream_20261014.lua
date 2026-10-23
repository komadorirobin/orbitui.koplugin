package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = assert(io.open(path))
    local s = f:read("*a"); f:close(); return s
end
local function run(src, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then
        local fn = assert(loadstring(src)); setfenv(fn, env); return fn()
    end
    return assert(load(src, "October 14 regression", "t", env))()
end
local function part(src, first, last)
    local start = assert(src:find(first, 1, true))
    return src:sub(start, assert(src:find(last, start, true)) - 1)
end
local root = "components/simpleui/"
local noop = function() end
local logger = { warn = noop, dbg = noop, info = noop }
local function memoryStore(data)
    return {
        data = data,
        get = function(_, k, default) if data[k] == nil then return default end; return data[k] end,
        readSetting = function(_, k, default) if data[k] == nil then return default end; return data[k] end,
        set = function(_, k, v) data[k] = v end,
        saveSetting = function(_, k, v) data[k] = v end,
        setNoFlush = function(_, k, v) data[k] = v end,
        isTrue = function(_, k) return data[k] == true end,
        flush = noop,
    }
end

local migrations = part(read(root .. "main.lua"), "        -- Settings migration v10:",
    "        -- Apply the saved UI font preference")
H.test("new view migrations preserve explicit choices and rollback keys", function()
    local data = { simpleui_fc_fade_finished = false, simpleui_fc_finished_mode = "hide",
        simpleui_fc_series_grouping = true, simpleui_fc_series_grouping_author = false }
    local env = { SUISettings = memoryStore(data), logger = logger }
    run(migrations, env)
    H.eq(data.simpleui_fc_finished_mode, "hide")
    H.eq(data.simpleui_fc_series_grouping_normal, true)
    H.eq(data.simpleui_fc_series_grouping_author, false)
    H.eq(data.simpleui_fc_series_grouping_tags, true)
    H.eq(data.simpleui_fc_fade_finished, false)
    H.eq(data.simpleui_fc_series_grouping, true)
    data.simpleui_fc_series_grouping_tags = false
    run(migrations, env)
    H.eq(data.simpleui_fc_series_grouping_tags, false)
end)
H.test("embedded migration deferral does not consume new migration markers", function()
    local data = { simpleui_fc_fade_finished = false, simpleui_fc_series_grouping = false }
    local env = { SUISettings = memoryStore(data), logger = logger,
        defer_defaults_until_settings_migrated = true }
    run(migrations, env)
    H.eq(data.simpleui_settings_migrated_v10, nil)
    H.eq(data.simpleui_settings_migrated_v11, nil)
    env.defer_defaults_until_settings_migrated = false
    run(migrations, env)
    H.eq(data.simpleui_fc_finished_mode, "show")
    H.eq(data.simpleui_fc_series_grouping_normal, false)
end)

local function realStore(data)
    local deps = { logger = logger, datastorage = { getSettingsDir = function() return "/test" end },
        luasettings = { open = function() return memoryStore(data) end } }
    return run(read(root .. "infra/sui_store.lua"), {
        require = function(name) return assert(deps[name], name) end,
    })
end
H.test("finished ledger copies old records and manual count exactly once", function()
    local old = { oldmd5 = { title = "Saved book", authors = "Author", year = 2025 } }
    local data = { simpleui_deleted_books = old, simpleui_reading_goal_physical = 7 }
    local store = realStore(data)
    local ledger = store.FinishedBooks.load()
    local key = "manual:bulk:" .. os.date("%Y")
    H.eq(ledger.books.oldmd5.finished, "2025")
    H.eq(ledger.books.oldmd5.gone, true)
    H.eq(ledger.books[key].count, 7)
    H.eq(data.simpleui_deleted_books, old)
    H.eq(data.simpleui_reading_goal_physical, 7)
    ledger.books[key] = nil
    store.FinishedBooks.save(ledger)
    H.eq(realStore(data).FinishedBooks.load().books[key], nil)
end)
H.test("manual count migration never overwrites an existing ledger entry", function()
    local key = "manual:bulk:" .. os.date("%Y")
    local data = { simpleui_reading_goal_physical = 7,
        simpleui_finished_books = { books = { [key] = { manual = true, count = 12 } } } }
    H.eq(realStore(data).FinishedBooks.load().books[key].count, 12)
end)

H.test("finished file gate composes with external wrappers and uninstalls safely", function()
    local mode, calls = "hide", 0
    local fc = { show_file = function(_, filename) return filename ~= "skip" end }
    local deps = {
        ["ui/widget/filechooser"] = fc,
        ["ui/widget/booklist"] = { getBookStatus = function() return "complete" end },
        ["infra/sui_store"] = {}, ["infra/sui_i18n"] = { translate = function(s) return s end },
        ["infra/sui_config"] = { readChoice = function() return mode end },
    }
    local Finished = run(read(root .. "features/library/sui_finished_books.lua"), {
        require = function(name) return assert(deps[name], name) end,
    })
    local browser = { name = "filemanager" }
    Finished.install()
    local gate = fc.show_file
    Finished.install(); H.eq(fc.show_file, gate)
    H.eq(fc.show_file(browser, "book", "/book"), false)
    H.eq(fc.show_file({ name = "other" }, "book", "/book"), true)
    mode = "fade"; H.eq(fc.show_file(browser, "book", "/book"), true)
    mode = "hide"
    local external = function(...) calls = calls + 1; return gate(...) end
    fc.show_file = external
    Finished.uninstall(); H.eq(fc.show_file, external)
    H.eq(fc.show_file(browser, "book", "/book"), true)
    H.eq(fc.show_file(browser, "skip", "/skip"), false)
    Finished.install(); H.eq(fc.show_file(browser, "book", "/book"), false)
    Finished.uninstall(); H.eq(fc.show_file, external)
    H.eq(fc.show_file(browser, "book", "/book"), true)
    H.eq(calls, 4)
end)

local function statsFixture()
    local f = { reads = 0, queries = 0, saves = 0, failure = true, mode_error = false }
    local date = os.date("%Y-%m-%d")
    f.ledger = { initialised = true, books = {
        a = { title = "Already finished", path = "/a", finished = date },
    } }
    f.data = { simpleui_stale_stats_v1 = { books_year = 1, books_total = 1, today_secs = 42 } }
    local store = memoryStore(f.data)
    store.FinishedBooks = {
        load = function() return f.ledger end,
        save = function(value) f.ledger = value; f.saves = f.saves + 1 end,
        preserveGone = function() return true end, manualInAllTime = function() return true end,
    }
    local sh = { sidecarData = function(fp)
        f.reads = f.reads + 1
        if fp == "/b" and f.failure then return nil end
        if fp == "/a" then return { summary = { status = "reading" } } end
        return { partial_md5_checksum = "b", title = "Newly finished",
            summary = { status = "complete", date_finished = date } }
    end }
    f.deps = {
        logger = logger, ["infra/sui_store"] = store, ["infra/sui_streak"] = {},
        ["infra/sui_perf"] = { mark = noop },
        ["infra/sui_config"] = { getStatsDbStamp = function() return "db:1" end,
            isFatalDbError = function() return false end },
        ["libs/libkoreader-lfs"] = { attributes = function()
            if f.mode_error then return nil, "I/O error", 5 end
            return "file"
        end },
        readhistory = { hist = { { file = "/a" }, { file = "/b" } } },
        ["modules/module_books_shared"] = sh,
        ["engines/sui_library_scan"] = { resolveHomeDir = function() return "/" end,
            getFileList = function() return { "/a", "/b" } end },
    }
    f.sp = run(read(root .. "modules/module_stats_provider.lua"), {
        require = function(name) return assert(f.deps[name], name) end,
        package = { loaded = f.deps },
    })
    f.conn = { exec = function(_, sql)
        f.queries = f.queries + 1
        if sql:find("WITH day_buckets", 1, true) then return { { 10 }, { 1 } } end
        return { {} }
    end }
    return f
end
H.test("incomplete ledger reconciliation cannot commit removals or persist partial counts", function()
    local f = statsFixture()
    local first = f.sp.get(f.conn, nil, true)
    H.eq(first._has_books, false)
    H.eq(f.saves, 0); assert(f.ledger.books.a); H.eq(f.ledger.books.b, nil)
    H.eq(f.data.simpleui_stale_stats_v1.books_total, 1)
    local queries = f.queries
    f.failure = false
    local next = f.sp.get(f.conn, nil, true)
    H.eq(next._has_books, true); H.eq(next.books_total, 1)
    H.eq(f.ledger.books.a, nil); assert(f.ledger.books.b)
    H.eq(f.queries, queries)
end)
H.test("unknown filesystem failures cannot mark a finished book gone", function()
    local f = statsFixture(); f.mode_error = true
    H.eq(f.sp.get(f.conn, nil, true)._has_books, false)
    H.eq(f.ledger.books.a.gone, nil); H.eq(f.saves, 0)
    f.mode_error, f.failure = false, false
    H.eq(f.sp.get(f.conn, nil, true)._has_books, true)
end)
H.test("missing and locked DBs retry full stats without persisting zero activity", function()
    local f = statsFixture(); f.failure = false
    f.sp.get(nil, nil, true)
    H.eq(f.data.simpleui_stale_stats_v1.today_secs, 42)
    H.eq(f.sp.get(f.conn, nil, true).today_secs, 10)
    f.sp.invalidate()
    f.sp.get({ exec = function() error("database is locked") end }, nil, true)
    H.eq(f.data.simpleui_stale_stats_v1.today_secs, 10)
    local before = f.queries
    H.eq(f.sp.get(f.conn, nil, true).today_secs, 10)
    assert(f.queries > before)
end)
H.test("incomplete status counts retry without a cache invalidation", function()
    local f = statsFixture()
    H.eq(f.sp.getStatusCounts().complete, 0)
    f.failure = false
    H.eq(f.sp.getStatusCounts().complete, 1)
    local reads = f.reads
    H.eq(f.sp.getStatusCounts().complete, 1); H.eq(f.reads, reads)
end)

H.test("plugin formats bypass the core-only shared SimpleUI walk", function()
    local src = read("components/bookshelf/lib/bookshelf_book_repository.lua")
    local fingerprint, calls = "", 0
    local scan = { peekFileIndex = function()
        calls = calls + 1
        return { complete = true, files = { { fp = "/books/one.epub" } }, dirs = { ["/books"] = 1 } }
    end }
    local walk = run(part(src, "local function _simpleUIWalk(", "-- Returns a shallow copy") ..
        "\nreturn _simpleUIWalk", {
        package = { loaded = { ["engines/sui_library_scan"] = scan } },
        _pluginFormatsFingerprint = function() return fingerprint end,
        _supportedExt = function() return true end, _dirsChanged = function() return false end,
    })
    H.eq(#walk("/books", 1), 1); H.eq(calls, 1)
    fingerprint = "meguru"
    H.eq(walk("/books", 1), nil); H.eq(calls, 1)
end)

local ffi = jit and require("ffi") or {}
local bit = jit and require("bit") or {}
local allocated = {}
local BB = { COLOR_WHITE = 255, TYPE_BBRGB32 = 32 }
function BB.new(w, h, bpp)
    local n = w * h * bpp / 8
    local data = ffi.new("uint8_t[?]", n + 32)
    ffi.fill(data, n + 32, 217)
    local bb = { data = data + 16, _data = data, stride = w * bpp / 8, n = n,
        getWidth = function() return w end, getHeight = function() return h end,
        getBpp = function() return bpp end, getType = function() return bpp end,
        getRotation = function() return 0 end,
        fill = function(self, value) ffi.fill(self.data, n, value) end,
        free = function(self) assert(not self.freed); self.freed = true end,
    }
    allocated[#allocated + 1] = bb
    return bb
end
local Warp = run(read(root .. "engines/sui_cover_warp.lua"), {
    require = function(name)
        return assert(({ ["ffi/blitbuffer"] = BB, bit = bit, ffi = ffi,
            ["features/sui_style"] = { COLOR = {}, BADGE_BORDER_SZ = 0 } })[name], name)
    end,
})
H.test("flow profiles clip source and output columns for both tilt directions", function()
    H.eq(Warp.profile(1, 100, 0.7), nil)
    H.eq(Warp.profile(100, 100, 0), nil)
    for _, left in ipairs({ true, false }) do
        for _, rho in ipairs({ 0.1, 0.7, 1 }) do
            local p = Warp.profile(73, 101, rho, left, 129)
            H.eq(Warp.profile(73, 101, rho, left, 129), p)
            for x = 1, p.w do
                assert(p.x0[x] >= 0 and p.x1[x] < p.src_w)
                assert(p.tops[x] >= 0 and p.tops[x] + p.heights[x] <= p.h)
            end
        end
    end
end)
if jit then
    H.test("flow raster keeps grayscale and colour writes inside guarded buffers", function()
        for _, bpp in ipairs({ 8, 24, 32 }) do
            for _, left in ipairs({ true, false }) do
                local src = BB.new(19, 31, bpp); src:fill(96)
                local result = assert(Warp.warp(src, 13, 31, 0.7, left))
                for x = 0, 12 do
                    for y = result.tops[x + 1], result.tops[x + 1] + result.heights[x + 1] - 1 do
                        for c = 0, bpp / 8 - 1 do
                            H.eq(result.bb.data[y * result.bb.stride + x * bpp / 8 + c], 96)
                        end
                    end
                end
                H.eq(Warp.warp(src, 13, 32, 0.7, left), nil)
                assert(not src.freed)
                result.bb:free(); src:free()
            end
        end
        for _, bb in ipairs(allocated) do
            for i = 0, 15 do
                H.eq(bb._data[i], 217); H.eq(bb._data[bb.n + 16 + i], 217)
            end
        end
    end)
end

H.test("new flow carousel remains opt-in without changing BookOrbit navigation", function()
    local src = read(root .. "modules/module_coverdeck.lua")
    assert(src:find('local DEFAULT_STYLE%s*=%s*"classic"'))
    assert(src:find("orbitui_set_index", 1, true))
    assert(src:find('getCachedFiles', 1, true))
end)
H.finish()
