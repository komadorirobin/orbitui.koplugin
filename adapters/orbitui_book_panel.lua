local M = {}
local Context = require("core/orbitui_context")

-- A book detail controller, not a second hidden shelf. It inherits the actual
-- Bookshelf methods (including userpatch wrappers), but never runs shelf init,
-- claims BookshelfWidget.live, registers timers or installs repository hooks.
function M.controller(file, opts)
    opts = opts or {}
    local Widget = require("lib/bookshelf_widget")
    local Profiles = require("lib/bookshelf_profiles")
    local Screen = require("device").screen
    local controller = Widget:extend{
        _orbitui_detail_only = true,
        width = Screen:getWidth(), height = Screen:getHeight(),
        dimen = require("ui/geometry"):new{ w = 0, h = 0 },
        profile_key = Profiles.matchFile(file),
        _drilldown_path = {}, _cursor = 1, page = 1,
        _selection = require("lib/bookshelf_selection").new(),
    }
    controller.profile = Profiles.get(controller.profile_key)
    controller.chip = Profiles.defaultChip(controller.profile) or "all"
    local initial_chip = controller.chip
    local function refresh()
        Context.refresh(file)
        if opts.refresh_fn then opts.refresh_fn() end
    end
    function controller:_rebuild()
        if self._selection:isActive() then
            local selection = self._selection
            self._selection = require("lib/bookshelf_selection").new()
            Context.withShelf(self.profile_key, function(shelf)
                shelf._selection = selection
                shelf:_rebuild()
                require("ui/uimanager"):setDirty(shelf, "ui")
            end)
        elseif self.chip ~= initial_chip then
            -- The Tags tab can create a new editable shelf. It belongs to
            -- the unscoped library, not the fixed prose/comics chip list.
            local chip = self.chip
            self.chip = initial_chip
            Context.withShelf(nil, function(shelf) shelf:_selectChip(chip) end)
        else
            refresh()
        end
    end
    function controller:_syncPageFromCursor() self.page = 1 end
    function controller:_orbitui_before_book_info()
        require("features/library/sui_book_hold_dialog").keepHomescreenAliveForNextShow()
    end
    function controller:_orbitui_after_book_info(widget)
        if not widget then return end
        local close = widget.close_callback
        widget.close_callback = function(...)
            if close then close(...) end
            refresh()
        end
    end
    function controller:_openBook(book)
        return (opts.open_book or Context.openBook)(book.filepath, book)
    end
    for _, method in ipairs({ "_expandAuthor", "_expandSeries", "_expandGenre",
            "_expandTag", "_expandFolder", "_selectChip" }) do
        controller[method] = function(self, value, whole)
            Context.withShelf(self.profile_key, function(shelf) shelf[method](shelf, value, whole) end)
        end
    end
    function controller:_orbitui_file_dialog_close(id)
        return function()
            if self._orbitui_modal then self._orbitui_modal:onClose() end
            local navigating = opts.navigate_row_ids
            if not navigating and opts.navigate_fn then
                navigating = require("features/library/sui_hold_rows").NAVIGATING_ROW_IDS
            end
            if navigating and navigating[id] and opts.navigate_fn then
                opts.navigate_fn()
            else
                refresh()
            end
        end
    end
    function controller:_fileDialogPluginRows(path)
        local close_and_refresh = function()
            if self._orbitui_modal then self._orbitui_modal:onClose() end
            refresh()
        end
        local rows = Widget._fileDialogPluginRows(self, path) or {}
        if opts.extra_rows then
            local ok, extra = pcall(opts.extra_rows, path, close_and_refresh)
            if ok then
                for _, row in ipairs(extra or {}) do rows[#rows + 1] = row end
            else
                require("logger").warn("OrbitUI book panel extra actions:", extra)
            end
        end
        if opts.open_settings_fn then
            rows[#rows + 1] = {{
                text = require("core/orbitui_i18n")("Open module settings"),
                callback = function() close_and_refresh(); opts.open_settings_fn() end,
            }}
        end
        return rows
    end
    function controller:_showBookDetail(book, detail_opts)
        detail_opts = detail_opts or {}
        local on_close = detail_opts.on_close
        detail_opts.on_close = function()
            refresh()
            if on_close then on_close() end
            if opts.on_close then opts.on_close() end
        end
        self._orbitui_modal = Widget._showBookDetail(self, book, detail_opts)
        return self._orbitui_modal
    end
    return controller
end

function M.show(file, opts)
    if type(file) ~= "string" or file == "" then return end
    local book = require("lib/bookshelf_book_repository").buildBookMeta(file, { want_cover = false })
    if not book then
        Context.notify(require("core/orbitui_i18n")("Could not load books."))
        return
    end
    return M.controller(file, opts):_showBookDetail(book, { active = "edit" })
end

-- Content drafts touch one native collection only, never book files, metadata,
-- favourites, remote lists or the membership of any other collection.
function M.collectionDraft(name, collections)
    local original = collections.coll[name]
    local settings = collections.coll_settings[name]
    if not original or not settings or name == collections.default_collection_name
            or (settings.folders and next(settings.folders)) then return nil, "managed" end
    local baseline, changes = {}, {}
    for file in pairs(original) do baseline[file] = true end
    local draft = { changes = changes, baseline = baseline }
    function draft:contains(file)
        if changes[file] ~= nil then return changes[file] end
        return baseline[file] == true
    end
    function draft:toggle(file)
        local value = not self:contains(file)
        if value == (baseline[file] == true) then changes[file] = nil
        else changes[file] = value end
    end
    function draft:counts()
        local add, remove = 0, 0
        for _file, value in pairs(changes) do
            if value then add = add + 1 else remove = remove + 1 end
        end
        return add, remove
    end
    function draft:save()
        if collections.coll[name] ~= original or collections.coll_settings[name] ~= settings
                or (settings.folders and next(settings.folders)) then return nil, "conflict" end
        local attrs = {}
        for file, value in pairs(changes) do
            if (original[file] ~= nil) ~= (baseline[file] == true) then return nil, "conflict" end
            if value then
                attrs[file] = require("libs/libkoreader-lfs").attributes(file)
                if not attrs[file] or attrs[file].mode ~= "file" then return nil, "missing" end
            end
        end
        if next(changes) == nil then return true end
        local backup = {}
        for file, entry in pairs(original) do backup[file] = entry end
        local ok, err = pcall(function()
            for file, value in pairs(changes) do
                if value then collections:addItem(file, name, attrs[file])
                else collections:removeItem(file, name, true) end
            end
            collections:write({ [name] = true })
        end)
        if not ok then
            -- Restore in-memory state on a native write error; keep the draft
            -- open so the reader can retry/cancel. Native storage owns disk IO.
            for file in pairs(original) do original[file] = nil end
            for file, entry in pairs(backup) do original[file] = entry end
            require("logger").warn("OrbitUI collection save:", err)
            return nil, "write"
        end
        return true
    end
    return draft
end

function M.collection(name, opts)
    opts = opts or {}
    local _ = require("core/orbitui_i18n")
    local UI = require("ui/uimanager")
    local Screen = require("device").screen
    local text_ok, Text = pcall(require, "infra/sui_text")
    local display_name = text_ok and Text.truncate(name, 48) or name
    local collections = require("readcollection")
    local draft = M.collectionDraft(name, collections)
    if not draft then
        Context.notify(_("This collection is managed by KOReader. Use its collection settings.")); return
    end
    local Repo = require("lib/bookshelf_book_repository")
    local Search = require("core/orbitui_search")
    local records, known, visible, query, tab, sort = {}, {}, {}, "", "members", "title"
    local modal, retired = nil, false
    local navigation = UI._simpleui_navigation_generation
    local function current() return not retired and navigation == UI._simpleui_navigation_generation end
    local function add(records_to_add)
        for _i, book in ipairs(records_to_add or {}) do
            local file = book.filepath
            if type(file) == "string" and file:sub(1, 1) == "/" and not known[file] then
                known[file] = book; records[#records + 1] = book
            end
        end
    end
    local ok, books = pcall(Repo.getBySource, { kind = "collection", id = name }, nil, nil,
        0, math.huge, nil, { light_only = true })
    if not ok then Context.notify(_("Could not load books.")); return end
    add(books)
    -- Keep missing/out-of-root entries removable; never drop them on Save.
    for file, entry in pairs(collections.coll[name]) do
        add({ { filepath = file, title = entry.text or file:match("([^/]+)$") } })
    end
    local function recompute()
        visible = {}
        local q = Search.lower(query)
        for _i, book in ipairs(records) do
            local file = book.filepath
            local author = book.author or book.authors or ""
            if type(author) == "table" then author = table.concat(author, ", ") end
            local text = Search.lower((book.title or file) .. " " .. author .. " " .. file)
            local include = tab == "members" and draft:contains(file)
                or tab == "add" and not draft:contains(file) and q ~= ""
                or tab == "changes" and draft.changes[file] ~= nil
            local matches = true
            for word in q:gmatch("%S+") do
                if not text:find(word, 1, true) then matches = false; break end
            end
            if include and matches then visible[#visible + 1] = book end
        end
        Search.sortBooks(visible, sort, query)
    end
    local function refresh(reset_page)
        if not current() then return end
        recompute()
        local plus, minus = draft:counts()
        modal.config.intro = display_name .. "\n" .. string.format(_("%d to add · %d to remove. Changes apply only when you Save."), plus, minus)
        if tab == "add" then modal.config.intro = modal.config.intro .. " " .. _("Search to find books to add.") end
        if reset_page then modal.page = 1 end
        modal:refresh()
    end
    local function close() if current() then modal:onClose() end end
    local views = { { key = "members", label = _("In collection") },
        { key = "add", label = _("Add books") }, { key = "changes", label = _("Changes") } }
    local function chooseView()
        if not current() then return end
        local picker, buttons = nil, {}
        for _i, view in ipairs(views) do
            buttons[#buttons + 1] = {{ text = view.label, callback = function()
                UI:close(picker)
                if not current() then return end
                tab = view.key; query = ""; modal.search_query = nil; refresh(true)
            end }}
        end
        buttons[#buttons + 1] = {{ text = _("Cancel"), callback = function() UI:close(picker) end }}
        picker = require("ui/widget/buttondialog"):new{ title = _("Show books"), buttons = buttons, sui_native = true }
        UI:show(picker)
    end
    local function save()
        if not current() then return end
        local saved, err = draft:save()
        if not saved then
            Context.notify(_(err == "conflict" and "This collection changed. Close and reopen the editor."
                or err == "missing" and "A selected book is no longer available. No changes were saved."
                or "Could not save the collection. Your draft is still open.")); return
        end
        close()
        Repo.invalidateBookCache("collections")
        Context.refresh()
        if opts.on_saved then opts.on_saved() end
    end
    recompute()
    modal = require("lib/bookshelf_library_modal"):new{ config = {
        title = _("Manage books"),
        intro = display_name .. "\n" .. string.format(_("%d to add · %d to remove. Changes apply only when you Save."), 0, 0),
        search_placeholder = function() return _("Title, author or filename") end,
        on_search_submit = function(value)
            if not current() then return end
            value = value or "" -- native clear/short-query callback supplies nil
            if tab == "add" and value:find("%S") then
                local success, matches = pcall(Repo.searchBooks, value, nil)
                if not success then Context.notify(_("Could not load books.")); return end
                add(matches)
            end
            query = value; refresh(true)
        end,
        grid_cols = 1, rows_per_page = 4,
        cells_per_page = function() return Screen:getWidth() > Screen:getHeight() and 3 or 4 end,
        empty_state = function(width, height)
            return require("lib/bookshelf_picker_cell").render({ label = _("No matches."),
                subtitle = tab == "add" and _("Search to find books to add.") or "" }, { w = width, h = height })
        end,
        item_count = function() return #visible end,
        item_at = function(index) return visible[index] end,
        cell_renderer = function(book, dimen)
            local selected = draft:contains(book.filepath)
            return require("lib/bookshelf_picker_cell").render({
                label = (selected and "✓ " or "+ ") .. (book.title or book.filepath),
                subtitle = draft.changes[book.filepath] == false and _("Will be removed")
                    or draft.changes[book.filepath] == true and _("Will be added")
                    or (selected and _("In collection") or _("Tap to add")),
            }, dimen, { selected = selected, tint = draft.changes[book.filepath] == false })
        end,
        on_cell_tap = function(book)
            if not current() then return end
            draft:toggle(book.filepath); refresh(false)
        end,
        footer_rows = {
            { { label_func = function()
                for _i, view in ipairs(views) do if view.key == tab then return view.label .. "…" end end
            end, on_tap = chooseView },
            { label_func = function() return _("Sort results") .. ": " .. _(sort == "title" and "Title" or "Author") end,
                on_tap = function() if current() then sort = sort == "title" and "author" or "title"; refresh(true) end end }},
            { { label = _("Cancel"), on_tap = close }, { label = _("Save"), primary = true, on_tap = save } },
        },
        on_closed = function() retired = true end,
    } }
    UI:show(modal)
    return modal, draft
end

return M
