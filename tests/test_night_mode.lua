local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;" .. root .. "/components/bookshelf/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local A = require("adapters/orbitui_appearance")
local Model = require("core/orbitui_appearance")
local W = H.widget()
local night, dark, android, cbb = false, false, true, true
local noop = function() end
package.loaded.logger = { dbg = noop, info = noop, warn = noop }
package.loaded.device = { screen = { getWidth = function() return 40 end,
    getHeight = function() return 60 end }, isAndroid = function() return android end }
local screen = package.loaded.device.screen
local function modes(n, d)
    night, dark, screen.night_mode = n, d, n
end
package.loaded["lib/bookshelf_cover_progress"] = { theme = function() return dark, night end }
package.loaded["ui/widget/widget"] = W
package.loaded["ui/geometry"] = { new = function(_, t) return t end }
package.loaded["lib/bookshelf_theme_pack"] = { shelfLook = function() return dark and "dark" or "light" end }
local ink = function(v) return { value = v, getColorRGB32 = function(self) return self end,
    getR = function() return v end, getG = function() return v end, getB = function() return v end } end
local BB = { COLOR_WHITE = ink(255), COLOR_BLACK = ink(0), TYPE_BB8 = 1,
    getUseCBB = function() return cbb end,
    ColorRGB32 = function(r, g, b, alpha) local v = ink(r); v.alpha = alpha; return v end }
package.loaded["ffi/blitbuffer"] = BB
local function target(w, h)
    return { ops = {}, getWidth = function() return w or 40 end,
        getHeight = function() return h or 60 end,
        blitFrom = function(self, src, x, y, sx, sy, rw, rh)
            self.ops[#self.ops + 1] = { "blit", src, x, y, sx, sy, rw, rh }
        end }
end
local function shelfWallpaper()
    local m = dofile(root .. "/components/bookshelf/lib/bookshelf_wallpaper.lua")
    m._disk_cache, m._keep_two = false, function() return false end
    m.pathFor = function(name) return name end
    m._render = function() return { getWidth = function() return 40 end,
        getHeight = function() return 60 end, free = noop, invertRect = noop } end
    package.loaded["lib/bookshelf_wallpaper"] = m
    return m
end
H.test("night contrast is a runtime policy and chooses paint space independently of look", function()
    H.eq(Model.nightBackdrop(false, true), nil)
    local s, c = Model.nightBackdrop(true, true); H.eq(s, .82); H.eq(c, 255)
    s, c = Model.nightBackdrop(true, false); H.eq(s, .82); H.eq(c, 0)
end)
H.test("whole Android paint guards restore flags on success and error, not software or hardware paths", function()
    local inverse = 1
    local bb = { getInverse = function() return inverse end, setInverse = function(_, v) inverse = v end }
    H.eq(A.withFrameInverse(bb, function() H.eq(inverse, 0); return 12 end), 12)
    H.eq(inverse, 1)
    H.eq(pcall(A.withFrameInverse, bb, function() error("paint failed") end), false); H.eq(inverse, 1)
    cbb = false; A.withFrameInverse(bb, function() H.eq(inverse, 1) end)
    cbb, android = true, false; A.withFrameInverse(bb, function() H.eq(inverse, 1) end)
    android = true; inverse = 0; A.withFrameInverse(bb, function() H.eq(inverse, 0) end)
end)
H.test("the loader installs only explicit wallpaper and rounded-fill adapters", function()
    local UI = require("adapters/orbitui_ui")
    for _, name in ipairs({ "features/sui_wallpaper", "lib/bookshelf_wallpaper" }) do
        assert(UI.modules[name]); local m = {}; H.eq(UI.wrap(name, m), m)
        assert(m.orbituiBackdrop and m.orbituiBackdropKey)
    end
    local calls = 0
    local m = { paintRoundedRect = function() calls = calls + 1 end }
    UI.wrap("lib/bookshelf_color", m); m.paintRoundedRect({}); H.eq(calls, 1)
end)
H.test("wallpaper policy preserves earlier hooks and follows pinned shelf look without settings writes", function()
    local m, prior, dim = shelfWallpaper(), 0, 0
    m.orbituiBackdrop = function() prior = prior + 1 end
    m.scrim = function(_, _, _, _, _, color, strength) dim = dim + 1; H.eq(color.value, night and 255 or 0); H.eq(strength, .82) end
    A.wallpaper(m, true)
    modes(false, false); m.orbituiBackdrop({}, 0, 0, 2, 2); H.eq(dim, 0); H.eq(prior, 1)
    modes(true, false); m.orbituiBackdrop({}, 0, 0, 2, 2); H.eq(dim, 0)
    modes(false, true); m.orbituiBackdrop({}, 0, 0, 2, 2); H.eq(dim, 1)
    modes(true, true); m.orbituiBackdrop({}, 0, 0, 2, 2); H.eq(dim, 2); H.eq(prior, 4)
    H.eq(m.orbituiBackdropKey(), ":orbitui-night-82")
end)
H.test("night dock retains native tone and ink over pinned Light, without changing day opacity", function()
    local surfaces={navbar={strength=0,tone="accent"},statusbar={strength=0},pagination={strength=0}}
    local descriptor={}
    local m={resolveBar=function(k) return surfaces[k] end,barSurface=function() return descriptor end}
    package.loaded["infra/sui_backdrop"]={resolve=function(s, strength)
        H.eq(s,descriptor); return {strength=strength,tone="accent",foreground="native-contrasting-ink"}
    end}
    A.wallpaper(m,false)
    modes(false,false); H.eq(m.resolveBar("navbar"),surfaces.navbar)
    modes(true,false); local resolved=m.resolveBar("navbar")
    H.eq(resolved.strength,90); H.eq(resolved.foreground,"native-contrasting-ink")
    H.eq(surfaces.navbar.strength,0); H.eq(m.resolveBar("statusbar"),surfaces.statusbar)
    surfaces.navbar.strength=100; H.eq(m.resolveBar("navbar"),surfaces.navbar)
    modes(false,false); H.eq(m.resolveBar("navbar"),surfaces.navbar)
end)
H.test("Bookshelf full, regional, restore and scratch paints shade only replaced wallpaper before panels", function()
    local m = shelfWallpaper()
    modes(true, true)
    m.orbituiBackdrop = function(bb, x, y, w, h)
        bb.ops[#bb.ops + 1] = { "dim", x, y, w, h }
    end
    local bg = assert(m.bg("test", 40, 60, false))
    local source = bg.bb
    local bb = target()
    bg:paintTo(bb, 0, 0); H.eq(#bb.ops, 2); H.eq(bb.ops[2][1], "dim")
    bb.ops = {}; assert(m.backdrop(bb)); H.eq(#bb.ops, 2, "double full-screen dim")
    bb.ops = {}; assert(m.backdrop(bb, { x=3,y=4,w=5,h=6 })); H.eq(#bb.ops, 2)
    H.eq(bb.ops[2][2], 3); H.eq(bb.ops[2][5], 6)
    m.setPanel(0, 0, 40, 60, BB.COLOR_WHITE, .8, 0)
    m.scrim = function(t) t.ops[#t.ops+1] = { "panel" } end
    bb.ops = {}; assert(m.restore(bb, 2, 3, 4, 5))
    H.eq(bb.ops[1][1], "blit"); H.eq(bb.ops[2][1], "dim"); H.eq(bb.ops[3][1], "panel")
    bb.ops = {}; assert(m.restoreBare(bb, 2, 3, 4, 5)); H.eq(#bb.ops, 2)
    bb.ops = {}; assert(m.patch(bb, 1, 2, 38, 58, 10, 10))
    H.eq(bb.ops[2][2], 1); H.eq(bb.ops[2][4], 2); H.eq(bb.ops[2][5], 2)
    assert(not m.restore(target(4, 5), 0, 0, 2, 2)); H.eq(bg.bb, source)
end)
H.test("blur caches distinguish the night overlay without mutating the cached source image", function()
    local m, builds = shelfWallpaper(), 0
    local bg = assert(m.bg("test", 40, 60, false))
    m.blurOn = function() return true end
    m.ditherPanels = function() return false end
    m._frost_build = function(src) H.eq(src, bg.bb); builds = builds + 1; return { free=noop } end
    A.wallpaper(m, true)
    modes(false, false); assert(m.frost(target(), 0, 0, 10, 10)); H.eq(builds, 1)
    modes(false, true); assert(m.frost(target(), 0, 0, 10, 10)); H.eq(builds, 2)
    assert(m.frost(target(), 0, 0, 10, 10)); H.eq(builds, 2)
    modes(false, false); assert(m.frost(target(), 0, 0, 10, 10)); H.eq(builds, 2)
end)

H.test("SimpleUI full, legacy facade and partial eraser share one shading pass, day values remain saved", function()
    local saved = { simpleui_style_wallpaper_enabled=true, simpleui_style_wallpaper="picture" }
    local buffers = {}
    local function raster()
        local b = target(); b.getType = function() return 1 end; b.fill=noop; b.free=noop
        buffers[#buffers+1] = b; return b
    end
    local store = { readSetting=function(_, k, default) if saved[k] == nil then return default end; return saved[k] end,
        get=function(_, k) return saved[k] end,
        memoize=function(f) return f end,
        isTrue=function(_, k) return saved[k] == true end, nilOrTrue=function(_, k) return saved[k] ~= false end }
    screen.bb = { getType=function() return 1 end }
    local deps = { device=package.loaded.device, logger=package.loaded.logger,
        ["infra/sui_store"]=store, ["infra/sui_memory"]={ onReset=noop },
        ["libs/libkoreader-lfs"]={}, ["infra/sui_backdrop"]={ STRENGTH_MIN=0, STRENGTH_MAX=100,
            clampBackdropStrength=function(v) return v end,
            surface=function() return {} end, withInverseGuard=function(_, f) return pcall(f) end,
            paintBackdrop=function(bb) bb.ops[#bb.ops+1] = { "panel" } end },
        ["ffi/blitbuffer"]={ new=function() return raster() end, COLOR_WHITE=BB.COLOR_WHITE },
        ["ui/renderimage"]={ renderImageFile=function() return raster() end },
        ["ui/widget/imagewidget"]={ new=function() return { paintTo=noop, free=noop } end },
    }
    local fn = assert(loadfile(root .. "/components/simpleui/features/sui_wallpaper.lua"))
    local env = setmetatable({ require=function(n) return assert(deps[n], n) end,
        G_reader_settings={ isTrue=function() return false end } }, { __index=_G })
    if setfenv then setfenv(fn, env) else fn=assert(loadfile(root .. "/components/simpleui/features/sui_wallpaper.lua", "t", env)) end
    local m = fn()
    local dims = 0
    m.orbituiBackdrop = function(bb) dims=dims+1; bb.ops[#bb.ops+1] = { "dim" } end
    local bb = target(); modes(true, true)
    m.paintBackground(bb, 0); H.eq(dims, 1)
    m.styleGetBgWidget():paintTo(bb, 0); H.eq(dims, 2)
    m.paintEraser(bb, 1, 2, 3, 4, 25); H.eq(dims, 3); H.eq(bb.ops[#bb.ops][1], "panel")
    m.paintEraser(bb, 1, 2, 3, 4, 100); H.eq(dims, 3, "opaque chrome must not replay wallpaper")
    H.eq(saved.simpleui_style_wallpaper, "picture"); H.eq(saved.simpleui_style_wallpaper_enabled, true)
    local count=0; for _ in pairs(saved) do count=count+1 end; H.eq(count,2)
end)

-- Optional real KOReader blitbuffer + C blitter. The pinned dependency remains
-- outside the release; run once with IS_ANDROID=1 and once unset, LuaJIT only.
local native = os.getenv("ORBITUI_NATIVE_BB_DIR")
if native then
    local ffi = require("ffi")
    ffi.cdef[[void *malloc(size_t); void *calloc(size_t,size_t); void free(void *);]]
    package.loaded["ffi/posix_h"] = true
    package.loaded["ffi/util"] = { idiv=function(a,b) return math.floor(a/b) end }
    ffi.loadlib = function() return ffi.load(assert(os.getenv("ORBITUI_NATIVE_BB_LIB"))) end
    BB = dofile(native .. "/ffi/blitbuffer.lua")
    package.loaded["ffi/blitbuffer"] = BB
    android = os.getenv("IS_ANDROID") ~= nil
    package.loaded["lib/bookshelf_color"] = dofile(root .. "/components/bookshelf/lib/bookshelf_color.lua")
    local unguarded_fill = package.loaded["lib/bookshelf_color"].paintRoundedRect
    A.colourPainter(package.loaded["lib/bookshelf_color"])
    local function shown(bb, x, y, final_flip)
        local c = bb:getPixelP(x, y)[0]:getColorRGB32()
        if final_flip then return 255-c.r,255-c.g,255-c.b end
        return c.r,c.g,c.b
    end
    H.test("native rounded RGB fill has no bright corner islands with CBB, software fallback and rotation", function()
        local Color = require("lib/bookshelf_color")
        if android then
            local bb=BB.new(50,50,BB.TYPE_BBRGB32); bb:setInverse(1)
            unguarded_fill(bb,5,5,36,36,BB.ColorRGB32(200,180,160,255),9)
            local center=shown(bb,20,20,false); local corner=shown(bb,9,9,false)
            assert(center~=corner,"the unguarded Android defect no longer reproduces")
            bb:free()
        end
        for _, use in ipairs({true,false}) do for _, rot in ipairs({0,1,2,3}) do
            BB:setUseCBB(use); local bb=BB.new(50,50,BB.TYPE_BBRGB32)
            bb:setRotation(rot); bb:setInverse(1)
            Color.paintRoundedRect(bb, 5,5,36,36,BB.ColorRGB32(200,180,160,255),9)
            local cx,cy=bb:getPhysicalCoordinates(20,20)
            local px,py=bb:getPhysicalCoordinates(9,9)
            local a,b,c=shown(bb,cx,cy,false); local d,e,f=shown(bb,px,py,false)
            H.eq(d,a); H.eq(e,b); H.eq(f,c); H.eq(bb:getInverse(),1)
            bb:free()
        end end
        BB:setUseCBB(true)
    end)
    H.test("native wallpaper dim caps displayed brightness in RGB and grey without changing the source", function()
        for _, use in ipairs({true,false}) do for _, typ in ipairs({BB.TYPE_BBRGB32,BB.TYPE_BB8}) do
            BB:setUseCBB(use)
            for _, mode in ipairs({{false,true,0},{true,true,1},{true,false,1}}) do
                modes(mode[1],mode[2]); local bb=BB.new(12,12,typ); bb:setInverse(mode[3])
                local source=BB.new(12,12,typ); source:fill(night and BB.COLOR_BLACK or BB.COLOR_WHITE)
                bb:blitFrom(source,0,0,0,0,12,12)
                shelfWallpaper() -- actual native scrim C/LUT paths
                A.paintNightBackdrop(bb,0,0,12,12,dark)
                local r=shown(bb,5,5,night and (android and use or mode[3]==0))
                if dark then assert(r<=48,"bright night wallpaper: "..r) else H.eq(r,255) end
                local raw=source:getPixelP(0,0)[0]:getColor8().a; H.eq(raw,night and 0 or 255)
                bb:free();source:free()
            end
        end end
        BB:setUseCBB(true)
    end)
    H.test("native background, repaired corner and real blur all keep the same night tone", function()
        BB:setUseCBB(true); modes(true,true)
        local bb=BB.new(40,60,BB.TYPE_BBRGB32); screen.bb=bb; bb:setInverse(android and 1 or 0)
        local m=shelfWallpaper()
        local source=BB.new(40,60,BB.TYPE_BBRGB32); source:fill(BB.COLOR_WHITE)
        m._render=function() return source end
        A.wallpaper(m,true)
        local bg=assert(m.bg("test",40,60,true)); bg:paintTo(bb,0,0)
        local first=shown(bb,5,5,true); assert(first<=48)
        assert(m.restoreBare(bb,3,4,5,6)); H.eq(shown(bb,5,5,true),first)
        m.blurOn=function() return true end; m.ditherPanels=function() return false end
        assert(m.frost(bb,0,0,20,20)); H.eq(shown(bb,5,5,true),first)
        H.eq(source:getPixelP(0,0)[0].r,0,"tone modified the source raster")
        bb:free(); source:free()
    end)
end
H.finish()
