-- Real settings adapter AND complete native LibraryModal, with only KOReader's
-- widget/font/display boundary stubbed. Geometry is not native text rendering.
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local locale, writes, eager, warnings = "en", 0, 0, {}
G_reader_settings = { readSetting = function(_, key) if key == "language" then return locale end end,
    saveSetting = function() writes = writes + 1 end }
local width, height, scale = 600, 800, 1
local Screen = { getWidth = function() return width end, getHeight = function() return height end,
    scaleBySize = function(_, v) return math.floor(v * scale + 0.5) end }
package.loaded.device = { screen = Screen, hasKeys = function() return true end, hasDPad = function() return true end,
    input = { group = { Back = "Back" } } }
local function geom(o)
    o.copy = function(self) return geom{ x = self.x, y = self.y, w = self.w, h = self.h } end
    return o
end
package.loaded["ui/geometry"] = { new = function(_, o) return geom(o) end }
local shown, hosts = {}, {}
local UI = { show = function(_, w) shown[#shown + 1] = w end,
    close = function(_, w)
        if w.closed then return end
        w.closed = true
        if w.onCloseWidget then w:onCloseWidget() end
    end,
    setDirty = function() end,
}
package.loaded["ui/uimanager"] = UI
package.loaded.logger = { warn = function(_, reason) warnings[#warnings + 1] = reason end }
local W = H.widget()
function W:free()
    assert(not self.freed, "double free")
    self.freed = true
    for _, child in ipairs(self) do child:free() end
end
function W:getSize() return self.dimen or { w = self.width or 0, h = self.height or 0 } end
local VG = W:extend{}
function VG:getSize()
    local w, h = 0, 0
    for _, child in ipairs(self) do local d = child:getSize(); w = math.max(w, d.w); h = h + d.h end
    return { w = w, h = h }
end
local HG = W:extend{}
function HG:getSize()
    local w, h = 0, 0
    for _, child in ipairs(self) do local d = child:getSize(); w = w + d.w; h = math.max(h, d.h) end
    return { w = w, h = h }
end
local Frame = W:extend{}
function Frame:getSize()
    local d = self[1]:getSize()
    local border, p = self.bordersize or 0, self.padding or 0
    return { w = d.w + 2 * border + 2 * p,
        h = d.h + 2 * border + (self.padding_top or p) + (self.padding_bottom or p) }
end
local VS = W:extend{}
function VS:getSize() return { w = 0, h = self.width } end
local HS = W:extend{}
function HS:getSize() return { w = self.width, h = 0 } end
local Text = W:extend{}
function Text:getSize()
    -- Conservative UTF-8 character count and wrapping proxy, not KOReader shaping.
    local _, chars = self.text:gsub("[^\128-\191]", "")
    local lines = math.max(1, math.ceil(chars * self.face.size * 0.57 / self.width))
    return { w = self.width, h = math.ceil(lines * self.face.size * 1.3) }
end
local Button = W:extend{}
function Button:getSize() return { w = self.width, h = Screen:scaleBySize(42) } end
function Button:onFocus() self.focused = true end
local fonts = { getFace = function(_, _, size, opts) return { size = Screen:scaleBySize(size) }, opts and opts.bold end }
for path, class in pairs({
    ["container/centercontainer"] = W, ["container/topcontainer"] = W,
    ["container/framecontainer"] = Frame, ["container/inputcontainer"] = W,
    verticalgroup = VG, horizontalgroup = HG, verticalspan = VS, horizontalspan = HS,
    textboxwidget = Text, button = Button, linewidget = W, iconwidget = W,
}) do package.loaded["ui/widget/" .. path] = class end
package.loaded["ui/gesturerange"] = W
package.loaded["ui/font"] = fonts
package.loaded["ui/size"] = { border = { window = 1 }, line = { thin = 1 } }
package.loaded["ffi/blitbuffer"] = { COLOR_WHITE = "white", COLOR_BLACK = "black", COLOR_DARK_GRAY = "gray" }
package.loaded["ffi/util"] = { template = function(s) return s end }
local translate = require("core/orbitui_i18n")
package.loaded["lib/bookshelf_i18n"] = { gettext = translate }
package.loaded["lib/bookshelf_fonts"] = fonts
package.loaded["lib/bookshelf_space"] = dofile(root .. "/components/bookshelf/lib/bookshelf_space.lua")
package.loaded["lib/bookshelf_pagination"] = { buildNav = function(opts)
    return W:new{ opts = opts, width = Screen:scaleBySize(180), height = Screen:scaleBySize(32) }
end }
local Base = dofile(root .. "/components/bookshelf/lib/bookshelf_library_modal.lua")
package.loaded["lib/bookshelf_library_modal"] = Base
package.loaded["core/orbitui_context"] = { plugin = function() eager = eager + 1; error("eager shelf") end }
package.loaded["lib/bookshelf_menu_host"] = { show = function(opts) hosts[#hosts + 1] = opts; return opts end,
    close = function(host) host.closed = true end }
package.loaded["ui/widget/inputdialog"] = { new = function(_, opts)
    opts.onShowKeyboard = function() end
    opts.getInputText = function(self) return self.input end
    return opts
end }
local Settings = require("adapters/orbitui_settings")
local function show()
    local m = Settings.show()
    assert(m.name == "orbitui_settings_start", tostring(warnings[#warnings]))
    return m
end
local function footer(m, key)
    for _, row in ipairs(m.config.footer_rows) do
        for _, item in ipairs(row) do if item.key == key then return item end end
    end
    error("Missing footer action " .. key)
end
local function inspect(widget, fn)
    fn(widget)
    for _, child in ipairs(widget) do inspect(child, fn) end
end

H.test("five static bilingual cards use existing category IDs and assets without preference writes", function()
    for _, lang in ipairs({ "en", "sv_SE" }) do
        locale = lang
        local m = show()
        H.eq(m.config.item_count(), 5)
        H.eq(m.config.item_at(1).text, translate("Home (SimpleUI)"))
        H.eq(m.config.item_at(5).id, "system")
        for _, card in ipairs(Settings.startCards()) do
            assert(card.description ~= "")
            local icon = assert(require("core/orbitui_icons").imageFile("material:" .. card.icon .. ":300"))
            local f = assert(io.open(icon, "rb")); f:close()
            if lang == "sv_SE" then assert(not card.description:find(" and ", 1, true)) end
        end
        assert(not m.config.on_search_submit and m.config.no_search)
    end
    H.eq(writes, 0); H.eq(eager, 0); H.eq(#warnings, 0)
end)
H.test("tap closes cards before opening the same native category; Back reconstructs the card start", function()
    local m = show()
    m.config.on_cell_tap(m.config.item_at(1))
    assert(m.closed)
    local host = hosts[#hosts]
    assert(host.title:find(translate("Home (SimpleUI)"), 1, true))
    host.on_back()
    H.eq(shown[#shown].name, "orbitui_settings_start")
end)
H.test("closed/replaced roots and repeated taps cannot open stale categories", function()
    local first, second = show(), show()
    assert(first.closed)
    local before = #hosts
    first.config.on_cell_tap(first.config.item_at(2)); H.eq(#hosts, before); assert(not second.closed)
    second:onClose(); assert(second.closed)
    second.config.on_cell_tap(second.config.item_at(1)); H.eq(#hosts, before)
end)
H.test("search uses the existing keyboard flow, and list view has a direct Back to category cards", function()
    local m = show()
    footer(m, "search").on_tap(); assert(m.closed)
    H.eq(shown[#shown].title, translate("Search settings"))
    local dialog = shown[#shown]
    H.eq(dialog.buttons[1][1].id, "close")
    dialog.buttons[1][1].callback(); H.eq(shown[#shown].name, "orbitui_settings_start")
    m = show(); footer(m, "list").on_tap(); assert(m.closed)
    local host = hosts[#hosts]
    H.eq(#host.item_table, 6); H.eq(host.parent_title, translate("Category cards"))
    host.on_back(); H.eq(shown[#shown].name, "orbitui_settings_start")
end)
H.test("search results keep their query Back route; late search callbacks never replace a newer destination", function()
    local m = show(); footer(m, "search").on_tap()
    local dialog = shown[#shown]
    dialog.input = "Home SimpleUI"; dialog.buttons[1][2].callback()
    local result = hosts[#hosts]
    H.eq(result.title, translate("Search settings"))
    result.item_table[2].callback()
    local target = hosts[#hosts]
    target.on_back(); H.eq(hosts[#hosts].title, translate("Search settings"))
    hosts[#hosts].on_back(); H.eq(shown[#shown].name, "orbitui_settings_start")
    local before = #hosts
    dialog.buttons[1][2].callback(); H.eq(#hosts, before)
end)
H.test("full native grid and card bodies fit portrait/landscape, narrow screens and larger font scaling", function()
    for _, size in ipairs({ {600,800}, {800,600}, {1264,1680}, {1680,1264}, {480,800}, {320,640} }) do
        for _, lang in ipairs({ "sv", "en" }) do
            for _, factor in ipairs({ 0.8, 1, 1.3 }) do
                locale, width, height = lang, size[1], size[2]
                scale = math.min(width, height) / 600 * factor
                local m = show()
                local d = m.frame:getSize()
                assert(d.w <= width and d.h <= height, width .. "x" .. height .. ": " .. d.w .. "x" .. d.h)
                H.eq(m.config.grid_cols() >= 1 and m.config.grid_cols() <= 2, true)
                inspect(m.frame, function(w)
                    if w[1] and w.dimen and getmetatable(w) == W and w[1].align == "left" then
                        assert(w[1]:getSize().h <= w.dimen.h, "card text clipped: " .. width .. "x" .. height
                            .. " scale " .. scale .. " body " .. w[1]:getSize().h .. " slot " .. w.dimen.h)
                    end
                end)
                while m.page < m._total_pages do m:onSwipeNextPage() end
                H.eq(m.page, m._total_pages)
                m:onSwipeNextPage(); H.eq(m.page, m._total_pages)
            end
        end
    end
    width, height, scale, locale = 600, 800, 1, "en"
end)
H.test("D-pad reaches every card and search/list/close footer without a touch-only exit", function()
    local m = show()
    m:onGridFocusDown(); H.eq(m._dpad_idx, 1)
    while m._dpad_idx < 5 do m:onGridFocusRight() end
    m:onGridFocusDown(); H.eq(m._focus_zone, "footer")
    H.eq(m._footer_row, 1)
    m:onGridFocusDown(); H.eq(m._footer_row, 2)
    m:onGridFocusRight(); H.eq(m._footer_col, 2)
    m:onGridPress(); assert(m.closed)
end)
H.test("touch-only devices keep tappable cards and a visible close action", function()
    local device = package.loaded.device
    local keys, dpad = device.hasKeys, device.hasDPad
    device.hasKeys = function() return false end; device.hasDPad = device.hasKeys
    local m = show()
    assert(not m.key_events)
    footer(m, "close").on_tap(); assert(m.closed)
    device.hasKeys, device.hasDPad = keys, dpad
end)
H.test("rotation replaces only the live card start and stale rotation events stay inert", function()
    local m = show()
    width, height = 800, 600
    m:onSetDimensions(); assert(m.closed)
    local replacement = shown[#shown]
    H.eq(replacement.name, "orbitui_settings_start")
    local before = #shown; m:onSetDimensions(); H.eq(#shown, before)
    width, height = 600, 800
    replacement:onSetDimensions()
end)
H.test("opening the card start invalidates an older deferred library settings request", function()
    local context = package.loaded["core/orbitui_context"]
    local original = context.plugin
    local ready, guard
    context.plugin = function() return nil end
    context.withShelf = function(_, callback, opts) ready, guard = callback, opts.is_current end
    Settings.library("comics")
    assert(guard())
    local m = show(); assert(not guard())
    local before = #hosts; ready({}); H.eq(#hosts, before); assert(not m.closed)
    context.plugin, context.withShelf = original, nil
end)
H.test("unusable geometry and missing optional UI dependencies fall back to the complete old list", function()
    width, height = 160, 100
    local h = Settings.show(); H.eq(h.title, translate("OrbitUI settings")); H.eq(#h.item_table, 6)
    width, height = 600, 800
    package.loaded["lib/bookshelf_library_modal"] = {}
    h = Settings.show(); H.eq(#h.item_table, 6)
    package.loaded["lib/bookshelf_library_modal"] = Base
    H.eq(writes, 0); H.eq(eager, 0)
end)
H.finish()
