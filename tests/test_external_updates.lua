package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function shell(s) local ok = os.execute(s); return ok == true or ok == 0 end
local fs = {}
function fs.symlinkattributes(path, key)
    local a = {}
    if shell("test -L " .. quote(path)) then a.mode = "link"
    elseif shell("test -d " .. quote(path)) then a.mode = "directory"
    else
        local f = io.open(path, "rb"); if not f then return end
        a.mode, a.size = "file", f:seek("end"); f:close()
    end
    return key and a[key] or a
end
function fs.mkdir(path) return shell("mkdir " .. quote(path)) end
function fs.rmdir(path) return shell("rmdir " .. quote(path)) end
function fs.dir(path)
    local f = assert(io.popen("find " .. quote(path) .. " -mindepth 1 -maxdepth 1 -print"))
    local list = {}; for p in f:lines() do list[#list + 1] = p:match("([^/]+)$") end; f:close()
    local i = 0; return function() i = i + 1; return list[i] end
end
package.loaded["libs/libkoreader-lfs"] = fs
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local function write(path, text)
    assert(shell("mkdir -p " .. quote(assert(path:match("^(.*)/")))))
    local f = assert(io.open(path, "wb")); assert(f:write(text)); assert(f:close())
end
local function digest(s)
    local n = 5381; for i = 1, #s do n = (n * 33 + s:byte(i)) % 4294967296 end
    return string.rep(string.format("%08x", n), 8)
end
local manifests = {}
package.loaded.rapidjson = { decode = function(s) return assert(manifests[s], "Invalid manifest JSON") end }
local base = os.tmpname(); os.remove(base)
assert(shell("mkdir " .. quote(base)))
local count, Boot, OTA = 0
local slot = string.rep("a", 64)
local paths = { "VERSION", "main.lua", "_meta.lua", "orbitui_bootstrap.lua", "core/orbitui_plugin.lua",
    "core/orbitui_runtime.lua", "core/orbitui_ota.lua", "adapters/orbitui_updates.lua",
    "components/bookshelf/main.lua", "components/simpleui/main.lua", "assets/ca-bundle.crt", "LICENSE" }
local function restart(root)
    Boot = dofile("orbitui_bootstrap.lua")
    package.loaded.orbitui_bootstrap = Boot
    OTA = dofile("core/orbitui_ota.lua")
    OTA.hashFile = function(path) return digest(read(path)) end
    return Boot.begin(root)
end
local function fixture(version)
    count = count + 1
    local root = base .. "/" .. count
    local manifest = { schema = 1, bootstrap_api = 1, version = version or "1.0.2", files = {} }
    for _, path in ipairs(paths) do
        local data = path == "VERSION" and manifest.version .. "\n" or "error('must not execute candidate code')\n"
        write(root .. "/" .. path, data)
        write(root .. "/.orbitui-versions/" .. slot .. "/" .. path, path == "VERSION" and "1.0.1\n" or data)
        manifest.files[#manifest.files + 1] = { path = path, size = #data, sha256 = digest(data) }
    end
    local token = "manifest-" .. count
    manifests[token] = manifest
    write(root .. "/manifest.json", token)
    write(root .. "/.orbitui-active", slot .. "\nfactory\n0\n")
    write(root .. "/settings-kept.txt", "reading data and settings")
    return restart(root), manifest
end
local function prepared(context)
    return OTA.prepareExternal(context, assert(OTA.externalCandidate(context)))
end

H.test("external root becomes a verified immutable snapshot without loading candidate code", function()
    local c = fixture()
    local plan = prepared(c)
    H.eq(Boot.state(c.root).current, slot)
    H.eq(Boot.read(c.root .. "/.orbitui-external-attempt"), nil)
    assert(plan.slot ~= "factory" and plan.slot ~= slot)
    assert(not fs.symlinkattributes(Boot.path(c.root, plan.slot) .. "/settings-kept.txt"))
    OTA.activateExternal(c, plan)
    H.eq(c.version, "1.0.1")
    H.eq(Boot.state(c.root).previous, slot)
    H.eq(Boot.metadata(c.root).version, "1.0.2")
    -- Further external overwrites cannot mutate the selected snapshot.
    write(c.root .. "/core/orbitui_plugin.lua", "unfinished next installation")
    local next_context = restart(c.root)
    H.eq(next_context.version, "1.0.2")
    assert(loadfile(next_context.runtime .. "/core/orbitui_plugin.lua"))
    Boot.healthy(c.root)
    H.eq(read(c.root .. "/settings-kept.txt"), "reading data and settings")
end)
H.test("older or identical factory versions never undo OTA updates", function()
    for _, version in ipairs({ "0.9.0", "1.0.1", "1.0.1-beta.9" }) do
        local c = fixture(version)
        H.eq(OTA.externalCandidate(c), nil)
    end
end)
H.test("a first installation and a pending update are not imported again", function()
    local c = fixture()
    Boot.save(c.root, { current = "factory", previous = "none", pending = false })
    H.eq(OTA.externalCandidate(restart(c.root)), nil)
    c = fixture()
    local p = prepared(c); OTA.activateExternal(c, p)
    H.eq(OTA.externalCandidate(c, true), nil)
end)
H.test("startup failure restores previous code without an external-update boot loop", function()
    local c = fixture()
    local p = prepared(c); OTA.activateExternal(c, p)
    restart(c.root) -- crash before healthy
    local recovered = restart(c.root)
    H.eq(recovered.version, "1.0.1")
    assert(recovered.notice)
    H.eq(OTA.externalCandidate(recovered), nil)
    assert(OTA.externalCandidate(recovered, true))
    H.eq(read(c.root .. "/settings-kept.txt"), "reading data and settings")
end)
H.test("manual rollback remains selected; explicit retry can reuse the retained snapshot", function()
    local c = fixture()
    local p = prepared(c); OTA.activateExternal(c, p)
    restart(c.root); Boot.healthy(c.root); Boot.rollback(c.root)
    c = restart(c.root); Boot.healthy(c.root)
    H.eq(OTA.externalCandidate(c), nil)
    p = OTA.prepareExternal(c, assert(OTA.externalCandidate(c, true)))
    OTA.activateExternal(c, p)
    H.eq(restart(c.root).version, "1.0.2")
end)
H.test("interrupted copying and validation errors cannot alter active code or attempt marker", function()
    for _, change in ipairs({
        function(c) os.remove(c.root .. "/components/simpleui/main.lua") end,
        function(c) write(c.root .. "/core/orbitui_plugin.lua", "truncated") end,
        function(_, m) m.files[5].sha256 = string.rep("b", 64) end,
        function(_, m) m.version = "9.9.9" end,
        function(c) write(c.root .. "/manifest.json", "broken JSON") end,
        function(c, m)
            local bad = "local = bad"
            write(c.root .. "/core/orbitui_plugin.lua", bad)
            m.files[5].size, m.files[5].sha256 = #bad, digest(bad)
        end,
        function(c, m)
            local bad = "return {}"
            write(c.root .. "/main.lua", bad)
            m.files[2].size, m.files[2].sha256 = #bad, digest(bad)
        end,
    }) do
        local c, m = fixture(); change(c, m)
        assert(not pcall(prepared, c))
        H.eq(Boot.state(c.root).current, slot)
        H.eq(Boot.read(c.root .. "/.orbitui-external-attempt"), nil)
    end
end)
H.test("file and parent-directory symlinks cannot enter an external snapshot", function()
    for _, name in ipairs({ "manifest.json", "core/orbitui_plugin.lua", "components/simpleui" }) do
        local c = fixture()
        local path = c.root .. "/" .. name
        assert(os.rename(path, path .. ".outside"))
        assert(shell("ln -s " .. quote(path .. ".outside") .. " " .. quote(path)))
        assert(not pcall(prepared, c), name)
        H.eq(Boot.state(c.root).current, slot)
    end
end)
H.test("unsafe manifest paths, duplicate case, sizes and incompatible bootstrap fail closed", function()
    for _, change in ipairs({
        function(m) m.bootstrap_api = 2 end,
        function(m) m.files[1].path = "../outside" end,
        function(m) m.files[1].path = "core/" end,
        function(m) m.files[1].path = "Manifest.json" end,
        function(m) m.files[1].size = -1 end,
        function(m) m.files[1].size = 0.5 end,
        function(m) m.files[1].size = 32 * 1024 * 1024 + 1 end,
        function(m) m.files[1].path = "MAIN.lua" end,
    }) do
        local c, m = fixture(); change(m)
        assert(not pcall(prepared, c))
        H.eq(Boot.state(c.root).current, slot)
    end
end)
H.test("root replacement between probe and copy is rejected", function()
    local c = fixture()
    local candidate = OTA.externalCandidate(c)
    write(c.root .. "/VERSION", "1.0.3\n")
    assert(not pcall(OTA.prepareExternal, c, candidate))
    H.eq(Boot.state(c.root).current, slot)
end)
H.test("failed activation pointer write keeps old code and allows explicit retry", function()
    local c = fixture(); local p = prepared(c)
    local save = Boot.save
    Boot.save = function() error("disk full") end
    assert(not pcall(OTA.activateExternal, c, p))
    Boot.save = save
    H.eq(Boot.state(c.root).current, slot)
    H.eq(OTA.externalCandidate(c), nil)
    assert(OTA.externalCandidate(c, true))
    OTA.activateExternal(c, p)
    H.eq(restart(c.root).version, "1.0.2")
end)
H.test("cancelled preparation can retry and a stale main-process callback cannot activate", function()
    local c = fixture(); local p = prepared(c)
    H.eq(prepared(c).slot, p.slot)
    Boot.save(c.root, { current = slot, previous = "factory", pending = true })
    assert(not pcall(OTA.activateExternal, c, p))
    H.eq(Boot.read(c.root .. "/.orbitui-external-attempt"), nil)
end)
assert(shell("rm -rf " .. quote(base)))
H.finish()
