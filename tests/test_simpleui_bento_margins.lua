package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local f = assert(io.open("components/simpleui/engines/sui_screen_engine.lua"))
local source = f:read("*a"); f:close()
local first = assert(source:find("function ScreenWidget:_updatePage(", 1, true))
local last = assert(source:find("\nfunction ScreenWidget:_refresh(", first, true))

-- Geometry-only widgets: execute the real page builder without books or UI I/O.
local function widget(kind)
    local W = {}
    function W:new(args)
        args.kind = kind
        return setmetatable(args, { __index = W })
    end
    function W:clear()
        for i = #self, 1, -1 do self[i] = nil end
    end
    function W:getSize()
        if self.dimen then return self.dimen end
        if kind == "vspan" then return { w = 0, h = self.width } end
        if kind == "hspan" then return { w = self.width, h = 0 } end
        local w, h = 0, 0
        for _, child in ipairs(self) do
            local size = child:getSize()
            if kind == "horizontal" then
                w, h = w + size.w, math.max(h, size.h)
            else
                w, h = math.max(w, size.w), h + size.h
            end
        end
        return { w = w, h = h }
    end
    return W
end
local V, HG, VS, HS, Box = widget("vertical"), widget("horizontal"),
    widget("vspan"), widget("hspan"), widget("box")
local noop = function() end
local mods = {
    coverdeck = { id = "coverdeck", is_book_mod = true, height = 300 },
    recent = { id = "recent", is_book_mod = true, height = 80 },
    new_books = { id = "new_books", is_book_mod = true, height = 70 },
    clock = { id = "clock", height = 40 },
}
local widths, gaps, settings, landscape, label_hidden, background
local layout_key, pfx = "test_layout", "simpleui_hs_"
local Config = {
    getBentoWidth = function(id) return widths[id] or 100 end,
    setBentoWidth = function(value, id) widths[id] = value end,
    getModuleGapPx = function(id, prefix, default)
        H.eq(prefix, pfx)
        return gaps[id] or default
    end,
    isModuleBackgroundEnabled = function() return background end,
    flushCoverQueue = noop,
}
local ScreenWidget = {}
local env = setmetatable({
    ScreenWidget = ScreenWidget, Config = Config, MOD_GAP = 10, SIDE_PAD = 0,
    VerticalGroup = V, HorizontalGroup = HG, VerticalSpan = VS,
    HorizontalSpan = HS, LeftContainer = Box,
    Geom = { new = function(_, args) return args end },
    Screen = { getWidth = function() return 1264 end, getHeight = function() return 1680 end },
    UI = { getSpreadColWidth = function(w) return math.floor((w - 1) / 2) end,
        getPortraitInnerW = function() return 1264 end },
    SUISettings = {
        readSetting = function(_, key) return settings[key] end,
        nilOrTrue = function(_, key) return settings[key] ~= false end,
    },
    Registry = {
        loadOrder = function() return { "coverdeck", "recent", "new_books" } end,
        get = function(id) return mods[id] end,
        isEnabled = function(mod) return not mod.disabled end,
    },
    _isLandscape = function() return landscape end,
    _updateNavpager = noop,
    labelTextFor = function(mod) return not label_hidden and mod.id or nil end,
    labelRightTextFor = noop, pageNavFor = noop, sectionLabelSignature = noop,
    sectionLabel = function(_, w, id)
        return Box:new{ label_id = id, dimen = { w = w, h = 12 } }
    end,
    applyModuleBackground = function(id, content, w, label)
        if not label then return content end
        return V:new{
            Box:new{ label_id = id, dimen = { w = w, h = 12 } }, content,
        }
    end,
    logger = { warn = noop },
}, { __index = _G })
local body = source:sub(first, last - 1)
if setfenv then
    local fn = assert(loadstring(body)); setfenv(fn, env); fn()
else
    assert(load(body, "bento page builder", "t", env))()
end

local function screen(pages, prefix)
    widths, gaps, settings = {}, {}, {}
    landscape, label_hidden, background = false, false, false
    pfx = prefix or "simpleui_hs_"
    settings[layout_key] = { pages = {} }
    for _, ids in ipairs(pages) do
        settings[layout_key].pages[#settings[layout_key].pages + 1] = { modules = ids }
    end
    settings.simpleui_topbar_enabled = true
    settings[pfx .. "overflow_warn"] = false
    for _, mod in pairs(mods) do mod.disabled = mod.id == "coverdeck" end
    for _, ids in ipairs(pages) do
        for _, id in ipairs(ids) do mods[id].disabled = false end
    end
    return setmetatable({
        _pfx = pfx, _id = "test", _layout_key = layout_key, _current_page = 1,
        _layout_inner_w = 1264, _body = V:new{ align = "left" },
        _buildCtx = function() return { _has_content = true } end,
        _vspan = function(_, h) return VS:new{ width = h } end,
        _buildModWidget = function(_, mod, w)
            local content = Box:new{ content_id = mod.id, dimen = { w = w, h = mod.height } }
            return content, content
        end,
        _makeModWrapper = function(_, _, content) return Box:new{ content } end,
        _updateFooter = noop,
    }, { __index = ScreenWidget })
end

local function positions(tree)
    local out = { labels = {}, contents = {} }
    local function walk(node, x, y)
        if node.label_id then out.labels[node.label_id] = { x = x, y = y } end
        if node.content_id then out.contents[node.content_id] = { x = x, y = y } end
        local size = node:getSize()
        for _, child in ipairs(node) do
            local cs = child:getSize()
            local cy = y
            if node.kind == "horizontal" and node.align == "center" then
                cy = cy + math.floor((size.h - cs.h) / 2)
            end
            walk(child, x, cy)
            if node.kind == "horizontal" then x = x + cs.w
            else y = y + cs.h end
        end
    end
    walk(tree, 0, 0)
    return out
end

H.test("each column uses its own margin above label and content", function()
    local s = screen({ { "coverdeck", "new_books" } })
    widths.coverdeck, widths.new_books = 55, 45
    gaps.coverdeck, gaps.new_books = 30, 0
    s:_updatePage(false)
    local p = positions(s._body)
    H.eq(p.labels.coverdeck.y, 30)
    H.eq(p.labels.new_books.y, 0)
    H.eq(p.contents.new_books.y, 12)
end)

H.test("stacked New Books margin moves only that module, not its neighbour or predecessor", function()
    local s = screen({ { "coverdeck", "recent", "new_books" } })
    widths.coverdeck, widths.recent, widths.new_books = 55, 45, 45
    gaps.coverdeck, gaps.recent, gaps.new_books = 30, 0, 0
    s:_updatePage(false)
    local before = positions(s._body)
    gaps.new_books = 30
    s:_updatePage(false)
    local after = positions(s._body)
    H.eq(before.labels.new_books.y, 92)
    H.eq(after.labels.new_books.y - before.labels.new_books.y, 30)
    H.eq(after.labels.recent.y, before.labels.recent.y)
    H.eq(after.labels.coverdeck.y, before.labels.coverdeck.y)
    H.eq(after.contents.new_books.y - after.labels.new_books.y, 12)
end)

H.test("a taller right stack does not pull the left module downward", function()
    local s = screen({ { "recent", "coverdeck", "new_books" } })
    widths.recent, widths.coverdeck, widths.new_books = 55, 45, 45
    gaps.recent, gaps.coverdeck, gaps.new_books = 10, 10, 10
    s:_updatePage(false)
    local before = positions(s._body)
    gaps.new_books = 30
    s:_updatePage(false)
    local after = positions(s._body)
    H.eq(after.labels.recent.y, 10)
    H.eq(after.labels.recent.y, before.labels.recent.y)
    H.eq(after.labels.new_books.y - before.labels.new_books.y, 20)
end)

H.test("warm cached pages pick up changed gaps without changing widths or module order", function()
    local s = screen({ { "recent", "new_books" } })
    widths.recent, widths.new_books = 55, 45
    gaps.recent, gaps.new_books = 0, 0
    s:_updatePage(false)
    local cache = s._enabled_mods_cache
    s:_updatePage(true)
    H.eq(s._enabled_mods_cache, cache)
    gaps.new_books = 20
    s:_updatePage(true)
    H.eq(positions(s._body).labels.new_books.y, 20)
    assert(s._enabled_mods_cache ~= cache, "gap change must invalidate layout cache")
end)

H.test("legacy module order also invalidates cached margins", function()
    local s = screen({ { "coverdeck", "recent", "new_books" } })
    settings[layout_key] = nil
    env.splitOrderIntoPages = function(order) return { order } end
    widths.coverdeck, widths.recent, widths.new_books = 55, 45, 45
    gaps.coverdeck, gaps.recent, gaps.new_books = 0, 0, 0
    s:_updatePage(false)
    local before = positions(s._body)
    gaps.new_books = 30
    s:_updatePage(true)
    local after = positions(s._body)
    H.eq(after.labels.new_books.y - before.labels.new_books.y, 30)
    H.eq(after.labels.coverdeck.y, before.labels.coverdeck.y)
    H.eq(after.labels.recent.y, before.labels.recent.y)
end)

H.test("full width rows keep their existing spacing including topbar-off padding", function()
    for _, topbar in ipairs({ true, false }) do
        local s = screen({ { "recent", "new_books" } })
        settings.simpleui_topbar_enabled = topbar
        gaps.recent, gaps.new_books = 20, 30
        s:_updatePage(false)
        local p = positions(s._body)
        local pad = topbar and 0 or 10
        H.eq(p.labels.recent.y, 20 + pad)
        H.eq(p.labels.new_books.y, 20 + pad + 12 + mods.recent.height + 30)
    end
end)

H.test("topbar-off padding is shared but column margins remain independent", function()
    local s = screen({ { "coverdeck", "new_books" } })
    settings.simpleui_topbar_enabled = false
    widths.coverdeck, widths.new_books = 55, 45
    gaps.coverdeck, gaps.new_books = 0, 30
    s:_updatePage(false)
    local p = positions(s._body)
    H.eq(p.labels.coverdeck.y, 10)
    H.eq(p.labels.new_books.y, 40)
end)

H.test("three columns below a full width row start from the same row boundary", function()
    local s = screen({ { "clock", "coverdeck", "recent", "new_books" } })
    widths.coverdeck, widths.recent, widths.new_books = 40, 30, 30
    gaps.clock, gaps.coverdeck, gaps.recent, gaps.new_books = 10, 0, 10, 30
    s:_updatePage(false)
    local p = positions(s._body)
    local row_top = 10 + 12 + mods.clock.height
    H.eq(p.labels.coverdeck.y, row_top)
    H.eq(p.labels.recent.y, row_top + 10)
    H.eq(p.labels.new_books.y, row_top + 30)
end)

H.test("centred narrow rows keep their width and respect independent top margins", function()
    local s = screen({ { "recent", "new_books" } })
    widths.recent, widths.new_books = 30, 30
    gaps.recent, gaps.new_books = 30, 0
    s:_updatePage(false)
    local p = positions(s._body)
    H.eq(p.labels.recent.x, 253)
    H.eq(p.labels.new_books.x, 632)
    H.eq(p.labels.recent.y, 30)
    H.eq(p.labels.new_books.y, 0)
end)

H.test("landscape pages each retain independent bento margins", function()
    local s = screen({ { "coverdeck", "recent" }, { "new_books", "clock" } })
    landscape = true
    widths.coverdeck, widths.recent, widths.new_books, widths.clock = 55, 45, 60, 40
    gaps.coverdeck, gaps.recent, gaps.new_books, gaps.clock = 30, 0, 10, 20
    s:_updatePage(false)
    local p = positions(s._body)
    H.eq(p.labels.coverdeck.y, 30)
    H.eq(p.labels.recent.y, 0)
    H.eq(p.labels.new_books.y, 10)
    H.eq(p.labels.clock.y, 20)
    assert(p.labels.new_books.x > p.labels.recent.x)
end)

H.test("custom screens, hidden labels and module backgrounds use the same margins", function()
    for _, hidden in ipairs({ true, false }) do
        for _, bg in ipairs({ true, false }) do
            local s = screen({ { "coverdeck", "new_books" } }, "simpleui_cs_reading_")
            label_hidden, background = hidden, bg
            widths.coverdeck, widths.new_books = 55, 45
            gaps.coverdeck, gaps.new_books = 0, 20
            s:_updatePage(false)
            local p = positions(s._body)
            H.eq(p.contents.new_books.y, hidden and 20 or 32)
            if not hidden then H.eq(p.labels.new_books.y, 20) end
            local slot = s._book_mod_slots.new_books
            H.eq(slot.parent[slot.index][1].kind, bg and not hidden and "vertical" or "box")
            H.eq(slot.content.content_id, "new_books")
            if not hidden and not bg then
                local label = s._book_mod_label_slots.new_books
                H.eq(label.parent[label.index].label_id, "new_books")
            end
        end
    end
end)

H.test("clock and book update slots still address their wrappers, not margin spacers", function()
    local s = screen({ { "clock", "new_books" } })
    widths.clock, widths.new_books = 40, 60
    gaps.clock, gaps.new_books = 30, 20
    s:_updatePage(false)
    H.eq(s._clock_body_ref[s._clock_body_idx][1].content_id, "clock")
    local slot = s._book_mod_slots.new_books
    H.eq(slot.parent[slot.index][1].content_id, "new_books")
end)

H.finish()
