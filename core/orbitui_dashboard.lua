-- Geometry and layout edits are independent of KOReader's widget/cache owners.
local M = { id = "orbitui_dashboard" }

-- OrbitUI's own card palette; no BookOrbit code, palettes or assets imported.
-- Stable card IDs keep colours attached to content when cards are reordered.
local CARD_INK = {
    hero = "#406B91", pages_today = "#3579A6", reading_today = "#287D78",
    streak = "#B56E19", week = "#3E865D", ongoing = "#5867AE",
    goal = "#B44770", want = "#9A713F", new = "#237D83",
}

function M.colourMode(value)
    return (value == "accents" or value == "tinted") and value or "off"
end

local function rgb(hex)
    if type(hex) ~= "string" then return end
    local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
    if r then return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) end
end

local function mix(hex, target, amount)
    local r, g, b = rgb(hex)
    local function channel(c) return math.floor(c + (target - c) * amount + 0.5) end
    return string.format("#%02X%02X%02X", channel(r), channel(g), channel(b))
end

-- Logical on-screen colours. The view uses SimpleUI's existing night-aware
-- conversion, while ordinary black/white text retains native inversion.
function M.cardColours(key, mode, night, cover_hex)
    if M.colourMode(mode) == "off" then return nil end
    local base = key == "hero" and rgb(cover_hex) and cover_hex or CARD_INK[key] or CARD_INK.hero
    return {
        accent = night and mix(base, 255, 0.38) or base,
        border = mix(base, 255, night and 0.18 or 0.48),
        fill = mode == "tinted" and mix(base, night and 0 or 255, night and 0.78 or 0.86) or nil,
        deep = key == "hero" and rgb(cover_hex)
            and mix(cover_hex, night and 255 or 0, night and 0.76 or 0.64) or nil,
    }
end

-- At most 64 reads from an already-cached bitmap. Quantised RGB buckets favour
-- a saturated region over white lettering/background; no image decode or I/O.
function M.coverColour(width, height, pixel)
    if width < 1 or height < 1 then return nil end
    local buckets, best, score = {}, nil, 0
    for row = 0, 7 do
        for col = 0, 7 do
            local r, g, b, alpha = pixel(math.min(width - 1, math.floor((col + 0.5) * width / 8)),
                math.min(height - 1, math.floor((row + 0.5) * height / 8)))
            if r and g and b and (alpha or 255) >= 128 then
                local bright, low = math.max(r, g, b), math.min(r, g, b)
                local chroma = bright - low
                if chroma >= 40 and bright >= 55 and low <= 215 then
                    local key = math.floor(r / 64) + 4 * math.floor(g / 64) + 16 * math.floor(b / 64)
                    local bucket = buckets[key] or { weight = 0, r = 0, g = 0, b = 0 }
                    buckets[key] = bucket
                    bucket.weight = bucket.weight + chroma
                    bucket.r, bucket.g, bucket.b = bucket.r + r * chroma, bucket.g + g * chroma, bucket.b + b * chroma
                    if bucket.weight > score then best, score = bucket, bucket.weight end
                end
            end
        end
    end
    if not best then return nil end
    return string.format("#%02X%02X%02X", math.floor(best.r / best.weight + 0.5),
        math.floor(best.g / best.weight + 0.5), math.floor(best.b / best.weight + 0.5))
end

M.heading_cards = {
    { key = "hero", label = "Continue reading" },
    { key = "pages_today", label = "Pages today" },
    { key = "reading_today", label = "Reading today" },
    { key = "streak", label = "Reading streak" },
    { key = "week", label = "This week" },
    { key = "ongoing", label = "Also reading" },
    { key = "goal", label = "Reading goal" },
    { key = "want", label = "BookOrbit Want to Read" },
    { key = "new", label = "Recently added" },
}

function M.normalizeHeading(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("%s+", " "):match("^%s*(.-)%s*$")
    return value ~= "" and value or nil
end

function M.heading(headings, key, fallback)
    return M.normalizeHeading(type(headings) == "table" and headings[key]) or fallback
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end

M.block_order = { "hero", "stats", "ongoing", "goal", "want", "new" }
M.stat_order = { "pages_today", "reading_today", "streak", "week" }

local function ordered(value, defaults)
    local result, allowed = {}, {}
    for _, id in ipairs(defaults) do allowed[id] = true end
    for _, id in ipairs(type(value) == "table" and value or {}) do
        if allowed[id] then result[#result + 1], allowed[id] = id, nil end
    end
    for _, id in ipairs(defaults) do
        if allowed[id] then result[#result + 1] = id end
    end
    return result
end

function M.config(raw, legacy)
    local result = { version = 1, order = copy(M.block_order), stats_order = copy(M.stat_order),
        hidden = {}, sources = {
            want = legacy and { kind = "bookorbit" } or { kind = "native", id = "tbr" },
            new = { kind = "native", id = "new_books" },
        }, goal = "auto" }
    if raw == nil then return result end
    if type(raw) ~= "table" or raw.version ~= 1 then
        -- A downgrade must not silently replace a newer configuration.
        result.unsupported = true
        for _, card in ipairs(M.heading_cards) do result.hidden[card.key] = true end
        return result
    end
    result.order = ordered(raw.order, M.block_order)
    result.stats_order = ordered(raw.stats_order, M.stat_order)
    for _, card in ipairs(M.heading_cards) do
        result.hidden[card.key] = type(raw.hidden) == "table" and raw.hidden[card.key] == true or nil
    end
    for _, key in ipairs({ "want", "new" }) do
        if type(raw.sources) == "table" and raw.sources[key] ~= nil then
            result.sources[key] = type(raw.sources[key]) == "table" and copy(raw.sources[key])
                or { kind = "unavailable" }
        end
    end
    if raw.goal == "local" or raw.goal == "hardcover" then result.goal = raw.goal end
    return result
end

function M.visible(config, key)
    return not config or not config.hidden[key]
end

function M.sourceKey(source)
    if source.kind == "shelf" then
        local ref = source.ref or {}
        return "shelf:" .. tostring(ref.profile) .. ":" .. tostring(ref.chip)
    end
    return tostring(source.kind) .. ":" .. tostring(source.id) .. ":" .. tostring(source.coll)
end

local function entryId(entry)
    return type(entry) == "table" and entry.id or entry
end

function M.contains(layout)
    for _, page in ipairs(layout.pages or {}) do
        for _, entry in ipairs(page.modules or {}) do
            if entryId(entry) == M.id then return true end
        end
    end
    return false
end

function M.withPage(layout, enabled)
    local result = copy(layout)
    result.pages = result.pages or {}
    if enabled then
        if M.contains(result) then return result end
        local max_id = 0
        for _, page in ipairs(result.pages) do
            max_id = math.max(max_id, tonumber(page.id) or 0)
        end
        table.insert(result.pages, 1, {
            id = max_id + 1, modules = { M.id }, orbitui_dashboard_page = true,
        })
    else
        for pi = #result.pages, 1, -1 do
            local page = result.pages[pi]
            for i = #(page.modules or {}), 1, -1 do
                if entryId(page.modules[i]) == M.id then table.remove(page.modules, i) end
            end
            if page.orbitui_dashboard_page and #page.modules == 0 then
                table.remove(result.pages, pi)
            end
        end
        if #result.pages == 0 then result.pages[1] = { id = 1, modules = {} } end
    end
    return result
end

function M.plan(w, h, config)
    w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
    local scale = math.min(w / 600, h / 730)
    local gap = math.max(2, math.floor(10 * scale))
    local pad = math.max(3, math.floor(12 * scale))
    local header = math.max(1, math.floor(52 * scale))
    local body_h = math.max(3, h - header - 3 * gap)
    local top_h = math.floor(body_h * 0.38)
    local mid_h = math.floor(body_h * 0.27)
    local bottom_h = body_h - top_h - mid_h
    local col = math.floor((w - gap) / 2)
    local right_w = w - col - gap
    local top_y, mid_y = header + gap, header + 2 * gap + top_h
    local bottom_y = mid_y + mid_h + gap
    local small_w = math.floor((right_w - gap) / 2)
    local small_h = math.floor((top_h - gap) / 2)
    local function rect(x, y, rw, rh) return { x = x, y = y, w = rw, h = rh } end
    local plan = {
        w = w, h = h, scale = scale, gap = gap, pad = pad, header_h = header,
        hero = rect(0, top_y, col, top_h),
        stats = {
            rect(col + gap, top_y, small_w, small_h),
            rect(col + 2 * gap + small_w, top_y, right_w - gap - small_w, small_h),
            rect(col + gap, top_y + small_h + gap, small_w, top_h - small_h - gap),
            rect(col + 2 * gap + small_w, top_y + small_h + gap,
                right_w - gap - small_w, top_h - small_h - gap),
        },
        ongoing = rect(0, mid_y, col, mid_h),
        goal = rect(col + gap, mid_y, right_w, mid_h),
        want = rect(0, bottom_y, col, bottom_h),
        new = rect(col + gap, bottom_y, right_w, bottom_h),
    }
    if not config then return plan end
    local blocks, stats = {}, {}
    for _, id in ipairs(config.stats_order) do
        if M.visible(config, id) then stats[#stats + 1] = id end
    end
    local weight = { hero = 38, stats = #stats <= 2 and 19 or 38,
        ongoing = 27, goal = 27, want = 35, new = 35 }
    for _, id in ipairs(config.order) do
        if id == "stats" and #stats > 0 or id ~= "stats" and M.visible(config, id) then
            blocks[#blocks + 1] = id
        end
    end
    for _, id in ipairs(M.block_order) do plan[id] = nil end
    plan.stats, plan.cards = {}, {}
    if #blocks == 0 then return plan end
    local rows, total = {}, 0
    for i = 1, #blocks, 2 do
        local a, b = blocks[i], blocks[i + 1]
        local size = math.max(weight[a], b and weight[b] or 0)
        rows[#rows + 1] = { a, b, weight = size }
        total = total + size
    end
    local available = h - header - #rows * gap
    local y = header + gap
    for index, row in ipairs(rows) do
        local rh = index == #rows and h - y or math.floor(available * row.weight / total)
        for side, id in ipairs(row) do
            local r = rect(side == 1 and 0 or col + gap, y, row[2] and (side == 1 and col or right_w) or w, rh)
            if id == "stats" then
                local sh = #stats <= 2 and rh or math.floor((rh - gap) / 2)
                for si, key in ipairs(stats) do
                    local left = si % 2 == 1
                    local sw = math.floor((r.w - gap) / 2)
                    local single = si == #stats and left
                    local sr = rect(r.x + (left and 0 or sw + gap), y + (si > 2 and sh + gap or 0),
                        single and r.w or (left and sw or r.w - sw - gap),
                        si > 2 and rh - sh - gap or sh)
                    plan.cards[key] = sr
                    for oi, original in ipairs(M.stat_order) do
                        if key == original then plan.stats[oi] = sr end
                    end
                end
            else plan[id], plan.cards[id] = r, r end
        end
        -- Reordered tall cards must not inherit a short row's font geometry.
        plan.scale = math.min(plan.scale, rh / (row.weight * 6))
        y = y + rh + gap
    end
    plan.pad = math.max(3, math.floor(12 * plan.scale))
    return plan
end

function M.fraction(value)
    local n = tonumber(value) or 0
    if n ~= n then return 0 end
    return math.max(0, math.min(1, n))
end

function M.ongoing(current, paths, read, limit)
    local result, seen = {}, { [current or ""] = true }
    for _, fp in ipairs(paths or {}) do
        if type(fp) == "string" and not seen[fp] then
            seen[fp] = true
            local data = read(fp)
            local pct = M.fraction(data.percent)
            if pct > 0 and pct < 1 and data.status ~= "complete" and data.status ~= "abandoned" then
                result[#result + 1] = { file = fp, data = data }
                if #result >= limit then break end
            end
        end
    end
    return result
end

function M.duration(seconds)
    local minutes = math.max(0, math.floor((tonumber(seconds) or 0) / 60))
    if minutes < 60 then return tostring(minutes) .. "m" end
    return string.format("%dh %02dm", math.floor(minutes / 60), minutes % 60)
end

function M.greeting(hour)
    if hour < 5 or hour >= 18 then return "Good evening" end
    if hour < 12 then return "Good morning" end
    return "Good afternoon"
end

return M
