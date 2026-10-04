local M = {}
M.pack = "Japan"
M.packs = {
    { name = M.pack, marker = "ornament-japan-v1.installed", files = {
        "ATTRIBUTION.txt", "README.txt", "prompts.json", "ornaments.json",
        "Pine Bonsai.png", "Maple Bonsai.png", "Sleeping Calico.png", "Maneki Neko.png", "Daruma.png",
    } },
}
M.defaults_marker = "ornament-japan-defaults-v1.applied"

local function stockAt(roots, name, expected)
    -- Match the effective root's exact stock artwork, not names alone. An
    -- edited plant or a custom pack's cactus must remain the user's choice.
    local fs = require("libs/libkoreader-lfs")
    for _, root in ipairs(roots) do
        local path = root .. "/" .. name
        local mode = fs.attributes(path, "mode")
        if mode then
            if mode ~= "file" then return false end
            local f = io.open(path, "rb")
            if not f then return false end
            local bytes = f:read(#expected + 1)
            f:close()
            return bytes == expected
        end
    end
    return false
end

function M.seed(root, ornaments)
    local Install = require("core/orbitui_ornament_install")
    local changed = Install.seed(root, ornaments.dir(), M.packs)
    if Install.installed(M.defaults_marker) then return changed end

    -- This one-time default change is user-requested. Keep the original SVGs
    -- available in the browser and allow re-enabling them permanently later.
    local Store = ornaments._store or require("lib/bookshelf_settings_store")
    local packs_off = Store.read(ornaments.PACKS_OFF_KEY) or {}
    local off = {}
    for name, value in pairs(Store.read(ornaments.OFF_KEY) or {}) do off[name] = value end
    local modified = false
    if not packs_off[M.pack] then
        local roots = ornaments.roots()
        for _, seed in ipairs({
            { name = ornaments.CACTUS_NAME, svg = ornaments.CACTUS_SVG },
            { name = ornaments.TEMPLATE_NAME, svg = ornaments.TEMPLATE_SVG },
        }) do
            if not off[seed.name] and stockAt(roots, seed.name, seed.svg) then
                off[seed.name] = true
                modified = true
            end
        end
    end
    if modified then
        -- One durable write; errors escape to the guarded adapter so the
        -- marker is not committed and installation can retry next startup.
        assert(Store.save(ornaments.OFF_KEY, off) ~= false, "Could not save ornament defaults")
        ornaments.invalidate()
    end
    Install.mark(root .. "/assets/ornaments/" .. M.pack .. "/README.txt", M.defaults_marker)
    return changed or modified
end

return M
