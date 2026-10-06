-- Bookshelf owns its dock tree instead of using SimpleUI's navbar wrapper.
local M = {}

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
