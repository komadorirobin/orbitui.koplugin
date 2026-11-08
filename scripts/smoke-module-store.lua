-- macOS/Linux native filesystem, SHA-256, JSON and libarchive test. Never
-- executes Silverfish. Requires an empty, explicitly created evidence directory.
-- luajit scripts/smoke-module-store.lua <refs> <new-empty-root> <official.zip>
package.path = "./?.lua;" .. assert(arg[1]) .. "/?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[typedef long time_t; void *malloc(size_t size); void free(void *ptr);]]
ffi.loadlib = function(name, version)
    if ffi.os == "OSX" then return ffi.load("/usr/lib/lib" .. name .. ".dylib") end
    return ffi.load("lib" .. name .. ".so." .. version)
end
package.loaded["ffi/posix_h"] = true
package.loaded["libs/libkoreader-lfs"] = os.getenv("ORBITUI_TEST_NATIVE_FS")
    and dofile(os.getenv("ORBITUI_TEST_NATIVE_FS")) or require("lfs")
package.loaded.rapidjson = require("cjson")
package.loaded.logger = {warn=function(...) print(...) end}
local F = require("core/orbitui_addon_files")
local M = require("core/orbitui_module_store")
local OTA = require("core/orbitui_ota")
local root, zip = assert(arg[2]), assert(arg[3])
assert(root:find("/test-results/module-library-20261108/native.", 1, true) or root:match("^/tmp/orbitui%-module%-"))
assert(#F.walk(root) == 0, "Test root must be new and empty")
local p = M.bundled().plugins[1]
assert(F.attr(zip).size == p.size and OTA.hashFile(zip) == p.sha256)
package.loaded["core/orbitui_http"] = {get=function(url, target, limit)
    assert(url == M.url(p) and limit == p.size)
    F.write(target, assert(F.read(zip, limit)))
end}
local s = M.new(root .. "/plugins", root .. "/settings/store", {root .. "/plugins"})
F.write(root .. "/settings/traca.lua", "untouched pet state fixture")
local plan = s:prepare(p)
assert(not F.attr(root .. "/plugins/" .. p.folder))
local started = os.clock()
s:activate(plan)
print(string.format("Activation CPU seconds (desktop, not Bigme): %.3f", os.clock()-started))
assert(s:status(p) == "verified")
local target = root .. "/plugins/" .. p.folder
local checks = {
    ["traca_simpleui.lua"] = "eca31747662055c3c4379bcebc1d10ea22530975251494dcc8b773c18570dd65",
    ["traca_bookshelf.lua"] = "f66c0c11e9d25defc3fb0faf0735d6805a83335d17eae159c1c110d2d15ad2ae",
    ["bookshelf_modules/traca.lua"] = "0af88b41ad83b9baa6c6e089428b76804efb77c1bb8c27232bdcf9d96a4acdfe"
}
-- Exact upstream adapter hashes are independently recorded in the dashboard
-- evidence. Also compare every extracted plugin byte with this same artifact
-- in the external audit; no main.lua/_meta.lua is required here.
assert(OTA.hashFile(target .. "/traca_simpleui.lua") == checks["traca_simpleui.lua"])
assert(OTA.hashFile(target .. "/traca_bookshelf.lua") == checks["traca_bookshelf.lua"])
assert(OTA.hashFile(target .. "/bookshelf_modules/traca.lua") == checks["bookshelf_modules/traca.lua"])
assert(F.read(target .. "/orbitui-catalog-docs/LICENSE-ART.md"):find("CC BY-NC-SA",1,true))
assert(F.read(root .. "/settings/traca.lua") == "untouched pet state fixture")
assert(not pcall(s.prepare,s,p))
F.write(target .. "/_meta.lua", "return {version='99.0.0'}")
assert(s:status(p) == "unverified" and not pcall(s.prepare,s,p))
F.write(target .. "/personal-note.txt", "keep this")
s:cleanup()
assert(F.read(target .. "/personal-note.txt") == "keep this")
print("PASS real pinned Silverfish ZIP, hashes, compilation-only extraction, license preservation, first install, changed-version detection, user data and staging cleanup")
