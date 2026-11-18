-- A view of KOReader's recorded reading. Only open Statistics on demand.
local _ = require("core/orbitui_i18n")
local M = {}
local WEEKS = 12
local RECENT_LIMIT = 6

local function dayAt(stamp, delta, hour)
    local t = os.date("*t", stamp)
    return os.time{ year = t.year, month = t.month, day = t.day + delta, hour = hour or 12 }
end

local function dayKey(stamp)
    return os.date("%Y-%m-%d", stamp)
end

function M.weekEnding(stamp)
    local days = {}
    for i = 1, 7 do days[i] = dayAt(stamp, i - 7) end
    return days
end

function M.calendarRange(stamp, back)
    local week_end = dayAt(stamp, (8 - os.date("*t", stamp).wday) % 7 - 7 * WEEKS * back)
    return dayAt(week_end, 1 - WEEKS * 7), week_end
end

local function withStats(fn)
    local Config = require("infra/sui_config")
    if Config.isStatsSyncGuarded() then return nil, "sync" end
    local path = Config.getStatsDbPath()
    if require("libs/libkoreader-lfs").attributes(path, "mode") ~= "file" then return nil, "missing" end
    local conn
    local ok, result = pcall(function()
        conn = require("lua-ljsqlite3/init").open(path, "ro")
        conn:exec("PRAGMA query_only=ON; PRAGMA busy_timeout=40;")
        return fn(conn)
    end)
    if conn then pcall(conn.close, conn) end
    if ok then return result end
    return nil, "error"
end

local function booksForRange(conn, lo, hi, limit)
    -- Count distinct pages once per book and local date. The six visible
    -- entries and the full week total share this one range scan.
    local sql = string.format([[
        WITH activity AS (
            SELECT id_book, date(start_time, 'unixepoch', 'localtime') AS day,
                   MAX(start_time) AS last, SUM(duration) AS secs, COUNT(DISTINCT page) AS pages
            FROM page_stat_data
            WHERE start_time >= %d AND start_time < %d AND duration > 0
            GROUP BY day, id_book
        ), recent AS (
            SELECT * FROM activity ORDER BY last DESC, id_book %s
        )
        SELECT recent.day, recent.secs, recent.pages, book.title %s
        FROM recent LEFT JOIN book ON book.id = recent.id_book
        ORDER BY recent.last DESC, recent.id_book
    ]], lo, hi, limit and ("LIMIT " .. limit) or "",
        limit and ", (SELECT SUM(pages) FROM activity)" or "")
    local stmt = assert(conn:prepare(sql), "Reading log query unavailable")
    local books, pages = {}, 0
    local ok, failure = pcall(function()
        for row in stmt:rows() do
            books[#books + 1] = { day = row[1], secs = tonumber(row[2]) or 0, pages = tonumber(row[3]) or 0,
                title = row[4] ~= "" and row[4] or nil }
            if limit then pages = tonumber(row[5]) or 0 end
        end
    end)
    pcall(stmt.close, stmt)
    if not ok then error(failure, 0) end
    return books, pages
end

function M.read(stamp)
    local days = M.weekEnding(stamp)
    local start, finish = dayAt(days[1], 0, 0), dayAt(days[7], 1, 0)
    return withStats(function(conn)
        local ledger = assert(require("infra/sui_stats_ledger").get(conn))
        local read = ledger:dailySeconds(dayKey(days[1]), dayKey(days[7]))
        local seconds = 0
        for _, day in ipairs(days) do seconds = seconds + (read[dayKey(day)] or 0) end
        local recent, pages = booksForRange(conn, start, finish, RECENT_LIMIT)

        local active = {}
        for _, entry in ipairs(ledger:activeDates()) do active[#active + 1] = entry[1] end
        local Streak = require("infra/sui_streak")
        local streak_opts = { today = dayKey(stamp), yesterday = dayKey(dayAt(stamp, -1)),
            frozen_dates = Streak.getFrozenDatesInRange(nil, dayKey(stamp)) }
        return { ledger = ledger, days = days, read = read, seconds = seconds, pages = pages,
            current = Streak.computeCurrentDayStreak(active, streak_opts),
            best = Streak.computeLongestDayStreak(active, streak_opts),
            recent = recent }
    end)
end

function M.readDay(stamp)
    return withStats(function(conn)
        return booksForRange(conn, dayAt(stamp, 0, 0), dayAt(stamp, 1, 0))
    end)
end

local function duration(seconds)
    if seconds > 0 and seconds < 60 then return _("<1 min") end
    return require("core/orbitui_dashboard").duration(seconds, true)
end

local function pagesText(n)
    return string.format(_(n == 1 and "%d page" or "%d pages"), n)
end

local function dateLabel(stamp, show_year)
    local d = os.date("*t", stamp)
    local months = require("infra/sui_datenames").monthShort()
    return string.format("%d %s%s", d.day, months[d.month], show_year and (" " .. d.year) or "")
end

local function dateFromKey(key)
    local y, m, d = key:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if y then return os.time{ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 } end
end

function M.open(opts)
    opts = opts or {}
    local today = os.time()
    local snapshot, failure = M.read(today)
    local active_tab, calendar_back = "log", 0
    local day_cache = {}

    local Device = require("device")
    local BB = require("ffi/blitbuffer")
    local Window = require("engines/sui_window")
    local UI = require("infra/sui_core")
    local Style = require("features/sui_style")
    local Names = require("infra/sui_datenames")
    local Heat = require("engines/sui_heatmap_data")
    local Frames = require("screens/insights/sui_insights_frames")
    local Font = require("ui/font")
    local Geom = require("ui/geometry")
    local Center = require("ui/widget/container/centercontainer")
    local Left = require("ui/widget/container/leftcontainer")
    local Frame = require("ui/widget/container/framecontainer")
    local Widget = require("ui/widget/container/widgetcontainer")
    local Text = require("ui/widget/textwidget")
    local H = require("ui/widget/horizontalgroup")
    local V = require("ui/widget/verticalgroup")
    local HGap = require("ui/widget/horizontalspan")
    local VGap = require("ui/widget/verticalspan")

    local ink, paper, muted = BB.COLOR_BLACK, BB.COLOR_WHITE, BB.Color8(72)
    local accent = muted
    if opts.accent then accent = require("infra/sui_accent").toColor(opts.accent) or muted end
    local function px(ctx, size) return math.max(1, ctx.SZ(Device.screen:scaleBySize(size))) end
    local function text(ctx, value, w, size, bold, color)
        return Text:new{ text = value, face = Font:getFace(Style.FACE_REGULAR, ctx.SZ(size)),
            max_width = w, bold = bold, fgcolor = color or ink, truncate_with_ellipsis = true }
    end
    local function box(w, h, fill, border, radius, child)
        local dimen = Geom:new{ w = w, h = h }
        local inset = border and 2 or 0
        local inner = Geom:new{ w = w - inset, h = h - inset }
        return Frame:new{ padding = 0, margin = 0, bordersize = border and 1 or 0,
            color = border, background = fill, radius = radius or 0, dimen = dimen,
            child and Center:new{ dimen = inner, child } or Widget:new{ dimen = inner } }
    end
    local function tappable(widget, tap)
        return Window.Input.tapable(widget, { on_tap = tap })
    end
    local statsMessages = {
        sync = "Reading statistics are syncing. Try again shortly.",
        missing = "Enable Reading statistics in KOReader to collect your reading log.",
        error = "Could not read KOReader's reading statistics. Try again shortly.",
    }
    local function message(ctx, err)
        return Window.ListRow{ inner_w = ctx.inner_w, title = _(statsMessages[err] or statsMessages.error) }
    end
    local function noReading(ctx)
        return Window.ListRow{ inner_w = ctx.inner_w, title = _("No reading recorded for this day.") }
    end
    local function subhead(ctx, label)
        return Window.Section{ inner_w = ctx.inner_w, title = label }
    end
    local function openDay(ctx, stamp)
        ctx.push("day", { stamp = stamp })
    end
    local function makeRow(ctx, book, with_date)
        local stamp = with_date and dateFromKey(book.day)
        local name = book.title or _("Untitled book")
        local meta = duration(book.secs) .. " · " .. pagesText(book.pages)
        if not stamp then
            return Window.ListRow{ inner_w = ctx.inner_w, title = name, subtitle = meta, left_icon = "book" }
        end
        local h, trailing = px(ctx, 49), px(ctx, 24)
        local w = ctx.inner_w - trailing
        local row = H:new{ align = "center",
            Left:new{ dimen = Geom:new{ w = w, h = h }, V:new{ align = "left",
                text(ctx, name, w, 17, true),
                text(ctx, dateLabel(stamp) .. " · " .. meta, w, 13, false, muted),
            } },
            Center:new{ dimen = Geom:new{ w = trailing, h = h }, text(ctx, "›", trailing, 20, true) },
        }
        return tappable(V:new{ align = "left", row, UI.solidBar(ctx.inner_w, 1, BB.Color8(195)) },
            function() openDay(ctx, stamp) end)
    end

    local function tabs(ctx)
        local h, gap = px(ctx, 37), px(ctx, 5)
        local w = math.floor((ctx.inner_w - 2 * gap) / 3)
        local row = H:new{ align = "center" }
        for i, tab in ipairs{ { "log", _("Log") }, { "calendar", _("Calendar") }, { "goal", _("Goal") } } do
            if i > 1 then row[#row + 1] = HGap:new{ width = gap } end
            local key, selected = tab[1], active_tab == tab[1]
            local mark = text(ctx, tab[2], w - 6, 16, true, selected and paper or ink)
            local button = box(w, h, selected and ink or paper, selected and ink or muted, px(ctx, 8), mark)
            row[#row + 1] = selected and button or tappable(button, function()
                active_tab = key
                ctx.repaint()
            end)
        end
        return V:new{ align = "left", row, VGap:new{ width = px(ctx, 10) } }
    end

    local function weekChart(ctx)
        local max = 0
        for _, day in ipairs(snapshot.days) do max = math.max(max, snapshot.read[dayKey(day)] or 0) end
        local columns = H:new{ align = "top" }
        local names = Names.weekdayShort()
        local column_w = math.floor(ctx.inner_w / 7)
        local chart_h = math.min(px(ctx, 88), math.max(px(ctx, 38), math.floor(ctx.page_h / 5)))
        local label_h = px(ctx, 22)
        local gap = px(ctx, 3)
        for _, stamp in ipairs(snapshot.days) do
            local secs = snapshot.read[dayKey(stamp)] or 0
            local ratio = max > 0 and secs / max or 0
            local book_size = math.max(8, math.min(ctx.SZ(13 + 22 * ratio), math.floor(column_w * .58)))
            local book_px = Device.screen:scaleBySize(book_size)
            local day = os.date("*t", stamp)
            local axis = box(column_w, 1, muted, nil)
            local mark = secs > 0 and UI.makeColoredText{ text = Style.icon("book"),
                face = Style.glyphFace(book_px), fgcolor = accent }
                or text(ctx, "·", column_w, 15, true, muted)
            local icon = Center:new{ dimen = Geom:new{ w = column_w, h = book_px }, mark }
            local travel = math.max(0, chart_h - book_px)
            local rise = math.floor(travel * ratio)
            local column = V:new{ align = "center",
                VGap:new{ width = travel - rise }, icon, VGap:new{ width = rise }, axis, VGap:new{ width = gap },
                Center:new{ dimen = Geom:new{ w = column_w, h = label_h },
                    text(ctx, names[day.wday], column_w, 14, dayKey(stamp) == dayKey(today)) },
                Center:new{ dimen = Geom:new{ w = column_w, h = px(ctx, 17) },
                    text(ctx, secs == 0 and "—" or secs < 60 and _("<1 min")
                        or tostring(math.floor(secs / 60)) .. " min", column_w, 12, false, muted) },
            }
            local selected = stamp
            columns[#columns + 1] = tappable(column, function() openDay(ctx, selected) end)
        end
        return columns
    end

    local function log(ctx)
        if not snapshot then return { message(ctx, failure) } end
        local gap = px(ctx, 6)
        local w, h = math.floor((ctx.inner_w - 2 * gap) / 3), px(ctx, 77)
        local figures = H:new{ align = "top" }
        local cards = {
            { value = duration(snapshot.seconds), label = _("Reading time") },
            { value = tostring(snapshot.pages), label = _("Pages read") },
            { value = string.format(_(snapshot.current == 1 and "%d day" or "%d days"), snapshot.current),
                label = _("Current streak"), sub = string.format(_(snapshot.best == 1 and "Best: %d day" or "Best: %d days"), snapshot.best) },
        }
        for i, card in ipairs(cards) do
            if i > 1 then figures[#figures + 1] = HGap:new{ width = gap } end
            local inner = w - 2 * gap
            figures[#figures + 1] = box(w, h, paper, muted, px(ctx, 9), V:new{ align = "center",
                text(ctx, card.value, inner, 22, true),
                text(ctx, card.label, inner, 14, false),
                card.sub and text(ctx, card.sub, inner, 12, false, muted),
            })
        end
        local widgets = { subhead(ctx, _("Last 7 days")), figures, VGap:new{ width = px(ctx, 8) },
            weekChart(ctx), subhead(ctx, _("Recent reading")) }
        for _, book in ipairs(snapshot.recent) do widgets[#widgets + 1] = makeRow(ctx, book, true) end
        if #snapshot.recent == 0 then
            widgets[#widgets + 1] = Window.ListRow{ inner_w = ctx.inner_w, title = _("No reading recorded in the last 7 days.") }
        end
        return widgets
    end

    local function calendar(ctx)
        if not snapshot then return { message(ctx, failure) } end
        local from, to = M.calendarRange(today, calendar_back)
        local latest = math.min(to, today)
        local read = snapshot.ledger:dailySeconds(dayKey(from), dayKey(latest))
        local grid = Heat.heatGrid(read, WEEKS, latest)
        local first = snapshot.ledger.list[1]
        local dows, split = Names.weekdayShort(), require("util").splitToChars
        local gutter, gap = px(ctx, 39), px(ctx, 3)
        local cell_w = math.max(4, math.floor((ctx.inner_w - gutter - WEEKS * gap) / WEEKS))
        local cell_h = math.max(9, math.min(px(ctx, 25), math.floor(ctx.page_h / 13)))
        local shades = { [0] = paper, BB.Color8(218), BB.Color8(167), BB.Color8(107), BB.Color8(49) }
        local heat = V:new{ align = "left" }
        for row = 1, 7 do
            if row > 1 then heat[#heat + 1] = VGap:new{ width = gap } end
            local chars = split(dows[row % 7 + 1])
            local label = table.concat(chars, "", 1, math.min(3, #chars))
            local line = H:new{ align = "center",
                Center:new{ dimen = Geom:new{ w = gutter, h = cell_h }, text(ctx, label, gutter, 12, false) },
            }
            for col = 1, WEEKS do
                line[#line + 1] = HGap:new{ width = gap }
                local level = grid.levels[col][row]
                local stamp = dayAt(from, 7 * (col - 1) + row - 1)
                local today_mark = dayKey(stamp) == dayKey(today)
                local cell = box(cell_w, cell_h, level and shades[level] or nil, level and muted or nil, px(ctx, 3),
                    today_mark and text(ctx, "•", cell_w - 2, 12, true, level and level >= 3 and paper or ink) or nil)
                line[#line + 1] = level and tappable(cell, function() openDay(ctx, stamp) end) or cell
            end
            heat[#heat + 1] = line
        end
        local legend = H:new{ align = "center", text(ctx, _("Less reading"), ctx.inner_w, 13, false) }
        for level = 0, 4 do
            legend[#legend + 1] = HGap:new{ width = gap }
            legend[#legend + 1] = box(px(ctx, 16), px(ctx, 12), shades[level], muted, px(ctx, 2))
        end
        legend[#legend + 1] = HGap:new{ width = px(ctx, 8) }
        legend[#legend + 1] = text(ctx, _("More reading"), ctx.inner_w, 13, false)
        return {
            Window.PeriodHeader{ inner_w = ctx.inner_w, label = dateLabel(from) .. " – " .. dateLabel(latest, true),
                prev_enabled = first ~= nil and first.day < dayKey(from), next_enabled = calendar_back > 0,
                compact = true, on_prev = function() calendar_back = calendar_back + 1; ctx.repaint() end,
                on_next = function() calendar_back = calendar_back - 1; ctx.repaint() end },
            VGap:new{ width = px(ctx, 10) }, heat, VGap:new{ width = px(ctx, 12) }, legend,
        }
    end

    local goal_data
    local function goal(ctx)
        if goal_data == nil then goal_data = opts.get_goal and opts.get_goal() or false end
        local current = goal_data
        if not current then
            return { Window.ListRow{ inner_w = ctx.inner_w, title = _("No reading goal is available yet.") } }
        end
        local value, target = tonumber(current.value) or 0, tonumber(current.target) or 0
        local unit = ({ book = "books", books = "books", page = "pages", pages = "pages",
            hour = "hours", minute = "minutes" })[current.metric] or "completed"
        local content = V:new{ align = "left",
            text(ctx, string.format("%g / %s", value, target > 0 and tostring(target) or "—") .. " " .. _(unit),
                Frames.contentWidth(ctx.inner_w, ctx.SZ), 24, true),
            VGap:new{ width = px(ctx, 6) },
            text(ctx, current.source or "", Frames.contentWidth(ctx.inner_w, ctx.SZ), 15, false, muted),
        }
        if target > 0 then
            local w = Frames.contentWidth(ctx.inner_w, ctx.SZ)
            content[#content + 1] = VGap:new{ width = px(ctx, 10) }
            content[#content + 1] = UI.progressBar(w, math.max(0, value / target), px(ctx, 8), accent)
        end
        return { Frames.card{ w = ctx.inner_w, SZ = ctx.SZ, content = content, icon = "book",
            title = current.title and current.title ~= "" and current.title or _("Reading goal") } }
    end

    local builders = { log = log, calendar = calendar, goal = goal }
    local function dayDetail(ctx)
        local stamp = ctx.current().params.stamp
        local key = dayKey(stamp)
        if not day_cache[key] then
            local books, err = M.readDay(stamp)
            if not books then return { message(ctx, err) } end
            day_cache[key] = books
        end
        local books = day_cache[key]
        if #books == 0 then return { noReading(ctx) } end
        local result = {}
        for _, book in ipairs(books) do result[#result + 1] = makeRow(ctx, book) end
        return result
    end

    local window = Window:new{
        name = "orbitui_reading_log", icon = "book",
        height = math.floor((select(2, UI.getPortraitDims())) * .82), position = "bottom",
        navpager_mode = require("infra/sui_config").isNavpagerEnabled(),
        screen_titles = { __root__ = _("Reading log"), day = function(ctx) return dateLabel(ctx.current().params.stamp, true) end },
        screen_headers = { __root__ = tabs },
        screens = { __root__ = function(ctx) return builders[active_tab](ctx) end, day = dayDetail },
    }
    window:show()
    return window
end

return M
