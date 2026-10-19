local M = {}
local STAR = "\xE2\x98\x85"
local REGISTRY = "bookshelf_folder_badge_providers"

-- Reuse the MAL plugin's folder links, without hydrating books or reading its
-- private settings. Nested volume folders resolve to their common parent.
function M.folder(book)
    if type(book) ~= "table" or type(book.books) ~= "table" then return nil end
    -- A collection of unrelated one-shots has no shared series rating.
    if book.kind == "folder" and book._series_box then return nil end
    local common
    for _, member in ipairs(book.books) do
        local path = type(member) == "table" and member.filepath
        if type(path) ~= "string" or path:find("://", 1, true) then return nil end
        path = path:gsub("\\", "/"):gsub("/+", "/")
        if ("/" .. path .. "/"):find("/%.%./") then return nil end
        local parent = path:match("^(.*)/[^/]+$")
        if not parent or parent == "" then return nil end
        common = common or parent
        while parent ~= common and parent:sub(1, #common + 1) ~= common .. "/" do
            common = common:match("^(.*)/[^/]+$")
            if not common or common == "" then return nil end
        end
    end
    if not common then return nil end
    return { path = common, label = book.series_name }
end

function M.cachedRating(folder)
    local registry = package.loaded[REGISTRY]
    local provider = type(registry) == "table" and registry.myanimelist
    if not folder or type(provider) ~= "function" then return nil end
    local ok, value = pcall(provider, folder)
    if not ok then return nil end
    local text = type(value) == "table" and value.text or value
    local mean = type(text) == "string" and tonumber(text:match("^" .. STAR .. "(%d+%.?%d*)$"))
    if not mean or mean <= 0 or mean > 10 then return nil end
    return string.format(STAR .. "%.2f", mean)
end

local function clear(self)
    if self._orbitui_rating_label then self._orbitui_rating_label:free() end
    self._orbitui_rating_label, self._orbitui_rating_key = nil, nil
end

local function label(self)
    local registry = package.loaded[REGISTRY]
    if not self.preserve_cover_aspect or type(registry) ~= "table"
            or type(registry.myanimelist) ~= "function" then
        clear(self)
        return
    end
    if self._orbitui_rating_folder == nil then
        self._orbitui_rating_folder = M.folder(self.book) or false
    end
    local text = M.cachedRating(self._orbitui_rating_folder)
    if not text then clear(self); return end

    local Progress = require("lib/bookshelf_cover_progress")
    local Screen = require("device").screen
    local key = text .. ":" .. Progress.badgeSize(12) .. ":" .. Screen:scaleBySize(100)
    if self._orbitui_rating_key ~= key then
        clear(self)
        local face, bold = require("lib/bookshelf_fonts"):getFace("smallinfofont",
            Progress.badgeSize(12), { bold = true })
        self._orbitui_rating_label = require("lib/bookshelf_colour_text"):new{
            text = text, face = face, bold = bold, padding = 0,
        }
        self._orbitui_rating_key = key
    end
    -- The native painter fits the notch to the current cover, colours the
    -- text like the box's other labels, and omits it if the image is too small.
    return self._orbitui_rating_label
end

function M.widget(widget)
    if widget._orbitui_series_rating_wrapped then return end
    widget._orbitui_series_rating_wrapped = true
    local init, free = widget.init, widget.free
    widget.stickerLeftLabel = label
    widget.init = function(self, ...)
        clear(self)
        self._orbitui_rating_folder = nil
        return init(self, ...)
    end
    widget.free = function(self, ...)
        clear(self)
        self._orbitui_rating_folder = nil
        if free then return free(self, ...) end
    end
end

return M
