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
        w[name] = method(name, {Repo = Repo, SPINE_ALL_LIMIT = 10000})
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

H.test("a one-volume series remains an ordinary book as upstream intends", function()
    local lone = book(1, "Saga")
    local w = widget({lone, book(0)})
    local items = w:_spineCachedFetch(100)
    H.eq(items[1], lone); H.eq(Boxes.isBox(items[1]), false)
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
-- completion overlay: upstream owns the marks on the exposed member spines.
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
    bb.texts[#bb.texts + 1] = {text = self.text, x = x, y = y, w = self.dimen.w, h = self.dimen.h}
end
local allocated, scaled = {}, 0
local function surface(w, h)
    local bb = {w = w, h = h, blits = 0, texts = {}, copies = {}}
    function bb:paintRectRGB32(x, y, rw, rh)
        assert(x >= 0 and y >= 0 and rw >= 0 and rh >= 0
            and x + rw <= self.w and y + rh <= self.h, "paint outside buffer")
    end
    function bb:blitFrom(srcbb, x, y, sx, sy, rw, rh)
        self:paintRectRGB32(x, y, rw, rh)
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
    cachedProgress = function() return nil end, _SpineBookSlot = Slot,
    bookLook = function() return {r = 90, g = 120, b = 80, aspect = cover_aspect} end,
    boardColor = function() return {r = 90, g = 120, b = 80} end,
}
local Painter = require("lib/bookshelf_series_box_widget")
local function visibleBox(raw, scale, name)
    scale = scale or 1
    local box = Boxes.box(raw, name or "Saga")
    local shape = Boxes.geometry(box, {w = 160 * scale, h = 248 * scale,
        face_h = 240 * scale, depth = 8 * scale}, {content_w = 800})
    local w = Painter:new{entry = {book = box, series_box = shape}, width = shape.w, height = 400}
    return w, box, shape
end
local function count(done, total) return done .. "\xE2\x80\x8A/\xE2\x80\x8A" .. total end

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
    H.eq(Boxes.SLIPCASE_MIN_SHARE, .7); H.eq(Painter.preserve_cover_aspect, true)
end)

H.test("box width stays between seventy percent and the existing cover cap", function()
    local previous = 0
    for _, n in ipairs({2, 3, 8, 120}) do
        local _, _, shape = visibleBox(members(n))
        assert(shape.w >= math.floor(160 * .7) and shape.w <= 160)
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
                allocated, scaled = {}, 0
                local bb = surface(shape.w, 400); w:paintTo(bb, 0, 0)
                H.eq(bb.blits, 1); H.eq(scaled, 0); H.eq(#allocated, 1)
                assert(allocated[1].freed)
                local copy = bb.copies[1]
                H.eq(copy.sx, W.CARD_BORDER); H.eq(copy.sy, W.CARD_BORDER)
                H.eq(copy.w, iw); H.eq(copy.h, ih)
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
        for i = 2, #bb.texts do
            local name = bb.texts[i]
            assert(cover.y + cover.h < name.y)
            assert(math.abs(name.x + name.w / 2 - (20 + shape.w / 2)) <= .5)
        end
        H.eq(#bb.texts, 3)
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
    local w = visibleBox(members(3)); local bb = surface(w.width, 400)
    allocated, fail_cover = {}, true
    w:paintTo(bb, 0, 0); H.eq(bb.blits, 0); H.eq(#allocated, 1)
    assert(allocated[1].freed)
    fail_cover = false
    w:paintTo(bb, 0, 0); H.eq(bb.blits, 1); assert(allocated[2].freed)
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
                H.eq(shape.style, "slipcase"); H.eq(#shape.spines, math.min(n, 8))
                H.eq(#box.books, n); H.eq(w.all_read, nil); H.eq(w.fade_amount, nil)
                painted_slots = 0; before = reads
                local bb = surface(shape.w, 400)
                w:paintTo(bb, 0, 0); w:paintTo(bb, 0, 0)
                H.eq(bb.blits, 2); H.eq(painted_slots, 2 * math.min(n, 8))
                H.eq(reads, before)
            end
        end
    end
    night = false
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

H.finish()
