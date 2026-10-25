package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Adapter = require("adapters/orbitui_series_boxes")
local Boxes = require("lib/bookshelf_series_boxes")
local function source(name)
    local f = assert(io.open("components/bookshelf/lib/" .. name .. ".lua"))
    local s = f:read("*a"); f:close(); return s
end
local function compile(code, env)
    setmetatable(env, {__index = _G})
    if setfenv then local f = assert(loadstring(code)); setfenv(f, env); return f end
    return assert(load(code, "upstream boxes", "t", env))
end
local src = source("bookshelf_widget")
local function method(name, env)
    local args, body = src:match("function BookshelfWidget:" .. name .. "%((.-)%)\n(.-)\nend")
    assert(body, name)
    return compile("return function(self" .. (args ~= "" and "," .. args or "")
        .. ")\n" .. body .. "\nend", env or {})()
end
local tab, metas, statuses, reads = nil, {}, {}, 0
local Repo = {
    lightMetaFor = function(fp) return metas[fp] end,
    buildBookMeta = function(fp, opts)
        assert(opts and opts.want_cover == false, "unexpected cover decode")
        return metas[fp] or {filepath = fp}
    end,
    readProgress = function(fp) reads = reads + 1; return 1, statuses[fp] end,
}
package.loaded["lib/bookshelf_book_repository"] = Repo
package.loaded["lib/bookshelf_tab_model"] = {getById = function() return tab end}
package.loaded["lib/bookshelf_settings_store"] = {
    read = function() end, generation = function() return 0 end,
}
package.loaded["lib/bookshelf_i18n"] = {gettext = function(s) return s end}
package.loaded["lib/bookshelf_scaled_cover_cache"] = {has = function() return true end}
local function book(n, series)
    return {filepath = "/books/" .. n .. ".epub", filename = n .. ".epub",
        title = "Book " .. n, series_name = series, series_num = tostring(n), has_cover = true}
end
local function members(n)
    local out = {}; for i = 1, n do out[i] = book(i, "Saga") end; return out
end
local function widget(raw)
    raw = raw or {}
    local w = {chip = "fiction", _drilldown_path = {}, _cursor = 1,
        _isSpineMode = function() return true end, _opdsEffectiveTab = function() end,
        _profileScope = function() return {roots = {"/books"}} end,
        _viewSize = function() return 4 end, _spineSkip = function() return 0 end,
        _fetchChipItems = function() return raw, #raw end,
        _jumpScanList = function() return raw, "title", "fixture" end,
    }
    for _, name in ipairs({"_prepareSpineItems", "_spineCachedFetch", "_spineItemsSig",
            "_spineUpdateBookCounts", "_serializeDrillPath", "_restoreDrillPath",
            "_applyWithinGroupSort"}) do
        w[name] = method(name, {Repo = Repo, SPINE_ALL_LIMIT = 10000,
            FolderLabel = {display = function(label) return label end}})
    end
    Adapter.widget(w)
    return w
end

H.test("both profiles and ordinary shelves use one native box preparation pass", function()
    local raw = {book(0), book(2, "Saga"), book(1, "Saga")}
    for _, profile in ipairs({false, {key = "prose"}, {key = "comics"}}) do
        tab = {source = {kind = "folder"}, series_boxes = false}
        local w = widget(raw); w.profile = profile or nil
        H.eq(w:_seriesBoxesEnabled(), true)
        local items = w:_spineCachedFetch(100)
        H.eq(#items, 2); assert(Boxes.isBox(items[2]))
        H.eq(items[2]._orbitui_series_box, nil)
        H.eq(items[2].first_book.filepath, raw[3].filepath)
        H.eq(w.prepareSpineItems, nil); H.eq(w.spineItemCount, nil)
        H.eq(w:_spineCachedFetch(100), items)
        H.eq(tab.series_boxes, false) -- Existing native choice survives rollback.
        H.eq(raw[2]._series_box, nil); H.eq(#raw, 3)
    end
    tab = nil
end)

H.test("fixed profile IDs cannot inherit an unrelated native single-series tab", function()
    tab = {source = {kind = "single_series"}}
    local w = widget(members(3)); w.chip = "authors"
    H.eq(w:_seriesBoxesEnabled(), false); H.eq(w:spineShowSectionBadges(), false)
    for _, key in ipairs({"prose", "comics"}) do
        w.profile = {key = key}
        H.eq(w:_seriesBoxesEnabled(), true); H.eq(w:spineShowSectionBadges(), true)
    end
    tab = nil
end)

H.test("grid, incomplete windows, series drills, search and OPDS do not compact", function()
    local raw = members(3)
    local w = widget(raw)
    H.eq(w:_prepareSpineItems(raw, 1000), raw)
    w._isSpineMode = function() return false end
    H.eq(w:_prepareSpineItems(raw, #raw), raw)
    w._isSpineMode = function() return true end
    for _, kind in ipairs({"series", "search", "opds_nav"}) do
        w._drilldown_path = {{kind = kind}}
        H.eq(w:_prepareSpineItems(raw, #raw), raw)
    end
    w._drilldown_path = {}; w._opdsEffectiveTab = function() return {} end
    H.eq(w:_prepareSpineItems(raw, #raw), raw)
end)

H.test("letter jumps and footer use the same native compact display list", function()
    local raw = {book(0), book(1, "Saga"), book(2, "Saga"), book(3, "Saga"), book(4)}
    local w = widget(raw)
    local items = w:_spineCachedFetch(100)
    local scan, key, via = w:_jumpScanList()
    H.eq(#items, 3); H.eq(#scan, 3); H.eq(key, "title"); H.eq(via, "fixture")
    H.eq(Boxes.signature(items[2]), Boxes.signature(scan[2]))
    w._cursor = 3; w:_spineUpdateBookCounts(items)
    H.eq(w._spine_books_total, 3); H.eq(w._spine_books_before, 2)
end)

H.test("a one-volume series is boxed in OrbitUI while standalone Bookshelf keeps its default", function()
    local lone = book(1, "Saga")
    local w = widget({lone, book(0)})
    local items = w:_spineCachedFetch(100)
    H.eq(Boxes.isBox(items[1]), true); H.eq(items[1].book_count, 1)
    H.eq(items[1].first_book.filepath, lone.filepath); H.eq(items[2].filepath, "/books/0.epub")
    H.eq(Boxes.prepare({lone})[1], lone)
    H.eq(lone._series_box, nil)
end)

H.test("singletons include light metadata and grouped stubs without mutating the source", function()
    local lone = book(1)
    metas[lone.filepath] = {series_name = "Light series", cover_bb = "shared"}
    local w = widget({lone})
    local box = w:_prepareSpineItems({lone}, 1)[1]
    H.eq(box.series_name, "Light series"); H.eq(box.books[1].cover_bb, nil)
    H.eq(lone.series_name, nil); H.eq(metas[lone.filepath].cover_bb, "shared")
    local group = {series_name = "Grouped series", books = {{filepath = "/books/stub.epub"}}}
    box = w:_prepareSpineItems({group}, 1)[1]
    assert(Boxes.isBox(box)); H.eq(box.series_name, "Grouped series"); H.eq(box.book_count, 1)
    H.eq(group.books[1].series_name, nil)
    local author = {kind = "author", series_name = "A name", books = {book(2, "Another")}}
    local display = w:_prepareSpineItems({author}, 1)[1]
    H.eq(display.books, author.books); assert(Boxes.isBox(display._series_display_books[1]))
    metas = {}
end)

local Profiles = require("lib/bookshelf_profiles")
local manga_root = Profiles.get("comics").chips[1].path
local function mangaBook(path, series)
    local b = book(1, series)
    b.filepath, b.filename, b.title = manga_root .. "/" .. path, path:match("([^/]+)$"), path
    return b
end
local function mangaWidget(raw)
    local w = widget(raw)
    w.profile, w.chip = Profiles.get("comics"), "profile_manga"
    w._profileScope = function() return Profiles.scope(w.profile) end
    return w
end

H.test("Oneshots directory matching is component-based scoped and local-only", function()
    for _, fp in ipairs({"/Manga/Oneshots/A.cbz", "/Manga/Oneshots/Title/A.cbz"}) do
        H.eq(Adapter.oneshotsPath(fp, "/Manga/"), "/Manga/Oneshots")
    end
    H.eq(Adapter.oneshotsPath("/Manga/Author/oneshots/A.cbz", "/Manga"), "/Manga/Author/oneshots")
    for _, fp in ipairs({"/Manga/Oneshots.cbz", "/Manga/Oneshots Extra/A.cbz", "/Manga2/Oneshots/A.cbz",
            "/Manga/../Fiction/Oneshots/A.epub", "https://example.org/Manga/Oneshots/A.cbz"}) do
        H.eq(Adapter.oneshotsPath(fp, "/Manga"), nil)
    end
    H.eq(Adapter.oneshotsPath(nil, "/Manga"), nil)
end)

H.test("Oneshots and nested title folders occupy one box preserving displayed order and metadata", function()
    local raw = {mangaBook("Before.cbz"), mangaBook("Oneshots/Z.cbz"),
        mangaBook("Oneshots/Title/A.cbz"), mangaBook("Oneshots/WithMetadata.cbz", "A real series"),
        mangaBook("After/1.cbz", "Another series"), mangaBook("Loose.cbz")}
    raw[2].cover_bb = "shared"
    local w = mangaWidget(raw)
    local items = w:_spineCachedFetch(100)
    H.eq(#items, 4)
    local box = items[2]
    assert(Boxes.isBox(box)); H.eq(box.kind, "folder"); H.eq(box.path, manga_root .. "/Oneshots")
    H.eq(box.label, "Oneshots"); H.eq(box.book_count, 3); H.eq(box._spine_single, false)
    H.eq(box.first_book.filepath, raw[2].filepath); H.eq(box.books[2].filepath, raw[3].filepath)
    H.eq(box.books[3].series_name, "A real series"); H.eq(box.books[1].cover_bb, nil)
    H.eq(raw[2].series_name, nil); H.eq(raw[2].cover_bb, "shared"); H.eq(raw[2]._series_box, nil)
    H.eq(box.author, nil); H.eq(box.authors, nil)
    H.eq(require("core/orbitui_author_ornaments").authorOf({book = box}), nil)
    H.eq(require("core/orbitui_manga_ornaments").seriesOf({book = box}), nil)
    assert(Boxes.isBox(items[3])); H.eq(items[3].book_count, 1)
    H.eq(items[4], raw[6])
    local scan = w:_jumpScanList()
    H.eq(#scan, #items); H.eq(Boxes.signature(scan[2]), Boxes.signature(box))
    w._cursor = 3; w:_spineUpdateBookCounts(items)
    H.eq(w._spine_books_total, 4); H.eq(w._spine_books_before, 2)
end)

H.test("separate Oneshots paths and a real series named Oneshots never merge", function()
    local raw = {mangaBook("Oneshots/A.cbz"), mangaBook("Oneshots/A.cbz"),
        mangaBook("Other/Oneshots/B.cbz"), mangaBook("Real/1.cbz", "Oneshots")}
    local items = mangaWidget(raw):_prepareSpineItems(raw, #raw)
    H.eq(#items, 3); H.eq(items[1].book_count, 1); H.eq(items[2].book_count, 1)
    assert(items[1]._series_box_key ~= items[2]._series_box_key)
    assert(items[1]._series_box_key ~= items[3]._series_box_key)
    H.eq(items[3].kind, "series"); H.eq(items[3].series_name, "Oneshots")
end)

H.test("Oneshots grouping does not invent collections on other profiles or non-folder sources", function()
    local raw = {mangaBook("Oneshots/A.cbz"), mangaBook("Oneshots/B.cbz")}
    local w = mangaWidget(raw)
    for _, chip in ipairs({"authors", "bookorbit_tbr", "latest", "next"}) do
        w.chip = chip
        H.eq(#w:_prepareSpineItems(raw, #raw), 2)
    end
    w.chip, w.profile = "profile_fiction", Profiles.get("prose")
    H.eq(#w:_prepareSpineItems(raw, #raw), 2)
    w.profile = nil; H.eq(#w:_prepareSpineItems(raw, #raw), 2)
    w = mangaWidget(raw)
    H.eq(w:_prepareSpineItems(raw, 1000), raw)
    w._isSpineMode = function() return false end
    H.eq(w:_prepareSpineItems(raw, #raw), raw)
    w._isSpineMode = function() return true end
    for _, kind in ipairs({"series", "search", "opds_nav", "author"}) do
        w._drilldown_path = {{kind = kind}}
        H.eq(#w:_prepareSpineItems(raw, #raw), 2)
    end
    w._drilldown_path = {}; raw[1].is_remote = true
    local items = w:_prepareSpineItems(raw, #raw)
    H.eq(items[1], raw[1]); H.eq(items[2].book_count, 1)
end)

H.test("opening and restoring an Oneshots box use the native folder path without reboxing", function()
    local raw = {mangaBook("Oneshots/A.cbz"), mangaBook("Oneshots/B.cbz", "Actual series")}
    local w = mangaWidget(raw)
    local box = w:_prepareSpineItems(raw, #raw)[1]
    local marked
    w._markTapped = function(_, fp) marked = fp end
    w._drillInto = function(self, entry) self._drilldown_path[#self._drilldown_path + 1] = entry end
    w._expandFolder = method("_expandFolder", {FolderLabel = {display = function(label) return label end}})
    w:_expandFolder(box)
    H.eq(marked, box.first_book.filepath); H.eq(w._drilldown_path[1].kind, "folder")
    H.eq(w:_seriesBoxesEnabled(), false); H.eq(w:_prepareSpineItems(raw, #raw), raw)
    local saved = w:_serializeDrillPath()
    H.eq(saved[1].path, box.path); H.eq(saved[1].kind, "folder")
    H.eq(saved[1].books, nil); H.eq(saved[1].series_box_files, nil)
    local restored = mangaWidget()
    restored:_restoreDrillPath(saved)
    H.eq(restored._drilldown_path[1].payload.path, box.path)
    H.eq(restored:_seriesBoxesEnabled(), false)
    -- Fetch again from the folder, not a persisted membership snapshot.
    local fresh = {raw[2], mangaBook("Oneshots/New.cbz")}
    Repo.getFolderSections = function(_, _, _, scope, _, opts)
        H.eq(opts.root, box.path); H.eq(scope.roots[1], manga_root)
        return fresh, #fresh
    end
    restored._fetchChipItems = method("_fetchChipItems", {Repo = Repo, Profiles = Profiles})
    local items, total = restored:_fetchChipItems(10000, true)
    H.eq(items, fresh); H.eq(total, 2); H.eq(restored:_prepareSpineItems(items, total), fresh)
    Repo.getFolderSections = nil
    restored._drilldown_path = {}; H.eq(restored:_seriesBoxesEnabled(), true)
end)

H.test("custom folder grouping works in any library and does not rebox its contents", function()
    local raw = { mangaBook("Short stories/A.epub"), mangaBook("Short stories/B.epub") }
    local w = widget(raw)
    w.profile = { key = "section_7", roots = { manga_root }, chips = {
        { key = "books", kind = "folder", path = manga_root, group_folder_name = "Short stories" },
    } }
    w.chip = "books"
    local boxes = w:_prepareSpineItems(raw, #raw)
    H.eq(#boxes, 1); H.eq(boxes[1].book_count, 2); H.eq(boxes[1].label, "Short stories")
    w._drilldown_path = { { kind = "folder", payload = { path = manga_root .. "/Short stories" } } }
    H.eq(w:_seriesBoxesEnabled(), false)
    H.eq(w:_prepareSpineItems(raw, #raw), raw)
end)

H.test("author groups retain members, bust identity and native box signatures", function()
    local raw = {kind = "author", series_name = "Joyce", books = members(3)}
    for _, b in ipairs(raw.books) do b.author = "James Joyce" end
    local w = widget({raw})
    local group = w:_spineCachedFetch(100)[1]
    H.eq(group.books, raw.books); H.eq(#group._series_display_books, 1)
    local box = group._series_display_books[1]
    H.eq(require("core/orbitui_author_ornaments").authorOf({book = box}), "james joyce")
    local sig = w:_spineItemsSig({group})
    box.books[3].filepath = "/books/other.epub"
    assert(w:_spineItemsSig({group}) ~= sig)
    H.eq(raw.books[3].filepath, "/books/3.epub")
end)

H.test("native group fetch opens the complete numerically ordered box without covers", function()
    local raw = members(120)
    for _, b in ipairs(raw) do metas[b.filepath] = b end
    local box = Boxes.box(raw, "Saga")
    local w = widget()
    w._fetchChipItems = method("_fetchChipItems", {Repo = Repo})
    w._drilldown_path = {{kind = "series", label = "Saga", payload = box}}
    tab = {sort_priority = {{key = "author"}, {key = "title", reverse = true}}, filter = {}}
    Repo.filterMembers = function(books) return {books[2], books[4]} end
    local items, total = w:_fetchChipItems(10000, true)
    H.eq(total, 2); H.eq(#items, 2); H.eq(items[1].series_num, "2")
    H.eq(w:_prepareSpineItems(items, total), items)
    w._drilldown_path[1].whole = true
    items, total = w:_fetchChipItems(10000, true)
    H.eq(total, 120); H.eq(#items, 120); H.eq(items[120].series_num, "120")
    H.eq(#box.books, 120); H.eq(Repo.spine_light, nil); H.eq(Repo.suppress_covers, nil)
    tab = nil; Repo.filterMembers = nil; metas = {}
end)

H.test("old saved box scopes restore through native code without widening or mutation", function()
    local saved = {{kind = "series", label = "Saga",
        orbitui_series_files = {"/books/2.epub", "/books/4.epub"}}}
    Repo.findGroup = function(kind, label, scope)
        H.eq(kind, "series"); H.eq(scope.roots[1], "/books")
        return {series_name = label, books = members(3)}
    end
    local w = widget(); w:_restoreDrillPath(saved)
    local box = w._drilldown_path[1].payload
    assert(Boxes.isBox(box)); H.eq(#box.books, 1); H.eq(box.books[1].series_num, "2")
    H.eq(saved[1].series_box_files, nil); H.eq(#saved[1].orbitui_series_files, 2)
    H.eq(w:_seriesBoxesEnabled(), false)
end)

H.test("new saves keep both identifier keys for safe rollback, never cover buffers", function()
    local raw = members(3); raw[1].cover_bb = "borrowed"
    local w = widget()
    w._drilldown_path = {{kind = "series", label = "Saga", payload = Boxes.box(raw, "Saga")}}
    local saved = w:_serializeDrillPath()
    H.eq(#saved[1].series_box_files, 3); H.eq(saved[1].books, nil)
    H.eq(saved[1].orbitui_series_files, saved[1].series_box_files)
    for _, fp in ipairs(saved[1].series_box_files) do H.eq(type(fp), "string") end
    local restored = widget(); restored:_restoreDrillPath(saved)
    H.eq(#restored._drilldown_path[1].payload.books, 3)
    H.eq(raw[1].cover_bb, "borrowed")
end)

H.test("modern scope takes precedence and missing members cannot restore a whole series", function()
    local w = widget()
    w:_restoreDrillPath({{kind = "series", label = "Saga", series_box_files = {"/books/1.epub"},
        orbitui_series_files = {"/books/2.epub"}}})
    H.eq(w._drilldown_path[1].payload.books[1].series_num, "1")
    w = widget(); w:_restoreDrillPath({{kind = "series", label = "Saga", orbitui_series_files = {}}})
    H.eq(#w._drilldown_path, 0)
    w:_restoreDrillPath(nil); H.eq(#w._drilldown_path, 0)
end)

H.test("redundant section badges stay hidden only inside a series", function()
    local w = widget()
    H.eq(w:spineShowSectionBadges(), true)
    for _, kind in ipairs({"series", "author", "folder", "genre", "search"}) do
        w._drilldown_path = {{kind = "series"}, {kind = kind}}
        H.eq(w:spineShowSectionBadges(), kind ~= "series")
    end
end)

H.test("ornament adapter leaves native box geometry, flattening and drawing untouched", function()
    local shelf = {_flattenItems = function() end, recessColumns = function() end}
    local flatten, recess = shelf._flattenItems, shelf.recessColumns
    require("adapters/orbitui_ornaments").wrap("lib/bookshelf_spine_shelf", shelf)
    H.eq(shelf._flattenItems, flatten); H.eq(shelf.recessColumns, recess)
    H.eq(shelf.seriesBoxGeometry, nil); H.eq(shelf.seriesBoxWidget, nil)
    H.eq(shelf.positionOrnamentX, require("core/orbitui_ornament_spacing").positionX)
    local editor = require("adapters/orbitui_ui").wrap("lib/bookshelf_chip_editor", {})
    H.eq(editor.series_boxes_external, true); H.eq(editor.face_out_override, "all")
end)

-- Exercise the real upstream painter, with bounded surfaces and native UI
-- primitives stubbed. This deliberately does not reinstate our old whole-box
-- completion overlay: the compact head carries the aggregate read count.
local W = H.widget()
local fail_cover = false
W.CARD_BORDER = 1
function W:getSize() return self.dimen or {w = self.width or 0, h = self.height or 0} end
function W:free() end
function W:paintTo(bb, x, y)
    if fail_cover then error("cover unavailable") end
    bb:paintRectRGB32(x, y, self.width, self.height, "cover")
end
for _, name in ipairs({"ui/widget/container/inputcontainer", "ui/geometry", "ui/gesturerange"}) do
    package.loaded[name] = W
end
local Text = W:extend{}
function Text:init()
    self.dimen = {w = math.min(self.max_width or math.huge,
        #(self.text:gsub("[\128-\191]", "")) * self.face.size / 2), h = self.face.size}
end
function Text:paintTo(bb, x, y)
    bb:paintRectRGB32(x, y, self.dimen.w, self.dimen.h, "text")
    bb.texts[#bb.texts + 1] = {text = self.text, x = x, y = y, w = self.dimen.w, h = self.dimen.h,
        ink = self.fgcolor}
end
local allocated, scaled = {}, 0
local function surface(w, h)
    local bb = {w = w, h = h, blits = 0, texts = {}, copies = {}, rects = {}}
    function bb:paintRectRGB32(x, y, rw, rh, color)
        assert(x >= 0 and y >= 0 and rw >= 0 and rh >= 0
            and x + rw <= self.w and y + rh <= self.h, "paint outside buffer")
        self.rects[#self.rects + 1] = {x = x, y = y, w = rw, h = rh, color = color}
    end
    function bb:blitFrom(srcbb, x, y, sx, sy, rw, rh)
        self:paintRectRGB32(x, y, rw, rh, "cover")
        srcbb:paintRectRGB32(sx, sy, rw, rh)
        self.blits = self.blits + 1
        self.copies[#self.copies + 1] = {x = x, y = y, sx = sx, sy = sy,
            w = rw, h = rh, source = srcbb}
    end
    function bb:scale(sw, sh)
        scaled = scaled + 1
        local next = surface(sw, sh); allocated[#allocated + 1] = next; return next
    end
    function bb:getType() return 1 end
    function bb:getWidth() return self.w end
    function bb:getHeight() return self.h end
    function bb:free() assert(not self.freed, "double free"); self.freed = true end
    function bb:colorAt(x, y)
        for i = #self.rects, 1, -1 do
            local r = self.rects[i]
            if r.color ~= "text" and x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h then
                return r.color
            end
        end
    end
    return bb
end
local night, painted_slots, cover_aspect, dpi = false, 0, 1.5, 1
package.loaded["device"] = {screen = {scaleBySize = function(_, n) return math.floor(n * dpi + .5) end}}
package.loaded["lib/bookshelf_space"] = {px = function(n) return n end}
package.loaded["ffi/blitbuffer"] = {new = function(w, h)
        local bb = surface(w, h); allocated[#allocated + 1] = bb; return bb
    end,
    ColorRGB32 = function(r, g, b, a) return {r = r, g = g, b = b, a = a} end}
package.loaded["lib/bookshelf_colour_text"] = Text
package.loaded["lib/bookshelf_fonts"] = {getFace = function(_, _, size) return {size = size} end,
    getUIFontFace = function() return "cfont" end, bundledFaceId = function() return "count.ttf" end}
package.loaded["ui/font"] = {getFace = function(_, _, size) return {size = size} end}
package.loaded["lib/bookshelf_night_mode_sync"] = {active = function() return night end}
package.loaded["lib/bookshelf_wallpaper"] = {shadeRect = function(bb, x, y, w, h)
    bb:paintRectRGB32(x, y, w, h)
end}
package.loaded["lib/bookshelf_spine_widget"] = W
local Slot = W:extend{}
function Slot:_renderIntoAt(bb, x, y)
    painted_slots = painted_slots + 1
    bb:paintRectRGB32(x, y, self.width, self.height)
end
package.loaded["lib/bookshelf_spine_shelf"] = {
    titleSize = function() return 12 end, textHeight = function(size) return size end,
    cachedProgress = function() return nil end, cachedPageCount = function() return nil end,
    _SpineBookSlot = Slot,
    bookLook = function() return {r = 90, g = 120, b = 80, aspect = cover_aspect} end,
    boardColor = function() return {r = 90, g = 120, b = 80} end,
}
local Painter = require("lib/bookshelf_series_box_widget")
local function visibleBox(raw, scale, name, position)
    scale = scale or 1
    local box = Boxes.box(raw, name or "Saga")
    local shape = Boxes.geometry(box, {w = 160 * scale, h = 248 * scale,
        face_h = 240 * scale, depth = 8 * scale}, {content_w = 800, series_title_position = position})
    local w = Painter:new{entry = {book = box, series_box = shape}, width = shape.w, height = 400}
    return w, box, shape
end
local function count(done, total) return done .. "\xE2\x80\x8A/\xE2\x80\x8A" .. total end

H.test("light series members use hydrated metadata in the real cover-selection gate", function()
    local body = assert(source("bookshelf_spine_widget"):match("function SpineWidget:init%(%)\n(.-)\nend"))
    local Cover = W:extend{}
    Cover.init = compile("return function(self)\n" .. body .. "\nend", {
        Geom = W, GestureRange = W, _draft_mode = false,
    })()
    function Cover:_renderCover(bb)
        H.eq(bb, nil, "the box must not borrow a shared cover buffer")
        return {kind = "cover", filepath = self.book.filepath}
    end
    function Cover:_renderFallback() return {kind = "placeholder"} end
    package.loaded["lib/bookshelf_spine_widget"] = Cover
    for _, kind in ipairs({"embedded", "external", "absent"}) do
        local raw = members(3)
        for _, b in ipairs(raw) do b.has_cover = nil end
        metas[raw[1].filepath] = {filepath = raw[1].filepath,
            has_cover = kind == "embedded", cover_bb = "shared-do-not-use",
            cover_image_path = kind == "external" and "/custom-cover.jpg" or nil}
        local w, box = visibleBox(raw)
        H.eq(w.art_cover[1].kind, kind == "absent" and "placeholder" or "cover")
        H.eq(w.art_cover.book.cover_image_path, metas[raw[1].filepath].cover_image_path)
        H.eq(w.art_cover.book.cover_bb, nil)
        H.eq(raw[1].has_cover, nil); H.eq(box.books[1].has_cover, nil)
        w:_makeArtCover(30, 45) -- A custom-image failure may resize the fallback.
        H.eq(w.art_cover[1].kind, kind == "absent" and "placeholder" or "cover")
        H.eq(metas[raw[1].filepath].cover_bb, "shared-do-not-use")
    end
    package.loaded["lib/bookshelf_spine_widget"] = W
    metas = {}
end)

H.test("aspect fit and wider minimum are host opt-ins, not standalone changes", function()
    H.eq(Boxes.SLIPCASE_MIN_SHARE, .5); H.eq(Painter.preserve_cover_aspect, false)
    local old = visibleBox(members(2))
    H.eq(old.st_w, old.art_w); H.eq(old.st_h, old.art_h)
    H.eq(old.count_band_h, nil)
    local UI = require("adapters/orbitui_ui")
    H.eq(UI.modules["lib/bookshelf_series_boxes"], true)
    H.eq(UI.modules["lib/bookshelf_series_box_widget"], true)
    UI.wrap("lib/bookshelf_series_boxes", Boxes)
    UI.wrap("lib/bookshelf_series_box_widget", Painter)
    H.eq(Boxes.SLIPCASE_MIN_SHARE, .85); H.eq(Painter.preserve_cover_aspect, true)
    H.eq(Boxes.SLIPCASE_COMPACT_HEADS, true)
    local larger = visibleBox(members(2))
    assert(larger.shape.rise < old.shape.rise)
    H.eq(larger.count_band_h, 0)
    assert(larger.st_h > old.st_h)
end)

H.test("box width stays between eighty-five percent and the existing cover cap", function()
    local previous = 0
    for _, n in ipairs({2, 3, 8, 120}) do
        local _, _, shape = visibleBox(members(n))
        assert(shape.w >= math.floor(160 * .85) and shape.w <= 160)
        assert(shape.w >= previous); previous = shape.w
    end
    local _, _, short = visibleBox(members(2))
    assert(short.w < 160, "a small collection should still have a narrower box")
    local _, _, long = visibleBox(members(2), 1, ("Long name "):rep(20))
    H.eq(long.w, 160)
    local shape = Boxes.geometry(Boxes.box(members(2), "Saga"),
        {w = 160, h = 248}, {content_w = 110, end_margin = 10})
    assert(shape.w <= 90, "minimum width must not override available shelf space")
end)

H.test("compact heads give covers more height than the previous aspect-preserving layout", function()
    for _,aspect in ipairs({.5,1,1.5,2.4}) do
        cover_aspect=aspect
        for _,n in ipairs({2,3,8,120}) do
            Boxes.SLIPCASE_MIN_SHARE,Boxes.SLIPCASE_COMPACT_HEADS=.7,false
            local before=visibleBox(members(n))
            Boxes.SLIPCASE_MIN_SHARE,Boxes.SLIPCASE_COMPACT_HEADS=.85,true
            local after=visibleBox(members(n))
            assert(after.st_h>=before.st_h)
            assert(after.st_w>=before.st_w)
            assert(after.art_h>before.art_h)
            H.eq(after.count_band_h,0)
            assert(after.shape.rise<before.shape.rise)
        end
    end
    cover_aspect=1.5
end)

H.test("portrait square and landscape stickers fit and center without a second scale", function()
    for _, aspect in ipairs({.5, 1, 1.5, 2.4, 4}) do
        cover_aspect = aspect
        for _, n in ipairs({2, 3, 8, 120}) do
            for _, scale in ipairs({.5, 1, 1.5}) do
                local w, _, shape = visibleBox(members(n), scale)
                local iw, ih = w.st_w - 2, w.st_h - 2
                assert(math.min(math.abs(ih - iw * aspect), math.abs(iw - ih / aspect)) <= .5)
                assert(w.st_dx >= 0 and w.st_dx + w.st_w <= w.art_w)
                assert(w.st_dy >= w.count_band_h and w.st_dy + w.st_h <= w.art_h)
                assert(math.abs(w.st_dx * 2 + w.st_w - w.art_w) <= 1)
                assert(math.abs((w.st_dy - w.count_band_h) * 2 + w.st_h
                    - (w.art_h - w.count_band_h)) <= 1)
                H.eq(w.art_cover.width - 2 * W.CARD_BORDER, iw)
                H.eq(w.art_cover.height - 2 * W.CARD_BORDER, ih)
                Painter.clearStickerCache()
                allocated, scaled = {}, 0
                local bb = surface(shape.w, 400); w:paintTo(bb, 0, 0)
                H.eq(bb.blits, 1); H.eq(scaled, 0); H.eq(#allocated, 1)
                assert(not allocated[1].freed, "the cached source must survive widget teardown")
                local copy = bb.copies[1]
                H.eq(copy.sx, W.CARD_BORDER); H.eq(copy.sy, W.CARD_BORDER)
                H.eq(copy.w, iw); H.eq(copy.h, ih)
                Painter.clearStickerCache()
                assert(allocated[1].freed, "clearing the sticker cache must release its source")
            end
        end
    end
    cover_aspect = 1.5
end)

H.test("counts stay above the image and two-line names stay centered on the board", function()
    for _, aspect in ipairs({.5, 1.5, 3}) do
        cover_aspect = aspect
        local w, _, shape = visibleBox(members(120), 1, ("Twelvechar Lettersmore "):rep(8))
        assert(w.name_lines)
        local bb = surface(shape.w + 40, 420); w:paintTo(bb, 20, 10)
        local cover = bb.copies[1]; assert(cover)
        local count_rect = bb.texts[1]
        H.eq(count_rect.text, w.count.text)
        assert(count_rect.y + count_rect.h < cover.y)
        H.eq(count_rect.x + count_rect.w, 20 + shape.w - w.inset)
        local first_name = w.more and 3 or 2
        if w.more then
            local more = bb.texts[2]
            H.eq(more.text, "+" .. shape.hidden_count)
            assert(more.x + more.w < count_rect.x)
            H.eq(more.y, count_rect.y)
        end
        for i = first_name, #bb.texts do
            local name = bb.texts[i]
            assert(cover.y + cover.h < name.y)
            assert(math.abs(name.x + name.w / 2 - (20 + shape.w / 2)) <= .5)
        end
        H.eq(#bb.texts, first_name + 1)
    end
    cover_aspect = 1.5
end)

H.test("missing or invalid aspect uses a finite portrait fallback", function()
    for _, aspect in ipairs({false, 0, -1, math.huge, 0/0, "invalid"}) do
        cover_aspect = aspect
        local w = visibleBox(members(2))
        local iw, ih = w.st_w - 2, w.st_h - 2
        assert(math.min(math.abs(ih - iw * 1.5), math.abs(iw - ih / 1.5)) <= .5)
        local bb = surface(w.width, 400); w:paintTo(bb, 0, 0); H.eq(bb.blits, 1)
    end
    cover_aspect = 1.5
end)

H.test("large read totals shrink to fit a small box without dropping digits", function()
    local raw = members(120)
    statuses = {}; for _, b in ipairs(raw) do statuses[b.filepath] = "finished" end
    local w = visibleBox(raw, .5)
    local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
    H.eq(bb.texts[1].text, count(120, 120))
    assert(bb.texts[1].w <= w.art_w)
    assert(bb.texts[1].y + bb.texts[1].h < bb.copies[1].y)
    statuses = {}
end)

H.test("high DPI borders are removed exactly without cropping the image", function()
    for _, factor in ipairs({1.5, 2}) do
        dpi = factor; W.CARD_BORDER = math.floor(dpi + .5)
        for _, dark in ipairs({false, true}) do
            night = dark
            local w = visibleBox(members(8))
            local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
            H.eq(bb.blits, 1)
            local copy = bb.copies[1]
            H.eq(copy.sx, W.CARD_BORDER); H.eq(copy.sy, W.CARD_BORDER)
            H.eq(copy.w, w.art_cover.width - 2 * W.CARD_BORDER)
            H.eq(copy.h, w.art_cover.height - 2 * W.CARD_BORDER)
        end
    end
    dpi, W.CARD_BORDER, night = 1, 1, false
end)

H.test("failed cover painting frees its scratch buffer and retries on redraw", function()
    Painter.clearStickerCache()
    local w = visibleBox(members(3)); local bb = surface(w.width, 400)
    allocated, fail_cover = {}, true
    w:paintTo(bb, 0, 0); H.eq(bb.blits, 0); H.eq(#allocated, 1)
    assert(allocated[1].freed)
    fail_cover = false
    w:paintTo(bb, 0, 0); H.eq(bb.blits, 1); assert(not allocated[2].freed)
    Painter.clearStickerCache(); assert(allocated[2].freed)
end)

H.test("upstream read count follows live completion and reverting the final volume", function()
    local raw = members(3)
    for _, b in ipairs(raw) do b.status = "finished" end
    statuses = {[raw[1].filepath] = "finished", [raw[2].filepath] = "finished"}
    local w = visibleBox(raw); H.eq(w.count.text, count(2, 3))
    statuses[raw[3].filepath] = "finished"
    w = visibleBox(raw); H.eq(w.count.text, count(3, 3))
    local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
    H.eq(bb.blits, 1) -- The cover path must not have silently failed its pcall.
    statuses[raw[3].filepath] = "reading"
    H.eq(visibleBox(raw).count.text, count(2, 3))
    H.eq(raw[3].status, "finished") -- No writes to source reading state.
end)

H.test("sticker buffers survive page rebuilds, stay bounded and free on explicit invalidation", function()
    Painter.clearStickerCache()
    allocated, fail_cover = {}, false
    local raw = members(3)
    raw[1].filepath = "/cache/rebuilt-first.cbz"
    local first = visibleBox(raw)
    first:paintTo(surface(first.width, 400), 0, 0)
    H.eq(#allocated, 1)
    local kept = allocated[1]
    first:free(); assert(not kept.freed)
    local rebuilt = visibleBox(raw)
    fail_cover = true -- a hit must not ask the cover to paint again
    local bb = surface(rebuilt.width, 400)
    rebuilt:paintTo(bb, 0, 0); H.eq(bb.blits, 1); H.eq(#allocated, 1)
    rebuilt:free(); fail_cover = false
    for i = 1, 12 do
        local other = members(3); other[1].filepath = "/cache/different-" .. i .. ".cbz"
        local w = visibleBox(other)
        w:paintTo(surface(w.width, 400), 0, 0); w:free()
    end
    assert(kept.freed, "the thirteenth cached sticker must evict the oldest")
    Painter.clearStickerCache()
    for _, buffer in ipairs(allocated) do assert(buffer.freed, "cache-owned buffer leaked") end
end)

H.test("complete native boxes paint safely in day and night after a fresh build", function()
    for _, n in ipairs({2, 8, 120}) do
        local raw = members(n)
        statuses = {}; for _, b in ipairs(raw) do statuses[b.filepath] = "finished" end
        for _, scale in ipairs({.5, 1, 1.5}) do
            for _, dark in ipairs({false, true}) do
                night = dark
                local before = reads
                local w, box, shape = visibleBox(raw, scale)
                H.eq(reads - before, n); H.eq(w.count.text, count(n, n))
                H.eq(shape.style, "slipcase")
                assert(#shape.spines > 0 and #shape.spines <= math.min(n, 8))
                H.eq(shape.hidden_count, n - #shape.spines)
                H.eq(#box.books, n); H.eq(w.all_read, nil); H.eq(w.fade_amount, nil)
                painted_slots = 0; before = reads
                local bb = surface(shape.w, 400)
                w:paintTo(bb, 0, 0); w:paintTo(bb, 0, 0)
                H.eq(bb.blits, 2); H.eq(painted_slots, 2 * #shape.spines)
                H.eq(reads, before)
            end
        end
    end
    night = false
end)

H.test("single-volume and Oneshots boxes paint live read totals including fully read collections", function()
    local raw = {mangaBook("Oneshots/A.cbz"), mangaBook("Oneshots/B.cbz")}
    local folder = mangaWidget(raw):_prepareSpineItems(raw, #raw)[1]
    local single = widget({book(1, "Only volume")}):_prepareSpineItems({book(1, "Only volume")}, 1)[1]
    for _, box in ipairs({folder, single}) do
        for _, done in ipairs({false, true}) do
            statuses = {}
            for _, b in ipairs(box.books) do statuses[b.filepath] = done and "finished" or "reading" end
            for _, dark in ipairs({false, true}) do
                night = dark
                local shape = Boxes.geometry(box, {w = 160, h = 248, face_h = 240, depth = 8}, {content_w = 800})
                local w = Painter:new{entry = {book = box, series_box = shape}, width = shape.w, height = 400}
                local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
                H.eq(w.count.text, count(done and #box.books or 0, #box.books))
                H.eq(bb.blits, 1)
                if box.kind == "folder" then H.eq(box._spine_single, false) end
                w:free()
            end
        end
    end
    statuses, night = {}, false
end)

H.test("Oneshots taps and holds use folder callbacks and folder images rather than series identities", function()
    local raw = {mangaBook("Oneshots/A.cbz")}
    local box = mangaWidget(raw):_prepareSpineItems(raw, #raw)[1]
    local shape = Boxes.geometry(box, {w = 160, h = 248, face_h = 240, depth = 8}, {content_w = 800})
    local cached = surface(200, 300)
    local folder_lookups, series_lookups, taps, holds = 0, 0, 0, 0
    package.loaded["lib/bookshelf_image_source"] = {
        resolveFolderImage = function(path)
            H.eq(path, box.path); folder_lookups = folder_lookups + 1; return "/folder.png"
        end,
        resolveStackImage = function() series_lookups = series_lookups + 1; return "/wrong.png" end,
        imageSizeTag = function() return "200x300" end,
        loadImageNative = function(path) H.eq(path, "/folder.png"); return cached end,
    }
    local w = Painter:new{entry = {book = box, series_box = shape}, width = shape.w, height = 400,
        callbacks = {
            on_folder_tap = function(b) H.eq(b, box); taps = taps + 1 end,
            on_folder_hold = function(b) H.eq(b, box); holds = holds + 1 end,
            on_series_tap = function() error("not a metadata series") end,
            on_series_hold = function() error("not a series menu") end,
        }}
    H.eq(w:onTap(), true); H.eq(w:onDoubleTap(), true); H.eq(w:onHold(), true)
    H.eq(taps, 2); H.eq(holds, 1)
    local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
    H.eq(folder_lookups, 1); H.eq(series_lookups, 0); H.eq(w.custom_path, "/folder.png")
    H.eq(bb.blits, 1); w:free(); H.eq(cached.freed, nil)
    package.loaded["lib/bookshelf_image_source"] = nil
end)

H.test("native box gestures still open the group rather than its first volume", function()
    local w, box = visibleBox(members(3))
    local taps, holds = 0, 0
    w.callbacks = {on_series_tap = function(g) H.eq(g, box); taps = taps + 1 end,
        on_series_hold = function(g) H.eq(g, box); holds = holds + 1 end}
    H.eq(w:onTap(), true); H.eq(w:onDoubleTap(), true); H.eq(w:onHold(), true)
    H.eq(taps, 2); H.eq(holds, 1)
end)

H.test("custom series images fit their decoded aspect and keep cache ownership", function()
    for _, aspect in ipairs({.5, 1, 1.5, 3}) do
        local cached = surface(200, 200 * aspect)
        package.loaded["lib/bookshelf_image_source"] = {
            resolveStackImage = function(kind, name) H.eq(kind, "series"); H.eq(name, "Saga"); return "/series.png" end,
            imageSizeTag = function() return "100x150" end, -- stale metadata
            loadImage = function(_, width, height) return surface(width, height) end,
            loadImageNative = function(path) H.eq(path, "/series.png"); return cached end,
        }
        local w = visibleBox(members(3)); local bb = surface(w.width, 400)
        allocated = {}; w:paintTo(bb, 0, 0)
        H.eq(bb.blits, 1); H.eq(#allocated, 1); assert(allocated[1].freed)
        H.eq(cached.freed, nil)
        local c = bb.copies[1]
        assert(math.min(math.abs(c.h - c.w * aspect), math.abs(c.w - c.h / aspect)) <= .5)
        H.eq(c.sx, 0); H.eq(c.sy, 0)
        assert(bb.texts[1].y + bb.texts[1].h < c.y)
    end
    package.loaded["lib/bookshelf_image_source"] = nil
end)

H.test("broken custom lookups and decodes fall back without stretching the book", function()
    for _, failure in ipairs({"lookup", "size", "decode", "missing"}) do
        local ready = false
        local cached = surface(200, 100)
        package.loaded["lib/bookshelf_image_source"] = {
            resolveStackImage = function()
                if failure == "lookup" then error("lookup failed") end
                return "/series.png"
            end,
            imageSizeTag = function()
                if failure == "size" then error("bad header") end
                return "200x100"
            end,
            loadImageNative = function()
                if ready then return cached end
                if failure == "decode" then error("decode failed") end
                return nil
            end,
        }
        local w = visibleBox(members(3)); local bb = surface(w.width, 400)
        w:paintTo(bb, 0, 0); H.eq(bb.blits, 1)
        local c = bb.copies[1]
        assert(math.min(math.abs(c.h - c.w * cover_aspect), math.abs(c.w - c.h / cover_aspect)) <= .5)
        H.eq(c.sx, W.CARD_BORDER)
        if failure ~= "lookup" then
            ready = true; w:paintTo(bb, 0, 0); H.eq(bb.blits, 2)
            c = bb.copies[2]; assert(math.abs(c.h - c.w * .5) <= .5)
            ready = false; w:paintTo(bb, 0, 0); H.eq(bb.blits, 3)
        end
        H.eq(cached.freed, nil)
    end
    package.loaded["lib/bookshelf_image_source"] = nil
end)

H.test("custom image paint errors release the scaled copy but not the cached source", function()
    local cached = surface(100, 150)
    package.loaded["lib/bookshelf_image_source"] = {
        resolveStackImage = function() return "/series.png" end,
        imageSizeTag = function() return "100x150" end,
        loadImageNative = function() return cached end,
    }
    local w = visibleBox(members(3)); local bb = surface(w.width, 400)
    local blit = bb.blitFrom
    bb.blitFrom = function() error("framebuffer blit failed") end
    allocated = {}; w:paintTo(bb, 0, 0)
    H.eq(#allocated, 1); assert(allocated[1].freed); H.eq(cached.freed, nil)
    bb.blitFrom = blit; w:paintTo(bb, 0, 0); H.eq(bb.blits, 1)
    assert(allocated[2].freed); H.eq(cached.freed, nil)
    package.loaded["lib/bookshelf_image_source"] = nil
end)

local STAR, REGISTRY = "\xE2\x98\x85", "bookshelf_folder_badge_providers"
local function ratedBox(n, scale, name, position)
    local raw = members(n or 3)
    for _, b in ipairs(raw) do b.filepath = "/Manga/Saga/" .. b.filename end
    return visibleBox(raw, scale, name, position)
end
local function ratingProvider(text)
    package.loaded["lib/bookshelf_cover_progress"] = {
        badgeSize = function(n) return n * dpi end,
    }
    package.loaded[REGISTRY] = {myanimelist = function(folder)
        H.eq(folder.path, "/Manga/Saga"); H.eq(folder.label, "Saga")
        return {text = text or STAR .. "8.72"}
    end}
end
local function ratingRect(bb)
    for _, t in ipairs(bb.texts) do if t.text:sub(1, #STAR) == STAR then return t end end
end
local function sameColor(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    return a.r == b.r and a.g == b.g and a.b == b.b
end

H.test("MAL notch fits native boxes without colliding with read-total, hidden count or title", function()
    ratingProvider()
    for _, factor in ipairs({1, 1.5, 2, 3}) do
        dpi = factor
        for _, n in ipairs({2, 8, 120}) do
            local raw = members(n)
            statuses = {}
            for _, b in ipairs(raw) do
                b.filepath = "/Manga/Saga/" .. b.filename
                statuses[b.filepath] = "finished"
            end
            for _, dark in ipairs({false, true}) do
                night = dark
                for _, aspect in ipairs({.5, 1, 1.5, 3}) do
                    cover_aspect = aspect
                    local w, box, shape = visibleBox(raw, .75)
                    local sw, sh, bw, bh = w.st_w, w.st_h, shape.w, shape.h
                    local bb = surface(w.width + 40, 420); w:paintTo(bb, 20, 10)
                    H.eq(w.st_w, sw); H.eq(w.st_h, sh); H.eq(shape.w, bw); H.eq(shape.h, bh)
                    H.eq(#box.books, n); H.eq(bb.texts[1].text, count(n, n))
                    local badge, cover = ratingRect(bb), bb.copies[1]
                    assert(cover, "rating must not suppress a completed series' cover")
                    if badge then
                        H.eq(bb.texts[#bb.texts].text, STAR .. "8.72")
                        assert(sameColor(badge.ink, bb.texts[1].ink), "rating must use the box's native ink")
                        assert(badge.x >= cover.x and badge.y >= cover.y)
                        assert(badge.x + badge.w <= cover.x + cover.w)
                        assert(badge.y + badge.h <= cover.y + cover.h)
                        for i = 1, #bb.texts - 1 do
                            local t = bb.texts[i]
                            assert(t.y + t.h <= badge.y or t.y >= badge.y + badge.h,
                                "rating collided with existing label")
                        end
                        local board = package.loaded["lib/bookshelf_spine_shelf"].boardColor()
                        for row = 0, badge.h - 1 do
                            assert(sameColor(bb:colorAt(badge.x, badge.y + row), board))
                            assert(sameColor(bb:colorAt(badge.x + badge.w - 1, badge.y + row), board),
                                "rating reaches the curved cover edge")
                        end
                    elseif dpi == 1 and aspect == 1.5 then
                        error("ordinary box should have room for its rating")
                    end
                    w:free()
                end
            end
        end
    end
    dpi, night, cover_aspect, statuses = 1, false, 1.5, {}
    package.loaded[REGISTRY] = nil
end)

H.test("the left cutout mirrors the upstream right count notch including its light edge", function()
    package.loaded[REGISTRY] = nil
    Painter.preserve_cover_aspect = false
    local w = visibleBox(members(8))
    Painter.preserve_cover_aspect = true
    w.preserve_cover_aspect = false
    w.stickerLeftLabel = function() return w.count end
    local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
    local sx, sy = w.inset, w.top + w.shape.rise + w.inset
    for row = 0, w.st_h - 1 do
        for col = 0, w.st_w - 1 do
            assert(sameColor(bb:colorAt(sx + col, sy + row), bb:colorAt(sx + w.st_w - 1 - col, sy + row)),
                "left notch is not the mirrored upstream stencil")
        end
    end
    w:free()
end)

H.test("rounded notch follows text width and restores cover pixels when a score disappears", function()
    local w = ratedBox()
    local sx, sy = w.inset + w.st_dx, w.top + w.shape.rise + w.inset + w.st_dy
    ratingProvider()
    local rated = surface(w.width, 400); w:paintTo(rated, 0, 0)
    local label = assert(ratingRect(rated))
    local gap = 3
    local nw, nh = label.w + 2 * gap, label.h + gap
    local board = rated:colorAt(sx, sy)
    assert(sameColor(rated:colorAt(sx + nw + 1, sy), board))
    assert(not sameColor(rated:colorAt(sx + nw + 1, sy + 5), board), "top transition is not rounded")
    assert(sameColor(rated:colorAt(sx + nw - 2, sy + nh - 5), board))
    assert(not sameColor(rated:colorAt(sx + nw - 2, sy + nh - 1), board), "inner transition is not rounded")
    H.eq(rated:colorAt(sx + gap, sy + nh + 6), "cover", "mask should end below the notch")

    ratingProvider(STAR .. "10.00")
    local perfect = surface(w.width, 400); w:paintTo(perfect, 0, 0)
    local wider = assert(ratingRect(perfect)); assert(wider.w > label.w)
    assert(sameColor(perfect:colorAt(sx + nw + 2, sy + 5), board))
    H.eq(w.st_h, rated.copies[1].h + 2); H.eq(w.st_w, rated.copies[1].w + 2)

    package.loaded[REGISTRY] = nil
    local plain = surface(w.width, 400); w:paintTo(plain, 0, 0)
    H.eq(ratingRect(plain), nil); H.eq(w._orbitui_rating_label, nil)
    H.eq(plain:colorAt(label.x + 1, label.y + 2), "cover")
    H.eq(#plain.copies, 1); H.eq(#rated.copies, 1)
    w:free()
end)

H.test("small covers omit both text and notch without reducing the image", function()
    for _, aspect in ipairs({.08, 1.5, 8}) do
        cover_aspect = aspect
        local w = ratedBox(3, .5)
        package.loaded[REGISTRY] = nil
        local plain = surface(w.width, 400); w:paintTo(plain, 0, 0)
        ratingProvider()
        package.loaded["lib/bookshelf_cover_progress"].badgeSize = function() return 50 end
        local tiny = surface(w.width, 400); w:paintTo(tiny, 0, 0)
        H.eq(ratingRect(tiny), nil); H.eq(#tiny.rects, #plain.rects)
        for i, rect in ipairs(plain.rects) do
            local actual = tiny.rects[i]
            H.eq(actual.x, rect.x); H.eq(actual.y, rect.y); H.eq(actual.w, rect.w); H.eq(actual.h, rect.h)
            assert(sameColor(actual.color, rect.color))
        end
        w:free()
    end
    cover_aspect = 1.5
    package.loaded[REGISTRY] = nil
end)

H.test("night-mode changes reuse the label with the same ink as the series name and count", function()
    ratingProvider()
    local w = ratedBox(); local cached
    for _, dark in ipairs({false, true, false}) do
        night = dark
        local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
        local label = assert(ratingRect(bb))
        cached = cached or w._orbitui_rating_label
        H.eq(w._orbitui_rating_label, cached)
        for _, t in ipairs(bb.texts) do assert(sameColor(t.ink, label.ink)) end
        H.eq(label.ink.r, dark and 30 or 246)
    end
    w:free(); night = false; package.loaded[REGISTRY] = nil
end)

H.test("custom-image refits and missing images move the notch with the current fitted cover", function()
    ratingProvider()
    local cached = surface(300, 150)
    package.loaded["lib/bookshelf_image_source"] = {
        resolveStackImage = function() return "/series.png" end,
        imageSizeTag = function() return "100x150" end,
        loadImageNative = function() return cached end,
    }
    local w = ratedBox()
    for _, aspect in ipairs({.5, 1.5, 3, 1}) do
        cached = surface(200, 200 * aspect)
        local bb = surface(w.width + 40, 420); w:paintTo(bb, 20, 10)
        local label = assert(ratingRect(bb))
        H.eq(label.x, 20 + w.inset + w.st_dx + 3)
        H.eq(label.y, 10 + w.top + w.shape.rise + w.inset + w.st_dy + 1)
        local cover = bb.copies[1]
        assert(math.min(math.abs(cover.h - cover.w * aspect), math.abs(cover.w - cover.h / aspect)) <= .5)
        H.eq(cached.freed, nil)
    end
    cached = nil
    local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
    H.eq(bb.blits, 1); assert(ratingRect(bb)); H.eq(bb.copies[1].sx, W.CARD_BORDER)
    H.eq(w.st_h, w.art_cover.height)
    w:free(); package.loaded[REGISTRY] = nil
    package.loaded["lib/bookshelf_image_source"] = nil
end)

H.test("overlay titles reclaim the name strip and anchor aspect-true covers at the foot", function()
    for _, factor in ipairs({1,1.5,2,3}) do
        dpi=factor
        for _, aspect in ipairs({.5,1,1.5,3}) do
            cover_aspect=aspect
            for _, n in ipairs({2,8,120}) do
                local plain=visibleBox(members(n))
                local w,_,shape=visibleBox(members(n),1,nil,"overlay")
                H.eq(shape.w,plain.shape.w); H.eq(shape.h,plain.shape.h)
                H.eq(#shape.spines,#plain.shape.spines); H.eq(shape.hidden_count,plain.shape.hidden_count)
                H.eq(w.art_h,plain.art_h+shape.strip_h)
                H.eq(w.st_dy+w.st_h,w.art_h)
                local bb=surface(w.width+40,420); w:paintTo(bb,20,10)
                local c=assert(bb.copies[1]); H.eq(bb.blits,1)
                assert(c.h>=plain.st_h-2, "removing the name strip must not shrink the image")
                assert(math.min(math.abs(c.h-c.w*aspect),math.abs(c.w-c.h/aspect))<=.5)
                H.eq(c.y+c.h,10+w.top+shape.rise+shape.front_h-w.inset-1)
                for _, t in ipairs(bb.texts) do
                    if t.text=="Saga" then
                        assert(t.x>=c.x and t.x+t.w<=c.x+c.w)
                        assert(t.y>=c.y and t.y+t.h<=c.y+c.h)
                        H.eq(bb:colorAt(t.x,t.y).r,90)
                    end
                end
                plain:free(); w:free()
            end
        end
    end
    dpi,cover_aspect=1,1.5
end)

H.test("long overlay titles fit on a plate without obscuring counts or MAL notches", function()
    local titles={"Saga", "Om utr\195\164kning av omf\195\165ng",
        "A very long series name that needs two lines and may be truncated",
        "\230\151\165\230\156\172\232\170\158\227\129\174\227\130\191\227\130\164\227\131\136\227\131\171"}
    for _, title in ipairs(titles) do
        for _, dark in ipairs({false,true}) do
            night=dark
            for _, scale in ipairs({.5,1,1.5}) do
                local raw=members(120)
                statuses={}; for _, b in ipairs(raw) do statuses[b.filepath]="finished" end
                local w=visibleBox(raw,scale,title,"overlay")
                package.loaded["lib/bookshelf_cover_progress"]={badgeSize=function(n) return n end}
                package.loaded[REGISTRY]={myanimelist=function() return {text=STAR.."8.72"} end}
                local bb=surface(w.width,400); w:paintTo(bb,0,0)
                local c=assert(bb.copies[1]); local badge=ratingRect(bb)
                local count_seen, title_seen=false,false
                for _, t in ipairs(bb.texts) do
                    if t.text==count(120,120) then
                        count_seen=true; assert(t.y+t.h<c.y)
                    elseif t.text~="+"..w.shape.hidden_count and t~=badge then
                        title_seen=true
                        assert(t.x>=c.x and t.x+t.w<=c.x+c.w)
                        assert(t.y>=c.y and t.y+t.h<=c.y+c.h)
                        if badge then assert(t.y>=badge.y+badge.h) end
                        H.eq(t.ink.r,dark and 30 or 246)
                    end
                end
                assert(count_seen); assert(title_seen,"ordinary boxes need a visible title")
                local edge=bb:colorAt(c.x+math.floor(c.w/2),c.y+c.h)
                assert(not sameColor(edge,bb:colorAt(c.x+math.floor(c.w/2),c.y+c.h-1)),
                    "the title band must preserve the light bottom border")
                w:free()
            end
        end
    end
    statuses,night={},false; package.loaded[REGISTRY]=nil
end)

H.test("custom-image refits rebuild cached title text and tiny images omit it safely", function()
    local cached=surface(200,300)
    package.loaded["lib/bookshelf_image_source"]={
        resolveStackImage=function() return "/custom.png" end,
        imageSizeTag=function() return "200x300" end,
        loadImageNative=function() return cached end,
    }
    local w=visibleBox(members(3),1,"Long series name","overlay")
    local previous
    for _, aspect in ipairs({1.5,.5,3,.05,1.5}) do
        cached=surface(200,200*aspect)
        local bb=surface(w.width,400); w:paintTo(bb,0,0)
        H.eq(bb.blits,1); H.eq(cached.freed,nil)
        local c=bb.copies[1]
        H.eq(c.y+c.h,w.top+w.shape.rise+w.shape.front_h-w.inset-1)
        local lines=w._orbitui_series_title_lines
        if aspect==.05 then H.eq(lines,nil) else assert(lines); assert(lines~=previous) end
        previous=lines
    end
    local lines=w._orbitui_series_title_lines
    local bb=surface(w.width,400); w:paintTo(bb,0,0)
    H.eq(w._orbitui_series_title_lines,lines)
    night=true; w:paintTo(bb,0,0); H.eq(w._orbitui_series_title_lines,lines)
    for _, ln in ipairs(lines) do H.eq(ln.fgcolor.r,30) end
    night=false; w:free(); H.eq(w._orbitui_series_title_lines,nil)
    package.loaded["lib/bookshelf_image_source"]=nil
end)

H.test("overlay text resources are released once on refit reinit and teardown", function()
    local free=Text.free
    Text.free=function(self) self.free_count=(self.free_count or 0)+1 end
    local w=visibleBox(members(3),1,"Saga","overlay")
    local bb=surface(w.width,400); w:paintTo(bb,0,0)
    local first=w._orbitui_series_title_lines
    assert(first)
    require("adapters/orbitui_series_titles").boxWidget(Painter)
    w:paintTo(bb,0,0); H.eq(w._orbitui_series_title_lines,first)
    H.eq(first[1].free_count,nil)
    w:init(); for _,ln in ipairs(first) do H.eq(ln.free_count,1,"reinit frees old title") end
    w:paintTo(bb,0,0)
    local second=w._orbitui_series_title_lines; assert(second~=first)
    w.first_look.aspect=.5; w:paintTo(bb,0,0)
    for _,ln in ipairs(second) do H.eq(ln.free_count,1,"refit frees old title") end
    local third=w._orbitui_series_title_lines; assert(third~=second)
    w:free(); for _,ln in ipairs(third) do H.eq(ln.free_count,1,"teardown frees title") end
    w:free(); for _,ln in ipairs(third) do H.eq(ln.free_count,1,"teardown must not double free") end
    Text.free,cover_aspect=free,1.5
end)

-- Optional shape-only preview from the real stencil, not device fonts/covers.
local title_preview = os.getenv("ORBITUI_SERIES_TITLE_PREVIEW")
local preview = title_preview or os.getenv("ORBITUI_RATING_PREVIEW")
if preview then
    local out = assert(io.open(preview, "w"))
    local function color(c)
        if c == "cover" then return "url(#cover)" end
        if type(c) == "table" then return string.format("rgb(%d,%d,%d)", c.r, c.g, c.b) end
        return "#353b42"
    end
    local function esc(s) return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;") end
    local preview_h = title_preview and 1400 or 600
    out:write(string.format('<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="%d" viewBox="0 0 1400 %d">', preview_h, preview_h))
    out:write('<defs><pattern id="cover" width="30" height="30" patternUnits="userSpaceOnUse">')
    out:write('<rect width="30" height="30" fill="#dec9a1"/><path d="M0 0L30 30M-15 0L15 30M15 0L45 30" stroke="#b99666" stroke-width="2"/>')
    out:write(string.format('</pattern></defs><rect width="1400" height="%d" fill="#f1ede4"/>', preview_h))
    out:write('<text x="25" y="30" font-size="18" fill="#202830">Native paint calls; placeholder artwork and approximate fonts</text>')
    local samples = title_preview and {
        {title="Below (existing)",score="8.72"},
        {title="On cover",score="8.72",position="overlay"},
        {title="Long series title",name="A very long series title",position="overlay"},
        {title="Landscape cover",aspect=.6,position="overlay"},
    } or {{title = "No rating"}, {title = "Rating 8.72", score = "8.72"},
        {title = "Rating 10.00", score = "10.00"}, {title = "Landscape cover", score = "8.72", aspect = .6}}
    for i, spec in ipairs(samples) do
        cover_aspect = spec.aspect or 1.5
        if spec.score then ratingProvider(STAR .. spec.score) else package.loaded[REGISTRY] = nil end
        local w = ratedBox(nil, nil, spec.name, spec.position)
        local bb = surface(w.width, 400); w:paintTo(bb, 0, 0)
        local x = title_preview and ((i - 1) % 2 * 690 + 40) or ((i - 1) * 345 + 25)
        local y = title_preview and (math.floor((i - 1) / 2) * 650 + 90) or 90
        out:write(string.format('<text x="%d" y="%d" font-size="20" fill="#202830">%s</text>', x, y - 25, spec.title))
        out:write(string.format('<g transform="translate(%d,%d) scale(2)"><g transform="translate(0,%g)">', x, y, -w.top))
        for _, rect in ipairs(bb.rects) do
            if rect.color ~= "text" then
                out:write(string.format('<rect x="%g" y="%g" width="%g" height="%g" fill="%s"/>',
                    rect.x, rect.y, rect.w, rect.h, color(rect.color)))
            end
        end
        for _, t in ipairs(bb.texts) do
            out:write(string.format('<text x="%g" y="%g" font-size="%g" font-family="sans-serif" font-weight="600" textLength="%g" lengthAdjust="spacingAndGlyphs" fill="%s">%s</text>',
                t.x, t.y + t.h * .8, t.h, t.w, color(t.ink), esc(t.text)))
        end
        out:write('</g></g>')
        w:free()
    end
    out:write('</svg>'); out:close()
    cover_aspect = 1.5; package.loaded[REGISTRY] = nil
end

H.test("preset switches repaginate real native box lists and restore singleton and per-chip choices", function()
    local A = require("adapters/orbitui_appearance")
    local policy = { version = 1, preset = "classic" }
    A.prepare({ readSetting = function() return policy end }, false)
    metas = {}
    tab = { source = { kind = "folder" }, series_boxes = true }
    local raw = { book(100), book(101, "Solo"), book(102, "Pair"), book(103, "Pair") }
    local w = widget(raw)
    A.widget(w)
    local items = w:_spineCachedFetch(100)
    H.eq(#items, 3); H.eq(Boxes.isBox(items[2]), true); H.eq(items[2].book_count, 1)
    policy.preset = "native"
    items = w:_spineCachedFetch(100)
    H.eq(#items, 3); H.eq(items[2], raw[2]); H.eq(Boxes.isBox(items[3]), true)
    local jumped = w:_jumpScanList(); H.eq(#jumped, 3); H.eq(jumped[2], raw[2])
    policy.preset = "minimal"
    H.eq(w:_spineCachedFetch(100), raw); H.eq(w:_jumpScanList(), raw)
    policy.preset = "native"; tab.series_boxes = false
    H.eq(w:_spineCachedFetch(100), raw)
    policy.preset = "classic"; H.eq(#w:_spineCachedFetch(100), 3)
    H.eq(tab.series_boxes, false); H.eq(raw[2]._series_box, nil)
end)

H.finish()
