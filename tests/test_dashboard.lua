package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_dashboard")

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
    args.dimen = { w = args.width, h = args.height or math.ceil(args.face.size * 1.2) }
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
package.loaded["ui/uimanager"] = { setDirty = function() dirtied = dirtied + 1 end }
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
end)

H.test("shelf pagination is independent, bounded and does not move Home's page", function()
    local p = Model.plan(600, 730)
    widget.dimen.x, widget.dimen.y = 0, 0
    widget:onDashboardTap(nil, { pos = { x = p.want.x + p.want.w - 15, y = p.want.y + 15 } })
    H.eq(ctx._screen_widget._orbitui_dashboard_pages.want, 2); H.eq(dirtied, 1)
    H.eq(ctx._screen_widget._orbitui_dashboard_pages.new, nil)
    H.eq(ctx._screen_widget._current_page, 1)
    local found = false
    for _, child in ipairs(widget[1]) do if child.fp == "/fourth" then found = true end end
    assert(found)
    widget:free()
end)

H.test("Swedish dashboard strings translate while other locales retain English", function()
    local translate = require("core/orbitui_i18n")
    G_reader_settings = { readSetting = function() return "sv_SE" end }
    H.eq(translate("Reading dashboard"), "Läsöversikt")
    H.eq(translate("Continue reading"), "Fortsätt läsa")
    H.eq(translate("October"), "oktober")
    G_reader_settings.readSetting = function() return "de_DE" end
    H.eq(translate("Continue reading"), "Continue reading")
end)
local preview_path = os.getenv("ORBITUI_DASHBOARD_PREVIEW")
if preview_path then
    G_reader_settings.readSetting = function() return "sv_SE" end
    books["/current"].title, books["/current"].authors, books["/current"].percent = "Skannad i dunklet", "Philip K. Dick", .59
    books["/first"].title, books["/second"].title, books["/third"].title = "The Strange House, Vol. 4", "En annan pågående bok", "En tredje bok"
    data = Dashboard.readData(ctx)
    data.goal = { title = "Läsmål för 2026", target = 300, value = 201, metric = "book", source = "Hardcover" }
    data.stats = { today_pages = 0, today_secs = 0, week_secs = 7 * 3600 + 13 * 60, streak = 12 }
    data.new = { "/third", "/first", "/second" }
    ctx._screen_widget._orbitui_dashboard_pages = {}
    local preview = View.build(720, 876, ctx, data)
    require("tests/dashboard_preview")(preview, preview_path)
    preview:free()
end
H.finish()
