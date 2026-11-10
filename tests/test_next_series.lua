local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Q = require("core/orbitui_shelf_query")
local function read(path)
    local file = assert(io.open(root .. "/" .. path)); local bytes = file:read("*a"); file:close(); return bytes
end
local function chunk(bytes, env)
    if setfenv then return setfenv(assert(loadstring(bytes)), env)() end
    return assert(load(bytes, "native next-series", "t", env))()
end
local source = read("components/bookshelf/lib/bookshelf_book_repository.lua")
local native = assert(source:match("(function Repo.getNextUnreadInSeries%b().-\nend)"))
local queue, saved, books, history, profiles, root_home, clock, generation
local writes, warms, cancels, metadata_reads, progress_reads, queries, grid_loads, builds, frees, refreshes, opens, holds
local owner, UI, last_child, broken, slow, scheduled, returned, Shelves
local Repo = {}
package.loaded["ui/time"] = { now = function() return clock end,
    since = function(start) return clock - start end, to_us = function(t) return t * 1e6 end }
UI = { _simpleui_navigation_generation = 1,
    scheduleIn = function(_, delay, fn)
        assert(delay > 0); queue[#queue + 1] = fn; scheduled[#scheduled + 1] = fn
    end,
    unschedule = function(_, fn) for i = #queue, 1, -1 do if queue[i] == fn then table.remove(queue, i) end end end,
    isWidgetShown = function(_, widget) return widget == owner and not widget.hidden end,
    getTopmostVisibleWidget = function() return owner.covered and {} or owner end,
    forceRePaint = function() end,
}
package.loaded["ui/uimanager"] = UI
package.loaded["device"] = { screen_saver_mode = false }
package.loaded["infra/sui_store"] = {
    readSetting = function(_, key) return saved[key] end,
    saveSetting = function(_, key, value) saved[key] = value; writes = writes + 1 end,
}
package.loaded["lib/bookshelf_settings_store"] = { read = function() return 3 end }
package.loaded["lib/bookshelf_profiles"] = {
    list = function() return profiles end,
    matchFile = function(file)
        for _, p in ipairs(profiles) do
            for _, path in ipairs(p.roots) do if file:sub(1, #path + 1) == path .. "/" then return p.key end end
        end
    end,
}
package.loaded["libs/libkoreader-lfs"] = { attributes = function(file, key)
    return books[file] and (key == "mode" and "file" or { mode = "file" })
end }
local W = H.widget()
function W:getSize() return self.dimen or { w = self.width or 500, h = 120 } end
function W:free() frees = frees + 1 end
for _, name in ipairs{ "ui/widget/container/centercontainer", "ui/widget/textboxwidget", "ui/geometry" } do package.loaded[name] = W end
package.loaded["lib/bookshelf_clip_container"] = W
package.loaded["ui/font"] = { getFace = function() return {} end }
package.loaded.logger = { warn = function() end, dbg = function() end }
package.loaded["core/orbitui_context"] = { notify = function() end, refresh = function() refreshes = refreshes + 1 end }
package.loaded["lib/bookshelf_book_repository"] = Repo
Repo.dataGeneration = function() return generation end
Repo.cachedTagInfo = function(file)
    metadata_reads = metadata_reads + 1; clock = clock + .001
    if broken == "metadata" then error("unavailable metadata") end
    return books[file]
end
Repo.tagTextMeta = function(file, info)
    return { filepath = file, title = info.title, authors = { info.authors or "Author" },
        series_name = info.series, series_num = info.series_index }
end
Repo.buildBookMeta = function() error("must not hydrate covers/documents across the library") end
Repo.readProgress = function(file)
    progress_reads = progress_reads + 1; clock = clock + (slow and .011 or .002)
    local book = assert(books[file]); return book.pct, book.status
end
Repo.prewarmFilepaths = function(roots, opts)
    warms = warms + 1
    local retired = false
    local step = function() if not retired and opts.is_alive() then opts.on_done() end end
    UI:scheduleIn(.01, step)
    return function() retired = true; cancels = cancels + 1; UI:unschedule(step) end
end
Repo.getAllFilepaths = function(scope)
    if broken == "inventory" then error("missing inventory") end
    local out = {}
    for file in pairs(books) do
        for _, path in ipairs(scope.roots) do
            if file:sub(1, #path + 1) == path .. "/" then out[#out + 1] = file; break end
        end
    end
    table.sort(out); return out
end
local Native = { buildBookMeta = Repo.buildBookMeta, readProgress = Repo.readProgress }
chunk(native, setmetatable({ Repo = Native, _gettime = function() return clock end,
    HomeDir = { get = function() return root_home end }, BookshelfSettings = { read = function() return 3 end },
    candidatesForScope = function() error("prepared query must not walk") end,
    _getLightMetaCache = function() error("prepared query must not select all BIM rows") end,
    _lightMetaForFp = function() error("prepared query must not hydrate lazy metadata") end,
    getReadHistory = function() return { hist = history } end,
    require = function(name)
        H.eq(name, "sort"); return { natsort_cmp = function() return function(a, b) return a < b end end }
    end, logger = package.loaded.logger }, { __index = _G }))
Repo.getNextUnreadInSeries = function(...)
    queries = queries + 1
    if broken == "query" then error("native query failure") end
    return Native.getNextUnreadInSeries(...)
end
package.preload["engines/sui_book_grid"] = function()
    grid_loads = grid_loads + 1
    return { makeModule = function(spec)
        returned = { id = spec.id, default_on = spec.default_on, spec = spec,
            getHeight = function() return 145 end, getGridHeight = function() return 120 end,
            getLabel = function() return { text = spec.label } end,
            getMenuItems = spec.extra_menu_items_before, updateCovers = function() return false end,
            build = function(w, ctx)
                builds = builds + 1; last_child = ctx
                local files = spec.getFileList(ctx); assert(#files > 0, "empty rows must not fall back to recent books")
                return W:new{ width = w, files = files, ctx = ctx }
            end }
        return returned
    end }
end
local function reset()
    queue, saved, books, history, scheduled = {}, {}, {}, {}, {}
    profiles = {{ key = "manga", label = "Manga", roots = { "/manga" } }, { key = "books", label = "Books", roots = { "/books" } }}
    root_home, clock, generation = "/books", 0, 1
    writes, warms, cancels, metadata_reads, progress_reads, queries, grid_loads, builds, frees = 0, 0, 0, 0, 0, 0, 0, 0, 0
    refreshes, opens, holds, broken, slow = 0, 0, 0, nil, false
    owner = {}; package.loaded.device.screen_saver_mode = false
    UI._simpleui_navigation_generation = 1
    G_reader_settings = { readSetting = function(_, key) return key == "home_dir" and root_home or nil end }
    package.loaded["engines/sui_book_grid"], package.loaded["adapters/orbitui_home_shelves"] = nil, nil
    Shelves = require("adapters/orbitui_home_shelves")
end
local function add(path, series, num, pct, status, author, time)
    books[path] = { title = path, authors = author, series = series, series_index = num, has_meta = 1, pct = pct, status = status }
    if time then history[#history + 1] = { file = path, time = time } end
end
local function flush(limit)
    local n = 0
    while #queue > 0 and (not limit or n < limit) do
        assert(n < 50000, "worker never settled")
        table.remove(queue, 1)(); n = n + 1
    end
end
local function context(prefix)
    return { pfx = prefix or "simpleui_hs_", _screen_widget = owner,
        refresh_fn = function() refreshes = refreshes + 1 end,
        open_fn = function() opens = opens + 1 end, hold_fn = function() holds = holds + 1 end }
end
local function fixture()
    reset()
    add("/manga/A01.epub", "A", 1, 1, "finished", nil, 100)
    add("/manga/A02.epub", "A", 2, .4, "reading", nil, 200)
    add("/manga/A03.epub", "A", 3)
    add("/books/B01.epub", "B", 1, 1, "complete", nil, 50)
    add("/books/B02.epub", "B", 2)
    add("/books/unstarted.epub", "Unstarted", 1)
    add("/books/standalone.epub")
    add("/books/done.epub", "Done", 1, 1, "finished")
    return Shelves.nextModule()
end
H.test("Next registration is lazy, opt-in and preserves Home layouts, settings and existing modules", function()
    reset(); saved.simpleui_layout = { "unchanged" }; local registry = {}
    local R = { register = function(m) registry[m.id] = m end }
    Shelves.install(R); Shelves.install(R)
    local def = assert(registry.orbitui_next_series)
    H.eq(def.name, "Next in series"); H.eq(def.default_on, false); H.eq(def.category, "books")
    H.eq(def.has_covers, true); H.eq(def.is_book_mod, true)
    H.eq(grid_loads, 0); H.eq(writes, 0); H.eq(warms, 0); H.eq(#queue, 0)
    H.eq(saved.simpleui_layout[1], "unchanged"); H.eq(def.getHeight({}), 145)
    H.eq(warms, 0); H.eq(metadata_reads, 0)
end)
H.test("Next rendering starts no synchronous library work; the native query chooses in-progress then next local volumes", function()
    local mod = fixture(); local ctx = context(); local widget = mod.build(500, ctx)
    H.eq(warms, 0); H.eq(metadata_reads, 0); H.eq(progress_reads, 0); H.eq(queries, 0); H.eq(builds, 0)
    H.eq(widget[1].text, "Preparing next volumes… Long-press for options.")
    H.eq(widget.h, widget[1].height); H.eq(widget[1].height_adjust, false)
    H.eq(widget[1].height_overflow_show_ellipsis, true)
    flush(); local state = Shelves.nextState(ctx.pfx)
    H.eq(state.phase, "ready"); H.eq(#state.files, 2); H.eq(state.files[1], "/manga/A02.epub")
    H.eq(state.files[2], "/books/B02.epub"); H.eq(queries, 1); H.eq(refreshes, 1); H.eq(writes, 0)
    local ready = mod.build(500, ctx); H.eq(#ready.files, 2)
    last_child.open_fn(ready.files[1]); last_child.hold_fn(ready.files[1]); H.eq(opens, 1); H.eq(holds, 1)
    last_child.open_fn("/books/unstarted.epub"); H.eq(opens, 1)
    widget:free(); H.eq(Shelves.nextState(ctx.pfx).phase, "ready")
    local before = progress_reads; mod.build(500, ctx); flush(); H.eq(progress_reads, before); H.eq(queries, 1)
end)
H.test("module previews without a real owner never start work or poison a later real placement", function()
    local mod = fixture(); local ctx = context(); ctx._screen_widget = nil
    mod.build(500, ctx); flush(); H.eq(warms, 0); H.eq(Shelves.nextState(ctx.pfx).phase, "idle")
    ctx = context(); ctx.preview = true; mod.build(500, ctx); flush(); H.eq(warms, 0)
    ctx.preview = nil; mod.build(500, ctx); flush(); H.eq(queries, 1)
end)
H.test("different author and library series identities cannot select one another's unread volume", function()
    local mod = fixture()
    add("/manga/S1.epub", "Same", 1, 1, "finished", "Author A", 300)
    add("/manga/S2.epub", "Same", 2, nil, nil, "Author B")
    add("/books/S2.epub", "Same", 2, nil, nil, "Author A")
    mod.build(500, context()); flush()
    H.eq(#Shelves.nextState().files, 2) -- neither unrelated S2 is a valid continuation
    add("/manga/S3.epub", "Same", 3, nil, nil, "Author A"); generation = generation + 1
    mod.build(500, context()); flush()
    H.eq(Shelves.nextState().files[1], "/manga/S3.epub")
end)
H.test("a selected library is screen-scoped and removed library IDs never fall back to all books", function()
    local mod = fixture(); local ctx = context()
    local rows = mod.getMenuItems({ pfx = ctx.pfx, refresh = function() refreshes = refreshes + 1 end })
    rows[2].sub_item_table[2].callback(); H.eq(saved[ctx.pfx .. "orbitui_next_series_profile"], "manga")
    mod.build(500, ctx); flush(); H.eq(#Shelves.nextState().files, 1)
    mod.build(500, context("other_")); flush(); H.eq(#Shelves.nextState("other_").files, 2)
    profiles = { profiles[2] }; local widget = mod.build(500, ctx); flush()
    H.eq(Shelves.nextState().phase, "folders"); H.eq(#Shelves.nextState().files, 0)
    H.eq(widget[1].text, "Choose library folders before using Next in series.")
end)
H.test("generation, root, deletion and navigation guards reject stale open and detail callbacks", function()
    for _, change in ipairs{ function() generation = generation + 1 end,
            function() profiles[1].roots = { "/other" } end,
            function() books["/manga/A02.epub"] = nil end,
            function() UI._simpleui_navigation_generation = 2 end,
            function() owner._current_page = 2 end,
            function() owner.covered = true end } do
        local mod = fixture(); local ctx = context(); mod.build(500, ctx); flush(); mod.build(500, ctx)
        local old = last_child; change(); old.open_fn("/manga/A02.epub"); old.hold_fn("/manga/A02.epub")
        H.eq(opens, 0); H.eq(holds, 0)
    end
end)
H.test("sleep pauses warmup and never resumes automatically; already queued stale callbacks stay inert", function()
    local mod = fixture(); local ctx = context(); mod.build(500, ctx); flush(1)
    local late = scheduled[#scheduled]; Shelves.nextEvent("onSuspend"); flush()
    H.eq(Shelves.nextState().phase, "paused"); H.eq(cancels, 1); H.eq(metadata_reads, 0)
    Shelves.nextEvent("onResume"); mod.build(500, ctx); flush(); H.eq(queries, 0)
    mod.getMenuItems({ pfx = ctx.pfx, refresh = function() end })[1].callback()
    mod.build(500, ctx); late(); flush(); H.eq(Shelves.nextState().phase, "ready"); H.eq(queries, 1)
end)
H.test("freeing, navigation, covered owners and reader transitions retire in-flight metadata", function()
    for _, change in ipairs{ function(widget) widget:free() end,
            function() UI._simpleui_navigation_generation = 2 end,
            function() owner.covered = true end,
            function() Shelves.nextEvent("onShowingReader") end } do
        local mod = fixture()
        for i = 1, 40 do add("/manga/extra" .. i .. ".epub", "Extra", i) end
        local ctx = context(); local widget = mod.build(500, ctx); flush(3)
        local before = metadata_reads; change(widget); flush(); H.eq(metadata_reads, before); H.eq(queries, 0)
        H.eq(Shelves.nextState().phase, "paused")
    end
end)
H.test("progress preparation yields within eight operations or eight milliseconds even across 3341 volumes", function()
    local mod = fixture()
    for i = 1, 3341 do add("/manga/large" .. i .. ".epub", "Large", i, i == 1 and 1 or 0) end
    slow = true; mod.build(500, context())
    local turns = 0
    while #queue > 0 do
        local before = progress_reads; flush(1)
        assert(progress_reads - before <= 1, "slow progress reads did not yield")
        turns = turns + 1; assert(turns < 20000)
    end
    H.eq(Shelves.nextState().phase, "ready"); H.eq(queries, 1); assert(turns > 3341)
    H.eq(#Shelves.nextState().files, 3)
end)
H.test("empty, unknown metadata and transient failures remain honest and explicit refresh retries", function()
    for _, failure in ipairs{ "inventory", "metadata", "query" } do
        local mod = fixture(); local ctx = context(); broken = failure; mod.build(500, ctx); flush()
        H.eq(Shelves.nextState().phase, "error"); H.eq(#Shelves.nextState().files, 0)
        broken = nil; mod.getMenuItems({ pfx = ctx.pfx, refresh = function() end })[1].callback()
        mod.build(500, ctx); flush(); H.eq(Shelves.nextState().phase, "ready"); H.eq(#Shelves.nextState().files, 2)
    end
    local mod = fixture(); for _, book in pairs(books) do book.has_meta = 0 end
    mod.build(500, context()); flush(); H.eq(#Shelves.nextState().files, 0); H.eq(Shelves.nextState().missing, 8)
    local rows = mod.getMenuItems({ pfx = "simpleui_hs_" }); H.eq(rows[4].dim, true)
    H.eq(books["/manga/A01.epub"].status, "finished")
end)
H.test("dashboard-private screen proxies resolve to the actual live owner and retain normal book callbacks", function()
    local mod = fixture(); local ctx = context()
    ctx.orbitui_dashboard_hosted, ctx._screen_widget = true, setmetatable({}, { __index = owner })
    mod.build(500, ctx); flush(); H.eq(Shelves.nextState().phase, "ready")
    local widget = mod.build(500, ctx); last_child.open_fn(widget.files[1]); H.eq(opens, 1)
    local before = frees; widget:free(); widget:free(); H.eq(frees, before + 1)
    H.eq(Shelves.nextState().lease, nil)
end)
H.test("dashboard page switches retire a prepared callback even when the root Home remains visible", function()
    local mod = fixture(); local ctx = context(); ctx.orbitui_dashboard_hosted = true
    ctx._screen_widget = setmetatable({}, { __index = owner })
    owner._orbitui_dashboard_module_page = 1
    mod.build(500, ctx); flush(); mod.build(500, ctx)
    owner._orbitui_dashboard_module_page = 2
    last_child.open_fn("/manga/A02.epub"); H.eq(opens, 0)
end)
H.test("CBZ/PDF volumes use the same metadata path and 400-series cap is applied after complete native ranking", function()
    local mod = fixture()
    for i = 1, 501 do
        add("/manga/S" .. i .. "-1.cbz", "Manga " .. i, 1, 1, "finished", nil, i + 1000)
        add("/manga/S" .. i .. "-2.pdf", "Manga " .. i, 2)
    end
    local ctx = context(); mod.build(500, ctx); flush()
    local state = Shelves.nextState()
    H.eq(#state.files, 400); H.eq(state.total, 503); H.eq(state.files[1], "/manga/S501-2.pdf")
    local rows = mod.getMenuItems({ pfx = ctx.pfx }); H.eq(rows[#rows].text, "Showing the first 400 series.")
end)
H.test("snapshots are bounded and evicted screen callbacks never regain permission to open", function()
    local mod = fixture(); local ctx = context(); mod.build(500, ctx); flush(); mod.build(500, ctx)
    local old = last_child
    for i = 1, 9 do Shelves.nextState("custom" .. i .. "_") end
    old.open_fn("/manga/A02.epub"); H.eq(opens, 0)
    H.eq(#Shelves.nextState().files, 0)
end)
H.test("native decimal order, source-query ownership and cooperative checkpoints preserve real next-volume rules", function()
    reset()
    local records = {}
    for _, n in ipairs{ 1, 2.5, 10 } do
        local file = "/manga/" .. n .. ".epub"; add(file, "Decimal", n, n == 1 and 1 or 0)
        records[#records + 1] = { filepath = file, title = file, series_name = "Decimal", series_num = n }
    end
    local checkpoints = 0
    local rows = Native.getNextUnreadInSeries(400, 0, nil, { records = records, light_only = true,
        checkpoint = function() checkpoints = checkpoints + 1 end })
    H.eq(rows[1].filepath, "/manga/2.5.epub"); assert(checkpoints >= 6)
    H.eq(records[2].series_num, 2.5); H.eq(books["/manga/1.epub"].pct, 1)
end)
H.test("Next uses Swedish and English strings independently of series and file names", function()
    local _ = require("core/orbitui_i18n")
    for _i, text in ipairs{ "Next in series", "All libraries", "Refresh next volumes", "About next in series",
        "Continue a volume in progress, otherwise show the next unread local volume in a started series. Different authors and libraries stay separate. Preparation runs in small steps; no BookOrbit account or server is needed. Long-press a cover for book details.",
        "%d books have no cached metadata. Refresh library metadata for complete series results.",
        "Showing the first 400 series.", "Preparing next volumes… Long-press for options.",
        "Series preparation paused. Long-press and choose Refresh next volumes.",
        "Could not prepare series. Long-press to refresh, or check library metadata.",
        "Choose library folders before using Next in series.", "No started series to continue in the indexed books." } do
        assert(_(text, "sv") ~= text); H.eq(_(text, "en"), text)
    end
end)
H.finish()
