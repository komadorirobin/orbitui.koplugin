local Model = require("core/orbitui_setup")
local Libraries = require("core/orbitui_libraries")
local _ = require("core/orbitui_i18n")
local M = {}
local state, active, offered, current_owner
local function ui() return require("ui/uimanager") end
local function profiles() return require("lib/bookshelf_profiles") end
local function sui() return require("infra/sui_store") end
local function directory(path) return require("libs/libkoreader-lfs").attributes(path, "mode") == "directory" end

function M.prepare(existing_host)
    if state then return end
    local fs = require("libs/libkoreader-lfs")
    local dir = require("datastorage"):getSettingsDir()
    local parent = dir .. "/orbitui"
    if not directory(parent) then assert(fs.mkdir(parent)) end
    local opened = require("luasettings"):open(parent .. "/setup.lua")
    local saved = opened:readSetting("setup")
    if saved == nil then
        local existing = false
        for name in fs.dir(dir) do
            if name:match("^bookshelf.*%.lua$") or name:match("^bookshelf.*%.lua%.old$") then existing = true end
        end
        for _i, suffix in ipairs({ "", ".old" }) do
            existing = existing or fs.attributes(dir .. "/simpleui/sui_settings.lua" .. suffix, "mode") == "file"
                or fs.attributes(dir .. "/bookshelf/settings.lua" .. suffix, "mode") == "file"
        end
        for key in pairs(G_reader_settings and G_reader_settings.data or {}) do
            if type(key) == "string" and (key:match("^simpleui_") or key:match("^bookshelf_")) then existing = true end
        end
        -- Persist detection before components create their default settings files.
        opened:saveSetting("setup", { version = 1, status = existing and "kept" or "pending" })
        assert(opened:flush() ~= false, "Could not save OrbitUI setup state")
    else
        assert(type(saved) == "table" and saved.version == 1
            and ({ pending = true, kept = true, complete = true, skipped = true })[saved.status],
            "Unsupported OrbitUI setup state; saved settings were not changed")
    end
    -- Existing standalone components are not evidence of OrbitUI's forced
    -- shelf policy. The pre-first-run snapshot distinguishes a host upgrade.
    require("adapters/orbitui_appearance").prepare(opened,
        existing_host == false or opened:readSetting("setup").status == "pending")
    state = opened
end

local function snapshot()
    local Registry = require("modules/moduleregistry")
    local order = Registry.loadOrder("simpleui_hs_")
    local layout = Libraries.copy(sui():readSetting("simpleui_layout"))
    if type(layout) ~= "table" or not layout.pages then
        layout = { pages = { { id = 1, modules = {} } } }
        for _, id in ipairs(order) do
            if id == "__page_break__" then
                layout.pages[#layout.pages + 1] = { id = #layout.pages + 1, modules = {} }
            else
                local mod = Registry.get(id)
                if mod and Registry.isEnabled(mod, "simpleui_hs_") then
                    local page = layout.pages[#layout.pages]
                    page.modules[#page.modules + 1] = id
                end
            end
        end
    end
    return { libraries = Libraries.copy(profiles().config()), layout = layout, order = Libraries.copy(order),
        tabs = Libraries.copy(require("infra/sui_config").loadTabConfig()),
        start = G_reader_settings:readSetting("start_with"),
        dashboard = sui():readSetting("simpleui_hs_orbitui_dashboard_enabled"),
        appearance = require("adapters/orbitui_appearance").current() }
end

local function actionChoices(draft)
    local Config = require("infra/sui_config")
    local result, seen = {}, {}
    local function add(id, label)
        if not seen[id] then result[#result + 1], seen[id] = { id = id, label = label }, true end
    end
    add("homescreen", _("Home"))
    for _i, section in ipairs(draft.libraries.sections) do
        if section.enabled ~= false then
            add(require("adapters/orbitui_libraries").actionId(section.key), _(section.label))
        end
    end
    for _i, id in ipairs({ "home", "history", "sui_settings", "power" }) do
        local action = Config.ACTION_BY_ID[id]
        if action then add(id, action.label) end
    end
    -- Keep custom-screen/gesture actions already in the user's bar selectable.
    for _, id in ipairs(draft.original.tabs) do
        local action = Config.ACTION_BY_ID[id]
        add(id, action and action.label or id)
    end
    return result
end

local function finish(session)
    if active ~= session then return end
    active = nil
    local children = {}
    for child in pairs(session.children) do children[#children + 1] = child end
    for _, child in ipairs(children) do ui():close(child) end
end

local function showChild(session, widget)
    local close = widget.onCloseWidget
    widget.onCloseWidget = function(self, ...)
        session.children[self] = nil
        if close then return close(self, ...) end
    end
    session.children[widget] = true
    ui():show(widget)
    return widget
end

local function info(session, text)
    return showChild(session, require("ui/widget/infomessage"):new{ text = text })
end

local function refresh(session)
    for rows, build in pairs(session.watched) do
        local fresh = build()
        for i = #rows, 1, -1 do rows[i] = nil end
        for i, row in ipairs(fresh) do rows[i] = row end
    end
    if session.host and not session.host._closed then session.host._shim.updateItems() end
end

local function watch(session, build)
    local rows = build()
    session.watched[rows] = build
    return rows
end

local function input(session, title, value, callback)
    local dialog
    dialog = require("ui/widget/inputdialog"):new{
        title = title, input = value or "", buttons = {{
            { text = _("Cancel"), id = "close", callback = function() ui():close(dialog) end },
            { text = _("Save"), is_enter_default = true, callback = function()
                if active ~= session then return end
                local value = (dialog:getInputText() or ""):match("^%s*(.-)%s*$")
                if value == "" then return end
                ui():close(dialog)
                callback(value)
                refresh(session)
            end },
        }},
    }
    showChild(session, dialog)
    dialog:onShowKeyboard()
end

local function folder(session, start, callback)
    start = start or G_reader_settings:readSetting("home_dir")
    if not start or not directory(start) then start = "/" end
    showChild(session, require("ui/widget/pathchooser"):new{
        path = start, select_directory = true, select_file = false, show_files = false,
        onConfirm = function(path)
            if active ~= session then return end
            path = Libraries.path(path)
            if path and directory(path) then callback(path); refresh(session) end
        end,
    })
end

local function sectionItems(session, section)
    local rows = { { text = _("Rename"), callback = function()
        input(session, _("Library name"), section.label, function(label) section.label = label end)
    end } }
    for i in ipairs(section.roots) do
        local index = i
        rows[#rows + 1] = { text_func = function() return _("Folder") .. ": " .. section.roots[index] end,
            callback = function()
                folder(session, section.roots[index], function(path) Model.relocate(section, section.roots[index], path) end)
            end }
    end
    rows[#rows + 1] = { text = _("Enabled"), checked_func = function() return section.enabled ~= false end,
        callback = function() section.enabled = section.enabled == false; refresh(session) end }
    return rows
end

local function libraryItems(session)
    return watch(session, function()
        local rows = {}
        for _i, section in ipairs(session.draft.libraries.sections) do
            local item = section
            rows[#rows + 1] = { text_func = function() return item.label end,
                sub_item_table_func = function() return sectionItems(session, item) end }
        end
        rows[#rows + 1] = { text = _("Add library section"), callback = function()
            input(session, _("Library name"), "", function(label)
                folder(session, nil, function(path) Model.add(session.draft, label, path) end)
            end)
        end }
        return rows
    end)
end

local home_names = { keep = "Keep existing", dashboard = "Reading dashboard", home = "Existing Home pages", files = "File browser" }
local function homeItems(session)
    local rows = {}
    for _i, id in ipairs({ "keep", "dashboard", "home", "files" }) do
        local value = id
        rows[#rows + 1] = { text = _(home_names[value]), radio = true,
            checked_func = function() return session.draft.home == value end,
            callback = function() session.draft.home = value end }
    end
    return rows
end

local function barItems(session)
    return watch(session, function()
        local draft, rows = session.draft, {}
        rows[1] = { text = _("Keep existing"), radio = true,
            checked_func = function() return draft.bar == "keep" end,
            callback = function() draft.bar = "keep" end }
        rows[2] = { text = _("Choose buttons (selection order)"), radio = true,
            checked_func = function() return draft.bar == "custom" end,
            callback = function() draft.bar = "custom" end }
        for _i, action in ipairs(actionChoices(draft)) do
            local id = action.id
            local function position()
                for i, value in ipairs(draft.tabs) do if value == id then return i end end
            end
            rows[#rows + 1] = { text_func = function()
                return (position() and tostring(position()) .. ". " or "") .. action.label
            end, checked_func = function() return position() ~= nil end, callback = function()
                draft.bar = "custom"
                local i = position()
                if i then table.remove(draft.tabs, i)
                elseif #draft.tabs < require("infra/sui_config").effectiveMaxTabs() then draft.tabs[#draft.tabs + 1] = id
                else info(session, _("The bottom bar is full. Remove a button first.")) end
            end }
        end
        return rows
    end)
end

local function stores()
    local bs = require("lib/bookshelf_settings_store")
    local function colon(store, write)
        return { read = function(key) return store:readSetting(key) end,
            write = function(key, value)
                if write then return write(key, value)
                elseif value == nil then return store:delSetting(key) else return store:saveSetting(key, value) end
            end, flush = function() return store:flush() end }
    end
    return { bookshelf = { read = bs.read, write = function(key, value)
        if value == nil then return bs.delete(key) else return (bs.saveDeferred or bs.save)(key, value) end
    end, flush = bs.flush }, simpleui = colon(sui(), function(key, value) return sui():setNoFlush(key, value) end),
        reader = colon(G_reader_settings), setup = colon(state) }
end

local function plan(session)
    local actions = {}
    for _, action in ipairs(actionChoices(session.draft)) do actions[action.id] = true end
    return Model.plan(session.draft, snapshot(), { actions = actions, directory = directory,
        max_tabs = require("infra/sui_config").effectiveMaxTabs() })
end

local function errorText(err)
    return _((tostring(err):match("[^:]+$") or tostring(err)):match("^%s*(.-)%s*$"))
end

local function apply(session)
    if active ~= session then return end
    local ok, writes = pcall(plan, session)
    if not ok then info(session, errorText(writes)); return end
    writes[#writes + 1] = { store = "setup", key = "setup", value = { version = 1, status = "complete" } }
    local saved, err, restored = Model.commit(writes, stores())
    if not saved then
        require("logger").warn("OrbitUI setup save failed", err)
        info(session, _(restored and "Could not save setup. Previous settings were restored."
            or "Could not save setup completely. Check your settings before retrying."))
        return
    end
    require("lib/bookshelf_menu_host").close(session.host)
    require("infra/sui_config").invalidateTabsCache()
    require("adapters/orbitui_libraries").changed()
    if session.draft.appearance ~= "keep" then require("adapters/orbitui_appearance").changed() end
    local HS = package.loaded["screens/sui_homescreen"]
    if HS and HS.rebuildLayout then HS.rebuildLayout({ keep_wallpaper = true }) end
    ui():show(require("ui/widget/infomessage"):new{
        text = _("Setup saved. The start screen takes effect next time KOReader starts. You can reopen this guide in OrbitUI settings."),
    })
end

local function review(session)
    local ok, err = pcall(plan, session)
    if not ok then info(session, errorText(err)); return end
    local draft, lines = session.draft, { _("Review setup") }
    lines[#lines + 1] = _("Start screen") .. ": " .. _(home_names[draft.home])
    lines[#lines + 1] = _("Shelf preset") .. ": " .. (draft.appearance == "keep" and _("Keep existing")
        or require("adapters/orbitui_appearance").label(draft.appearance))
    if draft.appearance ~= "keep" then
        lines[#lines + 1] = _(require("core/orbitui_appearance").preset(draft.appearance).description)
    end
    lines[#lines + 1] = _("Library sections") .. ":"
    for _, section in ipairs(draft.libraries.sections) do
        lines[#lines + 1] = section.label .. (section.enabled == false and " (" .. _("Off") .. ")" or "")
            .. ": " .. table.concat(section.roots, ", ")
    end
    local names, labels = {}, {}
    for _, action in ipairs(actionChoices(draft)) do labels[action.id] = action.label end
    for _, id in ipairs(draft.tabs) do names[#names + 1] = labels[id] or id end
    lines[#lines + 1] = _("Bottom bar") .. ": " .. (draft.bar == "keep" and _("Keep existing") or table.concat(names, ", "))
    lines[#lines + 1] = _("No books are moved. Existing Home pages, reading data and accounts are kept.")
    showChild(session, require("ui/widget/confirmbox"):new{
        text = table.concat(lines, "\n\n"), ok_text = _("Apply"), ok_callback = function()
            ui():nextTick(function() apply(session) end)
        end,
    })
end

function M.show(owner, fresh)
    M.prepare()
    if active then return active.host end
    local session = { owner = owner or current_owner, draft = Model.draft(snapshot()), children = {}, watched = {} }
    if fresh then
        session.draft.home, session.draft.bar = "dashboard", "custom"
        local first = session.draft.libraries.sections[1]
        local library = first and first.enabled ~= false and require("adapters/orbitui_libraries").actionId(first.key) or "home"
        session.draft.tabs = { "homescreen", library, "power" }
    end
    active = session
    local rows = {
        { text = _("About this guide"), callback = function()
            info(session, _("Choose folders, library sections, a start screen and bottom-bar buttons. Nothing is applied until you review and confirm. All online integrations are optional."))
        end },
        { text = _("Library sections and folders"), sub_item_table_func = function() return libraryItems(session) end },
        { text_func = function() return _("Start screen") .. ": " .. _(home_names[session.draft.home]) end,
            sub_item_table_func = function() return homeItems(session) end },
        { text = _("Bottom bar"), sub_item_table_func = function() return barItems(session) end },
        { text = _("Optional integrations"), sub_item_table_func = function()
            return require("adapters/orbitui_integrations").items(function(text) info(session, text) end)
        end },
        { text_func = function() return _("Shelf preset") .. ": " .. (session.draft.appearance == "keep"
            and _("Keep existing") or require("adapters/orbitui_appearance").label(session.draft.appearance)) end,
            sub_item_table_func = function()
                local function choose(id) session.draft.appearance = id end
                local rows = require("adapters/orbitui_appearance").items(function() return session.draft.appearance end, choose)
                table.insert(rows, 1, { text = _("Keep existing"), radio = true,
                    checked_func = function() return session.draft.appearance == "keep" end,
                    callback = function() choose("keep") end })
                return rows
            end },
        { text = _("Review and apply"), callback = function() review(session) end },
        { text = _("Cancel (keep settings)"), callback = function() require("lib/bookshelf_menu_host").close(session.host) end },
    }
    if state:readSetting("setup").status == "pending" then
        rows[#rows + 1] = { text = _("Skip automatic setup"), callback = function()
            state:saveSetting("setup", { version = 1, status = "skipped" }); state:flush()
            require("lib/bookshelf_menu_host").close(session.host)
        end }
    end
    local ok, host = pcall(require("lib/bookshelf_menu_host").show, { title = _("OrbitUI setup"), item_table = rows,
        close_callback = function() finish(session) end })
    if not ok then finish(session); error(host) end
    session.host = host
    return session.host
end

function M.started(owner)
    current_owner = owner
    owner._orbitui_setup_alive = true
    if owner.ui.document then return end
    ui():nextTick(function()
        if not owner._orbitui_setup_alive or current_owner ~= owner or offered
            or state:readSetting("setup").status ~= "pending" then return end
        offered = true
        local ok, err = pcall(M.show, owner, true)
        if not ok then
            require("logger").warn("OrbitUI setup could not open", err)
            ui():show(require("ui/widget/infomessage"):new{
                text = _("The setup guide could not open. Your choices were not changed. Try again from OrbitUI settings."),
            })
        end
    end)
end

function M.stopped(owner)
    owner._orbitui_setup_alive = nil
    if current_owner == owner then current_owner = nil end
    if active and active.owner == owner then require("lib/bookshelf_menu_host").close(active.host) end
end

return M
