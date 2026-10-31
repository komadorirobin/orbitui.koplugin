local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local queue, shown, live, generation, connected, network_calls = {}, {}, nil, 1, true, 0
local files, maps, requests, details, mode = {}, {}, {}, 0, nil
local UI = { _simpleui_navigation_generation = 1,
    nextTick = function(_, fn) queue[#queue + 1] = fn end,
    show = function(_, w) shown[#shown + 1] = w; w.shown = true end,
    close = function(_, w) w.closed = true; w.shown = false end,
    isWidgetShown = function(_, w) return w and w.shown end,
    setDirty = function() end, forceRePaint = function() end }
package.loaded["ui/uimanager"] = UI
package.loaded.logger = { warn = function() end }
package.loaded["device"] = { screen = { getWidth = function() return 600 end, getHeight = function() return 800 end } }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(file, field)
    if not files[file] then return nil end
    return field == "mode" and "file" or { mode = "file" }
end }
package.loaded.pluginloader = { getPluginInstance = function(_, name) H.eq(name, "bookorbit"); return live end }
package.loaded["bookorbit_state_manager"] = {
    setAccount = function() error("OrbitUI must not change BookOrbit's account") end,
    generation = function() return generation end,
    onDeviceMaps = function() return { byBookId = maps } end }
local deferred_network
package.loaded["ui/network/manager"] = { willRerunWhenConnected = function(_, fn)
    network_calls = network_calls + 1
    if not connected then deferred_network = fn; return true end
    return false
end }
local wrapped = false
package.loaded["ui/trapper"] = { wrap = function(_, fn) wrapped = true; fn(); wrapped = false end }
package.loaded["ui/widget/infomessage"] = H.widget()
local identity = { server_url = "https://example.invalid/api/v1", username = "user", userkey = "not-a-live-secret" }
local client
local function freshClient()
    local c = {}
    for k, v in pairs(identity) do c[k] = v end
    function c:canForkSubprocess() return wrapped end
    function c:catalogBook(id)
        details = details + 1
        if mode == "wrong_detail" then return { id = id + 1, tags = {} } end
        if mode == "bad_tags" then return { id = id, tags = { nested = "tag" } } end
        return { id = id, tags = { "Åland & 日本語", "same", "same" }, genres = { "Not a tag" }, collections = { "Not a tag" } }
    end
    function c:query(path, params) return { path = path, params = params } end
    function c:request(method, query)
        H.eq(method, "GET"); H.eq(query.path, "/koreader/plugin/catalog/tag-matches")
        H.eq(query.params.tag, "Åland & 日本語")
        local ids = {}
        for n in query.params.ids:gmatch("%d+") do ids[#ids + 1] = tonumber(n) end
        assert(#ids > 0 and #ids <= 200)
        requests[#requests + 1] = ids
        if mode == "404" then return nil, 404 end
        if mode == "partial_failure" and #requests == 2 then return nil, 503 end
        if mode == "foreign" then return { bookIds = { 999999 } } end
        if mode == "dictionary" then return { bookIds = { x = 1 } } end
        local found = {}
        for _, id in ipairs(ids) do
            if mode == "all" or id % 7 == 0 then found[#found + 1] = id end
        end
        if mode == "deleted" then for _, id in ipairs(found) do files[maps[id]] = nil end end
        return { bookIds = found }
    end
    function c:runInSubprocess(task, trap)
        assert(wrapped and trap and trap.sui_native)
        if mode == "cancel" then return false end
        local body, err = task()
        return true, { body = body, err = err }
    end
    return c
end
local function reset(count)
    queue, requests, files, maps, details, mode = {}, {}, {}, {}, 0, nil
    connected, deferred_network = true, nil
    for i = 1, count or 1 do maps[i] = "/books/" .. i .. ".epub"; files[maps[i]] = true end
    client = freshClient()
    live = { newClient = function() return freshClient() end, isLoggedIn = function() return true end }
end
local function flush() while #queue > 0 do table.remove(queue, 1)() end end
local Integration = require("adapters/orbitui_integrations")
local Panel = require("adapters/orbitui_book_panel")
local Search = require("core/orbitui_search")
local tag = "Åland & 日本語"
H.test("settings and rendering Tags are passive, with no plugin load or network request", function()
    reset(1)
    local calls = network_calls
    Integration.entries()
    local modal = { _tabs = {{ id = "tags" }}, _active_tab = 1 }
    local extra = Panel.tagSections({}, { filepath = maps[1] }, modal)
    H.eq(extra[1].title, "EPUB tags (offline)"); H.eq(extra[1].pills[1].label, "Read EPUB tags")
    H.eq(extra[2].title, "BookOrbit tags (optional online source)"); H.eq(extra[2].pills[1].label, "Load BookOrbit tags")
    H.eq(network_calls, calls); H.eq(details, 0); H.eq(#requests, 0)
end)
H.test("detail reads only this linked local book's tags, preserving exact names without genre or collection mixing", function()
    reset(2)
    local source = assert(Integration.bookOrbitSession())
    local result = assert(source:detail(maps[1]))
    H.eq(#result.tags, 2); H.eq(result.tags[1], tag); H.eq(result.tags[2], "same")
    H.eq(details, 1); H.eq(#requests, 0)
    local _, err = source:detail("/books/unlinked.epub"); H.eq(err, "not_linked")
end)
H.test("metadata identity and malformed tag arrays fail closed", function()
    reset(1)
    local source = assert(Integration.bookOrbitSession())
    for _, bad in ipairs{ "wrong_detail", "bad_tags" } do
        mode = bad; local result, err = source:detail(maps[1]); H.eq(result, nil); H.eq(err, "invalid")
    end
end)
H.test("all local linked profiles are queried in 200-ID batches without per-book detail calls", function()
    reset(497)
    maps[600] = "/deleted.epub"; maps[601] = "OPDS://remote/book"; maps.nope = "/invalid.epub"
    files[maps[601]], files[maps.nope] = true, true
    local result = assert(assert(Integration.bookOrbitSession()):matches(tag))
    H.eq(#requests, 3); H.eq(#requests[1], 200); H.eq(#requests[2], 200); H.eq(#requests[3], 97)
    H.eq(#result.paths, 71); H.eq(result.truncated, false); H.eq(details, 0)
    H.eq(result.paths[1], "/books/7.epub")
end)
H.test("results are bounded with an honest cap, never an implicit full-library fallback", function()
    reset(800); mode = "all"
    local result = assert(assert(Integration.bookOrbitSession()):matches(tag))
    H.eq(#result.paths, 400); H.eq(result.truncated, true); H.eq(#requests, 3)
    reset(0)
    result = assert(assert(Integration.bookOrbitSession()):matches(tag))
    H.eq(#result.paths, 0); H.eq(#requests, 0)
end)
H.test("a partial API failure, unknown IDs, dictionary responses and old servers are not reported as complete matches", function()
    for _, bad in ipairs{ "partial_failure", "foreign", "dictionary", "404" } do
        reset(400); mode = bad
        local result, err = assert(Integration.bookOrbitSession()):matches(tag)
        H.eq(result, nil); assert(err ~= nil)
    end
end)
H.test("files removed while requests run cannot enter the result list", function()
    reset(30); mode = "deleted"
    local result = assert(assert(Integration.bookOrbitSession()):matches(tag))
    H.eq(#result.paths, 0)
end)
H.test("ambiguous IDs and paths are excluded rather than guessed", function()
    reset(2); mode = "all"
    maps[3] = maps[1]
    maps["2"] = "/books/other.epub"; files[maps["2"]] = true
    local result = assert(assert(Integration.bookOrbitSession()):matches(tag))
    H.eq(#result.paths, 0); H.eq(#requests, 0)
end)
H.test("account, credential, link-generation and plugin changes retire sessions without persisting credentials", function()
    reset(1)
    for _, key in ipairs{ "server_url", "username", "userkey" } do
        local source = assert(Integration.bookOrbitSession())
        local old = identity[key]; identity[key] = old .. "-changed"; H.eq(source:current(), false); identity[key] = old
    end
    local source = assert(Integration.bookOrbitSession())
    generation = generation + 1; H.eq(source:current(), false)
    source = assert(Integration.bookOrbitSession()); live = nil; H.eq(source:current(), false)
    H.eq(Integration.bookOrbitSession(), nil)
    reset(1)
    local manager = package.loaded["bookorbit_state_manager"]
    local setAccount = manager.setAccount; manager.setAccount = nil
    local value, err = Integration.bookOrbitSession(); H.eq(value, nil); H.eq(err, "unsupported")
    manager.setAccount = setAccount
end)
H.test("explicit requests use the native cancelable worker and stale/offline callbacks are inert", function()
    reset(7)
    local active, result, failure = true, nil, nil
    local function current() return active end
    local function done(body, err) result, failure = body, err end
    Integration.bookOrbitRequest(assert(Integration.bookOrbitSession()), function(s) return s:matches(tag) end, current, done)
    H.eq(#requests, 0); flush(); H.eq(#result.paths, 1)
    mode = "cancel"; result, failure = nil, nil
    Integration.bookOrbitRequest(assert(Integration.bookOrbitSession()), function() error("cancelled") end, current, done)
    flush(); H.eq(result, nil); H.eq(failure, "cancelled")
    connected = false; result, failure = nil, nil
    Integration.bookOrbitRequest(assert(Integration.bookOrbitSession()), function() error("retired") end, current, done)
    active = false; assert(deferred_network)(); H.eq(result, nil); H.eq(failure, nil)
    connected, active, mode = true, true, nil
    Integration.bookOrbitRequest(assert(Integration.bookOrbitSession()), function() error("stale") end, current, done)
    generation = generation + 1; flush(); H.eq(failure, "stale")
end)
H.test("Tags loads explicitly, stays in its existing native tab and retires old pill callbacks", function()
    reset(7)
    local closed, opened = 0, 0
    local original = Search.bookOrbitTag
    Search.bookOrbitTag = function(value) H.eq(value, tag); opened = opened + 1 end
    local modal = { _tabs = {{ id = "tags" }}, _active_tab = 1 }
    local section
    function modal:rebuildTab() section = Panel.tagSections({}, { filepath = maps[7] }, self)[2] end
    function modal:onClose() self._dismissed = true; closed = closed + 1 end
    UI:show(modal)
    modal:rebuildTab()
    local old = section.pills[1].on_tap
    old(); H.eq(details, 0); flush(); H.eq(details, 1)
    H.eq(section.pills[1].label, tag); H.eq(#section.pills, 3)
    old(); flush(); H.eq(details, 1)
    local click = section.pills[1].on_tap
    click(); click(); H.eq(closed, 1); H.eq(opened, 1)
    Search.bookOrbitTag = original
end)
local Modal = H.widget()
function Modal:refresh() self.refreshes = (self.refreshes or 0) + 1 end
function Modal:onClose() self.config.on_closed() end
package.loaded["lib/bookshelf_library_modal"] = Modal
local metadata = 0
package.loaded["lib/bookshelf_book_repository"] = { buildBookMeta = function(file, opts)
    H.eq(opts.want_cover, false); metadata = metadata + 1
    return { filepath = file, title = "Book " .. file, author = "Author" }
end }
package.loaded["lib/bookshelf_picker_cell"] = { render = function(record) return record end }
H.test("tag results paginate natively and hydrate only visible local books, with original reader actions", function()
    reset(30)
    local opened, open_record
    local modal = Search.bookOrbitTag(tag, { open_book = function(file, record) opened, open_record = file, record end })
    H.eq(metadata, 0); flush(); H.eq(metadata, 0)
    H.eq(modal.config.grid_cols, 1); H.eq(modal.config.item_count(), 4)
    local book = modal.config.item_at(1)
    H.eq(modal.config.cell_renderer(book, {}).subtitle, "Author"); H.eq(metadata, 1)
    modal.config.on_search_submit("14.epub"); H.eq(modal.config.item_count(), 1)
    book = modal.config.item_at(1)
    modal.config.on_cell_tap(book); H.eq(opened, "/books/14.epub"); H.eq(open_record.filepath, opened)
    modal.config.footer_rows[1][1].on_tap(); flush(); H.eq(#requests, 1)
end)
H.test("closed, replaced, changed-account and removed-file result callbacks cannot navigate", function()
    reset(14)
    local opened = 0
    local modal = Search.bookOrbitTag(tag, { open_book = function() opened = opened + 1 end })
    flush()
    local book = modal.config.item_at(1)
    files[book.filepath] = nil; modal.config.on_cell_tap(book); H.eq(opened, 0)
    generation = generation + 1; H.eq(modal.config.item_count(), 0)
    modal.config.on_cell_tap(book); H.eq(opened, 0)
    modal.config.footer_rows[1][1].on_tap()
    UI._simpleui_navigation_generation = 2
    flush(); H.eq(opened, 0)
end)
H.test("actual native Tags builder retains author/collection/genre/folder sections, focus, zoom and scroll geometry", function()
    reset(1)
    local f = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_widget.lua"))
    local text = f:read("*a"); f:close()
    local factory = assert(text:match("function BookshelfWidget:_showBookDetail%(book, opts%)\n(.-)\nend\n"))
    local primitives = H.widget()
    function primitives:getSize() return { w = self.width or 80, h = self.height or 20 } end
    local headings, pill_sizes, notes = {}, {}, {}
    local text_box = primitives:extend{}
    function text_box:init() notes[#notes + 1] = self.text; assert(self.width > 0) end
    local deps = {
        ["readcollection"] = { default_collection_name = "favorites", getCollectionsWithFile = function() return {} end },
        ["lib/bookshelf_hardcover"] = { isAvailable = function() return false end },
        ["lib/bookshelf_tokens"] = {},
        ["lib/bookshelf_book_highlights"] = { count = function() return 0 end },
        ["lib/bookshelf_reviews_modal"] = { new = function(_, args) return args end },
        ["ui/widget/container/framecontainer"] = primitives,
        ["ui/widget/container/leftcontainer"] = primitives,
        ["ui/widget/horizontalspan"] = primitives,
        ["lib/bookshelf_chip_button"] = { build = function(args) return primitives:new(args) end },
    }
    local env = setmetatable({ UIManager = UI, _ = function(s) return s end, Repo = {},
        require = function(name) return deps[name] or require(name) end,
        Screen = { scaleBySize = function(_, v) return v end },
        Space = { px = function(v) return v end, padding = { small = 2 } },
        Size = { border = { thin = 1 } }, BFont = { getFace = function() return {} end },
        TextWidget = primitives, TextBoxWidget = text_box, Blitbuffer = {},
        VerticalGroup = primitives, HorizontalGroup = primitives, Geom = primitives,
        SnugScroll = primitives:extend{ widen = function(w) return w end },
        BookshelfSettings = { read = function() return nil end }, focusRow = function(rows) return rows end,
    }, { __index = _G })
    local code = "return function(self, book, opts)\n" .. factory .. "\nend"
    local build
    if setfenv then build = setfenv(assert(loadstring(code)), env)()
    else build = assert(load(code, "native Tags factory", "t", env))() end
    local native_pills = { { cat = "author", label = "Author" }, { cat = "folder", label = "Folder" } }
    local bw = { _isRemoteRecord = function() return false end,
        _descriptionArgs = function() return { html_body = "Book" } end,
        _bookReview = function() return nil end,
        _buildPillSpecs = function() return native_pills end,
        _sectionHeadingBar = function(_, title) headings[#headings + 1] = title; return primitives:new{} end,
        _buildPillGroup = function(_, specs, width, _, size)
            assert(width > 0); pill_sizes[#pill_sizes + 1] = size
            return primitives:new{}, { specs }
        end }
    Panel.widget(bw)
    local book = { filepath = maps[1], genre_sources = {} }
    local args = build(bw, book, { active = "tags" })
    local tab = args.tabs[args.active_tab]
    H.eq(tab.id, "tags")
    local modal = { _tabs = args.tabs, _active_tab = args.active_tab, font_size = 18, _side_pad = 20 }
    local body = tab.widget_builder(600, 400, modal)
    H.eq(table.concat(headings, ","), "EPUB tags (offline),BookOrbit tags (optional online source),Author(s),Collections,Genres,Folder")
    H.eq(body.dimen.w, 600); H.eq(body.dimen.h, 400); assert(#body.focus_tables > 0)
    assert(table.concat(notes, " "):find("across all library profiles", 1, true))
    for _, size in ipairs(pill_sizes) do H.eq(size, 18) end
    headings, pill_sizes = {}, {}
    modal.font_size = 28
    body = tab.widget_builder(280, 160, modal)
    H.eq(body.dimen.w, 280); H.eq(body.dimen.h, 160)
    for _, size in ipairs(pill_sizes) do H.eq(size, 28) end
    native_pills = {}
    args = build(bw, book, { active = "tags" })
    H.eq(args.tabs[args.active_tab].id, "tags", "host tags stay accessible without native pills")
    bw.orbitui_tag_sections = nil; headings = {}; native_pills = { { cat = "author", label = "Author" } }
    args = build(bw, book, { active = "tags" })
    args.tabs[args.active_tab].widget_builder(600, 400, modal)
    H.eq(table.concat(headings, ","), "Author(s),Collections,Genres", "standalone has no host section")
end)
H.test("all owned tag labels have Swedish translations without editing user tag names", function()
    local _ = require("core/orbitui_i18n")
    local old = G_reader_settings
    G_reader_settings = { readSetting = function(_, key) return key == "language" and "sv" end }
    H.eq(_("BookOrbit tags"), "BookOrbit-taggar"); H.eq(_("Tags"), "Taggar")
    H.eq(_("Load BookOrbit tags"), "Hämta BookOrbit-taggar"); H.eq(_(tag), tag)
    G_reader_settings = old
end)
H.finish()
