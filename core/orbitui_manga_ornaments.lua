-- Series-bound miniatures are excluded from the random ornament deck.
local M = {}
M.pack = "Manga"
M.packs = {
    { name = M.pack, marker = "ornament-manga-v1.installed", files = {
        "ATTRIBUTION.txt", "README.txt", "prompts.json", "ornaments.json",
        "Kaneda Motorcycle.png", "Walking Mushroom.png", "Apothecary Mortar.png",
    } },
}
M.pieces = {
    ["Manga/Kaneda Motorcycle.png"] = "series:akira",
    ["Manga/Walking Mushroom.png"] = "series:dungeon-meshi",
    ["Manga/Apothecary Mortar.png"] = "series:apothecary-diaries",
}

local function normalize(name)
    return name:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end
local aliases = {}
for id, names in pairs({
    ["series:akira"] = { "Akira", "アキラ" },
    ["series:dungeon-meshi"] = { "Dungeon Meshi", "Delicious in Dungeon", "ダンジョン飯" },
    ["series:apothecary-diaries"] = {
        "The Apothecary Diaries", "Apothecary Diaries", "Kusuriya no Hitorigoto", "薬屋のひとりごと",
    },
}) do
    for _, name in ipairs(names) do aliases[normalize(name)] = id end
end

function M.seriesOf(entry)
    local book = entry.book or {}
    if book.kind == "folder" then
        if not book._spine_single then return nil end
        book = book.first_book or {}
    elseif book.kind and book.kind ~= "series" and book.kind ~= "book" then
        return nil
    end
    local name = book.series_name or book.series
    -- Lightweight members may inherit metadata from an explicit series group,
    -- but never from an author, tag, folder name or a representative's title.
    if name == nil or name == "" then
        local group = entry.item
        if group and group.kind == "series" then name = group.series_name or group.series end
    end
    return type(name) == "string" and aliases[normalize(name)] or nil
end

function M.seed(root, ornaments_dir)
    return require("core/orbitui_ornament_install").seed(root, ornaments_dir, M.packs)
end

return M
