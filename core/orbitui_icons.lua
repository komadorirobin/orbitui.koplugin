-- Material names resolve to SVGs, not a text font inside native buttons.
-- Legacy names and OTA-slot image paths remain readable without rewriting settings.
local M = {}
local root = assert(debug.getinfo(1, "S").source:match("^@(.+)/core/orbitui_icons%.lua$"))
local base = root .. "/assets/material-symbols/"
local by_name, cells, bookshelf_cells

M.legacy_pack_id = "orbitui:material-symbols-rounded"

function M.catalogue()
    if cells then return cells end
    cells, by_name = {}, {}
    for _, entry in ipairs(require("core/orbitui_material_catalogue")) do
        local cell = {
            name = entry.name, code = entry.code, group = entry.group,
            label = entry.name:gsub("_", " "), canonical = entry.name,
            search_lc = (entry.name:gsub("_", " ") .. " " .. entry.name .. " " .. entry.aliases):lower(),
            is_image = true, icon = "orbitui-material-" .. entry.name,
            value = "material:" .. entry.name,
            image_name = "orbitui-material-" .. entry.name,
            file = base .. "icons/" .. entry.name .. ".svg",
        }
        cells[#cells + 1] = cell
        by_name[entry.name] = cell
    end
    return cells
end

function M.entry(value)
    if type(value) ~= "string" then return nil end
    local name = value:match("^material:([a-z0-9_]+)$")
        or value:match("^orbitui%-material%-([a-z0-9_]+)$")
    if not name then return nil end
    M.catalogue()
    return by_name[name]
end

function M.imageFile(value)
    local entry = M.entry(value)
    if entry then return entry.file end
end

-- Image-only SimpleUI slots may store a validated absolute SVG path. Rebase
-- only our exact asset suffix, including old OTA slots, never arbitrary files.
function M.rebaseImage(path)
    if type(path) ~= "string" then return nil end
    local name = path:match("/assets/material%-symbols/icons/([a-z0-9_]+)%.svg$")
    return name and M.imageFile("material:" .. name) or nil
end

function M.filtered(group, query)
    local out, terms = {}, {}
    for term in (query or ""):lower():gmatch("%S+") do terms[#terms + 1] = term end
    for _, cell in ipairs(M.catalogue()) do
        local match = not group or group == "all" or cell.group == group
        for _, term in ipairs(terms) do
            if not cell.search_lc:find(term, 1, true) then match = false; break end
        end
        if match then out[#out + 1] = cell end
    end
    return out
end

function M.bookshelfCells()
    if bookshelf_cells then return bookshelf_cells end
    local out = {}
    for _, cell in ipairs(M.catalogue()) do
        out[#out + 1] = {
            label = cell.label, canonical = cell.canonical, code = cell.code,
            is_image = true, icon = cell.image_name, file = cell.file,
            search_lc = cell.search_lc,
            insert_value = "[icon=" .. cell.image_name .. "]",
        }
    end
    bookshelf_cells = out
    return out
end

return M
