local M = {}
local _ = require("core/orbitui_i18n")
local VIEW_KEY = "orbitui_browse_views"
local local_sources = { folder = true, folder_flat = true, library = true, all = true,
    recent = true, latest = true, authors = true, series = true, genres = true,
    favorites = true, collections = true, collection = true, next = true, bookorbit_want = true,
    single_series = true, author = true, genre = true, format = true, rating = true, language = true,
    orbitui_epub_tags = true }
local fields = { sort = { title = true, author = true, date_added = true, last_opened = true, series = true },
    filter = { all = true, unread = true, reading = true, barely = true, finished = true },
    view = { covers = true, list = true, spines = true, compact = true, compact_two = true },
    alphabet = { [true] = true, [false] = true } }
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
        { text = _("Alphabet strip"), checked_func = function() return M.viewPrefs(ref).alphabet == true end,
            help_text = _("Drag a letter and release to jump, or tap it. Uses the current shelf and sorting, including Å, Ä and Ö; no books are opened. Hidden for non-alphabetical sorting, a single page, an opened series and two-column lists. Saved only for this view."),
            callback = function()
                if not current() then return end
                if not M.saveView(ref, "alphabet", not (M.viewPrefs(ref).alphabet == true)) then
                    require("core/orbitui_context").notify(_("Could not save this view. Other saved views are kept.")); return
                end
                Host.close(host)
                widget:_rebuild(); ui:setDirty(widget, "ui")
            end },
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
    require("core/orbitui_host").shareLightMetadata(repo)
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

-- Optional, per-place alphabet navigation. All data reads happen on release,
-- through the same native scoped producers as explicit letter/page jumps.
function M.alphabetContext(widget)
    local ref = reference(widget)
    if not ref then return end
    local prefs = M.viewPrefs(ref)
    if prefs.alphabet ~= true or (ref.drill and ref.drill.kind == "series") then return end
    if widget._selection and widget._selection:isActive() then return end
    if widget._shelf_module_edit or widget._micro_fullscreen then return end
    if widget._isListMode and widget:_isListMode() and widget:_chipListValue("list_columns") == 2 then return end
    local query = require("core/orbitui_shelf_query").resolve(ref)
    if not query then return end
    local key = ({ author = "author_surname", series = "series_combined" })[prefs.sort] or prefs.sort
    local priority, level = query.sort, nil
    if not key and ref.drill and ref.drill.kind == "folder" and widget.profile then
        priority = require("lib/bookshelf_profiles").folderSortPriority(widget.profile)
        level = priority and priority[1]
        key = level and level.key
    end
    if not key and ref.drill then
        -- Series/group members normally follow their own numeric order.
        -- Only an explicit within-group alphabetical priority is reliable.
        if not priority or not priority[2] then return end
        level = priority[2]; key = level.key
    end
    if not key then
        priority = priority or require("lib/bookshelf_book_repository").getSortPriority("all")
        level = priority and priority[1]; key = level and level.key
    end
    if not require("core/orbitui_shelf_sort").enabled{ { key = key } } then return end
    level = level or (priority and priority[ref.drill and 2 or 1])
    return { ref = ref, prefs = prefs, key = key, reverse = not prefs.sort and level and level.reverse == true,
        identity = M.viewKey(ref) .. "|" .. key .. "|" .. tostring(level and level.reverse)
            .. "|" .. tostring(query.filter) .. "|" .. tostring(query.source.kind) .. "|" .. tostring(query.source.id)
            .. "|" .. tostring(prefs.sort) .. "|" .. tostring(prefs.filter) }
end

function M.alphabetJump(widget, context, letter)
    local now = M.alphabetContext(widget)
    if not now or now.identity ~= context.identity then return false end
    local Repo, Order = require("lib/bookshelf_book_repository"), require("core/orbitui_shelf_sort")
    local light, suppress = Repo.spine_light, Repo.suppress_covers
    local mods = widget._activeShelfModules and widget:_activeShelfModules()
    Repo.spine_light, Repo.suppress_covers = true, true
    local ok, items, total = pcall(function()
        if context.prefs.sort or (context.prefs.filter and context.prefs.filter ~= "all") then
            local books, err = M.browseBooks(context.ref, context.prefs, false, widget:_isSpineMode())
            if err then error("unavailable shelf") end
            if widget:_isSpineMode() then
                books = widget:_prepareSpineItems(books, #books)
                if mods then books = require("lib/bookshelf_shelf_modules").insertItems(books, mods) end
            end
            return books
        end
        if widget:_isSpineMode() then
            return widget:_spineCachedFetch(math.max(10000, widget._total_items or 0))
        end
        return widget:_jumpScanList()
    end)
    Repo.spine_light, Repo.suppress_covers = light, suppress
    -- _jumpScanList returns a key, not a total, in its second position.
    if not ok or type(items) ~= "table" or (type(total) == "number" and total > #items) then
        require("core/orbitui_context").notify(_("Could not jump to this letter. The current shelf is kept.")); return false
    end
    local found, index = pcall(function()
        local index = Order.alphabetTarget(items, context.key, letter, require("lib/bookshelf_sort_engine").sortKeyValue)
        if index and mods and not widget:_isSpineMode() then
            local stream = require("lib/bookshelf_shelf_modules").stream(#items, mods, widget:_nCols(), nil, widget._moduleMinW)
            for slot, descriptor in ipairs(stream) do if descriptor.item == index then return slot end end
            error("missing visual slot")
        end
        return index
    end)
    if not found then
        require("core/orbitui_context").notify(_("Could not jump to this letter. The current shelf is kept.")); return false
    end
    if not index then
        require("core/orbitui_context").notify(string.format(_("Nothing on this shelf starts with %s."), letter)); return false
    end
    if widget:_isSpineMode() then
        widget:_setSpineCursor(index)
        widget._spine_hist = {}
    else
        local size = math.max(1, widget:_viewSize())
        widget._cursor = math.floor((index - 1) / size) * size + 1
    end
    widget:_clampCursor(); widget:_syncPageFromCursor(); widget:_swapShelvesInPlace()
    return true
end

local AlphabetLayer, AlphabetStrip
local function alphabetWidgets()
    if AlphabetLayer then return end
    local Input = require("ui/widget/container/inputcontainer")
    local Geom, Range = require("ui/geometry"), require("ui/gesturerange")
    local UI, Screen = require("ui/uimanager"), require("device").screen
    local Order = require("core/orbitui_shelf_sort")
    AlphabetStrip = Input:extend{ name = "orbitui_alphabet_strip" }
    function AlphabetStrip:current()
        local top = UI:getTopmostVisibleWidget()
        if type(top) == "table" and top.widget then top = top.widget end
        return not self.retired and not self.owner._closed and not self.owner._suspended
            and not self.owner._suppress_transition_paint and top == self.owner
            and self.epoch == self.owner._orbitui_alphabet_epoch
            and self.generation == UI._simpleui_navigation_generation
            and Screen:getWidth() == self.width and Screen:getHeight() == self.height
    end
    function AlphabetStrip:cancel()
        if self.letter then self.owner._orbitui_alphabet_restore = self.bubble end
        self.retired, self.drag, self.letter, self.pending = true, nil, nil, nil
        if self.tick then UI:unschedule(self.tick); self.tick = nil end
        if self.jump then UI:unschedule(self.jump); self.jump = nil end
    end
    function AlphabetStrip:init()
        self.letters = Order.alphabetLetters(self.context.reverse)
        self.ges_events = {}
        for event, gesture in pairs{ LetterTap = "tap", LetterPan = "pan", LetterRelease = "pan_release",
                LetterSwipe = "swipe", LetterHold = "hold", LetterHoldPan = "hold_pan", LetterHoldRelease = "hold_release" } do
            self.ges_events[event] = { Range:new{ ges = gesture, range = function()
                return self.drag and Geom:new{ x = 0, y = 0, w = self.width, h = self.height } or self.rect
            end } }
        end
    end
    function AlphabetStrip:dirty()
        if not self:current() then self:cancel(); return end
        UI:setDirty(self.owner, "fast", self.rect)
        UI:setDirty(self.owner, "fast", self.bubble)
    end
    function AlphabetStrip:move(ges)
        if not self:current() then self:cancel(); return false end
        local pos = ges and (ges.pos or ges.start_pos)
        if not pos or not tonumber(pos.y) then return false end
        self.drag, self.pending = true, Order.alphabetAt(pos.y, self.rect, self.letters)
        if self.tick then return true end
        local function flush()
            self.tick = nil
            if not self:current() then self:cancel(); return end
            if self.letter ~= self.pending then self.letter = self.pending; self:dirty() end
        end
        flush()
        self.tick = function() flush() end
        UI:scheduleIn(.06, self.tick)
        return true
    end
    function AlphabetStrip:release(ges)
        if not self:current() then self:cancel(); return false end
        local pos = ges and (ges.end_pos or ges.pos)
        local letter = pos and Order.alphabetAt(pos.y, self.rect, self.letters) or self.pending or self.letter
        if not letter then return false end
        if self.tick then UI:unschedule(self.tick); self.tick = nil end
        self.drag, self.letter, self.pending = nil, nil, nil
        self:dirty()
        if self.jump then UI:unschedule(self.jump) end
        self.jump = function()
            self.jump = nil
            if self:current() then M.alphabetJump(self.owner, self.context, letter) end
        end
        UI:scheduleIn(.001, self.jump)
        return true
    end
    for _, name in ipairs{ "onLetterPan", "onLetterHold", "onLetterHoldPan" } do
        AlphabetStrip[name] = function(self, _, ges) return self:move(ges) end
    end
    for _, name in ipairs{ "onLetterTap", "onLetterRelease", "onLetterSwipe", "onLetterHoldRelease" } do
        AlphabetStrip[name] = function(self, _, ges) return self:release(ges) end
    end
    function AlphabetStrip:paintTo(bb)
        if self.retired then return end
        local BB, Font, Text = require("ffi/blitbuffer"), require("ui/font"), require("lib/bookshelf_colour_text")
        local r, ink, paper = self.rect, BB.COLOR_BLACK, BB.COLOR_WHITE
        local slot = r.h / #self.letters
        local size = math.max(7, math.min(11, math.floor(slot / Screen:scaleBySize(1))))
        self.labels = self.labels or {}
        local function label(text, rect, font_size, selected)
            local key = text .. ":" .. font_size .. ":" .. tostring(selected)
            local t = self.labels[key]
            if not t then
                t = Text:new{ text = text, face = Font:getFace("cfont", font_size), bold = selected,
                    fgcolor = selected and paper or ink, bgcolor = selected and ink or paper }
                self.labels[key] = t
            end
            local d = t:getSize()
            if d.w <= rect.w and d.h <= rect.h then t:paintTo(bb, rect.x + math.floor((rect.w - d.w) / 2), rect.y + math.floor((rect.h - d.h) / 2)) end
        end
        bb:paintRect(r.x, r.y, r.w, r.h, paper)
        -- On short layouts label fewer positions, but keep all letters touchable.
        local stride = math.max(1, math.ceil(Screen:scaleBySize(size + 2) / slot))
        for i, letter in ipairs(self.letters) do
            local rect = { x = r.x, y = r.y + math.floor((i - 1) * slot), w = r.w, h = math.ceil(slot) }
            if letter == self.letter then bb:paintRect(rect.x, rect.y, rect.w, rect.h, ink) end
            if (i - 1) % stride == 0 or letter == self.letter then
                if letter ~= self.letter then rect.h = math.min(math.floor(slot * stride), r.y + r.h - rect.y) end
                label(letter, rect, size, letter == self.letter)
            end
        end
        if self.letter then
            local b = self.bubble
            bb:paintRect(b.x, b.y, b.w, b.h, ink)
            label(self.letter, b, math.floor(b.h / Screen:scaleBySize(2)), true)
        end
    end
    function AlphabetStrip:free()
        self:cancel()
        for _, label in pairs(self.labels or {}) do label:free() end
        self.labels = nil
    end
    AlphabetLayer = Input:extend{ _orbitui_alphabet_layer = true }
    function AlphabetLayer:paintTo(bb, x, y)
        self.dimen.x, self.dimen.y = x, y
        self[2]:paintTo(bb, x, y)
        self[1]:paintTo(bb, x, y)
    end
end

function M.cancelAlphabet(widget)
    widget._orbitui_alphabet_epoch = (widget._orbitui_alphabet_epoch or 0) + 1
    if widget._orbitui_alphabet then widget._orbitui_alphabet:cancel(); widget._orbitui_alphabet = nil end
end
function M.attachAlphabet(widget)
    local d = widget._shelf_dims
    if not d or not widget[1] then return end
    local Device, UI = require("device"), require("ui/uimanager")
    local Screen = Device.screen
    local function remove()
        if widget[1]._orbitui_alphabet_layer then
            local old = widget[1][1]
            widget[1] = widget[1][2]
            widget._orbitui_alphabet = nil
            old:cancel()
            local after = UI.tickAfterNext or UI.nextTick
            after(UI, function() old:free() end)
        end
    end
    if Device.isTouchDevice and not Device:isTouchDevice() then remove(); return end
    local context = M.alphabetContext(widget)
    if not context then remove(); return end
    local shown = widget:_isSpineMode() and widget._spine_shown or widget:_viewSize()
    if not shown or (widget._total_items or 0) <= shown then remove(); return end
    if widget._orbitui_alphabet and not widget._orbitui_alphabet.retired then return end
    local width, height = Screen:getWidth(), Screen:getHeight()
    local strip_w = math.min(d.PAD or 0, Screen:scaleBySize(22))
    local top = math.max(0, d.wipe_rows_top or 0)
    local bottom = height - widget:_simpleUIReservedBottom() - widget:_paginationFooterReserveHeight()
    if strip_w < Screen:scaleBySize(8) or bottom - top < Screen:scaleBySize(60) then remove(); return end
    alphabetWidgets()
    local Geom = require("ui/geometry")
    local bubble_size = math.min(Screen:scaleBySize(72), bottom - top, math.floor(width / 3))
    local strip = AlphabetStrip:new{ owner = widget, context = context,
        epoch = widget._orbitui_alphabet_epoch, generation = UI._simpleui_navigation_generation,
        width = width, height = height,
        rect = Geom:new{ x = width - strip_w, y = top, w = strip_w, h = bottom - top },
        bubble = Geom:new{ x = math.floor((width - bubble_size) / 2), y = math.floor((top + bottom - bubble_size) / 2), w = bubble_size, h = bubble_size } }
    local base, old = widget[1], nil
    if base._orbitui_alphabet_layer then old, base = base[1], base[2] end
    widget._orbitui_alphabet = strip
    widget[1] = AlphabetLayer:new{ dimen = Geom:new{ w = width, h = height }, strip, base }
    if old then
        local after = UI.tickAfterNext or UI.nextTick
        after(UI, function() old:free() end)
    end
end
function M.alphabet(widget)
    if not (widget._rebuild and widget._swapShelvesInPlace) then return end
    local function pack(...) return { n = select("#", ...), ... } end
    local unpack_values = unpack or table.unpack
    for _, name in ipairs{ "_rebuild", "_swapShelvesInPlace" } do
        local native = widget[name]
        widget[name] = function(self, ...)
            M.cancelAlphabet(self)
            local result = pack(native(self, ...))
            M.attachAlphabet(self)
            return unpack_values(result, 1, result.n)
        end
    end
    for _, name in ipairs{ "onSuspend", "onCloseWidget" } do
        local native = widget[name]
        widget[name] = function(self, ...)
            M.cancelAlphabet(self)
            if native then return native(self, ...) end
        end
    end
    local function visible(self)
        local UI = require("ui/uimanager")
        if not UI.getTopmostVisibleWidget then return false end
        local top = UI:getTopmostVisibleWidget()
        return top == self or (type(top) == "table" and top.widget == self)
    end
    for _, name in ipairs{ "onShow", "onResume" } do
        local native = widget[name]
        widget[name] = function(self, ...)
            local result = native and pack(native(self, ...)) or { n = 0 }
            if visible(self) then M.attachAlphabet(self) end
            return unpack_values(result, 1, result.n)
        end
    end
    local paint = widget.paintTo
    if paint then widget.paintTo = function(self, ...)
        if (self._orbitui_alphabet or self._orbitui_alphabet_restore)
                and visible(self) and not self._suppress_transition_paint then
            local strip = self._orbitui_alphabet
            if strip and strip.retired then M.attachAlphabet(self) end
            local restore = self._orbitui_alphabet_restore
            if restore then
                self._orbitui_alphabet_restore = nil
                local screen = require("device").screen
                if restore.x + restore.w > screen:getWidth() or restore.y + restore.h > screen:getHeight() then restore = nil end
                require("ui/uimanager"):setDirty(self, "ui", restore)
            end
        end
        return paint(self, ...)
    end end
end

return M
