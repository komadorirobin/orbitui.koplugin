local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local T = require("tests/helpers")
local W = T.widget()
local f, M
function W:_init()
    self.key_events, self.ges_events = {}, {}
    if self.kind == "button" then
        self.label_widget = W:new{}
        self.label_container = W:new{ self.label_widget }
    end
end
function W:free() for _, child in ipairs(self) do if child.free then child:free() end end end
function W:setText(copy) self.text = copy end
function W:getSize()
    if self.kind == "text" then
        local size = self.face.pixel_size
        local lines = 0
        for line in (self.text .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#line * size * .52 / math.max(1, self.width))) end
        return { w = self.width, h = self.height or math.ceil(lines * size * 1.35) }
    elseif self.kind == "button" then return { w = self.width, h = self.height + 2 * (self.padding_v + self.bordersize) }
    elseif self.kind == "vspan" then return { w = 0, h = self.width }
    elseif self.kind == "hspan" then return { w = self.width, h = 0 }
    elseif self.kind == "image" or self.kind == "icon" or self.kind == "progress" then return { w = self.width, h = self.height }
    elseif self.kind == "scroll" or self.kind == "center" then return self.dimen end
    local w, h = 0, 0
    for _, child in ipairs(self) do
        local size = child:getSize()
        if self.kind == "horizontal" then w, h = w + size.w, math.max(h, size.h)
        else w, h = math.max(w, size.w), h + size.h end
    end
    if self.kind == "frame" then w, h = w + 2 * (self.padding + self.bordersize), h + 2 * (self.padding + self.bordersize) end
    return { w = w, h = h }
end
function W:paintTo() end
function W:contains(pos) return pos.x >= self.x and pos.x < self.x + self.w and pos.y >= self.y and pos.y < self.y + self.h end
local function fixture(sw, sh, scale, lang, tab, count)
    f = { scale = scale or 2, width = sw or 1264, height = sh or 1680, actions = {}, gets = 0, writes = 0 }
    G_reader_settings = { readSetting = function(_, key) if key == "language" then return lang or "en" end end,
        saveSetting = function() f.writes = f.writes + 1 end }
    for path, kind in pairs{
        ["ui/widget/focusmanager"] = "focus", ["ui/widget/container/framecontainer"] = "frame",
        ["ui/widget/textboxwidget"] = "text", ["ui/widget/verticalgroup"] = "vertical",
        ["ui/widget/horizontalgroup"] = "horizontal", ["ui/widget/verticalspan"] = "vspan",
        ["ui/widget/horizontalspan"] = "hspan", ["ui/widget/button"] = "button",
        ["ui/widget/container/centercontainer"] = "center", ["ui/widget/container/scrollablecontainer"] = "scroll",
        ["ui/widget/progresswidget"] = "progress", ["ui/widget/iconwidget"] = "icon", ["ui/widget/imagewidget"] = "image",
        ["ui/geometry"] = "geom", ["ui/gesturerange"] = "gesture",
    } do package.loaded[path] = W:extend{ kind = kind } end
    package.loaded["ui/font"] = { getFace = function(_, _, size) return { pixel_size = size * f.scale } end }
    package.loaded["ffi/blitbuffer"] = { COLOR_BLACK = 0, COLOR_WHITE = 255, COLOR_LIGHT_GRAY = 204, COLOR_DARK_GRAY = 85 }
    package.loaded.device = { screen = { getWidth = function() return f.width end, getHeight = function() return f.height end,
        scaleBySize = function(_, n) return math.floor(n * f.scale + .5) end } }
    local UI = { setDirty = function() end, close = function(_, w) w:onCloseWidget() end,
        isWidgetShown = function(_, w) return f.shown == w end, getTopmostVisibleWidget = function() return f.top or f.shown end }
    package.loaded["ui/uimanager"] = UI
    package.loaded["infra/sui_cover_cache"] = nil
    local ui = { document = { file = "/books/current.epub", getPageCount = function() return 269 end },
        getCurrentPage = function() return 148 end,
        toc = { getTocTitleByPage = function() return "III · En mycket lång kapitelrubrik" end, getChapterPagesLeft = function() return 29 end } }
    local buttons = {}
    local function spec(id, copy, enabled)
        local b = { id = id, text = copy or id, enabled = enabled ~= false,
            callback = function() f.actions[#f.actions + 1] = id end }
        buttons[#buttons + 1] = { b }; return b
    end
    local selected = tab or "tools"
    spec("tools", "Tools", selected ~= "tools"); spec("ongoing", "Also reading", selected ~= "ongoing")
    for _, id in ipairs{ "toc", "bookmark", "search", "bookinfo", "pins", "gotopage", "config", "close", "library" } do spec(id) end
    spec("reader_ai", "X-Ray · KOAssistant")
    local books = {}
    for i = 1, count or 12 do
        local b = { file = "/books/" .. i .. ".epub", title = "The Long Library Book: Volume " .. i, author = "A test author", percent = i / 100 }
        books[#books + 1] = b; spec("book:" .. b.file)
    end
    spec("state_status", "Up to 12 unfinished books from the latest 200 history entries. Only local files are checked.", false)
    spec("refresh")
    package.loaded["adapters/orbitui_book_panel"] = nil; M = require("adapters/orbitui_book_panel")
    local opts = { ui = ui, title = "Nattsäsong · En mycket lång boktitel", author = { "Karolina Ramqvist" },
        file = ui.document.file, tab = selected, books = books, phase = "ready", missing = 1, buttons = buttons }
    local p = M.readerSheet(opts); f.shown = p
    return p, opts
end
local function bounded(p)
    local r = p.panel_rect
    assert(r.x >= 0 and r.y >= 0 and r.w <= f.width and r.h <= f.height,
        string.format("%dx%d @ %.1f: rectangle %d,%d %dx%d", f.width, f.height, f.scale, r.x, r.y, r.w, r.h))
    T.eq(r.y + r.h, f.height, "bottom anchored")
    if p.cropping_widget then
        local c = p.cropping_widget
        assert(c[1]:getSize().w <= c.dimen.w - math.floor(18 * f.scale + .5), "native scrollbar needs reserved width")
    end
    local function walk(widget)
        if widget.kind == "button" and widget.label_widget then
            local size = widget.label_widget:getSize()
            -- Plain stub labels have no measured text; rich native content does.
            if #widget.label_widget > 0 then
                assert(size.w <= widget.width and size.h <= widget.height,
                    "rich content must fit its native button: " .. widget.width .. "x" .. widget.height .. " / " .. size.w .. "x" .. size.h)
            end
        end
        for _, child in ipairs(widget) do walk(child) end
        if widget.kind == "button" then walk(widget.label_widget) end
    end
    walk(p[1])
end
T.test("native bottom sheet fits portrait, landscape, narrow and dense English/Swedish layouts", function()
    for _, dimensions in ipairs{ {1264,1680,2}, {1680,1264,2}, {320,480,1}, {320,240,1}, {600,800,2.5} } do
        for _, lang in ipairs{ "en", "sv" } do for _, tab in ipairs{ "tools", "ongoing" } do
            local p = fixture(dimensions[1], dimensions[2], dimensions[3], lang, tab); bounded(p)
            T.eq(p.name, "orbitui_reader_panel"); assert(p.modal); T.eq(f.writes, 0)
        end end
    end
end)
T.test("selected tab is black and enabled rather than disabled gray; optional AI uses a native rich row", function()
    local p = fixture()
    local tab = p:getButtonById("tools")
    assert(tab.enabled); T.eq(tab.background, 0); T.eq(tab.label_widget.fgcolor, 255)
    assert(p:getButtonById("reader_ai").label_container[1])
    assert(p:getButtonById("config").label_container[1])
    p:getButtonById("reader_ai").callback(); T.eq(f.actions[1], "reader_ai")
end)
T.test("four-book pages reuse prepared records without rescanning; old buttons cannot fire after a page turn", function()
    local p = fixture(nil, nil, nil, nil, "ongoing")
    assert(p:getButtonById("book:/books/4.epub")); T.eq(p:getButtonById("book:/books/5.epub"), nil)
    local stale = p:getButtonById("book:/books/1.epub")
    p:getButtonById("next").callback(); T.eq(p.page, 2); assert(p:getButtonById("book:/books/5.epub"))
    stale.callback(); T.eq(#f.actions, 0)
    p:getButtonById("next").callback(); T.eq(p.page, 3)
    p:getButtonById("next").callback(); T.eq(p.page, 3)
    p:getButtonById("prev").callback(); T.eq(p.page, 2); bounded(p)
end)
T.test("covered modal, close, sleep and rotation reject callbacks rather than touching the reader underneath", function()
    for _, method in ipairs{ "onClose", "onSuspend", "onScreenResize", "onSetRotationMode" } do
        local p = fixture(); local b = p:getButtonById("reader_ai")
        f.top = {}; b.callback(); T.eq(#f.actions, 0); f.top = nil
        p[method](p); assert(p.closed); b.callback(); T.eq(#f.actions, 0)
    end
    local p = fixture(); p:onOutside(nil, { pos = { x = 0, y = 0 } }); assert(p.closed)
end)
T.test("pause status changes in place with fixed height and no new dialog", function()
    local p = fixture(nil, nil, nil, nil, "ongoing")
    local rect, revision = p.panel_rect, p.revision
    local note = p:getButtonById("state_status"); local height = note:getSize().h
    note:setText("Förberedelsen har pausats. Tryck Uppdatera för att försöka igen.")
    T.eq(note:getSize().h, height); T.eq(p.panel_rect, rect); T.eq(p.revision, revision)
end)
T.test("covers borrow only loaded RAM bitmaps, never upscale or dispose the cache owner", function()
    local _, opts = fixture()
    local freed = 0
    local bb = { getWidth = function() return 20 end, getHeight = function() return 30 end,
        free = function() freed = freed + 1 end }
    package.loaded["infra/sui_cover_cache"] = { get = function() f.gets = f.gets + 1; return bb end }
    local p = M.readerSheet(opts); f.shown = p
    local images = 0
    local function walk(w)
        if w.kind == "image" then
            images = images + 1; T.eq(w.image, bb); T.eq(w.image_disposable, false)
            assert(w.width <= 20 and w.height <= 30)
        end
        for _, child in ipairs(w) do walk(child) end
        if w.kind == "button" then walk(w.label_widget) end
    end
    walk(p[1]); T.eq(images, 1); T.eq(f.gets, 1)
    p:onCloseWidget(); p:free(); T.eq(freed, 0); T.eq(f.writes, 0)
end)
T.finish()
