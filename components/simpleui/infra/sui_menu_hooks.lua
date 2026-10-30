-- sui_menu_hooks.lua — Simple UI
--
-- Single hook point for the top menus of the reader and the file browser.
--
-- Each menu class receives one wrapper per entry point, owned by this module:
--   setUpdateItemTable  runs the `prepare` steps right after the tab table is
--                       built, so anything that reads the table before the
--                       menu opens (e.g. gesture-zone tab lookups) already
--                       sees the final tab layout.
--   onShowMenu          builds the table when missing, runs the `prepare`
--                       steps again (the table is cached between openings)
--                       and lets the `resolve` steps choose the initial tab.
--
-- A step is a table:
--   id       unique name; registering an existing id replaces that step
--   order    position among the steps (see M.ORDER); lower runs first
--   prepare  function(menu, target)            — adjusts menu.tab_item_table;
--                                                must be idempotent
--   resolve  function(menu, target, tab_index) — returns the tab to open on;
--                                                skipped when the menu is built
--                                                without being shown
-- `target` is M.TARGET.READER or M.TARGET.FM.
-- M.refresh(menu, target) runs the `prepare` steps again on a built menu.

local logger = require("logger")

local M = {}

M.TARGET = { READER = "reader", FM = "fm" }

-- Execution order of the steps (lower runs first).
M.ORDER = { MENU_HIDE = 5, PANEL_TAB = 10, TAB_ICONS = 20, TAB_LAYOUT = 30 }

local MENU_MODULES = {
    [M.TARGET.READER] = "apps/reader/modules/readermenu",
    [M.TARGET.FM]     = "apps/filemanager/filemanagermenu",
}

-- Class field that holds the original methods while the wrappers are installed.
local ORIG_FIELD = "_sui_menu_hooks_orig"

local _steps = {}

-- Runs `hook` of every step in order. A failing step is logged and skipped so
-- the menu always opens. Returns the tab index as left by the resolve steps.
local function runSteps(hook, menu, target, tab_index)
    for _, step in ipairs(_steps) do
        local fn = step[hook]
        if fn then
            local ok, result = pcall(fn, menu, target, tab_index)
            if not ok then
                logger.warn("simpleui/menu_hooks: step", step.id, hook, "failed:", result)
            elseif hook == "resolve" then
                tab_index = result
            end
        end
    end
    return tab_index
end

local function loadMenuClass(target)
    local path = MENU_MODULES[target]
    local Menu = package.loaded[path]
    if Menu then return Menu end
    local ok, mod = pcall(require, path)
    return ok and mod or nil
end

local function hook(target)
    local Menu = loadMenuClass(target)
    if not Menu then return end
    local installed = rawget(Menu, ORIG_FIELD)
    if installed then
        installed.runSteps = runSteps
        return installed
    end

    local orig = {
        setUpdateItemTable = Menu.setUpdateItemTable,
        onShowMenu         = Menu.onShowMenu,
        active            = true,
        users             = {},
        runSteps          = runSteps,
    }
    Menu[ORIG_FIELD] = orig

    function Menu:setUpdateItemTable(...)
        local ret = orig.setUpdateItemTable(self, ...)
        if orig.active then orig.runSteps("prepare", self, target) end
        return ret
    end

    function Menu:onShowMenu(tab_index, do_not_show)
        if not orig.active then return orig.onShowMenu(self, tab_index, do_not_show) end
        if self.tab_item_table == nil then self:setUpdateItemTable() end
        orig.runSteps("prepare", self, target)
        if not do_not_show then
            tab_index = orig.runSteps("resolve", self, target, tab_index)
        end
        return orig.onShowMenu(self, tab_index, do_not_show)
    end
    orig.update_wrapper, orig.show_wrapper = Menu.setUpdateItemTable, Menu.onShowMenu
    return orig
end

local function unhook(target, owner)
    local Menu = package.loaded[MENU_MODULES[target]]
    local orig = Menu and rawget(Menu, ORIG_FIELD)
    if not orig then return end
    if owner then
        orig.users[owner] = nil
        if next(orig.users) then return true end
    end
    -- A patch installed later may wrap us. Leave it in place, but turn our
    -- captured wrapper into a pass-through so re-enabling cannot stack effects.
    orig.active = false
    if Menu.setUpdateItemTable == orig.update_wrapper then
        Menu.setUpdateItemTable = orig.setUpdateItemTable
    end
    if Menu.onShowMenu == orig.show_wrapper then Menu.onShowMenu = orig.onShowMenu end
    Menu[ORIG_FIELD]        = nil
end

function M.acquire(owner)
    for _, target in pairs(M.TARGET) do
        local state = hook(target)
        if state then state.users[owner] = true end
    end
end

--- Registers a step (replacing any step with the same id) and makes sure the
--- menu classes are hooked.
function M.register(step)
    assert(step.id and step.order, "menu hook steps need an id and an order")
    for i, existing in ipairs(_steps) do
        if existing.id == step.id then
            table.remove(_steps, i)
            break
        end
    end
    local pos = #_steps + 1
    for i, existing in ipairs(_steps) do
        if existing.order > step.order then
            pos = i
            break
        end
    end
    table.insert(_steps, pos, step)
    for _, target in pairs(M.TARGET) do hook(target) end
end

--- Runs the `prepare` steps again on a menu whose tab table is already built.
function M.refresh(menu, target)
    runSteps("prepare", menu, target)
end

--- Restores the original menu methods and drops every registered step.
function M.uninstall(owner)
    local retained = false
    for _, target in pairs(M.TARGET) do
        if unhook(target, owner) then retained = true end
    end
    if not retained then _steps = {} end
end

return M
