local M = {}
local Context = require("core/orbitui_context")

local function escape(value)
    return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
        :gsub('"', "&quot;")
end
function M.information(book)
    local _ = require("core/orbitui_i18n")
    local rows = {}
    local function add(label, value)
        if value ~= nil and value ~= "" then
            rows[#rows + 1] = "<p><b>" .. escape(_(label)) .. "</b><br/>" .. escape(value) .. "</p>"
        end
    end
    add("Pages", book.page_count)
    add("Language", book.lang or book.language)
    add("Format", book.format)
    local attrs
    local ok, fs = pcall(require, "libs/libkoreader-lfs")
    if ok and book.filepath then attrs = fs.attributes(book.filepath) end
    local size = book.size or (attrs and attrs.size)
    if size then add("Size", require("lib/bookshelf_tokens").formatFileSize(size)) end
    local function date(value)
        value = tonumber(value)
        return value and value > 0 and os.date("%Y-%m-%d", value) or nil
    end
    add("Added", date(book.date_added or (attrs and attrs.modification)))
    local last = book.last_opened
    if not last then
        local ok_history, history = pcall(require, "readhistory")
        for _i, item in ipairs(ok_history and history.hist or {}) do
            if item.file == book.filepath then last = item.time; break end
        end
    end
    add("Last read", date(last))
    add("File name", book.filename or (book.filepath or ""):match("([^/]+)$"))
    add("Folder", (book.filepath or ""):match("^(.*)/[^/]+$"))
    return table.concat(rows, "\n")
end
function M.widget(widget)
    widget.orbitui_detail_view = function(self, book, opts)
        if not M.bookPageEnabled() then return end
        return M.bookPage(self, book, opts, function(next_opts)
            -- Bypass a lightweight controller's wrapping method: its close
            -- callback is already carried in opts, and must run only once.
            return widget._showBookDetail(self, book, next_opts)
        end)
    end
    widget.orbitui_tag_sections = function(self, book, modal)
        return M.tagSections(self, book, modal, true)
    end
    widget.orbitui_detail_args = function(self, book, args, opts)
        local _ = require("core/orbitui_i18n")
        local selected = args.tabs[args.active_tab] and args.tabs[args.active_tab].id
        if opts and opts.active == "information" then selected = "information" end
        for _i, tab in ipairs(args.tabs) do if tab.id == "tags" then tab.label = _("Tags") end end
        -- Keep all native tabs, plugin actions, sources and their close/open
        -- lifecycle. The new read-only page is built only when selected.
        local position = #args.tabs + 1
        for i, tab in ipairs(args.tabs) do if tab.id == "edit" then position = i; break end end
        table.insert(args.tabs, position, { id = "information", label = _("Book details"),
            widget_builder = function(w, h, modal)
                -- The headed helper requires a real header widget. This tab
                -- has none; retain the modal's native scroller/gesture owner.
                return modal:_scroller{
                    html_body = M.information(book), css = modal._css,
                    default_font_size = require("device").screen:scaleBySize(modal.font_size or 20),
                    width = w, height = h, dialog = modal,
                }
            end })
        for i, tab in ipairs(args.tabs) do if tab.id == selected then args.active_tab = i end end
        args.open_text = _("Read now")
        args.header_builder = function(width)
            local pct, status = require("lib/bookshelf_book_repository").readProgress(book.filepath)
            local text = status == "finished" and _("Finished")
                or string.format(_("%d%% read"), math.floor(math.max(0, math.min(1, tonumber(pct) or 0)) * 100 + .5))
            return self:_buildBookMenuHeader(book, width, nil, nil, { rich = true, summary_text = text })
        end
    end
end

local tag_states = setmetatable({}, { __mode = "k" })
function M.tagSections(owner, book, modal, cached)
    local _ = require("core/orbitui_i18n")
    local Integration = require("adapters/orbitui_integrations")
    local UI = require("ui/uimanager")
    if not modal then return {} end
    local state = tag_states[modal]
    if not state then
        state = { navigation = UI._simpleui_navigation_generation }
        if cached then
            -- One validated per-file cache peek, never an EPUB read/index job.
            state.embedded = { tags = Integration.embeddedTags(book.filepath, false, true, true) }
        end
        tag_states[modal] = state
    end
    state.render = (state.render or 0) + 1
    local render = state.render
    local function current()
        return not modal._dismissed and not modal._closed and UI:isWidgetShown(modal)
            and state.navigation == UI._simpleui_navigation_generation
    end
    local function refresh()
        if current() and modal.orbitui_overview then modal:rebuild(); UI:setDirty(modal, "ui"); return end
        local tab = modal._tabs and modal._tabs[modal._active_tab]
        if current() and modal.rebuildTab and tab and tab.id == "tags" then modal:rebuildTab() end
    end
    local pills = {}
    if state.session and not state.session:current() then
        state.tags, state.session, state.error = nil, nil, Integration.bookOrbitError("stale")
    end
    for _, tag in ipairs(state.tags or {}) do
        pills[#pills + 1] = { label = tag, on_tap = function()
            if not current() or state.render ~= render or state.busy or not state.session or not state.session:current() then return end
            modal:onClose()
            require("core/orbitui_search").bookOrbitTag(tag, {
                origin = book.filepath, view_profile = owner.profile_key,
                open_book = function(file, record) owner:_openBook(record or { filepath = file }) end,
            })
        end }
    end
    pills[#pills + 1] = { label = _(state.busy and "Loading…" or state.tags and "Refresh BookOrbit tags" or "Load BookOrbit tags"),
        link = true, on_tap = function()
            if not current() or state.render ~= render or state.busy then return end
            local session, err = Integration.bookOrbitSession()
            if not session then state.error = Integration.bookOrbitError(err); refresh(); return end
            state.busy, state.error = true, nil
            refresh()
            Integration.bookOrbitRequest(session, function(s) return s:detail(book.filepath) end, current, function(result, failure)
                state.busy = false
                if result then state.tags, state.session = result.tags, session
                elseif failure ~= "cancelled" then state.error = Integration.bookOrbitError(failure) end
                refresh()
            end)
        end }
    local remote = { title = _("BookOrbit tags (optional online source)"), pills = pills,
        note = state.error or (state.tags and #state.tags == 0 and _("No BookOrbit tags for this book."))
            or _("Tap a tag to find linked books on this device, across all library profiles. Tags are read-only; nothing is synced or edited.") }
    local local_state = state.embedded
    if not local_state then local_state = {}; state.embedded = local_state end
    local local_pills = {}
    for _, tag in ipairs(local_state.tags or {}) do
        local_pills[#local_pills + 1] = { label = tag, on_tap = function()
            if not current() or state.render ~= render or local_state.busy then return end
            modal:onClose()
            require("core/orbitui_search").embeddedTag(tag, {
                origin = book.filepath,
                view_profile = owner.profile_key,
                open_book = function(file, record) owner:_openBook(record or { filepath = file }) end,
            })
        end, on_hold = function()
            if not current() or state.render ~= render or local_state.busy then return end
            require("adapters/orbitui_library_settings").tagChip{
                tag = tag, tags = local_state.tags, profile = owner.profile_key,
                is_current = function() return current() and state.render == render and not local_state.busy end,
                on_saved = function() if current() then modal:onClose() end end,
            }
        end }
    end
    local_pills[#local_pills + 1] = { label = _(local_state.busy and "Loading…"
            or local_state.tags and "Refresh EPUB tags" or "Read EPUB tags"), link = true,
        on_tap = function()
            if not current() or state.render ~= render or local_state.busy then return end
            local_state.busy, local_state.error = true, nil
            refresh()
            Integration.embeddedTagRequest(nil, { file = book.filepath, refresh = true }, current, function(result, failure)
                local_state.busy = false
                if result then local_state.tags = result.tags
                elseif failure ~= "cancelled" then local_state.error = Integration.embeddedTagError(failure) end
                refresh()
            end)
        end }
    if type(book.filepath) == "string" and book.filepath:sub(1, 1) == "/" and book.filepath:lower():match("%.epub$") then
        local_pills[#local_pills + 1] = { label = _("Find similar books and series…"), link = true,
            on_tap = function()
                if not current() or state.render ~= render or local_state.busy then return end
                modal:onClose()
                require("core/orbitui_search").similarBooks(book.filepath, {
                    title = book.title, view_profile = owner.profile_key,
                    open_book = function(file, record) owner:_openBook(record or { filepath = file }) end,
                })
            end }
    end
    local sections = {{ title = _("EPUB tags (offline)"), pills = local_pills,
        note = local_state.error or (local_state.tags and #local_state.tags == 0 and _("No separate tags embedded in this EPUB. Standard EPUB subjects are shown as genres below."))
            or _("Tap a local EPUB tag to search. Long-press to save a smart chip, optionally combining tags. No account or connection is needed; nothing is synced or edited.") }}
    if Integration.bookOrbitEnabled("tags") then sections[#sections + 1] = remote end
    return sections
end

local information = M.information
function M.information(...)
    return require("core/orbitui_host").measure("details", information, ...)
end

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
    return M.controller(file, opts):_showBookDetail(book)
end

local book_page_key = "orbitui_book_overview"
function M.bookPageEnabled()
    return not G_reader_settings or G_reader_settings:readSetting(book_page_key) ~= false
end
function M.bookPageItems(changed)
    local _ = require("core/orbitui_i18n")
    return {{ text = _("Use the airy book information page"), checked_func = M.bookPageEnabled,
        callback = function()
            if not G_reader_settings then return end
            G_reader_settings:saveSetting(book_page_key, not M.bookPageEnabled())
            if changed then changed() end
        end }, { text = _("Covers, description and tags in one overview. Actions opens the existing editor; turn this off to use the classic tabbed view."), enabled = false }}
end

-- Presentation only: native tabs retain every editing/source/plugin action.
-- One book's cached metadata and tags, never a library scan or network request.
function M.bookPage(owner, record, options, classic)
    local UI, Screen = require("ui/uimanager"), require("device").screen
    local BB, Geom, Font = require("ffi/blitbuffer"), require("ui/geometry"), require("lib/bookshelf_fonts")
    local Frame, Text = require("ui/widget/container/framecontainer"), require("ui/widget/textboxwidget")
    local V, H = require("ui/widget/verticalgroup"), require("ui/widget/horizontalgroup")
    local VS, HS = require("ui/widget/verticalspan"), require("ui/widget/horizontalspan")
    local Button, Center = require("ui/widget/button"), require("ui/widget/container/centercontainer")
    local Scroll = require("ui/widget/container/scrollablecontainer")
    local Repo, Tokens = require("lib/bookshelf_book_repository"), require("lib/bookshelf_tokens")
    local _ = require("core/orbitui_i18n")
    options = options or {}
    local px = function(n) return math.max(1, Screen:scaleBySize(n)) end
    local function clean(value, limit)
        if type(value) ~= "string" then return "" end
        value = value:gsub("[%c]", " ")
        local n = limit or 2048
        if #value <= n then return value end
        while value:byte(n + 1) and value:byte(n + 1) >= 128 and value:byte(n + 1) < 192 do n = n - 1 end
        return value:sub(1, n) .. "…"
    end
    local book = {}
    local ok, fresh = pcall(Repo.buildBookMeta, record.filepath, { want_cover = false })
    for k, v in pairs(ok and type(fresh) == "table" and fresh or {}) do book[k] = v end
    for k, v in pairs(record) do if v ~= nil then book[k] = v end end
    book.cover_bb = nil -- the shelf's one-shot image must never be borrowed
    local read_ok, pct, status, rating = pcall(Repo.readProgress, book.filepath)
    pct = read_ok and tonumber(pct) or 0
    if not pct or pct ~= pct then pct = 0 end
    pct = math.max(0, math.min(1, pct))
    local authors = clean(book.author)
    if authors == "" and type(book.authors) == "table" then
        local names = {}; for i = 1, math.min(8, #book.authors) do names[#names + 1] = clean(book.authors[i], 256) end
        authors = table.concat(names, ", ")
    end
    local description = Tokens.cleanDescription(clean(book.description, 12000)) or ""
    local Page = require("ui/widget/focusmanager"):extend{
        name = "orbitui_book_overview", modal = true, orbitui_overview = true,
        _sui_keep_homescreen = owner._orbitui_detail_only or nil,
    }
    function Page:current(revision)
        return not self._closed and (not revision or revision == self.revision)
            and self.navigation == UI._simpleui_navigation_generation
            and UI:isWidgetShown(self) and UI:getTopmostVisibleWidget() == self
    end
    function Page:onClose() if not self._closed then UI:close(self) end; return true end
    function Page:onCloseWidget()
        if self._closed then return end
        self._closed = true
        if self[1] then self[1]:free(); self[1] = nil end
        if self.owned_cover and self.cover then self.cover:free() end
        self.cover = nil
        UI:setDirty("all", "ui")
        if not self.handoff and options.on_close then options.on_close() end
    end
    function Page:onSuspend() return self:onClose() end
    function Page:onScreenResize() return self:onClose() end
    Page.onSetRotationMode = Page.onScreenResize
    function Page:onShowingReader() return self:onClose() end
    function Page:openTab(id)
        if not self:current() then return end
        self.handoff = true; self:onClose()
        local modal = classic{ active = id, classic = true, on_close = options.on_close }
        if owner._orbitui_detail_only then owner._orbitui_modal = modal end
        return modal
    end
    function Page:getButtonById(id) return self.native_buttons[id] end
    function Page:onFocusMove(args)
        local result = require("ui/widget/focusmanager").onFocusMove(self, args)
        local scroll, sel = self.cropping_widget, self.selected
        if scroll and scroll._is_scrollable and sel and sel.y > 1 and sel.y < #self.layout then
            local item = self.layout[sel.y] and self.layout[sel.y][sel.x]
            local d, view = item and item.dimen, scroll.dimen
            if d and d.y and view and view.y then
                if d.y < view.y then scroll:_scrollBy(0, d.y - view.y - px(8))
                elseif d.y + d.h > view.y + view.h then scroll:_scrollBy(0, d.y + d.h - view.y - view.h + px(8)) end
            end
        end
        return result
    end
    function Page:rebuild()
        if self._closed then return end
        if self[1] then self[1]:free(); self[1] = nil end
        self.revision = (self.revision or 0) + 1
        local revision = self.revision
        self.layout, self.native_buttons = {}, {}
        local sw, sh = Screen:getWidth(), Screen:getHeight()
        local pad = math.min(px(24), math.floor(sw / 16))
        local inner = sw - 2 * pad
        -- Reserve the native scrollbar's actual width, including after rotate.
        local w = inner - Scroll:getScrollbarWidth()
        local function space(n) return VS:new{ width = px(n) } end
        local function gap(n) return HS:new{ width = px(n) } end
        local function text(copy, size, bold, width, maxh, color)
            local face, face_bold = Font:getFace("cfont", size)
            local opts = { text = clean(copy, 12000), width = width, face = face, bold = bold or face_bold,
                fgcolor = color or BB.COLOR_BLACK, bgcolor = BB.COLOR_WHITE, height_overflow_show_ellipsis = true }
            local item = Text:new(opts)
            if maxh and item:getSize().h > maxh then
                item:free(); opts.height, opts.height_adjust = maxh, false; item = Text:new(opts)
            end
            return item
        end
        local function button(id, copy, width, callback, primary, hold, content)
            local b = Button:new{ text = clean(copy), width = width, height = math.max(px(30), content and content:getSize().h or 0),
                padding_h = px(6), padding_v = px(7), margin = 0, bordersize = (content or id == "close") and 0 or px(1), radius = px(8),
                background = primary and BB.COLOR_BLACK or nil,
                text_font_size = 16, avoid_text_truncation = false,
                callback = function() if self:current(revision) then callback() end end,
                hold_callback = hold and function() if self:current(revision) then hold() end end }
            if content then
                b.label_widget:free(); b.label_widget = content; b.label_container[1] = content
            elseif primary then b.label_widget.fgcolor, b.label_widget.bgcolor = BB.COLOR_WHITE, BB.COLOR_BLACK end
            self.native_buttons[id] = b; return b
        end
        local function rowButton(id, copy, tab)
            local content = H:new{ align = "center", text(copy, 16, false, w - px(36)), gap(8), text("›", 20, false, px(10)) }
            local b = button(id, "", w, function() self:openTab(tab) end, false, nil, content)
            self.layout[#self.layout + 1] = { b }; return b
        end
        local close = button("close", "×", px(44), function() self:onClose() end)
        local top = V:new{ align = "left", H:new{ align = "center",
            text(_("Book information"), 18, true, inner - px(44), px(54)), close }, space(12) }
        self.layout[#self.layout + 1] = { close }
        local body = V:new{ align = "left" }
        local coverw = math.min(px(112), math.floor(w * .29))
        local coverh = math.floor(coverw * 1.5)
        local art
        if self.cover then
            local ratio = math.min(1, coverw / self.cover:getWidth(), coverh / self.cover:getHeight())
            art = require("ui/widget/imagewidget"):new{ image = self.cover, image_disposable = false,
                width = math.max(1, math.floor(self.cover:getWidth() * ratio)), height = math.max(1, math.floor(self.cover:getHeight() * ratio)) }
        else art = text(_("No cover"), 14, false, coverw - px(8), coverh, BB.COLOR_DARK_GRAY) end
        local cover = Center:new{ dimen = Geom:new{ w = coverw, h = coverh }, art }
        local titlew = w - coverw - px(18)
        local hero = V:new{ align = "left", text(clean(book.title) ~= "" and book.title or book.filename or _("Book"),
            26, true, titlew, px(142)), space(7), text(authors, 17, false, titlew, px(70), BB.COLOR_DARK_GRAY), space(14) }
        local state = status == "finished" and _("Finished") or status == "abandoned" and _("On hold")
            or pct > 0 and string.format(_("%d%% read"), math.floor(pct * 100 + .5)) or _("Not started")
        hero[#hero + 1] = text(state, 16, true, titlew)
        local score = tonumber(rating or book.rating)
        if score and score >= 1 and score <= 5 then
            hero[#hero + 1] = space(7)
            hero[#hero + 1] = text(string.format(_("Your rating: %s / 5"), score), 14, false, titlew, nil, BB.COLOR_DARK_GRAY)
        end
        body[#body + 1] = H:new{ align = "top", cover, gap(18), hero }
        local facts = {}
        local function fact(label, value) value = clean(value, 512); if value ~= "" then facts[#facts + 1] = { _(label), value } end end
        fact("Series", book.series_name or book.series)
        if #facts > 0 and book.series_name and tonumber(book.series_num) then facts[1][2] = facts[1][2] .. " · " .. tostring(book.series_num) end
        fact("Language", book.lang or book.language)
        fact("Format", clean(book.format) ~= "" and book.format:upper() or (book.filepath:match("%.([^./]+)$") or ""):upper())
        if #facts > 0 then
            body[#body + 1] = space(22)
            local wide = w >= px(390)
            local cellw = wide and math.floor((w - (#facts - 1) * px(10)) / #facts) or w
            local strip = wide and H:new{ align = "top" } or V:new{ align = "left" }
            for i, value in ipairs(facts) do
                if i > 1 then strip[#strip + 1] = wide and gap(10) or space(10) end
                strip[#strip + 1] = V:new{ align = "left", text(value[1], 13, false, cellw, nil, BB.COLOR_DARK_GRAY),
                    space(4), text(value[2], 16, true, cellw, px(65)) }
            end
            body[#body + 1] = strip
        end
        body[#body + 1] = space(24)
        body[#body + 1] = text(_("About this book"), 18, true, w); body[#body + 1] = space(9)
        local base = tonumber(require("lib/bookshelf_settings_store").read("desc_font_size", 20)) or 20
        if base ~= base then base = 20 end
        base = math.max(12, math.min(40, base))
        body[#body + 1] = text(description ~= "" and description or _("No description available."), base, false, w, px(base * 5.4))
        if description ~= "" then body[#body + 1] = space(10); body[#body + 1] = rowButton("description", _("Full description"), "description") end
        body[#body + 1] = space(24); body[#body + 1] = text(_("Tags"), 18, true, w); body[#body + 1] = space(8)
        for section_i, section in ipairs(M.tagSections(owner, book, self, true)) do
            body[#body + 1] = text(section_i == 1 and _("EPUB tags (offline)") or section.title, 13, false, w, nil, BB.COLOR_DARK_GRAY)
            body[#body + 1] = space(8)
            local line, focus, used, lines, visible = H:new{ align = "center" }, {}, 0, 1, 0
            local function flush()
                if #focus > 0 then body[#body + 1] = line; self.layout[#self.layout + 1] = focus; body[#body + 1] = space(7) end
                line, focus, used = H:new{ align = "center" }, {}, 0
            end
            for i, pill in ipairs(section.pills) do
                if not pill.link then
                    local probe = require("ui/widget/textwidget"):new{ text = clean(pill.label, 800), face = Font:getFace("cfont", 16) }
                    local width = math.min(w, probe:getSize().w + px(24)); probe:free()
                    if used > 0 and used + px(8) + width > w then flush(); lines = lines + 1 end
                    if lines > 2 then break end
                    local b = button("tag:" .. section_i .. ":" .. i, pill.label, width, pill.on_tap, false, pill.on_hold)
                    if used > 0 then line[#line + 1] = gap(8); used = used + px(8) end
                    line[#line + 1] = b; focus[#focus + 1] = b; used = used + width; visible = visible + 1
                end
            end
            flush()
            if visible == 0 then body[#body + 1] = text(section.note or _("No tags available."), 14, false, w, px(60), BB.COLOR_DARK_GRAY) end
            body[#body + 1] = space(8)
        end
        -- Explicit refresh, online loads and similarity tools stay in Tags.
        body[#body + 1] = rowButton("tags", _("All tags and tag tools"), "tags"); body[#body + 1] = space(22)
        for _i, action in ipairs{{ "reviews", "Reviews" }, { "information", "File information" }, { "cover", "Cover" }} do
            body[#body + 1] = rowButton(action[1], _(action[2]), action[1]); body[#body + 1] = space(7)
        end
        local half = math.floor((inner - px(10)) / 2)
        local read = button("read", pct > 0 and status ~= "finished" and _("Continue reading") or _("Read now"), half,
            function() self:onClose(); owner:_openBook(book) end, true)
        local actions = button("actions", _("Actions…"), inner - half - px(10), function() self:openTab("edit") end)
        local footer = V:new{ align = "left", space(12), H:new{ align = "center", read, gap(10), actions } }
        self.layout[#self.layout + 1] = { read, actions }
        local maxh = math.max(1, sh - 2 * pad - top:getSize().h - footer:getSize().h)
        self.cropping_widget = Scroll:new{ dimen = Geom:new{ w = inner, h = maxh }, show_parent = self, body }
        self[1] = Frame:new{ padding = pad, margin = 0, bordersize = 0, background = BB.COLOR_WHITE,
            V:new{ align = "left", top, self.cropping_widget, footer } }
        self.dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh }
        self.key_events.Close = {{ "Back" }, { "Esc" }}
        self.selected = { x = 1, y = 1 }
    end
    function Page:init()
        self.navigation = UI._simpleui_navigation_generation
        if owner._orbituiDetailCover then
            local success, bb, owned = pcall(owner._orbituiDetailCover, owner, book, px(126))
            if success and bb then
                local valid, cw, ch = pcall(function() return bb:getWidth(), bb:getHeight() end)
                if valid and type(cw) == "number" and type(ch) == "number" and cw > 0 and ch > 0 then self.cover, self.owned_cover = bb, owned
                elseif owned then bb:free() end
            end
        end
        self:rebuild()
    end
    local page = Page:new{}; UI:show(page); return page
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

-- Reader reference drawer. Kept lazy in this existing book-panel adapter to
-- retain the API-1 installed path budget. No Aleph implementation or assets.
function M.readerPins()
    if M._reader_pins then return M._reader_pins end
    local P = {}
    M._reader_pins = P
    local _ = require("core/orbitui_i18n")
    local UI = require("ui/uimanager")
    local states = setmetatable({}, { __mode = "k" })
    local KEY, BUTTON, LIMIT = "orbitui_reader_pins", "zz_orbitui_pin_reference", 12
    local function notify(text) Context.notify(_(text)) end
    local function integer(n, max)
        return type(n) == "number" and n >= 1 and n <= (max or 1e9) and n == math.floor(n)
    end
    local function short(s, max) return type(s) == "string" and #s > 0 and #s <= max end
    local function truncate(text, n)
        while n > 0 do
            local next_byte = text:byte(n + 1)
            if not next_byte or next_byte < 128 or next_byte >= 192 then break end
            n = n - 1
        end
        return text:sub(1, n)
    end
    local function live(s)
        local R = package.loaded["apps/reader/readerui"]
        local top = UI:getTopmostVisibleWidget()
        local name = top and top.name
        if name == "bookshelf" or name == "homescreen" or name == "filemanager" then return false end
        return not s.closed and not s.sleeping and s.ui.document == s.document
            and s.ui.doc_settings == s.settings and (not R or R.instance == s.ui)
            and UI:isWidgetShown(s.ui)
    end
    local function store(s)
        local data = s.settings:readSetting(KEY)
        if data == nil then return { version = 1, next_id = 1, entries = {} } end
        -- Unknown/corrupt versions are preserved, not repaired or overwritten.
        if type(data) ~= "table" or data.version ~= 1 or not integer(data.next_id)
                or type(data.entries) ~= "table" or #data.entries > LIMIT then return end
        local seen, count = {}, 0
        for k, entry in pairs(data.entries) do
            if not integer(k, #data.entries) or type(entry) ~= "table" or not integer(entry.id)
                    or seen[entry.id] or entry.id >= data.next_id
                    or (entry.engine ~= "rolling" and entry.engine ~= "paging")
                    or (entry.engine == "rolling" and not short(entry.location, 4096))
                    or (entry.engine == "paging" and not integer(entry.location))
                    or (entry.kind ~= "page" and entry.kind ~= "text" and entry.kind ~= "image")
                    or (entry.kind == "text" and not short(entry.text, 4096))
                    or (entry.text ~= nil and not short(entry.text, 4096))
                    or (entry.digest ~= nil and not short(entry.digest, 256)) then return end
            if entry.kind == "image" and (not short(entry.image_key, 64) or #entry.image_key ~= 64
                    or entry.image_key:find("[^0-9a-f]") or not integer(entry.slot, LIMIT)) then return end
            seen[entry.id] = true
            count = count + 1
        end
        if count ~= #data.entries then return end
        return data
    end
    local function clone(data)
        local result = { version = 1, next_id = data.next_id, entries = {} }
        for i, entry in ipairs(data.entries) do
            local copy = {}; for k, v in pairs(entry) do copy[k] = v end
            result.entries[i] = copy
        end
        return result
    end
    local function save(s, data)
        if not live(s) then return false end
        local ok, result = pcall(s.settings.saveSetting, s.settings, KEY, data)
        if not ok or result == false then notify("Could not save the reference. Nothing was removed."); return false end
        -- Only this namespaced setting; native ReaderUI owns normal flushing.
        return true
    end
    local function page(s, entry)
        if (s.ui.rolling and "rolling" or "paging") ~= entry.engine then return end
        local digest = s.settings:readSetting("partial_md5_checksum")
        if entry.digest and entry.digest ~= digest then return end
        local ok, p = pcall(function()
            local n = entry.engine == "rolling" and s.document:getPageFromXPointer(entry.location) or entry.location
            return integer(n) and n <= s.document:getPageCount() and n or nil
        end)
        if ok then return p end
    end
    local function snapshotPath(entry)
        local dir = require("datastorage"):getSettingsDir()
        local fs = require("libs/libkoreader-lfs")
        for _, part in ipairs{ "orbitui", "reader-pins", entry.image_key } do
            dir = dir .. "/" .. part
            local a = fs.symlinkattributes(dir)
            if not a or a.mode ~= "directory" then return end
        end
        return dir .. "/slot" .. entry.slot .. ".png"
    end
    local function removeSnapshot(entry)
        if entry.kind ~= "image" then return end
        local path = snapshotPath(entry)
        if not path then return end
        local attrs = require("libs/libkoreader-lfs").symlinkattributes(path)
        if attrs and attrs.mode == "file" then os.remove(path) end
    end
    local function releasePreview(w)
        local child = w.preview and w.preview[1]
        if child and child.free then child:free() end
        if w.bb then w.bb:free(); w.bb = nil end
    end
    local function cancelPreview(s)
        if s.batch and s.ui.thumbnail then s.ui.thumbnail:cancelPageThumbnailRequests(s.batch) end
        s.batch = nil
    end
    local function closeWindow(s, key)
        local w = s[key]
        if w then s[key] = nil; UI:close(w) end
    end
    local function track(s, key, widget)
        s[key] = widget
        local original = widget.onCloseWidget
        widget.onCloseWidget = function(this, ...)
            if s[key] == this then s[key] = nil end
            if original then return original(this, ...) end
        end
        return widget
    end
    function P.disarm(s)
        if s.expiry then UI:unschedule(s.expiry); s.expiry = nil end
        s.armed = nil
        if s.hold_wrapper and s.ui.highlight.onHold == s.hold_wrapper then
            s.ui.highlight.onHold = s.hold_original
        end
        s.hold_wrapper, s.hold_original = nil, nil
    end
    function P.retire(ui, detach)
        local s = states[ui]; if not s then return end
        P.disarm(s); cancelPreview(s)
        for _, key in ipairs{ "viewer", "drawer", "list", "confirm" } do closeWindow(s, key) end
        if detach then
            s.closed = true
            local h = ui.highlight
            if h and h._highlight_buttons and h._highlight_buttons[BUTTON] == s.button then
                h:removeFromHighlightDialog(BUTTON)
            end
            states[ui] = nil
        end
    end
    function P.event(handler, ui)
        local s = states[ui]; if not s then return end
        if handler == "onCloseDocument" or handler == "onTeardown" then P.retire(ui, true)
        elseif handler == "onSuspend" then P.retire(ui); s.sleeping = true
        elseif handler == "onResume" then s.sleeping = false -- never reopen a retired panel
        elseif handler == "onSetRotationMode" or handler == "onScreenResize"
                or handler == "onChangeSize" or handler == "onDocumentRerendered"
                or handler == "onShowBookshelf" or handler == "onOpenBookshelfProfile"
                or handler == "onShowHomescreen" or handler == "onGoHome" then P.retire(ui) end
    end
    local function capture(s, text, location)
        if not live(s) then return end
        local engine = s.ui.rolling and "rolling" or "paging"
        if not location then
            local ok, current = pcall(function()
                return s.ui.rolling and s.document:getXPointer() or s.ui:getCurrentPage()
            end)
            if not ok then return end
            location = current
        end
        if (engine == "rolling" and not short(location, 4096)) or (engine == "paging" and not integer(location)) then return end
        return { engine = engine, location = location, kind = text and "text" or "page",
            text = text and truncate(text, 4096) or nil, digest = s.settings:readSetting("partial_md5_checksum") }
    end
    local function append(s, entry)
        local data = store(s)
        if not data then notify("Saved references use an unsupported format. They were left untouched."); return false end
        for _, old in ipairs(data.entries) do
            if entry.kind ~= "image" and old.kind == entry.kind and old.engine == entry.engine
                    and old.location == entry.location and old.text == entry.text then
                notify("This reference is already pinned."); return false
            end
        end
        if #data.entries >= LIMIT or data.next_id >= 1e9 then notify("This book already has 12 references. Remove one first."); return false end
        data = clone(data); entry.id = data.next_id; data.next_id = data.next_id + 1
        table.insert(data.entries, entry)
        if save(s, data) then notify("Reference pinned. Open Pinned references in the reading menu."); return true end
        return false
    end
    function P.pin(ui, text, location)
        if text ~= nil and (type(text) ~= "string" or #text == 0) then return false end
        local s = P.attach(ui)
        local entry = s and capture(s, text, location)
        return entry and append(s, entry) or false
    end
    local function imageSnapshot(s, position)
        local entry = capture(s); if not entry then return false end
        local data = store(s)
        if not data then notify("Saved references use an unsupported format. They were left untouched."); return false end
        if #data.entries >= LIMIT then notify("This book already has 12 references. Remove one first."); return false end
        local image, scaled, filename
        local ok = pcall(function()
            image = s.document:getImageFromPosition(position, false, false)
            assert(image and type(image) ~= "function" and image.getWidth and image.getHeight, "No static image")
            local w, h = image:getWidth(), image:getHeight()
            assert(integer(w, 16384) and integer(h, 16384) and w * h <= 4 * 1024 * 1024, "Image too large")
            local ratio = math.min(1, 1024 / w, 1024 / h)
            scaled = require("ui/renderimage"):scaleBlitBuffer(image,
                math.max(1, math.floor(w * ratio)), math.max(1, math.floor(h * ratio)), false)
            assert(scaled, "Scaling failed")
            entry.image_key = require("ffi/sha2").sha256(s.document.file)
            local fs = require("libs/libkoreader-lfs")
            local dir = require("datastorage"):getSettingsDir()
            for _, part in ipairs{ "orbitui", "reader-pins", entry.image_key } do
                dir = dir .. "/" .. part
                local a = fs.symlinkattributes(dir)
                assert(not a or a.mode == "directory", "Snapshot folder is not a plain directory")
                if not a then assert(fs.mkdir(dir), "Cannot create snapshot folder") end
            end
            for slot = 1, LIMIT do
                entry.slot = slot
                local path = snapshotPath(entry)
                if not fs.symlinkattributes(path) then filename = path; break end
            end
            assert(filename, "Snapshot slots full")
            assert(scaled:writePNG(filename) ~= false, "PNG write failed")
            local attr = fs.symlinkattributes(filename)
            assert(attr and attr.mode == "file" and attr.size > 0 and attr.size <= 2 * 1024 * 1024, "Snapshot too large")
        end)
        if scaled and scaled ~= image then scaled:free() end
        if type(image) == "function" then pcall(image, false) -- defensive scalable-image release
        elseif image and image.free then image:free() end
        if not ok then
            if filename then os.remove(filename) end -- only the newly created, never adopted, file
            notify("Could not pin this image. Use Pin current page instead. Static EPUB images up to 4 megapixels are supported.")
            return false
        end
        entry.kind = "image"
        if append(s, entry) then return true end
        removeSnapshot(entry)
        return false
    end
    function P.armImage(ui)
        local s = P.attach(ui)
        if not s or not live(s) or not ui.rolling or not ui.highlight
                or type(ui.highlight.onHold) ~= "function" then return false end
        local arm = {}
        P.retire(ui); s.armed = arm
        local generation = UI._simpleui_navigation_generation
        local highlight = ui.highlight
        s.hold_original = highlight.onHold
        local original = s.hold_original
        local wrapper
        wrapper = function(this, ...)
            if s.armed ~= arm then return original(this, ...) end
            local _arg, ges = ...
            P.disarm(s)
            if not live(s) or generation ~= UI._simpleui_navigation_generation then return false end
            local pos = ges and ges.pos and ui.view:screenToPageTransform(ges.pos)
            if not pos then notify("No image here. Try Pin current page instead."); return true end
            imageSnapshot(s, pos)
            return true
        end
        s.hold_wrapper = wrapper; highlight.onHold = wrapper
        s.expiry = function() if s.armed == arm then P.disarm(s) end end
        UI:scheduleIn(30, s.expiry)
        notify("Long-press an EPUB image within 30 seconds to pin a local copy. Ordinary image viewing is unchanged afterwards.")
        return true
    end
    function P.attach(ui)
        if not ui or not ui.document or not ui.doc_settings then return end
        if states[ui] then return states[ui] end
        local s = { ui = ui, document = ui.document, settings = ui.doc_settings }
        states[ui] = s
        local h = ui.highlight
        if h and h.addToHighlightDialog and h.removeFromHighlightDialog
                and h._highlight_buttons and not h._highlight_buttons[BUTTON] then
            s.button = function(this)
                return { text = _("Pin reference"), callback = function()
                    if not live(s) then return end
                    local selected = this.selected_text
                    if not selected or not short(selected.text, 65536) then return end
                    local loc = s.ui.rolling and type(selected.pos0) == "string" and selected.pos0 or nil
                    P.pin(ui, selected.text, loc)
                    if this.highlight_dialog then UI:close(this.highlight_dialog); this.highlight_dialog = nil end
                    this:clear()
                end }
            end
            h:addToHighlightDialog(BUTTON, s.button)
        end
        return s
    end
    local function entryById(s, id)
        local data = store(s)
        for i, entry in ipairs(data and data.entries or {}) do if entry.id == id then return entry, i, data end end
    end
    function P.remove(ui, id)
        local s = states[ui]; if not s or not live(s) then return false end
        local entry, i, data = entryById(s, id); if not entry then return false end
        data = clone(data); table.remove(data.entries, i)
        if not save(s, data) then return false end
        local shared = false
        for _, other in ipairs(data.entries) do
            if entry.kind == "image" and other.image_key == entry.image_key and other.slot == entry.slot then shared = true end
        end
        if not shared then removeSnapshot(entry) end
        return true
    end
    function P.jump(ui, id)
        local s = states[ui]; if not s or not live(s) then return false end
        local entry = entryById(s, id)
        if not entry or not page(s, entry) then notify("This reference cannot be located in the current book layout."); return false end
        P.retire(ui)
        ui.link:addCurrentLocationToStack()
        if entry.engine == "rolling" then ui.rolling:onGotoXPointer(entry.location)
        else ui.paging:onGotoPage(entry.location) end
        return true
    end
    function P.list(ui)
        local s = P.attach(ui); if not s or not live(s) then return end
        P.retire(ui)
        local data = store(s)
        if not data then notify("Saved references use an unsupported format. They were left untouched."); return end
        local buttons, list = {}, nil
        for i = #data.entries, 1, -1 do
            local entry = data.entries[i]
            local label = entry.kind == "image" and _("Image") or entry.kind == "text" and _("Text excerpt") or _("Page")
            local n = page(s, entry)
            buttons[#buttons + 1] = {{ text = label .. " · " .. (n and tostring(n) or "?")
                .. (entry.text and (" · " .. truncate(entry.text, 80):gsub("%s+", " ")) or ""),
                callback = function()
                    if s.list == list then closeWindow(s, "list"); P.show(ui, entry.id) end
                end }}
        end
        if #buttons == 0 then buttons[1] = {{ text = _("No references pinned in this book."), enabled = false }} end
        buttons[#buttons + 1] = {{ text = _("Pin current page"), callback = function()
            if s.list == list then closeWindow(s, "list"); P.pin(ui) end
        end }, { text = _("Close"), callback = function() if s.list == list then closeWindow(s, "list") end end }}
        list = require("ui/widget/buttondialog"):new{ title = _("Pinned references"), buttons = buttons,
            width = math.floor(require("device").screen:getWidth() * .85), rows_per_page = 6 }
        track(s, "list", list)
        UI:show(s.list)
    end
    function P.show(ui, id)
        local s = P.attach(ui); if not s or not live(s) then return end
        local data = store(s)
        if not data then notify("Saved references use an unsupported format. They were left untouched."); return end
        if #data.entries == 0 then return P.list(ui) end
        local entry, index = entryById(s, id or data.entries[#data.entries].id)
        if not entry then return end
        P.retire(ui)
        local Screen = require("device").screen
        local Geom = require("ui/geometry")
        local w = math.floor(Screen:getWidth() * .74)
        local h = math.floor(Screen:getHeight() * .9)
        local pad = math.max(4, Screen:scaleBySize(8))
        local inner = w - pad * 2 - 2
        local W = require("ui/widget/focusmanager")
        local window = W:new{ name = "orbitui_reader_pin_drawer", modal = true }
        s.drawer = window
        local generation = UI._simpleui_navigation_generation
        local function active()
            return s.drawer == window and not window.closed and live(s)
                and generation == UI._simpleui_navigation_generation
        end
        local function textWidget(text, height)
            return require("ui/widget/textboxwidget"):new{ text = text, width = inner, height = height,
                height_adjust = false, height_overflow_show_ellipsis = true,
                face = require("ui/font"):getFace("smallinfofont") }
        end
        local page_number = page(s, entry)
        local heading = textWidget(string.format("%s · %d/%d · %s %s", _("Pinned references"), index,
            #data.entries, _("Page"), page_number and tostring(page_number) or "?"), Screen:scaleBySize(45))
        local function button(text, callback, enabled) return { text = _(text), callback = function()
            if active() then callback() end
        end, enabled = enabled ~= false } end
        local controls = require("ui/widget/buttontable"):new{ width = inner, buttons = {
            { button("Previous", function() P.show(ui, data.entries[index == 1 and #data.entries or index - 1].id) end),
              button("Next", function() P.show(ui, data.entries[index == #data.entries and 1 or index + 1].id) end),
              button("List", function() P.list(ui) end) },
            { button("Go to page", function() P.jump(ui, entry.id) end, page_number ~= nil),
              button("Expand reference", function()
                if entry.kind == "text" then
                    local viewer = require("ui/widget/textviewer"):new{ title = _("Text excerpt"), text = entry.text }
                    UI:show(track(s, "viewer", viewer)); return
                end
                if not window.bb then notify("The preview is not ready. Close and reopen the drawer to retry."); return end
                local image = window.bb:copy()
                track(s, "viewer", require("ui/widget/imageviewer"):new{ image = image,
                    image_disposable = true, title_text = _("Pinned references"), fullscreen = true })
                UI:show(s.viewer)
              end) },
            { button("Remove reference", function()
                local confirm
                confirm = require("ui/widget/confirmbox"):new{ text = _("Remove this reference? Bookmarks are not affected."),
                    ok_callback = function()
                        if s.confirm == confirm then s.confirm = nil end
                        if active() and P.remove(ui, entry.id) then P.show(ui) end
                    end }
                UI:show(track(s, "confirm", confirm))
              end), button("Close", function() closeWindow(s, "drawer") end) },
        } }
        window.layout = controls.layout
        local preview_h = h - pad * 2 - 2 - heading:getSize().h - controls:getSize().h
        if preview_h < Screen:scaleBySize(50) then
            s.drawer = nil
            if heading.free then heading:free() end
            if controls.free then controls:free() end
            return P.list(ui) -- native scrolling list on unusually short screens
        end
        window.preview = require("ui/widget/container/centercontainer"):new{
            dimen = Geom:new{ w = inner, h = preview_h },
            textWidget(entry.kind == "text" and entry.text or _("Loading reference…"), preview_h),
        }
        local clip = require("lib/bookshelf_clip_container"):new{ w = inner, h = preview_h, window.preview }
        local frame = require("ui/widget/container/framecontainer"):new{ padding = pad, margin = 0, bordersize = 1,
            background = require("ffi/blitbuffer").COLOR_WHITE,
            require("ui/widget/verticalgroup"):new{ align = "left", heading, clip, controls },
        }
        window[1] = require("ui/widget/container/rightcontainer"):new{
            dimen = Geom:new{ w = Screen:getWidth(), h = Screen:getHeight() }, allow_mirroring = false, frame }
        window.onClose = function()
            if s.drawer == window then closeWindow(s, "drawer") end
            return true
        end
        window.onCloseWidget = function()
            if window.closed then return end
            window.closed = true
            if s.drawer == window then s.drawer = nil end
            if s.batch == window.batch then cancelPreview(s) end
            releasePreview(window)
            UI:setDirty(nil, "flashui")
        end
        window.key_events = window.key_events or {}
        window.key_events.Close = {{ require("device").input.group.Back }}
        window.ges_events = { Outside = { require("ui/gesturerange"):new{
            ges = "tap", range = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() } } } }
        window.onOutside = function(_, _arg, ges)
            if ges.pos.x < Screen:getWidth() - w then window:onClose() end
            return true
        end
        UI:show(window)
        local function showImage(image)
            if not active() then if image then image:free() end; return end
            releasePreview(window)
            window.bb = image
            window.preview[1] = image and require("ui/widget/imagewidget"):new{
                image = image, image_disposable = false, width = inner, height = preview_h,
                scale_factor = 0, original_in_nightmode = entry.kind == "image",
            } or textWidget(_("Preview unavailable. You can still use Go to page if the location is valid."), preview_h)
            UI:setDirty(window, "ui")
        end
        if entry.kind == "image" then
            local path = snapshotPath(entry)
            local a = path and require("libs/libkoreader-lfs").symlinkattributes(path)
            local ok, image = pcall(function()
                if a and a.mode == "file" and a.size <= 2 * 1024 * 1024 then
                    return require("ui/renderimage"):renderImageFile(path, false, math.min(inner, 1024), math.min(preview_h, 1024))
                end
            end)
            showImage(ok and image or nil)
        elseif entry.kind == "page" then
            if page_number and ui.thumbnail and ui.thumbnail.getPageThumbnail then
                local batch = {}; s.batch = batch; window.batch = batch
                local ok = pcall(ui.thumbnail.getPageThumbnail, ui.thumbnail, page_number,
                    math.max(1, math.min(inner, 1024)), math.max(1, math.min(preview_h, 1024)), batch,
                    function(tile, returned)
                        if returned ~= s.batch or not active() then return end
                        -- Copy cache-owned pixels: eviction/other native requesters retain ownership.
                        local copied, image = pcall(function() return tile and tile.bb and tile.bb:copy() end)
                        showImage(copied and image or nil)
                    end)
                if not ok then cancelPreview(s); showImage(nil) end
            else showImage(nil) end
        end
        return window
    end
    return P
end

-- Optional, already-instantiated reader integrations. Never require a plugin,
-- activate a disabled one, inspect its keys or run an AI action while probing.
local reader_ai_key = "orbitui_reader_ai"
local reader_ai_labels = { auto = "Automatic (X-Ray first)", xray = "X-Ray", koassistant = "KOAssistant", off = "Hide" }
local function readerCallable(fn)
    local mt = type(fn) == "table" and getmetatable(fn)
    return type(fn) == "function" or type(mt) == "table" and type(mt.__call) == "function"
end
function M.readerAIChoice()
    local value = G_reader_settings and G_reader_settings:readSetting(reader_ai_key)
    return reader_ai_labels[value] and value or "auto"
end
function M.readerAI(ui)
    local choice = M.readerAIChoice()
    if choice == "off" or not ui or not ui.document then return end
    local function find(name)
        local p = rawget(ui, name)
        local loader = package.loaded.pluginloader
        if not p and loader and readerCallable(loader.getPluginInstance) then
            local ok, found = pcall(loader.getPluginInstance, loader, name)
            if ok then p = found end
        end
        if type(p) ~= "table" or p.ui ~= ui or p.disabled == true or p._disabled == true then return end
        if name == "xray" and readerCallable(p.showFullXRayMenu) then return p end
        if name == "koassistant" and readerCallable(p.showCacheActionPopup) and readerCallable(p.executeBookLevelAction)
                and type(p.action_service) == "table" and readerCallable(p.action_service.getAction) then return p end
    end
    for _, name in ipairs(choice == "auto" and { "xray", "koassistant" } or { choice }) do
        local p = find(name)
        if p then return { id = name, label = name == "xray" and "X-Ray" or "X-Ray · KOAssistant", plugin = p } end
    end
    if choice ~= "auto" then return { id = choice, label = reader_ai_labels[choice], unavailable = true } end
end
function M.openReaderAI(ui, selected)
    local current = M.readerAI(ui)
    local R = package.loaded["apps/reader/readerui"]
    if not selected or not current or current.unavailable or current.plugin ~= selected.plugin
            or current.id ~= selected.id or not R or R.instance ~= ui then return false end
    local p, file = current.plugin, ui.document.file
    if current.id == "xray" then p:showFullXRayMenu(); return true end
    local action = p.action_service:getAction("book", "xray")
    -- An edited/custom action must not turn a navigation shortcut into an
    -- immediate model request. The native cache/scope popup owns consent.
    if type(action) ~= "table" or action.cache_as_xray ~= true or action.enabled == false then return false end
    p:showCacheActionPopup(action, "xray", function()
        local fresh = M.readerAI(ui)
        if R.instance == ui and ui.document and ui.document.file == file
                and fresh and fresh.plugin == p and fresh.id == "koassistant" then p:executeBookLevelAction("xray") end
    end)
    return true
end
function M.readerAIItems(changed)
    local _ = require("core/orbitui_i18n")
    local rows = {{ text = _("X-Ray in the reader panel"), enabled = false }, {
        text = _("Automatic uses active X-Ray first, then KOAssistant. Opening the panel never generates AI data."), enabled = false }}
    for _i, value in ipairs{ "auto", "xray", "koassistant", "off" } do
        local choice = value
        rows[#rows + 1] = { text = _(reader_ai_labels[choice]), radio = true,
            checked_func = function() return M.readerAIChoice() == choice end,
            callback = function()
                if not G_reader_settings then return end
                G_reader_settings:saveSetting(reader_ai_key, choice)
                if changed then changed() end
            end }
    end
    return rows
end

local reader_bottom_key = "orbitui_reader_bottom_panel"
function M.readerBottomEnabled()
    return not G_reader_settings or G_reader_settings:readSetting(reader_bottom_key) ~= false
end
function M.readerPanelItems(changed)
    local _ = require("core/orbitui_i18n")
    local rows = {{ text = _("Use OrbitUI as the bottom menu"), checked_func = M.readerBottomEnabled,
        callback = function()
            if not G_reader_settings then return end
            G_reader_settings:saveSetting(reader_bottom_key, not M.readerBottomEnabled())
            if changed then changed() end
        end }, { text = _("Reading settings… opens KOReader's original bottom menu. Turn this switch off to keep the original bottom gestures."),
        enabled = false }}
    for _i, row in ipairs(M.readerAIItems(changed)) do rows[#rows + 1] = row end
    return rows
end

-- Redirect only the two gesture-entry methods on this reader's config instance.
-- Keep native zones, activation preferences, keyboard/Dispatcher ShowConfigMenu
-- and the actual config dialog untouched. No class/global hook or default write.
function M.readerBottomMenu()
    if M._reader_bottom then return M._reader_bottom end
    local B, states, sleeping = {}, setmetatable({}, { __mode = "k" }), false
    M._reader_bottom = B
    local function current(s)
        local R = package.loaded["apps/reader/readerui"]
        return R and R.instance == s.ui and s.ui.config == s.config
            and s.ui.document == s.document and s.ui.doc_settings == s.settings
            and s.document.file == s.file
    end
    function B.detach(ui)
        local s = states[ui]; if not s then return end
        s.detached = true; states[ui] = nil
        for method, entry in pairs(s.methods) do
            if s.config[method] == entry.wrapper then s.config[method] = entry.raw end
        end
    end
    function B.event(handler, ui)
        if handler == "onSuspend" then sleeping = true
        elseif handler == "onResume" then sleeping = false
        elseif handler == "onShowingReader" then for owner in pairs(states) do B.detach(owner) end
        elseif handler == "onCloseDocument" or handler == "onTeardown" then B.detach(ui) end
    end
    function B.attach(ui)
        if not ui or type(ui.config) ~= "table" or ui.config.ui ~= ui or not ui.document or not ui.doc_settings then return end
        local old = states[ui]
        if old and current(old) then return end
        B.detach(ui)
        local config = ui.config
        if not readerCallable(config.onTapShowConfigMenu) or not readerCallable(config.onSwipeShowConfigMenu) then return end
        local s = { ui = ui, config = config, document = ui.document, file = ui.document.file,
            settings = ui.doc_settings, methods = {} }
        states[ui] = s
        local UI = require("ui/uimanager")
        local function event(name)
            if readerCallable(ui.handleEvent) then ui:handleEvent(require("ui/event"):new(name)) end
        end
        local function open()
            if sleeping or not UI:isWidgetShown(ui) or UI:getTopmostVisibleWidget() ~= ui then return end
            local hinted = false
            local ok, window = pcall(function()
                if ui.keyselection and readerCallable(ui.keyselection.stopHighlightIndicator) then
                    ui.keyselection:stopHighlightIndicator(true)
                end
                hinted = true; event("DisableHinting")
                return M.readerTools().show(ui)
            end)
            local function restore()
                if hinted then
                    hinted = false
                    if current(s) then pcall(event, "RestoreHinting") end
                end
            end
            if ok and window then
                local original = window.onCloseWidget
                window.onCloseWidget = function(this, ...)
                    restore()
                    if original then return original(this, ...) end
                end
                -- Native ReaderConfig consumes an in-flight pan too. Do not
                -- leave a page scroll running underneath the modal sheet.
                pcall(event, "HandledAsSwipe")
                return true
            end
            restore()
            if M._reader_tools then pcall(M._reader_tools.retire, ui) end
            if not ok then require("logger").warn("OrbitUI bottom menu unavailable; retaining native menu:", window) end
            return false
        end
        for _i, method in ipairs{ "onTapShowConfigMenu", "onSwipeShowConfigMenu" } do
            local entry = { original = config[method], raw = rawget(config, method) }
            s.methods[method] = entry
            local swipe = method == "onSwipeShowConfigMenu"
            entry.wrapper = function(owner, ...)
                if owner ~= config or not current(s) then return end
                if sleeping or not UI:isWidgetShown(ui) or UI:getTopmostVisibleWidget() ~= ui then return end
                if s.detached or not M.readerBottomEnabled() then return entry.original(owner, ...) end
                local gesture = ...
                if swipe and (owner.activation_menu == "tap" or not gesture or gesture.direction ~= "north")
                        or not swipe and owner.activation_menu == "swipe" then return entry.original(owner, ...) end
                local opened = open()
                if opened == false and current(s) and UI:isWidgetShown(ui) and UI:getTopmostVisibleWidget() == ui then
                    return entry.original(owner, ...) -- Failed renderer: retain the native escape hatch.
                end
                return opened
            end
            config[method] = entry.wrapper
        end
    end
    return B
end

-- Native bottom sheet. Only presentation belongs here: controller-owned
-- callbacks retain all reader/history/confirmation checks. No work in paint,
-- no cover extraction, plugin loading or reading-data writes.
function M.readerSheet(options)
    local UI, Screen = require("ui/uimanager"), require("device").screen
    local BB, Geom, Font = require("ffi/blitbuffer"), require("ui/geometry"), require("ui/font")
    local Frame, Text = require("ui/widget/container/framecontainer"), require("ui/widget/textboxwidget")
    local V, H = require("ui/widget/verticalgroup"), require("ui/widget/horizontalgroup")
    local VS, HS = require("ui/widget/verticalspan"), require("ui/widget/horizontalspan")
    local Button, Center = require("ui/widget/button"), require("ui/widget/container/centercontainer")
    local _ = require("core/orbitui_i18n")
    local px = function(n) return math.max(1, Screen:scaleBySize(n)) end
    local source = debug.getinfo(1, "S").source
    local root = source:match("^@(.+)/adapters/[^/]+$") or "."
    local Sheet = require("ui/widget/focusmanager"):extend{ name = "orbitui_reader_panel", modal = true }
    local function clean(value)
        if type(value) == "table" then
            local names = {}; for i = 1, math.min(4, #value) do if type(value[i]) == "string" then names[#names + 1] = value[i] end end
            value = table.concat(names, ", ")
        end
        if type(value) ~= "string" then return "" end
        value = value:gsub("[%c]", " ")
        if #value <= 512 then return value end
        local n = 512
        while value:byte(n + 1) and value:byte(n + 1) >= 128 and value:byte(n + 1) < 192 do n = n - 1 end
        return value:sub(1, n) .. "…"
    end
    local function call(owner, method, ...)
        if not owner or not readerCallable(owner[method]) then return end
        local ok, value = pcall(owner[method], owner, ...)
        if ok then return value end
    end
    local function number(value)
        return type(value) == "number" and value == value and value >= 0 and value <= 1e8 and value or nil
    end
    function Sheet:close() if not self.closed then UI:close(self) end end
    function Sheet:onClose() self:close(); return true end
    function Sheet:onOutside(_, gesture)
        if not self.panel_rect:contains(gesture.pos) then self:close() end
        return true
    end
    function Sheet:onSuspend() self:close() end
    function Sheet:onScreenResize() self:close() end
    Sheet.onSetRotationMode = Sheet.onScreenResize
    function Sheet:onCloseWidget() self.closed = true; UI:setDirty("all", "ui") end
    function Sheet:getButtonById(id) return self.native_buttons[id] end
    function Sheet:rebuild(reserve_scrollbar)
        if self[1] then self[1]:free(); self[1] = nil end
        self.layout, self.native_buttons = {}, {}
        self.revision = (self.revision or 0) + 1
        local revision = self.revision
        local sw, sh = Screen:getWidth(), Screen:getHeight()
        local margin, border = px(10), px(1)
        local width = math.min(px(620), sw - 2 * margin)
        local pad = math.min(px(18), math.floor(width / 16))
        local inner = width - 2 * (pad + border)
        local compact = sh < px(430)
        local function space(n) return VS:new{ width = px(n) } end
        local function gap(n) return HS:new{ width = px(n) } end
        local function text(copy, size, bold, w, maxh, color)
            local opts = { text = clean(copy), width = w, face = Font:getFace("cfont", size), bold = bold,
                fgcolor = color or BB.COLOR_BLACK, bgcolor = BB.COLOR_WHITE, height_overflow_show_ellipsis = true }
            local widget = Text:new(opts)
            if maxh and widget:getSize().h > maxh then
                widget:free(); opts.height, opts.height_adjust = maxh, false; widget = Text:new(opts)
            end
            return widget
        end
        local function cover(file, w, h)
            -- Borrow a strong reference only from the already-loaded RAM cache.
            -- A cache miss stays a placeholder; never open an EPUB or a database.
            local cached = package.loaded["infra/sui_cover_cache"]
            local bb = call(cached, "get", file)
            local bw, bh = number(call(bb, "getWidth")), number(call(bb, "getHeight"))
            local child
            if bw and bh and bw > 0 and bh > 0 then
                local ratio = math.min(1, w / bw, h / bh)
                child = require("ui/widget/imagewidget"):new{ image = bb, image_disposable = false,
                    width = math.max(1, math.floor(bw * ratio)), height = math.max(1, math.floor(bh * ratio)) }
            else
                child = text(_("Book"), 12, false, w - px(4), h, BB.COLOR_DARK_GRAY)
            end
            return Center:new{ dimen = Geom:new{ w = w, h = h }, child }
        end
        local function progress(w, pct)
            return require("ui/widget/progresswidget"):new{ width = w, height = px(3),
                percentage = math.max(0, math.min(1, number(pct) or 0)), margin_h = 0, margin_v = 0,
                bordersize = 0, bgcolor = BB.COLOR_LIGHT_GRAY, fillcolor = BB.COLOR_BLACK }
        end
        local specs = {}
        for _, row in ipairs(self.buttons) do for _, spec in ipairs(row) do if spec.id then specs[spec.id] = spec end end end
        local function button(id, copy, w, h, primary, content, cb)
            local spec = specs[id] or {}
            local enabled = spec.enabled ~= false
            local b = Button:new{ text = copy, width = w,
                height = math.max(h, px(28), content and content:getSize().h or 0), padding_h = px(6), padding_v = px(7),
                margin = 0, bordersize = 0, radius = px(8), background = primary and BB.COLOR_BLACK or nil,
                text_font_size = compact and 14 or 16, avoid_text_truncation = false, enabled = enabled,
                callback = function()
                    if self.closed or self.revision ~= revision or not UI:isWidgetShown(self)
                            or UI:getTopmostVisibleWidget() ~= self then return end
                    if cb then cb() elseif spec.callback then spec.callback() end
                end }
            if content then
                b.label_widget:free(); b.label_widget = content; b.label_container[1] = content
            elseif primary then b.label_widget.fgcolor, b.label_widget.bgcolor = BB.COLOR_WHITE, BB.COLOR_BLACK end
            self.native_buttons[id] = b
            return b
        end
        local top = V:new{ align = "left" }
        local closew, coverw, coverh = px(34), px(42), px(compact and 46 or 63)
        local headtext = V:new{ align = "left",
            text(self.title, compact and 18 or 20, true, inner - coverw - closew - px(12), px(compact and 27 or 54)),
            space(3), text(self.author, 14, false, inner - coverw - closew - px(12), px(21), BB.COLOR_DARK_GRAY) }
        local close = button("close", "×", closew, px(24))
        top[#top + 1] = H:new{ align = "top", cover(self.file, coverw, coverh), gap(12), headtext, close }
        self.layout[#self.layout + 1] = { close }
        local page = number(call(self.ui, "getCurrentPage"))
        local count = number(call(self.ui.document, "getPageCount"))
        local pct = page and count and count > 0 and math.min(1, page / count) or nil
        if not compact and pct then
            top[#top + 1] = space(10)
            local leftw = math.floor(inner / 2)
            top[#top + 1] = H:new{ align = "center",
                text(string.format("%.0f%%", pct * 100), 16, true, leftw, px(25)),
                text(string.format(_("Page %d of %d"), page, count), 14, false, inner - leftw, px(25), BB.COLOR_DARK_GRAY) }
            top[#top + 1] = space(6); top[#top + 1] = progress(inner, pct)
            local chapter = call(self.ui.toc, "getTocTitleByPage", page)
            local remaining = number(call(self.ui.toc, "getChapterPagesLeft", page))
            if type(chapter) == "string" and chapter ~= "" then
                top[#top + 1] = space(7)
                top[#top + 1] = text(chapter .. (remaining and (" · " .. string.format(_("%d pages left in chapter"), remaining)) or ""),
                    13, false, inner, px(22), BB.COLOR_DARK_GRAY)
            end
        end
        top[#top + 1] = space(compact and 8 or 14)
        local tabw = math.floor((inner - px(6)) / 2)
        -- Selected tabs stay readable and actionable, never native disabled gray.
        local tabs = {}
        for _i, id in ipairs{ "tools", "ongoing" } do
            local spec = specs[id]; local was = spec.enabled; spec.enabled = true
            tabs[#tabs + 1] = button(id, id == "tools" and _("This book") or _("Also reading"), tabw, px(24), self.tab == id)
            spec.enabled = was
        end
        top[#top + 1] = H:new{ align = "center", tabs[1], gap(6), tabs[2] }
        self.layout[#self.layout + 1] = tabs
        top[#top + 1] = space(compact and 8 or 14)
        local body = V:new{ align = "left" }
        -- The native class retains its own (possibly pre-rotation) scaled bar
        -- width. Scaling 18 again can also round differently from 3 * scale(6),
        -- leaving a one-pixel overflow and an unwanted horizontal scrollbar.
        local scrollbarw = reserve_scrollbar and require("ui/widget/container/scrollablecontainer"):getScrollbarWidth() or 0
        local bodyw = inner - scrollbarw
        local function append(widget) body[#body + 1] = widget end
        local function icon(name)
            return require("ui/widget/iconwidget"):new{ file = root .. "/assets/material-symbols/icons/300/" .. name .. ".svg",
                width = px(22), height = px(22) }
        end
        local function richRow(id, heading, detail, art, rowh)
            local spec = specs[id] or {}
            local fg = spec.enabled == false and BB.COLOR_DARK_GRAY or BB.COLOR_BLACK
            local labelw = bodyw - px(72)
            local label = V:new{ align = "left", text(heading, 16, true, labelw, px(25), fg) }
            if detail then label[#label + 1] = space(3); label[#label + 1] = detail end
            local content = H:new{ align = "center", art, gap(12), label,
                text("›", 22, false, px(16), px(30), fg) }
            return button(id, "", bodyw, px(rowh), false, content)
        end
        if self.tab == "tools" then
            local tiles, focus = H:new{ align = "center" }, {}
            local tilew = math.floor((bodyw - px(12)) / 3)
            for i, id in ipairs{ "toc", "bookmark", "search" } do
                local spec = specs[id]
                local content = V:new{ align = "center", icon(({ "menu_book", "bookmark", "search" })[i]), space(6),
                    text(spec.text, 14, true, tilew - px(12), px(40), spec.enabled == false and BB.COLOR_DARK_GRAY or nil) }
                local b = button(id, "", tilew, px(66), false, content)
                if i > 1 then tiles[#tiles + 1] = gap(6) end
                tiles[#tiles + 1] = b; focus[#focus + 1] = b
            end
            append(tiles); self.layout[#self.layout + 1] = focus
            for _, row in ipairs{ { "bookinfo", "info" }, { "pins", "collections_bookmark" }, { "gotopage", "auto_stories" },
                    { "config", "menu_book" }, { "reader_ai", "manage_search" } } do
                local spec = specs[row[1]]
                if spec then
                    append(space(4))
                    local b = richRow(row[1], spec.text, nil, Center:new{ dimen = Geom:new{ w = px(32), h = px(30) }, icon(row[2]) }, 34)
                    append(b); self.layout[#self.layout + 1] = { b }
                end
            end
        else
            local pages = math.max(1, math.ceil(#self.books / 4))
            self.page = math.min(self.page or 1, pages)
            for i = (self.page - 1) * 4 + 1, math.min(#self.books, self.page * 4) do
                local book = self.books[i]
                local labelw = bodyw - px(72)
                local detail = V:new{ align = "left", text((book.author ~= "" and (book.author .. " · ") or "")
                    .. string.format("%.0f%%", book.percent * 100), 13, false, labelw, px(20), BB.COLOR_DARK_GRAY),
                    space(5), progress(labelw, book.percent) }
                local b = richRow("book:" .. book.file, book.title, detail, cover(book.file, px(32), px(52)), 58)
                append(b); append(space(3)); self.layout[#self.layout + 1] = { b }
            end
            if pages > 1 then
                local function turn(delta) self.page = self.page + delta; self:rebuild(); UI:setDirty(self, "ui") end
                local prev = button("prev", "‹", px(42), px(20), false, nil, function() if self.page > 1 then turn(-1) end end)
                local nextb = button("next", "›", px(42), px(20), false, nil, function() if self.page < pages then turn(1) end end)
                append(H:new{ align = "center", prev, text(string.format("%d / %d", self.page, pages), 13, false,
                    bodyw - px(84), px(23), BB.COLOR_DARK_GRAY), nextb })
                self.layout[#self.layout + 1] = { prev, nextb }
            end
            local status = specs.state_status
            if status then
                append(space(6))
                local note = Text:new{ text = status.text, width = bodyw, face = Font:getFace("cfont", 12),
                    height = px(54), height_adjust = false, height_overflow_show_ellipsis = true,
                    fgcolor = BB.COLOR_DARK_GRAY, bgcolor = BB.COLOR_WHITE }
                -- The controller may pause beneath a foreign modal. Update only
                -- this label; never rebuild/raise the sheet over that modal.
                function note:setText(copy) Text.setText(self, clean(copy)) end
                self.native_buttons.state_status = note; append(note)
            end
            if self.missing > 0 then
                append(space(4)); append(text(string.format(_("%d reading-data records were unavailable."), self.missing),
                    12, false, bodyw, px(36), BB.COLOR_DARK_GRAY))
            end
        end
        local footer = V:new{ align = "left", space(compact and 6 or 12) }
        local refreshw = specs.refresh and px(106) or 0
        if specs.library then
            local lib = button("library", _("Library"), inner - refreshw, px(24))
            local row = H:new{ align = "center", lib }
            local focus = { lib }
            if specs.refresh then
                local refresh = button("refresh", _("Refresh"), refreshw, px(24))
                row[#row + 1] = refresh; focus[#focus + 1] = refresh
            end
            footer[#footer + 1] = row; self.layout[#self.layout + 1] = focus
        elseif specs.refresh then
            local refresh = button("refresh", _("Refresh"), inner, px(24))
            footer[#footer + 1] = refresh; self.layout[#self.layout + 1] = { refresh }
        end
        local maxbody = math.max(px(24), sh - margin - 2 * (pad + border) - top:getSize().h - footer:getSize().h)
        local content = body
        self.cropping_widget = nil
        if body:getSize().h > maxbody then
            if not reserve_scrollbar then top:free(); body:free(); footer:free(); return self:rebuild(true) end
            content = require("ui/widget/container/scrollablecontainer"):new{
                dimen = Geom:new{ w = inner, h = maxbody }, show_parent = self, body }
            self.cropping_widget = content
        end
        self[1] = Frame:new{ padding = pad, bordersize = border, radius = px(16), background = BB.COLOR_WHITE,
            V:new{ align = "left", top, content, footer } }
        local size = self[1]:getSize()
        self.panel_rect = Geom:new{ x = math.floor((sw - size.w) / 2), y = sh - size.h, w = size.w, h = size.h }
        self.dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh }
        self.ges_events.Outside = { require("ui/gesturerange"):new{ ges = "tap", range = self.dimen } }
        self.key_events.Close = {{ "Back" }, { "Esc" }}
        self.selected = { x = 1, y = 1 }
    end
    function Sheet:paintTo(bb, x, y) self[1]:paintTo(bb, self.panel_rect.x + (x or 0), self.panel_rect.y + (y or 0)) end
    function Sheet:init() self:rebuild() end
    return Sheet:new(options)
end

-- Explicit reader tools / Also reading. No global reader/menu replacement.
function M.readerTools()
    if M._reader_tools then return M._reader_tools end
    local T = {}
    M._reader_tools = T
    local _ = require("core/orbitui_i18n")
    local UI = require("ui/uimanager")
    local states = setmetatable({}, { __mode = "k" })
    local asleep = false
    local actions = {
        { "toc", "onShowToc", "Table of contents" },
        { "bookmark", "onShowBookmark", "Bookmarks" },
        { "search", "onShowFulltextSearchInput", "Search in book" },
        { "bookinfo", "onShowBookInfo", "Book information" },
        { "pins", nil, "Pinned references" },
        { "gotopage", "onShowGotoDialog", "Go to page" },
        { "config", "onShowConfigMenu", "Reading settings…" },
    }
    local function callable(fn)
        return type(fn) == "function" or type(fn) == "table" and type((getmetatable(fn) or {}).__call) == "function"
    end
    local function clip(text, length)
        text = type(text) == "string" and text:gsub("[%c]", " ") or ""
        if #text <= length then return text end
        while length > 0 do
            local b = text:byte(length + 1)
            if not b or b < 128 or b >= 192 then break end
            length = length - 1
        end
        return text:sub(1, length) .. "…"
    end
    local function localFile(file)
        return type(file) == "string" and file:sub(1, 1) == "/" and #file <= 4096
            and not file:find("[%c]") and not file:find("/%.%./")
    end
    local function notify(text) Context.notify(_(text)) end
    local function live(s)
        local R = package.loaded["apps/reader/readerui"]
        return not asleep and not s.closed and states[s.ui] == s and R and R.instance == s.ui
            and s.ui.document == s.document and s.document.file == s.file
            and s.ui.doc_settings == s.settings and UI:isWidgetShown(s.ui)
            and s.generation == UI._simpleui_navigation_generation
    end
    local function active(s, allowed)
        local top = UI:getTopmostVisibleWidget()
        return live(s) and s.window and UI:isWidgetShown(s.window)
            and (top == s.window or allowed ~= nil and top == allowed)
    end
    local function cancel(s)
        if s.job then s.job.cancelled = true; UI:unschedule(s.job.step); s.job = nil end
    end
    function T.retire(ui)
        local s = states[ui]; if not s then return end
        s.closed = true; states[ui] = nil; s.confirm_token = nil; cancel(s)
        for _, key in ipairs{ "confirm", "window" } do
            local w = s[key]; s[key] = nil; if w then UI:close(w) end
        end
    end
    function T.event(handler, ui)
        if handler == "onSuspend" or handler == "onShowingReader" then
            if handler == "onSuspend" then asleep = true end
            for owner in pairs(states) do T.retire(owner) end
        elseif handler == "onResume" then asleep = false
        elseif handler == "onCloseDocument" or handler == "onTeardown" or handler == "onSetRotationMode"
                or handler == "onScreenResize" or handler == "onChangeSize" or handler == "onDocumentRerendered"
                or handler == "onShowBookshelf" or handler == "onOpenBookshelfProfile"
                or handler == "onShowHomescreen" or handler == "onGoHome" then T.retire(ui) end
    end
    local function stamp(file)
        local a = require("libs/libkoreader-lfs").attributes(file)
        if a and a.mode == "file" then return tostring(a.modification) .. ":" .. tostring(a.size) end
    end
    local function plainSettings(DS, path, max)
        if not localFile(path) then return end
        local a = require("libs/libkoreader-lfs").symlinkattributes(path)
        if a and a.mode == "file" and type(a.size) == "number" and a.size > 0 and a.size <= max then
            -- Native light reader, never DocSettings:open/close/flush/repair.
            return DS.openSettingsFile(path)
        end
    end
    local function readBook(file)
        local before = stamp(file); if not before then return end
        local DS = require("docsettings")
        local source = DS:findSidecarFile(file)
        local ds = plainSettings(DS, source, 512 * 1024); if not ds then return end
        local pct = ds:readSetting("percent_finished")
        local summary, props = ds:readSetting("summary") or {}, ds:readSetting("doc_props") or {}
        if type(pct) ~= "number" or pct ~= pct or type(summary) ~= "table" or type(props) ~= "table" then return end
        if pct <= 0 or pct >= 1 then return false end
        if summary.status == "complete" or summary.status == "finished" or summary.status == "abandoned" then return false end
        local custom = DS.findCustomMetadataFile and DS:findCustomMetadataFile(file)
        if custom then
            local cds = plainSettings(DS, custom, 256 * 1024)
            local overrides = cds and cds:readSetting("custom_props")
            if type(overrides) == "table" then
                props = { title = overrides.title ~= nil and overrides.title or props.title,
                    authors = overrides.authors ~= nil and overrides.authors or props.authors }
            end
        end
        if before ~= stamp(file) then return end
        local author = props.authors
        if type(author) == "table" then
            local names = {}; for i = 1, math.min(#author, 4) do if type(author[i]) == "string" then names[#names + 1] = author[i] end end
            author = table.concat(names, ", ")
        end
        return { file = file, stamp = before, percent = pct, author = clip(author, 160),
            title = clip(props.title, 160) ~= "" and clip(props.title, 160) or clip(file:match("([^/]+)$"), 160) }
    end
    local function historyRecord(file, time)
        local hist = require("readhistory").hist or {}
        local Hidden = require("features/library/sui_recent_hidden")
        if Hidden.isHidden(file) then return false end
        for i = 1, math.min(#hist, 200) do
            local entry = hist[i]
            if type(entry) == "table" and entry.file == file and entry.time == time and not entry.dim then return true end
        end
        return false
    end
    local function failure(id, err)
        require("logger").warn("OrbitUI reader panel action failed:", id, err)
        notify("This reader tool is unavailable. Use KOReader's normal menu instead.")
    end
    local function open(s, entry)
        if not active(s) then return end
        local function commit(allowed)
            if not active(s, allowed) then return end
            local ok, fresh = pcall(function()
                if historyRecord(entry.file, entry.time) then return readBook(entry.file) end
            end)
            if not ok or not fresh or fresh.stamp ~= entry.stamp then
                notify("This book or its reading status changed. Refresh Also reading before opening it."); return
            end
            local R = package.loaded["apps/reader/readerui"]
            -- No Home prepareReturn override: switching from a reader preserves
            -- the existing origin. Native ShowingReader/close/ReaderReady owns
            -- saving, profile autoexec and normal external progress sync.
            if s.confirm == allowed then s.confirm = nil end -- native ConfirmBox closes itself after OK
            T.retire(s.ui)
            if M._reader_pins then M._reader_pins.retire(s.ui) end
            local opened, err = pcall(function() R:showReader(entry.file) end)
            if not opened then failure("open", err) end
        end
        if G_reader_settings and G_reader_settings:isTrue("file_ask_to_open") then
            local token = {}; s.confirm_token = token
            local confirm = require("ui/widget/confirmbox"):new{
                text = _("Open this book?") .. "\n\n" .. entry.title,
                ok_callback = function()
                    if s.confirm_token == token then s.confirm_token = nil; commit(s.confirm) end
                end,
                cancel_callback = function() if s.confirm_token == token then s.confirm_token = nil end end,
            }
            s.confirm = confirm
            local native = confirm.onCloseWidget
            confirm.onCloseWidget = function(this, ...)
                if s.confirm == this then s.confirm = nil end
                if native then return native(this, ...) end
            end
            UI:show(confirm)
        else commit() end
    end
    local function action(s, entry)
        if not active(s) then return end
        if entry[1] == "pins" then
            T.retire(s.ui); M.readerPins().show(s.ui); return
        end
        local target = s.ui[entry[1]]
        if not target or not callable(target[entry[2]]) then failure(entry[1], "missing handler"); return end
        T.retire(s.ui)
        local ok, err = pcall(function() return target[entry[2]](target) end)
        if not ok then failure(entry[1], err) end
    end
    local function draw(s)
        local rows, window = {}, nil
        local function button(id, text, callback, enabled)
            return { id = id, text = text, enabled = enabled ~= false, callback = function()
                if s.window == window and active(s) then callback() end
            end }
        end
        rows[1] = {
            button("tools", _("Tools"), function() T.show(s.ui) end, s.tab ~= "tools"),
            button("ongoing", _("Also reading"), function() T.show(s.ui, "ongoing") end, s.tab ~= "ongoing"),
        }
        if s.tab == "tools" then
            for i = 1, #actions, 2 do
                local row = {}
                for j = i, math.min(i + 1, #actions) do
                    local entry = actions[j]
                    local target = s.ui[entry[1]]
                    row[#row + 1] = button(entry[1], _(entry[3]), function() action(s, entry) end,
                        entry[1] == "pins" or target and callable(target[entry[2]]) or false)
                end
                rows[#rows + 1] = row
            end
            local selected = M.readerAI(s.ui)
            if selected then
                rows[#rows + 1] = { button("reader_ai", _(selected.label)
                    .. (selected.unavailable and (" · " .. _("Unavailable")) or ""), function()
                    local fresh = M.readerAI(s.ui)
                    if not fresh or fresh.plugin ~= selected.plugin or fresh.id ~= selected.id or fresh.unavailable then
                        notify("The selected X-Ray integration is unavailable. Check OrbitUI settings."); return
                    end
                    T.retire(s.ui)
                    local ok, result = pcall(M.openReaderAI, s.ui, selected)
                    if not ok or not result then failure("reader_ai", "unavailable integration") end
                end, not selected.unavailable) }
            end
        else
            for _, book in ipairs(s.books) do
                local entry = book
                rows[#rows + 1] = { button("book:" .. entry.file,
                    string.format("%s · %.0f%%", entry.title, entry.percent * 100), function() open(s, entry) end) }
            end
            local status = s.phase == "loading" and _("Checking recent reading data…")
                or s.phase == "paused" and _("Preparation paused. Tap Refresh to retry.")
                or s.phase == "error" and _("Could not read recent books. Tap Refresh to retry.")
                or #s.books == 0 and _("No other unfinished books in the checked recent files.")
                or _("Up to 12 unfinished books from the latest 200 history entries. Only local files are checked.")
            rows[#rows + 1] = {{ id = "state_status", text = status, enabled = false }}
            if s.missing > 0 then rows[#rows + 1] = {{
                text = string.format(_("%d reading-data records were unavailable."), s.missing), enabled = false }} end
            rows[#rows + 1] = { button("refresh", _("Refresh"), function() T.show(s.ui, "ongoing") end) }
        end
        if callable(s.ui.onClose) and callable(s.ui.showFileManager) then
            rows[#rows + 1] = { button("library", _("Library"), function()
                T.retire(s.ui)
                local ok, err = pcall(function()
                    -- Same native route as ReaderMenu's file-manager shortcut.
                    s.ui:onClose(); s.ui:showFileManager(s.file)
                end)
                if not ok then failure("library", err) end
            end) }
        end
        rows[#rows + 1] = { button("close", _("Close"), function() T.retire(s.ui) end) }
        local Screen = require("device").screen
        local props = type(s.ui.doc_props) == "table" and s.ui.doc_props or {}
        local title = clip(props.display_title or props.title, 160)
        if title == "" then title = clip(s.file:match("([^/]+)$"), 160) end
        local ok, sheet = pcall(M.readerSheet, { title = title, ui = s.ui, author = props.authors,
            file = s.file, books = s.books, tab = s.tab, phase = s.phase, missing = s.missing, buttons = rows })
        if ok then window = sheet else
            require("logger").warn("OrbitUI reader sheet unavailable; using native dialog:", sheet)
            window = require("ui/widget/buttondialog"):new{ name = "orbitui_reader_panel",
                title = _("Reader panel") .. "\n" .. title,
                buttons = rows, width = math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * .9), rows_per_page = 6 }
        end
        local original = window.onCloseWidget
        window.onCloseWidget = function(this, ...)
            if s.window == this then s.window = nil; cancel(s); s.closed = true; states[s.ui] = nil end
            if original then return original(this, ...) end
        end
        local old = s.window; s.window = window
        UI:show(window)
        if old then UI:close(old) end -- old close cannot retire its replacement
        return window
    end
    local function prepare(s)
        local job = { index = 1, seen = { [s.file] = true }, records = {} }
        s.job = job
        local clock = require("ui/time")
        local function pause()
            cancel(s); s.phase = "paused"
            local b = s.window and s.window.getButtonById and s.window:getButtonById("state_status")
            if b and b.setText then b:setText(_("Preparation paused. Tap Refresh to retry.")); UI:setDirty(s.window, "ui") end
        end
        job.step = function()
            if job.cancelled or s.job ~= job then return end
            if not live(s) then T.retire(s.ui); return end
            if not active(s) then pause(); return end
            local ok, err = pcall(function()
                local hist = require("readhistory").hist
                if type(hist) ~= "table" then error("missing reading history") end
                if not job.history then
                    job.history = hist
                    for i = 1, math.min(#hist, 200) do
                        local e = hist[i]
                        job.records[i] = type(e) == "table" and { file = e.file, time = e.time, dim = e.dim } or false
                    end
                end
                assert(hist == job.history, "reading history replaced")
                local start, count = clock.now(), 0
                local Hidden = require("features/library/sui_recent_hidden")
                while job.index <= #job.records and #s.books < 12 do
                    local record, current = job.records[job.index], hist[job.index]
                    job.index = job.index + 1; count = count + 1
                    if record then
                        assert(type(current) == "table" and current.file == record.file
                            and current.time == record.time and current.dim == record.dim, "reading history changed")
                        local file = record.file
                        if localFile(file) and not job.seen[file] and not record.dim and not Hidden.isHidden(file) then
                            job.seen[file] = true
                            local read, book = pcall(readBook, file)
                            if read and book then book.time = record.time; s.books[#s.books + 1] = book
                            elseif not read or book == nil then s.missing = s.missing + 1 end
                        end
                    end
                    if count >= 4 or clock.to_us(clock.since(start)) >= 8000 then break end
                end
            end)
            if not ok then
                require("logger").warn("OrbitUI reader panel preparation failed:", err)
                cancel(s); s.phase = "error"; draw(s)
            elseif job.index > #job.records or #s.books >= 12 then
                cancel(s); s.phase = "ready"; draw(s)
            else UI:scheduleIn(.01, job.step) end
        end
        UI:scheduleIn(.01, job.step)
    end
    function T.show(ui, tab)
        if not ui or not ui.document or not ui.doc_settings or not localFile(ui.document.file) then return end
        T.retire(ui)
        local s = { ui = ui, document = ui.document, file = ui.document.file, settings = ui.doc_settings,
            generation = UI._simpleui_navigation_generation, tab = tab == "ongoing" and "ongoing" or "tools",
            phase = "loading", books = {}, missing = 0 }
        states[ui] = s
        if not live(s) then states[ui] = nil; return end
        local top = UI:getTopmostVisibleWidget()
        if top and (top.name == "bookshelf" or top.name == "homescreen" or top.name == "filemanager") then states[ui] = nil; return end
        if M._reader_pins then M._reader_pins.retire(ui) end
        local window = draw(s)
        if s.tab == "ongoing" then prepare(s) end
        return window
    end
    return T
end

function M.readerToolsEvent(handler, ui)
    if M._reader_bottom then M._reader_bottom.event(handler, ui) end
    if M._reader_tools then M._reader_tools.event(handler, ui) end
end

function M.readerPinEvent(handler, ui)
    if M._reader_pins then M._reader_pins.event(handler, ui) end
end

return M
