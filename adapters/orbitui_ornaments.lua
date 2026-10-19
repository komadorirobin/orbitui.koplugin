local M = {}
M.modules = {
    ["lib/bookshelf_ornaments"] = true,
    ["lib/bookshelf_ornament_deck"] = true,
    ["lib/bookshelf_spine_shelf"] = true,
    ["lib/bookshelf_ornament_browser"] = true,
}

function M.wrap(name, module, root)
    local Authors = require("core/orbitui_author_ornaments")
    local Appearance = require("adapters/orbitui_appearance")
    if name == "lib/bookshelf_ornament_browser" then
        require("adapters/orbitui_addons").browser(module, root)
    elseif name == "lib/bookshelf_ornament_deck" then
        local fill = module.fillHooks
        module.fillHooks = function(env)
            if Appearance.policy().hide_ornaments then env.level = "off" end
            return Authors.fillHooks(fill, env)
        end
        module._tabs = function() return require("adapters/orbitui_shelf_themes").tabs(true) end
        local sync, shuffled = module.sync, {}
        module.sync = function(all, shelf)
            sync(all, shelf)
            local key = tostring(shelf or module.NO_SHELF)
            if Appearance.current() == "classic" and not shuffled[key] and all and #all > 0 then
                shuffled[key] = true
                local ok, err = pcall(module.shuffle, shelf)
                if not ok then
                    require("logger").warn("[OrbitUI] Could not shuffle ornaments for this session:", err)
                end
            end
        end
    elseif name == "lib/bookshelf_spine_shelf" then
        module.positionOrnamentX = require("core/orbitui_ornament_spacing").positionX
    else
        local frequency = module.frequency
        module.frequency = function(...)
            if Appearance.policy().hide_ornaments then return 0 end
            return frequency(...)
        end
        require("adapters/orbitui_addons").ornaments(module, root)
    end
    return module
end

return M
