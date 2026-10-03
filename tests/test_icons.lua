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
    close = function(_, w)
        if w.onCloseWidget then w:onCloseWidget()
        elseif w.config and w.config.on_closed then w.config.on_closed() end
    end,
    nextTick = function(_, fn) deferred[#deferred + 1] = fn end,
    setDirty = function() dirty = dirty + 1 end,
}
local store, writes = {}, 0
local copied = {}
local Image = Widget:extend{}
function Image:init()
    if self.file then
        assert(not self.file:match("^material:"), "Unresolved Material image reference")
    end
end
function Image:_render()
    local f = assert(io.open(self.file, "rb"), "Image must resolve to an existing file")
    f:close()
end
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
local screen = { width = 1264, height = 1680, scaleBySize = function(_, v) return v end,
    getWidth = function(self) return self.width end, getHeight = function(self) return self.height end }
local has_keys = false
package.loaded["device"] = { screen = screen, input = { group = { Back = { "Back" } } },
    hasKeys = function() return has_keys end, hasDPad = function() return has_keys end }
package.loaded["ui/uimanager"] = manager
package.loaded["ui/font"] = { getFace = function(_, name, size)
    assert(not name:lower():find("material", 1, true), "Material must never load as a text font")
    return { name = name, size = size }
end }
package.loaded["ui/geometry"] = { new = function(_, opts) return opts end }
package.loaded["ui/size"] = { border = { thin = 1, default = 2, window = 3 }, line = { thin = 1 } }
for _, name in ipairs({ "container/centercontainer", "container/framecontainer", "container/widgetcontainer",
        "container/inputcontainer", "container/leftcontainer", "container/topcontainer", "button", "linewidget",
        "textwidget", "imagewidget", "buttondialog", "notification", "horizontalgroup", "horizontalspan",
        "verticalgroup", "verticalspan" }) do
    package.loaded["ui/widget/" .. name] = Widget
end
package.loaded["ui/widget/imagewidget"] = Image
package.loaded["ui/widget/iconwidget"] = Image
package.loaded["ui/event"] = Widget
package.loaded["ui/gesturerange"] = Widget
local InputText = Widget:extend{}
function InputText:init() self._frame_textwidget = {} end
function InputText:getText() return self.text end
function InputText:setText(text) self.text = text end
function InputText:unfocus() self.focused = false end
function InputText:isKeyboardVisible() return false end
package.loaded["ui/widget/inputtext"] = InputText
package.loaded["lib/bookshelf_colour_text"] = Widget
package.loaded["lib/bookshelf_fonts"] = package.loaded["ui/font"]
package.loaded["lib/bookshelf_space"] = { px = function(n) return n end, radius = { default = 2 },
    padding = { default = 4 }, span = {} }
package.loaded["lib/bookshelf_pagination"] = { buildNav = function(opts) return Widget:new(opts) end }
-- Keep modal init/refresh and all picker callbacks real; stub native widgets only.
package.loaded["lib/bookshelf_library_modal"] = dofile("components/bookshelf/lib/bookshelf_library_modal.lua")
package.loaded["lib/bookshelf_icons_catalogue"] = {
    CHIPS = { { key = "all", label = "All" }, { key = "svg", label = "SVG" } },
    CURATED_BY_CHIP = {}, PATTERNS_BY_CHIP = {}, PATTERN_EXCLUDES = {},
}
package.loaded["lib/bookshelf_nerdfont_names"] = { { code = 0xF02D, name = "book" } }
package.loaded["infra/sui_aa_paint"] = {}
package.loaded["infra/sui_core"] = {
    makeColoredText = function(opts) return Widget:new(opts) end,
    wrapDimmable = function(w, dim) w.dim = dim; return w end,
    makeAlphaMaskWidget = function(inner, fg, dimen)
        return Widget:new{ _inner = inner, _fg = fg, dimen = dimen }
    end,
}
local language = "en"
G_reader_settings = { readSetting = function(_, key) if key == "language" then return language end end }
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
H.test("unweighted selections use 300 while each explicit weight round trips independently", function()
    H.eq(Icons.default_weight, 300)
    for _, value in ipairs({ "material:manga", "orbitui-material-manga", "[icon=orbitui-material-manga]",
            "/old-slot/assets/material-symbols/icons/manga.svg" }) do
        H.eq(Icons.entry(value).weight, 300)
    end
    for _, weight in ipairs({ 200, 300, 400, 500 }) do
        local catalogue = Icons.catalogue(weight)
        H.eq(#catalogue, 110)
        H.eq(Icons.catalogue(weight), catalogue)
        for _, cell in ipairs(catalogue) do
            H.eq(cell.weight, weight)
            for _, value in ipairs({ cell.value, cell.icon, cell.insert_value, cell.file }) do
                H.eq(Icons.entry(value), cell)
            end
            local old = "/reader/.orbitui-versions/old/assets/material-symbols/icons/" .. weight .. "/" .. cell.name .. ".svg"
            H.eq(Style.safeIconPath(old), cell.file)
            H.eq(Icons.rebaseImage(old), cell.file)
        end
    end
    H.eq(Icons.forWeight("material:manga:500", 200).weight, 200)
    H.eq(Icons.forWeight("nerd:F02D", 300), nil)
    H.eq(Icons.forWeight("material:manga", 999), nil)
end)
H.test("Material never uses font rendering and Nerd codepoints remain unchanged", function()
    H.eq(Adapter.modules["infra/sui_config"], nil)
    H.eq(Config.iconGlyph("material:manga"), nil)
    H.eq(Config.isNerdIcon("material:manga"), false)
    H.eq(Config.isFontIcon("material:manga"), false)
    H.eq(Config.nerdIconChar("nerd:F5E3"), string.char(0xEF, 0x97, 0xA3))
    H.eq(Config.iconFace("nerd:F5E3", 24).name, "symbols")
    H.eq(Config.iconGlyph("material:missing"), nil)
    H.eq(Config.isFontIcon(nil), false)
end)
H.test("pack names and assets reject path traversal or unlisted glyphs", function()
    for _, bad in ipairs({ "material:../manga", "material:MANGA", "material:manga.svg", "material:manga]",
            "orbitui-material-../manga", "nerd:F5E3", "material:missing", "material:manga:100",
            "material:manga:300.5", "material:manga:0300", "orbitui-material-manga-w999",
            "[icon=orbitui-material-manga-w300]suffix", "[icon=orbitui-material-../manga-w300]",
            "/old/assets/material-symbols/icons/999/manga.svg", "/old/assets/material-symbols/icons/300/../manga.svg" }) do
        H.eq(Icons.entry(bad), nil, bad)
    end
    for _, item in ipairs(Icons.catalogue()) do
        local f = assert(io.open(item.file, "rb")); f:close()
        H.eq(item.font, nil)
        H.eq(item.is_image, true)
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
    H.eq(Style.safeIconPath("material:manga"), Icons.imageFile("material:manga"))
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
    H.eq(cell.insert_value, "[icon=orbitui-material-manga-w300]")
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
    H.eq(Style.registerTabIconName("sui_tab_setting", Icons.imageFile("material:settings:200")), "simpleui_sui_tab_setting")
    H.eq(copied["/fake/icons/simpleui_sui_tab_setting.svg"], Icons.imageFile("material:settings:200"))
    H.eq(Style.registerTabIconName("sui_tab_tools", "nerd:F02D"), nil)
end)
H.test("both pickers render every Material weight with SVG and UI-face labels", function()
    for _, weight in ipairs(Icons.weights) do
        local cells = Icons.bookshelfCells(weight)
        for _, cell in ipairs(cells) do
            local widget = Library._renderCell(cell, { w = 220, h = 180 })
            local stack = widget[1][1]
            H.eq(stack[1].file, cell.file)
            stack[1]:_render()
            H.eq(stack[1].face, nil)
            H.eq(stack[3].face.name, "cfont")
        end
    end
end)
H.test("dock and quick actions use the existing image and alpha-mask paths", function()
    local Renderer = dofile("components/simpleui/engines/sui_quickactions_render.lua")
    local w = Renderer.buildIcon({ icon = "material:manga", label = "Manga", dim = true }, 64, "white")
    H.eq(w.file, Icons.imageFile("material:manga"))
    H.eq(w.alpha, true); H.eq(w.dim, true)
    local nerd = Renderer.buildIcon({ icon = "nerd:F5E3" }, 64, "black")
    H.eq(nerd[1].face.name, "symbols")
    local framed = Renderer.buildFramedIcon("material:manga", 64, "white")
    H.eq(framed._inner.file, Icons.imageFile("material:manga"))
    H.eq(framed._inner.original_in_nightmode, true)
    H.eq(framed._fg, "white")
end)
H.test("system buttons stay image widgets and resize without loading a new font", function()
    Style.setIcon("sui_search", "material:manga")
    local old = Image:new{ width = 40, height = 40 }
    local btn = { image = old, width = 40, height = 40, horizontal_group = { {}, old }, icon_color = "white" }
    assert(Style.applyIconToBtn("sui_search", btn))
    H.eq(btn.image, old)
    H.eq(btn.image.file, Icons.imageFile("material:manga"))
    H.eq(btn.image.face, nil)
    H.eq(btn.horizontal_group[2], btn.image)
    local titlebar = dofile("components/simpleui/screens/sui_titlebar.lua")
    local resize
    for i = 1, 100 do
        local name, value = debug.getupvalue(titlebar.apply, i)
        if not name then break end
        if name == "_resizeAndStrip" then resize = value; break end
    end
    assert(resize, "actual titlebar resizing helper not found")
    btn.update = function() end
    resize(btn, 80)
    H.eq(btn.image.file, Icons.imageFile("material:manga"))
    H.eq(btn.image.face, nil)
    H.eq(btn.image.width, 80); H.eq(btn.image.height, 80)
end)
H.test("Material initializes the real modal in both languages, orientations and input modes", function()
    local before = writes
    local labels = {
        en = { "All", "Reading", "Navigation", "System", "Tools" },
        sv = { "Alla", "L\195\164sning", "Navigering", "System", "Verktyg" },
    }
    for lang, expected in pairs(labels) do
        language = lang
        for _, landscape in ipairs({ false, true }) do
            screen.width, screen.height = landscape and 1680 or 1264, landscape and 1264 or 1680
            for _, keys in ipairs({ false, true }) do
                has_keys = keys
                local picker = Adapter.show(function() error("Opening must not select an icon") end)
                H.eq(shown, picker)
                H.eq(picker.active_chip, "all")
                H.eq(picker._total_pages, landscape and 8 or 7)
                H.eq(picker:_gridCols(), landscape and 5 or 4)
                H.eq(picker._dpad_idx, keys and 1 or nil)
                assert(picker.frame[1] and picker._search_input and picker._footer_layout)
                for i, chip in ipairs(picker.config.chip_strip()) do
                    H.eq(chip.label, expected[i])
                    H.eq(chip.is_active, i == 1)
                end
                local images = 0
                local function checkImages(widget)
                    if widget.file then
                        images = images + 1
                        H.eq(widget.file, picker.config.item_at(images).file)
                        widget:_render()
                    end
                    for _, child in ipairs(widget) do checkImages(child) end
                end
                checkImages(picker)
                H.eq(images, landscape and 15 or 16)
                picker:onClose()
            end
        end
    end
    language, has_keys = "en", false
    screen.width, screen.height = 1264, 1680
    H.eq(writes, before)
end)
H.test("Material modal refreshes categories, paging, search and empty results", function()
    local picker = Adapter.show(function() end)
    local input = picker._search_input
    picker:onSwipeNextPage()
    H.eq(picker.page, 2)
    for _, group in ipairs({ "Reading", "Navigation", "System", "Tools", "all" }) do
        picker:_onChipTap(group)
        H.eq(picker.page, 1)
        H.eq(picker.active_chip, group)
        H.eq(picker.config.item_count(), #Icons.filtered(group))
        for _, chip in ipairs(picker.config.chip_strip()) do
            H.eq(chip.is_active, chip.key == group)
        end
    end
    picker:_onSearchSubmit("manga")
    H.eq(picker.config.item_count(), 2)
    H.eq(picker.config.item_at(1).file, Icons.imageFile("material:manga"))
    H.eq(picker.config.item_at(2).file, Icons.imageFile("material:comic_bubble"))
    H.eq(picker._search_input, input)
    H.eq(input:getText(), "manga")
    picker:_onChipTap("Navigation")
    H.eq(picker.config.item_count(), 0)
    H.eq(picker._total_pages, 1)
    picker:_onSearchSubmit("")
    H.eq(picker.config.item_count(), #Icons.filtered("Navigation"))
    H.eq(input:getText(), "")
    picker:onClose()
end)
local function weightControl(picker)
    for i, action in ipairs(picker.config.footer_actions) do
        if action.key == "material_weight" then return picker._footer_layout[1][i], action end
    end
end
local function chooseWeight(picker, weight)
    local control = assert(weightControl(picker))
    control.callback()
    local dialog = shown
    for i, candidate in ipairs(Icons.weights) do
        if candidate == weight then dialog.buttons[i][1].callback(); return end
    end
    error("Missing weight option")
end
local function checkPreviewWeight(widget, weight)
    local count = 0
    if widget.file then
        H.eq(Icons.entry(widget.file).weight, weight)
        widget:_render()
        count = 1
    end
    for _, child in ipairs(widget) do count = count + checkPreviewWeight(child, weight) end
    return count
end
H.test("weight changes refresh actual previews without changing paging, query or settings", function()
    local before = writes
    local picker = Adapter.show(function() error("Only previewing") end)
    local input = picker._search_input
    picker:onSwipeNextPage()
    for _, weight in ipairs(Icons.weights) do
        chooseWeight(picker, weight)
        H.eq(picker.page, 2)
        H.eq(checkPreviewWeight(picker, weight), 16)
        local control = weightControl(picker)
        H.eq(control.text, "Line thickness: " .. weight .. "...")
    end
    picker:_onChipTap("Reading")
    picker:_onSearchSubmit("manga")
    chooseWeight(picker, 200)
    H.eq(picker.active_chip, "Reading")
    H.eq(picker._search_input, input)
    H.eq(input:getText(), "manga")
    H.eq(checkPreviewWeight(picker, 200), 2)
    H.eq(writes, before)
    local control = weightControl(picker)
    control.callback()
    shown.buttons[#shown.buttons][1].callback()
    H.eq(picker.config.item_at(1).weight, 200)
    picker:onClose()
    H.eq(writes, before)
    local fresh = Adapter.show(function() end)
    H.eq(fresh.config.item_at(1).weight, 300)
    fresh:onClose()
end)
H.test("current explicit weight reopens on only that icon and survives a runtime reload", function()
    local value
    local picker = Adapter.show(function(v) value = v end, nil, Icons.imageFile("material:manga:400"))
    H.eq(picker.config.item_at(1).weight, 400)
    chooseWeight(picker, 500)
    picker.config.on_cell_tap(picker.config.item_at(1))
    H.eq(value, Icons.imageFile("material:manga:500"))
    local reloaded = dofile("./core/orbitui_icons.lua")
    H.eq(reloaded.entry(value).weight, 500)
    H.eq(reloaded.entry("[icon=orbitui-material-manga-w500]").weight, 500)
    H.eq(reloaded.entry("material:home").weight, 300)
    H.eq(reloaded.entry("material:home:200").weight, 200)
end)
H.test("Bookshelf weights affect only Material and tokens retain their weight", function()
    local picked
    Library:show(function(v) picked = v end, { svg = true, current_icon = "[icon=orbitui-material-manga-w400]" })
    local picker = Library.modal
    H.eq(picker.config.item_at(1).weight, 400)
    local nerd = picker.config.item_at(picker.config.item_count())
    chooseWeight(picker, 200)
    H.eq(picker.config.item_at(picker.config.item_count()), nerd)
    picker:_onSearchSubmit("manga")
    H.eq(checkPreviewWeight(picker, 200), 2)
    picker.config.on_cell_tap(picker.config.item_at(1))
    H.eq(picked, "[icon=orbitui-material-manga-w200]")
    H.eq(Icons.imageFile(picked), Icons.imageFile("material:manga:200"))
    Library:show(function() error("Cancel must not select") end, { svg = true })
    picker = Library.modal
    H.eq(picker.config.item_at(1).weight, 300)
    chooseWeight(picker, 500)
    picker.config.footer_actions[1].on_tap()
    H.eq(picked, "[icon=orbitui-material-manga-w200]")
    Library:show(function() end, { svg = false })
    H.eq(weightControl(Library.modal), nil)
    Library.modal:onClose()
end)
H.test("weight controls translate and the default weight is always selectable", function()
    language = "sv"
    local picked
    local picker = Adapter.show(function(v) picked = v end)
    local control = weightControl(picker)
    H.eq(control.text, "Linjetjocklek: 300...")
    control.callback()
    H.eq(shown.buttons[2][1].text, "\226\156\147 300 - L\195\164tt (standard)")
    shown.buttons[2][1].callback()
    picker.config.on_cell_tap(picker.config.item_at(1))
    H.eq(picked, Icons.imageFile("material:manga:300"))
    language = "en"
end)
H.test("select and cancel are exclusive and all callers receive SVG", function()
    local picked, cancelled = nil, 0
    local function cancel() cancelled = cancelled + 1 end
    local picker = Adapter.show(function(v) picked = v end, cancel)
    picker.config.on_search_submit("manga")
    local cell = picker.config.item_at(1)
    picker.config.on_cell_tap(cell)
    H.eq(picked, Icons.imageFile("material:manga")); H.eq(cancelled, 0)
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
H.test("Material is not a pack and legacy apply requests never overwrite settings", function()
    local before = writes
    for _, pack in ipairs(Style.listPacks()) do assert(pack.path ~= Icons.legacy_pack_id) end
    store.unrelated = "keep"
    store.simpleui_custom_qa = { "keep this custom action" }
    local old = store.simpleui_custom_qa
    local result = Style.applyPack(Icons.legacy_pack_id)
    H.eq(result.applied, 0)
    H.eq(result.errors, 1)
    H.eq(writes, before)
    H.eq(store.unrelated, "keep"); H.eq(store.simpleui_custom_qa, old)
end)
H.test("external pack operations are unchanged", function()
    local calls = 0
    local module = Adapter.wrap("features/sui_style", {
        applyPack = function(path) calls = calls + 1; return path end,
        listPacks = function() return "external-pack-list" end,
    })
    H.eq(module.listPacks(), "external-pack-list")
    H.eq(module.applyPack("/my-custom-pack"), "/my-custom-pack")
    H.eq(calls, 1)
    module.applyPack(Icons.legacy_pack_id)
    H.eq(calls, 1)
end)
H.test("opening the individual picker and cancelling writes nothing; selection changes one icon", function()
    local QA = require("features/sui_quickactions")
    local before, old_search = writes, store.simpleui_sysicon_sui_search
    local function open()
        QA.showIconPicker(QA.getDefaultActionIcon("bookshelf_comics"), function(value)
            QA.setDefaultActionIcon("bookshelf_comics", value)
        end, "Default", {}, "picker", true)
        for _, row in ipairs(shown.buttons) do
            if row[1].text == "Material Symbols Rounded..." then row[1].callback(); return end
        end
        error("Material picker is missing")
    end
    open()
    local picker = shown
    chooseWeight(picker, 200)
    picker.config.footer_actions[1].on_tap(); deferred[#deferred]()
    H.eq(writes, before)
    open()
    picker = shown
    chooseWeight(picker, 500)
    H.eq(writes, before)
    picker:_onSearchSubmit("manga")
    picker.config.on_cell_tap(picker.config.item_at(1))
    H.eq(writes, before + 1)
    H.eq(store.simpleui_action_bookshelf_comics_icon, Icons.imageFile("material:manga:500"))
    H.eq(store.simpleui_sysicon_sui_search, old_search)
    open()
    H.eq(shown.config.item_at(1).weight, 500)
    shown:onClose(); deferred[#deferred]()
    local row = QA.buildQARowIcon("material:manga", "Manga", function(n) return n end)
    H.eq(row[1][1].file, Icons.imageFile("material:manga"))
end)
H.test("legacy Material overrides are readable at startup without setting writes", function()
    local before = writes
    store.simpleui_sysicon_sui_menu = "material:menu"
    store.simpleui_action_bookshelf_comics_icon = "material:manga"
    local btn = { image = Image:new{ width = 40, height = 40 }, width = 40, height = 40 }
    assert(Style.applyIconToBtn("sui_menu", btn))
    H.eq(btn.image.file, Icons.imageFile("material:menu"))
    H.eq(require("features/sui_quickactions").getDefaultActionIcon("bookshelf_comics"), "material:manga")
    H.eq(writes, before)
    H.eq(store.simpleui_sysicon_sui_menu, "material:menu")
end)
H.finish()
