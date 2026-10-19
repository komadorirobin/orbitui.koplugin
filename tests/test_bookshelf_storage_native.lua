package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local files, writes, moves, globals, Storage, Store
local dir = "/reader/settings"
package.loaded.datastorage = {
    getSettingsDir = function() return dir end, getDataDir = function() return "/reader" end,
}
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path)
    if files[path] then return "file" end
end }
package.loaded["lib/bookshelf_fs"] = { ensureDir = function() return true end }
package.loaded.logger = { dbg = function() end }
local function settings(path)
    local data = files[path] or files[path .. ".old"] or {}
    return { data = data, readSetting = function(_, key, default)
        if data[key] == nil then return default end
        return data[key]
    end, saveSetting = function(_, key, value) data[key] = value end,
        delSetting = function(_, key) data[key] = nil end,
        flush = function() files[path] = data; writes[path] = true end,
        isTrue = function(_, key) return data[key] == true end,
        nilOrTrue = function(_, key) return data[key] == nil or data[key] == true end }
end
package.loaded.luasettings = { open = function(_, path) return settings(path) end }
local function fixture(old, suffix)
    files, writes, moves = {}, {}, 0
    globals = { bookshelf_status_in_reader = false }
    files.reader = globals
    G_reader_settings = settings("reader")
    local prefs = { migrated = true, aux_data_relocated_v2 = true, reader_keys_moved = true,
        view_mode = "list", status_in_reader = true, reader_status_h = 42,
        hero_regions = { "clock" }, tabs = { "my-shelf" }, ornament_frequency = 2 }
    files[dir .. "/bookshelf/settings.lua" .. (suffix or "")] = prefs
    files[dir .. "/bookshelf/hardcover_links.lua"] = { hardcover_links = { linked = true } }
    if old then files[dir .. "/bookshelf.lua" .. (old == "backup" and ".old" or "")] = {
        migrated = true, aux_data_relocated_v2 = true, view_mode = "grid" } end
    for _, name in ipairs({ "adapters/orbitui_bookshelf_storage", "lib/bookshelf_settings_store",
        "lib/bookshelf_micromodule_store" }) do package.loaded[name] = nil end
    Storage = require("adapters/orbitui_bookshelf_storage")
    package.loaded["lib/bookshelf_paths"] = Storage.paths
    Store = Storage.wrapStore(require("lib/bookshelf_settings_store"))
    return prefs
end
H.test("native Bookshelf settings, links, caches and SQLite companions stay at their existing paths", function()
    fixture()
    for _, name in ipairs({ "settings.lua", "settings.lua.old", "hardcover_links.lua", "micromodule_data.lua",
        "book_facts.sqlite3-wal", "hardcover.sqlite3-shm", "ornaments/custom.png" }) do
        H.eq(Storage.paths.settingsFile(name), dir .. "/bookshelf/" .. name)
    end
    for _, name in ipairs({ "opds.lua", "opds.sqlite3-wal", "scaled_covers/a.jpg", "covers/a.jpg", "updater" }) do
        H.eq(Storage.paths.cacheFile(name), "/reader/cache/bookshelf/" .. name)
    end
    local rename = os.rename
    os.rename = function() moves = moves + 1; error("No moves allowed") end
    Storage.migration.run()
    os.rename = rename
    H.eq(moves, 0); H.eq(Store.read("view_mode"), "list")
    assert(Store.read("hardcover_links").linked)
    H.eq(Store.read("ornament_frequency"), 2)
    H.eq(Store.read("tabs")[1], "my-shelf")
    H.eq(files[dir .. "/bookshelf.lua"], nil)
end)
H.test("native reader-line settings are not replaced by legacy global values and edits remain native", function()
    fixture()
    H.eq(Store.view():readSetting("bookshelf_status_in_reader"), true)
    H.eq(Store.read("reader_status_h"), 42)
    Store.save("reader_status_h", 55)
    Store.save("view_mode", "spines")
    H.eq(files[dir .. "/bookshelf/settings.lua"].reader_status_h, 55)
    H.eq(files[dir .. "/bookshelf/settings.lua"].view_mode, "spines")
    H.eq(files[dir .. "/bookshelf.lua"], nil)
    assert(writes[dir .. "/bookshelf/settings.lua"])
end)
H.test("a native .old backup selects the same layout and old OrbitUI settings win ambiguous layouts", function()
    fixture(nil, ".old"); H.eq(Store.read("view_mode"), "list")
    H.eq(Storage.paths.settingsFile("settings.lua"), dir .. "/bookshelf/settings.lua")
    for _, old in ipairs({ "main", "backup" }) do
        local native = fixture(old)
        H.eq(Store.read("view_mode"), "grid")
        H.eq(Store.read("status_in_reader"), false)
        Store.save("view_mode", "spines")
        H.eq(native.view_mode, "list")
        H.eq(files[dir .. "/bookshelf.lua"].view_mode, "spines")
        H.eq(writes[dir .. "/bookshelf/settings.lua"], nil)
    end
end)
H.test("a fresh install keeps the established OrbitUI layout and does not change layout mid-session", function()
    fixture()
    -- Reload before resolving paths, with no component preferences at all.
    files = { reader = globals }
    package.loaded["adapters/orbitui_bookshelf_storage"] = nil
    Storage = require("adapters/orbitui_bookshelf_storage")
    H.eq(Storage.paths.settingsFile("settings.lua"), dir .. "/bookshelf.lua")
    files[dir .. "/bookshelf/settings.lua"] = {}
    H.eq(Storage.paths.settingsFile("settings.lua"), dir .. "/bookshelf.lua")
end)
H.finish()
