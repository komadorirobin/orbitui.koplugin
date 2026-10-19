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

H.test("Oneshots folder boxes cannot inherit a member's MAL rating", function()
    local collection = series({"/Manga/Oneshots/A title/one.cbz"}, "Oneshots")
    collection.kind, collection._series_box, collection.path = "folder", true, "/Manga/Oneshots"
    H.eq(Rating.folder(collection), nil)
    H.eq(Rating.folder(series({"/Manga/A title/one.cbz"}, "A title")).path, "/Manga/A title")
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
local dpi, font_scale = 1, 100
local labels = {}
local function px(n) return math.floor(n * dpi + .5) end
local Text = Widget:extend{}
function Text:init() labels[#labels + 1] = self end
function Text:getSize()
    return {w = px((#self.text - 2) * self.face.size * .55), h = px(self.face.size)}
end
function Text:free() assert(not self.freed); self.freed = true end
package.loaded["device"] = {screen = {scaleBySize = function(_, n) return px(n) end}}
package.loaded["lib/bookshelf_colour_text"] = Text
package.loaded["lib/bookshelf_fonts"] = {getFace = function(_, face, size, opts)
    H.eq(face, "smallinfofont"); H.eq(opts.bold, true) -- Never put Unicode stars into symbols.ttf.
    return {size = size}, true
end}
package.loaded["lib/bookshelf_cover_progress"] = {
    badgeSize = function(base) return math.floor(base * font_scale / 100 + .5) end,
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
function Box:paintTo() return "paint" end
function Box:free() self.native_frees = (self.native_frees or 0) + 1; return "free" end
function Box:onTap() return "open series" end
function Box:onHold() return "series menu" end
local UI = require("adapters/orbitui_ui")
local original_draw = Box.paintTo
UI.wrap("lib/bookshelf_series_box_widget", Box)
local function reset()
    dpi, font_scale, calls = 1, 100, 0
    mappings = {saga = {mal_mean = 8.72}}
    package.loaded[REGISTRY] = {myanimelist = provider}
end

H.test("wrapper is idempotent and leaves native lifecycle and gestures intact", function()
    reset()
    local draw = Box.paintTo
    UI.wrap("lib/bookshelf_series_box_widget", Box)
    H.eq(Box.paintTo, draw); H.eq(draw, original_draw)
    local w = Box:new(); H.eq(w:init(), "init")
    H.eq(w:paintTo({}, 0, 0), "paint")
    H.eq(w:stickerLeftLabel().text, STAR .. "8.72"); H.eq(calls, 1)
    H.eq(w:onTap(), "open series"); H.eq(w:onHold(), "series menu")
    H.eq(w:free(), "free"); H.eq(w.native_frees, 1)
end)

H.test("host supplies unframed bold text at the folder badge font scale", function()
    reset()
    local w = Box:new(); local label = w:stickerLeftLabel()
    H.eq(label.text, STAR .. "8.72"); H.eq(label.padding, 0)
    H.eq(label.bold, true); H.eq(label.face.size, 12)
    H.eq(label.background, nil); H.eq(label.fgcolor, nil)
    H.eq(label[1], nil) -- No separate badge/frame; the native box owns the ink.
    H.eq(w.width, 136); H.eq(w.height, 400); H.eq(w.shape.rise, 14)
    H.eq(w.st_h, 180); H.eq(w.st_w, 122)
    w:free()
end)

H.test("label lookup does not change cover fit or add a reserved band", function()
    reset()
    local w = Box:new(); local label = w:stickerLeftLabel()
    w.st_dx, w.st_dy, w.st_w, w.st_h = 0, 45, 128, 80
    H.eq(w:stickerLeftLabel(), label)
    H.eq(w.st_dx, 0); H.eq(w.st_dy, 45); H.eq(w.st_w, 128); H.eq(w.st_h, 80)
    H.eq(w.count_band_h, nil)
    w:free()
end)

H.test("disabling the host aspect policy clears only the added label", function()
    reset()
    local w = Box:new(); local label = w:stickerLeftLabel()
    w.preserve_cover_aspect = false
    H.eq(w:stickerLeftLabel(), nil); H.eq(label.freed, true)
    H.eq(w.book, manga); H.eq(calls, 1)
    w.preserve_cover_aspect = true
    H.eq(w:stickerLeftLabel().text, STAR .. "8.72")
    w:free()
end)

H.test("rating refresh, relinking and unlinking discard only the owned label", function()
    reset()
    local w = Box:new(); local old = w:stickerLeftLabel()
    H.eq(w:stickerLeftLabel(), old)
    mappings.saga.mal_mean = 9.13
    H.eq(w:stickerLeftLabel().text, STAR .. "9.13"); H.eq(old.freed, true)
    old = w._orbitui_rating_label
    mappings = {linked = {local_folder = "/Manga/Saga", mal_mean = 7.2}}
    H.eq(w:stickerLeftLabel().text, STAR .. "7.20"); H.eq(old.freed, true)
    old = w._orbitui_rating_label; mappings = {}
    H.eq(w:stickerLeftLabel(), nil); H.eq(old.freed, true)
    H.eq(w._orbitui_rating_label, nil); H.eq(w.book, manga)
    w:free()
end)

H.test("late plugin registration and removal work on an existing box", function()
    reset(); package.loaded[REGISTRY] = nil
    local w = Box:new()
    H.eq(w:stickerLeftLabel(), nil)
    package.loaded[REGISTRY] = {myanimelist = provider}
    local old = w:stickerLeftLabel(); H.eq(old.text, STAR .. "8.72")
    package.loaded[REGISTRY] = nil
    H.eq(w:stickerLeftLabel(), nil); H.eq(old.freed, true)
    w:free()
end)

H.test("provider errors remove an existing label and can recover on the next paint", function()
    reset()
    local w = Box:new(); local old = w:stickerLeftLabel()
    package.loaded[REGISTRY].myanimelist = function() error("unavailable") end
    H.eq(w:stickerLeftLabel(), nil); H.eq(old.freed, true)
    package.loaded[REGISTRY].myanimelist = provider
    H.eq(w:stickerLeftLabel().text, STAR .. "8.72")
    w:free()
end)

H.test("font scale and DPI replace cached text; reinit and repeated free are safe", function()
    reset()
    local w = Box:new(); local old = w:stickerLeftLabel(); font_scale = 150
    H.eq(w:stickerLeftLabel().face.size, 18); H.eq(old.freed, true)
    old = w._orbitui_rating_label; dpi = 1.5
    w:stickerLeftLabel(); H.eq(old.freed, true)
    old = w._orbitui_rating_label; w:init(); H.eq(old.freed, true)
    H.eq(w._orbitui_rating_folder, nil)
    old = w:stickerLeftLabel()
    w:free(); w:free(); H.eq(old.freed, true)
    for _, label in ipairs(labels) do H.eq(label.freed, true, "owned label leaked") end
end)

package.loaded[REGISTRY] = nil
H.finish()
