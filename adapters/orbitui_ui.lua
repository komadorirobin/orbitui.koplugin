-- Explicit integration points. Module wrappers run after the original module
-- has loaded; package.preload userpatches still have priority in the resolver.
local M = {}
M.modules = {
    ["infra/sui_config"] = true,
    ["lib/bookshelf_profiles"] = true,
    ["features/sui_quickactions"] = true,
    ["sui_bookshelf_bridge"] = true,
    ["features/library/sui_book_hold_dialog"] = true,
    ["features/library/sui_library_search"] = true,
    ["lib/bookshelf_widget"] = true,
    ["lib/bookshelf_spine_widget"] = true,
    ["lib/bookshelf_spine_shelf"] = true,
    ["lib/bookshelf_series_boxes"] = true,
    ["lib/bookshelf_series_box_widget"] = true,
    ["lib/bookshelf_settings"] = true,
    ["lib/bookshelf_chip_editor"] = true,
    ["lib/bookshelf_module_layout"] = true,
    ["lib/bookshelf_book_repository"] = true,
    ["lib/bookshelf_sort_engine"] = true,
    ["lib/bookshelf_theme_pack"] = true,
    ["lib/bookshelf_theme_menu"] = true,
    ["modules/moduleregistry"] = true,
    ["integrations/sui_bookorbit_want"] = true,
    ["features/sui_module_chrome"] = true,
    ["screens/sui_menu"] = true,
    ["screens/sui_bottombar"] = true,
    ["screens/sui_settings_window"] = true,
    ["lib/bookshelf_i18n"] = true,
    ["infra/sui_patches"] = true,
    ["infra/sui_cover_cache"] = true,
    ["lib/bookshelf_scaled_cover_cache"] = true,
    ["lib/bookshelf_page_wipe"] = true,
    ["engines/sui_screen_engine"] = true,
}

local function settingsEntry(items, old_key)
    items[old_key] = nil
    items.orbitui_settings = {
        text = require("core/orbitui_i18n")("OrbitUI settings"), sorting_hint = "tools",
        callback = function() require("adapters/orbitui_settings").show() end,
    }
end

function M.wrap(name, module)
    if name == "infra/sui_cover_cache" then
        require("core/orbitui_host").performanceCache(module, "home")
    elseif name == "lib/bookshelf_scaled_cover_cache" then
        require("core/orbitui_host").performanceCache(module, "shelf")
    elseif name == "engines/sui_screen_engine" then
        require("core/orbitui_host").timeMethod(module, "_open", "home")
        require("core/orbitui_host").timeMethod(module, "openBook", "open")
    elseif name == "lib/bookshelf_page_wipe" then
        local resolve = module.resolveSteps
        module.resolveSteps = function(...)
            if require("core/orbitui_host").performanceMode() == "responsive" then return nil end
            return resolve(...)
        end
    elseif name == "infra/sui_config" then
        require("adapters/orbitui_navbar").config(module)
    elseif name == "lib/bookshelf_profiles" then
        require("adapters/orbitui_libraries").profiles(module)
    elseif name == "features/sui_quickactions" then
        require("adapters/orbitui_libraries").actions(module)
    elseif name == "sui_bookshelf_bridge" then
        require("adapters/orbitui_libraries").bridge(module)
    elseif name == "infra/sui_patches" then
        -- Both embedded plugins used to replace this callback independently,
        -- before KOReader recreated it on the first menu build.
        module.wireReaderMenuFMTab = function(_plugin, reader)
            require("adapters/orbitui_libraries").wireReaderMenu(reader)
        end
        module.isNavigationDestination = function(widget)
            return widget and (widget.name == "bookshelf" or widget.name == "homescreen"
                or widget.name == "ReaderUI")
        end
    elseif name == "features/library/sui_book_hold_dialog" then
        local show = module.show
        module.show = function(file, opts)
            if opts and opts.file_chooser then return show(file, opts) end
            return require("adapters/orbitui_book_panel").show(file, opts)
        end
    elseif name == "features/library/sui_library_search" then
        module.show = function(opts) return require("core/orbitui_search").show(opts) end
    elseif name == "lib/bookshelf_widget" then
        local launch = module._launchReader
        if launch then
            module._launchReader = function(self, file, ...)
                self._orbitui_reader_file = file
                return launch(self, file, ...)
            end
        end
        require("adapters/orbitui_appearance").widget(module)
        require("adapters/orbitui_shelf_themes").widget(module)
        require("adapters/orbitui_cover_labels").widget(module)
        require("adapters/orbitui_shelf_sort").widget(module)
        require("adapters/orbitui_series_boxes").widget(module)
        require("adapters/orbitui_book_bindings").widget(module)
        require("adapters/orbitui_series_titles").widget(module)
        require("adapters/orbitui_navbar").widget(module)
        require("adapters/orbitui_android_covers").widget(module)
        local Host = require("core/orbitui_host")
        for key, label in pairs({ _rebuild = "shelf", _paginateNext = "next", _paginatePrev = "previous",
                _launchReader = "open" }) do Host.timeMethod(module, key, label) end
        for _, key in ipairs({ "_schedulePreload", "_queueWarmForVisible" }) do
            local original = module[key]
            if original then module[key] = function(self, ...)
                if Host.allowSpeculation() then return original(self, ...) end
            end end
        end
        module.orbitui_shelf_menu = function(self, chip)
            return require("adapters/orbitui_home_shelves").shelfMenu(self, chip)
        end
        module.orbitui_hero_menu = function(self, book)
            return require("adapters/orbitui_settings").heroMenu(self, book)
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
    elseif name == "lib/bookshelf_i18n" then
        local translate = module.gettext
        module.gettext = function(text)
            local native = translate(text)
            if native ~= text then return native end
            return require("core/orbitui_i18n")(text)
        end
    elseif name == "screens/sui_settings_window" then
        module.orbitui_settings_titles = function(titles, state)
            require("adapters/orbitui_settings").homeTitles(titles, state)
        end
    elseif name == "lib/bookshelf_spine_widget" then
        require("adapters/orbitui_cover_labels").cover(module)
    elseif name == "lib/bookshelf_spine_shelf" then
        require("adapters/orbitui_book_bindings").renderer(module)
    elseif name == "lib/bookshelf_series_boxes" then
        module.SLIPCASE_MIN_SHARE = 0.85
        module.SLIPCASE_COMPACT_HEADS = true
        require("adapters/orbitui_series_boxes").geometry(module)
        require("adapters/orbitui_series_titles").geometry(module)
    elseif name == "lib/bookshelf_series_box_widget" then
        module.preserve_cover_aspect = true
        require("adapters/orbitui_series_rating").widget(module)
        require("adapters/orbitui_series_titles").boxWidget(module)
    elseif name == "lib/bookshelf_settings" then
        require("adapters/orbitui_cover_labels").settings(module)
    elseif name == "lib/bookshelf_chip_editor" then
        require("adapters/orbitui_appearance").editor(module)
        module.cover_text_external = true
        -- The host owns profile-qualified bindings, including Kanzenban.
        module.book_binding_external = true
    elseif name == "lib/bookshelf_module_layout" then
        module.preserve_legacy = true
    elseif name == "lib/bookshelf_book_repository" then
        require("adapters/orbitui_shelf_sort").repository(module)
    elseif name == "lib/bookshelf_sort_engine" then
        require("adapters/orbitui_shelf_sort").engine(module)
    elseif name == "lib/bookshelf_theme_pack" then
        require("adapters/orbitui_shelf_themes").theme(module)
    elseif name == "lib/bookshelf_theme_menu" then
        require("adapters/orbitui_shelf_themes").menu(module)
    elseif name == "modules/moduleregistry" then
        require("adapters/orbitui_home_shelves").install(module)
        require("adapters/orbitui_dashboard").install(module)
    elseif name == "integrations/sui_bookorbit_want" then
        require("adapters/orbitui_dashboard").wrapWantProvider(module)
    elseif name == "features/sui_module_chrome" then
        require("adapters/orbitui_dashboard").wrapChrome(module)
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
    require("adapters/orbitui_libraries").classes(bookshelf)
    function bookshelf:_wireFastFileBrowserTab()
        require("adapters/orbitui_libraries").wireReaderMenu(self.ui)
    end
    require("adapters/orbitui_android_covers").bookshelf(bookshelf)
    local Host = require("core/orbitui_host")
    Host.timeMethod(bookshelf, "onCloseDocument", "close")
    Host.timeMethod(bookshelf, "onOpenBookshelfProfile", "library")
    Host.timeMethod(bookshelf, "_showAfterReaderReturn", "return_shelf")
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
