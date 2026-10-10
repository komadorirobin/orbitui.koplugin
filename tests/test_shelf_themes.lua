package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
package.loaded.logger = { warn=function() end, dbg=function() end }
local Adapter = require("adapters/orbitui_shelf_themes")
local P = require("lib/bookshelf_profiles")
local saved, deferred = {}, {}
local store = {
    read = function(k) return saved[k] end,
    save = function(k, v) saved[k] = v end,
    saveDeferred = function(k, v) saved[k] = v; deferred[k] = true end,
    delete = function(k) saved[k] = nil end,
}
package.loaded["lib/bookshelf_settings_store"] = store
local native = { {id="authors", label="Authors"}, {id="hidden", enabled=false} }
local TM = {
    load = function() return native end,
    getActive = function() return { native[1] } end,
    getById = function(id) for _, t in ipairs(native) do if t.id == id then return t end end end,
    save = function(t) native = t end,
}
package.loaded["lib/bookshelf_tab_model"] = TM
local menu = dofile("components/bookshelf/lib/bookshelf_theme_menu.lua")
Adapter.menu(menu)
local function widget(key, chip)
    local w = { profile=P.get(key), chip=chip, _profileChip=function(self, id) return P.chip(self.profile,id) end }
    Adapter.widget(w)
    return w
end

H.test("native and both profile Authors shelves have distinct persistent identities", function()
    H.eq(widget(nil,"authors"):themeShelfId(), "authors")
    H.eq(widget("prose","authors"):themeShelfId(), "orbitui:prose:authors")
    H.eq(widget("comics","authors"):themeShelfId(), "orbitui:comics:authors")
    H.eq(widget("prose","native-child"):themeShelfId(), "native-child")
    H.eq(menu.shelfOnScreen({_bw=widget("comics","authors")}), "orbitui:comics:authors")
end)

H.test("profile theme selection preserves size, density, and the other profile", function()
    P.saveShelfSettings(P.get("prose"),"authors", {spine_cover_size_pct=120, spine_rows=3})
    menu.setShelfTheme("orbitui:prose:authors", "plain")
    menu.setShelfTheme("orbitui:comics:authors", "mine")
    local a, b = Adapter.tab("orbitui:prose:authors"), Adapter.tab("orbitui:comics:authors")
    H.eq(a.theme,"plain"); H.eq(a.spine_cover_size_pct,120); H.eq(a.spine_rows,3)
    H.eq(b.theme,"mine"); H.eq(native[1].theme,nil)
    assert(a.label ~= b.label)
    menu.setShelfTheme(a.id,nil)
    H.eq(Adapter.tab(a.id).theme,nil)
    H.eq(Adapter.tab(a.id).spine_cover_size_pct,120)
    H.eq(Adapter.tab(b.id).theme,"mine")
end)

H.test("theme-library edits defer profile disk writes just like native shelves", function()
    package.loaded["lib/bookshelf_ornaments"] = {_defer=true}
    menu.setShelfTheme("orbitui:prose:authors", "plain")
    assert(deferred.profile_shelf_prose_authors)
    package.loaded["lib/bookshelf_ornaments"] = nil
    menu.setShelfTheme("authors", "mine")
    H.eq(native[1].theme,"mine")
end)

H.test("menu and deck inventories include profiles without inserting navigation tabs", function()
    local seen = {}
    for _, tab in ipairs(Adapter.tabs(true)) do
        assert(not seen[tab.id]); seen[tab.id]=true
    end
    assert(seen.hidden and seen["orbitui:prose:authors"] and seen["orbitui:comics:authors"])
    H.eq(#native,2)
    for _, tab in ipairs(menu.tabs()) do assert(tab.id ~= "hidden") end
end)

H.test("the actual upstream theme resolver reads separate profile choices", function()
    local TP = dofile("components/bookshelf/lib/bookshelf_theme_pack.lua")
    TP._store = store
    Adapter.theme(TP)
    H.eq(TP.ownChoice("orbitui:prose:authors"),"plain")
    H.eq(TP.ownChoice("orbitui:comics:authors"),"mine")
    H.eq(TP.ownChoice("authors"),"mine")
    H.eq(TP.ownChoice("orbitui:prose:profile_fiction"),nil)
    H.eq(TP.anyShelfTheme(),true)
end)

H.test("opening another shelf switches profile before its chip, including native shelves", function()
    local calls = {}
    local w = {
        setProfile=function(_, key, quiet) calls[#calls+1]={key=key,quiet=quiet} end,
        _setActiveChip=function(_, key) calls[#calls+1]=key end,
    }
    menu.activateShelf({_bw=w},"orbitui:comics:authors")
    H.eq(calls[1].key,"comics"); H.eq(calls[1].quiet,true); H.eq(calls[2],"authors")
    menu.activateShelf({_bw=w},"authors")
    H.eq(calls[3].key,nil); H.eq(calls[4],"authors")
end)

H.test("switching profiles on the same restored chip still rebuilds the visible tree", function()
    local rebuilds, paints = 0, 0
    package.loaded["ui/uimanager"] = {setDirty=function() paints=paints+1 end}
    local w = { profile=P.get("prose"), chip="authors",
        setProfile=function(self,key) self.profile=P.get(key); self.chip="authors" end,
        _setActiveChip=function() error("same-chip no-op must not swallow profile rebuild") end,
        _rebuild=function() rebuilds=rebuilds+1 end }
    menu.activateShelf({_bw=w},"orbitui:comics:authors")
    H.eq(w.profile,P.get("comics")); H.eq(rebuilds,1); H.eq(paints,1)
end)

H.finish()
