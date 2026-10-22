package.path = "./?.lua;./components/simpleui/?.lua;" .. package.path
local H = require("tests/helpers")
H.simpleuiMemory()
local function read(path)
    local f = assert(io.open("components/simpleui/" .. path))
    local s = f:read("*a"); f:close(); return s
end
local function section(s, first, last)
    local a = assert(s:find(first, 1, true), first)
    return s:sub(a, assert(s:find(last, a, true), last) - 1)
end
local function run(s, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then local f = assert(loadstring(s)); setfenv(f, env); return f() end
    return assert(load(s, "October 17 integration", "t", env))()
end
local function noop() end
local settings = {}
local store = {
    memoize = function(fn) return fn end,
    readSetting = function(_, k) return settings[k] end,
    saveSetting = function(_, k, v) settings[k] = v end,
    get = function(_, k) return settings[k] end,
    isTrue = function(_, k) return settings[k] == true end,
    del = function() error("migration must retain old settings") end,
}
package.loaded["infra/sui_store"] = store
package.loaded["infra/sui_i18n"] = { translate = function(s) return s end }
package.loaded["device"] = { screen = { scaleBySize = function(_, n) return n end } }
package.loaded["ui/geometry"] = H.widget()
package.loaded["ui/widget/widget"] = H.widget()
package.loaded["infra/sui_aa_paint"] = {}
package.loaded["features/sui_style"] = { BORDER_SZ = 1, COLOR = { surface = "white", surface_flat = "gray" } }
local Backdrop = require("infra/sui_backdrop")
local WP, active = {}, true
run(section(read("features/sui_wallpaper.lua"), "local STRENGTH_MIN, STRENGTH_MAX", "-- Applies the lighten"),
    { M = WP, Backdrop = Backdrop, SUISettings = store })
WP.isWallpaperActive = function() return active end

H.test("surface defaults preserve OrbitUI transparent bars and explicit settings", function()
    settings = {}; active = true
    for _, kind in ipairs({"pagination", "titlebar", "cover_strip", "module"}) do
        H.eq(Backdrop.SURFACE_DEFAULT[kind].strength, 0)
        H.eq(Backdrop.BACKDROP_DEFAULT[kind], 0)
    end
    for _, kind in ipairs({"statusbar", "navbar", "titlebar", "pagination"}) do
        WP.setBarStrength(kind, 37)
        H.eq(WP.getBarStrength(kind), 37); H.eq(WP.resolveBar(kind).strength, 37)
        Backdrop.saveTone(WP.barSurface(kind), "gray")
        Backdrop.saveFrame(WP.barSurface(kind), true)
        local look = WP.resolveBar(kind)
        H.eq(look.color, "gray"); H.eq(look.border_sz, 1)
    end
    WP.setTitlebarButtonBackdropStrength(19)
    H.eq(WP.getTitlebarButtonBackdropStrength(), 19); H.eq(WP.getTitlebarBackdropStrength(), 37)
    H.eq(settings.simpleui_statusbar_transparent, false)
    WP.setNavbarBackdropStrength(0); H.eq(settings.simpleui_navbar_transparent, true)
    H.eq(WP.getNavbarBackdropStrength(), 0)
    active = false
    H.eq(WP.resolveBar("titlebar").strength, 100) -- explicit gray/frame, no wallpaper
    H.eq(WP.getTitlebarBackdropStrength(), 0) -- legacy API fallback unchanged
    H.eq(settings.simpleui_titlebar_backdrop, 37)
    package.loaded["modules/moduleregistry"] = {getInstanceKeys = function() return {} end}
    local inPreset = run(section(read("features/sui_presets.lua"), "local HS_PRESET_KEY", "local function _getDirs")
        .. "\nreturn _hsMatchesKey")
    for _, kind in ipairs({"statusbar", "navbar", "titlebar", "pagination", "cover_strip"}) do
        for _, field in ipairs({"backdrop", "tone", "show_frame"}) do
            H.eq(inPreset("simpleui_" .. kind .. "_" .. field), true)
        end
    end
    H.eq(inPreset("simpleui_titlebar_button_backdrop"), true)
    H.eq(inPreset("simpleui_hs_presets"), false)
    H.eq(inPreset("unrelated_token"), false)
end)

H.test("bar migration is copy-only and explicit surface choices win", function()
    active = true
    settings = {simpleui_navbar_transparent = true, simpleui_statusbar_transparent = false}
    H.eq(WP.getBarStrength("navbar"), 0); H.eq(WP.getBarStrength("statusbar"), 100)
    H.eq(settings.simpleui_navbar_transparent, true)
    H.eq(settings.simpleui_statusbar_transparent, false)
    H.eq(WP.getNavbarLayout(), "full"); H.eq(WP.resolveBar("navbar").frame, false)
    for _, style in ipairs({"default", "framed", "bare"}) do
        settings = {simpleui_bar_style = style}
        H.eq(WP.getNavbarLayout(), style == "default" and "full" or "floating")
        H.eq(settings.simpleui_bar_style, style)
        if style == "bare" then
            H.eq(WP.getBarStrength("navbar"), 0); H.eq(WP.resolveBar("navbar").frame, false)
        end
        settings = {simpleui_bar_style = style, simpleui_navbar_backdrop = 42, simpleui_navbar_show_frame = true}
        WP.getNavbarLayout()
        H.eq(WP.getBarStrength("navbar"), 42); H.eq(WP.resolveBar("navbar").frame, true)
    end
    settings.simpleui_bar_layout = "full"
    H.eq(WP.getNavbarLayout(), "full")
end)

H.test("the unified transparent-bar flag only fills unset legacy choices", function()
    local migration = section(read("features/sui_wallpaper.lua"),
        "do\n    local legacy = \"simpleui_bars_transparent\"", "-- Surfaces that sit over")
    for _, old in ipairs({true, false}) do
        settings = {simpleui_bars_transparent = old, simpleui_navbar_transparent = not old}
        run(migration, {SUISettings = store})
        H.eq(settings.simpleui_bars_transparent, old)
        H.eq(settings.simpleui_statusbar_transparent, old)
        H.eq(settings.simpleui_navbar_transparent, not old)
    end
end)

H.test("quick-setting buttons preserve migrated opacity and let users change it", function()
    local source = read("screens/sui_quicksettings_bar.lua")
    local surface = Backdrop.surface("quick_settings", "quick_buttons")
    local function buttonSurface()
        Backdrop.migrateLook(surface, "old_buttons_look")
        return surface
    end
    local spec = run(section(source, "local function buttonSpec", "-- Returns makeButton")
        .. "\nreturn buttonSpec", {
            BTN_ICON_PCT = 0.5, getShape = function() return "square_round" end,
            buttonSurface = buttonSurface, Backdrop = Backdrop, SUIStyle = {COLOR = {}},
        })
    settings = {old_buttons_look = "transparent"}
    H.eq(spec(40).surface.strength, 0)
    Backdrop.saveStrength(surface, 45)
    H.eq(spec(40).surface.strength, 45)
    H.eq(settings.old_buttons_look, "transparent")
    local config = section(source, "Config.makeSurfaceMenu{\n            surface       = buttonSurface()",
        "\n    }\n\n    -- Behaviour")
    config = config:gsub(",%s*$", "")
    local menu = run("return " .. config, {
        Config = {makeSurfaceMenu = function(opts) return opts end},
        buttonSurface = buttonSurface, getShape = function() return "square_round" end,
    })
    H.eq(menu.enabled_func(), true); H.eq(menu.with_strength(), true)
end)

H.test("legacy flat and transparent cards migrate without deleting or overwriting choices", function()
    for _, legacy in ipairs({"flat", "solid", "transparent", "cards_transparent"}) do
        settings = {old_look = legacy}
        local surface = Backdrop.surface("card", "cards", "cards_strength")
        Backdrop.migrateLook(surface, "old_look", {cards_transparent = "transparent"})
        local look = Backdrop.resolve(surface)
        H.eq(look.tone, legacy == "flat" and "gray" or "white")
        H.eq(look.frame, legacy ~= "flat")
        H.eq(look.strength, legacy:find("transparent", 1, true) and 0 or 100)
        H.eq(settings.old_look, legacy)
        Backdrop.saveTone(surface, "gray"); Backdrop.saveFrame(surface, false); Backdrop.saveStrength(surface, 61)
        Backdrop.migrateLook(surface, "old_look", {cards_transparent = "transparent"})
        look = Backdrop.resolve(surface)
        H.eq(look.tone, "gray"); H.eq(look.frame, false); H.eq(look.strength, 61)
    end
end)

H.test("metadata helpers retain whole UTF-8 characters and bound multi-author list context", function()
    local Text = require("infra/sui_text")
    local glyph = string.char(0xe6, 0x9c, 0xac)
    local ellipsis = string.char(0xe2, 0x80, 0xa6)
    H.eq(Text.cut(glyph:rep(8), 3), glyph:rep(3))
    H.eq(Text.truncate(glyph:rep(8), 3), glyph:rep(2) .. ellipsis)
    H.eq(Text.truncateStart(glyph:rep(8), 3), ellipsis .. glyph:rep(2))
    H.eq(Text.firstLine("\r\n  \n  Writer \r\nOther"), "Writer")
    H.eq(Text.formatAuthors("  Writer \n Other\n"), "Writer et al.")
    H.eq(Text.formatAuthors(" \r\n "), nil)
    local context = run(section(read("features/library/sui_library_browse.lua"),
        "local CONTEXT_MAX_CHARS", "local function _getVirtualList") .. "\nreturn _bookContext",
        {Text = Text})
    H.eq(context({authors = glyph:rep(100) .. "\nWriter"}, {}), glyph:rep(27) .. ellipsis)
    H.eq(context({series = glyph:rep(100), series_index = 12}, {author = true}),
        glyph:rep(23) .. ellipsis .. " #12")
    H.eq(context({series_index = 12}, {author = true, series = true}), "#12")
end)

local patches = read("infra/sui_patches.lua")
local Patches = require("adapters/orbitui_ui").wrap("infra/sui_patches", {})
local menuOpen, carry = run(section(patches, "local function _mainMenuOpenAbove", "-- FileManager class patches")
    .. "\nreturn _mainMenuOpenAbove, _carryDisplacedScreen", {M = Patches})
local stack, fm, shown, hs, manager = {}, {}, {}, {}, {}
package.loaded["apps/filemanager/filemanager"] = {instance = fm}
package.loaded["engines/sui_screen_engine"] = {getInstance = function() end}
package.loaded["infra/sui_screen_nav"] = {reopen = function(id) shown[#shown + 1] = id end}
local reopen = run(section(patches, "local function _doShowHS", "-- Gate of the reopen step")
    .. "\nreturn _doShowHS", {
        UIManager = manager, isAppExiting = function() return false end,
        liveHS = function() return hs end, UI = {getWindowStack = function() return stack end},
        _carryDisplacedScreen = carry, _isTransientToast = function(w) return w.toast end,
        _closeOrphanedPopups = noop, _showHSCold = function() shown[#shown + 1] = "hs" end,
    })

H.test("main-menu ownership keeps Home alive only beneath its own open menu", function()
    local home, menu = {}, {}
    fm.menu = {menu_container = menu}
    H.eq(menuOpen({{widget = home}, {widget = menu}, {widget = {}}}, 1, fm), true)
    H.eq(menuOpen({{widget = menu}, {widget = home}}, 2, fm), false)
    H.eq(menuOpen({{widget = home}, {widget = {}}}, 1, fm), false)
    H.eq(menuOpen({}, 1, nil), false)
end)

H.test("temporary fullscreens restore the right screen but destinations never inherit Home", function()
    shown = {}; stack = {{widget = fm}}
    reopen(fm, {}, "custom_1", 0); H.eq(shown[1], "custom_1")
    reopen(fm, {}, "hs", 0); H.eq(shown[2], "hs")
    local temporary = {covers_fullscreen = true, name = "plugin_details"}
    stack = {{widget = fm}, {widget = temporary}}
    reopen(fm, {}, "custom_2", 0)
    H.eq(#shown, 2); H.eq(temporary._sui_displaced_screen, "custom_2")
    for _, name in ipairs({"bookshelf", "homescreen", "ReaderUI"}) do
        local destination = {covers_fullscreen = true, name = name}
        stack = {{widget = fm}, {widget = destination}}
        reopen(fm, {}, "hs", 0)
        H.eq(destination._sui_displaced_screen, nil); H.eq(#shown, 2)
    end
end)

H.test("a deferred restore cannot outlive navigation or cover an interactive dialog", function()
    shown = {}; stack = {{widget = fm}}
    manager._simpleui_navigation_generation = 2
    reopen(fm, {}, "hs", 1); H.eq(#shown, 0)
    stack[2] = {widget = {buttons = {}}}
    reopen(fm, {}, "hs", 2); H.eq(#shown, 0)
    stack[2] = {widget = {toast = true}}
    reopen(fm, {}, "hs", 2); H.eq(#shown, 1)
    hs._instance = {}; reopen(fm, {}, "hs", 2); H.eq(#shown, 1); hs._instance = nil
end)

H.finish()
