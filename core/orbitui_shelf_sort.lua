-- Bookcase-only ordering. Compare whole series/folder blocks before pagination,
-- using native keys so article handling, author names and natural order agree.
local M = {}
local alphabetical = {
    title = true, author_surname = true, author_name = true,
    series_name = true, series_combined = true, series_or_title = true,
}
local series_keys = { series_name = true, series_combined = true, series_or_title = true }

local function text(value)
    if type(value) ~= "string" then return nil end
    value = value:match("^%s*(.-)%s*$")
    return value ~= "" and value or nil
end

local function series(book)
    return text(book.series_name) or text(book.series)
end

local function title(book)
    return text(book.title) or (book.doc_props and text(book.doc_props.display_title))
        or text(book.filename) or text(book.name)
        or (book.filepath and book.filepath:match("([^/]+)$"))
end

function M.enabled(priority)
    return not not (priority and priority[1] and alphabetical[priority[1].key])
end

local function blockPriority(priority)
    local out = {}
    for _, level in ipairs(priority) do
        out[#out + 1] = { key = series_keys[level.key] and "title" or level.key,
            reverse = level.reverse }
    end
    return out
end

local function copyRecord(record)
    local out = {}
    for k, v in pairs(record) do
        -- A proxy has a different title/author identity: never reuse the
        -- native memoized sort keys from its representative volume.
        if type(k) ~= "string" or k:sub(1, 1) ~= "_" then out[k] = v end
    end
    return out
end

local function volumeComparator(engine)
    return engine.chainedComparator({ { key = "series_index" }, { key = "filename" } })
end

local function proxy(members, name, identity, grouped)
    local first = members[1] or {}
    local p = copyRecord(first)
    p.title = name or title(first)
    if name then p.title_sort = nil end
    p.filename = identity or p.filename
    p.series_name, p.series, p.series_num, p.series_index = nil, nil, nil, nil
    if grouped then
        p.author, p.authors, p.author_sort = nil, nil, nil
        p.author_surname, p.author_name = nil, nil
        p.books, p.books_meta = nil, members
    end
    return p
end

local function sortBlocks(blocks, priority, engine)
    local cmp = engine.chainedComparator(blockPriority(priority))
    table.sort(blocks, function(a, b)
        if cmp(a.key, b.key) then return true end
        if cmp(b.key, a.key) then return false end
        return a.index < b.index
    end)
end

function M.folderEntries(entries, priority)
    if not M.enabled(priority) then return entries end
    local engine = require("lib/bookshelf_sort_engine")
    local blocks, folders, loose_series = {}, {}, {}
    for _, entry in ipairs(entries) do
        local section, name = entry.section, series(entry.rec)
        local block
        if section.label then
            block = folders[section]
        elseif name then
            local by_name = loose_series[section]
            block = by_name and by_name[name]
        end
        if not block then
            block = { entries = {}, index = #blocks + 1 }
            blocks[#blocks + 1] = block
            if section.label then
                folders[section] = block
            elseif name then
                loose_series[section] = loose_series[section] or {}
                loose_series[section][name] = block
            end
        end
        block.entries[#block.entries + 1] = entry
    end
    local volume_cmp = volumeComparator(engine)
    for _, block in ipairs(blocks) do
        local items = block.entries
        table.sort(items, function(a, b) return volume_cmp(a.rec, b.rec) end)
        local members, common, conflicting = {}, nil, false
        for i, entry in ipairs(items) do
            members[i] = entry.rec
            local name = series(entry.rec)
            if name then
                if common and common ~= name then conflicting = true end
                common = common or name
            end
        end
        local section = items[1].section
        local name = not conflicting and common or nil
        -- A folder without usable series metadata keeps its existing block;
        -- its first volume supplies the title, not the arbitrary folder name.
        block.key = proxy(members, name,
            section.label and section.path or members[1].filepath,
            section.label ~= nil or #members > 1)
        block.key.title = block.key.title or section.label
    end
    sortBlocks(blocks, priority, engine)
    local out = {}
    for _, block in ipairs(blocks) do
        for _, entry in ipairs(block.entries) do
            out[#out + 1] = { rec = entry.rec, section = entry.section, sort_record = block.key }
        end
    end
    return out
end

-- Series-source shapes are sorted before their visible window is hydrated.
-- Return separate keys rather than mutating the shared cached shapes.
function M.seriesShapes(shapes, priority)
    if not M.enabled(priority) then return nil end
    local engine = require("lib/bookshelf_sort_engine")
    local blocks, keys = {}, {}
    local volume_cmp = volumeComparator(engine)
    for i, shape in ipairs(shapes) do
        local members = {}
        for j, book in ipairs(shape.books_meta or shape.books or {}) do members[j] = book end
        table.sort(members, volume_cmp)
        local key
        if shape.standalone then
            key = proxy({ shape }, series(shape), shape.filepath, false)
        else
            key = proxy(members, series(shape), shape.series_name, true)
        end
        -- Preserve native group statistics for explicit secondary priorities.
        for _, field in ipairs({ "latest", "latest_added", "avg_rating", "total_pages", "book_count" }) do
            key[field] = shape[field]
        end
        key.filepaths = shape.filepaths
        blocks[i] = { key = key, shape = shape, index = i }
        keys[shape] = key
    end
    sortBlocks(blocks, priority, engine)
    for i, block in ipairs(blocks) do shapes[i] = block.shape end
    return keys
end

function M.sortKeyValue(native, item, key)
    local record = item and item._orbitui_shelf_sort
    if record then return native(record, series_keys[key] and "title" or key) end
    return native(item, key)
end

-- Navigation only: never sort, fold Å/Ä/Ö into A/O, or hydrate a book here.
function M.alphabetLetters(reverse)
    local letters = { "#" }
    for byte = 65, 90 do letters[#letters + 1] = string.char(byte) end
    for _, letter in ipairs{ "Å", "Ä", "Ö" } do letters[#letters + 1] = letter end
    if reverse then
        local out = {}; for i = #letters, 1, -1 do out[#out + 1] = letters[i] end
        return out
    end
    return letters
end
local letter_folds = {}
for letter, variants in pairs{ A = "àáâãÀÁÂÃæÆ", E = "èéêëÈÉÊË", I = "ìíîïÌÍÎÏ",
        O = "òóôõøÒÓÔÕØœŒ", U = "ùúûüÙÚÛÜ", Y = "ýÿÝŸ", C = "çÇ", N = "ñÑ", S = "ß" } do
    for char in variants:gmatch("[\194-\244][\128-\191]*") do letter_folds[char] = letter end
end
function M.alphabetBucket(value)
    if type(value) ~= "string" then return "#" end
    local char = value:match("^%s*([%z\1-\127\194-\244][\128-\191]*)")
    if char == "å" or char == "Å" then return "Å" end
    if char == "ä" or char == "Ä" then return "Ä" end
    if char == "ö" or char == "Ö" then return "Ö" end
    if char and char:match("^[A-Za-z]$") then return char:upper() end
    return letter_folds[char] or "#"
end
function M.alphabetAt(y, rect, letters)
    if not tonumber(y) or not rect or not rect.h or rect.h <= 0 or #letters == 0 then return end
    local index = math.max(1, math.min(#letters, math.floor((y - rect.y) * #letters / rect.h) + 1))
    return letters[index]
end
function M.alphabetTarget(items, key, letter, sort_key)
    for i, item in ipairs(items) do
        if not item.shelf_module and not item.shelf_slot and not item.blank
                and M.alphabetBucket(sort_key(item._series_sort_book or item, key)) == letter then return i end
    end
end

return M
