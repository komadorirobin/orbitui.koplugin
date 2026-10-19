-- Inspection only: never loads a provider, contacts a server or changes credentials.
local _ = require("core/orbitui_i18n")
local M = {}
local help = {
    bookorbit = "BookOrbit is optional. Install and connect its KOReader plugin, then choose BookOrbit as a shelf or dashboard source. Library Sync can help match downloaded files. Local books work without it.",
    hardcover = "Hardcover is optional. Configure its API key in the Hardcover module settings, then select it as the dashboard goal source. The local reading goal needs no account.",
    mal = "MyAnimeList is optional. Its separate plugin provides ratings for linked folders and series. Books and series boxes work without ratings.",
}

function M.entries()
    local loader = package.loaded.pluginloader
    local plugins = loader and loader.loaded_plugins or {}
    local ratings = package.loaded.bookshelf_folder_badge_providers
    local key = G_reader_settings and G_reader_settings:readSetting("simpleui_hc_api_key")
    return {
        { name = "BookOrbit", available = plugins.bookorbit ~= nil, text = help.bookorbit },
        { name = "Hardcover", available = type(key) == "string" and key:match("%S") ~= nil, text = help.hardcover },
        { name = "MyAnimeList", available = type(ratings) == "table" and type(ratings.myanimelist) == "function", text = help.mal },
    }
end

function M.items(show)
    local rows = {}
    for _i, entry in ipairs(M.entries()) do
        local text = entry.text
        rows[#rows + 1] = {
            text = entry.name .. ": " .. _(entry.available and "Detected (not connection-tested)" or "Not detected"),
            callback = function()
                if show then return show(_(text)) end
                require("ui/uimanager"):show(require("ui/widget/infomessage"):new{ text = _(text) })
            end,
        }
    end
    return rows
end

return M
