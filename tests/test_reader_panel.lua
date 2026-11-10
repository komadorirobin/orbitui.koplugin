local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local W = H.widget()
local UI, reader, history, files, payloads, hidden, queue, scheduled, calls, notices, reads, now
local ask, slow, broken, language, R, closes, native_loads
function W:_init() self.key_events = {}; self.ges_events = {} end
function W:getSize() return { w = self.width or 400, h = self.height or (self.buttons and #self.buttons * 40) or 20 } end
function W:free() end
function W:onShowKeyboard() self.keyboard = true end
function W:addWidget(child) self.added = self.added or {}; self.added[#self.added + 1] = child end
function W:getButtonById(id)
    for _, row in ipairs(self.buttons) do for _, b in ipairs(row) do
        if b.id == id then b.setText = function(this, text) this.text = text end; return b end
    end end
end
package.loaded["ui/widget/buttondialog"] = W
package.loaded["ui/widget/confirmbox"] = W
package.loaded["ui/time"] = { now = function() return now end, since = function(start) return now - start end, to_us = function(v) return v * 1e6 end }
local function attr(path, key)
    local a = files[path]
    return key and a and a[key] or not key and a or nil
end
package.loaded["libs/libkoreader-lfs"] = { attributes = attr, symlinkattributes = attr }
local DS = {
    findSidecarFile = function(_, file) return file .. ".metadata.lua" end,
    findCustomMetadataFile = function(_, file) if payloads[file .. ".custom.lua"] then return file .. ".custom.lua" end end,
    openSettingsFile = function(path)
        reads = reads + 1; now = now + (slow and .011 or .0001)
        if broken == path then error("bad metadata") end
        local data = assert(payloads[path], path)
        return { readSetting = function(_, name) return data[name] end }
    end,
    open = function() error("must not open/repair DocSettings") end,
    close = function() error("must not write DocSettings") end,
}
package.loaded.docsettings = DS
package.loaded.readhistory = { hist = {} }
package.loaded["features/library/sui_recent_hidden"] = { isHidden = function(file) return hidden[file] end }
package.loaded["device"] = { screen = {
    getWidth = function() return 600 end, getHeight = function() return 800 end,
    scaleBySize = function(_, n) return n end, getSize = function() return { w = 600, h = 800 } end,
}, hasKeys = function() return false end, isTouchDevice = function() return true end }
package.loaded.logger = { warn = function() end, dbg = function() end }
package.loaded["core/orbitui_context"] = { notify = function(text) notices[#notices + 1] = text end,
    openBook = function() error("reader switch must not force a Home return origin") end }
G_reader_settings = { readSetting = function(_, key, default) if key == "language" then return language end; return default end,
    isTrue = function(_, key) return key == "file_ask_to_open" and ask or false end,
    nilOrTrue = function() return true end }
UI = {
    isWidgetShown = function(_, item) for _, w in ipairs(UI.stack) do if w == item then return true end end; return false end,
    getTopmostVisibleWidget = function() return UI.stack[#UI.stack] end,
    show = function(_, item) UI.stack[#UI.stack + 1] = item end,
    close = function(_, item)
        closes[item] = (closes[item] or 0) + 1
        if item.onCloseWidget then item:onCloseWidget() end
        for i = #UI.stack, 1, -1 do if UI.stack[i] == item then table.remove(UI.stack, i) end end
    end,
    scheduleIn = function(_, delay, fn)
        assert(delay > 0); queue[#queue + 1] = fn; scheduled[#scheduled + 1] = fn
    end,
    unschedule = function(_, fn) for i = #queue, 1, -1 do if queue[i] == fn then table.remove(queue, i) end end end,
    setDirty = function() end,
}
package.loaded["ui/uimanager"] = UI
local Panel = dofile(root .. "/adapters/orbitui_book_panel.lua")
local Tools = Panel.readerTools()
local function book(file, pct, status, title)
    files[file] = { mode = "file", size = 10000, modification = 10 }
    files[file .. ".metadata.lua"] = { mode = "file", size = 300, modification = 10 }
    payloads[file .. ".metadata.lua"] = { percent_finished = pct, summary = { status = status }, doc_props = { title = title or file } }
    history[#history + 1] = { file = file, time = #history + 1 }
end
local function fixture()
    if reader then Tools.retire(reader) end
    Tools.event("onResume")
    history, files, payloads, hidden, queue, scheduled, calls, notices, closes = {}, {}, {}, {}, {}, {}, {}, {}, {}
    reads, now, ask, slow, broken, language, native_loads = 0, 0, false, false, nil, "en", 0
    package.loaded.docsettings = DS
    package.loaded.readhistory.hist = history
    reader = { document = { file = "/books/current.epub" }, doc_props = { display_title = "Current book" },
        doc_settings = { readSetting = function() return nil end } }
    UI.stack = { reader }; UI._simpleui_navigation_generation = 1
    R = { instance = reader, showReader = function(self, ...)
        H.eq(self, R); H.eq(select("#", ...), 1); assert(UI:getTopmostVisibleWidget() ~= nil)
        calls[#calls + 1] = { "open", ... }
    end }
    package.loaded["apps/reader/readerui"] = R
    for _, action in ipairs{ { "toc", "onShowToc" }, { "bookmark", "onShowBookmark" },
        { "search", "onShowFulltextSearchInput" }, { "bookinfo", "onShowBookInfo" }, { "gotopage", "onShowGotoDialog" },
        { "config", "onShowConfigMenu" } } do
        local id, method = action[1], action[2]
        local target = {}; reader[id] = target
        target[method] = function(self, ...)
            H.eq(self, target); H.eq(select("#", ...), 0)
            H.eq(UI:getTopmostVisibleWidget(), reader)
            calls[#calls + 1] = { id }
        end
    end
    Panel._reader_pins = { retire = function() end, show = function(ui) H.eq(ui, reader); calls[#calls + 1] = { "pins" } end }
end
local function top() return UI:getTopmostVisibleWidget() end
local function find(id, window) return assert((window or top()):getButtonById(id), id) end
local function tick() local fn = table.remove(queue, 1); if fn then fn() end end
local function drain() local n = 0; while #queue > 0 do n = n + 1; assert(n < 1000); tick() end end
local function books(window)
    local result = {}
    for _, row in ipairs((window or top()).buttons) do for _, entry in ipairs(row) do
        if entry.id and entry.id:match("^book:") then result[#result + 1] = entry end
    end end
    return result
end
H.test("panel is lazy, tools do not scan or save and no menu/header hook is replaced", function()
    fixture(); H.eq(Panel.readerTools(), Tools)
    Tools.show(reader); H.eq(reads, 0); H.eq(#queue, 0); H.eq(#calls, 0)
    assert(find("toc").enabled); assert(find("pins").enabled)
    H.eq(reader.onClose, nil); H.eq(reader.view, nil); H.eq(reader.document.file, "/books/current.epub")
end)
H.test("each allowed native tool receives the right live module, no arguments and no lingering panel", function()
    for _, id in ipairs{ "toc", "bookmark", "search", "bookinfo", "gotopage", "pins", "config" } do
        fixture(); Tools.show(reader); find(id).callback(); H.eq(calls[1][1], id); H.eq(top(), reader)
    end
end)
H.test("missing and callable sandbox handlers retain safe native semantics", function()
    fixture(); reader.toc = nil; Tools.show(reader); H.eq(find("toc").enabled, false)
    local seen
    reader.toc = { onShowToc = setmetatable({}, { __call = function(_, self) seen = self; return nil, "native" end }) }
    Tools.show(reader); find("toc").callback(); H.eq(seen, reader.toc)
    reader.search.onShowFulltextSearchInput = function() error("native failure") end
    Tools.show(reader); find("search").callback(); assert(#notices > 0); H.eq(top(), reader)
end)
H.test("tools tabs start Also reading only after an explicit tap and yield between bounded reads", function()
    fixture(); for i = 1, 30 do book("/books/b" .. i .. ".epub", .2) end
    Tools.show(reader); find("ongoing").callback(); H.eq(reads, 0); H.eq(#queue, 1)
    tick(); H.eq(reads, 4); H.eq(#queue, 1); H.eq(#books(), 0)
    drain(); H.eq(#books(), 12); H.eq(reads, 12)
end)
H.test("slow single sidecar reads cannot become a whole-history UI tick", function()
    fixture(); slow = true; for i = 1, 10 do book("/books/b" .. i .. ".epub", .2) end
    Tools.show(reader, "ongoing"); tick(); H.eq(reads, 1); H.eq(#queue, 1)
    find("close").callback(); local before = reads; drain(); H.eq(reads, before); H.eq(top(), reader)
end)
H.test("ongoing excludes current, duplicates, remote, hidden, deleted and finished or abandoned books", function()
    fixture()
    book(reader.document.file, .4); book("/books/a.epub", .2, "reading", "Alpha")
    book("/books/a.epub", .2); book("/books/zero.epub", 0); book("/books/one.epub", 1)
    for _, status in ipairs{ "complete", "finished", "abandoned" } do book("/books/" .. status .. ".epub", .4, status) end
    book("/books/hidden.epub", .5); hidden["/books/hidden.epub"] = true
    book("/books/deleted.epub", .5); history[#history].dim = true
    history[#history + 1] = { file = "OPDS://remote.epub" }
    book("/books/volume.cbz", .3, "onhold"); book("/books/paper.pdf", .8)
    Tools.show(reader, "ongoing"); drain(); local result = books()
    H.eq(#result, 3); H.eq(result[1].id, "book:/books/a.epub"); H.eq(result[2].id, "book:/books/volume.cbz")
    H.eq(#calls, 0)
end)
H.test("a 3341-entry history stops after 200 records without walking the library", function()
    fixture(); for i = 1, 3341 do book("/books/b" .. i .. ".epub", i <= 200 and 1 or .3) end
    Tools.show(reader, "ongoing"); drain(); H.eq(reads, 200); H.eq(#books(), 0)
    assert(find("state_status").text:find("No other", 1, true))
end)
H.test("native custom titles, Unicode and progress are display-only", function()
    fixture(); book("/books/a.epub", .457, "reading", "Original")
    files["/books/a.epub.custom.lua"] = { mode = "file", size = 300 }
    payloads["/books/a.epub.custom.lua"] = { custom_props = { title = string.rep("漫画", 50) } }
    Tools.show(reader, "ongoing"); drain(); local label = books()[1].text
    assert(label:find("漫画", 1, true)); assert(label:find("46%", 1, true)); assert(#label < 190)
    H.eq(payloads["/books/a.epub.metadata.lua"].percent_finished, .457)
end)
H.test("oversized, missing, symlinked and corrupt metadata are disclosed rather than repaired", function()
    fixture(); for i = 1, 4 do book("/books/b" .. i .. ".epub", .2) end
    files["/books/b1.epub.metadata.lua"].size = 600 * 1024
    files["/books/b2.epub.metadata.lua"] = nil
    files["/books/b3.epub.metadata.lua"].mode = "link"
    broken = "/books/b4.epub.metadata.lua"
    Tools.show(reader, "ongoing"); drain(); H.eq(#books(), 0); H.eq(reads, 1)
    local text = {}; for _, row in ipairs(top().buttons) do for _, b in ipairs(row) do text[#text + 1] = b.text end end
    assert(table.concat(text, " "):find("4 reading-data records", 1, true))
end)
H.test("reader switch uses native showReader once and does not force Home or manually close the reader", function()
    fixture(); book("/books/manga.cbz", .2); Tools.show(reader, "ongoing"); drain()
    find("book:/books/manga.cbz").callback(); H.eq(#calls, 1); H.eq(calls[1][2], "/books/manga.cbz")
    H.eq(top(), reader); H.eq(reader.document.file, "/books/current.epub")
end)
H.test("selection rechecks file identity, status, hidden state and history before switching", function()
    for _, change in ipairs{ "file", "complete", "history", "hidden", "deleted", "metadata" } do
        fixture(); book("/books/a.epub", .4); Tools.show(reader, "ongoing"); drain()
        if change == "file" then files["/books/a.epub"].size = 10001
        elseif change == "complete" then payloads["/books/a.epub.metadata.lua"].summary.status = "complete"
        elseif change == "history" then package.loaded.readhistory.hist = {}
        elseif change == "hidden" then hidden["/books/a.epub"] = true
        elseif change == "deleted" then files["/books/a.epub"] = nil
        else broken = "/books/a.epub.metadata.lua" end
        find("book:/books/a.epub").callback(); H.eq(#calls, 0); assert(#notices > 0)
    end
end)
H.test("newer progress in the same still-unfinished book is resumed through the native opener", function()
    fixture(); book("/books/a.epub", .4); Tools.show(reader, "ongoing"); drain()
    payloads["/books/a.epub.metadata.lua"].percent_finished = .6
    find("book:/books/a.epub").callback(); H.eq(calls[1][1], "open")
end)
H.test("ask-before-open is retained, cancel is harmless and confirmation closes only once", function()
    fixture(); ask = true; book("/books/a.epub", .2); Tools.show(reader, "ongoing"); drain()
    find("book:/books/a.epub").callback(); local first = top(); H.eq(#calls, 0)
    first.cancel_callback(); UI:close(first); H.eq(#calls, 0)
    find("book:/books/a.epub").callback(); local confirm = top()
    confirm.ok_callback(); UI:close(confirm) -- native ConfirmBox invokes callback BEFORE close
    H.eq(closes[confirm], 1); H.eq(#calls, 1)
end)
H.test("stale and duplicate confirmations cannot open or unlink a replacement", function()
    fixture(); ask = true; book("/books/a.epub", .2); Tools.show(reader, "ongoing"); drain()
    local old_button = find("book:/books/a.epub"); old_button.callback(); local old = top()
    old_button.callback(); H.eq(top(), old)
    Tools.show(reader, "ongoing"); drain(); find("book:/books/a.epub").callback(); local current = top()
    old.ok_callback(); H.eq(#calls, 0); H.eq(top(), current)
    Tools.retire(reader); H.eq(top(), reader); current.ok_callback(); H.eq(#calls, 0)
end)
H.test("close, tabs and replaced native windows retire queued callbacks without affecting their successor", function()
    fixture(); book("/books/a.epub", .2); Tools.show(reader, "ongoing")
    local old = top(); local stale = scheduled[1]
    Tools.show(reader, "ongoing"); local current = top(); UI:close(old); stale()
    H.eq(top(), current); H.eq(reads, 0); drain(); H.eq(#books(), 1)
    find("tools").callback(); H.eq(#queue, 0); H.eq(reads, 1)
end)
H.test("covered preparation pauses in place without raising a new dialog; refresh is explicit", function()
    fixture(); book("/books/a.epub", .2); local w = Tools.show(reader, "ongoing")
    local foreign = {}; UI:show(foreign); tick()
    H.eq(top(), foreign); H.eq(reads, 0); H.eq(#queue, 0)
    assert(find("state_status", w).text:find("paused", 1, true))
    UI:close(foreign); H.eq(top(), w); find("refresh").callback(); drain(); H.eq(#books(), 1)
end)
H.test("suspend, rotation, reflow, navigation and reader close never reopen the old panel", function()
    for _, event in ipairs{ "onSuspend", "onSetRotationMode", "onScreenResize", "onDocumentRerendered",
        "onCloseDocument", "onTeardown", "onShowingReader", "onShowHomescreen" } do
        fixture(); book("/books/a.epub", .2); Tools.show(reader, "ongoing")
        local stale = scheduled[1]; Panel.readerToolsEvent(event, reader); stale()
        H.eq(top(), reader); H.eq(reads, 0); H.eq(#calls, 0)
        Panel.readerToolsEvent("onResume", reader); H.eq(top(), reader); H.eq(#queue, 0)
    end
end)
H.test("foreign modal, generation, settings, document and replaced-reader guards reject stale buttons", function()
    for _, change in ipairs{ "modal", "generation", "settings", "document", "reader" } do
        fixture(); Tools.show(reader); local button = find("toc")
        if change == "modal" then UI:show{}
        elseif change == "generation" then UI._simpleui_navigation_generation = 2
        elseif change == "settings" then reader.doc_settings = {}
        elseif change == "document" then reader.document = { file = "/books/current.epub" }
        else R.instance = {} end
        button.callback(); H.eq(#calls, 0)
    end
end)
H.test("missing history and mid-scan history replacement report an error and support retry", function()
    for _, change in ipairs{ "missing", "replaced", "mutated" } do
        fixture(); for i = 1, 8 do book("/books/b" .. i .. ".epub", .4) end
        Tools.show(reader, "ongoing")
        if change == "missing" then package.loaded.readhistory.hist = nil
        else tick(); if change == "replaced" then package.loaded.readhistory.hist = {} else history[5].time = 999 end end
        drain(); assert(find("state_status").text:find("Could not", 1, true)); H.eq(#calls, 0)
        package.loaded.readhistory.hist = history; find("refresh").callback(); drain(); H.eq(#books(), 8)
    end
end)
H.test("no reader, parked Home, unsafe paths and FileManager never receive a panel", function()
    fixture(); UI:show{ name = "homescreen" }; H.eq(Tools.show(reader), nil)
    UI.stack = {}; H.eq(Tools.show(reader), nil)
    UI.stack = { reader }; reader.document.file = "OPDS://remote"; H.eq(Tools.show(reader), nil)
    H.eq(Tools.show{ document = nil }, nil); H.eq(reads, 0)
end)
H.test("owned labels and long titles are bounded in Swedish and English", function()
    fixture(); language = "sv"; reader.doc_props.display_title = string.rep("漫画", 100)
    Tools.show(reader); assert(top().title:find("Läsarpanel", 1, true)); assert(#top().title < 200)
    H.eq(find("toc").text, "Innehållsförteckning"); H.eq(find("bookmark").text, "Bokmärken")
    H.eq(top().width, 540); language = "en"; Tools.show(reader); H.eq(find("toc").text, "Table of contents")
end)

H.test("optional AI handoff closes the owned panel first, rejects stale providers and isolates failures", function()
    fixture()
    reader.xray = { ui = reader, showFullXRayMenu = function()
        H.eq(top(), reader); calls[#calls + 1] = { "xray" }
    end }
    Tools.show(reader); find("reader_ai").callback(); H.eq(calls[1][1], "xray"); H.eq(reads, 0)
    Tools.show(reader); local stale = find("reader_ai")
    reader.xray = nil; stale.callback(); H.eq(#calls, 1); assert(#notices > 0)
    reader.xray = { ui = reader, showFullXRayMenu = function() error("plugin error") end }
    Tools.show(reader); find("reader_ai").callback(); H.eq(top(), reader); H.eq(#calls, 1)
end)
H.test("Library follows the native close/showFileManager route once and cancels owned pending work", function()
    fixture(); book("/books/a.epub", .2)
    reader.onClose = function(self)
        H.eq(self, reader); H.eq(top(), reader); R.instance = nil; calls[#calls + 1] = { "close-reader" }
    end
    reader.showFileManager = function(self, file)
        H.eq(self, reader); H.eq(file, "/books/current.epub"); H.eq(calls[1][1], "close-reader")
        calls[#calls + 1] = { "native-filemanager", file }
    end
    Tools.show(reader, "ongoing"); local button = find("library")
    button.callback(); H.eq(#calls, 2); drain(); H.eq(reads, 0)
    button.callback(); H.eq(#calls, 2)
end)

local native_dir = os.getenv("ORBITUI_NATIVE_READER_PANEL")
if native_dir then
    local function loadNative(name, overrides)
        local env = setmetatable({}, { __index = _G })
        env.G_defaults = { readSetting = function() return 32 end }
        env.G_reader_settings = G_reader_settings
        env.require = function(module)
            if overrides and overrides[module] then return overrides[module] end
            if module == "gettext" then return setmetatable({ pgettext = function(_ctx, text) return text end }, { __call = function(_, text) return text end }) end
            return package.loaded[module] or (module:match("^ui/widget/") and W) or {}
        end
        env.dofile = function(path) native_loads = native_loads + 1; return assert(payloads[path], path) end
        local f = assert(io.open(native_dir .. "/" .. name .. ".lua")); local source = f:read("*a"); f:close()
        if setfenv then return setfenv(assert(loadstring(source)), env)() end
        return assert(load(source, "@" .. native_dir .. "/" .. name, "t", env))()
    end
    H.test("whole native minimum/current modules expose every allowed reader tool", function()
        fixture()
        for _, pair in ipairs{ { "readertoc", "onShowToc" }, { "readerbookmark", "onShowBookmark" },
            { "readersearch", "onShowFulltextSearchInput" }, { "filemanagerbookinfo", "onShowBookInfo" }, { "readergoto", "onShowGotoDialog" } } do
            H.eq(type(loadNative(pair[1])[pair[2]]), "function")
        end
    end)
    H.test("actual native search, book-info and go-to handlers keep their own UI/state lifecycle", function()
        fixture()
        local bd = { getArrowLabels = function() return "<", ">" end, mirroredUILayout = function() return false end }
        local Search = loadNative("readersearch", { ["ui/bidi"] = bd })
        reader.search = Search:extend{ ui = reader }
        Tools.show(reader); find("search").callback(); assert(top().keyboard)
        UI:close(top())
        local Info = loadNative("filemanagerbookinfo")
        local seen
        reader.bookinfo = Info:extend{ ui = reader, document = reader.document,
            show = function(_, ds, props) seen = { ds, props } end }
        Tools.show(reader); find("bookinfo").callback(); H.eq(seen[1], reader.doc_settings); H.eq(seen[2], reader.doc_props)
        reader.getCurrentPage = function() return 10 end
        reader.document.getPageCount = function() return 100 end
        reader.document.hasHiddenFlows = function() return false end
        local Goto = loadNative("readergoto", { ["ffi/util"] = { template = function(text) return text end } })
        reader.gotopage = Goto:extend{ ui = reader, document = reader.document }
        Tools.show(reader); find("gotopage").callback(); assert(top().keyboard)
    end)
    H.test("native DocSettings discovery/light reader handles doc/central/legacy/custom data without open or repair", function()
        fixture()
        files["/history"] = { mode = "directory" }
        function W:readSetting(name, default) local v = self.data[name]; if v == nil then return default end; return v end
        local Native = loadNative("docsettings", { luasettings = W, datastorage = {
            getHistoryDir = function() return "/history" end, getDocSettingsDir = function() return "/central" end,
            getDocSettingsHashDir = function() return "/hash" end } })
        Native.open = DS.open
        package.loaded.docsettings = Native
        book("/books/a.epub", .3)
        payloads["/books/a.sdr/metadata.epub.lua"] = payloads["/books/a.epub.metadata.lua"]
        files["/books/a.sdr/metadata.epub.lua"] = { mode = "file", size = 100 }
        files["/books/a.sdr/custom_metadata.lua"] = { mode = "file", size = 100 }
        payloads["/books/a.sdr/custom_metadata.lua"] = { custom_props = { title = "Native title" } }
        Tools.show(reader, "ongoing"); drain(); assert(books()[1].text:find("Native title", 1, true))
        H.eq(native_loads, 2); H.eq(#calls, 0); H.eq(files["/books/a.sdr/metadata.epub.lua"].size, 100)
        book("/books/b.epub", .5, "reading", "Central title")
        payloads["/central/books/b.sdr/metadata.epub.lua"] = payloads["/books/b.epub.metadata.lua"]
        files["/central/books/b.sdr/metadata.epub.lua"] = { mode = "file", size = 100 }
        book("/books/c.epub", .6, "reading", "Legacy title")
        local legacy = Native:getHistoryPath("/books/c.epub")
        payloads[legacy] = payloads["/books/c.epub.metadata.lua"]
        files[legacy] = { mode = "file", size = 100 }
        Tools.show(reader, "ongoing"); drain(); H.eq(#books(), 3)
        assert(books()[2].text:find("Central title", 1, true)); assert(books()[3].text:find("Legacy title", 1, true))
        H.eq(native_loads, 6); H.eq(#calls, 0)
    end)
    H.test("whole native ButtonDialog and ConfirmBox keep constructors and callback-before-close ordering", function()
        fixture()
        local groups, button_tables = {}, {}
        local Group = W:extend{ init = function(self) groups[#groups + 1] = self end }
        local ButtonTable = W:extend{ init = function(self) button_tables[#button_tables + 1] = self end }
        local size = setmetatable({}, { __index = function(_, name)
            local category = setmetatable({}, { __index = function() return 4 end }); return category
        end })
        local overrides = { ["ui/font"] = { getFace = function() return {} end }, ["ui/size"] = size,
            ["ui/geometry"] = W, ["ui/gesturerange"] = W,
            ["ffi/blitbuffer"] = { COLOR_WHITE = 1, COLOR_BLACK = 0, COLOR_GRAY = .5 },
            ["ui/widget/buttontable"] = ButtonTable, ["ui/widget/verticalgroup"] = Group }
        local Dialog = loadNative("buttondialog", overrides)
        local Confirm = loadNative("confirmbox", overrides)
        package.loaded["ui/widget/buttondialog"], package.loaded["ui/widget/confirmbox"] = Dialog, Confirm
        ask = true; book("/books/a.epub", .3)
        Tools.show(reader); assert(top().buttontable); assert(top()[1]); H.eq(reads, 0)
        find("ongoing").callback(); drain(); find("book:/books/a.epub").callback()
        local confirm = top(); assert(confirm.text_group); H.eq(#calls, 0)
        local native_ok = button_tables[#button_tables].buttons[1][2]
        native_ok.callback(); H.eq(#calls, 1); H.eq(closes[confirm], 1); H.eq(top(), reader)
        package.loaded["ui/widget/buttondialog"], package.loaded["ui/widget/confirmbox"] = W, W
    end)
end
Tools.retire(reader)
H.finish()
