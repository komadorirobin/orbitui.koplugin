-- Cover labels belong to a navigation shelf, not to a global theme.
local M = {}
local Themes = require("adapters/orbitui_shelf_themes")
local _ = require("core/orbitui_i18n")
local modes = { title = true, author = true, series = true, custom = true, none = true }

function M.id(widget, chip)
    chip = chip or widget.chip
    if widget.profile and require("lib/bookshelf_profiles").chip(widget.profile, chip) then
        return "orbitui:" .. widget.profile.key .. ":" .. chip
    end
    return chip
end

function M.mode(id, physical)
    local tab = Themes.tab(id)
    local mode = tab and tab.cover_label_mode
    if modes[mode] then return mode end
    -- Preserve an untouched shelf: grids retain the old setting, physical
    -- shelves stay bare until the reader opts in on that chip.
    if physical then return "none" end
    mode = require("lib/bookshelf_settings_store").read("expanded_shelf_label")
    return modes[mode] and mode or "title"
end

function M.line(id)
    local tab = Themes.tab(id)
    local CL = require("lib/bookshelf_cover_label")
    if tab and tab.cover_label_custom ~= nil then return CL.normalise(tab.cover_label_custom) end
    return CL.line()
end

function M.save(id, mode, line)
    if not modes[mode] then return false end
    local function update(tab)
        tab.cover_label_mode = mode
        if line ~= nil then
            tab.cover_label_custom = require("lib/bookshelf_cover_label").normalise(line)
        end
    end
    local profile, chip = Themes.profile(id)
    if profile then
        local P = require("lib/bookshelf_profiles")
        local tab = P.shelfSettings(profile, chip)
        update(tab)
        P.saveShelfSettings(profile, chip, tab)
        require("lib/bookshelf_settings_store").flush()
        return true
    end
    local TM = require("lib/bookshelf_tab_model")
    local tabs = TM.load()
    for _, tab in ipairs(tabs) do
        if tab.id == id then
            update(tab)
            TM.save(tabs)
            return true
        end
    end
    return false
end

local function draft(widget)
    local d = widget._orbitui_cover_label_preview
    return d and d.id == M.id(widget) and d.line or nil
end

local function refresh(widget, id)
    if M.id(widget) ~= id then return false end
    widget:_rebuild()
    require("ui/uimanager"):setDirty(widget, "ui")
    return true
end

function M.editorTarget(widget, id)
    return {
        title = function() return _("Cover text") .. ": " .. ((Themes.tab(id) or {}).label or id) end,
        line = function() return M.line(id) end,
        defaults = function() return require("lib/bookshelf_cover_label").defaultLine() end,
        template = "%title",
        save = function(line) M.save(id, "custom", line) end,
        preview = function(line)
            if line and M.id(widget) ~= id then return false end
            widget._orbitui_cover_label_preview = line and { id = id, line = line } or nil
            return refresh(widget, id)
        end,
    }
end

function M.show(widget, chip)
    chip = chip or widget.chip
    local id = M.id(widget, chip)
    local tab = Themes.tab(id)
    if not tab then return end
    if widget.chip ~= chip then widget:_selectChip(chip) end
    local Host = require("lib/bookshelf_menu_host")
    local host
    local items = {}
    for _i, choice in ipairs({ {"title", "Title"}, {"author", "Author"},
            {"series", "Series"}, {"custom", "Custom text"}, {"none", "None"} }) do
        local mode = choice[1]
        items[#items + 1] = {
            text = _(choice[2]), radio = true, keep_menu_open = true,
            checked_func = function() return M.mode(id, widget:_isSpineMode()) == mode end,
            callback = function(menu)
                if mode == "custom" then
                    Host.close(host)
                    local settings = setmetatable({ _bw = widget },
                        { __index = require("lib/bookshelf_settings") })
                    require("lib/bookshelf_cover_label_editor").show(widget, settings, nil, false,
                        M.editorTarget(widget, id))
                else
                    if M.save(id, mode) then refresh(widget, id) end
                    if menu and menu.updateItems then menu:updateItems() end
                end
            end,
        }
    end
    host = Host.show{ title = _("Cover text") .. ": " .. (tab.label or chip), item_table = items }
    return host
end

function M.widget(widget)
    widget._bookLabelMode = function(self)
        return draft(self) and "custom" or M.mode(M.id(self), false)
    end
    widget._coverLabelLine = function(self) return draft(self) or M.line(M.id(self)) end
    local key = widget._gridLabelsKey
    widget._gridLabelsKey = function(self) return tostring(M.id(self)) .. "|" .. key(self) end
    widget.spineCoverLabel = function(self)
        local line = draft(self)
        local mode = line and "custom" or M.mode(M.id(self), true)
        if mode == "none" then return nil end
        line = line or (mode == "custom" and M.line(M.id(self))) or { template = "%" .. mode }
        local CL = require("lib/bookshelf_cover_label")
        local resolve = mode == "custom" and CL.resolver(line) or function(book)
            -- Physical shelves can contain light records with series_name but
            -- no preformatted `series`, or a filename before title extraction.
            local title = book.title or (book.filepath:match("([^/]+)$") or ""):gsub("%.[^.]+$", "")
            if mode == "author" then
                local author = book.author or book.authors
                if type(author) == "table" then author = table.concat(author, ", ") end
                if type(author) == "string" and author ~= "" then
                    local fmt = require("lib/bookshelf_settings_store").read("author_format") or "auto"
                    if fmt ~= "auto" then
                        author = require("lib/bookshelf_author_name").formatted(author, fmt)
                    end
                    return author
                end
            elseif mode == "series" then
                local name = book.label or book.series_name
                if name and name ~= "" then
                    local n = book.series_num or book.series_index
                    return name .. (n and (" #" .. tostring(n)) or "")
                end
                return book.series or _("None")
            end
            return title
        end
        return function(book)
            if not book or not book.filepath or book.books or book.is_directory or book.add_subshelf then
                return nil
            end
            local text = CL.utf8Cut(tostring(resolve(book)):gsub("%s+", " "), CL.MAX_BYTES)
            if text ~= "" then return { text = text, bold = line.bold } end
        end
    end
end

function M.settings(settings)
    local build = settings._coverDisplaySubItems
    if not build then return end
    settings._coverDisplaySubItems = function(self)
        local items = build(self)
        for i = #items, 1, -1 do
            if items[i].id == "book_cover_label" then table.remove(items, i) end
        end
        return items
    end
end

function M.cover(cover)
    local render = cover._renderShadowedCard
    cover._renderShadowedCard = function(self, card)
        if self.spine_face_out and self.cover_label then
            require("adapters/orbitui_cover_label_band").decorate(card, self.cover_label,
                self:_statusIndicators().bar)
        end
        return render(self, card)
    end
end

return M
