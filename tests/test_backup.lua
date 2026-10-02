package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Backup = require("core/orbitui_backup")
local original_open, original_rename, original_remove = io.open, os.rename, os.remove
local files, dirs, fail_write, fail_read, fail_close
local base = "/data/settings/orbitui/before-first-run"

local function fixture()
    files = {
        ["/data/settings/bookshelf.lua"] = "shelf-settings",
        ["/data/settings/bookshelf_hardcover_links.lua"] = "link-data",
        ["/data/settings/simpleui/sui_settings.lua"] = "home-settings",
        ["/data/settings.reader.lua"] = "global-settings",
        ["/data/settings/other.lua"] = "unrelated",
    }
    dirs = { ["/data/settings"] = true }
    fail_write, fail_read, fail_close = false, false, false
end
package.loaded.datastorage = {
    getSettingsDir = function() return "/data/settings" end,
    getDataDir = function() return "/data" end,
}
package.loaded["libs/libkoreader-lfs"] = {
    attributes = function(path)
        return dirs[path] and "directory" or files[path] and "file" or nil
    end,
    mkdir = function(path) dirs[path] = true; return true end,
    dir = function(path)
        local names = { ".", ".." }
        for name in pairs(files) do
            local relative = name:sub(#path + 2)
            if name:sub(1, #path + 1) == path .. "/" and not relative:find("/", 1, true) then
                names[#names + 1] = relative
            end
        end
        local i = 0
        return function() i = i + 1; return names[i] end
    end,
}
G_reader_settings = { file = "/data/settings.reader.lua" }
io.open = function(path, mode)
    if mode == "rb" and files[path] == nil then return nil, "missing" end
    local position = 1
    if mode == "wb" then files[path] = "" end
    return {
        read = function(_, size)
            if fail_read then return nil, "read failed" end
            if position > #files[path] then return nil end
            local data = files[path]:sub(position, position + size - 1)
            position = position + #data
            return data
        end,
        write = function(self, ...)
            if fail_write then return nil, "disk full" end
            files[path] = files[path] .. table.concat({ ... })
            return self
        end,
        close = function() if fail_close then return nil, "close failed" end; return true end,
    }
end
os.rename = function(from, to) files[to], files[from] = files[from], nil; return true end
os.remove = function(path) files[path] = nil; return true end

H.test("settings are copied before startup without changing originals", function()
    fixture()
    local before = {}
    for k, v in pairs(files) do before[k] = v end
    H.eq(Backup.ensure(), base)
    local marker = assert(files[base .. "/COMPLETE"])
    local attempt = assert(marker:match("\n([^\n]+)\n"))
    H.eq(files[base .. "/" .. attempt .. "/bookshelf.lua"], "shelf-settings")
    H.eq(files[base .. "/" .. attempt .. "/simpleui-settings.lua"], "home-settings")
    H.eq(files[base .. "/" .. attempt .. "/bookshelf_hardcover_links.lua"], "link-data")
    H.eq(files[base .. "/" .. attempt .. "/settings.reader.lua"], "global-settings")
    H.eq(files[base .. "/" .. attempt .. "/other.lua"], nil)
    for k, v in pairs(before) do H.eq(files[k], v) end
end)
H.test("a completed snapshot is never overwritten", function()
    local marker = files[base .. "/COMPLETE"]
    files["/data/settings/bookshelf.lua"] = "new-settings"
    Backup.ensure()
    H.eq(files[base .. "/COMPLETE"], marker)
    local attempt = marker:match("\n([^\n]+)\n")
    H.eq(files[base .. "/" .. attempt .. "/bookshelf.lua"], "shelf-settings")
end)
H.test("a failed write cannot mark a snapshot complete", function()
    fixture()
    fail_write = true
    H.eq(pcall(Backup.ensure), false)
    H.eq(files[base .. "/COMPLETE"], nil)
    H.eq(files["/data/settings/bookshelf.lua"], "shelf-settings")
end)
H.test("retrying an incomplete backup uses a separate attempt", function()
    fail_write = false
    Backup.ensure()
    local attempts = 0
    for path in pairs(dirs) do if path:find(base .. "/attempt-", 1, true) == 1 then attempts = attempts + 1 end end
    H.eq(attempts, 2)
    assert(files[base .. "/COMPLETE"])
end)
H.test("read errors do not become a successful truncated backup", function()
    fixture()
    fail_read = true
    H.eq(pcall(Backup.ensure), false)
    H.eq(files[base .. "/COMPLETE"], nil)
end)
H.test("close errors do not become a completed backup", function()
    fixture()
    fail_close = true
    H.eq(pcall(Backup.ensure), false)
    H.eq(files[base .. "/COMPLETE"], nil)
end)
io.open, os.rename, os.remove = original_open, original_rename, original_remove
H.finish()
