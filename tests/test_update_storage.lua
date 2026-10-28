package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
-- Exercise the actual collector, manifest validator, Lua parser and bootstrap
-- records on an isolated in-memory filesystem. No reader/user path is touched.
local nodes, manifests, serial = {}, {}, 0
local prefix = "/orbitui-storage-fixture/"
local original_open, original_loadfile = io.open, loadfile
local original_remove, original_rename = os.remove, os.rename
local on_remove, on_rename
local function digest(data)
    local n = 5381
    for i = 1, #data do n = (n * 33 + data:byte(i)) % 4294967296 end
    return string.rep(string.format("%08x", n), 8)
end
local function access(path)
    local parent = path
    while parent do
        assert(not nodes[parent] or nodes[parent].mode ~= "link", "Attempt to follow a symlink: " .. path)
        parent = parent:match("^(.*)/[^/]+$")
    end
    return nodes[path]
end
local function mkdir(path)
    if nodes[path] then assert(nodes[path].mode == "directory"); return true end
    local parent = path:match("^(.*)/[^/]+$")
    if parent and parent ~= "" then mkdir(parent) end
    nodes[path] = { mode = "directory" }
    return true
end
local function write(path, data)
    mkdir(assert(path:match("^(.*)/[^/]+$")))
    nodes[path] = { mode = "file", data = data }
end
local function read(path)
    local node = assert(access(path), path)
    assert(node.mode == "file")
    return node.data
end
local function listing(path)
    assert(access(path).mode == "directory")
    local entries = {}
    for name in pairs(nodes) do
        if name:sub(1, #path + 1) == path .. "/" then
            local child = name:sub(#path + 2)
            if not child:find("/", 1, true) then entries[#entries + 1] = child end
        end
    end
    table.sort(entries)
    return entries
end
local fs = {}
function fs.symlinkattributes(path, key)
    local node = nodes[path]
    if not node then return end
    local a = { mode = node.mode, size = node.data and #node.data or 0 }
    return key and a[key] or a
end
fs.mkdir = mkdir
function fs.rmdir(path)
    if not nodes[path] or nodes[path].mode ~= "directory" or #listing(path) ~= 0 then return nil end
    nodes[path] = nil
    return true
end
function fs.dir(path)
    local entries, i = listing(path), 0
    return function() i = i + 1; return entries[i] end
end
io.open = function(path, mode)
    if path:sub(1, #prefix) ~= prefix then return original_open(path, mode) end
    assert(mode == "rb", "Collector must not write activation/user records")
    local node = access(path)
    if not node then return nil, "missing", 2 end
    assert(node.mode == "file")
    local f = {}
    function f:read(limit) return node.data:sub(1, limit) end
    function f:close() return true end
    return f
end
loadfile = function(path)
    if path:sub(1, #prefix) ~= prefix then return original_loadfile(path) end
    return (loadstring or load)(read(path), "@" .. path)
end
os.remove = function(path)
    if path:sub(1, #prefix) ~= prefix then return original_remove(path) end
    if on_remove then on_remove(path) end
    assert(nodes[path] and nodes[path].mode == "file")
    nodes[path] = nil
    return true
end
os.rename = function(source, target)
    if source:sub(1, #prefix) ~= prefix then return original_rename(source, target) end
    assert(nodes[source] and not nodes[target])
    local moves = {}
    for path, node in pairs(nodes) do
        if path == source or path:sub(1, #source + 1) == source .. "/" then
            moves[#moves + 1] = { path, target .. path:sub(#source + 1), node }
        end
    end
    for _, item in ipairs(moves) do nodes[item[1]] = nil; nodes[item[2]] = item[3] end
    if on_rename then on_rename(source, target) end
    return true
end
package.loaded["libs/libkoreader-lfs"] = fs
package.loaded.rapidjson = { decode = function(data) return assert(manifests[data], "Invalid JSON") end }
local Boot = require("orbitui_bootstrap")
local OTA = dofile("core/orbitui_ota.lua")
OTA.hashFile = function(path) return digest(read(path)) end
local current, previous, obsolete = string.rep("a", 64), string.rep("b", 64), string.rep("c", 64)
local required = { "VERSION", "main.lua", "_meta.lua", "orbitui_bootstrap.lua", "core/orbitui_plugin.lua",
    "core/orbitui_runtime.lua", "core/orbitui_ota.lua", "adapters/orbitui_updates.lua",
    "components/bookshelf/main.lua", "components/simpleui/main.lua", "assets/ca-bundle.crt", "LICENSE" }
local function runtime(path, version)
    serial = serial + 1
    local token = "manifest-" .. serial
    local manifest = { schema = 1, bootstrap_api = 1, version = version, files = {} }
    for _, name in ipairs(required) do
        local data = name == "VERSION" and version .. "\n" or "error('candidate code must never execute')\n"
        write(path .. "/" .. name, data)
        manifest.files[#manifest.files + 1] = { path = name, size = #data, sha256 = digest(data) }
    end
    manifests[token] = manifest
    write(path .. "/manifest.json", token)
    return manifest
end
local function point(c, active, rollback, pending)
    write(c.root .. "/.orbitui-active", active .. "\n" .. rollback .. "\n" .. (pending and "1" or "0") .. "\n")
end
local function fixture()
    serial = serial + 1
    local root = prefix .. serial .. "/orbitui.koplugin"
    runtime(root, "1.0.0")
    runtime(Boot.path(root, current), "3.0.0")
    runtime(Boot.path(root, previous), "2.0.0")
    local m = runtime(Boot.path(root, obsolete), "1.5.0")
    local c = { root = root, runtime = Boot.path(root, current), slot = current,
        version = "3.0.0", _orbitui_storage_ready = true }
    point(c, current, previous, false)
    write(root .. "/settings/reading-data", "keep reading position and links")
    write(root .. "/cache/covers", "keep covers")
    return c, m
end
local function snapshot(path)
    local out = {}
    for name, node in pairs(nodes) do
        if name == path or name:sub(1, #path + 1) == path .. "/" then
            out[#out + 1] = name .. "\0" .. node.mode .. "\0" .. (node.data or "")
        end
    end
    table.sort(out)
    return table.concat(out, "\n")
end
local function gc(c) return c.root .. "/.orbitui-versions/.orbitui-gc-" .. obsolete end

H.test("healthy cleanup removes one exact obsolete runtime and preserves factory/current/rollback/user data", function()
    local c = fixture()
    local root, active, rollback = snapshot(c.root .. "/settings"), snapshot(c.runtime), snapshot(Boot.path(c.root, previous))
    local factory, cache, selection = read(c.root .. "/VERSION"), snapshot(c.root .. "/cache"), Boot.read(c.root .. "/.orbitui-active")
    local size = 0
    -- Count only this managed obsolete slot.
    local old = Boot.path(c.root, obsolete)
    for path, node in pairs(nodes) do
        if path:sub(1, #old + 1) == old .. "/" and node.data then size = size + #node.data end
    end
    local result = OTA.cleanup(c)
    H.eq(result.removed, 1); H.eq(result.bytes, size)
    H.eq(nodes[old], nil); H.eq(nodes[gc(c)], nil)
    H.eq(snapshot(c.runtime), active); H.eq(snapshot(Boot.path(c.root, previous)), rollback)
    H.eq(snapshot(c.root .. "/settings"), root); H.eq(snapshot(c.root .. "/cache"), cache)
    H.eq(read(c.root .. "/VERSION"), factory); H.eq(Boot.read(c.root .. "/.orbitui-active"), selection)
    H.eq(OTA.cleanup(c).removed, 0)
end)
H.test("cleanup is bounded to one runtime per startup call and preserves equal/newer prepared versions", function()
    local c = fixture()
    local other, future, equal = string.rep("d", 64), string.rep("e", 64), string.rep("f", 64)
    runtime(Boot.path(c.root, other), "1.6.0")
    runtime(Boot.path(c.root, future), "4.0.0")
    runtime(Boot.path(c.root, equal), "3.0.0")
    H.eq(OTA.cleanup(c).removed, 1)
    assert(nodes[Boot.path(c.root, other)])
    H.eq(OTA.cleanup(c).removed, 1)
    assert(nodes[Boot.path(c.root, future)] and nodes[Boot.path(c.root, equal)])
end)
H.test("pending, stale, unconfirmed and recovered starts cannot collect anything", function()
    for _, change in ipairs({
        function(c) c._orbitui_storage_ready = nil end,
        function(c) point(c, current, previous, true) end,
        function(c) point(c, previous, current, false) end,
        function(c) c.runtime = c.root end,
        function(c) c.version = "9.0.0" end,
        function(c) c.notice = "Recovered interrupted startup" end,
    }) do
        local c = fixture(); change(c)
        local before = snapshot(c.root)
        H.eq(OTA.cleanup(c).removed, 0); H.eq(snapshot(c.root), before)
    end
end)
H.test("missing rollback, bad selection and unsafe install/version roots fail closed", function()
    for _, change in ipairs({
        function(c) nodes[Boot.path(c.root, previous) .. "/VERSION"] = nil end,
        function(c) write(c.root .. "/.orbitui-active", "broken pointer") end,
        function(c) nodes[c.root .. "/.orbitui-active"] = { mode = "link" } end,
        function(c) nodes[c.root .. "/.orbitui-versions"] = { mode = "link" } end,
        function(c) nodes[c.root] = { mode = "link" } end,
    }) do
        local c = fixture(); change(c)
        local before = snapshot(c.root)
        assert(not pcall(OTA.cleanup, c)); H.eq(snapshot(c.root), before)
    end
end)
H.test("modified, incomplete, unlisted, incompatible or linked snapshots are never renamed or removed", function()
    for _, change in ipairs({
        function(c) write(Boot.path(c.root, obsolete) .. "/notes.txt", "user data") end,
        function(c) mkdir(Boot.path(c.root, obsolete) .. "/custom-empty-directory") end,
        function(c) write(Boot.path(c.root, obsolete) .. "/core/orbitui_plugin.lua", "return 'custom'\n") end,
        function(c) nodes[Boot.path(c.root, obsolete) .. "/LICENSE"] = nil end,
        function(c) write(Boot.path(c.root, obsolete) .. "/manifest.json", "bad JSON") end,
        function(_, m) m.bootstrap_api = 2 end,
        function(_, m) m.version = "invalid-version" end,
        function(_, m) m.files[1].path = "../outside" end,
        function(_, m) m.files[2].sha256 = string.rep("0", 64) end,
        function(c) nodes[Boot.path(c.root, obsolete) .. "/assets/ca-bundle.crt"] = { mode = "link" } end,
        function(c) nodes[Boot.path(c.root, obsolete) .. "/assets"] = { mode = "link" } end,
        function(c) nodes[Boot.path(c.root, obsolete) .. "/manifest.json"] = { mode = "link" } end,
        function(c) nodes[Boot.path(c.root, obsolete)] = { mode = "link" } end,
    }) do
        local c, m = fixture(); change(c, m)
        local before = snapshot(c.root)
        local result = OTA.cleanup(c)
        H.eq(result.removed, 0); H.eq(result.bytes, 0); H.eq(result.skipped, 1)
        H.eq(snapshot(c.root), before)
    end
end)
H.test("unknown names and factory aliases are not cleanup candidates", function()
    local c = fixture()
    for _, name in ipairs({ "factory", "backup", string.rep("A", 64), string.rep("0", 63) }) do
        runtime(c.root .. "/.orbitui-versions/" .. name, "0.1.0")
    end
    H.eq(OTA.cleanup(c).removed, 1)
    for _, name in ipairs({ "factory", "backup", string.rep("A", 64), string.rep("0", 63) }) do
        assert(nodes[c.root .. "/.orbitui-versions/" .. name])
    end
end)
H.test("a corrupt active or rollback package prevents every obsolete-runtime deletion", function()
    for _, id in ipairs({ current, previous }) do
        local c = fixture()
        write(Boot.path(c.root, id) .. "/core/orbitui_plugin.lua", "return 'corrupt or locally modified'\n")
        local before = snapshot(c.root)
        local result = OTA.cleanup(c)
        assert(result.retained_unverified)
        H.eq(result.removed, 0); H.eq(result.bytes, 0); H.eq(snapshot(c.root), before)
    end
end)
H.test("interrupted deletion retains its manifest and safely resumes without a complete VERSION/bootstrap", function()
    local c = fixture()
    local other = Boot.path(c.root, string.rep("d", 64))
    runtime(other, "1.6.0")
    local calls = 0
    on_remove = function()
        calls = calls + 1
        if calls == 4 then error("simulated interruption") end
    end
    local first = OTA.cleanup(c)
    on_remove = nil
    H.eq(first.removed, 0); assert(first.bytes > 0)
    assert(nodes[other], "an interrupted snapshot must not start collecting a second one")
    assert(nodes[gc(c) .. "/manifest.json"] and not nodes[Boot.path(c.root, obsolete)])
    -- Missing files are accepted only in our quarantine, not an original slot.
    nodes[gc(c) .. "/VERSION"] = nil
    nodes[gc(c) .. "/orbitui_bootstrap.lua"] = nil
    H.eq(OTA.cleanup(c).removed, 1); H.eq(nodes[gc(c)], nil)
    assert(nodes[other])
    assert(nodes[c.runtime] and nodes[Boot.path(c.root, previous)])
end)
H.test("an interruption after the last unlink resumes with empty-directory removal only", function()
    local c = fixture()
    local rmdir = fs.rmdir
    fs.rmdir = function(path) if path == gc(c) then return nil end; return rmdir(path) end
    H.eq(OTA.cleanup(c).removed, 0)
    fs.rmdir = rmdir
    assert(nodes[gc(c)] and not nodes[gc(c) .. "/manifest.json"])
    local result = OTA.cleanup(c)
    H.eq(result.removed, 1); H.eq(result.bytes, 0); H.eq(nodes[gc(c)], nil)
end)
H.test("quarantine without a manifest or with new/changed user files remains untouched", function()
    for _, change in ipairs({
        function(path) write(path .. "/notes.txt", "keep user notes") end,
        function(path) write(path .. "/LICENSE", "changed legal/custom file") end,
        function(path) nodes[path .. "/manifest.json"] = nil; write(path .. "/notes.txt", "keep") end,
    }) do
        local c = fixture()
        assert(os.rename(Boot.path(c.root, obsolete), gc(c))); change(gc(c))
        local before = snapshot(c.root)
        H.eq(OTA.cleanup(c).removed, 0); H.eq(snapshot(c.root), before)
    end
end)
H.test("protected quarantine aliases and future/equal quarantines are kept", function()
    local c = fixture()
    for _, item in ipairs({ { current, "1.0.0" }, { previous, "1.0.0" },
        { string.rep("e", 64), "4.0.0" }, { string.rep("f", 64), "3.0.0" } }) do
        runtime(c.root .. "/.orbitui-versions/.orbitui-gc-" .. item[1], item[2])
    end
    H.eq(OTA.cleanup(c).removed, 1)
    for _, id in ipairs({ current, previous, string.rep("e", 64), string.rep("f", 64) }) do
        assert(nodes[c.root .. "/.orbitui-versions/.orbitui-gc-" .. id])
    end
end)
H.test("selection changes before quarantine or during collection stop deletion", function()
    local c = fixture()
    local validate = OTA.validate
    OTA.validate = function(target, ...)
        validate(target, ...)
        if target == Boot.path(c.root, obsolete) then point(c, previous, current, true) end
    end
    local before = snapshot(Boot.path(c.root, obsolete))
    H.eq(OTA.cleanup(c).removed, 0)
    OTA.validate = validate
    H.eq(snapshot(Boot.path(c.root, obsolete)), before)
    c = fixture()
    on_rename = function() point(c, previous, current, true) end
    local result = OTA.cleanup(c)
    on_rename = nil
    H.eq(result.removed, 0); H.eq(result.bytes, 0)
    assert(nodes[gc(c) .. "/manifest.json"] and nodes[c.runtime] and nodes[Boot.path(c.root, previous)])
end)
H.test("rename failures cannot unlink a candidate", function()
    local c = fixture()
    local rename = os.rename
    os.rename = function() return nil, "disk error" end
    local before = snapshot(c.root)
    H.eq(OTA.cleanup(c).removed, 0); H.eq(snapshot(c.root), before)
    os.rename = rename
end)
H.test("normal update preparation no longer bulk-deletes arbitrary hex-named directories", function()
    local c = fixture()
    local unknown = Boot.path(c.root, string.rep("d", 64))
    write(unknown .. "/user-notes", "must survive preparing an update")
    local extract = OTA.extract
    OTA.extract = function(_, target)
        local m = runtime(target, "4.0.0")
        return OTA.inventory(m)
    end
    local zip_data = "verified zip bytes"
    package.loaded["core/orbitui_http"] = { get = function(_, path)
        if not path then return digest(zip_data) .. "  orbitui.koplugin.zip\n" end
        write(path, zip_data); return #zip_data
    end }
    local plan = OTA.prepare(c, { version = "4.0.0", checksum = { url = "checksum" },
        zip = { url = "zip", size = #zip_data } })
    OTA.extract = extract
    H.eq(plan.version, "4.0.0")
    H.eq(read(unknown .. "/user-notes"), "must survive preparing an update")
    assert(nodes[Boot.path(c.root, obsolete)] and nodes[Boot.path(c.root, plan.slot)])
    H.eq(Boot.state(c.root).current, current)
end)
H.test("a full API-1 1999-file runtime is collected without touching retained packages", function()
    local c, manifest = fixture()
    local target = Boot.path(c.root, obsolete)
    for i = #manifest.files + 1, 1999 do
        local path, data = string.format("assets/icons/entry-%04d.svg", i), "unchanged stock asset " .. i
        write(target .. "/" .. path, data)
        manifest.files[#manifest.files + 1] = { path = path, size = #data, sha256 = digest(data) }
    end
    local active, rollback = snapshot(c.runtime), snapshot(Boot.path(c.root, previous))
    local result = OTA.cleanup(c)
    H.eq(result.removed, 1); assert(result.bytes > 40000)
    H.eq(nodes[target], nil); H.eq(nodes[gc(c)], nil)
    H.eq(snapshot(c.runtime), active); H.eq(snapshot(Boot.path(c.root, previous)), rollback)
end)

io.open, loadfile = original_open, original_loadfile
os.remove, os.rename = original_remove, original_rename
H.finish()
