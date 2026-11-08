local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_dashboard")
local Integration = require("adapters/orbitui_integrations")
local Rows
local saved, tasks, calls, stats, writes, maps_calls, generation, now, online, fork, during, reply, mapping, p
local CACHE = "simpleui_orbitui_bookorbit_rows_cache"
local real_time = os.time
os.time = function(t) return t and real_time(t) or now end
package.loaded["infra/sui_store"] = { readSetting = function(_, k) return saved[k] end,
    saveSetting = function(_, k, v) saved[k] = v; writes = writes + 1 end }
package.loaded["ffi/sha2"] = { sha256 = function(s)
    return s:find("other", 1, true) and string.rep("b", 64) or string.rep("a", 64)
end }
package.loaded["core/orbitui_context"] = { plugin = function(name) H.eq(name, "bookorbit"); return p end,
    refresh = function() end, notify = function() end }
package.loaded["ui/uimanager"] = { scheduleIn = function(_, _, fn) tasks[#tasks + 1] = fn end }
package.loaded["ui/trapper"] = { wrap = function(_, fn) fn() end }
package.loaded["ui/network/manager"] = { isConnected = function() return online end }
package.loaded["device"] = {}
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path)
    stats = stats + 1
    if path == "/one.epub" or path == "/two.cbz" then return "file" end
end }
package.loaded["bookorbit_state_manager"] = { generation = function() return generation end,
    computeOnDeviceMaps = function() maps_calls = maps_calls + 1; return { generation = generation, bookEntries = mapping } end }
package.loaded.logger = { warn = function() end }
local source = { account = string.rep("a", 64), section = "collections", id = 7, title = "Favorites" }
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end
local function reset()
    now, generation, online, fork, during = real_time(), 1, true, true, nil
    saved, tasks, calls, stats, writes, maps_calls = { foreign_sync = true }, {}, {}, 0, 0, 0
    mapping = { { id = 1, file = "/one.epub" }, { id = 2, file = "/two.cbz" },
        { id = 3, file = "/deleted.epub" } }
    reply = function(kind, section, query)
        if kind == "section" then return { items = {{ id = 7, title = "Favorites" }} } end
        H.eq(query.collectionId, 7); H.eq(query.smartScopeId, nil); H.eq(query.sort, "title")
        return { items = {{ id = 2 }, { id = 1 }, { id = 3 }, { id = 90 }}, total = 4, hasNext = false }
    end
    local client = {
        canForkSubprocess = function() return fork end,
        runInSubprocess = function(_, fn)
            local body, err = fn()
            if during then local f = during; during = nil; f() end
            return true, { body = body, err = err }
        end,
        catalogSection = function(_, section, query)
            calls[#calls + 1] = { "section", section, query }; return reply("section", section, query)
        end,
        catalogBooks = function(_, query)
            calls[#calls + 1] = { "books", query }; return reply("books", nil, query)
        end,
    }
    p = { settings = { server_url = "https://example.invalid", username = "reader", userkey = "test-only" },
        newClient = function() return client end }
    package.loaded["device"].screen_saver_mode = false
    package.loaded["adapters/orbitui_bookorbit_rows"] = nil
    Rows = require("adapters/orbitui_bookorbit_rows")
end
local function drain()
    local n = 0
    while #tasks > 0 do n = n + 1; assert(n < 100); table.remove(tasks, 1)() end
end
local function refresh(s, options)
    local result
    options = options or {}; options.force = true
    options.on_done = function(value) result = value end
    Rows.refresh(s, options); drain(); return assert(result)
end
local function seed()
    saved[CACHE] = { version = 1, account = source.account, catalog = { copy(source) }, catalog_at = now,
        rows = { ["collections:7"] = { files = { "/one.epub" }, at = now, total = 9 } } }
end
H.test("inspection and cached Home snapshot do no HTTP, map scan, filesystem sweep or writes", function()
    reset(); seed()
    H.eq(Rows.catalog()[1].title, "Favorites")
    H.eq(Rows.snapshot(source).files[1], "/one.epub")
    H.eq(#calls, 0); H.eq(#tasks, 0); H.eq(maps_calls, 0); H.eq(stats, 0); H.eq(writes, 0)
    H.eq(refresh(source).ok, true)
    H.eq(saved.foreign_sync, true); H.eq(maps_calls, 1)
end)
H.test("server evaluates source membership; only exact existing local links survive in server order", function()
    reset()
    H.eq(#Rows.snapshot(source).files, 0)
    local result
    Rows.refresh(source, { source_required = true, on_done = function(r) result = r end })
    H.eq(#calls, 0); H.eq(writes, 0); H.eq(result, nil)
    drain(); assert(result.ok)
    local snapshot = Rows.snapshot(source)
    H.eq(#snapshot.files, 2); H.eq(snapshot.files[1], "/two.cbz"); H.eq(snapshot.files[2], "/one.epub")
    H.eq(snapshot.total, 4); H.eq(snapshot.at, now)
    H.eq(#calls, 2); H.eq(calls[1][2], "collections")
end)
H.test("multiple cards coalesce a source refresh, throttle automatic work and keep manual refresh available", function()
    reset(); local notifications = 0
    local opts = { on_done = function(r) assert(r.ok); notifications = notifications + 1 end }
    assert(Rows.refresh(source, opts)); assert(Rows.refresh(source, opts)); drain()
    H.eq(notifications, 2); H.eq(#calls, 2)
    local ok, err = Rows.refresh(source); H.eq(ok, false); H.eq(err, "fresh")
    H.eq(#calls, 2); now = now + Rows.ttl
    assert(Rows.refresh(source)); drain(); H.eq(#calls, 4)
    H.eq(refresh(source).ok, true); H.eq(#calls, 6)
end)
H.test("fresh source discovery never delays the first card refresh and failed automatic work stays explainable", function()
    reset(); seed(); saved[CACHE].rows = {}
    assert(Rows.refresh(source)); drain(); H.eq(#Rows.snapshot(source).files,2)
    now=now+Rows.ttl; online=false
    assert(Rows.refresh(source)); drain()
    H.eq(Rows.snapshot(source).error,"offline"); H.eq(#Rows.snapshot(source).files,2)
    local ok,why=Rows.refresh(source); H.eq(ok,false); H.eq(why,"recent_attempt")
    online=true; assert(refresh(source).ok); H.eq(Rows.snapshot(source).error,nil)
end)
H.test("source discovery pages each category independently and carries IDs, not executable rules", function()
    reset()
    reply = function(kind, section, q)
        H.eq(kind, "section")
        return { items = {{ id = q.page, title = section .. q.page, rules = { malicious = true } }},
            total = 2, hasNext = q.page == 1 }
    end
    assert(refresh(nil).ok)
    local sources = Rows.catalog(); H.eq(#sources, 6); H.eq(#calls, 6)
    H.eq(sources[3].section, "collections"); H.eq(sources[5].section, "smart-scopes")
    H.eq(sources[1].rules, nil); H.eq(maps_calls, 0)
end)
H.test("smartscope, shelf and library queries cannot accidentally broaden into all books", function()
    for section, param in pairs{ libraries = "libraryId", collections = "collectionId", ["smart-scopes"] = "smartScopeId" } do
        reset()
        local s = copy(source); s.section = section
        reply = function(kind, selected, q)
            if kind == "section" then H.eq(selected, section); return { items = {{ id = 7, title = "A" }} } end
            H.eq(q[param], 7)
            for _, other in ipairs{ "libraryId", "collectionId", "smartScopeId" } do if other ~= param then H.eq(q[other], nil) end end
            return { items = {}, total = 0 }
        end
        assert(refresh(s).ok); H.eq(#Rows.snapshot(s).files, 0)
    end
end)
H.test("book pagination is complete, deduplicated and rejects repeated or incomplete pages", function()
    reset()
    local base = reply
    reply = function(kind, section, q)
        if kind == "section" then return base(kind, section, q) end
        return { items = {{ id = q.page }}, total = 3, hasNext = q.page < 3 }
    end
    assert(refresh(source).ok); H.eq(#calls, 4); H.eq(Rows.snapshot(source).total, 3)
    local old = saved[CACHE]
    reply = function(kind, section, q)
        if kind == "section" then return base(kind, section, q) end
        return { items = {{ id = 1 }}, total = 3, hasNext = true }
    end
    H.eq(refresh(source).error, "incomplete"); H.eq(saved[CACHE], old)
end)
H.test("account switch, key rotation, disable/re-enable, map generation and suspend retire in-flight commits", function()
    for _, change in ipairs{
        function() p.settings.username = "other" end,
        function() p.settings.userkey = "other" end,
        function() Integration.setBookOrbitEnabled("rows", false); Integration.setBookOrbitEnabled("rows", true) end,
        function() generation = generation + 1 end,
        function() package.loaded["device"].screen_saver_mode = true end,
    } do
        reset(); seed(); local old = saved[CACHE]; during = change
        H.eq(refresh(source).error, "stale"); H.eq(saved[CACHE], old)
    end
end)
H.test("leaving or removing the last observing card prevents queued and in-flight writes", function()
    reset(); local active, result = true
    Rows.refresh(source, { force = true, current = function() return active end, on_done = function(r) result = r end })
    active = false; drain(); H.eq(#calls, 0); H.eq(writes, 0); H.eq(result, nil)
    reset(); seed(); local old = saved[CACHE]; active = true
    during = function() active = false end
    Rows.refresh(source, { force = true, current = function() return active end }); drain()
    H.eq(saved[CACHE], old)
end)
H.test("disabled, disconnected and another account never reveal cached books or start network", function()
    reset(); seed(); local old = saved[CACHE]
    Integration.setBookOrbitEnabled("rows", false)
    H.eq(Rows.snapshot(source).error, "disabled"); H.eq(refresh(source).error, "disabled")
    Integration.setBookOrbitEnabled("rows", true); Integration.setBookOrbitEnabled("want", false)
    H.eq(#Rows.snapshot(source).files, 1)
    p.settings.username = "other"
    H.eq(Rows.snapshot(source).error, "account"); H.eq(#Rows.catalog(), 0); H.eq(refresh(source).error, "account")
    H.eq(#calls, 0); H.eq(saved[CACHE], old)
end)
H.test("offline, cancelled, unsupported or failed requests keep last good cache and never turn Wi-Fi on", function()
    for _, failure in ipairs{ "offline", "cancelled", "unsupported", "server", "bad" } do
        reset(); seed(); local old = saved[CACHE]
        if failure == "offline" then online = false
        elseif failure == "unsupported" then fork = false
        elseif failure == "cancelled" then p:newClient().runInSubprocess = function() return false end
        elseif failure == "server" then reply = function() return nil, 500 end
        else reply = function() return { items = { [2] = { id = 1 } } } end end
        H.eq(refresh(source).ok, false); H.eq(saved[CACHE], old)
    end
end)
H.test("removed or inaccessible sources suppress cached membership instead of silently showing all books", function()
    reset(); seed()
    reply = function(kind) H.eq(kind, "section"); return { items = {} } end
    H.eq(refresh(source).error, "missing"); H.eq(#calls, 1)
    H.eq(saved[CACHE].rows["collections:7"].files[1], "/one.epub")
    H.eq(#Rows.snapshot(source).files, 0); H.eq(Rows.snapshot(source).error, "missing")
end)
H.test("ambiguous stable mappings and virtual/deleted paths are not substituted by metadata guesses", function()
    reset()
    mapping = { {id=1,file="/one.epub"}, {id=2,file="/one.epub"}, {id=3,file="OPDS://remote"} }
    assert(refresh(source).ok); H.eq(#Rows.snapshot(source).files, 0)
    H.eq(maps_calls, 1)
end)
H.test("bad descriptors and malformed cache cannot become a catalog-wide request or credential leak", function()
    reset(); seed()
    for _, bad in ipairs{ {}, {account=source.account,section="books",id=7,title="All"},
        {account=source.account,section="collections",id=-1,title="X"},
        {account=source.account,section="collections",id=7,title="bad\nname"} } do
        H.eq(refresh(bad).error, "source"); H.eq(#calls, 0)
    end
    saved[CACHE].rows["collections:7"] = { files = {"OPDS://remote", false, "/one.epub"}, at = math.huge }
    H.eq(#Rows.snapshot(source).files, 1); H.eq(Rows.snapshot(source).at, nil)
    local descriptor = Model.bookOrbitSource(source)
    descriptor.url, descriptor.token = "https://example.invalid/secret", "secret"
    H.eq(Model.bookOrbitSource(descriptor).url, nil); H.eq(Model.bookOrbitSource(descriptor).token, nil)
end)
H.test("source/book/path-cache bounds reject partial replacement and evict only owned old rows", function()
    reset(); seed(); local old = saved[CACHE]
    Rows.max_books = 2
    H.eq(refresh(source).error, "limit"); H.eq(saved[CACHE], old)
    reset(); seed(); old = saved[CACHE]; Rows.max_sources = 2
    reply = function() return { items = {{id=1,title="A"},{id=2,title="B"},{id=3,title="C"}} } end
    H.eq(refresh(nil).ok, false); H.eq(saved[CACHE], old)
    reset(); seed()
    for i = 1, 40 do saved[CACHE].rows["collections:" .. (100+i)] = { files={"/one.epub"}, at=now } end
    assert(refresh(source).ok)
    local n=0; for _ in pairs(saved[CACHE].rows) do n=n+1 end
    H.eq(n,32); H.eq(saved.foreign_sync,true); H.eq(#Rows.snapshot(source).files,2)
end)
H.test("new source cards use downgrade-safe v3 and preserve sizes, view, title and other screen settings", function()
    reset()
    local Dashboard = require("adapters/orbitui_dashboard")
    local Settings = require("adapters/orbitui_dashboard_settings")
    assert(Settings.add({ kind="bookorbit",source=source }, function() end, "simpleui_hs_"))
    assert(Settings.add({ kind="bookorbit",source=source,label="Second",view="carousel" }, function() end, "simpleui_hs_"))
    local c = Dashboard.readConfig("simpleui_hs_")
    H.eq(c.version, 3); H.eq(#c.modules, 2); H.eq(c.modules[2].ref, "row-2")
    H.eq(c.modules[1].view, "row"); H.eq(c.modules[2].view, "carousel")
    H.eq(c.modules[2].label, "Second"); H.eq(c.modules[1].source.id, 7)
    H.eq(#Dashboard.readConfig("other_").modules, 0); H.eq(saved.foreign_sync, true)
    local normalized = Model.config(c); H.eq(normalized.modules[2].source.account, source.account)
    H.eq(Model.config({version=3}).version, 3); H.eq(Model.config({version=4}).unsupported, true)
    local f = assert(io.open(root .. "/adapters/orbitui_bookorbit_rows.lua")); local code = f:read("*a"); f:close()
    assert(not code:find("catalogSetReadStatus",1,true) and not code:find("downloadCatalog",1,true))
end)
H.test("all new owned settings, help and failure messages retain Swedish and English", function()
    local tr = require("core/orbitui_i18n")
    for _, path in ipairs{ "adapters/orbitui_bookorbit_rows.lua", "adapters/orbitui_dashboard_settings.lua" } do
        local f = assert(io.open(root .. "/" .. path)); local code = f:read("*a"); f:close()
        for text in code:gmatch('_%("([^"]+)"%)') do
            -- Stock/native strings such as Save and Cancel can be inherited.
            if text:find("BookOrbit") or text:find("smartscope") or text:find("Card title")
                    or text == "Cover row" or text == "Carousel" then
                assert(tr(text,"sv") ~= text, text); H.eq(tr(text,"en"),text)
            end
        end
    end
    for _, error in ipairs{ "disabled", "unavailable", "unsupported", "account", "missing", "source", "offline", "stale", "unknown" } do
        assert(Rows.message(error) ~= "")
    end
end)
local native = os.getenv("BOOKORBIT_ROWS_SOURCE")
if native then
    local function methods(path, class, names)
        local f = assert(io.open(native .. "/" .. path)); local code = f:read("*a"); f:close()
        local object, chunks = {}, {}
        for _, name in ipairs(names) do
            chunks[#chunks + 1] = assert(code:match("(function " .. class .. ":" .. name .. "%b().-\nend)"), name)
        end
        local env = setmetatable({ [class] = object, util = { urlEncode = function(s) return s end } }, { __index = _G })
        if setfenv then setfenv(assert(loadstring(table.concat(chunks,"\n"))),env)()
        else assert(load(table.concat(chunks,"\n"),"native catalog methods","t",env))() end
        return object
    end
    local api = methods("bookorbit_api.lua","BookOrbitApi",{"catalogSection","catalogBooks"})
    local catalog = methods("bookorbit_catalog.lua","BookOrbitCatalog",{"paramsForEntry"})
    H.test("frozen real BookOrbit API methods accept every source filter as GET-only native catalog requests", function()
        for _, section in ipairs{"libraries","collections","smart-scopes"} do
            reset()
            local client = p:newClient()
            client.catalogSection, client.catalogBooks = api.catalogSection, api.catalogBooks
            client.query = function(_, path, params) return { path=path,params=params } end
            client.request = function(_, method, request)
                H.eq(method,"GET")
                if request.path:find("/sections/",1,true) then
                    H.eq(request.path,"/koreader/plugin/catalog/sections/"..section)
                    return { items={{id=7,title="A"}} }
                end
                H.eq(request.path,"/koreader/plugin/catalog/books")
                local expected = catalog:paramsForEntry(section,{id=7})
                for k,v in pairs(expected) do H.eq(request.params[k],v,k) end
                return { items={{id=1}},total=1,hasNext=false }
            end
            local selected = copy(source); selected.section = section
            assert(refresh(selected).ok); H.eq(Rows.snapshot(selected).files[1],"/one.epub")
        end
    end)
end
os.time = real_time
H.finish()
