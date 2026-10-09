package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = assert(io.open("components/simpleui/" .. path))
    local src = f:read("*a"); f:close(); return src
end
local function run(code, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then
        local fn = assert(loadstring(code)); setfenv(fn, env); return fn()
    end
    return assert(load(code, "October 9 follow-up regression", "t", env))()
end
local function section(src, first, last)
    local start = assert(src:find(first, 1, true))
    return src:sub(start, assert(src:find(last, start, true)) - 1)
end
local function method(src, first)
    local start = assert(src:find(first, 1, true))
    return src:sub(start, assert(src:find("\nend", start, true)) + 3) .. "\n"
end
local function identity(v) return v end
local noop = function() end
local settings = {}
local store = {
    readSetting = function(_, k) return settings[k] end,
    saveSetting = function(_, k, v) settings[k] = v end,
    isTrue = function(_, k) return settings[k] == true end,
}
local cfg = read("infra/sui_config.lua")
local Config = {}
run(section(cfg, "local function _resolveOptions", "function M.makeLabelToggleItem"),
    { M = Config, SUISettings = store, _ = identity })

H.test("radio rows are lazy and nested sources never write a group value", function()
    local scans, writes, refreshes = 0, 0, 0
    local value = "bookorbit_want"
    local row = Config.makeRadioSubmenuItem{
        text = "Source", current_label = function() return value end,
        options = function()
            scans = scans + 1
            return {
                { value = "bookorbit_want", label = "BookOrbit" },
                { value = "recent", label = "Recent" },
                { label = "Collections", selected = function(v) return v == "collection:A" end,
                    sub_item_table_func = function() return { { text = "A" } } end },
            }
        end,
        get = function() return value end,
        set = function(v) value = v; writes = writes + 1 end,
        refresh = function() refreshes = refreshes + 1 end,
    }
    H.eq(row.text_func(), "Source"); H.eq(row.value_func(), "bookorbit_want")
    H.eq(row.mandatory_func(), "bookorbit_want"); H.eq(scans, 0)
    local items = row.sub_item_table_func()
    H.eq(scans, 1); H.eq(items[1].checked_func(), true)
    H.eq(items[3].callback, nil); H.eq(items[3].sub_item_table_func()[1].text, "A")
    H.eq(writes, 0)
    items[2].callback(); H.eq(value, "recent"); H.eq(refreshes, 1)
    items[1].callback(); H.eq(value, "bookorbit_want"); H.eq(writes, 2)
    value = "collection:A"; H.eq(items[3].checked_func(), true)
    H.eq(items[1].checked_func(), false)
    local empty = Config.appendRadioItems({}, { options = {}, empty_text = "Empty" })
    H.eq(empty[1].enabled, false)
end)

H.test("alignment menus preserve instance keys and invalid choices without writing on read", function()
    settings = { custom_align = "old" }
    H.eq(Config.getAlignment("custom_align"), "center")
    H.eq(settings.custom_align, "old")
    local refreshed = 0
    local row = Config.makeAlignmentItem{
        key = "custom_align", values = { "left", "right", "justify" }, default = "left",
        refresh = function() refreshed = refreshed + 1 end, _lc = identity,
    }
    H.eq(row.value_func(), "Left")
    row.sub_item_table_func()[3].callback()
    H.eq(settings.custom_align, "justify"); H.eq(refreshed, 1)
    H.eq(row.value_func(), "Justified")
    H.eq(settings.simpleui_hs_align, nil)
end)

H.test("BookOrbit source and unsaved native collections survive the new menu helper", function()
    local src = read("modules/module_coverdeck.lua")
    local source = "bookorbit_want"
    local row = run(section(src, "    local fixed_sources =", "    -- True if any key") ..
        "\nreturn source_item", {
            Config = Config, _lc = identity, refresh = noop, pfx = "custom_",
            SETTING_SOURCE = "source", COLLECTION_PREFIX = "collection:",
            getSource = function() return source end,
            collectionNameOf = function(v) return v:match("^collection:(.*)") end,
            SUISettings = { saveSetting = function(_, k, v)
                H.eq(k, "custom_source"); source = v
            end },
            require = function(name)
                H.eq(name, "readcollection")
                return { coll = { favorites = {}, A = {} }, coll_folders = { B = {} },
                    _read = function() error("would discard unsaved changes") end }
            end,
            package = { loaded = {} },
        })
    H.eq(row.value_func(), "BookOrbit Want to Read")
    local items = row.sub_item_table_func()
    H.eq(items[3].checked_func(), true)
    local nested = items[5].sub_item_table_func()
    H.eq(#nested, 2); H.eq(nested[1].text, "A"); H.eq(nested[2].text, "B")
    nested[2].callback(); H.eq(source, "collection:B"); H.eq(row.value_func(), "B")
    items[3].callback(); H.eq(source, "bookorbit_want")
end)

H.test("wallpaper, cover shadow and currently-reading defaults remain opt-in and unchanged", function()
    local WP = {}
    run(section(read("features/sui_wallpaper.lua"), "M.BACKDROP_DEFAULT =", "local KEY_STATUSBAR"), { M = WP })
    H.eq(WP.BACKDROP_DEFAULT.pagination, 0); H.eq(WP.BACKDROP_DEFAULT.titlebar, 0)
    H.eq(WP.BACKDROP_DEFAULT.cover_strip, 0)
    local active = true
    WP.isWallpaperActive = function() return active end
    WP.readBackdropStrength = function(k, default) return settings[k] or default end
    WP.saveBackdropStrength = function(k, v) settings[k] = v end
    run(section(read("features/sui_wallpaper.lua"), "function M.getCoverStripBackdropStrength", "-- Module backdrop"),
        { M = WP, KEY_COVER_STRIP = "strip", _BACKDROP_MAX = 100 })
    settings = {}; H.eq(WP.getCoverStripBackdropStrength(), 0)
    WP.setCoverStripBackdropStrength(35); H.eq(WP.getCoverStripBackdropStrength(), 35)
    active = false; H.eq(WP.getCoverStripBackdropStrength(), 100); H.eq(settings.strip, 35)
    local style = {}
    run(section(read("features/sui_style.lua"), "local _COVER_SHADOW_KEY_PREFIX", "-- Folder book stack style"),
        { M = style, SUISettings = store, Screen = { scaleBySize = function(_, n) return n end } })
    H.eq(style.coverShadowOffset("currently"), 0)
    settings.simpleui_style_cover_shadow_currently = true
    H.eq(style.coverShadowOffset("currently"), 4)
    local currently = read("modules/module_currently.lua")
    local align, stats = run(section(currently, "local DESC_ALIGN_KEY", "-- Setting key for progress bar") ..
        section(currently, 'local STATS_STYLE_KEY', 'local COVER_GAP_KEY') ..
        "\nreturn resolveDescAlign, getStatsStyle", { Config = Config, SUISettings = store })
    H.eq(align(nil), "left"); H.eq(align("justify"), "justify")
    H.eq(stats("custom_"), "default")
    settings.custom_currently_stats_style = "compact"; H.eq(stats("custom_"), "compact")
end)

H.test("placeholder teardown restores its owned upvalue without clobbering later patches", function()
    local native, replacement = {}, {}
    local FakeCover = native
    local item = { update = function() return FakeCover end }
    local owner = item.update
    local M = {}
    local patch = { getUpValue = function(fn, target)
        for i = 1, 20 do
            local name, v = debug.getupvalue(fn, i)
            if name == target then return v, i end
        end
    end }
    run(section(read("features/library/sui_foldercovers.lua"), "local function _nativeUpdate", "function M.install()"), {
        M = M, _getMosaicMenuItemAndPatch = function() return item, patch end,
        _placeholderClass = function() return replacement end,
    })
    M.installPlaceholder(); M.installPlaceholder(); H.eq(item.update(), replacement)
    local wrapped = function() return owner() end
    item.update = wrapped
    M.uninstallPlaceholder(); H.eq(item.update, wrapped); H.eq(item.update(), native)
    item.update = owner; M.installPlaceholder()
    local external = {}; FakeCover = external
    M.uninstallPlaceholder(); H.eq(item.update(), external)
    H.eq(item._simpleui_placeholder_update, nil); H.eq(item._simpleui_placeholder_class, nil)
    M.uninstallPlaceholder(); H.eq(item.update(), external)
end)

H.test("shadow masks are reused, bounded and freed exactly once with collision-free dimensions", function()
    local live, allocated = 0, 0
    local BB = { TYPE_BB8 = 1, Color8 = identity, COLOR_BLACK = 0, COLOR_WHITE = 255 }
    BB.new = function(w, h)
        live = live + 1; allocated = allocated + 1
        return { w = w, h = h, fill = noop, paintRect = noop,
            free = function(self) assert(not self.freed); self.freed = true; live = live - 1 end }
    end
    local CW, screen = {}, { night_mode = false }
    run(section(read("features/library/sui_cover_widgets.lua"), "local _shadow_masks", "local ShadowWidget"), {
        CoverWidgets = CW, Blitbuffer = BB, Screen = screen, _SHADOW_MIN_STRENGTH = 0,
        shadowBandStrength = function() return .2 end,
    })
    local calls = {}
    local bb = { colorblitFromRGB32 = function(_, mask, _, _, _, _, w, h, color)
        assert(not mask.freed); H.eq(w, mask.w); H.eq(h, mask.h); calls[#calls + 1] = color
    end }
    CW.paintShadow(bb, 0, 0, 10, 20, 4)
    CW.paintShadow(bb, 0, 0, 10, 20, 4); H.eq(allocated, 2)
    screen.night_mode = true; CW.paintShadow(bb, 0, 0, 10, 20, 4)
    H.eq(allocated, 2); H.eq(calls[#calls], 255)
    -- These tuples collided with the upstream arithmetic key.
    CW.paintShadow(bb, 0, 0, 10, 4116, 4)
    CW.paintShadow(bb, 0, 0, 11, 20, 4)
    for i = 1, 150 do CW.paintShadow(bb, 0, 0, 100 + i, 300, 4); assert(live <= 128) end
    CW.clearShadowCache(); H.eq(live, 0)
    CW.clearShadowCache(); H.eq(live, 0)
end)

H.test("generated side covers crop the full cover and transfer only the slice buffer", function()
    local buffers, covers = {}, {}
    local widget = { new = function(_, props) return props end }
    local BB = { TYPE_BBRGB32 = 1, COLOR_WHITE = 255 }
    BB.new = function(w, h)
        local b = { w = w, h = h, fill = noop,
            free = function(self) assert(not self.freed); self.freed = true end,
            blitFrom = function(self, src, _, _, sx, sy, sw, sh)
                assert(not src.freed); H.eq(sw, self.w); H.eq(sh, self.h)
                assert(sx + sw <= src.w and sy + sh <= src.h); self.sx = sx
            end }
        buffers[#buffers + 1] = b; return b
    end
    local Placeholder = run(read("engines/sui_cover_placeholder.lua"), { require = function(name)
        if name == "ffi/blitbuffer" then return BB end
        if name == "infra/sui_i18n" then return { translate = identity } end
        return widget
    end })
    local w, h = Placeholder.fitSize(80, 90); H.eq(w, 60); H.eq(h, 90)
    w, h = Placeholder.fitSize(40, 90); H.eq(w, 40); H.eq(h, 60)
    Placeholder.build = function(cw, ch)
        local cover = { w = cw, h = ch, paintTo = noop,
            free = function(self) self.freed = true end }
        covers[#covers + 1] = cover; return cover
    end
    for _, side in ipairs({ "left", "right" }) do
        local out = Placeholder.buildCropped(20, 90, "Title", "Author", side)
        H.eq(out.image.sx, side == "left" and 0 or 40)
        H.eq(out.image_disposable, true); H.eq(out.image.freed, nil)
        H.eq(covers[#covers].freed, true); H.eq(buffers[#buffers - 1].freed, true)
        out.image:free()
    end
    local count = #buffers
    local full = Placeholder.buildCropped(60, 90, nil, nil, "left")
    H.eq(full.w, 60); H.eq(#buffers, count)
end)

H.finish()
