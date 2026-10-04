package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Authors = require("core/orbitui_author_ornaments")
local Adapter = require("adapters/orbitui_ornaments")
local original_open, original_rename, original_remove = io.open, os.rename, os.remove
local files, fail_write, fail_read, fail_close, fail_rename, no_space
local source, dest = "/slot/assets/ornaments/Modernists/", "/settings/bookshelf/ornaments/Modernists/"
local marker = "/settings/orbitui/ornament-modernists-v1.installed"
local function fixture()
    files = {}
    for _, file in ipairs(Authors.files) do files[source .. file] = string.rep(file, 7000) end
    fail_write, fail_read, fail_close, fail_rename, no_space = false, false, false, false, false
end
package.loaded.datastorage = { getSettingsDir = function() return "/settings" end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path) return files[path] and "file" end }
package.loaded["lib/bookshelf_fs"] = { ensureDir = function() return not no_space end }
io.open = function(path, mode)
    if mode == "rb" and not files[path] then return nil, "missing input" end
    if mode == "wb" then files[path] = "" end
    local cursor, closed = 1, false
    return {
        read = function(_, size)
            if fail_read then return nil, "read failed" end
            if cursor > #files[path] then return nil end
            local text = files[path]:sub(cursor, cursor + size - 1)
            cursor = cursor + #text; return text
        end,
        write = function(self, text)
            if fail_write then return nil, "disk full" end
            files[path] = files[path] .. text; return self
        end,
        close = function()
            assert(not closed, "attempt to use a closed file")
            closed = true
            if fail_close then return nil, "close failed" end
            return true
        end,
    }
end
os.rename = function(from, to)
    if fail_rename then return nil, "rename failed" end
    files[to], files[from] = files[from], nil; return true
end
os.remove = function(path) files[path] = nil; return true end
local function seed() return Authors.seed("/slot", "/settings/bookshelf/ornaments") end

H.test("the active runtime seeds all artwork and notices byte-for-byte", function()
    fixture(); H.eq(seed(), true)
    for _, file in ipairs(Authors.files) do H.eq(files[dest .. file], files[source .. file]) end
    assert(files[marker])
end)
H.test("a completed seed never overwrites edits or resurrects deleted ornaments", function()
    files[dest .. "James Joyce.png"] = "user edit"
    files[dest .. "Virginia Woolf.png"] = nil
    H.eq(seed(), false)
    H.eq(files[dest .. "James Joyce.png"], "user edit")
    H.eq(files[dest .. "Virginia Woolf.png"], nil)
    for _, file in ipairs(Authors.files) do files[dest .. file] = nil end
    H.eq(seed(), false); H.eq(files[dest .. "James Joyce.png"], nil)
end)
H.test("pre-existing same-name pack files and metadata are preserved", function()
    fixture(); files[dest .. "ornaments.json"] = "custom placement"
    files[dest .. "James Joyce.png"] = "custom image"
    seed()
    H.eq(files[dest .. "ornaments.json"], "custom placement")
    H.eq(files[dest .. "James Joyce.png"], "custom image")
    H.eq(files[dest .. "Virginia Woolf.png"], files[source .. "Virginia Woolf.png"])
end)
for _, kind in ipairs({ "write", "read", "close", "rename", "directory", "missing" }) do
    H.test("failed " .. kind .. " cannot complete or truncate an installed file", function()
        fixture()
        if kind == "write" then fail_write = true end
        if kind == "read" then fail_read = true end
        if kind == "close" then fail_close = true end
        if kind == "rename" then fail_rename = true end
        if kind == "directory" then no_space = true end
        if kind == "missing" then files[source .. "James Joyce.png"] = nil end
        H.eq(pcall(seed), false); H.eq(files[marker], nil)
        H.eq(files[dest .. "James Joyce.png"], nil)
        for path in pairs(files) do assert(not path:match("%.orbitui%-tmp$")) end
        fail_write, fail_read, fail_close, fail_rename, no_space = false, false, false, false, false
        files[source .. "James Joyce.png"] = "complete retry image"
        H.eq(seed(), true)
        H.eq(files[dest .. "James Joyce.png"], "complete retry image")
    end)
end
H.test("an installation error cannot crash or repeatedly stall the ornament browser", function()
    fixture(); fail_write = true
    local warnings, calls = 0, 0
    package.loaded.logger = { warn = function() warnings = warnings + 1 end }
    local module = Adapter.wrap("lib/bookshelf_ornaments", {
        dir = function() return "/settings/bookshelf/ornaments" end,
        listAll = function() calls = calls + 1; return { "existing" }, { "old pack" } end,
    }, "/slot")
    for _ = 1, 3 do
        local all, packs = module.listAll()
        H.eq(all[1], "existing"); H.eq(packs[1], "old pack")
    end
    H.eq(calls, 3); H.eq(warnings, 1); H.eq(files[marker], nil)
end)
io.open, os.rename, os.remove = original_open, original_rename, original_remove
H.finish()
