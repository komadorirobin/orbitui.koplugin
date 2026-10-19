-- Saved library sections. Presentation remains owned by Bookshelf; IDs stay
-- stable so existing shelf settings, Home references and gestures survive.
local M = { key = "orbitui_libraries", version = 1 }

function M.copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = M.copy(v) end
    return out
end

function M.path(path)
    if type(path) ~= "string" or path:sub(1, 1) ~= "/" or path:find("%z") then return nil end
    path = path:gsub("/+", "/"):gsub("/+$", "")
    for part in path:gmatch("[^/]+") do
        if part == "." or part == ".." then return nil end
    end
    return path ~= "" and path or "/"
end

function M.contains(file, root)
    file, root = M.path(file), M.path(root)
    return file and root and (root == "/" or file == root or file:sub(1, #root + 1) == root .. "/") or false
end

local function validId(value)
    return type(value) == "string" and value:match("^[a-z][a-z0-9_]*$")
        and value ~= "all" and value ~= "current"
end

function M.validate(config)
    assert(type(config) == "table" and config.version == M.version,
        "Unsupported OrbitUI library configuration; saved settings were not changed")
    assert(type(config.sections) == "table", "Missing library sections")
    local ids = {}
    for _, section in ipairs(config.sections) do
        assert(validId(section.key) and not ids[section.key], "Invalid or duplicate library ID")
        ids[section.key] = true
        assert(type(section.label) == "string" and section.label:match("%S"), "Missing library name")
        assert(type(section.roots) == "table" and #section.roots > 0, "Select a library folder")
        for _, root in ipairs(section.roots) do assert(M.path(root) == root, "Invalid library folder") end
        assert(type(section.chips) == "table" and #section.chips > 0, "Keep at least one shelf")
        local chips = {}
        for _, chip in ipairs(section.chips) do
            assert(validId(chip.key) and not chips[chip.key], "Invalid or duplicate shelf ID")
            chips[chip.key] = true
            assert(type(chip.label) == "string" and chip.label:match("%S"), "Missing shelf name")
            assert(type(chip.source) == "table" and type(chip.source.kind) == "string", "Missing shelf source")
            if chip.source.kind == "folder" then
                local path, included = M.path(chip.source.id), false
                for _, root in ipairs(section.roots) do included = included or M.contains(path, root) end
                assert(path == chip.source.id and included, "Shelf folder is outside its library")
            end
        end
    end
    return config
end

local function prepare(section)
    for _, chip in ipairs(section.chips) do
        chip.source = chip.source or { kind = chip.kind, id = chip.path }
        -- Compatibility view for component callers; the stored source is the
        -- same descriptor used by Bookshelf's native TabModel/repository.
        chip.kind, chip.path = chip.source.kind, chip.source.id
    end
    return section
end

function M.new(store, legacy, home, migrate_legacy)
    local api = {}
    local cached
    function api.config()
        local saved = store.read(M.key)
        if saved == nil then
            local sections = {}
            local existing = migrate_legacy and migrate_legacy()
                or (not migrate_legacy and store.wasPresent and store.wasPresent())
            if existing then
                sections = M.copy(legacy)
            elseif M.path(home) then
                sections = { { key = "library", label = "Library", roots = { M.path(home) },
                    icon = "nerd:F02D", chips = {
                        { key = "books", label = "Books", source = { kind = "folder", id = M.path(home) } },
                        { key = "latest", label = "Latest", source = { kind = "latest" } },
                        { key = "authors", label = "Authors", source = { kind = "authors" } },
                    } } }
            end
            for _, section in ipairs(sections) do prepare(section) end
            saved = M.validate({ version = M.version, sections = sections, next_id = 1 })
            -- Additive migration: never rewrite old profile settings or files.
            store.save(M.key, saved)
            store.flush()
        end
        if cached ~= saved then
            M.validate(saved)
            for _, section in ipairs(saved.sections) do prepare(section) end
            cached = saved
        end
        return cached
    end
    function api.list(include_disabled)
        local out = {}
        for _, section in ipairs(api.config().sections) do
            if include_disabled or section.enabled ~= false then out[#out + 1] = section end
        end
        return out
    end
    function api.get(key, include_disabled)
        for _, section in ipairs(api.list(include_disabled)) do
            if section.key == key then return section end
        end
    end
    function api.save(config)
        config = M.validate(M.copy(config))
        for _, section in ipairs(config.sections) do prepare(section) end
        store.save(M.key, config)
        store.flush()
        cached = nil
    end
    function api.edit(key, change)
        local config = M.copy(api.config())
        for _, section in ipairs(config.sections) do
            if section.key == key then
                change(section, config)
                api.save(config)
                return true
            end
        end
        return false
    end
    function api.add(label, root)
        root = assert(M.path(root), "Select a library folder")
        local config = M.copy(api.config())
        local n = tonumber(config.next_id) or 1
        while api.get("section_" .. n, true) do n = n + 1 end
        local key = "section_" .. n
        config.next_id = n + 1
        config.sections[#config.sections + 1] = { key = key, label = label,
            icon = "nerd:F02D", roots = { root }, chips = {
                { key = "books", label = "Books", source = { kind = "folder", id = root } },
            } }
        api.save(config)
        return key
    end
    function api.relocateRoot(key, old, path)
        path = assert(M.path(path), "Select a library folder")
        return api.edit(key, function(section)
            for i, root in ipairs(section.roots) do
                if M.contains(root, old) then section.roots[i] = M.path(path .. "/" .. root:sub(#old + 1)) end
            end
            for _, chip in ipairs(section.chips) do
                if chip.source.kind == "folder" and M.contains(chip.source.id, old) then
                    local suffix = chip.source.id:sub(#old + 1)
                    chip.source.id = M.path(path .. "/" .. suffix)
                end
            end
        end)
    end
    function api.matchFile(file)
        local best, length
        for _, section in ipairs(api.list()) do
            for _, root in ipairs(section.roots) do
                if M.contains(file, root) and (not length or #root > length) then
                    best, length = section.key, #root
                end
            end
        end
        return best
    end
    return api
end

return M
