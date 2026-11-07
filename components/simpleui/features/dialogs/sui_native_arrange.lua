-- sui_native_arrange.lua — Simple UI
-- Opens the reorder lists of the collections manager as Arrange windows.
--
-- The manager shows a sort widget over the item table of its collections list
-- (arranging the collections) or of its book list (arranging the books of one
-- collection). The sort widget reorders that table in place and its callback
-- saves the order. The window does the same on every move, so the order is
-- saved as it changes.
--
-- Public API
--   NativeArrange.interceptShow(widget) -> boolean   show step (consumes the call)

local ButtonDialog = require("ui/widget/buttondialog")
local logger       = require("logger")
local SortWidget   = require("ui/widget/sortwidget")
local UIManager    = require("ui/uimanager")
local _            = require("gettext")

local SUIWindow = require("engines/sui_window")

local NativeArrange = {}

-- True when `item_table` is one of the tables the collections manager of the
-- file manager lists.
local function isManagerTable(item_table)
    local file_manager = package.loaded["apps/filemanager/filemanager"]
    local manager = file_manager and file_manager.instance and file_manager.instance.collections
    if not manager then return false end

    local collections, books = manager.coll_list, manager.booklist_menu
    return (collections ~= nil and collections.item_table == item_table)
        or (books ~= nil and books.item_table == item_table)
end

local SORT_CHOICES = {
    { _("Sort A to Z"),             "strcoll", false },
    { _("Sort Z to A"),             "strcoll", true  },
    { _("Sort A to Z (natural)"),   "natural", false },
    { _("Sort Z to A (natural)"),   "natural", true  },
}

-- Sorts `items` in place by `text` with the file chooser collate `collate_id`.
local function sortItems(items, collate_id, reverse)
    local FileChooser = require("ui/widget/filechooser")
    table.sort(items, FileChooser:getSortingFunction(FileChooser.collates[collate_id], reverse))
end

local function present(sort_widget)
    local source = sort_widget.item_table
    local fm = package.loaded["apps/filemanager/filemanager"].instance
    local manager = fm.collections
    local slot = manager.coll_list and manager.coll_list.item_table == source and "coll_list" or "booklist_menu"
    local target, expected_table = manager[slot], source
    local path = target.path
    local generation = UIManager._simpleui_navigation_generation
    local win, popup, retired
    local function current()
        local file_manager = package.loaded["apps/filemanager/filemanager"]
        return not retired and win and not win._closed
            and generation == UIManager._simpleui_navigation_generation
            and file_manager and file_manager.instance == fm
            and fm.collections == manager and target and manager[slot] == target
            and target.item_table == expected_table and target.path == path
    end
    local function visible(owner)
        return UIManager:getTopmostVisibleWidget() == owner
    end
    local function closePopup()
        local dialog = popup
        popup = nil
        if dialog then UIManager:close(dialog) end
    end
    local items  = {}
    for _i, entry in ipairs(source) do
        items[#items + 1] = { text = entry.text, orig_item = entry }
    end

    local function applyChange(arranged)
        if not current() or not visible(win._wrapper) then return end
        for i, item in ipairs(arranged) do source[i] = item.orig_item end
        sort_widget.callback()
        -- Native collection callbacks rebuild their displayed item table after
        -- EVERY own save. Adopt that new identity, not an unrelated later one.
        target = manager[slot]
        expected_table = target and target.item_table
    end

    win = SUIWindow.showArrange{
        title     = sort_widget.title,
        items     = items,
        on_close  = function() retired = true; closePopup() end,
        footer    = {
            text   = _("Sort"),
            on_tap = function(ctx)
                if not current() or popup or not visible(win._wrapper) then return end
                local dialog
                local buttons = {}
                for _i, choice in ipairs(SORT_CHOICES) do
                    buttons[#buttons + 1] = {{
                        text     = choice[1],
                        align    = "left",
                        callback = function()
                            if not current() or popup ~= dialog or not visible(dialog) then return end
                            closePopup()
                            if not current() or not visible(win._wrapper) then return end
                            sortItems(items, choice[2], choice[3])
                            applyChange(items)
                            ctx.repaint()
                        end,
                    }}
                end
                -- Keep the native identity: hosted NativeSheets otherwise
                -- replaces ButtonDialog with a different window (C10).
                dialog = ButtonDialog:new{ sui_native = true, shrink_unneeded_width = true, buttons = buttons }
                popup = dialog
                UIManager:show(dialog)
            end,
        },
        on_change = applyChange,
    }
end

--- Show step: replaces a sort widget of the collections manager with an
--- Arrange window. Returns true when the widget was consumed.
function NativeArrange.interceptShow(widget)
    if widget == nil or getmetatable(widget) ~= SortWidget then return false end
    if not isManagerTable(widget.item_table) then return false end

    local ok, err = pcall(present, widget)
    if ok then return true end
    logger.warn("simpleui/native_arrange: window failed, showing the sort widget:", tostring(err))
    return false
end

return NativeArrange
