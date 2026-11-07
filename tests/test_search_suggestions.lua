local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Search = require("core/orbitui_search")
local function chars(text)
    local out = {}
    for c in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = c end
    return out
end
local function cursor(text) return #chars(text) + 1 end
local saved, writes = {}, 0
local notices = {}
require("core/orbitui_context").notify = function(text) notices[#notices + 1] = text end
package.loaded["infra/sui_store"] = { get = function(_, k) return saved[k] end,
    set = function(_, k, v) saved[k] = v; writes = writes + 1 end }
local vocabulary = Search.wordVocabulary()
for _, b in ipairs{
    { filepath = "/1", title = "Ångström: Ångström", author = "Ramqvist", series = "Hirayasumi" },
    { filepath = "/2", title = "Ångest med drakar", authors = { "Karolina Ramqvist" } },
    { filepath = "/3", title = "The Dragon—Dragonfly", series_name = "Hirayasumi" },
} do vocabulary:add(b) end
vocabulary:finish()
H.test("word suggestions are opt-in, read-only and independent of typo matching", function()
    H.eq(Search.suggestionsEnabled(), false)
    saved.orbitui_search_word_suggestions = true
    H.eq(Search.suggestionsEnabled(), true); H.eq(writes, 0)
    H.eq(vocabulary.entries.angstrom.count, 1)
    H.eq(vocabulary.entries.ramqvist.count, 2)
    H.eq(vocabulary.entries.med, nil); H.eq(vocabulary.entries.the, nil)
    H.eq(vocabulary.entries.dragon.count, 1)
end)
H.test("suggestions preserve accents and rank repeated local names first", function()
    H.eq(Search.wordSuggestions(vocabulary, "ang", cursor("ang"))[1], "Ångest")
    H.eq(Search.wordSuggestions(vocabulary, "ångs", cursor("ångs"))[1], "Ångström")
    H.eq(Search.wordSuggestions(vocabulary, "hir", 4)[1], "Hirayasumi")
    H.eq(Search.wordSuggestions(vocabulary, "ram", 4)[1], "Ramqvist")
    H.eq(#Search.wordSuggestions(vocabulary, "hirayasumi", 11), 0)
end)
H.test("completing a word preserves the preceding query and never replaces mid-text", function()
    H.eq(Search.completeWord("Nina ång", cursor("Nina ång"), "Ångström"), "Nina Ångström ")
    H.eq(Search.completeWord("Nina ång", 3, "Ångström"), nil)
    H.eq(Search.completeWord("Nina ång", cursor("Nina ång"), "Ångström", true), nil)
    H.eq(Search.completeWord("Nina ång", cursor("Nina ång"), "Dragon"), nil)
    for _, text in ipairs{ "", "a", "hi ", "hi!", string.rep("x", 513) } do
        H.eq(#Search.wordSuggestions(vocabulary, text, cursor(text)), 0)
    end
end)
H.test("duplicate books, oversized metadata and large vocabularies remain bounded", function()
    local v = Search.wordVocabulary()
    v:add{ filepath = "/dup", title = "Dragon" }; v:add{ filepath = "/dup", title = "Dragon" }
    H.eq(v.entries.dragon.count, 1)
    v:add{ title = "Missing path" }
    v:add{ filepath = "/huge", title = string.rep("x", 1000000) }
    H.eq(#v.keys, 1)
    v:add{ filepath = "/unicode-edge", title = string.rep(" ", 504) .. "Ångström" }
    H.eq(v.entries.angstr, nil, "byte limit must not suggest a partial UTF-8 word")
    v:add{ filepath = "/authors", author = "Primary", authors = { "Primary", "Secondary" } }
    H.eq(v.entries.secondary.text, "Secondary")
    -- Synthetic 3,341-book library: no metadata getter/EPUB/provider exists.
    local function word(n)
        local s = ""
        repeat s = string.char(97 + n % 26) .. s; n = math.floor(n / 26) until n == 0
        return "Name" .. s
    end
    for i = 1, 3341 do v:add{ filepath = "/" .. i, title = word(i), author = "Karolina" } end
    v:finish(); H.eq(v.entries.karolina.count, 3341)
    H.eq(#Search.wordSuggestions(v, "nam", 4), 3)
    H.eq(Search.wordSuggestions(v, "kar", 4)[1], "Karolina")
end)
H.test("vocabulary and per-keystroke prefix work have hard caps", function()
    local v = Search.wordVocabulary()
    local function name(n)
        local text = ""
        repeat text = string.char(97 + n % 26) .. text; n = math.floor(n / 26) until n == 0
        return "Word" .. text
    end
    for i = 1, 11000 do
        v:add{ filepath = "/" .. i, title = name(i * 3) .. " " .. name(i * 3 + 1) .. " " .. name(i * 3 + 2),
            author = "Karolina" }
    end
    v:finish()
    H.eq(#v.keys, 12000); H.eq(v.entries.karolina.count, 10000)
    local entries, reads = v.entries, 0
    v.entries = setmetatable({}, { __index = function(_, key) reads = reads + 1; return entries[key] end })
    H.eq(#Search.wordSuggestions(v, "wor", 4), 3)
    assert(reads > 0 and reads <= 256)
    local authors = { "First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Excluded" }
    local bounded = Search.wordVocabulary()
    bounded:add{ filepath = "/authors", authors = authors }
    H.eq(bounded.entries.eighth.text, "Eighth"); H.eq(bounded.entries.excluded, nil)
end)

local width, height, queue, stack, paints, steps = 1000, 1400, {}, {}, 0, 0
local UI = {}
function UI:scheduleIn(delay, fn) queue[#queue + 1] = { delay = delay, fn = fn } end
function UI:unschedule(fn) for i = #queue, 1, -1 do if queue[i].fn == fn then table.remove(queue, i) end end end
function UI:show(d) stack[#stack + 1] = d end
function UI:close(d)
    for i = #stack, 1, -1 do if stack[i] == d then table.remove(stack, i) end end
    if d.onCloseWidget then d:onCloseWidget() end
end
function UI:isWidgetShown(d) for _, w in ipairs(stack) do if w == d then return true end end; return false end
function UI:getTopmostVisibleWidget() return { widget = stack[#stack] } end
function UI:setDirty() paints = paints + 1 end
local function tick()
    local item = table.remove(queue, 1)
    if item then item.fn() end
    return item
end
local function drain() local n = 0; while #queue > 0 do tick(); n = n + 1; assert(n < 2000) end end
package.loaded["ui/uimanager"] = UI
package.loaded.device = { screen = { getWidth = function() return width end, getHeight = function() return height end } }
local W = H.widget()
local Button = W:extend{}
function Button:setText(text) self.text = text end
function Button:enableDisable(value) self.enabled = value end
local Dialog = W:extend{}
function Dialog:init()
    self._input_widget = { charpos = cursor(self.input), keyboard = {} }
    function self._input_widget:goToEnd() self.charpos = cursor(self.parent.input); self.strike_callback() end
    self._input_widget.parent = self
    self.button_table = { by_id = {} }
    function self.button_table:getButtonById(id) return self.by_id[id] end
    for _, row in ipairs(self.buttons) do for _, b in ipairs(row) do
        if b.id then
            local copy = {}; for k, v in pairs(b) do copy[k] = v end
            self.button_table.by_id[b.id] = Button:new(copy)
        end
    end end
end
function Dialog:getInputText() return self.input end
function Dialog:setInputText(text) self.input = text end
function Dialog:refreshButtons() paints = paints + 1 end
function Dialog:onShowKeyboard() self.keyboard_shown = true end
function Dialog:onCloseWidget() self.closed = true end
local native = os.getenv("ORBITUI_NATIVE_SEARCH_DIR")
if native then
    -- Real minimum/current InputDialog construction and InputText edit/cursor/
    -- keyboard APIs. Rendering services are metric fixtures, not a device/font QA.
    local version = os.getenv("ORBITUI_NATIVE_SEARCH_VERSION") or "minimum"
    local dev = package.loaded.device
    setmetatable(dev, { __index = function(_, k)
        if k == "isTouchDevice" then return function() return true end end
        return function() return false end
    end })
    local scale = 1
    dev.screen.scaleBySize = function(_, n) return n * scale end
    G_reader_settings = { nilOrFalse = function() return false end, readSetting = function() return "en" end }
    package.loaded.gettext = function(s) return s end
    package.loaded.dbg = { guard = function() end }
    package.loaded.util = { splitToChars = chars }
    package.loaded["ffi/util"] = { template = function(s) return s end }
    package.loaded["ffi/blitbuffer"] = { COLOR_WHITE = 1, COLOR_BLACK = 0, COLOR_DARK_GRAY = .5 }
    package.loaded["ui/font"] = { getFace = function() return {} end }
    package.loaded["ui/size"] = { padding = { default = 4 }, margin = { default = 4 },
        border = { window = 1, inputtext = 1 }, radius = { window = 2 } }
    function W:_init() self.ges_events, self.key_events = {}, {} end
    function W:free() end
    function W:getSize()
        if self.dimen then return self.dimen end
        local h, w = 0, 0
        for _, child in ipairs(self) do local d = child:getSize(); h = h + d.h; w = math.max(w, d.w) end
        return { w = self.width or w, h = self.height or h }
    end
    function W:mergeLayoutInVertical(other)
        for _, row in ipairs(other.layout or {}) do self.layout[#self.layout + 1] = row end
    end
    function W:refocusWidget() end
    local Span = W:extend{}
    function Span:getSize() return { w = 0, h = self.width } end
    local Title = W:extend{}
    function Title:getHeight() return 42 * scale end
    function Title:getSize() return { w = self.width, h = self:getHeight() } end
    local Table = W:extend{}
    function Table:init()
        self.layout, self.by_id = self.buttons, {}
        self.height = #self.buttons * 42 * scale
        for _, row in ipairs(self.buttons) do for _, b in ipairs(row) do
            if b.id then
                local copy = {}; for k, v in pairs(b) do copy[k] = v end
                copy.width = self.width / #row
                self.by_id[b.id] = Button:new(copy)
            end
        end end
    end
    function Table:getButtonById(id) return self.by_id[id] end
    for _, name in ipairs{ "focusmanager", "checkbutton", "infomessage", "multiconfirmbox", "notification",
        "scrolltextwidget", "textboxwidget", "virtualkeyboard", "container/inputcontainer", "container/centercontainer",
        "container/framecontainer", "container/movablecontainer", "verticalgroup" } do
        package.loaded["ui/widget/" .. name] = W
    end
    package.loaded["ui/widget/verticalspan"] = Span
    package.loaded["ui/widget/titlebar"] = Title
    package.loaded["ui/widget/buttontable"] = Table
    package.loaded["ui/geometry"] = W
    package.loaded["ui/event"] = W
    package.loaded["ui/gesturerange"] = W
    local Text = assert(loadfile(native .. "/inputtext-" .. version .. ".lua"))()
    function Text:init()
        self.charlist = chars(self.text)
        self.charpos = self.charpos or #self.charlist + 1
        local owner = self
        self.text_widget = { getCharPos = function() return owner.charpos, 1 end,
            moveCursorEnd = function() owner.charpos = #owner.charlist + 1 end,
            scrollToBottom = function() owner.charpos = #owner.charlist + 1 end }
        self.keyboard = { showKeyboard = function() if self.parent then self.parent.keyboard_shown = true end end,
            hideKeyboard = function() end, isVisible = function() return true end }
    end
    function Text:initTextBox(text)
        self.text = text or table.concat(self.charlist)
        self:resyncPos()
    end
    function Text:getTextHeight() return 28 * scale end
    function Text:getLineHeight() return 28 * scale end
    function Text:getSize() return { w = self.width, h = (self.height or self:getTextHeight()) + 16 * scale } end
    function Text:getKeyboardDimen() return { w = width, h = height * .30 } end
    function Text:onCloseWidget() end
    package.loaded["ui/widget/inputtext"] = Text
    Dialog = assert(loadfile(native .. "/inputdialog-" .. version .. ".lua"))()
    local close = Dialog.onCloseWidget
    function Dialog:onCloseWidget() self.closed = true; return close(self) end
    H.test("actual native dialog has room for input, controls and suggestions at fixture sizes", function()
        for _, size in ipairs{ { 1000, 1400, 1 }, { 1400, 1000, 1 }, { 600, 800, 1 }, { 1000, 1400, 1.5 } } do
            width, height, scale = size[1], size[2], size[3]
            local rows = {}; for i = 1, 6 do rows[i] = {{ text = "Control" }} end
            local d = Dialog:new{ input = "Ång", buttons = rows }
            assert(d.text_height >= d._input_widget:getLineHeight())
            assert(d.dialog_frame:getSize().h + d._input_widget:getKeyboardDimen().h <= height)
            d:onCloseWidget()
        end
        width, height, scale = 1000, 1400, 1
    end)
end
package.loaded["ui/widget/inputdialog"] = Dialog
package.loaded["lib/bookshelf_profiles"] = {
    list = function() return { { key = "comics", label = "Manga" } } end,
    get = function(key) if key == "comics" then return { roots = { "/manga" } } end end,
    scope = function(profile) return { roots = profile.roots } end,
}
local generation, captured, fail, book_count = 1, nil, false, 24
package.loaded["lib/bookshelf_book_repository"] = {
    cachedSearchSnapshot = function(scope, query)
        captured = { scope = scope, query = query }
        if fail then error("cache unavailable") end
        local position, gen = 0, generation
        return { current = function() return generation == gen end, next = function()
            steps = steps + 1; position = position + 1
            if position <= book_count then return { filepath = "/manga/" .. position,
                title = "Hirayasumi", author = "Ramqvist" } end
        end }
    end,
    searchAll = function() error("never search per keystroke") end,
    getAllFilepaths = function() error("never scan per keystroke") end,
}
local function show(text)
    queue, stack, paints, steps = {}, {}, 0, 0
    return Search.show{ query = text or "hir", scope = "comics" }
end
local function button(d, i) return d.button_table:getButtonById("orbitui_word_" .. i) end
H.test("native-shaped suggestion buttons appear only after bounded cache-only turns", function()
    local d = show()
    H.eq(steps, 0); H.eq(button(d, 1).enabled, false)
    tick(); H.eq(steps, 8); H.eq(captured.scope.roots[1], "/manga")
    H.eq(queue[1].delay, 0.01)
    drain(); H.eq(button(d, 1).text, "Hirayasumi"); H.eq(button(d, 1).enabled, true)
    H.eq(steps, 25)
    button(d, 1).callback()
    H.eq(d:getInputText(), "Hirayasumi "); H.eq(d.closed, nil); H.eq(d.keyboard_shown, true)
    H.eq(button(d, 1).enabled, false); H.eq(writes, 0)
end)
H.test("current-shelf completions retain the exact source/filter/sort and deleted scopes fail closed", function()
    local Query = require("core/orbitui_shelf_query")
    local resolve = Query.resolve
    local filter, sort = { statuses = { "reading" } }, { { key = "title" } }
    Query.resolve = function(ref)
        if ref.chip == "gone" then return end
        return { source = { kind = "folder", id = "/manga/sub" }, filter = filter, sort = sort,
            scope = { roots = { "/manga" } }, label = "Current" }
    end
    queue, stack = {}, {}
    local d = Search.show{ scope = "current", ref = { chip = "valid" }, query = "hir" }
    drain()
    H.eq(captured.query.source.kind, "folder_flat")
    H.eq(captured.query.source.id, "/manga/sub")
    H.eq(captured.query.filter, filter); H.eq(captured.query.sort, sort)
    H.eq(captured.scope.roots[1], "/manga")
    H.eq(button(d, 1).text, "Hirayasumi")
    H.eq(Search.show{ scope = "current", ref = { chip = "gone" } }, nil)
    H.eq(notices[#notices], "This shelf is no longer available.")
    Query.resolve = resolve
end)
H.test("typing is debounced without rescanning and stale visible choices are inert", function()
    local d = show(); drain()
    d:setInputText("ram"); d._input_widget.charpos = 4
    button(d, 1).callback(); H.eq(d:getInputText(), "ram")
    for _i = 1, 30 do d._input_widget.strike_callback() end
    H.eq(#queue, 1); H.eq(queue[1].delay, 0.18)
    local old_steps = steps
    drain(); H.eq(steps, old_steps); H.eq(button(d, 1).text, "Ramqvist")
    d._input_widget.charpos = 2; button(d, 1).callback(); H.eq(d:getInputText(), "ram")
    d._input_widget.strike_callback(); drain(); H.eq(button(d, 1).enabled, false)
end)
H.test("typing during warm vocabulary construction does not restart it", function()
    local d = show(); tick()
    for _i = 1, 20 do d._input_widget.strike_callback() end
    H.eq(#queue, 1); drain(); H.eq(steps, 25)
end)
if native then
    H.test("actual native text-input and Unicode cursor APIs keep the keyboard and query intact", function()
        local d = show("Nina ra"); drain()
        d._input_widget:onTextInput("m")
        H.eq(d:getInputText(), "Nina ram")
        H.eq(d._input_widget.charpos, cursor("Nina ram"))
        drain(); button(d, 1).callback()
        H.eq(d:getInputText(), "Nina Ramqvist ")
        H.eq(d.keyboard_shown, true); H.eq(d.closed, nil)
    end)
end
H.test("close, sleep, rotation, covered views and generation changes retire owned work", function()
    for _, reason in ipairs{ "close", "sleep", "rotate", "cover", "metadata", "navigation", "replace" } do
        local d = show(); local callback = queue[1].fn
        if reason == "close" then UI:close(d)
        elseif reason == "sleep" then d:onSuspend()
        elseif reason == "rotate" then width = 1100
        elseif reason == "cover" then UI:show({})
        elseif reason == "metadata" then tick(); generation = generation + 1; callback = queue[1].fn
        elseif reason == "navigation" then UI._simpleui_navigation_generation = 9
        elseif reason == "replace" then Search.show{ scope = "comics" } end
        local before = paints
        callback(); H.eq(paints, before, reason .. " must not repaint")
        H.eq(button(d, 1).enabled, false)
        width, UI._simpleui_navigation_generation = 1000, nil
    end
end)
H.test("cache failures leave normal input and close usable", function()
    fail = true; local d = show(); drain()
    H.eq(button(d, 1).enabled, false); H.eq(d.input, "hir")
    d.buttons[2][1].callback(); H.eq(d.closed, true); fail = false
end)
H.test("suggestion retirement must not disable Close on the still-visible dialog", function()
    local d = show(); drain(); d:onSuspend()
    local text = d:getInputText()
    button(d, 1).callback(); H.eq(d:getInputText(), text)
    d.buttons[2][1].callback(); H.eq(d.closed, true)
end)
H.test("the toggle and its cache-only help are available in Swedish", function()
    local old = G_reader_settings
    G_reader_settings = { readSetting = function() return "sv" end, nilOrFalse = function() return false end }
    local d = show()
    assert(d.buttons[5][2].text:find("Ordförslag", 1, true))
    G_reader_settings = old
end)
H.test("the setting preserves input, is off by default and adds no row when off", function()
    local d = show("Typed"); d.buttons[5][2].callback()
    H.eq(d.closed, true)
    local next_dialog = stack[#stack]
    H.eq(next_dialog.input, "Typed"); H.eq(#next_dialog.buttons, 5)
    H.eq(saved.orbitui_search_word_suggestions, false); H.eq(writes, 1)
end)
H.finish()
