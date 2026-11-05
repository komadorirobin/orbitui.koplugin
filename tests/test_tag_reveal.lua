local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local f = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_widget.lua", "rb"))
local source = f:read("*a"); f:close()
local files, queue, notices, queries, builds, previews, opens, spine, selected
local definitions = {
    books = { key = "books", roots = { "/books" }, chips = {{ key = "fiction", kind = "folder", path = "/books" }} },
    manga = { key = "manga", roots = { "/manga" }, chips = {{ key = "manga", kind = "folder", path = "/manga" }} },
}
local Profiles = dofile(root .. "/components/bookshelf/lib/bookshelf_profiles.lua")
Profiles.list = function() return { definitions.books, definitions.manga } end
Profiles.get = function(key) return definitions[key] end
local priority = {{ key = "title" }}
Profiles.folderSortPriority = function() return priority end
package.loaded["lib/bookshelf_profiles"] = Profiles
local UI = {
    isWidgetShown = function(_, widget) return widget.shown end,
    nextTick = function(_, fn) queue[#queue + 1] = fn end,
    scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end,
    setDirty = function() end,
}
package.loaded["ui/uimanager"] = UI
package.loaded["libs/libkoreader-lfs"] = { attributes = function(file, field)
    return files[file] and (field == "mode" and "file" or { mode = "file" })
end }
package.loaded["engines/sui_screen_engine"] = { openBook = function() opens = opens + 1 end }
local Repo = {
    getSortPriority = function() return priority end,
    getAll = function(parent, limit, offset, sort, filter, opts)
        H.eq(offset, 0); H.eq(opts.light_only, true); H.eq(opts.lazy_cover, true)
        queries = queries + 1
        local rows = {}
        for i = 1, 30 do
            local file = parent .. "/" .. i .. ".epub"
            if files[file] then rows[#rows + 1] = { filepath = file } end
        end
        return rows
    end,
    buildBook = function(file)
        previews = previews + 1
        return { filepath = file, title = "Selected", description = "Description", cover = "Cover" }
    end,
}
local Widget = {}
local env = setmetatable({ BookshelfWidget = Widget, Profiles = Profiles, Repo = Repo,
    Screen = { getWidth = function() return 600 end, getHeight = function() return 800 end },
    BookshelfSettings = { read = function() end, saveDeferred = function() end },
    FolderLabel = { display = function(text) return text end },
    _normFolderPath = function(path) return path end,
    UIManager = UI, logger = { warn = function() end },
}, { __index = _G })
for _, method in ipairs{ "setProfile", "showFileLocation", "_selectedFilepath", "_hydrateBook", "_jumpScanList", "_setSpineCursor" } do
    local code = assert(source:match("(function BookshelfWidget:" .. method .. "%b().-\nend)"))
    if setfenv then setfenv(assert(loadstring(code)), env)()
    else assert(load(code, "native " .. method, "t", env))() end
end
package.loaded["lib/bookshelf_tab_model"] = { getById = function() return { sort_priority = priority } end }
package.loaded["lib/bookshelf_folder_label"] = env.FolderLabel
local actual, targets, missing
local plugin = { onOpenBookshelfProfile = function(_, key)
    targets[#targets + 1] = { key = key }
    return not missing
end }
package.loaded.pluginloader = { getPluginInstance = function() return plugin end }
local Context = require("core/orbitui_context")
Context.notify = function(text) notices[#notices + 1] = text end
local function reset()
    files, queue, notices, targets = {}, {}, {}, {}
    queries, builds, previews, opens, spine, selected, missing = 0, 0, 0, 0, false, nil, false
    actual = setmetatable({ shown = true, profile_key = "manga", profile = definitions.manga,
        chip = "manga", _cursor = 1, page = 1, _drilldown_path = {},
        width = 600, height = 800, _expanded = true, _hero_mode = "micro",
        _preview_book = { filepath = "/manga/old.epub" }, _tap_selected_fp = "/manga/old.epub",
        _selection = { exitMode = function() end },
        _clearDpadFocus = function(self) self._cursor_idx = nil; self._focus_zone = nil end,
        _profileChip = function(self) return Profiles.chip(self.profile, self.chip) end,
        _profileSettingKey = function() return "active_chip" end,
        _viewSize = function(self) return spine and 80 or self._expanded and 20 or 10 end,
        _isSpineMode = function() return spine end,
        _isRemoteRecord = function() return false end,
        _keyOrnWidget = function() end, _cursorModule = function() end,
        _rebuild = function(self) builds = builds + 1; selected = self:_selectedFilepath() end,
        _openBook = function() opens = opens + 1 end,
        _previewBook = function() error("reveal must never invoke a potentially opening preview action") end,
    }, { __index = Widget })
    plugin._widget = actual
    package.loaded["apps/reader/readerui"] = nil
    package.loaded["lib/bookshelf_reader_park"] = nil
    for _, parent in ipairs{ "/books/Series", "/manga/Series", "/unscoped" } do
        for i = 1, 30 do files[parent .. "/" .. i .. ".epub"] = true end
    end
end
local function flush() while #queue > 0 do table.remove(queue, 1)() end end
H.test("a tag hit resolves its real profile, folder, collapsed page and selected cover/description without reading", function()
    reset()
    local file = "/books/Series/12.epub"
    assert(Context.revealBook(file)); H.eq(builds, 0); flush()
    H.eq(targets[1].key, "books"); H.eq(actual.profile_key, "books")
    H.eq(actual.chip, "fiction"); H.eq(actual._drilldown_path[1].payload.path, "/books/Series")
    H.eq(actual._cursor, 11); H.eq(actual.page, 2); H.eq(actual._expanded, false)
    H.eq(selected, file); H.eq(actual._preview_book.description, "Description")
    H.eq(actual._preview_book.cover, "Cover"); H.eq(actual._hero_mode, "current")
    H.eq(builds, 1); H.eq(queries, 1); H.eq(previews, 1); H.eq(opens, 0)
end)
H.test("repeatedly revealing the same already selected book never opens ReaderUI", function()
    reset()
    Context.revealBook("/books/Series/12.epub"); flush()
    Context.revealBook("/books/Series/12.epub"); flush()
    H.eq(builds, 2); H.eq(opens, 0); H.eq(selected, "/books/Series/12.epub")
end)
H.test("spine navigation anchors the actual book instead of an estimated capacity page", function()
    reset(); spine = true
    Context.revealBook("/books/Series/25.epub"); flush()
    H.eq(actual._cursor, 25); H.eq(actual._spine_skip, 0)
    H.eq(selected, "/books/Series/25.epub"); H.eq(opens, 0)
end)
H.test("an unprofiled hit uses the native real-folder listing without creating a library", function()
    reset()
    Context.revealBook("/unscoped/12.epub"); flush()
    H.eq(targets[1].key, nil); H.eq(actual.profile_key, nil)
    H.eq(actual._drilldown_path[1].payload.path, "/unscoped")
    H.eq(actual._cursor, 11); H.eq(selected, "/unscoped/12.epub"); H.eq(opens, 0)
end)
H.test("a removed file cannot navigate initially or be previewed during a deferred transition", function()
    reset()
    H.eq(Context.revealBook("OPDS://remote.epub"), false); H.eq(#targets, 0)
    Context.revealBook("/books/Series/12.epub"); files["/books/Series/12.epub"] = nil
    flush(); H.eq(previews, 0); H.eq(opens, 0); H.eq(#notices, 2)
end)
H.test("superseding reveal requests use only the final selected book", function()
    reset()
    Context.revealBook("/books/Series/12.epub")
    Context.revealBook("/manga/Series/25.epub"); flush()
    H.eq(builds, 1); H.eq(selected, "/manga/Series/25.epub"); H.eq(opens, 0)
end)
H.test("a newly active reader cannot be repositioned by a late reveal but a parked reader permits shelf preview", function()
    reset()
    Context.revealBook("/books/Series/12.epub")
    package.loaded["apps/reader/readerui"] = { instance = {} }
    flush(); H.eq(previews, 0); H.eq(opens, 0)
    package.loaded["lib/bookshelf_reader_park"] = { isParked = function() return true end }
    Context.revealBook("/books/Series/12.epub"); flush()
    H.eq(selected, "/books/Series/12.epub"); H.eq(opens, 0)
end)
H.test("a hidden or unavailable shelf cannot receive a preview", function()
    reset(); actual.shown = false
    Context.revealBook("/books/Series/12.epub"); flush()
    H.eq(previews, 0); H.eq(#notices, 1)
    reset(); missing = true
    H.eq(Context.revealBook("/books/Series/12.epub"), false)
    flush(); H.eq(previews, 0); H.eq(#notices, 1); H.eq(opens, 0)
end)
H.test("a missing or filtered folder target reports failure rather than previewing another book", function()
    reset()
    files["/books/Series/99.epub"] = true -- available but not in the native listing
    Context.revealBook("/books/Series/99.epub"); flush()
    H.eq(previews, 0); H.eq(selected, nil); H.eq(#notices, 1); H.eq(opens, 0)
end)
H.test("a series result reveals a pinned series drill with its first local member selected, without opening", function()
    reset()
    local members = {
        { filepath = "/manga/Series/1.epub", series_name = "Hirayasumi", series_num = 1 },
        { filepath = "/manga/Series/2.epub", series_name = "Hirayasumi", series_num = 2 },
    }
    assert(Context.revealSeries{ profile = "manga", series_name = "Hirayasumi", members = members })
    flush()
    H.eq(actual.profile_key, "manga"); H.eq(#actual._drilldown_path, 2)
    local tip = actual._drilldown_path[2]
    H.eq(tip.kind, "series"); H.eq(tip.payload._series_box, true)
    H.eq(#tip.payload.books, 2); H.eq(selected, members[1].filepath)
    H.eq(actual._preview_book.description, "Description"); H.eq(opens, 0)
    H.eq(members[1].filepath, "/manga/Series/1.epub")
end)
H.test("missing first volumes fall back only to another available member of the same series and profile", function()
    reset(); files["/manga/Series/1.epub"] = nil
    assert(Context.revealSeries{ profile = "manga", series_name = "S", members = {
        { filepath = "/manga/Series/1.epub" }, { filepath = "/books/Series/1.epub" },
        { filepath = "/manga/Series/2.epub" },
    } })
    flush(); H.eq(selected, "/manga/Series/2.epub")
    H.eq(#actual._drilldown_path[2].payload.books, 1); H.eq(opens, 0)
end)
H.test("retired series navigation cannot reposition a visible shelf after its source changes", function()
    reset()
    local current = true
    assert(Context.revealSeries({ profile = "manga", series_name = "S", members = {{ filepath = "/manga/Series/1.epub" }} },
        { is_current = function() return current end }))
    current = false; flush(); H.eq(previews, 0); H.eq(builds, 0); H.eq(opens, 0)
end)
H.finish()
