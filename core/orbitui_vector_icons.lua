-- SVG-only sources. Load only the requested catalogue, never fonts or settings.
local M = {}
local root = assert(debug.getinfo(1, "S").source:match("^@(.+)/core/orbitui_vector_icons%.lua$"))
local catalogues, by_name = {}, {}
M.sources = {
    { key = "solar-outline", label = "Solar Outline", module = "core/orbitui_solar_outline_catalogue" },
    { key = "solar-duotone", label = "Solar Duotone", title = "Solar Line Duotone", module = "core/orbitui_solar_duotone_catalogue" },
    { key = "tabler", label = "Tabler", module = "core/orbitui_tabler_catalogue" },
}

function M.source(key)
    for _, source in ipairs(M.sources) do
        if source.key == key then return source end
    end
end

function M.catalogue(key)
    local source = assert(M.source(key), "Unknown vector icon source")
    if catalogues[key] then return catalogues[key] end
    local cells, names = {}, {}
    for _, entry in ipairs(require(source.module)) do
        local image_name = "orbitui-" .. key .. "-" .. entry.name
        local cell = {
            name = entry.name, label = entry.label, group = entry.group, source = key,
            canonical = entry.name,
            search_lc = (entry.label .. " " .. entry.name:gsub("-", " ") .. " " .. entry.aliases
                .. " " .. source.label .. " " .. key):lower(),
            is_image = true, icon = image_name, image_name = image_name,
            value = key .. ":" .. entry.name,
            insert_value = "[icon=" .. image_name .. "]",
            file = root .. "/assets/vector-icons/" .. key .. "/" .. entry.name .. ".svg",
        }
        cells[#cells + 1], names[entry.name] = cell, cell
    end
    catalogues[key], by_name[key] = cells, names
    return cells
end

function M.entry(value)
    if type(value) ~= "string" then return nil end
    value = value:match("^%[icon=(orbitui%-[^%]]+)%]$") or value
    for _, source in ipairs(M.sources) do
        local key = source.key:gsub("%-", "%%-")
        local name = value:match("^" .. key .. ":([a-z0-9%-]+)$")
            or value:match("^orbitui%-" .. key .. "%-([a-z0-9%-]+)$")
            or value:match("/assets/vector%-icons/" .. key .. "/([a-z0-9%-]+)%.svg$")
        if name then
            M.catalogue(source.key)
            return by_name[source.key][name]
        end
    end
end

function M.filtered(key, group, query)
    local out, terms = {}, {}
    for term in (query or ""):lower():gmatch("%S+") do terms[#terms + 1] = term end
    for _, cell in ipairs(M.catalogue(key)) do
        local match = not group or group == "all" or cell.group == group
        for _, term in ipairs(terms) do
            if not cell.search_lc:find(term, 1, true) then match = false; break end
        end
        if match then out[#out + 1] = cell end
    end
    return out
end

return M
