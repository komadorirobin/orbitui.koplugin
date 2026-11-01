local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = io.open(root .. "/" .. path, "rb")
    if f then local text = f:read("*a"); f:close(); return text end
    local map = dofile(root .. "/core/orbitui_module_map.lua")
    for name, source in pairs(getmetatable(map).orbitui_embedded) do
        if map[name] == path then return source end
    end
    error("Missing reviewed source: " .. path)
end
local function run(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "6.2 integration", "t", env))()
end
local menuCode = read("components/bookshelf/lib/bookshelf_menu_close_refresh.lua")
local function menuFixture()
    local state = { native = 0, dirty = 0, shelf = true }
    local TM = { onCloseWidget = function(_, ...) state.native = state.native + 1; return ... end }
    state.original = TM.onCloseWidget
    local deps = { UIManager = { setDirty = function() state.dirty = state.dirty + 1 end },
        GZ = { shelfBelow = function() return state.shelf end },
        Screen = { scaleBySize = function(_, n) return n end,
            getWidth = function() return 100 end, getHeight = function() return 100 end } }
    state.module = run(menuCode, { require = function(name)
        H.eq(name, "ui/geometry"); return { new = function(_, r) return r end }
    end })
    state.tm, state.deps = TM, deps
    state.menu = setmetatable({ dimen = { x = 0, y = 0, w = 90, h = 40 } }, { __index = TM })
    return state
end
H.test("menu refresh owners share one hook and last release restores native behavior", function()
    local s, a, b = menuFixture(), {}, {}
    s.module.acquire(a, s.tm, s.deps); local wrapped = s.tm.onCloseWidget
    s.module.acquire(b, s.tm, s.deps); H.eq(s.tm.onCloseWidget, wrapped)
    s.menu:onCloseWidget(); H.eq(s.dirty, 1); H.eq(s.native, 0)
    s.module.release(a); s.menu:onCloseWidget(); H.eq(s.dirty, 2)
    s.module.release(b); H.eq(s.tm.onCloseWidget, s.original)
    H.eq(s.menu:onCloseWidget("native"), "native"); H.eq(s.native, 1)
end)
H.test("later wrappers survive release and reinstall without duplicate active effects", function()
    local s, owner = menuFixture(), {}
    s.module.acquire(owner, s.tm, s.deps)
    local inner = s.tm.onCloseWidget
    local external = function(self, ...) return inner(self, ...) end
    s.tm.onCloseWidget = external
    s.module.release(owner); H.eq(s.tm.onCloseWidget, external)
    local a, b, c = s.menu:onCloseWidget(nil, "middle", nil)
    H.eq(a, nil); H.eq(b, "middle"); H.eq(c, nil); H.eq(s.dirty, 0)
    s.module.acquire(owner, s.tm, s.deps)
    s.menu:onCloseWidget(); H.eq(s.dirty, 1)
    s.shelf = nil; s.menu:onCloseWidget(); H.eq(s.native, 2)
    s.module.release(owner); H.eq(s.tm.onCloseWidget, external)
end)
H.test("host attach and detach acquire the loaded menu owner without changing component events", function()
    local Host = require("core/orbitui_host")
    local original = package.loaded["lib/bookshelf_menu_close_refresh"]
    local acquired, released
    package.loaded["lib/bookshelf_menu_close_refresh"] = {
        acquire = function(owner) acquired = owner end,
        release = function(owner) released = owner end }
    local Widget = H.widget()
    local owner, loader = { ui = {} }, { loaded_plugins = {} }
    Host.attach(owner, { bookshelf = Widget, simpleui = Widget }, loader, "/plugin")
    H.eq(acquired, owner); H.eq(owner.ui.bookshelf, owner[1])
    Host.detach(owner, loader); H.eq(released, owner); H.eq(owner.ui.bookshelf, nil)
    package.loaded["lib/bookshelf_menu_close_refresh"] = original
end)
local widget = read("components/bookshelf/lib/bookshelf_widget.lua")
H.test("hidden footer reserves its small margin while visible modes preserve custom dimensions", function()
    local mode, selected, enabled, ctx = "show", false, true, nil
    local env = { BookshelfWidget = {}, Screen = { scaleBySize = function(_, n) return n end },
        SIMPLEUI_USE_OFFICIAL_FOOTER = enabled, _footerMode = function() return mode end,
        _paginationFooterVisibleReserve = function(base, top, bottom)
            return math.max(1, base + top + bottom) - math.min(0, top)
        end }
    run(assert(widget:match("(function BookshelfWidget:_paginationFooterReserveHeight%b().-\nend)")), env)
    local shelf = setmetatable({ _selection = { isActive = function() return selected end },
        _getSimpleUIBarContext = function() return ctx end,
        _paginationFooterBaseHeight = function() return 60 end,
        _paginationFooterTopMargin = function() return -10 end,
        _paginationFooterBottomMargin = function() return 20 end }, { __index = env.BookshelfWidget })
    H.eq(shelf:_paginationFooterReserveHeight(), 80)
    mode = "invisible"; H.eq(shelf:_paginationFooterReserveHeight(), 80)
    mode = "hide"; H.eq(shelf:_paginationFooterReserveHeight(), 12)
    ctx, env.SIMPLEUI_USE_OFFICIAL_FOOTER = {}, false
    H.eq(shelf:_paginationFooterReserveHeight(), 0)
    selected = true; H.eq(shelf:_paginationFooterReserveHeight(), 12)
end)
H.test("invisible-footer scratch is restored and freed even if the button painter fails", function()
    local saved, target = {}, { value = "background" }
    function target:blitFrom(src) self.value = src.value end
    function target:getType() return 1 end
    function saved:blitFrom(src) self.value = src.value end
    function saved:free() self.freed = true end
    local f = run(assert(widget:match("\n(local function _paintUnseen%b().-\nend)")) .. "\nreturn _paintUnseen", {
        require = function(name)
            if name == "ffi/blitbuffer" then return { new = function() return saved end } end
            H.eq(name, "lib/bookshelf_clip_bb"); return { real = function(bb) return bb end }
        end })
    local ok, err = pcall(f, target, 0, 0, 10, 10, function()
        target.value = "buttons"; error("paint failure")
    end)
    H.eq(ok, false); assert(tostring(err):find("paint failure", 1, true))
    H.eq(target.value, "background"); H.eq(saved.freed, true)
end)
H.test("minute refreshes coalesce and async callbacks retire on replaced pages or hidden shelves", function()
    local Hero, refreshes, later, current = {}, 0, nil, nil
    local entry = { module = "clock", id = 1 }
    local shelf = { chip = "fiction", _shelf_minute_cells = { entry, chip = "fiction" } }
    current = shelf
    Hero._hostOf = function() return { refresh = function() refreshes = refreshes + 1 end } end
    Hero._shelfView = function() return {} end
    local module = { on_minute = function(ctx) later = ctx.refresh; ctx.refresh(); ctx.refresh() end }
    run(assert(read("components/bookshelf/lib/bookshelf_hero_modules.lua"):match(
        "(function HeroModules%._tickShelfMinuteHooks%b().-\nend)")), {
        HeroModules = Hero, UIManager = { getTopmostVisibleWidget = function() return current end },
        Modules = { get = function() return module end },
        require = function() return { entryConfig = function() return {} end } end })
    H.eq(Hero._tickShelfMinuteHooks(shelf), true); H.eq(refreshes, 1)
    later(); H.eq(refreshes, 2)
    current = {}; later(); H.eq(refreshes, 2)
    current = shelf; shelf._shelf_minute_cells = { entry, chip = "fiction" }
    later(); H.eq(refreshes, 2)
    Hero._tickShelfMinuteHooks(shelf); H.eq(refreshes, 3)
    shelf._closed = true; later(); H.eq(refreshes, 3)
end)
H.test("rounded RGB calls preserve software inversion and restore errors without double guards", function()
    local android, cbb = true, true
    local BB = { getUseCBB = function() return cbb end, isColor8 = function(c) return not c.rgb end }
    local Color = run(read("components/bookshelf/lib/bookshelf_color.lua"), { require = function(name)
        if name == "ffi/blitbuffer" then return BB end
        H.eq(name, "device"); return { isAndroid = function() return android end }
    end })
    local bb = { inverse = 1, getInverse = function(self) return self.inverse end,
        setInverse = function(self, v) self.inverse = v end }
    function bb:paintRoundedRectRGB32() H.eq(self.inverse, cbb and android and 0 or 1); return 12 end
    for _, flags in ipairs({ {true, true}, {true, false}, {false, true} }) do
        android, cbb = flags[1], flags[2]
        H.eq(Color.paintRoundedRect(bb, 0, 0, 10, 10, { rgb = true }, 2), 12)
        H.eq(bb.inverse, 1)
    end
    android, cbb = true, true
    function bb:paintRoundedRectRGB32() H.eq(self.inverse, 0); error("RGB failure") end
    H.eq(pcall(Color.paintRoundedRect, bb, 0, 0, 10, 10, { rgb = true }, 2), false)
    H.eq(bb.inverse, 1)
end)
H.test("new labels translate to Swedish and English without changing defaults", function()
    local I = require("core/orbitui_i18n")
    for _, text in ipairs({ "Image contrast", "Wallpaper contrast", "Wallpaper brightness",
            "Covers and ornaments contrast boost", "Footer bar", "Invisible buttons",
            "Read calibre metadata.calibre" }) do
        assert(I(text, "sv") ~= text, text)
        H.eq(I(text, "en"), text)
    end
    local IC = run(read("components/bookshelf/lib/bookshelf_image_contrast.lua"), {
        require = function() return { read = function(_, default) return default end } end })
    H.eq(IC.boost(), 0); H.eq(IC.wallpaperKey(), "")
end)
-- Optional pixel checks against the pinned unmodified KOReader FFI buffer.
-- These run outside the shipped ZIP, with LuaJIT and the native C blitter.
local native = os.getenv("ORBITUI_NATIVE_BB_DIR")
if native then
    local ffi = require("ffi")
    ffi.cdef[[void *malloc(size_t); void *calloc(size_t,size_t); void free(void *);]]
    package.loaded["ffi/posix_h"] = true
    package.loaded["ffi/util"] = { idiv = function(a, b) return math.floor(a / b) end }
    ffi.loadlib = function() return ffi.load(assert(os.getenv("ORBITUI_NATIVE_BB_LIB"))) end
    local BB = dofile(native .. "/ffi/blitbuffer.lua")
    local values = { image_contrast_boost = 50 }
    local IC = run(read("components/bookshelf/lib/bookshelf_image_contrast.lua"), {
        require = function(name)
            if name == "lib/bookshelf_settings_store" then
                return { read = function(key, default) return values[key] or default end }
            end
            return require(name)
        end })
    local formats = { { BB.TYPE_BB8, 1 }, { BB.TYPE_BB8A, 2 },
        { BB.TYPE_BBRGB24, 3 }, { BB.TYPE_BBRGB32, 4 } }
    H.test("native contrast LUT handles grey and RGB strides without changing alpha or raw copies", function()
        local lut = IC.wallpaperLUT(100, .2, .3)
        for _, spec in ipairs(formats) do
            local bb, bpp = BB.new(3, 2, spec[1]), spec[2]
            local size = tonumber(bb.stride) * tonumber(bb.h)
            local p = ffi.cast("uint8_t *", bb.data)
            ffi.fill(p, size, 77)
            for y = 0, 1 do for x = 0, 2 do
                local q = p + y * bb.stride + x * bpp
                q[0] = 20 + 60 * x
                if bpp >= 3 then q[1], q[2] = 40 + 50 * x, 60 + 40 * x end
                if bpp == 2 or bpp == 4 then q[bpp - 1] = x == 0 and 0 or 190 end
            end end
            local raw = bb:copy()
            local before = ffi.string(raw.data, size)
            assert(IC.applyLUT(bb, lut))
            for y = 0, 1 do for x = 0, 2 do
                local q = p + y * bb.stride + x * bpp
                if bpp <= 2 then H.eq(tonumber(q[0]), lut[20 + 60 * x]) else
                    local r, g, b = IC.shiftRGB(20 + 60 * x, 40 + 50 * x, 60 + 40 * x, lut)
                    H.eq(tonumber(q[0]), r); H.eq(tonumber(q[1]), g); H.eq(tonumber(q[2]), b)
                end
                if bpp == 2 or bpp == 4 then H.eq(tonumber(q[bpp - 1]), x == 0 and 0 or 190) end
            end end
            H.eq(ffi.string(raw.data, size), before)
            bb:free(); raw:free()
        end
    end)
    H.test("native boosted buffers and derived copies are marked once while raw input stays unmarked", function()
        local raw = BB.new(3, 1, BB.TYPE_BB8)
        local p = ffi.cast("uint8_t *", raw.data)
        p[0], p[1], p[2] = 30, 100, 180
        local copy = raw:copy()
        assert(IC.boostImage(copy)); H.eq(IC.isBoosted(raw), false)
        local bytes = ffi.string(copy.data, tonumber(copy.stride))
        H.eq(IC.boostImage(copy), false); H.eq(ffi.string(copy.data, tonumber(copy.stride)), bytes)
        local derived = IC.derive(copy, copy:copy())
        H.eq(IC.isBoosted(derived), true); H.eq(IC.boostImage(derived), false)
        H.eq(tonumber(p[0]), 30); H.eq(tonumber(p[1]), 100); H.eq(tonumber(p[2]), 180)
        raw:free(); copy:free(); derived:free()
    end)
end
H.finish()
