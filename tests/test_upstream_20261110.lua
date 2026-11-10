local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local map = dofile(root .. "/core/orbitui_module_map.lua")
local function source(name)
    local f = io.open(root .. "/" .. assert(map[name]), "rb")
    if f then local s = f:read("*a"); f:close(); return s end
    return assert(getmetatable(map).orbitui_embedded[name])
end
local function run(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "upstream November 10", "t", env))()
end
H.test("new library helpers are exact-source lazy embeds without extra installed paths", function()
    for _, suffix in ipairs({ "rule_collections", "sort_sheet" }) do
        local name = "features/library/sui_" .. suffix
        H.eq(getmetatable(map).orbitui_embedded[name], source(name))
        assert((loadstring or load)(source(name), "@" .. map[name]))
    end
end)
H.test("host disables automatic rule rescan while keeping explicit collection operations", function()
    local patches = {}
    require("adapters/orbitui_ui").wrap("infra/sui_patches", patches)
    H.eq(patches.orbitui_defer_rule_startup, true)
    local s = source("infra/sui_patches")
    assert(s:find("if M.orbitui_defer_rule_startup or rawget(FMColl, COLLECTIONS_STATE) ~= state", 1, true))
    assert(s:find("pcall(RuleCollections.sync, rc_self, coll_name, is_showing)", 1, true))
end)
H.test("failed and incomplete metadata queries cannot remove connected collection membership", function()
    local complete, matches, call = true, {}, 0
    local services = {
        ["ffi/util"] = { realpath = function(p) return p end },
        ["libs/libkoreader-lfs"] = { attributes = function(p) return p == "/books" and "directory" or "file" end },
        util = { tableGetValue = function() return nil end },
        ["infra/sui_config"] = {},
        ["features/library/sui_filter_state"] = {
            new = function() return {} end, addFilter = function() end },
        ["features/library/sui_metadata_source"] = {
            getMatchingFiles = function(_, _, state)
                call = call + 1
                if not state then return { { "/books/a", "a" } }, true end
                return matches, complete
            end,
            sortFiles = function() end },
        ["features/library/sui_virtual_path"] = {}, bookinfomanager = {},
        ["document/documentregistry"] = { hasProvider = function() return true end },
    }
    local rules = run(source("features/library/sui_rule_collections"), {
        require = function(n) return assert(services[n], n) end })
    local rc = { coll = { test = { ["/books/a"] = true } },
        coll_settings = { test = { [rules.KEY] = rules.new("/books", { { dimension = "tags", value = "life" } }, true) } },
        addItem = function(self, p, n) self.coll[n][p] = true end,
        removeItem = function(self, p, n) self.coll[n][p] = nil end }
    complete = false
    local a, r = rules.sync(rc, "test"); H.eq(a, 0); H.eq(r, 0); H.eq(rc.coll.test["/books/a"], true)
    complete = true; matches = { { "/books/b", "b" } }
    a, r = rules.sync(rc, "test"); H.eq(a, 1); H.eq(r, 1); H.eq(rc.coll.test["/books/b"], true)
    rc.coll_settings.test[ rules.KEY ].scan_on_show = false
    local before = call; rules.sync(rc, "test", true); H.eq(call, before)
end)
H.test("data changes do not rearm deferred hosted page-building or suspended work", function()
    local body = assert(source("lib/bookshelf_widget"):match("function BookshelfWidget:_onDataGeneration%(%)\n(.-)\nend\n"))
    local calls = 0
    local fn = run("return function(self)\n" .. body .. "\nend", {
        require = function(n) H.eq(n, "lib/bookshelf_page_cache"); return { enabled = false } end,
        UIManager = { scheduleIn = function() calls = calls + 1 end } })
    fn({}); fn({ _orbitui_suspended = true }); fn({ _closed = true }); H.eq(calls, 0)
end)
H.finish()
