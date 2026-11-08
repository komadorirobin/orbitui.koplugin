local Model = require("core/orbitui_dashboard")
local Sources = require("adapters/orbitui_dashboard_sources")
local _ = require("core/orbitui_i18n")
local M = {}
local function dashboard() return require("adapters/orbitui_dashboard") end
local function label(key, config)
    local entry = Model.module(config, key)
    if entry then return entry.label or entry.ref end
    if key == "stats" then return _("Reading statistics") end
    if config.sources[key] then return Sources.label(config.sources[key]) end
    for _i, card in ipairs(Model.heading_cards) do if card.key == key then return _(card.label) end end
end

function M.add(entry, refresh, pfx)
    local id = Model.moduleId(entry.kind, entry.ref)
    if not id then return false end
    local current = dashboard().readConfig(pfx)
    if current.unsupported or Model.module(current, id) or #current.modules >= Model.module_limit then return false end
    return dashboard().editConfig(pfx, function(c)
        if Model.module(c, id) or #c.modules >= Model.module_limit then return end
        c.modules[#c.modules + 1] = { id = id, kind = entry.kind, ref = entry.ref,
            label = entry.label, width = 2, size = "normal" }
        c.order[#c.order + 1] = id
    end, refresh)
end

function M.moduleItems(id, refresh, pfx)
    local function edit(fn)
        return function() dashboard().editConfig(pfx, function(c)
            local entry = Model.module(c, id)
            if entry then fn(entry, c) end
        end, refresh) end
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
            callback = edit(function(_, c)
                for i = #c.modules, 1, -1 do if c.modules[i].id == id then table.remove(c.modules, i) end end
                for i = #c.order, 1, -1 do if c.order[i] == id then table.remove(c.order, i) end end
                c.hidden[id] = nil
            end) },
    }
    local entry = Model.module(dashboard().readConfig(pfx), id)
    if entry and entry.kind == "simpleui" then
        local def = Sources.resolveModule(entry)
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
                    } }}, { pfx = pfx or "simpleui_hs_" })
                end }
        end
    end
    return items
end

function M.pickerItems(refresh, pfx)
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
                                ok_callback = function() M.add(entry, refresh, pfx) end,
                            })
                        else M.add(entry, refresh, pfx) end
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
                                M.add({ kind = "action", ref = ref, label = qa.getEntry(ref).label }, refresh, pfx)
                                return
                            end
                        end
                    end)
                end }
            end
            return rows
        end }
    end
    items[#items + 1] = { text = _("Get more modules…"), callback = function()
        require("adapters/orbitui_module_store").show(pfx)
    end }
    return items
end

-- Use the existing paginated/settings shell, not an unbounded button dialog.
-- Defer Home rebuilding until the editor closes; never rebuild a buried view.
function M.show(pfx, ctx, id)
    local changed = false
    return require("screens/sui_settings_window"):show(function()
        if changed and ctx.refresh_fn then ctx.refresh_fn() end
    end, {{ id = "nested_menu", params = { title = _("Reading dashboard"), items_func = function(menu_ctx)
        local refresh = function() changed = true; menu_ctx.repaint() end
        if id == "add" then return M.pickerItems(refresh, pfx) end
        if id and Model.module(dashboard().readConfig(pfx), id) then return M.moduleItems(id, refresh, pfx) end
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
        sub_item_table_func = function() return M.pickerItems(refresh, pfx) end }
    for _i, entry in ipairs(config.modules) do
        local id = entry.id
        items[#items + 1] = { text_func = function()
            local c = dashboard().readConfig(pfx)
            local current = Model.module(c, id)
            return label(id, c) .. (current and Sources.resolveModule(current) and "" or " · " .. _("Unavailable"))
                .. (Model.visible(c, id) and "" or " (" .. _("Off") .. ")")
        end, sub_item_table_func = function() return M.moduleItems(id, refresh, pfx) end }
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
