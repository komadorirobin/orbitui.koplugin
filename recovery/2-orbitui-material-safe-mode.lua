-- Temporary KOReader userpatch for the OrbitUI alpha.6 Material startup issue.
-- Install in KOReader's patches directory while the app is stopped. This only
-- masks Material system/default-action overrides in memory; it never saves or
-- deletes settings. Remove/disable this patch after installing the corrected
-- OrbitUI build to make Material choices visible again.
local name = "infra/sui_store"

local function isMaterialOverride(key, value)
    if type(key) ~= "string" or type(value) ~= "string" then return false end
    if not key:match("^simpleui_sysicon_") and not key:match("^simpleui_action_.+_icon$") then
        return false
    end
    return value:match("^material:[a-z0-9_]+$")
        or value:match("/assets/material%-symbols/icons/[a-z0-9_]+%.svg$")
end

local function protect(store)
    if store._orbitui_material_safe_mode then return store end
    for _, method in ipairs({ "get", "readSetting" }) do
        local read = store[method]
        store[method] = function(self, key, default)
            local value = read(self, key, default)
            if isMaterialOverride(key, value) then return default end
            return value
        end
    end
    store._orbitui_material_safe_mode = true
    return store
end

if package.loaded[name] then
    protect(package.loaded[name])
else
    local preload = package.preload[name]
    package.preload[name] = function(module_name)
        if preload then return protect(preload(module_name)) end
        -- OrbitUI installs its resolver during plugin discovery. Preserve that
        -- resolver and any earlier userpatch loader instead of loading a path
        -- from a guessed or outdated OTA version directory.
        local loaders = package.searchers or package.loaders
        for i = 2, #loaders do
            local loader, data = loaders[i](module_name)
            if type(loader) == "function" then return protect(loader(module_name, data)) end
        end
        error("OrbitUI settings loader is unavailable")
    end
end
