-- Replace only recognized, published artwork-only captions with author cards.
local M = {
    baseline = "assets/ornament-updates/author-info-v1.json",
    packs = {
        { name = "Modernists", marker = "ornament-modernists-info-v1.updated" },
        { name = "Authors", marker = "ornament-authors-info-v1.updated" },
    },
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
    assert(type(result) == "table", "Invalid author ornament metadata")
    return result
end

function M.apply(root, ornaments_dir)
    local Install = require("core/orbitui_ornament_install")
    local fs = require("libs/libkoreader-lfs")
    local function exists(path) return fs.attributes(path, "mode") == "file" end
    local baseline, changed
    for _, pack in ipairs(M.packs) do
        if not Install.installed(pack.marker) then
            baseline = baseline or decode(read(root .. "/" .. M.baseline)).packs
            local old = type(baseline) == "table" and baseline[pack.name]
            assert(type(old) == "table" and type(old.metadata) == "table"
                and type(old.readme) == "string", "Missing author info baseline")
            local source = root .. "/assets/ornaments/" .. pack.name .. "/"
            local target = ornaments_dir .. "/" .. pack.name .. "/"
            if exists(target .. "ornaments.json") then
                local current = decode(read(target .. "ornaments.json"))
                local new = decode(read(source .. "ornaments.json"))
                local dirty = false
                for name, before in pairs(old.metadata) do
                    -- Retired Lispector metadata is left intact for custom art.
                    if not (pack.name == "Authors" and name == "Clarice Lispector.png") then
                        local entry, after = current[name], new[name]
                        assert(type(before.info) == "string" and type(after) == "table"
                            and type(after.info) == "string" and #after.info > 0
                            and #after.info <= 4000, "Invalid bundled author info")
                        -- Changed artwork owns its captions: never attach new
                        -- sculpture credits to a reader's custom image.
                        if not (pack.name == "Authors" and
                            (name == "Franz Kafka.png" or name == "Thomas Mann.png"
                            or name == "August Strindberg.png" or name == "Knut Hamsun.png"
                            or name == "Fyodor Dostoevsky.png" or name == "Dylan Thomas.png"
                            or name == "Stanislaw Lem.png" or name == "Robert Musil.png"))
                            and type(entry) == "table" and entry.info == before.info
                            and entry.info ~= after.info then
                            entry.info = after.info
                            dirty = true
                        end
                    end
                end
                if dirty then
                    Install.write(target .. "ornaments.json",
                        assert(require("rapidjson").encode(current, { pretty = true, sort_keys = true })))
                    changed = true
                end
            end
            if exists(target .. "README.txt") and read(target .. "README.txt") == old.readme then
                local bytes = read(source .. "README.txt")
                if bytes ~= old.readme then
                    Install.write(target .. "README.txt", bytes)
                    changed = true
                end
            end
            -- Deleted packs/entries stay deleted. Native reader overrides remain
            -- authoritative; no artwork, placement, enablement or credits change.
            Install.mark(source .. "README.txt", pack.marker)
        end
    end
    return changed == true
end

return M
