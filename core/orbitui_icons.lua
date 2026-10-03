-- Material names resolve to SVGs, not a text font inside native buttons.
-- Legacy names and OTA-slot image paths remain readable without rewriting settings.
local M = {}
local VectorIcons = require("core/orbitui_vector_icons")
local root = assert(debug.getinfo(1, "S").source:match("^@(.+)/core/orbitui_icons%.lua$"))
local base = root .. "/assets/material-symbols/"
local catalogues, by_name = {}, {}
local valid_weights = { [200] = true, [300] = true, [400] = true, [500] = true }

M.legacy_pack_id = "orbitui:material-symbols-rounded"
M.default_weight = 300
M.weights = { 200, 300, 400, 500 }

function M.catalogue(weight)
    weight = weight or M.default_weight
    assert(valid_weights[weight], "Unsupported Material weight")
    if catalogues[weight] then return catalogues[weight] end
    local cells, names = {}, {}
    for _, entry in ipairs(require("core/orbitui_material_catalogue")) do
        local image_name = "orbitui-material-" .. entry.name .. "-w" .. weight
        local cell = {
            name = entry.name, code = entry.code, group = entry.group, weight = weight,
            label = entry.name:gsub("_", " "), canonical = entry.name,
            search_lc = (entry.name:gsub("_", " ") .. " " .. entry.name .. " " .. entry.aliases):lower(),
            is_image = true, icon = image_name, image_name = image_name,
            value = "material:" .. entry.name .. ":" .. weight,
            insert_value = "[icon=" .. image_name .. "]",
            file = base .. "icons/" .. weight .. "/" .. entry.name .. ".svg",
        }
        cells[#cells + 1] = cell
        names[entry.name] = cell
    end
    catalogues[weight], by_name[weight] = cells, names
    return cells
end

function M.entry(value)
    if type(value) ~= "string" then return nil end
    value = value:match("^%[icon=(orbitui%-material%-[^%]]+)%]$") or value
    local name, weight = value:match("^material:([a-z0-9_]+):(%d%d%d)$")
    if not name then
        name, weight = value:match("^orbitui%-material%-([a-z0-9_]+)%-w(%d%d%d)$")
    end
    if not name then
        weight, name = value:match("/assets/material%-symbols/icons/(%d%d%d)/([a-z0-9_]+)%.svg$")
    end
    if not name then
        name = value:match("^material:([a-z0-9_]+)$")
            or value:match("^orbitui%-material%-([a-z0-9_]+)$")
            or value:match("/assets/material%-symbols/icons/([a-z0-9_]+)%.svg$")
    end
    if not name then return nil end
    -- Unweighted selections follow the requested new default; explicit choices stay fixed.
    weight = weight and tonumber(weight) or M.default_weight
    if not valid_weights[weight] then return nil end
    M.catalogue(weight)
    return by_name[weight][name]
end

function M.forWeight(value, weight)
    local entry = M.entry(value)
    if not entry or not valid_weights[weight] then return nil end
    M.catalogue(weight)
    return by_name[weight][entry.name]
end

function M.imageFile(value)
    local entry = M.entry(value) or VectorIcons.entry(value)
    if entry then return entry.file end
end

-- Image-only SimpleUI slots may store a validated absolute SVG path. Rebase
-- only our exact asset suffix, including old OTA slots, never arbitrary files.
function M.rebaseImage(path)
    if type(path) ~= "string" or not (path:find("/assets/material-symbols/icons/", 1, true)
        or path:find("/assets/vector-icons/", 1, true)) then return nil end
    return M.imageFile(path)
end

function M.filtered(group, query, weight)
    local out, terms = {}, {}
    for term in (query or ""):lower():gmatch("%S+") do terms[#terms + 1] = term end
    for _, cell in ipairs(M.catalogue(weight)) do
        local match = not group or group == "all" or cell.group == group
        for _, term in ipairs(terms) do
            if not cell.search_lc:find(term, 1, true) then match = false; break end
        end
        if match then out[#out + 1] = cell end
    end
    return out
end

function M.bookshelfCells(weight)
    return M.catalogue(weight)
end

return M
