local Model = require("core/orbitui_appearance")
local _ = require("core/orbitui_i18n")
local M = {}
local state

local function frameNight()
    return require("device").screen.night_mode == true
end

-- Android's C blitter ignores the inverse flag for rectangles, but its Lua
-- corner painter does not. Suppress it for the WHOLE paint, restoring even
-- after errors. Software-only and hardware-inverting targets keep native rules.
function M.withFrameInverse(bb, paint)
    local Device, BB = require("device"), require("ffi/blitbuffer")
    local suppress = Device.isAndroid and Device:isAndroid()
        and bb.getInverse and bb.setInverse and bb:getInverse() == 1
        and (not BB.getUseCBB or BB:getUseCBB())
    if not suppress then return paint() end
    bb:setInverse(0)
    local ok, result = pcall(paint)
    bb:setInverse(1)
    if not ok then error(result, 0) end
    return result
end

function M.paintNightBackdrop(bb, x, y, w, h, dark)
    local strength, tone = Model.nightBackdrop(dark, frameNight())
    if not strength then return end
    local BB = require("ffi/blitbuffer")
    return M.withFrameInverse(bb, function()
        -- Reuse the native C/LUT scrim paths, never a new per-pixel Lua loop
        -- or a retained full-screen bitmap. This touches only the destination.
        return require("lib/bookshelf_wallpaper").scrim(bb, x, y, w, h,
            tone == 255 and BB.COLOR_WHITE or BB.COLOR_BLACK, strength)
    end)
end

function M.wallpaper(module, shelf)
    -- The dock follows KOReader, not a shelf's independently pinned Light
    -- look. Resolve native tone/ink together; do not mutate its shared surface.
    if not shelf and module.resolveBar and module.barSurface then
        local resolve = module.resolveBar
        module.resolveBar = function(kind)
            local surface = resolve(kind)
            if kind == "navbar" and frameNight() and surface.strength < Model.NIGHT_NAVBAR then
                return require("infra/sui_backdrop").resolve(module.barSurface(kind), Model.NIGHT_NAVBAR)
            end
            return surface
        end
    end
    local function dark()
        if shelf then return require("lib/bookshelf_cover_progress").theme() end
        return frameNight()
    end
    local previous, previous_key = module.orbituiBackdrop, module.orbituiBackdropKey
    module.orbituiBackdrop = function(bb, x, y, w, h)
        if previous then previous(bb, x, y, w, h) end
        return M.paintNightBackdrop(bb, x, y, w, h, dark())
    end
    module.orbituiBackdropKey = function()
        return (previous_key and tostring(previous_key()) or "")
            .. (dark() and ":orbitui-night-82" or "")
    end
end

function M.colourPainter(module)
    local paint = module.paintRoundedRect
    module.paintRoundedRect = function(bb, x, y, w, h, color, radius)
        return M.withFrameInverse(bb, function() return paint(bb, x, y, w, h, color, radius) end)
    end
end

function M.prepare(store, fresh)
    Model.prepare(store, fresh)
    state = store
end

function M.current()
    -- Before host preflight, retain the released behavior (also used by
    -- isolated component callers). Fresh hosts bind their policy before load.
    return state and Model.validate(state:readSetting(Model.key)).preset or "classic"
end
function M.policy() return Model.preset(M.current()) end
function M.label(id) return _(Model.preset(id or M.current()).label) end

function M.editor(editor)
    editor.face_out_override = M.policy().face_out
    editor.series_boxes_external = M.policy().boxes ~= "native"
    editor.ornament_frequency_override = M.policy().hide_ornaments and 0 or nil
end

function M.refreshVisible()
    local widget = package.loaded["lib/bookshelf_widget"]
    local live = widget and widget.live
    if not (live and not live._closed and live._orbitui_navbar_pending) then return end
    local manager = require("ui/uimanager")
    if manager:getTopmostVisibleWidget() == live then live:_rebuildIfSimpleUIContextChanged() end
end

function M.changed()
    local editor = package.loaded["lib/bookshelf_chip_editor"]
    if editor then M.editor(editor) end
    local ornaments = package.loaded["lib/bookshelf_ornaments"]
    if ornaments and ornaments.invalidate then ornaments.invalidate() end
    local widget = package.loaded["lib/bookshelf_widget"]
    local live = widget and widget.live
    if live then
        live._spine_fetch_cache = nil
        -- The navbar's existing return hook rebuilds behind settings/reader
        -- dialogs only when the shelf is visible again.
        live._orbitui_navbar_pending = true
    end
    require("core/orbitui_context").refresh()
    M.refreshVisible()
end

function M.select(id)
    local value = Model.value(id)
    assert(state, "OrbitUI appearance has not been initialized")
    if id == M.current() then return true end
    local saved, err = require("core/orbitui_setup").commit({
        { store = "setup", key = Model.key, value = value },
    }, { setup = {
        read = function(key) return state:readSetting(key) end,
        write = function(key, v) return state:saveSetting(key, v) end,
        flush = function() return state:flush() end,
    } })
    if not saved then return nil, err end
    M.changed()
    return true
end

function M.items(get, choose, after_save)
    get = get or M.current
    choose = choose or function(id)
        require("ui/uimanager"):show(require("ui/widget/confirmbox"):new{
            text = M.label(id) .. "\n\n" .. _(Model.preset(id).description) .. "\n\n"
                .. _("Only the physical bookshelf changes. Home, backgrounds, icons and shelf settings are kept. Installed ornament packs are not removed; manage them in Shelf theme."),
            ok_text = _("Apply"), ok_callback = function()
                local saved, err = M.select(id)
                if not saved then
                    require("logger").warn("OrbitUI appearance save failed", err)
                    require("core/orbitui_context").notify(_("Could not save the shelf preset. Check your settings and try again."))
                elseif after_save then
                    after_save()
                end
            end,
        })
    end
    local rows = {}
    for _i, id in ipairs(Model.order) do
        local value = id
        rows[#rows + 1] = { text = M.label(value), help_text = _(Model.preset(value).description), radio = true,
            checked_func = function() return get() == value end,
            callback = function() choose(value) end }
    end
    return rows
end

function M.show()
    local host
    host = require("lib/bookshelf_menu_host").show{
        title = _("Shelf preset"),
        item_table = M.items(nil, nil, function()
            if host and not host._closed then host._shim.updateItems() end
        end),
        close_callback = M.refreshVisible,
    }
    return host
end

function M.widget(widget)
    local native = widget._spineFaceOut
    widget._spineFaceOut = function(self, ...)
        local override = M.policy().face_out
        if override ~= nil then return override end
        return native(self, ...)
    end
    -- A cached list may already contain compacted boxes. Invalidate at the
    -- consumer too, including parked widgets and next/previous-page fetches.
    -- Matched/random ornaments change row widths and deal states as well.
    local Ornaments = require("core/orbitui_author_ornaments")
    for _, name in ipairs({ "_spineCachedFetch", "_spinePageFirsts", "_rebuild" }) do
        local original = widget[name]
        if original then
            widget[name] = function(self, ...)
                local id = M.current()
                local placement = Ornaments.placementGeneration()
                if self._orbitui_appearance_seen ~= id or self._orbitui_placement_seen ~= placement then
                    self._spine_fetch_cache = nil
                    self._orbitui_appearance_seen = id
                    self._orbitui_placement_seen = placement
                end
                return original(self, ...)
            end
        end
    end
end

return M
