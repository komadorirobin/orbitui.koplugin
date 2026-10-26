package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
local function read(path)
    local f = assert(io.open(root .. "/components/simpleui/" .. path))
    local s = f:read("*a"); f:close(); return s
end
local function run(s, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(s)), env)() end
    return assert(load(s, "October 26 integration", "t", env))()
end
local function part(s, a, b)
    local start = assert(s:find(a, 1, true))
    return s:sub(start, assert(s:find(b, start, true)) - 1)
end
local noop = function() end
local function wallpaper()
    local f = { data = { simpleui_style_wallpaper_enabled = true,
        simpleui_style_wallpaper = "/test/wallpaper.png" }, buffers = {}, now = 100, decodes = 0 }
    local function buffer(w, h)
        local b = { w = w, h = h, freed = 0 }
        function b:getWidth() return self.w end
        function b:getHeight() return self.h end
        function b:getType() return 1 end
        function b:fill() if f.fail == "fill" then error("fill failed") end end
        function b:blitFrom(src) assert(src.freed == 0); self.source = src end
        function b:free() self.freed = self.freed + 1; assert(self.freed == 1, "double free") end
        b.lightenRect, b.darkenRect = noop, noop
        f.buffers[#f.buffers + 1] = b
        return b
    end
    f.screen = { bb = buffer(120, 160), getWidth = function() return 120 end,
        getHeight = function() return 160 end }
    local store = {
        get = function(_, k) return f.data[k] end,
        readSetting = function(_, k, default) if f.data[k] == nil then return default end; return f.data[k] end,
        isTrue = function(_, k) return f.data[k] == true end,
        nilOrTrue = function(_, k) return f.data[k] ~= false end,
        saveSetting = function(_, k, v) f.data[k] = v end,
        del = function(_, k) f.data[k] = nil end,
        memoize = function(fn) return fn end,
    }
    local backdrop = { STRENGTH_MIN = 0, STRENGTH_MAX = 100,
        surface = function() return {} end,
        saveBackdropStrength = function(k, v) f.data[k] = v end,
        readBackdropStrength = function(k, default) return f.data[k] or default end }
    local deps = {
        device = { screen = f.screen }, logger = { warn = noop },
        ["infra/sui_store"] = store, ["infra/sui_backdrop"] = backdrop,
        ["infra/sui_memory"] = { onReset = function(fn) f.reset = fn end },
        ["libs/libkoreader-lfs"] = {},
        ["ffi/blitbuffer"] = { COLOR_WHITE = {}, new = function(w, h)
            if f.fail == "allocation" then error("allocation failed") end
            return buffer(w, h)
        end },
        ["ui/renderimage"] = { renderImageFile = function()
            f.decodes = f.decodes + 1
            if f.fail == "decode" then return nil end
            return buffer(60, 80)
        end },
        ["ui/widget/imagewidget"] = { new = function(_, opts)
            if f.fail == "constructor" then error("constructor failed") end
            return { paintTo = function()
                if f.fail == "paint" then error("paint failed") end
            end, free = function() opts.image:free() end }
        end },
    }
    f.module = run(read("features/sui_wallpaper.lua"), {
        require = function(name) return assert(deps[name], name) end,
        os = { time = function() return f.now end },
        G_reader_settings = { isTrue = function() return false end },
    })
    return f
end

H.test("whole wallpaper module owns one raster and a safe legacy painting facade", function()
    local f = wallpaper(); local m = f.module
    local handle = assert(m.styleGetBgWidget())
    H.eq(f.decodes, 1); H.eq(f.buffers[2].freed, 1); H.eq(f.buffers[3].freed, 0)
    m.paintBackground(f.screen.bb, 0); handle:paintTo(f.screen.bb, 0)
    H.eq(f.screen.bb.source, f.buffers[3]); H.eq(f.decodes, 1)
    handle:free(); H.eq(f.buffers[3].freed, 0)
    f.screen.night_mode = true; m.paintBackground(f.screen.bb, 0)
    H.eq(f.decodes, 2); H.eq(f.buffers[3].freed, 1)
    handle:paintTo(f.screen.bb, 0); H.eq(f.screen.bb.source, f.buffers[5])
    f.reset(); H.eq(f.buffers[5].freed, 1)
end)
H.test("wallpaper constructor, allocation, fill and paint failures free every owned scratch", function()
    for _, failure in ipairs({ "constructor", "allocation", "fill", "paint" }) do
        local f = wallpaper(); f.fail = failure
        H.eq(f.module.styleGetBgWidget(), nil)
        for i = 2, #f.buffers do H.eq(f.buffers[i].freed, 1, failure) end
        f.module.styleGetBgWidget(); H.eq(f.decodes, 1, "unbounded failed retries")
        f.fail = nil; f.now = 105
        assert(f.module.styleGetBgWidget(), "failure did not retry: " .. failure)
        f.reset()
    end
end)
H.test("failed wallpaper decode retries after a bound and copy-only scrim migration keeps rollback flags", function()
    local f = wallpaper(); local m = f.module
    f.fail = "decode"; H.eq(m.styleGetBgWidget(), nil)
    f.fail = nil; H.eq(m.styleGetBgWidget(), nil); H.eq(f.decodes, 1)
    f.now = 105; assert(m.styleGetBgWidget()); H.eq(f.decodes, 2)
    f.data.simpleui_wallpaper_show_in_fm = true
    H.eq(m.getLibraryStrength(), 0); H.eq(f.data.simpleui_wallpaper_show_in_fm, true)
    m.setLibraryStrength(40); H.eq(m.getLibraryStrength(), 40)
    H.eq(f.data.simpleui_wallpaper_show_in_fm, true)
    m.styleSetWallpaperShowInFM(false); H.eq(m.getLibraryStrength(), 100)
    H.eq(f.data.simpleui_wallpaper_show_in_fm, false)
    f.reset()
end)

local Bento = dofile(root .. "/components/simpleui/infra/sui_bento.lua")
H.test("fixed-grid stacking is opt-in and free-width packing retains its columns", function()
    local source = read("infra/sui_config.lua")
    local data, m = { home_bento_width_a = 28 }, {}
    function m.readChoice(k, choices, default)
        for _, v in ipairs(choices) do if data[k] == v then return v end end
        return default
    end
    run(part(source, "local function _bentoKey(", "-- Module Settings Chrome"), {
        M = m, Bento = Bento, math_max = math.max, math_min = math.min, math_floor = math.floor,
        SUISettings = { get = function(_, k) return data[k] end,
            set = function(_, k, v) data[k] = v end, isTrue = function(_, k) return data[k] == true end,
            nilOrTrue = function(_, k) return data[k] ~= false end },
    })
    H.eq(m.getBentoWidth("a", "home_"), 28); H.eq(data.home_bento_width_a, 28)
    H.eq(m.isBentoStack("home_"), false)
    m.setBentoStack(true, "home_"); H.eq(m.isBentoStack("home_"), true)
    H.eq(m.isBentoStack("custom_"), false)
    m.setBentoClassic(true, "home_")
    H.eq(m.getBentoWidth("a", "home_"), 28); H.eq(m.getBentoFraction("a", "home_"), .28)
    m.setBentoPct(27, "a", "home_"); H.eq(data.home_bento_width_a, 25)
    local rows = Bento.packClassic({ "a", "b", "c", "d" }, { a=28, b=60, c=28, d=28 })
    H.eq(#rows, 1); H.eq(rows[1].cols[1].span, 28); H.eq(#rows[1].cols[1].ids, 3)
    H.eq(#Bento.pack({ "a", "b", "c", "d" }, { a=3,b=3,c=3,d=3 }, false), 2)
end)
H.test("later-page stats mark successful demand and retry an unavailable data source", function()
    local attempts = 0
    local source = read("modules/reading_stats/module_reading_stats.lua")
    local ensure = run(part(source, "local function ensureData(", "-- Maps each stat_id")
        .. "\nreturn ensureData", {
        DATA_SETS = {{field="stat_charts", flag="_needs_charts", uses=function() return true end,
            fetch=function(_, ctx) H.eq(ctx.db_conn, "live-db"); attempts=attempts+1
                if attempts > 1 then return { fresh = true } end end }},
        anyIn = function() return false end, BOOK_STAT_IDS = {}, require = function() return {} end,
    })
    local ctx = { db_conn = "live-db" }
    ensure(ctx, {}, "cards"); H.eq(ctx._needs_charts, nil)
    ensure(ctx, {}, "cards"); H.eq(ctx._needs_charts, true); H.eq(ctx.stat_charts.fresh, true)
    ensure(ctx, {}, "cards"); H.eq(attempts, 2)
end)
H.test("Flow side covers counter-invert only at paint time without changing shared source pixels", function()
    local tilted, screen, calls = {}, {}, {}
    run(part(read("modules/module_coverdeck.lua"), "function TiltedCover:paintTo(",
        "function TiltedCover:handleEvent("), { TiltedCover = tilted, Screen = screen })
    local source = {}
    local card = { entry = { bb = source, tops = {0,0}, heights = {3,3} }, w = 2 }
    local bb = { blitFrom = function(_, src) H.eq(src, source); calls[#calls+1] = "normal" end,
        invertblitFrom = function(_, src) H.eq(src, source); calls[#calls+1] = "inverse" end }
    tilted.paintTo(card, bb, 0, 0)
    screen.night_mode = true; tilted.paintTo(card, bb, 0, 0)
    H.eq(table.concat(calls, ","), "normal,inverse"); H.eq(next(source), nil)
end)
H.test("category lookup follows an instance base and keeps external modules reachable in Other", function()
    local registry, language = {}, "first:"
    local mods = { external = {}, clock = { category = "extras" }, unknown = { category = "new-kind" } }
    registry.get = function(id) return mods[id] end
    run(part(read("modules/moduleregistry.lua"), "function Registry.getCategories()", "-- Layout-editor summary"), {
        Registry = registry, _ = function(s) return language .. s end,
        _baseOf = function(id) if id == "stats_instance" then return { category = "stats" } end end,
        _instanciable = {},
    })
    H.eq(registry.getCategory("stats_instance"), "stats")
    H.eq(registry.getCategory("external"), "other"); H.eq(registry.getCategory("unknown"), "other")
    H.eq(registry.getCategory("clock"), "extras")
    H.eq(registry.getCategories()[1].title, "first:Books")
    language = "second:"; H.eq(registry.getCategories()[1].title, "second:Books")
end)
H.test("categorized picker preserves external and instanced modules and adds only the chosen item", function()
    local categories = {{key="books",title="Books"},{key="stats",title="Statistics"},{key="other",title="Other"}}
    local st = { layout = { pages = {{modules={"already"}}} }, current_page=1, pfx="home_" }
    local selected, pushed, popped, saves = nil, nil, nil, 0
    local registry = {
        list = function() return {{id="already"},{id="book",name="A book"},{id="external",name="OrbitUI"}} end,
        isInstance = function() return false end,
        getCategory = function(id) return id=="book" and "books" or id=="stats" and "stats" or "other" end,
        getCategories = function() return categories end,
        getInstanciableBaseIds = function() return {"stats"} end,
        getBase = function() return {name="Reading Stats"} end,
        createInstance = function(id) H.eq(id,"stats"); return "stats_new" end,
    }
    local source = read("screens/sui_settings_window.lua")
    local build = run(part(source, "    local function buildModulePicker(ctx)", "    -- ── 2.5b.")
        .. "\nreturn buildModulePicker", {
        st=st, Registry=registry, _=function(s) return s end,
        LayoutService={entryId=function(id) return id end, save=function() saves=saves+1 end},
        SUI={ListRow=function(item) return item end},
    })
    local ctx = {inner_w=600, current=function() return {params={category=selected}} end,
        push=function(_, params) pushed=params end, pop=function(opts) popped=opts.levels end}
    local groups = build(ctx); H.eq(#groups,3); H.eq(#st.layout.pages[1].modules,1)
    groups[3].on_tap(); H.eq(pushed.category,"other")
    selected="other"; local external=build(ctx); H.eq(#external,1)
    external[1].on_tap(); H.eq(st.layout.pages[1].modules[2],"external"); H.eq(popped,2)
    selected="stats"; build(ctx)[1].on_tap()
    H.eq(st.layout.pages[1].modules[3],"stats_new"); H.eq(saves,2)
end)
H.finish()
