package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Adapter = require("adapters/orbitui_ornaments")
local Authors = require("core/orbitui_author_ornaments")
local Japan = require("core/orbitui_japan_ornaments")
local Layout = require("lib/bookshelf_spine_layout")
local author_seed, japan_seed = Authors.seed, Japan.seed
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
    local memory = saved or { ornament_deck = {} }
    if not saved then
        for i, entry in ipairs(all) do memory.ornament_deck[i] = entry.name end
    end
    local stats = { writes = 0, shuffles = 0, warnings = 0, authors = 0, japan = 0,
        scans = 0, all = all, packs = { "Japan", "Modernists" } }
    local store = {
        read = function(key) return memory[key] end,
        save = function(key, value)
            H.eq(key, "ornament_deck", "session shuffle may only save the deck")
            memory[key] = value; stats.writes = stats.writes + 1
        end,
    }
    package.loaded.logger = { warn = function() stats.warnings = stats.warnings + 1 end }
    package.loaded["lib/bookshelf_settings_store"] = store
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

H.test("loading the adapter does no eager catalogue work or settings writes", function()
    local _, deck, stats = fixture()
    H.eq(stats.scans, 0); H.eq(stats.shuffles, 0); H.eq(stats.writes, 0)
    H.eq(stats.authors, 0); H.eq(stats.japan, 0); H.eq(deck.epoch(), 0)
end)

H.test("the first listing shuffles once and preserves the native list identities", function()
    local orn, deck, stats, memory = fixture()
    local before = table.concat(memory.ornament_deck, "|")
    local all, packs = orn.listAll()
    H.eq(all, stats.all); H.eq(packs, stats.packs)
    assert(table.concat(memory.ornament_deck, "|") ~= before)
    H.eq(#memory.ornament_deck, #all); H.eq(deck.epoch(), 1)
    H.eq(stats.shuffles, 1); H.eq(stats.writes, 1)
    H.eq(stats.authors, 1); H.eq(stats.japan, 1)
    H.eq(names(orn.list()), names(orn.list()), "native enabled-pool caching remains stable")
end)

H.test("newly seeded pieces are reconciled before the startup shuffle", function()
    local orn, deck, stats, memory = fixture({ joyce, maple })
    stats.new_piece = cat
    memory.ornament_deck[#memory.ornament_deck + 1] = "deleted.svg"
    orn.listAll()
    local result = table.concat(deck.names(), "|")
    assert(result:find(cat.name, 1, true)); assert(not result:find("deleted.svg", 1, true))
    H.eq(#deck.names(), 3); H.eq(stats.shuffles, 1)
    H.eq(names(deck.order(orn.list())), result)
end)

H.test("paging, new widgets, invalidation and new scan tables do not reshuffle", function()
    local orn, deck, stats = fixture()
    local first = names(deck.order(orn.list()))
    local generation, epoch, writes = deck.generation(), deck.epoch(), stats.writes
    for i = 1, 30 do
        orn.invalidate()
        local copy = {}; for k, entry in ipairs(stats.all) do copy[k] = entry end
        stats.all = copy
        deck.sync(orn.listAll())
        H.eq(names(deck.order(orn.list())), first)
    end
    H.eq(stats.shuffles, 1); H.eq(stats.writes, writes)
    H.eq(deck.generation(), generation); H.eq(deck.epoch(), epoch)
    H.eq(stats.authors, 1); H.eq(stats.japan, 1)
end)

H.test("a fresh process module shuffles again against the same persisted settings", function()
    local orn, _, stats, memory = fixture()
    orn.listAll()
    local first = table.concat(memory.ornament_deck, "|")
    local next_orn, next_deck, next_stats = fixture(stats.all, memory)
    next_orn.listAll()
    assert(table.concat(memory.ornament_deck, "|") ~= first)
    H.eq(next_stats.shuffles, 1); H.eq(next_deck.epoch(), 1)
    H.eq(stats.shuffles, 1)
end)

H.test("an empty first scan defers until artwork exists without consuming the startup shuffle", function()
    local orn, deck, stats = fixture({})
    for _ = 1, 3 do orn.listAll() end
    H.eq(stats.shuffles, 0); H.eq(stats.writes, 0); H.eq(deck.epoch(), 0)
    stats.all = { pine, cat }
    orn.listAll(); H.eq(stats.shuffles, 1)
    stats.all = {}; orn.listAll()
    stats.all = { pine, cat }; orn.listAll()
    H.eq(stats.shuffles, 1)
end)

H.test("manual swaps and explicit shuffles remain stable for the rest of the session", function()
    local orn, deck, stats = fixture()
    orn.listAll(); assert(deck.swap(pine.name, cat.name))
    local swapped = table.concat(deck.names(), "|")
    for _ = 1, 3 do orn.listAll(); H.eq(table.concat(deck.names(), "|"), swapped) end
    H.eq(stats.shuffles, 1)
    deck.shuffle()
    local manual = table.concat(deck.names(), "|")
    for _ = 1, 3 do orn.invalidate(); orn.list(); H.eq(table.concat(deck.names(), "|"), manual) end
    H.eq(stats.shuffles, 2); H.eq(deck.epoch(), 2)
end)

H.test("disabled pieces, disabled packs and frequency are never enabled by a shuffle", function()
    local orn, deck, stats, memory = fixture()
    local off, packs_off = { [cat.name] = true }, { Modernists = true }
    memory.ornaments_off, memory.ornament_packs_off = off, packs_off
    orn.setChipFrequency(0)
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
        H.eq(deck.order(orn.list())[1], cat)
    end
    H.eq(stats.shuffles, 1); H.eq(stats.writes, 1); H.eq(stats.warnings, 0)
end)

H.test("a new mid-session asset uses native insertion rather than another random shuffle", function()
    local orn, deck, stats = fixture({ pine, maple })
    orn.listAll()
    stats.all = { pine, maple, cat }; orn.invalidate()
    deck.sync(orn.listAll())
    H.eq(deck.names()[1], cat.name); H.eq(stats.shuffles, 1)
end)

H.test("a failed startup shuffle logs once and cannot crash or loop during redraws", function()
    local orn, deck, stats, memory = fixture()
    stats.fail_shuffle = true
    local before = table.concat(memory.ornament_deck, "|")
    for _ = 1, 5 do H.eq(orn.listAll(), stats.all) end
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
    deck.sync(orn.listAll()); deck.order(orn.list())
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

Authors.seed, Japan.seed = author_seed, japan_seed
H.finish()
