local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;" .. root .. "/components/bookshelf/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local saved = {}
package.loaded["lib/bookshelf_settings_store"] = { read = function(k) return saved[k] end,
    save = function(k, v) saved[k] = v end, flush = function() end, wasPresent = function() return false end }
G_reader_settings = { readSetting = function(_, key) if key == "home_dir" then return "/books" end end }
local P = dofile(root .. "/components/bookshelf/lib/bookshelf_profiles.lua")
package.loaded["lib/bookshelf_profiles"] = P
local Adapter = require("adapters/orbitui_libraries")
Adapter.profiles(P)
local changes = 0
Adapter.changed = function() changes = changes + 1 end
local shown, hosts = {}, {}
local UI = { show = function(_, w) shown[#shown + 1] = w end, close = function(_, w) w.closed = true end }
package.loaded["ui/uimanager"] = UI
local Dialog = H.widget()
function Dialog:getInputText() return self.input end
function Dialog:onShowKeyboard() self.keyboard = true end
package.loaded["ui/widget/inputdialog"] = Dialog
package.loaded["ui/widget/pathchooser"] = Dialog
package.loaded["ui/widget/confirmbox"] = Dialog
package.loaded["libs/libkoreader-lfs"] = { attributes = function() return "directory" end }
package.loaded["lib/bookshelf_menu_host"] = { show = function(opts)
    opts._shim = { updateItems = function() opts.refreshed = (opts.refreshed or 0) + 1 end }
    hosts[#hosts + 1] = opts; return opts
end }
local Settings = require("adapters/orbitui_library_settings")
local Model = require("core/orbitui_libraries")
local notices = {}
package.loaded["core/orbitui_context"] = { notify = function(text) notices[#notices + 1] = text end }
local function find(rows, text)
    for _, row in ipairs(rows) do if row.text == text then return row end end
    error("Missing menu item: " .. text)
end
local function submit(text)
    local dialog = shown[#shown]
    dialog.input = text; dialog.buttons[1][2].callback()
end

H.test("stock Bookshelf settings alone do not import personal profiles", function()
    H.eq(P.get("prose"), nil); H.eq(P.get("comics"), nil)
    H.eq(P.get("library").roots[1], "/books")
end)

H.test("adding an arbitrary library updates the open inventory without editing files", function()
    local rows = Settings.items()
    find(rows, "Add library section").callback()
    submit("Children")
    local chooser = shown[#shown]
    H.eq(chooser.select_directory, true); H.eq(chooser.select_file, false)
    chooser.onConfirm("/kids/")
    H.eq(P.get("section_1").roots[1], "/kids")
    assert(find(rows, "Children")); H.eq(changes, 1)
end)

H.test("section renames and repeated folder changes update live controls", function()
    local host = Settings.section("section_1")
    find(host.item_table, "Rename").callback(); submit("Children's books")
    H.eq(P.get("section_1").label, "Children's books")
    find(host.item_table, "Library folders (advanced)").callback()
    local folders = hosts[#hosts]
    find(folders.item_table, "Folder: /kids").callback()
    shown[#shown].onConfirm("/new/kids")
    H.eq(P.get("section_1").roots[1], "/kids") -- explicit whole-library confirmation
    shown[#shown].ok_callback()
    find(folders.item_table, "Folder: /new/kids").callback()
    shown[#shown].onConfirm("/second/kids")
    shown[#shown].ok_callback()
    H.eq(P.get("section_1").chips[1].path, "/second/kids")
    assert(host.refreshed >= 3)
end)

H.test("library folders are collapsed and each folder chip owns its source control", function()
    local rows = Settings.sectionItems("section_1")
    assert(find(rows, "Library folders (advanced)")); assert(find(rows, "Order chips"))
    for _, row in ipairs(rows) do
        assert(not row.text:match("^Folder:")); assert(row.text ~= "Move up" and row.text ~= "Move down")
    end
    rows = Settings.shelfItems("section_1", "books")
    assert(find(rows, "Source: Folder")); assert(find(rows, "Folder: /second/kids"))
    assert(find(rows, "Position 1 of 1"))
    for _, row in ipairs(rows) do assert(row.text ~= "Move up" and row.text ~= "Move down") end
end)

H.test("shelf grouping is optional and independent of section ID and folder name", function()
    local host = Settings.shelf("section_1", "books")
    find(host.item_table, "Group subfolder as a box: Off").callback(); submit("Short stories")
    H.eq(P.chip(P.get("section_1"), "books").group_folder_name, "Short stories")
    find(host.item_table, "Group subfolder as a box: Short stories").callback(); submit("")
    H.eq(P.chip(P.get("section_1"), "books").group_folder_name, nil)
    local flag = find(host.item_table, "Folder cards already show their titles")
    H.eq(flag.checked_func(), false); flag.callback()
    H.eq(find(host.item_table, "Folder cards already show their titles").checked_func(), true)
    H.eq(find(host.item_table, "Remove shelf").enabled_func(), false)
end)

H.test("adding, renaming and removing a shelf keeps other shelf IDs and settings", function()
    local host = Settings.section("section_1")
    find(host.item_table, "Add shelf").callback()
    find(hosts[#hosts].item_table, "Recently added").callback(); submit("New arrivals")
    H.eq(#P.get("section_1").chips, 2)
    find(host.item_table, "New arrivals").callback()
    local shelf = hosts[#hosts]
    find(shelf.item_table, "Rename").callback(); submit("Newest")
    H.eq(P.get("section_1").chips[2].key, "shelf_1")
    find(shelf.item_table, "Remove shelf").callback()
    shown[#shown].ok_callback()
    H.eq(#P.get("section_1").chips, 1); H.eq(P.get("section_1").chips[1].key, "books")
    H.eq(#shelf.item_table, 0)
end)

H.test("disabling and re-enabling a section is non-destructive", function()
    local host = Settings.section("section_1")
    find(host.item_table, "Enabled").callback()
    H.eq(P.get("section_1"), nil); H.eq(P.get("section_1", true).roots[1], "/second/kids")
    find(host.item_table, "Enabled").callback()
    H.eq(P.get("section_1").label, "Children's books")
end)

H.test("non-folder chip sources have readable labels and no misleading folder picker", function()
    local rows = Settings.shelfItems("library", "latest")
    assert(find(rows, "Source: Recently added"))
    for _, row in ipairs(rows) do assert(not row.text:match("^Folder:")) end
end)

H.test("changing one chip within a library never remaps its root or sibling sources", function()
    P.edit("section_1", function(s)
        s.chips[#s.chips + 1] = { key = "fiction", label = "Fiktion", theme = "MY_THEME",
            source = { kind = "folder", id = "/second/kids/Fiktion" } }
        s.chips[#s.chips + 1] = { key = "poetry", label = "Lyrik",
            source = { kind = "folder", id = "/second/kids/Lyrik" } }
    end)
    local host = Settings.shelf("section_1", "fiction")
    find(host.item_table, "Folder: /second/kids/Fiktion").callback()
    local chooser = shown[#shown]
    chooser.onConfirm("/second/kids/Prosa/")
    H.eq(shown[#shown], chooser) -- within existing root: no scope expansion
    local s = P.get("section_1")
    H.eq(#s.roots, 1); H.eq(s.roots[1], "/second/kids")
    H.eq(P.chip(s, "books").source.id, "/second/kids")
    H.eq(P.chip(s, "poetry").source.id, "/second/kids/Lyrik")
    H.eq(P.chip(s, "fiction").path, "/second/kids/Prosa")
    H.eq(P.chip(s, "fiction").theme, "MY_THEME")
    assert(find(host.item_table, "Folder: /second/kids/Prosa")); assert(host.refreshed > 0)
end)

H.test("external chip folders require consent and keep existing roots and other chips", function()
    local host = Settings.shelf("section_1", "fiction")
    find(host.item_table, "Folder: /second/kids/Prosa").callback()
    shown[#shown].onConfirm("/other/Prosa")
    local confirmation = shown[#shown]
    H.eq(confirmation.ok_text, "Add folder and use")
    H.eq(#P.get("section_1").roots, 1)
    H.eq(P.chip(P.get("section_1"), "fiction").path, "/second/kids/Prosa")
    confirmation.ok_callback()
    local s = P.get("section_1")
    H.eq(#s.roots, 2); H.eq(s.roots[1], "/second/kids"); H.eq(s.roots[2], "/other/Prosa")
    H.eq(P.chip(s, "fiction").path, "/other/Prosa")
    H.eq(P.chip(s, "poetry").path, "/second/kids/Lyrik")
end)

H.test("cancelled, invalid and stale chip folder choices cannot expand a library", function()
    local host = Settings.shelf("section_1", "fiction")
    find(host.item_table, "Folder: /other/Prosa").callback()
    local chooser = shown[#shown]
    chooser.onConfirm("/bad/../folder")
    H.eq(shown[#shown], chooser)
    chooser.onConfirm("/cancelled") -- not confirming writes nothing
    H.eq(#P.get("section_1").roots, 2)
    local confirmation = shown[#shown]
    P.edit("section_1", function(s) P.chip(s, "fiction").source.id = "/other/Prosa/changed" end)
    confirmation.ok_callback() -- don't overwrite a newer edit
    H.eq(#P.get("section_1").roots, 2)
    H.eq(P.chip(P.get("section_1"), "fiction").path, "/other/Prosa/changed")
end)

H.test("chip order is selected in place with no preference writes until moved", function()
    local host = Settings.orderChips("section_1")
    local before = changes
    local config = P.config()
    find(host.item_table, "2. Fiktion").callback()
    H.eq(P.config(), config); H.eq(changes, before)
    assert(find(host.item_table, "Fiktion — Position 2 of 3"))
    assert(find(host.item_table, "Place before Books")); assert(find(host.item_table, "Place after Lyrik"))
    assert(host.refreshed > 0)
end)

H.test("chip moves show the new numbered order and boundary immediately, preserving IDs and settings", function()
    local editor = Settings.shelf("section_1", "fiction")
    find(editor.item_table, "Position 2 of 3").callback()
    local host = hosts[#hosts]
    find(host.item_table, "Place before Books").callback()
    local s = P.get("section_1")
    H.eq(s.chips[1].key, "fiction"); H.eq(s.chips[2].key, "books"); H.eq(s.chips[3].key, "poetry")
    H.eq(s.chips[1].theme, "MY_THEME"); H.eq(s.chips[1].path, "/other/Prosa/changed")
    assert(find(host.item_table, "Fiktion — Position 1 of 3"))
    H.eq(find(host.item_table, "Already first").enabled_func(), false)
    assert(find(host.item_table, "1. Fiktion")); assert(find(host.item_table, "2. Books"))
    assert(find(editor.item_table, "Position 1 of 3")) -- parent also updates without reopening
    find(host.item_table, "Place after Books").callback()
    find(host.item_table, "Place after Lyrik").callback()
    assert(find(host.item_table, "Fiktion — Position 3 of 3"))
    H.eq(find(host.item_table, "Already last").enabled_func(), false)
end)

H.test("library order is separate from chip order and includes disabled libraries", function()
    local before_chips = P.get("section_1").chips
    P.edit("section_1", function(s) s.enabled = false end)
    local rows = Settings.items()
    find(rows, "Order libraries").callback()
    local host = hosts[#hosts]
    find(host.item_table, "2. Children's books").callback()
    assert(find(host.item_table, "Children's books — Position 2 of 2"))
    find(host.item_table, "Place before Library").callback()
    H.eq(P.list(true)[1].key, "section_1"); H.eq(P.get("section_1"), nil)
    H.eq(P.get("section_1", true).chips[1].key, before_chips[1].key)
    assert(find(host.item_table, "1. Children's books")); assert(find(host.item_table, "2. Library"))
    find(host.item_table, "About this order").callback()
    assert(notices[#notices]:find("not navigation buttons", 1, true))
    P.edit("section_1", function(s) s.enabled = true end)
end)

H.test("stale order controls resolve stable IDs, not old positions or deleted neighbours", function()
    local host = Settings.orderChips("section_1", "fiction")
    local move_before_poetry = find(host.item_table, "Place before Lyrik").callback
    P.edit("section_1", function(s) s.chips[1], s.chips[2] = s.chips[2], s.chips[1] end)
    move_before_poetry()
    local s = P.get("section_1")
    H.eq(s.chips[1].key, "fiction"); H.eq(s.chips[2].key, "poetry"); H.eq(s.chips[3].key, "books")
    P.edit("section_1", function(current) table.remove(current.chips, 2) end)
    move_before_poetry() -- deleted destination, no other item is moved
    s = P.get("section_1")
    H.eq(s.chips[1].key, "fiction"); H.eq(s.chips[2].key, "books")
    H.eq(#s.chips, 2)
end)

H.test("root replacement remains explicit, broad, and non-destructive in Advanced", function()
    local folders = Settings.folders("section_1")
    find(folders.item_table, "Folder: /second/kids").callback()
    shown[#shown].onConfirm("/relocated")
    H.eq(P.chip(P.get("section_1"), "books").path, "/second/kids")
    shown[#shown].ok_callback()
    local s = P.get("section_1")
    H.eq(s.roots[1], "/relocated"); H.eq(s.roots[2], "/other/Prosa")
    H.eq(P.chip(s, "books").path, "/relocated")
    H.eq(P.chip(s, "fiction").path, "/other/Prosa/changed")
    assert(find(folders.item_table, "Folder: /relocated"))
    Model.validate(P.config())
end)

H.test("labels are Swedish only in Swedish and otherwise have English fallbacks", function()
    local translate = require("core/orbitui_i18n")
    G_reader_settings.readSetting = function() return "sv_SE" end
    H.eq(translate("Library sections"), "Biblioteksavdelningar")
    local host = Settings.orderChips("section_1", "fiction")
    H.eq(host.title, "Ordna chip")
    assert(find(host.item_table, "Fiktion — Plats 1 av 2"))
    assert(find(host.item_table, "Placera efter Books")) -- user-entered names are NOT translated
    assert(find(Settings.shelfItems("section_1", "fiction"), "Källa: Mapp"))
    assert(find(Settings.shelfItems("section_1", "fiction"), "Mapp: /other/Prosa/changed"))
    assert(find(Settings.sectionItems("section_1"), "Bibliotekets mappar (avancerat)"))
    G_reader_settings.readSetting = function() return "de" end
    H.eq(translate("Library sections"), "Library sections")
end)

H.test("the real menu host repaints the numbered list, position and controls without closing or Back", function()
    package.loaded["lib/bookshelf_i18n"] = { gettext = require("core/orbitui_i18n") }
    package.loaded.device = { screen = { getWidth = function() return 1080 end,
        getHeight = function() return 1440 end } }
    local NativeMenu = H.widget()
    function NativeMenu:init() self.paths = {}; self.page = 1; self.page_num = 1 end
    function NativeMenu:switchItemTable(title, rows)
        self.title, self.item_table, self.page = title, rows, 1
        self.paints = (self.paints or 0) + 1
    end
    package.loaded["ui/widget/menu"] = NativeMenu
    local realHost = dofile(root .. "/components/bookshelf/lib/bookshelf_menu_host.lua")
    package.loaded["lib/bookshelf_menu_host"] = realHost
    local host = Settings.orderChips("section_1", "fiction")
    local native = host._menu
    local function mapped(text)
        for _, row in ipairs(native.item_table) do
            if row._src.text == text then return row end
        end
        error("Missing painted row: " .. text)
    end
    H.eq(mapped("Already first").select_enabled, false)
    mapped("Place after Books").callback()
    assert(not host._closed); H.eq(#host._stack, 1); assert(native.paints > 0)
    assert(mapped("2. Fiktion")); assert(mapped("Fiktion — Position 2 of 2"))
    H.eq(mapped("Already last").select_enabled, false)
    mapped("Place before Books").callback()
    assert(mapped("1. Fiktion")); assert(mapped("Fiktion — Position 1 of 2"))
    mapped("2. Books").callback() -- select another chip, not a submenu
    assert(mapped("Books — Position 2 of 2")); H.eq(#host._stack, 1)
    realHost.close(host); H.eq(host._closed, true)
end)

H.finish()
