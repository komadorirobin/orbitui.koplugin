package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local saved = {}
package.loaded["lib/bookshelf_settings_store"] = { read = function(k) return saved[k] end,
    save = function(k, v) saved[k] = v end, flush = function() end, wasPresent = function() return false end }
G_reader_settings = { readSetting = function(_, key) if key == "home_dir" then return "/books" end end }
local P = dofile("components/bookshelf/lib/bookshelf_profiles.lua")
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
    find(host.item_table, "Folder: /kids").callback()
    shown[#shown].onConfirm("/new/kids")
    find(host.item_table, "Folder: /new/kids").callback()
    shown[#shown].onConfirm("/second/kids")
    H.eq(P.get("section_1").chips[1].path, "/second/kids")
    assert(host.refreshed >= 3)
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

H.test("labels are Swedish only in Swedish and otherwise have English fallbacks", function()
    local translate = require("core/orbitui_i18n")
    G_reader_settings.readSetting = function() return "sv_SE" end
    H.eq(translate("Library sections"), "Biblioteksavdelningar")
    G_reader_settings.readSetting = function() return "de" end
    H.eq(translate("Library sections"), "Library sections")
end)

H.finish()
