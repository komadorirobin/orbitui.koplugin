package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = H.root()
local Runtime = require("core/orbitui_runtime")
local map = require("core/orbitui_module_map")
package.loaded.logger = { dbg = function() end, info = function() end, warn = function() end }
package.loaded.gettext = function(value) return value end
G_reader_settings = { readSetting = function(_, key) if key == "language" then return "sv" end end }

H.test("module map references existing component source only", function()
    local n = 0
    for key, path in pairs(map) do
        assert(path:match("^components/[^/]+/"))
        assert(not key:match("tests/") and key ~= "main" and key ~= "_meta")
        assert(loadfile(path))
        n = n + 1
    end
    assert(n > 200)
end)
H.test("foreign runtime modules stop mixed-version loading", function()
    package.loaded["screens/sui_homescreen"] = {}
    H.eq(pcall(Runtime.install, root, map), false)
    package.loaded["screens/sui_homescreen"] = nil
end)
H.test("disabled metadata helpers are replaced without altering package.path", function()
    local stale = { stale = true }
    package.loaded["infra/sui_paths"] = stale
    local path = package.path
    Runtime.install(root, map)
    H.eq(package.path, path)
    assert(require("infra/sui_paths") ~= stale)
end)
H.test("embedded paths resolve component assets rather than the outer plugin", function()
    H.eq(require("infra/sui_paths").getPluginDir(), root .. "/components/simpleui/")
    H.eq(require("infra/sui_paths").getPluginDirNoSlash(), root .. "/components/simpleui")
end)
H.test("legacy short module names share canonical instances", function()
    H.eq(require("sui_paths"), require("infra/sui_paths"))
    H.eq(require("sui_i18n"), require("infra/sui_i18n"))
end)
H.test("component translators retain language and SimpleUI's Swedish catalog", function()
    H.eq(require("lib/bookshelf_i18n").getLang(), "sv")
    H.eq(require("infra/sui_i18n").getLang(), "sv")
    H.eq(require("infra/sui_i18n").translate("Home"), "Hem")
    H.eq(package.loaded.gettext("Home"), "Home")
end)
H.test("userpatch preload interceptors retain priority", function()
    package.preload["modules/module_quote"] = function() return { patched = true } end
    H.eq(require("modules/module_quote").patched, true)
end)
H.test("updaters are resolved through OrbitUI even after cache eviction", function()
    local updater = require("lib/bookshelf_updater")
    H.eq(updater.getInstalledVersion(), "5.4.0")
    H.eq(updater.getAvailableUpdate(), nil)
    package.loaded["infra/sui_updater"] = nil
    local sui = require("infra/sui_updater")
    H.eq(sui.selectedBranch(), "Managed by OrbitUI")
    H.eq(sui.hasUpdate(), false)
    H.eq(sui.scheduleAutoCheck(), nil)
end)
H.test("same-root install is idempotent and a second root is rejected", function()
    local n = #(package.searchers or package.loaders)
    Runtime.install(root, map)
    H.eq(#(package.searchers or package.loaders), n)
    H.eq(pcall(Runtime.install, root .. "-other", map), false)
end)
H.test("compatibility checks never auto-disable plugins or rename patches", function()
    G_reader_settings.saveSetting = function() error("unexpected setting mutation") end
    H.eq(require("infra/sui_compat_check")(), false)
end)
H.test("unsupported KOReader stops before either component class is loaded", function()
    package.loaded.version = {
        getCurrentRevision = function() return "v2025.04" end,
        getNormalizedVersion = function() return 202504000000 end,
    }
    local ok, err = pcall(Runtime.classes, root)
    H.eq(ok, false)
    assert(err:find("Update KOReader", 1, true))
end)
H.finish()
