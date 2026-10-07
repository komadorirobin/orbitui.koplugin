local InputContainer = require("ui/widget/container/inputcontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local BB = require("ffi/blitbuffer")
local Screen = require("device").screen
local TextWidget = require("ui/widget/textwidget")
local BFont = require("lib/bookshelf_fonts")
local Boxes = require("core/orbitui_series_boxes")
local _ = require("core/orbitui_i18n")
local T = require("ffi/util").template

local Box = InputContainer:extend{}

function Box:init()
    self.dimen = Geom:new{w=self.width, h=self.height}
    self.ges_events = {
        Tap = {GestureRange:new{ges="tap", range=self.dimen}},
        Hold = {GestureRange:new{ges="hold", range=self.dimen}},
        DoubleTap = {GestureRange:new{ges="double_tap", range=self.dimen}},
    }
    local entry, shape = self.entry, self.entry.series_box
    self.book = entry.book
    local book = Boxes.copy(entry.book.first_book)
    if book.filepath and book.has_cover == nil then
        local Repo = require("lib/bookshelf_book_repository")
        local meta = Repo.buildBookMeta(book.filepath, {want_cover=false})
        for k, v in pairs(meta or {}) do if k ~= "cover_bb" then book[k] = v end end
    end
    self.shape = shape
    self.stroke = math.max(1, math.min(Screen:scaleBySize(2), math.floor(shape.cover_w/8)))
    self.top = self.height - (self.inset or 0) - shape.h
    entry._drawn_h = shape.h
    self[1] = require("lib/bookshelf_spine_widget"):new{
        book=book, width=math.max(1, shape.cover_w-2*self.stroke),
        height=math.max(1, shape.face_h-2*self.stroke), flat_thumb=true,
        show_progress=false, show_status=false, suppress_favorite_badge=true,
        suppress_number_badges=true,
    }
    local font_size = math.max(7, math.min(12, shape.cover_w / Screen:scaleBySize(100) * 10))
    local face = BFont:getFace("smallinfofont", font_size)
    self.label_w = math.max(1, shape.cover_w - 4*self.stroke)
    self[2] = TextWidget:new{text=entry.book.series_name, face=face,
        max_width=math.max(1, self.label_w-2*self.stroke), padding=0}
    self[3] = TextWidget:new{text=shape.count == 1 and _("1 volume") or T(_("%1 volumes"), shape.count), face=face,
        max_width=math.max(1, self.label_w-2*self.stroke), padding=0}
    self.label_h = self[2]:getSize().h + self[3]:getSize().h + 3*self.stroke
    self.show_title = self.label_h < shape.face_h*.45
    if not self.show_title then self.label_h = self[3]:getSize().h+2*self.stroke end
end

function Box:onTap()
    local cb = self.callbacks and self.callbacks.on_series_tap
    if cb then cb(self.entry.book); return true end
    return false
end

function Box:onDoubleTap() return self:onTap() end

function Box:onHold()
    local cb = self.callbacks and self.callbacks.on_series_hold
    if cb then cb(self.entry.book); return true end
    return false
end

function Box:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local p, look = self.shape, self.entry.look
    local top, stroke = y+self.top, self.stroke
    local night = G_reader_settings and G_reader_settings:isTrue("night_mode")
    local function colour(r, g, b)
        if night then r, g, b = 255-r, 255-g, 255-b end
        return BB.ColorRGB32(math.floor(r+.5), math.floor(g+.5), math.floor(b+.5), 255)
    end
    local r, g, b = look.r, look.g, look.b
    local board = colour(r*.55, g*.55, b*.55)
    local side = colour(r*.42, g*.42, b*.42)
    local upper = colour(r*.85, g*.85, b*.85)
    local rim = colour(r*.7+45, g*.7+45, b*.7+45)
    local foot = colour(r*.3, g*.3, b*.3)
    local paper = colour(r*.6+213*.25, g*.6+204*.25, b*.6+179*.25)
    -- Both planes recede by the same (side, -depth) vector. Leave the
    -- triangles above the front-left and below the rear-right untouched.
    for dy = 0, p.depth-1 do
        local dx = math.ceil(p.side*(p.depth-dy)/p.depth)
        bb:paintRect(x+dx, top+dy, p.cover_w, 1, dy<stroke and rim or upper)
    end
    -- Coalesce columns with equal rise: at most depth+1 strips, not one
    -- polygon/buffer per volume or per cover pixel.
    local dx, edge = 0, math.min(stroke, p.face_h)
    while dx < p.side do
        local rise = math.floor((dx+1)*p.depth/p.side)
        local next_dx = p.depth>0
            and math.min(p.side, math.ceil((rise+1)*p.side/p.depth)-1) or p.side
        local sy, width = top+p.depth-rise, next_dx-dx
        bb:paintRect(x+p.cover_w+dx, sy, width, p.face_h, side)
        bb:paintRect(x+p.cover_w+dx, sy, width, edge, upper)
        bb:paintRect(x+p.cover_w+dx, sy+p.face_h-edge, width, edge, foot)
        dx = next_dx
    end
    local layers = math.min(5, math.max(0,p.count-1),
        math.max(0,math.floor((p.side-2*stroke)/3)))
    for i = 1, layers do
        if p.face_h>2*stroke then
            local column = math.floor(i*p.side/(layers+1))
            local rise = math.floor((column+1)*p.depth/p.side)
            bb:paintRect(x+p.cover_w+column, top+p.depth-rise+stroke,
                1, p.face_h-2*stroke, paper)
        end
    end
    bb:paintRect(x, top+p.depth, p.cover_w, p.face_h, board)
    self[1]:paintTo(bb, x+stroke, top+p.depth+stroke)
    -- A paper label belongs to the box itself, never below the shelf plank.
    if self.label_h < p.face_h-4*stroke then
        local lx = x+2*stroke
        local ly = top+p.h-self.label_h-2*stroke
        bb:paintRect(lx-stroke, ly-stroke, self.label_w+2*stroke, self.label_h+2*stroke, board)
        local label_colour = night and colour(48, 47, 41) or colour(239, 232, 211)
        bb:paintRect(lx, ly, self.label_w, self.label_h, label_colour)
        local cy = ly+stroke
        for i = self.show_title and 2 or 3, 3 do
            local size = self[i]:getSize()
            self[i]:paintTo(bb, lx+math.floor((self.label_w-size.w)/2), cy)
            cy = cy+size.h+stroke
        end
    end
end

return Box
