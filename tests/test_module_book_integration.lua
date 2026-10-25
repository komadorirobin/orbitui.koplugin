-- Load both complete modules, not an extracted helper body. Native services
-- and drawing primitives are stubbed; no reader/UI acceptance is implied.
package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
local deps = {}
local function component(path)
    local f = assert(io.open(root .. "/components/bookshelf/" .. path))
    local source = f:read("*a"); f:close()
    local env = setmetatable({ require = function(name)
        return assert(deps[name], "unexpected dependency: " .. name)
    end }, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(source, path)), env)() end
    return assert(load(source, path, "t", env))()
end
for _, name in ipairs({ "lib/bookshelf_gestures", "lib/bookshelf_start_menu_modules",
    "lib/bookshelf_hero_modules_model", "lib/bookshelf_module_grid",
    "lib/bookshelf_module_layout", "lib/bookshelf_fonts",
    "lib/bookshelf_module_breaker", "lib/bookshelf_space" }) do deps[name] = {} end
for _, name in ipairs({ "ui/widget/container/centercontainer", "lib/bookshelf_clip_container",
    "ui/widget/container/framecontainer", "ui/geometry", "ui/gesturerange",
    "ui/widget/container/inputcontainer", "lib/bookshelf_colour_text",
    "lib/bookshelf_grid_container" }) do deps[name] = H.widget() end
deps["ffi/blitbuffer"] = { COLOR_WHITE = {} }
deps.device = { screen = {} }
deps["ui/uimanager"] = {}
deps["lib/bookshelf_i18n"] = { gettext = function(s) return s end }
deps["ffi/util"] = { template = function(s) return s end }
deps["lib/bookshelf_settings_store"] = { nilOrTrue = function() return false end }
deps["lib/bookshelf_spine_widget"] = {}
deps["lib/bookshelf_spine_shelf"] = {}
deps["lib/bookshelf_module_kit"] = { entryConfig = function() return {} end }
local opened, hydrated, shown = {}, 0
deps["apps/reader/readerui"] = { showReader = function(_, fp) opened[#opened + 1] = fp end }
deps["lib/bookshelf_book_repository"] = { buildBook = function(fp)
    hydrated = hydrated + 1; return { filepath = fp, title = "Cached title" }
end }
deps["lib/bookshelf_module_open"] = component("lib/bookshelf_module_open.lua")
local HM = component("lib/bookshelf_hero_modules.lua")

H.test("public module opener retains the live shelf path and deferred fullscreen close", function()
    local calls, closed, after = 0, 0
    local bw = { _micro_fullscreen = { onTapClose = function() closed = closed + 1 end } }
    local book = { filepath = "/books/a.epub", title = "A" }
    function bw:_openBook(rec, callback, opts)
        H.eq(self, bw); H.eq(rec, book); H.eq(opts.no_effect, true)
        calls = calls + 1; after = callback
    end
    local ctx = HM._ctx(bw, function() end, { id = "module-a" })
    H.eq(ctx.surface, "fullscreen")
    ctx.open_book(book)
    H.eq(calls, 1); H.eq(#opened, 0); H.eq(closed, 0)
    after(); H.eq(closed, 1)
end)

H.test("module book menu hydrates bare paths without opening or initializing another shelf", function()
    local bw = { _showBookDetail = function(_, book) shown = book end }
    local ctx = HM.bookHelpers({ bw = bw })
    ctx.show_book("/books/b.epub")
    H.eq(shown.title, "Cached title"); H.eq(hydrated, 1); H.eq(#opened, 0)
    local book = { filepath = "/books/c.epub", title = "C" }
    ctx.show_book(book)
    H.eq(shown, book); H.eq(hydrated, 1)
    ctx.show_book(nil); ctx.open_book({}); H.eq(#opened, 0)
end)

H.test("reader and picker module contexts use the normal ReaderUI fallback exactly once", function()
    local bw = { _reader_context = true,
        _showBookDetail = function() error("must not open a shelf over the reader") end }
    HM.bookHelpers({ bw = bw }).show_book("/books/reader.epub")
    HM.bookHelpers({}).show_book("/books/picker.epub")
    H.eq(#opened, 2); H.eq(opened[1], "/books/reader.epub")
    H.eq(opened[2], "/books/picker.epub")
end)

H.test("an adopted shelf module retains its own surface instead of a covering fullscreen", function()
    local entry = { id = "shelf-module" }
    HM._hosts[entry] = { surface = "shelf", refresh = function() end }
    local ctx = HM._ctx({ _micro_fullscreen = {} }, nil, entry)
    H.eq(ctx.surface, "shelf")
    H.eq(type(ctx.open_book), "function"); H.eq(type(ctx.show_book), "function")
end)
H.finish()
