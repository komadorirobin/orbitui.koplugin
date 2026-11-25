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
    local h = bottom - top
    if h < px(75) then
        text(book.data.title, left, top, width, 17, true, nil, 1, true)
        v.bookAction(rect(left, top, width, max(1, h)), book.file)
        return
    end
    local copy_x, copy_y, copy_w = left, top, width
    local title_size = fan and 21 or 23
    local title_h = v.line(title_size, true)
    local author_h, progress_h, button_h = v.line(14), v.line(14, true), max(px(31), v.line(15, true) + gap)
    local copy_h = title_h + author_h + progress_h + button_h + px(4) + gap * 4
    if h < title_h + progress_h + button_h + gap * 3 + px(4) then
        text(book.data.title, left, top, width, 17, true)
        text(string.format(_("%d%% read"), percent(book)), left, top + v.line(17, true), width, 14, false)
        v.bookAction(rect(left, top, width, h), book.file)
        if #books > 1 then v.swipe(rect(left, top, width, h), function(delta)
            selectBook(books[(index - 1 + delta) % #books + 1].file)
        end) end
        return
    end
    -- Shallow cards (notably landscape) put text alongside the fan.
    local stacked = fan and h >= copy_h + px(76) and h >= width * .55
    local art
    if stacked then
        art = rect(left, top, width, h - copy_h - gap)
        copy_y = art.y + art.h + gap
    else
        local art_w = floor(width * (fan and .54 or .32))
        art = rect(left, top, art_w, h)
        copy_x, copy_w = left + art_w + gap * 2, width - art_w - gap * 2
    end
    local n = #books
    if fan then
        local layers, leftmost, rightmost = {}, 0, 0
        for i = 1, n do
            local offset = (i - index) % n
            if offset > n / 2 then offset = offset - n end
            local spread = n <= 3 and .78 or .58
            local shift = offset * spread
            -- With four books the lone jacket on one side can show more art.
            if n == 4 and offset < 0 then shift = -.90 end
            layers[#layers + 1] = { index = i, offset = offset, shift = shift }
            leftmost, rightmost = min(leftmost, shift), max(rightmost, shift)
        end
        table.sort(layers, function(a, b) return math.abs(a.offset) > math.abs(b.offset) end)
        local cw = max(1, floor(min(art.h / 1.64, art.w / (1.25 + rightmost - leftmost))))
        local cy = art.y + art.h / 2
        local cx = art.x + art.w / 2 - (leftmost + rightmost) * cw / 2
        for _, layer in ipairs(layers) do
            local offset = layer.offset
            local w = max(1, floor(cw * (1 - .06 * math.abs(offset))))
            local x = cx + layer.shift * cw - w / 2
            bookCover(layer.index, rect(x, cy - .75*w + cw * .025 * math.abs(offset), w, 1.5*w), offset * 7)
        end
        if n > 1 then v.swipe(art, function(delta) selectBook(books[(index - 1 + delta) % n + 1].file) end) end
    else
        local cw = max(1, floor(min(art.h / 1.5, art.w)))
        bookCover(index, rect(art.x + (art.w - cw) / 2, top + (h - cw * 1.5) / 2, cw, cw * 1.5))
    end
    local thumb_h = not fan and n > 1 and max(0, min(px(63), h - copy_h - v.line(12, true) - gap * 2)) or 0
    local thumbs = thumb_h >= px(14)
    local group_h = copy_h + (thumbs and thumb_h + v.line(12, true) + gap * 2 or 0)
    if not stacked then copy_y = top + max(0, floor((h - group_h) / 2)) end
    local align = stacked and "center" or "left"
    local function label(value, size, bold, color)
        text(value, copy_x, copy_y, copy_w, size, bold, color, 1, true, align)
        copy_y = copy_y + v.line(size, bold)
    end
    label(book.data.title, title_size, true)
    local author = require("infra/sui_text").formatAuthors(book.data.authors)
    if author and copy_y + author_h + progress_h + button_h + gap * 2 <= bottom then label(author, 14, false, v.muted) end
    copy_y = copy_y + gap
    local progress = string.format(_("%d%% read"), percent(book))
    if data.current and data.current.file == book.file and data.time_left then progress = progress .. "  ·  " .. data.time_left end
    label(progress, 14, true)
    local track_w = min(copy_w, px(stacked and 148 or 230))
    v.bar(copy_x + (stacked and floor((copy_w - track_w) / 2) or 0), copy_y, track_w, book.data.percent, false, "hero")
    copy_y = copy_y + px(4) + gap
    local bw = min(copy_w, px(120))
    local button = rect(copy_x + (stacked and floor((copy_w - bw) / 2) or 0), copy_y, bw, button_h)
    v.button(button)
    v.bookAction(button, book.file)
    if thumbs then
        local tw = min(floor(thumb_h / 1.5), floor((copy_w - (n - 2) * gap) / (n - 1)))
        local tx, ty = copy_x, button.y + button.h + gap * 2
        for i, entry in ipairs(books) do
            if i ~= index and tw >= 1 then
                local area = rect(tx, ty, tw, tw * 1.5)
                local caption = data.config.cover_row_caption == "title" and entry.data.title or (percent(entry) .. " %")
                bookCover(i, area)
                text(caption, tx, ty + area.h, tw, 12, true, nil, 1, true, "center")
                v.action(rect(tx, ty + area.h, tw, v.line(12, true)), function() selectBook(entry.file) end,
                    function(card) v.hold(entry.file, card) end)
                tx = tx + tw + gap
            end
        end
    elseif not fan and n > 1 then
        -- A very short card still lets the reader select every book.
        v.swipe(art, function(delta) selectBook(books[(index - 1 + delta) % n + 1].file) end)
    end
end

return M
