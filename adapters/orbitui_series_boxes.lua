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

local function localPath(path)
    if type(path) ~= "string" or path:sub(1, 1) ~= "/" or path:find("://", 1, true) then return end
    path = path:gsub("/+", "/"):gsub("/+$", "")
    for part in path:gmatch("[^/]+") do if part == "." or part == ".." then return end end
    return path ~= "" and path or "/"
end

function M.oneshotsPath(filepath, root, folder_name)
    filepath, root = localPath(filepath), localPath(root)
    if not filepath or not root then return end
    local prefix = root == "/" and root or root .. "/"
    if filepath:sub(1, #prefix) ~= prefix then return end
    local parent = root == "/" and "" or root
    -- Only directory components count, never a book named Oneshots.epub.
    for part in filepath:sub(#prefix + 1):gmatch("([^/]+)/") do
        parent = parent .. "/" .. part
        if part:lower() == (folder_name or "Oneshots"):lower() then return parent end
    end
end

local function folderRoot(self)
    if not self.profile then return end
    local last = tip(self)
    if last and last.kind ~= "folder" then return end
    local chip = require("lib/bookshelf_profiles").chip(self.profile, self.chip)
    if chip and chip.kind == "folder" and chip.group_folder_name then
        return chip.path, chip.group_folder_name
    end
end

function M.folderBoxes(items, root, light_meta, folder_name)
    local Boxes = require("lib/bookshelf_series_boxes")
    local out, groups = {}, {}
    for _, item in ipairs(items) do
        local folder = not item.is_remote and not item.books and M.oneshotsPath(item.filepath, root, folder_name)
        if folder then
            local group = groups[folder]
            if not group then
                group = { books = {}, original = item, at = #out + 1 }
                groups[folder], out[group.at] = group, group
            end
            group.books[#group.books + 1] = item
        else
            out[#out + 1] = item
        end
    end
    for path, group in pairs(groups) do
        local label = path:match("([^/]+)$")
        local box = Boxes.box(group.books, label, group.original, light_meta)
        -- Retain folder order, rather than sorting unrelated books by series index.
        local order = {}
        for i, book in ipairs(group.books) do order[book.filepath] = order[book.filepath] or i end
        table.sort(box.books, function(a, b) return order[a.filepath] < order[b.filepath] end)
        box.first_book = box.books[1]
        box.kind, box.path = "folder", path
        box._spine_single = false
        box.author, box.authors = nil, nil
        box._series_box_key = "folder\0" .. path
        out[group.at] = box
    end
    return out
end

local function nativeTab(self)
    -- Fixed profile chips can share IDs with unrelated native tabs.
    if self.profile then return nil end
    return require("lib/bookshelf_tab_model").getById(self.chip)
end

function M.widget(widget)
    -- Presets change policy, never the saved per-shelf choices or box design.
    widget._seriesBoxesEnabled = function(self)
        local last, tab = tip(self), nativeTab(self)
        local policy = require("adapters/orbitui_appearance").policy().boxes
        if policy == "off" then return false end
        if policy == "native" then
            local saved = self.profile and require("lib/bookshelf_profiles").shelfSettings(self.profile, self.chip) or tab
            if not (saved and saved.series_boxes) then return false end
        end
        local root, folder_name = folderRoot(self)
        local folder = last and last.kind == "folder" and last.payload and localPath(last.payload.path)
        return self:_isSpineMode()
            and not (folder and root and M.oneshotsPath(folder .. "/_", root, folder_name))
            and not (tab and tab.source and tab.source.kind == "single_series")
            and not (last and (last.kind == "series" or last.kind == "search"
                or last.kind == "opds_nav"))
            and not (self._opdsEffectiveTab and self:_opdsEffectiveTab())
    end
    widget._prepareSpineItems = function(self, items, total)
        if not self:_seriesBoxesEnabled() or (total and total > #items) then return items end
        local light_meta = require("lib/bookshelf_book_repository").lightMetaFor
        local root, folder_name = folderRoot(self)
        if root then items = M.folderBoxes(items, root, light_meta, folder_name) end
        return require("lib/bookshelf_series_boxes").prepare(items, light_meta, {
            include_singletons = require("adapters/orbitui_appearance").policy().boxes == "all",
        })
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
