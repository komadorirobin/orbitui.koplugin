-- Replace only the known default; keep reader artwork, captions and overrides.
local Update = {}

local function decode(path)
    local f = assert(io.open(path, "rb"))
    local ok, bytes = pcall(function() return assert(f:read("*a")) end)
    f:close()
    assert(ok, bytes)
    local value = require("rapidjson").decode(bytes)
    assert(type(value) == "table", "Invalid ornament update metadata")
    return value
end

local function contains(values, value)
    for _, expected in ipairs(values) do if expected == value then return true end end
    return false
end

function Update.apply(root, ornaments_dir, M)
    local Install = require("core/orbitui_ornament_install")
    if Install.installed(M.marker) then return false end
    local fs = require("libs/libkoreader-lfs")
    local function mode(path) return fs.symlinkattributes(path, "mode") end
    local source = root .. "/assets/ornaments/" .. M.pack .. "/"
    local target = ornaments_dir .. "/" .. M.pack .. "/"
    local changed = false
    if mode(ornaments_dir .. "/" .. M.pack) == "directory"
        and mode(target .. M.file) == "file"
        and mode(target .. "ornaments.json") == "file" then
        local baseline = decode(root .. "/" .. M.baseline)
        local hash = require("core/orbitui_ota").hashFile
        local current = hash(target .. M.file)
        if contains(baseline.old_sha256, current) or current == baseline.new_sha256 then
            local metadata = decode(target .. "ornaments.json")
            local entry = metadata[M.file]
            if type(entry) == "table" then
                assert(hash(source .. M.file) == baseline.new_sha256, "Invalid bundled ornament image")
                local new = decode(source .. "ornaments.json")[M.file]
                assert(type(new) == "table" and type(new.info) == "string"
                    and #new.info > 0 and #new.info <= 4000, "Invalid ornament caption")
                -- Dedicated provenance survives edits to the shared pack notices.
                if not mode(target .. M.notice) then
                    Install.copy(source .. M.notice, target .. M.notice)
                    changed = true
                end
                if contains(baseline.old_sha256, current) then
                    Install.copy(source .. M.file, target .. M.file)
                    changed = true
                end
                local dirty = false
                if contains(baseline.old_info, entry.info) and entry.info ~= new.info then
                    entry.info, dirty = new.info, true
                end
                for _, old in ipairs(baseline.old_placements) do
                    if entry.scale == old.scale and entry.anchor == old.anchor and entry.lift == old.lift then
                        for _, key in ipairs({ "scale", "anchor", "lift" }) do
                            if entry[key] ~= new[key] then entry[key], dirty = new[key], true end
                        end
                        break
                    end
                end
                if dirty then
                    Install.write(target .. "ornaments.json",
                        assert(require("rapidjson").encode(metadata, { pretty = true, sort_keys = true })))
                    changed = true
                end
                for name, hashes in pairs(baseline.documents) do
                    if mode(target .. name) == "file" and contains(hashes, hash(target .. name)) then
                        Install.copy(source .. name, target .. name)
                        changed = true
                    end
                end
            end
        end
    end
    -- Recognizing the new hash makes an interrupted upgrade safe to retry.
    Install.mark(source .. M.notice, M.marker)
    return changed
end

return Update
