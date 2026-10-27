package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
local function read(path)
    local f = assert(io.open(root .. "/components/simpleui/" .. path))
    local s = f:read("*a"); f:close(); return s
end
local function run(source, env)
    env = setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(source)), env)() end
    return assert(load(source, "October 27 merge", "t", env))()
end
local identity = function(s) return s end
local function textFixture(util, utf8)
    return run(read("infra/sui_text.lua"), { require = function(name)
        if name == "util" then return util end
        if name == "infra/sui_i18n" then return { translate = identity } end
        H.eq(name, "ffi/utf8proc")
        if not utf8 then error("not available") end
        return utf8
    end })
end
local function unicodeLower(s)
    return (s:gsub("Ö", "ö"):gsub("Å", "å"):gsub("Ä", "ä")
        :gsub("Б", "б"):gsub("Ω", "ω"):lower())
end
H.test("Unicode comparison prefers the current native helper without modifying util", function()
    local util = { stringLower = function(s) return "native:" .. s end }
    local text = textFixture(util, { lowercase = function() error("must prefer native") end })
    H.eq(text.lower("TITLE"), "native:TITLE")
    H.eq(text.lower(nil), nil); H.eq(util.lower, nil)
end)
H.test("minimum readers use utf8proc while native-free test environments retain a safe fallback", function()
    local util = {}
    local text = textFixture(util, { lowercase = unicodeLower })
    H.eq(text.lower("ÖVNING ÅÄ Б Ω"), "övning åä б ω")
    H.eq(util.stringLower, nil)
    H.eq(textFixture({}, nil).lower("TITLE"), "title")
    H.eq(textFixture({}, true).lower("TITLE"), "title")
end)
H.test("all five changed search sort and asset paths use the shared compatibility helper", function()
    for _, path in ipairs({ "engines/sui_asset_browser.lua", "engines/sui_book_grid.lua",
        "features/library/sui_library_search.lua", "modules/module_library.lua", "modules/module_coverdeck.lua" }) do
        local src = read(path)
        assert(src:find("Text.lower(", 1, true), path)
        assert(not src:find("util.stringLower(", 1, true), path)
    end
end)
H.test("native library sorting folds title and author once per candidate and never mutates the scan", function()
    local src = assert(read("modules/module_library.lua"):match("local function sortRaw%(.-\nend"))
    local names = { a = "Östen", b = "äpple", c = "Åke" }
    local folds = 0
    local sort = run(src .. "\nreturn sortRaw", { Text = { lower = function(s)
        folds = folds + 1; return unicodeLower(s)
    end }, cachedTitle = function(fp) return names[fp] end, cachedAuthor = function(fp) return names[fp] end })
    local raw = { { fp = "a", size = 3 }, { fp = "b", size = 1 }, { fp = "c", size = 2 } }
    local result = sort(raw, "title_asc")
    H.eq(table.concat(result), "bca"); H.eq(folds, 3); H.eq(raw[1].fp, "a")
    folds = 0; H.eq(table.concat(sort(raw, "author_asc")), "bca"); H.eq(folds, 3)
    H.eq(table.concat(sort(raw, "title_desc")), "acb")
    H.eq(table.concat(sort(raw, "size_asc")), "bca")
end)

H.test("the whole library search matches Unicode title author series and filename literally", function()
    local prompt, window
    local files = { "/books/one.epub", "/books/ÖVNING-100%.epub" }
    local deps = {
        ["infra/sui_i18n"] = { translate = identity },
        ["ffi/util"] = { template = function(s) return s end },
        ["infra/sui_text"] = textFixture({}, { lowercase = unicodeLower }),
        ["infra/sui_virtual_paths"] = {},
        ["engines/sui_library_scan"] = { resolveHomeDir = function() return "/books" end,
            getFileList = function() return files end },
        ["features/library/sui_metadata_source"] = { getMatchingFiles = function()
            return { { files[1], title = "ÖVNING", authors = "ÅKE", series = "БΩ" } }
        end },
        ["bookinfomanager"] = {},
        ["features/dialogs/sui_dialogs"] = { prompt = function(opts) prompt = opts end },
        ["engines/sui_window"] = { new = function(_, opts)
            opts.show = function() window = opts end; return opts
        end, ListRow = identity },
        ["infra/sui_config"] = { isNavpagerEnabled = function() return false end },
        ["infra/sui_core"] = { Notify = { toast = function() end } },
    }
    local search = run(read("features/library/sui_library_search.lua"), { require = function(name)
        return assert(deps[name], name)
    end })
    search.show(); prompt.on_submit("övning åke бω")
    local rows = window.screens.__root__{ inner_w = 600 }
    H.eq(#rows, 1); H.eq(rows[1].title, "ÖVNING")
    window = nil; prompt.on_submit("övning-100%")
    rows = window.screens.__root__{ inner_w = 600 }
    H.eq(#rows, 1); H.eq(rows[1].title, "ÖVNING-100%.epub")
end)

local function providerFixture()
    local fault, value, warned, called = nil, nil, 0, 0
    local connection, statement = {}, {}
    local bim = { db_location = "/private/cache/bookinfo.sqlite3", db_conn = connection,
        get_stmt = statement, db_created = true, extractBookInfo = function() end }
    bim.getBookInfo = function(self, filepath, ...)
        H.eq(self, bim); called = called + 1
        if filepath == "/books/check.epub" then H.eq(select("#", ...), 2); H.eq(select(2, ...), "tail") end
        if fault then error(fault, 0) end
        return value
    end
    bim.closeDbConnection = function() error("must not reset a shared connection") end
    local providers = run(read("features/library/sui_metadata_providers.lua"), {
        os = { remove = function() error("must not remove cache/WAL/SHM") end,
            rename = function() error("must not move cache files") end },
        require = function(name)
            if name == "bookinfomanager" then return bim end
            if name == "document/documentregistry" then return { getProvider = function() end } end
            if name == "logger" then return { warn = function() warned = warned + 1 end } end
            if name == "ffi/util" or name == "ui/uimanager" then return {} end
            error("unexpected dependency: " .. name)
        end,
    })
    H.eq(providers.install(), true)
    return { bim = bim, set = function(err, result) fault, value = err, result end,
        warnings = function() return warned end, calls = function() return called end,
        unchanged = function() H.eq(bim.db_conn, connection); H.eq(bim.get_stmt, statement); H.eq(bim.db_created, true) end,
        providers = providers }
end
H.test("recognized database faults are contained without deleting caches or resetting live statements", function()
    for _, fault in ipairs({ "database disk image is malformed", "corrupt", "misuse", "not a database" }) do
        local f = providerFixture(); f.set(fault)
        H.eq(f.bim:getBookInfo("/books/check.epub", nil, "tail"), nil)
        f.unchanged(); H.eq(f.warnings(), 1)
    end
end)
H.test("faults remain retryable and warnings are bounded until a successful read", function()
    local f = providerFixture(); f.set("corrupt")
    for _ = 1, 10 do H.eq(f.bim:getBookInfo("/books/a.epub"), nil) end
    H.eq(f.warnings(), 1); H.eq(f.calls(), 10)
    local row = { title = "Recovered", has_meta = "Y", has_cover = true }
    f.set(nil, row); H.eq(f.bim:getBookInfo("/books/a.epub"), row)
    f.set("corrupt"); f.bim:getBookInfo("/books/a.epub")
    H.eq(f.warnings(), 2); f.unchanged()
end)
H.test("last known text survives a fault without claiming to have a real cached cover", function()
    local f = providerFixture()
    f.set(nil, { title = "Keep me", authors = "Author", has_meta = "Y", has_cover = true })
    f.bim:getBookInfo("/books/a.epub")
    f.set("malformed")
    local row = f.bim:getBookInfo("/books/a.epub")
    H.eq(row.title, "Keep me"); H.eq(row.authors, "Author")
    H.eq(row.has_cover, false); H.eq(row.cover_fetched, false)
    f.unchanged()
end)
H.test("unrelated errors propagate unchanged and provider installation is idempotent", function()
    local f = providerFixture()
    local err = { reason = "unrelated" }; f.set(err)
    local callback = f.bim.getBookInfo
    H.eq(f.providers.install(), true); H.eq(f.bim.getBookInfo, callback)
    local ok, result = pcall(f.bim.getBookInfo, f.bim, "/books/a.epub")
    H.eq(ok, false); H.eq(result, err); H.eq(f.warnings(), 0); f.unchanged()
end)
H.test("the complete preset module exports callable onboarding list rows without saving on read", function()
    local selected
    local presets = run(read("features/sui_presets.lua"), { require = function(name)
        if name == "infra/sui_i18n" then return { translate = identity } end
        if name == "infra/sui_store" then return { saveSetting = function() error("unexpected write") end } end
        if name == "logger" then return {} end
        if name == "util" then return { tableDeepCopy = identity } end
        H.eq(name, "engines/sui_window")
        return { ListRow = identity, SectionLabel = identity }
    end })
    H.eq(type(presets.buildListRows), "function")
    local rows = presets.buildListRows{ inner_w = 600, is_checked = function() return false end,
        on_builtin = function(bp) selected = bp.id end }
    assert(#rows > 0); rows[1].on_tap(); assert(selected)
end)
H.finish()
