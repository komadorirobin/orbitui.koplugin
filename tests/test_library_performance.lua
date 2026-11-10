local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Host = require("core/orbitui_host")
local function read(path)
    local f = assert(io.open(path, "rb")); local text = f:read("*a"); f:close(); return text
end
local function compile(code, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "library performance", "t", env))()
end
local function fixture()
    local calls, generation = 0, 1
    local repo = {}
    for _, key in ipairs({ "invalidateWalkCache", "invalidateSeriesCache", "invalidateLightMeta",
            "invalidateBookCache", "invalidateCalibreCache", "lightMetaReady", "forgetBook" }) do
        repo[key] = function(...) generation = generation + 1; return nil, select("#", ...), nil end
    end
    Host.shareLightMetadata(repo)
    local rows = { a = { title = "A" }, b = { title = "B" } }
    local function build(fp, info)
        calls = calls + 1
        return { filepath = fp, title = info.title, authors = { "Author" },
            genres = { "Fiction" }, calibre = { custom = { "value" } }, generation = generation }
    end
    return repo, rows, build, function() return calls end
end
H.test("two scopes derive text once but own independent records and nested metadata", function()
    local repo, rows, build, calls = fixture()
    local one = repo.deriveLightRecord("a", rows.a, rows, build)
    local two = repo.deriveLightRecord("a", rows.a, rows, build)
    H.eq(calls(), 1); assert(one ~= two and one.authors ~= two.authors)
    one._status, one.title, one.authors[1], one.calibre.custom[1] = "finished", "changed", "changed", "changed"
    H.eq(two.title, "A"); H.eq(two._status, nil); H.eq(two.authors[1], "Author")
    H.eq(repo.deriveLightRecord("a", rows.a, rows, build).calibre.custom[1], "value")
end)
H.test("all native invalidation routes keep returns and force fresh derivation", function()
    for _, key in ipairs({ "invalidateWalkCache", "invalidateSeriesCache", "invalidateLightMeta",
            "invalidateBookCache", "invalidateCalibreCache", "lightMetaReady", "forgetBook" }) do
        local repo, rows, build, calls = fixture()
        repo.deriveLightRecord("a", rows.a, rows, build)
        local a, b, c = repo[key](nil, "a", nil)
        H.eq(a, nil); H.eq(b, 3); H.eq(c, nil)
        H.eq(repo.deriveLightRecord("a", rows.a, rows, build).generation, 2)
        H.eq(calls(), 2)
    end
end)
H.test("row replacement batch replacement and expiry cannot freeze old text", function()
    local repo, rows, build, calls = fixture()
    local old_time, now = os.time, 100
    os.time = function() return now end
    local ok, err = pcall(function()
        H.eq(repo.deriveLightRecord("a", rows.a, rows, build).title, "A")
        rows.a = { title = "Replaced" }
        H.eq(repo.deriveLightRecord("a", rows.a, rows, build).title, "Replaced")
        local other = { a = rows.a }
        repo.deriveLightRecord("a", other.a, other, build); H.eq(calls(), 3)
        now = 160
        repo.deriveLightRecord("a", other.a, other, build); H.eq(calls(), 4)
    end)
    os.time = old_time; assert(ok, err)
end)
H.test("failed derivation retries and preserves the original error object", function()
    local repo, rows = fixture()
    local reason, calls = {}, 0
    local build = function() calls = calls + 1; if calls == 1 then error(reason) end; return { title = "Recovered" } end
    local ok, err = pcall(repo.deriveLightRecord, "a", rows.a, rows, build)
    H.eq(ok, false); H.eq(err, reason)
    H.eq(repo.deriveLightRecord("a", rows.a, rows, build).title, "Recovered"); H.eq(calls, 2)
end)
H.test("the shared metadata window is bounded at 4096 and installation is idempotent", function()
    local repo, rows, build, calls = fixture()
    local first = repo.deriveLightRecord
    Host.shareLightMetadata(repo); H.eq(repo.deriveLightRecord, first)
    for i = 1, 4097 do repo.deriveLightRecord(tostring(i), rows.a, rows, build) end
    H.eq(calls(), 4097)
    repo.deriveLightRecord("4097", rows.a, rows, build); H.eq(calls(), 4097)
    repo.deriveLightRecord("1", rows.a, rows, build); H.eq(calls(), 4098)
end)

-- Actual repository, native light-map producer and scope guards; only primitive
-- filesystem/BIM/persistence services use the existing component fixture.
local map = dofile(root .. "/core/orbitui_module_map.lua")
for name in pairs(map) do
    if not package.loaded[name] then package.preload[name] = function() return H.componentModule(root, name) end end
end
local source_fixture = read("components/bookshelf/tests/_test_lightmeta_lazy.lua")
local prefix = assert(source_fixture:match("^(.-)local Repo = dofile"))
local f = compile(prefix .. "\nreturn { books = BOOKS, derivations = function() return derivations end }", {
    dofile = function(path)
        if path == "tests/_helpers.lua" then return dofile("components/bookshelf/tests/_helpers.lua") end
        return dofile(path)
    end,
})
G_reader_settings.readSetting = function(_, key) if key == "home_dir" then return "/" end end
local repo = H.componentModule(root, "lib/bookshelf_book_repository")
Host.shareLightMetadata(repo)
H.test("real scoped shelf and global series-box lookup reuse derivation without widening scope", function()
    local out, total = repo.getFolderSections(100, 0, { { key = "title" } },
        { roots = { "/home" } }, nil, { light_only = true })
    H.eq(total, #f.books); H.eq(#out, #f.books)
    local before = f.derivations()
    for i, fp in ipairs(f.books) do
        local book = assert(repo.lightMetaFor(fp))
        H.eq(book.title, "Book " .. i); assert(book ~= out[i])
    end
    H.eq(f.derivations(), before, "series boxes must not re-probe every sidecar")
    H.eq(total, 40)
    repo.invalidateLightMeta()
    assert(repo.lightMetaFor(f.books[1])); H.eq(f.derivations(), before + 1)
end)

H.test("full native flat producer sorts once cold and not again on warm browse pages", function()
    local Query = require("core/orbitui_shelf_query")
    local Adapter = require("adapters/orbitui_shelf_sort")
    local Engine = require("lib/bookshelf_sort_engine")
    local old_resolve, old_repo, native_sort = Query.resolve,
        package.loaded["lib/bookshelf_book_repository"], Engine.sort
    local calls, scope = 0, { roots = { "/home" } }
    Query.resolve = function() return {source={kind="library"}, scope=scope} end
    package.loaded["lib/bookshelf_book_repository"] = repo
    Engine.sort = function(...) calls = calls + 1; return native_sort(...) end
    repo.invalidateBookCache("sort performance fixture")
    local cold = Adapter.browseBooks({}, {sort="title"}, false, false)
    H.eq(calls, 1); H.eq(#cold, 40)
    calls = 0
    local warm = Adapter.browseBooks({}, {sort="title"}, false, false)
    H.eq(calls, 0); H.eq(#warm, #cold)
    for i, b in ipairs(warm) do H.eq(b.filepath, cold[i].filepath); H.eq(b.cover_bb, nil) end
    scope = {roots={"/not-this-library"}}
    H.eq(#Adapter.browseBooks({}, {sort="title"}, false, false), 0)
    scope = {roots={"/home"}}
    calls = 0
    Adapter.browseBooks({}, {sort="author"}, false, true)
    H.eq(calls, 0, "bookcase owns the one block sort; producer must not sort flat books first")
    local native_progress = repo.readProgress
    repo.readProgress = function(fp) return fp == f.books[1] and .5 or 0, "reading" end
    local filtered = Adapter.browseBooks({}, {sort="title", filter="reading"}, false, false)
    H.eq(#filtered, 1); H.eq(filtered[1].filepath, f.books[1])
    repo.readProgress = function() return 1, "complete" end
    repo.invalidateProgressCache()
    H.eq(#Adapter.browseBooks({}, {sort="title", filter="reading"}, false, false), 0)
    repo.readProgress, Query.resolve, Engine.sort = native_progress, old_resolve, native_sort
    package.loaded["lib/bookshelf_book_repository"] = old_repo
end)

H.test("full native series pages reuse order and retire it on progress, metadata and group invalidation", function()
    local Adapter = require("adapters/orbitui_shelf_sort")
    local native_derive, native_sort, native_spine = repo.deriveLightRecord, table.sort, repo.spine_light
    local name, calls = "Series A", 0
    repo.deriveLightRecord = function(fp, info, rows, build)
        local b = native_derive(fp, info, rows, build)
        local n = tonumber(fp:match("b(%d+)"))
        b.series_name, b.series_num = n <= 20 and name or "Series Z", n
        return b
    end
    Adapter.repository(repo)
    repo.spine_light = true
    repo.invalidateWalkCache()
    local priority, scope = {{key="title"}}, {roots={"/home"}}
    table.sort = function(...) calls = calls + 1; return native_sort(...) end
    local ok, err = pcall(function()
        local first, total = repo.getSeriesGroups(1, 0, priority, scope, nil, {light_only=true})
        assert(calls > 0); H.eq(total, 2); H.eq(first[1].series_name, "Series A")
        first[1]._orbitui_shelf_sort.title = "Caller mutation"
        calls = 0
        local second = repo.getSeriesGroups(1, 1, priority, scope, nil, {light_only=true})
        H.eq(calls, 0); H.eq(second[1].series_name, "Series Z")
        first = repo.getSeriesGroups(1, 0, priority, scope, nil, {light_only=true})
        H.eq(calls, 0); H.eq(first[1]._orbitui_shelf_sort.title, "Series A")
        repo.invalidateProgressCache(f.books[1]); calls = 0
        repo.getSeriesGroups(1, 0, priority, scope, nil, {light_only=true})
        assert(calls > 0, "same shape token but new data generation must retire keys")
        repo.invalidateSeriesCache(); calls = 0
        repo.getSeriesGroups(1, 0, priority, scope, nil, {light_only=true})
        assert(calls > 0, "new native shape identity must not hit an old order")
        name = "Series B"; repo.invalidateLightMeta(); repo.invalidateSeriesCache(); calls = 0
        first = repo.getSeriesGroups(1, 0, priority, scope, nil, {light_only=true})
        assert(calls > 0); H.eq(first[1]._orbitui_shelf_sort.title, "Series B")
        local outside, outside_total = repo.getSeriesGroups(1, 0, priority,
            {roots={"/not-this-library"}}, nil, {light_only=true})
        H.eq(#outside, 0); H.eq(outside_total, 0)
    end)
    table.sort, repo.deriveLightRecord, repo.spine_light = native_sort, native_derive, native_spine
    repo.invalidateWalkCache()
    assert(ok, err)
end)

-- Actual label-counterfactual method and native protected pin. No replacement
-- renderer or geometry approximation is used by the optimization.
local widget_source = read(root .. "/components/bookshelf/lib/bookshelf_widget.lua")
local pin = assert(widget_source:match("local _covers_pin = 0\n(.-)\n%-%- _itemFilepath"))
local body = assert(widget_source:match("function BookshelfWidget:_ensureGridLabels%(%)\n(.-)\nend\n"))
local env = { Repo = {}, require = function(name)
    if name == "lib/bookshelf_tab_model" then return { getById = function() end } end
    error(name)
end }
local ensure = compile("local _covers_pin = 0\n" .. pin .. "\nreturn function(self)\n" .. body .. "\nend", env)
H.test("the layout probe requests only text and restores cursor and flags even after a failed fetch", function()
    for _, failure in ipairs({ false, true }) do
        env.Repo.suppress_covers, env.Repo.spine_light = "prior-cover", "prior-light"
        local w = { _cursor = 23, _gridLabelsKey = function() return "fixture" end,
            _fetchChipItems = function(self)
                H.eq(self._cursor, 1); H.eq(env.Repo.suppress_covers, true); H.eq(env.Repo.spine_light, true)
                if failure then error("temporary metadata fault") end
                return { { kind = "folder", label = "Manga" } }, 40
            end,
            _noteGridLabels = function(_, items, windowed)
                H.eq(items[1].label, "Manga"); H.eq(windowed, true)
            end }
        ensure(w)
        H.eq(w._cursor, 23); H.eq(env.Repo.suppress_covers, "prior-cover"); H.eq(env.Repo.spine_light, "prior-light")
    end
end)
H.test("device-reviewed Bookshelf menu labels support Swedish and unchanged English", function()
    local translate = require("core/orbitui_i18n")
    for english, swedish in pairs({ ["Close Bookshelf"] = "Stäng Bookshelf",
            ["Edit shelves…"] = "Redigera hyllor…", ["Hardcover enrichment"] = "Metadata från Hardcover" }) do
        H.eq(translate(english, "sv"), swedish); H.eq(translate(english, "en"), english)
    end
end)
H.finish()
