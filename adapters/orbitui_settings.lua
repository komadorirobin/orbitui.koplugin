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
            title = _("OrbitUI settings") .. " / " .. _(profile == "comics" and "Manga & comics" or "Library"),
            item_table = items,
        }
    end)
end

function M.items(close)
    local function navigate(fn)
        return function() if close then close() end; fn() end
    end
    return {
        { text = _("Home"), callback = navigate(function() home("home_screen_settings") end) },
        { text = _("Library"), callback = navigate(function() M.library("prose") end) },
        { text = _("Manga & comics"), callback = navigate(function() M.library("comics") end) },
        { text = _("Home shelves"), sub_item_table_func = function()
            return require("adapters/orbitui_home_shelves").menuItems()
        end },
        { text = _("Appearance"), sub_item_table = {
            { text = _("Home appearance"), callback = navigate(function() home("style_settings") end) },
            { text = _("Library appearance"), callback = navigate(function() M.library("prose", true) end) },
            { text = _("Navigation & bars"), callback = navigate(function() home("bars_settings") end) },
        } },
        { text = _("Search OrbitUI"), callback = navigate(function() require("core/orbitui_search").show() end) },
        { text = require("adapters/orbitui_updates").menuLabel,
            callback = navigate(function() require("adapters/orbitui_updates").show() end) },
        { text = _("All settings"), callback = navigate(function() home() end) },
    }
end

function M.show()
    local MenuHost = require("lib/bookshelf_menu_host")
    local host
    host = MenuHost.show{
        title = _("OrbitUI settings"),
        item_table = M.items(function() if host then MenuHost.close(host) end end),
    }
    return host
end

return M
