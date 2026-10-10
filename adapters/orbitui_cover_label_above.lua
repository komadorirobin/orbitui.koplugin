-- A separate label above the page block, within the existing shelf-row budget.
-- The real cover card remains untouched for status marks and opening effects.
local M = {}

function M.new(label, width, available, cover_h)
    local Screen = require("device").screen
    local pad, gap = Screen:scaleBySize(2), Screen:scaleBySize(3)
    local scale = tonumber(require("lib/bookshelf_settings_store").read("expanded_shelf_font_scale")) or 100
    local font_size = math.max(7, math.min(14 * scale / 100,
        math.floor(cover_h / (Screen:scaleBySize(100) / 100) * 0.09)))
    if width < Screen:scaleBySize(font_size * 2) + 2 * pad then return nil, cover_h end
    local face, bold = require("lib/bookshelf_fonts"):getFace("infofont", math.floor(font_size),
        label.bold and { bold = true } or nil)
    local BB = require("ffi/blitbuffer")
    local text = require("lib/bookshelf_colour_text"):new{
        text = label.text, face = face, bold = bold,
        fgcolor = BB.COLOR_WHITE, max_width = width - 2 * pad,
    }
    local ts = text:getSize()
    local height = ts.h + 2 * pad + gap
    -- Tiny rows omit the label instead of squeezing the book to nothing.
    local min_cover = math.min(cover_h, Screen:scaleBySize(40))
    if available - height < min_cover or ts.w > width - 2 * pad then
        text:free()
        return nil, cover_h
    end
    local dimen = require("ui/geometry"):new{ w = width, h = height }
    local widget = require("ui/widget/container/inputcontainer"):new{ dimen = dimen, text }
    local GestureRange = require("ui/gesturerange")
    widget.ges_events = {}
    for event, gesture in pairs({Tap="tap", Hold="hold", DoubleTap="double_tap"}) do
        widget.ges_events[event] = { GestureRange:new{ ges = gesture, range = dimen } }
        local handler = "on" .. event
        widget[handler] = function(self, ...)
            if self.cover then return self.cover[handler](self.cover, ...) end
        end
    end
    function widget:getSize() return self.dimen end
    function widget:paintTo(bb, x, y)
        self.dimen.x, self.dimen.y = x, y
        bb:paintRect(x, y, width, height - gap, BB.COLOR_BLACK)
        text:paintTo(bb, x + math.floor((width - ts.w) / 2), y + pad)
        local card = self.cover and self.cover._cover_card
        local fade = card and (card.fade_by or card.fade_amount)
        if fade and fade > 0 then bb:lightenRect(x, y, width, height - gap, fade) end
    end
    return widget, math.min(cover_h, available - height)
end

return M
