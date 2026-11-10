local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local W = H.widget()
function W:_init() self.key_events, self.ges_events = {}, {}; if self.kind == "button" then self.label_widget = {} end end
function W:free() for _, child in ipairs(self) do if child.free then child:free() end end end
function W:getSize()
    if self.kind == "text" then
        local size = self.face.pixel_size or self.face.orig_size
        local lines = 0
        for line in (self.text .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#line * size * .52 / math.max(1, self.width))) end
        return { w = self.width, h = self.height or math.ceil(lines * size * 1.35) }
    elseif self.kind == "button" then return { w = self.width, h = self.height + 2 * (self.padding_v + self.bordersize) }
    elseif self.kind == "vspan" then return { w = 0, h = self.width }
    elseif self.kind == "hspan" then return { w = self.width, h = 0 }
    elseif self.kind == "progress" then return { w = self.width, h = self.height }
    elseif self.kind == "scroll" then return self.dimen end
    local w, h = 0, 0
    for _, child in ipairs(self) do
        local s = child:getSize()
        if self.kind == "horizontal" then w, h = w + s.w, math.max(h, s.h)
        else w, h = math.max(w, s.w), h + s.h end
    end
    if self.kind == "frame" then w, h = w + 2 * ((self.padding or 0) + self.bordersize), h + 2 * ((self.padding or 0) + self.bordersize) end
    return { w = w, h = h }
end
function W:paintTo() end
function W:contains(pos) return pos.x >= self.x and pos.x < self.x + self.w and pos.y >= self.y and pos.y < self.y + self.h end

local f, U, language
local release = { version = "1.2.0-beta.2", notes = "Local recommendations\nReading references\nLess repeated sorting", zip = { size = 1000 } }
local function fixture(width, height, scale, lang)
    f = { width = width or 1264, height = height or 1680, scale = scale or 2, shown = {}, tasks = {},
        closed = 0, dirty = 0, activated = 0, prepared = 0, channel_closed = 0, restarts = 0, polls = 0 }
    language = lang or "en"
    G_reader_settings = { readSetting = function(_, key) if key == "language" then return language end end,
        saveSetting = function() end, flush = function() end }
    for path, kind in pairs{
        ["ui/widget/focusmanager"] = "focus", ["ui/widget/container/framecontainer"] = "frame",
        ["ui/widget/textboxwidget"] = "text", ["ui/widget/verticalgroup"] = "vertical",
        ["ui/widget/horizontalgroup"] = "horizontal", ["ui/widget/verticalspan"] = "vspan",
        ["ui/widget/horizontalspan"] = "hspan", ["ui/widget/button"] = "button",
        ["ui/widget/container/scrollablecontainer"] = "scroll", ["ui/widget/progresswidget"] = "progress",
        ["ui/geometry"] = "geom", ["ui/gesturerange"] = "gesture",
    } do package.loaded[path] = W:extend{ kind = kind } end
    package.loaded["ui/font"] = { getFace = function(_, name, size)
        assert(name == "cfont"); return { orig_size = size, pixel_size = size * f.scale }
    end }
    package.loaded["ffi/blitbuffer"] = { COLOR_BLACK = 0, COLOR_WHITE = 255, COLOR_LIGHT_GRAY = 204, COLOR_DARK_GRAY = 85, COLOR_GRAY_E = 238 }
    package.loaded.device = { screen = { getWidth = function() return f.width end, getHeight = function() return f.height end,
        scaleBySize = function(_, n) return math.floor(n * f.scale + .5) end } }
    package.loaded["ui/uimanager"] = {
        show = function(_, widget) f.shown[#f.shown + 1] = widget end,
        close = function(_, widget) f.closed = f.closed + 1; widget:onCloseWidget() end,
        setDirty = function() f.dirty = f.dirty + 1 end,
        scheduleIn = function(_, delay, fn) f.tasks[#f.tasks + 1] = { delay = delay, fn = fn } end,
        unschedule = function(_, fn) for _, task in ipairs(f.tasks) do if task.fn == fn then task.cancelled = true end end end,
        restartKOReader = function() f.restarts = f.restarts + 1 end,
    }
    package.loaded["ui/trapper"] = { isWrapped = function() return f.wrapped end, wrap = function(_, fn) fn() end,
        dismissableRunInSubprocess = function(_, fn, panel)
            assert(type(panel) == "table", "visible worker must use the existing panel, not another trap")
            f.trap = panel
            panel.dismiss_callback = function() f.dismissed = true end
            if f.before_worker then f.before_worker(panel) end
            if f.cancelled_worker then return false end
            return true, fn()
        end }
    local Boot = require("orbitui_bootstrap")
    Boot.state = function() return { current = f.selection or "factory", previous = "none", pending = f.pending } end
    Boot.activate = function(_, slot) f.activated = f.activated + 1; f.slot = slot end
    package.loaded["core/orbitui_ota"] = {
        prepare = function(_, candidate, report)
            H.eq(candidate.version, release.version); f.prepared = f.prepared + 1
            if report then report{ phase = "downloading", received = 650, total = 1000 } end
            if f.prepare_error then error(f.prepare_error) end
            return { slot = "candidate", version = candidate.version }
        end,
        progressChannel = function()
            if f.no_channel then return end
            return { write = function(value) f.progress = value end,
                read = function() f.polls = f.polls + 1; return f.progress end,
                close = function() f.channel_closed = f.channel_closed + 1 end }
        end,
    }
    U = assert(loadfile(root .. "/adapters/orbitui_updates.lua"))()
    U.configure{ root = "/isolated", version = "1.2.0-beta.1", slot = "factory" }
    return U.openPanel{ phase = "available", current = "1.2.0-beta.1", release = release,
        on_install = function(panel) U.install(release, panel) end }
end
local function tick(delay)
    for index, task in ipairs(f.tasks) do
        if task.delay == delay and not task.ran and not task.cancelled then task.ran = true; task.fn(); return true end
    end
end
local function copyCount(panel)
    local counts = { copied = 0, freed = 0, lightened = 0 }
    local bb = { copy = function()
        counts.copied = counts.copied + 1
        return { free = function() counts.freed = counts.freed + 1 end,
            lightenRect = function() counts.lightened = counts.lightened + 1 end }
    end, blitFrom = function() end, paintRect = function() end }
    panel:paintTo(bb, 0, 0); panel:paintTo(bb, 0, 0)
    return counts
end
local function bounded(panel)
    assert(panel.panel_rect.w <= f.width and panel.panel_rect.h <= f.height,
        string.format("panel exceeds viewport %dx%d: %dx%d", f.width, f.height, panel.panel_rect.w, panel.panel_rect.h))
    assert(panel.panel_rect.x >= 0 and panel.panel_rect.y >= 0)
    if panel.cropping_widget then
        local scroll = panel.cropping_widget
        assert(scroll[1]:getSize().w <= scroll.dimen.w - math.floor(18*f.scale+.5),
            "scrolling must reserve the native vertical bar, without horizontal scrolling")
    end
end

H.test("the lazy panel uses native rounded outlined/filled buttons and has no BookOrbit dependency", function()
    local p = fixture()
    H.eq(p.name, "orbitui_update_panel"); H.eq(p.modal, true); bounded(p)
    local update, later = p.buttons["Update now"], p.buttons.Later
    assert(update.background == 0 and update.radius > 0 and not update.preselect and later.bordersize > 0)
    H.eq(update.label_widget.fgcolor,255); H.eq(update.label_widget.bgcolor,0)
    H.eq(update.text_font_size, 16); H.eq(f.prepared, 0); H.eq(f.activated, 0)
end)
H.test("all states and expanded release text fit portrait, short, narrow and high-density screens", function()
    for _, size in ipairs{ {1264,1680,2}, {1680,1264,2}, {320,480,1}, {320,240,1}, {600,800,2.5} } do
        for _, lang in ipairs{ "en", "sv_SE" } do
            local p = fixture(size[1],size[2],size[3],lang)
            p.news_open = true; p:setState("available"); bounded(p)
            for _, phase in ipairs{ "downloading", "verifying", "installed", "failed", "cancelling" } do p:setState(phase); bounded(p) end
        end
    end
end)
H.test("a panel owns at most one bounded backdrop and releases it on close and rotation", function()
    local p = fixture()
    local c = copyCount(p); H.eq(c.copied, 1); H.eq(c.lightened, 1)
    p:onScreenResize(); H.eq(c.freed, 1)
    c = copyCount(p); p:close(); H.eq(c.freed, 1)
    p:onCloseWidget(); H.eq(c.freed, 1)
    p = fixture(3000,3000,2)
    c = copyCount(p); H.eq(c.copied, 0); p:close()
end)
H.test("progress paints only changed five-percent buckets and cannot regress after verification", function()
    local p = fixture(); p:setState("downloading")
    local dirty = f.dirty
    p:progressed{ phase = "downloading", received = 501, total = 1000 }
    H.eq(f.dirty, dirty + 1)
    p:progressed{ phase = "downloading", received = 539, total = 1000 }; H.eq(f.dirty, dirty + 1)
    p:progressed{ phase = "verifying", received = 1000, total = 1000 }; H.eq(p.phase, "verifying")
    p:progressed{ phase = "downloading", received = 950, total = 1000 }; H.eq(p.phase, "verifying")
end)
H.test("stale buttons cannot start another update or restart after their panel was rebuilt", function()
    local p = fixture(); local update = p.buttons["Update now"]
    p:setState("installed"); update.callback(); H.eq(f.prepared, 0)
    local restart = p.buttons["Restart now"]; p:setState("failed"); restart.callback(); H.eq(#f.tasks, 0)
end)
H.test("outside taps stay modal, and Back or explicit cancellation never reaches the book underneath", function()
    local p = fixture(); p:setState("downloading")
    p:onOutside(nil,{pos={x=0,y=0}}); H.eq(f.closed, 0); H.eq(p.cancel_requested, nil)
    p:onClose(); H.eq(p.cancel_requested, true); H.eq(p.phase, "cancelling"); H.eq(f.closed, 0)
end)
H.test("activation occurs only after completion in the parent callback; restart stays explicit", function()
    local p = fixture(); p.buttons["Update now"].callback()
    H.eq(p.phase, "downloading"); H.eq(f.activated, 0); H.eq(f.channel_closed, 1)
    assert(tick(.1)); H.eq(f.activated, 1); H.eq(p.phase, "installed"); H.eq(f.restarts, 0)
    p.buttons["Restart now"].callback(); H.eq(f.restarts, 0); assert(tick(.1)); H.eq(f.restarts, 1)
end)
H.test("a deferred worker cancelled before launch never starts or activates", function()
    local p = fixture(); f.wrapped = true
    U.install(release,p); p:cancel(); H.eq(p.phase,"cancelling")
    assert(tick(.1)); H.eq(f.prepared,0); assert(tick(.1)); H.eq(f.activated,0); H.eq(p.phase,"available")
    H.eq(f.channel_closed,1)
end)
H.test("late successful results after Cancel, suspend or native close cannot activate code", function()
    for _, kind in ipairs{"cancel","suspend","close"} do
        local p = fixture()
        f.before_worker = function(panel)
            if kind == "cancel" then panel:cancel() elseif kind == "suspend" then panel:onSuspend() else panel:onCloseWidget() end
        end
        U.install(release,p); assert(f.dismissed); assert(tick(.1)); H.eq(f.activated,0); H.eq(f.channel_closed,1)
        if kind ~= "close" then H.eq(p.phase,"available") else H.eq(p.closed,true) end
    end
end)
H.test("failed download or changed activation selection remains retryable without changing settings", function()
    local p = fixture(); f.prepare_error = "checksum mismatch"; U.install(release,p); assert(tick(.1))
    H.eq(p.phase,"failed"); H.eq(f.activated,0)
    f.prepare_error = nil; p.buttons["Try again"].callback(); assert(tick(.1)); H.eq(p.phase,"installed"); H.eq(f.activated,1)
    p = fixture(); U.install(release,p); f.selection = "another"; assert(tick(.1)); H.eq(p.phase,"failed"); H.eq(f.activated,0)
end)
H.test("missing progress storage never blocks a valid update or invents a percentage", function()
    local p = fixture(); f.no_channel = true; U.install(release,p)
    H.eq(p.received,nil); H.eq(f.channel_closed,0); assert(tick(.1)); H.eq(p.phase,"installed"); H.eq(f.activated,1)
end)
H.test("busy-operation guard rejects repeated install taps and stale rollback ownership", function()
    local p = fixture(); U.install(release,p); U.install(release,p)
    H.eq(f.prepared,1); assert(tick(.1)); H.eq(f.activated,1)
end)
H.test("queued polling belongs to one job and never paints after cleanup or cancellation", function()
    local p = fixture()
    f.before_worker = function()
        f.progress = {phase="downloading",received=500,total=1000}
        assert(tick(.25)); H.eq(f.polls,1); H.eq(p.received,500)
    end
    U.install(release,p); H.eq(f.channel_closed,1)
    local old_poll = f.tasks[1].fn
    assert(tick(.1)); H.eq(p.phase,"installed")
    local dirty=f.dirty; old_poll(); H.eq(f.dirty,dirty); H.eq(f.polls,1)
    p=fixture()
    f.before_worker=function(panel) panel:cancel(); assert(tick(.25)); H.eq(f.polls,0) end
    U.install(release,p); assert(tick(.1)); H.eq(f.activated,0)
end)
H.test("malformed or unbounded progress never changes the visible state", function()
    local p=fixture(); p:setState("downloading"); local dirty=f.dirty
    for _,value in ipairs{false,{}, {phase="installed",received=1,total=1},
        {phase="downloading",received=-1,total=1}, {phase="downloading",received=0/0,total=1},
        {phase="downloading",received=math.huge,total=1}, {phase="downloading",received=1,total=2^30}} do
        p:progressed(value)
    end
    H.eq(f.dirty,dirty); H.eq(p.phase,"downloading")
end)
H.finish()
