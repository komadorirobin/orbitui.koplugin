package.path = "./?.lua;./components/simpleui/?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = assert(io.open("components/simpleui/" .. path))
    local s = f:read("*a"); f:close(); return s
end
local function run(s, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then local f = assert(loadstring(s)); setfenv(f, env); return f() end
    return assert(load(s, "October 16 integration", "t", env))()
end
local function section(s, first, last)
    local a = assert(s:find(first, 1, true), first)
    return s:sub(a, assert(s:find(last, a, true), last) - 1)
end
local function method(s, first)
    local a = assert(s:find(first, 1, true), first)
    return s:sub(a, assert(s:find("\nend", a, true)) + 3) .. "\n"
end
local function identity(s) return s end
local function noop() end
local settings, writes, scheduled = {}, 0, {}
local store = {
    readSetting = function(_, k) return settings[k] end,
    saveSetting = function(_, k, v) settings[k] = v; writes = writes + 1 end,
    delSetting = function(_, k) settings[k] = nil; writes = writes + 1 end,
    nilOrTrue = function(_, k) return settings[k] ~= false end,
}
store.setNoFlush, store.delNoFlush = store.saveSetting, store.delSetting
package.loaded["infra/sui_store"] = store
package.loaded.logger = { warn = noop }
package.loaded["device"] = { screen = {
    getWidth = function() return 1072 end, getHeight = function() return 1448 end,
} }
package.loaded["ui/uimanager"] = {
    unschedule = function(_, fn) scheduled[fn] = nil end,
    scheduleIn = function(_, _, fn) scheduled[fn] = true end,
}
local Memory = require("infra/sui_memory")
local LRU = require("infra/sui_lru")

H.test("shared LRU scopes, byte bounds and ownership survive replacements", function()
    local freed = {}
    local cache = LRU.new{ max_entries = 3, max_bytes = 50,
        free = function(v) assert(not freed[v]); freed[v] = true end }
    cache:put("a", "first", 20, "one")
    cache:put("a", "second", 20, "two")
    H.eq(cache:get("a", "one"), "first")
    cache:put("b", "third", 20, "two")
    H.eq(cache:peek("a", "two"), nil); H.eq(freed.second, true)
    cache:put("a", "replacement", 20, "one"); H.eq(freed.first, true)
    cache:removeScope("two"); H.eq(freed.third, true)
    cache:put("huge", "huge", 100); H.eq(cache:count(), 1)
    H.eq(cache:get("huge"), "huge")
    cache:clear(); cache:clear(); H.eq(cache:bytes(), 0); H.eq(freed.huge, true)
end)
H.test("memory teardown cancels collections scheduled by its own reset hooks", function()
    local cache = LRU.new{}
    cache:put("cover", {}, 20 * 1024 * 1024)
    Memory.onReset(function() cache:clear() end)
    Memory.requestCollect(); assert(next(scheduled))
    Memory.reset(); H.eq(next(scheduled), nil)
    Memory.reset(); H.eq(next(scheduled), nil)
end)
H.test("nested alpha scratch buffers reuse memory and recover from allocation or paint errors", function()
    local core, buffers, fail_alloc, fail_view = {}, {}, false, false
    local BB = { TYPE_BB8 = 8 }
    function BB.new(w, h)
        if fail_alloc then error("allocation failed") end
        local b = { w = w, h = h }
        function b:getWidth() assert(not self.freed); return self.w end
        function b:getHeight() assert(not self.freed); return self.h end
        function b:free() assert(not self.freed); self.freed = true end
        function b:viewport(_, _, vw, vh)
            assert(not self.freed)
            if fail_view then error("viewport failed") end
            return { w = vw, h = vh, paintRect = noop, invertRect = noop }
        end
        buffers[#buffers + 1] = b
        return b
    end
    run(section(read("infra/sui_core.lua"), "local _scratch =", "-- Shared lazy loader"),
        { M = core, Blitbuffer = BB, SUIStyle = { COLOR = { surface = 0 } } })
    local target = { colorblitFromRGB32 = noop }
    local leaf = { paintTo = noop }
    local outer = { paintTo = function()
        core.paintWithAlphaMask(leaf, target, 0, 0, 8, 5, 0)
    end }
    core.paintWithAlphaMask(outer, target, 0, 0, 10, 10, 0)
    H.eq(#buffers, 2)
    core.paintWithAlphaMask(outer, target, 0, 0, 10, 10, 0); H.eq(#buffers, 2)
    fail_alloc = true
    H.eq(pcall(core.paintWithAlphaMask, leaf, target, 0, 0, 20, 20, 0), false)
    H.eq(buffers[1].freed, nil)
    fail_alloc = false; fail_view = true
    H.eq(pcall(core.paintWithAlphaMask, leaf, target, 0, 0, 10, 10, 0), false)
    fail_view = false
    H.eq(pcall(core.paintWithAlphaMask, { paintTo = function() error("paint failed") end },
        target, 0, 0, 10, 10, 0), false)
    core.paintWithAlphaMask(outer, target, 0, 0, 10, 10, 0); H.eq(#buffers, 2)
    core.paintWithAlphaMask(leaf, target, 0, 0, 20, 20, 0)
    H.eq(#buffers, 3); H.eq(buffers[1].freed, true)
    core.releaseScratch(); core.releaseScratch()
    H.eq(buffers[2].freed, true); H.eq(buffers[3].freed, true)
end)

local function menuClass()
    return {
        setUpdateItemTable = function(self) self.tab_item_table = {}; return "built" end,
        onShowMenu = function(_, index, hidden) return index, hidden end,
    }
end
local reader, fm = menuClass(), menuClass()
package.loaded["apps/reader/modules/readermenu"] = reader
package.loaded["apps/filemanager/filemanagermenu"] = fm
local Hooks = require("infra/sui_menu_hooks")
H.test("new central menu hooks survive out-of-order host teardown and later patches", function()
    local first, second, prepares = {}, {}, 0
    Hooks.acquire(first); Hooks.acquire(second)
    local own = reader.onShowMenu
    Hooks.acquire(first); H.eq(reader.onShowMenu, own)
    Hooks.register{ id = "test", order = 10, prepare = function() prepares = prepares + 1 end,
        resolve = function(_, _, i) return i + 1 end }
    local obj = setmetatable({}, { __index = reader })
    H.eq(obj:setUpdateItemTable(), "built"); H.eq(prepares, 1)
    H.eq(obj:onShowMenu(3), 4); H.eq(prepares, 2)
    Hooks.uninstall(first)
    H.eq(obj:onShowMenu(3), 4)
    local external_calls = 0
    local external = function(...) external_calls = external_calls + 1; return own(...) end
    reader.onShowMenu = external
    Hooks.uninstall(second); H.eq(reader.onShowMenu, external)
    local before = prepares
    H.eq(obj:onShowMenu(3), 3); H.eq(prepares, before)
    Hooks.acquire(first)
    Hooks.register{ id = "test", order = 10, resolve = function(_, _, i) return i + 2 end }
    H.eq(obj:onShowMenu(3), 5); H.eq(external_calls, 2)
    Hooks.uninstall(first); H.eq(reader.onShowMenu, external)
    H.eq(obj:onShowMenu(3, true), 3)
end)

local home, revision, walks, invalidations = "/books", 1, 0, 0
local files = {}
for i = 1, 200 do files[i] = { fp = string.format("/books/%03d", i), mtime = i } end
local SH = { isFinished = function(fp) return fp == "done" end,
    isCurrentExcluded = function(pfx) return settings[pfx .. "exclude"] ~= false end }
local deps = {
    ["infra/sui_i18n"] = { translate = identity },
    ["engines/sui_book_grid"] = {},
    ["features/library/sui_filter_state"] = {},
    ["modules/module_books_shared"] = SH,
    ["engines/sui_library_scan"] = {
        resolveHomeDir = function() return home end,
        getRevision = function() return revision end,
        getRaw = function() walks = walks + 1; return files end,
        invalidate = function() invalidations = invalidations + 1 end,
    },
    ["features/sui_source_menu"] = { excludeCurrentItems = function() return {} end },
}
local Sources = run(read("engines/sui_book_sources.lua"), { require = function(name)
    return deps[name] or require(name)
end })
H.test("new and tabbed grids share bounded new-books ranking keyed by root and revision", function()
    local source = Sources.get("new_books")
    local ranked = source.getFileList()
    H.eq(#ranked, 15); H.eq(ranked[1], "/books/200"); H.eq(ranked[15], "/books/186")
    H.eq(files[1].fp, "/books/001"); H.eq(walks, 1)
    H.eq(source.getFileList(), ranked); H.eq(walks, 1)
    revision = 2; source.getFileList(); H.eq(walks, 2)
    home = "/other"; source.getFileList(); H.eq(walks, 3)
    Sources.invalidate("new_books"); H.eq(invalidations, 1)
    source.getFileList(); H.eq(walks, 4)
    home = nil; H.eq(#source.getFileList(), 0); H.eq(walks, 4)
end)
H.test("recent tabs respect hidden books and per-screen current/finished choices", function()
    local Hidden = require("features/library/sui_recent_hidden")
    Hidden.hide("hidden")
    local recent = Sources.bind("recent", function() return { show_finished = true } end)
    local ctx = { pfx = "custom_", current_fp = "current", recent_fps = { "hidden", "done" } }
    H.eq(recent.getFileList(ctx), ctx.recent_fps)
    H.eq(recent.filterItem("hidden", ctx), false)
    H.eq(recent.filterItem("done", ctx), true)
    H.eq(recent.filterItem("current", ctx), false)
    settings.custom_exclude = false; H.eq(recent.filterItem("current", ctx), true)
    H.eq(Sources.bind("recent").filterItem("done", ctx), false)
    local refreshed = 0
    Sources.get("recent").menu_items{ _ = identity, refresh = function() refreshed = refreshed + 1 end }[1].callback()
    H.eq(refreshed, 1); H.eq(recent.filterItem("hidden", ctx), true)
end)

local tab_src = read("modules/module_tab_grid.lua")
local available = false
Sources.register{ id = "optional", label = function() return "Optional" end,
    getFileList = function() return {} end, isAvailable = function() return available end }
local newStore = run(section(tab_src, "local DEFAULT_TABS", "-- The store of an instance") ..
    "\nreturn newTabStore", { SUISettings = store, Sources = Sources })
H.test("tab settings are copy-on-write and isolated by module and screen", function()
    settings, writes = {}, 0
    local a, b = newStore("tab_grid_1"), newStore("tab_grid_2")
    H.eq(#a.read("home_"), 2); H.eq(writes, 0)
    a.add("home_", "optional", {})
    H.eq(#a.read("home_"), 2); H.eq(#settings.home_tab_grid_1_tabs, 3)
    a.reorder("home_", { 2, 1 })
    H.eq(settings.home_tab_grid_1_tabs[3].source, "optional")
    available = true; H.eq(#a.read("home_"), 3)
    H.eq(a.add("home_", "optional", {}), false)
    local previous = settings.home_tab_grid_1_tabs
    a.remove("home_", 1); H.eq(#previous, 3)
    H.eq(#a.read("home_"), 2); H.eq(#a.read("other_"), 2); H.eq(#b.read("home_"), 2)
    a.setOption("home_", 2, "show_finished", true)
    local old = settings.home_tab_grid_1_tab_options
    a.setOption("home_", 2, "show_finished", false)
    H.eq(old[2].show_finished, true)
    a.setActive("home_", 2); H.eq(a.activeTab("home_", a.read("home_")).id, 2)
    a.remove("home_", 2)
    H.eq(settings.home_tab_grid_1_active_tab, nil); H.eq(settings.home_tab_grid_1_tab_options[2], nil)
end)
H.test("tab grid is optional and recent demand follows selected data sources", function()
    assert(tab_src:find("default_on  = false", 1, true))
    local demand = run(method(tab_src, "local function recentDemand(tabs)") .. "\nreturn recentDemand",
        { Sources = Sources })
    H.eq(demand({{source="new_books"}, {source="tbr"}}), 0)
    H.eq(demand({{source="recent"}, {source="new_books"}}), 15)
    local cd = read("modules/module_coverdeck.lua")
    local mod = {}
    run(section(cd, "M.needs =", "\nM.") , { M = mod, SUISettings = store })
    H.eq(mod.needs.recent("custom_"), 15)
    settings.custom_coverdeck_source = "bookorbit_want"; H.eq(mod.needs.recent("custom_"), 0)
end)

local Config = {}
run(method(read("infra/sui_config.lua"), "function M.mergeOrder("), { M = Config })
H.test("currently-reading orders migrate by copy and keep explicit new choices", function()
    settings, writes = {}, 0
    local current = read("modules/module_currently.lua")
    local migrate, style = run(section(current, "local ITEM_IDS", "local function itemLabel") ..
        "\nreturn migrateOrders, getStatsStyle", { SUISettings = store, Config = Config })
    local legacy = { "book_time", "title", "description", "progress", "book_days", "author" }
    settings.custom_currently_elem_order = legacy
    migrate("custom_")
    H.eq(settings.custom_currently_elem_order, legacy)
    H.eq(settings.custom_currently_main_order[1], "stats")
    H.eq(settings.custom_currently_main_order[2], "title")
    H.eq(settings.custom_currently_stats_order[1], "book_time")
    H.eq(settings.custom_currently_stats_order[2], "book_days")
    local explicit = { "author", "title" }
    settings.custom_currently_main_order = explicit
    local n = writes; migrate("custom_"); H.eq(writes, n)
    H.eq(settings.custom_currently_main_order, explicit)
    H.eq(settings.home_currently_main_order, nil)
    H.eq(style("custom_"), "default")
    settings.custom_currently_stats_style = "compact"; H.eq(style("custom_"), "compact")
end)
H.test("reader quick panel stays classic until the book layout is explicitly selected", function()
    assert(read("infra/sui_config.lua"):find('def("simpleui_qs_bar_reader_layout",    "classic")', 1, true))
    Config.readChoice = function(k, _, default) return settings[k] or default end
    local get = run(method(read("screens/sui_quicksettings_bar.lua"), "local function getReaderLayout()") ..
        "\nreturn getReaderLayout", { _Config = function() return Config end,
            READER_LAYOUT_KEY = "reader_layout", LAYOUT_IDS = {}, LAYOUT = { BOOK="book", CLASSIC="classic" } })
    H.eq(get(), "classic"); settings.reader_layout = "book"; H.eq(get(), "book")
end)
H.test("tab grid rebuilds only its selected source without changing module height", function()
    settings = {}
    home = "/books"
    local strip, spec, pages, repaints, source_seen, covers_seen, framed_body
    pages, repaints = {}, 0
    local W = {}
    function W:new(t)
        return setmetatable(t or {}, { __index = self })
    end
    function W:getSize() return self.dimen or { w = 300, h = 100 } end
    local page_state = {
        get = function(ctx, id) return pages[id] or 1, ctx.npages or 1 end,
        setPage = function(_, id, page) pages[id] = page end,
    }
    local grid = {
        landscapeFactor = function() return 1 end,
        requestRepaint = function() repaints = repaints + 1 end,
        requestPageTurn = function(ctx, id, delta) pages[id] = pages[id] + delta end,
        progressDrawsText = function() return false end,
        getProgressStyle = function() return "none" end,
        makeEraser = function(w, h, surface)
            H.eq(surface.strength, 0); H.eq(surface.border_sz, 0)
            return W:new{ dimen = { w = w, h = h }, eraser = true }
        end,
        makeModule = function(opts)
            spec = opts
            return {
                getGridHeight = function(ctx)
                    H.eq(ctx.col_w, 280); H.eq(#opts.getSources(ctx), #ctx.measured_tabs)
                    return 180
                end,
                build = function(w, ctx)
                    H.eq(w, 280)
                    source_seen = opts.getSource(ctx).getFileList(ctx)[1]
                    if not ctx.empty then return W:new{ source = source_seen } end
                end,
                updateCovers = function(w) covers_seen = w; return true end,
                updateStats = function(_, ctx) ctx.npages = ctx.next_npages; return true end,
            }
        end,
    }
    local config = {
        readChoice = function(k, _, default) return settings[k] or default end,
        getLabelScale = function() return 1 end,
        resolveTextStyles = function() return { tabs = {} } end,
        getAlignment = function(_, _, default) return default end,
    }
    local chrome = {
        NO_CHROME = { strength = 0, border_sz = 0 }, resolve = function() return {} end,
        contentWidth = function(w) return w - 20 end,
        boxInset = function() return 4 end,
        inset = function(w) return w end,
        wrap = function(w) framed_body = w; return w end,
    }
    local imports = {
        ["infra/sui_i18n"] = { translate = identity },
        ["infra/sui_store"] = store,
        ["infra/sui_config"] = config,
        ["infra/sui_core"] = { PAD = 5, PAD2 = 4, makeColoredText = function(t) return W:new(t) end },
        ["infra/sui_backdrop"] = { BACKDROP_DEFAULT = { tab_bar = 100 } },
        ["features/sui_module_chrome"] = chrome,
        ["features/sui_style"] = { FS_BODY = 14, FS_DETAIL = 10, getTextFace = function() return {} end,
            faceHeight = function() return 12 end },
        ["features/sui_arrange"] = {}, ["features/sui_source_menu"] = {},
        ["engines/sui_book_sources"] = Sources, ["engines/sui_book_grid"] = grid,
        ["engines/sui_group_cell"] = { makeSettings = function() return {} end, new = function() return {} end },
        ["engines/sui_page_nav"] = { ICON_SIZE = 10, buildPager = function() return W:new{} end },
        ["engines/sui_section_label"] = { PageState = page_state },
        ["engines/sui_tab_strip"] = { height = function() return 20 end,
            new = function(opts) strip = opts; return W:new{} end },
        ["engines/sui_tab_window"] = {},
        ["device"] = { screen = { scaleBySize = function(_, v) return v end } },
        ["ui/font"] = { getFace = function() return {} end },
        ["ui/size"] = { padding = { button = 2 } }, ["ui/geometry"] = W,
    }
    local mod = run(tab_src, { require = function(name)
        if name:find("ui/widget/", 1, true) == 1 then return W end
        return assert(imports[name], name)
    end }).makeInstance("tab_grid_1")
    local ctx = { pfx = "home_", col_w = 300, npages = 3, recent_fps = { "recent" } }
    local height = mod.getHeight(ctx)
    local first = mod.build(300, ctx)
    H.eq(first:getSize().h, height); H.eq(first[1].eraser, true)
    -- Empty height belongs outside the visible frame, not after its pager.
    H.eq(framed_body[#framed_body].width, nil)
    assert(first[2][#first[2]].width > 0)
    H.eq(source_seen, "recent"); H.eq(pages.tab_grid_1, 1)
    pages.tab_grid_1 = 3; strip.on_select(1); H.eq(pages.tab_grid_1, 1)
    ctx[spec.cache_key] = { "stale" }
    pages.tab_grid_1 = 2; strip.on_select(2); H.eq(repaints, 1)
    local second = mod.build(300, ctx)
    H.eq(source_seen, "/books/200"); H.eq(ctx[spec.cache_key], nil)
    H.eq(pages.tab_grid_1, 1); H.eq(second:getSize().h, height)
    H.eq(mod.updateCovers(second, ctx), true); H.eq(covers_seen, second._grid)
    ctx.next_npages = 3; H.eq(mod.updateStats(second, ctx), true)
    ctx.next_npages = 4; H.eq(mod.updateStats(second, ctx), false)
    ctx.empty = true
    local empty = mod.build(300, ctx)
    H.eq(empty._grid, nil); H.eq(empty:getSize().h, height)
    H.eq(mod.updateStats(empty, ctx), false)
    settings.home_tab_grid_1_tabs = {}
    local no_tabs = mod.build(300, ctx)
    H.eq(no_tabs[1].eraser, true); H.eq(ctx._tab_grid.tab_grid_1.signature, nil)
end)
H.test("grid section height forwards the screen prefix and per-module scale", function()
    local grid = { getGridHeight = function() return 100 end }
    run(method(read("engines/sui_book_grid.lua"), "function GridRenderer.getHeight("), {
        GridRenderer = grid, landscapeFactor = function(ctx) return ctx.landscape_factor end,
        SectionLabel = { height = function(id, factor, pfx)
            H.eq(id, "recent"); H.eq(factor, 0.75); H.eq(pfx, "custom_"); return 23
        end },
    })
    H.eq(grid.getHeight({pfx="custom_", landscape_factor=0.75}, {id="recent"}), 123)
end)
H.finish()
