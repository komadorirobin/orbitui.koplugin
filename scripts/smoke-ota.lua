local fixture = dofile(assert(arg[1]))
package.path = "./?.lua;" .. fixture.references .. "/?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[void *malloc(size_t size); void free(void *ptr);]]
ffi.loadlib = function(name) return ffi.load(name) end
package.loaded["ffi/posix_h"] = true
local function quote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
local function shell(command)
    local a, _, code = os.execute(command)
    return a == 0 or (a == true and code == 0)
end
package.loaded["libs/libkoreader-lfs"] = {
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
local release = { version = fixture.manifest.version,
    zip = { url = "fixture", size = fixture.size }, checksum = { url = "fixture-checksum" } }
local prepared = OTA.prepare(context, release)
assert(prepared.version == fixture.manifest.version)
assert(Boot.state(context.root).current == "factory")
assert(Boot.version(context.root) == "0.1.0-alpha.1")
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
Boot = dofile("orbitui_bootstrap.lua")
assert(Boot.begin(context.root).version == release.version)
Boot.healthy(context.root)
Boot.rollback(context.root)
assert(Boot.state(context.root).current == "factory")
Boot = dofile("orbitui_bootstrap.lua")
context = Boot.begin(context.root)
Boot.healthy(context.root)
package.loaded.orbitui_bootstrap = Boot
corrupt_download = true
local ok, err = pcall(OTA.prepare, context, release)
assert(not ok and tostring(err):find("size mismatch", 1, true))
assert(Boot.state(context.root).current == "factory")
print("PASS activation, restart, code rollback and truncated-download recovery")
