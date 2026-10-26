package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local native_ffi = jit and require("ffi")
package.loaded.ffi = { C = { free = function() end } }
local M = require("adapters/orbitui_android_covers") -- cold load, no native globals
local android, safe, calls, pending, top, rows, failure, cover, in_use, busy, clock
local dropped, closed, freed, statements, original_kick, original_fire, notifications
local old_time = os.time
os.time = function() return clock end
local function copy(row) local new = {}; for k, v in pairs(row or {}) do new[k] = v end; return new end
local function bitmap(w, h)
    return { w = w, h = h, stride = w, data = "pixels", getWidth = function(self) return self.w end,
        getHeight = function(self) return self.h end, getType = function() return 1 end,
        free = function(self) assert(not self.freed, "double free"); self.freed = true; freed = freed + 1 end }
end
local connection = {}
function connection:exec(sql)
    if sql:find("SAVEPOINT", 1, true) then self.snapshot = {}; for fp, row in pairs(rows) do self.snapshot[fp] = copy(row) end end
    if sql:find("ROLLBACK", 1, true) then rows = self.snapshot end
    if failure == "release" and sql:find("RELEASE", 1, true) then failure = nil; error("disk full") end
end
function connection:prepare(sql)
    if failure == "prepare" then error("database busy") end
    statements = statements + 1
    local s = { values = {} }
    function s:bind(...) self.values = { ... }; return self end
    function s:bind1(i, value) self.values[i] = value; return self end
    function s:close() statements = statements - 1 end
    function s:step()
        if sql:find("INSERT", 1, true) then
            local fp = self.values[1] .. self.values[2]
            rows[fp] = rows[fp] or { in_progress = 0 }
        else
            if failure == "update" then error("storage full") end
            local cols = {}; for col in sql:match(" SET (.-) WHERE"):gmatch("([%w_]+)=%?") do cols[#cols + 1] = col end
            local row = assert(rows[self.values[#cols + 1] .. self.values[#cols + 2]])
            for i, col in ipairs(cols) do row[col] = self.values[i] end
        end
    end
    return s
end
package.loaded.device = { isAndroid = function() return android end, screen = { getWidth = function() return 1000 end } }
package.loaded["lib/bookshelf_settings"] = { nilOrTrue = function() return safe end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(fp, field)
    if fp == "/gone.epub" then return nil end
    if field == "mode" then return "file" end
    if field == "modification" then return 456 end
    return { size = 123, modification = 456 }
end }
package.loaded.util = { splitFilePathName = function(fp) return fp:match("^(.-)([^/]+)$") end }
package.loaded.logger = { warn = function() calls.warnings = (calls.warnings or 0) + 1 end }
package.loaded["lib/bookshelf_file_ops"] = { inUsePaths = function() return in_use end }
package.loaded["document/documentregistry"] = {
    hasProvider = function(_, fp) return fp ~= "/unsupported.xyz" end,
    openDocument = function(_, fp)
        calls[#calls + 1] = fp
        if failure == "open" then return nil end
        return { file = fp, loadDocument = function(_, full)
            H.eq(full, false); if failure == "load" then return false end; return true
        end, getProps = function() assert(failure ~= "load"); return { title = "Fresh", authors = "Author" } end,
            close = function() closed = closed + 1 end }
    end,
}
package.loaded["apps/filemanager/filemanagerbookinfo"] = {
    extendProps = function(props, fp) H.eq(fp:sub(1, 1), "/"); props.title = "Custom title"; return props end,
    getCoverImage = function(_, document, fp, force_orig)
        H.eq(document.file, fp); H.eq(force_orig, nil) -- keep custom cover, do not revert
        if failure == "decode" then error("decode failed") end
        if cover then return bitmap(cover[1], cover[2]) end
    end,
}
package.loaded["ui/renderimage"] = { scaleBlitBuffer = function(_, bb, w, h, free)
    H.eq(free, false); assert(w <= bb.w and h <= bb.h)
    if failure == "scale" then error("out of memory") end
    return bitmap(w, h)
end }
package.loaded["ffi/zstd"] = { zstd_compress = function()
    if failure == "compress" then error("compression failed") end
    return "compressed", 10
end }
package.loaded["lua-ljsqlite3/init"] = { blob = function(data) return data end }
local BIM = { db_conn = connection, openDbConnection = function() if failure == "db" then error("busy") end end,
    isExtractingInBackground = function() return busy end,
    getCachedCoverSize = function(w, h, mw, mh)
        local scale = math.min(mw / w, mh / h); return math.floor(w * scale), math.floor(h * scale)
    end,
    extractInBackground = function() error("FORK MUST NOT RUN") end,
    extractBookInfo = function() error("SUBPROCESS EXTRACTOR MUST NOT RUN") end,
    deleteBookInfo = function() error("OLD ROW MUST NOT BE DELETED") end }
package.loaded.bookinfomanager = BIM
package.loaded["lib/bookshelf_book_repository"] = {
    isPluginFormatFile = function(fp) return fp:match("%.meguru$") ~= nil end,
    bimGetBookInfo = function(_, fp) if failure == "read" then return nil, "busy" end; return rows[fp] end,
    forgetBook = function(fp) dropped[fp] = (dropped[fp] or 0) + 1 end,
    lightMetaReady = function() end, invalidateBookCache = function() calls.invalidated = true end,
    currentFilepath = function() return "/hero.epub" end,
}
package.loaded["lib/bookshelf_scaled_cover_cache"] = { drop = function(_, fp) dropped[fp] = (dropped[fp] or 0) + 1 end }
local UI = {
    scheduleIn = function(_, delay, cb) H.eq(delay, 0.15); pending[#pending + 1] = cb end,
    unschedule = function(_, cb) for i = #pending, 1, -1 do if pending[i] == cb then table.remove(pending, i) end end end,
    getTopmostVisibleWidget = function() return top end,
    topdown_widgets_iter = function()
        local n = 0; return function() n = n + 1; if n == 1 then return { toast = true } elseif n == 2 then return top end end
    end,
    show = function(_, widget) notifications[#notifications + 1] = widget end,
}
package.loaded["ui/uimanager"] = UI
package.loaded["core/orbitui_i18n"] = function(text) return text end
package.loaded["ui/widget/notification"] = { new = function(_, o) return o end }
package.loaded["ui/widget/infomessage"] = package.loaded["ui/widget/notification"]
local Widget = { _stopStatusTimer = function() calls.stopped = true end,
    _kickOffMissingMetaExtractionNow = function() original_kick = original_kick + 1 end,
    _fireBimExtraction = function() original_fire = original_fire + 1; return true end,
    _coverNeedsResize = function(info, specs) return (info.cover_w or 0) < specs.max_cover_w * 0.8 end }
M.widget(Widget)
local function fixture()
    package.loaded["apps/reader/readerui"] = nil
    android, safe, busy, failure, cover, clock = true, true, false, nil, { 1200, 1800 }, 100
    calls, pending, rows, dropped, in_use, notifications = {}, {}, {}, {}, {}, {}
    closed, freed, statements, original_kick, original_fire = 0, 0, 0, 0, 0
    local w = setmetatable({ _inner_vgroup = {}, _shelf_dims = {}, _hero_parent = {}, _hero_dims = {} }, { __index = Widget })
    function w:_isRemoteRecord(fp) return fp == "/remote.epub" end
    function w:_swapShelvesInPlace() calls.swaps = (calls.swaps or 0) + 1 end
    function w:_swapHeroInPlace() calls.hero = (calls.hero or 0) + 1 end
    top = w; return w
end
local function tick() local cb = table.remove(pending, 1); assert(cb); cb() end
local specs = { max_cover_w = 400, max_cover_h = 600 }
H.test("local extraction saves native dimensions and metadata without a subprocess or reader cache change", function()
    fixture(); assert(M.extract("/a.epub", specs))
    local row = rows["/a.epub"]
    H.eq(row.cover_w, 400); H.eq(row.cover_h, 600); H.eq(row.cover_sizetag, "1200x1800")
    H.eq(row.title, "Custom title"); H.eq(row.filesize, 123); H.eq(row.filemtime, 456)
    H.eq(row.has_cover, "Y"); H.eq(row.cover_fetched, "Y"); H.eq(row.cover_bb_data, "compressed")
    H.eq(closed, 1); H.eq(freed, 2); H.eq(statements, 0)
end)
H.test("an original small image is never upscaled and persisted as a fake high-resolution cover", function()
    fixture(); cover = { 80, 120 }; assert(M.extract("/a.epub", specs))
    H.eq(rows["/a.epub"].cover_w, 80); H.eq(freed, 1)
end)
H.test("a metadata refresh cannot downgrade a larger cached thumbnail to the smaller current slot", function()
    fixture(); rows["/a.epub"] = { has_cover = "Y", cover_w = 600, cover_h = 900 }
    assert(M.extract("/a.epub", specs)); H.eq(rows["/a.epub"].cover_w, 600)
end)
H.test("replacement merges derived fields without removing ignore flags, accurate pages or unrelated rows", function()
    fixture(); rows["/a.epub"] = { ignore_meta = "Y", ignore_cover = "Y", pages = 431, title = "Old" }
    rows["/other.epub"] = { title = "Untouched" }
    assert(M.extract("/a.epub", specs)); H.eq(rows["/a.epub"].ignore_cover, "Y")
    H.eq(rows["/a.epub"].ignore_meta, "Y"); H.eq(rows["/a.epub"].pages, 431)
    H.eq(rows["/other.epub"].title, "Untouched")
end)
H.test("a coverless refresh keeps an existing cover instead of deleting it", function()
    fixture(); cover = nil; rows["/a.epub"] = { has_cover = "Y", cover_bb_data = "old pixels", cover_w = 300 }
    assert(M.extract("/a.epub", specs)); H.eq(rows["/a.epub"].cover_bb_data, "old pixels")
    H.eq(rows["/a.epub"].has_cover, "Y"); H.eq(rows["/a.epub"].title, "Custom title")
end)
H.test("document, decoder, memory and database failures retain old rows and free owned resources", function()
    for _, stage in ipairs({ "open", "load", "decode", "scale", "compress", "db", "prepare", "update", "release" }) do
        fixture(); failure = stage; rows["/a.epub"] = { title = "Old", cover_bb_data = "old pixels" }
        assert(not M.extract("/a.epub", specs), stage)
        H.eq(rows["/a.epub"].title, "Old", stage); H.eq(rows["/a.epub"].cover_bb_data, "old pixels", stage)
        H.eq(statements, 0, stage); if stage ~= "open" then H.eq(closed, 1, stage) end
    end
end)
H.test("failed insertion is rolled back rather than leaving a poisoned or empty row", function()
    fixture(); failure = "update"; assert(not M.extract("/new.epub", specs)); H.eq(rows["/new.epub"], nil)
end)
H.test("remote, provider-stream, missing and live-reader documents are not opened", function()
    fixture(); in_use["/parked.epub"] = true
    for _, fp in ipairs({ "https://server/book", "/a.meguru", "/gone.epub", "/unsupported.xyz", "/parked.epub" }) do
        assert(not M.extract(fp, specs), fp)
    end
    H.eq(#calls, 0)
end)
H.test("the current hero borrows its parked document read-only without a second open, load or close", function()
    fixture(); in_use["/hero.epub"] = true
    package.loaded["apps/reader/readerui"] = { instance = { document = {
        file = "/hero.epub", loadDocument = function() error("live document reloaded") end,
        close = function() error("live reader closed") end,
        getProps = function() return { title = "Live book" } end,
    } } }
    assert(M.extract("/hero.epub", specs)); H.eq(#calls, 0); H.eq(closed, 0)
    H.eq(rows["/hero.epub"].cover_w, 400)
end)
H.test("visible-page work is hero-first, deduplicated and one document per UI turn", function()
    local w = fixture()
    w:_kickOffMissingMetaExtractionNow({ { filepath = "/hero.epub" }, { filepath = "/a.epub" },
        { first_book = { filepath = "/b.epub" } }, { books = { { filepath = "/c.epub" } } } }, 150, 225, 400, 600)
    H.eq(#calls, 0); H.eq(#pending, 1); tick(); H.eq(#calls, 1); H.eq(calls[1], "/hero.epub")
    H.eq(rows["/hero.epub"].cover_w, 400); tick(); H.eq(#calls, 2); H.eq(rows["/a.epub"].cover_w, 150)
    tick(); tick(); H.eq(#calls, 4); H.eq(#pending, 0); H.eq(w._orbitui_cover_job, nil)
    assert(dropped["/hero.epub"]); H.eq(original_fire, 0)
end)
H.test("known missing covers are retried but ready covers and ignored covers are left alone", function()
    local w = fixture(); rows["/hero.epub"] = { has_meta = "Y", cover_fetched = "Y" }
    rows["/good.epub"] = { has_meta = "Y", has_cover = "Y", cover_w = 800 }
    rows["/ignored.epub"] = { ignore_cover = "Y" }
    w:_kickOffMissingMetaExtractionNow({ { filepath = "/good.epub" }, { filepath = "/ignored.epub" } }, 100, 150, 400, 600)
    tick(); H.eq(#calls, 1); H.eq(calls[1], "/hero.epub")
end)
H.test("old small thumbnails are replaced at the requested native size and stale scaled pixels dropped", function()
    local w = fixture(); rows["/hero.epub"] = { has_meta = "Y", has_cover = "Y", cover_w = 30 }
    w:_kickOffMissingMetaExtractionNow({}, 100, 150, 400, 600); tick()
    H.eq(rows["/hero.epub"].cover_w, 400); assert(dropped["/hero.epub"])
end)
H.test("SQL read failure does not enqueue an entire page as apparently missing", function()
    local w = fixture(); failure = "read"; w:_kickOffMissingMetaExtractionNow({ { filepath = "/a.epub" } }, 100, 150)
    tick(); H.eq(#calls, 0)
end)
H.test("automatic extraction respects existing native bad-document quarantine and retry limits", function()
    local w = fixture(); rows["/hero.epub"] = { unsupported = "too many interruptions or crashes" }
    rows["/bad.epub"] = { in_progress = 3 }
    w:_kickOffMissingMetaExtractionNow({ { filepath = "/bad.epub" } }, 100, 150, 400, 600)
    tick(); H.eq(#calls, 0)
end)
H.test("turning off Android safe mode and non-Android devices retain the original extraction path", function()
    for _, state in ipairs({ { false, true }, { true, false } }) do
        local w = fixture(); android, safe = state[1], state[2]
        w:_kickOffMissingMetaExtractionNow({}, 100, 150); w:_fireBimExtraction({}, "kickoff")
        H.eq(original_kick, 1); H.eq(original_fire, 1); assert(not w:orbitui_refreshMetadata({ "/a.epub" }))
        H.eq(#pending, 0)
    end
end)
H.test("close, suspend and reader-open cancellation invalidate already captured callbacks", function()
    local w = fixture(); w:_fireBimExtraction({ { filepath = "/a.epub", cover_specs = specs } })
    local stale = pending[1]; w:_stopStatusTimer(); stale(); H.eq(#calls, 0); H.eq(#pending, 0); assert(calls.stopped)
end)
H.test("covered or closed shelves and changed safety preferences cannot run stale native loads", function()
    for _, change in ipairs({ "top", "closed", "safe" }) do
        local w = fixture(); w:_fireBimExtraction({ { filepath = "/a.epub", cover_specs = specs } })
        if change == "top" then top = {} elseif change == "closed" then w._closed = true else safe = false end
        tick(); H.eq(#calls, 0); H.eq(#pending, 0)
    end
end)
H.test("a new page drops obsolete automatic work without deleting old cover data", function()
    local w = fixture(); w:_fireBimExtraction({ { filepath = "/old.epub", cover_specs = specs } })
    w:_fireBimExtraction({ { filepath = "/new.epub", cover_specs = specs } }); tick()
    H.eq(#calls, 1); H.eq(calls[1], "/new.epub")
end)
H.test("failure does not discard a scaled cover and is cooldown-limited, not permanent", function()
    local w = fixture(); failure = "decode"
    w:_kickOffMissingMetaExtractionNow({}, 100, 150, 400, 600); tick(); H.eq(dropped["/hero.epub"], nil)
    failure = nil; w:_kickOffMissingMetaExtractionNow({}, 100, 150, 400, 600); tick(); H.eq(#calls, 1)
    clock = 161; w:_kickOffMissingMetaExtractionNow({}, 100, 150, 400, 600); tick(); H.eq(#calls, 2)
end)
H.test("explicit refresh bypasses the cooldown, preserves rows until commit and survives page changes", function()
    local w = fixture(); rows["/a.epub"] = { title = "Old", cover_bb_data = "old pixels" }
    assert(w:orbitui_preserveMetadataRefresh()); assert(w:orbitui_refreshMetadata({ "/a.epub" }))
    H.eq(rows["/a.epub"].title, "Old"); assert(not dropped["/a.epub"])
    w:_fireBimExtraction({ { filepath = "/other.epub", cover_specs = specs } }); tick()
    H.eq(calls[1], "/a.epub"); assert(calls.invalidated); H.eq(#notifications, 1)
end)
H.test("bulk refresh uses the same no-fork queue with cover sizes instead of text-only deletion", function()
    local w = fixture(); w:_fireBimExtraction({ { filepath = "/a.epub" }, { filepath = "/b.epub" } }, "bulk-refresh")
    tick(); tick(); H.eq(rows["/a.epub"].cover_w, 400); H.eq(rows["/b.epub"].cover_w, 400)
end)
H.test("queue and attempt cache have a fixed bound", function()
    local w = fixture(); local files = {}
    for i = 1, 300 do files[i] = { filepath = "/" .. i .. ".epub", cover_specs = specs } end
    w:_fireBimExtraction(files); H.eq(#w._orbitui_cover_job.files, 256); H.eq(#pending, 1)
end)
H.test("a foreign indexer is never interrupted or raced", function()
    local w = fixture(); busy = true; w:_fireBimExtraction({ { filepath = "/a.epub", cover_specs = specs } })
    tick(); H.eq(#calls, 0); H.eq(#pending, 0)
end)
H.test("full-library scan explains safe-mode page loading without starting its native subprocess scanner", function()
    fixture(); local scanned = 0; local Bookshelf = { scanAllMetadata = function() scanned = scanned + 1 end }
    M.bookshelf(Bookshelf); Bookshelf:scanAllMetadata(); H.eq(scanned, 0); H.eq(#notifications, 1)
    safe = false; Bookshelf:scanAllMetadata(); H.eq(scanned, 1)
end)

local function source(path)
    local f = assert(io.open((os.getenv("ORBITUI_TEST_ROOT") or ".") .. "/" .. path))
    local text = f:read("*a"); f:close(); return text
end
local function compile(code, env)
    if setfenv then local f = assert(loadstring(code)); setfenv(f, env); return f end
    return assert(load(code, "refresh-seam", "t", env))
end
H.test("the real single-book Refresh metadata callback delegates before any row or cache deletion", function()
    local w = fixture(); local text = source("components/bookshelf/lib/bookshelf_widget.lua")
    local body = assert(text:match('local refresh_btn = ({ text = _%("Refresh metadata"%).-})\n    local select_btn'))
    local env = setmetatable({ bw = w, book = { filepath = "/a.epub" }, _ = function(s) return s end,
        closeModal = function() calls.modal_closed = true end }, { __index = _G })
    rows["/a.epub"] = { title = "Keep until ready" }
    compile("return " .. body, env)().callback()
    assert(calls.modal_closed); H.eq(rows["/a.epub"].title, "Keep until ready"); H.eq(dropped["/a.epub"], nil)
    tick(); H.eq(rows["/a.epub"].title, "Custom title")
end)
H.test("the real bulk refresh branch collects paths without deleting rows in safe mode", function()
    local w = fixture(); local text = source("components/bookshelf/lib/bookshelf_bulk_actions.lua")
    local branch = assert(text:match('(if draft%.refresh_metadata then.-)\n                    if draft%.status then'))
    local paths = {}; local env = setmetatable({ bw = w, fp = "/a.epub", draft = { refresh_metadata = true },
        refresh_paths = paths, safe = function(_, fn) fn(); return true end }, { __index = _G })
    rows["/a.epub"] = { title = "Keep until ready" }
    compile("local ok = true; " .. branch, env)()
    H.eq(paths[1], "/a.epub"); H.eq(rows["/a.epub"].title, "Keep until ready"); H.eq(dropped["/a.epub"], nil)
end)

-- Optional actual-SQLite supplement, using KOReader's pinned binding rather
-- than a mock. The standard suites do not need a system SQLite installation.
local reference = os.getenv("ORBITUI_NATIVE_SQLITE")
if reference then
    package.loaded.ffi = native_ffi
    local stub = package.loaded["lua-ljsqlite3/init"]
    package.path = reference .. "/?.lua;" .. reference .. "/common/?.lua;" .. package.path
    require("ffi/loadlib")
    package.loaded["lua-ljsqlite3/init"] = nil
    local SQ = require("lua-ljsqlite3/init")
    local ffi = require("ffi")
    ffi.cdef("void *malloc(size_t size);")
    local fake_compress = package.loaded["ffi/zstd"].zstd_compress
    package.loaded["ffi/zstd"].zstd_compress = function()
        local ptr = ffi.C.malloc(10); ffi.copy(ptr, "compressed", 10); return ptr, 10
    end
    H.test("actual SQLite commits a BLOB and preserves unrelated columns and rows", function()
        fixture(); local db = SQ.open(":memory:")
        local schema = { "directory TEXT", "filename TEXT", "in_progress INTEGER", "ignore_cover TEXT", "pages INTEGER" }
        for _, col in ipairs({ "unsupported", "has_meta", "has_cover", "cover_fetched", "filesize", "filemtime", "title", "authors",
            "cover_sizetag", "cover_w", "cover_h", "cover_bb_type", "cover_bb_stride", "cover_bb_data BLOB" }) do schema[#schema + 1] = col end
        db:exec("CREATE TABLE bookinfo (" .. table.concat(schema, ",") .. ", UNIQUE(directory,filename));")
        db:exec("INSERT INTO bookinfo(directory,filename,pages,ignore_cover) VALUES('/','a.epub',431,'Y');")
        BIM.db_conn = db
        assert(M.extract("/a.epub", specs))
        local title, width, pages, ignored, kind = db:rowexec("SELECT title,cover_w,pages,ignore_cover,typeof(cover_bb_data) FROM bookinfo;")
        H.eq(title, "Custom title"); H.eq(tonumber(width), 400); H.eq(tonumber(pages), 431); H.eq(ignored, "Y"); H.eq(kind, "blob")
        local trigger = db:prepare("CREATE TRIGGER reject_cover BEFORE UPDATE ON bookinfo BEGIN SELECT RAISE(FAIL,'full disk'); END;")
        trigger:step(); trigger:close()
        assert(not M.extract("/new.epub", specs)); H.eq(tonumber(db:rowexec("SELECT count(*) FROM bookinfo;")), 1)
        H.eq(db:rowexec("SELECT title FROM bookinfo WHERE filename='a.epub';"), "Custom title")
        db:close(); BIM.db_conn = connection
    end)
    package.loaded["lua-ljsqlite3/init"] = stub
    package.loaded["ffi/zstd"].zstd_compress = fake_compress
end
os.time = old_time
H.finish()
