local M = {}
local Model = require("core/orbitui_libraries")
local _ = require("core/orbitui_i18n")

function M.profiles(profiles)
    local legacy = Model.copy(profiles.list())
    local home = G_reader_settings and G_reader_settings:readSetting("home_dir")
    local store = require("lib/bookshelf_settings_store")
    local function usedProfiles()
        -- A stock Bookshelf install also has bookshelf.lua. Its existence
        -- alone must not import another reader's folders.
        for _i, profile in ipairs(legacy) do
            if store.read("active_chip_" .. profile.key) ~= nil
                or store.read("profile_folder_sort_" .. profile.key) ~= nil then return true end
            for _j, chip in ipairs(profile.chips) do
                if store.read("profile_shelf_" .. profile.key .. "_" .. chip.key) ~= nil then return true end
            end
        end
        return false
    end
    local api = Model.new(store, legacy, home, usedProfiles)
    profiles.list, profiles.get, profiles.matchFile = api.list, api.get, api.matchFile
    profiles.config, profiles.save, profiles.edit, profiles.add = api.config, api.save, api.edit, api.add
    profiles.relocateRoot = api.relocateRoot
end

local function profiles() return require("lib/bookshelf_profiles") end

function M.actionId(key)
    -- Keep existing dock slots and user-defined icons untouched.
    if key == "prose" or key == "comics" then return "bookshelf_" .. key end
    return "orbitui_library_" .. key
end

function M.navigationProfile(id)
    if type(id) ~= "string" then return end
    local key = id:match("^orbitui_library_(.+)$")
    if key and profiles().get(key) then return key end
end

function M.actions(QA)
    local Config = require("infra/sui_config")
    for _i, section in ipairs(profiles().list(true)) do
        local key, label = section.key, _(section.label)
        local id = M.actionId(key)
        local descriptor = {
            id = id, label = label, icon = section.icon or "nerd:F02D", is_in_place = false,
            execute = function(ctx)
                if not profiles().get(key) then
                    require("core/orbitui_context").notify(_("This library section is disabled."))
                    return
                end
                return QA.openBookshelfProfile(key, ctx)
            end,
            hold_execute = function(ctx)
                if profiles().get(key) then return QA.openBookshelfProfile(key, ctx, true) end
            end,
        }
        QA.register(descriptor)
        if not Config.ACTION_BY_ID[id] then Config.ALL_ACTIONS[#Config.ALL_ACTIONS + 1] = descriptor end
        Config.ACTION_BY_ID[id] = descriptor
        for i, old in ipairs(Config.ALL_ACTIONS) do
            if old.id == id then Config.ALL_ACTIONS[i] = descriptor; break end
        end
    end
end

function M.bridge(bridge)
    local navigation, resolve = bridge.profileForNavigation, bridge.resolveProfileTab
    bridge.profileForNavigation = function(id)
        local key = M.navigationProfile(id) or navigation(id)
        return key and profiles().get(key) and key or nil
    end
    bridge.resolveProfileTab = function(key, tabs)
        for _, id in ipairs(tabs or {}) do
            if M.navigationProfile(id) == key then return id end
        end
        return resolve(key, tabs)
    end
end

function M.changed()
    local QA = package.loaded["features/sui_quickactions"]
    if QA then M.actions(QA) end
    local Widget = package.loaded["lib/bookshelf_widget"]
    local live = Widget and Widget.live
    if live and live.profile_key then
        local key = profiles().get(live.profile_key) and live.profile_key or nil
        live:setProfile(key, true)
        -- Rebuild on return, not over the settings dialog or the reader.
        live._orbitui_navbar_pending = true
    end
    require("core/orbitui_context").refresh()
end

return M
