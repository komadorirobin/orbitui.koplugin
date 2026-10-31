local M = {}
local _ = require("core/orbitui_i18n")
local VIEW_KEY = "orbitui_browse_views"
local local_sources = { folder = true, folder_flat = true, library = true, all = true,
    recent = true, latest = true, authors = true, series = true, genres = true,
    favorites = true, collections = true, collection = true, next = true, bookorbit_want = true,
    single_series = true, author = true, genre = true, format = true, rating = true, language = true }
local fields = { sort = { title = true, author = true, date_added = true, last_opened = true, series = true },
    filter = { all = true, unread = true, reading = true, barely = true, finished = true },
    view = { covers = true, list = true, spines = true, compact = true, compact_two = true } }
local function store() return package.loaded["infra/sui_store"] end
local function reference(widget)
    local Query = require("core/orbitui_shelf_query")
    local ref = Query.capture(widget, nil, true)
    local path = widget._drilldown_path or {}
    local tip = path[#path]
    if tip and (tip.kind == "search" or tip.kind == "source_nav" or tip.kind == "opds_nav") then return end
    local query = Query.resolve(ref)
    if not query or not local_sources[query.source.kind] then return end
    return ref
end
function M.viewKey(ref)
    if not ref or not ref.chip then return end
    local out = {}
    for _, value in ipairs({ ref.profile or "", ref.chip, ref.drill and ref.drill.kind or "",
            ref.drill and ref.drill.id or "", ref.drill and ref.drill.whole and "whole" or "" }) do
        value = tostring(value); out[#out + 1] = #value .. ":" .. value
    end
    return table.concat(out, "|")
end
function M.viewPrefs(ref)
    local settings, key = store(), M.viewKey(ref)
    local data = settings and settings:get(VIEW_KEY)
    local entry = type(data) == "table" and data.schema == 1 and type(data.items) == "table" and data.items[key]
    local out = {}
    for field, valid in pairs(fields) do if type(entry) == "table" and valid[entry[field]] then out[field] = entry[field] end end
    return out
end
function M.saveView(ref, field, value)
    local settings, key = store(), M.viewKey(ref)
    if not settings or not key or not fields[field] or (value ~= nil and not fields[field][value]) then return false end
    local data = settings:get(VIEW_KEY)
    if data ~= nil and (type(data) ~= "table" or data.schema ~= 1 or type(data.items) ~= "table") then return false end
    local items, count = {}, 0
    for id, item in pairs(data and data.items or {}) do
        items[id], count = item, count + 1
    end
    if not items[key] and count >= 100 then return false end
    if items[key] ~= nil and type(items[key]) ~= "table" then return false end
    local entry = {}
    for k, v in pairs(items[key] or {}) do entry[k] = v end
    entry[field] = value
    items[key] = next(entry) and entry or nil
    local replacement = {}
    for k, v in pairs(data or {}) do replacement[k] = v end
    replacement.schema, replacement.items = 1, items
    settings:set(VIEW_KEY, replacement)
    return true
end
function M.bookStatus(book, repo)
    local pct, status = book.book_pct or book.percent_finished, book.status or book.read_status
    if pct == nil or status == nil then
        local native_pct, native_status = repo.readProgress(book.filepath)
        pct, status = pct or native_pct, status or native_status
    end
    pct = tonumber(pct) or 0
    if status == "finished" or status == "complete" or pct >= 1 then return "finished" end
    if status == "reading" or status == "on_hold" or status == "abandoned" or pct > 0 then
        return pct <= .05 and "barely" or "reading"
    end
    return "unread"
end
function M.browseBooks(ref, prefs, with_counts, bookcase)
    local key = ({ author = "author_surname", series = "series_combined" })[prefs.sort] or prefs.sort
    local priority = key and { { key = key,
        reverse = prefs.sort == "last_opened" or prefs.sort == "date_added" }, { key = "title" } }
    local books, err = require("core/orbitui_shelf_query").books(ref, { sort = priority })
    if err then return nil, err end
    local Repo = require("lib/bookshelf_book_repository")
    local counts, selected = { all = #books, unread = 0, reading = 0, barely = 0, finished = 0 }, {}
    for _, book in ipairs(books) do
        -- Light group members may be path-only. Reuse the native metadata map
        -- before comparing them, never attach covers to a whole-list query.
        if not book.title and Repo.lightMetaFor then book = Repo.lightMetaFor(book.filepath) or book end
        local status
        if with_counts or (prefs.filter and prefs.filter ~= "all") then
            status = M.bookStatus(book, Repo)
            counts[status] = counts[status] + 1
        end
        if not prefs.filter or prefs.filter == "all" or status == prefs.filter then selected[#selected + 1] = book end
    end
    if prefs.sort then
        local dates = key == "date_added" or key == "last_opened"
        local TokenRecord
        if dates then
            TokenRecord = require("lib/bookshelf_token_record")
            local proxies = {}
            for i, book in ipairs(selected) do proxies[i] = TokenRecord.wrap(book) end
            selected = proxies
        end
        local Order = require("core/orbitui_shelf_sort")
        if bookcase and Order.enabled(priority) then
            local entries, section = {}, {}
            for i, book in ipairs(selected) do entries[i] = { rec = book, section = section } end
            local ordered = Order.folderEntries(entries, priority)
            selected = {}
            for i, entry in ipairs(ordered) do selected[i] = entry.rec end
        else require("lib/bookshelf_sort_engine").sort(selected, priority) end
        if TokenRecord then
            for i, book in ipairs(selected) do selected[i] = TokenRecord.unwrap(book) end
        end
    end
    return selected, nil, counts
end
local function refresh(widget)
    widget._cursor, widget.page = 1, 1
    if widget._expireSpineFetch then widget:_expireSpineFetch() end
    widget._draft_items_cache = nil
    widget:_rebuild()
    require("ui/uimanager"):setDirty(widget, "ui")
end
function M.browseControls(widget, native_sort)
    local ref = reference(widget)
    if not ref then return native_sort(widget) end
    local key, ui = M.viewKey(ref), require("ui/uimanager")
    local generation = ui._simpleui_navigation_generation
    local host
    local function current()
        return not widget._closed and generation == ui._simpleui_navigation_generation
            and M.viewKey(reference(widget)) == key
            and not (host and host._menu and ui.getTopmostVisibleWidget
                and ui:getTopmostVisibleWidget() ~= host._menu)
    end
    local Host = require("lib/bookshelf_menu_host")
    local function change(field, value)
        if not current() or (host and host._closed) then return end
        if not M.saveView(ref, field, value) then
            require("core/orbitui_context").notify(_("Could not save this view. Other saved views are kept.")); return
        end
        if host then Host.close(host) end
        refresh(widget)
    end
    local prefs = M.viewPrefs(ref)
    local ok, _books, err, counts = pcall(M.browseBooks, ref, prefs, true, widget._isSpineMode and widget:_isSpineMode())
    if not ok or err then require("core/orbitui_context").notify(_("Could not load books.")); return end
    local function choices(field, list)
        local rows = {}
        for _i, item in ipairs(list) do
            local value = item[1]
            rows[#rows + 1] = { text = _(item[2]) .. (counts[value] and (" (" .. counts[value] .. ")") or ""),
                radio = true, checked_func = function()
                    return (M.viewPrefs(ref)[field] or (field == "filter" and "all")) == value
                end,
                callback = function() change(field, value) end }
        end
        return rows
    end
    local filter = prefs.filter or "all"
    local sort_names = { title = "Title", author = "Author", date_added = "Date added",
        last_opened = "Last read", series = "Series" }
    local filter_names = { all = "All", unread = "Unread", reading = "In progress", barely = "Barely started", finished = "Finished" }
    local view_names = { covers = "Covers", list = "List", spines = "Book spines",
        compact = "Compact list", compact_two = "Compact list · 2 columns" }
    local rows = {
        { text = string.format(_("%d books"), counts.all), enabled_func = function() return false end },
        { text = _("Sort by") .. ": " .. _(sort_names[prefs.sort] or "Shelf default"),
            sub_item_table = choices("sort", { { "title", "Title" }, { "author", "Author" },
                { "date_added", "Date added" }, { "last_opened", "Last read" }, { "series", "Series" } }) },
        { text = _("Filter") .. ": " .. _(filter_names[filter]),
            sub_item_table = choices("filter", { { "all", "All" }, { "unread", "Unread" },
                { "reading", "In progress" }, { "barely", "Barely started" }, { "finished", "Finished" } }) },
        { text = _("View") .. ": " .. _(view_names[prefs.view] or "Shelf default"),
            sub_item_table = choices("view", { { "covers", "Covers" }, { "list", "List" }, { "spines", "Book spines" },
            { "compact", "Compact list" }, { "compact_two", "Compact list · 2 columns" } }) },
        { text = _("Go to page"), callback = function()
            if current() then Host.close(host); widget:_openPageJump() end
        end },
        { text = _("Advanced shelf sorting"), callback = function()
            if current() then Host.close(host); native_sort(widget) end
        end },
        { text = _("Use shelf defaults here"), callback = function()
            if not current() then return end
            for field in pairs(fields) do
                if not M.saveView(ref, field, nil) then
                    require("core/orbitui_context").notify(_("Could not save this view. Other saved views are kept.")); return
                end
            end
            Host.close(host); refresh(widget)
        end },
        { text = _("About this view"), callback = function()
            if current() then require("core/orbitui_context").notify(_("These choices are remembered for this profile, chip and author, series, collection or folder. Filters only narrow the existing shelf. Barely started means at most 5% read; it never changes reading status or remote sync. Shelf defaults restore your original layout and sorting.")) end
        end },
    }
    host = Host.show{ title = _("Sort, filter & view"), item_table = rows }
    return host
end

function M.browsing(widget)
    local fetch, mode, lines, density = widget._fetchChipItems, widget._viewMode, widget._listLines, widget._chipListValue
    if not (fetch and mode and lines and density) then return end
    local sort = widget._openSortMenu
    widget._openSortMenu = function(self) return M.browseControls(self, sort) end
    widget.orbitui_browse_controls = widget._openSortMenu
    -- Measure/probe strings and painted strings use the same short affordance.
    for _, method in ipairs({ "_simpleUIPageLabel", "_pageCounterText" }) do
        local native = widget[method]
        if native then widget[method] = function(self, ...) return native(self, ...) .. " ▾" end end
    end
    local function prefs(self)
        local ref = reference(self)
        return ref and M.viewPrefs(ref) or {}, ref
    end
    widget.orbitui_view_mode = function(self)
        local own = prefs(self)
        if own.view == "compact" or own.view == "compact_two" then return "list" end
        return own.view
    end
    local flip = widget._flipViewMode
    if flip then widget._flipViewMode = function(self, ...)
        local own, ref = prefs(self)
        if not own.view then return flip(self, ...) end
        local current_mode = self:_viewMode()
        local target = current_mode == "covers" and "list" or current_mode == "list" and "spines" or "covers"
        if M.saveView(ref, "view", target) then refresh(self) end
        return true
    end end
    widget._chipListValue = function(self, key)
        local own = prefs(self)
        if key == "list_columns" and (own.view == "compact" or own.view == "compact_two") then
            return own.view == "compact_two" and 2 or 1
        end
        return density(self, key)
    end
    widget._listLines = function(self, ...)
        local own = prefs(self)
        if (own.view == "compact" or own.view == "compact_two") and not self._list_lines_preview then
            local date = own.sort == "date_added" and "%orbitui_added_relative" or "%orbitui_opened_relative"
            return { show_cover = true, lines = {
                { template = "%title", font_size = 16, bold = true },
                { template = "%authors_short · %book_pct · " .. date, font_size = 13 },
            } }
        end
        return lines(self, ...)
    end
    widget._fetchChipItems = function(self, n, want_all)
        local own, ref = prefs(self)
        if not ref or (not own.sort and (not own.filter or own.filter == "all")) then return fetch(self, n, want_all) end
        local books, err = M.browseBooks(ref, own, false, self:_isSpineMode())
        if err then return {}, 0 end -- removed scope never widens
        local Repo = require("lib/bookshelf_book_repository")
        local offset = want_all and 0 or math.max(0, (self._cursor or 1) - 1)
        local limit = want_all and n or self:_viewSize()
        local out = {}
        for i = offset + 1, math.min(#books, offset + limit) do
            local book = books[i]
            -- Whole-list/select-all stays metadata-only; the native Android
            -- safe queue and cover caches still own decoding for visible rows.
            if not want_all and not Repo.spine_light and not Repo.suppress_covers and not self:_isSpineMode() then
                book = Repo.buildBookMeta(book.filepath, { lazy_cover = true }) or book
            end
            out[#out + 1] = book
        end
        return out, #books
    end
end

function M.relativeDate(epoch, now)
    epoch, now = tonumber(epoch), now or os.time()
    if not epoch or epoch ~= epoch or epoch <= 0 or epoch > now then return "" end
    if os.date("%Y-%m-%d", epoch) == os.date("%Y-%m-%d", now) then
        return now - epoch < 3600 and _("Today")
            or string.format(_("%dh ago"), math.floor((now - epoch) / 3600))
    end
    local date = os.date("*t", now)
    date.hour, date.min, date.sec = 12, 0, 0
    date.day = date.day - 1
    if os.date("%Y-%m-%d", epoch) == os.date("%Y-%m-%d", os.time(date)) then return _("Yesterday") end
    return os.date("%Y-%m-%d", epoch)
end
function M.tokens(tokens)
    tokens.register("orbitui_dates", {
        orbitui_added_relative = function(book) return M.relativeDate(book.date_added) end,
        orbitui_opened_relative = function(book) return M.relativeDate(book.last_opened) end,
    })
end

local browse = M.browseBooks
function M.browseBooks(...)
    return require("core/orbitui_host").measure("browse", browse, ...)
end

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
