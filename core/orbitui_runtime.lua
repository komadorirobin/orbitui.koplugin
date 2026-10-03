local M = {}
local installed_root, component_classes

function M.install(root, module_map)
    if installed_root then
        assert(installed_root == root, "Another OrbitUI installation is already loaded")
        return
    end
    module_map = module_map or require("core/orbitui_module_map")
    local metadata_only = {
        ["lib/bookshelf_i18n"] = true,
        ["infra/sui_i18n"] = true,
        ["infra/sui_paths"] = true,
    }
    -- Disabled plugins still load _meta.lua, which imports translation helpers.
    -- Refuse other foreign component state rather than silently mixing versions.
    for name in pairs(module_map) do
        if package.loaded[name] and not metadata_only[name] then
            error("Component module already loaded: " .. name .. ". Restart KOReader.")
        end
    end
    for name in pairs(metadata_only) do package.loaded[name] = nil end
    local aliases = {}
    for name in pairs(module_map) do
        local short = name:match("/([^/]+)$")
        if short and short:match("^sui_") then
            assert(not aliases[short], "Ambiguous component alias: " .. short)
            aliases[short] = name
        end
    end
    local replacements = {
        ["infra/sui_updater"] = "simpleui",
        ["lib/bookshelf_updater"] = "bookshelf",
    }
    local function searcher(name)
        if aliases[name] then return function() return require(aliases[name]) end end
        local path = module_map[name]
        if not path then return "\n\tno OrbitUI module '" .. name .. "'" end
        if replacements[name] then
            return function()
                return require("adapters/orbitui_updates").component(replacements[name], root)
            end
        end
        if name == "lib/bookshelf_paths" or name == "lib/bookshelf_storage_move" then
            return function()
                local storage = require("adapters/orbitui_bookshelf_storage")
                return name == "lib/bookshelf_paths" and storage.paths or storage.migration
            end
        end
        if name == "infra/sui_compat_check" then
            -- OrbitUI's guard reports conflicts without mutating plugin/patch choices.
            return function() return function() return false end end
        end
        local fn, err = loadfile(root .. "/" .. path)
        if not fn then error(err) end
        if name == "lib/bookshelf_settings_store" then
            return function()
                return require("adapters/orbitui_bookshelf_storage").wrapStore(fn())
            end
        end
        return fn
    end
    -- Keep package.preload first so existing KOReader userpatch interceptors work.
    table.insert(package.searchers or package.loaders, 2, searcher)
    installed_root = root
end

function M.classes(root)
    if component_classes then return component_classes end
    assert(installed_root == root, "OrbitUI module loader was not installed")
    assert(not require("lib/bookshelf_version_gate").tooOld(),
        "Update KOReader to v2025.08 or newer before using OrbitUI")
    local bookshelf = assert(dofile(root .. "/components/bookshelf/main.lua"))
    local simpleui = assert(dofile(root .. "/components/simpleui/main.lua"))
    component_classes = { bookshelf = bookshelf, simpleui = simpleui }
    return component_classes
end

return M
