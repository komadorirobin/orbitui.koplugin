local M = {}
local _ = require("core/orbitui_i18n")
local KEY = "orbitui_series_title_positions"
local valid = { below = true, overlay = true }

local function preferences()
    local value = require("lib/bookshelf_settings_store").read(KEY)
    return type(value) == "table" and value or {}
end

function M.position(id)
    local value = preferences()[id]
    return valid[value] and value or "below"
end

function M.save(id, position)
    if type(id) ~= "string" or id == "" or not valid[position] then return false end
    local data = {}
    for k, v in pairs(preferences()) do data[k] = v end
    data[id] = position
    local store = require("lib/bookshelf_settings_store")
    store.save(KEY, data)
    store.flush()
    return true
end

function M.show(widget, chip)
    local id = require("adapters/orbitui_cover_labels").id(widget, chip)
    local tab = require("adapters/orbitui_shelf_themes").tab(id)
    if not tab then return end
    local Host = require("lib/bookshelf_menu_host")
    local items, host = {}, nil
    for _i, choice in ipairs({{"below", "Below the cover (default)"}, {"overlay", "On the cover (bottom)"}}) do
        local position = choice[1]
        items[#items + 1] = {
            text = _(choice[2]), radio = true,
            checked_func = function() return M.position(id) == position end,
            callback = function()
                Host.close(host)
                if M.save(id, position) then
                    require("lib/bookshelf_spine_shelf").dropPlanCache()
                    widget:_rebuild()
                    require("ui/uimanager"):setDirty(widget, "ui")
                end
            end,
        }
    end
    host = Host.show{title = _("Series box title") .. ": " .. (tab.label or chip or id), item_table = items}
    return host
end

function M.widget(widget)
    if widget._orbitui_series_titles_wrapped or not widget._spinePlanBase then return end
    widget._orbitui_series_titles_wrapped = true
    local plan = widget._spinePlanBase
    widget._spinePlanBase = function(self, ...)
        local opts = plan(self, ...)
        opts.series_title_position = M.position(require("adapters/orbitui_cover_labels").id(self))
        return opts
    end
end

function M.geometry(boxes)
    if boxes._orbitui_series_titles_wrapped then return end
    boxes._orbitui_series_titles_wrapped = true
    local geometry = boxes.geometry
    boxes.geometry = function(book, base, opts)
        local shape = geometry(book, base, opts)
        if shape and opts and opts.series_title_position == "overlay" then shape.title_on_cover = true end
        return shape
    end
end

local function freeLines(lines)
    for _, line in ipairs(lines or {}) do line:free() end
end

local function clear(self)
    freeLines(self._orbitui_series_title_lines)
    self._orbitui_series_title_lines, self._orbitui_series_title_key = nil, nil
end

-- Fit again after custom-image decoding: a landscape image and a portrait
-- thumbnail can occupy different rectangles in the same box.
local function fitLines(names, size, room_w, room_h, font)
    local Text = require("lib/bookshelf_colour_text")
    local Fonts = require("lib/bookshelf_fonts")
    local minimum = math.min(size, 8)
    for n = size, minimum, -1 do
        local lines, width, height = {}, 0, 0
        for _, name in ipairs(names) do
            local line = Text:new{ text = name, face = Fonts:getFace(font, n), padding = 0,
                max_width = n == minimum and room_w or nil }
            lines[#lines + 1] = line
            local s = line:getSize()
            width, height = math.max(width, s.w), height + s.h
        end
        if width <= room_w and height <= room_h then return lines end
        freeLines(lines)
    end
end

local function paintTitle(self, bb, rect, board, ink)
    local Screen = require("device").screen
    local pad = math.max(2, Screen:scaleBySize(3))
    local side = math.max(pad, rect.radius)
    local room_w = rect.w - 2 * (rect.border + side)
    local room_h = math.floor(math.min((rect.h - 2 * rect.border) * .45,
        rect.h - 2 * rect.border - rect.notch_h - pad)) - 2 * pad
    local name = self.book.series_name or ""
    if name == "" or room_w < Screen:scaleBySize(12) or room_h < Screen:scaleBySize(8) then
        clear(self)
        return
    end
    local font = require("lib/bookshelf_fonts").getUIFontFace() or "cfont"
    local key = table.concat({name, room_w, room_h, self.shape.label_size, font, Screen:scaleBySize(100)}, "\0")
    if self._orbitui_series_title_key ~= key then
        clear(self)
        local names = self.shape.name_lines or {name}
        self._orbitui_series_title_lines = fitLines(names, self.shape.label_size, room_w, room_h, font)
        if not self._orbitui_series_title_lines and #names > 1 then
            self._orbitui_series_title_lines = fitLines({name}, self.shape.label_size, room_w, room_h, font)
        end
        self._orbitui_series_title_key = key
    end
    local lines = self._orbitui_series_title_lines
    if not lines then return end
    local height = 0
    for _, line in ipairs(lines) do height = height + line:getSize().h end
    local y = rect.y + rect.h - rect.border - height - 2 * pad
    -- Opaque board-coloured ink keeps even busy covers legible on e-ink.
    -- The native stencil subsequently clips this band to the rounded edge.
    bb:paintRectRGB32(rect.x + rect.border, y, rect.w - 2 * rect.border, height + 2 * pad, board)
    y = y + pad
    for _, line in ipairs(lines) do
        local size = line:getSize()
        line.fgcolor = ink
        line:paintTo(bb, rect.x + math.floor((rect.w - size.w) / 2), y)
        y = y + size.h
    end
end

function M.boxWidget(widget)
    if widget._orbitui_series_title_painter_wrapped then return end
    widget._orbitui_series_title_painter_wrapped = true
    widget.paintStickerTitle = paintTitle
    local init, free = widget.init, widget.free
    widget.init = function(self, ...)
        clear(self)
        return init(self, ...)
    end
    widget.free = function(self, ...)
        clear(self)
        if free then return free(self, ...) end
    end
end

return M
