local M = {}

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
