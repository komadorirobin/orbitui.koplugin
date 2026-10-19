-- Match ornaments to books by default; opted-in packs use the ordinary deck.
local Manga = require("core/orbitui_manga_ornaments")
local M = {}
M.pack = "Modernists"
M.files = { "ATTRIBUTION.txt", "README.txt", "prompts.json", "ornaments.json",
    "James Joyce.png", "Virginia Woolf.png" }
M.packs = {
    { name = M.pack, marker = "ornament-modernists-v1.installed", files = M.files },
    { name = "Authors", marker = "ornament-authors-v1.installed", files = {
        "ATTRIBUTION.txt", "README.txt", "prompts.json", "ornaments.json",
        "August Strindberg.png", "Stanislaw Lem.png", "Dylan Thomas.png",
        "Thomas Mann.png", "Fyodor Dostoevsky.png", "Knut Hamsun.png",
        "Robert Musil.png", "Franz Kafka.png", "KAFKA-KIELCE.txt", "THOMAS-MANN-SEITZ.txt",
        "AUTHOR-SCULPTURES.txt",
    } },
    { name = "Authors II", marker = "ornament-authors-ii-v1.installed", files = {
        "ATTRIBUTION.txt", "README.txt", "prompts.json", "ornaments.json",
        "Ernest Hemingway.png", "Italo Svevo.png", "ERNEST-HEMINGWAY.txt",
    } },
}
M.pieces = {
    ["Modernists/James Joyce.png"] = "james joyce",
    ["Modernists/Virginia Woolf.png"] = "virginia woolf",
    -- The earlier manually installed trial pack uses these same pictures.
    ["Modernists-Preview/James Joyce.png"] = "james joyce",
    ["Modernists-Preview/Virginia Woolf.png"] = "virginia woolf",
    ["Authors/August Strindberg.png"] = "august strindberg",
    ["Authors/Stanislaw Lem.png"] = "stanislaw lem",
    ["Authors/Dylan Thomas.png"] = "dylan thomas",
    ["Authors/Thomas Mann.png"] = "thomas mann",
    ["Authors/Fyodor Dostoevsky.png"] = "fyodor dostoevsky",
    ["Authors/Knut Hamsun.png"] = "knut hamsun",
    -- Keep matching for reader-supplied replacements of the retired portrait.
    ["Authors/Clarice Lispector.png"] = "clarice lispector",
    ["Authors/Robert Musil.png"] = "robert musil",
    ["Authors/Franz Kafka.png"] = "franz kafka",
    ["Authors II/Ernest Hemingway.png"] = "ernest hemingway",
    ["Authors II/Italo Svevo.png"] = "italo svevo",
}

local function normalize(name)
    -- Lua's lower() only folds ASCII; also fold the L-with-stroke in Lem's name.
    return name:gsub("\197\129", "\197\130"):lower():gsub("%s+", " ")
        :gsub("%s*,%s*", ", "):gsub("^%s+", ""):gsub("%s+$", "")
end
local aliases = {}
local extra_aliases, extra_pieces = {}, {}
function M.setBindings(bindings)
    extra_aliases, extra_pieces = {}, {}
    for path, binding in pairs(bindings) do
        if binding.kind == "author" then
            extra_pieces[path] = binding.id
            for _, name in ipairs(binding.names) do
                extra_aliases[normalize(name)] = binding.id
                local given, surname = name:match("^(.+) (%S+)$")
                if given then extra_aliases[normalize(surname .. ", " .. given)] = binding.id end
            end
        end
    end
end
function M.piece(name) return extra_pieces[name] or M.pieces[name] end
local placements = {}
local placement_generation = 0
function M.placementGeneration() return placement_generation end
function M.setPlacements(modes)
    local previous = placements
    placements = {}
    for folder, mode in pairs(modes) do
        if mode == "random" then placements[folder] = mode end
    end
    for folder in pairs(previous) do
        if not placements[folder] then placement_generation = placement_generation + 1; return end
    end
    for folder in pairs(placements) do
        if not previous[folder] then placement_generation = placement_generation + 1; return end
    end
end
function M.target(piece)
    if not piece then return nil end
    local folder = piece.pack or (piece.name or ""):match("^([^/]+)/")
    if placements[folder] == "random" then return nil end
    local id = M.piece(piece.name)
    if id then return id, "author" end
    id = Manga.piece(piece.name)
    if id then return id, "series" end
end
local function alias(id, name)
    aliases[normalize(name)] = id
    local given, surname = name:match("^(.+) (%S+)$")
    if given then aliases[normalize(surname .. ", " .. given)] = id end
end
for _, id in pairs(M.pieces) do alias(id, id) end
alias("virginia woolf", "Adeline Virginia Woolf")
alias("august strindberg", "Johan August Strindberg")
alias("ernest hemingway", "Ernest Miller Hemingway")
alias("italo svevo", "Ettore Schmitz")
alias("italo svevo", "Aron Hector Schmitz")
alias("italo svevo", "Hector Aaron Schmitz")
alias("stanislaw lem", "Stanis\197\130aw Lem")
for _, name in ipairs({
    "Fjodor Dostojevskij", "Fjodor Michajlovitj Dostojevskij", "Fjodor Dostojevsky",
    "Fyodor Dostoyevsky", "Fyodor Mikhailovich Dostoevsky", "Fyodor Mikhailovich Dostoyevsky",
    "Fedor Dostoevsky", "Feodor Dostoevsky", "Fiodor Dostoievski",
}) do alias("fyodor dostoevsky", name) end
local function author(value)
    if type(value) == "table" then
        if value.name then return author(value.name) end
        for _, name in ipairs(value) do
            local id = author(name)
            if id then return id end
        end
    elseif type(value) == "string" then
        for part in value:gmatch("[^\n;|&]+") do
            local name = normalize(part)
            if extra_aliases[name] or aliases[name] then return extra_aliases[name] or aliases[name] end
        end
    end
end

function M.authorOf(entry)
    local book = entry.book or {}
    -- A folder's representative is not necessarily its only author.
    if book.kind == "folder" and not book._spine_single then return nil end
    return author(entry.author) or author(book.author) or author(book.authors)
end

-- Each additive pack installs once from the active OTA runtime. Independent
-- markers allow new packs without overwriting or resurrecting older artwork.
function M.seed(root, ornaments_dir)
    local seeded = require("core/orbitui_ornament_install").seed(root, ornaments_dir, M.packs)
    local artwork = require("core/orbitui_kafka_update").apply(root, ornaments_dir)
    local mann = require("core/orbitui_mann_update").apply(root, ornaments_dir)
    local hemingway = require("core/orbitui_hemingway_update").apply(root, ornaments_dir)
    local sculptures = require("core/orbitui_sculpture_updates").apply(root, ornaments_dir)
    local retired = require("core/orbitui_lispector_retirement").apply(root, ornaments_dir)
    local updated = require("core/orbitui_author_info").apply(root, ornaments_dir)
    return seeded or artwork or mann or hemingway or sculptures or retired or updated
end

function M.fillHooks(native, env)
    local regular, targeted = {}, {}
    for _, piece in ipairs(env.dealer.cards) do
        local id = M.target(piece)
        if id then
            -- Prefer the released pack over an enabled copy of the trial pack.
            if not targeted[id] or piece.pack == M.pack then targeted[id] = piece end
        else
            regular[#regular + 1] = piece
        end
    end
    env.dealer.cards = regular
    env.max_per_row = 1
    local function sizeForBook(kind, piece, no, entry)
        local room = env.content_w - entry.w - (kind == "gap" and (entry.gap_base or 0) or 0)
        local pl = env.size(kind, piece, no)
        if not pl or room <= 0 then return nil end
        if env.space(kind, pl) > room then
            local cap = room - (env.space(kind, pl) - pl.w)
            local small = cap > 0 and env.size(kind, piece, no, cap) or nil
            if not small or small.w * 4 < pl.w or env.space(kind, small) > room then return nil end
            pl = small
        end
        return pl
    end
    -- Native squeeze handles row ends, not a boundary's leading ornament.
    -- Use identical bounds when previewing and dealing that book's piece.
    local sizing_index
    local native_env = {}
    for key, value in pairs(env) do native_env[key] = value end
    native_env.size = function(kind, piece, no, cap)
        if sizing_index and (kind == "lead" or kind == "gap") then
            return sizeForBook(kind, piece, no, env.entries[sizing_index])
        end
        return env.size(kind, piece, no, cap)
    end
    local hooks = native(native_env)
    if env.level == "off" then return hooks end

    local has_targets = next(targeted) ~= nil
    local avail, lead, placed, stop = hooks.avail, hooks.lead, hooks.placed, hooks.stop
    local final = hooks.final
    local gaps, active, row = hooks.gaps, true, 0
    local previous = {}
    local selected = {}
    local identities = { author = {}, series = {} }
    local function identity(i, category)
        local cache = identities[category]
        if cache[i] == nil then
            local match = category == "author" and M.authorOf or Manga.seriesOf
            cache[i] = match(env.entries[i]) or false
        end
        return cache[i]
    end
    local function allowed()
        return active and env.level ~= "off" and (env.paginating or row <= (env.n_rows or 1))
    end
    local function pieceFor(kind, i, preceding, category)
        if not allowed() then return nil end
        local id = identity(i, category)
        local piece = id ~= preceding and targeted[id] or nil
        if not piece then return nil end
        return sizeForBook(kind, piece, 1, env.entries[i])
    end
    local function selectCategory(first, category)
        local used, preceding = 0, previous[category]
        for i = first, #env.entries do
            local entry = env.entries[i]
            if i > first then used = used + (entry.gap_base or 0) end
            used = used + entry.w
            if used > env.content_w then return end
            local kind = i == first and "lead" or "gap"
            local pl = pieceFor(kind, i, preceding, category)
            if pl then
                selected[i] = pl
                used = used + env.space(kind, pl)
                -- Keep the proposal: fillRows will move this book/bust pair
                -- to the next row rather than silently dropping its bust.
                if used > env.content_w then return end
                hooks.row_count[row] = 1
                if category == "series" then return end
            end
            preceding = identity(i, category)
        end
    end
    local function selectTarget(first)
        selected = {}
        if not first or not allowed() or not has_targets then return end
        -- Busts retain priority and may share a row. A series miniature uses
        -- the row's single ordinary slot, before the random dealer runs.
        selectCategory(first, "author")
        if not next(selected) then selectCategory(first, "series") end
    end
    function hooks.avail(r, i)
        if active and r and r > row then
            row = r
            -- A page render starts without the preceding book. Reset at the
            -- same boundaries in whole-library pagination to reserve equal room.
            if r == 1 or (env.paginating and (r - 1) % math.max(1, env.per_page or 1) == 0) then
                previous = {}
            end
            selectTarget(i)
        end
        return avail(r, i)
    end
    hooks.gaps = setmetatable({}, { __index = function(_, i)
        local pl = selected[i]
        if pl then return (env.entries[i].gap_base or 0) + env.space("gap", pl) end
        sizing_index = i
        local gap = gaps[i]
        sizing_index = nil
        return gap
    end })
    function hooks.lead(i)
        local pl = selected[i]
        if pl then return env.space("lead", pl) end
        sizing_index = i
        local width = lead(i)
        sizing_index = nil
        return width
    end
    function hooks.placed(i, r, starts_row)
        local pl = selected[i]
        local entry = env.entries[i]
        local seed = entry.orn_seed
        if pl then entry.orn_seed = nil end
        sizing_index = i
        placed(i, r, starts_row)
        sizing_index = nil
        entry.orn_seed = seed
        if pl then
            if starts_row then entry.lead_ornament = pl
            else
                entry.ornament = pl
                entry.gap_before = (entry.gap_base or 0) + env.space("gap", pl)
            end
        end
        if has_targets then
            previous.author, previous.series = identity(i, "author"), identity(i, "series")
        end
    end
    function hooks.stop() active = false; stop() end
    function hooks.final()
        local fin_gaps, fin_lead, no_break, fixed = final()
        local ordinary, authors = { [0] = 0 }, { [0] = 0 }
        for i, e in ipairs(env.entries) do
            ordinary[i], authors[i] = ordinary[i - 1], authors[i - 1]
            local pl = e.ornament or e.lead_ornament
            if pl then
                local _, category = M.target(pl.entry)
                local counts = category == "author" and authors or ordinary
                counts[i] = counts[i] + 1
            end
        end
        -- Keep ordinary rows sparse. Author rows may hold several matching
        -- busts, but cannot acquire ordinary decorations during balancing.
        local function accept(r, first, last)
            local n = ordinary[last] - ordinary[first - 1] + (hooks.row_orn[r] and 1 or 0)
            return n <= 1 and (n == 0 or authors[last] == authors[first - 1])
        end
        return fin_gaps, fin_lead, no_break, fixed, accept
    end
    -- Native final() retains book/bust pairs; bare rows use only regular cards.
    return hooks
end

return M
