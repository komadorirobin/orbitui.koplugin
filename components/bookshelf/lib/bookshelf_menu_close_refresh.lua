-- lib/bookshelf_menu_close_refresh.lua
--
-- KOReader's menu (TouchMenu) flashes the whole screen as it closes, against
-- ghosting, whenever the file browser or a book is under it. Over the shelf
-- it refreshes the screen with no flash (maintainer: "is that
-- necessary?"). That covers stepping the menu aside for a slider or the
-- Theme library too, which flashed as the picker opened. Over a book or the
-- file browser, KOReader's own flash as ever.
--
-- UIManager:close sends CloseWidget while the menu is still on the stack, so
-- the window under it is the one the menu sat on.

local M = {}
local owners = setmetatable({}, { __mode = "k" })
local release

-- install([deps]): wraps TouchMenu:onCloseWidget once. deps (tests):
-- { TouchMenu?, UIManager, GZ, Screen }; the first argument may be the
-- TouchMenu class itself.
function M.install(TouchMenu, deps)
    deps = deps or {}
    TouchMenu = TouchMenu or require("ui/widget/touchmenu")
    if TouchMenu._bookshelf_close_refresh then return end
    TouchMenu._bookshelf_close_refresh = true
    local orig = TouchMenu.onCloseWidget
    local active = true
    local wrapped
    wrapped = function(self, ...)
        if not active then
            if orig then return orig(self, ...) end
            return
        end
        local UIManager = deps.UIManager or require("ui/uimanager")
        local GZ = deps.GZ or require("lib/bookshelf_gesture_zones")
        local d = self.dimen
        local shelf = d and d.w and GZ.shelfBelow(self.show_parent or self)
        if not shelf then
            if orig then return orig(self, ...) end
            return
        end
        -- The whole screen, as KOReader's own refresh is, but "ui" rather
        -- than "flashui": no flash. Not just the menu's area: a menu item
        -- may open a dialog that asks for no refresh of its own, during its
        -- callback or on the next tick (other plugins' do), and only a
        -- whole-screen refresh in this pass reaches it (572).
        UIManager:setDirty(nil, "ui")
    end
    TouchMenu.onCloseWidget = wrapped
    return function()
        if not active then return end
        active = false
        if TouchMenu.onCloseWidget == wrapped then TouchMenu.onCloseWidget = orig end
        TouchMenu._bookshelf_close_refresh = nil
    end
end

function M.acquire(owner, TouchMenu, deps)
    if owners[owner] then return end
    owners[owner] = true
    if not release then release = M.install(TouchMenu, deps) end
end

function M.release(owner)
    owners[owner] = nil
    if next(owners) == nil and release then
        release()
        release = nil
    end
end

return M
