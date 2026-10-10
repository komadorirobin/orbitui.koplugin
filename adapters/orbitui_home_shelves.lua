local M = {}
local _ = require("core/orbitui_i18n")
local Query = require("core/orbitui_shelf_query")
local Context = require("core/orbitui_context")
local KEY = "simpleui_orbitui_home_shelves"

local function store() return require("infra/sui_store") end
local function layoutService() return require("screens/sui_settings_window").LayoutService end
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end

function M.list()
    return copy(store():readSetting(KEY) or {})
end

local function modeFor(id)
    for _i, pin in ipairs(M.list()) do if pin.id == id then return pin.mode end end
end

local function title(pin)
    local query = Query.resolve(pin.ref)
    return query and query.label or pin.label or _("This shelf is no longer available.")
end

function M.open(pin)
    if not Query.resolve(pin.ref) then
        Context.notify(_("This shelf is no longer available."))
        return
    end
    Context.withShelf(pin.ref.profile, function(shelf) shelf:_selectChip(pin.ref.chip) end)
end

function M.module(pin)
    local id = pin.id
    local function files()
        local ok, paths, err = pcall(Query.paths, pin.ref)
        if not ok then require("logger").warn("OrbitUI Home shelf:", paths) end
        return ok and not err and paths or {}
    end
    local function menu()
        return {
            { text = _("Open shelf"), callback = function() M.open(pin) end },
            { text = _("Book row"), checked_func = function() return modeFor(id) == "row" end,
                callback = function() M.pin(pin.ref, "row") end },
            { text = _("Cover carousel"), checked_func = function() return modeFor(id) == "carousel" end,
                callback = function() M.pin(pin.ref, "carousel") end },
            { text = _("Remove from Home"), callback = function() M.remove(id) end },
        }
    end
    local module = require("engines/sui_book_grid").makeModule{
        id = id, name = title(pin), label = title(pin), label_fn = function() return title(pin) end,
        default_on = false, is_book_mod = true, paged = true, grid = true,
        default_rows = 1, default_cols = 5,
        getFileList = files,
        progress_style = { default = "none" },
        badges = { pages = "off", series = "off", new = "locked_off" },
        extra_menu_items_before = menu,
    }
    local grid_build = module.build
    local function empty(w, ctx)
        return require("ui/widget/textboxwidget"):new{
            text = _(Query.resolve(pin.ref) and "This shelf has no books."
                or "This shelf is no longer available."),
            width = w, face = require("ui/font"):getFace("cfont", 16),
            alignment = "center",
        }
    end
    if pin.mode == "carousel" then
        local Deck = require("modules/module_coverdeck")
        -- A private context and setting prefix per shelf: neither swiping nor
        -- styling one carousel can change the existing Want to Read carousel.
        local function deckContext(ctx)
            local key = "_orbitui_deck_" .. id
            local dc = ctx[key]
            if not dc then dc = {}; ctx[key] = dc end
            for k, v in pairs(ctx) do
                if not (type(k) == "string" and k:match("^_orbitui_deck_")) then dc[k] = v end
            end
            dc.pfx, dc.cfg = "simpleui_orbitui_" .. id .. "_", nil
            dc.coverdeck_cur_idx = dc._orbitui_index or 1
            dc.coverdeck_center_stats = nil
            dc.orbitui_module_id = id
            dc.orbitui_files = files
            dc.orbitui_set_index = function(index)
                dc._orbitui_index, dc.coverdeck_cur_idx = index, index
                local screen = ctx._screen_widget
                if screen then
                    if not screen:_refreshBookModSlot(id) then screen:_refreshImmediate(true) end
                end
            end
            return dc
        end
        module.build = function(w, ctx)
            require("infra/sui_config").applyLabelToggle(module, title(pin))
            if #files() == 0 then return empty(w, ctx) end
            return Deck.build(w, deckContext(ctx))
        end
        module.getHeight = function(ctx) return Deck.getHeight(deckContext(ctx)) end
        module.updateCovers = function(widget, ctx) return Deck.updateCovers(widget, deckContext(ctx)) end
        -- No updateStats shortcut: the shelf's membership may have changed.
        module.updateStats = nil
        module.getMenuItems = function(ctx)
            local items = menu()
            local dc = {}
            for k, v in pairs(ctx) do dc[k] = v end
            dc.pfx = "simpleui_orbitui_" .. id .. "_"
            -- The shelf owns membership. Do not expose the deck's own source
            -- picker (or its singleton label toggle) for these instances.
            items[#items + 1] = require("infra/sui_config").makeCoverHoldModeItem{
                mod_id = "coverdeck", pfx = dc.pfx, refresh = ctx.refresh, _lc = ctx._,
            }
            return items
        end
    else
        module.build = function(w, ctx)
            return grid_build(w, ctx) or empty(w, ctx)
        end
    end
    return module
end

function M.install(registry)
    for _i, pin in ipairs(M.list()) do
        registry.register(M.module(pin))
    end
end

function M.pin(ref, mode)
    assert(mode == "row" or mode == "carousel", "Unknown Home shelf layout")
    local query, err = Query.resolve(ref)
    if not query then return nil, err end
    local pins = M.list()
    local pin
    for _i, candidate in ipairs(pins) do
        if candidate.ref.profile == ref.profile and candidate.ref.chip == ref.chip then pin = candidate end
    end
    local existing = pin ~= nil
    local layout = copy(layoutService().load())
    if not pin then
        local number = (tonumber(store():readSetting(KEY .. "_next_id")) or 0) + 1
        store():saveSetting(KEY .. "_next_id", number)
        pin = { id = "orbitui_shelf_" .. number, ref = { profile = ref.profile, chip = ref.chip } }
        pins[#pins + 1] = pin
    end
    pin.label, pin.mode = query.label, mode
    store():saveSetting(KEY, pins)
    require("modules/moduleregistry").register(M.module(pin))
    local placed = false
    for _i, page in ipairs(layout.pages) do
        for _j, entry in ipairs(page.modules or {}) do
            if layoutService().entryId(entry) == pin.id then placed = true end
        end
    end
    if not placed then
        layout.pages[#layout.pages + 1] = { id = pin.id, modules = { pin.id } }
    end
    layoutService().save(layout)
    Context.refresh()
    return pin, existing and placed
end

function M.remove(id)
    local pins, kept = M.list(), {}
    for _i, pin in ipairs(pins) do if pin.id ~= id then kept[#kept + 1] = pin end end
    if #kept == #pins then return false end
    local layout = copy(layoutService().load())
    for _i, page in ipairs(layout.pages) do
        for i = #(page.modules or {}), 1, -1 do
            if layoutService().entryId(page.modules[i]) == id then table.remove(page.modules, i) end
        end
    end
    -- Remove only the empty page created by this pin, never a user's own page.
    for i = #layout.pages, 1, -1 do
        if layout.pages[i].id == id and #layout.pages[i].modules == 0 and #layout.pages > 1 then
            table.remove(layout.pages, i)
        end
    end
    -- A user may also have placed this module on a Custom Screen. Removing
    -- it from Home must not break that screen or erase its configuration.
    local elsewhere = false
    for _i, screen in ipairs(require("infra/sui_custom_screens").list()) do
        local other = store():readSetting(screen.layout_key) or {}
        for _j, page in ipairs(other.pages or {}) do
            for _k, entry in ipairs(page.modules or {}) do
                if layoutService().entryId(entry) == id then elsewhere = true end
            end
        end
    end
    store():saveSetting(KEY, elsewhere and pins or kept)
    store():saveSetting("simpleui_hs_" .. id .. "_enabled", false)
    if not elsewhere then require("modules/moduleregistry").unregister(id) end
    layoutService().save(layout)
    Context.refresh()
    return true
end

function M.choose(ref)
    local query, err = Query.resolve(ref)
    if not query then
        Context.notify(_(err == "remote" and "Remote catalogs cannot be added as local Home shelves."
            or "This shelf is no longer available."))
        return
    end
    local dialog
    local UIManager = require("ui/uimanager")
    local function save(mode)
        UIManager:close(dialog)
        local pin, existing = M.pin(ref, mode)
        if pin then Context.notify(_(existing and "Shelf updated on Home."
            or "Added on a new Home page. Move it using Home layout settings.")) end
    end
    dialog = require("ui/widget/buttondialog"):new{
        title = _("Show this shelf on Home") .. "\n" .. query.label,
        buttons = {
            {{ text = _("Book row"), callback = function() save("row") end },
             { text = _("Cover carousel"), callback = function() save("carousel") end }},
            {{ text = _("Cancel"), callback = function() UIManager:close(dialog) end }},
        },
    }
    UIManager:show(dialog)
end

function M.shelfMenu(widget, chip)
    local ref = Query.capture(widget, chip)
    local dialog
    local UIManager = require("ui/uimanager")
    local function close() UIManager:close(dialog) end
    dialog = require("ui/widget/buttondialog"):new{
        title = (Query.resolve(ref) or {}).label or chip,
        buttons = {
            {{ text = _("Show this shelf on Home"), callback = function() close(); M.choose(ref) end }},
            {{ text = _("Cover text"), callback = function()
                close()
                require("adapters/orbitui_cover_labels").show(widget, chip)
            end }},
            {{ text = _("Edit shelf"), callback = function()
                close()
                if widget.profile then widget:_showProfileShelfStyle(chip)
                else
                    if widget.chip ~= chip then widget:_selectChip(chip) end
                    require("lib/bookshelf_chip_editor"):editTab(chip, {
                        bw = widget, on_change = function() widget:_afterChipEdit() end,
                    })
                end
            end }},
            {{ text = _("Close"), callback = close }},
        },
    }
    UIManager:show(dialog)
end

function M.menuItems()
    local rows = {}
    for _i, pin in ipairs(M.list()) do
        rows[#rows + 1] = { text = title(pin), sub_item_table = {
            { text = _("Open shelf"), callback = function() M.open(pin) end },
            { text = _("Book row"), checked_func = function() return modeFor(pin.id) == "row" end,
                callback = function() M.pin(pin.ref, "row") end },
            { text = _("Cover carousel"), checked_func = function() return modeFor(pin.id) == "carousel" end,
                callback = function() M.pin(pin.ref, "carousel") end },
            { text = _("Remove from Home"), callback = function() M.remove(pin.id) end },
        } }
    end
    if #rows == 0 then rows[1] = { text = _("No shelves added yet. Long-press a library shelf to add it."), enabled = false } end
    return rows
end

return M
