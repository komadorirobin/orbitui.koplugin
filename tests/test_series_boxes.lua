package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Boxes = require("core/orbitui_series_boxes")
local Adapter = require("adapters/orbitui_series_boxes")
package.loaded["lib/bookshelf_settings_store"] = {read=function() end, generation=function() return 0 end}
package.loaded["lib/bookshelf_i18n"] = {gettext=function(s) return s end}

local function source(file)
    local f = assert(io.open("components/bookshelf/lib/" .. file .. ".lua"))
    local text = f:read("*a"); f:close(); return text
end
local function compile(code, env)
    setmetatable(env, {__index=_G})
    if setfenv then local f=assert(loadstring(code)); setfenv(f, env); return f end
    return assert(load(code, "series boxes", "t", env))
end
local shelf_source, widget_source = source("bookshelf_spine_shelf"), source("bookshelf_widget")
local flat_body = assert(shelf_source:match("function SpineShelf%._flattenItems%(items%)\n(.-)\nend"))
local native_flatten = compile("return function(items)\n" .. flat_body .. "\nend", {})()
local function nativeMethod(name, env)
    local args, body = widget_source:match("function BookshelfWidget:" .. name .. "%((.-)%)\n(.-)\nend")
    assert(body, name)
    return compile("return function(self" .. (args ~= "" and ("," .. args) or "")
        .. ")\n" .. body .. "\nend", env or {})()
end
local function book(n, series, dir)
    return {filepath=(dir or "/books") .. "/" .. tostring(n) .. ".epub", filename=tostring(n)..".epub",
        title="Book "..n, series_name=series, series_num=tostring(n), author="Vilhelm Moberg",
        has_cover=true, shelf_section_path=dir}
end
local function members(n, name)
    local out={}; for i=1,n do out[i]=book(i,name) end; return out
end

H.test("loose metadata series become one box in place without changing source records", function()
    local a, b = book(4,"Utvandrarna"), book(1,"Utvandrarna")
    a.cover_bb = "borrowed"
    local single = book(0)
    local raw={single,a,b}
    local out=Boxes.prepare(raw)
    H.eq(#out,2); H.eq(out[1],single)
    local box=out[2]
    assert(Boxes.isBox(box)); H.eq(#box.books,2); H.eq(box.first_book.filepath,b.filepath)
    H.eq(box.books[2].filepath,a.filepath); H.eq(box.books[2].cover_bb,nil)
    H.eq(box.filepath,nil); H.eq(box.series_num,nil); H.eq(box.title,"Utvandrarna")
    H.eq(#raw,3); H.eq(raw[2],a); H.eq(a.cover_bb,"borrowed"); H.eq(a._orbitui_series_box,nil)
    H.eq(require("core/orbitui_author_ornaments").authorOf({book=box}),nil)
    box.author="James Joyce"
    H.eq(require("core/orbitui_author_ornaments").authorOf({book=box}),"james joyce")
end)

H.test("grouped series preserve all volumes, remove duplicates and use numeric order", function()
    local raw={series_name="Saga", books={book(10,"Saga"),book(2,"Saga"),book(2,"Saga"),book(1,"Saga")}}
    local box=Boxes.prepare({raw})[1]
    H.eq(#box.books,3); H.eq(box.first_book.series_num,"1")
    H.eq(box.books[2].series_num,"2"); H.eq(box.books[3].series_num,"10")
    H.eq(#raw.books,4); H.eq(raw.books[1].series_num,"10")
    H.eq(Boxes.prepare({box})[1],box)
end)

H.test("metadata-free folders, distinct sections and standalone books are not merged", function()
    local a,b=book(1),book(2)
    a.shelf_section,b.shelf_section="Fiction","Fiction"
    local out=Boxes.prepare({a,b,book(1,"Saga","/one"),book(2,"Saga","/two")})
    H.eq(#out,4); H.eq(out[1],a); H.eq(out[2],b)
    H.eq(#out[3].books,1); H.eq(#out[4].books,1)
end)

H.test("author shelves retain raw membership and compact only their display list", function()
    local raw={kind="author",series_name="Moberg",books={book(0),book(1,"Saga"),book(2,"Saga")}}
    local group=Boxes.prepare({raw})[1]
    H.eq(group.books,raw.books); H.eq(#group.books,3)
    H.eq(#group._orbitui_display_books,2)
    local flat=Boxes.flatten(native_flatten,{group})
    H.eq(#flat,2); H.eq(flat[1].book,raw.books[1]); H.eq(flat[2].item,group)
    assert(Boxes.isBox(flat[2].book)); H.eq(flat[2].section_label,nil)
    H.eq(Boxes.displayCount(group),2)
    H.eq(#native_flatten({raw}),3) -- standalone component remains native
end)

H.test("boxes flatten to a single drillable item with unchanged item indices", function()
    local items=Boxes.prepare({{series_name="Saga",books=members(80,"Saga")},book(0)})
    local flat=Boxes.flatten(native_flatten,items)
    H.eq(#flat,2); H.eq(flat[1].book,items[1]); H.eq(flat[1].item_idx,1)
    H.eq(flat[2].item_idx,2); H.eq(flat[1].section_label,nil)
    H.eq(#flat[1].book.books,80); H.eq(Boxes.displayCount(items[1]),1)
end)

H.test("depth grows monotonically, is capped, and preserves the true volume count", function()
    local previous=0
    for _, n in ipairs({1,2,4,6,10,40,500}) do
        local box=Boxes.box(members(n,"Saga"),"Saga")
        local g=Boxes.geometry(box,{w=200,h=290,face_h=280,depth=10},{content_w=1000})
        assert(g.side>=previous and g.side<=60)
        H.eq(g.cover_w,200); H.eq(g.w,g.cover_w+g.side); H.eq(g.count,n)
        H.eq(g.face_h,280); H.eq(g.h,290)
        if n>=10 then H.eq(g.side,60) end
        previous=g.side
    end
    H.eq(Boxes.geometry(book(1),{},{content_w=1000}),nil)
end)

H.test("narrow screens and cover-size changes share bounded aspect-preserving geometry", function()
    local box=Boxes.box(members(50,"Saga"),"Saga")
    for _, dpi in ipairs({1,2,3}) do
        for _, size in ipairs({.5,1,1.5}) do
            for _, width in ipairs({90,250,800}) do
                local base={w=200*dpi*size,h=290*dpi*size,face_h=280*dpi*size,depth=10*dpi*size}
                local g=Boxes.geometry(box,base,{content_w=width*dpi})
                assert(g.w<=width*dpi and g.h<=base.h)
                assert(math.abs(g.face_h/g.cover_w-1.4)<.04)
            end
        end
    end
end)

local tab
package.loaded["lib/bookshelf_tab_model"]={getById=function() return tab end}
local repo={lightMetaFor=function() return nil end,
    applyFilter=function(books) local out={} for _,b in ipairs(books) do
        if tonumber(b.series_num)%2==0 then out[#out+1]=b end
    end return out end}
package.loaded["lib/bookshelf_book_repository"]=repo
local function widget(raw)
    local w={_isSpineMode=function() return true end,_drilldown_path={},_cursor=1,
        _fetchChipItems=function() return raw,#raw end,
        _applyWithinGroupSort=function() end,
        _jumpScanList=function() return raw,"title","native" end,
        _serializeDrillPath=nativeMethod("_serializeDrillPath"),
        _restoreDrillPath=nativeMethod("_restoreDrillPath",{Repo=repo}),
        _profileScope=function() return {roots={"/books"}} end}
    Adapter.widget(w)
    return w
end

H.test("full-list grouping, jump indices and footer count the same visible slots", function()
    local raw={book(0),book(1,"Saga"),book(2,"Saga"),book(3,"Saga"),book(5)}
    local w=widget(raw)
    local items=w:prepareSpineItems(raw,#raw)
    local scan,key=w:_jumpScanList()
    H.eq(#items,3); H.eq(#scan,3); H.eq(key,"title")
    H.eq(scan[2].series_name,items[2].series_name)
    w._spineSkip=function() return 0 end
    w._cursor=3
    nativeMethod("_spineUpdateBookCounts")(w,items,nil)
    H.eq(w._spine_books_total,3); H.eq(w._spine_books_before,2)
end)

H.test("the full list is compacted before cache signatures and page planning", function()
    local raw={book(0),book(1,"Saga"),book(2,"Saga")}
    local w=widget(raw)
    w.chip="fiction"
    w._spineItemsSig=function(_,items) H.eq(#items,2); return "two" end
    local fetch=nativeMethod("_spineCachedFetch")
    local items,hint=fetch(w,400)
    H.eq(#items,2); H.eq(hint,nil); H.eq(w._spine_fetch_cache.items,items)
    H.eq(fetch(w,400),items)
end)

H.test("a series drill exposes every volume without immediately boxing them again", function()
    local box=Boxes.box(members(120,"Saga"),"Saga")
    local w=widget({})
    w._drilldown_path={{kind="series",payload=box,label="Saga"}}
    local items,total=w:_fetchChipItems(8,true)
    H.eq(#items,120); H.eq(total,120)
    H.eq(w:prepareSpineItems(items,total),items)
    tab={filter={}}
    local filtered=w:_fetchChipItems(8,true)
    H.eq(#filtered,60); H.eq(#box.books,120)
    w._drilldown_path[1].whole=true
    H.eq(#w:_fetchChipItems(8,true),120)
    tab=nil
end)

H.test("grid, search, remote feeds and incomplete windows are not compacted", function()
    local raw={book(1,"Saga"),book(2,"Saga")}
    local w=widget(raw)
    H.eq(w:prepareSpineItems(raw,900),raw)
    w._isSpineMode=function() return false end
    H.eq(w:prepareSpineItems(raw,2),raw)
    w._isSpineMode=function() return true end
    for _,kind in ipairs({"search","opds_nav"}) do
        w._drilldown_path={{kind=kind}}
        H.eq(w:prepareSpineItems(raw,2),raw)
    end
    w._drilldown_path={}; w._opdsEffectiveTab=function() return {} end
    H.eq(w:prepareSpineItems(raw,2),raw)
end)

H.test("restored boxes intersect current membership with their original filtered scope", function()
    local w=widget({})
    w._drilldown_path={{kind="series",label="Saga",payload=Boxes.box({book(2,"Saga"),book(4,"Saga")},"Saga")}}
    local saved=w:_serializeDrillPath()
    H.eq(#saved[1].orbitui_series_files,2); H.eq(saved[1].books,nil)
    repo.findGroup=function(kind,label,scope)
        H.eq(kind,"series"); H.eq(scope.roots[1],"/books")
        return {series_name=label,books={book(1,"Saga"),book(2,"Saga"),book(3,"Saga")}}
    end
    w._drilldown_path={}; w:_restoreDrillPath(saved)
    local restored=w._drilldown_path[1].payload
    H.eq(#restored.books,1); H.eq(restored.books[1].series_num,"2")
    H.eq(Boxes.isBox(restored),true)
    H.eq(#w:_serializeDrillPath()[1].orbitui_series_files,1)
    repo.findGroup=function() return {series_name="Saga",books={book(99,"Saga")}} end
    w._drilldown_path={}; w:_restoreDrillPath(saved)
    H.eq(#w._drilldown_path[1].payload.books,0)
    local empty=w:_serializeDrillPath()
    H.eq(#empty[1].orbitui_series_files,0)
    w._drilldown_path={}; w:_restoreDrillPath(empty)
    H.eq(#w._drilldown_path[1].payload.books,0)
end)

-- Render the production widget against a bounded drawing surface. Record all
-- rectangles and text, and fail if geometry touches another slot or the dock.
local W=H.widget()
function W:getSize() return self.dimen or {w=self.width or 0,h=self.height or 0} end
function W:paintTo(bb,x,y) bb:paintRect(x,y,self.width,self.height,"cover") end
local Text=W:extend{}
function Text:init()
    self.dimen={w=math.max(1,math.min(self.max_width or 100,#self.text*5)),h=12}
end
function Text:paintTo(bb,x,y) bb:paintRect(x,y,self.dimen.w,self.dimen.h,"text:"..self.text) end
for _,name in ipairs({"ui/widget/container/inputcontainer","ui/geometry","ui/gesturerange"}) do
    package.loaded[name]=W
end
package.loaded["ui/widget/textwidget"]=Text
package.loaded["device"]={screen={scaleBySize=function(_,n) return n end}}
package.loaded["ffi/blitbuffer"]={ColorRGB32=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end}
package.loaded["lib/bookshelf_fonts"]={getFace=function() return {} end}
package.loaded["ffi/util"]={template=function(s,n) return (s:gsub("%%1",tostring(n))) end}
package.loaded["lib/bookshelf_spine_widget"]=W
local BoxWidget=require("core/orbitui_series_box_widget")

H.test("box painting stays inside its planned width and above the plank at every size", function()
    for _,size in ipairs({.5,1,1.5}) do
        for _,n in ipairs({1,4,40}) do
            local box=Boxes.box(members(n,"Saga"),"Saga")
            local shape=Boxes.geometry(box,{w=160*size,face_h=240*size,depth=8,h=240*size+8},{content_w=800})
            local entry={book=box,series_box=shape,w=shape.w,look={r=90,g=120,b=80}}
            for _,night in ipairs({false,true}) do
                G_reader_settings={isTrue=function() return night end,readSetting=function() return "sv" end}
                local w=BoxWidget:new{entry=entry,width=shape.w,height=410,inset=10}
                local texts,rects={},0
                local bb={paintRect=function(_,x,y,rw,rh,c)
                    assert(x>=20 and x+rw<=20+shape.w and y>=30 and y+rh<=430,
                        "paint overflow: "..table.concat({x,y,rw,rh},","))
                    assert(rw>0 and rh>=0)
                    if type(c)=="string" and c:match("^text:") then texts[c]=true end
                    rects=rects+1
                end}
                w:paintTo(bb,20,30)
                H.eq(w.dimen.x,20); H.eq(w.dimen.y,30)
                assert(texts["text:"..n..(n==1 and " del" or " delar")])
                assert(rects<shape.side+15)
                H.eq(entry._drawn_h,shape.h)
                H.eq(w.ges_events.Tap[1].range,w.dimen)
            end
        end
    end
end)

H.test("tap and double-tap open the series, hold uses its menu, never opens a book", function()
    local box=Boxes.box(members(4,"Saga"),"Saga")
    local shape=Boxes.geometry(box,{w=160,face_h=240,depth=8,h=248},{content_w=800})
    local taps,holds=0,0
    local w=BoxWidget:new{entry={book=box,series_box=shape},width=shape.w,height=300,inset=10,
        callbacks={on_series_tap=function(g) H.eq(g,box); taps=taps+1 end,
            on_series_hold=function(g) H.eq(g,box); holds=holds+1 end,
            on_book_tap=function() error("Must not open the representative book") end}}
    H.eq(w:onTap(),true); H.eq(w:onDoubleTap(),true); H.eq(w:onHold(),true)
    H.eq(taps,2); H.eq(holds,1); H.eq(w[1].on_tap,nil)
end)

H.finish()
