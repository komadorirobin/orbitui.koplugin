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
        controller[method] = function(self, value)
            Context.withShelf(self.profile_key, function(shelf) shelf[method](shelf, value) end)
        end
    end
    function controller:_orbitui_file_dialog_close(id)
        return function()
            if self._orbitui_modal then self._orbitui_modal:onClose() end
            if opts.navigate_row_ids and opts.navigate_row_ids[id] and opts.navigate_fn then
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

return M
