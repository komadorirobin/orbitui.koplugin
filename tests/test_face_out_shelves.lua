package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Integration = require("adapters/orbitui_ui")

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
    _layoutPrimitives = function() return {} end,
    _rowGap = function() return 12 end,
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
local function openStyle(draft, chrome)
    Editor:_pickGroupDisplay(draft, function() changes = changes + 1 end, chrome)
    for _, row in ipairs(shown.buttons) do
        for _, button in ipairs(row) do
            local text = button.text_func and button.text_func() or button.text
            if text and text:match("^Face out:") then return button, text end
        end
    end
end

H.test("the standalone component keeps its native configurable orientation", function()
    local button, text = openStyle({ [ViewMode.CHIP_KEY] = ViewMode.SPINES,
        spine_face_out = "reading" })
    H.eq(text, "Face out: Currently reading")
    H.eq(button.enabled, true)
    H.eq(Editor.face_out_override, nil)
end)

H.test("OrbitUI style editor reflects the override without changing saved drafts", function()
    H.eq(Integration.modules["lib/bookshelf_chip_editor"], true)
    H.eq(Integration.wrap("lib/bookshelf_chip_editor", Editor), Editor)
    for _, saved in ipairs(saved_values) do
        local draft = { [ViewMode.CHIP_KEY] = ViewMode.SPINES,
            spine_face_out = saved.value, spine_rows = 3 }
        local button, text = openStyle(draft)
        H.eq(text, "Face out: All books")
        H.eq(button.enabled, false)
        local old_shows, old_closes, old_changes = shows, closes, changes
        button.callback()
        H.eq(shows, old_shows); H.eq(closes, old_closes); H.eq(changes, old_changes)
        H.eq(draft.spine_face_out, saved.value)
        H.eq(draft.spine_rows, 3)
        H.eq(draft[ViewMode.CHIP_KEY], ViewMode.SPINES)
    end
end)

H.test("normal grid/list/auto modes and remote catalogue restrictions stay unchanged", function()
    for _, mode in ipairs({ ViewMode.AUTO, ViewMode.COVERS, ViewMode.LIST }) do
        local draft = { [ViewMode.CHIP_KEY] = mode, spine_face_out = false }
        H.eq(openStyle(draft), nil)
        H.eq(draft[ViewMode.CHIP_KEY], mode)
        H.eq(draft.spine_face_out, false)
    end
    H.eq(openStyle({ [ViewMode.CHIP_KEY] = ViewMode.SPINES }, { is_opds = true }), nil)
    local modes
    for _, row in ipairs(shown.buttons) do
        if row[1] and row[1].text == "Auto" then modes = row end
    end
    H.eq(#assert(modes), 3)
end)

local function sizeRow(draft, chrome)
    openStyle(draft, chrome)
    for _, row in ipairs(shown.buttons) do
        local button = row[2]
        if button and button.text_func
                and button.text_func():match("^Cover size:") then return row end
    end
end

H.test("cover size defaults to 100 percent and previews each ten-percent step", function()
    local draft = { [ViewMode.CHIP_KEY] = ViewMode.SPINES, spine_rows = 2 }
    local row = sizeRow(draft)
    H.eq(row[2].text_func(), "Cover size: 100%")
    local before = changes
    row[3].callback()
    H.eq(draft.spine_cover_size_pct, 110)
    H.eq(changes, before + 1)
    H.eq(sizeRow(draft)[2].text_func(), "Cover size: 110%")
    sizeRow(draft)[1].callback()
    H.eq(draft.spine_cover_size_pct, nil)
    H.eq(sizeRow(draft)[2].text_func(), "Cover size: 100%")
    for _ = 1, 12 do sizeRow(draft)[1].callback() end
    H.eq(draft.spine_cover_size_pct, 50)
    for _ = 1, 12 do sizeRow(draft)[3].callback() end
    H.eq(draft.spine_cover_size_pct, 150)
    H.eq(draft.spine_rows, 2)
    H.eq(draft.spine_thickness_pct, nil)
end)

H.test("only physical bookshelves expose the size control", function()
    for _, mode in ipairs({ ViewMode.AUTO, ViewMode.COVERS, ViewMode.LIST }) do
        H.eq(sizeRow({ [ViewMode.CHIP_KEY] = mode }), nil)
    end
    H.eq(sizeRow({ [ViewMode.CHIP_KEY] = ViewMode.SPINES }, { is_opds = true }), nil)
end)
H.finish()
