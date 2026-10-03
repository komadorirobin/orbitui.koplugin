-- Material names are stored instead of codepoints/OTA-slot paths. Nothing
-- replaces KOReader's symbols face or changes existing Nerd Font selections.
local M = {}
local root = assert(debug.getinfo(1, "S").source:match("^@(.+)/core/orbitui_icons%.lua$"))
local base = root .. "/assets/material-symbols/"
local by_name, cells, bookshelf_cells

M.pack_id = "orbitui:material-symbols-rounded"
M.actions = {
    homescreen = "home", home = "library_books", filemanager_menu = "menu",
    collections = "collections_bookmark", history = "history", recent = "schedule",
    ["continue"] = "menu_book", favorites = "favorite", bookmark_browser = "bookmarks",
    search_library = "search", wifi_toggle = "wifi", frontlight = "brightness_6",
    night_mode = "dark_mode", stats_calendar = "bar_chart", power = "power_settings_new",
    sui_settings = "settings", browse_authors = "person_book", browse_series = "book_3",
    browse_tags = "filter_list", bookshelf_prose = "library_books", bookshelf_comics = "manga",
    bookshelf_prose_menu = "library_books", bookshelf_comics_menu = "manga",
    extract_book_info = "info",
}
M.slots = {
    sui_menu = "menu", sui_search = "search", sui_back = "chevron_left",
    sui_browse_normal = "view_list", sui_browse_author = "person_book",
    sui_browse_series = "book_3", sui_browse_tags = "filter_list",
    sui_pager_prev = "chevron_left", sui_pager_next = "chevron_right",
    sui_pager_first = "first_page", sui_pager_last = "last_page",
    sui_navpager_prev = "chevron_left", sui_navpager_next = "chevron_right",
    sui_coll_back = "arrow_back", sui_fc_empty = "folder",
    sui_tab_main = "menu", sui_tab_setting = "settings", sui_tab_tools = "extension",
    sui_tab_search = "search", sui_tab_fm_settings = "folder",
    sui_tab_navigation = "menu_book", sui_tab_typeset = "format_size",
    sui_tab_filebrowser = "folder_open", sui_tab_qs_panel = "tune",
}

local function utf8(cp)
    return string.char(0xE0 + math.floor(cp / 0x1000),
        0x80 + math.floor((cp % 0x1000) / 0x40), 0x80 + cp % 0x40)
end

function M.catalogue()
    if cells then return cells end
    cells, by_name = {}, {}
    for _, entry in ipairs(require("core/orbitui_material_catalogue")) do
        local cell = {
            name = entry.name, code = entry.code, group = entry.group,
            label = entry.name:gsub("_", " "), canonical = entry.name,
            search_lc = (entry.name:gsub("_", " ") .. " " .. entry.name .. " " .. entry.aliases):lower(),
            glyph = utf8(entry.code), font = base .. "MaterialSymbolsRounded.ttf",
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

function M.glyph(value)
    local entry = M.entry(value)
    if entry then return entry.glyph, entry.font end
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
            glyph = cell.glyph, font = cell.font, search_lc = cell.search_lc,
            insert_value = "[icon=" .. cell.image_name .. "]",
        }
    end
    bookshelf_cells = out
    return out
end

return M
