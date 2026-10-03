package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = H.root()
package.loaded.datastorage = {
    getSettingsDir = function() return "/reader/settings" end,
    getDataDir = function() return "/reader" end,
}
local ensures = {}
package.preload["lib/bookshelf_fs"] = function() return { ensureDir = function(path)
    ensures[path] = (ensures[path] or 0) + 1
    return true
end } end
package.loaded.logger = { dbg = function() end }
local files, flushes = {}, {}
local function settings(path)
    local data = files[path] or {}
    files[path] = data
    return {
        data = data,
        readSetting = function(_, key, default)
            if data[key] == nil then return default end
            return data[key]
        end,
        saveSetting = function(_, key, value) data[key] = value end,
        delSetting = function(_, key) data[key] = nil end,
        flush = function() flushes[path] = (flushes[path] or 0) + 1 end,
        isTrue = function(_, key) return data[key] == true end,
        nilOrTrue = function(_, key) return data[key] == nil or data[key] == true end,
    }
end
package.loaded.luasettings = { open = function(_, path) return settings(path) end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path, key)
    if key == "mode" and files[path] then return "file" end
end }
G_reader_settings = settings("reader")
G_reader_settings:saveSetting("bookshelf_status_in_reader", false)
G_reader_settings:saveSetting("bookshelf_reader_status_h", 30)
G_reader_settings:saveSetting("bookshelf_hero_regions", { "clock" })
files["/reader/settings/bookshelf.lua"] = {
    migrated = true, aux_data_relocated_v2 = true, view_mode = "grid",
}
local links = { ["/books/a.epub"] = { book_id = 10, edition_id = 20 } }
files["/reader/settings/bookshelf_hardcover_links.lua"] = { hardcover_links = links }
require("core/orbitui_runtime").install(root)
local Paths = require("lib/bookshelf_paths")
local Store = require("lib/bookshelf_settings_store")

H.test("embedded paths preserve all existing files and SQLite companions", function()
    local cases = {
        { "settingsFile", "settings.lua", "/reader/settings/bookshelf.lua" },
        { "settingsFile", "micromodule_data.lua", "/reader/settings/bookshelf_micromodules.lua" },
        { "settingsFile", "hardcover_links.lua.old", "/reader/settings/bookshelf_hardcover_links.lua.old" },
        { "settingsFile", "book_facts.sqlite3-wal", "/reader/settings/bookshelf_book_facts.sqlite3-wal" },
        { "settingsFile", "hardcover.sqlite3-shm", "/reader/settings/bookshelf_hardcover.sqlite3-shm" },
        { "cacheFile", "opds.sqlite3", "/reader/settings/bookshelf_opds.sqlite3" },
        { "cacheFile", "opds.lua", "/reader/settings/bookshelf_opds.lua" },
        { "cacheFile", "changelog.lua", "/reader/settings/bookshelf_changelog.lua" },
        { "cacheFile", "hero_inflight", "/reader/settings/bookshelf_hero_inflight" },
        { "cacheFile", "covers/a.jpg", "/reader/settings/bookshelf_covers/a.jpg" },
        { "cacheFile", "hardcover/a.jpg", "/reader/settings/bookshelf_hardcover/a.jpg" },
        { "cacheFile", "updater", "/reader/settings/bookshelf_cache" },
        { "cacheFile", "scaled_covers", "/reader/cache/bookshelf_covers" },
        { "cacheFile", "scaled_covers/a.jpg", "/reader/cache/bookshelf_covers/a.jpg" },
        { "settingsFile", "ornaments/x.svg", "/reader/settings/bookshelf/ornaments/x.svg" },
        { "cacheFile", "new-feature", "/reader/cache/bookshelf/new-feature" },
    }
    for _, row in ipairs(cases) do H.eq(Paths[row[1]](row[2]), row[3]) end
    H.eq(Paths.settingsDir(), "/reader/settings/bookshelf")
    H.eq(Paths.cacheDir(), "/reader/cache/bookshelf")
    for _ = 1, 10 do Paths.settingsFile("hardcover_links.lua") end
    H.eq(ensures["/reader/settings"], 1, "do not stat the same directory on every lookup")
end)
H.test("startup migration neither renames files nor splits existing stores", function()
    local rename = os.rename
    os.rename = function() error("unexpected storage migration") end
    require("lib/bookshelf_storage_move").run()
    os.rename = rename
    H.eq(Store.read("view_mode"), "grid")
    H.eq(Store.read("hardcover_links"), links)
    H.eq(files["/reader/settings/bookshelf/settings.lua"], nil)
    H.eq(files["/reader/settings/bookshelf/hardcover_links.lua"], nil)
    H.eq(files["/reader/settings/bookshelf.lua"].reader_keys_moved, nil)
    H.eq(Store.view():readSetting("bookshelf_status_in_reader"), false)
    H.eq(G_reader_settings:readSetting("bookshelf_reader_status_h"), 30)
end)
H.test("edits stay readable by the previous OrbitUI and external header patches", function()
    local g = Store.generation()
    Store.save("status_in_reader", true)
    H.eq(G_reader_settings:readSetting("bookshelf_status_in_reader"), true)
    H.eq(Store.isTrue("status_in_reader"), true)
    H.eq(Store.generation(), g + 1)
    Store.save("view_mode", "list")
    H.eq(files["/reader/settings/bookshelf.lua"].view_mode, "list")
    local updated = { ["/books/b.epub"] = { book_id = 30, edition_id = 40 } }
    Store.save("hardcover_links", updated)
    H.eq(files["/reader/settings/bookshelf_hardcover_links.lua"].hardcover_links, updated)
    H.eq(Store.generation(), g + 3)
end)
H.test("deferred status edits flush once and deletion preserves default semantics", function()
    local count = flushes.reader
    Store.saveDeferred("reader_status_h", 40)
    Store.saveDeferred("hero_regions", { "clock", "battery" })
    H.eq(flushes.reader, count)
    H.eq(Store.view():readSetting("bookshelf_reader_status_h"), 40)
    Store.flush()
    H.eq(flushes.reader, count + 1)
    Store.flush()
    H.eq(flushes.reader, count + 1)
    Store.delete("status_in_reader")
    H.eq(Store.isTrue("status_in_reader"), false)
    H.eq(Store.nilOrTrue("status_in_reader"), true)
    H.eq(Store.read("status_in_reader", "default"), "default")
    G_reader_settings:saveSetting("bookshelf_status_in_reader", false)
    H.eq(Store.nilOrTrue("status_in_reader"), false)
end)
H.finish()
