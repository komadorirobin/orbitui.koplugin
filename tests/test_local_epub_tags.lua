local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Integration = require("adapters/orbitui_integrations")
local tag, other = "Åland & 日本語", "Other"
local values = {
    ['["Åland & 日本語","Other","Other"]'] = { tag, other, other },
    ['["Åland & 日本語"]'] = { tag }, ['[]'] = {}, ['{}'] = {},
    ['[1]'] = { 1 }, ['["bad"]'] = { "bad\n" },
}
package.loaded.rapidjson = { decode = function(text) return assert(values[text], "invalid JSON fixture") end }
local function opf(value, legacy)
    if legacy then
        return '<package><metadata><meta content="' .. value:gsub('&', '&amp;'):gsub('"', '&#34;')
            .. '" name="bookorbit:tags" /></metadata></package>'
    end
    return '<package><metadata><dc:subject>Not a tag</dc:subject><meta property="bookorbit:tags">'
        .. value:gsub("&", "&amp;") .. '</meta></metadata></package>'
end
H.test("local EPUB 2/3 tags retain exact Unicode names and deduplicate without genres or collections", function()
    for _, legacy in ipairs{ false, true } do
        local tags = assert(Integration.embeddedTagsFromOpf(opf('["Åland & 日本語","Other","Other"]', legacy)))
        H.eq(#tags, 2); H.eq(tags[1], tag); H.eq(tags[2], other)
    end
    H.eq(#assert(Integration.embeddedTagsFromOpf('<package><metadata><dc:subject>Genre</dc:subject></metadata></package>')), 0)
end)
H.test("XML comments, CDATA, prefixes, quotes and numeric entities cannot fabricate tags", function()
    local text = '<opf:package><opf:metadata><!-- <meta property="bookorbit:tags">[1]</meta> -->'
        .. '<opf:meta data-note=\'>\' property="bookorbit:tags"><![CDATA[["Åland & 日本語"]]]></opf:meta>'
        .. '</opf:metadata></opf:package>'
    H.eq(assert(Integration.embeddedTagsFromOpf(text))[1], tag)
    text = '<package><metadata><meta property="bookorbit:tags">[&quot;&#xC5;land &amp; 日本語&quot;]</meta></metadata></package>'
    H.eq(assert(Integration.embeddedTagsFromOpf(text))[1], tag)
    text = '<package><metadata><meta property="not:tags">[1]</meta></metadata></package>'
    H.eq(#assert(Integration.embeddedTagsFromOpf(text)), 0)
end)
H.test("malformed JSON/XML, DTDs, control tags and oversized metadata fail closed", function()
    for _, text in ipairs{ opf('{}'), opf('[1]'), opf('["bad"]'), opf('invalid'),
            opf('[]'):gsub('</metadata>', '</wrong>'), '<!DOCTYPE package><package><metadata/></package>',
            '<package><metadata>', '<package/><package/>', '<package/>' , string.rep(' ', 1048577) } do
        local tags, err = Integration.embeddedTagsFromOpf(text)
        H.eq(tags, nil); H.eq(err, "invalid_epub")
    end
end)

local files, documents, disk, queue, roots, opened, closed, extracted, written, last_widget
local elapsed, cache_cost, cache_reads, archive_cost, delays
local UI = { _simpleui_navigation_generation = 1,
    show = function(_, w) w.shown = true; last_widget = w end,
    close = function(_, w) w.shown = false end,
    isWidgetShown = function(_, w) return w and w.shown end,
    forceRePaint = function() end,
    nextTick = function(_, fn) queue[#queue + 1] = fn end,
    scheduleIn = function(_, delay, fn)
        H.eq(delay, .001); delays[#delays + 1] = delay; queue[#queue + 1] = fn
    end }
package.loaded["ui/uimanager"] = UI
package.loaded["ui/time"] = { now = function() return elapsed end,
    since = function(start) return elapsed - start end, to_us = function(value) return value * 1000000 end }
package.loaded["ui/widget/infomessage"] = H.widget()
package.loaded["ui/widget/confirmbox"] = H.widget()
package.loaded["device"] = { screen = { getWidth = function() return 600 end, getHeight = function() return 800 end } }
package.loaded["lib/bookshelf_keyed_cache"] = { new = function(name, version)
    H.eq(name, "orbitui_epub_tags"); H.eq(version, 1)
    return { read = function(file) elapsed = elapsed + cache_cost; cache_reads = cache_reads + 1; return disk[file] end,
        write = function(file, entry) disk[file] = entry; written = written + 1 end }
end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(file, field)
    local value = files[file]
    return field and value and value[field] or (not field and value) or nil
end }
package.loaded["lib/bookshelf_profiles"] = { list = function() return {{ key = "a", roots = roots }} end,
    scope = function(p) return { roots = p.roots } end }
package.loaded["lib/bookshelf_settings_store"] = { read = function() return 3 end }
local repo = { getAllFilepaths = function(scope)
    if scope then return { "/profile/a.epub", "/books/a.epub", "OPDS://remote.epub" } end
    local out = {}; for file in pairs(files) do if file:sub(1, 7) == "/books/" then out[#out + 1] = file end end
    return out
end, buildBookMeta = function(file, opts) H.eq(opts.want_cover, false); return { title = file, author = "Author" } end }
package.loaded["lib/bookshelf_book_repository"] = repo
local container = '<container><rootfiles><rootfile full-path="OPS/main.opf" media-type="application/oebps-package+xml" /></rootfiles></container>'
local archive = { new = function()
    local reader = { entries = {} }
    function reader:open(file)
        opened = opened + 1
        elapsed = elapsed + archive_cost
        self.doc = documents[file]
        if not self.doc then return nil end
        for i, item in ipairs(self.doc) do self.entries[i] = item; self.entries[item.path] = item end
        return true
    end
    function reader:iterate()
        local i = 0
        return function() i = i + 1; return self.entries[i] end
    end
    function reader:extractToMemory(key)
        extracted = extracted + 1
        local entry = assert(self.entries[key])
        assert(entry.size <= 1024 * 1024)
        return entry.data
    end
    function reader:close() closed = closed + 1 end
    return reader
end }
package.loaded["ffi/archiver"] = { Reader = archive }
local function add(file, data)
    files[file] = { mode = "file", modification = 1, change = 1, size = #data }
    documents[file] = {
        { path = "META-INF/container.xml", mode = "file", data = container, size = #container },
        { path = "OPS/main.opf", mode = "file", data = data, size = #data },
    }
end
local function reset()
    files, documents, disk, queue, roots = {}, {}, {}, {}, { "/profile" }
    opened, closed, extracted, written = 0, 0, 0, 0
    elapsed, cache_cost, cache_reads, archive_cost, delays = 0, 0, 0, 0, {}
    add("/books/a.epub", opf('["Åland & 日本語"]'))
    add("/profile/a.epub", opf('["Åland & 日本語"]', true))
    add("/books/untagged.epub", opf('[]'))
end
local function flush(count)
    while #queue > 0 and (not count or count > 0) do
        table.remove(queue, 1)()
        if count then count = count - 1 end
    end
end
H.test("safe archive reads always close and use stat-keyed disposable local cache", function()
    reset()
    local file = "/books/a.epub"
    H.eq(assert(Integration.embeddedTags(file))[1], tag); H.eq(opened, 1); H.eq(closed, 1)
    H.eq(assert(Integration.embeddedTags(file))[1], tag); H.eq(opened, 1)
    files[file].change = 2
    assert(Integration.embeddedTags(file)); H.eq(opened, 2)
    assert(Integration.embeddedTags(file, true)); H.eq(opened, 3)
    H.eq(written, 3)
    files[file] = nil
    H.eq(Integration.embeddedTags(file), nil); H.eq(opened, 3)
    files["/books/not.pdf"] = { mode = "file" }
    local _, err = Integration.embeddedTags("/books/not.pdf"); H.eq(err, "not_epub")
end)
H.test("bad archives, duplicate entries and oversized metadata are retryable and never negative-cached", function()
    for _, bad in ipairs{ "missing", "large", "duplicate", "link", "invalid" } do
        reset()
        local file = "/books/a.epub"
        if bad == "missing" then documents[file] = nil
        elseif bad == "large" then documents[file][2].size = 1048577
        elseif bad == "duplicate" then documents[file][3] = documents[file][2]
        elseif bad == "link" then documents[file][2].mode = "link"
        else documents[file][2].data = "invalid"; documents[file][2].size = 7 end
        H.eq(Integration.embeddedTags(file), nil); H.eq(written, 0); H.eq(closed, 1)
        add(file, opf('["Åland & 日本語"]'))
        H.eq(assert(Integration.embeddedTags(file))[1], tag); H.eq(opened, 2); H.eq(closed, 2)
    end
end)
H.test("local search scans configured profiles and unlinked EPUBs one per tick, with no network/provider", function()
    reset()
    local result
    local source = Integration.embeddedTagSession()
    Integration.embeddedTagRequest(source, { tag = tag }, function() return true end, function(value) result = value end)
    H.eq(opened, 0); H.eq(#queue, 1)
    flush(1); H.eq(opened, 1); H.eq(result, nil)
    flush(); H.eq(#result.paths, 2); H.eq(result.skipped, 0); H.eq(result.truncated, false)
    H.eq(opened, 3); H.eq(opened, closed)
end)
H.test("cache-only searches batch bounded hits without reopening unchanged or tagless EPUBs", function()
    reset()
    for i = 1, 80 do add("/books/cached" .. i .. ".epub", opf('[]')) end
    for file in pairs(files) do assert(Integration.embeddedTags(file)) end
    local before, result = opened
    Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag }, function() return true end,
        function(value) result = value end)
    flush(1)
    H.eq(opened, before); H.eq(result, nil); H.eq(#queue, 1)
    flush()
    H.eq(opened, before); H.eq(#result.paths, 2); H.eq(result.skipped, 0)
    H.eq(#delays, 2) -- 83 entries, at most 32 per turn rather than 83 timers.
end)
H.test("slow cache I/O yields at its elapsed budget and rechecks cancellation before more work", function()
    reset()
    for file in pairs(files) do assert(Integration.embeddedTags(file)) end
    cache_cost = .009
    local result, failure
    Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag }, function() return true end,
        function(value, err) result, failure = value, err end)
    flush(1); H.eq(elapsed, .009); H.eq(result, nil); H.eq(#delays, 1)
    last_widget.dismiss_callback(); flush()
    H.eq(elapsed, .009); H.eq(result, nil); H.eq(failure, "cancelled")
end)
H.test("mixed scans open at most one uncached archive per turn and preserve successes after cancellation", function()
    reset()
    local result, failure
    local function request()
        Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag }, function() return true end,
            function(value, err) result, failure = value, err end)
    end
    request(); flush(1); H.eq(opened, 1)
    last_widget.dismiss_callback(); flush(); H.eq(failure, "cancelled")
    request(); flush(1); H.eq(opened, 2); H.eq(result, nil)
    flush(1); H.eq(opened, 3)
    flush(); H.eq(#result.paths, 2)
    H.eq(written, 3); H.eq(opened, closed)
end)
H.test("cancelled, closed and changed-scope workers do not continue scans or deliver stale results", function()
    for _, reason in ipairs{ "cancel", "close", "scope" } do
        reset()
        local active, result, failure = true, nil, nil
        Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag }, function() return active end,
            function(value, err) result, failure = value, err end)
        flush(1); H.eq(opened, 1)
        if reason == "cancel" then last_widget.dismiss_callback()
        elseif reason == "close" then active = false
        else roots = { "/new" } end
        flush(); H.eq(opened, 1); H.eq(result, nil)
        H.eq(failure, reason == "cancel" and "cancelled" or reason == "scope" and "stale" or nil)
        H.eq(last_widget.shown, false)
    end
end)
H.test("unreadable EPUBs are counted honestly and the result cap is disclosed", function()
    reset(); documents["/books/untagged.epub"] = nil
    local result
    Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag }, function() return true end, function(value) result = value end)
    flush(); H.eq(result.skipped, 1); H.eq(#result.paths, 2)
    reset()
    for i = 1, 405 do add("/books/" .. i .. ".epub", opf('["Åland & 日本語"]')) end
    Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag }, function() return true end, function(value) result = value end)
    flush(); H.eq(#result.paths, 400); H.eq(result.truncated, true)
end)
local Modal = H.widget()
function Modal:refresh() end
function Modal:onClose() self.shown = false; self.config.on_closed() end
package.loaded["lib/bookshelf_library_modal"] = Modal
package.loaded["lib/bookshelf_picker_cell"] = { render = function(value) return value end }
H.test("existing Tags tab displays local pills offline and opens the shared local result modal", function()
    reset()
    local panel = require("adapters/orbitui_book_panel")
    local book, section = { filepath = "/books/a.epub" }
    local modal = { _tabs = {{ id = "tags" }}, _active_tab = 1, shown = true }
    function modal:rebuildTab() section = panel.tagSections({}, book, self)[1] end
    function modal:onClose() self._dismissed = true; self.shown = false end
    modal:rebuildTab(); H.eq(opened, 0)
    local retired = section.pills[1].on_tap
    retired(); flush(); H.eq(section.pills[1].label, tag)
    retired(); flush(); H.eq(opened, 1)
    section.pills[1].on_tap(); H.eq(modal._dismissed, true)
    flush(); H.eq(getmetatable(last_widget), Modal); H.eq(last_widget.shown, true) -- inline search, no blocking notice
end)
H.test("local result actions retain real reader paths and refuse a changed tag/file", function()
    reset()
    local opened_file
    local modal = require("core/orbitui_search").embeddedTag(tag, { open_book = function(file) opened_file = file end })
    flush(); H.eq(modal.config.item_count(), 2)
    local book = modal.config.item_at(1)
    modal.config.cell_renderer(book, { w = 200, h = 50 })
    add(book.filepath, opf('[]')); files[book.filepath].change = 2
    package.loaded["core/orbitui_context"].notify = function() end
    modal.config.on_cell_tap(book); H.eq(opened_file, nil)
    book = modal.config.item_at(2)
    modal.config.on_cell_tap(book); H.eq(opened_file, book.filepath)
end)
H.test("normal Refresh reuses valid tags, rechecks changed/deleted files and retries previous failures", function()
    reset()
    documents["/books/untagged.epub"] = nil
    local modal = require("core/orbitui_search").embeddedTag(tag)
    flush(); H.eq(opened, 3); H.eq(modal.config.item_count(), 2)
    add("/books/untagged.epub", opf('["Åland & 日本語"]'))
    modal.config.footer_rows[1][1].on_tap(); flush()
    H.eq(opened, 4); H.eq(modal.config.item_count(), 3)
    files["/books/a.epub"] = nil
    add("/profile/a.epub", opf('[]')); files["/profile/a.epub"].change = 2
    add("/books/new.epub", opf('["Åland & 日本語"]'))
    modal.config.footer_rows[1][1].on_tap(); flush()
    H.eq(opened, 6); H.eq(modal.config.item_count(), 2)
end)
H.test("full reread is a separate confirmed local action and stale confirmations cannot start work", function()
    reset()
    local modal = require("core/orbitui_search").embeddedTag(tag)
    flush(); H.eq(opened, 3)
    local action = modal.config.footer_rows[2][1]
    H.eq(action.label, "Reread all EPUB tags…")
    action.on_tap(); H.eq(opened, 3); H.eq(#queue, 0)
    local confirm = last_widget
    H.eq(confirm.sui_native, true)
    UI:close(confirm) -- Cancelling confirmation does not touch any archive/cache.
    H.eq(opened, 3); H.eq(#queue, 0)
    action.on_tap(); last_widget.ok_callback(); flush()
    H.eq(opened, 6); H.eq(modal.config.item_count(), 2)
    action.on_tap(); confirm = last_widget
    modal:onClose(); confirm.ok_callback(); flush(); H.eq(opened, 6)
end)
H.test("inline matches are usable before completion; stopping keeps honest partial results and Refresh continues", function()
    reset()
    for i = 1, 80 do add("/books/z" .. i .. ".epub", opf('[]')) end
    local modal = require("core/orbitui_search").embeddedTag(tag)
    H.eq(last_widget, modal); H.eq(modal.config.footer_rows[1][1].label_func(), "Stop search")
    flush(1); H.eq(modal.config.item_count(), 1)
    assert(modal.config.intro:find("1 of 83 files", 1, true))
    assert(modal.config.intro:find("incomplete", 1, true))
    modal.config.footer_rows[1][1].on_tap()
    H.eq(modal.config.item_count(), 1); H.eq(modal.config.footer_rows[1][1].label_func(), "Refresh")
    assert(modal.config.intro:find("Search stopped", 1, true))
    flush(); H.eq(opened, 1)
    modal.config.footer_rows[1][1].on_tap(); flush()
    H.eq(opened, 83); H.eq(modal.config.item_count(), 2)
    assert(not modal.config.intro:find("incomplete", 1, true))
end)
H.test("opening a checked partial match retires the worker and cannot read more archives", function()
    reset()
    local opened_file
    local modal = require("core/orbitui_search").embeddedTag(tag, { open_book = function(file) opened_file = file end })
    flush(1); H.eq(modal.config.item_count(), 1)
    modal.config.on_cell_tap(modal.config.item_at(1))
    H.eq(opened_file, "/books/a.epub"); flush(); H.eq(opened, 1)
end)
H.test("changed scope clears partial results and reports stale work rather than complete-looking matches", function()
    reset()
    local modal = require("core/orbitui_search").embeddedTag(tag)
    flush(1); H.eq(modal.config.item_count(), 1)
    roots = { "/new" }; flush()
    H.eq(modal.config.item_count(), 0)
    H.eq(modal.config.intro, "Library folders changed. Refresh and try again.")
end)
H.test("progress snapshots do not alias worker paths and updates are throttled", function()
    reset(); cache_cost = .009
    for i = 1, 80 do add("/books/z" .. i .. ".epub", opf('[]')) end
    local last, calls, result
    Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag, on_progress = function(body)
        if last then assert(elapsed - last >= .25) end
        last, calls = elapsed, (calls or 0) + 1
        body.paths[1] = "REMOTE://must-not-poison-worker"
    end }, function() return true end, function(body) result = body end)
    flush(); assert(calls > 1 and calls < 10)
    H.eq(result.paths[1], "/books/a.epub"); H.eq(result.complete, true)
    H.eq(result.scanned, 83); H.eq(result.total, 83)
end)
H.test("the clicked EPUB is checked first without narrowing or duplicating the all-profile search", function()
    reset()
    add("/outside/clicked.epub", opf('["Åland & 日本語"]'))
    local first, result
    Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag, origin = "/outside/clicked.epub",
        on_progress = function(body) first = first or body.paths[1] end }, function() return true end,
        function(body) result = body end)
    flush(1); H.eq(first, "/outside/clicked.epub"); flush()
    H.eq(#result.paths, 3); H.eq(opened, 4)
end)
H.test("aggregate-index hits avoid per-file disk reads; changed and failed files still use the EPUB provider", function()
    reset()
    local original = Integration.openEmbeddedTagIndex
    local rows, commits, saves = {}, 0, 0
    Integration.openEmbeddedTagIndex = function()
        local staged = {}
        return { prefetch = function(list, first, query)
            local out = {}
            for i = first, math.min(first + 127, #list) do
                local row = rows[list[i]]
                if row then
                    local match = false; for _, value in ipairs(row.tags) do if value == query then match = true end end
                    out[list[i]] = { stamp = row.stamp, matches = match }
                end
            end
            return out
        end, put = function(file, stamp, tags) staged[file] = { stamp = stamp, tags = tags }; saves = saves + 1 end,
        flush = function() for file, row in pairs(staged) do rows[file] = row end; staged = {}; commits = commits + 1; return true end,
        close = function() for file, row in pairs(staged) do rows[file] = row end; commits = commits + 1 end }
    end
    local result
    local function run()
        Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag }, function() return true end,
            function(body) result = body end); flush()
    end
    run(); H.eq(saves, 3); H.eq(#result.paths, 2)
    opened, cache_reads = 0, 0
    run(); H.eq(opened, 0); H.eq(cache_reads, 0); H.eq(#result.paths, 2)
    -- Single-book explicit reread updates a same-stamp indexed entry too.
    local file = "/books/a.epub"
    documents[file][2].data = opf('[]'); documents[file][2].size = #opf('[]')
    Integration.embeddedTags(file, true)
    run(); H.eq(#result.paths, 1)
    files["/profile/a.epub"].change = 2; documents["/profile/a.epub"] = nil
    run(); H.eq(result.skipped, 1); H.eq(#result.paths, 0)
    run(); H.eq(result.skipped, 1) -- not a negative cached success
    assert(commits > 0)
    Integration.openEmbeddedTagIndex = original
end)
H.test("an unavailable index falls back to file tags rather than a successful empty search", function()
    reset()
    local original, closed_index = Integration.openEmbeddedTagIndex, false
    Integration.openEmbeddedTagIndex = function()
        return { prefetch = function() return nil end, close = function() closed_index = true end }
    end
    local result
    Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag }, function() return true end,
        function(body) result = body end)
    flush(); H.eq(closed_index, true); H.eq(#result.paths, 2); H.eq(result.complete, true)
    H.eq(opened, 3)
    Integration.openEmbeddedTagIndex = original
end)
if os.getenv("ORBITUI_NATIVE_UI_MANAGER") then
    H.test("native handleInput polls cancellation between slow archive reads after repaint", function()
        reset(); archive_cost = .3
        local f = assert(io.open(os.getenv("ORBITUI_NATIVE_UI_MANAGER"), "rb"))
        local source = f:read("*a"); f:close()
        local keys = { "_checkTasks", "handleInput", "forceRePaint", "scheduleIn", "nextTick", "_repaint",
            "_task_queue", "_window_stack", "_zeromqs", "event_hook", "processZMQs", "_standbyTransition" }
        local old = {}; for _, key in ipairs(keys) do old[key] = UI[key] end
        local control, body, failure, polls, dirty = nil, nil, nil, 0, false
        local env = { UIManager = UI, time = package.loaded["ui/time"], unpack = unpack or table.unpack,
            logger = { info = function() end }, Input = { waitEvent = function()
                polls = polls + 1; control.cancel()
            end } }
        env.time.us = function(value) return value / 1000000 end
        setmetatable(env, { __index = _G })
        for _, method in ipairs{ "_checkTasks", "handleInput", "forceRePaint" } do
            local code = assert(source:match('(function UIManager:' .. method .. '%b().-\nend)'))
            local fn = assert((loadstring or load)(code))
            if setfenv then setfenv(fn, env) else fn = assert(load(code, "native UIManager", "t", env)) end
            fn()
        end
        UI._task_queue, UI._window_stack, UI._zeromqs = {}, { {} }, {}
        UI.event_hook = { execute = function() end }
        UI.processZMQs, UI._standbyTransition = function() end, function() end
        UI._repaint = function() if dirty then elapsed = elapsed + .008; dirty = false end end
        UI.scheduleIn = function(self, delay, fn)
            table.insert(self._task_queue, { time = elapsed + delay, action = fn, args = { n = 0 } })
            table.sort(self._task_queue, function(a, b) return a.time > b.time end)
            self._task_queue_dirty = true
        end
        UI.nextTick = function(self, fn) self:scheduleIn(0, fn) end
        control = Integration.embeddedTagRequest(Integration.embeddedTagSession(), { tag = tag,
            on_progress = function() dirty = true end }, function() return true end,
            function(value, err) body, failure = value, err end)
        UI:handleInput()
        H.eq(polls, 1); H.eq(opened, 1); H.eq(failure, "cancelled"); H.eq(body.complete, false)
        for _, key in ipairs(keys) do UI[key] = old[key] end
    end)
end
H.test("native dialog interception preserves tag progress identity, completion and cancellation", function()
    local old_show, old_close = UI.show, UI.close
    local Info, Toast = package.loaded["ui/widget/infomessage"], H.widget()
    local names = { "features/dialogs/sui_native_sheets", "features/dialogs/sui_native_inputs", "engines/sui_toast", "logger" }
    local previous = {}; for _, name in ipairs(names) do previous[name] = package.loaded[name] end
    package.loaded[names[1]] = { canReplace = function() return true end }
    package.loaded[names[2]] = { eligible = function() return false end }
    package.loaded[names[3]] = Toast
    package.loaded.logger = { warn = function() error("unexpected native widget fallback") end }
    local Native = H.componentModule(root, "features/dialogs/sui_native_widgets")
    UI.show = function(self, w) if not Native.interceptShow(w) then old_show(self, w) end end
    UI.close = function(self, w) if not Native.interceptClose(w) then old_close(self, w) end end
    -- Ordinary notices still use the facade; only explicit native ownership opts out.
    UI:show(Info:new{ text = "ordinary notice" }); H.eq(getmetatable(last_widget), Toast)
    for _, cancel in ipairs({ false, true }) do
        reset()
        local body, failure
        Integration.embeddedTagRequest(Integration.embeddedTagSession(), { file = "/books/a.epub" },
            function() return true end, function(value, err) body, failure = value, err end)
        H.eq(getmetatable(last_widget), Info); H.eq(last_widget.sui_native, true)
        if cancel then last_widget.dismiss_callback() end
        flush()
        if cancel then H.eq(body, nil); H.eq(failure, "cancelled"); H.eq(opened, 0)
        else H.eq(body.tags[1], tag); H.eq(opened, 1); H.eq(failure, nil) end
        H.eq(last_widget.shown, false)
    end
    UI.show, UI.close = old_show, old_close
    for _, name in ipairs(names) do package.loaded[name] = previous[name] end
end)
H.test("all embedded-tag strings have Swedish translations while literal tags stay unchanged", function()
    local old = G_reader_settings
    G_reader_settings = { readSetting = function(_, key) return key == "language" and "sv" end }
    local _ = require("core/orbitui_i18n")
    H.eq(_("EPUB tags (offline)"), "EPUB-taggar (offline)")
    H.eq(_("Read EPUB tags"), "Läs EPUB-taggar"); H.eq(_(tag), tag)
    H.eq(_("Reread all EPUB tags…"), "Läs om alla EPUB-taggar…")
    H.eq(_("Stop search"), "Stoppa sökning")
    G_reader_settings = old
end)
-- Optional supplement uses the unmodified native KOReader archive reader and
-- a real ZIP/JSON decoder; ordinary CI cases above remain dependency-free.
if os.getenv("ORBITUI_NATIVE_EPUB_ZIP") then
    H.test("native libarchive reads real EPUB bytes and JSON with no document engine or BookOrbit", function()
        reset()
        local file = os.getenv("ORBITUI_NATIVE_EPUB_ZIP")
        local ffi = require("ffi")
        ffi.cdef[[typedef long time_t; void *malloc(size_t); void free(void *);]]
        ffi.loadlib = function(name, version) return ffi.load(jit.os == "OSX" and name or ("lib" .. name .. ".so." .. version)) end
        package.loaded["ffi/posix_h"] = true
        package.loaded["ffi/archiver"] = nil
        package.path = assert(os.getenv("ORBITUI_NATIVE_ARCHIVE_DIR")) .. "/?.lua;" .. package.path
        package.loaded.rapidjson = require("cjson")
        local handle = assert(io.open(file, "rb"))
        files[file] = { mode = "file", modification = 1, change = 1, size = handle:seek("end") }; handle:close()
        local tags = assert(Integration.embeddedTags(file, true))
        H.eq(#tags, 2); H.eq(tags[1], tag); H.eq(tags[2], 'Quote " and comma, preserved')
    end)
end
H.finish()
