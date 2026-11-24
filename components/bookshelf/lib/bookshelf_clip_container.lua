--[[
A fixed-size container that centres its single child and bounds it to the
container's w×h. Used so the parent (hero grid) can guarantee a micro-module's
render output is painted within its cell — enforced here, not trusted to the
(often third-party) modules.

Sizing: getSize() always reports the fixed { w, h } (so the cell tiles
predictably regardless of the child's natural size).

Painting: the child is rendered into a REAL offscreen blitbuffer of exactly
w×h, then blitted onto the screen at this container's position. Two reasons to
go via an offscreen buffer rather than `bb:viewport`:

  1. Correctness. A viewport shares the parent's stride/pixel_stride but reports
     a narrower w. A child that does a raw full-width `paintRect(0, .., w, ..)`
     (e.g. reading_goal's progress bar, painted at exactly the cell width) then
     hits blitbuffer's "x == 0 and w == self.w" contiguous-scanline fast path,
     which fills `pixel_stride * h` pixels — the PARENT's width, not the
     viewport's — smearing a full-screen-width band. A real buffer has
     pixel_stride == w, so the fast path is correct. (Standard widgets blit
     rather than paintRect, so they never tripped this; only a raw-paint child
     did.)
  2. Containment. Anything the child draws past w×h lands outside the offscreen
     buffer and is discarded, so the parent's "a module can't overflow its
     cell" guarantee holds for any draw primitive, not just blits.

Placement: a child that fits is centred; a child taller/wider than the cell is
top-/left-aligned (offset clamped to >= 0) so its START is visible and the
overflow is clipped off the bottom/right. The Reading dashboard opts into
fit_content for fixed-size widgets, scaling their paint and hit coordinates
together when they exceed the available space.

Gestures: the child is painted into the offscreen buffer at buffer-local
coords, so its own tappable widgets know their places relative to this
container, not the screen. With pass_gestures, a gesture inside the container
reaches the child moved into that frame, so a module's own buttons work in a
card as they do in a bare module (painted in place). Taps and double taps
only: long-press and swipes stay the host's. Without it the child gets
no gestures at all (a picker preview: the tap picks the module), rather than
screen positions it would compare against the wrong frame.
]]
local Blitbuffer       = require("ffi/blitbuffer")
local Geom             = require("ui/geometry")
local WidgetContainer  = require("ui/widget/container/widgetcontainer")

local ClipContainer = WidgetContainer:extend{
    w = nil,
    h = nil,
    -- Fill colour for the offscreen buffer, so the centred child's surrounding
    -- margin matches the card it sits on (the parent paints the same colour
    -- behind this container). Defaults to white.
    bg = nil,
    -- Pass gestures to the child, in its painted frame (see the header).
    pass_gestures = nil,
}

-- Position in the native child's coordinate system, used by declarative
-- tap regions as well as interactive widgets drawn at a reduced scale.
function ClipContainer:childPoint(x, y)
    return math.floor((x - (self._child_dx or 0)) * (self._to_native_x or 1)),
        math.floor((y - (self._child_dy or 0)) * (self._to_native_y or 1))
end

function ClipContainer:handleEvent(event)
    if event and event.handler == "onGesture" then
        local ges = event.args and event.args[1]
        local d = self.dimen
        if not (self.pass_gestures and ges and ges.pos and d and d.x and self[1]) then return false end
        -- Taps only: long-press is the grid's (the layout editor) and swipes
        -- turn its pages, whatever a module's widget would make of them.
        if ges.ges ~= "tap" and ges.ges ~= "double_tap" then return false end
        local px, py = ges.pos.x - d.x, ges.pos.y - d.y
        if px < 0 or py < 0 or px >= self.w or py >= self.h then return false end
        if self._to_native_x then
            px, py = self:childPoint(px, py)
            local cs = self[1]:getSize()
            if px < 0 or py < 0 or px >= cs.w or py >= cs.h then return false end
        end
        local g = {}
        for k, v in pairs(ges) do g[k] = v end
        g.pos = Geom:new{ x = px, y = py, w = 0, h = 0 }
        local moved = {}
        for k, v in pairs(event) do moved[k] = v end
        moved.args = { g }
        return self[1]:handleEvent(moved) and true or false
    end
    return WidgetContainer.handleEvent(self, event)
end

function ClipContainer:getSize()
    return Geom:new{ w = self.w, h = self.h }
end

-- Only idle buffers are cached. A nested module can render another clipped
-- widget of the same size without overwriting or evicting its parent's buffer.
local idle, idle_count = {}, 0
local function takeScratch(w, h, bbtype)
    local key = w .. ":" .. h .. ":" .. tostring(bbtype)
    local off = idle[key]
    if not off then return Blitbuffer.new(w, h, bbtype), key end
    idle[key], idle_count = nil, idle_count - 1
    return off, key
end

local function putScratch(off, key)
    if idle[key] then
        off:free()
        return
    end
    if idle_count >= 8 then
        local evicted, buffer = next(idle)
        buffer:free()
        idle[evicted], idle_count = nil, idle_count - 1
    end
    idle[key], idle_count = off, idle_count + 1
end

local function fillBuffer(off, w, h, bg)
    -- fill() collapses a colour to its grey (getColor8), so a coloured card
    -- on a colour screen goes through paintRectRGB32, which keeps it.
    -- Asked of Blitbuffer, never by probing `bg.r`: a grey is a Color8
    -- cdata, which RAISES on a field it lacks -- that crashed the start menu
    -- on a greyscale PW5.
    -- Every colour buffer, not only RGB32: a PocketBook colour screen is
    -- RGB24, where the fill() below made every module card its grey (565).
    local t = off:getType()
    local colour_bb = t == Blitbuffer.TYPE_BBRGB32 or t == Blitbuffer.TYPE_BBRGB24
        or t == Blitbuffer.TYPE_BBRGB16
    if colour_bb and off.paintRectRGB32
            and Blitbuffer.isColor8 and not Blitbuffer.isColor8(bg) then
        off:paintRectRGB32(0, 0, w, h, bg:getColorRGB32())
    else
        off:fill(bg)
    end
end

function ClipContainer:paintTo(bb, x, y)
    self.dimen = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local child = self[1]
    if not child then return end
    local cs = child:getSize()
    local cw = (cs and cs.w) or 0
    local ch = (cs and cs.h) or 0
    self._to_native_x, self._to_native_y = nil, nil
    if self.fit_content and (cw > self.w or ch > self.h) then
        -- Bound memory even if an external module reports a corrupt size.
        assert(cw * ch <= math.max(4 * 1024 * 1024, self.w * self.h * 2), "Oversized dashboard widget")
        local factor = math.min(self.w / cw, self.h / ch)
        local dw, dh = math.max(1, math.floor(cw * factor)), math.max(1, math.floor(ch * factor))
        local dx, dy = math.floor((self.w - dw) / 2), math.floor((self.h - dh) / 2)
        local bg = self.bg or Blitbuffer.COLOR_WHITE
        local source = Blitbuffer.new(cw, ch, bb:getType())
        local scaled, off, key
        local ok, err = pcall(function()
            fillBuffer(source, cw, ch, bg)
            child:paintTo(source, 0, 0)
            scaled = require("ui/renderimage"):scaleBlitBuffer(source, dw, dh, false)
            off, key = takeScratch(self.w, self.h, bb:getType())
            fillBuffer(off, self.w, self.h, bg)
            off:blitFrom(scaled, dx, dy, 0, 0, dw, dh)
            bb:blitFrom(off, x, y, 0, 0, self.w, self.h)
        end)
        if off then putScratch(off, key) end
        if scaled and scaled ~= source then scaled:free() end
        source:free()
        if not ok then error(err) end
        self._child_dx, self._child_dy = dx, dy
        self._to_native_x, self._to_native_y = cw / dw, ch / dh
        return
    end
    local dx = math.max(0, math.floor((self.w - cw) / 2))
    local dy = math.max(0, math.floor((self.h - ch) / 2))
    -- Recorded so a host can translate a screen tap into CHILD-local
    -- coordinates (self.dimen + these offsets = the child's painted origin).
    -- This is what makes the module tap-region contract possible despite the
    -- offscreen paint: the host, not the module, owns the geometry.
    self._child_dx, self._child_dy = dx, dy
    -- Render into a real w×h buffer (pixel_stride == w), so any raw paint the
    -- child does is bounded to the cell and the full-width-paintRect fast path
    -- stays correct. Then blit the result onto the screen at this position.
    local off, key = takeScratch(self.w, self.h, bb:getType())
    local ok, err = pcall(function()
        fillBuffer(off, self.w, self.h, self.bg or Blitbuffer.COLOR_WHITE)
        child:paintTo(off, dx, dy)
        bb:blitFrom(off, x, y, 0, 0, self.w, self.h)
    end)
    putScratch(off, key)
    if not ok then error(err) end
end

return ClipContainer
