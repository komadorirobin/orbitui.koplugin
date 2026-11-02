local M = {}
local navigation = 0

function M.plugin(name)
    return require("pluginloader"):getPluginInstance(name)
end

function M.notify(text)
    require("ui/uimanager"):show(require("ui/widget/infomessage"):new{ text = text })
end

function M.refresh(file)
    local shared = package.loaded["modules/module_books_shared"]
    if shared then
        shared.invalidateSidecarCache(file)
        shared.invalidateSeriesCache(file)
    end
    local engine = package.loaded["engines/sui_screen_engine"]
    if engine then engine.invalidateAllCfgAndRefresh(true) end
end

function M.openBook(file)
    navigation = navigation + 1
    -- Keep the normal ReaderUI lifecycle: profile autoexec and the external
    -- BookOrbit/undo-opening hooks see the real file, just as on Home.
    return require("engines/sui_screen_engine").openBook(file)
end

function M.withShelf(profile, action, opts)
    local plugin = M.plugin("bookshelf")
    local function unavailable()
        M.notify(require("core/orbitui_i18n")(
            "Could not open the library. Try again from the library view."))
    end
    if not plugin then unavailable(); return false end
    navigation = navigation + 1
    local request = navigation
    if plugin:onOpenBookshelfProfile(profile) == false then unavailable(); return false end
    local UIManager = require("ui/uimanager")
    local attempts = 0
    local function ready()
        if request ~= navigation or (opts and opts.is_current and not opts.is_current()) then return end
        -- A parked reader can replace its plugin during the transition.
        local current = M.plugin("bookshelf")
        local widget = current and current._widget
        if widget and not widget._closed and UIManager:isWidgetShown(widget) then
            -- Hot reader parking may restore a different profile. Switch the
            -- visible shelf explicitly, including nil for the unscoped library.
            if widget.profile_key ~= profile then widget:setProfile(profile, opts and opts.defer_profile) end
            action(widget)
            return
        end
        attempts = attempts + 1
        if attempts < 20 then
            UIManager:scheduleIn(0.05, ready)
        else
            unavailable()
        end
    end
    UIManager:nextTick(ready)
    return true
end

-- A reveal is not a tap: native _previewBook opens an already-previewed book
-- on its second call. Set the preview explicitly, without any ReaderUI action.
function M.revealBook(file)
    local fs = require("libs/libkoreader-lfs")
    local _ = require("core/orbitui_i18n")
    local function available()
        return type(file) == "string" and file:sub(1, 1) == "/"
            and fs.attributes(file, "mode") == "file"
    end
    if not available() then M.notify(_("This book is no longer on the device.")); return false end
    local Profiles = require("lib/bookshelf_profiles")
    local profile = Profiles.matchFile(file)
    return M.withShelf(profile, function(widget)
        local reader = package.loaded["apps/reader/readerui"]
        local park = package.loaded["lib/bookshelf_reader_park"]
        if reader and reader.instance and not (park and park.isParked()) then return end
        if not available() then M.notify(_("This book is no longer on the device.")); return end
        if Profiles.matchFile(file) ~= profile then return end
        if widget._selection then widget._selection:exitMode() end
        widget:_clearDpadFocus()
        widget._tap_selected_fp, widget._preview_book, widget._hero_book_cache = nil, nil, nil
        -- Resolve pagination at the destination's actual (collapsed) size,
        -- not the larger view that may have been open beneath the dialog.
        widget._hero_mode, widget._expanded = "current", false
        local found
        if Profiles.locationForFile(file) then
            found = widget:showFileLocation(file, true)
        else
            -- Fresh/unscoped libraries may have no folder chip. Browse the
            -- actual parent through the native listing, including its filters;
            -- never create a permanent profile/chip to display a search hit.
            local parent = file:match("^(.*)/[^/]+$")
            if parent == "" then parent = "/" end
            widget._pending_restore_drill = nil
            widget._cursor, widget.page = 1, 1
            widget._drilldown_path = {{ kind = "folder",
                label = require("lib/bookshelf_folder_label").display(parent:match("([^/]+)$") or "/"),
                payload = { path = parent }, parent_cursor = 1 }}
            local items = widget:_jumpScanList() or {}
            for i, item in ipairs(items) do
                if (item.filepath or item.fp) == file then
                    local size = widget:_viewSize()
                    widget._cursor = math.floor((i - 1) / size) * size + 1
                    widget.page = math.floor((i - 1) / size) + 1
                    found = true; break
                end
            end
        end
        if found then
            if widget:_isSpineMode() then
                -- Spine capacity is an upper bound, not a real page size.
                -- Anchor the target itself so a wide preceding spine cannot
                -- leave the selected book outside the displayed page.
                for i, item in ipairs(widget:_jumpScanList() or {}) do
                    if (item.filepath or item.fp) == file then
                        widget:_setSpineCursor(i, 0)
                        widget._spine_hist = {}
                        break
                    end
                end
            end
            widget._preview_book = widget:_hydrateBook({ filepath = file })
            widget._hero_book_cache = widget._preview_book
        end
        widget:_rebuild()
        require("ui/uimanager"):setDirty(widget, "ui")
        if not found then
            M.notify(_("Could not find this book on the shelf. Check the library folders and filters."))
        end
    end, { defer_profile = true })
end

return M
