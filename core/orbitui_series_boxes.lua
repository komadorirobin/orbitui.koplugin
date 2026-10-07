-- View-only series grouping. Keep original members for drill, bulk actions and
-- metadata; only the physical bookshelf's display list is compacted.
local M = {}

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do if k ~= "cover_bb" then out[k] = v end end
    return out
end
M.copy = copy

local function name(book)
    local value = book and (book.series_name or book.series)
    return type(value) == "string" and value:match("%S") and value or nil
end

function M.isBox(item)
    return type(item) == "table" and item._orbitui_series_box == true
end

function M.box(books, title, original)
    local members, seen = {}, {}
    for _, book in ipairs(books) do
        if book.filepath and not seen[book.filepath] then
            members[#members+1], seen[book.filepath] = copy(book), true
        end
    end
    if #members == 0 then return original end
    local cmp = require("lib/bookshelf_sort_engine").chainedComparator{
        {key="series_index"}, {key="filename"},
    }
    table.sort(members, cmp)
    local box = copy(original)
    box.filepath, box.path, box.shelf_section, box.shelf_section_path = nil, nil, nil, nil
    box.kind, box.series_name, box.label, box.name = "series", title, title, title
    box.title, box.display_title = title, title
    box.books, box.first_book, box.book_count = members, members[1], #members
    box.author, box.authors = members[1].author, members[1].authors
    box._orbitui_series_box = true
    box._orbitui_display_books = nil
    box._orbitui_shelf_sort = original and original._orbitui_shelf_sort
    -- A box has no reading status of its own, nor a borrowed cover buffer.
    box.status, box._status, box.percent_finished, box.series_num = nil, nil, nil, nil
    return box
end

function M.prepare(items)
    local out, groups = {}, {}
    for _, item in ipairs(items or {}) do
        if M.isBox(item) then
            out[#out+1] = item
        elseif item.books then
            if name(item) and (not item.kind or item.kind == "series") then
                out[#out+1] = M.box(item.books, name(item), item)
            else
                local group = copy(item)
                group._orbitui_display_books = M.prepare(item.books)
                out[#out+1] = group
            end
        elseif item.filepath and name(item) and not item.is_remote then
            -- Distinct physical sections may contain different editions of
            -- a series: do not silently merge those collections together.
            local key = (item.shelf_section_path or "") .. "\0" .. name(item)
            local g = groups[key]
            if not g then
                g = {books={}, title=name(item), original=item, at=#out+1}
                groups[key] = g
                out[g.at] = g
            end
            g.books[#g.books+1] = item
        else
            out[#out+1] = item
        end
    end
    for _, g in pairs(groups) do out[g.at] = M.box(g.books, g.title, g.original) end
    return out
end

function M.flatten(native, items)
    local input, originals = {}, {}
    for i, item in ipairs(items) do
        if M.isBox(item) or item._orbitui_display_books then
            local proxy = copy(item)
            proxy.books = not M.isBox(item) and item._orbitui_display_books or nil
            input[i], originals[proxy] = proxy, item
        else input[i] = item end
    end
    local flat = native(input)
    for _, entry in ipairs(flat) do
        entry.item = originals[entry.item] or entry.item
        entry.book = originals[entry.book] or entry.book
        if M.isBox(entry.book) then entry.section_label = nil end
    end
    return flat
end

function M.displayCount(item)
    if M.isBox(item) then return 1 end
    local books = item._orbitui_display_books or item.books
    return books and #books > 0 and #books or 1
end

function M.geometry(book, base, opts)
    if not M.isBox(book) then return nil end
    local count = math.max(1, #book.books)
    local ratio = math.min(.45, .20 + .05 * (count - 1))
    local cover_w = base.w
    local side = math.max(1, math.floor(cover_w * ratio + .5))
    local max_w = math.max(2, (opts.content_w or (cover_w + side))
        - 2 * (opts.end_margin or 0))
    if cover_w + side > max_w then
        cover_w = math.max(1, math.floor(max_w / (1 + ratio)))
        side = math.max(1, math.min(max_w-cover_w, math.floor(cover_w*ratio+.5)))
    end
    local scale = cover_w / base.w
    local face_h = math.max(1, math.floor((base.face_h or base.h) * scale))
    return {w=cover_w+side, cover_w=cover_w, side=side, count=count,
        face_h=face_h, depth=base.depth, h=face_h+base.depth}
end

-- A bounded set of illustrative bindings, not miniature cover bitmaps. Reduce
-- their number on tiny faces rather than drawing subpixel stripes.
function M.spineSlots(shape, stroke)
    local slots = {}
    local gap = math.max(1, stroke)
    local room = shape.side - 2 * stroke
    local count = math.min(6, shape.count, math.floor((room + gap) / (3 + gap)))
    if count < 1 then return slots end
    local usable = room - (count - 1) * gap
    for i = 1, count do
        local start = math.floor((i - 1) * usable / count)
        local finish = math.floor(i * usable / count)
        slots[i] = { x = stroke + start + (i - 1) * gap, w = finish - start, member = i }
    end
    return slots
end

return M
