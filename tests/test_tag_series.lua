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
        info = info or {}
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

H.test("similar series exclude the source across profiles, preserve author identity and use maximum volume score", function()
    reset()
    local origin = add("/manga/current.epub", "Current", 1, "A")
    local own = add("/books/current02.epub", "Current", 2, "A"); own.similar_score = 10
    local homonym = add("/manga/homonym.epub", "Current", 1, "B"); homonym.similar_score = 2
    add("/manga/other01.epub", "Other", 1)
    local other = add("/manga/other02.epub", "Other", 2); other.similar_score = 3
    local records = { own, homonym, other }
    for i = 1, 30 do
        local row = add("/manga/large" .. i .. ".epub", "Large", i); row.similar_score = 1; records[#records + 1] = row
    end
    local state = start(records); H.eq(#Q.similarRows(records, state, origin.filepath, "series"), 0); flush()
    local before = reads
    local rows = Q.similarRows(records, state, origin.filepath, "series")
    H.eq(#rows, 3); H.eq(rows[1].title, "Other"); H.eq(rows[1].similar_score, 3)
    H.eq(rows[1].filepath, "/manga/other01.epub"); H.eq(#rows[1].matched, 1); H.eq(#rows[1].members, 2)
    H.eq(rows[2].authors[1], "B"); H.eq(rows[3].title, "Large"); H.eq(rows[3].similar_score, 1)
    H.eq(#Q.similarRows(records, state, origin.filepath, "volumes"), 32)
    H.eq(reads, before); H.eq(other.title, nil) -- sorting/rendering must not mutate the shared checked records
end)
H.test("similar books rank standalone titles by score then title with no fabricated metadata", function()
    reset()
    local origin = add("/books/source.epub")
    local records = {}
    for _, name in ipairs{ "Z", "A", "B" } do
        local row = add("/books/" .. name .. ".epub"); row.similar_score = name == "B" and 3 or 2
        records[#records + 1] = row
    end
    local unknown = add("/books/unknown.epub", nil, nil, nil, true); unknown.similar_score = 50
    records[#records + 1] = unknown
    local state = start(records); flush()
    local rows, incomplete = Q.similarRows(records, state, origin.filepath, "volumes")
    H.eq(incomplete, true); H.eq(#rows, 3); H.eq(rows[1].title, "B.epub"); H.eq(rows[2].title, "A.epub")
    H.eq(rows[1].tag_section_first, false)
    state.metadata[origin.filepath]._tag_known = false
    rows, incomplete = Q.similarRows(records, state, origin.filepath, "series")
    H.eq(#rows, 0); H.eq(incomplete, true)
    state.unavailable = true
    rows, incomplete = Q.similarRows(records, state, origin.filepath, "series")
    H.eq(#rows, 0); H.eq(incomplete, true)
end)

-- Exercise the shared dialog callbacks, not just the grouping helper.
local prefs, tag_reads, reveals, series_reveals, latest
local similar_paths, similar_scores, tag_revision, metadata_revision, request_failure
tag_revision, metadata_revision = "r1", 1
package.loaded["lib/bookshelf_book_repository"].dataGeneration = function() return metadata_revision end
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
    embeddedTagRequest = function(source, task, current, done)
        tag_reads = tag_reads + 1
        if task.similar then
            source.similar_revision, source.similar_tags, source.similar_stamp = tag_revision, { "Slice of life" }, "source"
        end
        UI:scheduleIn(.001, function()
            if current() then
                if task.similar and request_failure then done(nil, request_failure)
                else
                    local stamps = {}; for _, file in ipairs(similar_paths or {}) do stamps[file] = "checked" end
                    done({ paths = task.similar and similar_paths or { "/manga/02.epub", "/manga/10.epub" },
                        scores = task.similar and similar_scores or nil, stamps = stamps, scanned = #inventory, total = #inventory })
                end
            end
        end)
        return { cancel = function() end }
    end,
    embeddedTags = function() return { "Slice of life" } end,
    embeddedTagMatches = function() return true end,
    embeddedTagSnapshotRevision = function() return tag_revision end,
    embeddedTagScore = function(tags) return tags and 1 end,
    embeddedTagIsCurrent = function(file, stamp) return files[file] and not files[file].changed and type(stamp) == "string" end,
    embeddedTagError = function() return "Tag read failed" end,
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

local function similarDialog(opts, extras)
    reset(); prefs, tag_reads, reveals, series_reveals = {}, 0, 0, 0
    tag_revision, metadata_revision, request_failure = "r1", 1, nil
    add("/manga/source.epub", "Current", 1)
    add("/manga/source02.epub", "Current", 2)
    add("/manga/01.epub", "Other", 1)
    add("/manga/02.epub", "Other", 2)
    add("/books/single.epub")
    similar_paths, similar_scores = { "/manga/source02.epub", "/manga/02.epub", "/books/single.epub" },
        { ["/manga/source02.epub"] = 3, ["/manga/02.epub"] = 1, ["/books/single.epub"] = 2 }
    for i = 1, extras or 0 do
        local path = "/books/extra" .. i .. ".epub"; add(path)
        similar_paths[#similar_paths + 1], similar_scores[path] = path, 1
    end
    opts = opts or {}; opts.title, opts.view_profile = "Source", "manga"
    return Search.similarBooks("/manga/source.epub", opts)
end
H.test("recommendation modal uses native tabs, ranked scores and separate preferences without opening books", function()
    local modal = similarDialog({ open_book = function() error("must not open a reader") end })
    H.eq(tag_reads, 1); H.eq(reads, 0); H.eq(modal.config.initial_tab, "series")
    H.eq(modal.config.tabs[2].label, "Books"); flush()
    H.eq(modal.config.item_count(), 2); H.eq(modal.config.item_at(1).filepath, "/books/single.epub")
    H.eq(modal.config.item_at(2).filepath, "/manga/01.epub")
    local rendered = modal.config.cell_renderer(modal.config.item_at(2), {})
    assert(rendered.subtitle:find("Shared tags: 1 · Available volumes: 2", 1, true))
    local before = reads
    modal.config.on_tab_change("volumes"); H.eq(modal.config.item_count(), 2)
    H.eq(modal.config.item_at(2).filepath, "/manga/02.epub"); H.eq(tag_reads, 1); H.eq(reads, before)
    H.eq(prefs.orbitui_similar_result_view_manga, "volumes"); H.eq(prefs.orbitui_tag_result_view_manga, nil)
    local first = modal.config.item_at(1)
    modal.config.item_count(); modal.config.item_count(); H.eq(modal.config.item_at(1), first)
    modal.config.on_search_submit("single"); H.eq(modal.config.item_count(), 1)
    local I = package.loaded["adapters/orbitui_integrations"]
    local old_tags = I.embeddedTags
    I.embeddedTags = function() error("selection must use checked SQL scores/stamps, not open a candidate archive/cache") end
    modal.config.on_cell_tap(modal.config.item_at(1)); H.eq(reveals, 1); H.eq(modal.shown, false)
    I.embeddedTags = old_tags
end)
H.test("recommendations reveal a series' first local volume but refuse self-series, stale metadata and tag revisions", function()
    local modal = similarDialog(); flush()
    modal.config.on_cell_tap({ filepath = "/manga/source02.epub" }); H.eq(reveals, 0)
    modal.config.on_cell_tap(modal.config.item_at(2)); H.eq(series_reveals, 1); H.eq(reveals, 0)
    for _, change in ipairs{ function() metadata_revision = metadata_revision + 1 end,
            function() tag_revision = "r2" end,
            function() files["/books/single.epub"].changed = true end,
            function() files["/manga/source.epub"].changed = true end } do
        modal = similarDialog(); flush(); local row = modal.config.item_at(1)
        change(); modal.config.on_cell_tap(row); H.eq(reveals, 0)
        if metadata_revision ~= 1 or tag_revision ~= "r1" then H.eq(modal.config.item_count(), 0) end
        modal:onClose()
    end
end)
H.test("recommendations cap only after ranking, and surface missing metadata without a second user action", function()
    local modal = similarDialog(nil, 450); similar_scores[similar_paths[#similar_paths]] = 10; flush()
    H.eq(modal.config.item_count(), 400); H.eq(modal.config.item_at(1).similar_score, 10)
    assert(modal.config.intro:find("Showing the best 400 results.", 1, true))
    modal.config.on_search_submit("single"); H.eq(modal.config.item_count(), 1)
    assert(not modal.config.intro:find("Showing the best 400 results.", 1, true)); modal:onClose()
    modal = similarDialog(); files["/manga/source.epub"].unknown = true; flush()
    H.eq(modal.config.item_count(), 0)
    assert(modal.config.intro:find("Some cached series metadata is missing.", 1, true)); modal:onClose()
    modal = similarDialog(); fail = true; flush()
    H.eq(modal.config.item_count(), 0)
    assert(modal.config.intro:find("Some cached series metadata is missing.", 1, true)); modal:onClose()
end)
H.test("recommendations stop or sleep while discovering metadata without automatic wake scanning", function()
    for _, sleep in ipairs{ false, true } do
        local modal = similarDialog(nil, 40); flush(2); local before = reads
        H.eq(modal.config.item_count(), 0)
        if sleep then modal:onSuspend(); flush(); modal:onResume()
        else
            modal.config.footer_rows[1][1].on_tap()
            assert(modal.config.intro:find("Series discovery paused.", 1, true))
        end
        flush(); H.eq(reads, before)
        H.eq(modal.config.footer_rows[1][1].label_func(), "Refresh")
        modal.config.footer_rows[1][2].on_tap(); H.eq(modal.shown, false)
        flush(); H.eq(reads, before)
    end
end)
H.test("tagless recommendations have actionable help and index update is explicit, not a forced reread", function()
    local modal = similarDialog(); request_failure = "no_tags"; flush()
    assert(modal.config.intro:find("Genres are not used as substitute tags.", 1, true)); H.eq(reads, 0)
    local original, called = Search.tagIndex, nil
    Search.tagIndex = function(opts) called = opts end
    H.eq(modal.config.footer_rows[2][1].label, "Update tag index…")
    modal.config.footer_rows[2][1].on_tap(); H.eq(called.confirm_reread, false); H.eq(modal.shown, false)
    Search.tagIndex = original
    H.eq(Search.similarBooks("OPDS://source.epub"), nil); H.eq(Search.similarBooks("/source.pdf"), nil)
end)
H.test("an empty checked recommendation set does not walk metadata for the entire library", function()
    local modal = similarDialog(nil, 40); similar_paths = {}; flush()
    H.eq(modal.config.item_count(), 0); H.eq(reads, 0); H.eq(connections, 0); H.eq(#queue, 0)
    modal:onClose()
end)
H.test("recommendation strings have Swedish/English coverage without translating tag values", function()
    local _ = require("core/orbitui_i18n")
    for _i, text in ipairs{ "Find similar books and series…", "Similar books and series", "Update tag index…",
        "Library metadata or tags changed. Refresh and try again.",
        "Series discovery paused. Tap Refresh to continue.",
        "Showing the best 400 results.", "Shared tags: %d", "Shared tags: %d · Available volumes: %d",
        "%d EPUBs have no current cached tags. Update the tag index for complete recommendations.",
        "Some cached series metadata is missing. Those books are not recommended; update library metadata and refresh.",
        "This EPUB has no separate embedded tags. Add tags to the EPUB and update the tag index. Genres are not used as substitute tags.",
        "Local recommendations ranked by shared EPUB tags, across your libraries. The current book and its series are excluded. Only current indexed tags are used; no AI or server is needed." } do
        assert(_(text, "sv") ~= text); H.eq(_(text, "en"), text)
    end
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
