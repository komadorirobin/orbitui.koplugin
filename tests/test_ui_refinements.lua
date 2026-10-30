local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;" .. root .. "/components/bookshelf/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
package.loaded.logger = { warn = function() end, dbg = function() end }
local saved, shown, writes = {}, {}, 0
package.loaded["infra/sui_store"] = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value; writes = writes + 1 end,
}
local UI = { show = function(_, widget) shown[#shown + 1] = widget end,
    close = function(_, widget) widget._closed = true end, setDirty = function() end }
package.loaded["ui/uimanager"] = UI
local Search = require("core/orbitui_search")
H.test("forgiving matching ranks exact Swedish spelling before accent folding and typos", function()
    local match = Search.matcher("Räven", true)
    H.eq(match({ title = "Räven" }), 0)
    H.eq(match({ title = "Raven" }), 100)
    H.eq(match({ title = "Ravven" }), 201)
    H.eq(match({ title = "Unrelated" }), nil)
    H.eq(Search.matcher("räven", false)({ title = "raven" }), nil)
end)
H.test("typos, transpositions, prefixes, multi-word names and punctuation work", function()
    for _, query in ipairs({ "charlote bronte", "charlotte bront", "charlotte brontë" }) do
        assert(Search.matcher(query, true)({ author = "Charlotte Brontë" }) ~= nil, query)
    end
    assert(Search.matcher("tolkein hobit", true)({ title = "The Hobbit", author = "J. R. R. Tolkien" }))
    assert(Search.matcher("obrien", true)({ author = "O’Brien" }))
    assert(Search.matcher("garcia", true)({ author = "García" }))
    H.eq(Search.matcher("hp", true)({ title = "hq" }), nil, "short words stay exact")
    H.eq(Search.normalize("日本語 文字 ’"), "日本語 文字 ", "UTF-8 must not be stripped bytewise")
end)
H.test("matching is read-only and keeps excluded genres out", function()
    local book = { title = "Book", genres = { "Fantasy" } }
    H.eq(Search.matcher("fantasy", true)(book, nil, true), nil)
    H.eq(Search.matcher("fantasy", true)(book), 0)
    H.eq(book.search_key, nil); H.eq(book.genres[1], "Fantasy")
    local original = { { filepath = "/r", title = "Raven" }, { filepath = "/a", title = "Räven" } }
    Search.sortBooks(original, "relevance", "Räven", { [original[1]] = 100, [original[2]] = 0 })
    H.eq(original[1].filepath, "/a")
end)

local function compile(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "native source", "t", env))()
end
H.test("actual native repository matcher runs before its cap and leaves standalone rules intact", function()
    local file = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_book_repository.lua"))
    local source = file:read("*a"); file:close()
    local body = assert(source:match("function Repo.searchBooks%(query, limit, scope, opts%)\n(.-)\nend\n"))
    local books = { ["/a"] = { filepath = "/a", title = "Other" },
        ["/b"] = { filepath = "/b", title = "Charlotte", author = "Charlotte Brontë" } }
    local env = { HomeDir = { get = function() return "/" end },
        BookshelfSettings = { read = function() return 3 end },
        candidatesForScope = function(_, _, scope) H.eq(scope, "restricted"); return { { fp = "/a" }, { fp = "/b" } } end,
        _searchIncludesGenres = function() return false end,
        _getLightMetaCache = function() return books end, _lightMetaForFp = function(cache, path) return cache[path] end,
        _searchMatches = function(book, words) return book.title:lower():find(words[1], 1, true) end }
    local native = compile("return function(query, limit, scope, opts)\n" .. body .. "\nend", env)
    local match = Search.matcher("charlote bronte", true)
    local result = native("charlote bronte", 1, "restricted", {
        match_book = function(book, words, skip) H.eq(skip, true); return match(book, words, skip) ~= nil end })
    H.eq(#result, 1); H.eq(result[1], books["/b"])
    H.eq(#native("charlote", nil, "restricted"), 0)
end)

local Sort = require("adapters/orbitui_shelf_sort")
local ref = { profile = "prose", chip = "fiction", drill = { kind = "series", id = "One" } }
H.test("per-place preferences are profile/chip/group-qualified and never mutate sibling entries", function()
    local other = { profile = "manga", chip = "fiction", drill = ref.drill }
    assert(Sort.viewKey(ref) ~= Sort.viewKey(other))
    assert(Sort.viewKey(ref) ~= Sort.viewKey({ profile = "prose", chip = "fiction", drill = { kind = "author", id = "One" } }))
    assert(Sort.saveView(ref, "view", "compact_two")); assert(Sort.saveView(ref, "filter", "barely"))
    H.eq(Sort.viewPrefs(other).view, nil); H.eq(Sort.viewPrefs(ref).view, "compact_two")
    local copy = Sort.viewPrefs(ref); copy.view = "list"
    H.eq(Sort.viewPrefs(ref).view, "compact_two")
    assert(not Sort.saveView(ref, "sort", "unknown"))
    saved.orbitui_browse_views.items[Sort.viewKey(ref)].future = "keep"
    saved.orbitui_browse_views.future = "keep top-level"
    saved.orbitui_browse_views.items.other = "future place format"
    assert(Sort.saveView(ref, "view", "covers"))
    H.eq(saved.orbitui_browse_views.items[Sort.viewKey(ref)].future, "keep")
    H.eq(saved.orbitui_browse_views.future, "keep top-level")
    H.eq(saved.orbitui_browse_views.items.other, "future place format")
    saved.orbitui_browse_views = { schema = 99, items = {} }
    assert(not Sort.saveView(ref, "view", "list")); H.eq(saved.orbitui_browse_views.schema, 99)
    saved.orbitui_browse_views = nil
end)
local books = {
    { filepath = "/a", title = "A", book_pct = 0, status = "unread" },
    { filepath = "/b", title = "B", book_pct = .01, status = "reading" },
    { filepath = "/c", title = "C", book_pct = .05, status = "reading" },
    { filepath = "/d", title = "D", book_pct = .5, status = "reading" },
    { filepath = "/e", title = "E", book_pct = .4, status = "complete" },
}
local captures, resolved = 0, true
local Query = { capture = function() captures = captures + 1; return ref end,
    resolve = function() if resolved then return { source = { kind = "single_series" } } end end,
    books = function() if resolved then return books end; return {}, "missing" end }
package.loaded["core/orbitui_shelf_query"] = Query
local hydrated, sorts, progress_reads = {}, {}, 0
package.loaded["lib/bookshelf_book_repository"] = {
    readProgress = function() progress_reads = progress_reads + 1; return 0, nil end,
    buildBookMeta = function(file, opts) hydrated[#hydrated + 1] = { file = file, opts = opts }; return { filepath = file } end,
}
package.loaded["lib/bookshelf_sort_engine"] = { sort = function(records, priority)
    sorts[#sorts + 1] = priority; table.sort(records, function(a, b) return a.title < b.title end)
end }
H.test("filters are local derived classifications, with explicit 5-percent and finished rules", function()
    local selected, err, counts = Sort.browseBooks(ref, { filter = "barely" }, true)
    H.eq(err, nil); H.eq(#selected, 2); H.eq(selected[1], books[2]); H.eq(counts.all, 5)
    H.eq(counts.unread, 1); H.eq(counts.reading, 1); H.eq(counts.barely, 2); H.eq(counts.finished, 1)
    H.eq(books[2].status, "reading"); H.eq(progress_reads, 0)
    H.eq(#hydrated, 0)
end)
H.test("sorting-only avoids all progress reads and uses the native author/series comparators", function()
    Sort.browseBooks(ref, { sort = "author" })
    H.eq(sorts[#sorts][1].key, "author_surname")
    Sort.browseBooks(ref, { sort = "series" })
    H.eq(sorts[#sorts][1].key, "series_combined")
    H.eq(progress_reads, 0); H.eq(books[1].title, "A")
end)
local Widget = { _fetchChipItems = function() return "native" end, _viewMode = function(self)
    return (self.orbitui_view_mode and self:orbitui_view_mode()) or "spines"
end,
    _listLines = function() return "native-lines" end, _chipListValue = function() return 7 end,
    _openSortMenu = function() return "native-sort" end,
    _pageCounterText = function() return "1–5" end, _simpleUIPageLabel = function() return "1/2" end }
Sort.browsing(Widget)
local view = setmetatable({ _cursor = 2, _drilldown_path = {}, chip = "fiction", _rebuild = function(self) self.rebuilt = true end,
    _viewSize = function() return 2 end, _isSpineMode = function() return false end }, { __index = Widget })
H.test("unset views stay native and compact layout overrides remain per place", function()
    H.eq(view:_fetchChipItems(10), "native"); H.eq(view:_viewMode(), "spines")
    Sort.saveView(ref, "view", "compact_two")
    H.eq(view:_viewMode(), "list"); H.eq(view:_chipListValue("list_columns"), 2)
    H.eq(#view:_listLines().lines, 2); H.eq(view:_chipListValue("list_rows"), 7)
    H.eq(view:_pageCounterText(), "1–5 ▾")
    H.eq(view:_simpleUIPageLabel(), "1/2 ▾")
end)
H.test("filtering precedes pagination and whole-list queries never hydrate covers", function()
    Sort.saveView(ref, "filter", "barely")
    local selected, total = view:_fetchChipItems(10)
    H.eq(total, 2); H.eq(#selected, 1); H.eq(selected[1].filepath, "/c")
    H.eq(#hydrated, 1); H.eq(hydrated[1].opts.lazy_cover, true)
    selected = view:_fetchChipItems(1, true)
    H.eq(#selected, 1); H.eq(#hydrated, 1)
    resolved = false
    H.eq(view:_fetchChipItems(10), "native", "missing scope retains native failure handling")
    resolved = true
end)
package.loaded["lib/bookshelf_menu_host"] = { show = function(opts)
    opts._stack = { { title = opts.title } }; return opts
end, close = function(host) host._closed = true end }
package.loaded["core/orbitui_context"].notify = function() end
H.test("browse controls show counts and stale callbacks cannot change another destination", function()
    local host = Sort.browseControls(view, function() end)
    H.eq(host.title, "Sort, filter & view")
    local row = host.item_table[3].sub_item_table[2]
    assert(row.text:find("Unread", 1, true))
    local before = writes
    UI._simpleui_navigation_generation = 5
    row.callback(); H.eq(writes, before)
    UI._simpleui_navigation_generation = nil
    row.callback(); H.eq(Sort.viewPrefs(ref).filter, "unread"); H.eq(view.rebuilt, true)
    before = writes; row.callback(); H.eq(writes, before)
end)
H.test("relative dates handle invalid, future, yesterday and year rollover without writes", function()
    local now = os.time{ year = 2026, month = 1, day = 1, hour = 12 }
    H.eq(Sort.relativeDate(0, now), ""); H.eq(Sort.relativeDate(now + 1, now), "")
    H.eq(Sort.relativeDate(0/0, now), "")
    H.eq(Sort.relativeDate(now - 7200, now), "2h ago")
    H.eq(Sort.relativeDate(now - 86400, now), "Yesterday")
    H.eq(Sort.relativeDate(now - 86400 * 3, now), "2025-12-29")
    local midnight = os.time{ year = 2026, month = 1, day = 1, hour = 0, min = 10 }
    H.eq(Sort.relativeDate(midnight - 1200, midnight), "Yesterday")
end)

local Panel = require("adapters/orbitui_book_panel")
package.loaded["libs/libkoreader-lfs"] = { attributes = function() return { size = 1024, modification = 1 } end }
package.loaded["lib/bookshelf_tokens"] = { formatFileSize = function() return "1 KiB" end }
H.test("book information is lazy escaped local data, with no metadata or network writes", function()
    local text = Panel.information{ filepath = '/books/<&>.epub', lang = "sv", page_count = 10 }
    assert(text:find("&lt;&amp;&gt;.epub", 1, true)); assert(text:find("1 KiB", 1, true))
    assert(not text:find("<script>", 1, true))
end)
H.test("book detail enhancement preserves native active tab, callbacks and header owner", function()
    local self = { _headedHtmlBody = function(_, _, _, _, _, html) return html end,
        _buildBookMenuHeader = function(_, _, _, _, _, opts) return opts end }
    Panel.widget(self)
    local opened = function() end
    local args = { tabs = { { id = "description" }, { id = "edit" }, { id = "cover" } }, active_tab = 2, on_open = opened }
    self:orbitui_detail_args({ filepath = "/book.epub" }, args)
    H.eq(args.tabs[1].id, "description"); H.eq(args.tabs[2].id, "information")
    H.eq(args.tabs[args.active_tab].id, "edit")
    H.eq(args.on_open, opened); H.eq(args.open_text, "Read now")
    H.eq(args.header_builder(400).summary_text, "0% read")
end)
H.test("actual native menu host exposes breadcrumb ancestors and preserves page/close ownership", function()
    package.loaded["ui/widget/menu"] = { new = function(_, opts)
        opts.paths, opts.page, opts.page_num = {}, 1, 10
        opts.switchItemTable = function(self, title, rows) self.title, self.item_table = title, rows end
        opts.onGotoPage = function(self, page) self.page = page end
        return opts
    end }
    package.loaded.device = { screen = { getWidth = function() return 600 end, getHeight = function() return 800 end } }
    package.loaded["lib/bookshelf_i18n"] = { gettext = require("core/orbitui_i18n") }
    local Settings = require("adapters/orbitui_settings")
    local Host = dofile(root .. "/components/bookshelf/lib/bookshelf_menu_host.lua")
    local host = Host.show{ title = "OrbitUI settings / Book panel at the top", item_table = {},
        level_header = Settings.locationHeader("OrbitUI settings / Book panel at the top", "bookshelf", { profile = "prose" }) }
    assert(host._menu.item_table[1].text:find("You are here", 1, true))
    host._menu.page = 3
    host:_push("Advanced", {}, {})
    local location = host._menu.item_table[1]
    assert(location.text:find("Bookshelf", 1, true)); assert(location.text:find("Advanced", 1, true))
    location.callback() -- choose an ancestor, not merely Back one level
    H.eq(#host._stack, 3)
    local panel_row
    for _, row in ipairs(host._menu.item_table) do
        if row.text == "Book panel at the top" then panel_row = row end
    end
    assert(panel_row); panel_row.callback()
    H.eq(#host._stack, 1); H.eq(host._menu.page, 3)
    Host.close(host)
    local before = #host._stack; panel_row.callback(); H.eq(#host._stack, before)
end)
H.test("native cover-preview pin outranks per-place list preferences", function()
    local file = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_widget.lua"))
    local source = file:read("*a"); file:close()
    local body = assert(source:match("function BookshelfWidget:_viewMode%(%)\n(.-)\nend\n"))
    local env = { _covers_pin = 1, ViewMode = { COVERS = "covers" } }
    local native = compile("return function(self)\n" .. body .. "\nend", env)
    local object = { orbitui_view_mode = function() return "list" end }
    H.eq(native(object), "covers")
    env._covers_pin = 0; H.eq(native(object), "list")
end)
H.test("quick changes expire only native listing caches, not covers or persisted shelf defaults", function()
    local expired = 0
    view._expireSpineFetch = function() expired = expired + 1 end
    view._draft_items_cache = { stale = true }
    local host = Sort.browseControls(view, function() end)
    host.item_table[4].sub_item_table[1].callback()
    H.eq(expired, 1); H.eq(view._draft_items_cache, nil)
    H.eq(Sort.viewPrefs(ref).view, "covers")
end)
H.test("actual native summary header keeps title, author and progress without stat/history detail IO", function()
    local file = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_widget.lua"))
    local source = file:read("*a"); file:close()
    local body = assert(source:match("function BookshelfWidget:_buildBookMenuHeader%(book, override_width, pill_specs, bookmark_action, opts%)\n(.-)\nend\n"))
    local text, W = {}, H.widget()
    function W:init() if self.text then text[#text + 1] = self.text; assert(self.width > 0) end end
    function W:getSize()
        if self.text then return { w = self.width, h = 20 } end
        local width, height = 0, 0
        for _, child in ipairs(self) do local size = child:getSize(); width = math.max(width, size.w); height = height + size.h end
        return { w = width, h = height }
    end
    local deps = {}
    for _, name in ipairs({ "ui/font", "ui/widget/imagewidget", "ui/widget/horizontalgroup", "ui/widget/horizontalspan",
            "ui/widget/verticalgroup", "ui/widget/verticalspan", "ui/widget/textboxwidget", "lib/bookshelf_colour_text" }) do deps[name] = W end
    deps["libs/libkoreader-lfs"] = { attributes = function() error("summary must not stat technical details") end }
    deps.readhistory = { hist = setmetatable({}, { __index = function() error("no history detail IO") end }) }
    local native = compile("return function(self, book, override_width, pill_specs, bookmark_action, opts)\n" .. body .. "\nend", {
        require = function(name) assert(deps[name], name); return deps[name] end,
        Screen = { getWidth = function() return 600 end, getHeight = function() return 800 end,
            scaleBySize = function(_, value) return value end },
        Space = { padding = { fullscreen = 10, default = 5, large = 10 } },
        BFont = { getFace = function() return {} end }, FrameContainer = W,
        Repo = { buildBookMeta = function() return {} end }, _headerThumbBB = function() return nil, false end,
    })
    local header = native({ _bookGap = function() return 8 end },
        { filepath = "/books/a.epub", title = "Title", author = "Author" }, 400, nil, nil,
        { rich = true, summary_text = "42% read" })
    assert(header); H.eq(#text, 3); H.eq(text[1], "Title"); H.eq(text[3], "42% read")
end)
H.test("owned new controls and format placeholders have Swedish and English labels", function()
    local translate = require("core/orbitui_i18n")
    for _, label in ipairs({ "Typo-tolerant search", "Sort, filter & view", "Barely started", "In progress",
            "Compact list", "Compact list · 2 columns", "You are here", "Book details", "Read now",
            "Use shelf defaults here", "Shelf default", "Book spines", "Today", "Yesterday" }) do
        H.eq(translate(label, "en"), label)
        assert(translate(label, "sv") ~= label, label)
    end
end)
H.finish()
