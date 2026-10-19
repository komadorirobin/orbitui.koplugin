local Model = require("core/orbitui_dashboard")
local Sources = require("adapters/orbitui_dashboard_sources")
local _ = require("core/orbitui_i18n")
local M = {}
local function dashboard() return require("adapters/orbitui_dashboard") end
local function label(key, config)
    if key == "stats" then return _("Reading statistics") end
    if config.sources[key] then return Sources.label(config.sources[key]) end
    for _i, card in ipairs(Model.heading_cards) do if card.key == key then return _(card.label) end end
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
