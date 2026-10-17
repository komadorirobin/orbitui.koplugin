package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Adapter = require("adapters/orbitui_series_boxes")
local Boxes = require("lib/bookshelf_series_boxes")
local Layout = require("lib/bookshelf_spine_layout")
local dpi, facts, markers, queries = 1, {}, {}, 0
local Screen = {scaleBySize = function(_, n) return math.floor(n * dpi + .5) end}
package.loaded.device = {screen = Screen}
package.loaded["lib/bookshelf_spine_shelf"] = {
    cachedPageCount = function(fp)
        queries = queries + 1
        local row = facts[fp] or {}
        return row.pages, row.source
    end,
    cachedProgress = function()
        assert(not Boxes.packSpines, "width must not validate or invalidate reading status")
    end,
    titleSize = function() return 12 end,
    textHeight = function(size) return size end,
}
package.loaded["lib/bookshelf_book_repository"] = {
    pageCountFromFilename = function(fp) return markers[fp] end,
    readProgress = function() error("geometry must not read every sidecar") end,
    buildBookMeta = function() error("geometry must not decode or hydrate every member") end,
}
package.loaded["lib/bookshelf_fonts"] = {
    getFace = function(_, _, size) return {size = size} end,
    getUIFontFace = function() return "cfont" end,
}
local Text = H.widget()
function Text:getSize() return {w = #self.text * self.face.size / 2, h = self.face.size} end
function Text:free() end
package.loaded["lib/bookshelf_colour_text"] = Text

local function book(pages, ext, tag)
    return {filepath = "/books/book." .. (ext or "cbz"), page_count = pages, _page_src = tag}
end
local function members(n, pages)
    local books = {}
    for i = 1, n do books[i] = {filepath = "/books/" .. i .. ".cbz", page_count = pages} end
    return {_series_box = true, series_name = "Saga", books = books}
end
local function shape(box, width, opts)
    return Boxes.geometry(box, {w = width or 160, h = 248, aspect = 1.5}, opts or {row_h = 240})
end
local function natural(pages, auto)
    return Screen:scaleBySize(math.max(8, Layout.spineWidthDp(pages) * (auto or 1)))
end

H.test("partial filling is host-only and does not change standalone box packing", function()
    local raw = members(2, 200)
    H.eq(Boxes.packSpines, nil)
    local old = shape(raw)
    H.eq(old.spines[1].w + old.spines[2].w, old.w - 2 * old.wall)
    H.eq(old.occupied_w, nil); H.eq(old.hidden_count, nil)
    require("adapters/orbitui_ui").wrap("lib/bookshelf_series_boxes", Boxes)
    H.eq(Boxes.packSpines, Adapter.packSpines)
    local new = shape(raw)
    H.eq(new.spines[1].w, natural(200)); H.eq(new.spines[2].w, natural(200))
    H.eq(new.occupied_w, 2 * natural(200)); H.eq(new.hidden_count, 0)
    assert(new.occupied_w < new.w - 2 * new.wall)
end)

H.test("a volume keeps its width across short long and title-widened boxes", function()
    for _, n in ipairs({2, 3, 6, 8, 120}) do
        for _, title in ipairs({"Saga", ("Very long series name "):rep(6)}) do
            local box = members(n, 200); box.series_name = title
            local g = shape(box)
            for _, spine in ipairs(g.spines) do H.eq(spine.w, natural(200)) end
            assert(g.w >= 136 and g.w <= 160)
            H.eq(g.h, 248); H.eq(g.front_h + g.rise, g.h)
        end
    end
end)

H.test("long series keep a whole prefix rather than squeezing or skipping members", function()
    local box = members(120, 200)
    box.books[3].page_count = 1000
    local g = shape(box)
    local x = 0
    for i, spine in ipairs(g.spines) do
        H.eq(spine.member, i); H.eq(spine.x, x)
        H.eq(spine.w, natural(box.books[i].page_count))
        x = x + spine.w
    end
    H.eq(g.occupied_w, x); H.eq(g.hidden_count, 120 - #g.spines)
    assert(x <= g.w - 2 * g.wall)
    assert(x + natural(box.books[#g.spines + 1].page_count) > g.w - 2 * g.wall)
    H.eq(#box.books, 120); H.eq(box.books[3].page_count, 1000)
end)

H.test("visible spines remain bounded to eight even in a very wide box", function()
    queries = 0
    local g = shape(members(120, 60), 1000)
    H.eq(#g.spines, 8); H.eq(g.hidden_count, 112)
    H.eq(queries, 8)
    H.eq(g.occupied_w, 8 * natural(60))
end)

H.test("known equal page counts stay equal and thicker volumes remain thicker", function()
    local box = members(5, 200)
    box.books[2].page_count = 600
    local g = shape(box)
    H.eq(#g.spines, 5)
    H.eq(g.spines[1].w, g.spines[3].w)
    assert(g.spines[2].w > g.spines[1].w)
    local fewer = shape({books = {box.books[1], box.books[2]}, _series_box = true, series_name = "Other"})
    H.eq(fewer.spines[1].w, g.spines[1].w); H.eq(fewer.spines[2].w, g.spines[2].w)
end)

H.test("only comparable counts set reflowable widths; reading layout is ignored", function()
    local b = book(900, "epub", "render")
    for _, source in ipairs({"render", "user", "layout", "scan", "unknown"}) do
        facts[b.filepath] = {pages = 1200, source = source}
        H.eq(Adapter.memberSpineWidth(b, 1, {}), natural(nil))
    end
    facts[b.filepath] = {pages = 1200}
    H.eq(Adapter.memberSpineWidth(b, 1, {}), natural(nil))
    for _, source in ipairs({"print", "stable", "calibre", "filename"}) do
        facts[b.filepath] = {pages = 200, source = source}
        H.eq(Adapter.memberSpineWidth(b, 1, {}), natural(200))
        facts[b.filepath] = nil; b._page_src = source; b.page_count = 200
        H.eq(Adapter.memberSpineWidth(b, 1, {}), natural(200))
    end
    facts = {}
end)

H.test("fixed-layout and explicit filename counts work without scanning or state writes", function()
    for _, ext in ipairs({"cbz", "CBR", "PDF", "djvu"}) do
        H.eq(Adapter.memberSpineWidth(book(200, ext), 1, {}), natural(200))
    end
    local b = book(nil, "epub")
    markers[b.filepath] = 400
    H.eq(Adapter.memberSpineWidth(b, 1, {}), natural(400)); H.eq(b.page_count, nil)
    facts[b.filepath] = {pages = 200, source = "stable"}
    H.eq(Adapter.memberSpineWidth(b, 1, {}), natural(200))
    H.eq(facts[b.filepath].source, "stable"); H.eq(markers[b.filepath], 400)
    facts, markers = {}, {}
end)

H.test("missing malformed and nonfinite counts have one neutral bounded fallback", function()
    for _, value in ipairs({false, "bad", 0, -1, 0/0, math.huge}) do
        H.eq(Adapter.memberSpineWidth(book(value), 1, {}), natural(nil))
    end
    H.eq(Adapter.memberSpineWidth(book(nil), 1, {}), natural(nil))
    H.eq(Adapter.memberSpineWidth(book("200"), 1, {}), natural(200))
    H.eq(Adapter.memberSpineWidth(book(999999), 1, {}), natural(1200))
end)

H.test("completion and changing rendered page counts cannot inflate the box contents", function()
    local b = book(700, "epub", "render")
    for _, status in ipairs({"new", "reading", "finished"}) do
        facts[b.filepath] = {pages = status == "finished" and 1400 or 500,
            source = "render", status = status}
        H.eq(Adapter.memberSpineWidth(b, 1, {}), natural(nil))
        H.eq(facts[b.filepath].status, status)
    end
    facts = {}
end)

H.test("the same DPI row-height and thickness calibration applies across boxes", function()
    for _, scale in ipairs({1, 1.5, 2, 3}) do
        dpi = scale
        for _, row in ipairs({160, 240, 400}) do
            for _, pct in ipairs({40, 100, 180, 300}) do
                local opts = {row_h = row * dpi, thickness_pct = pct}
                local a, b = shape(members(2, 200), 160 * dpi, opts), shape(members(120, 200), 160 * dpi, opts)
                local expected = natural(200, Layout.autoThickness(row) * pct / 100)
                for _, g in ipairs({a, b}) do
                    for _, spine in ipairs(g.spines) do H.eq(spine.w, expected) end
                    assert(g.occupied_w <= g.w - 2 * g.wall)
                end
            end
        end
    end
    dpi = 1
    for _, pct in ipairs({0, 39, 301, math.huge, "bad"}) do
        H.eq(Adapter.memberSpineWidth(book(200), 1, {thickness_pct = pct}), natural(200))
    end
end)

H.test("a too-narrow box omits a spine rather than clipping it or skipping ahead", function()
    local box = members(2, 1200); box.books[2].page_count = 60
    local g = shape(box, 30)
    H.eq(#g.spines, 0); H.eq(g.occupied_w, 0); H.eq(g.hidden_count, 2)
    H.eq(#box.books, 2)
    for _, col in ipairs(Boxes.shadowColumns(g, 10)) do H.eq(col.h, g.front_h + g.wall_top) end
end)

H.test("empty space casts a low box shadow rather than a phantom book shadow", function()
    local g = shape(members(2, 200))
    local cols = Boxes.shadowColumns(g, 10)
    H.eq(#cols, 4)
    H.eq(cols[2].w, g.occupied_w); H.eq(cols[2].h, g.h)
    H.eq(cols[3].x, 10 + g.wall + g.occupied_w)
    H.eq(cols[3].w, g.w - 2 * g.wall - g.occupied_w)
    H.eq(cols[3].h, g.front_h + g.wall_top)
    local x = 10
    for _, col in ipairs(cols) do H.eq(col.x, x); assert(col.w > 0); x = x + col.w end
    H.eq(x, 10 + g.w)
end)

H.test("native width-only cache access does not validate status or discard page counts", function()
    local file = assert(io.open("components/bookshelf/lib/bookshelf_spine_shelf.lua"))
    local src = file:read("*a"); file:close()
    local body = assert(src:match("function SpineShelf.cachedPageCount%(fp%)\n(.-)\nend"))
    local rows = {book = {p = 200, psrc = "print", m = 999, s = "finished", sk = false}}
    local env = {_facts = function() return {get = function(fp) return rows[fp] end} end}
    local code = "return function(fp)\n" .. body .. "\nend"
    local chunk
    if setfenv then chunk = assert(loadstring(code)); setfenv(chunk, env)
    else chunk = assert(load(code, "cached pages", "t", env)) end
    local get = chunk()
    local pages, source = get("book")
    H.eq(pages, 200); H.eq(source, "print")
    H.eq(rows.book.m, 999); H.eq(rows.book.sk, false); H.eq(rows.book.s, "finished")
    H.eq(get(nil), nil); H.eq(get("missing"), nil)
end)

H.finish()
