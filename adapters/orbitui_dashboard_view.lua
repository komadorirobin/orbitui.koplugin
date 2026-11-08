-- Native widgets, not a screenshot: each book retains its own open/hold action.
local Model = require("core/orbitui_dashboard")
local _ = require("core/orbitui_i18n")
local Geom = require("ui/geometry")
local Frame = require("ui/widget/container/framecontainer")
local Input = require("ui/widget/container/inputcontainer")
local Overlap = require("ui/widget/overlapgroup")
local GestureRange = require("ui/gesturerange")
local BB = require("ffi/blitbuffer")
local UI = require("infra/sui_core")
local Style = require("features/sui_style")
local SH = require("modules/module_books_shared")
local Screen = require("device").screen

local M = {}
local Dashboard = Input:extend{}
local cover_colours = setmetatable({}, { __mode = "k" })
local cover_colour_count = 0

function M.colourSupported()
    return Screen.isColorScreen and Screen:isColorScreen()
        and Screen.isColorEnabled and Screen:isColorEnabled()
        and BB.ColorRGB32 ~= nil and BB.isColor8 ~= nil or false
end

-- Find the borrowed ImageWidget bitmap in the native cover/shadow containers.
-- Never hold an extra strong reference, mutate, scale, invert or free it.
function M.coverColour(image)
    local visited = 0
    local function find(node, depth)
        if type(node) ~= "table" or depth > 5 or visited >= 24 then return end
        visited = visited + 1
        local bb = node.image
        if (type(bb) == "table" or type(bb) == "cdata") and bb.getPixel and bb.getWidth and bb.getHeight then return bb end
        for i = 1, math.min(#node, 8) do
            local found = find(node[i], depth + 1)
            if found then return found end
        end
    end
    local ok, result = pcall(function()
        local bb = find(image, 0)
        if not bb then return nil end
        if cover_colours[bb] ~= nil then return cover_colours[bb] or nil end
        local colour = Model.coverColour(bb:getWidth(), bb:getHeight(), function(x, y)
            local c = bb:getPixel(x, y):getColorRGB32()
            return c.r, c.g, c.b, c.alpha
        end)
        if cover_colour_count >= 32 then cover_colours, cover_colour_count = setmetatable({}, { __mode = "k" }), 0 end
        cover_colours[bb], cover_colour_count = colour or false, cover_colour_count + 1
        return colour
    end)
    return ok and result or nil
end

-- These decorative frames have no content; text/covers are separate siblings.
-- Explicit RGB fills/borders also work with older FrameContainer implementations
-- whose plain paintRoundedRect/paintBorder lose chroma with a C blitter.
function M.paintColourCard(frame, bb, x, y)
    local Colour = require("lib/bookshelf_color")
    frame.dimen.x, frame.dimen.y = x, y
    Colour.paintRoundedRect(bb, x, y, frame.width, frame.height, frame.background, frame.radius + frame.bordersize)
    Colour.paintBorder(bb, x, y, frame.width, frame.height, frame.bordersize, frame.color, frame.radius,
        not G_reader_settings or G_reader_settings:nilOrTrue("anti_alias_ui"))
end
local MONTHS = { "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December" }

local function rect(x, y, w, h) return { x = x, y = y, w = w, h = h } end

local function hit(area, x, y)
    return x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h
end

function Dashboard:modulesVisible(generation)
    if self._disposed or self._modules_suspended or generation ~= self._module_generation then return false end
    if require("device").screen_saver_mode then return false end
    local owner = self._dashboard_ctx and self._dashboard_ctx._screen_widget
    if owner and (owner._suspended or owner._parked) then return false end
    local ui = require("ui/uimanager")
    return not (owner and ui.getTopmostVisibleWidget) or ui:getTopmostVisibleWidget() == owner
end

function Dashboard:onSuspend()
    self._modules_suspended = true
    if self._module_tick then require("ui/uimanager"):unschedule(self._module_tick) end
end

function Dashboard:onResume()
    self._modules_suspended = false
    if self._module_tick then
        local ui = require("ui/uimanager")
        ui:unschedule(self._module_tick)
        ui:scheduleIn(60, self._module_tick)
    end
end

local function makeCover(fp, r, ctx)
    local image = SH.getBookCover(fp, r.w, r.h, false)
    if not image then
        local book = SH.getBookData(fp, ctx.prefetched and ctx.prefetched[fp], { skip_description = true })
        image = SH.coverPlaceholder(book.title, book.authors, r.w, r.h, false)
    end
    return image
end

function Dashboard:onDashboardTap(_, ges)
    if not ges or not ges.pos then return end
    local x, y = ges.pos.x - self.dimen.x, ges.pos.y - self.dimen.y
    for i = #self._actions, 1, -1 do
        local action = self._actions[i]
        if hit(action, x, y) then action.tap(x - action.x, y - action.y); return true end
    end
end

function Dashboard:onDashboardHold(_, ges)
    self._held = nil
    if not ges or not ges.pos then return end
    local x, y = ges.pos.x - self.dimen.x, ges.pos.y - self.dimen.y
    for i = #self._actions, 1, -1 do
        local action = self._actions[i]
        if action.hold and hit(action, x, y) then self._held = action.hold; return true end
    end
    if require("infra/sui_store"):readSetting("simpleui_hs_settings_on_hold") == false then return end
    self._held = function() self:editModules() end
    return true
end

function Dashboard:onDashboardHoldRelease()
    if not self._held then return end
    local held = self._held
    self._held = nil
    held()
    return true
end

function Dashboard:editModules(id)
    if self._disposed then return end
    local generation = self._module_generation
    local ctx = self._dashboard_ctx
    require("adapters/orbitui_dashboard_settings").show(ctx.pfx, { refresh_fn = function()
        if not self._disposed and generation == self._module_generation and ctx.refresh_fn then ctx.refresh_fn() end
    end }, id)
end

function Dashboard:free(full)
    if self._disposed then return end
    self._disposed = true
    if self._module_tick then require("ui/uimanager"):unschedule(self._module_tick) end
    Input.free(self, full)
end

-- SimpleUI routes interior swipes here, keeping screen-edge gestures intact.
function Dashboard:onSwipe(_, ges)
    if not ges or not ges.pos or (ges.direction ~= "west" and ges.direction ~= "east") then return end
    local x, y = ges.pos.x - self.dimen.x, ges.pos.y - self.dimen.y
    for _, area in ipairs(self._swipe_areas) do
        if hit(area, x, y) then
            self._held = nil
            area.turn(ges.direction == "west" and 1 or -1)
            -- Consume at either end too: never turn a Home page by accident.
            return true
        end
    end
end

function Dashboard:replaceContent(ctx, data)
    local old = self[1]
    if self._module_tick then require("ui/uimanager"):unschedule(self._module_tick); self._module_tick = nil end
    self._dashboard_ctx, self._dashboard_data = ctx, data
    self._actions, self._cover_slots, self._held = {}, {}, nil
    self._hero_apply_colour = nil
    self._swipe_areas = {}
    self._module_generation = (self._module_generation or 0) + 1
    local owner = ctx._screen_widget
    local p = Model.plan(self.dimen.w, self.dimen.h, data.config,
        self._module_page or owner and owner._orbitui_dashboard_module_page)
    self._module_page, self._plan = p.page, p
    if owner then owner._orbitui_dashboard_module_page = p.page end
    self[1] = M.content(self, p, ctx, data)
    if old then old:free() end
end

function Dashboard:refreshCovers()
    local changed = false
    for _, slot in ipairs(self._cover_slots) do
        local image = SH.getBookCover(slot.file, slot.area.w, slot.area.h, false)
        if image then
            image.overlap_offset = { slot.area.x, slot.area.y }
            local parent = slot.parent or self[1]
            local old = parent[slot.index]
            parent[slot.index] = image
            old:free()
            if slot.hero and self._hero_apply_colour then self._hero_apply_colour(image) end
            changed = true
        end
    end
    return changed
end

function M.content(widget, p, ctx, data)
    local root = Overlap:new{ dimen = Geom:new{ w = p.w, h = p.h }, allow_mirroring = false }
    local target, card_scope = root, nil
    local ink, paper, muted = BB.COLOR_BLACK, BB.COLOR_WHITE, BB.COLOR_DARK_GRAY
    local coloured = Model.colourMode(data.colour) ~= "off" and M.colourSupported()
    widget.dithered = coloured or nil
    local Accent = coloured and require("infra/sui_accent")
    local function colours(key, cover_hex)
        return coloured and Model.cardColours(key, data.colour, Screen.night_mode, cover_hex) or nil
    end
    local function native(hex) return hex and Accent.toColor(hex) end
    local function px(n) return math.max(1, math.floor(n * p.scale)) end
    local function add(child, x, y)
        child.overlap_offset = { x, y }
        target[#target + 1] = child
        return child
    end
    local function box(r, fill, border, key)
        local palette = colours(key)
        local frame = Frame:new{
            dimen = Geom:new{ w = r.w, h = r.h }, width = r.w, height = r.h,
            margin = 0, padding = 0, radius = px(12), bordersize = px(1),
            background = fill or (palette and native(palette.fill)) or paper,
            color = border or (palette and native(palette.border)) or BB.COLOR_GRAY,
            Overlap:new{ dimen = Geom:new{ w = r.w - 2 * px(1), h = r.h - 2 * px(1) } },
        }
        if coloured then frame.paintTo = M.paintColourCard end
        return add(frame, r.x, r.y)
    end
    local function text(value, x, y, w, size, bold, color, lines)
        if w < 1 then return end
        -- Geometry is already in device pixels; Font:getFace scales by DPI.
        local dpi = Screen:scaleBySize(1000) / 1000
        local face, is_bold = Style.getStyledFace(nil, math.max(7, size * p.scale) / dpi,
            bold and "bold" or "regular")
        local args = { text = tostring(value or ""), face = face, bold = is_bold,
            fgcolor = color or ink, width = math.floor(w), max_width = math.floor(w) }
        if lines then
            args.max_lines, args.height_adjust = lines, false
            args.height = math.ceil(face.size * 1.3) * lines
            args.height_overflow_show_ellipsis = true
            return add(UI.makeTextBox(args, true), x, y)
        end
        return add(UI.makeColoredText(args), x, y)
    end
    local function action(r, tap, hold)
        local item = rect(r.x, r.y, r.w, r.h)
        item.tap, item.hold = tap, hold
        item.row_card = card_scope
        widget._actions[#widget._actions + 1] = item
    end
    local function settings(id)
        return function() if ctx.open_settings_fn then ctx.open_settings_fn(id) end end
    end
    local function bookAction(r, fp)
        action(r, function() if ctx.open_fn then ctx.open_fn(fp) end end,
            function() if ctx.hold_fn then ctx.hold_fn(fp, Model.id) end end)
    end
    local function bar(x, y, w, value, dark, key)
        local palette = colours(key)
        add(UI.progressBar(math.max(1, math.floor(w)), Model.fraction(value), px(4),
            dark and paper or (palette and native(palette.accent)) or ink,
            dark and BB.COLOR_DARK_GRAY or BB.COLOR_LIGHT_GRAY), x, y)
    end
    local function cover(fp, r, hero)
        local image = makeCover(fp, r, ctx)
        if image then
            add(image, r.x, r.y)
            widget._cover_slots[#widget._cover_slots + 1] = {
                file = fp, area = r, index = #target, parent = target, hero = hero, row_card = card_scope }
        end
        bookAction(r, fp)
        return image
    end
    local function title(label, r, dark)
        text(label, r.x + p.pad, r.y + p.pad, r.w - p.pad * 2, 13, true, dark and paper or ink)
    end
    local function heading(key, fallback)
        return Model.heading(data.headings, key, fallback)
    end

    local date = os.date("*t")
    text(_(Model.greeting(date.hour)), 0, 0, p.w - px(112), 23, true)
    text(string.format("%d %s %d", date.day, _(MONTHS[date.month]), date.year),
        0, px(31), p.w - px(112), 13, false, muted)
    local search = rect(p.w - px(54), 0, px(54), px(52))
    text(_("Search"), search.x, px(14), search.w, 13, true)
    action(search, function() require("core/orbitui_search").show() end)
    local add_area = rect(p.w - px(108), 0, px(48), px(52))
    text("+", add_area.x + px(12), px(8), add_area.w, 26, true)
    action(add_area, function() widget:editModules("add") end)
    if (p.pages or 1) > 1 then
        -- These are dashboard pages, independent of Home and book-row pagers.
        local row = math.max(26, math.floor(p.header_h * .40))
        local y = p.header_h - row
        text(string.format("%d / %d", p.page, p.pages), p.w / 2 - px(25), y, px(55), 14, true)
        local function turn(delta)
            local next_page = math.max(1, math.min(p.pages, p.page + delta))
            if next_page == p.page then return end
            widget._module_page = next_page
            widget:replaceContent(ctx, data)
            require("ui/uimanager"):setDirty(ctx._screen_widget or widget, "ui", widget.dimen)
        end
        text("<", 0, y, px(42), 21, true, p.page > 1 and ink or muted)
        text(">", p.w - px(42), y, px(42), 21, true, p.page < p.pages and ink or muted)
        action(rect(0, y, px(54), row), function() turn(-1) end)
        action(rect(p.w - px(54), y, px(54), row), function() turn(1) end)
    end

    -- Hero: covers stay in colour; only the surrounding card is dark.
    -- Night cards share light ink on a dark surface. The day-only hero
    -- emphasis must not become a bright white hole when the frame inverts.
    local r, dark = p.hero, data.dark and not Screen.night_mode
    if r then
    local hero_frame = box(r, dark and ink or nil, dark and ink or nil, "hero")
    if coloured then
        widget._hero_apply_colour = function(image)
            local palette = colours("hero", M.coverColour(image))
            hero_frame.background = (dark and native(palette.deep)) or (not dark and native(palette.fill)) or (dark and ink or paper)
            hero_frame.color = dark and hero_frame.background or native(palette.border)
        end
    end
    local label = data.current and data.current.data.status == "complete" and "Last opened" or "Continue reading"
    title(heading("hero", _(label)), r, dark)
    if data.current then
        local bd = data.current.data
        local h = r.h - p.pad * 2 - px(28)
        local cw = math.floor(math.min(h * 2 / 3, r.w * 0.40))
        local ch = math.floor(cw * 3 / 2)
        local cr = rect(r.x + p.pad, r.y + r.h - p.pad - ch, cw, ch)
        local hero_image = cover(data.current.file, cr, true)
        if widget._hero_apply_colour then widget._hero_apply_colour(hero_image) end
        local tx, ty = cr.x + cw + px(12), r.y + p.pad + px(34)
        local tw = r.x + r.w - p.pad - tx
        text(bd.title, tx, ty, tw, 18, true, dark and paper or ink, 2)
        text(require("infra/sui_text").formatAuthors(bd.authors) or "",
            tx, ty + px(53), tw, 13, false, dark and paper or muted, 2)
        local by = r.y + r.h - p.pad - px(35)
        bar(tx, by, tw, bd.percent, dark, "hero")
        text(string.format("%d%%", math.floor(Model.fraction(bd.percent) * 100 + 0.5)),
            tx, by + px(11), tw, 14, true, dark and paper or ink)
        bookAction(rect(tx, ty, tw, r.y + r.h - p.pad - ty), data.current.file)
    else
        text(_("Open a book to start reading."), r.x + p.pad, r.y + px(60),
            r.w - p.pad * 2, 17, false, dark and paper or ink, 3)
    end
    end

    local stats = data.stats
    local tiles = {
        { "Pages today", tostring(stats.today_pages or 0), "pages", "pages_today" },
        { "Reading today", Model.duration(stats.today_secs), "reading time", "reading_today" },
        { "Reading streak", tostring(stats.streak or 0), "days in a row", "streak" },
        { "This week", Model.duration(stats.week_secs), "reading time", "week" },
    }
    for i, tile in ipairs(tiles) do
        r = p.stats[i]
        if r then
        box(r, nil, nil, tile[4])
        title(heading(tile[4], _(tile[1])), r)
        text(tile[2], r.x + p.pad, r.y + math.floor(r.h * 0.40), r.w - p.pad * 2, 23, true)
        text(_(tile[3]), r.x + p.pad, r.y + r.h - p.pad - px(15), r.w - p.pad * 2, 11, false, muted)
        action(r, settings("reading_stats"))
        end
    end

    r = p.ongoing
    if r then
    box(r, nil, nil, "ongoing")
    title(heading("ongoing", _("Also reading")), r)
    if #data.ongoing == 0 then
        text(_("No other books in progress."), r.x + p.pad, r.y + px(46),
            r.w - p.pad * 2, 14, false, muted, 3)
    else
        local rh = math.floor((r.h - 2 * p.pad - px(25)) / 3)
        for i, book in ipairs(data.ongoing) do
            local y = r.y + p.pad + px(26) + (i - 1) * rh
            local ch, cw = rh - px(5), math.floor((rh - px(5)) * 2 / 3)
            cover(book.file, rect(r.x + p.pad, y, cw, ch))
            local tx = r.x + p.pad + cw + px(10)
            local tw = r.x + r.w - p.pad - tx
            text(book.data.title, tx, y, tw, 13, true)
            local pct = string.format("%d%%", math.floor(Model.fraction(book.data.percent) * 100 + 0.5))
            bar(tx, y + rh - px(15), tw - px(37), book.data.percent, false, "ongoing")
            text(pct, tx + tw - px(32), y + rh - px(21), px(32), 10, false, muted)
            bookAction(rect(tx, y, tw, rh), book.file)
        end
    end
    end

    r = p.goal
    if r then
    box(r, nil, nil, "goal")
    local goal = data.goal
    title(heading("goal", goal and goal.title and goal.title ~= "" and goal.title
        or _("Reading goal") .. " " .. date.year), r)
    if goal then
        local unit = ({ book = "books", books = "books", page = "pages", pages = "pages",
            hour = "hours", minute = "minutes" })[goal.metric] or "completed"
        local value, target = tonumber(goal.value) or 0, tonumber(goal.target) or 0
        text(string.format("%s / %s", value, target > 0 and tostring(target) or "-"),
            r.x + p.pad, r.y + px(43), r.w - p.pad * 2, 28, true)
        text(_(unit), r.x + p.pad, r.y + px(80), r.w - p.pad * 2, 13, false, muted)
        bar(r.x + p.pad, r.y + r.h - p.pad - px(30), r.w - p.pad * 2, target > 0 and value / target or 0, false, "goal")
        text(target <= 0 and _("Set a reading goal") or
            (value >= target and _("Goal reached") or goal.source),
            r.x + p.pad, r.y + r.h - p.pad - px(17), r.w - p.pad * 2, 11, false, muted)
    else
        text(_("No cached goal yet. Tap to configure."), r.x + p.pad, r.y + px(46),
            r.w - p.pad * 2, 14, false, muted, 3)
    end
    action(r, settings(goal and goal.module or "hardcover"))
    end

    local owner = ctx._screen_widget or widget
    owner._orbitui_dashboard_pages = owner._orbitui_dashboard_pages or {}
    owner._orbitui_dashboard_sources = owner._orbitui_dashboard_sources or {}
    local function shelf(key, label, files, failed, module, extra)
        local area = extra and p.cards[key] or p[key]
        if not area then return end
        local source = extra and extra.source or data.config and data.config.sources[key]
        if source then
            local identity = extra and table.concat({ source.account, source.section, source.id, extra.view }, ":") or Model.sourceKey(source)
            if owner._orbitui_dashboard_sources[key] ~= identity then
                owner._orbitui_dashboard_pages[key] = 1
                owner._orbitui_dashboard_sources[key] = identity
            end
        end
        box(area, nil, nil, key)
        local count = extra and extra.view == "carousel" and 1 or 3
        local pages = math.max(1, math.ceil(#files / count))
        local page = math.min(pages, math.max(1, owner._orbitui_dashboard_pages[key] or 1))
        owner._orbitui_dashboard_pages[key] = page
        local nav_h = pages > 1 and px(48) or 0
        local bottom_pad = pages > 1 and px(4) or p.pad
        local nav_y = area.y + area.h - bottom_pad - nav_h
        local function turn(delta)
            local next_page = math.max(1, math.min(pages, page + delta))
            if next_page == page then return end
            owner._orbitui_dashboard_pages[key] = next_page
            if extra then extra.redraw() else widget:replaceContent(ctx, data) end
            require("ui/uimanager"):setDirty(ctx._screen_widget or widget, "ui", widget.dimen)
        end
        local swipe_area = rect(area.x, area.y, area.w, area.h)
        swipe_area.turn, swipe_area.row_card = turn, card_scope
        widget._swipe_areas[#widget._swipe_areas + 1] = swipe_area
        text(heading(key, label), area.x + p.pad, area.y + p.pad, area.w - 2 * p.pad, 13, true)
        if extra then
            local edit = function() widget:editModules(key) end
            local hold = require("infra/sui_store"):readSetting("simpleui_hs_settings_on_hold") ~= false and edit or nil
            action(area, edit, hold)
            action(rect(area.x, area.y, area.w, px(65)), function() widget:editModules(key) end,
                hold)
            text("[BookOrbit] " .. extra.caption, area.x + p.pad, area.y + p.pad + px(22), area.w - 2 * p.pad, 10, false, muted)
        end
        if pages > 1 then
            local button_w = px(52)
            local indicator_w = math.min(px(76), area.w - 2 * p.pad - 2 * button_w)
            local nav_x = area.x + math.floor((area.w - 2 * button_w - indicator_w) / 2)
            local function centered(value, x, width, size, color)
                local label_widget = text(value, x, nav_y, width, size, false, color)
                local label_size = label_widget:getSize()
                label_widget.overlap_offset = {
                    x + math.floor((width - label_size.w) / 2),
                    nav_y + math.floor((nav_h - label_size.h) / 2),
                }
            end
            centered("<", nav_x, button_w, 28, page > 1 and ink or BB.COLOR_LIGHT_GRAY)
            centered(string.format("%d/%d", page, pages), nav_x + button_w, indicator_w, 16, ink)
            centered(">", nav_x + button_w + indicator_w, button_w, 28,
                page < pages and ink or BB.COLOR_LIGHT_GRAY)
            action(rect(nav_x, nav_y, button_w, nav_h), function() turn(-1) end)
            action(rect(nav_x + button_w + indicator_w, nav_y, button_w, nav_h), function() turn(1) end)
        end
        if #files == 0 then
            text(extra and (extra.error and require("adapters/orbitui_bookorbit_rows").message(extra.error)
                    or _("No linked books from this source on this device."))
                    or (failed and _("Could not load books.") or _("No books to show yet.")),
                area.x + p.pad, area.y + px(extra and 75 or 50), area.w - p.pad * 2, 14, false, muted, 3)
            action(area, extra and function() widget:editModules(key) end or settings(data.config and Model.id or module))
            return
        end
        local slot_w = math.floor((area.w - 2 * p.pad - 2 * p.gap) / count)
        local cover_top = px(extra and 65 or 34)
        local max_h = math.max(3, nav_y - area.y - p.pad - cover_top)
        local cw = math.floor(math.min(slot_w, max_h * 2 / 3))
        local ch = math.floor(cw * 3 / 2)
        for i = 1, count do
            local fp = files[(page - 1) * count + i]
            if fp and (not extra or require("adapters/orbitui_bookorbit_rows").fileExists(fp)) then
                cover(fp, rect(area.x + p.pad + (i - 1) * (slot_w + p.gap) + math.floor((slot_w - cw) / 2),
                    area.y + cover_top + p.pad + math.floor((max_h - ch) / 2), cw, ch))
            end
        end
    end
    shelf("want", data.source_labels and data.source_labels.want or _("BookOrbit Want to Read"), data.want, data.want_error, "bookorbit_want")
    shelf("new", data.source_labels and data.source_labels.new or _("Recently added"), data.new, data.new_error, "new_books")
    local Sources = require("adapters/orbitui_dashboard_sources")
    local generation = widget._module_generation
    local ticks = {}
    for _i, entry in ipairs(data.config and data.config.modules or {}) do
        local area = p.cards[entry.id]
        if area then
            local selected = entry
            if entry.kind == "bookorbit" then
                local Rows = require("adapters/orbitui_bookorbit_rows")
                local index, group, redraw
                local function draw()
                    for _, list in ipairs({ widget._actions, widget._cover_slots, widget._swipe_areas }) do
                        for i = #list, 1, -1 do if list[i].row_card == selected.id then table.remove(list, i) end end
                    end
                    local previous = target
                    group = Overlap:new{ dimen = Geom:new{ w = p.w, h = p.h }, allow_mirroring = false }
                    group.overlap_offset = { 0, 0 }
                    target, card_scope = group, selected.id
                    local snapshot = Rows.snapshot(selected.source)
                    shelf(selected.id, (selected.label or selected.source and selected.source.title or _("Source")) .. " [BookOrbit]",
                        snapshot.files, nil, nil, { source = selected.source, view = selected.view,
                            caption = Rows.caption(snapshot), error = snapshot.error, redraw = function() redraw() end })
                    target, card_scope = previous, nil
                    return group
                end
                redraw = function()
                    if not widget:modulesVisible(generation) then return end
                    local old = group
                    root[index] = draw()
                    old:free()
                    local d = widget.dimen
                    require("ui/uimanager"):setDirty(ctx._screen_widget or widget, "ui",
                        Geom:new{ x = (d.x or 0) + area.x, y = (d.y or 0) + area.y, w = area.w, h = area.h })
                end
                root[#root + 1] = draw(); index = #root
                -- Schedule after building. No network or ID-map construction
                -- in paint; retired/hidden cards cannot commit or redraw Home.
                local function refreshRow()
                    if not widget:modulesVisible(generation) then return end
                    Rows.refresh(selected.source, { source_required = true,
                        current = function() return widget:modulesVisible(generation) end,
                        on_done = function(result)
                            if result.error ~= "stale" then redraw() end
                        end })
                end
                ticks[#ticks + 1] = refreshRow
                require("ui/uimanager"):nextTick(refreshRow)
            else
            box(area, nil, nil, entry.id)
            title(entry.label or entry.ref, area)
            local inset, top = p.pad, math.max(px(32), p.pad * 2)
            local w, h = math.max(1, area.w - inset * 2), math.max(1, area.h - top - inset)
            local args, pending, building, index, clip, def, regions, refreshModule
            local revision = 0
            local function makeClip()
                revision = revision + 1
                local born = revision
                args = {}
                for k, v in pairs(ctx) do args[k] = v end
                args.refresh_fn = function() if born == revision then refreshModule() end end
                building = true
                local child
                child, def, regions = Sources.buildModule(selected, w, h, args)
                building = false
                local fallback = UI.makeTextBox{ text = selected.kind == "action" and def and _("Tap to open")
                        or _("Module unavailable. Long-press to configure."),
                    face = Style.getStyledFace(nil, 14 / (Screen:scaleBySize(1000) / 1000), "regular"),
                    width = w, max_lines = 3, height_adjust = true }
                return Sources.moduleContainer(child, fallback, w, h, paper)
            end
            refreshModule = function()
                if building or pending or not widget:modulesVisible(generation) then return end
                pending = true
                require("ui/uimanager"):nextTick(function()
                    pending = false
                    if not widget:modulesVisible(generation) then return end
                    local previous = clip
                    clip = makeClip()
                    clip.overlap_offset = { area.x + inset, area.y + top }
                    root[index] = clip
                    previous:free()
                    local d = widget.dimen
                    require("ui/uimanager"):setDirty(ctx._screen_widget or widget, "ui",
                        Geom:new{ x = (d.x or 0) + area.x + inset, y = (d.y or 0) + area.y + top, w = w, h = h })
                end)
            end
            clip = makeClip()
            if clip[1] ~= clip.fallback and def and (def.on_minute or def.wants_minute_tick
                    or selected.kind == "simpleui" and def.scheduleRefresh) then
                ticks[#ticks + 1] = function() Sources.tickModule(selected, def, refreshModule) end
            end
            add(clip, area.x + inset, area.y + top)
            index = #root
            action(area, function(x, y)
                if not def or clip.failed then widget:editModules(selected.id)
                else
                    Sources.tapModule(selected, def, args, regions,
                        x - inset - (clip._child_dx or 0), y - top - (clip._child_dy or 0))
                end
            end, require("infra/sui_store"):readSetting("simpleui_hs_settings_on_hold") ~= false
                and function() widget:editModules(selected.id) end or nil)
            end
        end
    end
    if #ticks > 0 then
        widget._module_tick = function()
            if widget._disposed or generation ~= widget._module_generation then return end
            local owner = ctx._screen_widget
            if widget._modules_suspended or owner and owner._suspended or require("device").screen_saver_mode then return end
            if widget:modulesVisible(generation) then
                for _, tick in ipairs(ticks) do
                    if not widget:modulesVisible(generation) then break end
                    tick()
                end
            end
            if not widget._disposed and not widget._modules_suspended and generation == widget._module_generation then
                require("ui/uimanager"):scheduleIn(60, widget._module_tick)
            end
        end
        require("ui/uimanager"):scheduleIn(60, widget._module_tick)
    end
    if p.cards and not next(p.cards) then
        text(_(data.config.unsupported and "This dashboard needs a newer OrbitUI version."
            or "No cards selected. Tap to configure."), p.pad, p.header_h + p.gap,
            p.w - 2 * p.pad, 16, false, muted, 3)
        action(rect(0, p.header_h, p.w, p.h - p.header_h), settings(Model.id))
    end
    return root
end

function M.build(w, h, ctx, data)
    local widget = Dashboard:new{ dimen = Geom:new{ w = w, h = h } }
    widget.ges_events = {
        DashboardTap = { GestureRange:new{ ges = "tap", range = function() return widget.dimen end } },
        DashboardHold = { GestureRange:new{ ges = "hold", range = function() return widget.dimen end } },
        DashboardHoldRelease = { GestureRange:new{ ges = "hold_release", range = function() return widget.dimen end } },
    }
    widget:replaceContent(ctx, data)
    return widget
end

return M
