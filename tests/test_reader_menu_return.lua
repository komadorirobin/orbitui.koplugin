local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local copy = require("core/orbitui_libraries").copy
local values, calls, queue, current, parked, shelf = {}, {}, {}, nil, false, nil
local lang = "en"
local UI = {
    isWidgetShown = function(_, w) return w and w.shown end,
    nextTick = function(_, fn) queue[#queue + 1] = fn end,
    scheduleIn = function() end, forceRePaint = function() end,
    show = function() end, close = function() end, setDirty = function() end,
}
local RUI = {}
local Store = { get = function(_, key) return values[key] end,
    set = function(_, key, value) values[key] = value end }
local profiles = { section_7 = { key = "section_7" }, nested = { key = "nested" } }
package.loaded["ui/uimanager"] = UI
package.loaded["infra/sui_store"] = Store
package.loaded["apps/reader/readerui"] = RUI
package.loaded.logger = { warn = function() end, dbg = function() end }
package.loaded["lib/bookshelf_profiles"] = {
    get = function(key) return profiles[key] end,
    matchFile = function(file)
        if file:sub(1, 13) == "/books/manga/" then return "nested" end
        if file:sub(1, 7) == "/books/" then return "section_7" end
    end,
}
package.loaded["lib/bookshelf_widget"] = {}
package.loaded["lib/bookshelf_reader_park"] = {
    isParked = function() return parked end,
    closeShelfToFileManager = function(w)
        H.eq(w, shelf); calls.parked_exit = (calls.parked_exit or 0) + 1; return true
    end,
}
G_reader_settings = { readSetting = function(_, key) if key == "language" then return lang end end,
    has = function() return false end }

-- Native UI boundary: menu construction REPLACES the browser item and its
-- callback, just like actual ReaderMenu:setUpdateItemTable. A copied sorter
-- result catches fixes that update only menu_items, not the visible tab.
local Menu = {}
function Menu:getDefaultMenuButtons()
    return { filemanager = { icon = "appbar.filebrowser", callback = function()
        self:onTapCloseMenu()
        self.ui:onClose()
        self.ui:showFileManager(self.ui.document.file)
    end } }
end
function Menu:init() self.menu_items = self:getDefaultMenuButtons() end
function Menu:setUpdateItemTable()
    for key, item in pairs(self:getDefaultMenuButtons()) do self.menu_items[key] = item end
    self.tab_item_table = { { id = "filemanager", icon = "custom-icon", callback = self.menu_items.filemanager.callback } }
end
function Menu:onShowMenu() if not self.tab_item_table then self:setUpdateItemTable() end; return true end
function Menu:onTapCloseMenu() calls.menu_close = (calls.menu_close or 0) + 1 end
local function loadModule(path, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadfile(path)), env)() end
    return assert(loadfile(path, "t", env))()
end

-- Optional supplement loads the COMPLETE actual KOReader ReaderMenu. Native
-- widget creation/sorting/system service boundaries only are stubbed; init,
-- default callback, table rebuild, menu opening and rebuild methods are real.
local reference = os.getenv("ORBITUI_NATIVE_READER_MENU")
if reference then
    local W = H.widget()
    local deps = {
        ["ui/widget/container/inputcontainer"] = W,
        ["ui/widget/container/centercontainer"] = W,
        ["ui/widget/confirmbox"] = W, ["ui/uimanager"] = UI,
        ["device"] = { hasKeys = function() return false end, hasDPad = function() return false end,
            isTouchDevice = function() return true end,
            supportsScreensaver = function() return false end,
            screen = { getSize = function() return {} end, getWidth = function() return 100 end } },
        ["dbg"] = { guard = function() end }, ["gettext"] = function(s) return s end,
        ["ui/bidi"] = {}, ["ui/event"] = { new = function() return {} end },
        ["ui/screensaver"] = {},
        ["pluginloader"] = { genPluginManagerSubItem = function() return {} end }, ["util"] = {},
        ["logger"] = package.loaded.logger, ["ffi/util"] = {},
        ["ui/elements/common_info_menu_table"] = {}, ["ui/elements/common_exit_menu_table"] = {},
        ["ui/elements/reader_menu_order"] = {}, ["ui/elements/page_overlap.lua"] = {},
        ["ui/menusorter"] = { mergeAndSort = function(_, _, items)
            return { { id = "filemanager", icon = items.filemanager.icon, callback = items.filemanager.callback } }
        end },
        ["ui/widget/touchmenu"] = { new = function(_, opts) return opts end },
    }
    Menu = loadModule(reference, {
        require = function(name) return assert(deps[name], "Unstubbed native dependency: " .. name) end,
        dofile = function(path)
            assert(path:match("^frontend/ui/elements/"), path); return {}
        end,
    })
end
local FMMenu = { setUpdateItemTable = function() end, onShowMenu = function() end }
package.loaded["apps/reader/modules/readermenu"] = Menu
package.loaded["apps/filemanager/filemanagermenu"] = FMMenu
local Hooks = dofile(root .. "/components/simpleui/infra/sui_menu_hooks.lua")
package.loaded["infra/sui_menu_hooks"] = Hooks
local Libraries = require("adapters/orbitui_libraries")
local Adapter = require("adapters/orbitui_ui")
local Bookshelf = { _wireFastFileBrowserTab = function(self)
    self.ui.menu.menu_items.filemanager.callback = function() calls.legacy_bookshelf = true end
end,
    buildMenuItems = function() end }
Adapter.classes(Bookshelf, {})
local Patches = Adapter.wrap("infra/sui_patches", {
    wireReaderMenuFMTab = function(_, reader)
        reader.menu.menu_items.filemanager.callback = function() calls.legacy_simpleui = true end
    end,
})

local previous_owner
local function fixture(file, owned)
    if previous_owner then Hooks.uninstall(previous_owner) end
    values, calls, queue, parked, lang = {}, {}, {}, false, "en"
    profiles.section_7, profiles.nested = { key = "section_7" }, { key = "nested" }
    current = { document = { file = file or "/books/a.epub" },
        onClose = function() calls.native_close = (calls.native_close or 0) + 1 end,
        showFileManager = function(_, fp) calls.native_file = fp end,
        keyselection = { stopHighlightIndicator = function() end },
        handleEvent = function() end,
        doc_settings = { saveSetting = function() end },
    }
    RUI.instance = current
    shelf = { profile_key = "section_7", chip = "custom_chip", page = 7,
        _cursor = 43, _drilldown_path = { "custom_folder" }, shown = true,
        _opened_book = true, _orbitui_reader_file = current.document.file }
    package.loaded["lib/bookshelf_widget"].live = shelf
    local plugin = setmetatable({ _orbitui_owned = owned ~= false, ui = current,
        _safeShow = function(_, key, file_target)
            calls.fast = (calls.fast or 0) + 1; calls.profile, calls.target = key, file_target
        end,
    }, { __index = Bookshelf })
    current.bookshelf = plugin
    local menu = setmetatable({ ui = current, key_events = {}, registered_widgets = {} }, { __index = Menu })
    menu:init()
    if reference then
        -- Real menu closure remains intact, including its CloseConfigMenu event.
        local close = menu.onTapCloseMenu
        menu.onTapCloseMenu = function(self) calls.menu_close = (calls.menu_close or 0) + 1; return close(self) end
    end
    current.menu = menu
    Hooks.acquire(plugin)
    previous_owner = plugin
    plugin:_wireFastFileBrowserTab()
    Patches.wireReaderMenuFMTab({}, current)
    return current, menu, plugin
end
local function tap(menu)
    menu:onShowMenu()
    menu.tab_item_table[1].callback()
end

H.test("the real shared menu hook rewires the native browser item after the first full menu build", function()
    local reader, menu = fixture()
    local before = copy(shelf)
    tap(menu)
    H.eq(calls.fast, 1); H.eq(calls.native_close, nil); H.eq(calls.menu_close, 1)
    H.eq(calls.legacy_bookshelf, nil); H.eq(calls.legacy_simpleui, nil)
    H.eq(calls.target, nil); H.eq(shelf.chip, before.chip); H.eq(shelf.page, before.page)
    H.eq(shelf._cursor, before._cursor); H.eq(shelf._drilldown_path[1], before._drilldown_path[1])
    H.eq(reader.tearing_down, nil)
end)
H.test("cached openings and fresh menu rebuilds keep one owner and preserve the icon", function()
    local reader, menu, plugin = fixture()
    for _i = 1, 4 do
        menu:setUpdateItemTable()
        local original_icon = menu.tab_item_table[1].icon
        plugin:_wireFastFileBrowserTab(true); Patches.wireReaderMenuFMTab({}, reader)
        tap(menu)
        H.eq(menu.tab_item_table[1].icon, original_icon)
    end
    H.eq(calls.fast, 4); H.eq(calls.native_close, nil)
end)
H.test("the fast action cannot run twice from one menu or through a stale menu callback", function()
    local _, menu = fixture()
    menu:onShowMenu(); local stale = menu.tab_item_table[1].callback
    menu:onShowMenu(); stale(); H.eq(calls.fast, nil)
    local callback = menu.tab_item_table[1].callback
    callback(); callback(); H.eq(calls.fast, 1)
end)
H.test("rebuilding the whole menu invalidates callbacks from the replaced native browser item", function()
    local _, menu = fixture()
    menu:onShowMenu(); local stale = menu.tab_item_table[1].callback
    menu:setUpdateItemTable(); stale(); H.eq(calls.fast, nil)
    menu:onShowMenu(); menu.tab_item_table[1].callback(); H.eq(calls.fast, 1)
end)
H.test("a replaced reader, detached plugin or tearing-down reader makes old callbacks inert", function()
    for _, change in ipairs({ function(r) RUI.instance = {} end,
        function(r) r.bookshelf = nil end, function(r) r.tearing_down = true end }) do
        local reader, menu = fixture(); menu:onShowMenu()
        change(reader); menu.tab_item_table[1].callback()
        H.eq(calls.fast, nil); H.eq(calls.native_close, nil); H.eq(calls.menu_close, nil)
    end
end)
H.test("external Home and search books select their configured profile without touching a buried old shelf", function()
    local _, menu = fixture("/books/manga/a.epub")
    shelf._opened_book, shelf.profile_key = false, "section_7"
    tap(menu)
    H.eq(calls.profile, "nested"); H.eq(calls.target, "/books/manga/a.epub")
    H.eq(shelf.profile_key, "section_7"); H.eq(shelf.chip, "custom_chip"); H.eq(shelf.page, 7)
end)
H.test("a stale shelf-origin flag for another file cannot override the new book's profile", function()
    local _, menu = fixture("/books/manga/b.epub")
    shelf._orbitui_reader_file = "/books/old.epub"
    tap(menu); H.eq(calls.profile, "nested"); H.eq(calls.target, "/books/manga/b.epub")
end)
H.test("an unprofiled source shelf still returns to its exact saved view", function()
    local _, menu = fixture("/elsewhere/a.epub"); shelf.profile_key = nil
    tap(menu); H.eq(calls.fast, 1); H.eq(calls.profile, nil); H.eq(calls.target, nil)
end)
H.test("unknown files and disabled source profiles use the original native action, never a different shelf", function()
    for _, file in ipairs({ "/elsewhere/a.epub", "/books/a.epub" }) do
        local reader, menu = fixture(file)
        if file:sub(1, 7) == "/books/" then profiles.section_7 = nil
        else shelf._opened_book = false end
        tap(menu); H.eq(calls.fast, nil); H.eq(calls.native_close, 1); H.eq(calls.native_file, file)
        H.eq(reader._orbitui_native_reader_close, true); H.eq(reader._navbar_closing_intentionally, true)
    end
end)
H.test("the bilingual opt-out is live, defaults on, and writes only its own preference", function()
    local reader, menu = fixture()
    values.unrelated = "KEEP"
    local row = Libraries.readerMenuSetting()
    H.eq(row.checked_func(), true); row.callback(); H.eq(row.checked_func(), false)
    tap(menu); H.eq(calls.native_close, 1); H.eq(calls.fast, nil)
    H.eq(values.unrelated, "KEEP"); H.eq(values.orbitui_reader_menu_return, false)
    for _, locale in ipairs({ "en", "sv" }) do
        lang = locale; local translated = Libraries.readerMenuSetting()
        assert(#translated.help_text > 100)
        if locale == "sv" then assert(translated.text ~= row.text and translated.help_text ~= row.help_text) end
    end
    H.eq(reader.tearing_down, nil)
end)
H.test("settings search finds the cabinet control in either language without changing preferences", function()
    fixture()
    local Settings = require("adapters/orbitui_settings")
    for _, locale in ipairs({ "en", "sv" }) do
        lang = locale
        for _, query in ipairs({ "arkivskåp", "stäng boken", "reader menu", "snabb återgång" }) do
            local found
            for _, hit in ipairs(Settings.find(query)) do found = found or hit.id == "reader_menu" end
            assert(found, query)
        end
    end
    H.eq(next(values), nil); H.eq(calls.fast, nil); H.eq(calls.native_close, nil)
end)
H.test("a file-browser click over a parked shelf exits through the existing real-close owner", function()
    local _, menu = fixture(); parked = true
    tap(menu); H.eq(calls.parked_exit, 1); H.eq(calls.fast, nil); H.eq(calls.native_close, nil)
end)
H.test("non-OrbitUI readers and the ordinary FileManager menu are untouched", function()
    local reader, menu = fixture(nil, false)
    menu:setUpdateItemTable(); tap(menu)
    H.eq(calls.native_close, 1); H.eq(calls.fast, nil)
    local fm = setmetatable({ menu_items = { filemanager = { callback = function() return "original" end } } }, { __index = FMMenu })
    local callback = fm.menu_items.filemanager.callback
    FMMenu.onShowMenu(fm); H.eq(fm.menu_items.filemanager.callback, callback)
end)
H.test("hook teardown restores the native menu and reopening a reader does not stack registrations", function()
    local reader, menu, plugin = fixture()
    Libraries.unwireReaderMenu(reader, plugin)
    Hooks.uninstall(plugin)
    menu:setUpdateItemTable(); tap(menu); H.eq(calls.native_close, 1); H.eq(calls.fast, nil)
    local _, fresh = fixture(); tap(fresh); H.eq(calls.fast, 1); H.eq(calls.native_close, nil)
end)
H.test("host teardown restores only its own menu and never unwires a newer owner", function()
    local reader, menu, plugin = fixture()
    menu:onShowMenu(); local live = menu.tab_item_table[1].callback
    local Host = require("core/orbitui_host")
    Host.detach({ ui = reader, _orbitui_components = { bookshelf = {} } }, {})
    H.eq(menu.tab_item_table[1].callback, live)
    Host.detach({ ui = reader }, {})
    H.eq(menu.tab_item_table[1].callback, live)
    Host.detach({ ui = reader, _orbitui_components = { bookshelf = plugin } }, {})
    assert(menu.tab_item_table[1].callback ~= live)
    live(); H.eq(calls.fast, nil); H.eq(calls.native_close, nil)
end)
H.test("the hosted launch seam records the actual path without changing the native open or callback", function()
    local modules, saved = { "appearance", "shelf_themes", "cover_labels", "shelf_sort", "series_boxes",
        "book_bindings", "series_titles", "navbar", "android_covers" }, {}
    for _, name in ipairs(modules) do
        local id = "adapters/orbitui_" .. name; saved[id] = package.loaded[id]
        package.loaded[id] = { widget = function() end }
    end
    local after = function() end
    local W = { _commitBookStatus = function() end,
        _launchReader = function(self, file, cb)
            H.eq(self._orbitui_reader_file, file); H.eq(cb, after); return "native-open-result"
        end }
    Adapter.wrap("lib/bookshelf_widget", W)
    local obj = setmetatable({}, { __index = W })
    H.eq(obj:_launchReader("/books/real.epub", after), "native-open-result")
    H.eq(obj._orbitui_reader_file, "/books/real.epub")
    for _, name in ipairs(modules) do
        local id = "adapters/orbitui_" .. name; package.loaded[id] = saved[id]
    end
end)

-- Run the actual native safeShow method. Screen/native document operations are
-- explicit boundaries; the guard and delayed normal-close lifecycle are real.
local file = assert(io.open(root .. "/components/bookshelf/main.lua")); local source = file:read("*a"); file:close()
local method = assert(source:match("(function Bookshelf:_safeShow%b().-\nend)"))
local function safeShowCase(kind)
    local r = { document = { file = "/books/manga/a.epub" } }
    local closed, raised, shown, park_attempts = 0, 0, {}, 0
    local ticks, B = {}, {}
    local warm = { profile_key = "nested", _bookshelf_reader_prewarmed_only = true,
        _bookshelf_reader_return_ready = true, _orbitui_reader_return_file = r.document.file,
        _orbitui_reader_return_reader = r }
    if kind == "stale_reader" then warm._orbitui_reader_return_reader = {} end
    if kind == "stale_file" or kind == "legacy_explicit" then warm._orbitui_reader_return_file = "/books/old.epub" end
    if kind == "wrong_profile" then warm.profile_key = "section_7" end
    if kind == "not_ready" then warm._bookshelf_reader_return_ready = false end
    if kind == "source" then warm._bookshelf_reader_prewarmed_only = nil end
    local env = { Bookshelf = B, _live_widget = warm,
        _suppressPathChangedFor = function() end,
        BookshelfSettings = { nilOrTrue = function() return false end },
        UIManager = setmetatable({ nextTick = function(_, fn) ticks[#ticks + 1] = fn end }, { __index = UI }),
        require = function(name)
            if name == "lib/bookshelf_reader_park" then return {
                park = function() park_attempts = park_attempts + 1; return kind ~= "rotation" end }
            end
            error(name)
        end,
        _ = function(s) return s end, G_reader_settings = G_reader_settings,
        logger = package.loaded.logger,
    }
    local loader
    if setfenv then loader = setfenv(assert(loadstring(method)), setmetatable(env, { __index = _G }))
    else loader = assert(load(method, "safeShow", "t", setmetatable(env, { __index = _G }))) end
    loader()
    r.onClose = function() closed = closed + 1 end
    r.showFileManager = function() end
    RUI.instance = r
    -- Native safeShow reads the live ReaderUI only on the queued fallback.
    env.package = { loaded = { ["apps/reader/readerui"] = RUI } }
    local obj = setmetatable({ ui = r, _cancelReaderPrewarm = function() end,
        _raiseInPlace = function() raised = raised + 1 end,
        _showAfterReaderReturnWhenChromeReady = function(_, key, _, target) shown = { key, target } end }, { __index = B })
    local key, target
    if kind ~= "source" then key, target = "nested", r.document.file end
    obj:_safeShow(key, target, kind ~= "legacy_explicit")
    local parked_fast = #ticks == 0
    local pending = ticks; ticks = {}; for _, fn in ipairs(pending) do fn() end
    return parked_fast, park_attempts, closed, raised, shown
end
H.test("an exact external reader/file/profile prewarm can use the native fast path", function()
    local fast, attempts, closed = safeShowCase("ready")
    H.eq(fast, true); H.eq(attempts, 1); H.eq(closed, 0)
end)
H.test("ordinary source-shelf gesture calls keep their existing fast path", function()
    local fast, attempts, closed = safeShowCase("source")
    H.eq(fast, true); H.eq(attempts, 1); H.eq(closed, 0)
end)
H.test("other explicit target actions retain the standalone native fast-path contract", function()
    local fast, attempts, closed = safeShowCase("legacy_explicit")
    H.eq(fast, true); H.eq(attempts, 1); H.eq(closed, 0)
end)
H.test("stale or unready external shelves cannot park into the wrong profile", function()
    for _, kind in ipairs({ "stale_reader", "stale_file", "wrong_profile", "not_ready" }) do
        local fast, attempts, closed, raised, shown = safeShowCase(kind)
        H.eq(fast, false); H.eq(attempts, 0); H.eq(closed, 1); H.eq(raised, 1)
        H.eq(shown[1], "nested"); H.eq(shown[2], "/books/manga/a.epub")
    end
end)
H.test("the native rotation refusal still takes the normal close and location-return path", function()
    local fast, attempts, closed, _, shown = safeShowCase("rotation")
    H.eq(fast, false); H.eq(attempts, 1); H.eq(closed, 1); H.eq(shown[1], "nested")
end)
H.test("the native prewarm binds readiness to the actual reader and file only after location succeeds", function()
    local methods = assert(source:match("(function Bookshelf:_prewarmShelfBehindReader%b().-\nend)"))
    for _, found in ipairs({ true, false }) do
        local reader = { document = { file = "/books/manga/a.epub" } }
        local w = { profile_key = "nested", profile = { key = "nested" }, shown = true,
            showFileLocation = function(_, file) H.eq(file, reader.document.file); return found end }
        local B = {}
        local env = { Bookshelf = B, _live_widget = w, _gettime = function() return 0 end,
            UIManager = { isWidgetShown = function() return true end,
                _window_stack = { { widget = w }, { widget = reader } }, setDirty = function() end },
            logger = package.loaded.logger,
            require = function(name)
                H.eq(name, "lib/bookshelf_reader_park"); return { isParked = function() return false end }
            end }
        setmetatable(env, { __index = _G })
        local fn
        if setfenv then fn = setfenv(assert(loadstring(methods)), env)
        else fn = assert(load(methods, "prewarm", "t", env)) end
        fn()
        local obj = setmetatable({}, { __index = B })
        assert(obj:_prewarmShelfBehindReader("nested", reader, {
            explicit_return_target = true, target_file = reader.document.file }))
        H.eq(w._bookshelf_reader_return_ready, found)
        H.eq(w._orbitui_reader_return_file, found and reader.document.file or nil)
        H.eq(w._orbitui_reader_return_reader, found and reader or nil)
    end
end)
H.test("the native opt-out leaves close invalidations intact and suppresses only destination restoration", function()
    local method = assert(source:match("(function Bookshelf:onCloseDocument%b().-\nend)"))
    local guard = assert(method:find("if self.ui and self.ui._orbitui_native_reader_close then return end", 1, true))
    assert(guard > assert(method:find("noteRealClose()", 1, true)))
    assert(guard > assert(method:find("self._cancelReaderPrewarm", 1, true) or method:find("self:_cancelReaderPrewarm", 1, true)))
    assert(guard > assert(method:find("_live_widget._opened_book = false", 1, true)))
    assert(guard < assert(method:find("_close_returns_to_shelf = true", 1, true)))
end)
H.finish()
