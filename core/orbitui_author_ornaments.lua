-- Author ornaments are book-adjacent pieces, never cards in the general deck.
local M = {}
M.pack = "Modernists"
M.files = { "ATTRIBUTION.txt", "README.txt", "prompts.json", "ornaments.json",
    "James Joyce.png", "Virginia Woolf.png" }
M.pieces = {
    ["Modernists/James Joyce.png"] = "james joyce",
    ["Modernists/Virginia Woolf.png"] = "virginia woolf",
    -- The earlier manually installed trial pack uses these same pictures.
    ["Modernists-Preview/James Joyce.png"] = "james joyce",
    ["Modernists-Preview/Virginia Woolf.png"] = "virginia woolf",
}

local aliases = {
    ["james joyce"] = "james joyce", ["joyce, james"] = "james joyce",
    ["virginia woolf"] = "virginia woolf", ["woolf, virginia"] = "virginia woolf",
    ["adeline virginia woolf"] = "virginia woolf",
    ["woolf, adeline virginia"] = "virginia woolf",
}
local function author(value)
    if type(value) == "table" then
        if value.name then return author(value.name) end
        for _, name in ipairs(value) do
            local id = author(name)
            if id then return id end
        end
    elseif type(value) == "string" then
        for part in value:gmatch("[^\n;|&]+") do
            local name = part:lower():gsub("%s+", " "):gsub("%s*,%s*", ", ")
                :gsub("^%s+", ""):gsub("%s+$", "")
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

local function copy(source, target)
    local input = assert(io.open(source, "rb"))
    local temporary, output = target .. ".orbitui-tmp"
    local ok, err = pcall(function()
        output = assert(io.open(temporary, "wb"))
        while true do
            local bytes, read_error = input:read(65536)
            assert(not read_error, read_error)
            if not bytes then break end
            assert(output:write(bytes))
        end
        assert(output:close())
        output = nil
        assert(os.rename(temporary, target))
    end)
    input:close()
    if output then pcall(output.close, output) end
    if not ok then os.remove(temporary); error(err) end
end

-- Install once, from the active OTA runtime. Never replace user files or
-- resurrect a deleted piece/pack. A partial first install can retry safely.
function M.seed(root, ornaments_dir)
    local fs = require("libs/libkoreader-lfs")
    local settings = require("datastorage"):getSettingsDir() .. "/orbitui"
    local marker = settings .. "/ornament-modernists-v1.installed"
    if fs.attributes(marker, "mode") == "file" then return false end
    local target = ornaments_dir .. "/" .. M.pack
    local ensure = require("lib/bookshelf_fs").ensureDir
    assert(ensure(settings) and ensure(target), "Cannot create ornament pack folder")
    for _, file in ipairs(M.files) do
        if not fs.attributes(target .. "/" .. file, "mode") then
            copy(root .. "/assets/ornaments/" .. M.pack .. "/" .. file, target .. "/" .. file)
        end
    end
    -- Commit only after all files and notices have reached their destination.
    copy(root .. "/assets/ornaments/" .. M.pack .. "/README.txt", marker)
    return true
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
    local hooks = native(env)
    if env.level == "off" or not next(targeted) then return hooks end

    local avail, lead, placed, stop = hooks.avail, hooks.lead, hooks.placed, hooks.stop
    local empty_ok, author_lead = hooks.empty_ok, false
    local gaps, active, row, previous = hooks.gaps, true, 0, nil
    local identities = {}
    local function identity(i)
        if identities[i] == nil then identities[i] = M.authorOf(env.entries[i]) or false end
        return identities[i]
    end
    local function allowed()
        return active and (env.paginating or row <= (env.n_rows or 1))
    end
    local function pieceFor(kind, i)
        if not allowed() then return nil end
        local id = identity(i)
        local piece = id ~= previous and targeted[id] or nil
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
    function hooks.avail(r, i)
        if active and r and r > row then
            row = r
            -- A page render starts without the preceding book. Reset at the
            -- same boundaries in whole-library pagination to reserve equal room.
            if r == 1 or (env.paginating and (r - 1) % math.max(1, env.per_page or 1) == 0) then
                previous = nil
            end
        end
        return avail(r, i)
    end
    hooks.gaps = setmetatable({}, { __index = function(_, i)
        local pl = pieceFor("gap", i)
        if pl then return (env.entries[i].gap_base or 0) + env.space("gap", pl) end
        return gaps[i]
    end })
    function hooks.lead(i)
        local pl = pieceFor("lead", i)
        author_lead = pl ~= nil
        return pl and env.space("lead", pl) or lead(i)
    end
    function hooks.empty_ok(r)
        -- Prefer the book and its bust to a decorative row-end piece. Apart
        -- from wasting rows, skipping them can carry MAX_EMPTY_RUN across a
        -- page boundary, which a separate page render cannot reproduce.
        return not author_lead and empty_ok(r)
    end
    function hooks.placed(i, r, starts_row)
        local kind = starts_row and "lead" or "gap"
        local pl = pieceFor(kind, i)
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
        previous = identity(i)
    end
    function hooks.stop() active = false; stop() end
    -- Native final() pins lead books to row starts and keeps mid-row pairs
    -- together during balancing. Bare shelves only draw from regular cards.
    return hooks
end

return M
