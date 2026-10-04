package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Authors = require("core/orbitui_author_ornaments")
local Adapter = require("adapters/orbitui_ornaments")
local Deck = require("lib/bookshelf_ornament_deck")
local Layout = require("lib/bookshelf_spine_layout")
local native = Deck.fillHooks
local joyce = { name = "Modernists/James Joyce.png", pack = "Modernists", w = 54 }
local woolf = { name = "Modernists/Virginia Woolf.png", pack = "Modernists", w = 60 }
local plant = { name = "plant.svg", w = 30 }
local added = {
    { file = "August Strindberg", id = "august strindberg", names = { "August Strindberg", "Johan August Strindberg" } },
    { file = "Stanislaw Lem", id = "stanislaw lem", names = { "Stanis\197\130aw Lem", "STANIS\197\129AW LEM", "Stanislaw Lem" } },
    { file = "Dylan Thomas", id = "dylan thomas", names = { "Dylan Thomas" } },
    { file = "Thomas Mann", id = "thomas mann", names = { "Thomas Mann" } },
    { file = "Fyodor Dostoevsky", id = "fyodor dostoevsky", names = {
        "Fjodor Dostojevskij", "Fjodor Michajlovitj Dostojevskij", "Fyodor Dostoevsky", "Fyodor Dostoyevsky",
        "Fyodor Mikhailovich Dostoyevsky", "Fedor Dostoevsky", "Feodor Dostoevsky", "Fiodor Dostoievski" } },
    { file = "Knut Hamsun", id = "knut hamsun", names = { "Knut Hamsun" } },
    { file = "Clarice Lispector", id = "clarice lispector", names = { "Clarice Lispector" } },
    { file = "Robert Musil", id = "robert musil", names = { "Robert Musil" } },
    { file = "Franz Kafka", id = "franz kafka", names = { "Franz Kafka" } },
}

local function entry(id, name, width, group)
    return { id = id, author = name, book = { filepath = "/book" .. id .. ".epub" },
        w = width or 90, gap_base = 8, orn_seed = group and "group" or nil }
end
local function clone(es, first)
    local out = {}
    for i = first or 1, #es do
        local e = {}; for k, v in pairs(es[i]) do e[k] = v end
        out[#out + 1] = e
    end
    return out
end
local function fixture(es, options)
    local o = options or {}
    local env = { entries = es, dealer = Deck.dealer(Deck.copyState(o.state), o.cards or { joyce, plant, woolf }),
        level = o.level or "always", content_w = o.width or 320,
        max_per_row = o.limit,
        paginating = o.paginating or false, per_page = o.per_page or 2,
        n_rows = o.n_rows or 2, pageKey = function(i) return tostring(es[i].id) end,
        size = function(_, piece, _, cap)
            return { entry = piece, w = math.min(piece.w, cap or math.huge) }
        end,
        space = function(kind, pl) return pl.w + (kind == "lead" and 6 or 12) end,
    }
    local hooks = o.native and native(env) or Authors.fillHooks(native, env)
    local widths = {}; for i, e in ipairs(es) do widths[i] = e.w end
    local rows = Layout.fillRows(widths, hooks.avail, hooks.gaps, hooks.empty_ok, hooks)
    while #rows > env.n_rows do table.remove(rows) end
    hooks.stop()
    return hooks, rows, env, widths
end
local function bust(e) return e.lead_ornament or e.ornament end
local function assertFits(es, rows, hooks, env)
    for r, range in ipairs(rows) do
        local used = 0
        local ornaments = hooks.row_orn[r] and 1 or 0
        local authors = 0
        for i = range.first, range.last do
            local e = es[i]
            used = used + e.w
            if i == range.first then
                if e.lead_ornament then used = used + env.space("lead", e.lead_ornament) end
            else used = used + e.gap_before end
            local pl = bust(e)
            if pl and Authors.pieces[pl.entry.name] then
                authors = authors + 1
                H.eq(Authors.pieces[pl.entry.name], Authors.authorOf(e), "Wrong author beside book")
            elseif pl then
                ornaments = ornaments + 1
            end
        end
        assert(range.empty or used <= hooks.avail(r), "Book/ornament pair exceeds row budget")
        assert(ornaments <= 1, "More than one ordinary ornament on row " .. r)
        assert(authors == 0 or ornaments == 0, "Ordinary decoration mixed with busts on row " .. r)
    end
end

H.test("metadata matches full author names and inverted names without substring guesses", function()
    for _, name in ipairs({ "James Joyce", " JOYCE , James ", "JAMES  JOYCE", "James Joyce\nTranslator" }) do
        H.eq(Authors.authorOf(entry(1, name)), "james joyce")
    end
    for _, name in ipairs({ "Virginia Woolf", "Woolf, Virginia", "Adeline Virginia Woolf" }) do
        H.eq(Authors.authorOf(entry(1, name)), "virginia woolf")
    end
    for _, name in ipairs({ "Joyce Carol Oates", "Leonard Woolf", "About James Joyce", "Joyce", "" }) do
        H.eq(Authors.authorOf(entry(1, name)), nil)
    end
    H.eq(Authors.authorOf({ book = { authors = { "Translator", { name = "Virginia Woolf" } } } }), "virginia woolf")
    H.eq(Authors.authorOf({ book = { author = "James Joyce" } }), "james joyce")
    H.eq(Authors.authorOf({ label = "James Joyce", book = { filepath = "/James Joyce.epub" } }), nil)
end)

H.test("a multi-book folder is not attributed to its representative's author", function()
    local e = { author = "James Joyce", book = { kind = "folder" } }
    H.eq(Authors.authorOf(e), nil)
    e.book._spine_single = true
    H.eq(Authors.authorOf(e), "james joyce")
end)

for _, subject in ipairs(added) do
    H.test("new bust matches full and inverted names: " .. subject.file, function()
        local piece = { name = "Authors/" .. subject.file .. ".png", pack = "Authors", w = 60 }
        H.eq(Authors.pieces[piece.name], subject.id)
        for _, name in ipairs(subject.names) do
            local given, surname = name:match("^(.+) (%S+)$")
            local inverted = surname .. ", " .. given
            for _, variant in ipairs({ name, inverted, name:upper(), "  " .. inverted .. "  " }) do
                H.eq(Authors.authorOf(entry(1, variant)), subject.id)
            end
        end
        local es = { entry(1, subject.names[1]), entry(2, subject.names[#subject.names]), entry(3, "Other") }
        local h, rows, env = fixture(es, { cards = { piece, plant }, width = 650 })
        H.eq(bust(es[1]).entry, piece); H.eq(bust(es[2]), nil); H.eq(bust(es[3]), nil)
        for _, pl in pairs(h.bare(#rows + 1, 7)) do H.eq(pl.entry, plant) end
        assertFits(es, rows, h, env)
    end)
end

H.test("new matches never use surnames, title mentions or similar family names", function()
    for _, name in ipairs({ "Heinrich Mann", "Klaus Mann", "Caitlin Thomas", "Thomas", "Mann", "Lem",
        "About Clarice Lispector", "Robert Musil Foundation", "Translator of Fjodor Dostojevskij",
        "Kafka", "Franz Kafka Society", "Hermann Kafka", "About Franz Kafka" }) do
        H.eq(Authors.authorOf(entry(1, name)), nil)
    end
end)

H.test("busts stand next to matching books only and never on bare shelves", function()
    local es = { entry(1, "Other"), entry(2, "James Joyce"), entry(3, "Virginia Woolf"), entry(4, "Other") }
    local h, rows, env = fixture(es, { n_rows = 5 })
    H.eq(bust(es[1]), nil); H.eq(bust(es[4]), nil)
    H.eq(bust(es[2]).entry, joyce); H.eq(bust(es[3]).entry, woolf)
    for _, pl in pairs(h.row_orn) do H.eq(pl.entry, plant) end
    for _, pl in pairs(h.bare(#rows + 1, 7)) do H.eq(pl.entry, plant) end
    assertFits(es, rows, h, env)
end)

H.test("a contiguous author's run receives one bust, not one per volume", function()
    local es = { entry(1, "James Joyce"), entry(2, "Joyce, James"), entry(3, "Other"), entry(4, "James Joyce") }
    fixture(es, { cards = { joyce }, n_rows = 4, width = 700 })
    H.eq(bust(es[1]).entry, joyce); H.eq(bust(es[2]), nil); H.eq(bust(es[3]), nil)
    H.eq(bust(es[4]).entry, joyce)
end)

H.test("a matching book at a page start gets its own lead ornament", function()
    local es = { entry(1, "Virginia Woolf"), entry(2, "Virginia Woolf") }
    fixture(es, { cards = { woolf } })
    H.eq(es[1].lead_ornament.entry, woolf)
    H.eq(es[1].ornament, nil); H.eq(bust(es[2]), nil)
end)

H.test("off shelves and disabled pieces never force an author ornament", function()
    local es = { entry(1, "James Joyce"), entry(2, "Virginia Woolf") }
    local h = fixture(es, { level = "off" })
    H.eq(bust(es[1]), nil); H.eq(bust(es[2]), nil); H.eq(next(h.row_orn), nil)
    es = { entry(1, "James Joyce"), entry(2, "Virginia Woolf") }
    fixture(es, { cards = { plant } })
    H.eq(bust(es[1]), nil); H.eq(bust(es[2]), nil)
end)

H.test("rare ornament frequency still places a matching bust at its book", function()
    local es = { entry(1, "James Joyce") }
    fixture(es, { cards = { joyce }, level = "rarely" })
    H.eq(bust(es[1]).entry, joyce)
end)

H.test("the released pack takes priority over an enabled trial copy", function()
    local preview = { name = "Modernists-Preview/James Joyce.png", pack = "Modernists-Preview", w = 54 }
    for _, cards in ipairs({ { preview, joyce }, { joyce, preview }, { preview } }) do
        local es = { entry(1, "James Joyce") }
        local h = fixture(es, { cards = cards })
        H.eq(#h.dealer.cards, 0)
        H.eq(bust(es[1]).entry, #cards == 1 and preview or joyce)
    end
end)

H.test("ordinary placement uses the native limited deck away from matching authors", function()
    local es = {}; for i = 1, 30 do es[i] = entry(i, "Other", 85, i % 2 == 0) end
    local a = clone(es); local b = clone(es)
    local ha, ra = fixture(a, { cards = { plant }, native = true, limit = 1, n_rows = 6 })
    local hb, rb = fixture(b, { cards = { joyce, plant, woolf }, n_rows = 6 })
    H.eq(#ra, #rb); H.eq(ha.state().n, hb.state().n)
    for r, range in ipairs(ra) do H.eq(range.first, rb[r].first); H.eq(range.last, rb[r].last) end
    for i = 1, #a do
        H.eq(a[i].gap_before, b[i].gap_before)
        H.eq(bust(a[i]) and bust(a[i]).entry, bust(b[i]) and bust(b[i]).entry)
    end
end)

H.test("narrow rows shrink or omit the bust rather than overlap its book", function()
    for _, w in ipairs({ 100, 130, 150, 170, 240 }) do
        local es = { entry(1, "James Joyce", 100), entry(2, "Virginia Woolf", 100) }
        local h, rows, env = fixture(es, { width = w, n_rows = 8 })
        assertFits(es, rows, h, env)
        if w == 100 then H.eq(bust(es[1]), nil); H.eq(bust(es[2]), nil) end
    end
end)

H.test("native row balancing preserves book-bust adjacency and reserved width", function()
    local es = { entry(1, "Other", 100), entry(2, "James Joyce", 100, true),
        entry(3, "Other", 90), entry(4, "Virginia Woolf", 90, true), entry(5, "Other", 80) }
    local h, rows, env, widths = fixture(es, { width = 330, n_rows = 4, cards = { joyce, woolf } })
    local gaps, lead, no_break, fixed, accept = h.final()
    for i, e in ipairs(es) do
        if e.lead_ornament then H.eq(fixed[i], true) end
        if e.ornament then H.eq(no_break[i], true) end
    end
    local even = Layout.balanceRows(widths, h.avail, gaps, rows[#rows].last, #rows,
        { lead = lead, no_break = no_break, fixed = fixed, row_accept = accept })
    assertFits(es, even or rows, h, env)
end)

H.test("two or three matching busts can share a row without an ordinary decoration", function()
    local kafka = { name = "Authors/Franz Kafka.png", pack = "Authors", w = 60 }
    for _, third in ipairs({ "Other", "Franz Kafka" }) do
        local es = { entry(1, "Other", 90, true), entry(2, "James Joyce", 90, true),
            entry(3, "Virginia Woolf", 90, true), entry(4, third, 90, true) }
        local h, rows, env = fixture(es, { width = 700, cards = { joyce, woolf, kafka, plant } })
        H.eq(#rows, 1); H.eq(bust(es[2]).entry, joyce); H.eq(bust(es[3]).entry, woolf)
        H.eq(bust(es[4]) and bust(es[4]).entry, third == "Franz Kafka" and kafka or nil)
        H.eq(h.row_orn[1], nil); H.eq(h.avail(1), 700)
        H.eq(h.state().n, 0, "Suppressed decorations must not consume the random deck")
        assertFits(es, rows, h, env)
    end
end)

H.test("a mid-row bust replaces the row-end decoration before reserving width", function()
    local es = { entry(1, "Other", 90, true), entry(2, "James Joyce", 90, true),
        entry(3, "Other", 90, true) }
    local h, rows, env = fixture(es, { width = 360 })
    H.eq(#rows, 1); H.eq(h.row_orn[1], nil); H.eq(h.avail(1), 360)
    H.eq(es[2].ornament.entry, joyce); H.eq(bust(es[3]), nil)
    assertFits(es, rows, h, env)
end)

H.test("ordinary row ends and group gaps share one slot at every frequency", function()
    local gaps_seen, ends_seen = 0, 0
    for _, level in ipairs({ "off", "rarely", "often", "always" }) do
        local es = {}; for i = 1, 60 do es[i] = entry(i, "Other", 70, true) end
        local h, rows, env = fixture(es, { width = 400, n_rows = math.huge,
            paginating = true, level = level, cards = { plant } })
        assertFits(es, rows, h, env)
        local dealt = 0
        for _, pl in pairs(h.row_orn) do
            H.eq(pl.entry, plant); dealt = dealt + 1; ends_seen = ends_seen + 1
        end
        for _, e in ipairs(es) do
            if bust(e) then dealt = dealt + 1; gaps_seen = gaps_seen + 1 end
        end
        H.eq(h.state().n, dealt)
        if level == "off" then H.eq(dealt, 0) end
    end
    assert(gaps_seen > 0 and ends_seen > 0, "Both native placement kinds must remain available")
end)

H.test("the limit is opt-in and leaves standalone Bookshelf's native density unchanged", function()
    local es = {}; for i = 1, 5 do es[i] = entry(i, "Other", 50, true) end
    local h, rows = fixture(es, { width = 700, native = true, cards = { plant } })
    local count = h.row_orn[1] and 1 or 0
    for i = rows[1].first, rows[1].last do if bust(es[i]) then count = count + 1 end end
    assert(count > 1, "The native planner must not silently acquire OrbitUI's policy")
end)

H.test("empty and squeezed rows never accumulate decorations or overlap books", function()
    for per_page = 1, 4 do
        local es = {}; for i = 1, 12 do es[i] = entry(i, "Other", 90, true) end
        local h, rows, env = fixture(es, { width = 150, per_page = per_page,
            n_rows = math.huge, paginating = true, cards = { { name = "large.svg", w = 400 } } })
        assertFits(es, rows, h, env)
        H.eq(rows[#rows].last, #es)
        for r, pl in pairs(h.bare(#rows + 1, #rows + 4)) do
            assert(r > #rows); H.eq(pl.entry.name, "large.svg")
        end
    end
end)

H.test("squeezing away an oversized row end cannot deal an unbudgeted lead piece", function()
    local cards = { plant }
    for i = 1, 6 do cards[#cards + 1] = { name = "wide" .. i .. ".svg", w = 600 } end
    local es = { entry(1, "Other", 60, true), entry(2, "Other", 60, true), entry(3, "Other", 90, true) }
    local h, rows, env = fixture(es, { width = 220, n_rows = 8, per_page = 8, cards = cards })
    H.eq(rows[#rows].last, 3)
    H.eq(bust(es[3]), nil)
    assertFits(es, rows, h, env)
end)

H.test("balancing cannot move a mid-row bust onto an already decorated shelf", function()
    local es = { entry(1, "Other", 140), entry(2, "Other", 20), entry(3, "James Joyce", 80),
        entry(4, "Other", 40), entry(5, "Other", 40) }
    local h, rows, env, widths = fixture(es, { width = 360 })
    local gaps, lead, no_break, fixed, accept = h.final()
    local opts = { lead = lead, no_break = no_break, fixed = fixed }
    local unchecked = assert(Layout.balanceRows(widths, h.avail, gaps, #es, #rows, opts))
    assert(not accept(2, unchecked[2].first, unchecked[2].last), "Fixture must reproduce two ornaments")
    opts.row_accept = accept
    local checked = Layout.balanceRows(widths, h.avail, gaps, #es, #rows, opts)
    assertFits(es, checked or rows, h, env)
end)

H.test("the balancer permits several author busts but still enforces their width", function()
    local es = { entry(1, "Other", 70), entry(2, "James Joyce", 90),
        entry(3, "Other", 70), entry(4, "Virginia Woolf", 90) }
    local h, rows, env, widths = fixture(es, { width = 250, cards = { joyce, woolf } })
    local gaps, lead, no_break, fixed, accept = h.final()
    H.eq(bust(es[2]).entry, joyce); H.eq(bust(es[4]).entry, woolf)
    H.eq(accept(1, 1, 4), true)
    local even = Layout.balanceRows(widths, h.avail, gaps, #es, #rows,
        { lead = lead, no_break = no_break, fixed = fixed, row_accept = accept })
    assertFits(es, even or rows, h, env)
end)

H.test("a second bust that does not fit moves with its book instead of disappearing", function()
    local es = { entry(1, "James Joyce", 90), entry(2, "Other", 90), entry(3, "Virginia Woolf", 90) }
    local h, rows, env = fixture(es, { width = 360 })
    H.eq(#rows, 2); H.eq(rows[1].last, 2); H.eq(rows[2].first, 3)
    H.eq(es[1].lead_ornament.entry, joyce); H.eq(es[3].lead_ornament.entry, woolf)
    assertFits(es, rows, h, env)
end)

H.test("whole-library pagination and page renders agree across author and page boundaries", function()
    local cards = { joyce, plant, woolf }
    local names = { "James Joyce", "Virginia Woolf", "Other", "James Joyce" }
    for _, subject in ipairs(added) do
        cards[#cards + 1] = { name = "Authors/" .. subject.file .. ".png", pack = "Authors", w = 60 }
        names[#names + 1] = subject.names[1]
    end
    for _, width in ipairs({ 200, 320, 480 }) do
        for per_page = 1, 3 do
            for _, level in ipairs({ "rarely", "often", "always" }) do
                local es = {}
                for i = 1, 72 do
                    es[i] = entry(i, names[(math.floor((i - 1) / 5) % #names) + 1], 75 + i % 3 * 15, i % 5 == 1)
                end
                local h, rows, env = fixture(es, { width = width, per_page = per_page,
                    n_rows = math.huge, paginating = true, level = level, cards = cards })
                assertFits(es, rows, h, env)
                local state, first, page = nil, 1, 1
                while first <= #es do
                    local slice = clone(es, first)
                    local ph, pr, pe = fixture(slice, { width = width, n_rows = per_page,
                        per_page = per_page, state = state, level = level, cards = cards })
                    assertFits(slice, pr, ph, pe)
                    local cached = h.page_orn[tostring(first)]
                    assert(cached, "Missing page-start ornament state")
                    for _, key in ipairs({ "n", "shelf", "bnd" }) do
                        H.eq(cached[key], (state or Deck.newState())[key])
                    end
                    for r in ipairs(pr) do
                        local full = h.row_orn[(page - 1) * per_page + r]
                        local visible = ph.row_orn[r]
                        H.eq(visible and visible.entry, full and full.entry)
                        H.eq(visible and visible.side, full and full.side)
                    end
                    local page_last = rows[math.min(page * per_page, #rows)].last
                    H.eq(first + pr[#pr].last - 1, page_last, "Page boundary drift: "
                        .. width .. "/" .. per_page .. "/" .. level .. "/page " .. page .. "/first " .. first)
                    for i = 1, pr[#pr].last do
                        local full = es[first + i - 1]
                        H.eq(bust(slice[i]) and bust(slice[i]).entry, bust(full) and bust(full).entry)
                        H.eq(slice[i].gap_before, full.gap_before)
                    end
                    local g, l, nb, fixed, accept = ph.final()
                    local widths = {}; for i, e in ipairs(slice) do widths[i] = e.w end
                    local empty = false; for _, r in ipairs(pr) do empty = empty or r.empty end
                    if not empty then
                        local balanced = Layout.balanceRows(widths, ph.avail, g, pr[#pr].last, #pr,
                            { lead = l, no_break = nb, fixed = fixed, row_accept = accept })
                        assertFits(slice, balanced or pr, ph, pe)
                    end
                    state, first, page = Deck.copyState(ph.state()), page_last + 1, page + 1
                end
            end
        end
    end
end)

H.test("runtime adapter enables the optional limit on the canonical native dealer", function()
    H.eq(Adapter.modules["lib/bookshelf_ornament_deck"], true)
    local wrapped = Adapter.wrap("lib/bookshelf_ornament_deck", { fillHooks = native }, "/active-slot")
    local es = { entry(1, "James Joyce") }
    local env = { entries = es, dealer = Deck.dealer(nil, { joyce }), level = "always",
        content_w = 320, n_rows = 1, per_page = 1, size = function(_, p) return { w = p.w, entry = p } end,
        space = function(_, p) return p.w + 8 end }
    local h = wrapped.fillHooks(env)
    Layout.fillRows({ 90 }, h.avail, h.gaps, h.empty_ok, h)
    H.eq(bust(es[1]).entry, joyce)
    H.eq(Deck.fillHooks, native)
end)

H.test("the real shelf planner forwards the row constraint to the balancer", function()
    local f = assert(io.open("components/bookshelf/lib/bookshelf_spine_shelf.lua"))
    local source = f:read("*a"); f:close()
    assert(source:find("fin_gaps, fin_lead, fin_nb, fin_fixed, fin_accept = hk.final()", 1, true))
    assert(source:find("row_accept = fin_accept", 1, true))
end)
H.finish()
