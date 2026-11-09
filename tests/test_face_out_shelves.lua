package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Integration = require("adapters/orbitui_ui")
package.loaded["lib/bookshelf_settings_store"] = {read = function() end}
package.loaded["lib/bookshelf_tab_model"] = {getById = function() end}

local function source(path)
    local f = assert(io.open("components/bookshelf/lib/" .. path .. ".lua"))
    local text = f:read("*a")
    f:close()
    return text
end

local function compile(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then
        local fn = assert(loadstring(code))
        setfenv(fn, env)
        return fn
    end
    return assert(load(code, "face-out shelves", "t", env))
end

-- Exercise the native normalization and geometry helpers without loading the
-- rendering stack; the component suites cover full planning and pagination.
local SS = { BOOK_GAP_DP = 0, GROUP_GAP_DP = 12,
    spineTextScale = function() return 1 end,
    endMargin = function(h) return math.floor(h / 10) end }
local model = assert(source("bookshelf_spine_shelf"):match(
    "(SpineShelf%.FACE_REASONS.-)\n%-%- recentSetForItems"))
compile(model, { SpineShelf = SS })()
SS.recentSetForItems = function() error("All books must not scan recent books") end
package.loaded["lib/bookshelf_spine_shelf"] = SS
package.loaded["lib/bookshelf_space"] = { px = function(v) return v * 2 end }
local widget_source = source("bookshelf_widget")
local function widgetMethod(name)
    local args, body = widget_source:match(
        "\nfunction BookshelfWidget:" .. name .. "%((.-)%)\n(.-)\nend\n")
    assert(body, "Native shelf method moved: " .. name)
    return compile("return function(self, " .. args .. ")\n" .. body .. "\nend",
        { Space = package.loaded["lib/bookshelf_space"] })()
end
local Widget = Integration.wrap("lib/bookshelf_widget", {
    _spineFaceOut = function() error("Legacy face-out rules must not apply") end,
    _spineFaceRecent = widgetMethod("_spineFaceRecent"),
    _spinePlanBase = widgetMethod("_spinePlanBase"),
    _spineSameSize = function() return nil end,
    _seriesBoxStyle = function() return nil end,
    _layoutPrimitives = function() return {} end,
    _rowGap = function() return 12 end,
    _ornDrill = function() return nil end,
    _chipListValue = function(_, key)
        if key == "spine_cover_size_pct" then return 130 end
        H.eq(key, "spine_thickness_pct"); return 120
    end,
})

local saved_values = { {}, { value = false }, { value = true },
    { value = "favorites" }, { value = "reading" }, { value = "none" },
    { value = { favorites = true, recent = 5, collection = "Manga" } } }

H.test("existing prose and manga shelves always use native all-cover orientation", function()
    for _, profile in ipairs({ "prose", "comics" }) do
        for _, saved in ipairs(saved_values) do
            local shelf = setmetatable({ profile_key = profile,
                chip = { spine_face_out = saved.value },
                _profileShelfSettings = function() error("Must not read old profile rules") end,
            }, { __index = Widget })
            H.eq(shelf:_spineFaceOut(), "all")
            H.eq(SS.faceOutSpec(shelf:_spineFaceOut()).all, true)
            H.eq(shelf.chip.spine_face_out, saved.value)
        end
    end
end)

H.test("shared render/pagination options keep margins and density but use all covers", function()
    local items = { { filepath = "/fiction.epub" }, { filepath = "/manga.cbz" } }
    local opts = Widget:_spinePlanBase(1264, 400, items)
    H.eq(opts.face_out, "all")
    H.eq(opts.face_recent_set, nil)
    H.eq(opts.content_w, 1184)
    H.eq(opts.row_h, 400)
    H.eq(opts.gap, 0)
    H.eq(opts.group_gap, 24)
    H.eq(opts.thickness_pct, 120)
    H.eq(opts.cover_size_pct, 130)
    for _, name in ipairs({ "_buildSpineRows", "_spinePageFirsts" }) do
        local _, body = widget_source:match(
            "\nfunction BookshelfWidget:" .. name .. "%((.-)%)\n(.-)\nend\n")
        assert(body and body:find("self:_spinePlanBase(", 1, true),
            name .. " must keep using the shared face-out options")
    end
end)

local shown, shows, closes, changes = nil, 0, 0, 0
package.loaded["ui/widget/buttondialog"] = { new = function(_, o) return o end }
package.loaded["ui/uimanager"] = {
    show = function(_, o) shown = o; shows = shows + 1 end,
    close = function() closes = closes + 1 end,
}
for _, name in ipairs({ "ui/widget/confirmbox", "ui/geometry", "ui/size",
    "lib/bookshelf_tab_model", "lib/bookshelf_filter", "logger" }) do
    package.loaded[name] = {}
end
package.loaded["lib/bookshelf_tab_model"] = { isShelves = function() return false end }
package.loaded["device"] = { screen = {} }
package.loaded["lib/bookshelf_i18n"] = { gettext = function(s) return s end }
package.loaded["lib/bookshelf_gettime"] = os.clock
package.loaded["ffi/util"] = { template = function(s, ...)
    local args = { ... }
    return (s:gsub("%%(%d+)", function(n) return tostring(args[tonumber(n)]) end))
end }
package.loaded["lib/bookshelf_module_kit"] = { radioRow = function(o)
    return { text = o.label, active = o.active, callback = o.on_pick }
end }
package.loaded["lib/bookshelf_stack_display"] = {
    pinned = function(v) return v end, FOLLOW_DEFAULT = "default", CHIP_OPTIONS = {},
}
package.loaded["lib/bookshelf_ornaments"] = { FREQ_DEFAULT = 1 }
local ViewMode = require("lib/bookshelf_view_mode")
local Editor = require("lib/bookshelf_chip_editor")
Editor._menu = function(spec)
    shown = spec; shows = shows + 1
    return { refresh = function() end }
end
local function control(label)
    for _, block in ipairs(shown.page().blocks) do
        if block.label == label then return block end
    end
end
local function openStyle(draft, chrome)
    Editor:_pickGroupDisplay(draft, function() changes = changes + 1 end, chrome)
    return control("Face out")
end
H.test("standalone orientation and captions remain configurable", function()
    local button = openStyle({view_mode="spines", spine_face_out="reading"})
    H.eq(button.value,"Reading"); H.eq(button.enabled,true)
    H.eq(Editor.face_out_override,nil)
    openStyle({id="home",view_mode="covers"})
    assert(control("Cover captions")); H.eq(Editor.cover_text_external,nil)
end)
H.test("OrbitUI shows read-only all-cover orientation and preserves saved drafts", function()
    H.eq(Integration.modules["lib/bookshelf_chip_editor"],true)
    H.eq(Integration.wrap("lib/bookshelf_chip_editor",Editor),Editor)
    for _,saved in ipairs(saved_values) do
        local draft={view_mode="spines",spine_face_out=saved.value,spine_rows=3}
        local button=openStyle(draft)
        H.eq(button.value,"All books"); H.eq(button.enabled,false)
        local before={shows,closes,changes}
        button.callback()
        H.eq(shows,before[1]); H.eq(closes,before[2]); H.eq(changes,before[3])
        H.eq(draft.spine_face_out,saved.value); H.eq(draft.spine_rows,3)
        H.eq(draft.view_mode,"spines")
        H.eq(control("Book binding"),nil); H.eq(control("Series boxes"),nil)
    end
end)
H.test("grid/list/auto controls and remote restrictions are preserved", function()
    for _,mode in ipairs({"auto","covers","list"}) do
        local draft={view_mode=mode,spine_face_out=false}
        H.eq(openStyle(draft),nil)
        H.eq(control("Cover captions"),nil)
        H.eq(draft.view_mode,mode); H.eq(draft.spine_face_out,false)
    end
    local draft={view_mode="spines"}
    H.eq(openStyle(draft,{is_opds=true}),nil)
    H.eq(#control("Show as").items,3)
    H.eq(control("Show as").active,"covers"); H.eq(draft.view_mode,"spines")
end)
H.test("legacy unset view exposes covers and list controls without a migration", function()
    local draft={source={kind="authors"}}
    openStyle(draft)
    H.eq(control("Show as").active,"auto")
    assert(control("Columns")); H.eq(control("Top level"),nil)
    H.eq(draft.view_mode,nil)
    control("Show as").on_pick("covers")
    H.eq(draft.view_mode,"covers")
end)
local function sizeRow(draft,chrome)
    openStyle(draft,chrome); return control("Cover size")
end
H.test("cover-size steps preview, clamp and preserve unrelated settings",function()
    local draft={view_mode="spines",spine_rows=2}
    H.eq(sizeRow(draft).value,"100%")
    local before=changes
    sizeRow(draft).on_inc()
    H.eq(draft.spine_cover_size_pct,110); H.eq(changes,before+1)
    H.eq(sizeRow(draft).value,"110%")
    sizeRow(draft).on_dec()
    H.eq(draft.spine_cover_size_pct,nil); H.eq(sizeRow(draft).value,"100%")
    for _=1,12 do sizeRow(draft).on_dec() end
    H.eq(draft.spine_cover_size_pct,50)
    for _=1,12 do sizeRow(draft).on_inc() end
    H.eq(draft.spine_cover_size_pct,150)
    H.eq(draft.spine_rows,2); H.eq(draft.spine_thickness_pct,nil)
end)
H.test("only physical shelves expose cover-size controls",function()
    for _,mode in ipairs({"auto","covers","list"}) do H.eq(sizeRow({view_mode=mode}),nil) end
    H.eq(sizeRow({view_mode="spines"},{is_opds=true}),nil)
end)
H.test("minimal preset disables ornaments without rewriting the saved choice",function()
    local draft={view_mode="spines",ornament_frequency=3}
    Editor.ornament_frequency_override=0
    openStyle(draft)
    local row=assert(control("Ornaments"))
    H.eq(row.items[row.active].label,"None"); H.eq(row.enabled,false)
    local before=changes; row.on_pick(2)
    H.eq(changes,before); H.eq(draft.ornament_frequency,3)
    Editor.ornament_frequency_override=nil
    openStyle(draft); row=control("Ornaments")
    H.eq(row.items[row.active].label,"Always"); H.eq(row.enabled,true)
end)
H.finish()
