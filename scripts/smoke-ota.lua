local fixture = dofile(assert(arg[1]))
-- Load the starting release's actual installer when --base-zip is supplied.
package.path = fixture.root .. "/?.lua;" .. fixture.references .. "/?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[typedef long time_t; void *malloc(size_t size); void free(void *ptr);]]
ffi.loadlib = function(name, version)
    return ffi.load(jit.os == "OSX" and name or ("lib" .. name .. ".so." .. version))
end
package.loaded["ffi/posix_h"] = true
local function quote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
local function shell(command)
    local a, _, code = os.execute(command)
    return a == 0 or (a == true and code == 0)
end
-- Optional test-only native filesystem adapter; default stays compiler-free.
package.loaded["libs/libkoreader-lfs"] = os.getenv("ORBITUI_TEST_NATIVE_FS")
    and dofile(os.getenv("ORBITUI_TEST_NATIVE_FS")) or {
    symlinkattributes = function(path, key)
        local mode, size
        if shell("test -L " .. quote(path)) then mode = "link"
        elseif shell("test -d " .. quote(path)) then mode = "directory"
        else
            local f = io.open(path, "rb")
            if not f then return nil end
            mode, size = "file", f:seek("end")
            f:close()
        end
        local result = { mode = mode, size = size }
        return key and result[key] or result
    end,
    mkdir = function(path) return shell("mkdir " .. quote(path)) end,
    rmdir = function(path) return shell("rmdir " .. quote(path)) end,
    dir = function(path)
        local f = assert(io.popen("find " .. quote(path) .. " -mindepth 1 -maxdepth 1 -print"))
        local entries = {}
        for line in f:lines() do entries[#entries + 1] = line:match("([^/]+)$") end
        f:close()
        local i = 0
        return function() i = i + 1; return entries[i] end
    end,
}
package.loaded.rapidjson = { decode = function(data)
    if data == fixture.external_manifest_text then return fixture.external_manifest end
    if data == fixture.cleanup_manifest_text then return fixture.cleanup_manifest end
    assert(data == fixture.manifest_text, "Unexpected JSON bytes")
    return fixture.manifest
end }
local corrupt_download
package.loaded["core/orbitui_http"] = { get = function(url, target)
    if not target then return fixture.checksum end
    local source, dest = assert(io.open(fixture.archive, "rb")), assert(io.open(target, "wb"))
    local data = source:read("*a")
    if corrupt_download then data = data:sub(1, -2) end
    assert(dest:write(data))
    assert(dest:close())
    source:close()
    return #data
end }
local OTA = require("core/orbitui_ota")
local Boot = require("orbitui_bootstrap")
local context = Boot.begin(fixture.root)
local tag = "v" .. fixture.manifest.version
local asset_base = "https://github.com/" .. OTA.REPO .. "/releases/download/" .. tag .. "/"
-- Exercise the starting installer's discovery limits too, not only extraction.
local release = assert(OTA.select({ {
    tag_name = tag, draft = false, prerelease = true,
    assets = {
        { name = OTA.ASSET, size = fixture.size, browser_download_url = asset_base .. OTA.ASSET },
        { name = OTA.ASSET .. ".sha256", size = #fixture.checksum,
          browser_download_url = asset_base .. OTA.ASSET .. ".sha256" },
    },
} }, true))
local fixture_http = package.loaded["core/orbitui_http"]
if fixture.live then
    package.loaded["core/orbitui_http"] = nil
    package.loaded.rapidjson = require("cjson")
    package.loaded.socketutil = {
        set_timeout = function(_, block)
            require("socket.http").TIMEOUT = block
            require("ssl.https").TIMEOUT = block
        end,
        reset_timeout = function() end,
    }
    release = assert(OTA.check(true), "No public preview release found")
    assert(release.version == fixture.manifest.version, "Public release differs from build under test")
    print("PASS anonymous GitHub release discovery through real LuaSocket/LuaSec TLS")
end
assert(context.version == fixture.base_version)
assert(OTA.newer(release.version, context.version), "No newer version to install")
print("PASS update offered from " .. context.version .. " to " .. release.version)
local prepared = OTA.prepare(context, release)
assert(prepared.version == fixture.manifest.version)
assert(Boot.state(context.root).current == "factory")
assert(Boot.version(context.root) == fixture.base_version)
print("PASS native libarchive extraction and SHA-256 verification of full release inventory")
local target = Boot.path(context.root, prepared.slot)
local files = { "manifest.json" }
for _, entry in ipairs(fixture.manifest.files) do files[#files + 1] = entry.path end
local core_path = target .. "/core/orbitui_plugin.lua"
assert(os.rename(core_path, core_path .. ".saved"))
assert(not pcall(OTA.validate, target, files, release, fixture.root))
assert(os.rename(core_path .. ".saved", core_path))
print("PASS missing runtime module is rejected before activation")
Boot.activate(context.root, prepared.slot)
assert(context.slot == "factory")
Boot = dofile(fixture.root .. "/orbitui_bootstrap.lua")
assert(Boot.begin(context.root).version == release.version)
Boot.healthy(context.root)
Boot.rollback(context.root)
assert(Boot.state(context.root).current == "factory")
Boot = dofile(fixture.root .. "/orbitui_bootstrap.lua")
context = Boot.begin(context.root)
assert(context.version == fixture.base_version)
Boot.healthy(context.root)
package.loaded.orbitui_bootstrap = Boot
package.loaded["core/orbitui_http"] = fixture_http
corrupt_download = true
local ok, err = pcall(OTA.prepare, context, release)
assert(not ok and tostring(err):find("size mismatch", 1, true))
assert(Boot.state(context.root).current == "factory")
print("PASS activation, restart, code rollback and truncated-download recovery")

-- The newly installed runtime must adopt a later external overwrite safely.
Boot.activate(context.root, prepared.slot)
Boot = dofile(fixture.root .. "/orbitui_bootstrap.lua")
context = Boot.begin(fixture.root)
Boot.healthy(context.root)
package.loaded.orbitui_bootstrap = Boot
local next_ota = dofile(context.runtime .. "/core/orbitui_ota.lua")
local function write(path, data)
    assert(shell("mkdir -p " .. quote(assert(path:match("^(.*)/")))))
    local f = assert(io.open(path, "wb")); assert(f:write(data)); assert(f:close())
end
for _, entry in ipairs(fixture.manifest.files) do
    write(context.root .. "/" .. entry.path, assert(Boot.read(context.runtime .. "/" .. entry.path, 32 * 1024 * 1024)))
end
write(context.root .. "/VERSION", fixture.external_manifest.version .. "\n")
write(context.root .. "/manifest.json", fixture.external_manifest_text)
local candidate = assert(next_ota.externalCandidate(context))
local external = next_ota.prepareExternal(context, candidate)
assert(Boot.state(context.root).current == prepared.slot)
next_ota.activateExternal(context, external)
assert(context.version == fixture.manifest.version)
Boot = dofile(fixture.root .. "/orbitui_bootstrap.lua")
assert(Boot.begin(context.root).version == fixture.external_manifest.version)
Boot.healthy(context.root)
Boot.rollback(context.root)
Boot = dofile(fixture.root .. "/orbitui_bootstrap.lua")
context = Boot.begin(fixture.root)
Boot.healthy(context.root)
package.loaded.orbitui_bootstrap = Boot
next_ota = dofile(context.runtime .. "/core/orbitui_ota.lua")
assert(context.version == fixture.manifest.version)
assert(not next_ota.externalCandidate(context), "Rollback must not re-adopt the same external install")
print("PASS full external runtime snapshot, native SHA verification, restart and persistent rollback")

-- New runtime's collector on real files/native hashes, without touching a reader.
-- A small complete API-1 fixture uses the real bootstrap and required Lua/assets.
local obsolete = string.rep("e", 64)
assert(obsolete ~= Boot.state(context.root).current and obsolete ~= Boot.state(context.root).previous)
local obsolete_path = Boot.path(context.root, obsolete)
for _, entry in ipairs(fixture.cleanup_manifest.files) do
    local data = entry.path == "VERSION" and "0.0.1\n"
        or assert(Boot.read(context.runtime .. "/" .. entry.path, 32 * 1024 * 1024))
    write(obsolete_path .. "/" .. entry.path, data)
end
write(obsolete_path .. "/manifest.json", fixture.cleanup_manifest_text)
write(context.root .. "/reading-data-sentinel", "preserve user data")
local selection = assert(Boot.read(context.root .. "/.orbitui-active"))
local retained = Boot.state(context.root)
local previous_manifest = next_ota.hashFile(Boot.path(context.root, retained.previous) .. "/manifest.json")
context._orbitui_storage_ready = true
local remove, unlinks = os.remove, 0
os.remove = function(path)
    if path:find("/.orbitui-gc-" .. obsolete .. "/", 1, true) then
        unlinks = unlinks + 1
        if unlinks == 2 then return nil, "simulated interruption" end
    end
    return remove(path)
end
local interrupted = next_ota.cleanup(context)
os.remove = remove
assert(interrupted.removed == 0 and interrupted.bytes > 0)
assert(Boot.read(context.root .. "/.orbitui-versions/.orbitui-gc-" .. obsolete .. "/manifest.json"))
-- Reload resolver state and collector rather than keep an in-memory delete plan.
Boot = dofile(fixture.root .. "/orbitui_bootstrap.lua")
context = Boot.begin(fixture.root)
Boot.healthy(fixture.root)
context._orbitui_storage_ready = true
package.loaded.orbitui_bootstrap = Boot
next_ota = dofile(context.runtime .. "/core/orbitui_ota.lua")
local cleaned = next_ota.cleanup(context)
assert(cleaned.removed == 1 and cleaned.bytes > 0)
assert(not package.loaded["libs/libkoreader-lfs"].symlinkattributes(obsolete_path))
assert(not package.loaded["libs/libkoreader-lfs"].symlinkattributes(context.root .. "/.orbitui-versions/.orbitui-gc-" .. obsolete))
assert(Boot.read(context.root .. "/.orbitui-active") == selection)
assert(next_ota.hashFile(Boot.path(context.root, retained.previous) .. "/manifest.json") == previous_manifest)
assert(Boot.read(context.root .. "/reading-data-sentinel") == "preserve user data")
print("PASS native obsolete-runtime cleanup, interrupted-delete restart/resume and retained rollback/user data")
