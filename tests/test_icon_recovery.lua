package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local name = "infra/sui_store"
local patch = "recovery/2-orbitui-material-safe-mode.lua"
local data = {
    simpleui_sysicon_sui_menu = "material:menu",
    simpleui_sysicon_sui_tab_main = "/old/assets/material-symbols/icons/menu.svg",
    simpleui_action_bookshelf_comics_icon = "material:manga",
    simpleui_action_filemanager_icon = "nerd:F02D",
    simpleui_sysicon_sui_search = "/custom/search.svg",
    simpleui_action_bookshelf_comics_label = "Manga",
    simpleui_qa_custom = { icon = "nerd:F02D", label = "Personal action" },
    simpleui_deleted_books = { book = { title = "Read book", year = 2026 } },
    simpleui_screen = "my-layout",
    unrelated = "material:manga",
}
local original = {}
for k, v in pairs(data) do original[k] = v end
local writes, opened = 0, 0
package.loaded.logger = { dbg = function() end, info = function() end, warn = function() end }
package.loaded.datastorage = { getSettingsDir = function() return "/fake/settings" end }
package.loaded.luasettings = { open = function(_, path)
    H.eq(path, "/fake/settings/simpleui/sui_settings.lua")
    opened = opened + 1
    return {
        data = data,
        readSetting = function(_, key, default)
            if data[key] == nil then return default end
            return data[key]
        end,
        saveSetting = function() error("Recovery must not change settings") end,
        delSetting = function() error("Recovery must not delete settings") end,
        flush = function() writes = writes + 1 end,
    }
end }

H.test("recovery can install before plugin discovery without loading settings", function()
    local require_before, path = require, package.path
    dofile(patch)
    H.eq(package.loaded[name], nil)
    H.eq(opened, 0)
    H.eq(require, require_before)
    H.eq(package.path, path)
end)
local Store
H.test("normal OrbitUI resolver loads the protected store at startup", function()
    require("core/orbitui_runtime").install(H.root())
    Store = require(name)
    H.eq(require("sui_store"), Store)
    for _, key in ipairs({ "simpleui_sysicon_sui_menu", "simpleui_sysicon_sui_tab_main",
            "simpleui_action_bookshelf_comics_icon" }) do
        H.eq(Store:get(key), nil)
        H.eq(Store:readSetting(key, "default-icon"), "default-icon")
    end
    H.eq(opened, 1)
    H.eq(writes, 0)
end)
H.test("recovery leaves every saved value intact and preserves unrelated reads", function()
    for _, key in ipairs({ "simpleui_action_filemanager_icon", "simpleui_sysicon_sui_search",
            "simpleui_action_bookshelf_comics_label", "simpleui_qa_custom", "simpleui_deleted_books",
            "simpleui_screen", "unrelated" }) do
        H.eq(Store:get(key), original[key], key)
        H.eq(Store:readSetting(key), original[key], key)
    end
    H.eq(Store:get("absent", false), false)
    for key, value in Store:iterateKeys() do H.eq(value, original[key], key) end
    for key, value in pairs(original) do H.eq(data[key], value, key) end
    H.eq(writes, 0)
end)
H.test("loaded-store recovery is idempotent", function()
    local get, read = Store.get, Store.readSetting
    dofile(patch)
    dofile(patch)
    H.eq(Store.get, get)
    H.eq(Store.readSetting, read)
end)
H.test("removing the patch on restart reveals original choices", function()
    package.loaded[name] = nil
    package.loaded.sui_store = nil
    package.preload[name] = nil
    local clean = require(name)
    H.eq(clean:get("simpleui_sysicon_sui_menu"), "material:menu")
    H.eq(clean:get("simpleui_action_bookshelf_comics_icon"), "material:manga")
    H.eq(writes, 0)
end)
H.test("existing userpatch preload keeps priority and is called once", function()
    local calls = 0
    package.loaded[name] = nil
    package.preload[name] = function(module_name)
        H.eq(module_name, name)
        calls = calls + 1
        local store = dofile("components/simpleui/infra/sui_store.lua")
        store.other_patch = true
        return store
    end
    dofile(patch)
    dofile(patch)
    local protected = require(name)
    H.eq(calls, 1)
    H.eq(protected.other_patch, true)
    H.eq(protected:get("simpleui_sysicon_sui_menu"), nil)
    H.eq(writes, 0)
end)
H.finish()
