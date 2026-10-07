local Boxes = require("core/orbitui_series_boxes")
local M = {}
local group_kinds = {series=true, author=true, genre=true, tag=true,
    format=true, rating=true, language=true}

local function tip(self)
    local path = self._drilldown_path or {}
    return path[#path]
end

local function enabled(self)
    local last = tip(self)
    return self:_isSpineMode() and not (last and (last.kind == "series"
        or last.kind == "search" or last.kind == "opds_nav"))
        and not (self._opdsEffectiveTab and self:_opdsEffectiveTab())
end

function M.shelf(shelf)
    local flatten = shelf._flattenItems
    shelf._flattenItems = function(items) return Boxes.flatten(flatten, items) end
    shelf.isSeriesBox = Boxes.isBox
    shelf.seriesBoxGeometry = function(book, base, opts)
        return Boxes.geometry(book, base, opts)
    end
    shelf.seriesBoxWidget = function(entry, opts, stand_h, inset)
        if not entry.series_box then return nil end
        return require("core/orbitui_series_box_widget"):new{
            entry=entry, width=entry.w, height=stand_h, inset=inset,
            callbacks=opts.callbacks, book_look=shelf.bookLook,
        }
    end
    local recess_columns = shelf.recessColumns
    shelf.recessColumns = function(entry, x, inset)
        if entry.series_box then return Boxes.shadowColumns(entry.series_box, x, inset) end
        return recess_columns(entry, x, inset)
    end
end

function M.widget(widget)
    widget.spineShowSectionBadges = function(self)
        local last = tip(self)
        if last then return last.kind ~= "series" end
        local tab = require("lib/bookshelf_tab_model").getById(self.chip)
        return not (tab and tab.source and tab.source.kind == "single_series")
    end
    widget.prepareSpineItems = function(self, items, total)
        -- Never group a partial window, especially a remote catalogue. The
        -- full light list is fetched/cached natively before this seam runs.
        if not enabled(self) or (total and total > #items) then return items end
        return Boxes.prepare(items)
    end
    widget.spineItemCount = function(_, item) return Boxes.displayCount(item) end
    local scan = widget._jumpScanList
    widget._jumpScanList = function(self)
        local items, key, via = scan(self)
        if items and enabled(self) then items = Boxes.prepare(items) end
        return items, key, via
    end
    local fetch = widget._fetchChipItems
    widget._fetchChipItems = function(self, n, want_all)
        local last = tip(self)
        if self:_isSpineMode() and want_all and last and group_kinds[last.kind]
                and last.payload and last.payload.books then
            -- Native group drills fetch one page even for want_all. A box
            -- must expose every volume to the shelf's local page planner.
            self:_applyWithinGroupSort(last.payload)
            local books = last.payload.books
            local Repo = require("lib/bookshelf_book_repository")
            local tab = require("lib/bookshelf_tab_model").getById(self.chip)
            if tab and tab.filter and Repo.applyFilter and not last.whole then
                books = Repo.applyFilter(books, tab.filter)
            end
            local out = {}
            for _, book in ipairs(books) do
                local b = Boxes.copy(book)
                if b.filepath and Repo.lightMetaFor then
                    for k, v in pairs(Repo.lightMetaFor(b.filepath) or {}) do
                        if k ~= "cover_bb" then b[k] = v end
                    end
                end
                out[#out+1] = b
            end
            return out, #out
        end
        return fetch(self, n, want_all)
    end
    -- Keep a filtered/section-local box scoped after a restart. Native series
    -- restoration refreshes membership; intersect it with identifiers only.
    local serialize, restore = widget._serializeDrillPath, widget._restoreDrillPath
    widget._serializeDrillPath = function(self)
        local saved = serialize(self)
        for _, entry in ipairs(saved) do
            for _, frame in ipairs(self._drilldown_path or {}) do
                if entry.kind == "series" and frame.kind == entry.kind
                        and entry.label == frame.label and Boxes.isBox(frame.payload) then
                    entry.orbitui_series_files = {}
                    for _, book in ipairs(frame.payload.books) do
                        entry.orbitui_series_files[#entry.orbitui_series_files+1] = book.filepath
                    end
                end
            end
        end
        return saved
    end
    widget._restoreDrillPath = function(self, saved)
        restore(self, saved)
        for _, entry in ipairs(saved or {}) do
            if entry.kind == "series" and type(entry.orbitui_series_files) == "table" then
                local allowed = {}
                for _, fp in ipairs(entry.orbitui_series_files) do allowed[fp] = true end
                for _, frame in ipairs(self._drilldown_path or {}) do
                    if frame.kind == "series" and frame.label == entry.label then
                        local books = {}
                        for _, book in ipairs(frame.payload.books or {}) do
                            if allowed[book.filepath] then books[#books+1] = book end
                        end
                        frame.payload = Boxes.box(books, entry.label, frame.payload)
                        frame.payload = Boxes.copy(frame.payload)
                        frame.payload._orbitui_series_box = true
                        frame.payload.books = books
                        frame.payload.first_book, frame.payload.book_count = books[1], #books
                    end
                end
            end
        end
    end
end

return M
