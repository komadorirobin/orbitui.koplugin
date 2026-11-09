local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local map = dofile(root .. "/core/orbitui_module_map.lua")
local function source(name)
    local f = io.open(root .. "/" .. assert(map[name]), "rb")
    if f then local s = f:read("*a"); f:close(); return s end
    return assert(getmetatable(map).orbitui_embedded[name], name)
end
local function run(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "1.2 upstream boundaries", "t", env))()
end
local widget = source("lib/bookshelf_widget")
local function method(name, env)
    local args, body = widget:match("\nfunction BookshelfWidget:" .. name .. "%((.-)%)\n(.-)\nend\n")
    assert(body, name)
    return run("return function(self" .. (args ~= "" and "," .. args or "") .. ")\n" .. body .. "\nend", env or {})
end

H.test("five new helpers retain exact-source lazy canonical module identities", function()
    for _, name in ipairs({ "bytecode", "page_cache", "pubdate_format", "scale", "slice" }) do
        local key = "lib/bookshelf_" .. name
        H.eq(getmetatable(map).orbitui_embedded[key], source(key))
        assert((loadstring or load)(source(key), "@" .. map[key]))
    end
end)
H.test("hosted bytecode never inserts a competing searcher or creates a cache", function()
    local BC = run(source("lib/bookshelf_bytecode"), { require = function(name)
        if name == "lib/bookshelf_paths" then return { deferBytecodeCache = true } end
        error("unexpected bytecode service: " .. name)
    end })
    local loaders = package.loaders or package.searchers
    local before = {}; for i, f in ipairs(loaders) do before[i] = f end
    BC.install("/no-device/", "/no-cache/"); BC.install()
    H.eq(BC._installed, nil); H.eq(#loaders, #before)
    for i, f in ipairs(before) do H.eq(loaders[i], f) end
    H.eq(BC.data("/not-read.po", "sv", function() return { text = "parsed" } end).text, "parsed")
end)
H.test("host defers whole-page pixels and build-ahead without disabling native thumbnail caches", function()
    local PC = run(source("lib/bookshelf_page_cache"), {})
    H.eq(PC.enabled, true)
    require("adapters/orbitui_ui").wrap("lib/bookshelf_page_cache", PC)
    H.eq(PC.enabled, false)
    local frees = 0
    local pc = PC.new()
    PC.put(pc, { key = "p", rows = { { free = function() frees = frees + 1 end } } })
    H.eq(PC.size(pc), 0); H.eq(PC.take(pc, "p"), nil); H.eq(frees, 1)
    local env = { require = function(name) H.eq(name, "lib/bookshelf_page_cache"); return PC end }
    H.eq(method("_pageCacheKey", env)({}, {}, {}, 2), nil)
    local cancelled = 0
    method("_pageAheadArm", env)({ _pageAheadCancel = function() cancelled = cancelled + 1 end }, 1)
    H.eq(cancelled, 1)
end)
H.test("a late closed or suspended prepaint callback cannot rearm itself", function()
    local runAhead = method("_pageAheadRun")
    for _, state in ipairs({ "_closed", "_orbitui_suspended" }) do
        local cancels = 0
        local w = { [state] = true, _first_paint_done = false,
            _pageAheadCancel = function() cancels = cancels + 1 end }
        runAhead(w); runAhead(w)
        H.eq(cancels, 2); H.eq(w._page_ahead_fn, nil)
    end
end)
H.test("new retained list keys distinguish sections and changed roots but not cursor saves", function()
    local depth = 4
    local key = method("_profileCacheKey", { BookshelfSettings = { read = function() return depth end } })
    local a = { profile = { key = "library", roots = { "/books" } }, _cursor = 1 }
    local b = { profile = { key = "manga", roots = { "/manga" } }, _cursor = 1 }
    assert(key(a) ~= key(b))
    local before = key(a); a._cursor = 800; H.eq(key(a), before)
    a.profile.roots = { "/books" }; H.eq(key(a), before)
    a.profile.roots = { "/new-books" }; assert(key(a) ~= before)
    a.profile.roots = { "/books" }; depth = 5; assert(key(a) ~= before)
end)
H.test("new size and box styles resolve profile preferences rather than unrelated native chips", function()
    local prefs = { spine_same_size = "height", series_boxes = "plain" }
    local env = { require = function() error("must not read a namesake native chip") end }
    local w = { _profileShelfSettings = function() return prefs end }
    H.eq(method("_spineSameSize", env)(w), "height")
    H.eq(method("_seriesBoxPlain", env)(w), true)
    H.eq(method("_seriesBoxStyle", env)(w), nil)
    prefs.series_boxes = "spines"; H.eq(method("_seriesBoxStyle", env)(w), "spines")
end)
H.test("a data generation expires retained lists without losing the page's anchor and deal state", function()
    local generation, fetches = 1, 0
    local env = { Repo = { dataGeneration = function() return generation end },
        logger = { dbg = function() end }, SPINE_ALL_LIMIT = 10000 }
    local w = { chip = "all", _cursor = 1, _drilldown_path = {},
        _fetchChipItems = function() fetches = fetches + 1; return { { filepath = "/book" } } end,
        _prepareSpineItems = function(_, items) return items end,
        _spineItemsSig = function() return "unchanged-list" end,
        _extractionHoldsOrder = function() return false end }
    local fetch = method("_spineCachedFetch", env)
    local items = fetch(w, 10); H.eq(fetches, 1); H.eq(fetch(w, 10), items); H.eq(fetches, 1)
    local deal = { page = true }; w._spine_fetch_cache.page_orn = deal
    generation = 2; assert(fetch(w, 10) ~= items); H.eq(fetches, 2)
    H.eq(w._spine_fetch_cache.page_orn, deal)
    H.eq(w._spine_fetch_cache.data_gen, 2)
end)
H.test("new native control labels retain explicit Swedish and English", function()
    local T = require("core/orbitui_i18n")
    for _, text in ipairs({ "Book sizes", "Varied", "Equal height", "Plain", "Decades",
            "A decade", "Spine text", "Spine text size", "Genres from calibre only" }) do
        assert(T(text, "sv") ~= text, text); H.eq(T(text, "en"), text)
    end
end)
H.test("retired collector and extraction callbacks cannot resume work behind a reader", function()
    local callbacks, owner = {}, nil
    local env = { _gettime = function() return 0 end, BIM_APPLY_GAP_S = 2.5,
        UIManager = { scheduleIn = function(_, _, fn) callbacks[#callbacks + 1] = fn end,
            getTopmostVisibleWidget = function() return owner end } }
    local acc = { paths = { ["/book"] = true }, covers = {} }
    local w = { _bim_ready_acc = acc, _inner_vgroup = {}, _shelf_dims = {}, _bim_applied_at = 0,
        _inputBusyFor = function() return 0 end }
    owner = w
    local apply = method("_applyExtractionReady", env)
    w._applyExtractionReady = apply
    apply(w); H.eq(#callbacks, 1)
    w._bim_apply_fn = nil; callbacks[1](); H.eq(#callbacks, 1)
    H.eq(w._bim_ready_acc, acc)
    owner = {}; apply(w); H.eq(#callbacks, 1); H.eq(w._bim_ready_acc, acc)
    method("_collectWhenQuiet", env)(w, 1000); H.eq(#callbacks, 2)
    w._collect_fn = nil; callbacks[2](); H.eq(#callbacks, 2)
end)
H.test("hot return defers pending extraction results and coalesces repeated starts", function()
    local calls, queue = 0, {}
    local start = method("_startStatusTimer", {
        Repo = { setMetadataRefreshActive = function() end }, package = { loaded = {} },
        UIManager = { scheduleIn = function(_, seconds, fn) H.eq(seconds, .3); queue[#queue + 1] = fn end } })
    local w = { _bim_ready_acc = { paths = { ["/book"] = true } },
        _startFilePoll = function() end, _status_timer_func = function() end,
        _applyExtractionReady = function(self) calls = calls + 1; self._bim_ready_acc = nil end }
    start(w, false); H.eq(#queue, 0)
    start(w); start(w); H.eq(#queue, 1); H.eq(calls, 0)
    queue[1](); H.eq(calls, 1); queue[1](); H.eq(calls, 1)
    H.eq(w._bim_ready_acc, nil)
end)
H.finish()
