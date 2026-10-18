-- Geometry and layout edits are independent of KOReader's widget/cache owners.
local M = { id = "orbitui_dashboard" }

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
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

function M.plan(w, h)
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
    return {
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
