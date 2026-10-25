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

function M.bookshelfTarget()
    return require("infra/sui_store"):get("orbitui_bookshelf_profile")
end

function M.setBookshelfTarget(key)
    assert(key == nil or profiles().get(key), "Unavailable Bookshelf profile")
    require("infra/sui_store"):set("orbitui_bookshelf_profile", key)
    require("adapters/orbitui_navbar").changed()
end

local function openProfile(QA, key, ctx, menu)
    if menu or key == nil then return QA.openBookshelfProfile(key, ctx, menu) end
    local UI = require("infra/sui_core")
    local _id, screen = UI.getOpenScreen()
    if screen then
        screen._navbar_closing_intentionally = true
        require("ui/uimanager"):close(screen)
        screen._navbar_closing_intentionally = nil
    end
    -- The normal owner handles ReaderUI/parking; enforce the explicitly chosen
    -- profile only when its live shelf is ready, never by bypassing that lifecycle.
    return require("core/orbitui_context").withShelf(key, function() end)
end

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
    if QA.iterBuiltin then
        for descriptor in QA.iterBuiltin() do
            if descriptor.id == "home" then descriptor.label = _("File browser") end
        end
    end
    local function register(descriptor)
        QA.register(descriptor)
        if not Config.ACTION_BY_ID[descriptor.id] then Config.ALL_ACTIONS[#Config.ALL_ACTIONS + 1] = descriptor end
        Config.ACTION_BY_ID[descriptor.id] = descriptor
        for i, old in ipairs(Config.ALL_ACTIONS) do
            if old.id == descriptor.id then Config.ALL_ACTIONS[i] = descriptor; break end
        end
    end
    register{
        id = require("adapters/orbitui_navbar").bookshelf_action, label = "Bookshelf", icon = "nerd:F02D",
        is_in_place = false,
        execute = function(ctx)
            local key = M.bookshelfTarget()
            if key and not profiles().get(key) then
                return require("adapters/orbitui_library_settings").missingProfile(key)
            end
            return openProfile(QA, key, ctx)
        end,
        hold_execute = function() return require("adapters/orbitui_library_settings").navigation() end,
    }
    for _i, section in ipairs(profiles().list(true)) do
        local key, label = section.key, _(section.label)
        local id = M.actionId(key)
        local descriptor = {
            id = id, label = label, icon = section.icon or "nerd:F02D", is_in_place = false,
            execute = function(ctx)
                if not profiles().get(key) then
                    return require("adapters/orbitui_library_settings").missingProfile(key)
                end
                return openProfile(QA, key, ctx)
            end,
            hold_execute = function(ctx)
                if profiles().get(key) then return QA.openBookshelfProfile(key, ctx, true) end
            end,
        }
        register(descriptor)
    end
end

function M.bridge(bridge)
    local navigation, resolve = bridge.profileForNavigation, bridge.resolveProfileTab
    bridge.profileForNavigation = function(id)
        if id == require("adapters/orbitui_navbar").bookshelf_action then
            local key = M.bookshelfTarget()
            return key and profiles().get(key) and key or nil
        end
        local key = M.navigationProfile(id) or navigation(id)
        return key and profiles().get(key) and key or nil
    end
    bridge.resolveProfileTab = function(key, tabs)
        for _, id in ipairs(tabs or {}) do
            if key and M.navigationProfile(id) == key then return id end
        end
        local exact = resolve(key, tabs)
        if exact then return exact end
        local target = M.bookshelfTarget()
        if target == nil or (target == key and profiles().get(key)) then
            for _, id in ipairs(tabs or {}) do
                if id == require("adapters/orbitui_navbar").bookshelf_action then return id end
            end
        end
    end
end

function M.classes(bookshelf)
    -- Dispatcher aliases remain stable, but a missing/disabled legacy profile
    -- must explain itself instead of silently marking a dead navigation tab.
    for _, name in ipairs({ "onOpenBookshelfProfile", "onOpenBookshelfProfileStartMenu" }) do
        local original = bookshelf[name]
        if original then
            bookshelf[name] = function(self, key, ...)
                if key and not profiles().get(key) then
                    require("adapters/orbitui_library_settings").missingProfile(key)
                    return false
                end
                return original(self, key, ...)
            end
        end
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
