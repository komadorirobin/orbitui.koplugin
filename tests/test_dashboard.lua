package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_dashboard")

H.test("custom headings stay single-line and invalid or empty values use the default", function()
    H.eq(Model.normalizeHeading("  Min\n\t boklista  "), "Min boklista")
    H.eq(Model.normalizeHeading(" \t\r\n"), nil)
    H.eq(Model.normalizeHeading(false), nil)
    H.eq(Model.normalizeHeading({}), nil)
    H.eq(Model.heading({ want = 12 }, "want", "Default"), "Default")
    H.eq(Model.heading(false, "want", "Default"), "Default")
    H.eq(Model.heading({ want = "Mina böcker 日本語" }, "want", "Default"), "Mina böcker 日本語")
end)

H.test("dashboard insertion and removal preserve all existing pages and settings", function()
    local original = { custom = "keep", pages = {
        { id = 3, modules = { "currently", "hardcover" } },
        { id = "custom", modules = { { id = "recent", width = 50 } } },
    } }
    local added = Model.withPage(original, true)
    H.eq(#added.pages, 3); H.eq(added.pages[1].id, 4)
    H.eq(added.pages[2].modules[2], "hardcover"); H.eq(#original.pages, 2)
    H.eq(#Model.withPage(added, true).pages, 3)
    added.pages[2].modules[3] = "user_added_later"
    local removed = Model.withPage(added, false)
    H.eq(#removed.pages, 2); H.eq(removed.pages[1].modules[3], "user_added_later")
    H.eq(removed.pages[2].modules[1].width, 50); H.eq(removed.custom, "keep")
    H.eq(#added.pages, 3)
end)

H.test("only empty dashboard-owned pages are removed, never user additions", function()
    local added = Model.withPage({ pages = { { id = 1, modules = {} } } }, true)
    added.pages[1].modules[2] = "quote"
    local removed = Model.withPage(added, false)
    H.eq(#removed.pages, 2); H.eq(removed.pages[1].modules[1], "quote")
    H.eq(#removed.pages[2].modules, 0)
    H.eq(#Model.withPage({ pages = { { orbitui_dashboard_page = true, modules = { Model.id } } } }, false).pages, 1)
end)

H.test("cards stay separated and inside the body at reader and landscape sizes", function()
    for _, size in ipairs({ { 600, 730 }, { 1100, 1350 }, { 300, 400 }, { 450, 610 }, { 800, 480 } }) do
        local p = Model.plan(size[1], size[2])
        local boxes = { p.hero, p.ongoing, p.goal, p.want, p.new }
        for _, r in ipairs(p.stats) do boxes[#boxes + 1] = r end
        for i, a in ipairs(boxes) do
            assert(a.x >= 0 and a.y >= p.header_h and a.w > 0 and a.h > 0)
            assert(a.x + a.w <= p.w and a.y + a.h <= p.h)
            for j = i + 1, #boxes do
                local b = boxes[j]
                assert(a.x + a.w <= b.x or b.x + b.w <= a.x
                    or a.y + a.h <= b.y or b.y + b.h <= a.y)
            end
        end
    end
end)

local books = {
    ["/current"] = { title = "Current book", authors = "An Author", percent = .59 },
    ["/first"] = { title = "First", percent = .23 },
    ["/finished"] = { percent = .8, status = "complete" },
    ["/zero"] = { percent = 0 },
    ["/abandoned"] = { percent = .2, status = "abandoned" },
    ["/done"] = { percent = 1 },
    ["/second"] = { title = "Second", percent = .3 },
    ["/third"] = { title = "Third", percent = .05 },
    ["/fourth"] = { percent = .1 },
}
local recent = { "/current", "/finished", "/zero", "/abandoned", "/first", "/first", "/done", "/second", "/third", "/fourth" }
H.test("ongoing books are unique and genuinely in progress, excluding the hero", function()
    local result = Model.ongoing("/current", recent, function(fp) return books[fp] end, 3)
    H.eq(#result, 3); H.eq(result[1].file, "/first"); H.eq(result[3].file, "/third")
    H.eq(Model.fraction(0/0), 0); H.eq(Model.fraction(-2), 0); H.eq(Model.fraction(5), 1)
    H.eq(Model.duration(3600 + 13 * 60), "1h 13m")
    H.eq(Model.greeting(7), "Good morning"); H.eq(Model.greeting(15), "Good afternoon")
end)

local saved, fresh, refresh = {}, 0, 0
local Store = {
    readSetting = function(_, k) return saved[k] end,
    saveSetting = function(_, k, v) saved[k] = v end,
}
package.loaded["infra/sui_store"] = Store
package.loaded["logger"] = { warn = function() end }
local dpi = 1
package.loaded["device"] = { screen = { scaleBySize = function(_, n) return math.floor(n * dpi) end } }
package.loaded["infra/sui_config"] = { getModuleGapPx = function() return 12 end }
package.loaded["infra/sui_goals"] = { get = function() return 100 end }
package.loaded["infra/sui_text"] = { formatAuthors = function(s) return s end }
local cached_goal = { progress = 201, goal = 300, metric = "book", description = "2026 goal" }
package.loaded["modules/module_hardcover"] = { _getCached = function() return cached_goal end,
    ensureFresh = function() fresh = fresh + 1 end }
local want_files = { "/first", "/second", "/third", "/fourth" }
package.loaded["integrations/sui_bookorbit_want"] = { getCachedFiles = function() return want_files end }
package.loaded["engines/sui_book_sources"] = { bind = function(id)
    H.eq(id, "new_books")
    return { getFileList = function() return { "/second", "/filtered", "/first" } end,
        filterItem = function(fp) return fp ~= "/filtered" end }
end }
local Widget = H.widget()
function Widget:getSize()
    return self.dimen or { w = self.width or 0, h = self.height or 0 }
end
function Widget:free()
    assert(not self.freed, "widget freed twice")
    self.freed = true
    for _, child in ipairs(self) do child:free() end
end
local covers, opened, held, settings, dirtied = {}, nil, nil, nil, 0
local missing_cover
local SH = {
    getBookData = function(fp, _, opts)
        H.eq(opts.skip_description, true)
        return books[fp] or { title = fp, authors = "", percent = 0 }
    end,
    getBookCover = function(fp, w, h)
        if fp == missing_cover then return nil end
        local image = Widget:new{ kind = "cover", fp = fp, dimen = { w = w, h = h } }
        covers[#covers + 1] = image
        return image
    end,
    coverPlaceholder = function(title, _, w, h)
        return Widget:new{ kind = "placeholder", text = title, dimen = { w = w, h = h } }
    end,
}
package.loaded["modules/module_books_shared"] = SH
local UI = { MOD_GAP = 12, getContentHeight = function() return 800 end,
    progressBar = function(w, pct, h)
        assert(w > 0 and h > 0 and pct >= 0 and pct <= 1)
        return Widget:new{ kind = "bar", pct = pct, dimen = { w = w, h = h } }
    end,
}
local function makeText(args)
    args.kind = "text"
    local _, glyphs = tostring(args.text):gsub("[^\128-\191]", "")
    local text_w = math.min(args.width, math.ceil(glyphs * args.face.size * .55))
    args.dimen = { w = args.max_lines and args.width or text_w,
        h = args.height or math.ceil(args.face.size * 1.2) }
    return Widget:new(args)
end
UI.makeTextBox, UI.makeColoredText = makeText, makeText
package.loaded["infra/sui_core"] = UI
local Dashboard = require("adapters/orbitui_dashboard")
local ctx = { current_fp = "/current", recent_fps = recent, stats = { books_year = 79, today_pages = 65 },
    pfx = "simpleui_hs_", prefetched = {}, _screen_widget = { _layout_content_h = 800 },
    open_fn = function(fp) opened = fp end, hold_fn = function(fp) held = fp end,
    open_settings_fn = function(id) settings = id end }

H.test("uses existing filtered sources and cached Hardcover goal without replacing settings", function()
    saved.simpleui_hs_hardcover = true
    local data = Dashboard.readData(ctx)
    H.eq(data.goal.value, 201); H.eq(data.goal.target, 300); H.eq(fresh, 1)
    H.eq(data.goal.module, "hardcover"); H.eq(data.want[1], "/first")
    H.eq(#data.new, 2); H.eq(data.new[2], "/first"); H.eq(#data.ongoing, 3)
    H.eq(#ctx.recent_fps, #recent); H.eq(ctx.stats.books_year, 79)
    saved.simpleui_hs_hardcover = false
    data = Dashboard.readData(ctx)
    H.eq(data.goal.value, 79); H.eq(data.goal.target, 100); H.eq(data.goal.source, "KOReader")
    H.eq(fresh, 1)
end)

H.test("missing remote cache is not substituted with misleading local goal numbers", function()
    saved.simpleui_hs_hardcover, cached_goal = true, nil
    H.eq(Dashboard.readData(ctx).goal, nil)
    saved.simpleui_hs_hardcover = false
    local data = Dashboard.readData({ recent_fps = { "/first" }, stats = {} })
    H.eq(data.current.file, "/first"); H.eq(#data.ongoing, 0)
end)

H.test("unavailable lists fail independently without hiding local reading data", function()
    local Want = package.loaded["integrations/sui_bookorbit_want"]
    local Sources = package.loaded["engines/sui_book_sources"]
    local get, bind = Want.getCachedFiles, Sources.bind
    Want.getCachedFiles = function() error("offline cache unavailable") end
    Sources.bind = function() error("database temporarily unavailable") end
    local result = Dashboard.readData(ctx)
    H.eq(result.current.file, "/current"); H.eq(#result.ongoing, 3)
    H.eq(#result.want, 0); H.eq(result.want_error, true)
    H.eq(#result.new, 0); H.eq(result.new_error, true)
    Want.getCachedFiles, Sources.bind = get, bind
end)

H.test("body height reserves the actual dock-adjusted content area, footer and top margins", function()
    H.eq(Dashboard.getHeight(ctx), 740)
    saved.simpleui_topbar_enabled = false
    H.eq(Dashboard.getHeight(ctx), 728)
    ctx._screen_widget._footer_chevron = { widget = Widget:new{ height = 70 } }
    H.eq(Dashboard.getHeight(ctx), 698)
    saved.simpleui_topbar_enabled = true
    ctx._screen_widget._footer_chevron = nil
end)

H.test("BookOrbit refresh respects opt-in and the existing automatic-refresh switch", function()
    local provider = { shouldAutoRefreshHome = function(_, key) return key == "existing" end }
    Dashboard.wrapWantProvider(provider)
    Dashboard.wrapWantProvider(provider)
    H.eq(provider.shouldAutoRefreshHome("simpleui_hs_"), false)
    saved.simpleui_hs_orbitui_dashboard_enabled = true
    H.eq(provider.shouldAutoRefreshHome("simpleui_hs_"), true)
    saved.simpleui_bookorbit_want_auto_refresh = false
    H.eq(provider.shouldAutoRefreshHome("simpleui_hs_"), false)
    H.eq(provider.shouldAutoRefreshHome("simpleui_hs_", "existing"), true)
    H.eq(provider.shouldAutoRefreshHome("simpleui_cs_private_"), false)
end)

H.test("dashboard owns its cards without presenting ineffective native frame settings", function()
    local chrome = { skipsModuleChrome = function(id) return id == "reading_stats" end }
    Dashboard.wrapChrome(chrome); Dashboard.wrapChrome(chrome)
    H.eq(chrome.skipsModuleChrome(Model.id), true)
    H.eq(chrome.skipsModuleChrome("reading_stats"), true)
    H.eq(chrome.skipsModuleChrome("currently"), false)
end)

H.test("Home switch is additive and disabling it leaves user changes untouched", function()
    saved.simpleui_layout = { pages = { { id = 1, modules = { "recent", "hardcover" } } } }
    package.loaded["screens/sui_settings_window"] = { LayoutService = {
        load = function() return saved.simpleui_layout end,
        save = function(value) saved.simpleui_layout = value end,
    } }
    package.loaded["screens/sui_homescreen"] = { getInstance = function() return ctx._screen_widget end,
        rebuildLayout = function() refresh = refresh + 1 end }
    Dashboard.setHomeEnabled(true)
    H.eq(#saved.simpleui_layout.pages, 2); H.eq(ctx._screen_widget._current_page, 1)
    saved.simpleui_layout.pages[2].modules[3] = "quote"
    Dashboard.setHomeEnabled(false)
    H.eq(#saved.simpleui_layout.pages, 1); H.eq(saved.simpleui_layout.pages[1].modules[3], "quote")
    H.eq(saved.simpleui_hs_orbitui_dashboard_enabled, false); H.eq(refresh, 2)
end)

for _, id in ipairs({ "ui/geometry", "ui/widget/container/framecontainer", "ui/widget/container/inputcontainer",
    "ui/widget/overlapgroup", "ui/gesturerange" }) do package.loaded[id] = Widget end
package.loaded["ffi/blitbuffer"] = { COLOR_BLACK = "black", COLOR_WHITE = "white", COLOR_DARK_GRAY = "#555",
    COLOR_GRAY = "#aaa", COLOR_LIGHT_GRAY = "#ddd" }
package.loaded["features/sui_style"] = { getStyledFace = function(_, size, variant)
    return { size = math.floor(size * dpi) }, variant == "bold"
end }
local shown_dialog
package.loaded["ui/uimanager"] = {
    setDirty = function() dirtied = dirtied + 1 end,
    show = function(_, dialog) shown_dialog = dialog end,
    close = function(_, dialog) dialog.closed = true end,
}
package.loaded["ui/widget/inputdialog"] = Widget:extend{
    getInputText = function(self) return self.input end,
    onShowKeyboard = function(self) self.keyboard_shown = true end,
}
local View = require("adapters/orbitui_dashboard_view")
local data = Dashboard.readData(ctx)
local widget

H.test("a cold missing cover gets a clickable placeholder and is replaced when ready", function()
    missing_cover = "/current"
    local cold = View.build(600, 730, ctx, data)
    local slot = cold._cover_slots[1]
    local placeholder = cold[1][slot.index]
    H.eq(placeholder.kind, "placeholder")
    missing_cover = nil
    H.eq(Dashboard.updateCovers(cold), true)
    H.eq(placeholder.freed, true); H.eq(cold[1][slot.index].fp, "/current")
    cold:free()
end)

H.test("native dashboard tree stays bounded and uses real cover widgets", function()
    for _, density in ipairs({ 1, 1.5, 2 }) do
    dpi = density
    for _, size in ipairs({ { 600, 730 }, { 1100, 1350 }, { 300, 400 }, { 450, 610 }, { 800, 480 } }) do
        local current = View.build(size[1], size[2], ctx, data)
        local plan = Model.plan(size[1], size[2])
        local cards = { plan.hero, plan.ongoing, plan.goal, plan.want, plan.new }
        for _, card in ipairs(plan.stats) do cards[#cards + 1] = card end
        for _, child in ipairs(current[1]) do
            local xy, sz = child.overlap_offset, child:getSize()
            assert(xy[1] >= 0 and xy[2] >= 0, child.kind or "card")
            assert(xy[1] + sz.w <= size[1], "width overflow: " .. (child.text or child.kind or "card"))
            assert(xy[2] + sz.h <= size[2], "height overflow: " .. (child.text or child.kind or "card"))
            if child.kind and xy[2] >= plan.header_h then
                local inside = false
                for _, card in ipairs(cards) do
                    if xy[1] >= card.x and xy[2] >= card.y and xy[1] + sz.w <= card.x + card.w
                            and xy[2] + sz.h <= card.y + card.h then inside = true end
                end
                assert(inside, "card overflow: " .. (child.text or child.kind))
            end
            if child.kind == "cover" then assert(math.abs(sz.h - sz.w * 1.5) <= 1) end
        end
        if size[1] == 600 and dpi == 1 then widget = current else current:free() end
    end
    end
    dpi = 1
end)

H.test("taps and long-presses use native book handlers and goal settings", function()
    widget.dimen.x, widget.dimen.y = 17, 30
    local function tapAt(x, y, hold)
        local ges = { pos = { x = x + 17, y = y + 30 } }
        if hold then widget:onDashboardHold(nil, ges); widget:onDashboardHoldRelease()
        else widget:onDashboardTap(nil, ges) end
    end
    local current_cover
    for _, child in ipairs(widget[1]) do if child.fp == "/current" then current_cover = child end end
    local xy = current_cover.overlap_offset
    tapAt(xy[1] + 2, xy[2] + 2); H.eq(opened, "/current")
    tapAt(xy[1] + 2, xy[2] + 2, true); H.eq(held, "/current")
    local r = Model.plan(600, 730).goal
    tapAt(r.x + 2, r.y + 2); H.eq(settings, "reading_goals")
end)

H.test("cover and progress refresh free only the replaced tree and do not change layout", function()
    local old, height = widget[1], widget.dimen.h
    books["/current"].percent = .75
    H.eq(Dashboard.updateStats(widget, ctx), true)
    H.eq(old.freed, true); H.eq(widget._dashboard_data.current.data.percent, .75)
    H.eq(widget.dimen.h, height)
    local second = widget[1]
    local old_image = second[widget._cover_slots[1].index]
    H.eq(Dashboard.updateCovers(widget), true); H.eq(second.freed, nil)
    H.eq(old_image.freed, true); H.eq(widget[1], second)
    widget:free()
end)

local function shelfItem(current, key, value)
    local area = Model.plan(current.dimen.w, current.dimen.h)[key]
    for _, child in ipairs(current[1]) do
        local xy = child.overlap_offset
        if (child.text == value or child.fp == value)
                and xy[1] >= area.x and xy[1] < area.x + area.w
                and xy[2] >= area.y and xy[2] < area.y + area.h then return child end
    end
end

local function tapArrow(current, key, direction)
    local arrow = assert(shelfItem(current, key, direction))
    local xy, sz = arrow.overlap_offset, arrow:getSize()
    return current:onDashboardTap(nil, { pos = {
        x = current.dimen.x + xy[1] + math.floor(sz.w / 2),
        y = current.dimen.y + xy[2] + math.floor(sz.h / 2),
    } })
end

local function pagedWidget()
    local page_ctx = {}
    for k, v in pairs(ctx) do page_ctx[k] = v end
    page_ctx._screen_widget = { _current_page = 4 }
    local page_data = Dashboard.readData(page_ctx)
    page_data.want = { "/want1", "/want2", "/want3", "/want4", "/want5", "/want6", "/want7" }
    page_data.new = { "/new1", "/new2", "/new3", "/new4" }
    local current = View.build(600, 730, page_ctx, page_data)
    current.dimen.x, current.dimen.y = 17, 30
    return current, page_ctx, page_data
end

local function swipeAt(current, key, direction)
    local area = Model.plan(current.dimen.w, current.dimen.h)[key]
    local pos = { x = current.dimen.x + area.x + math.floor(area.w / 2),
        y = current.dimen.y + area.y + math.floor(area.h / 2) }
    function pos:intersectWith(r)
        return self.x >= r.x and self.x < r.x + r.w and self.y >= r.y and self.y < r.y + r.h
    end
    return { ges = "swipe", direction = direction, pos = pos }
end

H.test("larger page controls use the card bottom without overlapping covers or the Home footer", function()
    for _, density in ipairs({ 1, 1.5, 2 }) do
    dpi = density
    for _, size in ipairs({ { 600, 730 }, { 1100, 1350 }, { 300, 400 }, { 450, 610 }, { 800, 480 } }) do
        local initial, page_ctx, page_data = pagedWidget()
        initial:free()
        local current = View.build(size[1], size[2], page_ctx, page_data)
        local plan = Model.plan(size[1], size[2])
        for _, key in ipairs({ "want", "new" }) do
            local area = plan[key]
            local arrow = assert(shelfItem(current, key, ">"))
            local xy, sz = arrow.overlap_offset, arrow:getSize()
            H.eq(arrow.face.size, math.floor(math.max(7, 28 * plan.scale) / dpi * dpi))
            local target
            for _, a in ipairs(current._actions) do
                if xy[1] >= a.x and xy[1] + sz.w <= a.x + a.w
                        and xy[2] >= a.y and xy[2] + sz.h <= a.y + a.h then target = a end
            end
            assert(target)
            H.eq(target.w, math.max(1, math.floor(52 * plan.scale)))
            H.eq(target.h, math.max(1, math.floor(48 * plan.scale)))
            H.eq(target.y + target.h, area.y + area.h - math.max(1, math.floor(4 * plan.scale)))
            assert(target.x >= area.x and target.x + target.w <= area.x + area.w)
            local counter = assert(shelfItem(current, key, key == "want" and "1/3" or "1/2"))
            H.eq(counter.fgcolor, "black")
            H.eq(counter.face.size, math.floor(math.max(7, 16 * plan.scale) / dpi * dpi))
            local cover_widget = assert(shelfItem(current, key, key == "want" and "/want1" or "/new1"))
            assert(cover_widget.overlap_offset[2] + cover_widget:getSize().h <= target.y)
            if size[1] == 600 then
                -- The portrait covers remain width-limited, not shrunk for the larger pager.
                H.eq(cover_widget:getSize().w, math.floor((area.w - 2 * plan.pad - 2 * plan.gap) / 3))
            end
        end
        current:free()
    end
    end
    dpi = 1
end)

H.test("the larger arrow hit target works below the glyph without opening a book", function()
    local current, page_ctx = pagedWidget()
    local area = Model.plan(600, 730).want
    opened = nil
    H.eq(current:onDashboardTap(nil, { pos = { x = current.dimen.x + area.w / 2 + 60,
        y = current.dimen.y + area.y + area.h - 6 } }), true)
    H.eq(page_ctx._screen_widget._orbitui_dashboard_pages.want, 2)
    H.eq(opened, nil)
    current:free()
end)

H.test("horizontal swipes page each card independently and share arrow state", function()
    local current, page_ctx = pagedWidget()
    local pages = page_ctx._screen_widget._orbitui_dashboard_pages
    local before = dirtied
    H.eq(current:onSwipe(nil, swipeAt(current, "want", "west")), true)
    H.eq(pages.want, 2); H.eq(pages.new, 1); H.eq(dirtied, before + 1)
    assert(shelfItem(current, "want", "/want4"))
    tapArrow(current, "want", ">")
    H.eq(pages.want, 3)
    H.eq(current:onSwipe(nil, swipeAt(current, "want", "east")), true)
    H.eq(pages.want, 2)
    H.eq(current:onSwipe(nil, swipeAt(current, "new", "west")), true)
    H.eq(pages.new, 2); H.eq(pages.want, 2)
    assert(shelfItem(current, "new", "/new4"))
    H.eq(current:onSwipe(nil, swipeAt(current, "new", "east")), true)
    H.eq(pages.new, 1); H.eq(page_ctx._screen_widget._current_page, 4)
    current:free()
end)

H.test("card swipes at either boundary or on empty and single-page lists are consumed without repaint", function()
    local current, page_ctx, page_data = pagedWidget()
    local before = dirtied
    H.eq(current:onSwipe(nil, swipeAt(current, "want", "east")), true)
    H.eq(dirtied, before)
    tapArrow(current, "want", ">"); tapArrow(current, "want", ">")
    before = dirtied
    H.eq(current:onSwipe(nil, swipeAt(current, "want", "west")), true)
    H.eq(dirtied, before)
    page_data.want, page_data.new = { "/only" }, {}
    current:replaceContent(page_ctx, page_data)
    for _, key in ipairs({ "want", "new" }) do
        for _, dir in ipairs({ "west", "east" }) do
            H.eq(current:onSwipe(nil, swipeAt(current, key, dir)), true)
            H.eq(page_ctx._screen_widget._orbitui_dashboard_pages[key], 1)
        end
    end
    H.eq(dirtied, before)
    current:free()
end)

H.test("vertical swipes, other cards and invalid gestures remain available to the Home screen", function()
    local current = pagedWidget()
    local before = dirtied
    for _, dir in ipairs({ "north", "south", "northeast" }) do
        H.eq(current:onSwipe(nil, swipeAt(current, "want", dir)), nil)
    end
    H.eq(current:onSwipe(nil, swipeAt(current, "ongoing", "west")), nil)
    H.eq(current:onSwipe(nil, swipeAt(current, "goal", "east")), nil)
    H.eq(current:onSwipe(nil, nil), nil)
    H.eq(current:onSwipe(nil, { direction = "west" }), nil)
    H.eq(current:onSwipe(nil, { pos = { x = -1, y = -1 }, direction = "west" }), nil)
    H.eq(dirtied, before)
    current:free()
end)

H.test("swipes discard a pending book hold and use fresh lists after data and cover updates", function()
    local current, page_ctx, page_data = pagedWidget()
    local book = shelfItem(current, "want", "/want1")
    held = nil
    current:onDashboardHold(nil, { pos = { x = current.dimen.x + book.overlap_offset[1] + 2,
        y = current.dimen.y + book.overlap_offset[2] + 2 } })
    assert(current._held)
    current:onSwipe(nil, swipeAt(current, "want", "west"))
    H.eq(current:onDashboardHoldRelease(), nil); H.eq(held, nil)
    page_data.want = { "/replacement1", "/replacement2", "/replacement3", "/replacement4" }
    current:replaceContent(page_ctx, page_data)
    Dashboard.updateCovers(current)
    current:onSwipe(nil, swipeAt(current, "want", "east"))
    assert(shelfItem(current, "want", "/replacement1"))
    current:onSwipe(nil, swipeAt(current, "want", "west"))
    assert(shelfItem(current, "want", "/replacement4"))
    H.eq(#current._swipe_areas, 2)
    current:free()
end)

H.test("native SimpleUI swipe routing reaches the dashboard while retaining Home and edge gestures", function()
    local file = assert(io.open("components/simpleui/engines/sui_screen_engine.lua"))
    local source = file:read("*a"); file:close()
    local code = ""
    for _, name in ipairs({ "_inXRange", "_findSwipeWidget", "_pageHasMod" }) do
        code = code .. assert(source:match("(local function " .. name .. "%b().-\nend)")) .. "\n"
    end
    for _, name in ipairs({ "_isSideEdge", "_isModOnVisiblePage", "_bookModHitDimen", "_swipeBookMod", "onScreenSwipe" }) do
        code = code .. assert(source:match("(function ScreenWidget:" .. name .. "%b().-\nend)")) .. "\n"
    end
    local current, page_ctx = pagedWidget()
    local screen = page_ctx._screen_widget
    local env = setmetatable({ ScreenWidget = screen, Screen = { getWidth = function() return 640 end },
        _isLandscape = function() return false end }, { __index = _G })
    if setfenv then setfenv(assert(loadstring(code)), env)()
    else assert(load(code, "native dashboard swipe routing", "t", env))() end
    local home_turns, forwarded = 0, 0
    screen._gesture_zones = { left_edge = { ratio_x = 0, ratio_w = .05 },
        right_edge = { ratio_x = .95, ratio_w = .05 } }
    screen._enabled_mods_cache = { pages_of_mods = { [4] = { { id = Model.id } }, [5] = {} } }
    screen._book_mod_slots = { [Model.id] = { widget = Widget:new{ dimen = current.dimen, current } } }
    function screen:_swipePage() home_turns = home_turns + 1 end
    function screen:_fmGestureAction() forwarded = forwarded + 1; return true end
    -- Only the screen registers a swipe range, so its edge priority cannot be bypassed.
    for _, ranges in pairs(current.ges_events) do
        for _, range in ipairs(ranges) do assert(range.ges ~= "swipe") end
    end
    H.eq(screen:onScreenSwipe(nil, swipeAt(current, "want", "west")), true)
    H.eq(screen._orbitui_dashboard_pages.want, 2); H.eq(home_turns, 0)
    screen:onScreenSwipe(nil, swipeAt(current, "new", "west"))
    screen:onScreenSwipe(nil, swipeAt(current, "new", "west"))
    H.eq(screen._orbitui_dashboard_pages.new, 2); H.eq(home_turns, 0)
    screen:onScreenSwipe(nil, swipeAt(current, "ongoing", "west"))
    H.eq(home_turns, 1)
    local edge = swipeAt(current, "want", "east"); edge.pos.x = 20
    screen:onScreenSwipe(nil, edge)
    H.eq(forwarded, 1); H.eq(screen._orbitui_dashboard_pages.want, 2)
    screen:onScreenSwipe(nil, swipeAt(current, "new", "north"))
    H.eq(forwarded, 2)
    screen._current_page = 5
    screen:onScreenSwipe(nil, swipeAt(current, "want", "west"))
    H.eq(home_turns, 2); H.eq(screen._orbitui_dashboard_pages.want, 2)
    current:free()
end)

H.test("both book rows page forwards and backwards independently of the Home page", function()
    local current, page_ctx = pagedWidget()
    local pages = page_ctx._screen_widget._orbitui_dashboard_pages
    assert(shelfItem(current, "want", "1/3")); assert(shelfItem(current, "new", "1/2"))
    local counter = shelfItem(current, "want", "1/3")
    local area = Model.plan(current.dimen.w, current.dimen.h).want
    assert(math.abs(counter.overlap_offset[1] + counter:getSize().w / 2 - area.x - area.w / 2) <= 1)
    local before = dirtied
    H.eq(tapArrow(current, "want", ">"), true)
    H.eq(pages.want, 2); H.eq(pages.new, 1); H.eq(dirtied, before + 1)
    assert(shelfItem(current, "want", "/want4")); assert(not shelfItem(current, "want", "/want1"))
    tapArrow(current, "new", ">")
    H.eq(pages.want, 2); H.eq(pages.new, 2)
    assert(shelfItem(current, "new", "/new4")); assert(shelfItem(current, "new", "2/2"))
    tapArrow(current, "want", "<")
    H.eq(pages.want, 1); H.eq(pages.new, 2)
    tapArrow(current, "new", "<")
    H.eq(pages.new, 1); H.eq(page_ctx._screen_widget._current_page, 4)
    current:free()
end)

H.test("first and last page arrows are dimmed and do not wrap or repaint", function()
    local current, page_ctx = pagedWidget()
    local before = dirtied
    H.eq(shelfItem(current, "want", "<").fgcolor, "#ddd")
    H.eq(tapArrow(current, "want", "<"), true)
    H.eq(dirtied, before); H.eq(page_ctx._screen_widget._orbitui_dashboard_pages.want, 1)
    tapArrow(current, "want", ">"); tapArrow(current, "want", ">")
    assert(shelfItem(current, "want", "3/3")); assert(shelfItem(current, "want", "/want7"))
    assert(not shelfItem(current, "want", "/want6"))
    H.eq(shelfItem(current, "want", ">").fgcolor, "#ddd")
    before = dirtied
    tapArrow(current, "want", ">")
    H.eq(dirtied, before); H.eq(page_ctx._screen_widget._orbitui_dashboard_pages.want, 3)
    tapArrow(current, "want", "<")
    H.eq(shelfItem(current, "want", ">").fgcolor, "black")
    current:free()
end)

H.test("page refresh preserves selection, clamps shorter lists and hides single-page controls", function()
    local current, page_ctx, page_data = pagedWidget()
    local pages = page_ctx._screen_widget._orbitui_dashboard_pages
    tapArrow(current, "want", ">"); tapArrow(current, "want", ">")
    tapArrow(current, "new", ">")
    current:replaceContent(page_ctx, page_data)
    H.eq(pages.want, 3); H.eq(pages.new, 2)
    local files = page_data.want
    page_data.want = { "/want1", "/want2", "/want3", "/want4" }
    current:replaceContent(page_ctx, page_data)
    H.eq(pages.want, 2); assert(shelfItem(current, "want", "2/2"))
    page_data.want, page_data.new = { "/want1" }, {}
    current:replaceContent(page_ctx, page_data)
    H.eq(pages.want, 1); H.eq(pages.new, 1)
    assert(not shelfItem(current, "want", "<")); assert(not shelfItem(current, "new", ">"))
    page_data.want = files
    current:replaceContent(page_ctx, page_data)
    H.eq(pages.want, 1); assert(shelfItem(current, "want", "/want1"))
    current:free()
end)

H.test("book actions after paging use the displayed book and stay outside the arrow row", function()
    local current = pagedWidget()
    tapArrow(current, "new", ">")
    local book = assert(shelfItem(current, "new", "/new4"))
    local xy, sz = book.overlap_offset, book:getSize()
    local nav_y = shelfItem(current, "new", ">").overlap_offset[2]
    assert(xy[2] + sz.h < nav_y)
    local ges = { pos = { x = current.dimen.x + xy[1] + 2, y = current.dimen.y + xy[2] + 2 } }
    current:onDashboardTap(nil, ges); H.eq(opened, "/new4")
    current:onDashboardHold(nil, ges); current:onDashboardHoldRelease(); H.eq(held, "/new4")
    H.eq(Dashboard.updateCovers(current), true)
    assert(shelfItem(current, "new", "2/2")); assert(shelfItem(current, "new", "/new4"))
    current:free()
end)

local function headingSetting(key, pfx)
    return (pfx or "simpleui_hs_") .. "orbitui_dashboard_heading_" .. key
end

local function pressDialog(button)
    for _, row in ipairs(shown_dialog.buttons) do
        for _, item in ipairs(row) do
            if item.text == button then item.callback(); return end
        end
    end
    error("Missing dialog button: " .. button)
end

local function headingWidget(current, key)
    local plan = Model.plan(current.dimen.w, current.dimen.h)
    local areas = { pages_today = plan.stats[1], reading_today = plan.stats[2],
        streak = plan.stats[3], week = plan.stats[4] }
    local area = areas[key] or plan[key]
    for _, child in ipairs(current[1]) do
        local xy = child.overlap_offset
        if child.kind == "text" and xy[1] == area.x + plan.pad
                and xy[2] == area.y + plan.pad then return child, area end
    end
    error("Missing heading: " .. key)
end

H.test("both settings entry points expose all nine independent heading editors", function()
    local updates = 0
    local menu = Dashboard.menuItems(function() updates = updates + 1 end)
    H.eq(menu[3].text, "Headings")
    local items = menu[3].sub_item_table_func()
    H.eq(#items, 9)
    H.eq(Dashboard.getMenuItems(ctx)[2].text, "Headings")
    local keys = {}
    for i, card in ipairs(Model.heading_cards) do
        assert(not keys[card.key]); keys[card.key] = true
        H.eq(items[i].text_func(), card.label .. ": Automatic")
        items[i].callback()
        H.eq(shown_dialog.input, ""); H.eq(shown_dialog.keyboard_shown, true)
        H.eq(shown_dialog.title, "Edit heading: " .. card.label)
        shown_dialog.input = "  Custom " .. card.key .. "\n "
        pressDialog("Save")
        H.eq(shown_dialog.closed, true)
        H.eq(updates, i)
        H.eq(Dashboard.readData(ctx).headings[card.key], "Custom " .. card.key)
        H.eq(items[i].text_func(), card.label .. ": Custom " .. card.key)
    end
    local reloaded = dofile("adapters/orbitui_dashboard.lua")
    for i, card in ipairs(Model.heading_cards) do
        H.eq(reloaded.readHeadings()[card.key], "Custom " .. card.key)
        items[i].callback()
        H.eq(shown_dialog.input, "Custom " .. card.key)
        pressDialog("Restore default")
        H.eq(saved[headingSetting(card.key)], nil)
    end
    H.eq(updates, 18)
end)

H.test("cancel writes nothing and blank input restores the automatic heading", function()
    local updates = 0
    saved[headingSetting("want")] = "My list"
    local item = Dashboard.headingItems(function() updates = updates + 1 end)[8]
    item.callback(); shown_dialog.input = "Not saved"; pressDialog("Cancel")
    H.eq(saved[headingSetting("want")], "My list"); H.eq(updates, 0)
    H.eq(shown_dialog.closed, true)
    item.callback(); shown_dialog.input = " \t\n "; pressDialog("Save")
    H.eq(saved[headingSetting("want")], nil); H.eq(updates, 1)
end)

H.test("heading changes are screen-scoped and never rewrite ordinary module or goal settings", function()
    local other = "simpleui_cs_private_"
    saved.simpleui_hide_label_new_books = true
    saved.simpleui_hs_label_scale = 115
    saved[headingSetting("new")] = "Home additions"
    saved[headingSetting("want")] = "Home list"
    local before_refresh = refresh
    Dashboard.headingItems(nil, other)[9].callback()
    shown_dialog.input = "Private additions"; pressDialog("Save")
    H.eq(refresh, before_refresh + 1)
    H.eq(Dashboard.readHeadings(other).new, "Private additions")
    H.eq(Dashboard.readHeadings().new, "Home additions")
    H.eq(Dashboard.readHeadings(other).want, nil)
    H.eq(saved.simpleui_hide_label_new_books, true)
    H.eq(saved.simpleui_hs_label_scale, 115)
    H.eq(saved.simpleui_hs_hardcover, false)
    Dashboard.getMenuItems({ pfx = other })[2].sub_item_table_func()[9].callback()
    pressDialog("Restore default")
    H.eq(saved[headingSetting("new", other)], nil)
    H.eq(saved[headingSetting("new")], "Home additions")
    saved[headingSetting("new")], saved[headingSetting("want")] = nil, nil
end)

H.test("all nine cards render custom headings with unchanged geometry in light and dark modes", function()
    for _, card in ipairs(Model.heading_cards) do
        saved[headingSetting(card.key)] = card.key .. " " .. string.rep("Lång rubrik 日本語 ", 20)
    end
    for _, density in ipairs({ 1, 1.5, 2 }) do
    dpi = density
    for _, size in ipairs({ { 300, 400 }, { 600, 730 }, { 800, 480 } }) do
    for _, dark in ipairs({ true, false }) do
        local custom_data = Dashboard.readData(ctx)
        custom_data.dark = dark
        local current = View.build(size[1], size[2], ctx, custom_data)
        local plan = Model.plan(size[1], size[2])
        for _, card in ipairs(Model.heading_cards) do
            local label, area = headingWidget(current, card.key)
            H.eq(label.text, Model.normalizeHeading(saved[headingSetting(card.key)]))
            H.eq(label.max_width, math.floor(area.w - 2 * plan.pad))
            H.eq(label.max_lines, nil)
            assert(label.overlap_offset[1] + label:getSize().w <= area.x + area.w - plan.pad)
            assert(label.overlap_offset[2] + label:getSize().h <= area.y + area.h)
            H.eq(label.fgcolor, card.key == "hero" and dark and "white" or "black")
        end
        current:free()
    end
    end
    end
    dpi = 1
    for _, card in ipairs(Model.heading_cards) do saved[headingSetting(card.key)] = nil end
end)

H.test("stats and cover-row refreshes retain titles and native paging and book actions", function()
    local current, page_ctx = pagedWidget()
    Dashboard.headingItems(function() Dashboard.updateStats(current, page_ctx) end)[8].callback()
    shown_dialog.input = "Want list"; pressDialog("Save")
    H.eq(headingWidget(current, "want").text, "Want list")
    tapArrow(current, "want", ">")
    H.eq(headingWidget(current, "want").text, "Want list")
    H.eq(Dashboard.updateCovers(current), true)
    H.eq(headingWidget(current, "want").text, "Want list")
    H.eq(page_ctx._screen_widget._orbitui_dashboard_pages.want, 2)
    current:free()
    saved[headingSetting("want")] = nil
end)

H.test("reset keeps the dynamic last-opened and remote or annual goal headings", function()
    local source = Dashboard.readData(ctx)
    source.current = { file = "/current", data = { title = "Done", status = "complete" } }
    source.goal = { title = "A remote challenge", value = 10, target = 30 }
    source.headings = { hero = "My book", goal = "My goal" }
    local current = View.build(600, 730, ctx, source)
    H.eq(headingWidget(current, "hero").text, "My book")
    H.eq(headingWidget(current, "goal").text, "My goal")
    source.headings = { hero = false, goal = "  " }
    current:replaceContent(ctx, source)
    H.eq(headingWidget(current, "hero").text, "Last opened")
    H.eq(headingWidget(current, "goal").text, "A remote challenge")
    source.goal = nil
    source.current = nil
    current:replaceContent(ctx, source)
    H.eq(headingWidget(current, "hero").text, "Continue reading")
    H.eq(headingWidget(current, "goal").text, "Reading goal " .. os.date("%Y"))
    current:free()
end)

H.test("Swedish dashboard strings translate while other locales retain English", function()
    local translate = require("core/orbitui_i18n")
    G_reader_settings = { readSetting = function() return "sv_SE" end }
    H.eq(translate("Reading dashboard"), "Läsöversikt")
    H.eq(translate("Continue reading"), "Fortsätt läsa")
    H.eq(translate("October"), "oktober")
    H.eq(Dashboard.menuItems()[3].text, "Rubriker")
    H.eq(Dashboard.headingItems()[9].text_func(), "Nya böcker: Automatisk")
    Dashboard.headingItems()[9].callback()
    H.eq(shown_dialog.title, "Ändra rubrik: Nya böcker")
    shown_dialog.input = "Min läslista"; pressDialog("Spara")
    H.eq(Dashboard.readHeadings().new, "Min läslista")
    G_reader_settings.readSetting = function() return "de_DE" end
    H.eq(translate("Continue reading"), "Continue reading")
    H.eq(Dashboard.menuItems()[3].text, "Headings")
    H.eq(Dashboard.headingItems()[9].text_func(), "Recently added: Min läslista")
    local current = Dashboard.build(600, ctx)
    H.eq(headingWidget(current, "new").text, "Min läslista")
    current:free()
    G_reader_settings.readSetting = function() return "sv" end
    Dashboard.headingItems()[9].callback(); pressDialog("Återställ standard")
    current = Dashboard.build(600, ctx)
    H.eq(headingWidget(current, "new").text, "Nya böcker")
    current:free()
    G_reader_settings.readSetting = function() return "en" end
end)
local preview_path = os.getenv("ORBITUI_DASHBOARD_PREVIEW")
if preview_path then
    G_reader_settings.readSetting = function() return "sv_SE" end
    books["/current"].title, books["/current"].authors, books["/current"].percent = "Skannad i dunklet", "Philip K. Dick", .59
    books["/first"].title, books["/second"].title, books["/third"].title = "The Strange House, Vol. 4", "En annan pågående bok", "En tredje bok"
    data = Dashboard.readData(ctx)
    data.goal = { title = "Läsmål för 2026", target = 300, value = 201, metric = "book", source = "Hardcover" }
    data.stats = { today_pages = 0, today_secs = 0, week_secs = 7 * 3600 + 13 * 60, streak = 12 }
    data.new = { "/third", "/first", "/second", "/fourth" }
    ctx._screen_widget._orbitui_dashboard_pages = {}
    local preview = View.build(720, 876, ctx, data)
    require("tests/dashboard_preview")(preview, preview_path)
    preview:free()
end
H.finish()
