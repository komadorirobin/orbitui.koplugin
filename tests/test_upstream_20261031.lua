local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local noop = function() end
local function read(path)
    local file = assert(io.open(root .. "/components/simpleui/" .. path .. ".lua", "rb"))
    local text = file:read("*a"); file:close(); return text
end
local function run(code, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "October 31 upstream", "t", env))()
end
local source = read("modules/module_coverdeck")
local first = assert(source:find("local TiltedCover =", 1, true))
local last = assert(source:find("-- Cache key is independent", first, true))
local code = source:sub(first, last - 1)
    .. "return { entry = tiltEntry, widget = TiltedCover, cache = _tilt_cache }"
local function raster(w, h, kind)
    return { kind = kind, w = w, h = h, stride = w * (kind == 3 and 4 or 1),
        getWidth = function(self) return self.w end,
        getHeight = function(self) return self.h end,
        getType = function(self) return self.kind end,
        blitFrom = function(self, src)
            assert(not self.freed and not src.freed); self.copied = src
        end,
        free = function(self) assert(not self.freed, "double free"); self.freed = true end }
end
local function fixture(native, Warp)
    local s = { calls = 0, buffers = {}, screen = { night_mode = false } }
    local BB = native or { new = function(w, h, kind)
        s.calls = s.calls + 1
        if s.fail and kind == s.fail then error("allocation unavailable") end
        local bb = raster(w, h, kind); s.buffers[#s.buffers + 1] = bb; return bb
    end }
    s.screen.bb = { getType = function() return s.kind end }
    local logger = { warn = noop }
    local memory = run(read("infra/sui_memory"), { require = function(name)
        if name == "logger" then return logger end
        if name == "ui/uimanager" then return { unschedule = noop, scheduleIn = noop } end
        if name == "util" then return { calcFreeMem = function() return 1, 512 * 1024 * 1024 end } end
        error(name)
    end })
    local lru = run(read("infra/sui_lru"), { require = function(name)
        if name == "logger" then return logger end
        H.eq(name, "infra/sui_memory"); return memory
    end })
    local config = { stretchBBToSize = function(src, w, h)
        if s.borrow then return src end
        local bb = BB.new(w, h, src:getType()); bb:blitFrom(src, 0, 0, 0, 0, w, h)
        return bb
    end }
    local warp = Warp or { warp = function(src, w, h)
        local bb = BB.new(w, h, src:getType()); s.warped = bb
        local tops, heights = {}, {}
        for i = 1, w do tops[i], heights[i] = 0, h end
        return { bb = bb, tops = tops, heights = heights }
    end }
    s.module = run(code, { Screen = s.screen, Config = config, CoverWarp = warp,
        Blitbuffer = BB, Memory = memory, LRU = lru, TILT_CACHE_MAX = 16,
        CoverWidgets = { drawProgressBadge = noop }, logger = logger,
        Geom = { new = function(_, value) return value end } })
    s.bb, s.slot = BB, { w = 8, h = 6, flat_w = 8, tilt = .75, align = "left" }
    return s
end
H.test("tilted colour artwork converts to the screen type without freeing its cached source", function()
    local s, original = fixture(), raster(8, 6, 3)
    s.kind = 1
    local entry = assert(s.module.entry(s.slot, "book", original, 1))
    H.eq(entry.bb:getType(), 1); H.eq(entry.bb.copied, s.warped)
    H.eq(s.warped.freed, true); H.eq(original.freed, nil)
    H.eq(s.module.cache:bytes(), 48)
    H.eq(s.module.entry(s.slot, "book", original, 1), entry); H.eq(s.calls, 3)
end)
H.test("matching screen buffers avoid an extra allocation and account for real RGB bytes", function()
    local s, original = fixture(), raster(8, 6, 3)
    s.kind = 3
    local entry = assert(s.module.entry(s.slot, "book", original, 1))
    H.eq(entry.bb, s.warped); H.eq(s.calls, 2); H.eq(original.freed, nil)
    H.eq(s.module.cache:bytes(), 192)
end)
H.test("unavailable conversion falls back, frees only private rasters and remains retryable", function()
    local s, original = fixture(), raster(8, 6, 3)
    s.kind, s.fail = 1, 1
    H.eq(s.module.entry(s.slot, "book", original, 1), nil)
    H.eq(s.warped.freed, true); H.eq(s.module.cache:count(), 0)
    H.eq(original.freed, nil)
    s.fail = nil; assert(s.module.entry(s.slot, "book", original, 1))
end)
H.test("borrowed stretch results are cloned and generated placeholders release their own source", function()
    local s, original = fixture(), raster(8, 6, 3)
    s.kind, s.borrow = 1, true
    assert(s.module.entry(s.slot, "book", original, 1)); H.eq(original.freed, nil)
    local generated = raster(8, 6, 3)
    s.borrow = false
    assert(s.module.entry(s.slot, "generated", nil, nil, function() return generated end))
    H.eq(generated.freed, true); H.eq(original.freed, nil)
end)
H.test("byte-budget eviction dereferences entries still borrowed by widgets", function()
    local s, original = fixture(), raster(8, 6, 3)
    s.kind = 3; s.module.cache:setByteBudget(200)
    local previous = assert(s.module.entry(s.slot, "first", original, 1))
    local current = assert(s.module.entry(s.slot, "second", original, 1))
    H.eq(s.module.cache:count(), 1); H.eq(s.module.cache:bytes(), 192)
    H.eq(s.module.cache:peek("first"), nil)
    H.eq(previous.bb.freed, nil); H.eq(current.bb.freed, nil); H.eq(original.freed, nil)
end)
H.test("day and night painting preserve trapezoid spans and choose the native blit", function()
    local s, original = fixture(), raster(8, 6, 3)
    s.kind = 1
    local entry = assert(s.module.entry(s.slot, "book", original, 1))
    local widget = setmetatable({ w = 8, h = 6, entry = entry }, s.module.widget)
    local calls = {}
    local bb = { blitFrom = function(_, src, x, y, sx, sy, w, h)
        calls[#calls + 1] = "day"; H.eq(src, entry.bb); H.eq(x, 2); H.eq(w, 8); H.eq(h, 6)
    end, invertblitFrom = function(_, src) calls[#calls + 1] = "night"; H.eq(src:getType(), 1) end }
    widget:paintTo(bb, 2, 3); s.screen.night_mode = true; widget:paintTo(bb, 2, 3)
    H.eq(table.concat(calls, ","), "day,night")
end)

-- Optional unmodified KOReader blitbuffer/CBB plus the real perspective warp.
local native = os.getenv("ORBITUI_NATIVE_BB_DIR")
if native then
    local ffi = require("ffi")
    ffi.cdef[[void *malloc(size_t); void *calloc(size_t,size_t); void free(void *);]]
    package.loaded["ffi/posix_h"] = true
    package.loaded["ffi/util"] = { idiv = function(a, b) return math.floor(a / b) end }
    ffi.loadlib = function() return ffi.load(assert(os.getenv("ORBITUI_NATIVE_BB_LIB"))) end
    local BB = dofile(native .. "/ffi/blitbuffer.lua")
    local warp = run(read("engines/sui_cover_warp"), { require = function(name)
        if name == "ffi/blitbuffer" then return BB end
        if name == "features/sui_style" then return { COLOR = {}, BADGE_BORDER_SZ = 0 } end
        return require(name)
    end })
    H.test("native grey/RGB tilted covers survive CBB and software day-night painting", function()
        for _, cbb in ipairs({ true, false }) do for _, kind in ipairs({ BB.TYPE_BB8, BB.TYPE_BBRGB32 }) do
            BB:setUseCBB(cbb)
            local source_kind = kind == BB.TYPE_BB8 and BB.TYPE_BBRGB32 or BB.TYPE_BB8
            local s = fixture(BB, warp); s.kind = kind
            local original = BB.new(8, 6, source_kind); original:fill(BB.ColorRGB32(150, 100, 50, 255))
            local entry = assert(s.module.entry(s.slot, "native", original, 1))
            H.eq(entry.bb:getType(), kind)
            local target = BB.new(8, 6, kind)
            local widget = setmetatable({ w = 8, h = 6, entry = entry }, s.module.widget)
            widget:paintTo(target, 0, 0)
            local before = target:getPixel(0, 0):getColor8().a
            s.screen.night_mode = true; widget:paintTo(target, 0, 0)
            H.eq(target:getPixel(0, 0):getColor8().a, 255 - before)
            H.eq(s.module.cache:bytes(), tonumber(entry.bb.stride) * entry.bb:getHeight())
            H.eq(original:getWidth(), 8)
            target:free(); original:free(); entry.bb:free()
        end end
        BB:setUseCBB(true)
    end)
end
H.finish()
