-- Upgrade known defaults only; a partial write can resume using the new hash.
local M = {
    marker = "ornament-author-sculptures-v1.updated",
    baseline = "assets/ornament-updates/author-sculptures-v1.json",
    notice = "AUTHOR-SCULPTURES.txt",
    files = {
        ["August Strindberg.png"] = true, ["Knut Hamsun.png"] = true,
        ["Fyodor Dostoevsky.png"] = true, ["Dylan Thomas.png"] = true,
        ["Stanislaw Lem.png"] = true, ["Robert Musil.png"] = true,
    },
}

local function decode(path)
    local f = assert(io.open(path, "rb"))
    local ok, bytes = pcall(function() return assert(f:read("*a")) end)
    f:close()
    assert(ok, bytes)
    local value = require("rapidjson").decode(bytes)
    assert(type(value) == "table", "Invalid sculpture update metadata")
    return value
end

local function contains(values, value)
    for _, expected in ipairs(values) do if expected == value then return true end end
    return false
end

function M.apply(root, ornaments_dir)
    local Install = require("core/orbitui_ornament_install")
    if Install.installed(M.marker) then return false end
    local fs = require("libs/libkoreader-lfs")
    local function mode(path) return fs.symlinkattributes(path, "mode") end
    local source = root .. "/assets/ornaments/Authors/"
    local target = ornaments_dir .. "/Authors/"
    local changed, eligible = false, false
    if mode(ornaments_dir .. "/Authors") == "directory"
        and mode(target .. "ornaments.json") == "file" then
        local baseline = decode(root .. "/" .. M.baseline)
        local hash = require("core/orbitui_ota").hashFile
        local metadata = decode(target .. "ornaments.json")
        local bundled
        for _, before in ipairs(baseline.assets) do
            local name = before.file
            assert(M.files[name], "Unexpected sculpture update")
            local entry = metadata[name]
            if type(entry) == "table" and mode(target .. name) == "file" then
                local current = hash(target .. name)
                if current == before.old_sha256 or current == before.new_sha256 then
                    assert(hash(source .. name) == before.new_sha256, "Invalid bundled sculpture image")
                    bundled = bundled or decode(source .. "ornaments.json")
                    local new = bundled[name]
                    assert(type(new) == "table" and type(new.info) == "string"
                        and #new.info > 0 and #new.info <= 4000, "Invalid sculpture caption")
                    -- Keep per-file credits even if the shared notices were customized.
                    if not mode(target .. M.notice) then
                        Install.copy(source .. M.notice, target .. M.notice)
                        changed = true
                    end
                    eligible = true
                    if current == before.old_sha256 then
                        Install.copy(source .. name, target .. name)
                        changed = true
                    end
                    local dirty = false
                    if contains(before.old_info, entry.info) and entry.info ~= new.info then
                        entry.info, dirty = new.info, true
                    end
                    local old = before.old_placement
                    if entry.scale == old.scale and entry.anchor == old.anchor and entry.lift == old.lift then
                        for _, key in ipairs({ "scale", "anchor", "lift" }) do
                            if entry[key] ~= new[key] then entry[key], dirty = new[key], true end
                        end
                    end
                    if dirty then
                        Install.write(target .. "ornaments.json",
                            assert(require("rapidjson").encode(metadata, { pretty = true, sort_keys = true })))
                        changed = true
                    end
                end
            end
        end
        if eligible then
            for name, hashes in pairs(baseline.documents) do
                if mode(target .. name) == "file" and contains(hashes, hash(target .. name)) then
                    Install.copy(source .. name, target .. name)
                    changed = true
                end
            end
        end
    end
    Install.mark(source .. M.notice, M.marker)
    return changed
end

return M
