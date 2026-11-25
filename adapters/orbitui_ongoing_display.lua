-- Two presentations of the same ongoing-book card. The selected title is a
-- preview; only opening it goes through KOReader's normal reading history.
local Model = require("core/orbitui_dashboard")
local _ = require("core/orbitui_i18n")
local M = {}
local floor, min, max = math.floor, math.min, math.max

local function rect(x, y, w, h)
    return { x = floor(x), y = floor(y), w = max(1, floor(w)), h = max(1, floor(h)) }
end

local function percent(book)
    return floor(Model.fraction(book.data.percent) * 100 + .5)
end

-- Bounding box and inverse mapping shared by painting and hit testing.
local function tilted(r, radians)
    local c, s = math.cos(radians), math.sin(radians)
    local w = math.ceil(math.abs(c) * r.w + math.abs(s) * r.h)
    local h = math.ceil(math.abs(s) * r.w + math.abs(c) * r.h)
    local area = rect(r.x + (r.w - w) / 2, r.y + (r.h - h) / 2, w, h)
    local function source(x, y)
        local dx, dy = x + .5 - w / 2, y + .5 - h / 2
        return floor(r.w / 2 + dx*c + dy*s), floor(r.h / 2 - dx*s + dy*c)
    end
    area.contains = function(x, y)
        local sx, sy = source(x, y)
        return sx >= 0 and sx < r.w and sy >= 0 and sy < r.h
    end
    local function wrap(image)
        local BB = require("ffi/blitbuffer")
        local view = require("ui/widget/widget"):new{ dimen = require("ui/geometry"):new{ w = w, h = h } }
        function view:paintTo(bb, x, y)
            if not self.rotated then
                -- Use a private RGBA surface even on monochrome devices. The
                -- source cover may be borrowed or a generated placeholder.
                local src = BB.new(r.w, r.h, BB.TYPE_BBRGB32)
                src:fill(BB.COLOR_WHITE)
                image:paintTo(src, 0, 0)
                local dst = BB.new(w, h, BB.TYPE_BBRGB32) -- zero alpha outside the cover
                for yy = 0, h - 1 do
                    local row = dst:getPixelP(0, yy)
                    for xx = 0, w - 1 do
                        local sx, sy = source(xx, yy)
                        if sx >= 0 and sx < r.w and sy >= 0 and sy < r.h then
                            row[xx] = src:getPixelP(sx, sy)[0]
                            row[xx].alpha = 255
                        end
                    end
                end
                src:free()
                self.rotated = dst
            end
            bb:alphablitFrom(self.rotated, x, y, 0, 0, w, h)
        end
        function view:free()
            if self.rotated then self.rotated:free(); self.rotated = nil end
            image:free()
        end
        return view
    end
    return area, wrap
end

-- A distant pivot keeps the arc shallow and leaves neighbouring jackets
-- exposed even at a small angle. Distances are in units of one cover width.
local function drawFan(art, count, index, gap, draw)
    local layers = {}
    local xmin, xmax, ymin, ymax = math.huge, -math.huge, math.huge, -math.huge
    local pivot_distance = 3.1
    local outer_angle = count >= 4 and 16 or 10
    local angle_step = outer_angle / max(1, floor(count / 2))
    for i = 1, count do
        local offset = (i - index) % count
        if offset > count / 2 then offset = offset - count end
        local angle = angle_step * offset
        local scale = 1 - .14 * math.abs(offset)
        local radians = math.rad(angle)
        local c, s = math.cos(radians), math.sin(radians)
        local x = pivot_distance * s
        -- Lower the smaller jackets slightly to keep their feet on the arc.
        local y = pivot_distance * (1 - c) + .35 * (1 - scale)
        local dx = scale * (.5 * c + .75 * math.abs(s))
        local dy = scale * (.5 * math.abs(s) + .75 * c)
        xmin, xmax, ymin, ymax = min(xmin, x - dx), max(xmax, x + dx), min(ymin, y - dy), max(ymax, y + dy)
        layers[i] = { i = i, x = x, y = y, angle = angle, scale = scale }
    end
    table.sort(layers, function(a, b)
        if math.abs(a.angle) == math.abs(b.angle) then return a.angle < b.angle end
        return math.abs(a.angle) > math.abs(b.angle)
    end)
    local w = max(1, floor(min((art.w - 2*gap) / (xmax - xmin), (art.h - 2*gap) / (ymax - ymin))))
    local cx = art.x + (art.w - (xmin + xmax) * w) / 2
    local cy = art.y + (art.h - (ymin + ymax) * w) / 2
    for _, layer in ipairs(layers) do
        local cover_w = max(1, floor(w * layer.scale))
        local cover_h = floor(1.5 * cover_w)
        draw(layer.i, rect(cx + layer.x*w - cover_w/2, cy + layer.y*w - cover_h/2, cover_w, cover_h), layer.angle)
    end
end

local function drawCompanions(v, area, books, index, title_captions, caption_size, cover, selectBook)
    local n, gap = #books - 1, v.px(7)
    local label_h = v.line(caption_size, true)
    local slot = (area.w - (n - 1) * gap) / n
    local w = floor(min(slot, (area.h - label_h - gap) / 1.5))
    if w < v.px(14) then return false end
    local h = floor(w * 1.5)
    local top = area.y + floor((area.h - h - label_h - gap) / 2)
    local j = 0
    for i, entry in ipairs(books) do
        if i ~= index then
            local x = floor(area.x + j * (slot + gap))
            cover(i, rect(x + (slot - w) / 2, top, w, h))
            local caption = title_captions and entry.data.title or (percent(entry) .. " %")
            v.text(caption, x, top + h + gap, floor(slot), caption_size, true, nil, 1, true, "center")
            v.action(rect(x, top + h, slot, gap + label_h), function() selectBook(entry.file) end,
                function(card) v.hold(entry.file, card) end)
            j = j + 1
        end
    end
    return true
end

function M.draw(v, r, data, selected, selectBook)
    local books = data.featured
    local px, text = v.px, v.text
    local gap = px(6)
    local left, right = r.x + v.pad, r.x + r.w - v.pad
    local width = right - left
    local top, bottom = r.y + v.pad, r.y + r.h - v.pad
    local header_h = v.line(15, true) + gap
    local see = text(_("See all") .. " ›", left, top, width, 13, true)
    local see_w = min(width, see:getSize().w + gap)
    see.overlap_offset[1] = right - see:getSize().w
    text(Model.heading(data.headings, "hero", _("Books in progress")),
        left, top, width - see_w - gap, 15, true)
    v.action(rect(right - see_w, r.y, see_w + v.pad, top + header_h - r.y), v.seeAll)
    v.rule(left, top + header_h, width)
    top = top + header_h + gap
    local pet = v.pet
    if pet and bottom - top >= px(125) then
        local foot_h = min(px(30), floor((bottom - top) * .14))
        local y = bottom - foot_h
        v.rule(left, y - gap, width)
        v.sprite(pet, foot_h, left, y)
        text(pet.name .. "   " .. pet.stage, left + foot_h + gap, y + max(0, floor((foot_h - v.line(13, true)) / 2)),
            width - foot_h - gap, 13, true)
        v.action(rect(left, y - gap, width, foot_h + gap), function() v.openPet(pet) end)
        bottom = y - gap * 2
    end
    if #books == 0 then
        text(_("Open a book to start reading."), left, top, width, 15, false, v.muted, 2)
        return
    end
    local index = 1
    for i, entry in ipairs(books) do if entry.file == selected then index = i; break end end
    local book = books[index]
    local function bookCover(i, area, angle)
        local bounds, wrap = area, nil
        if angle and angle ~= 0 then bounds, wrap = tilted(area, math.rad(angle)) end
        local file = books[i].file
        v.cover(file, area, bounds, wrap)
        v.action(bounds, function()
            if i == index then v.open(file) else selectBook(file) end
        end, function(card) v.hold(file, card) end)
    end
    local fan = data.config.ongoing_style == "fan"
    local n, h = #books, bottom - top
    local function swipe(area)
        if n > 1 then v.swipe(area, function(delta) selectBook(books[(index - 1 + delta) % n + 1].file) end) end
    end
    local spacious = width >= px(440) and h >= px(165)
    local title_size, author_size = spacious and 29 or 21, spacious and 18 or 14
    local progress_size, button_size = spacious and 17 or 14, spacious and 17 or 15
    local title_h, author_h = v.line(title_size, true), v.line(author_size)
    local progress_h, button_h = v.line(progress_size, true), px(spacious and 39 or 31)
    local minimum = title_h + progress_h + px(4) + button_h + 3 * gap
    if h < minimum then
        text(book.data.title, left, top, width, 17, true)
        if h >= v.line(17, true) + v.line(14) then
            text(string.format(_("%d%% read"), percent(book)), left, top + v.line(17, true), width, 14, false)
        end
        local body = rect(left, top, width, h)
        v.bookAction(body, book.file)
        swipe(body)
        return
    end

    local gutter = px(spacious and 15 or 9)
    local art, copy, companions
    local stacked = fan and h >= minimum + author_h + px(95) and h >= width * .65
    if stacked then
        local art_h = h - minimum - author_h - 2 * gap
        art = rect(left, top, width, art_h)
        copy = rect(left, top + art_h + gap, width, bottom - top - art_h - gap)
    else
        local art_w = fan and floor(width * .54) or min(floor(width * .30), floor(h / 1.5))
        art = rect(left, top, art_w, h)
        local tx = left + art_w + gutter
        copy = rect(tx, top, right - tx, h)
        if not fan and n > 1 then
            -- On wide cards give the companion covers their own area at the
            -- right edge. They no longer compete with the title for height.
            local rail_w = floor(min(width * .40, (n - 1) * h * .46 + (n - 2) * gap))
            if spacious and copy.w - rail_w - gutter >= px(172) then
                companions = rect(right - rail_w, top, rail_w, h)
                copy.w = companions.x - gutter - copy.x
            else
                local rail_h = floor(min(h * .44, h - minimum - author_h - gutter))
                if rail_h >= px(40) then
                    companions = rect(tx, bottom - rail_h, right - tx, rail_h)
                    copy.h = companions.y - gap - copy.y
                end
            end
        end
    end

    if fan then
        drawFan(art, n, index, gap, bookCover)
        swipe(art)
    else
        local w = floor(min(art.w, art.h / 1.5))
        bookCover(index, rect(art.x + (art.w - w) / 2, art.y + (art.h - w * 1.5) / 2, w, w * 1.5))
    end

    local align = stacked and "center" or "left"
    local title = book.data.title or ""
    local author = require("infra/sui_text").formatAuthors(book.data.authors)
    local progress = string.format(_("%d%% read"), percent(book))
    local eta = data.current and data.current.file == book.file and data.time_left
    local used = minimum
    if author and used + author_h <= copy.h then used = used + author_h else author = nil end
    if eta then
        local combined = progress .. "  ·  " .. eta
        if v.textWidth(combined, progress_size, true) <= copy.w then
            progress, eta = combined, nil
        elseif used + v.line(author_size) <= copy.h then
            used = used + v.line(author_size)
        else
            eta = nil
        end
    end
    local lines = 1
    if v.textWidth(title, title_size, true) > copy.w and used + title_h <= copy.h then
        lines, used = 2, used + title_h
    end
    local y = copy.y + floor((copy.h - used) / 2)
    text(title, copy.x, y, copy.w, title_size, true, nil, lines, true, align)
    y = y + lines * title_h
    if author then
        text(author, copy.x, y, copy.w, author_size, false, v.muted, 1, true, align)
        y = y + author_h
    end
    y = y + gap
    text(progress, copy.x, y, copy.w, progress_size, true, nil, 1, true, align)
    y = y + progress_h
    if eta then
        text(eta, copy.x, y, copy.w, author_size, false, v.muted, 1, true, align)
        y = y + v.line(author_size)
    end
    local track_w = min(copy.w, px(stacked and 175 or 285))
    v.bar(copy.x + (stacked and floor((copy.w - track_w) / 2) or 0), y, track_w, book.data.percent, false, "hero")
    y = y + px(4) + 2 * gap
    local bw = min(copy.w, px(spacious and 155 or 120))
    local button = rect(copy.x + (stacked and floor((copy.w - bw) / 2) or 0), y, bw, button_h)
    v.button(button, button_size)
    v.bookAction(button, book.file)

    if not fan and n > 1 then
        if not companions or not drawCompanions(v, companions, books, index, data.config.cover_row_caption == "title",
                spacious and 16 or 12, bookCover, selectBook) then swipe(art) end
    end
end

return M
