local M = {}

function M.repository(repo)
    local Sort = require("core/orbitui_shelf_sort")
    repo.orderShelfSections = Sort.folderEntries
    repo.orderShelfSeries = Sort.seriesShapes
end

function M.engine(engine)
    local native = engine.sortKeyValue
    engine.sortKeyValue = function(item, key)
        return require("core/orbitui_shelf_sort").sortKeyValue(native, item, key)
    end
end

function M.widget(widget)
    local native = widget._jumpScanList
    if not native then return end
    widget._jumpScanList = function(self)
        if not self:_isSpineMode() then return native(self) end
        local repo = require("lib/bookshelf_book_repository")
        local tab = require("lib/bookshelf_tab_model").getById(self.chip)
        local tip = self._drilldown_path[#self._drilldown_path]
        local chip = self.profile and self:_profileChip()
        local folder = tip and tip.kind == "folder" and tip.payload.path
            or (not tip and chip and chip.path)
        if folder then
            local priority = self.profile
                and require("lib/bookshelf_profiles").folderSortPriority(self.profile)
                or (tab and tab.sort_priority)
            if not priority or #priority == 0 then priority = repo.getSortPriority("all") end
            local scope = self._profileScope and self:_profileScope() or nil
            local ok, books = pcall(repo.getFolderSections,
                math.max(self._total_items or 0, 10000), 0, priority, scope,
                (not self.profile and tab) and tab.filter or nil,
                { root = folder, light_only = true, lazy_cover = true })
            return ok and books or nil, priority and priority[1] and priority[1].key,
                ok and "getFolderSections" or ("getFolderSections-ERR:" .. tostring(books))
        end
        -- getBySource must use the same bookcase producer as the visible
        -- shelf. Restore both flags even when a native scan raises an error.
        local light, suppress = repo.spine_light, repo.suppress_covers
        repo.spine_light, repo.suppress_covers = true, true
        local ok, books, key, via = pcall(native, self)
        repo.spine_light, repo.suppress_covers = light, suppress
        if not ok then error(books) end
        return books, key, via
    end
end

return M
