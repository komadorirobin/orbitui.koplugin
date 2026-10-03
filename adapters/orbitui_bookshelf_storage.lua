-- Keep rollback-compatible paths until a separate storage migration is approved.
local M = {}
local function ds() return require("datastorage") end
local settings_names = {
    ["settings.lua"] = "bookshelf.lua",
    ["micromodule_data.lua"] = "bookshelf_micromodules.lua",
    ["hardcover_links.lua"] = "bookshelf_hardcover_links.lua",
    ["book_facts.sqlite3"] = "bookshelf_book_facts.sqlite3",
    ["hardcover.sqlite3"] = "bookshelf_hardcover.sqlite3",
}
local cache_names = {
    ["opds.sqlite3"] = "bookshelf_opds.sqlite3",
    ["opds.lua"] = "bookshelf_opds.lua",
    ["changelog.lua"] = "bookshelf_changelog.lua",
    ["hero_inflight"] = "bookshelf_hero_inflight",
    ["covers"] = "bookshelf_covers",
    ["hardcover"] = "bookshelf_hardcover",
    ["updater"] = "bookshelf_cache",
}
local function mapped(name, names)
    for key, old in pairs(names) do
        local suffix = name:sub(#key + 1)
        if name:sub(1, #key) == key and
                (suffix == "" or suffix:match("^[./%-]")) then
            return ds():getSettingsDir() .. "/" .. old .. suffix
        end
    end
end
local made = {}
local function ensureParent(path)
    local parent = path:match("^(.*)/[^/]+$")
    if made[parent] then return path end
    local ok, fs = pcall(require, "lib/bookshelf_fs")
    if ok and fs.ensureDir and fs.ensureDir(parent) then made[parent] = true end
    return path
end

M.paths = { preserveReaderSettings = true }
function M.paths.settingsDir() return ds():getSettingsDir() .. "/bookshelf" end
function M.paths.cacheDir() return ds():getDataDir() .. "/cache/bookshelf" end
function M.paths.settingsFile(name)
    return ensureParent(mapped(name, settings_names) or (M.paths.settingsDir() .. "/" .. name))
end
function M.paths.cacheFile(name)
    local path = mapped(name, cache_names)
    if name == "scaled_covers" or name:sub(1, 14) == "scaled_covers/" then
        path = ds():getDataDir() .. "/cache/bookshelf_covers" .. name:sub(14)
    end
    return ensureParent(path or (M.paths.cacheDir() .. "/" .. name))
end
M.migration = { run = function() end }

local reader_keys = {
    hero_regions = "bookshelf_hero_regions",
    status_in_reader = "bookshelf_status_in_reader",
    reader_status_h = "bookshelf_reader_status_h",
}

function M.wrapStore(store)
    local read, save, defer = store.read, store.save, store.saveDeferred
    local delete, flush, generation = store.delete, store.flush, store.generation
    local isTrue, nilOrTrue = store.isTrue, store.nilOrTrue
    local changed, dirty = 0, false
    local function write(key, value, deferred)
        G_reader_settings:saveSetting(reader_keys[key], value)
        changed, dirty = changed + 1, true
        if not deferred then
            G_reader_settings:flush()
            dirty = false
        end
    end
    function store.read(key, default)
        if not reader_keys[key] then return read(key, default) end
        local value = G_reader_settings:readSetting(reader_keys[key])
        if value == nil then return default end
        return value
    end
    function store.save(key, value)
        if reader_keys[key] then return write(key, value, false) end
        return save(key, value)
    end
    function store.saveDeferred(key, value)
        if reader_keys[key] then return write(key, value, true) end
        return defer(key, value)
    end
    function store.delete(key)
        if not reader_keys[key] then return delete(key) end
        G_reader_settings:delSetting(reader_keys[key])
        G_reader_settings:flush()
        changed, dirty = changed + 1, false
    end
    function store.flush()
        flush()
        if dirty then G_reader_settings:flush(); dirty = false end
    end
    function store.generation() return generation() + changed end
    function store.isTrue(key)
        if reader_keys[key] then return store.read(key) == true end
        return isTrue(key)
    end
    function store.nilOrTrue(key)
        if reader_keys[key] then local v = store.read(key); return v == nil or v == true end
        return nilOrTrue(key)
    end
    return store
end

return M
