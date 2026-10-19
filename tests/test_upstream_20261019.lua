package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local file = assert(io.open("components/bookshelf/lib/bookshelf_widget.lua"))
local source = file:read("*a"); file:close()
local body = assert(source:match("function BookshelfWidget:handleEvent%(event%)\n(.-)\nend"))
local trace, host, parked, user_first, child, live = {}, {}, false, false, false, false
local function record(name) trace[#trace + 1] = name end
local Device = {}
local env = setmetatable({
    Device = Device,
    require = function(name)
        if name == "apps/filemanager/filemanager" then return {instance=not parked and host} end
        if name == "apps/reader/readerui" then return {instance=host} end
        if name == "lib/bookshelf_reader_park" then return {isParked=function() return parked end} end
        error(name)
    end,
    GestureZones = {
        tryUserFirst=function(_, target) H.eq(target,host); record("user"); return user_first end,
        tryLiveZones=function() record("live"); return live end,
        forwardToLive=function() record("action"); return true end,
    },
    InputContainer = {handleEvent=function() record("child"); return child end},
}, {__index=_G})
local code = "return function(self,event)\n" .. body .. "\nend"
local fn
if setfenv then fn=assert(loadstring(code)); setfenv(fn,env)
else fn=assert(load(code,"embedded gesture priority","t",env)) end
local handle = fn()
local w = {
    _handleSimpleUIBottomBarHold=function(_,ev) record("hold"); return ev.dock=="hold" end,
    _handleSimpleUIBottomBarTap=function(_,ev) record("tap"); return ev.dock=="tap" end,
    _isInSimpleUIBottomBand=function(_,pos) record("band"); return pos.dock end,
    _dropLiftOnTap=function() record("drop"); return false end,
}
local function gesture(dock)
    trace={}
    return handle(w,{handler="onGesture",args={{dock=dock,pos={dock=dock=="band"}}}})
end

H.test("embedded dock owns its taps, holds and empty band before live host zones", function()
    for _,p in ipairs({false,true}) do
        parked=p
        for dock,expected in pairs({hold="user,child,hold",tap="user,child,hold,tap",
                band="user,child,hold,tap,band"}) do
            H.eq(gesture(dock),true); H.eq(table.concat(trace,","),expected)
        end
    end
end)

H.test("user gestures and child widgets keep priority with either live host", function()
    for _,p in ipairs({false,true}) do
        parked=p; user_first=true
        H.eq(gesture("tap"),true); H.eq(table.concat(trace,","),"user")
        user_first=false; child=true
        H.eq(gesture("tap"),true); H.eq(table.concat(trace,","),"user,child")
        child=false
    end
end)

H.test("non-dock gestures reach live zones before dropping a lifted book", function()
    live=true
    H.eq(gesture(),true); H.eq(trace[#trace],"live")
    live=false
    H.eq(gesture(),false); H.eq(trace[#trace-1],"live"); H.eq(trace[#trace],"drop")
    trace={}
    H.eq(handle(w,{handler="onIncreaseFlIntensity",args={}}),true)
    H.eq(table.concat(trace,","),"child,action")
end)

H.test("gesture unlock remains with the screensaver, not the dock or parked host", function()
    Device.screen_saver_lock=true
    H.eq(gesture("tap"),false); H.eq(#trace,0)
    Device.screen_saver_lock=false
end)
H.finish()
