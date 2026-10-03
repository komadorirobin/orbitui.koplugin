local M = {}
local incompatible = {
    projecttitle = true, zenos = true, burrow = true, quickui = true,
    ["zzz-readermenuredesign"] = true,
}
local sentinels = {
    ptutil = "projecttitle", ["common/zen_logger"] = "zenos",
    burrow_util = "burrow", qui_utils = "quickui",
    readermenuredesign_installer = "zzz-readermenuredesign",
}

local function legacyName(plugin)
    local name = tostring(plugin.name or ""):lower()
    if incompatible[name] then return name end
    if name:find("bookshelf", 1, true) or name:find("simpleui", 1, true) then
        return name
    end
    if plugin.onSimpleUIGoHomescreen then return name .. " (SimpleUI)" end
    if plugin.MENU_ORDER and plugin.onOpenBookshelfProse then
        return name .. " (Bookshelf)"
    end
end

function M.conflicts(discovered, enabled, host)
    local out, seen = {}, {}
    local function add(plugin)
        if plugin.disabled or plugin._orbitui_owned then return end
        local name = legacyName(plugin)
        if name and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    for _, plugin in ipairs(discovered or {}) do add(plugin) end
    -- The enabled list is authoritative until restart, even if settings changed.
    for _, plugin in ipairs(enabled or {}) do add(plugin) end
    -- Report conflicting loaded UIs, but never rewrite plugins_disabled or patches.
    for sentinel, name in pairs(sentinels) do
        if package.loaded[sentinel] then add({ name = name }) end
    end
    if rawget(_G, "__ZEN_UI_PLUGIN") then add({ name = "zenos" }) end
    for _, name in ipairs({ "bookshelf", "simpleui" }) do
        local instance = host and host[name]
        if instance and not instance._orbitui_owned then add({ name = name }) end
    end
    table.sort(out)
    return out
end

function M.check(host)
    local Loader = require("pluginloader")
    local discovered
    if Loader._discover then
        discovered = Loader:_discover()
    else
        -- Older KOReader releases expose only the populated enabled list.
        -- At component initialization it is complete; at module-load time we
        -- additionally inspect the install directories without loading code.
        local lfs = require("libs/libkoreader-lfs")
        local DS = require("datastorage")
        local settings = G_reader_settings
        local disabled = settings:readSetting("plugins_disabled", {})
        local roots = { "plugins", DS:getDataDir() .. "/plugins" }
        local extra = settings:readSetting("extra_plugin_paths")
        if type(extra) == "string" then extra = { extra } end
        for _, path in ipairs(type(extra) == "table" and extra or {}) do
            roots[#roots + 1] = path
        end
        discovered = {}
        for _, root in ipairs(roots) do
            if lfs.attributes(root, "mode") == "directory" then
                for entry in lfs.dir(root) do
                    if entry:sub(-9) == ".koplugin" then
                        local name = entry:sub(1, -10)
                        discovered[#discovered + 1] = {
                            name = name,
                            disabled = disabled[name] == true,
                        }
                    end
                end
            end
        end
    end
    local conflicts = M.conflicts(discovered, Loader.enabled_plugins, host)
    if #conflicts > 0 then
        return nil, "Disable these standalone plugins and restart KOReader before enabling OrbitUI:\n"
            .. table.concat(conflicts, ", ")
    end
    return true
end

return M
