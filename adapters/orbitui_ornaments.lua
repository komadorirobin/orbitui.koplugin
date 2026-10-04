local M = {}
M.modules = {
    ["lib/bookshelf_ornaments"] = true,
    ["lib/bookshelf_ornament_deck"] = true,
}

function M.wrap(name, module, root)
    local Authors = require("core/orbitui_author_ornaments")
    if name == "lib/bookshelf_ornament_deck" then
        local fill = module.fillHooks
        module.fillHooks = function(env) return Authors.fillHooks(fill, env) end
    else
        local list, attempted = module.listAll, false
        module.listAll = function(...)
            if not attempted then
                attempted = true
                local ok, err = pcall(Authors.seed, root, module.dir())
                if not ok then require("logger").warn("[OrbitUI] Could not install author ornaments:", err) end
            end
            return list(...)
        end
    end
    return module
end

return M
