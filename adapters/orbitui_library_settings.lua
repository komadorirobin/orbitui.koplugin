local M = {}
local Model = require("core/orbitui_libraries")
local _ = require("core/orbitui_i18n")
local function profiles() return require("lib/bookshelf_profiles") end
local function ui() return require("ui/uimanager") end
local watched = setmetatable({}, { __mode = "k" })
local function watch(build)
    local rows = build()
    watched[rows] = { build = build }
    return rows
end
local function changed()
    require("adapters/orbitui_libraries").changed()
    for rows, observer in pairs(watched) do
        local fresh = observer.build()
        for i = #rows, 1, -1 do rows[i] = nil end
        for i, row in ipairs(fresh) do rows[i] = row end
        local host = observer.host and observer.host[1]
        if host and not host._closed then host._shim.updateItems() end
    end
end

local function input(title, value, save, allow_empty)
    local dialog
    dialog = require("ui/widget/inputdialog"):new{
        title = title, input = value or "",
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() ui():close(dialog) end },
            { text = _("Save"), is_enter_default = true, callback = function()
                local text = (dialog:getInputText() or ""):match("^%s*(.-)%s*$")
                if text == "" and not allow_empty then return end
                ui():close(dialog)
                save(text)
            end },
        }},
    }
    ui():show(dialog)
    dialog:onShowKeyboard()
end

local function folder(start, save)
    local fs = require("libs/libkoreader-lfs")
    if not start or fs.attributes(start, "mode") ~= "directory" then
        start = G_reader_settings and G_reader_settings:readSetting("home_dir")
        if not start or fs.attributes(start, "mode") ~= "directory" then start = "/" end
    end
    ui():show(require("ui/widget/pathchooser"):new{
        path = start, select_directory = true, select_file = false, show_files = false,
        onConfirm = function(path) if Model.path(path) then save(Model.path(path)) end end,
    })
end

local function menu(title, rows)
    if type(rows) == "function" then rows = watch(rows) end
    local host = require("lib/bookshelf_menu_host").show{ title = title, item_table = rows }
    if watched[rows] then watched[rows].host = setmetatable({ host }, { __mode = "v" }) end
    return host
end

local function edit(key, fn)
    if profiles().edit(key, fn) then changed() end
end

local function move(list, key, delta)
    for i, item in ipairs(list) do
        if item.key == key and list[i + delta] then
            list[i], list[i + delta] = list[i + delta], list[i]
            return
        end
    end
end

local function addShelf(key, kind, path, default_label)
    input(_("Shelf name"), kind == "folder" and path:match("([^/]+)$") or _(default_label), function(label)
        edit(key, function(section)
            local n = tonumber(section.next_shelf_id) or 1
            local used = {}
            for _, chip in ipairs(section.chips) do used[chip.key] = true end
            while used["shelf_" .. n] do n = n + 1 end
            section.next_shelf_id = n + 1
            section.chips[#section.chips + 1] = {
                key = "shelf_" .. n, label = label, source = { kind = kind, id = path },
            }
            if path then
                local covered = false
                for _, root in ipairs(section.roots) do covered = covered or Model.contains(path, root) end
                if not covered then section.roots[#section.roots + 1] = path end
            end
        end)
    end)
end

function M.addShelf(key)
    local section = profiles().get(key, true)
    if not section then return end
    local rows = { { text = _("Folder"), callback = function()
        folder(section.roots[1], function(path) addShelf(key, "folder", path) end)
    end } }
    for _i, source in ipairs({ { "latest", "Recently added" }, { "authors", "Authors" },
        { "series", "Series" }, { "recent", "Recent" }, { "favorites", "Favorites" },
        { "next", "Next unread in series" }, { "bookorbit_want", "BookOrbit Want to Read" } }) do
        local kind, label = source[1], source[2]
        rows[#rows + 1] = { text = _(label), callback = function() addShelf(key, kind, nil, label) end }
    end
    menu(_("Add shelf"), rows)
end

function M.shelfItems(key, id)
    local p = profiles()
    local section = p.get(key, true)
    local chip = p.chip(section, id)
    if not chip then return {} end
    local function update(fn)
        edit(key, function(current)
            local target = p.chip(current, id)
            if target then fn(target, current) end
        end)
    end
    local rows = {
        require("adapters/orbitui_settings").scopeRow("shelf", section.label .. " / " .. chip.label),
        { text = _("Rename"), callback = function()
            input(_("Shelf name"), chip.label, function(text) update(function(c) c.label = text end) end)
        end },
        { text = _("Appearance"), callback = function()
            require("core/orbitui_context").withShelf(key, function(widget) widget:_showProfileShelfStyle(id) end)
        end },
        { text = _("Move up"), callback = function() edit(key, function(s) move(s.chips, id, -1) end) end },
        { text = _("Move down"), callback = function() edit(key, function(s) move(s.chips, id, 1) end) end },
    }
    if chip.kind == "folder" then
        rows[#rows + 1] = { text = _("Group subfolder as a box") .. ": " .. (chip.group_folder_name or _("Off")),
            callback = function()
                input(_("Subfolder name (empty disables grouping)"), chip.group_folder_name, function(text)
                    if text:find("/", 1, true) or text == "." or text == ".." then return end
                    update(function(c) c.group_folder_name = text ~= "" and text or nil end)
                end, true)
            end }
        rows[#rows + 1] = { text = _("Folder cards already show their titles"),
            checked_func = function() return chip.folders_only == true end,
            callback = function() update(function(c) c.folders_only = not c.folders_only end) end }
        rows[#rows + 1] = { text = _("Limit folder lists to three rows"),
            checked_func = function() return chip.folder_list_max == 3 end,
            callback = function() update(function(c) c.folder_list_max = c.folder_list_max ~= 3 and 3 or nil end) end }
    end
    rows[#rows + 1] = { text = _("Remove shelf"), enabled_func = function() return #section.chips > 1 end, callback = function()
        ui():show(require("ui/widget/confirmbox"):new{
            text = _("Remove this shelf? Books and saved appearance settings will not be deleted."),
            ok_text = _("Remove"), ok_callback = function()
                update(function(_, s)
                    if #s.chips <= 1 then return end
                    for i, c in ipairs(s.chips) do if c.key == id then table.remove(s.chips, i); break end end
                end)
            end,
        })
    end }
    return rows
end

function M.shelf(key, id)
    local section = profiles().get(key, true)
    local chip = profiles().chip(section, id)
    if chip then return menu(section.label .. " / " .. chip.label, function() return M.shelfItems(key, id) end) end
end

function M.sectionItems(key)
    local p, rows = profiles(), {}
    local section = p.get(key, true)
    if not section then return {} end
    rows[#rows + 1] = require("adapters/orbitui_settings").scopeRow("library", section.label)
    rows[#rows + 1] = { text = _("Rename"), callback = function()
        input(_("Library name"), section.label, function(text) edit(key, function(s) s.label = text end) end)
    end }
    rows[#rows + 1] = { text = _("Icon"), callback = function()
        require("features/sui_quickactions").showIconPicker(section.icon, function(icon)
            edit(key, function(s) s.icon = icon end)
        end, section.label, nil, nil, true)
    end }
    rows[#rows + 1] = { text = _("Enabled"), checked_func = function()
        return p.get(key, true).enabled ~= false
    end, callback = function() edit(key, function(s) s.enabled = s.enabled == false end) end }
    rows[#rows + 1] = { text = _("Move up"), callback = function()
        edit(key, function(_, config) move(config.sections, key, -1) end)
    end }
    rows[#rows + 1] = { text = _("Move down"), callback = function()
        edit(key, function(_, config) move(config.sections, key, 1) end)
    end }
    for _i, root in ipairs(section.roots) do
        local path = root
        rows[#rows + 1] = { text = _("Folder") .. ": " .. path, callback = function()
            folder(path, function(replacement)
                p.relocateRoot(key, path, replacement)
                changed()
            end)
        end }
    end
    for _, chip in ipairs(section.chips) do
        local id = chip.key
        rows[#rows + 1] = { text = chip.label, callback = function() M.shelf(key, id) end }
    end
    rows[#rows + 1] = { text = _("Add shelf"), callback = function() M.addShelf(key) end }
    rows[#rows + 1] = { text = _("Add to navigation bar"), enabled_func = function()
        return p.get(key) ~= nil
    end, callback = function() M.addToBar(require("adapters/orbitui_libraries").actionId(key)) end }
    rows[#rows + 1] = { text = _("Use for Bookshelf button"), enabled_func = function()
        return p.get(key) ~= nil
    end, callback = function()
        require("adapters/orbitui_libraries").setBookshelfTarget(key)
        M.addToBar(require("adapters/orbitui_navbar").bookshelf_action)
    end }
    return rows
end

function M.section(key)
    local section = profiles().get(key, true)
    if section then return menu(section.label, function() return M.sectionItems(key) end) end
end

local function items()
    local rows = {}
    for _i, section in ipairs(profiles().list(true)) do
        local key = section.key
        rows[#rows + 1] = { text = section.label .. (section.enabled == false and " (" .. _("Off") .. ")" or ""),
            callback = function() M.section(key) end }
    end
    rows[#rows + 1] = { text = _("Add library section"), callback = function()
        input(_("Library name"), "", function(label)
            folder(nil, function(path) profiles().add(label, path); changed() end)
        end)
    end }
    return rows
end

function M.items() return watch(items) end

function M.addToBar(id)
    local Nav = require("adapters/orbitui_navbar")
    local ok, reason = Nav.setAction(id, true)
    if ok then return true end
    if reason ~= "full" then
        require("core/orbitui_context").notify(_("The navigation bar changed. Please try again."))
        return false
    end
    local rows, Config = {}, require("infra/sui_config")
    for _, current in ipairs(Config.loadTabConfig()) do
        local old = current
        rows[#rows + 1] = { text = require("features/sui_quickactions").getEntry(old).label,
            callback = function(host)
                host.closeMenu()
                local saved = Nav.setAction(id, true, old)
                if not saved then M.addToBar(id) end
            end }
    end
    return menu(_("Bar full: choose a button to replace"), rows)
end

function M.destinationItems()
    local Libraries = require("adapters/orbitui_libraries")
    local rows = { { text = _("Bookshelf (no fixed profile)"), radio = true,
        checked_func = function() return Libraries.bookshelfTarget() == nil end,
        callback = function() Libraries.setBookshelfTarget(nil) end } }
    for _i, section in ipairs(profiles().list()) do
        local key = section.key
        rows[#rows + 1] = { text = _(section.label), radio = true,
            checked_func = function() return Libraries.bookshelfTarget() == key end,
            callback = function() Libraries.setBookshelfTarget(key) end }
    end
    return rows
end

function M.navigationItems()
    local Libraries, Nav = require("adapters/orbitui_libraries"), require("adapters/orbitui_navbar")
    return {
        { text = _("Show Bookshelf in navigation bar"), checked_func = function()
            return Nav.hasAction(Nav.bookshelf_action)
        end, callback = function()
            if Nav.hasAction(Nav.bookshelf_action) then
                if not Nav.setAction(Nav.bookshelf_action, false) then
                    require("core/orbitui_context").notify(_("Keep at least two navigation buttons, or one with the page navigator."))
                end
            else M.addToBar(Nav.bookshelf_action) end
        end },
        { text_func = function()
            local key = Libraries.bookshelfTarget()
            local section = key and profiles().get(key)
            return _("Destination") .. ": " .. (key == nil and _("Bookshelf (no fixed profile)")
                or section and _(section.label) or _("Unavailable profile"))
        end, sub_item_table_func = M.destinationItems },
        { text = _("Profiles and chips"), sub_item_table_func = M.items },
        { text = _("About Bookshelf navigation"), callback = function()
            require("core/orbitui_context").notify(_("Each library section is a Bookshelf profile with its own folders and chips. Choose one for the Bookshelf button, or add several profiles as separate navigation buttons. Long-press Bookshelf to return here. The file browser is separate."))
        end },
    }
end

function M.navigation() return menu(_("Bookshelf navigation"), M.navigationItems) end

function M.missingProfile(key)
    local rows = {
        { text = string.format(_("Profile '%s' is missing or disabled on this device."), tostring(key)),
            enabled_func = function() return false end },
        { text = _("Open Bookshelf"), callback = function(host)
            host.closeMenu()
            require("features/sui_quickactions").openBookshelfProfile(nil, {})
        end },
        { text = _("Configure Bookshelf navigation"), sub_item_table_func = M.navigationItems },
    }
    return menu(_("Bookshelf profile unavailable"), rows)
end

return M
