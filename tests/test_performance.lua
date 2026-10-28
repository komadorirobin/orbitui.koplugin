package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local saved, writes, mem_reads, clock = {}, 0, 0, 0
local available, total, reader_shown = 512 * 1024 * 1024, 1024 * 1024 * 1024, false
local scheduled, cancelled = {}, {}
package.loaded["infra/sui_store"] = {
    readSetting = function(_, key) return saved[key] end,
    saveSetting = function(_, key, value) saved[key] = value; writes = writes + 1 end,
}
package.loaded["ui/uimanager"] = {
    scheduleIn = function(_, seconds, fn) scheduled[#scheduled + 1] = { seconds = seconds, fn = fn } end,
    unschedule = function(_, fn) cancelled[fn] = true end,
    isWidgetShown = function() return reader_shown end,
}
package.loaded["ui/time"] = { now = function() return clock end,
    since = function(start) return clock - start end, to_us = function(t) return t * 1000000 end }
package.loaded.util = { calcFreeMem = function() mem_reads = mem_reads + 1; return available, total end }
package.loaded.logger = { warn = function() end, dbg = function() end }
H.simpleuiMemory()
local Host = require("core/orbitui_host")
local MiB = 1024 * 1024
local MODE = "simpleui_orbitui_performance_mode"
local LRU = require("infra/sui_lru")
local home = { _lru = LRU.new{ max_bytes = 32 * MiB, max_entries = 100 } }
package.loaded["infra/sui_cover_cache"] = home
package.loaded["lib/bookshelf_cover_disk_cache"] = false
package.preload["lib/bookshelf_cover_disk_cache"] = function() return false end
local shelf = dofile("components/bookshelf/lib/bookshelf_scaled_cover_cache.lua")
package.loaded["lib/bookshelf_scaled_cover_cache"] = shelf
shelf:setByteBudget(32 * MiB)
local owner = {}
local function fill()
    local kept = {}
    for i = 1, 4 do
        kept[i] = { stride = 8192, h = 1024,
            getWidth = function() return 1024 end, getHeight = function() return 1024 end,
            free = function() error("borrowed image must not be freed") end }
        home._lru:put(i, kept[i], 8 * MiB)
        shelf:put("/private/book" .. i, kept[i])
    end
    return kept
end
H.test("default/unknown profiles leave budgets settings and preload unchanged without probing memory", function()
    saved[MODE] = "future-profile"
    Host.performanceStarted(owner)
    Host.performanceCache(home, "home"); Host.performanceCache(shelf, "shelf")
    Host.performanceCache(home, "home")
    Host.applyMemoryPolicy()
    H.eq(Host.performanceMode(), "existing"); H.eq(Host.allowSpeculation(), true)
    H.eq(home._lru._max_bytes, 32 * MiB); H.eq(shelf._byte_budget, 32 * MiB)
    H.eq(saved[MODE], "future-profile"); H.eq(writes, 0); H.eq(mem_reads, 0)
    H.eq(#scheduled, 0)
end)
H.test("pure policy handles invalid/unknown readings and never increases a cache", function()
    for _, value in ipairs({ false, "bad", -1, 0/0, math.huge }) do
        H.eq(Host.memoryPolicy("adaptive", value, total, false).factor, 1)
    end
    H.eq(Host.memoryPolicy("adaptive", total + 1, total).factor, 1)
    H.eq(Host.memoryPolicy("adaptive", 0, total).pressure, "critical")
    H.eq(Host.memoryPolicy("adaptive", total * .20, total).pressure, "low")
    H.eq(Host.memoryPolicy("adaptive", total * .50, total).factor, 1)
    H.eq(Host.memoryPolicy("existing", 0, total).factor, 1)
end)
H.test("both real cache implementations shrink only borrowed references and restore original budgets", function()
    local kept = fill()
    available = total * .1
    Host.setPerformanceMode("adaptive")
    H.eq(home._lru._max_bytes, math.floor(32 * MiB * .35))
    H.eq(shelf._byte_budget, math.floor(32 * MiB * .35))
    H.eq(home._lru:count(), 1); H.eq(#shelf._order, 1)
    H.eq(home._lru:get(4), kept[4]); H.eq(shelf:get("/private/book4"), kept[4])
    H.eq(kept[1]:getWidth(), 1024)
    Host.setPerformanceMode("existing")
    H.eq(home._lru._max_bytes, 32 * MiB); H.eq(shelf._byte_budget, 32 * MiB)
    H.eq(saved.cover_cache_mb, nil)
end)
H.test("a later user budget change remains the base instead of compounding the runtime cap", function()
    Host.setPerformanceMode("adaptive")
    shelf:setByteBudget(64 * MiB); home._lru:setByteBudget(64 * MiB)
    Host.applyMemoryPolicy(); Host.applyMemoryPolicy()
    H.eq(shelf._byte_budget, math.floor(64 * MiB * .35))
    H.eq(home._lru._max_bytes, math.floor(64 * MiB * .35))
    Host.setPerformanceMode("existing")
    H.eq(shelf._byte_budget, 64 * MiB); H.eq(home._lru._max_bytes, 64 * MiB)
end)
H.test("oversized live images remain usable and no policy writes disk cache or image sources", function()
    local cache = LRU.new{ max_bytes = 32 * MiB }
    local image = { borrowed = true }
    cache:put("hero", image, 12 * MiB); cache:setByteBudget(2 * MiB)
    H.eq(cache:count(), 1); H.eq(cache:get("hero"), image)
    cache:setByteBudget(0/0); cache:setByteBudget(math.huge); cache:setByteBudget(-1)
    H.eq(cache._max_bytes, 2 * MiB)
end)
H.test("reader policy uses visible ownership not the parked document and never drops its shelf state", function()
    local live = { profile_key = "custom", chip = "fiction", _cursor = 43, _reader_parked = true }
    package.loaded["lib/bookshelf_widget"] = { live = live }
    package.loaded["apps/reader/readerui"] = { instance = { document = { file = "/private/book" } } }
    available = total * .5; reader_shown = true
    Host.setPerformanceMode("adaptive")
    H.eq(shelf._byte_budget, 48 * MiB)
    reader_shown = false; Host.applyMemoryPolicy()
    H.eq(shelf._byte_budget, 64 * MiB)
    H.eq(live.profile_key, "custom"); H.eq(live.chip, "fiction"); H.eq(live._cursor, 43)
    H.eq(live._reader_parked, true)
end)
H.test("deferred memory work is one-shot cancellable on navigation suspend teardown and newer events", function()
    Host.performanceEvent("onReaderReady")
    local first = scheduled[#scheduled].fn
    H.eq(scheduled[#scheduled].seconds, 1.5)
    Host.performanceEvent("onCloseDocument")
    local second = scheduled[#scheduled].fn
    local before = mem_reads
    first(); H.eq(mem_reads, before); H.eq(cancelled[first], true)
    Host.performanceEvent("onSuspend"); second(); H.eq(mem_reads, before)
    Host.performanceEvent("onResume")
    local third = scheduled[#scheduled].fn; third(); H.eq(mem_reads, before + 1)
    third(); H.eq(mem_reads, before + 1)
    Host.performanceEvent("onReaderReady"); local last = scheduled[#scheduled].fn
    Host.performanceStopped(owner); before = mem_reads; last(); H.eq(mem_reads, before)
    Host.performanceStarted(owner)
end)
H.test("responsive gating leaves safe visible extraction and mandatory reader-return prewarm untouched", function()
    local cancelled_jobs = 0
    local live = package.loaded["lib/bookshelf_widget"].live
    live._cancelPreload = function() cancelled_jobs = cancelled_jobs + 1 end
    live._cancelChipPreload = function() cancelled_jobs = cancelled_jobs + 1 end
    live._orbitui_cover_job = { files = { "/private/one", "/private/two" }, callback = function() end }
    live._reader_return_target_file = "/private/reader"
    Host.setPerformanceMode("responsive")
    H.eq(Host.allowSpeculation(), false); H.eq(cancelled_jobs, 2)
    H.eq(#live._orbitui_cover_job.files, 2); H.eq(live._reader_return_target_file, "/private/reader")
    H.eq(saved.android_safe_mode, nil); H.eq(saved.shelf_page_animation, nil)
    Host.setPerformanceMode("existing"); H.eq(Host.allowSpeculation(), true)
end)
H.test("timing is opt-in preserves nil arguments/results and original errors without recording payloads", function()
    Host.resetMeasurements()
    local payload = { file = "/private/secret", token = "PRIVATE_TOKEN" }
    local function call(...)
        H.eq(select("#", ...), 3)
        local a, b, c = ...; H.eq(a, nil); H.eq(b, payload); H.eq(c, nil)
        clock = clock + .002
        return nil, payload, nil
    end
    Host.measure("open", call, nil, payload, nil)
    H.eq(next(Host.performanceSnapshot().timings), nil)
    Host.setMeasuring(true)
    local values = { n = 0 }
    local function capture(...) values = { n = select("#", ...), ... } end
    capture(Host.measure("open", call, nil, payload, nil))
    H.eq(values.n, 3); H.eq(values[1], nil); H.eq(values[2], payload); H.eq(values[3], nil)
    local ok, err = pcall(Host.measure, "open", function() error(payload) end)
    H.eq(ok, false); H.eq(err, payload)
    local report = Host.performanceReport()
    assert(not report:find("private", 1, true)); assert(not report:find("PRIVATE_TOKEN", 1, true))
    H.eq(Host.performanceSnapshot().timings.open.count, 2)
    H.eq(Host.performanceSnapshot().timings.open.errors, 1)
end)
H.test("timing ring is bounded and method hooks are idempotent with later external wrappers preserved", function()
    Host.resetMeasurements()
    local module = { build = function(value) clock = clock + .001; return value, nil end }
    Host.timeMethod(module, "build", "home"); local first = module.build
    Host.timeMethod(module, "build", "home"); H.eq(module.build, first)
    for i = 1, 75 do H.eq(module.build(i), i) end
    local t = Host.performanceSnapshot().timings.home
    H.eq(t.count, 75); H.eq(t.samples, 60); assert(math.abs(t.median - 1) < .00001)
    module.build = function() return "external" end
    Host.timeMethod(module, "build", "home"); H.eq(module.build(), "external")
    Host.resetMeasurements(); H.eq(next(Host.performanceSnapshot().timings), nil)
    H.eq(Host.isMeasuring(), true)
end)
H.test("real adapter animation/cache/screen seams retain original actions when opt-out is selected", function()
    local UI = require("adapters/orbitui_ui")
    local wipe = { resolveSteps = function(key) return key, 5 end }
    UI.wrap("lib/bookshelf_page_wipe", wipe)
    Host.setPerformanceMode("responsive"); H.eq(wipe.resolveSteps("custom"), nil)
    Host.setPerformanceMode("existing"); local key, steps = wipe.resolveSteps("custom")
    H.eq(key, "custom"); H.eq(steps, 5)
    local engine = { _open = function(a, b) return a, b end }
    UI.wrap("engines/sui_screen_engine", engine)
    local a, b = engine._open(false, "screen"); H.eq(a, false); H.eq(b, "screen")
end)
H.test("CPU fallback is labelled separately and a newly available elapsed clock starts a fresh series", function()
    Host.resetMeasurements(); Host.setMeasuring(true)
    local native = package.loaded["ui/time"]
    package.loaded["ui/time"] = nil
    Host.measure("open", function() end)
    H.eq(Host.performanceSnapshot().timings.open.clock, "CPU")
    package.loaded["ui/time"] = native
    Host.measure("open", function() clock = clock + .001 end)
    local sample = Host.performanceSnapshot().timings.open
    H.eq(sample.clock, "elapsed"); H.eq(sample.count, 1)
    Host.measure("/private/unapproved-label", function() end)
    H.eq(Host.performanceSnapshot().timings["/private/unapproved-label"], nil)
end)
H.test("performance and quick-guide menus are bilingual searchable read-only until explicitly chosen", function()
    Host.setMeasuring(false)
    local Settings = require("adapters/orbitui_settings")
    local translate = require("core/orbitui_i18n")
    local before = writes
    local english
    for _, lang in ipairs({ "en", "sv" }) do
        G_reader_settings = { readSetting = function() return lang end }
        local items = Settings.performanceItems()
        if lang == "en" then english = items end
        for i, row in ipairs(items) do
            assert(type(row.text) == "string")
            if lang == "sv" then H.eq(row.text, translate(english[i].text, "sv")); assert(row.text ~= english[i].text) end
        end
        for _, query in ipairs({ "snabbhetsläge", "benchmark", "diagnostik", "memory" }) do
            H.eq(Settings.find(query)[1].id, "performance")
        end
        local guide = Settings.quickStartItems(); H.eq(#guide, 5)
        for i = 2, #guide do assert(guide[i].help_text) end
    end
    H.eq(writes, before)
    G_reader_settings = nil
    local opened, closed, original = nil, 0, Settings.open
    Settings.open = function(id) opened = id end
    Settings.quickStartItems(function() closed = closed + 1 end)[3].callback()
    H.eq(opened, "bookshelf_navigation"); H.eq(closed, 1)
    Settings.open = original
    local choices = Settings.performanceItems()[1].sub_item_table_func()
    choices[3].callback(); H.eq(Host.performanceMode(), "responsive")
    choices[1].callback(); H.eq(Host.performanceMode(), "existing")
end)
H.test("last owner teardown cancels policy and makes captured hooks inert without rewriting saved choices", function()
    local other = {}
    Host.setPerformanceMode("responsive"); Host.setMeasuring(true)
    Host.performanceStarted(other)
    Host.performanceStopped(owner); H.eq(Host.performanceMode(), "responsive")
    local before = writes
    Host.performanceStopped(other)
    H.eq(Host.performanceMode(), "existing"); H.eq(Host.isMeasuring(), false)
    H.eq(home._lru._max_bytes, 64 * MiB); H.eq(shelf._byte_budget, 64 * MiB)
    H.eq(saved[MODE], "responsive"); H.eq(writes, before)
end)
H.finish()
