-- Explicit integration points. Module wrappers run after the original module
-- has loaded; package.preload userpatches still have priority in the resolver.
local M = {}
local SHELF_FACE_OUT = "all"
M.modules = {
    ["features/library/sui_book_hold_dialog"] = true,
    ["features/library/sui_library_search"] = true,
    ["lib/bookshelf_widget"] = true,
    ["lib/bookshelf_chip_editor"] = true,
    ["lib/bookshelf_book_repository"] = true,
    ["lib/bookshelf_sort_engine"] = true,
    ["modules/moduleregistry"] = true,
    ["screens/sui_menu"] = true,
    ["screens/sui_bottombar"] = true,
}

local function settingsEntry(items, old_key)
    items[old_key] = nil
    items.orbitui_settings = {
        text = require("core/orbitui_i18n")("OrbitUI settings"), sorting_hint = "tools",
        callback = function() require("adapters/orbitui_settings").show() end,
    }
end

function M.wrap(name, module)
    if name == "features/library/sui_book_hold_dialog" then
        module.show = function(file, opts) return require("adapters/orbitui_book_panel").show(file, opts) end
    elseif name == "features/library/sui_library_search" then
        module.show = function(opts) return require("core/orbitui_search").show(opts) end
    elseif name == "lib/bookshelf_widget" then
        -- Use the native face-out geometry for both render and pagination.
        -- Saved chip/profile/global choices stay intact for code rollback.
        module._spineFaceOut = function() return SHELF_FACE_OUT end
        require("adapters/orbitui_shelf_sort").widget(module)
        require("adapters/orbitui_series_boxes").widget(module)
        require("adapters/orbitui_navbar").widget(module)
        module.orbitui_shelf_menu = function(self, chip)
            return require("adapters/orbitui_home_shelves").shelfMenu(self, chip)
        end
        module.orbitui_search = function(self, text)
            return require("core/orbitui_search").show{
                ref = require("core/orbitui_shelf_query").capture(self, nil, true), query = text,
                open_book = function(file, book) self:_openBook(book or { filepath = file }) end,
            }
        end
        local commit = module._commitBookStatus
        module._commitBookStatus = function(self, book, status)
            commit(self, book, status)
            require("core/orbitui_context").refresh(book and book.filepath)
        end
    elseif name == "lib/bookshelf_chip_editor" then
        module.face_out_override = SHELF_FACE_OUT
    elseif name == "lib/bookshelf_book_repository" then
        require("adapters/orbitui_shelf_sort").repository(module)
    elseif name == "lib/bookshelf_sort_engine" then
        require("adapters/orbitui_shelf_sort").engine(module)
    elseif name == "modules/moduleregistry" then
        require("adapters/orbitui_home_shelves").install(module)
    elseif name == "screens/sui_bottombar" then
        require("adapters/orbitui_navbar").bottombar(module)
    elseif name == "screens/sui_menu" then
        return function(plugin)
            module(plugin)
            local build = plugin.addToMainMenu
            function plugin:addToMainMenu(items)
                build(self, items)
                settingsEntry(items, "simpleui")
            end
        end
    end
    return module
end

function M.classes(bookshelf, simpleui)
    local build = bookshelf.buildMenuItems
    function bookshelf:buildMenuItems(items)
        build(self, items)
        settingsEntry(items, "bookshelf_settings")
    end
    function simpleui:onSimpleUISettingsWindow()
        require("adapters/orbitui_settings").show()
        return true
    end
end

return M
