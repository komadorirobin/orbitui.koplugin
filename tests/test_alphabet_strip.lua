local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Order = require("core/orbitui_shelf_sort")
local Adapter = require("adapters/orbitui_shelf_sort")
local Widget = H.widget()
local unpack_values = unpack or table.unpack
-- WidgetContainer, not Widget, owns child propagation in real KOReader.
Widget.handleEvent = function(self, event)
    local handler = self[event.handler]
    if handler then return handler(self, unpack_values(event.args or {}, 1, event.n or #(event.args or {}))) end
end
local Input = Widget:extend{}
function Input:_init() self.ges_events = {} end
function Input:handleEvent(event)
    for _, child in ipairs(self) do if child:handleEvent(event) then return true end end
    return Widget.handleEvent(self, event)
end
function Input:onGesture(ges)
    for name, ranges in pairs(self.ges_events) do
        if ranges[1]:match(ges) and self["on" .. name](self, nil, ges) then return true end
    end
end
local function geom(o)
    function o:contains(pos)
        return pos and pos.x >= self.x and pos.x < self.x + self.w and pos.y >= self.y and pos.y < self.y + self.h
    end
    return o
end
package.loaded["ui/geometry"] = { new = function(_, o) return geom(o) end }
package.loaded["ui/gesturerange"] = { new = function(_, o)
    function o:match(ges)
        local r = type(self.range) == "function" and self.range() or self.range
        return self.ges == ges.ges and r:contains(ges.pos)
    end
    return o
end }
package.loaded["ui/event"] = { new = function(_, name, ...)
    return { handler = "on" .. name, args = { ... }, n = select("#", ...) }
end }
package.loaded.logger = { dbg = function() end, warn = function() end }
package.loaded.gettext = function(s) return s end
local width, height, touch = 600, 800, true
local Screen = { getWidth = function() return width end, getHeight = function() return height end,
    scaleBySize = function(_, n) return n end }
package.loaded.device = { screen = Screen, hasKeys = function() return false end,
    isTouchDevice = function() return touch end }
local top, queue, dirty, notices, reads, writes, draws = nil, {}, {}, {}, 0, 0, {}
local UI = { getTopmostVisibleWidget = function() return top end,
    scheduleIn = function(_, delay, fn) queue[#queue + 1] = { fn = fn, delay = delay } end,
    unschedule = function(_, fn) for i = #queue, 1, -1 do if queue[i].fn == fn then table.remove(queue, i) end end end,
    nextTick = function(_, fn) queue[#queue + 1] = { fn = fn, delay = 0 } end,
    setDirty = function(_, owner, mode, rect) dirty[#dirty + 1] = { owner = owner, mode = mode, rect = rect } end }
package.loaded["ui/uimanager"] = UI
local native = os.getenv("ORBITUI_NATIVE_INPUT_DIR")
if native then
    package.loaded["ui/widget/widget"] = Widget
    package.loaded.depgraph = {}
    package.loaded["ui/widget/container/widgetcontainer"] = assert(loadfile(native .. "/widgetcontainer.lua"))()
    Input = assert(loadfile(native .. "/inputcontainer.lua"))()
end
package.loaded["ui/widget/container/inputcontainer"] = Input
package.loaded["core/orbitui_context"] = { notify = function(s) notices[#notices + 1] = s end }
local saved = {}
package.loaded["infra/sui_store"] = { get = function(_, k) return saved[k] end,
    set = function(_, k, value) writes = writes + 1; saved[k] = value end }
local source_kind, sort, drill, profile = "folder", { { key = "title" } }, nil, "manga"
local Query = { capture = function() return { profile = profile, chip = "fiction", drill = drill } end,
    resolve = function() return { source = { kind = source_kind, id = "/manga" }, sort = sort } end }
package.loaded["core/orbitui_shelf_query"] = Query
package.loaded["lib/bookshelf_profiles"] = { folderSortPriority = function() return sort end }
local items, fail, partial
local repo = { getSortPriority = function() return sort end }
package.loaded["lib/bookshelf_book_repository"] = repo
package.loaded["lib/bookshelf_sort_engine"] = { sortKeyValue = function(book, key)
    return book[key] or book.title
end }
local Text = Widget:extend{}
function Text:getSize() return { w = #self.text * 2, h = math.min(10, self.face) } end
function Text:paintTo(bb, x, y) bb:paintRect(x, y, 1, 1, self.fgcolor) end
function Text:free() self.freed = true end
package.loaded["lib/bookshelf_colour_text"] = Text
package.loaded["ui/font"] = { getFace = function(_, _, size) return size end }
package.loaded["ffi/blitbuffer"] = { COLOR_BLACK = 0, COLOR_WHITE = 255 }
local bb = { paintRect = function(_, x, y, w, h, color)
    draws[#draws + 1] = { x = x, y = y, w = w, h = h, color = color }
end }
local Base = Widget:extend{}
function Base:handleEvent() self.events = (self.events or 0) + 1; return true end
function Base:paintTo() end
local Class = {
    _rebuild = function(self) self.rebuilds = self.rebuilds + 1; self[1] = Base:new{}; return "built", nil, 3 end,
    _swapShelvesInPlace = function(self) self.swaps = self.swaps + 1 end,
    paintTo = function(self, target) self[1]:paintTo(target, 0, 0) end,
    _viewSize = function() return 4 end,
    _isSpineMode = function(self) return self.mode == "spines" end,
    _isListMode = function(self) return self.mode == "list" end,
    _chipListValue = function(self) return self.columns end,
    _simpleUIReservedBottom = function() return 70 end,
    _paginationFooterReserveHeight = function() return 30 end,
    _clampCursor = function() end, _syncPageFromCursor = function(self) self.page = math.floor((self._cursor - 1) / 4) + 1 end,
    _setSpineCursor = function(self, n) self._cursor = n; self.skip = 0 end,
    _prepareSpineItems = function(_, books) return books end,
    _jumpScanList = function()
        reads = reads + 1; H.eq(repo.spine_light, true); H.eq(repo.suppress_covers, true)
        if fail then error("metadata busy") end
        return items, "title"
    end,
    _spineCachedFetch = function()
        reads = reads + 1
        if fail then error("metadata busy") end
        return items, partial
    end,
}
Adapter.alphabet(Class)
local function flush(limit)
    local count = 0
    while #queue > 0 and (not limit or count < limit) do
        local q = table.remove(queue, 1); q.fn(); count = count + 1; assert(count < 50)
    end
end
local function reset(enabled)
    saved, notices, queue, dirty, draws = {}, {}, {}, {}, {}
    reads, writes, fail, partial = 0, 0, false, nil
    width, height, touch, profile, drill, source_kind = 600, 800, true, "manga", nil, "folder"
    sort = { { key = "title" } }; UI._simpleui_navigation_generation = 1
    items = { { title = "Apple" }, { title = "Banana" }, { title = "C" }, { title = "D" },
        { title = "E" }, { title = "F" }, { title = "G" }, { title = "Manga" }, { title = "Åland" }, { title = "Ön" } }
    local w = setmetatable({ profile_key = "manga", chip = "fiction", _cursor = 1, mode = "covers", columns = 1,
        _drilldown_path = {}, _total_items = 10, rebuilds = 0, swaps = 0, _spine_shown = 4,
        _shelf_dims = { PAD = 18, wipe_rows_top = 250 } }, { __index = Class })
    top = w
    if enabled then Adapter.saveView(Query.capture(), "alphabet", true) end
    writes = 0
    w:_rebuild()
    return w, w._orbitui_alphabet
end
local function gesture(w, kind, y, x)
    local ev = { ges = kind, pos = { x = x or 590, y = y } }
    return w[1]:handleEvent({ handler = "onGesture", args = { ev }, n = 1 })
end
local function at(strip, letter)
    for i, value in ipairs(strip.letters) do if value == letter then return strip.rect.y + (i - .5) * strip.rect.h / #strip.letters end end
end
H.test("alphabet keeps Å Ä Ö distinct, folds other accents and safely buckets Unicode", function()
    H.eq(#Order.alphabetLetters(), 30); H.eq(Order.alphabetLetters(true)[1], "Ö")
    for _, value in ipairs{ "å", "Åland", " Åke" } do H.eq(Order.alphabetBucket(value), "Å") end
    H.eq(Order.alphabetBucket("Äpple"), "Ä"); H.eq(Order.alphabetBucket("ö"), "Ö")
    H.eq(Order.alphabetBucket("Émile"), "E"); H.eq(Order.alphabetBucket("Manga"), "M")
    H.eq(Order.alphabetBucket("日本語"), "#"); H.eq(Order.alphabetBucket("123"), "#"); H.eq(Order.alphabetBucket(nil), "#")
end)
H.test("letter lookup keeps native order, proxies and first matching series block", function()
    local books = { { title = "Z" }, { title = "Wrong", _series_sort_book = { title = "Apple" } }, { title = "Again" } }
    local key = package.loaded["lib/bookshelf_sort_engine"].sortKeyValue
    H.eq(Order.alphabetTarget(books, "title", "A", key), 2); H.eq(books[1].title, "Z")
    H.eq(Order.alphabetTarget(books, "title", "Ö", key), nil)
end)
H.test("default off leaves native tree, results and settings untouched", function()
    local w, strip = reset(false)
    H.eq(strip, nil); H.eq(w[1]._orbitui_alphabet_layer, nil); H.eq(writes, 0); H.eq(reads, 0)
    local a, b, c = w:_rebuild(); H.eq(a, "built"); H.eq(b, nil); H.eq(c, 3)
end)
H.test("enabled strip only consumes existing side margin, not hero, footer or shelf width", function()
    local w, strip = reset(true)
    assert(strip); H.eq(strip.rect.x, 582); H.eq(strip.rect.y, 250); H.eq(strip.rect.h, 450)
    H.eq(w._shelf_dims.PAD, 18); H.eq(w._shelf_dims.content_w, nil)
    H.eq(reads, 0); H.eq(writes, 0)
    gesture(w, "tap", 100); H.eq(reads, 0); H.eq(w[1][2].events, 1)
end)
H.test("dragging is coalesced, clipped and performs no scans or page changes", function()
    local w, strip = reset(true)
    H.eq(strip:current(), true, "live gesture owner")
    assert(strip.ges_events.LetterPan[1]:match{ ges = "pan", pos = { x = 590, y = at(strip, "M") } })
    for _ = 1, 30 do gesture(w, "pan", at(strip, "M")) end
    H.eq(strip.letter, "M"); H.eq(reads, 0); H.eq(w.swaps, 0); H.eq(w.rebuilds, 1); H.eq(writes, 0)
    H.eq(#queue, 1); H.eq(#dirty, 2); H.eq(dirty[1].rect, strip.rect); H.eq(dirty[2].rect, strip.bubble)
    H.eq(dirty[1].mode, "fast"); flush(); H.eq(reads, 0)
    w:paintTo(bb); w:paintTo(bb)
    for _, r in ipairs(draws) do
        local function within(a) return r.x >= a.x and r.y >= a.y and r.x + r.w <= a.x + a.w and r.y + r.h <= a.y + a.h end
        assert(within(strip.rect) or within(strip.bubble), "painting escaped the two small regions")
    end
end)
H.test("tap and release navigate once to the native page without opening a reader", function()
    local w, strip = reset(true); gesture(w, "tap", at(strip, "M")); H.eq(reads, 0)
    flush(); H.eq(reads, 1); H.eq(w._cursor, 5); H.eq(w.page, 2); H.eq(w.swaps, 1)
    H.eq(w.rebuilds, 1); H.eq(writes, 0)
end)
H.test("active drag captures release outside the narrow strip and clamps end letters", function()
    local w, strip = reset(true); gesture(w, "pan", at(strip, "Å"))
    gesture(w, "pan_release", at(strip, "Å"), 100); flush(); H.eq(w._cursor, 9); H.eq(reads, 1)
    H.eq(Order.alphabetAt(-100, strip.rect, strip.letters), "#")
    H.eq(Order.alphabetAt(9999, strip.rect, strip.letters), "Ö")
end)
H.test("quick filters use the same scoped producer and restore native flags after failures", function()
    local w = reset(true); Adapter.saveView(Query.capture(), "filter", "reading"); w:_rebuild()
    local original = Adapter.browseBooks
    Adapter.browseBooks = function(ref, prefs, counts)
        H.eq(ref.profile, "manga"); H.eq(prefs.filter, "reading"); H.eq(counts, false)
        reads = reads + 1; return { { title = "A" }, { title = "M" } }
    end
    repo.spine_light, repo.suppress_covers = false, nil
    H.eq(Adapter.alphabetJump(w, w._orbitui_alphabet.context, "M"), true); H.eq(w._cursor, 1)
    H.eq(repo.spine_light, false); H.eq(repo.suppress_covers, nil)
    Adapter.browseBooks = function() error("busy") end
    local cursor = w._cursor
    H.eq(Adapter.alphabetJump(w, w._orbitui_alphabet.context, "M"), false); H.eq(w._cursor, cursor)
    H.eq(repo.spine_light, false); H.eq(repo.suppress_covers, nil); assert(#notices > 0)
    Adapter.browseBooks = original
end)
H.test("spines anchor an actual item, not their upper-bound capacity", function()
    local w = reset(true); w.mode = "spines"; w:_rebuild()
    H.eq(Adapter.alphabetJump(w, w._orbitui_alphabet.context, "M"), true)
    H.eq(w._cursor, 8); H.eq(w.skip, 0); H.eq(#w._spine_hist, 0)
    partial = 100; w:_rebuild(); local before = w._cursor
    H.eq(Adapter.alphabetJump(w, w._orbitui_alphabet.context, "M"), false); H.eq(w._cursor, before)
end)
H.test("module fillers keep the grid cursor in visual-slot units", function()
    local w = reset(true)
    local modules = dofile(root .. "/components/bookshelf/lib/bookshelf_shelf_modules.lua")
    package.loaded["lib/bookshelf_shelf_modules"] = modules
    local mods = { { id = "test", after = 0, w = 4 } }
    w._activeShelfModules = function() return mods end
    w._nCols = function() return 4 end
    local stream = modules.stream(#items, mods, 4)
    local target
    for slot, d in ipairs(stream) do if d.item == 8 then target = slot end end
    assert(target and target > 8)
    H.eq(Adapter.alphabetJump(w, w._orbitui_alphabet.context, "M"), true)
    H.eq(w._cursor, math.floor((target - 1) / 4) * 4 + 1)
    H.eq(Order.alphabetTarget({ { shelf_module = {} }, { title = "123" } }, "title", "#",
        package.loaded["lib/bookshelf_sort_engine"].sortKeyValue), 2)
end)
H.test("fixed-profile folder drills use their real level-one priority", function()
    local w = reset(true); w.profile = { id = "manga" }
    drill = { kind = "folder", id = "/manga/Sub" }; w:_rebuild()
    -- Enable this separate place explicitly; another place is not modified.
    H.eq(w._orbitui_alphabet, nil)
    Adapter.saveView(Query.capture(), "alphabet", true); w:_rebuild()
    H.eq(w._orbitui_alphabet.context.key, "title")
end)
H.test("missing letters and native read errors retain page, flags and data", function()
    local w, strip = reset(true); repo.spine_light, repo.suppress_covers = nil, false
    H.eq(Adapter.alphabetJump(w, strip.context, "X"), false); H.eq(w._cursor, 1)
    fail = true; H.eq(Adapter.alphabetJump(w, strip.context, "A"), false)
    H.eq(repo.spine_light, nil); H.eq(repo.suppress_covers, false); H.eq(w.swaps, 0); H.eq(writes, 0)
end)
H.test("hidden and nonalphabetical contexts never change sorting to show the strip", function()
    local w = reset(true)
    sort = { { key = "last_opened" } }; w:_rebuild(); H.eq(w._orbitui_alphabet, nil)
    sort = { { key = "title", reverse = true } }; w:_rebuild(); H.eq(w._orbitui_alphabet.letters[1], "Ö")
    drill = { kind = "series", id = "One" }; w:_rebuild(); H.eq(w._orbitui_alphabet, nil)
    drill = nil; w.mode, w.columns = "list", 2; w:_rebuild(); H.eq(w._orbitui_alphabet, nil)
    w.mode = "covers"; source_kind = "opds"; w:_rebuild(); H.eq(w._orbitui_alphabet, nil)
    source_kind, touch = "folder", false; w:_rebuild(); H.eq(w._orbitui_alphabet, nil)
    touch = true; w._total_items = 4; w:_rebuild(); H.eq(w._orbitui_alphabet, nil)
end)
H.test("stale navigation, covered owners, rotation and close cancel all deferred jumps", function()
    for _, invalidate in ipairs{
        function(w) UI._simpleui_navigation_generation = 2 end,
        function(w) top = {} end,
        function(w) width = 800 end,
        function(w) w:onCloseWidget() end,
        function(w) w:_rebuild() end,
    } do
        local w, strip = reset(true); gesture(w, "tap", at(strip, "M")); invalidate(w); flush()
        H.eq(reads, 0); H.eq(w.swaps, 0)
    end
end)
H.test("suspend retires drag without drawing, resume restores only the visible owner", function()
    local w, strip = reset(true); gesture(w, "pan", at(strip, "M")); local n = #dirty
    w:onSuspend(); flush(); H.eq(#dirty, n); H.eq(reads, 0); H.eq(strip.retired, true)
    top = {}; w:onResume(); H.eq(w._orbitui_alphabet, nil)
    top = w; w:onResume(); assert(w._orbitui_alphabet); H.eq(reads, 0)
end)
H.test("covered drag restores on next visible paint without resurrecting a hidden owner", function()
    local w, strip = reset(true); gesture(w, "pan", at(strip, "M"))
    top = {}; flush(); H.eq(strip.retired, true); H.eq(reads, 0)
    local count = #dirty; w:paintTo(bb); H.eq(#dirty, count)
    top = w; w:paintTo(bb); assert(not w._orbitui_alphabet.retired)
    assert(#dirty > count); H.eq(dirty[#dirty].rect, strip.bubble)
end)
H.test("landscape and tight margins stay inside the dock-safe viewport", function()
    local w = reset(true); width, height = 1200, 600
    w._shelf_dims.PAD = 36; w._shelf_dims.wipe_rows_top = 150; w:_rebuild()
    local strip = w._orbitui_alphabet
    H.eq(strip.rect.x + strip.rect.w, width); H.eq(strip.rect.y + strip.rect.h, 500)
    w._shelf_dims.PAD = 3; w:_rebuild(); H.eq(w._orbitui_alphabet, nil)
end)
H.test("actual native sort keys honour articles and a series' proxy instead of volume title", function()
    local engine = dofile(root .. "/components/bookshelf/lib/bookshelf_sort_engine.lua")
    local books = { { title = "The Apple" }, { title = "Volume One", _series_sort_book = { title = "The Mountain" } } }
    H.eq(Order.alphabetTarget(books, "title", "A", engine.sortKeyValue), 1)
    H.eq(Order.alphabetTarget(books, "title", "M", engine.sortKeyValue), 2)
    H.eq(Order.alphabetTarget(books, "title", "V", engine.sortKeyValue), nil)
end)
H.test("per-place enable is SV/EN, opt-in and preserves future and unrelated preferences", function()
    reset(false); Adapter.saveView(Query.capture(), "alphabet", true)
    profile = "books"; H.eq(Adapter.viewPrefs(Query.capture()).alphabet, nil)
    profile = "manga"; H.eq(Adapter.viewPrefs(Query.capture()).alphabet, true)
    Adapter.saveView(Query.capture(), "alphabet", false); H.eq(Adapter.viewPrefs(Query.capture()).alphabet, false)
    saved.orbitui_browse_views.schema = 999
    H.eq(Adapter.saveView(Query.capture(), "alphabet", true), false)
    G_reader_settings = { readSetting = function() return "sv" end }
    H.eq(require("core/orbitui_i18n")("Alphabet strip"), "Bokstavslist")
    G_reader_settings = { readSetting = function() return "en" end }
    H.eq(require("core/orbitui_i18n")("Alphabet strip"), "Alphabet strip")
end)
local raster = os.getenv("ORBITUI_NATIVE_BB_DIR")
if jit and raster then
    local ffi = require("ffi")
    ffi.cdef[[void *malloc(size_t); void *calloc(size_t,size_t); void free(void *);]]
    package.loaded["ffi/posix_h"] = true
    package.loaded["ffi/util"] = { idiv = function(a, b) return math.floor(a / b) end }
    ffi.loadlib = function() return ffi.load(assert(os.getenv("ORBITUI_NATIVE_BB_LIB"))) end
    local BB = dofile(raster .. "/ffi/blitbuffer.lua")
    package.loaded["ffi/blitbuffer"] = BB
    local Clip = dofile(root .. "/components/bookshelf/lib/bookshelf_clip_bb.lua")
    H.test("real grey/RGB, CBB/software and inverted strip fills remain clipped and preserve buffer flags", function()
        for _, kind in ipairs{ BB.TYPE_BB8, BB.TYPE_BBRGB32 } do
            for _, cbb in ipairs{ false, true } do
                BB:setUseCBB(cbb)
                for _, inverse in ipairs{ 0, 1 } do
                    local w, strip = reset(true); gesture(w, "pan", at(strip, "M"))
                    local target = BB.new(width, height, kind)
                    target:paintRect(0, 0, width, height, BB.Color8(82)); target:setInverse(inverse)
                    local before = target:getPixel(10, 10):getColor8().a
                    strip:paintTo(Clip.new(target, { strip.rect, strip.bubble }))
                    H.eq(target:getPixel(10, 10):getColor8().a, before)
                    H.eq(target:getInverse(), inverse)
                    local a = target:getPixel(strip.rect.x + 1, strip.rect.y + 1):getColor8().a
                    local b = target:getPixel(strip.bubble.x + 1, strip.bubble.y + 1):getColor8().a
                    assert(math.abs(a - b) > 100, "bubble/strip contrast lost")
                    target:free(); w:onCloseWidget(); flush()
                end
            end
        end
    end)
end
H.finish()
