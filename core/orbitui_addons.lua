-- Data-only ornament releases. Preparation never changes the active registry.
local F = require("core/orbitui_addon_files")
local OTA = require("core/orbitui_ota")
local M = { API = 1, MAX_ZIP = 128 * 1024 * 1024, MAX_FILE = 16 * 1024 * 1024,
    REPO = "komadorirobin/orbitui-addons", LEGACY_REPO = "komadorirobin/orbitui.koplugin" }
local Store = {}; Store.__index = Store
local function releaseBase(repo) return "https://github.com/" .. repo .. "/releases/download/" end
local function integer(n) return type(n) == "number" and n >= 1 and n <= 1000000000 and n == math.floor(n) end
local function id(s) return type(s) == "string" and #s <= 60 and s:match("^[a-z][a-z0-9%-]*$") end
local function slotId(s) return type(s) == "string" and #s <= 140 and s:match("^[a-z][a-z0-9%-]*$") end
local function hash(s) return type(s) == "string" and #s == 64 and s:match("^[a-f0-9]+$") end
local function text(s, limit) return type(s) == "string" and #s <= limit and not s:find("%z") end
local function folders(list)
    assert(type(list) == "table" and #list > 0 and #list <= 20, "Invalid pack folders")
    local out = {}
    for _, name in ipairs(list) do
        assert(OTA.safePath(name) and not name:find("/", 1, true) and not out[name:lower()], "Invalid folder")
        out[name:lower()] = name
    end
    return out
end
function M.asset(a)
    assert(type(a) == "table" and integer(a.size) and a.size <= M.MAX_ZIP and hash(a.sha256), "Invalid asset")
    local trusted = false
    for _, repo in ipairs({ M.REPO, M.LEGACY_REPO }) do
        local base = releaseBase(repo)
        if type(a.url) == "string" and a.url:sub(1, #base) == base
                and a.url:sub(#base + 1):match("^ornaments%-%d+/[a-z0-9%-]+%.[a-z]+$") then trusted = true end
    end
    assert(trusted, "Untrusted asset URL")
    return a
end
function M.catalog(value)
    assert(type(value) == "table" and value.schema == 1 and value.api == M.API
        and integer(value.revision) and type(value.packs) == "table" and #value.packs <= 100, "Unsupported ornament catalog")
    local seen, names = {}, {}
    for _, pack in ipairs(value.packs) do
        assert(id(pack.id) and not seen[pack.id] and integer(pack.version), "Invalid pack identity/version")
        seen[pack.id] = true
        assert(text(pack.name, 100) and text(pack.description, 2000), "Invalid pack description")
        for name in pairs(folders(pack.folders)) do
            assert(not names[name], "Overlapping packs"); names[name] = true
        end
        M.asset(pack)
        if pack.preview then M.asset(pack.preview); assert(pack.preview.size <= M.MAX_FILE, "Preview too large") end
    end
    return value
end
local function fetchCatalog(repo)
    local HTTP = require("core/orbitui_http")
    local ok, body = pcall(HTTP.get,
        "https://api.github.com/repos/" .. repo .. "/releases?per_page=100", nil, 2 * 1024 * 1024)
    if not ok then return nil, body end
    local releases = require("rapidjson").decode(body)
    assert(type(releases) == "table", "Invalid add-on releases response")
    local best, revision = nil, 0
    for _, release in ipairs(releases) do
        local n = tonumber((release.tag_name or ""):match("^ornaments%-(%d+)$"))
        if not release.draft and n and n > revision then best, revision = release, n end
    end
    if not best then return nil, "No ornament catalog has been published yet" end
    local url = releaseBase(repo) .. best.tag_name .. "/ornaments-catalog.json"
    local present = false
    for _, a in ipairs(best.assets or {}) do
        if a.name == "ornaments-catalog.json" and a.browser_download_url == url then present = true end
    end
    assert(present, "Catalog asset missing")
    local catalog = M.catalog(require("rapidjson").decode(HTTP.get(url, nil, 1024 * 1024)))
    assert(catalog.revision == revision, "Catalog revision mismatch")
    return catalog
end
function M.fetchCatalog()
    -- Fall back only for an unavailable/empty channel, never an invalid catalog.
    -- Old URLs stay trusted so cached catalogs and installed packs keep working.
    local catalog = fetchCatalog(M.REPO)
    if catalog then return catalog end
    local legacy, err = fetchCatalog(M.LEGACY_REPO)
    return assert(legacy, err)
end

local allowed = { png = true, jpg = true, jpeg = true, json = true, txt = true, md = true }
function M.filePath(path, owned)
    local folder = type(path) == "string" and path:match("^([^/]+)/") or ""
    folder = folder or ""
    return OTA.safePath(path) and owned[folder:lower()] == folder
        and allowed[(path:match("%.([^%.]+)$") or ""):lower()] and select(2, path:gsub("/", "")) <= 2
end
function M.manifest(m, pack)
    assert(type(m) == "table" and m.schema == 1 and m.api == M.API and m.id == pack.id
        and m.version == pack.version and type(m.files) == "table" and #m.files <= 1000, "Invalid pack manifest")
    local owned, expected, total = folders(pack.folders), {}, 0
    for name, exact in pairs(folders(m.folders)) do assert(owned[name] == exact, "Unexpected pack folder") end
    local cases = {}
    for _, f in ipairs(m.files) do
        assert(M.filePath(f.path, owned) and not cases[f.path:lower()], "Unsafe/duplicate pack path")
        assert(type(f.size) == "number" and f.size >= 0 and f.size <= M.MAX_FILE and hash(f.sha256), "Invalid file inventory")
        total = total + f.size; assert(total <= 192 * 1024 * 1024, "Expanded pack too large")
        cases[f.path:lower()], expected[f.path] = true, f
    end
    for path, binding in pairs(m.bindings or {}) do
        assert(expected[path] and path:lower():match("%.png$"), "Binding without an ornament")
        assert(type(binding) == "table" and (binding.kind == "author" or binding.kind == "series")
            and text(binding.id, 120) and #binding.id > 0 and type(binding.names) == "table"
            and #binding.names > 0 and #binding.names <= 40, "Invalid binding")
        assert((binding.kind == "series") == (binding.id:sub(1, 7) == "series:"), "Invalid target category")
        for _, name in ipairs(binding.names) do assert(text(name, 200), "Invalid target alias") end
    end
    return expected
end

function M.extract(zip, target)
    F.mkdir(target)
    local arc = require("ffi/archiver").Reader:new()
    local seen, files, total, count = {}, {}, 0, 0
    local ok, err = pcall(function()
        assert(arc:open(zip), arc.err or "Could not open ornament ZIP")
        for e in arc:iterate() do
            count = count + 1; assert(count <= 1200, "Too many ZIP entries")
            assert(OTA.safePath(e.path), "Unsafe ZIP path")
            local identity = e.path:gsub("/$", ""):lower()
            assert(not seen[identity], "Duplicate ZIP path"); seen[identity] = true
            assert(e.mode == "file" or e.mode == "directory", "Links/special files are forbidden")
            if e.mode == "file" then
                local size = tonumber(e.size)
                assert(size and size >= 0 and size <= M.MAX_FILE, "Oversized ZIP file")
                total = total + size; assert(total <= 192 * 1024 * 1024, "Expanded pack too large")
                local data = assert(arc:extractToMemory(e.path), arc.err)
                assert(#data == size, "Truncated ZIP file")
                F.write(target .. "/" .. e.path, data); files[#files + 1] = e.path
            end
        end
        assert(not arc.err, arc.err)
    end)
    arc:close(); assert(ok, err)
    return files
end
function M.png(path)
    local f = assert(io.open(path, "rb")); local h = f:read(24); f:close()
    assert(h and #h == 24 and h:sub(1, 8) == "\137PNG\13\10\26\10" and h:sub(13, 16) == "IHDR", "Invalid PNG")
    local function u32(i) local a,b,c,d = h:byte(i, i + 3); return ((a*256+b)*256+c)*256+d end
    local w, ht = u32(17), u32(21)
    assert(w > 0 and ht > 0 and w <= 8192 and ht <= 8192 and w * ht <= 32 * 1024 * 1024, "Oversized PNG")
    return w / ht
end
function M.jpeg(path)
    local bytes = assert(F.read(path, M.MAX_FILE))
    assert(bytes:sub(1, 2) == "\255\216", "Invalid JPEG")
    local pos = 3
    while pos < #bytes do
        assert(bytes:byte(pos) == 255, "Invalid JPEG marker")
        repeat pos = pos + 1 until bytes:byte(pos) ~= 255
        local marker = bytes:byte(pos); pos = pos + 1
        assert(marker and marker ~= 218 and marker ~= 217, "JPEG dimensions missing")
        local a, b = bytes:byte(pos, pos + 1)
        assert(a and b, "Truncated JPEG")
        local size = a * 256 + b
        assert(size >= 2 and pos + size - 1 <= #bytes, "Invalid JPEG segment")
        if marker >= 192 and marker <= 207 and marker ~= 196 and marker ~= 200 and marker ~= 204 then
            assert(size >= 8, "Invalid JPEG dimensions")
            local h1,h2,w1,w2 = bytes:byte(pos + 3, pos + 6)
            local h, w = h1 * 256 + h2, w1 * 256 + w2
            assert(w > 0 and h > 0 and w <= 8192 and h <= 8192 and w * h <= 32 * 1024 * 1024, "Oversized JPEG")
            return w / h
        end
        pos = pos + size
    end
    error("JPEG dimensions missing")
end
function M.validate(target, files, pack)
    local m = F.json(target .. "/manifest.json")
    local expected = M.manifest(m, pack)
    assert(#files == #m.files + 1, "Incomplete pack")
    for _, path in ipairs(files) do assert(path == "manifest.json" or expected[path], "Unlisted pack file") end
    for path, f in pairs(expected) do
        local a = F.attr(target .. "/" .. path)
        assert(a and a.mode == "file" and a.size == f.size and OTA.hashFile(target .. "/" .. path) == f.sha256,
            "Ornament checksum mismatch: " .. path)
        if path:lower():match("%.png$") then M.png(target .. "/" .. path) end
        if path:lower():match("%.jpe?g$") then M.jpeg(target .. "/" .. path) end
        if path:match("/ornaments%.json$") then
            local metadata = F.json(target .. "/" .. path)
            for name, directives in pairs(metadata) do
                assert(OTA.safePath(name) and not name:find("/", 1, true) and type(directives) == "table", "Invalid ornament metadata")
                assert(directives.tap == nil or directives.tap == "zoom", "Remote ornament actions are forbidden")
                for _, v in pairs(directives) do
                    assert(type(v) == "number" or type(v) == "boolean" or text(v, 12000), "Invalid ornament directive")
                end
            end
            assert(type(m.defaults) == "table", "Missing metadata defaults")
            -- Use the actual verified file as the defaults, never a second unverified interpretation.
            m.defaults[path] = metadata
        end
    end
    return m
end

function M.merge(old, local_value, new)
    if type(old) ~= "table" or type(local_value) ~= "table" or type(new) ~= "table" then
        if local_value == old then return new end
        return local_value
    end
    local keys, out = {}, {}
    for k in pairs(old) do keys[k] = true end
    for k in pairs(local_value) do keys[k] = true end
    for k in pairs(new) do keys[k] = true end
    for k in pairs(keys) do out[k] = M.merge(old[k], local_value[k], new[k]) end
    return out
end

function M.new(root, directory, legacy_roots)
    return setmetatable({ root = root, directory = directory, legacy = legacy_roots or {}, hashes = {} }, Store)
end
function M.placement(value) return value == "random" and "random" or "matched" end
function Store:registry()
    local s = F.json(self.directory .. "/installed.json", true) or { schema = 1, revision = 0, packs = {} }
    assert(s.schema == 1 and type(s.revision) == "number" and type(s.packs) == "table", "Unsupported add-on state; not changed")
    for key, r in pairs(s.packs) do
        assert(id(key) and type(r) == "table" and slotId(r.slot) and type(r.pack) == "table"
            and r.pack.id == key and integer(r.pack.version), "Invalid installed pack")
        folders(r.pack.folders)
    end
    return s
end
function Store:save(s)
    s.revision = s.revision + 1
    F.save(self.directory .. "/installed.json", s)
    self.hashes = {}
end
function Store:catalog()
    local c = F.json(self.directory .. "/catalog.json", true)
    return c and M.catalog(c) or F.json(self.root .. "/assets/addons/catalog.json")
end
function Store:saveCatalog(c)
    M.catalog(c)
    local old = self:catalog()
    assert(c.revision >= (old.revision or 0), "Catalog downgrade rejected")
    local current = {}; for _, p in ipairs(old.packs) do current[p.id] = p end
    for _, p in ipairs(c.packs) do
        local prev = current[p.id]
        if prev and prev.sha256 then
            assert(p.version >= prev.version, "Pack downgrade rejected")
            assert(p.version ~= prev.version or p.sha256 == prev.sha256, "Version reused with different content")
        end
    end
    F.save(self.directory .. "/catalog.json", c)
end
function Store:baseline()
    if not self._baseline then self._baseline = F.json(self.root .. "/assets/addons/legacy-v1.json").packs end
    return self._baseline
end
function Store:versionRoot(r) return self.directory .. "/versions/" .. r.slot end
local sequence = 0
function Store:slot(pack)
    F.mkdir(self.directory .. "/versions")
    while true do
        sequence = sequence + 1
        local slot = pack.id .. "-" .. pack.version .. "-" .. os.time() .. "-" .. sequence
        if not F.attr(self.directory .. "/versions/" .. slot) then return slot end
    end
end
function Store:prepare(pack)
    M.asset(pack); folders(pack.folders); assert(id(pack.id) and integer(pack.version), "Invalid pack")
    local state = self:registry()
    local previous = state.packs[pack.id]
    local owned = folders(pack.folders)
    for key, record in pairs(state.packs) do
        if key ~= pack.id then
            for folder in pairs(folders(record.pack.folders)) do assert(not owned[folder], "Pack folder already owned") end
        end
    end
    if previous then
        assert(pack.version >= previous.pack.version, "Installed pack is newer")
        if pack.version == previous.pack.version then assert(pack.sha256 == previous.pack.sha256, "Version hash changed") end
    end
    self:cleanup(state)
    local slot = self:slot(pack)
    local target = self.directory .. "/versions/" .. slot
    F.mkdir(target)
    local zip = target .. "/download.zip"
    require("core/orbitui_http").get(pack.url, zip, pack.size)
    assert(F.attr(zip).size == pack.size and OTA.hashFile(zip) == pack.sha256, "Download checksum mismatch")
    local files = M.extract(zip, target); assert(os.remove(zip))
    local manifest = M.validate(target, files, pack)
    local old = previous and F.json(self:versionRoot(previous) .. "/manifest.json") or self:baseline()[pack.id]
    if old then
        for folder, exact in pairs(folders(old.folders)) do assert(owned[folder] == exact, "Updates must retain compatibility folders") end
    end
    local adopted = previous and previous.adopted or {}
    local was_local = false
    -- Preserve user edits and deletions; native reader overrides are never touched.
    if old then
        local before = {}; for _, f in ipairs(old.files) do before[f.path] = f end
        local function preserve(path, source, exists)
            local origin = before[path]
            if not origin then return end
            local attr = F.attr(source)
            if not attr then
                if exists then F.remove(target .. "/" .. path) end
            elseif attr.mode == "file" and OTA.hashFile(source) ~= origin.sha256 then
                if path:match("/ornaments%.json$") then
                    local current = F.json(source)
                    F.save(target .. "/" .. path, M.merge((old.defaults or {})[path] or {}, current,
                        (manifest.defaults or {})[path] or {}))
                else F.copy(source, target .. "/" .. path) end
            end
        end
        if previous then
            local prior_root = self:versionRoot(previous)
            for path in pairs(before) do preserve(path, prior_root .. "/" .. path, not previous.removed) end
            for _, path in ipairs(F.walk(prior_root)) do
                if path ~= "manifest.json" and not before[path] then
                    assert(M.filePath(path, folders(pack.folders)), "Unsupported local file in managed pack")
                    F.copy(prior_root .. "/" .. path, target .. "/" .. path)
                end
            end
        else
            for path, origin in pairs(before) do
                for _, native in ipairs(self.legacy) do
                    local parent = native .. "/" .. assert(path:match("^(.*)/"))
                    if F.attr(parent) then
                        was_local = true
                        local source = native .. "/" .. path
                        preserve(path, source, true)
                        adopted[path] = { path = source, hash = origin.sha256, missing = not F.attr(source) or nil }
                        break
                    end
                end
            end
        end
    end
    F.save(target .. "/manifest.json", manifest)
    return { revision = state.revision, id = pack.id,
        record = { slot = slot, pack = pack, adopted = adopted,
            placement = previous and previous.placement,
            enabled = previous and previous.enabled ~= false or (not previous and was_local) } }
end
function Store:cleanup(state)
    if not F.attr(self.directory .. "/versions") then return end
    local keep = {}; for _, r in pairs(state.packs) do keep[r.slot] = true end
    local fs = require("libs/libkoreader-lfs")
    for slot in fs.dir(self.directory .. "/versions") do
        if slotId(slot) and not keep[slot] then
            local ok, err = pcall(F.remove, self.directory .. "/versions/" .. slot)
            if not ok then require("logger").warn("[OrbitUI] Could not reclaim old add-on data", err) end
        end
    end
end
function Store:activate(plan)
    local state = self:registry()
    assert(plan.revision == state.revision, "Add-on settings changed; retry installation")
    assert(id(plan.id) and slotId(plan.record.slot), "Invalid installation plan")
    assert(F.attr(self:versionRoot(plan.record) .. "/manifest.json"), "Prepared pack missing")
    state.packs[plan.id] = plan.record
    self:save(state)
    -- Old edits have been copied into the new snapshot before activation.
    self:cleanup(state)
end
function Store:enable(pack_id, enabled)
    local state = self:registry(); local r = assert(state.packs[pack_id], "Pack is not installed")
    assert(not r.removed, "Pack is uninstalled"); r.enabled = enabled == true; self:save(state)
end
function Store:setPlacement(pack_id, mode)
    assert(mode == "matched" or mode == "random", "Invalid ornament placement")
    local state = self:registry(); local r = assert(state.packs[pack_id], "Pack is not installed")
    assert(not r.removed, "Pack is uninstalled")
    if M.placement(r.placement) == mode then return end
    r.placement = mode
    self:save(state)
end
function Store:uninstall(pack_id)
    local state = self:registry(); local r = assert(state.packs[pack_id], "Pack is not installed")
    local old = F.json(self:versionRoot(r) .. "/manifest.json")
    -- Hide first; a cleanup failure cannot re-enable an uninstalled pack.
    r.removed, r.enabled = true, true; self:save(state)
    for _, f in ipairs(old.files) do
        local path = self:versionRoot(r) .. "/" .. f.path
        local a = F.attr(path)
        if a and a.mode == "file" and OTA.hashFile(path) == f.sha256 then F.remove(path) end
    end
    self.hashes = {}
end
function Store:same(path, digest)
    local a = F.attr(path)
    if not a or a.mode ~= "file" then return false end
    local key = path .. ":" .. a.size .. ":" .. tostring(a.modification) .. ":" .. tostring(a.change)
    if not self.hashes[key] then self.hashes[key] = OTA.hashFile(path) end
    return self.hashes[key] == digest
end
function Store:packDir(pack, native)
    for _, r in pairs(self:registry().packs) do
        for _, folder in ipairs(r.pack.folders) do
            if folder == pack and not r.removed then
                if native then
                    -- A user-supplied/edited theme still wins; otherwise themed
                    -- add-on updates must not keep reading the old native files.
                    for _, path in ipairs(F.walk(native .. "/theme")) do
                        local rel = pack .. "/theme/" .. path
                        local prior = (r.adopted or {})[rel]
                        if not prior or not self:same(native .. "/theme/" .. path, prior.hash) then return native end
                    end
                end
                local path = self:versionRoot(r) .. "/" .. pack
                if F.attr(path) then return path end
            end
        end
    end
    return native
end
function Store:view()
    local state, roots, managed, owners, removed = self:registry(), {}, {}, {}, {}
    for pack_id, r in pairs(state.packs) do
        local root = self:versionRoot(r)
        if F.attr(root) then roots[#roots + 1] = root; managed[root] = r end
        if r.removed and F.attr(root) then
            removed[root] = {}
            for _, f in ipairs(F.json(root .. "/manifest.json").files) do removed[root][f.path] = f.sha256 end
        end
        for _, folder in ipairs(r.pack.folders) do owners[folder] = r end
    end
    table.sort(roots)
    local function accept(path, name, root)
        local r = owners[name:match("^([^/]+)/")]
        if not r then return true end
        local a = (r.adopted or {})[name]
        if managed[root] then
            if removed[root] and removed[root][name] and self:same(path, removed[root][name]) then return false end
            if a and (not F.attr(a.path) or not self:same(a.path, a.hash)) then return false end
            return true
        end
        return not (a and a.path == path and self:same(path, a.hash))
    end
    local function enabled(entry)
        local r = owners[entry.pack]
        return not r or r.enabled ~= false
    end
    return roots, accept, enabled, state
end
return M
