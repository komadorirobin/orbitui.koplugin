package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local f = assert(io.open("components/simpleui/engines/sui_screen_engine.lua"))
local source = f:read("*a"); f:close()
local ScreenWidget, UIManager = {}, {}
local dirty, label, flushes, poll = 0, 0, 0, 0
function UIManager:setDirty(_, region)
    assert(type(region) == "function")
    local _, dimen = region()
    assert(dimen and dimen.h > 0)
    dirty = dirty + 1
end
local Config = { cover_extraction_pending = true, flushCoverQueue = function() flushes = flushes + 1 end }
local function node(child)
    return { child, dimen = { w = 200, h = 60 }, getSize = function() return { w = 200, h = 60 } end }
end
local last_chrome, last_content
package.loaded["features/sui_module_chrome"] = {
    resolve = function(pfx, id) return { pfx = pfx, id = id } end,
    contentWidth = function(w) return w - 20 end,
    wrap = function(content, chrome, w)
        H.eq(chrome.pfx, "simpleui_hs_")
        H.eq(w, 200)
        last_content, last_chrome = content, node(content)
        return last_chrome
    end,
}
local function applyModuleBackground(id, widget, w, text)
    H.eq(id, "currently")
    H.eq(text, "Reading")
    return node(widget)
end
local noop = function() end
local function method(name)
    local start = assert(source:find("function ScreenWidget:" .. name .. "(", 1, true))
    local finish = assert(source:find("\nfunction ScreenWidget:", start + 1, true))
    local body = source:sub(start, finish - 1)
    local load_fn = loadstring or load
    assert(load_fn("local ScreenWidget, UIManager, Config, applyModuleBackground, labelTextFor, pageIndicatorFor, pageNavFor = ...\n" .. body))(
        ScreenWidget, UIManager, Config, applyModuleBackground, function() return "Reading" end, noop, noop)
end
method("_buildModWidget")
method("_updateModuleStats")
method("_refreshBookModSlot")
local updates, builds = 0, 0
local mod = {
    id = "currently", is_book_mod = true, has_covers = true,
    updateCovers = noop,
    build = function(w, ctx)
        H.eq(w, 180)
        H.eq(ctx.col_w, 200)
        builds = builds + 1
        local n = node()
        n.book = "book-" .. builds
        return n
    end,
    updateStats = function(content)
        H.eq(content, last_content)
        assert(content.book, "updater was passed chrome instead of module content")
        updates = updates + 1
        return true
    end,
}
local s = setmetatable({
    _pfx = "simpleui_hs_", _ctx_cache = {},
    _book_mod_slots = {}, _stats_mod_slots = {}, _cover_mod_slots = {},
    _wrapper_pool = { currently = node() },
    _makeModWrapper = function(self, _, widget)
        self._wrapper_pool.currently[1] = widget
        return self._wrapper_pool.currently
    end,
    _bookModRefreshType = function() return "ui" end,
    _syncBookModLabel = function(_, id) H.eq(id, "currently"); label = label + 1 end,
    _scheduleCoverPoll = function() poll = poll + 1 end,
}, { __index = ScreenWidget })

H.test("chrome and module contents have separate identities on initial build", function()
    local widget, content = s:_buildModWidget(mod, 200, s._ctx_cache)
    assert(widget ~= content)
    s._book_mod_slots.currently = {
        mod = mod, widget = widget, content = content, col_w = 200,
        bg_enabled = true, has_menu = true,
    }
    s._stats_mod_slots.currently = { mod = mod, widget = widget, content = content }
    H.eq(s:_updateModuleStats(s._book_mod_slots.currently), true)
end)
H.test("page rebuild retains labels and retargets both stats and cover polling", function()
    H.eq(s:_refreshBookModSlot("currently"), true)
    local slot = s._book_mod_slots.currently
    H.eq(slot.widget, last_chrome)
    H.eq(slot.content, last_content)
    H.eq(s._cover_mod_slots.currently.widget, last_content)
    H.eq(s._stats_mod_slots.currently.content, last_content)
    H.eq(s._stats_mod_slots.currently.widget, last_chrome)
    H.eq(s._wrapper_pool.currently[1][1], last_chrome)
    H.eq(s:_updateModuleStats(s._stats_mod_slots.currently), true)
    H.eq(updates, 2)
    H.eq(dirty, 1); H.eq(label, 1); H.eq(flushes, 1); H.eq(poll, 1)
end)
H.test("failed rebuild leaves mounted content and update targets untouched", function()
    local mounted = s._wrapper_pool.currently[1]
    mod.build = function() error("fixture render failure") end
    H.eq(s:_refreshBookModSlot("currently"), false)
    H.eq(s._wrapper_pool.currently[1], mounted)
    H.eq(s._stats_mod_slots.currently.content, last_content)
    H.eq(dirty, 1)
end)
H.finish()
