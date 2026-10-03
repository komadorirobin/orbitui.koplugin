package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local shown, opened_screen, profile, refreshes, updates = nil, nil, nil, 0, 0
local widget = { profile = { chips = { { key = "fiction", label = "Fiction" } } } }
local plugin = {}
package.loaded["core/orbitui_context"] = {
    withShelf = function(key, fn) profile = key; fn(widget) end,
    plugin = function(name) H.eq(name, "bookshelf"); return plugin end,
    refresh = function() refreshes = refreshes + 1 end,
}
package.loaded["screens/sui_settings_window"] = { show = function(_, _, screen)
    opened_screen = screen or "__root__"
end }
package.loaded["lib/bookshelf_settings"] = {
    _settingsSubItems = function() return { { text = "Existing native setting" } } end,
    _colorsSubItems = function() return { { text = "Native colors" } } end,
    _backgroundSubItems = function() return { { text = "Native backgrounds" } } end,
}
package.loaded["lib/bookshelf_menu_host"] = {
    show = function(opts) shown = opts; return opts end,
    close = function(host) host.closed = true end,
}
package.loaded["adapters/orbitui_updates"] = {
    menuLabel = "Uppdatera OrbitUI", show = function() updates = updates + 1 end,
}
local search_opts, panel_args, shelf_menu, installed
package.loaded["core/orbitui_search"] = { show = function(opts) search_opts = opts or true end }
package.loaded["core/orbitui_shelf_query"] = { capture = function(w)
    return { chip = w.chip, profile = w.profile_key }
end }
package.loaded["adapters/orbitui_book_panel"] = { show = function(file, opts) panel_args = { file, opts } end }
package.loaded["adapters/orbitui_home_shelves"] = {
    shelfMenu = function(w, chip) shelf_menu = { w, chip } end,
    choose = function(ref) shelf_menu = ref end,
    install = function(registry) installed = registry end,
    menuItems = function() return {} end,
}
local Settings = require("adapters/orbitui_settings")
local Integration = require("adapters/orbitui_ui")
H.test("shared settings expose Home, Library, Manga, appearance and the sole updater", function()
    local host = Settings.show()
    H.eq(host.title, "OrbitUI settings")
    H.eq(#host.item_table, 8)
    host.item_table[1].callback()
    H.eq(host.closed, true); H.eq(opened_screen, "home_screen_settings")
    host.item_table[2].callback(); H.eq(profile, "prose")
    H.eq(shown.item_table[#shown.item_table].text, "Existing native setting")
    host.item_table[3].callback(); H.eq(profile, "comics")
    H.eq(package.loaded["lib/bookshelf_settings"]._plugin, plugin)
    host.item_table[5].sub_item_table[1].callback(); H.eq(opened_screen, "style_settings")
    host.item_table[5].sub_item_table[3].callback(); H.eq(opened_screen, "bars_settings")
    host.item_table[7].callback(); H.eq(updates, 1)
    host.item_table[8].callback(); H.eq(opened_screen, "__root__")
end)
H.test("native component settings entries converge on one shared menu key", function()
    local bs = { buildMenuItems = function(_, items)
        items.bookshelf_settings = { text = "Bookshelf settings" }
        items.bookshelf_action = { callback = function() end }
    end }
    local sui = {}
    Integration.classes(bs, sui)
    local installer = Integration.wrap("screens/sui_menu", function(class)
        function class:addToMainMenu(items) items.simpleui = { text = "Simple UI" } end
    end)
    installer(sui)
    local items = {}
    bs:buildMenuItems(items); sui:addToMainMenu(items)
    H.eq(items.bookshelf_settings, nil); H.eq(items.simpleui, nil)
    assert(items.bookshelf_action.callback)
    H.eq(items.orbitui_settings.text, "OrbitUI settings")
    items.orbitui_settings.callback(); H.eq(shown.title, "OrbitUI settings")
    sui:onSimpleUISettingsWindow(); H.eq(shown.title, "OrbitUI settings")
end)
H.test("legacy Home book-menu and search calls route to shared services", function()
    local hold = Integration.wrap("features/library/sui_book_hold_dialog", {})
    local opts = { open_settings_fn = function() end }
    hold.show("/book", opts)
    H.eq(panel_args[1], "/book"); H.eq(panel_args[2], opts)
    Integration.wrap("features/library/sui_library_search", {}).show()
    H.eq(search_opts, true)
end)
H.test("library seams retain the book-opening path and only invalidate after the native status write", function()
    local commits, opened = 0
    local bs = Integration.wrap("lib/bookshelf_widget", {
        _commitBookStatus = function(_, book, status)
            H.eq(book.filepath, "/book"); H.eq(status, "complete"); commits = commits + 1
        end,
        _openBook = function(_, book) opened = book.filepath end,
        chip = "next", profile_key = "comics",
    })
    bs:orbitui_search("Billy Bat")
    H.eq(search_opts.ref.profile, "comics"); H.eq(search_opts.query, "Billy Bat")
    search_opts.open_book("/book"); H.eq(opened, "/book")
    bs:orbitui_shelf_menu("next"); H.eq(shelf_menu[1], bs)
    bs:_commitBookStatus({ filepath = "/book" }, "complete")
    H.eq(commits, 1); H.eq(refreshes, 1)
end)
H.test("saved Home modules register via the component loader seam", function()
    local registry = {}
    H.eq(Integration.wrap("modules/moduleregistry", registry), registry)
    H.eq(installed, registry)
end)
H.test("owned labels follow Swedish locale without replacing component translators", function()
    G_reader_settings = { readSetting = function() return "sv_SE" end }
    H.eq(require("core/orbitui_i18n")("OrbitUI settings"), "OrbitUI-inställningar")
    H.eq(require("core/orbitui_i18n")("Show this shelf on Home"), "Visa den här hyllan på Hem")
    G_reader_settings = nil
end)
H.finish()
