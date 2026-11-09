local M = {}
local names = { "bookshelf", "simpleui" }

function M.attach(owner, classes, loader, root)
    assert(owner.ui, "OrbitUI requires a FileManager or ReaderUI host")
    local prefix = owner.ui.document and "reader" or "filemanager"
    owner._orbitui_components = {}
    for _, name in ipairs(names) do
        assert(not owner.ui[name], "Host already owns " .. name)
        assert(classes[name], "Missing component " .. name)
    end
    -- Allocate both first so cross-component callbacks resolve during init.
    for _, name in ipairs(names) do
        local class = assert(classes[name], "Missing component " .. name)
        local instance = class:extend{
            ui = owner.ui,
            path = root .. "/components/" .. name,
            name = prefix .. name,
            _orbitui_owned = true,
        }
        owner._orbitui_components[name] = instance
        owner.ui[name] = instance
        if loader.loaded_plugins then loader.loaded_plugins[name] = instance end
        owner[#owner + 1] = instance
    end
    for _, name in ipairs(names) do
        local instance = owner._orbitui_components[name]
        if instance._init then instance:_init() end
        if instance.init then instance:init() end
    end
    local refresh = package.loaded["lib/bookshelf_menu_close_refresh"]
    if refresh and refresh.acquire then refresh.acquire(owner) end
    M.performanceStarted(owner)
    require("adapters/orbitui_integrations").statusImport.started(owner)
end

function M.detach(owner, loader)
    local refresh = package.loaded["lib/bookshelf_menu_close_refresh"]
    if refresh and refresh.release then refresh.release(owner) end
    local navbar = package.loaded["adapters/orbitui_navbar"]
    if navbar then navbar.quickControlsEvent("teardown", owner.ui) end
    M.performanceStopped(owner)
    local integrations = package.loaded["adapters/orbitui_integrations"]
    if integrations then integrations.statusImport.stopped(owner) end
    local libraries = package.loaded["adapters/orbitui_libraries"]
    local bookshelf = owner._orbitui_components and owner._orbitui_components.bookshelf
    if bookshelf and libraries and libraries.unwireReaderMenu then
        libraries.unwireReaderMenu(owner.ui, bookshelf)
    end
    for _, name in ipairs(names) do
        local instance = owner._orbitui_components and owner._orbitui_components[name]
        if instance then
            if owner.ui[name] == instance then owner.ui[name] = nil end
            if owner.ui._simpleui_plugin == instance then owner.ui._simpleui_plugin = nil end
            if loader.loaded_plugins and loader.loaded_plugins[name] == instance then
                loader.loaded_plugins[name] = nil
            end
        end
    end
end

function M.abort(owner, loader)
    for i = #owner, 1, -1 do
        local instance = owner[i]
        if instance._cancelReaderPrewarm then pcall(instance._cancelReaderPrewarm, instance) end
        if instance.onTeardown then pcall(instance.onTeardown, instance) end
        owner[i] = nil
    end
    M.detach(owner, loader)
end

function M.propagate(owner, event, report)
    local navbar = package.loaded["adapters/orbitui_navbar"]
    if navbar then navbar.quickControlsEvent(event.handler, owner.ui) end
    M.performanceEvent(event.handler)
    local integrations = package.loaded["adapters/orbitui_integrations"]
    if integrations then integrations.statusImport.event(event.handler) end
    for _, instance in ipairs(owner) do
        local ok, consumed = pcall(instance.handleEvent, instance, event)
        if not ok then
            report(instance.name, consumed)
        elseif consumed then
            return true
        end
    end
    return false
end

-- Shared opt-in policy/diagnostics live here to keep the installed API-1 path
-- set unchanged. No third-party implementation is embedded. These helpers do
-- not own reading state, disk caches, image quality, reader parking or sync.
local MiB = 1024 * 1024
local mode, measuring, suspended = "existing", false, false
local owners = setmetatable({}, { __mode = "k" })
local caches = setmetatable({}, { __mode = "k" })
local observations, policy = {}, { pressure = "unknown", factor = 1 }
local pending, generation = nil, 0
local MODE_KEY, MEASURE_KEY = "simpleui_orbitui_performance_mode", "simpleui_orbitui_measure_performance"
local modes = { existing = true, adaptive = true, responsive = true }
local labels = {
    home = "Home build", dashboard = "Dashboard build", shelf = "Shelf rebuild",
    next = "Shelf next page", previous = "Shelf previous page", open = "Book open call",
    close = "Book close event", library = "Open Bookshelf call", return_shelf = "Return to shelf call",
    search = "Library search", browse = "Browse filter and sort", settings = "Settings search",
    details = "Book details build",
}
local function settings() return package.loaded["infra/sui_store"] end
local function readOptions()
    local store = settings()
    local value = store and store:readSetting(MODE_KEY)
    mode = modes[value] and value or "existing"
    measuring = store and store:readSetting(MEASURE_KEY) == true or false
end
function M.performanceMode() return mode end
function M.isMeasuring() return measuring end
function M.resetMeasurements() observations = {} end

-- One batch of BIM rows can back several independently scoped light maps.
-- Keep the expensive, immutable text derivation once, not its render/status
-- mutations. Each scope receives its own copy. No new disk cache or writer.
function M.shareLightMetadata(repo)
    if repo._orbitui_shared_light_metadata then return end
    repo._orbitui_shared_light_metadata = true
    local source, cache, ring, cursor = nil, {}, {}, 0
    local function reset()
        source, cache, ring, cursor = nil, {}, {}, 0
    end
    local function copy(value, seen)
        if type(value) ~= "table" then return value end
        seen = seen or {}
        if seen[value] then return seen[value] end
        local out = {}; seen[value] = out
        for key, item in pairs(value) do out[key] = copy(item, seen) end
        return out
    end
    repo.deriveLightRecord = function(fp, info, rows, build)
        if source ~= rows then reset(); source = rows end
        local now = os.time()
        local hit = cache[fp]
        if not hit or hit.info ~= info or now >= hit.expires then
            -- Publish only successful derivations. Failed metadata/provider
            -- reads retain the native retry/error contract.
            local record = build(fp, info)
            if type(record) ~= "table" then return record end
            cursor = cursor % 4096 + 1
            local old = ring[cursor]
            if old and cache[old.fp] == old then cache[old.fp] = nil end
            hit = { fp = fp, info = info, record = record, expires = now + 60 }
            cache[fp], ring[cursor] = hit, hit
        end
        return copy(hit.record)
    end
    for _, key in ipairs({ "invalidateWalkCache", "invalidateSeriesCache", "invalidateLightMeta",
            "invalidateBookCache", "invalidateCalibreCache", "lightMetaReady", "forgetBook" }) do
        local native = repo[key]
        if type(native) == "function" then
            repo[key] = function(...) reset(); return native(...) end
        end
    end
end

-- Exact-size copies already produced by Bookshelf's native renderer. Reuse
-- the shared byte-bounded LRU rather than the component's FIFO, and do not
-- pin the much larger canonical source after its own cache has evicted it.
-- No pixels, disk-cache policy, saved budget or scaling algorithm changes.
local thumbnail_caches = setmetatable({}, { __mode = "k" })
function M.coverThumbnails(widget)
    if widget.coverThumbFor then return end -- an external owner wins
    local cache, Memory, registered
    local function reset()
        if cache then cache:clear() end
        registered = false
    end
    widget.coverThumbFor = function(fp, src, w, h)
        if type(fp) ~= "string" or fp == "" or not src
                or type(w) ~= "number" or type(h) ~= "number"
                or w < 1 or h < 1 or w ~= w or h ~= h
                or w == math.huge or h == math.huge then return nil end
        if not cache then
            Memory = require("infra/sui_memory")
            cache = require("infra/sui_lru").new{ max_entries = 96, max_bytes = 12 * MiB }
            thumbnail_caches[cache] = true
            widget._orbitui_cover_thumbnails = cache
            M.performanceCache(cache, "thumbnail")
        end
        if not registered then Memory.onReset(reset); registered = true end
        local ok, sw, sh, kind, rotation, inverse, stride, pixel_stride = pcall(function()
            return src:getWidth(), src:getHeight(), src.getType and src:getType(),
                src.getRotation and src:getRotation(), src.getInverse and src:getInverse(),
                tonumber(src.stride), tonumber(src.pixel_stride)
        end)
        if not ok then return nil end
        local key = w .. "x" .. h
        local hit = cache:get(key, fp)
        if hit and hit.source[1] == src and hit.sw == sw and hit.sh == sh
                and hit.kind == kind and hit.rotation == rotation
                and hit.inverse == inverse and hit.stride == stride
                and hit.pixel_stride == pixel_stride then return hit.bb end
        local success, scaled = pcall(function()
            return require("ui/renderimage"):scaleBlitBuffer(src, w, h, false)
        end)
        if not (success and scaled) then return nil end
        local bytes = Memory.bbBytes(scaled)
        if bytes > 0 then
            cache:put(key, {
                bb = scaled, source = setmetatable({ src }, { __mode = "v" }),
                sw = sw, sh = sh, kind = kind, rotation = rotation, inverse = inverse,
                stride = stride, pixel_stride = pixel_stride,
            }, bytes, fp)
        end
        return scaled
    end
end

-- The original source cache still owns refresh, contrast changes and disk
-- deletion. Retire only our derived copies, preserving native nils/errors.
function M.thumbnailSourceCache(module)
    if module._orbitui_thumbnail_invalidation then return end
    module._orbitui_thumbnail_invalidation = true
    for _, key in ipairs{ "drop", "dropMemory", "clear" } do
        local native = module[key]
        if type(native) == "function" then
            module[key] = function(self, ...)
                local fp = ...
                for cache in pairs(thumbnail_caches) do
                    if key == "drop" then pcall(cache.removeScope, cache, fp)
                    else pcall(cache.clear, cache) end
                end
                return native(self, ...)
            end
        end
    end
end

local function memory()
    local util = package.loaded.util
    if not util then local ok, loaded = pcall(require, "util"); if ok then util = loaded end end
    if not (type(util) == "table" and type(util.calcFreeMem) == "function") then return nil, nil end
    local ok, available, total = pcall(util.calcFreeMem)
    if not ok or type(available) ~= "number" or type(total) ~= "number"
            or available ~= available or total ~= total or available < 0 or total <= 0
            or available > total or total == math.huge then return nil, nil end
    return available, total
end

-- Pure, conservative cover-cache policy. Unknown readings never invent RAM
-- or shrink a cache. This caps retained cache entries, not all live native
-- images (a visible/parked widget may correctly keep its own borrowed image).
function M.memoryPolicy(selected, available, total, reader)
    local result = { pressure = "unknown", factor = 1 }
    if selected == "existing" or not modes[selected] then return result end
    if type(available) ~= "number" or type(total) ~= "number" or total <= 0
            or available ~= available or total ~= total or available < 0
            or available > total or total == math.huge then return result end
    local ratio = available / total
    result.pressure = ratio < .15 and "critical" or ratio < .25 and "low" or "normal"
    result.factor = result.pressure == "critical" and .35 or result.pressure == "low" and .60 or 1
    -- Keep the active shelf's widget tree/return state. Only inactive cache
    -- references are reduced; there is no reader-close/GC on the paint path.
    if reader then result.factor = result.factor * .75 end
    result.available, result.total = available, total
    return result
end

local function readerVisible()
    local Reader = package.loaded["apps/reader/readerui"]
    local UI = package.loaded["ui/uimanager"]
    local reader = Reader and Reader.instance
    if not (reader and reader.document and UI and UI.isWidgetShown) then return false end
    local ok, shown = pcall(UI.isWidgetShown, UI, reader)
    return ok and shown == true
end

local function effectiveBudget(base)
    return math.min(base, math.max(math.min(base, 2 * MiB), math.floor(base * policy.factor)))
end

local function currentShelf()
    local Widget = package.loaded["lib/bookshelf_widget"]
    return Widget and Widget.live and not Widget.live._closed and Widget.live or nil
end

function M.allowSpeculation()
    return not suspended and mode ~= "responsive" and (mode == "existing" or policy.pressure ~= "critical")
end

function M.applyMemoryPolicy()
    local available, total
    if mode ~= "existing" then available, total = memory() end
    policy = M.memoryPolicy(mode, available, total, readerVisible())
    for cache, entry in pairs(caches) do
        local before = cache._bytes or 0
        entry.setter(cache, effectiveBudget(entry.base))
        if entry.kind == "shelf" and before > (cache._bytes or 0) then
            local Memory = package.loaded["infra/sui_memory"]
            if Memory and Memory.noteReleased then Memory.noteReleased(before - cache._bytes) end
        end
    end
    if not M.allowSpeculation() then
        local shelf = currentShelf()
        if shelf then
            if shelf._cancelPreload then shelf:_cancelPreload() end
            if shelf._cancelChipPreload then shelf:_cancelChipPreload() end
            if shelf._pageAheadCancel then shelf:_pageAheadCancel() end
        end
    end
end

local function cancelPolicy()
    generation = generation + 1
    local UI = package.loaded["ui/uimanager"]
    if pending and UI and UI.unschedule then UI:unschedule(pending) end
    pending = nil
end
local function schedulePolicy()
    cancelPolicy()
    if mode == "existing" or suspended or not next(owners) then return end
    local UI = package.loaded["ui/uimanager"]
    if not (UI and UI.scheduleIn) then return end
    local token = generation
    pending = function()
        if token ~= generation or suspended or not next(owners) then return end
        pending = nil
        generation = generation + 1
        M.applyMemoryPolicy()
    end
    UI:scheduleIn(1.5, pending)
end

-- Register only already-loaded native caches. Base budget writers remain the
-- owners of saved preferences; a later user change updates the base rather
-- than being overwritten with a reduced runtime value.
function M.performanceCache(module, kind)
    local cache = module._lru or module
    if caches[cache] or type(cache.setByteBudget) ~= "function" then return end
    local base = cache._max_bytes or cache._byte_budget
    if type(base) ~= "number" or base < 1 then return end
    local entry = { setter = cache.setByteBudget, base = base, kind = kind }
    caches[cache] = entry
    cache.setByteBudget = function(self, bytes)
        if type(bytes) == "number" and bytes == bytes and bytes >= 1 and bytes < math.huge then
            entry.base = math.floor(bytes)
            return entry.setter(self, effectiveBudget(entry.base))
        end
        return entry.setter(self, bytes)
    end
    schedulePolicy()
end

function M.setPerformanceMode(value)
    assert(modes[value], "Unknown performance mode")
    local store = assert(settings(), "Settings are not ready")
    store:saveSetting(MODE_KEY, value)
    mode = value
    cancelPolicy()
    M.applyMemoryPolicy()
end
function M.setMeasuring(value)
    assert(settings(), "Settings are not ready"):saveSetting(MEASURE_KEY, value == true)
    measuring = value == true
end

function M.performanceStarted(owner)
    owners[owner] = true
    suspended = false
    readOptions()
    schedulePolicy()
end
function M.performanceStopped(owner)
    owners[owner] = nil
    if not next(owners) then
        cancelPolicy()
        -- Captured hooks may still be reachable by a later external wrapper.
        -- Leave them inert and restore only runtime caps, never preferences.
        mode, measuring = "existing", false
        policy = { pressure = "unknown", factor = 1 }
        for cache, entry in pairs(caches) do entry.setter(cache, entry.base) end
    end
end
function M.performanceEvent(handler)
    if handler == "onSuspend" then suspended = true; cancelPolicy()
    elseif handler == "onResume" then suspended = false; schedulePolicy()
    elseif handler == "onReaderReady" or handler == "onCloseDocument" then schedulePolicy() end
end

local unpackValues = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end
function M.measure(label, fn, ...)
    if not measuring or not labels[label] then return fn(...) end
    local time = package.loaded["ui/time"]
    local native = time and time.now and time.since and time.to_us
    local start = native and time.now() or os.clock()
    local result = pack(pcall(fn, ...))
    local elapsed = native and time.to_us(time.since(start)) / 1000 or (os.clock() - start) * 1000
    local entry = observations[label]
    local clock_kind = native and "elapsed" or "CPU"
    -- Do not mix CPU fallback and monotonic elapsed samples in one series.
    if not entry or entry.clock ~= clock_kind then
        entry = { count = 0, errors = 0, times = {}, clock = clock_kind }; observations[label] = entry
    end
    entry.count = entry.count + 1
    if not result[1] then entry.errors = entry.errors + 1 end
    if elapsed == elapsed and elapsed >= 0 and elapsed < math.huge then
        if #entry.times == 60 then table.remove(entry.times, 1) end
        entry.times[#entry.times + 1] = elapsed
    end
    if not result[1] then error(result[2], 0) end
    return unpackValues(result, 2, result.n)
end
function M.timeMethod(module, key, label)
    local original = module[key]
    if type(original) ~= "function" or not labels[label] then return end
    local entries = module._orbitui_timing_wrappers
    if not entries then entries = {}; module._orbitui_timing_wrappers = entries end
    -- Mark on the module, not a global owner table which could retain it via
    -- the original function's upvalues on Lua 5.1. Later external hooks win.
    if entries[key] then return end
    local wrapped = function(...)
        if mode == "existing" then return M.measure(label, original, ...) end
        local result = pack(M.measure(label, original, ...))
        schedulePolicy()
        return unpackValues(result, 1, result.n)
    end
    entries[key], module[key] = wrapped, wrapped
end

-- Fixed scalar allowlist only: no book names/paths, profile names, identifiers,
-- credentials, raw errors, screenshots or provider data leave their owners.
function M.performanceSnapshot()
    local result = { mode = mode, measuring = measuring, pressure = policy.pressure,
        lua_kib = collectgarbage("count"), caches = {}, timings = {} }
    result.available, result.total = memory()
    for cache, entry in pairs(caches) do
        local module = package.loaded[entry.kind == "home" and "infra/sui_cover_cache" or "lib/bookshelf_scaled_cover_cache"] or {}
        result.caches[entry.kind] = { bytes = cache._bytes or 0,
            budget = cache._max_bytes or cache._byte_budget, base = entry.base,
            count = cache._count or #(cache._order or {}),
            hits = module._hits, puts = module._puts, evictions = module._evictions }
    end
    for label, entry in pairs(observations) do
        local times = {}
        for i, value in ipairs(entry.times) do times[i] = value end
        table.sort(times)
        result.timings[label] = { count = entry.count, errors = entry.errors, samples = #times,
            median = times[math.ceil(#times / 2)] or 0,
            p90 = times[math.ceil(#times * .9)] or 0, clock = entry.clock }
    end
    local shelf = currentShelf()
    local job = shelf and shelf._orbitui_cover_job
    result.cover_queue = job and #(job.files or {}) or 0
    return result
end

function M.performanceReport()
    local _ = require("core/orbitui_i18n")
    local data = M.performanceSnapshot()
    local lines = { _("OrbitUI performance report"),
        _("Synchronous call timings only; not screen latency. Lua memory excludes native image buffers. At most 60 recent samples per operation. This report does not force garbage collection."),
        _("Performance profile") .. ": " .. _(({ existing = "Keep existing behaviour",
            adaptive = "Adaptive memory", responsive = "Responsive" })[data.mode]),
        _("Lua memory (KiB)") .. ": " .. string.format("%.0f", data.lua_kib),
        _("Memory pressure") .. ": " .. _(({ unknown = "Unknown", normal = "Normal", low = "Low", critical = "Critical" })[data.pressure]),
        _("Pending local covers") .. ": " .. data.cover_queue }
    if data.available then lines[#lines + 1] = _("Available / total memory (MiB)") .. ": "
        .. string.format("%.1f / %.1f", data.available / MiB, data.total / MiB) end
    for _i, kind in ipairs({ "home", "shelf" }) do
        local cache = data.caches[kind]
        if cache then lines[#lines + 1] = (kind == "home" and _("Home cover cache") or _("Bookshelf cover cache"))
            .. string.format(": %.1f / %.1f MiB; n=%d", cache.bytes / MiB, cache.budget / MiB, cache.count)
            .. (cache.hits and string.format("; %s=%d; %s=%d", _("Hits"), cache.hits, _("Puts"), cache.puts or 0) or "") end
    end
    local order = { "home", "dashboard", "shelf", "next", "previous", "open", "close", "library", "return_shelf",
        "search", "browse", "settings", "details" }
    for _i, id in ipairs(order) do
        local timing = data.timings[id]
        if timing then lines[#lines + 1] = _(labels[id]) .. string.format(
            ": n=%d (%d); p50=%.2f; p90=%.2f ms [%s]; %s=%d",
            timing.count, timing.samples, timing.median, timing.p90,
            timing.clock == "CPU" and "CPU" or _("Elapsed"), _("Errors"), timing.errors) end
    end
    lines[#lines + 1] = _("No book paths, titles, accounts or raw errors are included. Nothing is uploaded.")
    return table.concat(lines, "\n\n")
end

return M
