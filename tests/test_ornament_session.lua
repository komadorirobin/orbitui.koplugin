package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Adapter = require("adapters/orbitui_ornaments")
local Authors = require("core/orbitui_author_ornaments")
local Japan = require("core/orbitui_japan_ornaments")
local Gallery = require("core/orbitui_ukiyoe_ornaments")
local Layout = require("lib/bookshelf_spine_layout")
local author_seed, japan_seed = Authors.seed, Japan.seed
local gallery_seed = Gallery.seed
package.loaded["ui/widget/widget"] = H.widget()

local function piece(name, pack, width)
    return { name = name, pack = pack, w = width or 30 }
end
local pine = piece("Japan/Pine Bonsai.png", "Japan")
local maple = piece("Japan/Maple Bonsai.png", "Japan", 40)
local cat = piece("Japan/Sleeping Calico.png", "Japan", 50)
local joyce = piece("Modernists/James Joyce.png", "Modernists", 45)
local woolf = piece("Modernists/Virginia Woolf.png", "Modernists", 45)
local function names(entries)
    local out = {}; for i, entry in ipairs(entries) do out[i] = entry.name end
    return table.concat(out, "|")
end

local function fixture(all, saved)
    all = all or { pine, maple, cat, joyce, woolf }
    local memory = saved or { ornament_decks = { _ = {} } }
    if not saved then
        for i, entry in ipairs(all) do memory.ornament_decks._[i] = entry.name end
    end
    local stats = { writes = 0, shuffles = 0, warnings = 0, authors = 0, japan = 0, gallery = 0,
        scans = 0, all = all, packs = { "Japan", "Modernists" } }
    local store = {
        read = function(key) return memory[key] end,
        save = function(key, value)
            assert(key == "ornament_decks" or (key == "ornament_deck" and value == nil),
                "session shuffle may only save decks or migrate the legacy deck")
            memory[key] = value; stats.writes = stats.writes + 1
        end,
    }
    package.loaded.logger = { warn = function() stats.warnings = stats.warnings + 1 end }
    package.loaded["lib/bookshelf_settings_store"] = store
    package.loaded["lib/bookshelf_tab_model"] = { load = function() return {} end }
    local deck = dofile("components/bookshelf/lib/bookshelf_ornament_deck.lua")
    deck._store, deck._rand = store, function() return 1 end
    local shuffle = deck.shuffle
    deck.shuffle = function(...)
        stats.shuffles = stats.shuffles + 1
        if stats.fail_shuffle then error("shuffle unavailable") end
        return shuffle(...)
    end
    Adapter.wrap("lib/bookshelf_ornament_deck", deck, "/slot")
    package.loaded["lib/bookshelf_ornament_deck"] = deck
    Authors.seed = function() stats.authors = stats.authors + 1 end
    Japan.seed = function()
        stats.japan = stats.japan + 1
        if stats.new_piece then stats.all[#stats.all + 1] = stats.new_piece end
    end
    Gallery.seed = function()
        stats.gallery = stats.gallery + 1
        if stats.new_print then stats.all[#stats.all + 1] = stats.new_print end
    end
    local orn = dofile("components/bookshelf/lib/bookshelf_ornaments.lua")
    orn._store, orn._clock = store, function() return 1 end
    orn.dir = function() return "/settings/bookshelf/ornaments" end
    orn.listAll = function()
        stats.scans = stats.scans + 1
        return stats.all, stats.packs
    end
    Adapter.wrap("lib/bookshelf_ornaments", orn, "/slot")
    package.loaded["lib/bookshelf_ornaments"] = orn
    return orn, deck, stats, memory
end

local function scan(orn, deck, shelf)
    local all, packs = orn.listAll()
    deck.sync(all, shelf)
    return all, packs
end

H.test("loading the adapter does no eager catalogue work or settings writes", function()
    local _, deck, stats = fixture()
    H.eq(stats.scans, 0); H.eq(stats.shuffles, 0); H.eq(stats.writes, 0)
    H.eq(stats.authors, 0); H.eq(stats.japan, 0); H.eq(deck.epoch(), 0)
end)

H.test("listing is read-only; the first deal shuffles once and preserves list identities", function()
    local orn, deck, stats, memory = fixture()
    local before = table.concat(memory.ornament_decks._, "|")
    orn.listAll(); H.eq(stats.shuffles, 0); H.eq(stats.writes, 0)
    local all, packs = scan(orn, deck)
    H.eq(all, stats.all); H.eq(packs, stats.packs)
    assert(table.concat(memory.ornament_decks._, "|") ~= before)
    H.eq(#memory.ornament_decks._, #all); H.eq(deck.epoch(), 1)
    H.eq(stats.shuffles, 1); H.eq(stats.writes, 1)
    H.eq(stats.authors, 1); H.eq(stats.japan, 1)
    H.eq(names(orn.list()), names(orn.list()), "native enabled-pool caching remains stable")
end)

H.test("newly seeded pieces are reconciled before the startup shuffle", function()
    local orn, deck, stats, memory = fixture({ joyce, maple })
    stats.new_piece = cat
    memory.ornament_decks._[#memory.ornament_decks._ + 1] = "deleted.svg"
    scan(orn, deck)
    local result = table.concat(deck.names(), "|")
    assert(result:find(cat.name, 1, true)); assert(not result:find("deleted.svg", 1, true))
    H.eq(#deck.names(), 3); H.eq(stats.shuffles, 1)
    H.eq(names(deck.order(orn.list())), result)
end)

H.test("new gallery prints join the same one-time native startup shuffle", function()
    local orn, deck, stats = fixture({ joyce, cat })
    stats.new_print = piece("Ukiyo-e Gallery/Hokusai - Great Wave.png", "Ukiyo-e Gallery")
    H.eq(stats.gallery, 0)
    scan(orn, deck)
    assert(table.concat(deck.names(), "|"):find(stats.new_print.name, 1, true))
    orn.invalidate(); scan(orn, deck)
    H.eq(stats.gallery, 1); H.eq(stats.shuffles, 1); H.eq(stats.warnings, 0)
end)

H.test("paging, new widgets, invalidation and new scan tables do not reshuffle", function()
    local orn, deck, stats = fixture()
    scan(orn, deck)
    local first = names(deck.order(orn.list()))
    local generation, epoch, writes = deck.generation(), deck.epoch(), stats.writes
    for i = 1, 30 do
        orn.invalidate()
        local copy = {}; for k, entry in ipairs(stats.all) do copy[k] = entry end
        stats.all = copy
        scan(orn, deck)
        H.eq(names(deck.order(orn.list())), first)
    end
    H.eq(stats.shuffles, 1); H.eq(stats.writes, writes)
    H.eq(deck.generation(), generation); H.eq(deck.epoch(), epoch)
    H.eq(stats.authors, 1); H.eq(stats.japan, 1)
end)

H.test("a fresh process module shuffles again against the same persisted settings", function()
    local orn, deck, stats, memory = fixture()
    scan(orn, deck)
    local first = table.concat(memory.ornament_decks._, "|")
    local next_orn, next_deck, next_stats = fixture(stats.all, memory)
    scan(next_orn, next_deck)
    assert(table.concat(memory.ornament_decks._, "|") ~= first)
    H.eq(next_stats.shuffles, 1); H.eq(next_deck.epoch(), 1)
    H.eq(stats.shuffles, 1)
end)

H.test("an empty first scan defers until artwork exists without consuming the startup shuffle", function()
    local orn, deck, stats = fixture({})
    for _ = 1, 3 do scan(orn, deck) end
    H.eq(stats.shuffles, 0); H.eq(stats.writes, 0); H.eq(deck.epoch(), 0)
    stats.all = { pine, cat }
    scan(orn, deck); H.eq(stats.shuffles, 1)
    stats.all = {}; scan(orn, deck)
    stats.all = { pine, cat }; scan(orn, deck)
    H.eq(stats.shuffles, 1)
end)

H.test("manual swaps and explicit shuffles remain stable for the rest of the session", function()
    local orn, deck, stats = fixture()
    scan(orn, deck); assert(deck.swap(pine.name, cat.name))
    local swapped = table.concat(deck.names(), "|")
    for _ = 1, 3 do scan(orn, deck); H.eq(table.concat(deck.names(), "|"), swapped) end
    H.eq(stats.shuffles, 1)
    deck.shuffle()
    local manual = table.concat(deck.names(), "|")
    for _ = 1, 3 do orn.invalidate(); scan(orn, deck); H.eq(table.concat(deck.names(), "|"), manual) end
    H.eq(stats.shuffles, 2); H.eq(deck.epoch(), 2)
end)

H.test("disabled pieces, disabled packs and frequency are never enabled by a shuffle", function()
    local orn, deck, stats, memory = fixture()
    local off, packs_off = { [cat.name] = true }, { Modernists = true }
    memory.ornaments_off, memory.ornament_packs_off = off, packs_off
    orn.setChipFrequency(0)
    scan(orn, deck)
    H.eq(#deck.order(orn.list()), 2)
    H.eq(memory.ornaments_off, off); H.eq(memory.ornament_packs_off, packs_off)
    H.eq(orn.frequency(), 0); H.eq(stats.shuffles, 1)
    off[cat.name] = nil; orn.invalidate()
    H.eq(#deck.order(orn.list()), 3); H.eq(stats.shuffles, 1)
end)

H.test("a single available ornament remains valid without repeatedly saving its order", function()
    local orn, deck, stats = fixture({ cat })
    for _ = 1, 3 do
        orn.invalidate()
        scan(orn, deck)
        H.eq(deck.order(orn.list())[1], cat)
    end
    H.eq(stats.shuffles, 1); H.eq(stats.writes, 1); H.eq(stats.warnings, 0)
end)

H.test("a new mid-session asset uses native insertion rather than another random shuffle", function()
    local orn, deck, stats = fixture({ pine, maple })
    scan(orn, deck)
    stats.all = { pine, maple, cat }; orn.invalidate()
    scan(orn, deck)
    H.eq(deck.names()[1], cat.name); H.eq(stats.shuffles, 1)
end)

H.test("a failed startup shuffle logs once and cannot crash or loop during redraws", function()
    local orn, deck, stats, memory = fixture()
    stats.fail_shuffle = true
    local before = table.concat(memory.ornament_decks._, "|")
    for _ = 1, 5 do H.eq(scan(orn, deck), stats.all) end
    H.eq(stats.shuffles, 1); H.eq(stats.warnings, 1)
    H.eq(table.concat(deck.names(), "|"), before); H.eq(deck.epoch(), 0)
end)

local function widgetMethod(name)
    local f = assert(io.open("components/bookshelf/lib/bookshelf_widget.lua"))
    local source = f:read("*a"); f:close()
    local body = assert(source:match("\n(function BookshelfWidget:" .. name .. "%(.-\nend)\n"))
    local widget = {}
    local env = setmetatable({ BookshelfWidget = widget }, { __index = _G })
    local fn
    if setfenv then fn = assert(loadstring(body)); setfenv(fn, env)
    else fn = assert(load(body, name, "t", env)) end
    fn(); return widget[name]
end

H.test("native page signatures see the shuffle before caching the first rendered page", function()
    local orn, deck, stats = fixture()
    local widget = {
        _cursor = 1, _spine_fetch_cache = {}, _nShelves = function() return 2 end,
        _spineSkip = function() return 0 end, _spinePageFirsts = function() error("Unexpected replan") end,
        _ornKey = widgetMethod("_ornKey"), _ornSig = widgetMethod("_ornSig"),
    }
    local start = widgetMethod("_ornStartState")
    H.eq(start(widget).n, 0)
    H.eq(widget._spine_fetch_cache.orn_sig, widget:_ornSig())
    H.eq(widget._spine_fetch_cache.orn_epoch, deck.epoch())
    scan(orn, deck); deck.order(orn.list())
    widget._cursor = 5
    local states = widget._spine_fetch_cache.page_orn
    states["5:0"], states["9:0"] = { n = 3, shelf = 2, bnd = 1 }, { n = 8, shelf = 4, bnd = 2 }
    for _ = 1, 3 do
        H.eq(start(widget).n, 3)
        H.eq(widget._spine_fetch_cache.page_orn, states)
        H.eq(states["9:0"].n, 8)
    end
    H.eq(stats.shuffles, 1)
end)

H.test("the shuffled native deck still binds busts only to matching authors", function()
    local orn, deck = fixture()
    scan(orn, deck)
    local entries = {
        { author = "James Joyce", w = 60, gap_base = 5 },
        { author = "Other", w = 60, gap_base = 5 },
        { author = "Virginia Woolf", w = 60, gap_base = 5 },
    }
    local env = { entries = entries, dealer = deck.dealer(nil, deck.order(orn.list())),
        level = "always", content_w = 450, n_rows = 2, per_page = 2,
        size = function(_, e) return { entry = e, w = e.w } end,
        space = function(_, pl) return pl.w + 5 end,
    }
    local hooks = deck.fillHooks(env)
    Layout.fillRows({ 60, 60, 60 }, hooks.avail, hooks.gaps, hooks.empty_ok, hooks)
    H.eq((entries[1].lead_ornament or entries[1].ornament).entry, joyce)
    H.eq((entries[3].lead_ornament or entries[3].ornament).entry, woolf)
    H.eq(entries[2].lead_ornament or entries[2].ornament, nil)
    for _, e in ipairs(env.dealer.cards) do H.eq(Authors.pieces[e.name], nil) end
end)

H.test("profile decks survive pruning and shuffle independently once per session", function()
    local orn, deck, stats, memory = fixture()
    local a, b = "orbitui:prose:authors", "orbitui:comics:authors"
    scan(orn, deck, a)
    local first = table.concat(deck.names(a), "|")
    scan(orn, deck, b)
    H.eq(stats.shuffles, 2)
    assert(deck.swap(pine.name, cat.name, a))
    local manual = table.concat(deck.names(a), "|")
    assert(first ~= manual)
    stats.all = { pine, maple, cat, joyce, woolf }
    scan(orn, deck, b); scan(orn, deck, a)
    assert(memory.ornament_decks[a] and memory.ornament_decks[b])
    H.eq(table.concat(deck.names(a), "|"), manual)
    H.eq(stats.shuffles, 2)
end)

H.test("the legacy order migrates without touching unrelated settings", function()
    local memory = { ornament_deck = { pine.name, cat.name },
        ornaments_off = { [pine.name] = true }, library_theme = "custom" }
    local orn, deck, stats = fixture({pine, cat}, memory)
    local key = "orbitui:prose:profile_fiction"
    scan(orn, deck, key)
    H.eq(memory.ornament_deck, nil)
    H.eq(#memory.ornament_decks[key], 2)
    H.eq(memory.ornaments_off[pine.name], true)
    H.eq(memory.library_theme, "custom")
    H.eq(stats.shuffles, 1)
end)

Authors.seed, Japan.seed = author_seed, japan_seed
Gallery.seed = gallery_seed
H.finish()
