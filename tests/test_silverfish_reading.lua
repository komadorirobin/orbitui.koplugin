local root=os.getenv("ORBITUI_TEST_ROOT") or "."
package.path=root.."/?.lua;./?.lua;"..package.path
local H=require("tests/helpers")
local M=require("adapters/orbitui_silverfish")
local Model=require("core/orbitui_dashboard")
local now=1800000000
local pet, active, rows, paints, opens, reads, covers, ready, warnings, measured_title_h
local sandbox
local loader=os.getenv("ORBITUI_NATIVE_PLUGIN_LOADER")
if loader then
    local f=assert(io.open(loader));local source=f:read("*a");f:close()
    local code=assert(source:match("(local HandlerSandbox = { mt = {} }.-)\nlocal PluginLoader ="))
    sandbox=assert((loadstring or load)("local dbg={}; local logger={err=function() end};\n"..code.."\nreturn sandboxPluginEventHandlers"))()
end
local function sandboxPet()
    if sandbox then sandbox(pet);return end
    local original=pet.onMostrarTraca
    pet.onMostrarTraca=setmetatable({}, {__call=function(_,instance,...) return original(instance,...) end})
end
local function copy(t)
    if type(t)~="table" then return t end
    local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
package.loaded.logger={warn=function() warnings=(warnings or 0)+1 end,dbg=function() end}
local function reset()
    paints, opens, reads, covers, warnings=0,0,0,0,0
    measured_title_h=nil
    active={id="gato"}
    pet={estado={especie="gato",nome="Franz 日本語",letras=5000,barriga=80,humor=80,
        nascimento=now-86400*4,geracao=2,livro_corrente="Wrong stale title",ultimo_arquivo="/wrong",
        livros={A={terminado=true},B={terminado=true},C={terminado=false}},meus_livros={A=true}},
        onMostrarTraca=function() opens=opens+1 end,
        salvar=function() error("must not save pet") end}
    rows={};for i=1,64 do rows[i]=i>=20 and i<=50 and string.rep(" ",20)..string.rep("#",24)..string.rep(" ",20) or string.rep(" ",64) end
    package.loaded["ui/screensaver"]={traca_instancia=pet}
    package.loaded.traca_versao={numero="2.0.0",publica=true}
    package.loaded.traca_species={current=function() return active end,texto=function() return "Ash Cat" end}
    package.loaded.traca_estado={fase=function() return {nome="filhote"} end,sprite=function() return "filhote_normal" end,
        passarTempo=function() error("must not advance pet") end}
    package.loaded.traca_desenho={LARGURA=64,ALTURA=64,sprite=function() return rows end,
        pintarSprite=function() paints=paints+1 end}
end
H.test("card is opt-in and registry installation writes no settings, initializes no plugin and preserves other modules",function()
    reset();local mods,writes={currently={keep=true}},0
    package.loaded["infra/sui_store"]={saveSetting=function() writes=writes+1 end}
    local r={register=function(m) mods[m.id]=m end}
    M.install(r);M.install(r)
    H.eq(mods[M.id],M);H.eq(mods.currently.keep,true);H.eq(M.default_on,false)
    H.eq(M.needs.recent,1);H.eq(M.has_covers,true);H.eq(writes,0)
    local c=Model.config();H.eq(#c.modules,0);H.eq(Model.visible(c,"hero"),true)
end)
H.test("snapshot reads the active cat without changing save data, clocks, book state or species",function()
    reset();local before=copy(pet.estado)
    local s=assert(M.snapshot(now))
    H.eq(s.name,"Franz 日本語");H.eq(s.species,"gato");H.eq(s.stage,"Ash Cat · Kitten")
    H.eq(s.days,5);H.eq(s.finished,1);H.eq(s.generation,2)
    H.eq(s.bounds[1],20);H.eq(s.bounds[2],19);H.eq(s.bounds[3],24);H.eq(s.bounds[4],31)
    H.eq(M.current(s),true);assert(equal(pet.estado,before));H.eq(paints,0)
    active={id="traca"};pet.estado.especie=nil
    package.loaded.traca_estado.fase=function() return {nome="ovo"} end
    H.eq(assert(M.snapshot(now)).stage,"Silverfish · Egg")
end)
H.test("KOReader sandboxed event handlers are accepted without unwrapping or calling them during snapshot",function()
    reset();sandboxPet()
    H.eq(type(pet.onMostrarTraca),"table")
    local wrapped=pet.onMostrarTraca
    local before=copy(pet.estado)
    local s=assert(M.snapshot(now));assert(M.current(s));H.eq(opens,0)
    H.eq(pet.onMostrarTraca,wrapped);assert(equal(before,pet.estado))
    pet.onMostrarTraca={};H.eq(M.current(s),false)
    local absent,reason=M.snapshot(now);H.eq(absent,nil);assert(reason)
end)
H.test("missing, unreviewed, mismatched, failed and malformed pet APIs give a reason without loading anything",function()
    for _,why in ipairs{"missing","future","private","method","species","phase","rows","blank"} do
        reset()
        if why=="missing" then package.loaded["ui/screensaver"]=nil
        elseif why=="future" then package.loaded.traca_versao.numero="2.1.0"
        elseif why=="private" then package.loaded.traca_versao.publica=false
        elseif why=="method" then package.loaded.traca_desenho.pintarSprite=nil
        elseif why=="species" then active={id="traca"}
        elseif why=="phase" then package.loaded.traca_estado.fase=function() error("not ready") end
        elseif why=="rows" then rows[1]="wrong size"
        else for i=1,64 do rows[i]=string.rep(" ",64) end end
        local s,reason=M.snapshot(now);H.eq(s,nil);assert(type(reason)=="string" and #reason>0,why)
        H.eq(paints,0);H.eq(opens,0)
    end
end)
H.test("snapshots retire on plugin/state/species replacement or an unreviewed version change",function()
    for _,why in ipairs{"pet","state","species","version","private","state_species","draw"} do
        reset();local s=assert(M.snapshot(now))
        if why=="pet" then package.loaded["ui/screensaver"].traca_instancia={}
        elseif why=="state" then pet.estado=copy(pet.estado)
        elseif why=="species" then active={id="traca"}
        elseif why=="version" then package.loaded.traca_versao.numero="3.0.0"
        elseif why=="private" then package.loaded.traca_versao.publica=false
        elseif why=="state_species" then pet.estado.especie="traca"
        else package.loaded.traca_desenho={} end
        H.eq(M.current(s),false)
    end
end)
H.test("all geometry is bounded in half/full, portrait/landscape and tiny viewports",function()
    for _,size in ipairs{{1264,520},{600,320},{300,200},{1680,430},{120,90},{1,1}} do
        local p=M.plan(size[1],size[2]);local previous
        for _,key in ipairs{"pet","book","cover"} do
            local r=p[key]
            assert(r.x>=0 and r.y>=0 and r.w>0 and r.h>0)
            assert(r.x+r.w<=p.w and r.y+r.h<=p.h,key)
            if previous and size[1]>=120 then assert(previous.x+previous.w<=r.x) end
            previous=r
        end
    end
end)
H.test("composition keeps a full-height creature left, a centered text stack and the cover right without intersections",function()
    for _,size in ipairs{{1236,200,2},{1236,250,2},{1236,300,2},{1236,400,2},{1236,660,2},{600,300,2},{1680,430,2},{300,200,1}} do
        local p=M.plan(size[1],size[2],size[3]);assert(p.readable)
        assert(p.pet.x+p.pet.w<p.book.x)
        assert(p.book.x+p.book.w<p.cover.x)
        assert(p.pet.h>=p.cover.h,"name must not reduce the creature's height")
        assert(math.abs(p.pet.y+p.pet.h/2-(p.cover.y+p.cover.h/2))<=1)
        assert(math.abs(p.pet.y+p.pet.h/2-(p.book.y+p.book.h/2))<=1)
        local function separate(a,b)
            return a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y
        end
        local keys={"name","stage","title","author","percent","metrics","bar"}
        for i,key in ipairs(keys) do
            local r=p[key]
            if r then
                assert(r.x>=p.book.x and r.x+r.w<=p.book.x+p.book.w,key)
                assert(r.y>=p.book.y and r.y+r.h<=p.book.y+p.book.h,key)
                for j=1,i-1 do if p[keys[j]] then assert(separate(r,p[keys[j]]),key.." overlaps "..keys[j]) end end
            end
        end
    end
    local p=M.plan(1236,300,2)
    assert(p.pet.h>=240);H.eq(p.title_lines,1);assert(p.author)
    H.eq(M.plan(1236,400,2).title_lines,2)
    H.eq(M.plan(1236,250,2).author,nil)
    H.eq(M.plan(1236,200,2).companion,nil)
end)

-- Actual bounded container and optional minimum/current native input + FFI
-- buffers. Text/cover service boundaries are deterministic fixtures.
local W=H.widget()
function W:getSize() return self.dimen or {w=self.width or 1,h=self.height or 1} end
function W:paintTo(bb,x,y)
    self.dimen=self.dimen or self:getSize();self.dimen.x,self.dimen.y=x,y
    for _,c in ipairs(self) do local o=c.overlap_offset or {0,0};c:paintTo(bb,x+o[1],y+o[2]) end
end
function W:free()
    assert(not self.freed,"double free");self.freed=true
    for _,c in ipairs(self) do c:free() end
end
local native_bb=os.getenv("ORBITUI_NATIVE_BB_DIR")
local BB
if native_bb then
    package.path=native_bb.."/?.lua;"..package.path
    local ffi=require("ffi");ffi.cdef[[void *malloc(size_t); void *calloc(size_t,size_t); void free(void *);]]
    package.loaded["ffi/posix_h"]=true
    package.loaded["ffi/util"]={idiv=function(a,b) return math.floor(a/b) end}
    ffi.loadlib=function(name) return ffi.load(os.getenv("ORBITUI_NATIVE_BB_LIB") or name) end
    BB=require("ffi/blitbuffer")
else
    BB={COLOR_BLACK=0,COLOR_WHITE=255,COLOR_GRAY=128,COLOR_DARK_GRAY=80,COLOR_LIGHT_GRAY=200}
    function BB.new(w,h,t) return {getType=function() return t or 1 end,fill=function() end,
        blitFrom=function() end,free=function() end} end
end
package.loaded["ffi/blitbuffer"]=BB
for _,name in ipairs{"ui/widget/widget","ui/geometry","ui/gesturerange","ui/widget/overlapgroup",
    "ui/widget/container/widgetcontainer","ui/widget/container/inputcontainer","ui/widget/container/framecontainer"} do package.loaded[name]=W end
local Input=W
local screen={getWidth=function() return 1264 end,getHeight=function() return 1680 end,
    scaleBySize=function(_,n) return n end}
package.loaded.device={hasKeys=function() return false end,screen=screen}
package.loaded["ui/event"]={new=function(_,name,...) return {handler="on"..name,args={n=select("#",...),...}} end}
package.loaded["ui/uimanager"]={}
local native_input=os.getenv("ORBITUI_NATIVE_INPUT_DIR")
if native_input then
    local Base=W:extend{}
    function Base:handleEvent(event)
        local fn=self[event.handler]
        if fn then return fn(self,(unpack or table.unpack)(event.args,1,event.args.n or #event.args)) end
    end
    package.loaded["ui/widget/widget"],package.loaded.depgraph=Base,{}
    package.loaded.gettext=function(s) return s end
    package.loaded["ui/widget/container/widgetcontainer"]=assert(loadfile(native_input.."/widgetcontainer.lua"))()
    Input=assert(loadfile(native_input.."/inputcontainer.lua"))()
    package.loaded["ui/widget/container/inputcontainer"]=Input
end
local Range=W:extend{}
function Range:match(g)
    local r=type(self.range)=="function" and self.range() or self.range
    return g.ges==self.ges and g.pos.x>=(r.x or 0) and g.pos.y>=(r.y or 0)
        and g.pos.x<(r.x or 0)+r.w and g.pos.y<(r.y or 0)+r.h
end
package.loaded["ui/gesturerange"]=Range
local labels={}
local native_font=os.getenv("ORBITUI_NATIVE_FONT")
if native_font then
    local saved={}
    for _,name in ipairs{"fontlist","ffi/freetype","util"} do saved[name]=package.loaded[name] end
    local settings=G_reader_settings
    G_reader_settings={nilOrTrue=function() return true end,has=function() return false end}
    package.loaded.fontlist={fontdir="fonts",getFontList=function() return {} end}
    package.loaded["ffi/freetype"]={newFaceSize=function() return {} end}
    package.loaded.util={splitFilePathName=function(path) return "",path end}
    native_font=assert(loadfile(native_font))()
    for _,name in ipairs{"fontlist","ffi/freetype","util"} do package.loaded[name]=saved[name] end
    G_reader_settings=settings
end
local function label(args)
    local v=W:new{kind="text",text=args.text,width=args.width,height=args.height or args.face.size*1.3,
        face=args.face,bold=args.bold,fgcolor=args.fgcolor,max_lines=args.max_lines}
    if args.height_adjust then
        if measured_title_h~=nil then v.height=measured_title_h
        elseif os.getenv("ORBITUI_CARD_PREVIEW_DIR") and args.text=="Actual KOReader book" then
            v.height=math.ceil(args.face.size*1.3) -- explicit one-line fixture, not runtime wrapping logic
        end
    end
    labels[#labels+1]=v;return v
end
-- Font:getFace applies density scaling itself; model that at the service
-- boundary rather than accidentally treating point sizes as physical pixels.
package.loaded["features/sui_style"]={getStyledFace=function(_,size)
    if native_font then
        local face=native_font:getFace("cfont",size);face.points=face.orig_size;return face
    end
    return {size=math.floor(screen:scaleBySize(size)+.5),points=size}
end}
package.loaded["infra/sui_core"]={getContentHeight=function() return 1400 end,
    makeColoredText=label,makeTextBox=label,progressBar=function(w,value,h) return W:new{kind="bar",width=w,height=h,pct=value} end}
local SH={getBookData=function(file,prefetched,opts)
    reads=reads+1;H.eq(file,"/actual.epub");H.eq(opts.skip_description,true)
    return {title="Actual KOReader book",authors="Author",percent=.39}
end,getBookCover=function(file,w,h)
    covers=covers+1;H.eq(file,"/actual.epub")
    if ready then return W:new{kind="cover",width=w,height=h,cover=true} end
end,coverPlaceholder=function(_,_,w,h) return W:new{kind="cover",width=w,height=h,placeholder=true} end,
    pctStr=function(n) return string.format("%.0f%%",n*100) end}
package.loaded["modules/module_books_shared"]=SH
package.loaded["lib/bookshelf_clip_container"]=H.componentModule(root,"lib/bookshelf_clip_container")
local function build(opts)
    opts=opts or {};labels={}
    local c={current_fp="/actual.epub",prefetched={untouched=true},open_fn=function(file) H.eq(file,"/actual.epub");opens=opens+10 end,
        orbitui_dashboard_hosted=opts.hosted,height=opts.height or 330,_screen_widget={}}
    if opts.no_book then c.current_fp=nil end
    local v=M.build(opts.width or 618,c)
    return v,v.orbitui_reading_pet or v,c
end
local function tap(v,card,x,y)
    local gesture={ges="tap",pos={x=x,y=y}}
    if native_input then
        return v:handleEvent{handler="onGesture",args={gesture,n=1}}
    end
    return card:onReadingPetTap(nil,gesture)
end
H.test("native book data, cover placeholder and progress coexist with pet info and never use its stale book title",function()
    reset();ready=false
    local before=copy(pet.estado)
    local v,card,ctx=build{hosted=true}
    H.eq(reads,1);H.eq(card.file,"/actual.epub")
    H.eq(card.group[card.cover_index].placeholder,true);H.eq(ctx.prefetched.untouched,true)
    local found={};for _,l in ipairs(labels) do found[l.text]=true end
    assert(found["Actual KOReader book"] and found["39%"] and found["Franz 日本語"])
    H.eq(found["Wrong stale title"],nil);assert(equal(pet.estado,before));v:free()
end)
H.test("short native title measurements close reserved-line gaps, recenter the stack and reuse the measured widget",function()
    reset();measured_title_h=23
    local original=M.plan(618,330,1)
    local v,card=build{hosted=true}
    local title=labels[1]
    H.eq(card.plan.title.h,23)
    assert(card.plan.book.h<original.book.h)
    assert(card.plan.book.y>original.book.y)
    H.eq(card.plan.author.y,card.plan.title.y+23+4)
    local copies=0
    for _,child in ipairs(card.group) do if child==title then copies=copies+1 end end
    H.eq(copies,1);H.eq(title.freed,nil)
    H.eq(title.overlap_offset[2],card.plan.title.y)
    v:free();H.eq(title.freed,true)
end)
H.test("invalid native text measurements retire the provisional widget and use a bounded fallback",function()
    for _,height in ipairs{-1,0,math.huge} do
        reset();measured_title_h=height
        local v,card=build{hosted=true}
        H.eq(labels[1].freed,true)
        assert(card.plan.title.h>0 and card.plan.title.h<card.plan.book.h)
        v:free()
    end
end)
H.test("book and pet taps are independent through hosted and standalone native gesture frames",function()
    for _,hosted in ipairs{true,false} do
        reset();sandboxPet();local wrapped=pet.onMostrarTraca
        local v,card=build{hosted=hosted}
        local bb=BB.new(800,500,native_bb and BB.TYPE_BB8 or 1)
        v:paintTo(bb,30,40)
        local dx,dy=hosted and 30 or 0,hosted and 40 or 0
        -- The standalone outer clip moves gestures before the input widget;
        -- the hosted widget receives screen coordinates directly.
        local r=card.plan.pet
        local gx,gy=30+r.x+2,40+r.y+2
        if not native_input then gx,gy=dx+r.x+2,dy+r.y+2 end
        assert(tap(v,card,gx,gy));H.eq(opens,1);H.eq(pet.onMostrarTraca,wrapped)
        r=card.plan.companion
        gx,gy=30+r.x+2,40+r.y+2
        if not native_input then gx,gy=dx+r.x+2,dy+r.y+2 end
        assert(tap(v,card,gx,gy));H.eq(opens,2)
        gx,gy=30+card.plan.cover.x+2,40+card.plan.cover.y+2
        if not native_input then gx,gy=dx+card.plan.cover.x+2,dy+card.plan.cover.y+2 end
        assert(tap(v,card,gx,gy));H.eq(opens,12)
        r=card.plan.title
        gx,gy=30+r.x+2,40+r.y+2
        if not native_input then gx,gy=dx+r.x+2,dy+r.y+2 end
        assert(tap(v,card,gx,gy));H.eq(opens,22)
        v:free();bb:free()
    end
end)
H.test("late native covers replace only their own placeholder and disposed or different-book updates are inert",function()
    reset();ready=false;local v,card,ctx=build{hosted=true}
    local old=card.group[card.cover_index]
    local done,changed=M.updateCovers(v,ctx);H.eq(done,false);H.eq(changed,false);H.eq(old.freed,nil)
    ready=true;done,changed=M.updateCovers(v,ctx);assert(done and changed);H.eq(old.freed,true)
    H.eq(card.group[card.cover_index].cover,true)
    ctx.current_fp="/other";local count=covers;done,changed=M.updateCovers(v,ctx);assert(done);H.eq(changed,false);H.eq(covers,count)
    v:free();ctx.current_fp="/actual.epub";done,changed=M.updateCovers(v,ctx);assert(done);H.eq(changed,false)
end)
H.test("confirmed missing covers stop the native poll without requesting or repainting forever",function()
    reset();ready=false;local v,card,ctx=build{hosted=true}
    package.loaded["infra/sui_config"]={isCoverMissing=function(file) H.eq(file,card.file);return true end}
    local done,changed=M.updateCovers(v,ctx);assert(done);H.eq(changed,false)
    local count=covers;done,changed=M.updateCovers(v,ctx);assert(done);H.eq(changed,false);H.eq(covers,count)
    package.loaded["infra/sui_config"]=nil;v:free()
end)
H.test("missing plugin or book stays readable; unavailable pet, sleep, parked and disposed inputs cannot act",function()
    reset();package.loaded["ui/screensaver"]=nil
    local v,card=build{hosted=true,no_book=true}
    H.eq(card.pet,nil);H.eq(card.file,nil);H.eq(reads,0);v:free()
    reset();v,card=build{hosted=true};card.dimen.x,card.dimen.y=0,0
    local r=card.plan.pet
    local g={pos={x=r.x+2,y=r.y+2}}
    package.loaded["ui/screensaver"].traca_instancia={}
    assert(card:onReadingPetTap(nil,g));H.eq(opens,0)
    card.ctx._screen_widget._parked=true;H.eq(card:onReadingPetTap(nil,g),false)
    card.ctx._screen_widget._parked=false;package.loaded.device.screen_saver_mode=true
    H.eq(card:onReadingPetTap(nil,g),false);package.loaded.device.screen_saver_mode=nil
    v:free();H.eq(card:onReadingPetTap(nil,g),false)
end)
H.test("tiny cards fail closed and native height respects dock-adjusted body space",function()
    reset();local v=build{width=1,height=1};H.eq(v:getSize().w,1);H.eq(v:getSize().h,1);v:free()
    H.eq(M.getHeight{_screen_widget={_layout_content_h=100}},42)
    H.eq(M.getHeight{_screen_widget={_layout_content_h=1400}},300)
end)
H.test("failed metadata/cover reads keep an independent usable card and do not throw in native Home",function()
    reset();local data,cover,placeholder=SH.getBookData,SH.getBookCover,SH.coverPlaceholder
    SH.getBookData=function() error("metadata unavailable") end
    SH.getBookCover=function() error("cover unavailable") end
    SH.coverPlaceholder=function() error("placeholder unavailable") end
    local v,card=build{hosted=true};H.eq(card.file,"/actual.epub");H.eq(card.cover_index,nil)
    assert(card.pet);local done,changed=M.updateCovers(v,card.ctx);assert(done);H.eq(changed,false);v:free()
    SH.getBookData,SH.getBookCover,SH.coverPlaceholder=data,cover,placeholder
end)
H.test("an external sprite paint error is contained inside its region without breaking book actions",function()
    reset();package.loaded.traca_desenho.pintarSprite=function() error("external painter") end
    local v,card=build{hosted=true}
    local bb=BB.new(800,500,native_bb and BB.TYPE_BB8 or 1)
    v:paintTo(bb,0,0);H.eq(card.disposed,nil)
    local r=card.plan.cover;assert(card:onReadingPetTap(nil,{pos={x=r.x+1,y=r.y+1}}));H.eq(opens,10)
    v:free();bb:free()
end)
H.test("high-DPI fonts are converted to points once and localized card text leaves pet names unchanged",function()
    reset();screen.scaleBySize=function(_,n) return n*2 end
    local v=build{hosted=true,width=1236,height=660}
    H.eq(labels[1].face.points,22);H.eq(labels[1].face.size,44);v:free();screen.scaleBySize=function(_,n) return n end
    G_reader_settings={readSetting=function() return "sv" end}
    local s=assert(M.snapshot(now));H.eq(s.name,"Franz 日本語");H.eq(s.stage,"Ash Cat · Kattunge")
    H.eq(require("core/orbitui_i18n")("Currently reading + Silverfish"),"Läser just nu + Silverfish")
    G_reader_settings=nil
end)
H.test("wide shallow high-DPI card has readable fonts, full-height cover and visible companion allocation",function()
    reset();sandboxPet();screen.scaleBySize=function(_,n) return n*2 end
    local original=SH.getBookData
    SH.getBookData=function() return {title=string.rep("Lång boktitel 日本語 ",20),authors=string.rep("Författare ",12),percent=.44} end
    for _,size in ipairs{{1236,300},{1236,400},{1236,660},{600,300}} do
        local v,card=build{hosted=true,width=size[1],height=size[2]}
        assert(card.pet,"sandbox must not hide the cat")
        local p=card.plan
        assert(p.cover.h>=math.min(size[2]*.7,size[1]*.3),"cover should not lose a global header's height")
        assert(p.pet.h>=size[2]*.4,"companion should have a substantial drawing region")
        for _,l in ipairs(labels) do
            assert(l.face.size>=10*p.scale,"never shrink by aspect ratio")
            local pos=l.overlap_offset
            assert(pos[1]>=0 and pos[2]>=0 and pos[1]+l.width<=size[1])
            assert(pos[2]+l.height<=size[2],l.text)
        end
        if size[1]>1000 then
            H.eq(labels[1].face.size,44)
            local found=false
            for _,l in ipairs(labels) do if l.text:match("^Lång") then H.eq(l.face.size,44);H.eq(l.max_lines,size[2]>=400 and 2 or 1);found=true end end
            assert(found)
        end
        v:free()
    end
    for _,height in ipairs{120,200,250,300} do
        package.loaded["ui/screensaver"]=nil
        local v,card=build{hosted=true,width=1236,height=height,no_book=true}
        for _,l in ipairs(labels) do assert(l.overlap_offset[2]+l.height<=height,"unavailable reason stays bounded") end
        v:free()
    end
    SH.getBookData=original;screen.scaleBySize=function(_,n) return n end
end)
local frozen=os.getenv("ORBITUI_SILVERFISH_ROOT")
if frozen then
    package.path=frozen.."/?.lua;"..package.path
    H.test("real frozen Silverfish state/species/sprite renderer draws both species without mutating pet state",function()
        assert(native_bb,"real Silverfish drawing requires the native buffer supplement")
        reset();sandboxPet()
        package.loaded["traca_lingua"]=nil
        require("traca_lingua").forcar("en")
        package.loaded["ui/font"]={getFace=function(_,_,size) return {size=size} end}
        for _,name in ipairs{"ui/widget/textwidget","ui/widget/textboxwidget"} do package.loaded[name]=W end
        for _,name in ipairs{"traca_versao","traca_species","traca_estado","traca_desenho"} do
            package.loaded[name]=nil
            require(name)
        end
        local Species=require("traca_species")
        screen.isColorEnabled=function() return true end
        for _,id in ipairs{"gato","traca"} do
            Species.use(id);pet.estado.especie=id=="gato" and id or nil
            local before=copy(pet.estado)
            local s=assert(M.snapshot(now));H.eq(s.species,id)
            for _,size in ipairs{{1236,300},{600,300},{1680,430}} do
            for _,kind in ipairs{BB.TYPE_BBRGB32,BB.TYPE_BB8} do
                screen.scaleBySize=function(_,n) return n*2 end
                local v,card=build{hosted=true,width=size[1],height=size[2]}
                local bb=BB.new(size[1]+64,size[2]+80,kind)
                bb:fill(BB.COLOR_WHITE);v:paintTo(bb,30,40)
                H.eq(v.failed,nil);assert(equal(pet.estado,before))
                local coloured,drawn,min_y,max_y=0,0,math.huge,0
                local r=card.plan.pet
                for y=40+r.y,40+r.y+r.h-1 do
                    for x=30+r.x,30+r.x+r.w-1 do
                        local c=bb:getPixel(x,y):getColorRGB32()
                        if c.r~=255 or c.g~=255 or c.b~=255 then drawn=drawn+1;min_y=math.min(min_y,y);max_y=math.max(max_y,y) end
                        if c.r~=c.g or c.g~=c.b then coloured=coloured+1 end
                    end
                end
                assert(drawn>0,"real sprite must be visible")
                if id=="gato" and size[1]==1236 then assert(max_y-min_y>=180,"cat must be substantially larger than beta.11") end
                if kind==BB.TYPE_BBRGB32 then assert(coloured>0,"real colour sprite must be visible") else H.eq(coloured,0) end
                for y=0,size[2]+79 do for x=0,size[1]+63 do
                    if x<30 or x>=30+size[1] or y<40 or y>=40+size[2] then H.eq(bb:getPixel(x,y):getColor8().a,255) end
                end end
                local preview=os.getenv("ORBITUI_CARD_PREVIEW_DIR")
                if preview and kind==BB.TYPE_BBRGB32 then
                    assert(loadfile(preview.."/preview.lua"))(card,preview.."/"..id.."-"..size[1]..".svg")
                end
                v:free();bb:free()
                screen.scaleBySize=function(_,n) return n end
            end
            end
        end
    end)
end
H.finish()
