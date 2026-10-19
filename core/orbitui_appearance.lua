-- Reversible shelf policies, kept separately from native per-shelf preferences.
local M = { key = "appearance", order = { "native", "classic", "minimal" } }
local presets = {
    native = { label = "Shelf settings", boxes = "native",
        description = "Use each shelf's cover orientation, series boxes and ornaments. No extra ornament packs are installed automatically." },
    classic = { label = "Classic OrbitUI", face_out = "all", boxes = "all", bundles = true,
        description = "All covers face forward and eligible series become boxes, including single volumes. Install OrbitUI's extra ornament packs and keep author and manga matching." },
    minimal = { label = "Minimal bookshelf", face_out = "all", boxes = "off", hide_ornaments = true,
        description = "All covers face forward, without series boxes or ornaments. Saved shelf choices and installed artwork are kept." },
}

function M.preset(id) return presets[id] end
function M.value(id)
    assert(presets[id], "Invalid shelf preset")
    return { version = 1, preset = id }
end
function M.validate(value)
    assert(type(value) == "table" and value.version == 1 and presets[value.preset],
        "Unsupported OrbitUI appearance settings; saved settings were not changed")
    return value
end
function M.prepare(store, fresh)
    local value = store:readSetting(M.key)
    if value == nil then
        value = M.value(fresh and "native" or "classic")
        store:saveSetting(M.key, value)
        if store:flush() == false then
            store:delSetting(M.key)
            error("Could not save OrbitUI appearance settings")
        end
    end
    return M.validate(value)
end

return M
