package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_libraries")
local original = dofile("components/bookshelf/lib/bookshelf_profiles.lua")
local legacy = original.list()
local function make(present, home, data)
    data = data or {}
    local writes = 0
    local store = { read = function(k) return data[k] end,
        save = function(k, v) writes = writes + 1; data[k] = v end,
        flush = function() end, wasPresent = function() return present end }
    return Model.new(store, legacy, home), data, store, function() return writes end
end

H.test("migration is additive, durable and keeps all profile and chip identities", function()
    local api, saved, _, writes = make(true, "/different", { profile_shelf_prose_authors = { theme = "mine" },
        active_chip_comics = "next", profile_folder_sort_prose = { { key = "title" } } })
    local sections = api.list()
    H.eq(#sections, 2); H.eq(sections[1].key, "prose"); H.eq(sections[2].key, "comics")
    H.eq(sections[1].chips[1].key, "profile_fiction")
    H.eq(sections[1].chips[1].source.id, legacy[1].roots[1])
    H.eq(sections[2].chips[1].group_folder_name, "Oneshots")
    H.eq(saved.profile_shelf_prose_authors.theme, "mine"); H.eq(saved.active_chip_comics, "next")
    H.eq(saved.profile_folder_sort_prose[1].key, "title")
    api.list(); H.eq(writes(), 1)
    local restarted = make(false, "/other", saved)
    H.eq(restarted.get("prose").roots[1], sections[1].roots[1])
    H.eq(legacy[1].chips[1].source, nil, "migration must not mutate the component seed")
end)

H.test("clean installs use only the chosen home folder and need no external integration", function()
    local api = make(false, "/media/books/")
    H.eq(#api.list(), 1); H.eq(api.get("library").roots[1], "/media/books")
    H.eq(api.get("comics"), nil); H.eq(api.get("prose"), nil)
    for _, chip in ipairs(api.get("library").chips) do assert(chip.kind ~= "bookorbit_want") end
    local empty = make(false)
    H.eq(#empty.list(), 0); H.eq(empty.matchFile("/book.epub"), nil)
end)

H.test("renames and root relocation preserve IDs and saved style references", function()
    local api = make(true)
    api.edit("prose", function(s) s.label = "Novels" end)
    local root = legacy[1].roots[1]
    api.edit("prose", function(s)
        s.chips[#s.chips + 1] = { key = "sub", label = "Sub", source = { kind = "folder", id = root .. "/Sub" } }
    end)
    api.relocateRoot("prose", root, "/mnt/books")
    local section = api.get("prose")
    H.eq(section.label, "Novels"); H.eq(section.chips[1].key, "profile_fiction")
    H.eq(section.chips[1].path, "/mnt/books"); H.eq(section.chips[#section.chips].path, "/mnt/books/Sub")
    H.eq(api.matchFile(root .. "/book.epub"), nil)
    H.eq(api.matchFile("/mnt/books/book.epub"), "prose")
    H.eq(section.roots[2], legacy[1].roots[2])
end)

H.test("matching is boundary-safe, deterministic, and prefers the most specific root", function()
    local api = make(false, "/books")
    local nested = api.add("Nested", "/books/manga")
    H.eq(api.matchFile("/books/manga/a.cbz"), nested)
    H.eq(api.matchFile("/books/manga-extra/a.epub"), "library")
    H.eq(api.matchFile("/books-other/a.epub"), nil)
    H.eq(api.matchFile("/books/../private/a.epub"), nil)
    H.eq(Model.contains("/books/a.epub", "/"), true)
    local same = api.add("Same", "/books/manga")
    H.eq(api.matchFile("/books/manga/a.cbz"), nested)
    api.edit(nested, function(s) s.enabled = false end)
    H.eq(api.matchFile("/books/manga/a.cbz"), same)
end)

H.test("disabled sections retain their identities and new sections never reuse them", function()
    local api = make(false)
    local a = api.add("A", "/a")
    api.edit(a, function(s) s.enabled = false end)
    H.eq(api.get(a), nil); H.eq(api.get(a, true).label, "A"); H.eq(#api.list(), 0)
    local b = api.add("B", "/b")
    assert(a ~= b)
    api.edit(a, function(s) s.enabled = true end)
    H.eq(#api.list(), 2)
end)

H.test("invalid or future configuration fails closed without replacing saved data", function()
    local api, data, _, writes = make(false, nil, { [Model.key] = { version = 99, sections = {} } })
    H.eq(pcall(api.list), false); H.eq(data[Model.key].version, 99); H.eq(writes(), 0)
    api, data = make(false, "/books")
    local config = Model.copy(api.config())
    config.sections[1].chips[1].source.id = "/private"
    H.eq(pcall(api.save, config), false)
    H.eq(api.get("library").chips[1].path, "/books")
    config = Model.copy(api.config()); config.sections[2] = Model.copy(config.sections[1])
    H.eq(pcall(api.save, config), false)
    H.eq(Model.path("relative/path"), nil); H.eq(Model.path("/a/../b"), nil)
end)

local api, saved, store = make(true, nil, { active_chip_prose = "profile_fiction" })
package.loaded["lib/bookshelf_settings_store"] = store
local P = dofile("components/bookshelf/lib/bookshelf_profiles.lua")
package.loaded["lib/bookshelf_profiles"] = P
local Adapter = require("adapters/orbitui_libraries")
Adapter.profiles(P)
H.test("runtime profile wrapper keeps style keys and reader-return locations", function()
    local key = P.add("Poetry", "/sd/books/poetry")
    local loc = P.locationForFile("/sd/books/poetry/Sub/book.epub")
    H.eq(loc.profile_key, key); H.eq(loc.chip_key, "books"); H.eq(loc.folder, "/sd/books/poetry/Sub")
    P.saveShelfSettings(P.get(key), "books", { theme = "paper", spine_cover_size_pct = 125, series_boxes = true })
    P.edit(key, function(s) s.label = "Renamed" end)
    H.eq(P.shelfSettings(P.get(key), "books").theme, "paper")
    H.eq(P.shelfSettings(P.get(key), "books").spine_cover_size_pct, 125)
    H.eq(P.shelfSettings(P.get(key), "books").series_boxes, true)
    local other = P.add("Essays", "/sd/books/essays")
    P.saveShelfSettings(P.get(other), "books", { series_boxes = false })
    H.eq(P.shelfSettings(P.get(other), "books").series_boxes, false)
    H.eq(P.shelfSettings(P.get(key), "books").series_boxes, true)
end)

H.test("search and Home references resolve added sections and fail closed when disabled", function()
    local key = P.add("Local comics", "/mnt/comics")
    local Query = require("core/orbitui_shelf_query")
    local Search = require("core/orbitui_search")
    local ref = { profile = key, chip = "books" }
    H.eq(Query.resolve(ref).source.id, "/mnt/comics")
    local scopes = Search.scopes(ref)
    H.eq(scopes[#scopes - 1].id, key); H.eq(scopes[#scopes - 1].text, "Local comics")
    P.edit(key, function(s) s.enabled = false end)
    H.eq(select(2, Query.resolve(ref)), "missing")
    package.loaded["lib/bookshelf_book_repository"] = {}
    H.eq(select(3, Search.search("book", key)), "missing")
end)

H.test("navigation registers arbitrary sections while retaining old action IDs", function()
    local Config = { ALL_ACTIONS = {}, ACTION_BY_ID = {} }
    package.loaded["infra/sui_config"] = Config
    local registered, calls = {}, {}
    local QA = { register = function(desc) registered[desc.id] = desc end,
        openBookshelfProfile = function(key, ctx, menu) calls = { key, ctx, menu } end }
    local key = P.add("Audio", "/audio")
    Adapter.actions(QA)
    local id = Adapter.actionId(key)
    registered[id].execute({ test = true }); H.eq(calls[1], key); H.eq(calls[2].test, true)
    registered[id].hold_execute({}); H.eq(calls[3], true)
    H.eq(Adapter.actionId("prose"), "bookshelf_prose")
    assert(registered.bookshelf_comics)
    P.edit(key, function(s) s.label = "Spoken books" end); Adapter.actions(QA)
    H.eq(Config.ACTION_BY_ID[id].label, "Spoken books")
    local bridge = { profileForNavigation = function(id) if id == "old" then return "prose" end end,
        resolveProfileTab = function(_, tabs) return tabs[1] == "old" and "old" end }
    Adapter.bridge(bridge)
    H.eq(bridge.profileForNavigation(id), key)
    H.eq(bridge.resolveProfileTab(key, { "homescreen", id }), id)
    H.eq(bridge.profileForNavigation("old"), "prose")
end)

H.finish()
