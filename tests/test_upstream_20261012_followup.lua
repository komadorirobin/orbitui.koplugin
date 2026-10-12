package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local function run(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then
        local f = assert(loadstring(code)); setfenv(f, env); return f()
    end
    return assert(load(code, "5.4.4 integration", "t", env))()
end
local src = read("components/bookshelf/lib/bookshelf_widget.lua")
local saved, tabs, writes = {}, {}, 0
local Settings = {
    read = function(k) return saved[k] end,
    save = function(k, v) saved[k] = v end,
    delete = function(k) saved[k] = nil end,
    saveDeferred = function(k, v) saved[k] = v end,
}
package.loaded["lib/bookshelf_settings_store"] = Settings
local Profiles = require("lib/bookshelf_profiles")
local ViewMode = require("lib/bookshelf_view_mode")
local TabModel = {
    getById = function(id) return tabs[id] end,
    load = function()
        local out = {}; for _, t in pairs(tabs) do out[#out+1] = t end; return out
    end,
    saveDeferred = function() writes = writes + 1 end,
}
local W = {}
for _, name in ipairs({"_profileShelfSettings", "_chipViewMode", "_isSearchResults",
        "_isDrilledIn", "_autoLevel", "_chipListValue", "_setChipDensity"}) do
    local args, body = src:match("\nfunction BookshelfWidget:" .. name .. "%((.-)%)\n(.-)\nend\n")
    assert(body, name)
    run("function BookshelfWidget:" .. name .. "(" .. args .. ")\n" .. body .. "\nend", {
        BookshelfWidget=W, Profiles=Profiles, ViewMode=ViewMode, BookshelfSettings=Settings,
        require=function(m)
            if m == "lib/bookshelf_tab_model" then return TabModel end
            error(m)
        end,
    })
end
local function shelf(profile, drill)
    return setmetatable({ profile=profile and Profiles.get(profile), chip="authors",
        _drilldown_path=drill and {{kind=drill, payload={name="Author"}}} or {} }, {__index=W})
end
local function settings(extra)
    local t = {view_mode="auto", view_level1="list", view_level2="list",
        list_rows=6, list_columns=2, theme="washi", cover_label_position="above",
        spine_cover_size_pct=120}
    for k,v in pairs(extra or {}) do t[k]=v end
    return t
end
local function reset()
    saved, tabs, writes = {list_rows=4, list_columns=1}, {}, 0
end

H.test("both profile levels retain independent list density across reloads", function()
    reset()
    Profiles.saveShelfSettings(Profiles.get("prose"), "authors",
        settings{list_rows_l2=9, list_columns_l2=3, list_rows_expanded_l2=11})
    Profiles.saveShelfSettings(Profiles.get("comics"), "authors",
        settings{list_rows_l2=7, list_columns_l2=1})
    package.loaded["lib/bookshelf_profiles"] = nil
    local reloaded = require("lib/bookshelf_profiles")
    H.eq(reloaded.shelfSettings(Profiles.get("prose"), "authors").list_rows_expanded_l2, 11)
    H.eq(shelf("prose"):_chipListValue("list_rows"), 6)
    H.eq(shelf("prose", "author"):_chipListValue("list_rows"), 9)
    H.eq(shelf("comics", "author"):_chipListValue("list_columns"), 1)
    H.eq(shelf("prose", "author"):_chipListValue("list_columns"), 3)
end)

H.test("profile pinch writes only the visible level without losing other preferences", function()
    reset()
    Profiles.saveShelfSettings(Profiles.get("prose"), "authors", settings())
    local w = shelf("prose", "author")
    w:_setChipDensity("list_rows", 9)
    w:_setChipDensity("list_columns", 3)
    local t = w:_profileShelfSettings()
    H.eq(t.list_rows_l2, 9); H.eq(t.list_columns_l2, 3)
    H.eq(t.list_rows, 6); H.eq(t.list_columns, 2)
    H.eq(t.theme, "washi"); H.eq(t.cover_label_position, "above")
    H.eq(t.spine_cover_size_pct, 120)
    H.eq(shelf("comics", "author"):_chipListValue("list_rows"), 4)
    w._drilldown_path = {}
    w:_setChipDensity("list_rows", 5)
    H.eq(w:_profileShelfSettings().list_rows_l2, 9)
    H.eq(w:_chipListValue("list_rows"), 5)
end)

H.test("level two inherits density but never level one's expanded zoom", function()
    reset()
    Profiles.saveShelfSettings(Profiles.get("prose"), "authors",
        settings{list_rows_expanded=10, list_rows_expanded_l2=8})
    local w = shelf("prose", "series")
    H.eq(w:_chipListValue("list_rows"), 6)
    H.eq(w:_chipListValue("list_rows_expanded"), 8)
    w:_setChipDensity("list_rows_expanded", nil)
    H.eq(w:_chipListValue("list_rows_expanded"), nil)
    H.eq(w:_profileShelfSettings().list_rows_expanded, 10)
    w:_setChipDensity("list_rows", 9)
    w:_setChipDensity("list_rows", nil)
    H.eq(w:_chipListValue("list_rows"), 6)
end)

H.test("native namesake chips cannot leak density into either fixed profile", function()
    reset()
    tabs.authors = settings{ id="authors", list_rows=10, list_rows_l2=12 }
    H.eq(shelf("prose", "author"):_chipListValue("list_rows"), 4)
    H.eq(shelf(nil, "author"):_chipListValue("list_rows"), 12)
    shelf(nil, "author"):_setChipDensity("list_rows", 11)
    H.eq(tabs.authors.list_rows_l2, 11); H.eq(tabs.authors.list_rows, 10)
    H.eq(writes, 1)
    H.eq(shelf("comics", "author"):_chipListValue("list_rows"), 4)
end)

H.test("single list modes and legacy unset modes keep one density setting", function()
    reset()
    for _, mode in ipairs({"list", "covers", "auto", false}) do
        local t = settings{list_rows_l2=10, view_level1="covers"}
        t.view_mode = mode or nil
        Profiles.saveShelfSettings(Profiles.get("prose"), "authors", t)
        local w = shelf("prose", "author")
        H.eq(w:_chipListValue("list_rows"), 6)
        w:_setChipDensity("list_rows", 7)
        H.eq(w:_profileShelfSettings().list_rows, 7)
        H.eq(w:_profileShelfSettings().list_rows_l2, 10)
    end
end)

H.test("search and non-list keys never use level two's density", function()
    reset()
    Profiles.saveShelfSettings(Profiles.get("prose"), "authors", settings{list_rows_l2=9})
    local w = shelf("prose", "search")
    H.eq(w:_autoLevel(), 1); H.eq(w:_chipListValue("list_rows"), 6)
    w._drilldown_path = {{kind="author", payload={name="Author"}}}
    H.eq(w:_autoLevel(), 2)
    w:_setChipDensity("spine_cover_size_pct", 130)
    H.eq(w:_chipListValue("spine_cover_size_pct"), 130)
    H.eq(w:_profileShelfSettings().list_rows_l2, 9)
end)

H.test("face-out favourite corner mirrors the glyph without moving ordinary grid badges", function()
    local s = read("components/bookshelf/lib/bookshelf_spine_widget.lua")
    local code = assert(s:match("(                local x_offset = _glyphLeftInset%(%) %- halo_w %+ center_shift\n.-)\n                %-%- Zero%-chrome"))
    for _, right in ipairs({false, true}) do
        local x = run(code .. "\nreturn x_offset", {self={favorite_top_right=right},
            _glyphLeftInset=function() return 5 end, halo_w=1, center_shift=3,
            card_w=100, glyph_w=14, shadow_d=3})
        H.eq(x, right and 76 or 7)
    end
end)

H.finish()
