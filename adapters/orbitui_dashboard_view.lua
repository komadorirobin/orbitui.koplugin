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
local MONTHS = { "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December" }

local function rect(x, y, w, h) return { x = x, y = y, w = w, h = h } end

local function hit(area, x, y)
    return x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h
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
        if hit(action, x, y) then action.tap(); return true end
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
end

function Dashboard:onDashboardHoldRelease()
    if not self._held then return end
    local held = self._held
    self._held = nil
    held()
    return true
end

function Dashboard:replaceContent(ctx, data)
    local old = self[1]
    self._dashboard_ctx, self._dashboard_data = ctx, data
    self._actions, self._cover_slots, self._held = {}, {}, nil
    self[1] = M.content(self, Model.plan(self.dimen.w, self.dimen.h), ctx, data)
    if old then old:free() end
end

function Dashboard:refreshCovers()
    local changed = false
    for _, slot in ipairs(self._cover_slots) do
        local image = SH.getBookCover(slot.file, slot.area.w, slot.area.h, false)
        if image then
            image.overlap_offset = { slot.area.x, slot.area.y }
            local old = self[1][slot.index]
            self[1][slot.index] = image
            old:free()
            changed = true
        end
    end
    return changed
end

function M.content(widget, p, ctx, data)
    local root = Overlap:new{ dimen = Geom:new{ w = p.w, h = p.h }, allow_mirroring = false }
    local ink, paper, muted = BB.COLOR_BLACK, BB.COLOR_WHITE, BB.COLOR_DARK_GRAY
    local function px(n) return math.max(1, math.floor(n * p.scale)) end
    local function add(child, x, y)
        child.overlap_offset = { x, y }
        root[#root + 1] = child
        return child
    end
    local function box(r, fill, border)
        return add(Frame:new{
            dimen = Geom:new{ w = r.w, h = r.h }, width = r.w, height = r.h,
            margin = 0, padding = 0, radius = px(12), bordersize = px(1),
            background = fill or paper, color = border or BB.COLOR_GRAY,
            Overlap:new{ dimen = Geom:new{ w = r.w - 2 * px(1), h = r.h - 2 * px(1) } },
        }, r.x, r.y)
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
        widget._actions[#widget._actions + 1] = item
    end
    local function settings(id)
        return function() if ctx.open_settings_fn then ctx.open_settings_fn(id) end end
    end
    local function bookAction(r, fp)
        action(r, function() if ctx.open_fn then ctx.open_fn(fp) end end,
            function() if ctx.hold_fn then ctx.hold_fn(fp, Model.id) end end)
    end
    local function bar(x, y, w, value, dark)
        add(UI.progressBar(math.max(1, math.floor(w)), Model.fraction(value), px(4),
            dark and paper or ink, dark and BB.COLOR_DARK_GRAY or BB.COLOR_LIGHT_GRAY), x, y)
    end
    local function cover(fp, r)
        local image = makeCover(fp, r, ctx)
        if image then
            add(image, r.x, r.y)
            widget._cover_slots[#widget._cover_slots + 1] = { file = fp, area = r, index = #root }
        end
        bookAction(r, fp)
    end
    local function title(label, r, dark)
        text(label, r.x + p.pad, r.y + p.pad, r.w - p.pad * 2, 13, true, dark and paper or ink)
    end
    local function heading(key, fallback)
        return Model.heading(data.headings, key, fallback)
    end

    local date = os.date("*t")
    text(_(Model.greeting(date.hour)), 0, 0, p.w - px(58), 23, true)
    text(string.format("%d %s %d", date.day, _(MONTHS[date.month]), date.year),
        0, px(31), p.w - px(58), 13, false, muted)
    local search = rect(p.w - px(54), 0, px(54), p.header_h)
    text(_("Search"), search.x, px(14), search.w, 13, true)
    action(search, function() require("core/orbitui_search").show() end)

    -- Hero: covers stay in colour; only the surrounding card is dark.
    local r, dark = p.hero, data.dark
    box(r, dark and ink or paper, dark and ink or nil)
    local label = data.current and data.current.data.status == "complete" and "Last opened" or "Continue reading"
    title(heading("hero", _(label)), r, dark)
    if data.current then
        local bd = data.current.data
        local h = r.h - p.pad * 2 - px(28)
        local cw = math.floor(math.min(h * 2 / 3, r.w * 0.40))
        local ch = math.floor(cw * 3 / 2)
        local cr = rect(r.x + p.pad, r.y + r.h - p.pad - ch, cw, ch)
        cover(data.current.file, cr)
        local tx, ty = cr.x + cw + px(12), r.y + p.pad + px(34)
        local tw = r.x + r.w - p.pad - tx
        text(bd.title, tx, ty, tw, 18, true, dark and paper or ink, 2)
        text(require("infra/sui_text").formatAuthors(bd.authors) or "",
            tx, ty + px(53), tw, 13, false, dark and paper or muted, 2)
        local by = r.y + r.h - p.pad - px(35)
        bar(tx, by, tw, bd.percent, dark)
        text(string.format("%d%%", math.floor(Model.fraction(bd.percent) * 100 + 0.5)),
            tx, by + px(11), tw, 14, true, dark and paper or ink)
        bookAction(rect(tx, ty, tw, r.y + r.h - p.pad - ty), data.current.file)
    else
        text(_("Open a book to start reading."), r.x + p.pad, r.y + px(60),
            r.w - p.pad * 2, 17, false, dark and paper or ink, 3)
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
        box(r)
        title(heading(tile[4], _(tile[1])), r)
        text(tile[2], r.x + p.pad, r.y + math.floor(r.h * 0.40), r.w - p.pad * 2, 23, true)
        text(_(tile[3]), r.x + p.pad, r.y + r.h - p.pad - px(15), r.w - p.pad * 2, 11, false, muted)
        action(r, settings("reading_stats"))
    end

    r = p.ongoing
    box(r)
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
            bar(tx, y + rh - px(15), tw - px(37), book.data.percent)
            text(pct, tx + tw - px(32), y + rh - px(21), px(32), 10, false, muted)
            bookAction(rect(tx, y, tw, rh), book.file)
        end
    end

    r = p.goal
    box(r)
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
        bar(r.x + p.pad, r.y + r.h - p.pad - px(30), r.w - p.pad * 2, target > 0 and value / target or 0)
        text(target <= 0 and _("Set a reading goal") or
            (value >= target and _("Goal reached") or goal.source),
            r.x + p.pad, r.y + r.h - p.pad - px(17), r.w - p.pad * 2, 11, false, muted)
    else
        text(_("No cached goal yet. Tap to configure."), r.x + p.pad, r.y + px(46),
            r.w - p.pad * 2, 14, false, muted, 3)
    end
    action(r, settings(goal and goal.module or "hardcover"))

    local owner = ctx._screen_widget or widget
    owner._orbitui_dashboard_pages = owner._orbitui_dashboard_pages or {}
    local function shelf(key, label, files, failed, module)
        local area = p[key]
        box(area)
        local count = 3
        local pages = math.max(1, math.ceil(#files / count))
        local page = math.min(pages, math.max(1, owner._orbitui_dashboard_pages[key] or 1))
        owner._orbitui_dashboard_pages[key] = page
        local nav_h = pages > 1 and px(32) or 0
        text(heading(key, label), area.x + p.pad, area.y + p.pad, area.w - 2 * p.pad, 13, true)
        if pages > 1 then
            local button_w = px(36)
            local indicator_w = math.min(px(76), area.w - 2 * p.pad - 2 * button_w)
            local nav_x = area.x + math.floor((area.w - 2 * button_w - indicator_w) / 2)
            local nav_y = area.y + area.h - p.pad - nav_h
            local function centered(value, x, width, size, color)
                local label_widget = text(value, x, nav_y, width, size, false, color)
                local label_size = label_widget:getSize()
                label_widget.overlap_offset = {
                    x + math.floor((width - label_size.w) / 2),
                    nav_y + math.floor((nav_h - label_size.h) / 2),
                }
            end
            local function turn(delta)
                local next_page = math.max(1, math.min(pages, page + delta))
                if next_page == page then return end
                owner._orbitui_dashboard_pages[key] = next_page
                widget:replaceContent(ctx, data)
                require("ui/uimanager"):setDirty(ctx._screen_widget or widget, "ui", widget.dimen)
            end
            centered("<", nav_x, button_w, 18, page > 1 and ink or BB.COLOR_LIGHT_GRAY)
            centered(string.format("%d/%d", page, pages), nav_x + button_w, indicator_w, 11, muted)
            centered(">", nav_x + button_w + indicator_w, button_w, 18,
                page < pages and ink or BB.COLOR_LIGHT_GRAY)
            action(rect(nav_x, nav_y, button_w, nav_h), function() turn(-1) end)
            action(rect(nav_x + button_w + indicator_w, nav_y, button_w, nav_h), function() turn(1) end)
        end
        if #files == 0 then
            text(failed and _("Could not load books.") or _("No books to show yet."),
                area.x + p.pad, area.y + px(50), area.w - p.pad * 2, 14, false, muted, 3)
            action(area, settings(module))
            return
        end
        local slot_w = math.floor((area.w - 2 * p.pad - 2 * p.gap) / count)
        local max_h = area.h - 2 * p.pad - px(34) - nav_h
        local cw = math.floor(math.min(slot_w, max_h * 2 / 3))
        local ch = math.floor(cw * 3 / 2)
        for i = 1, count do
            local fp = files[(page - 1) * count + i]
            if fp then
                cover(fp, rect(area.x + p.pad + (i - 1) * (slot_w + p.gap) + math.floor((slot_w - cw) / 2),
                    area.y + px(34) + p.pad + math.floor((max_h - ch) / 2), cw, ch))
            end
        end
    end
    shelf("want", _("BookOrbit Want to Read"), data.want, data.want_error, "bookorbit_want")
    shelf("new", _("Recently added"), data.new, data.new_error, "new_books")
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
