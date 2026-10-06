package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Layout = require("lib/bookshelf_spine_layout")

local function source(name)
    local f = assert(io.open("components/bookshelf/lib/" .. name .. ".lua"))
    local text = f:read("*a")
    f:close()
    return text
end

local function compile(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then
        local f = assert(loadstring(code))
        setfenv(f, env)
        return f
    end
    return assert(load(code, "shelf cover size", "t", env))
end

local shelf_source = source("bookshelf_spine_shelf")
local block = assert(shelf_source:match("(        local w_dp, w, depth, face_h\n.-)\n        local series_num"))
local plank_source = assert(shelf_source:match("(function SpineShelf.plankUnit.-)\n%-%- badgeDrop"))
local inset_source = assert(shelf_source:match("(function SpineShelf.plankInset.-\nend)"))

-- Exercise the real planning block, including the same plank clearance used
-- by rowWidget, without loading the native framebuffer/cover decoder.
local function geometry(pct, aspect, row_h, width, dpi, face_out)
    local Screen = { scaleBySize = function(_, v) return math.floor(v * dpi + 0.5) end }
    local SS = { VIEW_SIN = Layout.VIEW_SIN, thicknessPages = function() return 300 end,
        PLANK_INSET_UNITS = tonumber(assert(shelf_source:match("SpineShelf%.PLANK_INSET_UNITS%s*=%s*([%d.]+)"))) }
    compile(plank_source .. "\n" .. inset_source, { SpineShelf = SS, Screen = Screen })()
    local h = Layout.spineHeight(row_h, aspect)
    local env = { h = h, aspect = aspect, budget = row_h,
        face_out = face_out ~= false, SpineLayout = Layout, SpineShelf = SS,
        Screen = Screen, auto_thick = Layout.autoThickness(row_h / dpi),
        opts = { cover_size_pct = pct, content_w = width } }
    local entry = compile(block .. "\nreturn { h=h, face_h=face_h, depth=depth, w=w }", env)()
    entry.stand = row_h - SS.plankFace(row_h) - 2 * SS.plankInset(SS.plankUnit(row_h))
    return entry
end

H.test("default cover geometry stays pixel-identical", function()
    for _, aspect in ipairs({ .7, 1, 1.5, 2.2 }) do
        for _, dpi in ipairs({ 1, 2, 3 }) do
            local h = Layout.spineHeight(300 * dpi, aspect)
            local expected_face = math.max(24 * dpi, h - Layout.topEdgeHeight(h, aspect, 5 * dpi))
            for _, pct in ipairs({ 100, "invalid", 0/0 }) do
                local g = geometry(pct, aspect, 300 * dpi, 900 * dpi, dpi)
                H.eq(g.h, h)
                H.eq(g.face_h, expected_face)
                H.eq(g.w, Layout.faceOutWidth(expected_face, aspect))
            end
            H.eq(geometry(nil, aspect, 300 * dpi, 900 * dpi, dpi).face_h, expected_face)
        end
    end
end)

H.test("larger covers grow proportionally and the renderer has room for their slots", function()
    local base = geometry(100, 1.5, 300, 900, 1)
    local large = geometry(120, 1.5, 300, 900, 1)
    assert(large.face_h > base.face_h and large.w > base.w)
    H.eq(large.face_h, math.floor(base.face_h * 1.2 + 0.5))
    H.eq(large.h, large.face_h + large.depth)
    H.eq(large.depth, base.depth) -- thickness is a separate setting
    H.eq(large.stand, base.stand)
end)

H.test("extreme aspects, row counts and DPI stay inside the shelf", function()
    for _, aspect in ipairs({ .35, .7, 1, 1.5, 2.2, 3 }) do
        for _, dpi in ipairs({ 1, 2, 3 }) do
            for _, row_h in ipairs({ 80, 200, 500, 900 }) do
                for _, pct in ipairs({ 50, 90, 110, 130, 150, 900 }) do
                    local g = geometry(pct, aspect, row_h*dpi, 600*dpi, dpi)
                    assert(g.h <= g.stand and g.w <= 600*dpi)
                    assert(g.face_h > 0 and g.depth >= 0)
                    assert(math.abs(g.w - g.face_h/aspect) <= .5)
                    -- The renderer must not silently clamp away the increase.
                    local avail = math.min(g.h, g.stand)
                    local depth = math.min(g.depth, math.max(0, avail - 10))
                    H.eq(math.min(g.face_h, avail - depth), g.face_h)
                end
            end
        end
    end
end)

H.test("cover size never changes edge-on spine geometry", function()
    local base = geometry(100, 1.5, 300, 900, 1, false)
    local large = geometry(150, 1.5, 300, 900, 1, false)
    H.eq(large.w, base.w)
    H.eq(large.h, base.h)
end)

H.test("wider covers repaginate without overlapping a reserved ornament slot", function()
    local function pack(pct)
        local widths = {}
        for i = 1, 25 do widths[i] = geometry(pct, 1.5, 300, 900, 1).w end
        local rows = Layout.fillRows(widths, function() return 900 - 180 end, 12)
        local seen = 0
        for _, row in ipairs(rows) do
            local used = 0
            for i = row.first, row.last do
                used = used + widths[i] + (i > row.first and 12 or 0)
                H.eq(i, seen + 1)
                seen = i
            end
            assert(used <= 720)
        end
        H.eq(seen, 25)
        return Layout.paginate(rows, 2)
    end
    assert(#pack(130) > #pack(100))
end)

H.test("plan cache keys distinguish cover sizes but not page position", function()
    local body = assert(shelf_source:match("local function _optsKey%(opts%)\n(.-)\nend"))
    local key = compile("return function(opts)\n" .. body .. "\nend",
        { SpineShelf = {}, _nightMode = function() return false end })()
    assert(key({cover_size_pct=110}) ~= key({cover_size_pct=120}))
    H.eq(key({cover_size_pct=120, n_rows=2, skip=3}), key({cover_size_pct=120, n_rows=9, skip=0}))
end)

H.test("size persists independently for Library and Manga and survives reloading", function()
    local saved = {}
    package.loaded["lib/bookshelf_settings_store"] = {
        read = function(key) return saved[key] end,
        save = function(key, value) saved[key] = value end,
        delete = function(key) saved[key] = nil end,
    }
    local Profiles = require("lib/bookshelf_profiles")
    Profiles.saveShelfSettings(Profiles.get("prose"), "profile_fiction",
        { spine_cover_size_pct = 120, spine_rows = 2 })
    Profiles.saveShelfSettings(Profiles.get("comics"), "profile_manga",
        { spine_cover_size_pct = 90 })
    package.loaded["lib/bookshelf_profiles"] = nil
    Profiles = require("lib/bookshelf_profiles")
    H.eq(Profiles.shelfSettings(Profiles.get("prose"), "profile_fiction").spine_cover_size_pct, 120)
    H.eq(Profiles.shelfSettings(Profiles.get("comics"), "profile_manga").spine_cover_size_pct, 90)
    H.eq(Profiles.shelfSettings(Profiles.get("prose"), "profile_poetry").spine_cover_size_pct, nil)
    Profiles.saveShelfSettings(Profiles.get("prose"), "profile_fiction", { spine_rows = 2 })
    H.eq(Profiles.shelfSettings(Profiles.get("prose"), "profile_fiction").spine_cover_size_pct, nil)
end)

H.test("ordinary chip previews carry and clear the size override", function()
    local editor = source("bookshelf_chip_editor")
    local statement = assert(editor:match("override%.spine_cover_size_pct%s*=%s*draft%.spine_cover_size_pct"))
    local env = { override = {spine_cover_size_pct=80}, draft = {spine_cover_size_pct=120} }
    compile(statement, env)()
    H.eq(env.override.spine_cover_size_pct, 120)
    env.draft.spine_cover_size_pct = nil
    compile(statement, env)()
    H.eq(env.override.spine_cover_size_pct, nil)
    local widget = source("bookshelf_widget")
    local callback = assert(widget:match("function BookshelfWidget:_afterChipEdit%(%)\n(.-)\nend"))
    local shelf = { _spine_fetch_cache = {page_firsts={1,5,9}}, _markOpdsNav=function() end,
        _rebuild=function(self) H.eq(self._spine_fetch_cache, nil) end }
    compile("return function(self)\n" .. callback .. "\nend",
        {UIManager={setDirty=function() end}})()(shelf)
end)

H.test("resizing forgets old back-page boundaries without moving the current book", function()
    local widget = source("bookshelf_widget")
    local block = assert(widget:match("(    if self%._spine_hist_chip ~= self%.chip.-\n    end)"))
    local shelf = { chip="fiction", _spine_hist_chip="fiction", _cursor=20,
        _spine_hist_cover_size=100, _spine_hist={{c=1}, {c=10}} }
    local env = { self=shelf, opts={cover_size_pct=120} }
    compile(block, env)()
    H.eq(#shelf._spine_hist, 0)
    H.eq(shelf._cursor, 20)
    shelf._spine_hist[1] = {c=12}
    compile(block, env)()
    H.eq(#shelf._spine_hist, 1)
    env.opts.cover_size_pct = nil
    compile(block, env)()
    H.eq(#shelf._spine_hist, 0)
    H.eq(shelf._spine_hist_cover_size, 100)
end)

H.test("the size setting has a Swedish label without overriding KOReader gettext", function()
    package.loaded["logger"] = {dbg=function() end}
    local fallback = function(s) return "native:" .. s end
    package.loaded["gettext"] = fallback
    G_reader_settings = {readSetting=function() return "sv_SE" end}
    local I18n = require("lib/bookshelf_i18n")
    H.eq(I18n.gettext("Cover size"), "Omslagsstorlek")
    H.eq(I18n.gettext("Unrelated"), "native:Unrelated")
    H.eq(package.loaded["gettext"], fallback)
end)

H.finish()
