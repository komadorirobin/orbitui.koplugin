local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H, W = require("tests/helpers"), require("tests/helpers").widget()
local function read(path) local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s end
local function compile(s, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(s)), env)() end
    return assert(load(s, "reviewed native source", "t", env))()
end
local stack, saves, opts, sort_calls, locale, win = {}, 0, nil, {}, "en", nil
local UI = { _simpleui_navigation_generation = 1 }
function UI:show(w)
    if w.buttons then assert(w.sui_native, "sort popup must keep its native identity") end
    stack[#stack + 1] = w
end
function UI:close(w) for i = #stack, 1, -1 do if stack[i] == w then table.remove(stack, i) end end end
function UI:getTopmostVisibleWidget() return stack[#stack] end
local SortWidget, Window = W:extend{}, {}
local sv = { ["Sort"] = "Sortera", ["Sort A to Z"] = "Sortera A till Ö",
    ["Sort Z to A"] = "Sortera Ö till A", ["Sort A to Z (natural)"] = "Sortera A till Ö (naturligt)",
    ["Sort Z to A (natural)"] = "Sortera Ö till A (naturligt)" }
package.loaded.gettext = function(s) return locale == "sv" and sv[s] or s end
package.loaded["ui/widget/buttondialog"], package.loaded["ui/widget/sortwidget"] = W, SortWidget
package.loaded["ui/uimanager"], package.loaded.logger = UI, { warn = function() end }
function Window:new(o)
    opts = o; win = { _wrapper = {} }
    function win:show() UI:show(self._wrapper) end
    function win:close() self._closed = true; o.on_close(); UI:close(self._wrapper) end
    return win
end
function Window.CenteredButtonFooter(_, o) return o end
compile(assert(read(root .. "/components/simpleui/engines/sui_window.lua")
    :match("(function SUIWindow.showArrange%(opts%).-\nend)\n")), { SUIWindow = Window })
local nativeShowArrange, arrange_opts = Window.showArrange, nil
function Window.showArrange(o) arrange_opts = o; return nativeShowArrange(o) end
package.loaded["engines/sui_window"] = Window
local FC = { collates = { strcoll = { id = "strcoll" }, natural = { id = "natural", can_collate_mixed = true } } }
function FC:getSortingFunction(collate, reverse)
    sort_calls[#sort_calls + 1] = { id = collate.id, reverse = reverse }
    local function key(item)
        if collate.id == "date" then return item.date end
        if collate.id == "natural" then return (item.text:gsub("%d+", function(n) return string.format("%08d", n) end)) end
        return item.text
    end
    return function(a, b) if reverse then return key(a) > key(b) end; return key(a) < key(b) end
end
package.loaded["ui/widget/filechooser"] = FC
local function loadArrange() return assert(loadfile(root .. "/components/simpleui/features/dialogs/sui_native_arrange.lua"))() end
local Arrange = loadArrange()
local function fixture()
    stack, saves, sort_calls = {}, 0, {}; UI._simpleui_navigation_generation = 1
    local source = { { text = "Book 10", file = "/10", metadata = {} },
        { text = "Book 2", file = "/2", metadata = {} }, { text = "Book 1", file = "/1", metadata = {} } }
    local target = { item_table = source, path = "Personal" }
    local manager = { booklist_menu = target }; local fm = { collections = manager }
    package.loaded["apps/filemanager/filemanager"] = { instance = fm }
    local widget = SortWidget:new{ item_table = source, title = "Arrange", callback = function()
        saves = saves + 1
        -- Real KOReader rebuilds the native table after each own save.
        local new_table = {}; for i, entry in ipairs(source) do new_table[i] = entry end
        target.item_table = new_table
    end }
    H.eq(Arrange.interceptShow(widget), true)
    local repaints = 0
    return { source = source, target = target, manager = manager, fm = fm, opts = arrange_opts, win = win,
        footer = opts.screen_footers.__root__{ repaint = function() repaints = repaints + 1 end },
        repaints = function() return repaints end }
end
H.test("actual Arrange footer restores four native sort choices and metadata identity", function()
    local f = fixture(); local first = f.source[1]
    f.footer.on_tap(); local popup = stack[#stack]
    H.eq(#popup.buttons, 4); H.eq(popup.buttons[3][1].text, "Sort A to Z (natural)")
    popup.buttons[3][1].callback()
    H.eq(f.source[1].file, "/1"); H.eq(f.source[2].file, "/2"); H.eq(f.source[3], first)
    H.eq(saves, 1); H.eq(f.repaints(), 1)
    f.footer.on_tap(); stack[#stack].buttons[4][1].callback()
    H.eq(f.source[1], first); H.eq(saves, 2, "own-save table replacement must not block subsequent sorting")
    H.eq(sort_calls[2].id, "natural"); H.eq(sort_calls[2].reverse, true)
    f.footer.on_tap(); stack[#stack].buttons[1][1].callback(); H.eq(f.source[2], first)
    f.footer.on_tap(); stack[#stack].buttons[2][1].callback(); H.eq(saves, 4)
end)
H.test("retired, covered or replaced sort dialogs cannot save to an old collection", function()
    for _, why in ipairs{ "close", "navigation", "manager", "list", "path", "covered", "removed_fm" } do
        local f = fixture(); f.footer.on_tap(); local popup = stack[#stack]
        if why == "close" then f.win:close(); assert(stack[#stack] ~= popup)
        elseif why == "navigation" then UI._simpleui_navigation_generation = 2
        elseif why == "manager" then f.fm.collections = {}
        elseif why == "list" then f.target.item_table = {}
        elseif why == "path" then f.target.path = "Other"
        elseif why == "covered" then UI:show({})
        else package.loaded["apps/filemanager/filemanager"] = nil end
        popup.buttons[3][1].callback(); H.eq(saves, 0, why); H.eq(f.source[1].file, "/10")
    end
end)
H.test("arrange moves keep native callbacks and foreign SortWidgets stay native", function()
    local f = fixture(); local items = f.opts.items
    items[1], items[3] = items[3], items[1]
    f.opts.on_change(items); H.eq(saves, 1); H.eq(f.source[1].file, "/1")
    H.eq(Arrange.interceptShow(SortWidget:new{ item_table = {} }), false)
    f.win:close(); f.opts.on_change(items); H.eq(saves, 1)
end)
H.test("sort labels retain native gettext localization and Italian plural syntax", function()
    locale = "sv"; Arrange = loadArrange()
    local f = fixture(); H.eq(f.footer.text, "Sortera"); f.footer.on_tap()
    H.eq(stack[#stack].buttons[1][1].text, "Sortera A till Ö"); locale = "en"
    local italian = read(root .. "/components/simpleui/locale/it_IT.po")
    assert(italian:find('"PO-Revision-Date: 2026-11-06 00:33+0000\\n"', 1, true))
    for block in italian:gmatch("[^\n]+.-\n\n") do
        if block:find("msgid_plural", 1, true) then
            assert(block:find("msgstr[1]", 1, true)); assert(not block:find('\nmsgstr "', 1, true))
        end
    end
end)

-- Actual complete modal assembly; group deliberately never sets a dimen.
local Class, Frame = W:extend{}, W:extend{}
local function rect(o)
    function o:intersect(other)
        local x, y = math.max(self.x, other.x), math.max(self.y, other.y)
        return rect{ x = x, y = y, w = math.max(0, math.min(self.x + self.w, other.x + other.w) - x),
            h = math.max(0, math.min(self.y + self.h, other.y + other.h) - y) }
    end
    return o
end
function Class:getSize() return { w = 400, h = 200 } end
function Class:paintTo(bb, x, y) for _, child in ipairs(self) do if child.paintTo then child:paintTo(bb, x, y) end end end
function Frame:paintTo(bb, x, y)
    self.dimen = rect{ x = x, y = y, w = 400, h = 200 }; Class.paintTo(self, bb, x, y)
end
local env = { ReviewsModal = {}, FrameContainer = Frame, VerticalGroup = Class, CenterContainer = Class,
    Geom = { new = function(_, o) return rect(o) end }, _gettime = os.clock, logger = { dbg = function() end },
    Space = { radius = { window = 0 } }, Size = { border = { window = 1 } }, Blitbuffer = { COLOR_WHITE = 255 },
    Device = { hasDPad = function() return false end }, Event = { new = function(_, s) return { handler = "on" .. s } end } }
compile(assert(read(root .. "/components/bookshelf/lib/bookshelf_reviews_modal.lua")
    :match("(function ReviewsModal:_assemble%(%).-\nend)\n")), env)
local function modalFixture(body, native, assemble)
    local modal = { _screen_w = 600, _screen_h = 800, _activeBody = function() return body, native end,
        _buildButtons = function() return {} end, _buildHeader = function() end,
        _isRetainedBody = function() return false end, mergeLayoutInVertical = function() end }
    setmetatable(modal, { __index = env.ReviewsModal })
    if assemble then modal._assemble = assemble end
    modal:_assemble(); return modal
end
local painted, inverted = 0, 0
local function arrayReferences(t, wanted, seen)
    if t == wanted then return true end
    if type(t) ~= "table" then return false end
    seen = seen or {}; if seen[t] then return false end; seen[t] = true
    for _, child in ipairs(t) do if arrayReferences(child, wanted, seen) then return true end end
    return false
end
local native_ui, panelUI = os.getenv("ORBITUI_NATIVE_PANEL_UI_FILE"), {}
if native_ui then
    local source = read(native_ui)
    local ui_env = { UIManager = panelUI, logger = env.logger, Geom = env.Geom,
        util = { arrayReferences = arrayReferences }, Screen = { bb = { invertRect = function() inverted = inverted + 1 end } } }
    for _, name in ipairs{ "widgetRepaint", "widgetInvert" } do
        compile(assert(source:match("(function UIManager:" .. name .. "%([^\n]-\n.-\nend)\n")), ui_env)
    end
end
local old_modal = os.getenv("ORBITUI_NATIVE_OLD_MODAL_FILE")
if native_ui and old_modal then
    H.test("the exact premerge crop fails native text and icon feedback as reported", function()
        local old = assert(read(old_modal):match("function ReviewsModal:_assemble%(%)(.-)\nend\n"))
        local assemble = compile("return function(self)\n" .. old .. "\nend", env)
        local button, body = Class:new{}, Class:new{}
        body[1] = button
        local modal = modalFixture(body, true, assemble); button.show_parent = modal
        modal[1]:paintTo({}, 10, 20)
        local ok, err = pcall(panelUI.widgetRepaint, panelUI, button, 10, 20)
        H.eq(ok, false); assert(tostring(err):find("dimen", 1, true))
        ok = pcall(panelUI.widgetInvert, panelUI, button, 10, 20, 30, 30)
        H.eq(ok, false)
    end)
end
H.test("Cover crop records painted bounds for text and icon tap feedback", function()
    local button = Class:new{}; function button:paintTo() painted = painted + 1 end
    local body = Class:new{ button }; local modal = modalFixture(body, true); button.show_parent = modal
    local crop = modal.cropping_widget
    assert(crop ~= body); H.eq(crop[1], body); H.eq(crop.padding, 0); H.eq(crop.margin, 0); H.eq(crop.bordersize, 0)
    H.eq(modal._vgroup[1], crop); modal[1]:paintTo({}, 10, 20)
    H.eq(crop.dimen.x, 10); H.eq(crop:getCropRegion(), crop.dimen); H.eq(body.dimen, nil)
    if native_ui then
        panelUI:widgetRepaint(button, 10, 20); panelUI:widgetInvert(button, 10, 20, 30, 30)
        assert(painted > 1 and inverted == 1)
    end
end)
H.test("scroll crops retain native regions, HTML stays uncropped and replaced bodies close once", function()
    local closed = 0
    local scroll = Class:new{ getCropRegion = function() return rect{ x = 0, y = 0, w = 20, h = 20 } end,
        handleEvent = function(_, e) H.eq(e.handler, "onCloseWidget"); closed = closed + 1 end }
    local modal = modalFixture(scroll, true); H.eq(modal.cropping_widget, scroll)
    local html = Class:new{}; modal._activeBody = function() return html, false end
    modal:_assemble(); H.eq(modal.cropping_widget, nil); H.eq(closed, 1); H.eq(modal._tab_body, html)
end)

local gen = assert(read(root .. "/components/simpleui/features/library/sui_library_browse.lua")
    :match("(FileChooser.genItemTable = function%(fc, dirs, fls, path%).-\n        end)\n"))
local level, leaf, reverse, mixed, collate_reads = "file_list", "author", false, true, 0
compile(gen, { FileChooser = FC, orig = function() return { { text = "native" } } end,
    VirtualPath = { isVirtual = function(p) return p == "meta" end,
        parse = function() return nil, { trail = { { dimension = leaf } } }, nil, level end, parentOf = function() return "parent" end },
    BD = { mirroredUILayout = function() return false end }, _is_windows = false,
    G_reader_settings = { isTrue = function() return reverse end } })
local fc = setmetatable({ _browse_by_meta_entry_path = "meta", getCollate = function()
    collate_reads = collate_reads + 1
    return mixed and FC.collates.natural or { id = "date", can_collate_mixed = false }
end }, { __index = FC })
H.test("facets and nonseries books follow native reverse and natural collation", function()
    level, leaf, reverse, mixed = "file_list", "author", true, true
    local dirs, books = { { text = "Folder 2" }, { text = "Folder 10" } }, { { text = "Book 2" }, { text = "Book 10" } }
    local result = FC.genItemTable(fc, dirs, books, "meta")
    H.eq(result[1].text, "Folder 10"); H.eq(result[3].text, "Book 10")
end)
H.test("series numeric reading order survives reverse collation and folders have name fallback", function()
    leaf, reverse, mixed = "series", true, false
    local books, dirs = { { text = "Volume 2", date = 2 }, { text = "Volume 10", date = 10 } },
        { { text = "Zulu" }, { text = "Alpha" } }
    local result = FC.genItemTable(fc, dirs, books, "meta")
    H.eq(result[1].text, "Alpha"); H.eq(result[3], books[1]); H.eq(books[1].text, "Volume 2")
    level = "root"; local before = collate_reads
    FC.genItemTable(fc, {}, {}, "meta"); H.eq(collate_reads, before)
    H.eq(FC.genItemTable(fc, {}, {}, "/real")[1].text, "native")
end)
H.finish()
