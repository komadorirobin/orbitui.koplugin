local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;" .. package.path
local T = require("tests/helpers")
local W, f, M = T.widget()
function W:_init()
    self.key_events, self.ges_events = {}, {}
    if self.kind == "button" then self.label_widget = W:new{}; self.label_container = W:new{ self.label_widget } end
end
function W:free() for _, c in ipairs(self) do if c.free then c:free() end end end
function W:getScrollbarWidth() return f.bar or math.floor(18 * f.scale + .5) end
function W:getSize()
    if self.kind == "text" or self.kind == "label" then
        local size = self.face.size
        local w = self.width or math.ceil(#self.text * size * .52)
        return { w = w, h = self.height or math.ceil(math.max(1, math.ceil(#self.text * size * .52 / math.max(1,w))) * size * 1.35) }
    elseif self.kind == "button" then return { w = self.width, h = self.height + 2 * (self.padding_v + self.bordersize) }
    elseif self.kind == "vspan" then return { w = 0, h = self.width }
    elseif self.kind == "hspan" then return { w = self.width, h = 0 }
    elseif self.kind == "scroll" or self.kind == "center" then return self.dimen
    elseif self.kind == "image" then return { w = self.width, h = self.height } end
    local w, h = 0, 0
    for _, c in ipairs(self) do
        local s = c:getSize()
        if self.kind == "horizontal" then w, h = w + s.w, math.max(h, s.h)
        else w, h = math.max(w, s.w), h + s.h end
    end
    if self.kind == "frame" then w, h = w + 2 * self.padding, h + 2 * self.padding end
    return { w = w, h = h }
end
local function fixture(width, height, scale, language, owned)
    f = { width = width or 1264, height = height or 1680, scale = scale or 2, reads = 0, peeks = 0,
        closed = 0, freed = 0, writes = 0, opens = 0, tabs = {}, tags = {"Slice of life", "Found family", "猫", "日常", ("Long tag "):rep(30)} }
    local values = { language = language or "sv" }
    G_reader_settings = { readSetting = function(_, k, default) if values[k] ~= nil then return values[k] end; return default end,
        saveSetting = function(_, k, v) f.writes = f.writes + 1; values[k] = v end }
    for path, kind in pairs{
        ["ui/widget/focusmanager"] = "focus", ["ui/widget/container/framecontainer"] = "frame",
        ["ui/widget/textboxwidget"] = "text", ["ui/widget/textwidget"] = "label", ["ui/widget/verticalgroup"] = "vertical",
        ["ui/widget/horizontalgroup"] = "horizontal", ["ui/widget/verticalspan"] = "vspan", ["ui/widget/horizontalspan"] = "hspan",
        ["ui/widget/button"] = "button", ["ui/widget/container/centercontainer"] = "center",
        ["ui/widget/container/scrollablecontainer"] = "scroll", ["ui/widget/imagewidget"] = "image", ["ui/geometry"] = "geom",
    } do package.loaded[path] = W:extend{ kind = kind } end
    package.loaded["lib/bookshelf_fonts"] = { getFace = function(_, _, size) return { size = size * f.scale } end }
    package.loaded["ffi/blitbuffer"] = { COLOR_BLACK = 0, COLOR_WHITE = 255, COLOR_DARK_GRAY = 85 }
    package.loaded.device = { screen = { getWidth = function() return f.width end, getHeight = function() return f.height end,
        scaleBySize = function(_, n) return math.floor(n * f.scale + .5) end } }
    local UI = { _simpleui_navigation_generation = 1, setDirty = function() end,
        show = function(_, p) f.shown = p end, close = function(_, p) p:onCloseWidget(); f.shown = nil end,
        isWidgetShown = function(_, p) return f.shown == p end, getTopmostVisibleWidget = function() return f.top or f.shown end }
    package.loaded["ui/uimanager"] = UI
    local book = { filepath = "/books/book.epub", title = "The Long Book Title: A Story", author = "Author Name",
        description = ("A book description. "):rep(40), series_name = "Hirayasumi", series_num = 1, lang = "Svenska",
        cover_bb = { getWidth = function() error("shared one-shot cover must not be touched") end } }
    package.loaded["lib/bookshelf_book_repository"] = {
        buildBookMeta = function(file, opts) T.eq(file, book.filepath); T.eq(opts.want_cover, false); f.reads = f.reads + 1; return book end,
        readProgress = function() return .44, "reading", 4 end,
    }
    package.loaded["lib/bookshelf_tokens"] = { cleanDescription = function(s) return s end }
    package.loaded["lib/bookshelf_settings_store"] = { read = function(_, default) return f.font or default end }
    package.loaded["adapters/orbitui_integrations"] = {
        embeddedTags = function(file, refresh, defer, cache)
            T.eq(file, book.filepath); T.eq(refresh, false); assert(defer and cache); f.peeks = f.peeks + 1; return f.tags
        end, bookOrbitEnabled = function() return false end,
    }
    package.loaded["core/orbitui_search"] = { embeddedTag = function(tag, opts) f.search = { tag, opts } end }
    package.loaded["adapters/orbitui_library_settings"] = { tagChip = function(opts) f.chip = opts end }
    M = dofile(root .. "/adapters/orbitui_book_panel.lua")
    local owner = { profile_key = "manga", _orbitui_detail_only = true, _openBook = function(_, b)
        assert(not f.shown); T.eq(b.filepath, book.filepath); f.opens = f.opens + 1 end }
    local bb = { getWidth = function() return 300 end, getHeight = function() return 450 end, free = function() f.freed = f.freed + 1 end }
    owner._orbituiDetailCover = function(_, b) T.eq(b.cover_bb, nil); return bb, owned end
    local p = M.bookPage(owner, book, { on_close = function() f.closed = f.closed + 1 end }, function(opts)
        assert(not f.shown); f.tabs[#f.tabs + 1] = opts; return { native = true }
    end)
    return p, owner, UI
end
local function bounds(p)
    local s = p[1]:getSize()
    assert(s.w <= f.width and s.h <= f.height, string.format("page %dx%d in %dx%d", s.w,s.h,f.width,f.height))
    local scroll = p.cropping_widget
    assert(scroll[1]:getSize().w <= scroll.dimen.w - scroll:getScrollbarWidth())
    local function walk(w)
        if w.kind == "button" and #w.label_widget > 0 then
            local label = w.label_widget:getSize()
            assert(label.w <= w.width - 2 * (w.padding_h + w.bordersize) and label.h <= w.height)
        end
        for _, c in ipairs(w) do walk(c) end
    end
    walk(p[1])
end
T.test("overview fits narrow, landscape, dense and portrait layouts without shrinking content text", function()
    for _, d in ipairs{{1264,1680,2}, {1680,1264,2}, {600,800,1}, {320,480,1}, {320,240,1}, {600,800,2.5}} do
        for _, lang in ipairs{"sv", "en"} do
            local p = fixture(d[1],d[2],d[3],lang); bounds(p)
            f.font = 40; f.bar = 57; p:rebuild(); bounds(p)
            T.eq(f.reads,1); T.eq(f.peeks,1); T.eq(f.writes,0)
        end
    end
end)
T.test("owned covers are freed once, borrowed covers never; rebuild reuses metadata and tags", function()
    for _, owned in ipairs{true,false} do
        local p = fixture(nil,nil,nil,nil,owned)
        p:rebuild(); p:rebuild(); p:onClose(); p:onCloseWidget(); p:onClose()
        T.eq(f.freed,owned and 1 or 0); T.eq(f.closed,1); T.eq(f.reads,1); T.eq(f.peeks,1)
    end
end)
T.test("tag tap searches locally; long press preserves chip creation and revision guards", function()
    local p = fixture(); local pill = p:getButtonById("tag:1:1"); pill.hold_callback()
    T.eq(f.chip.tag,"Slice of life"); T.eq(f.chip.profile,"manga"); assert(f.chip.is_current())
    p:rebuild(); assert(not f.chip.is_current()); pill.callback(); T.eq(f.search,nil)
    p:getButtonById("tag:1:1").callback(); T.eq(f.closed,1); T.eq(f.search[1],"Slice of life")
    T.eq(f.search[2].view_profile,"manga"); T.eq(f.opens,0)
end)
T.test("native tabs take over with one final close callback and the same lightweight owner", function()
    for _, id in ipairs{"description","tags","reviews","information","cover","actions"} do
        local p, owner = fixture(); p:getButtonById(id).callback(); T.eq(f.closed,0); T.eq(#f.tabs,1)
        T.eq(f.tabs[1].active,id == "actions" and "edit" or id); assert(f.tabs[1].classic)
        assert(owner._orbitui_modal.native); f.tabs[1].on_close(); T.eq(f.closed,1)
    end
end)
T.test("read uses the real owner once; old, covered, rotated and navigated callbacks are inert", function()
    local p = fixture(); local read = p:getButtonById("read")
    f.top = {}; read.callback(); T.eq(f.opens,0); f.top = nil
    read.callback(); read.callback(); T.eq(f.opens,1); T.eq(f.closed,1)
    for _, event in ipairs{"onSuspend","onScreenResize","onShowingReader"} do
        p = fixture(); read = p:getButtonById("read"); p[event](p); read.callback(); T.eq(f.opens,0); T.eq(f.closed,1)
    end
    local ui; p, _, ui = fixture(); read = p:getButtonById("read")
    ui._simpleui_navigation_generation = 2; read.callback(); T.eq(f.opens,0)
end)
T.test("classic view is a reversible opt-out; opening settings writes nothing", function()
    fixture(); assert(M.bookPageEnabled()); local rows = M.bookPageItems()
    T.eq(f.writes,0); rows[1].callback(); assert(not M.bookPageEnabled()); rows[1].callback(); assert(M.bookPageEnabled())
end)
T.finish()
