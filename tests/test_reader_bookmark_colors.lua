local H = require("tests/helpers")
local Panel = require("adapters/orbitui_book_panel")
local function fixture()
    local settings, stack, events = {}, {}, {}
    local UI = {
        show = function(_, widget) stack[#stack + 1] = widget end,
        close = function(_, widget)
            for i, entry in ipairs(stack) do if entry == widget then table.remove(stack, i); return end end
        end,
        setDirty = function() end,
    }
    G_reader_settings = {
        readSetting = function(_, key) return settings[key] end,
        saveSetting = function(_, key, value) settings[key] = value end,
    }
    local W = { new = function(_, opts) return opts end }
    package.loaded["ui/widget/menu"], package.loaded["ui/widget/buttondialog"] = W, W
    package.loaded["ui/uimanager"] = UI
    package.loaded["ui/event"] = { new = function(_, name, data) return { name = name, data = data } end }
    package.loaded.device = { screen = { isColorEnabled = function() return true end } }
    package.loaded["ui/bidi"] = { mirroredUILayout = function() return false end }
    package.loaded["ffi/blitbuffer"] = { COLOR_BLACK = "black", colorFromString = function(ink) return ink end }
    local dogear = { { dimen = { w = 400 } }, icon = { dimen = {} }, dogear_size = 20, dogear_y_offset = 3,
        paintTo = function() events[#events + 1] = "native paint" end }
    local ui = { document = {}, paging = {}, current = 1, annotation = { annotations = {} }, view = { dogear = dogear },
        handleEvent = function(_, event) events[#events + 1] = event end,
        link = { addCurrentLocationToStack = function() events[#events + 1] = "position saved" end } }
    local bm = {}; ui.bookmark = bm
    function bm:getCurrentPageNumber() return ui.current end
    function bm:getDogearBookmarkIndex(page)
        for i, entry in ipairs(ui.annotation.annotations) do if entry.page == page and not entry.drawer then return i end end
    end
    function bm:toggleBookmark(page)
        page = page or ui.current
        local i = self:getDogearBookmarkIndex(page)
        if i then table.remove(ui.annotation.annotations, i)
        else table.insert(ui.annotation.annotations, { page = page }) end
    end
    function bm:onToggleBookmark() self:toggleBookmark() end
    function bm:getBookmarkPageString(page) return tostring(page) end
    function bm:gotoBookmark(page) ui.current = page end
    Panel.attachBookmarkColors(ui)
    return ui, dogear, stack, events
end

H.test("native uncolored bookmarks stay native and later bookmarks use the last selected color", function()
    local ui, ribbon, _, events = fixture()
    ui.bookmark:onToggleBookmark()
    ribbon:paintTo({}, 0, 0); H.eq(events[1], "native paint")
    local chooser = Panel.bookmarkColorPicker(ui)
    chooser.buttons[1][1].callback()
    local first = ui.annotation.annotations[1]
    H.eq(first.orbitui_bookmark_color, "red")
    H.eq(events[2].name, "AnnotationsModified")
    local ink = {}
    ribbon:paintTo({ paintRect = function(_, x, y, w, h, color) ink[color] = true end }, 0, 0)
    assert(ink["#ca4f43"] and ink.black)
    ui.current = 2
    ui.bookmark:onToggleBookmark()
    H.eq(ui.annotation.annotations[2].orbitui_bookmark_color, "red")
    ui.bookmark:onToggleBookmark(); H.eq(#ui.annotation.annotations, 1)
end)

H.test("color filters preserve bookmark navigation and never include text highlights", function()
    local ui, _, stack, events = fixture()
    ui.annotation.annotations = {
        { page = 1, drawer = "lighten", orbitui_bookmark_color = "red" },
        { page = 2, orbitui_bookmark_color = "red" }, { page = 3, orbitui_bookmark_color = "blue" },
    }
    local list = Panel.showColoredBookmarks(ui)
    list:onMenuSelect(list.item_table[1]); H.eq(#stack, 2)
    local filter = stack[2]
    filter:onMenuSelect(filter.item_table[2]); H.eq(#stack, 1)
    local red = stack[1]
    H.eq(#red.item_table, 3)
    red:onMenuSelect(red.item_table[3]); H.eq(#stack, 0)
    H.eq(ui.current, 2); H.eq(events[1], "position saved")
end)

H.finish()
