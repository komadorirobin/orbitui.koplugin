package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = assert(io.open("components/simpleui/" .. path))
    local src = f:read("*a"); f:close(); return src
end
local function run(code, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then
        local fn = assert(loadstring(code)); setfenv(fn, env); return fn()
    end
    return assert(load(code, "October 9 upstream regression", "t", env))()
end
local function section(src, first, last)
    local start = assert(src:find(first, 1, true))
    return src:sub(start, assert(src:find(last, start, true)) - 1)
end
local function method(src, first)
    local start = assert(src:find(first, 1, true))
    return src:sub(start, assert(src:find("\nend", start, true)) + 3) .. "\n"
end
local noop = function() end

local PageState = run(section(read("engines/sui_section_label.lua"),
    "local PageState = {}", "-- Descriptor") .. "\nreturn PageState", { M = {} })
H.test("new page state preserves legacy pages when count is set first", function()
    local ctx = { _row_page_bookorbit_want = 3, _row_npages_bookorbit_want = 4 }
    PageState.setCount(ctx, "bookorbit_want", 5)
    local page, count = PageState.get(ctx, "bookorbit_want")
    H.eq(page, 3); H.eq(count, 5)
    PageState.setPage(ctx, "bookorbit_want", 1)
    H.eq(ctx._row_page_bookorbit_want, 1)
    H.eq(ctx._row_npages_bookorbit_want, 5)
    H.eq(PageState.get({}, "bookorbit_want"), 1)
end)

local cfg = read("infra/sui_config.lua")
local memory, native = {}, { start_with = "filemanager" }
local store = {
    get = function(_, k) return memory[k] end,
    set = function(_, k, v) memory[k] = v end,
    readSetting = function(_, k, default) if memory[k] == nil then return default end; return memory[k] end,
    saveSetting = function(_, k, v) memory[k] = v end,
    isTrue = function(_, k) return memory[k] == true end,
    flush = noop,
}
local Config = { saveTopbarConfig = noop }
local config_env = { M = Config, SUISettings = store, math_max = math.max,
    math_min = math.min, math_floor = math.floor,
    G_reader_settings = { readSetting = function(_, k) return native[k] end,
        saveSetting = function(_, k, v) native[k] = v end } }
run(section(cfg, "local START_WITH_KEY", "function M.homeLabel") ..
    method(cfg, "function M.applyFirstRunDefaults()"), config_env)
run(section(cfg, "local SCALE_MIN", "-- Navigation Bar Size") ..
    section(cfg, 'local BADGE_SCALE_KEY_SUFFIX', '-- Element Scale'), config_env)

H.test("book-close preference migrates once without changing startup or library settings", function()
    for _, sample in ipairs({
        { start = "homescreen_simpleui", folder = false, expected = "homescreen" },
        { start = "filemanager", folder = false, expected = "library" },
        { start = "last", folder = true, expected = "book_folder" },
    }) do
        memory = { simpleui_onboarding_done = true,
            simpleui_hs_return_to_book_folder = sample.folder, simpleui_tb_style = "classic" }
        native = { start_with = sample.start, book_grid_width = 5 }
        Config.applyFirstRunDefaults()
        H.eq(Config.getBookCloseTarget(), sample.expected)
        H.eq(native.start_with, sample.start); H.eq(native.book_grid_width, 5)
        Config.setBookCloseTarget("book_folder")
        Config.applyFirstRunDefaults()
        H.eq(Config.getBookCloseTarget(), "book_folder")
        H.eq(memory.simpleui_hs_return_to_book_folder, sample.folder)
        H.eq(memory.simpleui_tb_style, "classic")
    end
    local main = read("main.lua")
    assert(not main:find('saveSetting("simpleui_tb_style", "tabs")', 1, true))
    assert(not main:find("Config.applyFirstRunLibraryDefaults()", 1, true))
end)
H.test("legacy grid badge scale remains readable without changing other badge defaults", function()
    memory = { simpleui_bookgrid_badge_scale = 165 }
    H.eq(Config.getBadgeScalePct("recent"), 150)
    H.eq(Config.getBadgeScalePct("currently"), 100)
    H.eq(Config.getBadgeScalePct("coverdeck"), 100)
    H.eq(memory.simpleui_hs_recent_badge_scale, nil)
    Config.setBadgeScale(90, "recent", "custom_")
    H.eq(Config.getBadgeScalePct("recent", "custom_"), 90)
    H.eq(Config.getBadgeScalePct("recent"), 150)
    H.eq(memory.simpleui_bookgrid_badge_scale, 165)
end)

local titlebar = read("screens/sui_titlebar.lua")
H.test("classic titlebar retains old menu and back icons while tabs is opt-in", function()
    memory = {}
    local M = { STYLE_CLASSIC = "classic", STYLE_TABS = "tabs" }
    run(method(titlebar, "function M.getStyle()"),
        { M = M, STYLE_KEY = "simpleui_tb_style", SUISettings = store })
    H.eq(M.getStyle(), "classic")
    local icons = { back = "new-back", menu = "new-menu", ko_menu = "old-menu" }
    local selected
    local back, menu = run(method(titlebar, "local function _backIcon()") ..
        method(titlebar, "local function _applyMenuIcon(btn)") .. "\nreturn _backIcon, _applyMenuIcon", {
        M = M, Config = { ICON = icons }, require = function() return { mirroredUILayout = function() return false end } end,
        SUIStyle = function() return { applyIconToBtn = function() return false end,
            restoreDefaultIcon = function(_, _, file) selected = file end } end,
    })
    H.eq(back().icon, "chevron.left"); menu({}); H.eq(selected, "old-menu")
    memory.simpleui_tb_style = "tabs"
    H.eq(back().file, "new-back"); menu({}); H.eq(selected, "new-menu")
end)

local patches = read("infra/sui_patches.lua")
local acquire, add, release, inset = run(
    section(patches, "local function _acquireHooks", "-- Ensure the goal-tap") ..
    'local MENU_WIDTH_FIELDS = { "width", "screen_w" }\n' ..
    method(patches, "local function _withInsetWidth(") ..
    "\nreturn _acquireHooks, _addHook, _releaseHooks, _withInsetWidth")
H.test("shared hooks install once across hosts and survive out-of-order teardown", function()
    local calls = 0
    local original = function() calls = calls + 1 end
    local target, fm, reader = { init = original }, {}, {}
    local state = acquire(target, "state", fm)
    local wrapper = function() original() end
    add(state, target, "init", wrapper)
    H.eq(acquire(target, "state", reader), nil)
    H.eq(acquire(target, "state", fm), nil)
    target.init(); H.eq(calls, 1)
    H.eq(release(target, "state", fm), false); H.eq(target.init, wrapper)
    H.eq(release(target, "state", reader), true); H.eq(target.init, original)
end)
H.test("hook release does not erase a later external wrapper", function()
    local target, owner = {}, {}
    local state = acquire(target, "state", owner)
    add(state, target, "init", noop)
    local external = function() end
    target.init = external
    release(target, "state", owner)
    H.eq(target.init, external)
end)
H.test("library width insets restore native geometry after success and failure", function()
    local menu = { width = 1000, screen_w = 1000, inner_dimen = { w = 980 } }
    for i = 1, 3 do
        H.eq(inset(menu, 20, function(m)
            H.eq(m.width, 960); H.eq(m.screen_w, 960); H.eq(m.inner_dimen.w, 940)
            return "built"
        end), "built")
        H.eq(menu.width, 1000); H.eq(menu.inner_dimen.w, 980)
    end
    assert(not pcall(inset, menu, 20, function() error("failed build") end))
    H.eq(menu.width, 1000); H.eq(menu.screen_w, 1000); H.eq(menu.inner_dimen.w, 980)
end)

local stamp, fail, queries, finalized = "db:1/wal:1", false, 0, 0
local row = { "/books/", "one.epub", "One", "Author", "Series", 1, "Fiction" }
local filter = {
    parseSeries = function(s) return s end, seriesKey = function(s) return s end,
    isDimension = function(d) return d == "author" end, DIMENSIONS = { author = "authors" },
    eachFacetValue = function(r, key, add) add(r[key], r[key]) end,
}
local Metadata = run(read("features/library/sui_metadata_source.lua"), { require = function(name)
    if name == "features/library/sui_bim_stamp" then return { get = function() return stamp end } end
    if name == "features/library/sui_filter_state" then return filter end
    if name == "ffi/util" then return { strcoll = function(a, b) return a < b end } end
    if name == "logger" then return { warn = noop } end
    error("no Calibre metadata")
end })
local bim = { openDbConnection = noop, db_conn = { prepare = function()
    queries = queries + 1
    local emitted = false
    return { bind = noop, step = function()
        if fail then error("database locked") end
        if not emitted then emitted = true; return row end
    end, finalize = function() finalized = finalized + 1 end }
end } }
H.test("transient SQL failure never poisons matching, facet or validated caches", function()
    local accept = function() return true end
    for _, fetch in ipairs({
        function() return Metadata.getMatchingFiles(bim, "/books") end,
        function() return Metadata.getFacetValues(bim, "/books", "author") end,
        function() return Metadata.getValidRows(bim, "/books", nil, "all", accept) end,
        function() return Metadata.getValidFacetCounts(bim, "/books", "author", nil, "all", accept) end,
    }) do
        Metadata.clearCache(); fail = true
        H.eq(next((fetch())), nil)
        fail = false
        assert(next((fetch())), "same DB stamp must allow retry")
        local count = queries; fetch(); H.eq(queries, count)
    end
    H.eq(finalized, queries)
end)
H.test("a WAL change invalidates validated metadata even with unchanged main DB", function()
    fail = false; Metadata.clearCache()
    local first = Metadata.getMatchingFiles(bim, "/books")
    H.eq(first[1].title, "One")
    first[1] = nil
    H.eq(#Metadata.getMatchingFiles(bim, "/books"), 1)
    row[3] = "Updated"; stamp = "db:1/wal:2"
    H.eq(Metadata.getMatchingFiles(bim, "/books")[1].title, "Updated")
end)

local cover_fail, reads, cover_exists = false, 0, true
local Finder = run(read("features/library/sui_cover_finder.lua"), {
    G_reader_settings = { readSetting = function() return "strcoll" end, isTrue = function() return false end },
    require = function(name)
        if name == "libs/libkoreader-lfs" then return { attributes = function() return 1 end } end
        if name == "features/library/sui_bim_stamp" then return { get = function() return stamp end } end
        if name == "ui/widget/filechooser" then return {} end
        error(name)
    end,
})
local menu = { genItemTableFromPath = function() return { { path = "/books/one.epub", is_file = true } } end }
local covers = { getBookInfo = function()
    reads = reads + 1
    if cover_fail then error("database locked") end
    return { cover_bb = cover_exists and {} or nil, has_cover = cover_exists,
        cover_fetched = true, cover_w = 100, cover_h = 150 }
end }
H.test("folder cover searches retry DB failures without restart or stamp changes", function()
    for _, fetch in ipairs({
        function() return Finder.findFirstCover(menu, "/books", covers) end,
        function() return Finder.collectCovers(menu, "/books", 4, covers, true)[1] end,
        function() return Finder.findCoverRecursive(menu, "/books", 0, 3, covers) end,
    }) do
        Finder.clearCache(); cover_fail = true
        H.eq(fetch(), nil)
        cover_fail = false
        assert(fetch())
    end
end)
H.test("confirmed missing folder covers remain cached until database changes", function()
    Finder.clearCache(); cover_exists = false
    H.eq(Finder.findFirstCover(menu, "/books", covers), nil)
    local n = reads
    H.eq(Finder.findFirstCover(menu, "/books", covers), nil); H.eq(reads, n)
    stamp = "db:1/wal:3"; cover_exists = true
    assert(Finder.findFirstCover(menu, "/books", covers)); H.eq(reads, n + 1)
end)

H.test("native reader menu honors all close targets without changing explicit Home routes", function()
    local target, closed, destination = "library", 0, nil
    local fm = {}
    local M = { closeReaderToLibrary = function() destination = "library" end }
    run(method(patches, "function M.wireReaderMenuFMTab("), {
        M = M, Config = { BOOK_CLOSE_TARGET = Config.BOOK_CLOSE_TARGET,
            getBookCloseTarget = function() return target end },
        liveFM = function() return fm end, liveHS = function() return {} end,
        _dropParkedScreen = noop,
        _prepareReaderClose = function() return "/books/one.epub", "prose" end,
        _closeReaderToHomescreenSync = function() destination = "homescreen" end,
    })
    for _, t in ipairs({ "library", "book_folder", "homescreen" }) do
        target, destination = t, nil
        local reader = { document = { file = "/books/one.epub" },
            menu = { menu_items = { filemanager = {} }, onTapCloseMenu = function() closed = closed + 1 end },
            onClose = function() end, showFileManager = function(_, fp)
                H.eq(fp, "/books/one.epub"); destination = "book_folder"
            end }
        M.wireReaderMenuFMTab({}, reader)
        reader.menu.menu_items.filemanager.callback()
        H.eq(destination, t)
    end
    H.eq(closed, 3)
    assert(not method(patches, "function M.closeReaderToHomescreen("):find("getBookCloseTarget", 1, true))
end)

local wallpaper = read("features/sui_wallpaper.lua")
H.test("wallpaper lighten and darken keep their meaning after night inversion", function()
    local screen, calls = { night_mode = false }, {}
    local M = {}
    run(method(wallpaper, "function M.paintTint("), {
        M = M, Screen = screen, KEY_LIGHTEN = "lighten", KEY_DARKEN = "darken",
        _readTint = function(key) return key == "lighten" and 20 or 30 end,
    })
    local bb = { lightenRect = function(_, _, _, _, _, p) calls.lighten = p end,
        darkenRect = function(_, _, _, _, _, p) calls.darken = p end }
    M.paintTint(bb, 0, 0, 10, 10)
    H.eq(calls.lighten, .2); H.eq(calls.darken, .3)
    screen.night_mode = true; M.paintTint(bb, 0, 0, 10, 10)
    H.eq(calls.lighten, .3); H.eq(calls.darken, .2)
end)
H.test("paginated grid erasers restore module backdrop over the wallpaper", function()
    local calls = {}
    local M = { paintTint = function() calls[#calls + 1] = "tint" end,
        paintBackdrop = function(_, _, _, _, _, strength)
            calls[#calls + 1] = "backdrop:" .. strength
        end }
    run(method(wallpaper, "function M.paintEraser("), {
        M = M, _clampBackdrop = function(n) return n end,
        _style_bg_cache_bb = { getWidth = function() return 100 end, getHeight = function() return 100 end },
    })
    local bb = { blitFrom = function() calls[#calls + 1] = "wallpaper" end }
    M.paintEraser(bb, 0, 0, 10, 10, 40, 0)
    H.eq(table.concat(calls, ","), "wallpaper,tint,backdrop:40")
    calls = {}; M.paintEraser(bb, 0, 0, 10, 10, 100, 0)
    H.eq(table.concat(calls, ","), "backdrop:100")
end)

H.finish()
