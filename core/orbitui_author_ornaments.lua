-- Author ornaments are book-adjacent pieces, never cards in the general deck.
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
        "Ernest Hemingway.png", "Italo Svevo.png",
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
            if aliases[name] then return aliases[name] end
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
    local sculptures = require("core/orbitui_sculpture_updates").apply(root, ornaments_dir)
    local retired = require("core/orbitui_lispector_retirement").apply(root, ornaments_dir)
    local updated = require("core/orbitui_author_info").apply(root, ornaments_dir)
    return seeded or artwork or mann or sculptures or retired or updated
end

function M.fillHooks(native, env)
    local regular, targeted = {}, {}
    for _, piece in ipairs(env.dealer.cards) do
        local id = M.pieces[piece.name]
        if id then
            -- Prefer the released pack over an enabled copy of the trial pack.
            if not targeted[id] or piece.pack == M.pack then targeted[id] = piece end
        else
            regular[#regular + 1] = piece
        end
    end
    env.dealer.cards = regular
    env.max_per_row = 1
    local hooks = native(env)
    if env.level == "off" then return hooks end

    local has_authors = next(targeted) ~= nil
    local avail, lead, placed, stop = hooks.avail, hooks.lead, hooks.placed, hooks.stop
    local final = hooks.final
    local gaps, active, row, previous = hooks.gaps, true, 0, nil
    local selected = {}
    local identities = {}
    local function identity(i)
        if identities[i] == nil then identities[i] = M.authorOf(env.entries[i]) or false end
        return identities[i]
    end
    local function allowed()
        return active and env.level ~= "off" and (env.paginating or row <= (env.n_rows or 1))
    end
    local function pieceFor(kind, i, preceding)
        if not allowed() then return nil end
        local id = identity(i)
        local piece = id ~= preceding and targeted[id] or nil
        if not piece then return nil end
        local entry = env.entries[i]
        local room = env.content_w - entry.w - (kind == "gap" and (entry.gap_base or 0) or 0)
        local pl = env.size(kind, piece, 1)
        if not pl or room <= 0 then return nil end
        if env.space(kind, pl) > room then
            local cap = room - (env.space(kind, pl) - pl.w)
            local small = cap > 0 and env.size(kind, piece, 1, cap) or nil
            if not small or small.w * 4 < pl.w or env.space(kind, small) > room then return nil end
            pl = small
        end
        return pl
    end
    local function selectAuthor(first)
        selected = {}
        if not first or not allowed() or not has_authors then return end
        -- Reserve author pieces before ordinary dealing. Several busts may
        -- share a row, but together occupy its only decorative slot.
        local used, preceding = 0, previous
        for i = first, #env.entries do
            local entry = env.entries[i]
            if i > first then used = used + (entry.gap_base or 0) end
            used = used + entry.w
            if used > env.content_w then return end
            local kind = i == first and "lead" or "gap"
            local pl = pieceFor(kind, i, preceding)
            if pl then
                selected[i] = pl
                used = used + env.space(kind, pl)
                -- Keep the proposal: fillRows will move this book/bust pair
                -- to the next row rather than silently dropping its bust.
                if used > env.content_w then return end
                hooks.row_count[row] = 1
            end
            preceding = identity(i)
        end
    end
    function hooks.avail(r, i)
        if active and r and r > row then
            row = r
            -- A page render starts without the preceding book. Reset at the
            -- same boundaries in whole-library pagination to reserve equal room.
            if r == 1 or (env.paginating and (r - 1) % math.max(1, env.per_page or 1) == 0) then
                previous = nil
            end
            selectAuthor(i)
        end
        return avail(r, i)
    end
    hooks.gaps = setmetatable({}, { __index = function(_, i)
        local pl = selected[i]
        if pl then return (env.entries[i].gap_base or 0) + env.space("gap", pl) end
        return gaps[i]
    end })
    function hooks.lead(i)
        local pl = selected[i]
        return pl and env.space("lead", pl) or lead(i)
    end
    function hooks.placed(i, r, starts_row)
        local pl = selected[i]
        local entry = env.entries[i]
        local seed = entry.orn_seed
        if pl then entry.orn_seed = nil end
        placed(i, r, starts_row)
        entry.orn_seed = seed
        if pl then
            if starts_row then entry.lead_ornament = pl
            else
                entry.ornament = pl
                entry.gap_before = (entry.gap_base or 0) + env.space("gap", pl)
            end
        end
        previous = has_authors and identity(i) or nil
    end
    function hooks.stop() active = false; stop() end
    function hooks.final()
        local fin_gaps, fin_lead, no_break, fixed = final()
        local ordinary, authors = { [0] = 0 }, { [0] = 0 }
        for i, e in ipairs(env.entries) do
            ordinary[i], authors[i] = ordinary[i - 1], authors[i - 1]
            local pl = e.ornament or e.lead_ornament
            if pl then
                local counts = M.pieces[pl.entry.name] and authors or ordinary
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
