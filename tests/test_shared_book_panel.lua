package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Widget = H.widget()
local queue, shown, opened, refreshed, navigated = {}, {}, nil, 0, 0
local UI = {
    nextTick = function(_, fn) queue[#queue + 1] = fn end,
    scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end,
    show = function(_, w) w.shown = true; shown[#shown + 1] = w end,
    close = function(_, w) w.shown = false end,
    isWidgetShown = function(_, w) return w.shown end,
    setDirty = function() end,
}
local function flush()
    local n = 0
    while #queue > 0 do
        table.remove(queue, 1)(); n = n + 1; assert(n < 50, "unbounded transition")
    end
end
package.loaded["ui/uimanager"] = UI
package.loaded["ui/geometry"] = H.widget()
package.loaded["device"] = { screen = { getWidth = function() return 1264 end, getHeight = function() return 1680 end } }
package.loaded["ui/widget/infomessage"] = H.widget()
package.loaded.logger = { warn = function() end }
package.loaded["engines/sui_screen_engine"] = {
    openBook = function(file) opened = file end,
    invalidateAllCfgAndRefresh = function() refreshed = refreshed + 1 end,
}
local actual = { shown = true, profile_key = "comics", _rebuild = function() end,
    setProfile = function(self, profile) self.profile_key = profile end,
    _selectChip = function(self, chip) self.chip = chip end }
local plugin = { _widget = actual, onOpenBookshelfProfile = function() end }
package.loaded.pluginloader = { getPluginInstance = function(_, name)
    if name == "bookshelf" then return plugin end
end }
local Context = require("core/orbitui_context")
local Repo = { buildBookMeta = function(file, opts)
    H.eq(opts.want_cover, false)
    return { filepath = file, title = "Book", hardcover_book_id = 42 }
end }
package.loaded["lib/bookshelf_book_repository"] = Repo

-- Exercise the real native detail factory and plugin-row builder with render
-- primitives stubbed, rather than copying their behavior into the adapter test.
local f = assert(io.open("components/bookshelf/lib/bookshelf_widget.lua"))
local source = f:read("*a"); f:close()
local function native(name, args)
    local body = assert(source:match("\nfunction BookshelfWidget:" .. name .. "%(" .. args .. "%)\n(.-)\nend\n"))
    local code = "return function(self, " .. args .. ")\n" .. body .. "\nend"
    local env = setmetatable({ UIManager = UI, Repo = Repo, _ = function(s) return s end }, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "native book detail", "t", env))()
end
Widget._fileDialogPluginRows = native("_fileDialogPluginRows", "file")
Widget._showBookDetail = native("_showBookDetail", "book, opts")
Widget._isRemoteRecord = function() return false end
Widget._buildPillSpecs = function() return {} end
Widget._descriptionArgs = function() return { html_body = "<p>Book</p>" } end
Widget._bookReview = function() return nil end
Widget._buildBookEditTab = function() return "native-edit" end
Widget.init = function() error("must not initialize a hidden shelf") end
Widget.live = actual
package.loaded["lib/bookshelf_widget"] = Widget
package.loaded.readcollection = { default_collection_name = "favorites", getCollectionsWithFile = function() return {} end }
package.loaded["lib/bookshelf_tokens"] = { reviewsHtml = function() return "<p>Cached</p>" end }
local cache_reads = 0
package.loaded["lib/bookshelf_hardcover"] = {
    isAvailable = function() return true end,
    fetchReviews = function(_, opts)
        H.eq(opts.cache_only, true); cache_reads = cache_reads + 1; return true, {}
    end,
    fetchReviewsOnline = function() error("render must not start a network request") end,
}
local Modal = H.widget()
function Modal:onClose()
    if self.closed then return end
    self.closed = true
    UI:close(self)
    self.on_close()
end
package.loaded["lib/bookshelf_reviews_modal"] = Modal
package.loaded["lib/bookshelf_cover_apply"] = { resetWorkingCache = function() end }
local callbacks = {}
package.loaded["apps/filemanager/filemanager"] = { file_dialog_added_buttons = {
    function(file, is_file, props, close)
        H.eq(is_file, true); callbacks.undo = close
        return { { text = "Undo opening", callback = close } }
    end,
    function(file, is_file, props, close)
        callbacks.navigate = close
        return { { text = "Browse author", callback = close } }
    end,
    function() error("one broken plugin must not hide other actions") end,
    function() error("coverbrowser button must be skipped") end,
    index = { undo = 1, author = 2, broken = 3, coverbrowser = 4 },
} }
local Panel = require("adapters/orbitui_book_panel")
local file = "/storage/emulated/0/ePubs/Fiktion/book.epub"
local controller, modal
H.test("Home opens the actual Bookshelf panel without initializing or owning a shelf", function()
    modal = Panel.show(file)
    controller = modal.bw
    H.eq(Widget.live, actual)
    H.eq(controller._orbitui_detail_only, true)
    H.eq(controller.profile_key, "prose")
    H.eq(modal._sui_keep_homescreen, true)
    H.eq(modal.tabs[modal.active_tab].id, "edit")
    H.eq(modal.tabs[modal.active_tab].widget_builder(), "native-edit")
    H.eq(cache_reads, 1)
    H.eq(#queue, 0)
end)
H.test("book opening retains the native Home path and registered userpatch actions", function()
    modal.on_open(); H.eq(opened, file)
    local rows = controller:_fileDialogPluginRows(file)
    H.eq(#rows, 2)
    H.eq(rows[1][1].text, "Undo opening")
    assert(type(callbacks.undo) == "function")
    callbacks.undo()
    H.eq(modal.closed, true)
    assert(refreshed > 0)
end)
H.test("context-specific plugin navigation and module settings remain reachable", function()
    local module_settings = 0
    modal = Panel.show(file, {
        navigate_row_ids = { author = true },
        navigate_fn = function() navigated = navigated + 1 end,
        open_settings_fn = function() module_settings = module_settings + 1 end,
        extra_rows = function(_, close)
            return { { { text = "Module action", callback = close } } }
        end,
    })
    local rows = modal.bw:_fileDialogPluginRows(file)
    H.eq(#rows, 4)
    rows[2][1].callback(); H.eq(navigated, 1)
    rows[4][1].callback(); H.eq(module_settings, 1)
    H.eq(modal.closed, true)
end)
H.test("a broken extra-row provider cannot break the native panel", function()
    local c = Panel.controller(file, { extra_rows = function() error("unavailable") end })
    H.eq(#c:_fileDialogPluginRows(file), 2)
end)
H.test("Book Information preserves Home through the native one-shot helper and chains its close callback", function()
    local f = assert(io.open("components/simpleui/features/library/sui_book_hold_dialog.lua"))
    local text = f:read("*a"); f:close()
    local body = assert(text:match("local function _keepHomescreenAliveForNextShow%(%)\n(.-)\nend\n"))
    local env = setmetatable({ UIManager = UI }, { __index = _G })
    local code = "return function()\n" .. body .. "\nend"
    local helper
    if setfenv then helper = setfenv(assert(loadstring(code)), env)()
    else helper = assert(load(code, "one-shot Home preservation", "t", env))() end
    package.loaded["features/library/sui_book_hold_dialog"] = { keepHomescreenAliveForNextShow = helper }
    local original_show = UI.show
    controller:_orbitui_before_book_info()
    local closed = 0
    local info = { close_callback = function() closed = closed + 1 end }
    UI:show(info)
    H.eq(info._sui_keep_homescreen, true)
    H.eq(UI.show, original_show)
    controller:_orbitui_after_book_info(info)
    local before = refreshed
    info.close_callback()
    H.eq(closed, 1); H.eq(refreshed, before + 1)
    controller:_orbitui_before_book_info()
    flush()
    H.eq(UI.show, original_show)
end)
H.test("selection hands off to the real visible library, not a second widget", function()
    controller._selection:enterMode(); controller._selection:add(file)
    local selection = controller._selection
    controller:_rebuild(); flush()
    H.eq(actual._selection, selection)
    H.eq(actual.profile_key, "prose")
    H.eq(controller._selection:isActive(), false)
end)
H.test("a genre shelf created in the panel opens in the unscoped library", function()
    controller.chip = "custom_9"
    controller:_syncPageFromCursor()
    controller:_rebuild(); flush()
    H.eq(actual.profile_key, nil); H.eq(actual.chip, "custom_9")
end)
H.test("Home group navigation preserves the upstream whole-group flag", function()
    for _, method in ipairs{ "_expandAuthor", "_expandSeries", "_expandGenre", "_expandTag" } do
        local group = { series_name = "Group", books = {} }
        local passed_group, passed_whole
        actual[method] = function(_, value, whole)
            passed_group, passed_whole = value, whole
        end
        controller[method](controller, group, true)
        flush()
        H.eq(passed_group, group); H.eq(passed_whole, true)
        controller[method](controller, group)
        flush()
        H.eq(passed_group, group); H.eq(passed_whole, nil)
        actual[method] = nil
    end
end)
H.test("profile navigation handles a shelf restored by hot reader parking", function()
    actual.profile_key = "prose"
    local called = false
    Context.withShelf("comics", function(w) called = true; H.eq(w, actual) end)
    flush()
    H.eq(called, true); H.eq(actual.profile_key, "comics")
end)
H.test("superseded navigation cannot open stale UI after another request or a book opening", function()
    Context.withShelf("prose", function() error("superseded callback") end)
    Context.withShelf("comics", function() end)
    flush()
    Context.withShelf("prose", function() error("book already opened") end)
    Context.openBook(file); flush()
end)
H.test("library transition timeout reports failure without touching a hidden shelf", function()
    actual.shown = false
    Context.withShelf("prose", function() error("hidden widget must not be used") end)
    flush()
    assert(shown[#shown].text:find("Could not open the library", 1, true))
    actual.shown = true
end)
H.finish()
