local M = { REPO = "komadorirobin/orbitui.koplugin", ASSET = "orbitui.koplugin.zip" }
local Boot = require("orbitui_bootstrap")
local MAX_ZIP, MAX_TOTAL, MAX_FILE = 128 * 1024 * 1024, 256 * 1024 * 1024, 32 * 1024 * 1024

function M.version(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^v", "")
    local a, b, c, suffix = value:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
    if not a then return nil end
    local rank, number = 4, 0
    if suffix ~= "" then
        local kind, n = suffix:match("^%-([a-z]+)%.(%d+)$")
        rank, number = ({ alpha = 1, beta = 2, rc = 3 })[kind], tonumber(n)
        if not rank or not number then return nil end
    end
    return { tonumber(a), tonumber(b), tonumber(c), rank, number }, value
end

function M.newer(left, right)
    local a, b = assert(M.version(left), "Invalid release version"), assert(M.version(right), "Invalid installed version")
    for i = 1, 5 do
        if a[i] ~= b[i] then return a[i] > b[i] end
    end
    return false
end

function M.select(releases, preview)
    assert(type(releases) == "table", "Invalid GitHub releases response")
    local best
    for _, release in ipairs(releases) do
        local parts, version = M.version(release.tag_name)
        if parts and not release.draft and (preview or (not release.prerelease and parts[4] == 4)) then
            if not best or M.newer(version, best.version) then
                best = { version = version, tag = release.tag_name, assets = release.assets or {} }
            end
        end
    end
    if not best then return nil end
    local base = "https://github.com/" .. M.REPO .. "/releases/download/" .. best.tag .. "/"
    for _, asset in ipairs(best.assets) do
        if asset.name == M.ASSET or asset.name == M.ASSET .. ".sha256" then
            assert(asset.browser_download_url == base .. asset.name, "Unexpected release asset URL")
            assert(type(asset.size) == "number" and asset.size > 0 and asset.size <= MAX_ZIP, "Invalid asset size")
            local key = asset.name == M.ASSET and "zip" or "checksum"
            assert(not best[key], "Duplicate release asset")
            best[key] = { url = asset.browser_download_url, size = asset.size }
        end
    end
    assert(best.zip and best.checksum, "Latest release is incomplete (ZIP/checksum missing)")
    best.assets = nil
    return best
end

function M.check(preview)
    local body = require("core/orbitui_http").get("https://api.github.com/repos/" .. M.REPO .. "/releases?per_page=100", nil, 4 * 1024 * 1024)
    return M.select(require("rapidjson").decode(body), preview)
end

function M.safePath(path)
    if type(path) ~= "string" or path == "" or #path > 512 or path:find("[%z%c\\:]")
            or path:sub(1, 1) == "/" or path:find("//", 1, true) then return false end
    for segment in path:gmatch("[^/]+") do
        if segment:sub(1, 1) == "." or segment:find("%.koplugin$")
                or segment:match("[. ]$") then return false end
    end
    return true
end

function M.hashFile(path)
    local digest = require("ffi/sha2").sha256()
    local f = assert(io.open(path, "rb"))
    local ok, err = pcall(function()
        while true do
            local chunk, read_error = f:read(65536)
            assert(not read_error, read_error)
            if not chunk then break end
            digest(chunk)
        end
    end)
    f:close()
    assert(ok, err)
    return digest()
end

local function mkdir(path)
    local lfs = require("libs/libkoreader-lfs")
    local mode = lfs.symlinkattributes(path, "mode")
    if mode then assert(mode == "directory", "Not a plain directory: " .. path)
    else assert(lfs.mkdir(path)) end
end

local function removeTree(path)
    local lfs = require("libs/libkoreader-lfs")
    local mode = lfs.symlinkattributes(path, "mode")
    if mode == "directory" then
        for name in lfs.dir(path) do
            if name ~= "." and name ~= ".." then removeTree(path .. "/" .. name) end
        end
        assert(lfs.rmdir(path))
    elseif mode then assert(os.remove(path)) end
end

local function writeFile(root, path, data)
    local parent = root
    for part in (path:match("^(.*)/") or ""):gmatch("[^/]+") do
        parent = parent .. "/" .. part
        mkdir(parent)
    end
    local f = assert(io.open(root .. "/" .. path, "wb"))
    local written, err = f:write(data)
    local closed, close_error = f:close()
    assert(written, err)
    assert(closed, close_error)
end

function M.extract(zip, target)
    local arc = require("ffi/archiver").Reader:new()
    local seen, files, total = {}, {}, 0
    local ok, err = pcall(function()
        assert(arc:open(zip), arc.err or "Could not open ZIP")
        for entry in arc:iterate() do
            assert(type(entry.path) == "string", "Missing archive path")
            local path = entry.path:match("^orbitui%.koplugin/(.*)$")
            assert(path and (path == "" or M.safePath(path)), "Unsafe archive path")
            assert(entry.mode == "file" or entry.mode == "directory", "Archive links/special files are forbidden")
            local identity = path:gsub("/$", ""):lower()
            assert(not seen[identity], "Duplicate archive path")
            seen[identity] = true
            if entry.mode == "file" then
                assert(path ~= "" and path:sub(-1) ~= "/", "Invalid file path")
                local size = tonumber(entry.size)
                assert(size and size >= 0 and size <= MAX_FILE, "Archive file too large")
                total = total + size
                assert(total <= MAX_TOTAL and #files < 2000, "Archive exceeds extraction limit")
                -- Read bytes, not archive filesystem metadata: links cannot escape staging.
                local content = assert(arc:extractToMemory(entry.path), arc.err or "Archive read failed")
                assert(#content == size, "Short archive read")
                writeFile(target, path, content)
                files[#files + 1] = path
            end
        end
        assert(not arc.err, arc.err)
    end)
    arc:close()
    assert(ok, err)
    return files
end

function M.inventory(manifest)
    assert(type(manifest) == "table" and manifest.schema == 1 and manifest.bootstrap_api == Boot.API,
        "Unsupported OTA/bootstrap format; install manually")
    assert(type(manifest.files) == "table" and #manifest.files < 2000, "Invalid package inventory")
    local files, seen, total = { "manifest.json" }, {}, 0
    for _, entry in ipairs(manifest.files) do
        assert(type(entry) == "table" and M.safePath(entry.path) and entry.path:sub(-1) ~= "/"
            and entry.path:lower() ~= "manifest.json" and not seen[entry.path:lower()], "Invalid manifest path")
        assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^[0-9a-f]+$"), "Invalid manifest hash")
        assert(type(entry.size) == "number" and entry.size >= 0 and entry.size <= MAX_FILE
            and entry.size == math.floor(entry.size), "Invalid manifest file size")
        total = total + entry.size
        assert(total <= MAX_TOTAL - 1024 * 1024, "Package exceeds size limit")
        seen[entry.path:lower()] = true
        files[#files + 1] = entry.path
    end
    return files
end

local function plainFile(root, path)
    local fs, parent = require("libs/libkoreader-lfs"), root
    assert(fs.symlinkattributes(parent, "mode") == "directory", "Not a plain runtime directory")
    for part in (path:match("^(.*)/") or ""):gmatch("[^/]+") do
        parent = parent .. "/" .. part
        assert(fs.symlinkattributes(parent, "mode") == "directory", "Not a plain directory: " .. parent)
    end
    return fs.symlinkattributes(root .. "/" .. path)
end

function M.validate(target, files, release, install_root)
    local manifest = require("rapidjson").decode(assert(Boot.read(target .. "/manifest.json", 1024 * 1024)))
    M.inventory(manifest)
    assert(manifest.version == release.version and Boot.version(target) == release.version, "Package version mismatch")
    local expected = {}
    for _, entry in ipairs(manifest.files) do
        local attr = plainFile(target, entry.path)
        assert(attr and attr.mode == "file" and attr.size == entry.size, "Missing/incomplete file: " .. entry.path)
        assert(M.hashFile(target .. "/" .. entry.path) == entry.sha256, "File checksum mismatch: " .. entry.path)
        expected[entry.path] = true
        if entry.path:match("%.lua$") then assert(loadfile(target .. "/" .. entry.path)) end
    end
    for _, path in ipairs(files) do
        assert(path == "manifest.json" or expected[path], "File absent from manifest: " .. path)
    end
    assert(#files == #manifest.files + 1, "Incomplete package inventory")
    for _, path in ipairs({ "VERSION", "main.lua", "_meta.lua", "orbitui_bootstrap.lua", "core/orbitui_plugin.lua",
        "core/orbitui_runtime.lua", "core/orbitui_ota.lua", "adapters/orbitui_updates.lua",
        "components/bookshelf/main.lua", "components/simpleui/main.lua", "assets/ca-bundle.crt", "LICENSE" }) do
        assert(expected[path], "Required runtime file missing: " .. path)
    end
    for _, path in ipairs({ "main.lua", "_meta.lua", "orbitui_bootstrap.lua" }) do
        assert(M.hashFile(target .. "/" .. path) == M.hashFile(install_root .. "/" .. path),
            "Stable bootstrap changed; this release requires manual installation")
    end
end

-- Inspect only data from the externally overwritten root. Its code must never
-- be loaded into the already-running OTA runtime, even during verification.
function M.externalCandidate(context, retry)
    local state = Boot.state(context.root)
    if context.slot == "factory" or state.pending or state.current ~= context.slot then return end
    local version = Boot.read(context.root .. "/VERSION", 80)
    version = version and version:match("^([%w.%-]+)%s*$")
    if not M.version(version) or not M.newer(version, context.version) then return end
    local attr = plainFile(context.root, "manifest.json")
    assert(attr and attr.mode == "file" and attr.size <= 1024 * 1024, "External update has no valid manifest")
    local digest = M.hashFile(context.root .. "/manifest.json")
    if not retry and Boot.read(context.root .. "/.orbitui-external-attempt", 80) == digest then return end
    return { version = version, slot = digest }
end

function M.prepareExternal(context, candidate)
    local current = assert(M.externalCandidate(context, true), "No newer external update is available")
    assert(current.slot == candidate.slot and current.version == candidate.version, "External update changed; retry")
    local manifest = require("rapidjson").decode(assert(Boot.read(context.root .. "/manifest.json", 1024 * 1024)))
    local files = M.inventory(manifest)
    assert(manifest.version == candidate.version, "External package version mismatch")
    local work = context.root .. "/.orbitui-work"
    removeTree(work); mkdir(work)
    local staging = work .. "/runtime"
    mkdir(staging)
    for i, path in ipairs(files) do
        local attr = plainFile(context.root, path)
        local limit = path == "manifest.json" and 1024 * 1024 or MAX_FILE
        local size = i == 1 and attr and attr.size or manifest.files[i - 1].size
        assert(attr and attr.mode == "file" and attr.size == size and size <= limit, "Invalid external file: " .. path)
        local data = assert(Boot.read(context.root .. "/" .. path, size))
        assert(#data == size, "External file changed while copying: " .. path)
        writeFile(staging, path, data)
    end
    assert(M.hashFile(staging .. "/manifest.json") == candidate.slot, "External manifest changed while copying")
    M.validate(staging, files, candidate, context.runtime)
    local state = Boot.state(context.root)
    assert(not state.pending and state.current == context.slot, "Restart before updating again")
    mkdir(context.root .. "/.orbitui-versions")
    local destination = Boot.path(context.root, candidate.slot)
    if candidate.slot == state.current or candidate.slot == state.previous then
        assert(M.hashFile(destination .. "/manifest.json") == candidate.slot, "Retained snapshot changed")
        M.validate(destination, files, candidate, context.runtime)
    else
        removeTree(destination)
        assert(os.rename(staging, destination))
    end
    removeTree(work)
    return { slot = candidate.slot, version = candidate.version }
end

function M.activateExternal(context, plan)
    local state = Boot.state(context.root)
    assert(not state.pending and state.current == context.slot and Boot.validSlot(plan.slot)
        and plan.slot ~= "factory" and plan.slot ~= state.current, "External activation is stale")
    assert(Boot.version(Boot.path(context.root, plan.slot)) == plan.version, "Prepared external update missing")
    -- Record before activation: a failed boot/manual rollback must never select
    -- the same root again. A power loss between writes is recoverable via Retry.
    Boot.atomicWrite(context.root .. "/.orbitui-external-attempt", plan.slot)
    Boot.activate(context.root, plan.slot)
end

-- No activation here. A killed subprocess can only leave inactive staging data.
function M.prepare(context, release)
    local HTTP = require("core/orbitui_http")
    local state = Boot.state(context.root)
    assert(not state.pending and state.current == context.slot, "Restart before updating again")
    local work = context.root .. "/.orbitui-work"
    removeTree(work)
    mkdir(work)
    local sum = HTTP.get(release.checksum.url, nil, 256)
    local digest, filename = sum:match("^([0-9a-f]+)%s+([^%s]+)%s*$")
    assert(digest and #digest == 64 and filename == M.ASSET, "Invalid release checksum file")
    local zip = work .. "/update.zip"
    local received = HTTP.get(release.zip.url, zip, MAX_ZIP)
    assert(received == release.zip.size, "Downloaded ZIP size mismatch")
    assert(M.hashFile(zip) == digest, "Downloaded ZIP checksum mismatch")
    local staging = work .. "/runtime"
    mkdir(staging)
    local files = M.extract(zip, staging)
    M.validate(staging, files, release, context.root)
    local versions = context.root .. "/.orbitui-versions"
    mkdir(versions)
    for slot in require("libs/libkoreader-lfs").dir(versions) do
        if slot ~= "factory" and Boot.validSlot(slot) and slot ~= state.current and slot ~= state.previous then
            removeTree(Boot.path(context.root, slot))
        end
    end
    local destination = Boot.path(context.root, digest)
    assert(digest ~= state.current and digest ~= state.previous, "This package is already retained; use rollback")
    removeTree(destination)
    assert(os.rename(staging, destination))
    removeTree(work)
    return { slot = digest, version = release.version }
end

return M
