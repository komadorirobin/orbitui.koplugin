-- A setup draft has no storage or UI side effects. Only the reviewed plan is saved.
local Libraries = require("core/orbitui_libraries")
local Dashboard = require("core/orbitui_dashboard")
local M = {}

function M.equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not M.equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

function M.draft(snapshot)
    return { original = Libraries.copy(snapshot), libraries = Libraries.copy(snapshot.libraries),
        home = "keep", bar = "keep", appearance = "keep", tabs = Libraries.copy(snapshot.tabs or {}) }
end

function M.add(draft, label, path)
    path = assert(Libraries.path(path), "Select a library folder")
    assert(type(label) == "string" and label:match("%S"), "Missing library name")
    local config, used = draft.libraries, {}
    for _, section in ipairs(config.sections) do used[section.key] = true end
    local n = tonumber(config.next_id) or 1
    while used["section_" .. n] do n = n + 1 end
    local key = "section_" .. n
    config.next_id = n + 1
    config.sections[#config.sections + 1] = { key = key, label = label, icon = "nerd:F02D",
        roots = { path }, chips = {
            { key = "books", label = "Books", source = { kind = "folder", id = path } },
            { key = "latest", label = "Latest", source = { kind = "latest" } },
            { key = "authors", label = "Authors", source = { kind = "authors" } },
            { key = "series", label = "Series", source = { kind = "series" } },
        } }
    return key
end

function M.relocate(section, old, path)
    path = assert(Libraries.path(path), "Select a library folder")
    for i, root in ipairs(section.roots) do
        if Libraries.contains(root, old) then section.roots[i] = Libraries.path(path .. "/" .. root:sub(#old + 1)) end
    end
    for _, chip in ipairs(section.chips) do
        if chip.source.kind == "folder" and Libraries.contains(chip.source.id, old) then
            chip.source.id = Libraries.path(path .. "/" .. chip.source.id:sub(#old + 1))
            chip.path = chip.source.id
        end
    end
end

function M.plan(draft, current, options)
    options = options or {}
    Libraries.validate(draft.libraries)
    assert(M.equal(current, draft.original), "Settings changed while setup was open. Reopen the guide.")
    local writes = {}
    local function set(store, key, value) writes[#writes + 1] = { store = store, key = key, value = value } end
    if not M.equal(draft.libraries, draft.original.libraries) then
        local old_roots = {}
        for _, section in ipairs(draft.original.libraries.sections) do
            for _, path in ipairs(section.roots) do old_roots[path] = true end
        end
        for _, section in ipairs(draft.libraries.sections) do
            for _, path in ipairs(section.roots) do
                assert(old_roots[path] or not options.directory or options.directory(path), "Select an existing folder")
            end
        end
        set("bookshelf", Libraries.key, Libraries.copy(draft.libraries))
    end
    assert(({ keep = true, dashboard = true, home = true, files = true })[draft.home], "Invalid start screen")
    if draft.home ~= "keep" then
        set("reader", "start_with", draft.home == "files" and "filemanager" or "homescreen_simpleui")
    end
    if draft.home == "dashboard" then
        local layout = Dashboard.withPage(current.layout, true)
        set("simpleui", "simpleui_layout", layout)
        set("simpleui", "simpleui_hs_orbitui_dashboard_enabled", true)
        -- Keep the native module-order setting in sync without resetting modules.
        local order, seen = {}, {}
        for _, page in ipairs(layout.pages) do
            for _, entry in ipairs(page.modules) do
                local id = type(entry) == "table" and entry.id or entry
                if id then order[#order + 1], seen[id] = id, true end
            end
        end
        for _, id in ipairs(current.order or {}) do
            if id ~= "__page_break__" and not seen[id] then order[#order + 1], seen[id] = id, true end
        end
        set("simpleui", "simpleui_hs_module_order", order)
    end
    assert(draft.bar == "keep" or draft.bar == "custom", "Invalid bottom bar")
    if draft.bar == "custom" then
        assert(#draft.tabs >= 2 and #draft.tabs <= (options.max_tabs or 6), "Choose between two and the maximum number of buttons")
        local seen = {}
        for _, id in ipairs(draft.tabs) do
            assert(type(id) == "string" and not seen[id] and options.actions[id], "Invalid bottom-bar action")
            seen[id] = true
        end
        set("simpleui", "simpleui_bar_tabs", Libraries.copy(draft.tabs))
        set("simpleui", "simpleui_bar_enabled", true)
    end
    if draft.appearance ~= "keep" then
        local Appearance = require("core/orbitui_appearance")
        set("setup", Appearance.key, Appearance.value(draft.appearance))
    end
    return writes
end

function M.commit(writes, stores)
    local undo, touched, flush_order = {}, {}, {}
    local ok, err = pcall(function()
        for _, change in ipairs(writes) do
            local store = assert(stores[change.store])
            undo[#undo + 1] = { store = store, key = change.key, value = Libraries.copy(store.read(change.key)) }
            if not touched[store] then flush_order[#flush_order + 1], touched[store] = store, true end
            assert(store.write(change.key, Libraries.copy(change.value)) ~= false, "Settings write failed")
        end
        -- The setup-complete marker is last, after all preferences reach disk.
        for _, store in ipairs(flush_order) do assert(store.flush() ~= false, "Settings flush failed") end
    end)
    if not ok then
        local restored = true
        for i = #undo, 1, -1 do
            local change = undo[i]
            local saved, result = pcall(change.store.write, change.key, change.value)
            restored = saved and result ~= false and restored
        end
        for store in pairs(touched) do
            local saved, result = pcall(store.flush)
            restored = saved and result ~= false and restored
        end
        return nil, err, restored
    end
    return true
end

return M
