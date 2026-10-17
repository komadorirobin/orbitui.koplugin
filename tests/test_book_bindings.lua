package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local saved, flushes, rebuilds = {}, 0, 0
package.loaded["lib/bookshelf_settings_store"] = {
    read = function(k) return saved[k] end,
    save = function(k, v) saved[k] = v end,
    flush = function() flushes = flushes + 1 end,
    generation = function() return 1 end,
}
package.loaded["lib/bookshelf_i18n"] = {gettext = function(t) return t end}
local tabs = {authors = {id="authors", label="Authors"}, child = {id="child", label="Child"}}
package.loaded["lib/bookshelf_tab_model"] = { getById = function(id) return tabs[id] end }
local P = require("lib/bookshelf_profiles")
local M = require("adapters/orbitui_book_bindings")
local Labels = require("adapters/orbitui_cover_labels")
local W = H.widget()
local UI = {setDirty=function() end, show=function() end, close=function() end}
package.loaded["ui/uimanager"] = UI
local menu
package.loaded["lib/bookshelf_menu_host"] = {
    show=function(opts) menu=opts; return opts end,
    close=function(host) host.closed=true end,
}
local function widget(profile, chip)
    local w = {profile=P.get(profile), chip=chip or "authors", _drilldown_path={},
        _spinePlanBase=function(_, width, height) return {content_w=width, row_h=height} end,
        _rebuild=function() rebuilds=rebuilds+1 end}
    M.widget(w)
    return w
end

H.test("bindings are opt-in; no initial settings or metadata migration", function()
    H.eq(M.shelf("authors"), "hardcover"); H.eq(M.series("Saga"), nil)
    H.eq(M.resolve({}, {}, {}), "hardcover")
    H.eq(next(saved), nil); H.eq(flushes, 0)
end)

H.test("native, nested, prose and manga shelves remain independent across reloads", function()
    M.save("shelves", "authors", "paperback")
    M.save("shelves", "child", "tankobon")
    local prose, manga = widget("prose"), widget("comics")
    M.save("shelves", Labels.id(prose), "hardcover")
    M.save("shelves", Labels.id(manga), "tankobon")
    package.loaded["adapters/orbitui_book_bindings"] = nil
    M = require("adapters/orbitui_book_bindings")
    H.eq(M.shelf("authors"), "paperback"); H.eq(M.shelf("child"), "tankobon")
    H.eq(M.shelf(Labels.id(prose)), "hardcover")
    H.eq(M.shelf(Labels.id(manga)), "tankobon")
    H.eq(tabs.authors.binding, nil)
end)

H.test("series overrides win everywhere and following the shelf removes only that override", function()
    M.save("series", "Saga", "paperback")
    M.save("series", "Another", "hardcover")
    local a, b = widget("prose"), widget("comics")
    local raw = {filepath="one.epub", series_name="Saga", cover_bb="borrowed"}
    for _, w in ipairs({a, b}) do
        H.eq(M.resolve(raw, raw, w:_spinePlanBase(800, 300)), "paperback")
    end
    H.eq(raw.binding, nil); H.eq(raw.cover_bb, "borrowed")
    M.save("series", "Saga", nil)
    H.eq(M.resolve(raw, raw, a:_spinePlanBase(800, 300)), "hardcover")
    H.eq(M.resolve(raw, raw, b:_spinePlanBase(800, 300)), "tankobon")
    H.eq(M.series("Another"), "hardcover")
end)

H.test("invalid settings fall back without erasing unrelated or unknown values", function()
    saved.orbitui_book_bindings.future = {keep=true}
    saved.orbitui_book_bindings.series.Bad = "unknown"
    saved.orbitui_book_bindings.shelves.bad = false
    local old = saved.orbitui_book_bindings
    local n = flushes
    H.eq(M.save("series", "Saga", "bad"), false)
    H.eq(M.save("series", "", "paperback"), false)
    H.eq(M.save("bad", "Saga", "paperback"), false)
    H.eq(flushes, n)
    H.eq(M.shelf("bad"), "hardcover"); H.eq(M.series("Bad"), nil)
    M.save("series", "Saga", "paperback")
    H.eq(old.series.Saga, nil)
    H.eq(saved.orbitui_book_bindings.future.keep, true)
    H.eq(saved.orbitui_book_bindings.series.Bad, "unknown")
    M.save("series", "Saga", nil)
end)

H.test("drills and pinned series supply the name when a light member lacks metadata", function()
    M.save("series", "Saga", "paperback")
    local w = widget("comics")
    w._drilldown_path = {{kind="series", label="A display label", payload={series_name="Saga"}}}
    H.eq(M.resolve({}, {}, w:_spinePlanBase(800, 300)), "paperback")
    tabs.child.source = {kind="single_series", id="Saga"}
    local pinned = widget(nil, "child")
    H.eq(M.resolve({}, {}, pinned:_spinePlanBase(800, 300)), "paperback")
    w._drilldown_path = {{kind="author", label="Saga"}}
    H.eq(M.resolve({}, {}, w:_spinePlanBase(800, 300)), "tankobon")
    H.eq(M.resolve({series_name="Another"}, {}, w:_spinePlanBase(800, 300)), "hardcover")
end)

-- Load the real planner and painters, only replacing native display services.
local dpi, night = 1, false
local Screen = {scaleBySize=function(_, n) return math.floor(n*dpi+.5) end}
package.loaded.device = {screen=Screen}
package.loaded.logger = {dbg=function() end, warn=function() end}
package.loaded["lib/bookshelf_space"] = {px=function(n) return Screen:scaleBySize(n) end}
package.loaded["lib/bookshelf_night_mode_sync"] = {active=function() return night end}
package.loaded["lib/bookshelf_cover_progress"] = {
    theme=function() return false end, decide=function() return {} end,
}
package.loaded["lib/bookshelf_round_corner"] = {}
for _, name in ipairs({"ui/geometry", "ui/gesturerange", "ui/widget/widget",
        "ui/widget/container/inputcontainer"}) do package.loaded[name] = W end
local Text = W:extend{}
local texts = {}
function Text:init()
    self.dimen={w=math.min(self.max_width or math.huge, #self.text*self.face.size*.5), h=self.face.size}
end
function Text:getSize() return self.dimen end
function Text:paintTo(_bb, x, y)
    texts[#texts+1]={text=self.text, ink=self.fgcolor, x=x, y=y,
        size=self.face.size,w=self.dimen.w,h=self.dimen.h}
end
function Text:free() end
package.loaded["lib/bookshelf_colour_text"] = Text
package.loaded["lib/bookshelf_fonts"] = {
    getFace=function(_, _, size) return {size=size} end, getUIFontFace=function() return "cfont" end,
}
local BB = {COLOR_BLACK="black", COLOR_WHITE="white"}
function BB.ColorRGB32(r,g,b,a) return {r=r,g=g,b=b,a=a} end
local function surface(w,h)
    local bb = {w=w,h=h, rects={}, blits=0}
    function bb:paintRectRGB32(x,y,rw,rh,c)
        assert(x>=0 and y>=0 and rw>=0 and rh>=0 and x+rw<=w and y+rh<=h, "out of bounds")
        self.rects[#self.rects+1]={x=x,y=y,w=rw,h=rh,c=c}
    end
    function bb:blitFrom(src,x,y,_,_,rw,rh)
        local last=src.rects and src.rects[#src.rects]
        self:paintRectRGB32(x,y,rw,rh,last and last.c or {}); self.blits=self.blits+1
    end
    function bb:getWidth() return w end
    function bb:getHeight() return h end
    function bb:getType() return 5 end
    function bb:rotatedCopy() return surface(h,w) end
    function bb:free() end
    return bb
end
BB.new=surface
package.loaded["ffi/blitbuffer"] = BB
package.loaded["lib/bookshelf_book_repository"] = {
    pageCountFor=function(_,pages) return pages end,
    readProgress=function() return 0, nil end,
}
-- No decoration, disk, or cover decoding needed for binding-only planning.
package.loaded["lib/bookshelf_ornaments"] = false
package.preload["lib/bookshelf_ornaments"] = function() error("no test ornaments") end
local Shelf = require("lib/bookshelf_spine_shelf")
M.renderer(Shelf)
local look={r=90,g=115,b=145,aspect=1.5}
Shelf.bookLook=function() return look end
Shelf.prefetchFacts=function() end
Shelf.cachedProgress=function() return nil,nil,true end
Shelf.cachedPageCount=function() return nil end
Shelf.persistProgress=function() end

H.test("shelf and series radios persist, rebuild immediately and allow inheritance", function()
    local w=widget("comics")
    M.showShelf(w,"authors")
    H.eq(#menu.item_table,3); H.eq(menu.item_table[3].checked_func(),true)
    local old, builds=menu,rebuilds
    menu.item_table[2].callback()
    H.eq(old.closed,true); H.eq(rebuilds,builds+1)
    H.eq(M.shelf(Labels.id(w)),"paperback")
    local closed=false
    local button=w:seriesBindingButton("Saga",function() closed=true end)
    button.callback()
    H.eq(closed,true); H.eq(#menu.item_table,4)
    H.eq(menu.item_table[3].checked_func(),true)
    menu.item_table[4].callback()
    H.eq(M.series("Saga"),"tankobon")
    button.callback(); menu.item_table[1].callback()
    H.eq(M.series("Saga"),nil)
    H.eq(M.resolve({series_name="Saga"},{},w:_spinePlanBase(800,300)),"paperback")
end)

H.test("real page plans change binding on warm cache hits without changing book geometry", function()
    local books={{filepath="one.epub",title="One",has_cover=false,series_name="Saga",page_count=250}}
    local opts={content_w=800,row_h=300,n_rows=2,face_out="all",binding_shelf="hardcover",binding_series={}}
    local hard=Shelf.plan(books,opts)
    H.eq(hard.entries[1].binding,"hardcover")
    opts.binding_series.Saga="tankobon"
    local manga=Shelf.plan(books,opts)
    H.eq(manga.entries[1].binding,"tankobon")
    H.eq(manga.entries[1].w,hard.entries[1].w); H.eq(manga.entries[1].h,hard.entries[1].h)
    opts.binding_series.Saga=nil; opts.binding_shelf="paperback"
    local pocket=Shelf.plan(books,opts)
    H.eq(pocket.entries[1].binding,"paperback")
    H.eq(books[1].binding,nil)
end)

local function slot(style, title)
    local entry={w=30*dpi,h=200*dpi,look=look,binding=style,w_dp=30,ref_w_dp=22,
        label=title or "",series_num="2"}
    return Shelf._SpineBookSlot:new{entry=entry,book={},width=entry.w,height=entry.h,
        show_status=false,show_series=true}
end
local function upvalue(fn,name)
    for i=1,100 do
        local key,value=debug.getupvalue(fn,i)
        if not key then break end
        if key==name then return value end
    end
    error("missing upvalue "..name)
end
local Top=upvalue(Shelf.rowWidget,"FaceOutTopBlock")

H.test("soft spines and face-out page blocks paint within bounds at multiple DPI", function()
    for _,scale in ipairs({1,1.5,2,3}) do
        dpi=scale
        for _,dark in ipairs({false,true}) do
            night=dark
            for _,style in ipairs({"hardcover","paperback","tankobon"}) do
                local s=slot(style)
                local bb=surface(s.width,s.height)
                s:_renderIntoAt(bb,0,0,night)
                assert(#bb.rects>0)
                local top=Top:new{dimen={w=120*dpi,h=8*dpi},look=look,binding=style}
                top:paintTo(surface(top.dimen.w,top.dimen.h),0,0)
                H.eq(look.binding_skin,nil)
            end
        end
    end
    dpi,night=1,false
end)

H.test("paperback has no board overhang; manga has a light jacket and dark legible text", function()
    local renders={}
    for _,style in ipairs({"hardcover","paperback","tankobon"}) do
        local s=slot(style); local bb=surface(s.width,s.height)
        texts={}; s:_renderIntoAt(bb,0,0,false)
        renders[style]=bb
        H.eq(texts[1].ink,style=="tankobon" and "black" or "white")
        local head_paper=false
        for _,rect in ipairs(bb.rects) do
            if rect.y==0 and rect.w>5 then head_paper=true end
        end
        H.eq(head_paper,style~="hardcover")
    end
    local hard,pocket,manga=renders.hardcover,renders.paperback,renders.tankobon
    assert(manga.rects[1].c.r>pocket.rects[1].c.r)
    assert(math.abs(pocket.rects[30].c.r-pocket.rects[1].c.r)
        < math.abs(hard.rects[30].c.r-hard.rects[1].c.r))
    local s=slot("tankobon"); texts={}; s:_renderIntoAt(surface(s.width,s.height),0,0,true)
    H.eq(texts[1].ink,"white") -- pre-inverted, still dark on the displayed jacket
end)

H.test("Latin and Japanese spine titles use the matching jacket background and ink", function()
    for _,title in ipairs({"A modern book", "\227\129\178\227\130\137\227\129\140\227\129\170"}) do
        local s=slot("tankobon",title); texts={}
        local bb=surface(s.width,s.height); s:_renderIntoAt(bb,0,0,false)
        assert(#texts>1, "title painting failed")
        for _,text in ipairs(texts) do H.eq(text.ink,"black") end
    end
end)

H.test("render cache includes binding, count suppression and compact head geometry", function()
    local s=slot("hardcover")
    local key=s:_renderKey(false)
    s.entry.binding="paperback"; assert(key~=s:_renderKey(false))
    key=s:_renderKey(false); s.top_edge_cap=12; assert(key~=s:_renderKey(false))
    key=s:_renderKey(false); s.show_status=true; assert(key~=s:_renderKey(false))
end)

H.test("real box member spines inherit the series binding without mutating shared records", function()
    local Cover=W:extend{}
    function Cover:paintTo(bb,x,y) bb:paintRectRGB32(x,y,self.width,self.height,{r=80,g=90,b=100}) end
    function Cover:free() end
    Cover.CARD_BORDER=1
    package.loaded["lib/bookshelf_spine_widget"]=Cover
    package.loaded["lib/bookshelf_image_source"]={resolveStackImage=function() end}
    local Boxes=require("lib/bookshelf_series_boxes")
    local Box=require("lib/bookshelf_series_box_widget")
    local adapter=require("adapters/orbitui_ui")
    adapter.wrap("lib/bookshelf_series_boxes",Boxes)
    adapter.wrap("lib/bookshelf_series_box_widget",Box)
    for _,style in ipairs({"hardcover","paperback","tankobon"}) do
        for _,n in ipairs({2,3,8,120}) do
            local members={}
            for i=1,n do members[i]={filepath="member"..i,has_cover=true,series_name="Saga",series_num=i} end
            local book=Boxes.box(members,"Saga")
            local shape=Boxes.geometry(book,{w=160,h=248,aspect=1.5},{row_h=300,content_w=800})
            local box=Box:new{entry={book=book,series_box=shape,binding=style},width=shape.w,height=300}
            for _,member in ipairs(box.slots) do
                H.eq(member.slot.entry.binding,style)
                H.eq(member.slot.show_status,false)
                H.eq(member.slot.top_edge_cap,shape.wall_top)
            end
            texts={}
            box:paintTo(surface(box.width,box.height),0,0)
            assert(#texts>=2) -- read count and series name
            for _,member in ipairs(members) do H.eq(member.binding,nil) end
        end
    end
end)

local function packedBox(n,style,scale)
    local Boxes=require("lib/bookshelf_series_boxes")
    local Box=require("lib/bookshelf_series_box_widget")
    local members={}
    for i=1,n do members[i]={filepath="member"..i..".cbz",page_count=200,
        has_cover=true,series_name="Saga",series_num=i} end
    local book=Boxes.box(members,"Saga")
    scale=scale or 1
    local shape=Boxes.geometry(book,{w=160*scale,h=248*scale,aspect=1.5},
        {row_h=300*scale,content_w=800*scale})
    return Box:new{entry={book=book,series_box=shape,binding=style},width=shape.w,height=300*scale}
end

local function pixel(bb,x,y)
    local colour
    for _,r in ipairs(bb.rects) do
        if r.x<=x and r.y<=y and r.x+r.w>x and r.y+r.h>y then colour=r.c end
    end
    return colour
end

H.test("real book heads leave a recessed continuous interior and untouched air above", function()
    local interior={}
    for _,dark in ipairs({false,true}) do
        night=dark
        for _,style in ipairs({"hardcover","paperback","tankobon"}) do
            local box=packedBox(2,style)
            local g=box.shape
            H.eq(#box.slots,2); H.eq(box.more,nil)
            assert(g.occupied_w<g.w-2*g.wall)
            local bb=surface(box.width,box.height); texts={}; box:paintTo(bb,0,0)
            local gx=g.wall+g.occupied_w+2
            local wy=box.top+g.rise-g.wall_top
            H.eq(pixel(bb,gx,wy-1),nil,"air above the empty box was filled")
            local c=pixel(bb,gx,wy+1); assert(c and c.r)
            interior[dark and "night" or "day"]=c
            H.eq(bb.blits,1)
        end
    end
    assert(math.abs(interior.day.r+interior.night.r-255)<=1)
    assert(math.abs(interior.day.g+interior.night.g-255)<=1)
    assert(math.abs(interior.day.b+interior.night.b-255)<=1)
    night=false
end)

H.test("overflow and read labels remain separate above real bound spines at small sizes", function()
    for _,factor in ipairs({1,1.5,2}) do
        dpi=factor
        for _,scale in ipairs({.5,1,1.5}) do
            for _,dark in ipairs({false,true}) do
                night=dark
                local box=packedBox(120,"tankobon",scale)
                H.eq(box.more.text,"+"..(120-#box.slots))
                local bb=surface(box.width+40,box.height+20)
                texts={}; box:paintTo(bb,20,10)
                local count,more
                for _,t in ipairs(texts) do
                    if t.text==box.count.text then count=t end
                    if t.text==box.more.text then more=t end
                end
                assert(count and more,"a label was silently lost")
                assert(more.x+more.w<count.x)
                H.eq(more.y,count.y)
                assert(count.x+count.w<=20+box.width)
                assert(count.y+count.h<10+box.top+box.shape.rise)
                H.eq(bb.blits,1)
            end
        end
    end
    dpi,night=1,false
end)

-- Optional generated shape preview from the real paint calls (not device fonts).
local preview=os.getenv("ORBITUI_BINDING_PREVIEW")
if preview then
    local out=assert(io.open(preview,"w"))
    out:write('<svg xmlns="http://www.w3.org/2000/svg" width="750" height="550" viewBox="0 0 750 550">')
    out:write('<rect width="750" height="550" fill="#f1ede4"/>')
    for i,style in ipairs({"hardcover","paperback","tankobon"}) do
        local bb=surface(180,230)
        slot(style):_renderIntoAt(bb,10,20,false)
        Top:new{dimen={w=120,h=14},look=look,binding=style}:paintTo(bb,55,20)
        bb:paintRectRGB32(55,34,120,186,{r=90,g=115,b=145})
        out:write(string.format('<g transform="translate(%d,70) scale(1.2)">',(i-1)*245+15))
        for _,r in ipairs(bb.rects) do
            if r.c.r then
                out:write(string.format('<rect x="%g" y="%g" width="%g" height="%g" fill="rgb(%d,%d,%d)"/>',
                    r.x,r.y,r.w,r.h,r.c.r,r.c.g,r.c.b))
            end
        end
        out:write('</g>')
        out:write(string.format('<text x="%d" y="400" font-size="22" fill="#202830">%s</text>',
            (i-1)*245+20,style))
    end
    out:write('</svg>'); out:close()
end

local box_preview=os.getenv("ORBITUI_BOX_FILL_PREVIEW")
if box_preview then
    local out=assert(io.open(box_preview,"w"))
    local function esc(s) return s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;") end
    out:write('<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="780" viewBox="0 0 1000 780">')
    out:write('<rect width="1000" height="780" fill="#f1ede4"/>')
    out:write('<text x="30" y="30" font-size="18" fill="#202830">Native paint calls; placeholder covers and approximate fonts</text>')
    for row,style in ipairs({"tankobon","paperback"}) do
        for col,n in ipairs({2,6,12,120}) do
            local box=packedBox(n,style)
            local bb=surface(box.width,box.height)
            texts={}; box:paintTo(bb,0,0)
            local x,y=(col-1)*240+30,(row-1)*360+50
            out:write(string.format('<g transform="translate(%d,%d)">',x,y))
            out:write('<rect x="-12" y="300" width="210" height="12" fill="#b1a08a"/>')
            for _,r in ipairs(bb.rects) do
                if r.c.r then
                    out:write(string.format('<rect x="%g" y="%g" width="%g" height="%g" fill="rgb(%d,%d,%d)"/>',
                        r.x,r.y,r.w,r.h,r.c.r,r.c.g,r.c.b))
                end
            end
            for _,t in ipairs(texts) do
                if t.text==box.count.text or (box.more and t.text==box.more.text) or t.text=="Saga" then
                    local c=t.ink
                    out:write(string.format('<text x="%g" y="%g" font-size="%g" textLength="%g" lengthAdjust="spacingAndGlyphs" fill="rgb(%d,%d,%d)">%s</text>',
                        t.x,t.y+t.size*.8,t.size,t.w,c.r,c.g,c.b,esc(t.text)))
                end
            end
            out:write(string.format('<text x="0" y="340" font-size="17" fill="#202830">%s / %d volumes</text>',style,n))
            out:write('</g>')
        end
    end
    out:write('</svg>'); out:close()
end

H.finish()
