package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local function run(s, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then local f = assert(loadstring(s)); setfenv(f, env); return f() end
    return assert(load(s, "October 12 integration", "t", env))()
end
local function section(s, first, last)
    local a = assert(s:find(first, 1, true))
    return s:sub(a, assert(s:find(last, a, true)) - 1)
end
local function method(s, marker)
    local a = assert(s:find(marker, 1, true))
    return s:sub(a, assert(s:find("\nend", a, true)) + 3) .. "\n"
end

local Raster = dofile("components/simpleui/infra/sui_raster_cache.lua")
H.test("shared raster cache budgets RGB stride and evicts LRU across kinds", function()
    local live = 0
    local function buffer()
        live = live + 1
        return { stride = 1024, getHeight = function() return 1024 end,
            free = function(self) assert(not self.freed); self.freed = true; live = live - 1 end }
    end
    local function build() return { bb = buffer() } end
    local a = Raster.get("a", 1, build)
    local b = Raster.get("b", 1, build)
    Raster.get("c", 1, build)
    H.eq(Raster.get("a", 1, build), a)
    Raster.get("d", 1, build)
    H.eq(live, 3); H.eq(b.bb.freed, true); H.eq(a.bb.freed, nil)
    Raster.clear("a"); H.eq(live, 2)
    Raster.clear(); Raster.clear(); H.eq(live, 0)
    H.eq(Raster.bbBytes({stride=800, getHeight=function() return 200 end}), 160000)
end)
H.test("zero-byte raster entries stay bounded and oversized entries remain usable", function()
    local count = 0
    local function build() count = count + 1; return { size = count } end
    local old = Raster.get("font", 1, build)
    for i = 2, 65 do Raster.get("font", i, build) end
    assert(Raster.get("font", 1, build) ~= old)
    local big = Raster.get("big", 1, function()
        return { bb = { stride=4*1024*1024, getHeight=function() return 1 end,
            free=function(self) self.freed=true end } }
    end)
    H.eq(big.bb.freed, nil)
    Raster.clear(); H.eq(big.bb.freed, true)
end)

local stored = {}
package.loaded["lib/bookshelf_settings_store"] = {
    read = function(k) return stored[k] end,
    save = function(k, v) stored[k] = v end, flush = function() end,
}
local Profiles = require("lib/bookshelf_profiles")
local ViewMode = require("lib/bookshelf_view_mode")
local W = {}
local native = { source = { kind = "all" }, view_level1 = "covers", view_level2 = "list" }
local widget_source = read("components/bookshelf/lib/bookshelf_widget.lua")
run(method(widget_source, "function BookshelfWidget:_viewMode"), {
    BookshelfWidget=W, ViewMode=ViewMode, _covers_pin=0,
    require=function(name)
        if name == "lib/bookshelf_tab_model" then return {getById=function() return native end} end
        if name == "lib/bookshelf_sources" then return {isPaged=function() return false end} end
        error(name)
    end,
})
H.test("Auto level choices persist independently in Library and Manga profiles", function()
    local a, b = Profiles.get("prose"), Profiles.get("comics")
    Profiles.saveShelfSettings(a, "authors", {
        view_mode="auto", view_level1="list", view_level2="spines",
        theme="washi", cover_label_mode="author", cover_label_position="above",
    })
    Profiles.saveShelfSettings(b, "authors", {
        view_mode="auto", view_level1="spines", view_level2="covers",
    })
    package.loaded["lib/bookshelf_profiles"] = nil
    Profiles = require("lib/bookshelf_profiles")
    local w = setmetatable({
        chip="authors", profile=a, _expanded=false, drilled=false,
        _profileShelfSettings=function(self) return Profiles.shelfSettings(self.profile, self.chip) end,
        _chipViewMode=function(self) return self:_profileShelfSettings().view_mode end,
        _isDrilledIn=function(self) return self.drilled end,
        _isSearchResults=function() return false end,
    }, {__index=W})
    H.eq(w:_viewMode(), "list")
    w._expanded = true; H.eq(w:_viewMode(), "list")
    w.drilled = true; H.eq(w:_viewMode(), "spines")
    w.profile = b; H.eq(w:_viewMode(), "covers")
    w.drilled = false; H.eq(w:_viewMode(), "spines")
    native = {source={kind="opds"}, view_level2="spines"}
    H.eq(w:_viewMode(), "spines", "a namesake native catalogue cannot override a profile")
    local a_settings = Profiles.shelfSettings(a, "authors")
    H.eq(a_settings.theme, "washi"); H.eq(a_settings.cover_label_position, "above")
    w.profile=nil; w._profileShelfSettings=function() return nil end
    w._chipViewMode=function() return nil end
    H.eq(w:_viewMode(), "list", "unset expanded mode retains legacy policy")
    w._expanded=false; H.eq(w:_viewMode(), "covers")
    w.drilled=true; H.eq(w:_viewMode(), "list")
    w._chipViewMode=function() return "auto" end
    native={source={kind="opds"}, view_level2="spines"}
    H.eq(w:_viewMode(), "covers", "remote Auto spines must degrade to covers, not legacy list")
end)

local core = {}
run(section(read("components/simpleui/infra/sui_core.lua"),
    "function M.setTextsInPlace", "-- ---------------------------------------------------------------------------\n-- makeAlphaTextBox"),
    { M=core, require=function() return {setDirty=function(_, owner, fn)
        owner.dirty[#owner.dirty+1] = fn
    end} end })
core.updateColoredText = function(w, text) w.text = text end
local function textWidget(text)
    return {text=text, getSize=function(self) return {w=#self.text, h=10} end, dimen={x=10,y=20,w=5,h=10}}
end
H.test("same-size clock text updates in place and refreshes its current box", function()
    local w = textWidget("12:00")
    local changed = core.setTextsInPlace({{widget=w,text="12:01"}})
    H.eq(changed[1], w)
    local owner={dirty={}}
    core.refreshBoxes(owner, changed)
    w.dimen.x=30
    local mode, box = owner.dirty[1]()
    H.eq(mode,"ui"); H.eq(box.x,30)
    H.eq(#core.setTextsInPlace({{widget=w,text="12:01"}}),0)
    H.eq(core.setTextsInPlace({{widget=w,text="1:02"}}),nil)
end)
H.test("topbar fallback builds isolated widget trees and the next tick reuses them", function()
    local top = {}
    local a,b={_navbar_container={}}, {_navbar_container={}}
    local changed, built, dirty = false, 0, {}
    local ui={
        getWindowStack=function() return {{widget=a},{widget=b}} end,
        replaceTopbar=function(w, bar) w._navbar_topbar=bar end,
        refreshBoxes=function() end,
    }
    top.buildTopbarWidget=function()
        built=built+1; return {dimen={y=built*10}}
    end
    run(method(read("components/simpleui/screens/sui_topbar.lua"),"function M.refresh(plugin)"), {
        M=top, shouldRefreshTopbar=function() return true end,
        shouldRunTimer=function() return false end, resolveBar=function() return {} end,
        patchLabels=function() return changed and {} or nil end,
        UIManager={setDirty=function(_, w, fn) dirty[w]=fn end},
        logger={warn=function(_, err) error(err) end},
        require=function(name) return name=="device" and {} or ui end,
    })
    top.refresh({ui=a})
    H.eq(built,2); assert(a._navbar_topbar ~= b._navbar_topbar)
    local _, ba=dirty[a](); local _, bb=dirty[b]()
    H.eq(ba.y,10); H.eq(bb.y,20)
    changed=true; top.refresh({ui=a}); H.eq(built,2)
end)
H.test("clock rebuild retains module background and hold wrapper", function()
    local body={{}}
    local screen={_clock_body_ref=body, _clock_body_idx=1,
        _clock_is_wrapped=true, _navbar_container={}, _clock_inner_w=300,
        _applyModuleBackground=function(_, id, inner, width)
            H.eq(id,"clock"); H.eq(width,300)
            return {inner, background=true}
        end}
    local rebuild = run(section(read("components/simpleui/modules/module_clock.lua"),
        "local function _rebuildModule", "local function _tick") .. "\nreturn _rebuildModule", {
        Screen={getWidth=function() return 600 end},
        UI={}, UIManager={setDirty=function() end},
        build=function(_,_,_,_,_,live) live.texts={}; return {clock=true} end,
        require=function() return nil end,
    })
    assert(rebuild(screen))
    H.eq(body[1][1].background,true); H.eq(body[1][1][1].clock,true)
    H.eq(type(screen._clock_live.texts),"table")
end)
H.finish()
