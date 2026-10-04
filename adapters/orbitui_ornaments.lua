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
        local list, attempted, shuffled = module.listAll, false, false
        module.listAll = function(...)
            if not attempted then
                attempted = true
                local ok, err = pcall(Authors.seed, root, module.dir())
                if not ok then require("logger").warn("[OrbitUI] Could not install author ornaments:", err) end
                local japan_ok, japan_err = pcall(function()
                    return require("core/orbitui_japan_ornaments").seed(root, module)
                end)
                if not japan_ok then
                    require("logger").warn("[OrbitUI] Could not install Japan ornaments:", japan_err)
                end
            end
            local all, packs = list(...)
            if not shuffled and all and #all > 0 then
                -- This module lives for the KOReader process, not the widget.
                -- Shuffle after seeding, before list()/page signatures return,
                -- so pagination and display see the same order from the start.
                shuffled = true
                local ok, err = pcall(function()
                    local Deck = require("lib/bookshelf_ornament_deck")
                    Deck.sync(all)
                    Deck.shuffle()
                end)
                if not ok then
                    require("logger").warn("[OrbitUI] Could not shuffle ornaments for this session:", err)
                end
            end
            return all, packs
        end
    end
    return module
end

return M
