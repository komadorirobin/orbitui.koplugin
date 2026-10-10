-- Profile chips are not native TabModel records. Give themes and decks stable,
-- profile-qualified identities without inserting synthetic navigation tabs.
local M = {}
local function profiles() return require("lib/bookshelf_profiles") end

function M.id(widget)
    if widget.profile and widget:_profileChip(widget.chip) then
        return "orbitui:" .. widget.profile.key .. ":" .. widget.chip
    end
    return widget.chip
end

function M.profile(id)
    local key, chip
    if type(id) == "string" then key, chip = id:match("^orbitui:([^:]+):(.+)$") end
    local profile = profiles().get(key)
    if profile and profiles().chip(profile, chip) then return profile, chip end
end

function M.tab(id)
    local P = profiles()
    local profile, chip = M.profile(id)
    if not profile then return require("lib/bookshelf_tab_model").getById(id) end
    local values = P.shelfSettings(profile, chip)
    values.id = id
    values.label = profile.label .. " / " .. P.chip(profile, chip).label
    values.enabled = true
    return values
end

function M.tabs(all)
    local out = {}
    local TM = require("lib/bookshelf_tab_model")
    for _, tab in ipairs(all and TM.load() or TM.getActive()) do out[#out + 1] = tab end
    for _, key in ipairs({ "prose", "comics" }) do
        local profile = profiles().get(key)
        for _, chip in ipairs(profile.chips) do
            out[#out + 1] = M.tab("orbitui:" .. key .. ":" .. chip.key)
        end
    end
    return out
end

function M.widget(widget)
    widget.themeShelfId = M.id
end

function M.theme(module)
    module._tab = M.tab
    module._tabs_list = M.tabs
end

function M.menu(module)
    module.tab = M.tab
    module.tabs = function() return M.tabs() end
    local screen = module.shelfOnScreen
    module.shelfOnScreen = function(S)
        if S._bw and S._bw.profile then return M.id(S._bw) end
        return screen(S)
    end
    local save = module.setShelfTheme
    module.setShelfTheme = function(id, value)
        local profile, chip = M.profile(id)
        if not profile then return save(id, value) end
        local P = profiles()
        local values = P.shelfSettings(profile, chip)
        values.theme = value
        local orn = package.loaded["lib/bookshelf_ornaments"]
        P.saveShelfSettings(profile, chip, values, orn and orn._defer)
    end
    module.activateShelf = function(S, id)
        local bw = S._bw
        if not bw then return end
        local profile, chip = M.profile(id)
        local changed_profile = bw.profile ~= profile
        if bw.setProfile then bw:setProfile(profile and profile.key or nil, true) end
        local target = chip or id
        if changed_profile and bw.chip == target then
            -- setProfile may already restore this chip. _setActiveChip then
            -- returns early, leaving the previous profile's tree on screen.
            bw:_rebuild()
            require("ui/uimanager"):setDirty(bw, "ui")
        elseif bw._setActiveChip then
            bw:_setActiveChip(target)
        end
    end
end

return M
