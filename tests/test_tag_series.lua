local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Q = require("core/orbitui_shelf_query")
local queue, files, inventory, statements, reads, connections, closes, changed, active, fail
local function flush(limit)
    local n = 0
    while #queue > 0 and (not limit or n < limit) do
        local item = table.remove(queue, 1); item.fn(); n = n + 1
    end
end
local UI = {
    scheduleIn = function(_, delay, fn)
        assert(delay > 0); queue[#queue + 1] = { fn = fn, delay = delay }
    end,
    unschedule = function(_, fn)
        for i = #queue, 1, -1 do if queue[i].fn == fn then table.remove(queue, i) end end
    end,
}
package.loaded["ui/uimanager"] = UI
package.loaded["ui/time"] = { now = os.clock, since = function(start) return os.clock() - start end,
    to_us = function(value) return value * 1000000 end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(file, key)
    return files[file] and (key == "mode" and "file" or { mode = "file" })
end }
package.loaded.datastorage = { getSettingsDir = function() return "/settings" end }
package.loaded["lib/bookshelf_profiles"] = {
    list = function() return {{ key = "manga", roots = { "/manga" } }, { key = "books", roots = { "/books" } }} end,
    matchFile = function(file) return file:match("^/manga/") and "manga" or file:match("^/books/") and "books" or nil end,
}
package.loaded["lib/bookshelf_book_repository"] = {
    getAllFilepaths = function() return inventory end,
    tagTextMeta = function(file, info)
        return { filepath = file, title = info.title or file, authors = info.authors and { info.authors } or {},
            series_name = info.series, series_num = info.series_index }
    end,
    getCoverBB = function() error("grouping must not request a cover") end,
    buildBookMeta = function() error("grouping must not open EPUB metadata") end,
}
package.loaded["lua-ljsqlite3/init"] = { open = function(path, mode)
    H.eq(path, "/settings/bookinfo_cache.sqlite3"); H.eq(mode, "ro")
    connections = connections + 1
    return {
        exec = function(_, sql) H.eq(sql, "PRAGMA busy_timeout=0;") end,
        prepare = function(_, sql)
            assert(sql:find("SELECT title,authors,series,series_index", 1, true))
            assert(not sql:find("cover")); assert(not sql:find("INSERT")); assert(not sql:find("UPDATE"))
            statements[#statements + 1] = sql
            local stmt = {}
            function stmt:reset() return self end
            function stmt:bind(dir, name) self.file = dir .. name; return self end
            function stmt:step()
                reads = reads + 1
                if fail then error("busy database") end
                local row = files[self.file]
                if row and not row.unknown then return { row.title, row.author, row.series, row.num } end
            end
            function stmt:close() closes = closes + 1 end
            return stmt
        end,
        close = function() closes = closes + 1 end,
    }
end }
local function reset()
    queue, files, inventory, statements = {}, {}, {}, {}
    reads, connections, closes, changed, active, fail = 0, 0, 0, 0, true, false
end
local function add(file, series, num, author, unknown)
    files[file] = { title = file:match("[^/]+$"), series = series, num = num, author = author or "Author", unknown = unknown }
    inventory[#inventory + 1] = file
    return { filepath = file, filename = file:match("[^/]+$") }
end
local function start(matches)
    local state = Q.tagSeriesSession{ current = function() return active end, changed = function() changed = changed + 1 end }
    state.update(matches); state.start(); return state
end
H.test("series collapse matching volumes and choose the first local volume even if it has no matching tag", function()
    reset()
    add("/manga/H/01.epub", "Hirayasumi", 1)
    local ten = add("/manga/H/10.epub", "Hirayasumi", 10)
    local two = add("/manga/H/02.epub", "Hirayasumi", 2)
    local state = start{ ten, two }
    H.eq(connections, 0); flush()
    local rows = state.rows(); H.eq(#rows, 1); H.eq(rows[1].series_name, "Hirayasumi")
    H.eq(#rows[1].matched, 2); H.eq(#rows[1].members, 3)
    H.eq(rows[1].filepath, "/manga/H/01.epub"); H.eq(rows[1].members[3].series_num, 10)
    H.eq(state.finished, true); H.eq(closes, 2)
    local before = reads; state.rows(); state.rows(); H.eq(reads, before)
end)
H.test("same-named series remain separate across profiles and authors", function()
    reset()
    local a = add("/manga/A.epub", "Same", 1, "A")
    local b = add("/manga/B.epub", "Same", 2, "B")
    local c = add("/books/C.epub", "Same", 3, "A")
    local state = start{ a, b, c }; flush(); H.eq(#state.rows(), 3)
    H.eq(Q.tagSeriesKey({ series_name = "Same", authors = { "B", "A" } }, "manga"),
        Q.tagSeriesKey({ series_name = "Same", authors = { "A", "B" } }, "manga"))
end)
H.test("oneshots and unknown series metadata stay in distinct visible sections", function()
    reset()
    local a = add("/manga/oneshot.epub")
    local b = add("/manga/unknown.epub", nil, nil, nil, true)
    local state = start{ a, b }; flush()
    local rows = state.rows(); H.eq(#rows, 2)
    H.eq(rows[1].tag_section, "standalone"); H.eq(rows[1].tag_section_first, true)
    H.eq(rows[2].tag_section, "unknown"); H.eq(rows[2].tag_section_first, true)
end)
H.test("numeric decimal volume order wins over filenames and unknown indexes sort last", function()
    reset()
    local a = add("/manga/z.epub", "S", 2.5)
    local b = add("/manga/a.epub", "S", 10)
    local c = add("/manga/0.epub", "S")
    local state = start{ a, b, c }; flush()
    H.eq(state.rows()[1].filepath, a.filepath)
    H.eq(state.rows()[1].members[3].filepath, c.filepath)
end)
H.test("an eight-file turn yields and tab pause resumes without repeating earlier metadata reads", function()
    reset()
    local matches = {}
    for i = 1, 25 do matches[i] = add("/manga/" .. i .. ".epub", "S", i) end
    local state = start(matches); flush(1); H.eq(reads, 8); assert(#queue > 0)
    state.pause(); H.eq(#queue, 0); H.eq(closes, 2); H.eq(state.busy, false)
    local before = reads; flush(); H.eq(reads, before)
    state.start(); flush(); H.eq(reads, 25); H.eq(connections, 2); H.eq(closes, 4)
    H.eq(state.finished, true); H.eq(#state.rows()[1].members, 25)
end)
H.test("closed and navigation-retired sessions close their own statement and connection", function()
    for _, cancel in ipairs{ true, false } do
        reset()
        local matches = {}; for i = 1, 20 do matches[i] = add("/manga/" .. i .. ".epub", "S", i) end
        local state = start(matches); flush(1)
        local before = reads
        if cancel then state.cancel() else active = false end
        flush(); H.eq(reads, before); H.eq(closes, 2); H.eq(state.busy, false)
        state.start(); flush(); H.eq(reads, before)
    end
end)
H.test("database errors are explicit and do not produce a complete empty series result", function()
    reset(); local match = add("/manga/a.epub", "S", 1); fail = true
    local state = start{ match }; flush()
    H.eq(state.unavailable, true); H.eq(state.finished, nil); H.eq(state.busy, false); H.eq(closes, 2)
    H.eq(#state.rows(), 1); H.eq(state.rows()[1].tag_section, "unknown")
    fail = false; state.start(); flush()
    H.eq(state.unavailable, false); H.eq(state.finished, true)
    H.eq(state.rows()[1].filepath, match.filepath)
end)
H.test("native modal construction honours a saved initial tab without changing other pickers", function()
    local f = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_library_modal.lua")); local source = f:read("*a"); f:close()
    local Native = {}
    local simple = { new = function(_, value) return value end }
    local env = setmetatable({ LibraryModal = Native, Geom = simple, GestureRange = simple,
        Screen = { getWidth = function() return 600 end, getHeight = function() return 800 end },
        Device = { hasKeys = function() return false end, hasDPad = function() return false end,
            screen = { getWidth = function() return 600 end, getHeight = function() return 800 end } },
    }, { __index = _G })
    local code = assert(source:match("(function LibraryModal:init%b().-\nend)"))
    if setfenv then setfenv(assert(loadstring(code)), env)() else assert(load(code, "native initial tab", "t", env))() end
    for _, initial in ipairs{ "volumes", "invalid", "series" } do
        local modal = { config = { tabs = {{ key = "series" }, { key = "volumes" }}, initial_tab = initial },
            _buildFrame = function() end }
        Native.init(modal)
        H.eq(modal.active_tab, initial == "volumes" and "volumes" or "series")
    end
end)
H.test("quoted Unicode paths are bound as parameters and deleted volumes cannot become members", function()
    reset()
    local a = add("/manga/日本語 ' ?/01.epub", "S", 1)
    add("/manga/deleted.epub", "S", 0); files["/manga/deleted.epub"] = nil
    local state = start{ a }; flush()
    H.eq(#state.rows()[1].members, 1); H.eq(state.rows()[1].filepath, a.filepath)
    H.eq(#statements, 1)
end)
H.test("updating the tag predicate never promotes unmatching series or combines tags across volumes", function()
    reset()
    local a = add("/manga/a.epub", "A", 1)
    local b = add("/manga/b.epub", "B", 1)
    local state = start{ a }; flush(); H.eq(#state.rows(), 1); H.eq(state.rows()[1].title, "A")
    local before = reads
    state.update{}; H.eq(#state.rows(), 0)
    state.update{ b }; H.eq(#state.rows(), 1); H.eq(state.rows()[1].title, "B"); H.eq(reads, before)
end)
H.test("an already warm metadata batch performs no SQLite, archive or cover reads", function()
    reset()
    local repo = package.loaded["lib/bookshelf_book_repository"]
    local match = add("/manga/02.epub", "S", 2)
    add("/manga/01.epub", "S", 1)
    repo.cachedTagInfo = function(file)
        local entry = files[file]
        return { title = entry.title, authors = entry.author, series = entry.series, series_index = entry.num, has_meta = 1 }
    end
    local state = start{ match }; flush()
    H.eq(state.rows()[1].filepath, "/manga/01.epub"); H.eq(connections, 0); H.eq(reads, 0)
    repo.cachedTagInfo = nil
end)
H.test("tag-result tab labels and warnings are Swedish and English without changing singular metadata labels", function()
    local _ = require("core/orbitui_i18n")
    H.eq(_("Series", "sv", "tag-results"), "Serier"); H.eq(_("Series", "sv"), "Serie")
    H.eq(_("Volumes", "sv"), "Volymer"); H.eq(_("Series", "en", "tag-results"), "Series")
    for _i, text in ipairs{ "Volume 1 is not in cached metadata", "Standalone books", "Unknown series metadata",
        "Volume order is unknown", "Series metadata is not complete yet. Wait, refresh, or switch to Volumes." } do
        assert(_(text, "sv") ~= text); H.eq(_(text, "en"), text)
    end
end)
H.test("slow metadata resolution yields at its eight millisecond budget", function()
    reset()
    local clock, original_time = 0, package.loaded["ui/time"]
    package.loaded["ui/time"] = { now = function() return clock end, since = function(start) return clock - start end,
        to_us = function(value) return value * 1000000 end }
    local repo = package.loaded["lib/bookshelf_book_repository"]
    local native_meta = repo.tagTextMeta
    repo.tagTextMeta = function(...) clock = clock + .011; return native_meta(...) end
    local matches = {}; for i = 1, 3 do matches[i] = add("/manga/" .. i .. ".epub", "S", i) end
    local state = start(matches); flush(1); H.eq(reads, 1); H.eq(state.busy, true)
    flush(); H.eq(reads, 3); H.eq(state.finished, true)
    repo.tagTextMeta, package.loaded["ui/time"] = native_meta, original_time
end)
H.test("native text resolution honours custom and Calibre series without repairing an EPUB", function()
    local f = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_book_repository.lua")); local source = f:read("*a"); f:close()
    local calls = 0
    local env = setmetatable({ Repo = {},
        _cpText = function(props, key) return props and props[key] end,
        _calibreMetadataFor = function() return { series = "Calibre", series_index = 4, authors = { "Curated" } } end,
        _customPropsFor = function() return { series = "Edited", series_index = "2.5", title = "Custom" } end,
        seriesFromInfoOrEpub = function() calls = calls + 1; error("must not open EPUB") end,
        splitAuthors = function(text) return { text } end,
        authorsFromInfo = function(_, info) return { info.authors or "Unknown" } end,
    }, { __index = _G })
    for _, pattern in ipairs{ "(local function _resolveTextMeta%b().-\nend)", "(function Repo.tagTextMeta%b().-\nend)" } do
        local code = assert(source:match(pattern))
        if pattern:find("local function", 1, true) then code = code:gsub("local function", "function", 1) end
        if setfenv then setfenv(assert(loadstring(code)), env)() else assert(load(code, "native cached metadata", "t", env))() end
    end
    local book = env.Repo.tagTextMeta("/manga/a.epub", { series = "Embedded #8", series_index = 8 })
    H.eq(book.series_name, "Edited"); H.eq(book.series_num, "2.5"); H.eq(book.title, "Custom")
    H.eq(book.authors[1], "Curated"); H.eq(calls, 0)
end)

-- Exercise the shared dialog callbacks, not just the grouping helper.
local prefs, tag_reads, reveals, series_reveals, latest
UI.show = function(_, modal) modal.shown = true end
UI.close = function(_, modal) modal.shown = false end
UI.isWidgetShown = function(_, modal) return modal and modal.shown end
UI._simpleui_navigation_generation = 1
local Modal = {}
function Modal:new(opts)
    local modal = { config = opts.config, active_tab = opts.config.initial_tab, page = 1 }
    function modal:refresh() self.config.item_count() end
    function modal:onClose() self.shown = false; self.config.on_closed() end
    latest = modal; return modal
end
package.loaded["lib/bookshelf_library_modal"] = Modal
package.loaded["device"] = { screen = { getWidth = function() return 600 end, getHeight = function() return 800 end } }
package.loaded["lib/bookshelf_picker_cell"] = { render = function(item) return item end }
package.loaded["lib/bookshelf_settings_store"] = {
    read = function(key) return prefs[key] end,
    saveDeferred = function(key, value) prefs[key] = value end,
}
package.loaded["adapters/orbitui_integrations"] = {
    embeddedTagRule = function(rule) return type(rule) == "table" and rule or { tags = { rule }, mode = "all" } end,
    embeddedTagSession = function()
        return { inventory = inventory, current = function() return active end }
    end,
    embeddedTagRequest = function(_, _, current, done)
        tag_reads = tag_reads + 1
        UI:scheduleIn(.001, function()
            if current() then done({ paths = { "/manga/02.epub", "/manga/10.epub" }, scanned = 3, total = 3 }) end
        end)
        return { cancel = function() end }
    end,
    embeddedTags = function() return { "Slice of life" } end,
    embeddedTagMatches = function() return true end,
}
local Context = require("core/orbitui_context")
Context.notify = function() end
Context.revealSeries = function(book) series_reveals = series_reveals + 1; H.eq(book.filepath, "/manga/01.epub") end
Context.revealBook = function() reveals = reveals + 1 end
local Search = require("core/orbitui_search")
local function dialog()
    reset(); prefs, tag_reads, reveals, series_reveals = {}, 0, 0, 0
    add("/manga/01.epub", "Hirayasumi", 1)
    add("/manga/02.epub", "Hirayasumi", 2)
    add("/manga/10.epub", "Hirayasumi", 10)
    return Search.embeddedTag("Slice of life", { view_profile = "manga" })
end
H.test("Manga starts on Series, tab switches reuse the tag search and remember only that library's choice", function()
    local modal = dialog(); H.eq(modal.config.initial_tab, "series"); flush()
    H.eq(modal.config.item_count(), 1); H.eq(tag_reads, 1)
    local group = modal.config.item_at(1)
    assert(modal.config.cell_renderer(group, {}).subtitle:find("2 matching volumes", 1, true))
    assert(not modal.config.cell_renderer(group, {}).subtitle:find("Volume 1 is not", 1, true))
    local before = reads
    modal.config.on_tab_change("volumes"); H.eq(modal.config.item_count(), 2)
    modal.config.on_tab_change("series"); flush(); H.eq(modal.config.item_count(), 1)
    H.eq(tag_reads, 1); H.eq(reads, before); H.eq(prefs.orbitui_tag_result_view_manga, "series")
    modal.config.on_tab_change("volumes"); modal:onClose()
    local other = Search.embeddedTag("Slice of life", { view_profile = "manga" })
    H.eq(other.config.initial_tab, "volumes"); other:onClose()
    H.eq(Search.embeddedTag("Slice of life", { view_profile = "books" }).config.initial_tab, "volumes")
end)
H.test("series taps navigate to the first available volume without opening and missing volume one is labelled", function()
    local modal = dialog(); flush()
    modal.config.on_cell_tap(modal.config.item_at(1)); H.eq(series_reveals, 1); H.eq(reveals, 0)
    modal = dialog(); files["/manga/01.epub"] = nil; flush()
    local note = modal.config.cell_renderer(modal.config.item_at(1), {}).subtitle
    assert(note:find("Volume 1 is not in cached metadata", 1, true)); modal:onClose()
end)
H.test("a closed dialog or incomplete metadata cannot navigate, and Volumes keeps its existing reveal", function()
    local modal = dialog()
    for i = 11, 30 do add("/manga/extra" .. i .. ".epub", "Extra", i) end
    flush(2)
    local book = modal.config.item_at(1); modal.config.on_cell_tap(book)
    H.eq(series_reveals, 0); flush()
    book = modal.config.item_at(1); modal:onClose(); modal.config.on_cell_tap(book); H.eq(series_reveals, 0)
    modal = dialog(); flush(); modal.config.on_tab_change("volumes")
    modal.config.on_cell_tap(modal.config.item_at(1)); H.eq(reveals, 1); H.eq(series_reveals, 0)
end)
H.test("Stop, Close and sleep retire metadata work without rescanning tags on tab changes", function()
    local modal = dialog()
    for i = 11, 40 do add("/manga/extra" .. i .. ".epub", "Extra", i) end
    flush(2); local before = reads
    H.eq(modal.config.footer_rows[1][1].label_func(), "Stop search")
    modal.config.footer_rows[1][1].on_tap(); flush(); H.eq(reads, before)
    H.eq(modal.config.footer_rows[1][1].label_func(), "Refresh")
    modal.config.on_tab_change("volumes"); modal.config.on_tab_change("series"); flush()
    H.eq(tag_reads, 1); H.eq(modal.config.item_count(), 1)
    modal:onClose(); before = reads; flush(); H.eq(reads, before)
    modal = dialog()
    for i = 11, 40 do add("/manga/extra" .. i .. ".epub", "Extra", i) end
    flush(2); before = reads; modal:onSuspend(); flush(); H.eq(reads, before)
    modal:onClose(); modal:onResume(); flush(); H.eq(reads, before)
end)

H.test("visible series thumbnails preserve aspect and never free a borrowed cover", function()
    local Widget = H.widget()
    for _, name in ipairs{ "ui/widget/imagewidget", "ui/widget/horizontalgroup", "ui/widget/container/centercontainer", "ui/geometry" } do
        package.loaded[name] = Widget
    end
    local bb = { getWidth = function() return 100 end, getHeight = function() return 200 end }
    package.loaded["lib/bookshelf_scaled_cover_cache"] = { get = function() return bb end }
    local group = { title = "Hirayasumi", filepath = "/manga/01.epub" }
    local rendered = Q.tagSeriesCell(group, { w = 400, h = 100 }, "2 matching volumes · 3 available")
    local image = rendered[1][1]
    H.eq(image.image, bb); H.eq(image.image_disposable, false)
    H.eq(image.width * 2, image.height)
    local repo = package.loaded["lib/bookshelf_book_repository"]
    local old = repo.getCoverBB; repo.getCoverBB = function() return bb end
    package.loaded["lib/bookshelf_scaled_cover_cache"].get = function() end
    rendered = Q.tagSeriesCell(group, { w = 400, h = 100 }, "3 available")
    H.eq(rendered[1][1].image_disposable, true)
    local freed, put = 0, nil
    bb.free = function() freed = freed + 1 end
    local small = { getWidth = function() return 44 end, getHeight = function() return 88 end }
    package.loaded["ui/renderimage"] = { scaleBlitBuffer = function() return small end }
    package.loaded["lib/bookshelf_scaled_cover_cache"].put = function(_, file, cover)
        H.eq(file, group.filepath); put = cover
    end
    rendered = Q.tagSeriesCell(group, { w = 400, h = 100 }, "3 available")
    H.eq(put, small); H.eq(freed, 1); H.eq(rendered[1][1].image_disposable, false)
    repo.getCoverBB = old
end)

local native = os.getenv("ORBITUI_NATIVE_SQLITE_DIR")
if jit and native then
    package.path = native .. "/?.lua;" .. package.path
    local ffi = require("ffi")
    ffi.cdef[[void *malloc(size_t); void free(void *);]]
    package.loaded["ffi/posix_h"] = true
    ffi.loadlib = function(name, version)
        return ffi.load(jit.os == "OSX" and name or ("lib" .. name .. ".so." .. version))
    end
    package.loaded["lua-ljsqlite3/init"] = nil
    local SQL = require("lua-ljsqlite3/init")
    H.test("actual native SQLite reads indexed text with bound paths on a separate read-only connection", function()
        reset()
        local pipe = assert(io.popen("mktemp -d /tmp/orbitui-tag-series.XXXXXX"))
        local directory = assert(pipe:read("*l")); assert(pipe:close())
        local path = directory .. "/bookinfo_cache.sqlite3"
        package.loaded.datastorage = { getSettingsDir = function() return directory end }
        local db = SQL.open(path)
        db:exec("CREATE TABLE bookinfo(directory TEXT,filename TEXT,title TEXT,authors TEXT,series TEXT,series_index REAL,in_progress INTEGER,has_meta INTEGER)")
        local put = db:prepare("INSERT INTO bookinfo VALUES(?,?,?,?,?,?,0,1)")
        for i = 1, 3 do
            local name = "日本語 ' " .. i .. ".epub"
            add("/manga/" .. name, "Hirayasumi", i)
            put:reset():bind("/manga/", name, name, "Author", "Hirayasumi", i):step()
        end
        put:close(); db:close()
        local f = assert(io.open(path, "rb")); local before = f:read("*a"); f:close()
        local state = start{{ filepath = inventory[2], filename = "2.epub" }}; flush()
        H.eq(state.unavailable, false); H.eq(state.finished, true)
        H.eq(#state.rows(), 1); H.eq(#state.rows()[1].members, 3)
        H.eq(state.rows()[1].filepath, inventory[1])
        f = assert(io.open(path, "rb")); H.eq(f:read("*a"), before); f:close()
    end)
else print("SKIP native tag-series SQLite supplement: set ORBITUI_NATIVE_SQLITE_DIR under LuaJIT") end
H.finish()
