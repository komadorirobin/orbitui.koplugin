-- Series-bound miniatures are excluded from the random ornament deck.
local M = {}
M.pack = "Manga"
M.packs = {
    { name = M.pack, marker = "ornament-manga-v1.installed", files = {
        "ATTRIBUTION.txt", "README.txt", "prompts.json", "ornaments.json",
        "Kaneda Motorcycle.png", "Walking Mushroom.png", "Apothecary Mortar.png",
    } },
    { name = "Manga II", marker = "ornament-manga-ii-v1.installed", files = {
        "ATTRIBUTION.txt", "README.txt", "prompts.json", "ornaments.json",
        "Nyanko Sensei.png", "Brushbuddy.png", "Ohmu.png", "Mimic Chest.png",
        "Pochita.png", "Turbo Granny.png", "Transponder Snail.png", "Kettenkrad.png",
        "Camp Tent.png", "Armillary Sphere.png", "Cafe Alpha.png",
    } },
}
M.pieces = {
    ["Manga/Kaneda Motorcycle.png"] = "series:akira",
    ["Manga/Walking Mushroom.png"] = "series:dungeon-meshi",
    ["Manga/Apothecary Mortar.png"] = "series:apothecary-diaries",
    ["Manga II/Nyanko Sensei.png"] = "series:natsume",
    ["Manga II/Brushbuddy.png"] = "series:witch-hat-atelier",
    ["Manga II/Ohmu.png"] = "series:nausicaa",
    ["Manga II/Mimic Chest.png"] = "series:frieren",
    ["Manga II/Pochita.png"] = "series:chainsaw-man",
    ["Manga II/Turbo Granny.png"] = "series:dandadan",
    ["Manga II/Transponder Snail.png"] = "series:one-piece",
    ["Manga II/Kettenkrad.png"] = "series:girls-last-tour",
    ["Manga II/Camp Tent.png"] = "series:laid-back-camp",
    ["Manga II/Armillary Sphere.png"] = "series:orb",
    ["Manga II/Cafe Alpha.png"] = "series:yokohama-kaidashi-kikou",
}

local function normalize(name)
    return name:gsub("’", "'"):gsub("‘", "'"):gsub("Ä", "a"):gsub("ä", "a")
        :lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end
local aliases = {}
for id, names in pairs({
    ["series:akira"] = { "Akira", "アキラ" },
    ["series:dungeon-meshi"] = { "Dungeon Meshi", "Delicious in Dungeon", "ダンジョン飯" },
    ["series:apothecary-diaries"] = {
        "The Apothecary Diaries", "Apothecary Diaries", "Kusuriya no Hitorigoto", "薬屋のひとりごと",
    },
    ["series:natsume"] = { "Natsume's Book of Friends", "Natsume Yujin-cho", "Natsume Yuujinchou", "夏目友人帳" },
    ["series:witch-hat-atelier"] = { "Witch Hat Atelier", "Tongari Boushi no Atelier", "とんがり帽子のアトリエ" },
    ["series:nausicaa"] = { "Nausicaa of the Valley of the Wind", "Kaze no Tani no Nausicaa", "風の谷のナウシカ" },
    ["series:frieren"] = { "Frieren: Beyond Journey's End", "Frieren", "Sousou no Frieren", "葬送のフリーレン" },
    ["series:chainsaw-man"] = { "Chainsaw Man", "チェンソーマン" },
    ["series:dandadan"] = { "Dandadan", "Dan Da Dan", "ダンダダン" },
    ["series:one-piece"] = { "One Piece", "ワンピース" },
    ["series:girls-last-tour"] = { "Girls' Last Tour", "Shoujo Shuumatsu Ryokou", "少女終末旅行" },
    ["series:laid-back-camp"] = { "Laid-Back Camp", "Yuru Camp", "Yuru Camp△", "ゆるキャン△" },
    ["series:orb"] = {
        "Orb: On the Movements of the Earth", "Orb: On the Movements of the Earth (Omnibus)",
        "Chi: On the Movements of the Earth", "Chi: Chikyuu no Undou ni Tsuite", "チ。―地球の運動について―",
    },
    ["series:yokohama-kaidashi-kikou"] = {
        "Yokohama Kaidashi Kikou", "Yokohama Kaidashi Kikou: Deluxe Edition", "ヨコハマ買い出し紀行",
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
