package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Icons = require("core/orbitui_icons")
local Adapter = require("adapters/orbitui_icons")
local Widget = H.widget()
function Widget:getSize() return { w = self.width or 24, h = self.height or 24 } end
function Widget:free() end
function Widget:_render() end
function Widget:paintTo() end
local shown, deferred, dirty = nil, {}, 0
local manager = {
    show = function(_, w) shown = w end,
    close = function(_, w) if w.config and w.config.on_closed then w.config.on_closed() end end,
    nextTick = function(_, fn) deferred[#deferred + 1] = fn end,
    setDirty = function() dirty = dirty + 1 end,
}
local store, writes = {}, 0
local copied = {}
package.loaded["infra/sui_store"] = {
    get = function(_, k) return store[k] end,
    set = function(_, k, v) store[k] = v; writes = writes + 1 end,
    del = function(_, k) store[k] = nil; writes = writes + 1 end,
}
package.loaded["logger"] = { warn = function() end, dbg = function() end, info = function() end }
package.loaded["ffi/blitbuffer"] = {
    COLOR_BLACK = "black", COLOR_WHITE = "white", COLOR_GRAY = "gray",
    Color8 = function(n) return n end,
    gray = function(n) return n end,
}
package.loaded["datastorage"] = {
    getDataDir = function() return "/fake" end, getSettingsDir = function() return "/fake/settings" end,
}
package.loaded["infra/sui_paths"] = { getPluginDir = function() return "./components/simpleui/" end }
package.loaded["infra/sui_cover_cache"] = {}
package.loaded["infra/sui_i18n"] = { translate = function(s) return s end, ngettext = function(s) return s end }
package.loaded["lib/bookshelf_i18n"] = { gettext = function(s) return s end }
package.loaded["ffi/util"] = { template = function(s) return s end,
    copyFile = function(src, dst) copied[dst] = src end }
package.loaded["libs/libkoreader-lfs"] = {
    attributes = function(path, mode)
        if copied[path] then return mode == "mode" and "file" or { mode = "file" } end
        if path:match("^/fake") then return mode == "mode" and "directory" or { mode = "directory" } end
        local f = io.open(path, "rb")
        if f then f:close(); return mode == "mode" and "file" or { mode = "file" } end
    end,
    dir = function() return function() end end,
}
local screen = { scaleBySize = function(_, v) return v end,
    getWidth = function() return 1264 end, getHeight = function() return 1680 end }
package.loaded["device"] = { screen = screen }
package.loaded["ui/uimanager"] = manager
package.loaded["ui/font"] = { getFace = function(_, name, size) return { name = name, size = size } end }
package.loaded["ui/geometry"] = { new = function(_, opts) return opts end }
package.loaded["ui/size"] = { border = { thin = 1 } }
for _, name in ipairs({ "container/centercontainer", "container/framecontainer", "container/widgetcontainer",
        "textwidget", "imagewidget", "buttondialog", "notification", "horizontalgroup", "horizontalspan",
        "verticalgroup", "verticalspan" }) do
    package.loaded["ui/widget/" .. name] = Widget
end
package.loaded["ui/event"] = Widget
package.loaded["lib/bookshelf_library_modal"] = Widget
package.loaded["lib/bookshelf_colour_text"] = Widget
package.loaded["lib/bookshelf_fonts"] = package.loaded["ui/font"]
package.loaded["lib/bookshelf_space"] = { px = function(n) return n end, radius = { default = 2 }, span = {} }
package.loaded["lib/bookshelf_icons_catalogue"] = {
    CHIPS = { { key = "all", label = "All" }, { key = "svg", label = "SVG" } },
    CURATED_BY_CHIP = {}, PATTERNS_BY_CHIP = {}, PATTERN_EXCLUDES = {},
}
package.loaded["lib/bookshelf_nerdfont_names"] = { { code = 0xF02D, name = "book" } }
package.loaded["infra/sui_aa_paint"] = {}
package.loaded["infra/sui_core"] = {
    makeColoredText = function(opts) return Widget:new(opts) end,
    wrapDimmable = function(w, dim) w.dim = dim; return w end,
}
G_reader_settings = { readSetting = function() end }
local Config = Adapter.wrap("infra/sui_config", dofile("components/simpleui/infra/sui_config.lua"))
package.loaded["infra/sui_config"] = Config
local Style = Adapter.wrap("features/sui_style", dofile("components/simpleui/features/sui_style.lua"))
package.loaded["features/sui_style"] = Style
local Library = Adapter.wrap("lib/bookshelf_icons_library", dofile("components/bookshelf/lib/bookshelf_icons_library.lua"))
package.loaded["lib/bookshelf_icons_library"] = Library

H.test("loading icon support makes no setting writes and catalogue is lazy/cached", function()
    H.eq(writes, 0)
    H.eq(#Icons.catalogue(), 110)
    H.eq(Icons.catalogue(), Icons.catalogue())
    H.eq(Icons.bookshelfCells(), Icons.bookshelfCells())
end)
H.test("Material names select their own face without changing Nerd codepoints", function()
    local char, face = Config.iconGlyph("material:manga")
    H.eq(char, string.char(0xEF, 0x97, 0xA3))
    assert(face:match("MaterialSymbolsRounded.ttf$"))
    H.eq(Config.isNerdIcon("material:manga"), false)
    H.eq(Config.isFontIcon("material:manga"), true)
    H.eq(Config.nerdIconChar("nerd:F5E3"), char)
    H.eq(Config.iconFace("nerd:F5E3", 24).name, "symbols")
    H.eq(Config.iconFace("material:manga", 24).name, face)
    H.eq(Config.iconGlyph("material:missing"), nil)
    H.eq(Config.isFontIcon(nil), false)
end)
H.test("pack names and assets reject path traversal or unlisted glyphs", function()
    for _, bad in ipairs({ "material:../manga", "material:MANGA", "material:manga.svg", "material:manga]",
            "orbitui-material-../manga", "nerd:F5E3", "material:missing" }) do
        H.eq(Icons.entry(bad), nil, bad)
    end
    for _, item in ipairs(Icons.catalogue()) do
        for _, path in ipairs({ item.font, item.file }) do
            local f = assert(io.open(path, "rb")); f:close()
        end
        H.eq(Icons.entry(item.value), item)
    end
end)
H.test("search covers canonical names, Swedish aliases, multiple words and categories", function()
    H.eq(Icons.filtered("Reading", "manga")[1].name, "manga")
    H.eq(Icons.filtered("Navigation", "hem")[1].name, "home")
    H.eq(Icons.filtered("System", "power off")[1].name, "power_settings_new")
    H.eq(#Icons.filtered("Navigation", "manga"), 0)
    H.eq(#Icons.filtered("all", "[."), 0)
end)
H.test("only known bundled images rebase across OTA slots", function()
    local old = "/reader/plugins/orbitui.koplugin/.orbitui-versions/old/assets/material-symbols/icons/manga.svg"
    H.eq(Style.safeIconPath(old), Icons.imageFile("material:manga"))
    H.eq(Style.safeIconPath("material:manga"), "material:manga")
    H.eq(Style.safeIconPath("nerd:F02D"), "nerd:F02D")
    H.eq(Style.safeIconPath("/missing.svg", "fallback"), "fallback")
    H.eq(Icons.rebaseImage("/custom/manga.svg"), nil)
    H.eq(Icons.rebaseImage(old:gsub("manga.svg", "missing.svg")), nil)
end)
H.test("Bookshelf offers Material only where image tokens are supported", function()
    H.eq(#Library._itemList("material", nil, true), 110)
    H.eq(#Library._itemList("all", nil, true), 111)
    H.eq(#Library._itemList("all", nil, false), 1)
    H.eq(#Library._itemList("all", "manga", false), 0)
    local cell = Library._itemList("all", "manga", true)[1]
    H.eq(cell.insert_value, "[icon=orbitui-material-manga]")
    local model = Adapter.wrap("lib/bookshelf_start_menu_model", {})
    H.eq(model.imageIconFile("orbitui-material-manga"), Icons.imageFile("material:manga"))
    H.eq(model.imageIconFile("home"), nil)
    Library:show(function() end, { svg = true })
    H.eq(shown.config.chip_strip()[2].key, "material")
end)
H.test("native tabs register actual SVGs from names and previous OTA slots", function()
    H.eq(Style.registerTabIconName("sui_tab_main", "material:manga"), "simpleui_sui_tab_main")
    H.eq(copied["/fake/icons/simpleui_sui_tab_main.svg"], Icons.imageFile("material:manga"))
    local old = "/old-slot/assets/material-symbols/icons/settings.svg"
    H.eq(Style.registerTabIconName("sui_tab_setting", old), "simpleui_sui_tab_setting")
    H.eq(copied["/fake/icons/simpleui_sui_tab_setting.svg"], Icons.imageFile("material:settings"))
    H.eq(Style.registerTabIconName("sui_tab_tools", "nerd:F02D"), nil)
end)
H.test("picker renders Material with its own face and labels with the UI face", function()
    local widget = Library._renderCell(Icons.catalogue()[1], { w = 220, h = 180 })
    local stack = widget[1][1]
    assert(stack[1].face.name:match("MaterialSymbolsRounded.ttf$"))
    H.eq(stack[3].face.name, "cfont")
end)
H.test("dock and quick-action primitives preserve colors, dimming and separate faces", function()
    local Renderer = dofile("components/simpleui/engines/sui_quickactions_render.lua")
    local w = Renderer.buildIcon({ icon = "material:manga", label = "Manga", dim = true }, 64, "white")
    assert(w[1].face.name:match("MaterialSymbolsRounded.ttf$"))
    H.eq(w[1].fgcolor, "white"); H.eq(w.dim, true)
    local nerd = Renderer.buildIcon({ icon = "nerd:F5E3" }, 64, "black")
    H.eq(nerd[1].face.name, "symbols")
    local framed = Renderer.buildFramedIcon("material:manga", 64, "white")
    assert(framed._inner.face.name:match("MaterialSymbolsRounded.ttf$"))
    framed:onToggleNightMode(); H.eq(dirty, 1)
end)
H.test("system button wrappers retain the Material face for later resizing", function()
    Style.setIcon("sui_search", "material:manga")
    local old = Widget:new{ width = 40, height = 40 }
    local btn = { image = old, width = 40, height = 40, horizontal_group = { {}, old }, icon_color = "white" }
    assert(Style.applyIconToBtn("sui_search", btn))
    assert(btn.image.sui_icon_font:match("MaterialSymbolsRounded.ttf$"))
    H.eq(btn.image.face.name, btn.image.sui_icon_font)
    H.eq(btn.image.fgcolor, "white")
    H.eq(btn.horizontal_group[2], btn.image)
    local titlebar = dofile("components/simpleui/screens/sui_titlebar.lua")
    local resize
    for i = 1, 100 do
        local name, value = debug.getupvalue(titlebar.apply, i)
        if not name then break end
        if name == "_resizeAndStrip" then resize = value; break end
    end
    assert(resize, "actual titlebar resizing helper not found")
    btn.icon, btn.file, btn.update = "material:manga", "nerd:invalid", function() end
    resize(btn, 80)
    H.eq(btn.image.face.name, btn.image.sui_icon_font)
    H.eq(btn.image.face.size, 52)
    H.eq(btn.icon, nil); H.eq(btn.file, nil)
end)
H.test("select and cancel are exclusive and image-only callers receive SVG", function()
    local picked, cancelled = nil, 0
    local function cancel() cancelled = cancelled + 1 end
    local picker = Adapter.show(function(v) picked = v end, cancel)
    picker.config.on_search_submit("manga")
    local cell = picker.config.item_at(1)
    picker.config.on_cell_tap(cell)
    H.eq(picked, "material:manga"); H.eq(cancelled, 0)
    picker = Adapter.show(function(v) picked = v end, cancel, true)
    picker.config.on_cell_tap(picker.config.item_at(1))
    H.eq(picked, Icons.imageFile("material:manga"))
    picker = Adapter.show(function() error("cancel selected an icon") end, cancel)
    picker.config.footer_actions[1].on_tap()
    H.eq(cancelled, 0); deferred[#deferred](); H.eq(cancelled, 1)
end)
H.test("existing picker exposes Material and returns to the same picker on cancel", function()
    local QA = Adapter.wrap("features/sui_quickactions", dofile("components/simpleui/features/sui_quickactions.lua"))
    package.loaded["features/sui_quickactions"] = QA
    local handle = {}
    QA.showIconPicker("nerd:F02D", function() end, "Default", handle, "picker", true)
    local original, material = shown
    for _, row in ipairs(shown.buttons) do
        if row[1].text == "Material Symbols Rounded..." then material = row[1] end
    end
    assert(material)
    material.callback(); assert(shown.config)
    shown.config.footer_actions[1].on_tap(); deferred[#deferred]()
    assert(shown ~= original and shown.buttons)
    H.eq(handle.picker, shown)
end)
H.test("pack listing is read-only; applying changes only mapped icon settings", function()
    local before = writes
    H.eq(Style.listPacks()[1].path, Icons.pack_id)
    H.eq(writes, before)
    store.unrelated = "keep"
    store.simpleui_custom_qa = { "keep this custom action" }
    local old = store.simpleui_custom_qa
    local result = Style.applyPack(Icons.pack_id)
    assert(result.applied > 40)
    H.eq(store.unrelated, "keep"); H.eq(store.simpleui_custom_qa, old)
    H.eq(Style.getIcon("sui_menu"), "material:menu")
    H.eq(Style.getIcon("sui_tab_main"), Icons.imageFile("material:menu"))
    H.eq(require("features/sui_quickactions").getDefaultActionIcon("bookshelf_comics"), "material:manga")
end)
H.finish()
