local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = io.open(root .. "/" .. path, "rb")
    if f then local s = f:read("*a"); f:close(); return s end
    local map = dofile(root .. "/core/orbitui_module_map.lua")
    for name, s in pairs(getmetatable(map).orbitui_embedded) do
        if map[name] == path then return s end
    end
    error("missing reviewed source " .. path)
end
local function run(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "1.1 upstream boundary", "t", env))()
end
local pubcode = read("components/bookshelf/lib/bookshelf_published.lua")
H.test("hosted publication years never create an unowned file-reader queue", function()
    local rows, writes, scheduled = {}, 0, 0
    local parser = run(read("components/bookshelf/lib/bookshelf_pubdate.lua"), {})
    local facts = { get = function(fp) return rows[fp] end,
        put = function(fp, value)
            rows[fp] = rows[fp] or {}
            for k, v in pairs(value) do rows[fp][k] = v ~= false and v or nil end
            writes = writes + 1
        end, flushSoon = function() end }
    local P = run(pubcode, { require = function(n)
        if n == "lib/bookshelf_pubdate" then return parser end
        if n == "lib/bookshelf_book_facts_db" then return facts end
        if n == "ui/uimanager" then return { scheduleIn = function() scheduled = scheduled + 1 end } end
        error("unexpected file/engine/network access " .. n)
    end })
    require("adapters/orbitui_ui").wrap("lib/bookshelf_published", P)
    H.eq(P.orbitui_defer_file_reads, true)
    local year, source = P.info({ filepath = "/b/unread.epub" })
    H.eq(year, nil); H.eq(source, "unavailable")
    P.enqueue("/b/unread.epub")
    H.eq(scheduled, 0); H.eq(writes, 0)
    H.eq(P.forRecord({ filepath = "/b/a.epub", calibre = { pubdate = "1869" } }), "1869")
    H.eq(P.forRecord({ filepath = "/b/a.epub", hardcover_published = "1901" }), "1901")
    H.eq(P.forRecord({ filepath = "OPDS://s/id", published = "1923" }), "1923")
    rows["/b/a.epub"] = { pd = "2000-02", pdm = 5 }
    H.eq(P.forRecord({ filepath = "/b/a.epub" }), "2000")
    assert(P.setUserDate("/b/a.epub", "1999-01-02"))
    H.eq(P.info({ filepath = "/b/a.epub" }), "1999-01-02")
    P.forget("/b/a.epub", 6)
    H.eq(P.userDate("/b/a.epub"), "1999-01-02")
    assert(P.setUserDate("/b/a.epub", nil))
    H.eq(P.info({ filepath = "/b/a.epub" }), nil)
    H.eq(scheduled, 0)
end)
H.test("explicit metadata reload keeps cooperative refresh and retires grouped caches", function()
    local source = read("components/bookshelf/lib/bookshelf_book_repository.lua")
    local invalidated, grouped, listed, requested = 0, 0, 0, 0
    local env = { Repo = {
        invalidateSeriesCache = function() grouped = grouped + 1 end,
        invalidateBookCache = function() listed = listed + 1 end },
        _light_meta_cache = { old = true }, _light_meta_rows_cache = { old = true },
        _lightmeta_refresh = { invalidate = function() invalidated = invalidated + 1 end },
        _scheduleLightMetaRefresh = function() requested = requested + 1 end }
    run(assert(source:match("(function Repo.reloadLightMeta%b().-\nend)")), env)
    env.Repo.reloadLightMeta()
    H.eq(invalidated, 1); H.eq(grouped, 1); H.eq(listed, 1); H.eq(requested, 1)
    assert(next(env._light_meta_cache) == nil and env._light_meta_rows_cache == nil)
end)
H.test("wallpaper fit bounds native allocation without changing normal geometry", function()
    local M = {}
    run(assert(read("components/bookshelf/lib/bookshelf_wallpaper.lua"):match(
        "(function M.fitLayout%b().-\nend)")), { M = M })
    H.eq(M.fitLayout(1, 1000000000, 1200, 1600, "fill"), nil)
    H.eq(M.fitLayout(1000000000, 1, 1200, 1600, "fill"), nil)
    local w, h, x, y = M.fitLayout(1000, 1000, 1200, 1600, "fill")
    H.eq(w, 1600); H.eq(h, 1600); H.eq(x, -200); H.eq(y, 0)
    w, h, x, y = M.fitLayout(1000, 1000, 1200, 1600, "fit")
    H.eq(w, 1200); H.eq(h, 1200); H.eq(x, 0); H.eq(y, 200)
end)
H.test("retired wallpaper page, tab and Close callbacks cannot save late choices", function()
    local queue, choices, scales = {}, 0, 0
    local WB = { ALL = "all", SETTLE_S = 0.6, GRID_SHARE = 0.55,
        entries = function() return { {}, {} } end, perPage = function() return 1 end,
        inUse = function() return false end, choose = function() choices = choices + 1 end,
        startPage = function() return 1 end, nextScaling = function() scales = scales + 1 end }
    local LM = { new = function(_, o) o.refresh = function() end; return o end }
    local ui = { scheduleIn = function(_, _, cb) queue[#queue + 1] = cb end,
        unschedule = function() end, show = function() end, setDirty = function() end }
    run(assert(read("components/bookshelf/lib/bookshelf_wallpaper_browser.lua"):match(
        "(function WB.show%b().-\nend)")), { WB = WB,
        require = function(n) if n == "ui/uimanager" then return ui end
            H.eq(n, "lib/bookshelf_library_modal"); return LM end,
        WP = function() return {} end, _ = function(s) return s end })
    local modal = WB.show("wallpaper_default")
    modal.config.on_page_shown(1); local first = queue[#queue]
    modal.config.on_page_shown(2); first(); H.eq(choices, 0)
    queue[#queue](); H.eq(choices, 1)
    modal.config.on_page_shown(1); local tab = queue[#queue]
    modal.config.on_chip_tap("new"); tab(); H.eq(choices, 1)
    modal.config.on_page_shown(1); local late = queue[#queue]
    modal.config.on_closed(); late()
    modal.config.on_cell_tap({}); modal.config.footer_rows[1][1].on_tap()
    H.eq(choices, 1); H.eq(scales, 0)
end)
H.test("new folder-delete action remains standalone-only pending recoverable cleanup", function()
    local source = read("components/bookshelf/lib/bookshelf_widget.lua")
    local gate = assert(source:match("(if self.orbitui_allow_folder_delete == false then.-end)"))
    for _, flag in ipairs({ "unset", false, true }) do
        local actions = { "move", "rename", "delete" }
        local self = {}
        if flag ~= "unset" then self.orbitui_allow_folder_delete = flag end
        run(gate, { self = self, strip_actions = actions })
        H.eq(#actions, flag == false and 2 or 3)
    end
    assert(read("adapters/orbitui_ui.lua"):find("module.orbitui_allow_folder_delete = false", 1, true))
end)
H.test("Cover Deck uses conservative CJK widths while preserving Swedish Latin accents", function()
    local source = read("components/simpleui/modules/module_coverdeck.lua")
    local body = assert(source:match("(local _AVG_CHAR_WIDTH_RATIO.-)\n%-%- %-%-%-%-"))
    local truncate = run(body .. "\nreturn truncateToWidth", { Text = { truncate = function(_, n) return n end } })
    H.eq(truncate("Ångström", { size = 20 }, 110), 10)
    H.eq(truncate("日本語", { size = 20 }, 110), 5)
    H.eq(truncate("Ελληνικά", { size = 20 }, 110), 8)
end)
H.finish()
