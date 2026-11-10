local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;" .. root .. "/components/bookshelf/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
package.loaded.logger = { dbg = function() end, warn = function() end }
local Engine = require("lib/bookshelf_sort_engine")
local Sort = require("core/orbitui_shelf_sort")
local Integration = require("adapters/orbitui_ui")
local Adapter = require("adapters/orbitui_shelf_sort")
local alpha = { { key = "author_surname" }, { key = "title" } }
local title_order = { { key = "title" } }
local function book(id, name, author, series, num)
    return { id = id, filepath = "/lib/" .. id .. ".epub", title = name,
        author = author or "Vilhelm Moberg", author_sort = author and nil or "Moberg, Vilhelm",
        series_name = series, series_num = num }
end
local function fixture()
    local root = { path = "/lib" }
    local folder = { label = "Folder Z", path = "/lib/Folder Z" }
    local books = {
        book("z", "Zzz"), book("r", "Rid i natt"),
        book("u4", "Sista brevet till Sverige", nil, "Utvandrarna", 4),
        book("u2", "Invandrarna", nil, "Utvandrarna", 2),
        book("u3", "Nybyggarna", nil, "Utvandrarna", 3),
        book("u1", "Utvandrarna", nil, "Utvandrarna", 1),
    }
    local entries = {}
    for i, b in ipairs(books) do entries[i] = { rec = b, section = i < 3 and root or folder } end
    return entries, books
end
local function ids(entries)
    local out = {}
    for i, b in ipairs(entries) do out[i] = (b.rec or b).id end
    return table.concat(out, ",")
end

H.test("Moberg series interleaves as a block, in volume order", function()
    local entries, books = fixture()
    local result = Sort.folderEntries(entries, alpha)
    H.eq(ids(result), "r,u1,u2,u3,u4,z")
    H.eq(ids(entries), "z,r,u4,u2,u3,u1")
    H.eq(result[2].section, entries[3].section)
    H.eq(result[2].rec, books[6])
    H.eq(books[6].title, "Utvandrarna")
    H.eq(books[6].author_sort, "Moberg, Vilhelm")
    H.eq(books[6]._orbitui_shelf_sort, nil)
    H.eq(alpha[2].key, "title")
end)

H.test("series name, not first volume title or folder name, determines placement", function()
    local entries = fixture()
    entries[6].rec.title, entries[6].rec.title_sort = "A very different first title", "A first title"
    H.eq(ids(Sort.folderEntries(entries, title_order)), "r,u1,u2,u3,u4,z")
    for _, key in ipairs({ "series_name", "series_combined", "series_or_title" }) do
        H.eq(ids(Sort.folderEntries(entries, { { key = "author_surname" }, { key = key } })),
            "r,u1,u2,u3,u4,z")
    end
end)

H.test("reverse changes block order but never reverses volume order", function()
    local entries = fixture()
    H.eq(ids(Sort.folderEntries(entries, { { key = "title", reverse = true } })),
        "z,u1,u2,u3,u4,r")
end)

H.test("author is derived from members, never the series title", function()
    local entries = fixture()
    entries[1].rec.author, entries[1].rec.author_sort = "James Joyce", "Joyce, James"
    entries[2].rec.author, entries[2].rec.author_sort = "Virginia Woolf", "Woolf, Virginia"
    H.eq(ids(Sort.folderEntries(entries, alpha)), "z,u1,u2,u3,u4,r")
end)

H.test("metadata-free folder falls back to first numbered volume title", function()
    local entries = fixture()
    for i = 3, #entries do entries[i].rec.series_name = nil end
    H.eq(ids(Sort.folderEntries(entries, title_order)), "r,u1,u2,u3,u4,z")
end)

H.test("loose series members stay together; decimals and missing indices are deterministic", function()
    local entries = fixture()
    for i = 3, #entries do entries[i].section = entries[1].section end
    entries[4].rec.series_num = 1.5
    entries[3].rec.series_num = nil
    H.eq(ids(Sort.folderEntries(entries, title_order)), "r,u1,u2,u3,u4,z")
    for _ = 1, 3 do
        H.eq(ids(Sort.folderEntries(entries, title_order)), "r,u1,u2,u3,u4,z")
    end
end)

H.test("article settings, curated standalone title and natural ordering use native keys", function()
    local entries = fixture()
    entries[1].rec.title, entries[1].rec.title_sort = "A Book 10", "Book 10"
    entries[2].rec.title = "Book 2"
    for i = 3, #entries do entries[i].rec.series_name = "The Book 3" end
    local old_settings = G_reader_settings
    G_reader_settings = { readSetting = function(_, k)
        if k == "bookshelf_sort_ignore_articles" then return true end
    end }
    -- Compare against the native engine instead of duplicating its setting semantics.
    local expected = { { id = "r", title = "Book 2" },
        { id = "u", title = "The Book 3" }, { id = "z", title = "A Book 10", title_sort = "Book 10" } }
    Engine.sort(expected, title_order)
    local result = Sort.folderEntries(entries, title_order)
    local blocks = {}
    for _, entry in ipairs(result) do
        local id = entry.rec.id:sub(1, 1)
        if id ~= blocks[#blocks] then blocks[#blocks + 1] = id end
    end
    H.eq(table.concat(blocks, ","), ids(expected))
    G_reader_settings = old_settings
end)

H.test("nonalphabetical and empty priorities retain native order unchanged", function()
    local entries = fixture()
    for _, key in ipairs({ "date_added", "last_opened", "filename", "read_status", "collection_order" }) do
        H.eq(Sort.folderEntries(entries, { { key = key }, { key = "title" } }), entries)
        H.eq(Sort.seriesShapes({}, { { key = key } }), nil)
    end
    H.eq(Sort.folderEntries(entries, {}), entries)
    H.eq(Sort.folderEntries(entries, nil), entries)
    H.eq(#Sort.folderEntries({}, alpha), 0)
end)

local function source()
    local f = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_book_repository.lua"))
    local s = f:read("*a"); f:close(); return s
end
local function compile(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then
        local f = assert(loadstring(code)); setfenv(f, env); return f()
    end
    return assert(load(code, "shelf-sort integration", "t", env))()
end
local function folderRepository()
    local entries = fixture()
    local walk, metadata = {}, {}
    for i, entry in ipairs(entries) do
        local rec = entry.rec
        rec.filepath = entry.section.path .. "/" .. rec.id .. ".epub"
        metadata[rec.filepath] = rec
        walk[i] = { fp = rec.filepath, mtime = i, size = i * 10 }
    end
    local repo = { getSortPriority = function() return alpha end }
    local env = {
        Repo = repo, _resolveScopeFilterOpts = function(sp, scope, filter, opts)
            return sp, scope, filter, opts or {}
        end,
        _normalizePath = function(v) return v end, _resolveLibraryRoot = function() return "/lib" end,
        _gettime = os.clock, _scopeRoots = function(scope) return scope and scope.roots end,
        _joinPath = function(a) return a .. "/" end,
        BookshelfSettings = { read = function() return 3 end },
        G_reader_settings = { isTrue = function() return false end },
        cachedWalk = function() return walk end, _getLightMetaCache = function() return metadata end,
        _lightMetaForFp = function(cache, fp) return cache[fp] end,
        _filterIsActive = function(filter) return filter ~= nil end,
        _applyFilter = function(records, filter)
            local out = {}
            for _, rec in ipairs(records) do if rec.id ~= filter.exclude then out[#out + 1] = rec end end
            return out
        end,
        _hydrationStop = function(offset, limit, total, _, _, light)
            H.eq(light, true, "must not hydrate covers")
            return math.min(offset + limit, total)
        end, logger = package.loaded.logger,
    }
    local method = assert(source():match("(function Repo%.getFolderSections.-)\nfunction Repo%.getGenres"))
    local prefetch = assert(source():match("(local function _prefetchSortProgress.-)\nend")) .. "\nend"
    compile(prefetch .. "\n" .. method .. "\nreturn Repo", env)
    Integration.wrap("lib/bookshelf_book_repository", repo)
    return repo, entries
end

H.test("real folder producer reorders before pagination and preserves labels, metadata and scopes", function()
    local repo, entries = folderRepository()
    local all, total = repo.getFolderSections(100, 0, alpha, nil, nil, { light_only = true })
    H.eq(total, 6); H.eq(ids(all), "r,u1,u2,u3,u4,z")
    local paged = {}
    for offset = 0, 4, 2 do
        local page, count = repo.getFolderSections(2, offset, alpha, nil, nil, { light_only = true })
        H.eq(count, total)
        for _, rec in ipairs(page) do paged[#paged + 1] = rec end
    end
    H.eq(ids(paged), ids(all))
    H.eq(all[2].shelf_section, "Folder Z")
    H.eq(all[3].shelf_section_path, "/lib/Folder Z")
    H.eq(all[3].author, "Vilhelm Moberg")
    assert(all[2] ~= entries[6].rec, "hydrate light copies, not shared cache records")
    all[2].read_status = "complete"
    H.eq(entries[6].rec.read_status, nil)
    local filtered, count = repo.getFolderSections(2, 1, alpha, nil, { exclude = "r" }, { light_only = true })
    H.eq(count, 5); H.eq(ids(filtered), "u2,u3")
    local scoped, scoped_total = repo.getFolderSections(100, 0, alpha,
        { roots = { "/lib/Folder Z" } }, nil, { root = "/lib", light_only = true })
    H.eq(scoped_total, 4); H.eq(ids(scoped), "u1,u2,u3,u4")
end)

local function shapes()
    local _, books = fixture()
    return { { series_name = "Utvandrarna", filepaths = { "u1", "u2", "u3", "u4" },
        books_meta = { books[6], books[4], books[5], books[3] } } },
        { book("z", "Zzz"), book("r", "Rid i natt") }
end

H.test("real series readout uses mixed alphabet before paging, without editing cached shapes", function()
    local repo = { spine_light = true }
    Integration.wrap("lib/bookshelf_book_repository", repo)
    local groups, singles = shapes()
    for _, single in ipairs(singles) do single.standalone = true end
    local env = { Repo = repo, _shapeVisible = function() return true end,
        _filterIsActive = function() return false end,
        _groupShapeCmp = function(priority) return Engine.chainedComparator(priority) end,
        _attachFlattenedCounts = function(_, sorted) H.eq(#sorted, 3) end,
        _hydrationStop = function(offset, limit, total) return math.min(offset + limit, total) end,
        hydrateSeriesShape = function(shape)
            return { series_name = shape.series_name, books = shape.books_meta }
        end,
    }
    local method = assert(source():match("(local function _seriesReadout.-)\nfunction Repo%.getSeriesGroups"))
    local readout = compile(method .. "\nreturn _seriesReadout", env)
    for _ = 1, 2 do
        local page, total = readout(groups, singles, { series_membership = "both" }, false, alpha, 1, 1, true)
        H.eq(total, 3); H.eq(page[1].series_name, "Utvandrarna")
        H.eq(page[1]._orbitui_shelf_sort.title, "Utvandrarna")
        H.eq(groups[1].title, nil); H.eq(groups[1]._orbitui_shelf_sort, nil)
    end
    repo.spine_light = nil
    local native = readout(groups, singles, { series_membership = "both" }, false, alpha, 3, 0, true)
    H.eq(native[2].title, "Zzz", "grid/list order stays native")
    H.eq(native[3].series_name, "Utvandrarna")
end)

H.test("letter keys match series blocks but visible book titles remain unchanged", function()
    Integration.wrap("lib/bookshelf_sort_engine", Engine)
    local repo = folderRepository()
    local all = repo.getFolderSections(100, 0, title_order, nil, nil, { light_only = true })
    H.eq(all[3].title, "Invandrarna")
    H.eq(Engine.sortKeyValue(all[3], "title"), "utvandrarna")
    H.eq(Engine.sortKeyValue(all[3], "series_combined"), "utvandrarna")
    H.eq(Engine.sortKeyValue(all[3], "author_surname"), "moberg")
    H.eq(Engine.sortKeyValue({ title = "Invandrarna" }, "title"), "invandrarna")
end)

H.test("bookcase letter scans reuse fixed profile/folder scopes and sorting", function()
    local repo = folderRepository()
    package.loaded["lib/bookshelf_book_repository"] = repo
    local filter = { exclude = "r" }
    package.loaded["lib/bookshelf_tab_model"] = { getById = function()
        return { sort_priority = alpha, filter = filter }
    end }
    package.loaded["lib/bookshelf_profiles"] = { folderSortPriority = function() return alpha end }
    local calls = 0
    local widget = { _jumpScanList = function()
        calls = calls + 1; return "native"
    end }
    Adapter.widget(widget)
    local self = setmetatable({ profile = {}, chip = "fiction", _drilldown_path = {},
        _isSpineMode = function() return true end,
        _profileChip = function() return { path = "/lib" } end,
        _profileScope = function() return { roots = { "/lib" } } end,
    }, { __index = widget })
    local all, key, via = self:_jumpScanList()
    H.eq(ids(all), "r,u1,u2,u3,u4,z"); H.eq(key, "author_surname")
    H.eq(via, "getFolderSections"); H.eq(calls, 0)
    self.profile = nil
    self._drilldown_path = { { kind = "folder", payload = { path = "/lib" } } }
    H.eq(ids(self:_jumpScanList()), "u1,u2,u3,u4,z")
    self._isSpineMode = function() return false end
    H.eq(self:_jumpScanList(), "native"); H.eq(calls, 1)
end)

H.test("unscoped bookcase scans restore native flags on success and error", function()
    local repo = package.loaded["lib/bookshelf_book_repository"]
    repo.spine_light, repo.suppress_covers = nil, false
    local fail = false
    local widget = { _jumpScanList = function()
        H.eq(repo.spine_light, true); H.eq(repo.suppress_covers, true)
        if fail then error("scan failed") end
        return "books", "title", "getBySource"
    end }
    Adapter.widget(widget)
    local self = setmetatable({ _drilldown_path = {}, _isSpineMode = function() return true end },
        { __index = widget })
    local books, key, via = self:_jumpScanList()
    H.eq(books, "books"); H.eq(key, "title"); H.eq(via, "getBySource")
    H.eq(repo.spine_light, nil); H.eq(repo.suppress_covers, false)
    fail = true
    local ok = pcall(self._jumpScanList, self)
    H.eq(ok, false); H.eq(repo.spine_light, nil); H.eq(repo.suppress_covers, false)
end)

H.test("quick bookcase sorting retains the native Moberg series blocks and volume order", function()
    local saved_query = package.loaded["core/orbitui_shelf_query"]
    local _entries, books = fixture()
    package.loaded["core/orbitui_shelf_query"] = { books = function() return books end }
    local result = Adapter.browseBooks({}, { sort = "author" }, false, true)
    H.eq(ids(result), "r,u1,u2,u3,u4,z")
    H.eq(ids(books), "z,r,u4,u2,u3,u1", "native metadata list remains unchanged")
    package.loaded["core/orbitui_shelf_query"] = saved_query
end)

local function countedSorts(fn)
    local native, calls = table.sort, 0
    table.sort = function(...) calls = calls + 1; return native(...) end
    local ok, value = pcall(fn)
    table.sort = native
    assert(ok, value)
    return calls, value
end
local function cacheFixture()
    local groups, singles = shapes()
    for _, single in ipairs(singles) do single.standalone = true end
    local function input() return { groups[1], singles[1], singles[2] } end
    return Sort.seriesOrderCache(), groups, input
end
H.test("prepared series orders avoid all warm sorts and return separately owned keys", function()
    local order, token, input = cacheFixture()
    local cold, keys = countedSorts(function() return order(input(), alpha, token, 1, 1) end)
    assert(cold > 0)
    keys[token[1]].title = "Do not leak"
    local warm, fresh = countedSorts(function() return order(input(), alpha, token, 1, 1) end)
    H.eq(warm, 0); H.eq(fresh[token[1]].title, "Utvandrarna")
    fresh[token[1]].title = "Still owned"
    H.eq(order(input(), alpha, token, 1, 1)[token[1]].title, "Utvandrarna")
    H.eq(token[1].title, nil); H.eq(token[1]._orbitui_shelf_sort, nil)
end)
H.test("scope token, filtered membership and tie order are part of prepared series identity", function()
    local order, token, input = cacheFixture()
    order(input(), alpha, token, 1, 1)
    assert(countedSorts(function() return order(input(), alpha, {}, 1, 1) end) > 0)
    assert(countedSorts(function() return order({token[1]}, alpha, token, 1, 1) end) > 0)
    local reordered = input(); reordered[2], reordered[3] = reordered[3], reordered[2]
    assert(countedSorts(function() return order(reordered, alpha, token, 1, 1) end) > 0)
    H.eq(countedSorts(function() return order(input(), alpha, token, 1, 1) end), 0)
end)
H.test("data generation retires old metadata while unrelated cursor saves retain order", function()
    local order, token, input = cacheFixture()
    order(input(), alpha, token, 1, 1)
    token[1].series_name = "Changed series"
    local calls, keys = countedSorts(function() return order(input(), alpha, token, 2, 1) end)
    assert(calls > 0); H.eq(keys[token[1]].title, "Changed series")
    -- An extra former blanket-settings token must not expire the order:
    -- native Store.generation changes on every saved page/cursor too.
    H.eq(countedSorts(function() return order(input(), alpha, token, 2, 2) end), 0)
    H.eq(countedSorts(function() return order(input(), alpha, token, 2, 2) end), 0)
    local reversed = {{key="title", reverse=true}}
    assert(countedSorts(function() return order(input(), reversed, token, 2, 2) end) > 0)
    local list = input(); order(list, reversed, token, 2, 2)
    H.eq(list[1].id, "z"); H.eq(list[2].id, "r")
end)
H.test("native collation signature changes retire prepared orders even at the same data generation", function()
    local order, token, input = cacheFixture()
    local native, sig = Engine.keySignature, "articles"
    Engine.keySignature = function() return sig end
    order(input(), alpha, token, 1, 1)
    H.eq(countedSorts(function() return order(input(), alpha, token, 1, 1) end), 0)
    sig = "pinyin"
    local calls = countedSorts(function() return order(input(), alpha, token, 1, 1) end)
    Engine.keySignature = native
    assert(calls > 0)
end)
H.test("dynamic sorts and callers without a repository token never use prepared orders", function()
    local order, token, input = cacheFixture()
    for _ = 1, 2 do
        assert(countedSorts(function() return order(input(), alpha, nil, 1, 1) end) > 0)
        assert(countedSorts(function() return order(input(), alpha, token, nil, 1) end) > 0)
        assert(countedSorts(function() return order(input(), {{key="title"},{key="rating"}}, token, 1, 1) end) > 0)
        H.eq(order(input(), {{key="last_opened"}}, token, 1, 1), nil)
    end
end)
H.test("prepared series work is bounded by entries, members and absolute age", function()
    local order, token, input = cacheFixture()
    local tokens = {token, {}, {}, {}, {}}
    for _, id in ipairs(tokens) do order(input(), alpha, id, 1, 1) end
    H.eq(countedSorts(function() return order(input(), alpha, tokens[5], 1, 1) end), 0)
    assert(countedSorts(function() return order(input(), alpha, tokens[1], 1, 1) end) > 0)
    local big = {series_name="Big", books_meta={}}
    for i = 1, 8193 do big.books_meta[i] = {filepath="/large/"..i, title="Volume", series_num=i} end
    for _ = 1, 2 do assert(countedSorts(function() return order({big}, alpha, token, 1, 1) end) > 0) end
    for i = 3001, 8193 do big.books_meta[i] = nil end
    local large_tokens = {{}, {}, {}}
    for _, id in ipairs(large_tokens) do order({big}, alpha, id, 1, 1) end
    assert(countedSorts(function() return order({big}, alpha, large_tokens[1], 1, 1) end) > 0,
        "aggregate member budget, not just a per-entry limit")
    local native, now = os.time, 1000
    os.time = function() return now end
    local ok, err = pcall(function()
        order(input(), alpha, token, 2, 1)
        now = 1029; H.eq(countedSorts(function() return order(input(), alpha, token, 2, 1) end), 0)
        now = 1030; assert(countedSorts(function() return order(input(), alpha, token, 2, 1) end) > 0)
        now = 1; assert(countedSorts(function() return order(input(), alpha, token, 2, 1) end) > 0)
    end)
    os.time = native; assert(ok, err)
end)
H.test("prepared orders do not pin their whole source array or cache failed work", function()
    local order, token, input = cacheFixture()
    local weak = setmetatable({token}, {__mode="v"})
    local list = input()
    order(list, alpha, token, 1, 1)
    token, input = nil, nil
    collectgarbage("collect"); collectgarbage("collect")
    H.eq(weak[1], nil)
    local native, reason = Sort.seriesShapes, {}
    Sort.seriesShapes = function() error(reason) end
    local id = {}
    local ok, err = pcall(order, list, alpha, id, 2, 1)
    Sort.seriesShapes = native
    H.eq(ok, false); H.eq(err, reason)
    assert(countedSorts(function() return order(list, alpha, id, 2, 1) end) > 0)
end)
H.test("large-series fixture sorts once rather than repeating work for every page", function()
    local groups, members = {}, 0
    for s = 1, 235 do
        local group = {series_name="Series "..s, books_meta={}}
        for v = 1, 14 + (s <= 51 and 1 or 0) do
            group.books_meta[#group.books_meta+1] = book(s.."-"..v, "Volume "..v, "Author "..s, group.series_name, v)
            members = members + 1
        end
        groups[#groups+1] = group
    end
    local order = Sort.seriesOrderCache()
    for pass = 1, 3 do
        local list = {}; for i, g in ipairs(groups) do list[i] = g end
        local calls = countedSorts(function() return order(list, title_order, groups, 1, 1) end)
        H.eq(calls, pass == 1 and 236 or 0)
        H.eq(#list, 235); H.eq(members, 3341)
    end
end)

H.test("actual query skips redundant flat sorts but retains bookcase, grouped and foreign-source ownership", function()
    local saved_query, saved_repo, saved_sources = package.loaded["core/orbitui_shelf_query"],
        package.loaded["lib/bookshelf_book_repository"], package.loaded["lib/bookshelf_sources"]
    package.loaded["core/orbitui_shelf_query"] = nil
    local query = require("core/orbitui_shelf_query")
    local producer_sort, cached, foreign, grouped = nil, nil, false, false
    local _, books = fixture()
    query.resolve = function() return {source={kind="library"}, scope={roots={"/lib"}}} end
    package.loaded["lib/bookshelf_sources"] = {get=function() return foreign and {} or nil end}
    package.loaded["lib/bookshelf_book_repository"] = {getBySource=function(_, _, priority, _, _, _, opts)
        H.eq(opts.light_only, true)
        producer_sort = priority
        if grouped then return {{books=books, books_meta=books}} end
        if cached then return cached end
        local list = {}; for i, b in ipairs(books) do list[i] = b end
        if #priority > 0 then Engine.sort(list, priority) end
        cached = list; return list
    end, readProgress=function() return 0, "new" end}
    local first = countedSorts(function() return Adapter.browseBooks({}, {sort="title"}, false, false) end)
    H.eq(first, 1)
    local warm, result = countedSorts(function() return Adapter.browseBooks({}, {sort="title"}, false, false) end)
    H.eq(warm, 0); H.eq(#result, 6)
    local filtered = Adapter.browseBooks({}, {sort="title", filter="unread"}, false, false)
    H.eq(#filtered, 6)
    H.eq(producer_sort[1].key, "title")
    cached = nil
    local block_calls, blocks = countedSorts(function() return Adapter.browseBooks({}, {sort="author"}, false, true) end)
    H.eq(#producer_sort, 0); H.eq(ids(blocks), "r,u1,u2,u3,u4,z"); assert(block_calls > 0)
    foreign, cached = true, nil
    local foreign_calls = countedSorts(function() return Adapter.browseBooks({}, {sort="title"}, false, false) end)
    H.eq(foreign_calls, 2)
    foreign, grouped, cached = false, true, nil
    assert(countedSorts(function() return Adapter.browseBooks({}, {sort="title"}, false, false) end) > 0)
    package.loaded["core/orbitui_shelf_query"], package.loaded["lib/bookshelf_book_repository"],
        package.loaded["lib/bookshelf_sources"] = saved_query, saved_repo, saved_sources
end)
H.test("metadata replacement and lazy date keys still receive their required final sort", function()
    local saved_query, saved_repo = package.loaded["core/orbitui_shelf_query"],
        package.loaded["lib/bookshelf_book_repository"]
    local a = {filepath="/a", title="Z", date_added=100, last_opened=400}
    local b = {filepath="/b", title="A", date_added=200, last_opened=300}
    package.loaded["core/orbitui_shelf_query"] = {books=function()
        return {{filepath="/a"}, {filepath="/b"}}, nil, true
    end}
    package.loaded["lib/bookshelf_book_repository"] = {lightMetaFor=function(fp) return fp == "/a" and a or b end}
    local calls, result = countedSorts(function() return Adapter.browseBooks({}, {sort="title"}, false, false) end)
    H.eq(calls, 1); H.eq(result[1], b)
    H.eq(Adapter.browseBooks({}, {sort="last_opened"}, false, false)[1], a)
    H.eq(Adapter.browseBooks({}, {sort="date_added"}, false, false)[1], b)
    package.loaded["core/orbitui_shelf_query"], package.loaded["lib/bookshelf_book_repository"] = saved_query, saved_repo
end)
H.finish()
