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
    if not registry._orbitui_next_series then
        registry._orbitui_next_series = true
        -- Register a lazy descriptor, not the cover renderer or a query.
        -- Merely opening the module picker never scans a library.
        local descriptor = { id = "orbitui_next_series", name = _("Next in series"), label = _("Next in series"),
            enabled_key = "orbitui_next_series_enabled", default_on = false,
            category = "books", is_book_mod = true, has_covers = true, text_elems = { "label" } }
        for _i, method in ipairs{ "build", "getHeight", "getLabel", "getGridHeight", "getMenuItems", "updateCovers" } do
            local name = method
            descriptor[name] = function(...) return M.nextModule()[name](...) end
        end
        registry.register(descriptor)
    end
    for _i, pin in ipairs(M.list()) do
        registry.register(M.module(pin))
    end
end

-- Disposable, bounded Home snapshots. Never persist candidate paths or become
-- another reading-status owner; the native repository owns the actual choice.
local next_states, next_order, next_module, next_sleeping = {}, {}, nil, false
local NEXT_ID = "orbitui_next_series"
local function nextScope(pfx)
    local Profiles = require("lib/bookshelf_profiles")
    local selected = store():readSetting(pfx .. NEXT_ID .. "_profile")
    local roots, seen, parts = {}, {}, { tostring(selected), tostring(G_reader_settings and G_reader_settings:readSetting("home_dir")),
        tostring(require("lib/bookshelf_settings_store").read("latest_walk_depth")) }
    local function add(path)
        if type(path) == "string" and path:sub(1, 1) == "/" and path ~= "/" and not seen[path] then
            seen[path], roots[#roots + 1] = true, path
        end
    end
    local found = selected == nil
    for _i, profile in ipairs(Profiles.list()) do
        parts[#parts + 1] = profile.key
        for _j, path in ipairs(profile.roots or {}) do
            parts[#parts + 1] = #path .. ":" .. path
            if not selected or selected == profile.key then found = true; add(path) end
        end
    end
    if not selected then add(G_reader_settings and G_reader_settings:readSetting("home_dir")) end
    return found and #roots > 0 and roots or nil, table.concat(parts, "\0")
end
local function stopNext(state)
    state.running, state.job = false, nil
    if state.tick then require("ui/uimanager"):unschedule(state.tick); state.tick = nil end
    if state.cancel_walk then state.cancel_walk(); state.cancel_walk = nil end
    if state.metadata then state.metadata.cancel(); state.metadata = nil end
    state.co = nil
end
function M.nextEvent(handler)
    if handler == "onResume" then next_sleeping = false; return end
    if handler == "onSuspend" then next_sleeping = true end
    if handler == "onSuspend" or handler == "onShowingReader" or handler == "onSetupShowReader"
            or handler == "onReaderReady" or handler == "onSetRotationMode" or handler == "onScreenResize" then
        for _pfx, state in pairs(next_states) do
            if state.running then stopNext(state); state.phase = "paused" end
        end
    end
end
function M.nextState(pfx)
    pfx = pfx or "simpleui_hs_"
    local roots, identity = nextScope(pfx)
    local Repo = require("lib/bookshelf_book_repository")
    local state = next_states[pfx]
    if not state or state.identity ~= identity or (state.generation and state.generation ~= Repo.dataGeneration()) then
        if state then stopNext(state) end
        state = { identity = identity, roots = roots, files = {}, phase = roots and "idle" or "folders" }
        next_states[pfx] = state
        for i = #next_order, 1, -1 do if next_order[i] == pfx then table.remove(next_order, i) end end
        next_order[#next_order + 1] = pfx
        while #next_order > 8 do
            local old = table.remove(next_order, 1)
            stopNext(next_states[old]); next_states[old] = nil
        end
    end
    return state
end
local function nextLive(state)
    local lease = state.lease
    if not lease or lease.disposed or next_sleeping then return false end
    if next_states[lease.pfx] ~= state then return false end
    local owner, UI = lease.owner, require("ui/uimanager")
    if not owner or owner._closed or owner._suspended or owner._parked or require("device").screen_saver_mode then return false end
    if not UI:isWidgetShown(owner) or lease.navigation ~= UI._simpleui_navigation_generation then return false end
    if lease.page ~= owner._current_page
            or lease.dashboard and lease.dashboard_page ~= owner._orbitui_dashboard_module_page then return false end
    if UI.getTopmostVisibleWidget and UI:getTopmostVisibleWidget() ~= owner then return false end
    local roots, identity = nextScope(lease.pfx)
    return roots ~= nil and identity == state.identity
        and (not state.generation or state.generation == require("lib/bookshelf_book_repository").dataGeneration())
end
local function nextRefresh(state)
    if not nextLive(state) then return end
    local ctx = state.lease.ctx
    ctx["_row_fps_" .. NEXT_ID] = nil
    if ctx.refresh_fn then ctx.refresh_fn()
    elseif state.lease.owner._refreshImmediate then state.lease.owner:_refreshImmediate(true) end
end
local function prepareNext(state)
    if state.running or state.phase ~= "idle" then return end
    local UI, Repo = require("ui/uimanager"), require("lib/bookshelf_book_repository")
    local time = require("ui/time")
    local job = {}
    local function current()
        if state.job ~= job then return false end
        if state.running and nextLive(state) then return true end
        stopNext(state); state.phase = "paused"; return false
    end
    local function failed()
        stopNext(state); state.phase = "error"; nextRefresh(state)
    end
    local function finish(files, total)
        stopNext(state); state.files, state.total, state.phase = files, total, "ready"
        nextRefresh(state)
    end
    state.running, state.phase, state.job = true, "loading", job
    state.tick = function()
        if not current() then return end
        local ok, cancel = pcall(Repo.prewarmFilepaths, state.roots, { is_alive = current,
            on_done = function()
                if not current() then return end
                state.cancel_walk = nil
                local success, paths = pcall(Repo.getAllFilepaths, { roots = state.roots })
                if not success then failed(); return end
                state.generation = Repo.dataGeneration()
                local metadata
                metadata = Query.tagSeriesSession{ current = current, inventory = function() return paths end,
                    changed = function()
                        if not current() then return end
                        if metadata.unavailable then failed(); return end
                        if not metadata.finished or state.co then return end
                        state.missing = 0
                        local count, started
                        local function checkpoint()
                            count = count + 1
                            if count >= 8 or time.to_us(time.since(started)) >= 8000 then coroutine.yield() end
                        end
                        state.co = coroutine.create(function()
                            local records = {}
                            for _i, file in ipairs(paths) do
                                local meta = metadata.metadata[file]
                                if meta and meta._tag_known then
                                    if Query.tagSeriesKey(meta, meta._tag_profile) then records[#records + 1] = meta end
                                else state.missing = state.missing + 1 end
                                checkpoint()
                            end
                            local picks, total = Repo.getNextUnreadInSeries(400, 0, { roots = state.roots }, {
                                records = records, light_only = true, checkpoint = checkpoint,
                                series_key = function(book) return Query.tagSeriesKey(book, book._tag_profile) end,
                            })
                            local files = {}; for _i, book in ipairs(picks) do files[#files + 1] = book.filepath end
                            return files, total
                        end)
                        state.tick = function()
                            if not current() then return end
                            count, started = 0, time.now()
                            local resumed, files, total = coroutine.resume(state.co)
                            if not resumed then failed()
                            elseif coroutine.status(state.co) == "dead" then finish(files, total)
                            else UI:scheduleIn(.01, state.tick) end
                        end
                        UI:scheduleIn(.01, state.tick)
                    end }
                state.metadata = metadata
                metadata.update{}; metadata.start()
            end })
        if not ok then failed() else state.cancel_walk = cancel end
    end
    UI:scheduleIn(.05, state.tick)
end

function M.nextModule()
    if next_module then return next_module end
    local function menu(ctx)
        local pfx = ctx.pfx or "simpleui_hs_"
        local function refresh()
            local state = next_states[pfx]
            if state then stopNext(state); next_states[pfx] = nil end
            if ctx.refresh then ctx.refresh() end
        end
        local choices = {{ key = false, label = _("All libraries") }}
        for _i, profile in ipairs(require("lib/bookshelf_profiles").list()) do
            choices[#choices + 1] = { key = profile.key, label = profile.label }
        end
        local rows = {}
        for _i, choice in ipairs(choices) do
            local selected = choice
            rows[#rows + 1] = { text = selected.label, checked_func = function()
                return (store():readSetting(pfx .. NEXT_ID .. "_profile") or false) == selected.key
            end, callback = function()
                store():saveSetting(pfx .. NEXT_ID .. "_profile", selected.key or nil); refresh()
            end }
        end
        local result = {
            { text = _("Refresh next volumes"), callback = refresh },
            { text = _("Library"), sub_item_table = rows },
            { text = _("About next in series"), callback = function()
                Context.notify(_("Continue a volume in progress, otherwise show the next unread local volume in a started series. Different authors and libraries stay separate. Preparation runs in small steps; no BookOrbit account or server is needed. Long-press a cover for book details."))
            end },
        }
        local state = next_states[pfx]
        if state and (state.missing or 0) > 0 then result[#result + 1] = { text = string.format(
            _("%d books have no cached metadata. Refresh library metadata for complete series results."), state.missing), dim = true } end
        if state and (state.total or 0) > 400 then result[#result + 1] = { text = _("Showing the first 400 series."), dim = true } end
        return result
    end
    local module = require("engines/sui_book_grid").makeModule{
        id = NEXT_ID, name = _("Next in series"), label = _("Next in series"), category = "books",
        default_on = false, is_book_mod = true, paged = true, grid = true, default_rows = 1, default_cols = 5,
        getFileList = function(ctx) return copy(M.nextState(ctx.pfx).files) end,
        progress_style = { default = "bar_text" }, badges = { pages = "off", series = "off", new = "locked_off" },
        extra_menu_items_before = menu,
    }
    local build = module.build
    module.updateStats = nil -- membership, not only the percentage, may change
    module.build = function(w, ctx)
        local pfx, UI = ctx.pfx or "simpleui_hs_", require("ui/uimanager")
        local state = M.nextState(pfx)
        local owner = ctx._screen_widget
        if ctx.orbitui_dashboard_hosted and owner then owner = (getmetatable(owner) or {}).__index or owner end
        local lease = { owner = owner, ctx = ctx, pfx = pfx, navigation = UI._simpleui_navigation_generation,
            page = owner and owner._current_page, dashboard = ctx.orbitui_dashboard_hosted,
            dashboard_page = owner and owner._orbitui_dashboard_module_page }
        state.lease = lease
        local child = {}; for k, value in pairs(ctx) do child[k] = value end
        child["_row_fps_" .. NEXT_ID] = nil
        local function allowed(file)
            if not nextLive(state) or state.lease ~= lease then return false end
            for _i, path in ipairs(state.files) do
                if file == path then return require("libs/libkoreader-lfs").attributes(file, "mode") == "file" end
            end
            return false
        end
        for _i, name in ipairs{ "open_fn", "hold_fn" } do
            local fn = ctx[name]
            if fn then child[name] = function(file, ...) if allowed(file) then return fn(file, ...) end end end
        end
        local widget = #state.files > 0 and build(w, child)
        if not widget then
            local messages = { idle = "Preparing next volumes… Long-press for options.", loading = "Preparing next volumes… Long-press for options.",
                paused = "Series preparation paused. Long-press and choose Refresh next volumes.",
                error = "Could not prepare series. Long-press to refresh, or check library metadata.",
                folders = "Choose library folders before using Next in series.", ready = "No started series to continue in the indexed books." }
            local height = math.max(1, module.getGridHeight(ctx))
            -- Native TextBox may grow to at least one font line. Retain the
            -- existing fixed-size clip even for very narrow/tiny cards, so
            -- a loading/error message cannot paint over the next row/dock.
            widget = require("lib/bookshelf_clip_container"):new{ w = w, h = height,
                require("ui/widget/textboxwidget"):new{ text = _(messages[state.phase]), width = w,
                    height = height, height_adjust = false, height_overflow_show_ellipsis = true,
                    face = require("ui/font"):getFace("cfont", 16), alignment = "center" } }
        end
        local free = widget.free
        widget.free = function(self, ...)
            if lease.disposed then return end
            lease.disposed = true
            if state.lease == lease then
                if state.running then stopNext(state); state.phase = "paused" end
                state.lease = nil
            end
            if free then return free(self, ...) end
        end
        if owner and not ctx.preview then prepareNext(state) end
        return widget
    end
    next_module = module
    return module
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
        title = _("Customize this shelf") .. "\n"
            .. ((Query.resolve(ref) or {}).label or chip),
        buttons = {
            {{ text = _("Show this shelf on Home"), callback = function() close(); M.choose(ref) end }},
            {{ text = _("Cover text"), callback = function()
                close()
                require("adapters/orbitui_cover_labels").show(widget, chip)
            end }},
            {{ text = _("Book binding"), callback = function()
                close()
                require("adapters/orbitui_book_bindings").showShelf(widget, chip)
            end }},
            {{ text = _("Series box title"), callback = function()
                close()
                require("adapters/orbitui_series_titles").show(widget, chip)
            end }},
            {{ text = _("Customize this shelf"), callback = function()
                close()
                if widget.profile then require("adapters/orbitui_library_settings").shelf(widget.profile.key, chip)
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
