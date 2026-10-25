-- Bookshelf owns its dock tree instead of using SimpleUI's navbar wrapper.
local M = {}
local _ = require("core/orbitui_i18n")
M.bookshelf_action = "orbitui_bookshelf"

function M.config(Config)
    local entry = { id = M.bookshelf_action, label = "Bookshelf", icon = "nerd:F02D" }
    Config.ACTION_BY_ID[entry.id] = entry
    Config.ALL_ACTIONS[#Config.ALL_ACTIONS + 1] = entry
    -- Defaults only: loadTabConfig still honours every explicitly saved bar.
    Config.DEFAULT_TABS = { "homescreen", entry.id, "sui_settings", "history", "power" }
    Config.NON_HOME_DEFAULTS = { entry.id, "sui_settings", "homescreen", "history", "power" }
    Config.homeLabel = function() return _("File browser") end
    Config.ACTION_BY_ID.home.label = _("File browser")
end

function M.changed()
    local Config = require("infra/sui_config")
    Config.invalidateTabsCache()
    local plugin = require("core/orbitui_context").plugin("simpleui")
    local bar = package.loaded["screens/sui_bottombar"]
    if plugin and bar then bar.rewrapAllWidgets(plugin) end
end

function M.hasAction(id)
    for _, value in ipairs(require("infra/sui_config").loadTabConfig()) do
        if value == id then return true end
    end
    return false
end

function M.setAction(id, enabled, replace)
    local Config = require("infra/sui_config")
    local tabs = require("core/orbitui_libraries").copy(Config.loadTabConfig())
    for i, value in ipairs(tabs) do
        if value == id then
            if enabled then return true end
            local min = Config.isNavpagerEnabled() and 1 or 2
            if #tabs <= min then return false, "minimum" end
            table.remove(tabs, i)
            Config.saveTabConfig(tabs); M.changed(); return true
        end
    end
    if not enabled then return true end
    if not Config.ACTION_BY_ID[id] then return false, "missing" end
    if replace then
        local found
        for i, value in ipairs(tabs) do if value == replace then tabs[i], found = id, true; break end end
        if not found then return false, "changed" end
    elseif #tabs < Config.effectiveMaxTabs() then tabs[#tabs + 1] = id
    else return false, "full" end
    Config.saveTabConfig(tabs); M.changed(); return true
end

local function refreshShelf()
    local Widget = package.loaded["lib/bookshelf_widget"]
    local shelf = Widget and Widget.live
    if not shelf then return end
    shelf._orbitui_navbar_pending = true
    local UIManager = require("ui/uimanager")
    if UIManager:isWidgetShown(shelf) then
        shelf:_rebuildIfSimpleUIContextChanged()
    end
end

function M.bottombar(module)
    local rewrap = module.rewrapAllWidgets
    module.rewrapAllWidgets = function(plugin)
        rewrap(plugin)
        if not (plugin and plugin._simpleui_suspended) then refreshShelf() end
    end
end

function M.widget(module)
    local rebuild = module._rebuild
    local contextChanged = module._rebuildIfSimpleUIContextChanged
    module._rebuild = function(self, ...)
        rebuild(self, ...)
        self._orbitui_navbar_pending = nil
    end
    module._rebuildIfSimpleUIContextChanged = function(self)
        if not self._orbitui_navbar_pending then return contextChanged(self) end
        -- A hidden/warm shelf is reflowed on return, not raised over Home or
        -- the reader when a global setting changes.
        self:_rebuild()
        if self._startStatusTimer then self:_startStatusTimer() end
        require("ui/uimanager"):setDirty(self, "ui")
        return true
    end
end

return M
