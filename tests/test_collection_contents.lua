local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;" .. root .. "/components/bookshelf/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Panel = require("adapters/orbitui_book_panel")
local writes, adds, removes, fail, gone = 0, 0, 0, false, false
local RC = { default_collection_name = "favorites", coll = { TBR = { ["/a"] = { file = "/a", text = "A" } },
    Other = { ["/z"] = { file = "/z" } }, favorites = { ["/a"] = { file = "/a" } } },
    coll_settings = { TBR = {}, Other = {}, favorites = {} } }
function RC:addItem(file, name, attr) adds = adds + 1; self.coll[name][file] = { file = file, attr = attr } end
function RC:removeItem(file, name, no_write)
    H.eq(no_write, true); removes = removes + 1; self.coll[name][file] = nil
end
function RC:write(changed)
    H.eq(changed.TBR, true); H.eq(changed.Other, nil)
    if fail then error("disk error") end
    writes = writes + 1
end
package.loaded.readcollection = RC
package.loaded.logger = { warn = function() end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function()
    return not gone and { mode = "file" } or nil
end }
H.test("collection edits are drafts with accurate add/remove counts and undo", function()
    local draft = assert(Panel.collectionDraft("TBR", RC))
    draft:toggle("/a"); draft:toggle("/b")
    H.eq(draft:counts(), 1); H.eq(select(2, draft:counts()), 1)
    H.eq(draft:contains("/a"), false); H.eq(draft:contains("/b"), true)
    H.eq(writes, 0); H.eq(adds, 0); assert(RC.coll.TBR["/a"])
    draft:toggle("/a"); draft:toggle("/b")
    H.eq(next(draft.changes), nil); H.eq(draft:save(), true); H.eq(writes, 0)
end)
H.test("Save affects only requested local membership and preserves concurrent unrelated changes", function()
    local draft = assert(Panel.collectionDraft("TBR", RC))
    draft:toggle("/a"); draft:toggle("/b")
    RC.coll.TBR["/extra"] = { file = "/extra" }
    H.eq(draft:save(), true); H.eq(writes, 1)
    H.eq(RC.coll.TBR["/a"], nil); assert(RC.coll.TBR["/b"]); assert(RC.coll.TBR["/extra"])
    assert(RC.coll.Other["/z"]); assert(RC.coll.favorites["/a"])
end)
H.test("conflicts, deleted collections and missing additions fail before any writes", function()
    local draft = assert(Panel.collectionDraft("TBR", RC)); draft:toggle("/b")
    RC.coll.TBR["/b"] = nil
    H.eq(select(2, draft:save()), "conflict")
    draft = assert(Panel.collectionDraft("TBR", RC)); draft:toggle("/new")
    gone = true; H.eq(select(2, draft:save()), "missing"); gone = false
    local old = RC.coll.TBR; RC.coll.TBR = {}
    H.eq(select(2, draft:save()), "conflict"); RC.coll.TBR = old
    H.eq(writes, 1)
end)
H.test("native write failures restore memory and retain the draft for retry", function()
    local draft = assert(Panel.collectionDraft("TBR", RC)); draft:toggle("/new")
    fail = true; H.eq(select(2, draft:save()), "write"); fail = false
    H.eq(RC.coll.TBR["/new"], nil); H.eq(draft:contains("/new"), true)
    H.eq(draft:save(), true); assert(RC.coll.TBR["/new"])
end)
H.test("favourites and folder-managed collections keep their native owner", function()
    H.eq(Panel.collectionDraft("favorites", RC), nil)
    RC.coll_settings.Other.folders = { ["/folder"] = {} }
    H.eq(Panel.collectionDraft("Other", RC), nil)
    H.eq(Panel.collectionDraft("deleted", RC), nil)
end)
local shown
local UI = { show = function(_, w) w.shown = true; shown = w end, close = function(_, w)
    w.shown = false; if w.config then w.config.on_closed() end
end }
package.loaded["ui/uimanager"] = UI
package.loaded.device = { screen = { getWidth = function() return 600 end, getHeight = function() return 800 end } }
local Modal = H.widget()
function Modal:refresh() self.refreshes = (self.refreshes or 0) + 1 end
function Modal:onClose() UI:close(self) end
package.loaded["lib/bookshelf_library_modal"] = Modal
package.loaded["ui/widget/buttondialog"] = H.widget()
package.loaded["lib/bookshelf_picker_cell"] = { render = function(item) return item end }
local repo = { getBySource = function(source, filter, sort, offset, limit, scope, opts)
    H.eq(source.kind, "collection"); H.eq(opts.light_only, true); H.eq(limit, math.huge)
    return { { filepath = "/new", title = "New", author = "Writer" } }
end, searchBooks = function(q, limit)
    H.eq(limit, nil); return { { filepath = "/found", title = "Found", author = "Author" } }
end, invalidateBookCache = function() end }
package.loaded["lib/bookshelf_book_repository"] = repo
require("core/orbitui_context").refresh = function() end
local notifications = {}
require("core/orbitui_context").notify = function(s) notifications[#notifications + 1] = s end
local function view(config, index)
    config.footer_rows[1][1].on_tap(); shown.buttons[index][1].callback()
end
H.test("native modal supports search, staged changes, sorting and Cancel without writes", function()
    local modal, draft = Panel.collection("TBR")
    local config, before = modal.config, writes
    view(config, 2); config.on_search_submit(nil); config.on_search_submit("Author Found")
    H.eq(config.item_count(), 1); H.eq(config.item_at(1).filepath, "/found")
    config.on_cell_tap(config.item_at(1)); H.eq(draft:contains("/found"), true)
    view(config, 3); H.eq(config.item_count(), 1)
    assert(config.intro:find("1 to add", 1, true))
    config.footer_rows[1][2].on_tap(); assert(config.footer_rows[1][2].label_func():find("Author", 1, true))
    config.footer_rows[2][1].on_tap(); H.eq(writes, before)
    config.footer_rows[2][2].on_tap(); H.eq(writes, before, "retired Save must be inert")
    H.eq(RC.coll.TBR["/found"], nil)
end)
H.test("native modal Save delegates once and refreshes only after success", function()
    local refreshed = 0
    local modal = Panel.collection("TBR", { on_saved = function() refreshed = refreshed + 1 end })
    local config, before = modal.config, writes
    view(config, 2); config.on_search_submit("Found")
    config.on_cell_tap(config.item_at(1))
    config.footer_rows[2][2].on_tap()
    H.eq(writes, before + 1); H.eq(refreshed, 1); H.eq(modal.shown, false)
    assert(RC.coll.TBR["/found"])
end)
H.test("explicit loader seam does not replace the native collection manager", function()
    local native_show = function() end
    local module = require("adapters/orbitui_ui").wrap("lib/bookshelf_collection_manager", { show = native_show })
    H.eq(module.show, native_show); H.eq(type(module.orbitui_edit_contents), "function")
end)
H.test("complete native manager exposes the host entry only in manage mode", function()
    package.loaded["ui/widget/confirmbox"] = H.widget()
    package.loaded["ui/widget/inputdialog"] = H.widget()
    package.loaded["lib/bookshelf_i18n"] = { gettext = require("core/orbitui_i18n") }
    function RC:_read() end
    function RC:getCollectionsWithFile(file)
        local found = {}
        for name, coll in pairs(self.coll) do found[name] = coll[file] ~= nil end
        return found
    end
    local manager = dofile(root .. "/components/bookshelf/lib/bookshelf_collection_manager.lua")
    local edited, callback
    manager.orbitui_edit_contents = function(name, saved) edited, callback = name, saved end
    UI.isWidgetShown = function(_, w) return w.shown == true end
    manager.show{}
    local parent = shown
    parent.config.on_cell_tap("TBR")
    local menu = shown
    H.eq(menu.buttons[1][1].text, "Manage books…")
    menu.buttons[1][1].callback(); H.eq(edited, "TBR")
    callback(); H.eq(parent.refreshes, 1)
    UI:close(parent); callback(); H.eq(parent.refreshes, 1)
    for _i, opts in ipairs({ { book = { filepath = "/found" } }, { bulk = true, paths = { "/found" } } }) do
        manager.show(opts); shown.config.cell_long_tap("TBR")
        H.eq(shown.buttons[1][1].text, "Rename")
    end
    manager.orbitui_edit_contents = nil
    manager.show{}; shown.config.on_cell_tap("TBR")
    H.eq(shown.buttons[1][1].text, "Rename", "standalone manager remains unchanged")
end)
H.test("owned search and collection labels resolve in Swedish and English", function()
    local translate = require("core/orbitui_i18n")
    for _i, text in ipairs({ "Manage books…", "In collection", "Add books", "Changes", "Show books",
            "Sort results", "Relevance", "Recent searches", "Clear search history" }) do
        H.eq(translate(text, "en"), text)
        assert(translate(text, "sv_SE") ~= text, "untranslated: " .. text)
    end
end)
H.finish()
