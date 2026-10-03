package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Profiles = require("lib/bookshelf_profiles")
local Query = require("core/orbitui_shelf_query")
local Search = require("core/orbitui_search")
local tabs, records, search_records, groups = {}, {}, {}, {}
local call, search_call, next_call
package.loaded["lib/bookshelf_tab_model"] = { getById = function(id) return tabs[id] end }
package.loaded["lib/bookshelf_book_repository"] = {
    getBySource = function(source, filter, sort, offset, limit, scope, opts)
        call = { source = source, filter = filter, sort = sort, scope = scope, opts = opts, limit = limit }
        return records
    end,
    getNextUnreadInSeries = function(limit, offset, scope, opts)
        next_call = { limit = limit, scope = scope, opts = opts }
        return records
    end,
    searchBooks = function(text, limit, scope)
        search_call = { text = text, limit = limit, scope = scope }
        return search_records
    end,
    searchAll = function(text, scope, opts)
        search_call = { text = text, scope = scope, limit = opts.book_limit }
        return { books = search_records, authors = groups }
    end,
}
package.loaded["lib/bookshelf_bookorbit_want_source"] = {
    snapshot = function() return { "/tbr.epub" }, "snapshot-v2" end,
}
package.loaded["lib/bookshelf_sort_engine"] = { sort = function(books, priority)
    H.eq(priority[1].key, "title")
    table.sort(books, function(a, b) return a.title < b.title end)
end }
local ref = { chip = "custom" }
H.test("shelves resolve live filters and sorts instead of copying book lists", function()
    tabs.custom = { label = "A", source = { kind = "collection", id = "TBR" }, filter = { status = "new" } }
    H.eq(Query.resolve(ref).label, "A")
    tabs.custom = { label = "B", source = { kind = "genre", id = "Fantasy" }, filter = { status = "reading" } }
    Query.books(ref)
    H.eq(call.source.kind, "genre")
    H.eq(call.filter.status, "reading")
    H.eq(Query.resolve(ref).label, "B")
end)
H.test("deleted and remote shelves fail closed rather than showing the whole library", function()
    H.eq(select(2, Query.resolve({ chip = "gone" })), "missing")
    tabs.remote = { source = { kind = "opds" } }
    H.eq(select(2, Query.paths({ chip = "remote" })), "remote")
    H.eq(#Query.paths({ chip = "gone" }), 0)
end)
H.test("profile folders use the native roots, filter pipeline and light metadata only", function()
    Query.books({ profile = "comics", chip = "profile_manga" })
    H.eq(call.source.kind, "folder_flat")
    H.eq(call.source.id, Profiles.get("comics").roots[1])
    H.eq(call.scope.roots, Profiles.get("comics").roots)
    H.eq(call.sort, Profiles.folderSortPriority(Profiles.get("comics")))
    H.eq(call.opts.light_only, true)
    H.eq(call.limit, math.huge)
    H.eq(Profiles.chip(Profiles.get("comics"), "profile_manga").kind, "folder")
end)
H.test("next-volume and BookOrbit shelves use the existing local source implementations", function()
    Query.paths({ profile = "comics", chip = "next" })
    H.eq(next_call.opts.light_only, true)
    H.eq(next_call.scope.roots, Profiles.get("comics").roots)
    Query.paths({ profile = "prose", chip = "bookorbit_tbr" })
    H.eq(call.source.paths[1], "/tbr.epub")
    H.eq(call.source.id, "snapshot-v2")
end)
H.test("group flattening deduplicates and preserves within-group sort without mutating source", function()
    tabs.custom.sort_priority = { { key = "author" }, { key = "title" } }
    local members = { { filepath = "/z", title = "Z" }, { filepath = "/a", title = "A" } }
    records = { { books = members, books_meta = members }, { filepath = "/z" }, { filepath = "OPDS://x" } }
    local paths = Query.paths(ref)
    H.eq(#paths, 2); H.eq(paths[1], "/a"); H.eq(paths[2], "/z")
    H.eq(members[1].title, "Z")
end)
H.test("current shelf captures the deepest supported drilldown", function()
    local captured = Query.capture({ profile_key = "comics", chip = "profile_manga",
        _drilldown_path = { { kind = "series", payload = { series_name = "Billy Bat" }, label = "Billy Bat" } } }, nil, true)
    H.eq(Query.resolve(captured).source.kind, "single_series")
    H.eq(Query.resolve(captured).source.id, "Billy Bat")
end)
H.test("current-shelf queries preserve whole groups without changing the source filter", function()
    records = {}
    local filter = tabs.custom.filter
    for _, kind in ipairs{ "series", "author", "genre", "tag" } do
        local widget = { chip = "custom", _drilldown_path = {
            { kind = kind, whole = true, payload = { series_name = "Group" }, label = "Group" },
        } }
        local captured = Query.capture(widget, nil, true)
        H.eq(captured.drill.whole, true)
        Query.books(captured)
        H.eq(call.filter, nil, "book-detail group search must not inherit the chip filter")
        H.eq(tabs.custom.filter, filter, "never erase the underlying shelf filter")
        widget._drilldown_path[1].whole = nil
        captured = Query.capture(widget, nil, true)
        H.eq(captured.drill.whole, nil)
        Query.books(captured)
        H.eq(call.filter, filter, "ordinary shelf groups retain their filter")
    end
    local folder = { chip = "custom", drill = { kind = "folder", id = "/books", whole = true } }
    Query.books(folder)
    H.eq(call.filter, filter, "folder drills keep the shelf filter")
    local scoped = Query.capture({ profile_key = "comics", chip = "profile_manga",
        _drilldown_path = { { kind = "series", whole = true,
            payload = { series_name = "Billy Bat" }, label = "Billy Bat" } } }, nil, true)
    Query.books(scoped)
    H.eq(call.scope.roots, Profiles.get("comics").roots, "whole groups keep the profile scope")
end)
H.test("search filters current-shelf membership before applying the result cap", function()
    records = { { filepath = "/b500" } }
    tabs.custom.sort_priority = nil
    search_records = {}
    for i = 1, 500 do search_records[i] = { filepath = "/b" .. i, title = "Book " .. i } end
    local books, truncated = Search.search("  Book  ", "current", ref)
    H.eq(#books, 1); H.eq(books[1].filepath, "/b500"); H.eq(truncated, false)
    H.eq(search_call.text, "Book"); H.eq(search_call.limit, nil)
end)
H.test("whole-library and profile search share a bounded result presentation", function()
    local books, truncated = Search.search("Book", "all")
    H.eq(#books, 400); H.eq(truncated, true); H.eq(search_call.scope, nil)
    H.eq(search_call.limit, math.huge)
    Search.search("Book", "comics")
    H.eq(search_call.scope.roots, Profiles.get("comics").roots)
    Search.search("Book", "prose")
    H.eq(search_call.scope.roots, Profiles.get("prose").roots)
end)
H.test("author, series and folder result groups remain available", function()
    groups = { { series_name = "Writer" } }
    local books, truncated, err, found_groups = Search.search("Book", "all")
    H.eq(#books, 399); H.eq(truncated, true); H.eq(err, nil)
    H.eq(found_groups[1].category, "authors")
    H.eq(found_groups[1].record.series_name, "Writer")
    groups = {}
end)
H.test("blank queries and stale scopes do not silently search unrelated books", function()
    H.eq(#Search.search("  ", "all"), 0)
    H.eq(select(3, Search.search("Book", "current", { chip = "gone" })), "missing")
    H.eq(select(3, Search.search("Book", "unexpected")), "missing")
    H.eq(#Search.scopes({ chip = "gone" }), 3)
    H.eq(#Search.scopes(ref), 4)
end)

local shown, queued, notifications = {}, {}, {}
local UI = { show = function(_, d) shown[#shown + 1] = d end,
    close = function(_, d) d.closed = true end,
    nextTick = function(_, fn) queued[#queued + 1] = fn end }
package.loaded["ui/uimanager"] = UI
local Dialog = H.widget()
function Dialog:getInputText() return self.input end
function Dialog:onShowKeyboard() self.keyboard = true end
package.loaded["ui/widget/inputdialog"] = Dialog
package.loaded["ui/widget/buttondialog"] = Dialog
package.loaded["ui/widget/infomessage"] = Dialog
local Context = require("core/orbitui_context")
Context.notify = function(text) notifications[#notifications + 1] = text end
H.test("scope picker preserves typed query and opens the keyboard", function()
    local input = Search.show{ query = "Hikaru", ref = ref }
    H.eq(input.keyboard, true)
    input.buttons[1][1].callback()
    local picker = shown[#shown]
    picker.buttons[3][1].callback()
    local next_input = shown[#shown]
    H.eq(next_input.input, "Hikaru")
    assert(next_input.buttons[1][1].text:find("Manga", 1, true))
    H.eq(input.closed, true)
end)
local Window = H.widget()
function Window:show() self.shown = true end
Window.ListRow = function(opts) return opts end
Window.CenteredButtonFooter = function(_, opts) return opts end
package.loaded["engines/sui_window"] = Window
package.loaded["infra/sui_config"] = { isNavpagerEnabled = function() return true end }
H.test("results use the same book panel and retain the caller's reader-opening path", function()
    search_records = { { filepath = "/book", title = "Book" } }
    local opened, held, opened_book
    local open = function(file, book) opened = file; opened_book = book end
    package.loaded["adapters/orbitui_book_panel"] = { show = function(file, opts)
        held = file; H.eq(opts.open_book, open)
    end }
    local win = Search.results("Book", "all", nil, { open_book = open })
    local rows = win.screens.__root__{ inner_w = 600 }
    rows[1].on_hold(); H.eq(held, "/book")
    rows[1].on_tap(); H.eq(opened, "/book")
    H.eq(opened_book, search_records[1])
end)
H.test("empty and unavailable search results provide explicit feedback", function()
    search_records = {}
    local win = Search.results("Missing", "all")
    H.eq(win.screens.__root__{ inner_w = 600 }[1].title, "No matches.")
    H.eq(Search.results("Book", "current", { chip = "gone" }), nil)
    H.eq(notifications[#notifications], "This shelf is no longer available.")
end)
H.finish()
