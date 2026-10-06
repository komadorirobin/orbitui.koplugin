-- Upgrade only the reviewed default image, never user artwork or deleted packs.
local M = {
    marker = "ornament-kafka-kielce-v1.updated",
    baseline = "assets/ornament-updates/kafka-kielce-v1.json",
    file = "Franz Kafka.png",
}

local function read(path)
    local f = assert(io.open(path, "rb"))
    local ok, bytes = pcall(function() return assert(f:read("*a")) end)
    f:close()
    assert(ok, bytes)
    return bytes
end

local function decode(path)
    local value = require("rapidjson").decode(read(path))
    assert(type(value) == "table", "Invalid Kafka update metadata")
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
    local function exists(path) return fs.attributes(path, "mode") == "file" end
    local source = root .. "/assets/ornaments/Authors/"
    local target = ornaments_dir .. "/Authors/"
    local changed = false
    if exists(target .. M.file) and exists(target .. "ornaments.json") then
        local baseline = decode(root .. "/" .. M.baseline)
        local hash = require("core/orbitui_ota").hashFile
        local current = hash(target .. M.file)
        if current == baseline.old_sha256 or current == baseline.new_sha256 then
            local metadata = decode(target .. "ornaments.json")
            local entry = metadata[M.file]
            if type(entry) == "table" then
                assert(hash(source .. M.file) == baseline.new_sha256, "Invalid bundled Kafka image")
                local new = decode(source .. "ornaments.json")[M.file]
                assert(type(new) == "table" and type(new.info) == "string"
                    and #new.info > 0 and #new.info <= 4000, "Invalid Kafka caption")
                -- Add the dedicated notice even when shared pack notices were
                -- edited by the reader; it explains the replacement's license.
                if not fs.attributes(target .. "KAFKA-KIELCE.txt", "mode") then
                    Install.copy(source .. "KAFKA-KIELCE.txt", target .. "KAFKA-KIELCE.txt")
                    changed = true
                end
                if current == baseline.old_sha256 then
                    Install.copy(source .. M.file, target .. M.file)
                    changed = true
                end
                local dirty = false
                if contains(baseline.old_info, entry.info) then
                    entry.info, dirty = new.info, true
                end
                local old = baseline.old_placement
                if entry.scale == old.scale and entry.anchor == old.anchor and entry.lift == old.lift then
                    entry.lift, dirty = new.lift, true
                end
                if dirty then
                    Install.write(target .. "ornaments.json",
                        assert(require("rapidjson").encode(metadata, { pretty = true, sort_keys = true })))
                    changed = true
                end
                for name, hashes in pairs(baseline.documents) do
                    if exists(target .. name) and contains(hashes, hash(target .. name)) then
                        Install.copy(source .. name, target .. name)
                        changed = true
                    end
                end
            end
        end
    end
    -- A replaced image is recognized on retry after a later write failure.
    -- Completed markers avoid all image hashing on subsequent startups.
    Install.mark(source .. "KAFKA-KIELCE.txt", M.marker)
    return changed
end

return M
