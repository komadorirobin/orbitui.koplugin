-- Paint inside the real card: no extra layout height, cover decode or bitmap
-- cache entry. The opening-book effect uses this same card and its dimen.
local M = {}

function M.decorate(card, label, progress)
    local Screen = require("device").screen
    local BB = require("ffi/blitbuffer")
    local size = card:getSize()
    local inset = math.max(1, card.border_size or card.bordersize or 0)
    local width = size.w - 2 * inset
    local pad = Screen:scaleBySize(2)
    -- Native face-out progress is 8dp high, inset 3dp. Leave it clear.
    local foot = progress and Screen:scaleBySize(14) or 0
    local available = size.h - 2 * inset - foot
    local scale = tonumber(require("lib/bookshelf_settings_store").read("expanded_shelf_font_scale")) or 100
    local font_size = math.max(7, math.min(14 * scale / 100,
        math.floor(available / (Screen:scaleBySize(100) / 100) * 0.09)))
    if width < Screen:scaleBySize(font_size * 2) + 2 * pad or available < Screen:scaleBySize(12) then
        return
    end
    local face, bold = require("lib/bookshelf_fonts"):getFace("infofont", math.floor(font_size),
        label.bold and { bold = true } or nil)
    local text = require("lib/bookshelf_colour_text"):new{
        text = label.text, face = face, bold = bold,
        fgcolor = BB.COLOR_WHITE, max_width = width - 2 * pad,
    }
    local ts = text:getSize()
    local height = ts.h + 2 * pad
    if height > available or ts.w > width - 2 * pad then text:free(); return end
    local offset = size.h - inset - foot - height
    local paint, free = card.paintTo, card.free
    card.paintTo = function(self, bb, x, y)
        paint(self, bb, x, y)
        bb:paintRect(x + inset, y + offset, width, height, BB.COLOR_BLACK)
        text:paintTo(bb, x + inset + math.floor((width - ts.w) / 2), y + offset + pad)
        -- Match finished/on-hold fading without fading the cover twice.
        local fade = self.fade_by or self.fade_amount
        if fade and fade > 0 then bb:lightenRect(x + inset, y + offset, width, height, fade) end
    end
    card.free = function(self, ...)
        text:free()
        if free then return free(self, ...) end
    end
end

return M
