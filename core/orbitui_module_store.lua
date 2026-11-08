-- Executable plugins have separate trust, registry and staging from ornaments.
-- First installs only: never hot-load code or overwrite an existing plugin.
local F = require("core/orbitui_addon_files")
local OTA = require("core/orbitui_ota")
local M, Store = {}, {}
Store.__index = Store
local MAX_ZIP, MAX_TOTAL, MAX_FILE, MAX_FILES = 16 * 1048576, 32 * 1048576, 8 * 1048576, 512
local REPO = "komadorirobin/orbitui.koplugin"
local function text(v, n) return type(v) == "string" and #v > 0 and #v <= n and not v:find("[%z\1-\31\127]") end
local function integer(v, max) return type(v) == "number" and v >= 1 and v <= max and v == math.floor(v) end
local function hash(v) return type(v) == "string" and #v == 64 and v:match("^[0-9a-f]+$") end
local function id(v) return text(v, 64) and v:match("^[a-z][a-z0-9_-]*$") end
local function array(t, limit)
    assert(type(t) == "table" and #t <= limit, "Invalid catalog list")
    local n = 0; for k in pairs(t) do n = n + 1; assert(integer(k, #t), "Invalid list key") end
    assert(n == #t, "Sparse list"); return t
end
local function plain(path)
    assert(type(path) == "string" and path ~= "" and not path:find("[%z\1-\31\127\\]"), "Invalid directory")
    local parent = path:sub(1, 1) == "/" and "" or "."
    for part in path:gmatch("[^/]+") do
        assert(part ~= "..", "Parent directory not allowed")
        parent = parent == "" and "/" .. part or parent .. "/" .. part
        local a = F.attr(parent)
        assert(not a or a.mode == "directory", "Directory is a link or file")
    end
end
local function pathOK(path) return OTA.safePath(path) and path:sub(-1) ~= "/" end
local function version(v)
    -- Canonical semver spelling also prevents same-version hash reuse through
    -- aliases such as v2.0.0 or 02.0.0.
    if not text(v, 64) then return false end
    local parts = OTA.version(v)
    if not parts then return false end
    local normalized = parts[1] .. "." .. parts[2] .. "." .. parts[3]
    if parts[4] ~= 4 then normalized = normalized .. "-" .. ({"alpha", "beta", "rc"})[parts[4]] .. "." .. parts[5] end
    return v == normalized
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function M.entry(p)
    assert(type(p) == "table" and id(p.id) and p.folder == p.id .. ".koplugin", "Invalid plugin identity")
    assert(text(p.name, 80) and text(p.description, 1000) and text(p.description_sv, 1000)
        and version(p.version), "Invalid bilingual plugin description")
    assert(text(p.repository, 160) and p.repository:match("^[%w_-]+/[%w_-][%w_.-]*$"), "Invalid source repository")
    assert(text(p.tag, 80) and p.tag:match("^[%w_.-]+$") and p.tag ~= "." and p.tag ~= "..", "Invalid source tag")
    assert(text(p.asset, 120) and p.asset:match("^[%w_.-]+%.zip$"), "Invalid release asset")
    assert(hash(p.sha256) and integer(p.size, MAX_ZIP), "Invalid archive checksum/size")
    assert(type(p.commit) == "string" and #p.commit == 40 and p.commit:match("^[0-9a-f]+$"), "Missing reviewed source commit")
    assert(text(p.license, 240) and text(p.license_sv, 240) and text(p.data_note, 1000)
        and text(p.data_note_sv, 1000), "Missing bilingual license/data disclosure")
    assert(type(p.test) == "table" and p.test.scope == "adapter-desktop"
        and text(p.test.koreader, 160) and text(p.test.orbitui, 160)
        and text(p.test.date, 20) and text(p.test.evidence, 240), "Missing scoped test evidence")
    local seen = { [p.id] = true }
    for _, name in ipairs(array(p.conflicts, 8)) do
        assert(id(name) and not seen[name], "Invalid conflict identity"); seen[name] = true
    end
    return p
end
function M.url(p)
    M.entry(p)
    return "https://github.com/" .. p.repository .. "/releases/download/" .. p.tag .. "/" .. p.asset
end
function M.localized(p, key, language)
    local lang = language or (G_reader_settings and G_reader_settings:readSetting("language")) or "en"
    return p[key .. (type(lang) == "string" and lang:match("^sv") and "_sv" or "")]
end
function M.catalog(c)
    assert(type(c) == "table" and c.schema == 1 and c.api == 1 and integer(c.revision, 1000000), "Unsupported module catalog")
    local seen = {}
    for _, p in ipairs(array(c.plugins, 32)) do
        M.entry(p); assert(not seen[p.id], "Duplicate plugin"); seen[p.id] = true
    end
    return c
end
function M.bundled()
    -- Official unchanged release: no Silverfish code/art is bundled in OrbitUI.
    return { schema = 1, api = 1, revision = 1, plugins = {{
        id = "silverfish", folder = "silverfish.koplugin", name = "Silverfish",
        description = "A reading companion with a dashboard card. Plugin interface: English/Portuguese.",
        description_sv = "En läskompis med kort i läsöversikten. Pluginets gränssnitt: engelska/portugisiska.",
        version = "2.0.0", repository = "theusmaoliveiras/silverfish-koreader", tag = "v2.0.0",
        asset = "silverfish-v2.0.0.zip", size = 842889,
        sha256 = "959d61798e1d4ad4899ea220103492cb95d8c24fc5e7b874566855914c6e38f8",
        commit = "d3da0797b6e51ee73afdb4da6745b297b3a19830", conflicts = { "traca" },
        license = "Code: GPL-3.0; art/writing: CC BY-NC-SA 4.0; fonts/data: see CREDITS.md.",
        license_sv = "Kod: GPL-3.0; bilder/texter: CC BY-NC-SA 4.0; typsnitt/data: se CREDITS.md.",
        data_note = "Silverfish owns settings/traca.lua and its screensaver options. This catalog does not change or back up that data.",
        data_note_sv = "Silverfish hanterar settings/traca.lua och sina skärmsläckarval. Katalogen varken ändrar eller säkerhetskopierar dessa data.",
        test = { scope = "adapter-desktop", koreader = "Minimum/current native widget APIs; see test evidence",
            orbitui = "1.1-dev / 7c02737e", date = "2026-11-08",
            evidence = "docs/TESTING.md · dashboard-modules-20261108" },
    }} }
end
function M.fetchCatalog()
    local HTTP = require("core/orbitui_http")
    local list = require("rapidjson").decode(HTTP.get("https://api.github.com/repos/" .. REPO .. "/releases?per_page=100", nil, 2 * 1048576))
    local best, rev
    for _, release in ipairs(array(list, 100)) do
        local r = type(release.tag_name) == "string" and tonumber(release.tag_name:match("^modules%-(%d+)$"))
        if r and integer(r, 1000000) and not release.draft and not release.prerelease and (not rev or r > rev) then
            for _, asset in ipairs(release.assets or {}) do
                local expected = "https://github.com/" .. REPO .. "/releases/download/" .. release.tag_name .. "/module-catalog.json"
                if asset.name == "module-catalog.json" and asset.browser_download_url == expected then best, rev = expected, r end
            end
        end
    end
    if not best then return nil end -- no independent catalog published yet
    local c = M.catalog(require("rapidjson").decode(HTTP.get(best, nil, 256 * 1024)))
    assert(c.revision == rev, "Catalog release/revision mismatch"); return c
end
function M.new(plugin_root, directory, roots)
    plain(plugin_root); plain(directory)
    assert(type(roots) == "table" and #roots > 0, "No plugin lookup directories")
    local reachable = false
    for _, root in ipairs(roots) do if root == plugin_root then reachable = true end end
    assert(reachable, "Plugin destination is not discoverable")
    return setmetatable({ root = plugin_root, directory = directory, roots = roots }, Store)
end
function Store:catalog()
    local saved = F.json(self.directory .. "/catalog.json", true)
    return M.catalog(saved and saved.catalog or M.bundled())
end
function Store:saveCatalog(c)
    M.catalog(c)
    local old = self:catalog()
    assert(c.revision >= old.revision, "Catalog rollback rejected")
    local previous = F.json(self.directory .. "/catalog.json", true)
    local known = previous and previous.known or {}
    local function remember(p)
        local k = known[p.id]
        if k then
            assert(not OTA.newer(k.version, p.version), "Plugin version rollback rejected")
            assert(k.version ~= p.version or k.sha256 == p.sha256, "Reused plugin version rejected")
        end
        known[p.id] = { version = p.version, sha256 = p.sha256 }
    end
    for _, p in ipairs(old.plugins) do remember(p) end
    if c.revision == old.revision then assert(equal(c, old), "Catalog revision reused") end
    for _, p in ipairs(c.plugins) do remember(p) end
    F.save(self.directory .. "/catalog.json", { catalog = c, known = known })
end
function Store:registry()
    local s = F.json(self.directory .. "/installed.json", true) or { schema = 1, plugins = {} }
    assert(s.schema == 1 and type(s.plugins) == "table", "Unsupported plugin registry; kept")
    for key, r in pairs(s.plugins) do
        assert(id(key) and type(r) == "table" and type(r.pack) == "table" and r.pack.id == key, "Invalid installed plugin")
        M.entry(r.pack)
        array(r.files, MAX_FILES); assert(#r.files > 0, "Empty installed inventory")
        local seen = {}
        for _, f in ipairs(r.files) do
            assert(type(f) == "table" and pathOK(f.path) and hash(f.sha256) and type(f.size) == "number"
                and integer(f.size + 1, MAX_FILE + 1) and not seen[f.path:lower()], "Invalid installed file")
            seen[f.path:lower()] = true
        end
    end
    return s
end
function Store:conflict(p, skip)
    M.entry(p)
    local names = { p.id }; for _, name in ipairs(p.conflicts) do names[#names + 1] = name end
    for _, root in ipairs(self.roots) do
        plain(root)
        for _, name in ipairs(names) do
            local path = root .. "/" .. name .. ".koplugin"
            if path ~= skip and F.attr(path) then return path end
        end
    end
end
function Store:status(p)
    local conflict = self:conflict(p)
    if not conflict then return "missing" end
    local r = self:registry().plugins[p.id]
    if not r or conflict ~= self.root .. "/" .. p.folder then return "unmanaged" end
    if self:conflict(p, conflict) then return "unmanaged" end
    local ok = pcall(function()
        plain(conflict)
        local actual, directories = {}, 0
        local function walk(root, prefix, depth)
            assert(depth <= 12, "Plugin directory too deep")
            directories = directories + 1; assert(directories <= 64, "Too many plugin directories")
            for name in require("libs/libkoreader-lfs").dir(root) do
                if name ~= "." and name ~= ".." then
                    local a = assert(F.attr(root .. "/" .. name))
                    if a.mode == "directory" then walk(root .. "/" .. name, prefix .. name .. "/", depth + 1)
                    else
                        assert(a.mode == "file" and #actual < MAX_FILES, "Changed/unsafe plugin files")
                        actual[#actual + 1] = prefix .. name
                    end
                end
            end
        end
        walk(conflict, "", 0)
        assert(#actual == #r.files, "Changed inventory")
        for _, f in ipairs(r.files) do
            local a = F.attr(conflict .. "/" .. f.path)
            assert(a and a.mode == "file" and a.size == f.size and OTA.hashFile(conflict .. "/" .. f.path) == f.sha256, "Changed plugin")
        end
    end)
    if not ok then return "unverified" end
    return r.pack.sha256 == p.sha256 and "verified" or "other-tested"
end
local DOCS = { ["README.md"] = true, ["LEIAME.md"] = true, ["LICENSE"] = true,
    ["LICENSE-ART.md"] = true, ["CHANGELOG.md"] = true, ["CREDITS.md"] = true }
local EXT = { lua = true, json = true, md = true, txt = true, png = true, jpg = true, jpeg = true, svg = true, ttf = true, otf = true }
function M.extract(zip, target, p)
    M.entry(p); plain(target); F.mkdir(target)
    local arc = require("ffi/archiver").Reader:new()
    local seen, files, total, count = {}, {}, 0, 0
    local ok, err = pcall(function()
        assert(arc:open(zip), "Could not open plugin ZIP")
        for entry in arc:iterate() do
            count = count + 1; assert(count <= MAX_FILES + 64, "Too many archive entries")
            assert(type(entry.path) == "string" and (entry.mode == "file" or entry.mode == "directory"), "Unsafe archive entry")
            local prefix = p.folder .. "/"
            local path
            if entry.path:sub(1, #prefix) == prefix then path = entry.path:sub(#prefix + 1)
            elseif DOCS[entry.path] and entry.mode == "file" then path = "orbitui-catalog-docs/" .. entry.path end
            local bare = path and path:gsub("/$", "")
            assert(bare and (bare == "" and entry.mode == "directory" or pathOK(bare)), "Unsafe plugin path")
            assert(not seen[bare:lower()], "Duplicate archive path"); seen[bare:lower()] = entry.mode
            if entry.mode == "file" then
                assert(path == bare and bare ~= "" and (DOCS[path:match("^orbitui%-catalog%-docs/(.+)$")] or EXT[path:match("%.([a-z]+)$")]), "Unsupported plugin file")
                local size = tonumber(entry.size)
                assert(type(size) == "number" and size >= 0 and size <= MAX_FILE and size == math.floor(size), "Oversized plugin file")
                total = total + size; assert(total <= MAX_TOTAL and #files < MAX_FILES, "Plugin extraction limit")
                local content = assert(arc:extractToMemory(entry.path), "Archive read failed")
                assert(#content == size, "Short archive entry")
                if path:match("%.lua$") then
                    assert(content:byte(1) ~= 27 and (loadstring or load)(content, "@" .. target .. "/" .. path), "Invalid Lua source")
                end
                F.write(target .. "/" .. path, content)
                files[#files + 1] = { path = path, size = size, sha256 = OTA.hashFile(target .. "/" .. path) }
            end
        end
        assert(not arc.err, "Plugin archive read failed")
        assert(seen["main.lua"] == "file" and seen["_meta.lua"] == "file", "Missing plugin entry points")
        for path in pairs(seen) do
            local parent = path:match("^(.*)/")
            while parent do assert(seen[parent:lower()] ~= "file", "Archive file/directory collision"); parent = parent:match("^(.*)/") end
        end
    end)
    arc:close(); assert(ok, err); return files
end
local function approved(self, wanted)
    for _, p in ipairs(self:catalog().plugins) do
        if p.id == wanted.id and p.sha256 == wanted.sha256 and equal(p, wanted) then return p end
    end
    error("Plugin is not in the reviewed catalog")
end
local sequence = 0
function Store:prepare(p)
    p = approved(self, M.entry(p))
    assert(not self:conflict(p), "Existing plugin/conflict kept; first installs only")
    self:registry() -- fail closed before downloading if recovery state is unreadable
    plain(self.root); F.mkdir(self.root)
    local staging = self.root .. "/.orbitui-module-downloads"
    plain(staging); F.mkdir(staging)
    local dir
    repeat
        sequence = sequence + 1
        dir = staging .. "/" .. p.sha256 .. "-" .. os.time() .. "-" .. sequence
    until not F.attr(dir)
    F.mkdir(dir); F.write(dir .. "/owner.txt", "OrbitUI module staging v1")
    local zip = dir .. "/download.zip"
    require("core/orbitui_http").get(M.url(p), zip, p.size)
    local a = F.attr(zip)
    assert(a and a.mode == "file" and a.size == p.size and OTA.hashFile(zip) == p.sha256, "Plugin download checksum mismatch")
    local files = M.extract(zip, dir .. "/payload", p)
    F.save(dir .. "/plan.json", { pack = p, files = files })
    return { directory = dir, sha256 = p.sha256, id = p.id }
end
function Store:activate(plan)
    assert(type(plan) == "table" and hash(plan.sha256) and id(plan.id) and type(plan.directory) == "string", "Invalid plugin plan")
    local prefix = self.root .. "/.orbitui-module-downloads/"
    local suffix = plan.directory:sub(#prefix + 1)
    assert(plan.directory == prefix .. suffix and suffix:match("^[0-9a-f]+%-%d+%-%d+$")
        and suffix:sub(1, 64) == plan.sha256, "Foreign plugin staging")
    plain(plan.directory)
    assert(F.read(plan.directory .. "/owner.txt", 64) == "OrbitUI module staging v1", "Unowned staging")
    local stored = F.json(plan.directory .. "/plan.json")
    local p = approved(self, M.entry(stored.pack))
    assert(p.sha256 == plan.sha256 and p.id == plan.id, "Changed plugin plan")
    -- Recheck original ZIP and extract fresh; do not trust mutable worker
    -- output or a plan-provided inventory. Neither pass executes plugin code.
    local zip = plan.directory .. "/download.zip"
    assert(F.attr(zip).mode == "file" and F.attr(zip).size == p.size and OTA.hashFile(zip) == p.sha256, "Changed plugin archive")
    local payload = plan.directory .. "/payload"
    F.remove(payload)
    local files = M.extract(zip, payload, p)
    assert(not self:conflict(p), "A plugin appeared during download; kept")
    local state = self:registry()
    -- Durable intent before the single rename; an interrupted install remains
    -- verifiable from the same inventory. No overwrite-based recovery.
    state.plugins[p.id] = { pack = p, files = files }
    F.save(self.directory .. "/installed.json", state)
    assert(not self:conflict(p), "Plugin destination appeared; kept")
    assert(os.rename(payload, self.root .. "/" .. p.folder), "Could not install plugin directory")
    -- Failure to remove an already inactive download must not misreport a
    -- successful first install as a failed activation.
    local cleaned, err = pcall(F.remove, plan.directory)
    if not cleaned then require("logger").warn("[OrbitUI] Inactive module staging kept", err) end
    return p
end
function Store:cleanup()
    local root = self.root .. "/.orbitui-module-downloads"
    plain(root); if not F.attr(root) then return end
    for name in require("libs/libkoreader-lfs").dir(root) do
        if name:match("^[0-9a-f]+%-%d+%-%d+$") then
            local path = root .. "/" .. name
            if F.attr(path).mode == "directory" and F.read(path .. "/owner.txt", 64) == "OrbitUI module staging v1" then F.remove(path) end
        end
    end
end
return M
