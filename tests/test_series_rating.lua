package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Rating = require("adapters/orbitui_series_rating")
local STAR, REGISTRY = "\xE2\x98\x85", "bookshelf_folder_badge_providers"

local function series(paths, name)
    local books = {}
    for _, path in ipairs(paths) do books[#books + 1] = {filepath = path} end
    return {books = books, series_name = name or "Saga"}
end
local manga = series({"/Manga/Saga/1.cbz", "/Manga/Saga/2.cbz"})

H.test("folder identity comes from all members, not the first book or a fabricated path", function()
    local folder = Rating.folder(manga)
    H.eq(folder.path, "/Manga/Saga"); H.eq(folder.label, "Saga")
    H.eq(Rating.folder(series({"/Manga/Saga/vol1/1.cbz", "/Manga/Saga/vol2/2.cbz"})).path, "/Manga/Saga")
    H.eq(Rating.folder(series({"/Manga/Saga/1.cbz", "/Manga/Saga sequel/2.cbz"})).path, "/Manga")
    H.eq(Rating.folder(series({"Manga\\Saga\\1.cbz", "Manga//Saga/2.cbz"})).path, "Manga/Saga")
    H.eq(manga.books[1].filepath, "/Manga/Saga/1.cbz")
end)

H.test("unknown, remote and unrelated locations do not guess a linked folder", function()
    for _, paths in ipairs({{}, {"book.cbz"}, {"/book.cbz"}, {"https://example.org/1.cbz"},
            {"/Manga/Saga/1.cbz", "https://example.org/2.cbz"},
            {"/Manga/Saga/1.cbz", "/Fiction/2.epub"}, {"/Manga/../Fiction/1.epub"}}) do
        H.eq(Rating.folder(series(paths)), nil)
    end
    H.eq(Rating.folder({books = {{filepath = "/Manga/Saga/1.cbz"}, {}}}), nil)
    H.eq(Rating.folder(nil), nil)
end)

H.test("only the cached MAL provider is consulted, independently of registration order", function()
    local folder = Rating.folder(manga)
    package.loaded[REGISTRY] = nil
    H.eq(Rating.cachedRating(folder), nil)
    package.loaded[REGISTRY] = {another = function() error("unrelated provider") end}
    H.eq(Rating.cachedRating(folder), nil)
    package.loaded[REGISTRY].myanimelist = function(value)
        H.eq(value.path, folder.path); H.eq(value.label, "Saga")
        return {text = STAR .. "8.72"}
    end
    H.eq(Rating.cachedRating(folder), STAR .. "8.72")
    package.loaded[REGISTRY].myanimelist = function() return STAR .. "9.1" end
    H.eq(Rating.cachedRating(folder), STAR .. "9.10")
end)

H.test("absent, zero, malformed and failing providers never produce a rating", function()
    for _, value in ipairs({false, 0, {}, {text = 8}, {text = "MAL 8.72"},
            STAR .. "0.00", STAR .. "-1", STAR .. "10.1", STAR .. "nan", STAR .. "inf",
            STAR .. "8.72extra", ""}) do
        package.loaded[REGISTRY] = {myanimelist = function() return value end}
        H.eq(Rating.cachedRating(Rating.folder(manga)), nil)
    end
    package.loaded[REGISTRY] = {myanimelist = function() error("plugin unavailable") end}
    H.eq(Rating.cachedRating(Rating.folder(manga)), nil)
end)

-- The external folder provider owns its Manga scope and explicit-folder
-- precedence. This fixture follows myanimelist.koplugin 1.5.2's public hook.
local mappings, calls = {}, 0
local function provider(folder)
    calls = calls + 1
    if not folder.path:lower():find("/manga/", 1, true) then return nil end
    local found
    for _, mapping in pairs(mappings) do
        if mapping.local_folder == folder.path then found = mapping; break end
    end
    found = found or mappings[(folder.label or ""):lower()]
    if found and found.mal_mean then return {text = string.format(STAR .. "%.2f", found.mal_mean)} end
end

H.test("existing folder links win, with series-name fallback and no matching prose badge", function()
    package.loaded[REGISTRY] = {myanimelist = provider}
    mappings = {saga = {mal_mean = 7}, linked = {local_folder = "/Manga/Saga", mal_mean = 8.72}}
    H.eq(Rating.cachedRating(Rating.folder(manga)), STAR .. "8.72")
    mappings.linked = nil
    H.eq(Rating.cachedRating(Rating.folder(manga)), STAR .. "7.00")
    H.eq(Rating.cachedRating(Rating.folder(series({"/Fiction/Saga/1.epub"}))), nil)
    H.eq(Rating.cachedRating(Rating.folder(series({"/Manga/A/1.cbz", "/Manga/B/2.cbz"}))), nil)
    mappings = {}
    H.eq(Rating.cachedRating(Rating.folder(manga)), nil)
end)

local Widget = H.widget()
local dpi, font_scale, night = 1, 100, false
local frames, recolourables = {}, setmetatable({}, {__mode = "k"})
local function px(n) return math.floor(n * dpi + .5) end
local Text = Widget:extend{}
function Text:getSize()
    return {w = px((#self.text - 2) * self.face.size * .55), h = px(self.face.size)}
end
function Text:free() assert(not self.freed); self.freed = true end
local Frame = Widget:extend{}
function Frame:init() frames[#frames + 1] = self end
function Frame:getSize()
    local ts = self[1]:getSize()
    return {w = ts.w + self.padding_left + self.padding_right + 2 * self.bordersize,
        h = ts.h + self.padding_top + self.padding_bottom + 2 * self.bordersize}
end
function Frame:paintTo(bb, x, y)
    assert(bb.native_painted, "badge must follow the native cover fit")
    local size = self:getSize()
    bb.badges[#bb.badges + 1] = {x = x, y = y, w = size.w, h = size.h,
        text = self[1].text, bg = self.background, fg = self[1].fgcolor}
end
function Frame:free() assert(not self.freed); self.freed = true; self[1]:free() end
local colors = function() return {badge_bg = night and "black" or "white", badge_fg = night and "white" or "black"} end
package.loaded["device"] = {screen = {scaleBySize = function(_, n) return px(n) end}}
package.loaded["ui/size"] = {border = {thin = 1}}
package.loaded["lib/bookshelf_space"] = {px = px, padding = {default = 5, small = 2}}
package.loaded["lib/bookshelf_colour_text"] = Text
package.loaded["ui/widget/container/framecontainer"] = Frame
package.loaded["ui/font"] = {}
package.loaded["lib/bookshelf_fonts"] = {getFace = function(_, face, size, opts)
    H.eq(face, "smallinfofont"); H.eq(opts.bold, true) -- Never put Unicode stars into symbols.ttf.
    return {size = size}, true
end}
package.loaded["lib/bookshelf_cover_progress"] = {
    badgeSize = function(base) return math.floor(base * font_scale / 100 + .5) end,
    resolvedColors = colors,
    registerRecolour = function(widget, pick) recolourables[widget] = pick end,
}

local Box = Widget:extend{}
function Box:init()
    self.book = manga
    self.width, self.height = 136, 400
    self.inset, self.top = 4, 170
    self.st_dx, self.st_dy, self.st_w, self.st_h = 3, 0, 122, 180
    self.shape = {w = self.width, h = 230, rise = 14, front_h = 216, strip_h = 20}
    return "init"
end
function Box:paintTo(bb)
    bb.native_painted = true
    if bb.refit then self.st_dx, self.st_dy, self.st_w, self.st_h = 0, 45, 128, 80 end
    return "paint"
end
function Box:free() self.native_frees = (self.native_frees or 0) + 1; return "free" end
function Box:onTap() return "open series" end
function Box:onHold() return "series menu" end
local UI = require("adapters/orbitui_ui")
UI.wrap("lib/bookshelf_series_box_widget", Box)
local function surface() return {badges = {}} end
local function reset()
    dpi, font_scale, night, calls = 1, 100, false, 0
    mappings = {saga = {mal_mean = 8.72}}
    package.loaded[REGISTRY] = {myanimelist = provider}
end

H.test("wrapper is idempotent and leaves native lifecycle and gestures intact", function()
    reset()
    local draw = Box.paintTo
    UI.wrap("lib/bookshelf_series_box_widget", Box)
    H.eq(Box.paintTo, draw)
    local w = Box:new(); H.eq(w:init(), "init")
    H.eq(w:paintTo(surface(), 0, 0), "paint"); H.eq(calls, 1)
    H.eq(w:onTap(), "open series"); H.eq(w:onHold(), "series menu")
    H.eq(w:free(), "free"); H.eq(w.native_frees, 1)
end)

H.test("native badge renderer overlays the cover below heads without resizing the box", function()
    reset()
    local w = Box:new(); local bb = surface()
    w:paintTo(bb, 20, 10)
    local badge = bb.badges[1]; H.eq(badge.text, STAR .. "8.72")
    H.eq(badge.x, 20 + 4 + 3 + 3); H.eq(badge.y, 10 + 170 + 14 + 4 + 3)
    assert(badge.x + badge.w <= 20 + w.inset + w.st_dx + w.st_w)
    assert(badge.y + badge.h < 10 + w.top + w.shape.h - w.shape.strip_h)
    H.eq(w.width, 136); H.eq(w.height, 400); H.eq(w.shape.rise, 14)
    H.eq(w.st_h, 180); H.eq(w.st_w, 122)
    w:free()
end)

H.test("a custom image refit uses current sticker bounds, with no stale coordinates", function()
    reset()
    local w = Box:new(); local bb = surface(); bb.refit = true
    w:paintTo(bb, 20, 10)
    H.eq(bb.badges[1].x, 27); H.eq(bb.badges[1].y, 246)
    assert(bb.badges[1].y + bb.badges[1].h <= 10 + w.top + w.shape.rise + w.inset + w.st_dy + w.st_h)
    w:free()
end)

H.test("tiny covers omit rather than clip ratings, and recover when space returns", function()
    reset()
    local w = Box:new(); w.st_w = 20
    local bb = surface(); w:paintTo(bb, 0, 0); H.eq(#bb.badges, 0)
    w.st_w, w.st_h = 122, 10
    w:paintTo(bb, 0, 0); H.eq(#bb.badges, 0)
    w.st_h = 180
    w:paintTo(bb, 0, 0); H.eq(#bb.badges, 1)
    w:free()
end)

H.test("rating refresh, relinking and unlinking discard only the owned badge", function()
    reset()
    local w = Box:new(); local bb = surface()
    w:paintTo(bb, 0, 0); local old = w._orbitui_rating_badge
    w:paintTo(bb, 0, 0); H.eq(w._orbitui_rating_badge, old)
    mappings.saga.mal_mean = 9.13
    w:paintTo(bb, 0, 0); H.eq(old.freed, true); H.eq(bb.badges[3].text, STAR .. "9.13")
    old = w._orbitui_rating_badge
    mappings = {linked = {local_folder = "/Manga/Saga", mal_mean = 7.2}}
    w:paintTo(bb, 0, 0); H.eq(old.freed, true); H.eq(bb.badges[4].text, STAR .. "7.20")
    old = w._orbitui_rating_badge; mappings = {}
    w:paintTo(bb, 0, 0); H.eq(old.freed, true); H.eq(#bb.badges, 4)
    H.eq(w._orbitui_rating_badge, nil); H.eq(w.book, manga)
    w:free()
end)

H.test("late plugin registration and removal work on an existing box", function()
    reset(); package.loaded[REGISTRY] = nil
    local w = Box:new(); local bb = surface()
    w:paintTo(bb, 0, 0); H.eq(#bb.badges, 0)
    package.loaded[REGISTRY] = {myanimelist = provider}
    w:paintTo(bb, 0, 0); H.eq(#bb.badges, 1)
    local old = w._orbitui_rating_badge
    package.loaded[REGISTRY] = nil
    w:paintTo(bb, 0, 0); H.eq(old.freed, true); H.eq(#bb.badges, 1)
    w:free()
end)

H.test("night recolouring uses the shared badge palette without rebuilding", function()
    reset()
    local w = Box:new(); local bb = surface(); w:paintTo(bb, 0, 0)
    H.eq(bb.badges[1].bg, "white"); H.eq(bb.badges[1].fg, "black")
    local old = w._orbitui_rating_badge; night = true
    old:_bs_recolour(recolourables[old](colors()))
    w:paintTo(bb, 0, 0)
    H.eq(w._orbitui_rating_badge, old)
    H.eq(bb.badges[2].bg, "black"); H.eq(bb.badges[2].fg, "white")
    w:free()
end)

H.test("font scale and DPI replace cached text; reinit and repeated free are safe", function()
    reset()
    local w = Box:new(); local bb = surface(); w:paintTo(bb, 0, 0)
    local old = w._orbitui_rating_badge; font_scale = 150
    w:paintTo(bb, 0, 0); H.eq(old.freed, true)
    H.eq(w._orbitui_rating_badge[1].face.size, 18)
    old = w._orbitui_rating_badge; dpi = 1.5
    w:paintTo(bb, 0, 0); H.eq(old.freed, true)
    old = w._orbitui_rating_badge; w:init(); H.eq(old.freed, true)
    H.eq(w._orbitui_rating_folder, nil)
    w:paintTo(bb, 0, 0); old = w._orbitui_rating_badge
    w:free(); w:free(); H.eq(old.freed, true)
    for _, frame in ipairs(frames) do H.eq(frame.freed, true, "owned badge leaked") end
end)

package.loaded[REGISTRY] = nil
H.finish()
