local Model = require("core/orbitui_dashboard")
local Sources = require("adapters/orbitui_dashboard_sources")
local _ = require("core/orbitui_i18n")
local M = {}
local function dashboard() return require("adapters/orbitui_dashboard") end
local function notify(message) require("core/orbitui_context").notify(message) end
local function sourceCard(source, pfx)
    source = Model.bookOrbitSource(source)
    if not source then return end
    for _, entry in ipairs(dashboard().readConfig(pfx).modules) do
        local other = entry.kind == "bookorbit" and entry.source
        if other and other.account == source.account and other.section == source.section and other.id == source.id then
            return entry.id
        end
    end
end
local function addFromPicker(entry, refresh, pfx)
    local ok, added = pcall(function()
        if entry.kind == "bookorbit" and sourceCard(entry.source, pfx) then return "exists" end
        return M.add(entry, refresh, pfx)
    end)
    if ok and added == "exists" then
        notify(_("This source already has a card. Manage it in Cards and content."))
    elseif ok and added then
        notify(string.format(_("Card added: %s"), entry.label or entry.source and entry.source.title or entry.ref))
        return true
    else notify(_("Could not add the card. Check the card limit and reopen the menu.")) end
    return false
end
local function label(key, config)
    local entry = Model.module(config, key)
    if entry then
        if entry.kind == "bookorbit" then return (entry.label or entry.source and entry.source.title or _("Source")) .. " [BookOrbit]" end
        return entry.label or entry.ref
    end
    if key == "stats" then return _("Reading statistics") end
    if config.sources[key] then return Sources.label(config.sources[key]) end
    for _i, card in ipairs(Model.heading_cards) do if card.key == key then return _(card.label) end end
end

function M.add(entry, refresh, pfx)
    if entry.kind == "bookorbit" then
        if not Model.bookOrbitSource(entry.source) then return false end
        -- Placements are independent, even when they share a remote source.
        local c, serial = dashboard().readConfig(pfx), 1
        while Model.module(c, Model.moduleId("bookorbit", "row-" .. serial)) do serial = serial + 1 end
        entry = { kind = "bookorbit", ref = "row-" .. serial, source = entry.source,
            label = entry.label, view = entry.view }
    end
    local id = Model.moduleId(entry.kind, entry.ref)
    if not id then return false end
    local current = dashboard().readConfig(pfx)
    if current.unsupported or Model.module(current, id) or #current.modules >= Model.module_limit then return false end
    return dashboard().editConfig(pfx, function(c)
        if Model.module(c, id) or #c.modules >= Model.module_limit then return end
        c.modules[#c.modules + 1] = { id = id, kind = entry.kind, ref = entry.ref,
            label = entry.label, width = 2, size = "normal", source = entry.source, view = entry.view }
        c.order[#c.order + 1] = id
    end, refresh)
end

function M.bookOrbitSources(refresh, choose, checked)
    local Rows = require("adapters/orbitui_bookorbit_rows")
    local sources, err, at = Rows.catalog()
    local items = {
        { text = _("Refresh shelves and smartscopes"), callback = function()
            Rows.refresh(nil, { force = true, on_done = function(result)
                if refresh then refresh() end
                require("core/orbitui_context").notify(result.ok
                    and _("BookOrbit sources refreshed. Select a source below.") or Rows.message(result.error))
            end })
        end },
        { text = at and string.format(_("Saved sources: %s"), os.date("%Y-%m-%d %H:%M", at))
                or (err and Rows.message(err) or _("Refresh the source list, then select a shelf or smartscope.")), dim = true },
        { text = _("About BookOrbit cards"), callback = function()
            require("core/orbitui_context").notify(_("Only BookOrbit-linked files already on this device are shown. Smartscope rules run on the server. Results are cached; visible cards refresh in the background at most every 15 minutes. No downloads, reading-status writes or extras server patch. Books missing a BookOrbit file link are not guessed from their titles."))
        end },
    }
    local types = { libraries = "Library", collections = "Shelf", ["smart-scopes"] = "Smartscope" }
    for _i, source in ipairs(sources) do
        local selected = source
        items[#items + 1] = { text = _(types[selected.section]) .. ": " .. selected.title,
            checked_func = checked and function() return checked(selected) end or nil,
            callback = function() choose(selected) end }
    end
    return items
end

function M.moduleItems(id, refresh, pfx, navigation)
    if not Model.module(dashboard().readConfig(pfx), id) then
        return {{ text = _("Card removed."), dim = true }}
    end
    local stop = navigation and type(navigation.current) == "function" and navigation.current()
    local did_remove = false
    local function edit(fn)
        return function()
            if not Model.module(dashboard().readConfig(pfx), id) then return false end
            return dashboard().editConfig(pfx, function(c)
                local entry = Model.module(c, id)
                if entry then fn(entry, c) end
            end, refresh)
        end
    end
    local items = {
        { text = _("Show card"), checked_func = function() return Model.visible(dashboard().readConfig(pfx), id) end,
            callback = edit(function(_, c) c.hidden[id] = not c.hidden[id] or nil end) },
        { text = _("Card size"), sub_item_table_func = function()
            local choices = {}
            for _i, spec in ipairs({ { 1, "normal", "Half-width" }, { 2, "normal", "Full-width" },
                { 2, "tall", "Tall card" }, { 2, "page", "Whole page" } }) do
                local width, size, title = spec[1], spec[2], spec[3]
                choices[#choices + 1] = { text = _(title), checked_func = function()
                    local entry = Model.module(dashboard().readConfig(pfx), id)
                    return entry and entry.width == width and entry.size == size
                end, callback = edit(function(entry) entry.width, entry.size = width, size end) }
            end
            return choices
        end },
        { text = _("Remove card"), help_text = _("Removes only this dashboard card, not the plugin or its data."),
            callback = function()
                if did_remove then return end
                if stop and navigation.current() ~= stop then return end
                if not Model.module(dashboard().readConfig(pfx), id) then return end
                local ok, removed = pcall(edit(function(_, c)
                    for i = #c.modules, 1, -1 do if c.modules[i].id == id then table.remove(c.modules, i) end end
                    for i = #c.order, 1, -1 do if c.order[i] == id then table.remove(c.order, i) end end
                    c.hidden[id] = nil
                end))
                if ok and removed then
                    did_remove = true
                    if stop and navigation.current() == stop and navigation.pop then navigation.pop() end
                    notify(_("Card removed."))
                    return true
                elseif not ok then notify(_("Could not remove the card. Reopen the menu and try again.")) end
            end },
    }
    local entry = Model.module(dashboard().readConfig(pfx), id)
    if entry and entry.kind == "bookorbit" then
        local Rows = require("adapters/orbitui_bookorbit_rows")
        items[#items + 1] = { text = _("Source") .. ": " .. (entry.source and entry.source.title or _("Unavailable")),
            sub_item_table_func = function()
                return M.bookOrbitSources(refresh, function(source)
                    edit(function(e) e.source = source end)()
                end)
            end }
        items[#items + 1] = { text = _("Card title…"), callback = function()
            local UI, dialog = require("ui/uimanager")
            local current = Model.module(dashboard().readConfig(pfx), id)
            dialog = require("ui/widget/inputdialog"):new{ title = _("Card title"), input = current and current.label or "",
                description = _("Leave empty to use the BookOrbit source name. The BookOrbit label is always shown."),
                buttons = {{ { text = _("Cancel"), callback = function() UI:close(dialog) end },
                    { text = _("Save"), is_enter_default = true, callback = function()
                        local value = dialog:getInputText()
                        UI:close(dialog)
                        edit(function(e) e.label = type(value) == "string" and #value <= 512 and Model.normalizeHeading(value) or nil end)()
                    end } }} }
            UI:show(dialog); dialog:onShowKeyboard()
        end }
        items[#items + 1] = { text = _("Display"), sub_item_table_func = function()
            local choices = {}
            for _i, spec in ipairs({ { "row", "Cover row" }, { "carousel", "Carousel" } }) do
                local mode, title = spec[1], spec[2]
                choices[#choices + 1] = { text = _(title), checked_func = function()
                    local e = Model.module(dashboard().readConfig(pfx), id)
                    return e and e.view == mode
                end, callback = edit(function(e) e.view = mode end) }
            end
            return choices
        end }
        items[#items + 1] = { text = _("Refresh this BookOrbit card"), callback = function()
            local e = Model.module(dashboard().readConfig(pfx), id)
            Rows.refresh(e and e.source, { force = true, source_required = true, on_done = function(result)
                if refresh then refresh() end
                require("core/orbitui_context").notify(result.ok and _("BookOrbit card refreshed.") or Rows.message(result.error))
            end })
        end }
        items[#items + 1] = { text = Rows.caption(Rows.snapshot(entry.source)), dim = true }
    elseif entry and entry.kind == "simpleui" then
        local def = Sources.resolveModule(entry)
        if def then
            local label = require("infra/sui_config").makeLabelToggleItem(entry.ref, refresh or function() end, _)
            label.text = _("Show card heading")
            label.help_text = _("Settings are shared with this module on other Home pages.")
            items[#items + 1] = label
        end
        if def and def.getMenuItems then
            items[#items + 1] = { text = _("Module settings…"),
                help_text = _("Settings are shared with this module on other Home pages."), callback = function()
                    -- Only the module's own controls, not Home layout/chrome
                    -- saving: the dashboard owns this card's placement/size.
                    require("screens/sui_settings_window"):show(refresh, {{ id = "nested_menu", params = {
                        title = entry.label or entry.ref, items_func = function(menu_ctx)
                            local ctx = require("engines/sui_window").makeCtxMenu(menu_ctx)
                            ctx.pfx, ctx.pfx_qa = pfx or "simpleui_hs_", (pfx or "simpleui_hs_") .. "qa_"
                            local ok, rows = pcall(def.getMenuItems, ctx)
                            if ok and type(rows) == "table" then return rows end
                            return {{ text = _("Unavailable"), enabled_func = function() return false end }}
                        end,
                    } }}, { pfx = pfx or "simpleui_hs_", orbitui_back_to_parent = true })
                end }
        end
    end
    return items
end

function M.pickerItems(refresh, pfx, return_to_parent)
    if dashboard().readConfig(pfx).unsupported then
        return {{ text = _("This dashboard needs a newer OrbitUI version."), enabled_func = function() return false end }}
    end
    local items = {}
    for _i, spec in ipairs({ { "simpleui", "Home modules (SimpleUI)" },
        { "bookshelf", "Shelf modules (Bookshelf)" }, { "action", "Action shortcuts" } }) do
        local kind, title = spec[1], spec[2]
        items[#items + 1] = { text = _(title), sub_item_table_func = function()
            local rows = {}
            for _j, choice in ipairs(Sources.moduleChoices(kind)) do
                local entry = choice
                local id = Model.moduleId(kind, entry.ref)
                rows[#rows + 1] = { text = entry.label,
                    checked_func = function() return Model.module(dashboard().readConfig(pfx), id) ~= nil end,
                    enabled_func = function()
                        local c = dashboard().readConfig(pfx)
                        return not Model.module(c, id) and #c.modules < Model.module_limit
                    end,
                    callback = function()
                        if entry.network then
                            require("ui/uimanager"):show(require("ui/widget/confirmbox"):new{
                                text = _("This module uses the network. Add it to the dashboard?")
                                    .. "\n" .. table.concat(entry.network, "\n"),
                                ok_callback = function() addFromPicker(entry, refresh, pfx) end,
                            })
                        else addFromPicker(entry, refresh, pfx) end
                    end }
            end
            if #rows == 0 then rows[1] = { text = _("No compatible modules available. Enable the plugin and restart KOReader."),
                enabled_func = function() return false end } end
            if kind == "action" then
                rows[#rows + 1] = { text = _("Create shortcut…"), enabled_func = function()
                    return Sources.shortcutPlugin() ~= nil and #dashboard().readConfig(pfx).modules < Model.module_limit
                end, callback = function()
                    local plugin = Sources.shortcutPlugin()
                    if not plugin then return end
                    local qa = require("features/sui_quickactions")
                    local before = {}
                    for _, ref in ipairs(qa.getCustomQAList()) do before[ref] = true end
                    qa.showQuickActionDialog(plugin, nil, function()
                        for _, ref in ipairs(qa.getCustomQAList()) do
                            if not before[ref] then
                                addFromPicker({ kind = "action", ref = ref, label = qa.getEntry(ref).label }, refresh, pfx)
                                return
                            end
                        end
                    end)
                end }
            end
            return rows
        end }
    end
    items[#items + 1] = { text = _("BookOrbit shelves and smartscopes"), enabled_func = function()
        return #dashboard().readConfig(pfx).modules < Model.module_limit
    end, sub_item_table_func = function()
        return M.bookOrbitSources(refresh, function(source)
            addFromPicker({ kind = "bookorbit", source = source }, refresh, pfx)
        end, function(source) return sourceCard(source, pfx) ~= nil end)
    end }
    items[#items + 1] = { text = _("Get more modules…"), callback = function()
        require("adapters/orbitui_module_store").show(pfx, return_to_parent)
    end }
    return items
end

local function pickerSheet(pfx, ctx)
    local UI = require("ui/uimanager")
    local Sheets = require("lib/bookshelf_library_modal")
    local items, panel, closed, changed = M.pickerItems(nil, pfx, true), nil, false, false
    local function current()
        return not closed and (not UI.getTopmostVisibleWidget or UI:getTopmostVisibleWidget() == panel)
    end
    local function openCategory(index, title)
        local alive = true
        return require("screens/sui_settings_window"):show(function() alive = false end,
            {{ id = "nested_menu", params = { title = title, items_func = function(menu_ctx)
                local function refresh()
                    changed = true
                    if alive and menu_ctx.repaint then menu_ctx.repaint() end
                end
                local item = M.pickerItems(refresh, pfx)[index]
                return item and item.sub_item_table_func and item.sub_item_table_func()
                    or {{ text = _("Unavailable"), dim = true }}
            end } }}, { pfx = pfx or "simpleui_hs_", pfx_qa = (pfx or "simpleui_hs_") .. "qa_",
                orbitui_back_to_parent = true })
    end
    local rows, action
    if #items == 1 then
        rows = {{ title = items[1].text }}
    else
        rows = {}
        local icons = { "home", "shelves", "link", "sync" }
        for index, icon in ipairs(icons) do
            local item = items[index]
            rows[index] = { title = item.text, icon = icon,
                group = index == 1 and _("Modules on this device") or index == 4 and _("Book sources") or nil,
                action = function()
                    if current() and (not item.enabled_func or item.enabled_func()) then openCategory(index, item.text) end
                end }
        end
        local catalog = items[#items]
        action = { label = catalog.text, on_tap = function() if current() then catalog.callback() end end }
    end
    panel = Sheets.showSheet{
        title = _("Add module"), back = _("Reading dashboard"),
        on_back = function() if current() then UI:close(panel) end end,
        rows = rows, row_height = 68, action = action, action_icon = "download",
        on_closed = function()
            closed = true
            if changed and ctx.refresh_fn then ctx.refresh_fn() end
        end,
    }
    return panel
end

local function cardSheet(pfx, ctx, id, parent_open)
    local UI = require("ui/uimanager")
    local Sheets = require("lib/bookshelf_library_modal")
    local panel, changed, closed
    local function close()
        if panel and not closed then UI:close(panel) end
    end
    local function back()
        close()
        if not parent_open then M.show(pfx, ctx) end
    end
    local rows
    local function refresh()
        if closed then return end
        changed = true
        if panel and Model.module(dashboard().readConfig(pfx), id) then
            panel.config.sheet.rows = rows()
            panel.config.sheet.identity.title = label(id, dashboard().readConfig(pfx))
            panel:refresh()
        end
    end
    local function choices(item)
        return require("screens/sui_settings_window"):show(nil, {{ id = "nested_menu", params = {
            title = item.text, items_func = item.sub_item_table_func,
        } }}, { pfx = pfx or "simpleui_hs_", orbitui_back_to_parent = true })
    end
    rows = function()
        local items = M.moduleItems(id, refresh, pfx)
        local entry = Model.module(dashboard().readConfig(pfx), id)
        local out = {{ title = items[1].text, group = _("Display"),
            subtitle = _("Show this card in the reading dashboard."),
            get_checked = items[1].checked_func, action = items[1].callback }}
        local first = 4
        if entry.kind == "simpleui" and items[first] and items[first]._sui_section_label_toggle then
            local heading = items[first]
            out[#out + 1] = { title = heading.text, subtitle = _("The heading above this card."),
                get_checked = heading.checked_func, action = heading.callback }
            first = first + 1
        end
        local size = items[2]
        out[#out + 1] = { title = size.text, action = function() choices(size) end, get_subtitle = function()
            for _, option in ipairs(size.sub_item_table_func()) do if option.checked_func() then return option.text end end
        end }
        for i = first, #items do
            local item = items[i]
            out[#out + 1] = { title = item.text, group = i == first and _("Module") or nil,
                subtitle = item.help_text,
                action = item.callback or item.sub_item_table_func and function() choices(item) end }
        end
        return out
    end
    panel = Sheets.showSheet{
        title = _("Card settings"), back = _("Reading dashboard"), on_back = back,
        identity = { title = label(id, dashboard().readConfig(pfx)), icon = "menu_book",
            subtitle = (not pfx or pfx == "simpleui_hs_") and (_("Home") .. " · " .. _("Reading dashboard")) or _("Reading dashboard") },
        rows = rows(), row_height = 66, max_rows = 8,
        action_icon = "expand_more", action_disclosure = true,
        action = { label = _("Remove card…"), on_tap = function()
            local remove = M.moduleItems(id, refresh, pfx)[3]
            if not remove then return end
            UI:show(require("ui/widget/confirmbox"):new{
                text = remove.help_text, ok_text = remove.text,
                ok_callback = function() if not closed and remove.callback() then close() end end,
            })
        end },
        on_closed = function()
            closed = true
            if changed and ctx.refresh_fn then ctx.refresh_fn() end
        end,
    }
    return panel
end

-- The card overview keeps its paginated settings shell.
-- Defer Home rebuilding until the editor closes; never rebuild a buried view.
function M.show(pfx, ctx, id)
    if id == "add" then return pickerSheet(pfx, ctx) end
    if id and id ~= "add" and Model.module(dashboard().readConfig(pfx), id) then
        return cardSheet(pfx, ctx, id)
    end
    local changed, alive = false, true
    return require("screens/sui_settings_window"):show(function()
        alive = false
        if changed and ctx.refresh_fn then ctx.refresh_fn() end
    end, {{ id = "nested_menu", params = { title = _("Reading dashboard"), items_func = function(menu_ctx)
        local refresh = function() changed = true; if alive then menu_ctx.repaint() end end
        return M.items(refresh, pfx, require("engines/sui_window").makeCtxMenu(menu_ctx))
    end } }}, { pfx = pfx or "simpleui_hs_", pfx_qa = (pfx or "simpleui_hs_") .. "qa_" })
end

function M.sourceItems(key, refresh, pfx)
    local function option(source, title)
        return { text = title or Sources.label(source), checked_func = function()
            return Model.sourceKey(dashboard().readConfig(pfx).sources[key]) == Model.sourceKey(source)
        end, callback = function()
            dashboard().editConfig(pfx, function(c) c.sources[key] = source end, refresh)
        end }
    end
    local items = {}
    for _, id in ipairs({ "tbr", "new_books", "recent" }) do
        items[#items + 1] = option({ kind = "native", id = id })
    end
    items[#items + 1] = option({ kind = "bookorbit" })
    items[#items + 1] = { text = _("Collection"), sub_item_table_func = function()
        local rows = {}
        for _, name in ipairs(require("engines/sui_book_sources").listCollectionNames()) do
            rows[#rows + 1] = option({ kind = "native", id = "collection", coll = name }, name)
        end
        if #rows == 0 then rows[1] = { text = _("No collections available."), enabled_func = function() return false end } end
        return rows
    end }
    items[#items + 1] = { text = _("Library shelf"), sub_item_table_func = function()
        local rows = {}
        for _, choice in ipairs(Sources.shelves()) do rows[#rows + 1] = option(choice.source, choice.label) end
        if #rows == 0 then rows[1] = { text = _("No shelves available."), enabled_func = function() return false end } end
        return rows
    end }
    return items
end

local function arrange(field, title, refresh, pfx, ctx_menu)
    local config, items = dashboard().readConfig(pfx), {}
    for _, key in ipairs(config[field]) do items[#items + 1] = { text = label(key, config), orig_item = key } end
    local function save(ordered)
        dashboard().editConfig(pfx, function(c)
            c[field] = {}
            for _, item in ipairs(ordered or items) do c[field][#c[field] + 1] = item.orig_item end
        end, refresh)
    end
    if ctx_menu and ctx_menu.show_arrange then
        ctx_menu.show_arrange{ title = title, items = items, on_change = save }
    else
        require("ui/uimanager"):show(require("ui/widget/sortwidget"):new{
            title = title, item_table = items, covers_fullscreen = true, callback = function() save(items) end,
        })
    end
end

function M.items(refresh, pfx, ctx_menu)
    local config = dashboard().readConfig(pfx)
    if config.unsupported then
        return {{ text = _("This dashboard needs a newer OrbitUI version."), enabled_func = function() return false end }}
    end
    local items = {
        { text = _("Arrange cards"), help_text = _("Cards fill rows from left to right. Statistics move as one group."),
            callback = function() arrange("order", _("Arrange cards"), refresh, pfx, ctx_menu) end },
        { text = _("Arrange statistics"), callback = function()
            arrange("stats_order", _("Arrange statistics"), refresh, pfx, ctx_menu)
        end },
    }
    for index, card in ipairs(Model.heading_cards) do
        local key, heading_index = card.key, index
        items[#items + 1] = { text_func = function()
            local current = dashboard().readConfig(pfx)
            return Model.heading(dashboard().readHeadings(pfx), key, label(key, current))
                .. (Model.visible(current, key) and "" or " (" .. _("Off") .. ")")
        end, sub_item_table_func = function()
            local rows = {
                { text = _("Show card"), checked_func = function() return Model.visible(dashboard().readConfig(pfx), key) end,
                    callback = function() dashboard().editConfig(pfx, function(c)
                        c.hidden[key] = not c.hidden[key] or nil
                    end, refresh) end },
                dashboard().headingItems(refresh, pfx)[heading_index],
            }
            if key == "want" or key == "new" then
                rows[#rows + 1] = { text_func = function()
                    return _("Book source") .. ": " .. Sources.label(dashboard().readConfig(pfx).sources[key])
                end, sub_item_table_func = function() return M.sourceItems(key, refresh, pfx) end }
            elseif key == "goal" then
                rows[#rows + 1] = { text = _("Goal source"), sub_item_table_func = function()
                    local options = {}
                    for _i, entry in ipairs({ { "auto", "Automatic" }, { "local", "Local reading goal" }, { "hardcover", "Hardcover" } }) do
                        local id = entry[1]
                        options[#options + 1] = { text = _(entry[2]), checked_func = function()
                            return dashboard().readConfig(pfx).goal == id
                        end, callback = function() dashboard().editConfig(pfx, function(c) c.goal = id end, refresh) end }
                    end
                    return options
                end }
            end
            return rows
        end }
    end
    items[#items + 1] = { text = _("Add module…"),
        help_text = _("Choose a card supplied by an installed plugin, a Home module, or an action shortcut. Plugins stay separate. More cards use extra dashboard pages."),
        keep_menu_open = true, callback = function() pickerSheet(pfx, { refresh_fn = refresh }) end }
    for _i, entry in ipairs(config.modules) do
        local id = entry.id
        items[#items + 1] = { text_func = function()
            local c = dashboard().readConfig(pfx)
            local current = Model.module(c, id)
            if not current then return _("Card removed.") end
            local available
            if current.kind == "bookorbit" then
                local snapshot = require("adapters/orbitui_bookorbit_rows").snapshot(current.source)
                available = not snapshot.error or #snapshot.files > 0
            else available = Sources.resolveModule(current) ~= nil end
            return label(id, c) .. (available and "" or " · " .. _("Unavailable"))
                .. (Model.visible(c, id) and "" or " (" .. _("Off") .. ")")
        end, enabled_func = function() return Model.module(dashboard().readConfig(pfx), id) ~= nil end,
            keep_menu_open = true, callback = function()
                if Model.module(dashboard().readConfig(pfx), id) then
                    cardSheet(pfx, { refresh_fn = refresh }, id, true)
                end
            end }
    end
    items[#items + 1] = { text = _("Restore card layout"), callback = function()
        require("ui/uimanager"):show(require("ui/widget/confirmbox"):new{
            text = _("Show all cards in their original order? Book sources, headings and other pages are kept."),
            ok_text = _("Restore default"), ok_callback = function()
                dashboard().editConfig(pfx, function(c)
                    local defaults = Model.config()
                    c.order, c.stats_order, c.hidden = defaults.order, defaults.stats_order, {}
                end, refresh)
            end,
        })
    end }
    return items
end

return M
