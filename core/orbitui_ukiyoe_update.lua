-- Upgrade only recognized alpha.19 defaults, never reader overrides or images.
local M = {
    marker = "ornament-ukiyoe-gallery-v2.updated",
    baseline = "assets/ornament-updates/ukiyoe-gallery-v1.json",
}

local function read(path)
    local f = assert(io.open(path, "rb"))
    local ok, bytes = pcall(function() return assert(f:read("*a")) end)
    f:close()
    assert(ok, bytes)
    return bytes
end

local function decode(bytes)
    local result = require("rapidjson").decode(bytes)
    assert(type(result) == "table", "Invalid Ukiyo-e metadata")
    return result
end

local function customPosition(entry, old, reader)
    return entry.anchor ~= old.anchor or entry.scale ~= old.scale
        or (type(reader) == "table" and
            (reader.lift ~= nil or reader.anchor ~= nil or reader.scale ~= nil))
end

function M.apply(root, ornaments_dir)
    local Install = require("core/orbitui_ornament_install")
    if Install.installed(M.marker) then return false end
    local fs = require("libs/libkoreader-lfs")
    local source = root .. "/assets/ornaments/Ukiyo-e Gallery/"
    local target = ornaments_dir .. "/Ukiyo-e Gallery/"
    local changed = false
    local function exists(path) return fs.attributes(path, "mode") == "file" end
    local baseline = decode(read(root .. "/" .. M.baseline)).files
    assert(type(baseline) == "table", "Missing Ukiyo-e update baseline")

    if exists(target .. "ornaments.json") then
        local current = decode(read(target .. "ornaments.json"))
        local old, new = decode(baseline["ornaments.json"]), decode(read(source .. "ornaments.json"))
        local reader_path = ornaments_dir .. "/ornaments.json"
        local reader = exists(reader_path) and decode(read(reader_path)) or {}
        for name, before in pairs(old) do
            local entry, after = current[name], new[name]
            if type(entry) == "table" and type(after) == "table" then
                for _, field in ipairs({ "lift", "info" }) do
                    if entry[field] == before[field] and after[field] ~= before[field]
                        and not (field == "lift" and customPosition(entry, before,
                            reader["Ukiyo-e Gallery/" .. name])) then
                        entry[field] = after[field]
                        changed = true
                    end
                end
            end
        end
        if changed then
            Install.write(target .. "ornaments.json",
                assert(require("rapidjson").encode(current, { pretty = true, sort_keys = true })))
        end
    end

    -- Default notices/provenance follow the new content; edited/deleted files stay.
    for _, name in ipairs({ "provenance.json", "ATTRIBUTION.txt", "README.txt" }) do
        if exists(target .. name) and read(target .. name) == baseline[name] then
            local bytes = read(source .. name)
            if bytes ~= baseline[name] then
                Install.write(target .. name, bytes)
                changed = true
            end
        end
    end
    -- A failed partial upgrade is retried next process; completed/deleted packs
    -- are never resurrected and no image, reader settings or theme is written.
    Install.mark(source .. "README.txt", M.marker)
    return changed
end

return M
