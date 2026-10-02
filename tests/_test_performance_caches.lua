package.path = "./?.lua;./?/init.lua;" .. package.path

local passed = 0
local function test(name, fn)
    fn()
    passed = passed + 1
    print("ok " .. name)
end
for _, name in ipairs({
    "ui/bidi", "ffi/blitbuffer", "ui/widget/container/centercontainer",
    "ui/font", "ui/widget/container/framecontainer", "ui/geometry",
    "ui/widget/linewidget", "ui/widget/overlapgroup", "ui/size",
    "ui/widget/textboxwidget", "ui/widget/textwidget", "ui/widget/verticalgroup",
    "ui/widget/verticalspan", "features/sui_style",
}) do package.loaded[name] = {} end
package.loaded.device = { screen = { scaleBySize = function(_, n) return n end } }
package.loaded.logger = { warn = function() end }
package.loaded.util = { htmlToPlainTextIfHtml = function(s) return s end }
package.loaded["infra/sui_config"] = { isFatalDbError = function() return false end }
package.loaded["infra/sui_i18n"] = { translate = function(s) return s end }
G_reader_settings = { readSetting = function(_, _, default) return default end }

local real_time, now = os.time, os.time()
os.time = function(t) if t then return real_time(t) end; return now end
local opens, closes, bim_reads = 0, 0, 0
local sidecar, mtime
local settings = {}
package.loaded["libs/libkoreader-lfs"] = { attributes = function(_, key)
    if key == nil then return { mode = "file", modification = mtime } end
    if key == "mode" then return "file" end
    if key == "modification" then return mtime end
end }
package.loaded.docsettings = {
    findCustomMetadataFile = function() return nil end,
    open = function()
        opens = opens + 1
        return { source_candidate = sidecar,
            readSetting = function(_, k) return settings[k] end,
            close = function() closes = closes + 1 end }
    end,
}
local book_info = { title = "Indexed title", pages = 120, description = "Description" }
package.loaded.bookinfomanager = { getBookInfo = function()
    bim_reads = bim_reads + 1
    return book_info
end }
local SH = dofile("modules/module_books_shared.lua")
package.loaded["modules/module_books_shared"] = SH

test("unopened books reuse one sidecar read and one BIM row", function()
    for _ = 1, 3 do
        local b = SH.getBookData("/books/a.epub")
        assert(b.title == "Indexed title" and b.pages == 120 and b.description == "Description")
    end
    assert(opens == 1 and bim_reads == 1 and closes == 0)
end)
test("expiry, sidecar mtime and explicit invalidation expose changes", function()
    now = now + 6
    book_info = { title = "Updated title", pages = 121 }
    sidecar, mtime = "/books/a.sdr/metadata.epub.lua", 1
    assert(SH.getBookData("/books/a.epub").title == "Updated title")
    settings.doc_props = { title = "Sidecar title" }
    now, mtime = now + 1, 2
    assert(SH.getBookData("/books/a.epub").title == "Sidecar title")
    settings.percent_finished = 0.6
    SH.invalidateSidecarCache("/books/a.epub")
    assert(SH.getBookData("/books/a.epub").percent == 0.6)
end)
test("progress-only and prefetched tiles do not query BIM", function()
    local before = bim_reads
    assert(SH.getBookData("/books/b.epub", nil, { progress_only = true }).percent == 0.6)
    local b = SH.getBookData("/books/c.epub", {
        title = "Prefetched", doc_pages = 12, percent = 0, summary = false,
    }, { skip_description = true })
    assert(b.title == "Prefetched" and b.pages == 12 and bim_reads == before)
end)
test("missing BIM results expire and the cache stays bounded", function()
    SH.invalidateSidecarCache()
    settings = {}
    book_info = nil
    SH.getBookData("/books/missing.epub", false)
    local before = bim_reads
    SH.getBookData("/books/missing.epub", false)
    assert(bim_reads == before)
    now = now + 6
    book_info = { title = "Extracted" }
    assert(SH.getBookData("/books/missing.epub", false).title == "Extracted")
    for i = 1, 256 do SH.getBookData("/books/" .. i .. ".epub", false) end
    before = bim_reads
    SH.getBookData("/books/missing.epub", false)
    assert(bim_reads == before + 1, "oldest entry must have been evicted")
end)

local persisted = {}
package.loaded["infra/sui_store"] = {
    readSetting = function(_, k)
        if k:match("show_finished$") then return false end
        return persisted[k]
    end,
    setNoFlush = function(_, k, v) persisted[k] = v end,
}
package.loaded["engines/sui_book_grid"] = { makeModule = function(opts) return opts end }
package.loaded["engines/sui_library_scan"] = {}
test("new-books and flat-library filters never write sidecars", function()
    local new = dofile("modules/module_new_books.lua")
    local library = dofile("modules/module_library.lua")
    settings = { percent_finished = 0.2 }
    for i = 1, 15 do
        assert(new.filterItem("/books/" .. i, {}))
        assert(library.filterItem("/books/" .. i, {}))
    end
    settings.summary = { status = "complete" }
    assert(not new.filterItem("/books/finished", {}))
    assert(not library.filterItem("/books/finished", {}))
    assert(closes == 0)
end)

test("prefetch and render share metadata but a status edit is read immediately", function()
    local fp = "/books/prefetched.epub"
    sidecar, mtime, settings = nil, nil, {}
    SH.invalidateSidecarCache()
    package.loaded.readhistory = { hist = { { file = fp } } }
    book_info = { title = "Prefetched title", pages = 120, description = "Text" }
    local before_opens, before_bim = opens, bim_reads
    local state = SH.prefetchBooks(true, false)
    local pre = state.prefetched_data[fp]
    assert(pre and pre.summary == false)
    for _ = 1, 3 do
        assert(SH.getBookData(fp, pre).title == "Prefetched title")
    end
    assert(opens == before_opens + 1 and bim_reads == before_bim + 1)
    -- ScreenEngine keep_cache refresh deliberately clears these two fields.
    pre.summary, pre.percent = nil, nil
    settings = { summary = { status = "complete" }, percent_finished = 1 }
    local b = SH.getBookData(fp, pre)
    assert(b.percent == 1 and b.status == "complete" and opens == before_opens + 2)
    -- Resetting status back to unread must also remain cached, not retried.
    pre.summary, pre.percent, settings = nil, nil, {}
    b = SH.getBookData(fp, pre)
    assert(b.percent == 0 and b.status == nil)
    local after_reset = opens
    SH.getBookData(fp, pre)
    assert(opens == after_reset and closes == 0)
end)

settings = { summary = { status = "complete", date_finished = os.date("%Y-%m-%d", now) } }
package.loaded.readhistory = { hist = { { file = "/books/finished" } } }
package.loaded["infra/sui_streak"] = {}
local queries = 0
local conn = { exec = function(_, sql)
    queries = queries + 1
    if sql:find("WITH day_buckets", 1, true) then return { { 10 }, { 1 } } end
    return { {} }
end }
local SP = dofile("modules/module_stats_provider.lua")
test("partial stats cache is reused and promoted without querying again", function()
    local partial = SP.get(conn, nil, false)
    assert(not partial._has_books and partial.today_secs == 10)
    assert(SP.get(conn, nil, false) == partial and SP.getStale() == partial)
    assert(queries == 2 and persisted.simpleui_stale_stats_v1.today_secs == 10)
    local full = SP.get(conn, nil, true)
    assert(full._has_books and full.books_year == 1 and full.books_total == 1)
    assert(queries == 2 and persisted.simpleui_stale_stats_v1.books_total == 1)
end)
test("partial time-series invalidation never invents completed book counts", function()
    SP.invalidate()
    SP.get(conn, nil, false)
    SP.invalidateTimeSeries()
    local full = SP.get(conn, nil, true)
    assert(full._has_books and full._changed.books and full.books_total == 1)
    SP.invalidateTimeSeries()
    SP.get(conn, nil, false)
    full = SP.get(conn, nil, true)
    assert(full.books_total == 1)
end)
test("day rollover and full invalidation still refresh partial stats", function()
    local before = queries
    now = now + 86400
    SP.get(conn, nil, false)
    assert(queries == before + 2)
    SP.invalidate()
    SP.get(conn, nil, false)
    assert(queries == before + 4)
end)
test("a temporarily unavailable or busy database does not freeze zero stats", function()
    SP.invalidate()
    SP.get(nil, nil, false)
    local before = queries
    local stats = SP.get(conn, nil, false)
    assert(queries == before + 2 and stats.today_secs == 10)
    SP.invalidate()
    SP.get({ exec = function() error("database is locked") end }, nil, false)
    before = queries
    stats = SP.get(conn, nil, false)
    assert(queries == before + 2 and stats.today_secs == 10)
end)

package.loaded.datastorage = { getSettingsDir = function() return "/settings" end }
package.loaded["infra/sui_paths"] = { getPluginDir = function() return "./" end }
package.loaded["infra/sui_cover_cache"] = {}
local indexes = 0
package.loaded["lua-ljsqlite3/init"] = { open = function()
    return { exec = function(_, sql)
        if sql:find("CREATE INDEX", 1, true) then
            assert(not sql:find("ON page_stat(", 1, true), "page_stat is a view")
            indexes = indexes + 1
        end
    end }
end }
local Config = dofile("infra/sui_config.lua")
test("statistics indexes are installed once, and renewed after cloud sync", function()
    for _ = 1, 3 do assert(Config.openStatsDB()) end
    assert(indexes == 1)
    Config.beginStatsSyncGuard()
    assert(Config.openStatsDB() == nil)
    Config.endStatsSyncGuard()
    assert(Config.openStatsDB() and indexes == 2)
end)
os.time = real_time
print("PASS " .. passed .. " performance cache tests")
