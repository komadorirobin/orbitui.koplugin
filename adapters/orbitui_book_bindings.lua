-- Presentation only: never change book metadata or the shelf's saved layout.
local M = {}
local _ = require("core/orbitui_i18n")
local KEY = "orbitui_book_bindings"
local valid = { hardcover = true, paperback = true, tankobon = true }
local styles = { "hardcover", "paperback", "tankobon" }
local skins = {
    paperback = { lighten = 0, shade = 0.14, paper = 248, page_line = 210 },
    tankobon = { lighten = 0.55, shade = 0.05, paper = 252, page_line = 224, accent = true },
}

local function tableOrEmpty(v) return type(v) == "table" and v or {} end
local function copy(v)
    local out = {}
    for k, value in pairs(tableOrEmpty(v)) do out[k] = value end
    return out
end
local function settings() return require("lib/bookshelf_settings_store") end
local function choices(scope)
    return tableOrEmpty(tableOrEmpty(settings().read(KEY))[scope])
end

function M.label(style)
    if style == "paperback" then return _("Paperback") end
    if style == "tankobon" then return _("Manga / tankobon") end
    return _("Hardcover")
end

function M.shelf(id)
    local value = choices("shelves")[id]
    return valid[value] and value or "hardcover"
end

function M.series(name)
    local value = choices("series")[name]
    return valid[value] and value or nil
end

function M.save(scope, id, style)
    if scope ~= "shelves" and scope ~= "series" then return false end
    if type(id) ~= "string" or id == "" then return false end
    if style ~= nil and not valid[style] then return false end
    local store = settings()
    local data = copy(store.read(KEY))
    data[scope] = copy(data[scope])
    data[scope][id] = style
    store.save(KEY, data)
    store.flush()
    return true
end

function M.resolve(book, source, opts)
    local name = book.series_name or (source and source.series_name) or opts.binding_series_name
    local value = name and tableOrEmpty(opts.binding_series)[name]
    if valid[value] then return value end
    return valid[opts.binding_shelf] and opts.binding_shelf or "hardcover"
end

function M.renderer(shelf)
    shelf.bookBinding = M.resolve
    shelf.bindingStyle = function(style) return skins[style] end
end

local function shelfId(widget, chip)
    return require("adapters/orbitui_cover_labels").id(widget, chip)
end

local function refresh(widget)
    -- Both page planning and drawing must discard the old binding entries.
    require("lib/bookshelf_spine_shelf").dropPlanCache()
    widget:_rebuild()
    require("ui/uimanager"):setDirty(widget, "ui")
end

local function show(widget, scope, id, label)
    local Host = require("lib/bookshelf_menu_host")
    local items, host = {}, nil
    local function add(style, text)
        items[#items + 1] = {
            text = text, radio = true,
            checked_func = function()
                local selected
                if scope == "series" then selected = M.series(id) else selected = M.shelf(id) end
                return selected == style
            end,
            callback = function()
                Host.close(host)
                if M.save(scope, id, style) then refresh(widget) end
            end,
        }
    end
    if scope == "series" then
        add(nil, _("Follow shelf") .. " (" .. M.label(M.shelf(shelfId(widget))) .. ")")
    end
    for _, style in ipairs(styles) do add(style, M.label(style)) end
    host = Host.show{ title = _("Book binding") .. ": " .. label, item_table = items }
    return host
end

function M.showShelf(widget, chip)
    local id = shelfId(widget, chip)
    local tab = require("adapters/orbitui_shelf_themes").tab(id)
    if not tab then return end
    return show(widget, "shelves", id, tab.label or chip)
end

function M.widget(widget)
    local plan = widget._spinePlanBase
    if plan then
        widget._spinePlanBase = function(self, ...)
            local opts = plan(self, ...)
            opts.binding_shelf = M.shelf(shelfId(self))
            opts.binding_series = copy(choices("series"))
            local path = self._drilldown_path or {}
            local tip = path[#path]
            if tip and tip.kind == "series" then
                opts.binding_series_name = (tip.payload or {}).series_name or tip.label
            elseif not self.profile then
                local tab = require("lib/bookshelf_tab_model").getById(self.chip)
                if tab and tab.source and tab.source.kind == "single_series" then
                    opts.binding_series_name = tab.source.id
                end
            end
            return opts
        end
    end
    widget.seriesBindingButton = function(self, name, close)
        return { text = _("Book binding") .. ": " ..
            (M.series(name) and M.label(M.series(name)) or _("Follow shelf")),
            callback = function()
                close()
                return show(self, "series", name, name)
            end,
        }
    end
end

return M
