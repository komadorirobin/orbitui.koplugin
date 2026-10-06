package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Authors = require("core/orbitui_author_ornaments")
local Adapter = require("adapters/orbitui_ornaments")
-- Default-caption migration uses JSON fixtures in test_author_info.
package.loaded["core/orbitui_author_info"] = { apply = function() return false end }
package.loaded["core/orbitui_kafka_update"] = { apply = function() return false end }
package.loaded["core/orbitui_mann_update"] = { apply = function() return false end }
package.loaded["core/orbitui_sculpture_updates"] = { apply = function() return false end }
package.loaded["core/orbitui_lispector_retirement"] = { apply = function() return false end }
-- Session ordering is exercised with the native deck in test_ornament_session.
package.loaded["lib/bookshelf_ornament_deck"] = { sync = function() end, shuffle = function() end }
local original_open, original_rename, original_remove = io.open, os.rename, os.remove
local files, fail_write, fail_read, fail_close, fail_rename, no_space
local source, dest = "/slot/assets/ornaments/Modernists/", "/settings/bookshelf/ornaments/Modernists/"
local marker = "/settings/orbitui/ornament-modernists-v1.installed"
local new_source, new_dest = "/slot/assets/ornaments/Authors/", "/settings/bookshelf/ornaments/Authors/"
local new_marker = "/settings/orbitui/ornament-authors-v1.installed"
local function fixture()
    files = {}
    for _, pack in ipairs(Authors.packs) do
        for _, file in ipairs(pack.files) do
            files["/slot/assets/ornaments/" .. pack.name .. "/" .. file] = string.rep(file, 7000)
        end
    end
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
    for _, pack in ipairs(Authors.packs) do
        for _, file in ipairs(pack.files) do
            H.eq(files["/settings/bookshelf/ornaments/" .. pack.name .. "/" .. file],
                files["/slot/assets/ornaments/" .. pack.name .. "/" .. file])
        end
        assert(files["/settings/orbitui/" .. pack.marker])
    end
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
H.test("alpha.14 upgrades add Authors without restoring or changing Modernists", function()
    fixture()
    files[marker] = "alpha.14 installed"
    files[dest .. "James Joyce.png"] = "custom Joyce"
    files[dest .. "ornaments.json"] = "disabled Woolf and custom sizes"
    H.eq(seed(), true)
    H.eq(files[marker], "alpha.14 installed")
    H.eq(files[dest .. "James Joyce.png"], "custom Joyce")
    H.eq(files[dest .. "Virginia Woolf.png"], nil)
    H.eq(files[dest .. "ornaments.json"], "disabled Woolf and custom sizes")
    H.eq(files[new_dest .. "Robert Musil.png"], files[new_source .. "Robert Musil.png"])
    H.eq(files[new_dest .. "Clarice Lispector.png"], nil)
    H.eq(files[new_dest .. "Franz Kafka.png"], files[new_source .. "Franz Kafka.png"])
    assert(files[new_marker])
end)
H.test("a deleted old pack stays deleted when the new pack is installed", function()
    fixture(); files[marker] = "old pack removed by user"
    H.eq(seed(), true)
    for _, file in ipairs(Authors.files) do H.eq(files[dest .. file], nil) end
    assert(files[new_dest .. "Thomas Mann.png"])
end)
H.test("new pack custom files and later deletions are preserved independently", function()
    fixture(); files[marker] = "old installed"
    files[new_dest .. "ornaments.json"] = "user metadata"
    files[new_dest .. "Robert Musil.png"] = "custom Musil"
    H.eq(seed(), true)
    H.eq(files[new_dest .. "ornaments.json"], "user metadata")
    H.eq(files[new_dest .. "Robert Musil.png"], "custom Musil")
    files[new_dest .. "August Strindberg.png"] = nil
    files[new_dest .. "Franz Kafka.png"] = nil
    H.eq(seed(), false); H.eq(files[new_dest .. "August Strindberg.png"], nil)
    H.eq(files[new_dest .. "Franz Kafka.png"], nil)
    for _, file in ipairs(Authors.packs[2].files) do files[new_dest .. file] = nil end
    H.eq(seed(), false); H.eq(files[new_dest .. "Clarice Lispector.png"], nil)
end)
H.test("an interrupted new pack installation does not roll back the old marker", function()
    fixture(); files[marker] = "old installed"
    files[dest .. "James Joyce.png"] = "user Joyce"
    files[new_source .. "Robert Musil.png"] = nil
    H.eq(pcall(seed), false)
    H.eq(files[marker], "old installed"); H.eq(files[new_marker], nil)
    H.eq(files[dest .. "James Joyce.png"], "user Joyce")
    files[new_source .. "Robert Musil.png"] = "complete retry image"
    files[new_dest .. "August Strindberg.png"] = "customized during partial install"
    H.eq(seed(), true)
    H.eq(files[new_dest .. "August Strindberg.png"], "customized during partial install")
    H.eq(files[new_dest .. "Robert Musil.png"], "complete retry image")
    assert(files[new_marker])
end)
H.test("Authors II is additive with independent marker and preserves older edits and deletions", function()
    fixture()
    files[marker], files[new_marker] = "old Modernists", "old Authors"
    files[dest .. "James Joyce.png"] = "custom Joyce"
    files[new_dest .. "ornaments.json"] = "custom sizes and captions"
    local extra = "/settings/bookshelf/ornaments/Authors II/"
    local extra_source = "/slot/assets/ornaments/Authors II/"
    local extra_marker = "/settings/orbitui/ornament-authors-ii-v1.installed"
    H.eq(seed(), true)
    H.eq(files[dest .. "James Joyce.png"], "custom Joyce")
    H.eq(files[dest .. "Virginia Woolf.png"], nil)
    H.eq(files[new_dest .. "Thomas Mann.png"], nil)
    H.eq(files[new_dest .. "ornaments.json"], "custom sizes and captions")
    H.eq(files[extra .. "Ernest Hemingway.png"], files[extra_source .. "Ernest Hemingway.png"])
    H.eq(files[extra .. "Italo Svevo.png"], files[extra_source .. "Italo Svevo.png"])
    assert(files[extra_marker])
    files[extra .. "Italo Svevo.png"] = nil
    files[extra .. "Ernest Hemingway.png"] = "custom Hemingway"
    files[extra .. "ornaments.json"] = "custom new metadata"
    H.eq(seed(), false)
    H.eq(files[extra .. "Italo Svevo.png"], nil)
    H.eq(files[extra .. "Ernest Hemingway.png"], "custom Hemingway")
    H.eq(files[extra .. "ornaments.json"], "custom new metadata")
end)
H.test("an interrupted Authors II seed retries without rewriting either older pack", function()
    fixture()
    files[marker], files[new_marker] = "old Modernists", "old Authors"
    local extra = "/settings/bookshelf/ornaments/Authors II/"
    local input = "/slot/assets/ornaments/Authors II/Italo Svevo.png"
    local extra_marker = "/settings/orbitui/ornament-authors-ii-v1.installed"
    files[input] = nil
    H.eq(pcall(seed), false)
    H.eq(files[extra_marker], nil)
    H.eq(files[marker], "old Modernists"); H.eq(files[new_marker], "old Authors")
    files[extra .. "Ernest Hemingway.png"] = "edited during failed copy"
    files[input] = "retry Svevo"
    H.eq(seed(), true)
    H.eq(files[extra .. "Ernest Hemingway.png"], "edited during failed copy")
    H.eq(files[extra .. "Italo Svevo.png"], "retry Svevo")
    assert(files[extra_marker])
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
    H.eq(calls, 3); H.eq(warnings, 3); H.eq(files[marker], nil)
end)
io.open, os.rename, os.remove = original_open, original_rename, original_remove
H.finish()
