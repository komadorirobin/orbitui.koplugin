local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;" .. root .. "/components/bookshelf/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local saved, shown, queue, disk, files = {}, {}, {}, {}, {}
local UI = { _simpleui_navigation_generation = 1,
    show = function(_, w) w.shown = true; shown[#shown + 1] = w end,
    close = function(_, w) w.shown = false end, isWidgetShown = function(_, w) return w.shown end,
    nextTick = function(_, fn) queue[#queue + 1] = fn end, setDirty = function() end }
package.loaded["ui/uimanager"] = UI
package.loaded["lib/bookshelf_settings_store"] = { read = function(key) return saved[key] end,
    save = function(key, value) saved[key] = value end, flush = function() end, wasPresent = function() return false end }
G_reader_settings = { readSetting = function(_, key) if key == "home_dir" then return "/books" end end }
local P = dofile(root .. "/components/bookshelf/lib/bookshelf_profiles.lua")
package.loaded["lib/bookshelf_profiles"] = P
local Libraries = require("adapters/orbitui_libraries"); Libraries.profiles(P)
Libraries.changed = function() end
P.add("Manga", "/manga")
local Menu = { show = function(opts)
    opts._shim = { updateItems = function() end }; shown[#shown + 1] = opts; return opts
end, close = function(host) host._closed = true end }
package.loaded["lib/bookshelf_menu_host"] = Menu
local Input = H.widget()
function Input:getInputText() return self.input end
function Input:onShowKeyboard() end
package.loaded["ui/widget/inputdialog"] = Input
package.loaded["core/orbitui_context"] = { notify = function() end }
package.loaded["lib/bookshelf_keyed_cache"] = { new = function() return {
    read = function(key) return disk[key] end, write = function(key, value) disk[key] = value; return true end } end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(file) return files[file] end }
local I = require("adapters/orbitui_integrations")
local Q = require("core/orbitui_shelf_query")
local Settings = require("adapters/orbitui_library_settings")
local Model = require("core/orbitui_libraries")
local tag, second = "Åland & 日本語", "History, exact"
local function find(rows, text)
    for _, row in ipairs(rows) do if row.text == text then return row end end
    error("Missing: " .. text)
end
local function rows(host) return host.item_table end
local function submit(value)
    local input = shown[#shown]; input.input = value; input.buttons[1][2].callback()
end
local function source(mode, scope)
    return { kind = Q.tag_kind, version = 1, profile = "library", scope = scope or "library",
        rule = { version = 1, mode = mode or "all", tags = { tag } } }
end
local function stamp(file, change)
    files[file] = { mode = "file", modification = 1, change = change or 1, size = 10 }
    return "1:" .. (change or 1) .. ":10"
end
H.test("tag-chip drafts support combinations/scope/name, write only on Save and keep stable IDs", function()
    local before = #P.get("library").chips
    local host = Settings.tagChip{ tag = tag, tags = { tag, second }, profile = "library" }
    find(rows(host), "Name: " .. tag).callback(); submit("My history")
    find(find(rows(host), "Add tag…").sub_item_table, second).callback()
    find(find(rows(host), "Match tags: All selected tags (AND)").sub_item_table, "At least one tag (OR)").callback()
    find(find(rows(host), "Search scope: Selected library").sub_item_table, "All local libraries").callback()
    H.eq(#P.get("library").chips, before)
    find(rows(host), "Save chip").callback()
    local chip = P.chip(P.get("library"), "shelf_1")
    H.eq(chip.label, "My history"); H.eq(chip.source.scope, "all"); H.eq(chip.source.rule.mode, "any")
    H.eq(#chip.source.rule.tags, 2); H.eq(chip.kind, Q.tag_kind); H.eq(host._closed, true)
    host = Settings.tagChip{ profile = "library", id = "shelf_1" }
    find(rows(host), "Name: My history").callback(); submit("Changed")
    find(rows(host), "Save chip").callback()
    H.eq(P.chip(P.get("library"), "shelf_1").label, "Changed"); H.eq(#P.get("library").chips, before + 1)
end)
H.test("Cancel, closed owners and concurrent source edits leave saved chips untouched", function()
    local count = #P.get("library").chips
    local host = Settings.tagChip{ tag = tag, profile = "library" }
    local save = find(rows(host), "Save chip").callback
    find(rows(host), "Cancel").callback(); save(); H.eq(#P.get("library").chips, count)
    host = Settings.tagChip{ profile = "library", id = "shelf_1" }
    save = find(rows(host), "Save chip").callback
    P.edit("library", function(profile) P.chip(profile, "shelf_1").source.rule.tags = { "Replacement" } end)
    save(); H.eq(P.chip(P.get("library"), "shelf_1").source.rule.tags[1], "Replacement")
    host = Settings.tagChip{ tag = tag, profile = "library" }
    save = find(rows(host), "Save chip").callback; UI._simpleui_navigation_generation = 2; save()
    H.eq(#P.get("library").chips, count)
end)
H.test("concurrent renames retire old editors while unrelated future source fields survive Save", function()
    local host = Settings.tagChip{ profile = "library", id = "shelf_1" }
    local save = find(rows(host), "Save chip").callback
    P.edit("library", function(profile) P.chip(profile, "shelf_1").label = "Newer name" end)
    save(); H.eq(P.chip(P.get("library"), "shelf_1").label, "Newer name")
    host = Settings.tagChip{ profile = "library", id = "shelf_1" }
    P.edit("library", function(profile) P.chip(profile, "shelf_1").source.future_field = { keep = true } end)
    find(rows(host), "Save chip").callback()
    H.eq(P.chip(P.get("library"), "shelf_1").source.future_field.keep, true)
end)
H.test("extra exact tags preserve punctuation/whitespace, deduplicate and cannot remove the last tag", function()
    local host = Settings.tagChip{ tag = tag, profile = "library" }
    local action = find(find(rows(host), "Add tag…").sub_item_table, "Enter exact tag name…")
    action.callback(); submit(" Space, \"quoted\" ")
    assert(find(rows(host), 'Remove tag:  Space, "quoted" '))
    action.callback(); submit("\n"); H.eq(#P.get("library").chips, 4)
    find(rows(host), 'Remove tag:  Space, "quoted" ').callback()
    H.eq(find(rows(host), "Remove tag: " .. tag).enabled_func(), false)
    find(rows(host), "Cancel").callback()
end)
H.test("rendering reads only bounded saved matches and drops changed/deleted/out-of-scope files", function()
    local s = source()
    local result = { paths = { "/books/a.epub", "/books/b.epub", "/private/a.epub", "/books/a.epub" }, stamps = {} }
    for _, file in ipairs(result.paths) do result.stamps[file] = stamp(file) end
    Q.tagResult(s, result)
    local paths = Q.tagPaths(s); H.eq(#paths, 2)
    stamp("/books/a.epub", 2); files["/books/b.epub"] = nil; H.eq(#Q.tagPaths(s), 0)
    local original = P.get("library").roots[1]
    P.relocateRoot("library", original, "/new")
    H.eq(#Q.tagPaths(s), 0)
    P.relocateRoot("library", "/new", original)
    s.version = 99; H.eq(#Q.tagPaths(s), 0)
end)
H.test("native source delegation preserves caller filtering/sorting/page and explicit local/all scope", function()
    local native_calls, captured = 0
    local repo = { getBySource = function(...) native_calls = native_calls + 1; captured = { ... }; return { "native" }, 7 end }
    Q.tagRepository(repo)
    local s = source(); Q.tagResult(s, { paths = { "/books/c.epub" }, stamps = { ["/books/c.epub"] = stamp("/books/c.epub") } })
    local filter, sort, options = {}, {{ key = "author" }}, { lazy_cover = true }
    local got, total = repo.getBySource(s, filter, sort, 14, 7, nil, options)
    H.eq(got[1], "native"); H.eq(total, 7); H.eq(captured[1].kind, "bookorbit_want")
    H.eq(captured[1].paths[1], "/books/c.epub"); H.eq(captured[2], filter); H.eq(captured[3], sort)
    H.eq(captured[4], 14); H.eq(captured[6].roots[1], "/books"); H.eq(captured[7], options)
    s.scope = "all"; repo.getBySource(s, nil, nil, 0, 8, { roots = { "/wrong" } }, options)
    H.eq(captured[6], nil); H.eq(captured[7], options)
    s.version = 99; local calls = native_calls; H.eq(#repo.getBySource(s), 0); H.eq(native_calls, calls)
    local normal = { kind = "folder" }; repo.getBySource(normal); H.eq(captured[1], normal)
end)
H.test("automatic checks are cache-only, bounded by TTL and retire on navigation", function()
    local request, active
    local original = I.embeddedTagRequest
    I.embeddedTagRequest = function(session, task, current, done) request = task; active = current; return { done = done } end
    local s = source("any")
    Q.tagCheck(s, function() return true end); H.eq(request.cache_only, true); H.eq(request.profile, "library")
    H.eq(Q.tagCheck(s, function() return true end), nil)
    H.eq(active(), true)
    P.relocateRoot("library", "/books", "/other")
    H.eq(active(), false)
    P.relocateRoot("library", "/other", "/books")
    I.embeddedTagRequest = original
end)
H.test("visible chip hooks defer work, keep honest counters and guard reader/scope transitions", function()
    local fetches, checks, opened, request = 0, 0, 0
    local s = source()
    local old = Q.tagCheck
    Q.tagCheck = function(_, current) checks = checks + 1; H.eq(current(), true) end
    local widget = { shown = true, _drilldown_path = {}, profile = {},
        _profileChip = function() return { source = s } end,
        _fetchChipItems = function() fetches = fetches + 1; return { "native" }, 10 end,
        _pageCounterText = function() return "1 of 2" end,
        _refreshLibrary = function() error("must use the explicit tag updater") end,
        _launchReader = function() opened = opened + 1 end,
    }
    Q.tagWidget(widget)
    local got, total = widget:_fetchChipItems(14)
    H.eq(got[1], "native"); H.eq(total, 10); H.eq(checks, 0); H.eq(fetches, 1)
    H.eq(widget:_pageCounterText(), "Indexed · 1 of 2")
    table.remove(queue, 1)(); H.eq(checks, 1)
    widget:_fetchChipItems(14); widget._closed = true; table.remove(queue, 1)(); H.eq(checks, 1)
    widget._closed = false; widget._opened_book = true
    package.loaded["apps/reader/readerui"] = { instance = {} }
    package.loaded["lib/bookshelf_reader_park"] = { isParked = function() return true end }
    widget:_fetchChipItems(14); table.remove(queue, 1)(); H.eq(checks, 2)
    package.loaded["lib/bookshelf_reader_park"].isParked = function() return false end
    widget:_fetchChipItems(14); table.remove(queue, 1)(); H.eq(checks, 2)
    package.loaded["apps/reader/readerui"], package.loaded["lib/bookshelf_reader_park"] = nil, nil
    local original = I.embeddedTags
    Q.tagResult(s, { paths = { "/books/a.epub" }, stamps = { ["/books/a.epub"] = stamp("/books/a.epub") } })
    I.embeddedTags = function() return { "wrong tag" } end
    widget:_launchReader("/books/a.epub"); H.eq(opened, 0)
    widget:_launchReader("/books/global-search.epub"); H.eq(opened, 1)
    I.embeddedTags = function() return { tag } end
    widget:_launchReader("/books/a.epub"); H.eq(opened, 2)
    local original_refresh = Q.tagRefresh
    Q.tagRefresh = function(_, opts) request = opts end
    widget:_refreshLibrary(); H.eq(request.is_current(), true)
    s.rule.tags = { "Changed rule" }; H.eq(request.is_current(), false)
    Q.tagRefresh, I.embeddedTags, Q.tagCheck = original_refresh, original, old
end)
H.test("registered source is local-only and hidden from generic source creation", function()
    local Sources = dofile(root .. "/components/bookshelf/lib/bookshelf_sources.lua")
    Q.tagSources(Sources)
    local spec = assert(Sources.get(Q.tag_kind))
    H.eq(spec.picker, false); H.eq(spec.library, false); H.eq(spec.remote_prefix, nil)
    H.eq(Sources.isAvailable(Q.tag_kind), true)
    local s = source("any", "all")
    Q.tagResult(s, { paths = { "/manga/m.epub" }, stamps = { ["/manga/m.epub"] = stamp("/manga/m.epub") } })
    H.eq(Sources.list(Q.tag_kind, s)[1].filepath, "/manga/m.epub")
end)
H.test("tag chips keep shared per-place sorting/views and schedule preview even when sorting bypasses native fetch", function()
    local s = source()
    P.edit("library", function(profile) profile.chips[#profile.chips + 1] = { key = "tag_browse", label = "Tags", source = s } end)
    local prefs = {}
    package.loaded["infra/sui_store"] = { get = function(_, key) return prefs[key] end,
        set = function(_, key, value) prefs[key] = value end }
    local Sort = require("adapters/orbitui_shelf_sort")
    local native_fetch, checks = 0, 0
    local widget = { shown = true, profile_key = "library", chip = "tag_browse", profile = P.get("library"),
        _drilldown_path = {}, _cursor = 1,
        _profileChip = function(self) return P.chip(self.profile, self.chip) end,
        _fetchChipItems = function() native_fetch = native_fetch + 1; return {} end,
        _pageCounterText = function() return "1 of 1" end,
        _viewMode = function() return "covers" end, _listLines = function() return {} end,
        _chipListValue = function() return 1 end, _refreshLibrary = function() end, _launchReader = function() end,
        _isSpineMode = function() return true end, _viewSize = function() return 14 end,
    }
    local ref = Q.capture(widget)
    H.eq(Sort.saveView(ref, "sort", "title"), true)
    H.eq(Sort.saveView(ref, "view", "compact"), true)
    local original_browse, original_check = Sort.browseBooks, Q.tagCheck
    Sort.browseBooks = function(_, view) H.eq(view.sort, "title"); return {{ filepath = "/books/c.epub" }} end
    Q.tagCheck = function() checks = checks + 1 end
    package.loaded["lib/bookshelf_book_repository"] = {}
    Sort.browsing(widget); Q.tagWidget(widget) -- production wrapper order
    H.eq(widget:orbitui_view_mode(), "list")
    local books, count = widget:_fetchChipItems(14)
    H.eq(books[1].filepath, "/books/c.epub"); H.eq(count, 1); H.eq(native_fetch, 0); H.eq(checks, 0)
    table.remove(queue, 1)(); H.eq(checks, 1)
    assert(widget:_pageCounterText():find("Indexed", 1, true))
    Sort.browseBooks, Q.tagCheck = original_browse, original_check
end)
H.test("the real menu host refreshes scope/match/selected-tag summaries and Cancel writes nothing", function()
    package.loaded["lib/bookshelf_i18n"] = { gettext = require("core/orbitui_i18n") }
    package.loaded.device = { screen = { getWidth = function() return 1080 end, getHeight = function() return 1440 end } }
    local NativeMenu = H.widget()
    function NativeMenu:init() self.paths = {}; self.page = 1; self.page_num = 1 end
    function NativeMenu:switchItemTable(title, items) self.title, self.item_table, self.page = title, items, 1 end
    package.loaded["ui/widget/menu"] = NativeMenu
    local Host = dofile(root .. "/components/bookshelf/lib/bookshelf_menu_host.lua")
    package.loaded["lib/bookshelf_menu_host"] = Host
    local before = #P.get("library").chips
    local host = Settings.tagChip{ tag = tag, tags = { tag, second }, profile = "library" }
    local function mapped(text)
        for _, row in ipairs(host._menu.item_table) do if row._src and row._src.text == text then return row end end
        error("Missing painted editor row: " .. text)
    end
    mapped("Match tags: All selected tags (AND)").callback()
    mapped("At least one tag (OR)").callback(); host:_pop()
    assert(mapped("Match tags: At least one tag (OR)"))
    mapped("Search scope: Selected library").callback()
    mapped("All local libraries").callback(); host:_pop()
    assert(mapped("Search scope: All local libraries"))
    mapped("Add tag…").callback(); mapped(second).callback(); host:_pop()
    assert(mapped("Remove tag: " .. second))
    mapped("Cancel").callback(); H.eq(host._closed, true); H.eq(#P.get("library").chips, before)
    package.loaded["lib/bookshelf_menu_host"] = Menu
end)
H.test("new editor labels and notices have Swedish fallbacks without translating literal tags", function()
    G_reader_settings = { readSetting = function(_, key) return key == "language" and "sv" or nil end }
    local _ = require("core/orbitui_i18n")
    for _i, text in ipairs{ "Create tag chip", "Edit tag chip", "Save chip", "Search scope", "Selected library",
            "All local libraries", "All selected tags (AND)", "At least one tag (OR)", "Indexed", "About indexed matches",
            "Update tag matches…", "Enter exact tag name…", "Add tag…", "Remove tag" } do assert(_(text) ~= text, text) end
    H.eq(_(tag), tag)
end)
H.finish()
