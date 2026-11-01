local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local native = os.getenv("ORBITUI_NATIVE_SQLITE_DIR")
if not jit or not native then
    print("SKIP native EPUB tag index: set ORBITUI_NATIVE_SQLITE_DIR under LuaJIT")
    H.finish(); return
end
package.path = native .. "/?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[void *malloc(size_t); void free(void *);]]
package.loaded["ffi/posix_h"] = true
ffi.loadlib = function(name, version)
    return ffi.load(jit.os == "OSX" and name or ("lib" .. name .. ".so." .. version))
end
local SQL = require("lua-ljsqlite3/init")
local pipe = assert(io.popen("mktemp -d /tmp/orbitui-tag-index.XXXXXX"))
local directory = assert(pipe:read("*l")); assert(pipe:close())
assert(directory:match("^/tmp/orbitui%-tag%-index%.[%w]+$"))
local markers, current_dir, count = {}, nil, 0
package.loaded.datastorage = { getDataDir = function() return current_dir end }
package.loaded["libs/libkoreader-lfs"] = {
    mkdir = function(path) return os.execute("mkdir -p '" .. path .. "'") end,
    attributes = function(path, key)
        local f = io.open(path, "rb"); if not f then return nil end; f:close()
        return key == "mode" and "file" or { mode = "file" }
    end,
}
package.loaded["lib/bookshelf_keyed_cache"] = { new = function(namespace, version)
    H.eq(namespace, "orbitui_epub_tags"); H.eq(version, 1)
    return { read = function(key) return markers[key] end,
        write = function(key, value) markers[key] = value; return true end }
end }
local function module() return assert(loadfile(root .. "/adapters/orbitui_integrations.lua"))() end
local function fresh()
    count = count + 1; current_dir = directory .. "/case" .. count
    assert(os.execute("mkdir -p '" .. current_dir .. "'") == 0)
    markers = {}; package.loaded["lua-ljsqlite3/init"] = SQL
    return module()
end
local function dbpath() return current_dir .. "/cache/bookshelf/orbitui_epub_tag_index_v1.sqlite3" end
local tag = 'Åland & 日本語 "quoted", literal'
H.test("real SQLite index persists exact tags, empty results and replacement without genre conflation", function()
    local M = fresh()
    local index = assert(M.openEmbeddedTagIndex())
    index.put("/local/a.epub", "1:1:10", { tag, "Other" })
    index.put("/local/empty.epub", "2:2:20", {})
    assert(index.close())
    index = assert(module().openEmbeddedTagIndex())
    local rows = assert(index.prefetch({ "/local/a.epub", "/local/empty.epub", "/missing.epub" }, 1, tag))
    H.eq(rows["/local/a.epub"].matches, true); H.eq(rows["/local/a.epub"].stamp, "1:1:10")
    H.eq(rows["/local/empty.epub"].matches, false); H.eq(rows["/missing.epub"], nil)
    H.eq(index.prefetch({ "/local/a.epub" }, 1, "other")["/local/a.epub"].matches, false)
    index.put("/local/a.epub", "3:3:30", { "Replacement" }); assert(index.flush())
    H.eq(index.prefetch({ "/local/a.epub" }, 1, tag)["/local/a.epub"].matches, false)
    assert(index.close())
end)
H.test("index parameterization protects literal paths/tags and prefetch is bounded to 128 requested files", function()
    local M = fresh(); local index = assert(M.openEmbeddedTagIndex())
    local files = {}
    for i = 1, 1305 do
        files[i] = "/local/" .. i .. ".epub"; index.put(files[i], tostring(i), { tag })
        if i % 32 == 0 then assert(index.flush()) end
    end
    local attack = "/local/'; DROP TABLE files;--.epub"
    index.put(attack, "safe", { "x' OR 1=1 --" }); assert(index.flush())
    local rows = assert(index.prefetch(files, 1, tag)); local n = 0; for _ in pairs(rows) do n = n + 1 end
    H.eq(n, 128); H.eq(rows[files[129]], nil)
    rows = assert(index.prefetch({ attack, files[1] }, 1, "x' OR 1=1 --"))
    H.eq(rows[attack].matches, true); H.eq(rows[files[1]].matches, false)
    H.eq(index.prefetch({ "/other-profile/not-requested.epub" }, 1, tag)[attack], nil)
    assert(index.close())
end)
H.test("real SQLite combines literal AND/OR predicates in one bounded batch with no duplicate rows", function()
    local M = fresh(); local index = assert(M.openEmbeddedTagIndex())
    local names = { tag, "x' OR 1=1 --" }
    index.put("/a.epub", "a", names); index.put("/b.epub", "b", { tag }); index.put("/c.epub", "c", {})
    assert(index.flush())
    local rule = { version = 1, mode = "all", tags = names }
    local rows = assert(index.prefetch({ "/a.epub", "/b.epub", "/c.epub" }, 1, rule))
    H.eq(rows["/a.epub"].matches, true); H.eq(rows["/b.epub"].matches, false); H.eq(rows["/c.epub"].matches, false)
    rule.mode = "any"
    rows = assert(index.prefetch({ "/a.epub", "/b.epub", "/c.epub" }, 1, rule))
    H.eq(rows["/a.epub"].matches, true); H.eq(rows["/b.epub"].matches, true); H.eq(rows["/c.epub"].matches, false)
    rule.tags = { "ÅLAND & 日本語" }; H.eq(index.prefetch({ "/a.epub" }, 1, rule)["/a.epub"].matches, false)
    assert(index.close())
end)
H.test("index manager stamp-only batches reuse known tagless rows without a tag predicate", function()
    local M = fresh(); local index = assert(M.openEmbeddedTagIndex())
    index.put("/a.epub", "a", { tag }); index.put("/b.epub", "b", {})
    assert(index.flush())
    local rows = assert(index.prefetch({ "/a.epub", "/b.epub", "/missing.epub" }, 1))
    H.eq(rows["/a.epub"].stamp, "a"); H.eq(rows["/b.epub"].stamp, "b")
    H.eq(rows["/missing.epub"], nil); H.eq(rows["/a.epub"].matches, false)
    assert(index.close())
end)
H.test("a missing epoch marker cannot revive rows from any previous index generation", function()
    local M = fresh(); local index = assert(M.openEmbeddedTagIndex())
    index.put("/local/a.epub", "same", { "Old" }); assert(index.close())
    markers = {}
    index = assert(module().openEmbeddedTagIndex())
    H.eq(markers.index_epoch_v1.epoch, 2)
    H.eq(index.prefetch({ "/local/a.epub" }, 1, "Old")["/local/a.epub"], nil)
    assert(index.close())
end)
H.test("failed commit rolls back atomically and durable epoch prevents old same-stamp rows after reopen", function()
    local M = fresh(); local index = assert(M.openEmbeddedTagIndex())
    index.put("/local/a.epub", "same", { "Old" }); assert(index.close())
    package.loaded["lua-ljsqlite3/init"] = { open = function(path)
        local db = SQL.open(path)
        return { exec = function(_, text) if text == "COMMIT;" then error("injected commit failure") end; return db:exec(text) end,
            prepare = function(_, text) return db:prepare(text) end, close = function() return db:close() end }
    end }
    index = assert(M.openEmbeddedTagIndex())
    index.put("/local/a.epub", "same", { "New" }); H.eq(index.flush(), false)
    H.eq(M.openEmbeddedTagIndex(), nil); H.eq(markers.index_epoch_v1.epoch, 2)
    package.loaded["lua-ljsqlite3/init"] = SQL
    local raw = SQL.open(dbpath())
    H.eq(tonumber(raw:rowexec("SELECT COUNT(*) FROM tags WHERE tag='Old'")), 1)
    H.eq(tonumber(raw:rowexec("SELECT COUNT(*) FROM tags WHERE tag='New'")), 0); raw:close()
    index = assert(module().openEmbeddedTagIndex())
    H.eq(index.prefetch({ "/local/a.epub" }, 1, "Old")["/local/a.epub"], nil)
    index.put("/local/a.epub", "same", { "New" }); assert(index.close())
end)
H.test("corrupt or locked index is not deleted or confused with a complete empty result", function()
    local M = fresh(); local index = assert(M.openEmbeddedTagIndex()); assert(index.close())
    local owner = SQL.open(dbpath()); owner:exec("BEGIN IMMEDIATE;")
    index = assert(M.openEmbeddedTagIndex())
    index.put("/local/a.epub", "stamp", { tag }); H.eq(index.flush(), false)
    owner:exec("ROLLBACK;"); owner:close()
    H.eq(markers.index_epoch_v1.epoch, 2)
    M = fresh(); index = assert(M.openEmbeddedTagIndex()); assert(index.close())
    local raw = SQL.open(dbpath()); raw:exec("ALTER TABLE files RENAME TO incompatible;"); raw:close()
    -- A read failure must return nil, never {} (which would look like no tags).
    index = assert(M.openEmbeddedTagIndex())
    local db = SQL.open(dbpath()); db:exec("DROP TABLE files;"); db:close()
    H.eq(index.prefetch({ "/local/a.epub" }, 1, tag), nil)
    H.eq(M.openEmbeddedTagIndex(), nil)
    local f = assert(io.open(dbpath(), "rb")); assert(f:seek("end") > 0); f:close()
end)
H.finish()
