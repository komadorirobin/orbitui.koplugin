package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
local map = dofile(root .. "/core/orbitui_module_map.lua")
local embedded = getmetatable(map).orbitui_embedded
local function read(name)
    local f = io.open(root .. "/components/simpleui/" .. name .. ".lua", "rb")
    if f then local s = f:read("*a"); f:close(); return s end
    return (assert(embedded[name], name))
end
local function run(source, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(source)), env)() end
    return assert(load(source, "October 30 upstream", "t", env))()
end
local function part(source, first, last)
    local a = assert(source:find(first, 1, true), first)
    return source:sub(a, assert(source:find(last, a + #first, true), last) - 1)
end
local function store(data)
    return { get = function(_, k) return data[k] end,
        set = function(_, k, v) data[k] = v end,
        del = function(_, k) data[k] = nil end,
        isTrue = function(_, k) return data[k] == true end,
        nilOrTrue = function(_, k) return data[k] ~= false end }
end
H.test("all thirteen embedded sources are valid Lua and retain the path-map API", function()
    local count = 0
    for name, source in pairs(embedded) do
        count = count + 1; assert(map[name]); assert((loadstring or load)(source))
        H.eq(source, read(name))
    end
    H.eq(count, 13)
    local n = 0; for _, path in pairs(map) do H.eq(type(path), "string"); n = n + 1 end
    H.eq(n, 396)
end)
H.test("Critter defaults copy only and per-screen picks topics and decorations survive", function()
    local data = { simpleui_hs_critter_pick = "hazel", custom_critter_pick = "suey",
        custom_critter_reactions = false, custom_critter_decor_left = { "lamp" },
        custom_critter_cat_today = false, simpleui_critter_cfg_source = "builtin" }
    local st = store(data)
    local cfg = { readChoice = function(key, _, default) return data[key] or default end }
    local S = run(read("modules/critter/settings"), { unpack = unpack or table.unpack, require = function(n)
        if n == "infra/sui_store" then return st end
        if n == "infra/sui_config" then return cfg end
        if n == "modules/critter/phrases" then return { CATEGORIES = { { id = "today" } } } end
        error(n)
    end })
    S.migrateLegacy(); H.eq(S.pick(), "hazel"); H.eq(data.simpleui_hs_critter_pick, "hazel")
    local scoped = S.forScreen("custom_")
    H.eq(scoped.pick(), "suey"); H.eq(scoped.reactionsOn(), false)
    H.eq(scoped.categoryOn("today"), false); H.eq(scoped.source(), "builtin")
    local ids = scoped.decorIds("left"); ids[1] = "edited"
    H.eq(scoped.decorIds("left")[1], "lamp")
    scoped.setPick("argos"); H.eq(S.pick(), "hazel"); H.eq(scoped.pick(), "argos")
    S.setPick("frankie"); S.migrateLegacy(); H.eq(S.pick(), "frankie")
end)
H.test("Android native Bluetooth API stays read-only and cached", function()
    local reads = 0
    local bt = run(read("screens/sui_bluetooth"), { require = function(n)
        H.eq(n, "device")
        return { hasBluetoothToggle = function() return true end,
            isBluetoothOn = function() reads = reads + 1; return true end }
    end, io = { popen = function() error("Android must not launch platform probes") end } })
    H.eq(bt.isAvailable(), true); H.eq(bt.isOn(), true); H.eq(bt.isOn(), true); H.eq(reads, 1)
    bt.setState(false); H.eq(bt.isOn(), false); bt.reset(); H.eq(bt.isOn(), true); H.eq(reads, 2)
end)
H.test("unavailable Kindle Bluetooth is not misreported as an available backend", function()
    local bt = run(read("screens/sui_bluetooth"), { require = function(n)
        if n == "device" then return { isKindle = function() return true end } end
        error("unavailable")
    end, io = { popen = function() return nil end } })
    H.eq(bt.isAvailable(), false); H.eq(bt.isOn(), false)
end)
H.test("menu pruning restores order and protects shared settings and Quick Settings", function()
    local deps = { ["infra/sui_store"] = store({}), ["infra/sui_i18n"] = {
        translate = function(s) return s end, ngettext = function(s) return s end },
        ["infra/sui_menu_hooks"] = {} }
    local hide = run(read("features/sui_menu_hide"), { require = function(n) return assert(deps[n], n) end })
    local settings = { id = "orbitui_settings", text = "OrbitUI" }
    local tabs = { { id = "tools", settings }, { id = "filemanager" }, { id = "_sui_qs_panel" } }
    local log = {}
    hide.prune(tabs, { tools = true, orbitui_settings = true, filemanager = true, _sui_qs_panel = true }, log)
    H.eq(#tabs, 2); H.eq(tabs[1][1], settings); H.eq(tabs[2].id, "_sui_qs_panel")
    hide.restore(log); H.eq(#tabs, 3); H.eq(tabs[2].id, "filemanager")
    local tree = hide.extractTree({ { id = "tab", { id = "dynamic", text_func = function()
        error("must not inspect native values/providers") end } } })
    H.eq(tree[1].children[1].text, "dynamic")
end)
H.test("menu hiding teardown restores both live menus and cancels deferred snapshots", function()
    local data, steps, queued, unscheduled = {}, {}, {}, 0
    local menu = { tab_item_table = { { id = "filemanager" }, { id = "tools" } } }
    local ui = { scheduleIn = function(_, _, fn, arg) queued[#queued + 1] = { fn, arg } end,
        unschedule = function() unscheduled = unscheduled + 1 end }
    local deps = { ["infra/sui_store"] = store(data),
        ["infra/sui_i18n"] = { translate = function(s) return s end, ngettext = function(s) return s end },
        ["infra/sui_menu_hooks"] = { TARGET = { FM = "fm", READER = "reader" },
            ORDER = { MENU_HIDE = 5, TAB_LAYOUT = 30 }, register = function(s) steps[#steps + 1] = s end },
        ["ui/uimanager"] = ui, ["features/sui_style"] = { SLOTS = {} } }
    local hide = run(read("features/sui_menu_hide"), {
        require = function(n) return assert(deps[n], n) end,
        package = { loaded = { ["apps/reader/readerui"] = { instance = { menu = menu } } } } })
    local a, b = {}, {}; hide.install(a); hide.install(b)
    data.simpleui_menu_hidden_reader = { filemanager = true }
    steps[1].prepare(menu, "reader"); H.eq(#menu.tab_item_table, 1)
    hide.uninstall(a); H.eq(#menu.tab_item_table, 1); hide.uninstall(b)
    H.eq(#menu.tab_item_table, 2); H.eq(unscheduled, 1)
    for _, task in ipairs(queued) do task[1](task[2]) end -- no disk write after teardown
end)
H.test("new Critter games are pure and preserve UTF-8 bounded quote selection", function()
    local games = run(read("modules/critter/games"))
    local fixed = function() return 1 end
    local move, outcome = games.rps("paper", fixed); H.eq(move, "rock"); H.eq(outcome, "win")
    local side, right = games.coin("heads", fixed); H.eq(side, "heads"); H.eq(right, true)
    local quote = games.pickQuote({ { q = string.rep("å", 120) }, { q = "Kort", a = "A" } }, fixed)
    H.eq(quote.q, "Kort")
    H.eq(games.quiz({ { q = "Q", a = "A" } }, fixed), nil)
end)
H.test("Critter current book respects hidden recent entries and a thirty-item bound", function()
    local hist, probes = {}, 0
    for i = 1, 31 do hist[i] = { file = "/" .. i, time = 0 } end
    local deps = { ["libs/libkoreader-lfs"] = { attributes = function(path)
        probes = probes + 1; return path == "/31" and "file" or nil end },
        ["modules/module_books_shared"] = {},
        ["features/library/sui_recent_hidden"] = { snapshot = function() return { ["/1"] = true } end } }
    local book = run(read("modules/critter/book"), { require = function(n) return assert(deps[n], n) end,
        package = { loaded = { readhistory = { hist = hist } } } })
    H.eq(book.current(100), nil); H.eq(probes, 29)
    H.eq(book.facts("Title", 0.5, nil, 100), nil)
    H.eq(book.facts("Title", 0.5, 0, 100).percent, 50)
end)
H.test("grid quick actions stay opt-in and capacity follows its own screen", function()
    local data = {}; local SUISettings = store(data)
    local cfg = { readChoice = function(k, _, d) return data[k] or d end,
        readClampedInt = function(k, lo, hi, d) return math.max(lo, math.min(hi, data[k] or d)) end }
    local source = read("modules/module_quick_actions")
    local code = part(source, "local MAX_QA_ITEMS =", "-- Smallest gap") ..
        part(source, "-- Grid of an instance", "-- ---------------------------------------------------------------------------\n-- Action entry") .. "\nreturn _maxItems"
    local capacity = run(code, { Config = cfg, SUISettings = SUISettings })
    H.eq(capacity("qa_1", "home_"), 6)
    data.home_qa_1_layout = "grid"; data.home_qa_1_grid_cols = 7; data.home_qa_1_grid_rows = 4
    H.eq(capacity("qa_1", "home_"), 28); H.eq(capacity("qa_1", "other_"), 6)
end)
H.test("boot warming is inert after navigation reader suspend rotation or teardown", function()
    local source = read("infra/sui_patches")
    local code = part(source, "                    local owner, fm = _live_plugin, liveFM()", "                end)\n                return")
    local function fixture(change)
        local queue, calls, plugin, fm, instance = {}, {}, {}, {}, {}
        local ui = { scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end,
            nextTick = function(_, fn) queue[#queue + 1] = fn end }
        local env = { _live_plugin = plugin, _hs_boot_done = true,
            HS = { _instance = instance }, UIManager = ui,
            liveFM = function() return fm end, isAppExiting = function() return false end,
            _materializeLazyListing = function() calls.list = true end,
            _warmFolderCovers = function(valid) H.eq(valid(), true); calls.warm = true end,
            package = { loaded = {} } }
        run(code, env)
        change(env, plugin, instance)
        for _i = 1, 2 do local fn = table.remove(queue, 1); if fn then fn() end end
        return calls
    end
    local normal = fixture(function() end); H.eq(normal.list, true); H.eq(normal.warm, true)
    for _, change in ipairs({
        function(e) e.UIManager._simpleui_navigation_generation = 1 end,
        function(e) e.package.loaded["apps/reader/readerui"] = { instance = {} } end,
        function(_, p) p._simpleui_suspended = true end,
        function(e) e.HS._instance = {} end,
        function(e) e._hs_boot_done = false end,
        function(e) e._live_plugin = {} end,
        function(_, _, i) i._parked = true end,
    }) do local calls = fixture(change); H.eq(calls.list, nil); H.eq(calls.warm, nil) end
end)
H.test("folder warm-up runs one bounded visible entry per tick and cancels on path changes", function()
    local source = part(read("features/library/sui_foldercovers"), "function M.warmFolderListings", "-- Collect up to")
    local queue, probes, valid = {}, 0, true
    local M = { isEnabled = function() return true end }
    run(source, { M = M, _isRealFolder = function() return true end,
        _resolveStyle = function() end, CoverFinder = { getDirSummary = function() probes = probes + 1 end },
        require = function() return { nextTick = function(_, fn) queue[#queue + 1] = fn end } end })
    local fc = { item_table = {}, path = "/a", page = 1, perpage = 100 }
    for i = 1, 100 do fc.item_table[i] = { path = "/a/" .. i } end
    M.warmFolderListings(fc, function() return valid end); H.eq(probes, 1)
    fc.path = "/b"; table.remove(queue, 1)(); H.eq(probes, 1)
    fc.path = "/a"; M.warmFolderListings(fc, function() return valid end)
    while #queue > 0 do table.remove(queue, 1)() end
    H.eq(probes, 65) -- one first attempt, then at most 64 entries
end)
H.test("plural header parser supports Swedish and chained Slavic and ternary forms", function()
    local source = part(read("infra/sui_i18n"), "local function parsePluralExpression", "local function parsePO")
    local parse = run(source .. "\nreturn parsePluralExpression")
    local sv = assert(parse("nplurals=2; plural=(n != 1);"))
    H.eq(sv(1), 0); H.eq(sv(2), 1); H.eq(sv(0), 1)
    local ru = assert(parse("nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;"))
    H.eq(ru(1), 0); H.eq(ru(2), 1); H.eq(ru(11), 2); H.eq(ru(21), 0)
    local nested = assert(parse("nplurals=3; plural=n==1 ? n<2 ? 0 : 1 : 2;"))
    H.eq(nested(1), 0); H.eq(nested(5), 2)
    for _, lang in ipairs({ "ru", "pl", "cs", "lt_LT", "uk" }) do
        local f = assert(io.open(root .. "/components/simpleui/locale/" .. lang .. ".po"))
        local po = f:read("*a"); f:close()
        local fn = assert(parse(assert(po:match('Plural%-Forms: (.-)\\n'))), lang)
        for n = 0, 200 do
            local expected
            if lang == "cs" then expected = n == 1 and 0 or (n >= 2 and n <= 4 and 1 or 2)
            elseif lang == "pl" then expected = n == 1 and 0 or (n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20) and 1 or 2)
            elseif lang == "lt_LT" then expected = n % 10 == 1 and n % 100 ~= 11 and 0 or (n % 10 >= 2 and (n % 100 < 10 or n % 100 >= 20) and 1 or 2)
            else expected = n % 10 == 1 and n % 100 ~= 11 and 0 or (n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 12 or n % 100 > 14) and 1 or 2) end
            H.eq(fn(n), expected, lang .. " plural " .. n)
        end
    end
end)
H.test("long action-sheet messages scroll within half of the native page height", function()
    local freed, args, scrolling = 0, nil, 0
    local TextBoxWidget = { new = function(_, opts)
        return { getSize = function() return { h = #opts.text } end,
            free = function() freed = freed + 1 end }
    end }
    local code = part(read("engines/sui_action_sheet"), "local MESSAGE_MAX_SHARE", "-- Message line:")
    local build = run(code .. "\nreturn buildMessage", {
        TextBoxWidget = TextBoxWidget, Font = { getFace = function() return {} end },
        SUIStyle = { FS_BODY = 16, FS_DETAIL = 12 }, COLOR = { text_primary = {} },
        require = function(n) H.eq(n, "ui/widget/scrolltextwidget"); return { new = function(_, opts)
            args = opts; scrolling = scrolling + 1; return opts end } end })
    local ctx = { page_h = 100, inner_w = 200, SZ = function(v) return v end }
    build(ctx, "Short", true); H.eq(freed, 0); H.eq(scrolling, 0)
    local dialog = {}; build(ctx, string.rep("L", 200), false, nil, dialog)
    H.eq(freed, 1); H.eq(scrolling, 1); H.eq(args.height, 50); H.eq(args.dialog, dialog)
end)
H.test("page-turn totals reuse the existing aggregate query without changing distinct-page counts", function()
    local code = part(read("modules/module_stats_provider"), "local function fetchTimeSeries", "-- ---------------------------------------------------------------------------\n-- Query 2")
    local fetch = run(code .. "\nreturn fetchTimeSeries", { rownum = function(v) return tonumber(v) or 0 end,
        Perf = { mark = function() end }, logger = { warn = function() end } })
    local queries, fail = {}, false
    local conn = { exec = function(_, sql)
        queries[#queries + 1] = sql
        if fail then error("database is locked") end
        if #queries == 1 then return { { 40 }, { 2 }, { 90 }, { 3 }, { 90 }, { 3 }, { 90 }, { 3 } } end
        return { { 100 }, { 200 }, { 8 }, { 3 } }
    end }
    local stats, err = fetch(conn, 1, 2, 3, "2026-10-30", "2026-10-26", "2026-10-01", "2026-10-24")
    H.eq(err, nil); H.eq(#queries, 2); H.eq(stats.today_pages, 2); H.eq(stats.total_turns, 8)
    H.eq(stats.today_turns, 3); assert(queries[2]:find("start_time >= 3", 1, true))
    fail = true; local _, failure = fetch(conn, 1, 2, 3, "today", "week", "month", "rolling")
    assert(failure:find("database is locked", 1, true)) -- no successful-zero signal
end)
H.test("Critter panel suggestions cannot open a book after a newer reader or navigation", function()
    local code = part(read("modules/critter/panel_row"), "local function openBook", "-- Opens the settings")
    local queue, opens, reader, rui = {}, 0, {}, {}
    rui.instance = reader; reader.switchDocument = function(_, file) H.eq(file, "/book.epub"); opens = opens + 1 end
    local ui = { nextTick = function(_, fn) queue[#queue + 1] = fn end }
    local open = run(code .. "\nreturn openBook", { UIManager = ui,
        package = { loaded = { ["apps/reader/readerui"] = rui } },
        VirtualPaths = { toVirtual = function(file) return file end } })
    local menu = { onClose = function() end }
    open(menu, "/book.epub"); table.remove(queue, 1)(); H.eq(opens, 1)
    open(menu, "/book.epub"); rui.instance = {}; table.remove(queue, 1)(); H.eq(opens, 1)
    rui.instance = reader; open(menu, "/book.epub"); ui._simpleui_navigation_generation = 1
    table.remove(queue, 1)(); H.eq(opens, 1)
end)
H.test("raw alpha scan respects both pixel strides and row padding", function()
    local code = part(read("modules/critter/sprite"), "local function transparentFoot", "-- RasterCache entry")
    for _, bpp in ipairs({ 2, 4 }) do
        local bytes, stride = {}, bpp * 3 + 4
        for i = 0, stride * 4 - 1 do bytes[i] = 255 end
        for y = 2, 3 do for x = 0, 2 do bytes[y * stride + x * bpp + bpp - 1] = 0 end end
        local pointer
        pointer = function(offset) return setmetatable({}, {
            __add = function(_, n) return pointer(offset + n) end,
            __index = function(_, n) return bytes[offset + n] end,
        }) end
        local scan = run(code .. "\nreturn transparentFoot", { has_ffi = true,
            ffi = { cast = function() return pointer(0) end },
            Blitbuffer = { TYPE_BB8A = 2, TYPE_BBRGB32 = 4 } })
        H.eq(scan({ data = bytes, stride = stride, getType = function() return bpp end,
            getWidth = function() return 3 end, getHeight = function() return 4 end,
            getPixel = function() error("raw scan must not allocate pixel wrappers") end }), 2)
    end
end)
H.test("new visible menu and page-turn controls translate in Swedish without global gettext replacement", function()
    local native = function(s) return s end
    local deps = { logger = { info = function() end, warn = function() end, dbg = function() end },
        gettext = native, util = { trim = function(s) return s:match("^%s*(.-)%s*$") end },
        ["infra/sui_paths"] = { getPluginDir = function() return root .. "/components/simpleui/" end } }
    local i18n = run(read("infra/sui_i18n"), { require = function(n) return assert(deps[n], n) end,
        G_reader_settings = { readSetting = function() return "sv" end } })
    for _, text in ipairs({ "Hide Menu Items", "Show this menu", "Show All Items", "Reader",
        "Pages turned", "Total pages turned", "Show Tiny Critter", "Tiny Critter Settings", "Let's play", "Guess the author" }) do
        assert(i18n.translate(text) ~= text, text)
    end
    H.eq(i18n.ngettext("%d hidden", "%d hidden", 2), "%d dolda"); H.eq(native("Reader"), "Reader")
end)
H.finish()
