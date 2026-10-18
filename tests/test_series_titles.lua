package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local saved, flushes, rebuilds, drops, dirties = {}, 0, 0, 0, 0
package.loaded["lib/bookshelf_settings_store"] = {
    read = function(k) return saved[k] end,
    save = function(k, v) saved[k] = v end,
    flush = function() flushes = flushes + 1 end,
}
local tabs = {authors={id="authors", label="Authors"}, nested={id="nested",label="Nested"}}
package.loaded["lib/bookshelf_tab_model"] = {getById=function(id) return tabs[id] end}
package.loaded["lib/bookshelf_spine_shelf"] = {dropPlanCache=function() drops=drops+1 end}
package.loaded["ui/uimanager"] = {setDirty=function() dirties=dirties+1 end}
local menu
package.loaded["lib/bookshelf_menu_host"] = {
    show=function(opts) menu=opts; return opts end,
    close=function(host) host.closed=true end,
}
local M = require("adapters/orbitui_series_titles")
local Labels = require("adapters/orbitui_cover_labels")
local Profiles = require("lib/bookshelf_profiles")
local function widget(profile, chip)
    local w = {profile=Profiles.get(profile),chip=chip or "authors",
        _spinePlanBase=function(_, width, height) return {content_w=width,row_h=height} end,
        _rebuild=function() rebuilds=rebuilds+1 end}
    M.widget(w)
    return w
end

H.test("series title placement defaults below without reading-data or preference writes", function()
    H.eq(M.position("authors"),"below")
    H.eq(widget():_spinePlanBase(800,300).series_title_position,"below")
    H.eq(next(saved),nil); H.eq(flushes,0)
end)

H.test("native nested prose and manga chips retain independent title positions after reload", function()
    local native, nested, prose, manga = widget(), widget(nil,"nested"), widget("prose"), widget("comics")
    M.save(Labels.id(native),"overlay")
    M.save(Labels.id(manga),"overlay")
    package.loaded["adapters/orbitui_series_titles"] = nil
    M = require("adapters/orbitui_series_titles")
    for _, w in ipairs({native,manga}) do H.eq(M.position(Labels.id(w)),"overlay") end
    for _, w in ipairs({nested,prose}) do H.eq(M.position(Labels.id(w)),"below") end
    H.eq(native:_spinePlanBase(800,300).content_w,800)
    H.eq(manga:_spinePlanBase(800,300).series_title_position,"overlay")
    H.eq(prose:_spinePlanBase(800,300).series_title_position,"below")
    H.eq(tabs.authors.cover_label_position,nil)
end)

H.test("invalid choices are rejected and unrelated saved values survive changes", function()
    local key="orbitui_series_title_positions"
    saved[key].future={keep=true}; saved[key].bad="unknown"
    local old, count=saved[key],flushes
    H.eq(M.save("","overlay"),false); H.eq(M.save("authors","above"),false)
    H.eq(M.position("bad"),"below"); H.eq(flushes,count)
    H.eq(M.save("authors","below"),true)
    H.eq(old.authors,"overlay"); H.eq(saved[key].future.keep,true); H.eq(saved[key].bad,"unknown")
    H.eq(M.position("orbitui:comics:authors"),"overlay")
end)

H.test("the chip menu targets that chip and invalidates planning before the immediate redraw", function()
    local w=widget("prose")
    M.show(w,"authors")
    H.eq(#menu.item_table,2); H.eq(menu.item_table[1].checked_func(),true)
    local old=menu
    menu.item_table[2].callback()
    H.eq(old.closed,true); H.eq(drops,1); H.eq(rebuilds,1); H.eq(dirties,1)
    H.eq(M.position(Labels.id(w)),"overlay")
    M.show(w,"authors"); H.eq(menu.item_table[2].checked_func(),true)
    menu.item_table[1].callback()
    H.eq(M.position(Labels.id(w)),"below")
    local native=widget()
    M.show(native,"nested"); menu.item_table[2].callback()
    H.eq(M.position("nested"),"overlay"); H.eq(M.position("authors"),"below")
    local writes=flushes
    H.eq(M.show(native,"missing"),nil); H.eq(flushes,writes)
end)

H.test("title choices use Swedish only for Swedish and English otherwise", function()
    local before=G_reader_settings
    for _, lang in ipairs({"sv","sv_SE","en","de","ja"}) do
        G_reader_settings={readSetting=function() return lang end}
        M.show(widget(),"authors")
        local swedish=lang:sub(1,2)=="sv"
        H.eq(menu.title,(swedish and "Serieboxarnas titel" or "Series box title")..": Authors")
        H.eq(menu.item_table[1].text,swedish and "Under omslaget (standard)" or "Below the cover (default)")
        H.eq(menu.item_table[2].text,swedish and "På omslaget, nedtill" or "On the cover (bottom)")
    end
    G_reader_settings=before
end)

H.test("geometry opt-in and wrappers are idempotent and leave non-box items alone", function()
    local calls=0
    local boxes={geometry=function(book)
        calls=calls+1
        if book.box then return {w=120,h=200,strip_h=20} end
    end}
    M.geometry(boxes); local wrapped=boxes.geometry; M.geometry(boxes)
    H.eq(boxes.geometry,wrapped)
    H.eq(boxes.geometry({box=true},{},{series_title_position="overlay"}).title_on_cover,true)
    H.eq(boxes.geometry({box=true},{},{}).title_on_cover,nil)
    H.eq(boxes.geometry({}, {}, {series_title_position="overlay"}),nil)
    H.eq(calls,3)
    local w=widget(); local plan=w._spinePlanBase; M.widget(w)
    H.eq(w._spinePlanBase,plan)
    local f=assert(io.open("adapters/orbitui_home_shelves.lua"))
    local source=f:read("*a"); f:close()
    assert(source:find('_("Series box title")',1,true))
    assert(source:find('require("adapters/orbitui_series_titles").show(widget, chip)',1,true))
end)

H.finish()
