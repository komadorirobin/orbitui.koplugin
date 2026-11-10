local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local key = "orbitui_reader_pins"
local W = H.widget()
local UI, reader, saved, writes, messages, tasks, images, fs, pending, copied, frees, jumps, native_holds
local file_write_failure, save_failure, source_image, small_screen
local function bb(w, h)
    local image = { w = w, h = h }
    function image:getWidth() return self.w end
    function image:getHeight() return self.h end
    function image:free() assert(not self.freed, "double free"); self.freed = true; frees = frees + 1 end
    function image:copy() assert(not self.freed, "use after free"); copied = copied + 1; return bb(self.w, self.h) end
    function image:writePNG(path)
        if file_write_failure then return false end
        fs[path] = { mode = "file", size = 512 }; images[path] = { self.w, self.h }; return true
    end
    return image
end
function W:getSize()
    return { w = self.width or self.w or (self.dimen and self.dimen.w) or 450,
        h = self.height or self.h or (self.dimen and self.dimen.h) or (self.buttons and #self.buttons * 40) or 20 }
end
function W:free() self.freed = true end
local viewer = W:extend{}
function viewer:onCloseWidget() if self.image then self.image:free(); self.image = nil end end
package.loaded["ui/widget/imageviewer"] = viewer
for _, path in ipairs{
    "ui/widget/container/inputcontainer", "ui/widget/focusmanager", "ui/widget/container/centercontainer", "ui/widget/container/framecontainer",
    "ui/widget/container/rightcontainer", "ui/widget/verticalgroup", "ui/widget/buttontable", "ui/widget/textboxwidget",
    "ui/widget/imagewidget", "ui/widget/buttondialog", "ui/widget/confirmbox", "ui/widget/textviewer", "ui/geometry", "ui/gesturerange",
    "lib/bookshelf_clip_container",
} do package.loaded[path] = W end
package.loaded["ui/font"] = { getFace = function() return {} end }
package.loaded["ffi/blitbuffer"] = { COLOR_WHITE = 255 }
package.loaded["ffi/sha2"] = { sha256 = function(file) return string.rep(file:find("other", 1, true) and "b" or "a", 64) end }
package.loaded["datastorage"] = { getSettingsDir = function() return "/test-settings" end }
package.loaded["libs/libkoreader-lfs"] = {
    symlinkattributes = function(path) return fs[path] end,
    mkdir = function(path) fs[path] = { mode = "directory" }; return true end,
}
package.loaded["ui/renderimage"] = {
    scaleBlitBuffer = function(_, image, w, h, free_orig) assert(not image.freed); H.eq(free_orig, false); return bb(w, h) end,
    renderImageFile = function(_, path, _animated, w, h)
        local size = images[path]; if size then return bb(math.min(w, size[1]), math.min(h, size[2])) end
    end,
}
package.loaded["device"] = { screen = {
    getWidth = function() return 600 end, getHeight = function() return small_screen and 180 or 800 end,
    scaleBySize = function(_, n) return n end,
}, input = { group = { Back = "Back" } } }
package.loaded["core/orbitui_context"] = { notify = function(text) messages[#messages + 1] = text end }
UI = {
    show = function(_, widget) UI.stack[#UI.stack + 1] = widget end,
    close = function(_, widget)
        if widget.onCloseWidget then widget:onCloseWidget() end
        for i = #UI.stack, 1, -1 do if UI.stack[i] == widget then table.remove(UI.stack, i) end end
    end,
    setDirty = function() end,
    isWidgetShown = function(_, widget) for _, w in ipairs(UI.stack) do if w == widget then return true end end; return false end,
    getTopmostVisibleWidget = function() return UI.stack[#UI.stack] end,
    scheduleIn = function(_, delay, fn) assert(delay > 0); tasks[#tasks + 1] = fn end,
    unschedule = function(_, fn) for i = #tasks, 1, -1 do if tasks[i] == fn then table.remove(tasks, i) end end end,
}
package.loaded["ui/uimanager"] = UI
local old_remove = os.remove
os.remove = function(path) assert(path:match("^/test%-settings/orbitui/reader%-pins/[ab]+/slot%d+%.png$")); fs[path] = nil; return true end
local Panel = dofile(root .. "/adapters/orbitui_book_panel.lua")
local P = Panel.readerPins()
local function fixture(paging)
    if reader then P.retire(reader, true) end
    saved = { partial_md5_checksum = "document-digest", pinned_page = "native-pin", bookmarks = { "original" } }
    writes, messages, tasks, images, pending, fs = {}, {}, {}, {}, {}, {}
    copied, frees, jumps, native_holds = 0, 0, {}, 0
    file_write_failure, save_failure, small_screen, source_image = nil, nil, false, nil
    reader = { document = { file = "/books/book.epub" }, highlight = { _highlight_buttons = {} }, view = {} }
    UI.stack = { reader }
    UI._simpleui_navigation_generation = 1
    package.loaded["apps/reader/readerui"] = { instance = reader }
    reader.document.getPageCount = function() return 100 end
    reader.document.getXPointer = function() return "xp:10" end
    reader.document.getPageFromXPointer = function(_, xp) return tonumber(xp:match("^xp:(%d+)")) end
    reader.document.getImageFromPosition = function(_, pos, frames, scalable)
        assert(pos.x == 50 and frames == false and scalable == false)
        return source_image
    end
    reader.getCurrentPage = function() return 10 end
    reader.link = { addCurrentLocationToStack = function() jumps[#jumps + 1] = "back" end }
    reader.rolling = not paging and { onGotoXPointer = function(_, p) jumps[#jumps + 1] = p end } or nil
    reader.paging = paging and { onGotoPage = function(_, p) jumps[#jumps + 1] = p end } or nil
    reader.doc_settings = {
        readSetting = function(_, name) return saved[name] end,
        saveSetting = function(_, name, value)
            if save_failure then error("read only") end
            assert(name == key, "native setting write: " .. name)
            writes[#writes + 1] = name; saved[name] = value
        end,
    }
    reader.highlight.addToHighlightDialog = function(self, name, fn) self._highlight_buttons[name] = fn end
    reader.highlight.removeFromHighlightDialog = function(self, name) self._highlight_buttons[name] = nil end
    reader.highlight.clear = function(self) self.selected_text = nil end
    reader.highlight.onHold = function(_, ...) native_holds = native_holds + 1; return nil, select("#", ...), "native" end
    reader.view.screenToPageTransform = function(_, pos) return pos end
    reader.thumbnail = {
        getPageThumbnail = function(_, page, w, h, batch, callback)
            pending[#pending + 1] = { page = page, batch = batch, callback = callback, w = w, h = h }; return true
        end,
        cancelPageThumbnailRequests = function(_, batch)
            for _, request in ipairs(pending) do if request.batch == batch then request.cancelled = true end end
        end,
    }
    return reader
end
local function top() return UI.stack[#UI.stack] end
local function deliver(request, image)
    request = request or pending[#pending]
    image = image or bb(300, 400)
    request.callback({ bb = image }, request.batch, true)
    return image
end
local function control(window, row, column)
    return window[1][1][1][3].buttons[row][column]
end
H.test("lazy attachment is nonwriting and namespaced; no native pin/bookmark/header hooks", function()
    fixture(); H.eq(Panel.readerPins(), P); P.attach(reader); P.attach(reader)
    H.eq(#writes, 0); H.eq(saved.pinned_page, "native-pin"); H.eq(saved.bookmarks[1], "original")
    H.eq(reader.view.onPaint, nil); H.eq(reader.onClose, nil)
    local n = 0; for _ in pairs(reader.highlight._highlight_buttons) do n = n + 1 end; H.eq(n, 1)
end)
H.test("page pin survives reattachment and suppresses duplicates", function()
    fixture(); assert(P.pin(reader)); assert(not P.pin(reader)); H.eq(#saved[key].entries, 1)
    P.retire(reader, true); assert(P.show(reader)); H.eq(pending[1].page, 10)
    H.eq(#jumps, 0); H.eq(#writes, 1)
end)
H.test("text selection stores xpointer/excerpt without creating a highlight", function()
    fixture(); P.attach(reader)
    reader.highlight.selected_text = { text = "a selected passage", pos0 = "xp:42" }
    local fn = reader.highlight._highlight_buttons.zz_orbitui_pin_reference
    fn(reader.highlight).callback()
    H.eq(saved[key].entries[1].kind, "text"); H.eq(saved[key].entries[1].location, "xp:42")
    local w = P.show(reader); H.eq(w.preview[1].text, "a selected passage"); H.eq(#pending, 0); H.eq(#jumps, 0)
end)
H.test("long UTF8 excerpts are cut at character boundaries", function()
    fixture(); assert(P.pin(reader, string.rep("å", 3000)))
    local text = saved[key].entries[1].text
    H.eq(#text, 4096); H.eq(text:sub(-2), "å")
end)
H.test("current pages in PDF or CBZ use paging without xpointer conversion", function()
    fixture(true); reader.document.file = "/books/volume.cbz"; assert(P.pin(reader))
    H.eq(saved[key].entries[1].location, 10)
    assert(not P.armImage(reader)); P.show(reader); H.eq(#jumps, 0)
    assert(P.jump(reader, 1)); H.eq(jumps[1], "back"); H.eq(jumps[2], 10)
end)
H.test("previews copy native cache buffers and never jump or write", function()
    fixture(); P.pin(reader); local w = P.show(reader)
    local original = deliver(); H.eq(copied, 1); assert(w.bb ~= original)
    H.eq(#jumps, 0); H.eq(#writes, 1)
    UI:close(w); assert(not original.freed); H.eq(frees, 1); H.eq(pending[1].cancelled, true)
end)
H.test("stale thumbnail callbacks after drawer replacement are ignored", function()
    fixture(); P.pin(reader); P.show(reader); local old = pending[1]
    local next_window = P.show(reader); deliver(old); H.eq(copied, 0)
    deliver(pending[2]); assert(next_window.bb); H.eq(copied, 1)
end)
H.test("explicit jump uses native back stack and the stored xpointer", function()
    fixture(); P.pin(reader); P.show(reader); assert(P.jump(reader, 1))
    H.eq(jumps[1], "back"); H.eq(jumps[2], "xp:10"); H.eq(top(), reader)
end)
H.test("reflow resolves xpointer anew, invalid or replaced documents do not jump", function()
    fixture(); P.pin(reader)
    reader.document.getPageFromXPointer = function() return 25 end
    P.show(reader); H.eq(pending[1].page, 25)
    saved.partial_md5_checksum = "changed"; assert(not P.jump(reader, 1)); H.eq(#jumps, 0)
    P.show(reader); assert(top().preview[1].text:find("Preview", 1, true) or top().preview[1].text:find("Förhands", 1, true))
end)
H.test("book engine change and invalid page counts fail closed", function()
    fixture(); P.pin(reader); reader.rolling = nil; reader.paging = {}
    assert(not P.jump(reader, 1)); H.eq(#jumps, 0)
    reader.rolling = {}; reader.document.getPageCount = function() error("closed document") end
    assert(not P.jump(reader, 1)); P.show(reader); H.eq(#pending, 0)
end)
H.test("twelve-entry cap and malformed/future stores do not reset saved data", function()
    fixture()
    for i = 1, 12 do assert(P.pin(reader, nil, "xp:" .. i)) end
    assert(not P.pin(reader, nil, "xp:20")); H.eq(#writes, 12)
    saved[key] = { version = 9, entries = { "precious" } }; local unknown = saved[key]
    P.show(reader); assert(not P.pin(reader)); H.eq(saved[key], unknown); H.eq(#writes, 12)
    saved[key] = { version = 1, next_id = 2, entries = { { id = 1, engine = "rolling", kind = "image",
        location = "xp:1", image_key = "../../escape", slot = 1 } } }
    unknown = saved[key]; P.list(reader); assert(not P.remove(reader, 1)); H.eq(saved[key], unknown)
end)
H.test("read-only settings fail non-destructively", function()
    fixture(); save_failure = true; assert(not P.pin(reader)); H.eq(saved[key], nil)
    save_failure = false; P.pin(reader); local data = saved[key]; save_failure = true
    assert(not P.remove(reader, 1)); H.eq(saved[key], data)
end)
H.test("Remove requires confirmation and refreshes the list immediately", function()
    fixture(); P.pin(reader); local w = P.show(reader)
    control(w, 3, 1).callback(); H.eq(#saved[key].entries, 1)
    local confirm = top(); confirm.ok_callback(); UI:close(confirm)
    H.eq(#saved[key].entries, 0); assert(top().buttons)
    H.eq(saved.pinned_page, "native-pin"); H.eq(saved.bookmarks[1], "original")
end)
H.test("reference paging, native list, Back and outside close stay in the same book", function()
    fixture(); P.pin(reader, nil, "xp:1"); P.pin(reader, nil, "xp:2")
    local w = P.show(reader); control(w, 1, 1).callback(); H.eq(pending[2].page, 1)
    w = top(); control(w, 1, 3).callback(); local list = top()
    list.buttons[1][1].callback(); w = top(); H.eq(pending[3].page, 2)
    w:onOutside(nil, { pos = { x = 1 } }); H.eq(top(), reader); H.eq(#jumps, 0)
    w = P.show(reader); w:onClose(); H.eq(top(), reader); H.eq(pending[#pending].cancelled, true)
end)
H.test("image pin is explicit, one-shot and persists only a bounded local copy", function()
    fixture(); local native = reader.highlight.onHold; P.armImage(reader)
    source_image = bb(1600, 1000)
    assert(reader.highlight:onHold(nil, { pos = { x = 50, y = 30 } }))
    H.eq(reader.highlight.onHold, native); H.eq(native_holds, 0); H.eq(#jumps, 0)
    local entry = saved[key].entries[1]; H.eq(entry.kind, "image"); H.eq(entry.slot, 1)
    local path = "/test-settings/orbitui/reader-pins/" .. string.rep("a", 64) .. "/slot1.png"
    H.eq(images[path][1], 1024); H.eq(images[path][2], 640); assert(source_image.freed)
    local w = P.show(reader); assert(w.bb); H.eq(#pending, 0)
    control(w, 2, 2).callback(); local v = top(); assert(v.image ~= w.bb)
    UI:close(v); assert(not w.bb.freed)
    assert(P.remove(reader, entry.id)); H.eq(fs[path], nil)
end)
H.test("oversized, absent, animated/scalable or unwritable images do not create entries", function()
    for _, problem in ipairs{ "large", "absent", "animated", "scalable", "write" } do
        fixture(); P.armImage(reader)
        source_image = problem == "large" and bb(3000, 3000) or problem == "animated" and {} or problem ~= "absent" and bb(100, 100) or nil
        local released
        if problem == "scalable" then source_image = function(arg) H.eq(arg, false); released = true end end
        file_write_failure = problem == "write"
        reader.highlight:onHold(nil, { pos = { x = 50, y = 30 } })
        H.eq(saved[key], nil); H.eq(#writes, 0)
        if type(source_image) == "function" then assert(released)
        elseif source_image and source_image.free then assert(source_image.freed) end
    end
end)
H.test("image slots never overwrite or adopt existing or symlinked files", function()
    fixture(); local dir = "/test-settings/orbitui/reader-pins/" .. string.rep("a", 64)
    fs[dir .. "/slot1.png"] = { mode = "file", size = 123 }
    fs[dir .. "/slot2.png"] = { mode = "link" }
    P.armImage(reader); source_image = bb(100, 100); reader.highlight:onHold(nil, { pos = { x = 50 } })
    H.eq(saved[key].entries[1].slot, 3); H.eq(fs[dir .. "/slot1.png"].size, 123)
    fixture(); fs["/test-settings/orbitui"] = { mode = "link" }
    P.armImage(reader); source_image = bb(100, 100); reader.highlight:onHold(nil, { pos = { x = 50 } })
    H.eq(saved[key], nil)
end)
H.test("image pin rolls back its new file when settings reject the reference", function()
    fixture(); P.armImage(reader); source_image = bb(100, 100); save_failure = true
    reader.highlight:onHold(nil, { pos = { x = 50 } }); H.eq(saved[key], nil)
    for path, attr in pairs(fs) do assert(attr.mode ~= "file", path) end
end)
H.test("image arm expires and preserves native nil arguments/results", function()
    fixture(); local native = reader.highlight.onHold; P.armImage(reader)
    local wrapper = reader.highlight.onHold; tasks[1](); H.eq(reader.highlight.onHold, native)
    local a, b, c = wrapper(reader.highlight, nil, nil, 5)
    H.eq(a, nil); H.eq(b, 3); H.eq(c, "native")
end)
H.test("later external image/highlight wrappers survive cleanup with ours inert", function()
    fixture(); P.attach(reader); P.armImage(reader)
    local ours = reader.highlight.onHold
    local external = function(this, ...) return ours(this, ...) end
    reader.highlight.onHold = external
    local external_button = function() end
    reader.highlight._highlight_buttons.zz_orbitui_pin_reference = external_button
    P.retire(reader, true); H.eq(reader.highlight.onHold, external)
    H.eq(reader.highlight._highlight_buttons.zz_orbitui_pin_reference, external_button)
    external(reader.highlight, nil, nil); H.eq(native_holds, 1)
end)
H.test("sleep, rotation, reflow and reader close retire callbacks, owned windows and arm", function()
    for _, event in ipairs{ "onSuspend", "onSetRotationMode", "onScreenResize", "onDocumentRerendered", "onCloseDocument", "onTeardown" } do
        fixture(); P.pin(reader); P.show(reader); local request = pending[1]
        Panel.readerPinEvent(event, reader); deliver(request); H.eq(copied, 0); H.eq(top(), reader)
        H.eq(request.cancelled, true)
        if event == "onSuspend" then
            assert(not P.pin(reader)); Panel.readerPinEvent("onResume", reader); H.eq(top(), reader); assert(P.show(reader))
        end
        fixture(); local native = reader.highlight.onHold; P.armImage(reader)
        Panel.readerPinEvent(event, reader); H.eq(reader.highlight.onHold, native)
    end
end)
H.test("closed or replaced reader cannot save, jump or accept a stale control", function()
    fixture(); P.pin(reader); local w = P.show(reader); local request = pending[1]
    package.loaded["apps/reader/readerui"].instance = {}
    control(w, 2, 1).callback(); deliver(request); H.eq(#jumps, 0); H.eq(copied, 0)
    assert(not P.pin(reader)); H.eq(#writes, 1)
end)
H.test("short screens use the native scrolling list, without a clipped drawer", function()
    fixture(); P.pin(reader); small_screen = true; P.show(reader)
    assert(top().buttons); H.eq(#pending, 0)
end)
H.test("navigation generations and parked-reader Home prevent stale work/actions", function()
    fixture(); P.pin(reader); local w = P.show(reader); local request = pending[1]
    UI._simpleui_navigation_generation = 2
    deliver(request); control(w, 2, 1).callback(); H.eq(copied, 0); H.eq(#jumps, 0)
    P.retire(reader); UI:show{ name = "homescreen" }
    assert(not P.pin(reader)); H.eq(#writes, 1)
end)
H.test("snapshot missing or redirected directories never load or remove foreign files", function()
    fixture(); P.armImage(reader); source_image = bb(100, 100)
    reader.highlight:onHold(nil, { pos = { x = 50 } })
    local entry = saved[key].entries[1]
    fs["/test-settings/orbitui/reader-pins"] = { mode = "link" }
    P.show(reader); H.eq(top().bb, nil)
    assert(P.remove(reader, entry.id)) -- removes only the reference, not a symlink target
end)
-- Optional whole native modules: the methods we call are not reconstructed in
-- this test. Rendering, IPC and document engines remain explicit boundaries.
local native_dir = os.getenv("ORBITUI_NATIVE_READER_PINS")
if native_dir then
    local function native(name)
        local env = setmetatable({}, { __index = _G })
        env.G_reader_settings = { readSetting = function(_, _key, default) return default end }
        env.require = function(module)
            if module == "ui/widget/container/inputcontainer" then return W end
            if module == "device" then return { screen = package.loaded.device.screen, isTouchDevice = function() return true end } end
            if module == "gettext" then return setmetatable({ pgettext = function(_, text) return text end }, { __call = function(_, text) return text end }) end
            return package.loaded[module] or {}
        end
        local fn = assert(loadfile(native_dir .. "/" .. name .. ".lua"))
        if setfenv then setfenv(fn, env) else
            local f = assert(io.open(native_dir .. "/" .. name .. ".lua")); local source = f:read("*a"); f:close()
            fn = assert(load(source, "@" .. name, "t", env))
        end
        return fn()
    end
    H.test("native ReaderHighlight extension protocol preserves other buttons", function()
        fixture(); local Highlight = native("readerhighlight")
        reader.highlight.addToHighlightDialog = Highlight.addToHighlightDialog
        reader.highlight.removeFromHighlightDialog = Highlight.removeFromHighlightDialog
        reader.highlight._highlight_buttons.original = function() end
        P.attach(reader); assert(reader.highlight._highlight_buttons.zz_orbitui_pin_reference)
        P.retire(reader, true); assert(reader.highlight._highlight_buttons.original)
        H.eq(reader.highlight._highlight_buttons.zz_orbitui_pin_reference, nil)
    end)
    H.test("native thumbnail cache callback and cancellation protocol is compatible", function()
        fixture(); P.pin(reader)
        local Thumbnail = native("readerthumbnail")
        local image = bb(300, 400)
        reader.thumbnail = Thumbnail:extend{ ui = reader, thumbnails_requests = {},
            setupCache = function() end, tile_cache = { check = function() return { bb = image } end } }
        local window = P.show(reader); assert(window.bb); H.eq(copied, 1)
        UI:close(window); assert(not image.freed)
        reader.thumbnail.tile_cache.check = function() return nil end
        reader.thumbnail._ensureTileGeneration_action = function() end
        P.show(reader); local batch, requests = next(reader.thumbnail.thumbnails_requests); assert(batch and #requests == 1)
        local request = requests[1]; reader.thumbnail.req_in_progress = request
        P.retire(reader); H.eq(request.when_generated_callback, nil)
        H.eq(next(reader.thumbnail.thumbnails_requests), nil)
    end)
    H.test("native container sizing keeps the right-hand drawer inside the screen, including RTL", function()
        fixture(); P.pin(reader)
        local previous, paths, mirrored = {}, {}, false
        paths["ui/widget/widget"] = W
        paths["ui/bidi"] = { mirroredUILayout = function() return mirrored end }
        paths["ui/size"] = { border = { window = 1 }, padding = { default = 8 } }
        for name, value in pairs(paths) do previous[name] = package.loaded[name]; package.loaded[name] = value end
        for _, name in ipairs{ "widgetcontainer", "centercontainer", "framecontainer", "rightcontainer", "verticalgroup" } do
            local path = "ui/widget/" .. (name ~= "verticalgroup" and "container/" or "") .. name
            previous[path] = package.loaded[path]
            package.loaded[path] = native(name)
            paths[path] = package.loaded[path]
        end
        local window = P.show(reader); local right = window[1]; local frame = right[1]
        local size = frame:getSize(); H.eq(size.w, 444); H.eq(size.h, 720)
        local painted
        frame.paintTo = function(_, _bb, x, y) painted = { x, y } end
        right:paintTo({}, 0, 0); H.eq(painted[1], 156); H.eq(painted[2], 40)
        mirrored = true; right:paintTo({}, 0, 0); H.eq(painted[1], 156); H.eq(painted[2], 40)
        P.retire(reader)
        for path in pairs(paths) do package.loaded[path] = previous[path] end
    end)
end
if reader then P.retire(reader, true) end
os.remove = old_remove
H.finish()
