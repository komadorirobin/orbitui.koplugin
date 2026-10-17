local M = {}

local page_sources = { print = true, stable = true, calibre = true, filename = true }
local fixed_formats = { pdf = true, cbz = true, cbr = true, djvu = true }

local function positive(value)
    local n = tonumber(value)
    return n and n > 0 and n < math.huge and n or nil
end

function M.memberSpineWidth(member, auto_thick, opts)
    local Shelf = require("lib/bookshelf_spine_shelf")
    local Layout = require("lib/bookshelf_spine_layout")
    local pp, source = Shelf.cachedPageCount(member.filepath)
    local pages = page_sources[source] and positive(pp) or nil
    if not pages and page_sources[member._page_src] then
        pages = positive(member.page_count) or positive(member.pages)
    end
    -- Never turn a reflowable's reader-layout count into physical thickness.
    -- Fixed-layout page counts and explicit filename markers are comparable.
    local ext = (member.filepath or ""):match("%.([^./]+)$")
    if not pages and ext and fixed_formats[ext:lower()] then
        pages = positive(member.page_count) or positive(member.pages) or positive(pp)
    end
    if not pages and member.filepath then
        local Repo = require("lib/bookshelf_book_repository")
        if Repo.pageCountFromFilename then pages = positive(Repo.pageCountFromFilename(member.filepath)) end
    end
    local width = Layout.spineWidthDp(pages) * auto_thick
    local pct = tonumber(opts.thickness_pct)
    if pct and pct >= 40 and pct <= 300 then width = width * pct / 100 end
    return require("device").screen:scaleBySize(math.max(8, width))
end

function M.packSpines(widths, room)
    local spines, used = {}, 0
    for i, width in ipairs(widths) do
        if used + width > room then break end
        spines[#spines + 1] = { member = i, x = used, w = width }
        used = used + width
    end
    return spines, used
end

function M.geometry(boxes)
    boxes.memberSpineWidth = M.memberSpineWidth
    boxes.packSpines = M.packSpines
end

local function tip(self)
    local path = self._drilldown_path or {}
    return path[#path]
end

local function nativeTab(self)
    -- Fixed profile chips can share IDs with unrelated native tabs.
    if self.profile then return nil end
    return require("lib/bookshelf_tab_model").getById(self.chip)
end

function M.widget(widget)
    -- Keep OrbitUI's existing all-series policy, but let Bookshelf own the
    -- compaction, geometry, painting, counts and member status marks.
    widget._seriesBoxesEnabled = function(self)
        local last, tab = tip(self), nativeTab(self)
        return self:_isSpineMode()
            and not (tab and tab.source and tab.source.kind == "single_series")
            and not (last and (last.kind == "series" or last.kind == "search"
                or last.kind == "opds_nav"))
            and not (self._opdsEffectiveTab and self:_opdsEffectiveTab())
    end
    widget.spineShowSectionBadges = function(self)
        local last = tip(self)
        if last then return last.kind ~= "series" end
        local tab = nativeTab(self)
        return not (tab and tab.source and tab.source.kind == "single_series")
    end
    local scan = widget._jumpScanList
    widget._jumpScanList = function(self)
        local items, key, via = scan(self)
        if items then items = self:_prepareSpineItems(items, #items) end
        return items, key, via
    end

    -- Read the old identifiers-only scope without rewriting stored settings.
    -- Write both spellings so a rollback to the preserved design stays scoped.
    local serialize, restore = widget._serializeDrillPath, widget._restoreDrillPath
    widget._serializeDrillPath = function(self)
        local saved = serialize(self)
        for _, entry in ipairs(saved) do
            if entry.kind == "series" and type(entry.series_box_files) == "table" then
                entry.orbitui_series_files = entry.series_box_files
            end
        end
        return saved
    end
    widget._restoreDrillPath = function(self, saved)
        if type(saved) ~= "table" then return restore(self, saved) end
        local compatible = {}
        for i, entry in ipairs(saved) do
            local copy = {}
            for k, v in pairs(entry) do copy[k] = v end
            if copy.kind == "series" and copy.series_box_files == nil
                    and type(copy.orbitui_series_files) == "table" then
                copy.series_box_files = copy.orbitui_series_files
            end
            compatible[i] = copy
        end
        return restore(self, compatible)
    end
end

return M
