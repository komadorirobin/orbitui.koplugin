-- Linux smoke test with real libarchive, SHA-256, JSON and filesystem I/O.
-- Usage: luajit scripts/smoke-addons.lua /refs /tmp/orbitui-addon-smoke [--live]
package.path = "./?.lua;" .. assert(arg[1]) .. "/?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[typedef long time_t; void *malloc(size_t size); void free(void *ptr);]]
ffi.loadlib = function(name, version) return ffi.load("lib" .. name .. ".so." .. version) end
package.loaded["ffi/posix_h"] = true
package.loaded["libs/libkoreader-lfs"] = require("lfs")
package.loaded.rapidjson = require("cjson")
package.loaded.logger = { warn = function(...) print(...) end }
local F = require("core/orbitui_addon_files")
local A = require("core/orbitui_addons")
local Text = require("core/orbitui_ornament_text")
local root = assert(arg[2]); assert(root:match("^/tmp/orbitui%-addon%-"))
F.remove(root); F.mkdir(root)
local catalog = A.catalog(F.json("./dist/ornaments/ornaments-catalog.json"))
if arg[3] == "--live" then
    package.loaded.socketutil = {
        set_timeout = function(_, block)
            require("socket.http").TIMEOUT = block
            require("ssl.https").TIMEOUT = block
        end,
        reset_timeout = function() end,
    }
    local public = A.fetchCatalog()
    assert(public.revision == catalog.revision, "Public catalog differs from build under test")
    assert(#public.packs == #catalog.packs)
    for i, pack in ipairs(public.packs) do
        local expected = catalog.packs[i]
        assert(pack.id == expected.id and pack.version == expected.version)
        assert(pack.sha256 == expected.sha256 and pack.size == expected.size)
        assert(pack.url == expected.url)
    end
    catalog = public
    print("PASS anonymous catalog discovery through real LuaSocket/LuaSec TLS")
else
    package.loaded["core/orbitui_http"] = { get = function(url, target)
        F.write(target, F.read("./dist/ornaments/" .. assert(url:match("/([^/]+)$")), A.MAX_ZIP))
    end }
end
local store = A.new(".", root .. "/addons", { root .. "/native" })
store:saveCatalog(catalog)
for _, pack in ipairs(catalog.packs) do
    local plan = store:prepare(pack)
    assert(not store:registry().packs[pack.id])
    store:activate(plan)
    assert(store:registry().packs[pack.id].enabled == false)
    assert(A.placement(store:registry().packs[pack.id].placement) == "matched")
    store:enable(pack.id, true)
    local version = store:versionRoot(store:registry().packs[pack.id])
    for _, folder in ipairs(pack.folders) do
        for _, entry in pairs(F.json(version .. "/" .. folder .. "/ornaments.json")) do
            assert(Text.resolve(entry, "sv_SE") == entry.info_sv)
            assert(Text.resolve(entry, "en") == entry.info_en)
            assert(Text.resolve(entry, "ja") == entry.info_en)
            assert(#entry.info_en > 0 and #entry.info_en <= 4000)
            assert(#entry.info_sv > 0 and #entry.info_sv <= 4000)
        end
    end
    print("PASS native install/hash/archive/metadata:", pack.id, pack.size)
end
local p = catalog.packs[1]
store:setPlacement("manga", "random")
store = A.new(".", root .. "/addons", { root .. "/native" })
assert(store:registry().packs.manga.placement == "random")
assert(store:registry().packs.authors.placement == nil)
local before = store:versionRoot(store:registry().packs.manga)
local removed = "/Manga II/Pochita.png"
F.remove(before .. removed)
F.write(before .. "/Manga/Own.txt", "user note")
local metadata = F.json(before .. "/Manga/ornaments.json")
metadata["Kaneda Motorcycle.png"].scale = 1.234
metadata["Kaneda Motorcycle.png"].info = "My custom caption"
F.save(before .. "/Manga/ornaments.json", metadata)
local plan = store:prepare(p)
assert(not F.attr(store:versionRoot(plan.record) .. removed))
store:activate(plan)
assert(store:registry().packs.manga.placement == "random")
local after = store:versionRoot(store:registry().packs.manga)
assert(F.read(after .. "/Manga/Own.txt") == "user note")
assert(F.json(after .. "/Manga/ornaments.json")["Kaneda Motorcycle.png"].scale == 1.234)
local caption = F.json(after .. "/Manga/ornaments.json")["Kaneda Motorcycle.png"]
assert(Text.resolve(caption, "sv") == "My custom caption")
assert(Text.resolve(caption, "en") == "My custom caption")
assert(not F.attr(before))
store:uninstall("manga")
assert(not F.attr(after .. "/Manga/Kaneda Motorcycle.png"))
assert(F.read(after .. "/Manga/Own.txt") == "user note")
assert(F.attr(after .. "/Manga/ornaments.json"))
assert(store:registry().packs.manga.placement == "random")
store:activate(store:prepare(p))
assert(store:registry().packs.manga.placement == "random")
store:setPlacement("manga", "matched")
assert(store:registry().packs.manga.placement == "matched")
print("PASS native update, deletion, custom metadata, cleanup and uninstall")
print("PASS native placement defaults, per-pack isolation, restart, update, reinstall and restore")
F.remove(root)
