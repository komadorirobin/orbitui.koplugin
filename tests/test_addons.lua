package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end
local files, tick, fail_save = {}, 0, false
local function digest(s)
    local n = 5381
    for i = 1, #s do n = (n * 33 + s:byte(i)) % 4294967296 end
    return string.rep(string.format("%08x", n), 8)
end
local function put(path, content, json)
    tick = tick + 1
    files[path] = { content = content or "json", json = copy(json), stamp = tick }
end
local F = {}
function F.attr(path)
    if files[path] then return { mode = "file", size = #files[path].content, modification = files[path].stamp } end
    for name in pairs(files) do if name:sub(1, #path + 1) == path .. "/" then return { mode = "directory" } end end
end
function F.mkdir() end
function F.read(path) return files[path] and files[path].content end
function F.write(path, value) put(path, value) end
function F.json(path, optional)
    if not files[path] and optional then return nil end
    return copy(assert(files[path], path).json)
end
function F.save(path, value)
    if fail_save and path:match("installed%.json$") then error("disk full") end
    put(path, "json", value)
end
function F.copy(from, to) files[to] = copy(assert(files[from])) end
function F.remove(path)
    for name in pairs(files) do if name == path or name:sub(1, #path + 1) == path .. "/" then files[name] = nil end end
end
function F.walk(path)
    local out = {}
    for name in pairs(files) do if name:sub(1, #path + 1) == path .. "/" then out[#out + 1] = name:sub(#path + 2) end end
    return out
end
package.loaded["core/orbitui_addon_files"] = F
package.loaded["libs/libkoreader-lfs"] = { dir = function(path)
    local names, seen = {}, {}
    for _, file in ipairs(F.walk(path)) do
        local name = file:match("^[^/]+")
        if not seen[name] then names[#names + 1] = name; seen[name] = true end
    end
    local i = 0; return function() i = i + 1; return names[i] end
end }
package.loaded.logger = { warn = function() end }
local OTA = require("core/orbitui_ota")
OTA.hashFile = function(path) return digest(assert(files[path], path).content) end
local M = require("core/orbitui_addons")
local base = "https://github.com/komadorirobin/orbitui.koplugin/releases/download/ornaments-1/"
local function pack(version)
    return { id = "manga", name = "Manga", description = "Manga miniatures", version = version or 1,
        folders = { "Manga", "Manga II", "Manga III" }, size = 3, sha256 = digest("zip"), url = base .. "manga-1.zip" }
end
local function manifest(p, values)
    local out = { schema = 1, api = 1, id = p.id, version = p.version, folders = p.folders, files = {}, defaults = {}, bindings = {} }
    for path, value in pairs(values or {}) do out.files[#out.files + 1] = { path = path, size = #value, sha256 = digest(value) } end
    return out
end
H.test("catalog accepts stable pack identity and rejects foreign hosts, code and overlaps", function()
    local catalog = { schema = 1, api = 1, revision = 1, packs = { pack() } }
    H.eq(M.catalog(catalog), catalog)
    for _, change in ipairs({
        function(c) c.api = 99 end,
        function(c) c.packs[1].url = "https://github.com/other/repo/releases/download/ornaments-1/manga.zip" end,
        function(c) c.packs[1].version = "1" end,
        function(c) local p = pack(); p.id = "other"; c.packs[2] = p end,
    }) do local c = copy(catalog); change(c); assert(not pcall(M.catalog, c)) end
    local p = pack()
    for _, path in ipairs({ "Manga/../escape.png", "Manga/main.lua", "Manga/code.so", "Other/image.png", "manga/A.png", "Manga/a/b/c.png" }) do
        assert(not pcall(M.manifest, manifest(p, { [path] = "x" }), p), path)
    end
    local m = manifest(p, { ["Manga/A.png"] = "a", ["Manga/a.png"] = "b" })
    assert(not pcall(M.manifest, m, p))
end)
H.test("data bindings are constrained, while new series aliases need no plugin update", function()
    local p = pack(); local m = manifest(p, { ["Manga/New.png"] = "a" })
    m.bindings["Manga/New.png"] = { kind = "series", id = "series:new", names = { "A New Manga" } }
    M.manifest(m, p)
    local Manga = require("core/orbitui_manga_ornaments")
    local Authors = require("core/orbitui_author_ornaments")
    Manga.setBindings(m.bindings)
    H.eq(Manga.piece("Manga/New.png"), "series:new")
    H.eq(Manga.seriesOf({ book = { kind = "series", series_name = "A New Manga" } }), "series:new")
    Authors.setBindings({ ["Authors/New.png"] = { kind = "author", id = "new author", names = { "New Author" } } })
    H.eq(Authors.authorOf({ author = "Author, New" }), "new author")
    H.eq(Authors.piece("Authors/New.png"), "new author")
    m.bindings["Manga/New.png"].kind = "execute"
    assert(not pcall(M.manifest, m, p))
    Manga.setBindings({}); Authors.setBindings({})
end)
H.test("three-way metadata merge keeps edits/deletions and accepts new official fields", function()
    local out = M.merge({ a = { scale = 1, info = "old", pad = 2 }, b = true },
        { a = { scale = 1.2, info = "old" }, custom = true },
        { a = { scale = 0.8, info = "new", pad = 3 }, b = true, new = true })
    H.eq(out.a.scale, 1.2); H.eq(out.a.info, "new"); H.eq(out.a.pad, nil)
    H.eq(out.b, nil); H.eq(out.custom, true); H.eq(out.new, true)
end)

H.test("local captions survive translation adoption and independent pack updates", function()
    local Text = require("core/orbitui_ornament_text")
    local original = { info = "Original" }
    local bilingual = { info = "Original", info_source = "Original", info_sv = "Svenska", info_en = "English" }
    local adopted = M.merge(original, original, bilingual)
    H.eq(Text.resolve(adopted, "sv"), "Svenska")
    H.eq(Text.resolve(adopted, "fr"), "English")
    local custom = M.merge(original, { info = "My biography" }, bilingual)
    H.eq(Text.resolve(custom, "en"), "My biography")
    local revised = { info = "New original", info_source = "New original", info_sv = "Ny text", info_en = "New English" }
    H.eq(Text.resolve(M.merge(bilingual, adopted, revised), "en"), "New English")
    H.eq(Text.resolve(M.merge(bilingual, custom, revised), "en"), "My biography")
    H.eq(Text.resolve(M.merge(bilingual, {}, revised), "en"), nil)
end)

local archive, payload, metadata = {}, {}, {}
local extract, png = M.extract, M.png
M.png = function() return 1 end
M.extract = function(_, target)
    local list = { "manifest.json" }
    F.save(target .. "/manifest.json", archive)
    for path, content in pairs(payload) do put(target .. "/" .. path, content, metadata[path]); list[#list + 1] = path end
    return list
end
local remove = os.remove
os.remove = function(path) if files[path] then files[path] = nil; return true end; return remove(path) end
local bad_download
package.loaded["core/orbitui_http"] = { get = function(_, target) put(target, bad_download and "bad" or "zip") end }
local function fixture(local_files)
    files, metadata, bad_download, fail_save = {}, {}, false, false
    local p = pack()
    local baseline = manifest(p, { ["Manga/A.png"] = "old-a", ["Manga II/B.png"] = "old-b" })
    F.save("/plugin/assets/addons/legacy-v1.json", { packs = { manga = baseline } })
    F.save("/plugin/assets/addons/catalog.json", { schema = 1, packs = { p } })
    for path, content in pairs(local_files or {}) do put("/native/" .. path, content) end
    payload = { ["Manga/A.png"] = "new-a", ["Manga II/B.png"] = "new-b", ["Manga/New.png"] = "new" }
    archive = manifest(p, payload)
    return M.new("/plugin", "/settings/addons", { "/native" }), p
end
H.test("prepare is inactive; a fresh install stays opt-in and a corrupt download changes nothing", function()
    local s, p = fixture()
    local plan = s:prepare(p)
    H.eq(next(s:registry().packs), nil)
    H.eq(plan.record.enabled, false)
    s:activate(plan); H.eq(s:registry().packs.manga.pack.version, 1)
    local roots, accept, enabled = s:view()
    H.eq(#roots, 1); assert(accept(roots[1] .. "/Manga/A.png", "Manga/A.png", roots[1]))
    assert(not enabled({ pack = "Manga" })); s:enable("manga", true)
    local revision = s:registry().revision
    bad_download = true; assert(not pcall(s.prepare, s, pack(2)))
    H.eq(s:registry().revision, revision)
end)
H.test("legacy aliases, modifications and deletions survive adoption", function()
    local s, p = fixture({ ["Manga/A.png"] = "old-a", ["Manga II/custom.png"] = "personal" })
    local plan = s:prepare(p); local root = s:versionRoot(plan.record)
    H.eq(F.read(root .. "/Manga/A.png"), "new-a")
    H.eq(F.read(root .. "/Manga II/B.png"), nil)
    H.eq(F.read(root .. "/Manga/New.png"), "new")
    H.eq(plan.record.enabled, true); s:activate(plan)
    local _, accept = s:view()
    assert(not accept("/native/Manga/A.png", "Manga/A.png", "/native"))
    assert(accept(root .. "/Manga/A.png", "Manga/A.png", root))
    put("/native/Manga/A.png", "personal edit")
    assert(accept("/native/Manga/A.png", "Manga/A.png", "/native"))
    assert(not accept(root .. "/Manga/A.png", "Manga/A.png", root))
    H.eq(F.read("/native/Manga II/custom.png"), "personal")
end)
H.test("placement defaults are read-only; explicit choices persist without enabling the pack", function()
    local s, p = fixture(); s:activate(s:prepare(p))
    local revision = s:registry().revision
    H.eq(M.placement(s:registry().packs.manga.placement), "matched")
    H.eq(M.placement("unknown"), "matched")
    s:setPlacement("manga", "matched")
    H.eq(s:registry().revision, revision)
    assert(not pcall(s.setPlacement, s, "manga", "unknown"))
    assert(not pcall(s.setPlacement, s, "missing", "random"))
    H.eq(s:registry().revision, revision)
    s:setPlacement("manga", "random")
    local restarted = M.new("/plugin", "/settings/addons", { "/native" })
    H.eq(restarted:registry().packs.manga.placement, "random")
    H.eq(restarted:registry().packs.manga.enabled, false)
    fail_save = true
    assert(not pcall(s.setPlacement, s, "manga", "matched"))
    H.eq(restarted:registry().packs.manga.placement, "random")
    fail_save = false
    restarted:setPlacement("manga", "matched")
    H.eq(s:registry().packs.manga.placement, "matched")
end)
H.test("placement changes invalidate pending updates and survive update, uninstall and reinstall", function()
    local s, p = fixture(); s:activate(s:prepare(p))
    p = pack(2); archive = manifest(p, payload)
    local pending = s:prepare(p)
    s:setPlacement("manga", "random")
    assert(not pcall(s.activate, s, pending))
    s:activate(s:prepare(p))
    H.eq(s:registry().packs.manga.placement, "random")
    H.eq(s:registry().packs.manga.enabled, false)
    s:uninstall("manga")
    assert(not pcall(s.setPlacement, s, "manga", "matched"))
    s:activate(s:prepare(p))
    H.eq(s:registry().packs.manga.placement, "random")
end)
H.test("independent Manga v2 adds ornaments while preserving edited and removed managed images", function()
    local s, p = fixture(); s:activate(s:prepare(p)); s:enable("manga", true)
    local before = s:versionRoot(s:registry().packs.manga)
    put(before .. "/Manga/A.png", "edited"); F.remove(before .. "/Manga II/B.png")
    put(before .. "/Manga/Own.png", "own")
    p = pack(2); payload["Manga/Added.png"] = "added"; archive = manifest(p, payload)
    local plan = s:prepare(p); s:activate(plan)
    local after = s:versionRoot(s:registry().packs.manga)
    H.eq(F.read(after .. "/Manga/A.png"), "edited")
    H.eq(F.read(after .. "/Manga II/B.png"), nil)
    H.eq(F.read(after .. "/Manga/Added.png"), "added")
    H.eq(F.read(after .. "/Manga/Own.png"), "own")
    H.eq(F.attr(before), nil)
    s:uninstall("manga")
    H.eq(F.read(after .. "/Manga/A.png"), "edited")
    H.eq(F.read(after .. "/Manga/Own.png"), "own")
    H.eq(F.read(after .. "/Manga/Added.png"), nil)
    assert(s:registry().packs.manga.removed)
end)
H.test("stale plans and failed atomic registry writes leave the active version unchanged", function()
    local s, p = fixture(); s:activate(s:prepare(p))
    p = pack(2); archive = manifest(p, payload)
    local plan = s:prepare(p); s:enable("manga", true)
    assert(not pcall(s.activate, s, plan)); H.eq(s:registry().packs.manga.pack.version, 1)
    plan = s:prepare(p); fail_save = true
    assert(not pcall(s.activate, s, plan)); H.eq(s:registry().packs.manga.pack.version, 1)
    fail_save = false
end)
H.test("unknown registry schema and changed immutable catalog versions are rejected", function()
    local s, p = fixture()
    F.save("/settings/addons/installed.json", { schema = 99, packs = {} })
    assert(not pcall(s.registry, s))
    local c = { schema = 1, api = 1, revision = 1, packs = { p } }
    s:saveCatalog(c)
    c.revision = 2; c.packs[1].sha256 = digest("changed")
    assert(not pcall(s.saveCatalog, s, c))
end)
H.test("remote ornament action tables are rejected after hash verification", function()
    local s, p = fixture()
    payload["Manga/ornaments.json"] = "json"
    metadata["Manga/ornaments.json"] = { ["A.png"] = { tap = { action = "execute" } } }
    archive = manifest(p, payload)
    assert(not pcall(s.prepare, s, p)); H.eq(next(s:registry().packs), nil)
end)
M.extract, M.png, os.remove = extract, png, remove
H.test("ZIP traversal, symlinks, case duplicates, oversized files and late archive errors fail closed", function()
    local entries, late_error, closed
    package.loaded["ffi/archiver"] = { Reader = { new = function()
        local arc = {}; local i = 0
        function arc:open() return true end
        function arc:iterate() return function()
            i = i + 1; if not entries[i] then self.err = late_error end; return entries[i]
        end end
        function arc:extractToMemory() return entries[i].data end
        function arc:close() closed = true end
        return arc
    end } }
    for _, value in ipairs({
        {{ path = "../outside", mode = "file", size = 1, data = "x" }},
        {{ path = "Manga/link.png", mode = "link", size = 0 }},
        {{ path = "Manga/big.png", mode = "file", size = M.MAX_FILE + 1 }},
        {{ path = "Manga/A.png", mode = "file", size = 5, data = "x" }},
        {{ path = "Manga/A.png", mode = "file", size = 1, data = "x" },
         { path = "Manga/a.png", mode = "file", size = 1, data = "x" }},
    }) do
        entries, closed = value, false
        assert(not pcall(M.extract, "unused", "/stage")); assert(closed)
    end
    entries, late_error, closed = {}, "CRC failure", false
    assert(not pcall(M.extract, "unused", "/stage")); assert(closed)
end)
H.test("catalog discovery ignores code releases and does not affect the code OTA channel", function()
    local catalog = { schema = 1, api = 1, revision = 2, packs = { pack() } }
    local url = base:gsub("orbitui%.koplugin", "orbitui-addons"):gsub("ornaments%-1", "ornaments-2") .. "ornaments-catalog.json"
    local releases = {
        { tag_name = "v9.9.9", assets = {} },
        { tag_name = "ornaments-1", assets = {} },
        { tag_name = "ornaments-2", prerelease = true,
            assets = { { name = "ornaments-catalog.json", browser_download_url = url } } },
        { tag_name = "ornaments-99", draft = true },
    }
    package.loaded.rapidjson = { decode = function(body) return copy(body == "releases" and releases or catalog) end }
    package.loaded["core/orbitui_http"] = { get = function(address)
        if address:find("api.github.com", 1, true) then return "releases" end
        H.eq(address, url); return "catalog"
    end }
    H.eq(M.fetchCatalog().revision, 2)
    H.eq(OTA.version("ornaments-2"), nil)
    catalog.revision = 3
    assert(not pcall(M.fetchCatalog))
end)
H.test("separate repository accepts old cached URLs without trusting other repositories", function()
    local p = pack()
    M.asset(p)
    p.url = p.url:gsub("orbitui%.koplugin", "orbitui-addons")
    M.asset(p)
    for _, url in ipairs({ p.url:gsub("orbitui%-addons", "orbitui-addons-evil"),
        p.url .. "?redirect=evil", p.url:gsub("github.com", "github.com.evil"),
        p.url:gsub("ornaments%-1", "v1.0.0"), p.url:gsub("manga%-1", "../manga-1") }) do
        p.url = url
        assert(not pcall(M.asset, p))
    end
end)
H.test("unavailable new channel falls back to the unchanged legacy catalog", function()
    local catalog = { schema = 1, api = 1, revision = 1, packs = { pack() } }
    local url = base .. "ornaments-catalog.json"
    local calls = {}
    package.loaded.rapidjson = { decode = function(body)
        if body == "releases" then return {{ tag_name = "ornaments-1",
            assets = {{ name = "ornaments-catalog.json", browser_download_url = url }} }} end
        return copy(catalog)
    end }
    package.loaded["core/orbitui_http"] = { get = function(address)
        calls[#calls + 1] = address
        if address:find("/orbitui-addons/", 1, true) then error("offline") end
        if address:find("api.github.com", 1, true) then return "releases" end
        H.eq(address, url); return "catalog"
    end }
    H.eq(M.fetchCatalog().revision, 1)
    H.eq(#calls, 3)
    -- An available but broken new catalog must not be hidden by falling back.
    calls = {}
    package.loaded["core/orbitui_http"].get = function(address)
        calls[#calls + 1] = address
        return "releases"
    end
    assert(not pcall(M.fetchCatalog))
    H.eq(#calls, 1)
end)
H.test("moving a catalog preserves pack versions registry enablement and placement", function()
    local p = pack()
    local store = M.new("/plugin", "/migration")
    F.save("/migration/catalog.json", { schema = 1, api = 1, revision = 1, packs = { p } })
    local registry = { schema = 1, revision = 7, packs = {
        manga = { slot = "manga-1-saved", pack = p, enabled = false, placement = "random" },
    } }
    F.save("/migration/installed.json", registry)
    local moved = copy(p); moved.url = p.url:gsub("orbitui%.koplugin", "orbitui-addons")
    store:saveCatalog{ schema = 1, api = 1, revision = 1, packs = { moved } }
    H.eq(store:catalog().packs[1].url, moved.url)
    H.eq(store:registry().revision, 7)
    H.eq(store:registry().packs.manga.enabled, false)
    H.eq(store:registry().packs.manga.placement, "random")
    H.eq(store:registry().packs.manga.slot, "manga-1-saved")
    assert(not pcall(store.saveCatalog, store, { schema = 1, api = 1, revision = 1,
        packs = { (function() local v = copy(moved); v.sha256 = string.rep("a", 64); return v end)() } }))
end)
H.finish()
