local root=os.getenv("ORBITUI_TEST_ROOT") or "."
package.path=root.."/?.lua;./?.lua;"..package.path
local H=require("tests/helpers")
local function read(path)
    local f=assert(io.open(root.."/"..path,"rb")); local s=f:read("*a"); f:close(); return s
end
local function run(code,env)
    setmetatable(env,{__index=_G})
    if setfenv then return setfenv(assert(loadstring(code)),env)() end
    return assert(load(code,"6.1 integration","t",env))()
end
H.test("all lazy helpers preserve canonical source bytes and API-1 module identities",function()
    local map=dofile(root.."/core/orbitui_module_map.lua")
    local embedded=getmetatable(map).orbitui_embedded
    local count=0
    for name,source in pairs(embedded) do
        count=count+1
        assert((loadstring or load)(source),name)
        local f=io.open(root.."/"..assert(map[name]),"rb")
        if f then H.eq(f:read("*a"),source,name); f:close() end
    end
    H.eq(count,28)
    for _,name in ipairs({"book_actions_layout","editor_page","link_panel","page_dialog",
            "picker_sort","popup_kit","slider","image_contrast","menu_close_refresh"}) do
        assert(embedded["lib/bookshelf_"..name],name)
    end
end)
local patches=read("components/simpleui/infra/sui_patches.lua")
local method=assert(patches:match("function M.patchFontGetFace%(plugin%)\n(.-)\nend\n"))
H.test("scaled fonts keep shared synthetic/real bold clones in unscaled units",function()
    local face={hash="shared",orig_size=9}
    local F={sizemap={cfont=10},faces={sharedsynthbold={orig_size=9},sharedrealbold={orig_size=9}}}
    function F:getFace(_,size) H.eq(size,9); return face end
    local native=F.getFace
    local M={}
    run("function M.patchFontGetFace(plugin)\n"..method.."\nend",{
        M=M,Config={getFontScalePct=function() return 90 end},
        require=function(n) H.eq(n,"ui/font"); return F end,
        _acquireHooks=function() return {} end,_trackHooks=function() end,
        FONT_GETFACE_STATE="test",logger={warn=function() error("unexpected fallback") end},
    })
    M.patchFontGetFace({})
    for _,size in ipairs({10,11,10}) do
        H.eq(F:getFace("cfont",size),face)
        H.eq(face.orig_size,size)
        H.eq(F.faces.sharedsynthbold.orig_size,size)
        H.eq(F.faces.sharedrealbold.orig_size,size)
    end
    H.eq(F._simpleui_native_getface,native)
end)
H.test("default text scale never installs a font hook",function()
    local F={getFace=function() end}; local native=F.getFace; local M={}
    run("function M.patchFontGetFace(plugin)\n"..method.."\nend",{
        M=M,Config={getFontScalePct=function() return 100 end},require=function() return F end,
        _acquireHooks=function() error("default must not hook") end,
    })
    M.patchFontGetFace({}); H.eq(F.getFace,native)
end)
H.test("new editor/filter/cache labels retain explicit Swedish and English",function()
    local T=require("core/orbitui_i18n")
    for _,s in ipairs({"View mode","Top level","Inside folders and stacks","Shelf order",
            "Any of these genres","All of these genres","Leave out these genres",
            "Leave out these collections","Module font scale","Include spoilers","Newest","Last used"}) do
        assert(T(s,"sv")~=s,s); H.eq(T(s,"en"),s)
    end
end)
H.finish()
