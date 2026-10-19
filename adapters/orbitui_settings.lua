local M = {}
local _ = require("core/orbitui_i18n")
local Context = require("core/orbitui_context")

local function home(screen)
    return require("screens/sui_settings_window"):show(nil, screen)
end

function M.library(profile, appearance)
    Context.withShelf(profile, function(widget)
        local Settings = require("lib/bookshelf_settings")
        Settings._bw = widget
        Settings._plugin = Context.plugin("bookshelf")
        local items
        if appearance then
            items = {
                { text = _("Appearance"), sub_item_table_func = function() return Settings:_colorsSubItems() end },
                { text = _("Library appearance"), sub_item_table_func = function() return Settings:_backgroundSubItems() end },
            }
        else
            items = Settings:_settingsSubItems()
            table.insert(items, 1, { text = _("Show this shelf on Home"), callback = function()
                require("adapters/orbitui_home_shelves").choose(require("core/orbitui_shelf_query").capture(widget))
            end })
            for i = #(widget.profile and widget.profile.chips or {}), 1, -1 do
                local chip = widget.profile.chips[i]
                table.insert(items, 1, { text = chip.label, callback = function()
                    require("adapters/orbitui_home_shelves").shelfMenu(widget, chip.key)
                end })
            end
        end
        require("lib/bookshelf_menu_host").show{
            title = _("OrbitUI settings") .. " / " .. _(widget.profile and widget.profile.label or "Library"),
            item_table = items,
        }
    end)
end

function M.items(close)
    local function navigate(fn)
        return function() if close then close() end; fn() end
    end
    local items = {
        { text = _("Home"), callback = navigate(function() home("home_screen_settings") end) },
        { text = _("Reading dashboard"), sub_item_table_func = function()
            return require("adapters/orbitui_dashboard").menuItems()
        end },
        { text = _("Library sections"), sub_item_table_func = function()
            return require("adapters/orbitui_library_settings").items()
        end },
        { text = _("Home shelves"), sub_item_table_func = function()
            return require("adapters/orbitui_home_shelves").menuItems()
        end },
        { text = _("Appearance"), sub_item_table = {
            { text = _("Home appearance"), callback = navigate(function() home("style_settings") end) },
            { text = _("Library appearance"), callback = navigate(function() M.library(nil, true) end) },
            { text = _("Navigation & bars"), callback = navigate(function() home("bars_settings") end) },
            { text = _("Shelf preset"), callback = navigate(function()
                require("adapters/orbitui_appearance").show()
            end) },
        } },
        { text = _("Search OrbitUI"), callback = navigate(function() require("core/orbitui_search").show() end) },
        { text = require("adapters/orbitui_updates").menuLabel,
            callback = navigate(function() require("adapters/orbitui_updates").show() end) },
        { text = _("All settings"), callback = navigate(function() home() end) },
        { text = _("Setup guide"), callback = navigate(function() require("adapters/orbitui_setup").show() end) },
        { text = _("Optional integrations"), sub_item_table_func = function()
            return require("adapters/orbitui_integrations").items()
        end },
        { text = _("Add-ons"), sub_item_table = {
            { text = _("Ornament add-ons"), callback = navigate(function()
                require("adapters/orbitui_addons").show()
            end) },
        } },
    }
    local sections = require("lib/bookshelf_profiles").list()
    for i, section in ipairs(sections) do
        local key = section.key
        table.insert(items, 3 + i, { text = _(section.label), callback = navigate(function() M.library(key) end) })
    end
    if #sections == 0 then
        table.insert(items, 4, { text = _("Library"), callback = navigate(function() M.library(nil) end) })
    end
    return items
end

function M.show()
    local MenuHost = require("lib/bookshelf_menu_host")
    local host
    host = MenuHost.show{
        title = _("OrbitUI settings"),
        item_table = M.items(function() if host then MenuHost.close(host) end end),
        close_callback = function() require("adapters/orbitui_appearance").refreshVisible() end,
    }
    return host
end

return M
