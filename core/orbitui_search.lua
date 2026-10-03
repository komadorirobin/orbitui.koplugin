local M = { limit = 400 }
local _ = require("core/orbitui_i18n")
local Query = require("core/orbitui_shelf_query")
local Context = require("core/orbitui_context")

function M.scopes(ref)
    local scopes = {
        { id = "all", text = _("Entire library") },
        { id = "prose", text = _("Library") },
        { id = "comics", text = _("Manga & comics") },
    }
    if ref and Query.resolve(ref) then
        scopes[#scopes + 1] = { id = "current", text = _("Current shelf") }
    end
    return scopes
end

function M.search(text, scope_id, ref)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return {}, false end
    local Repo = require("lib/bookshelf_book_repository")
    local Profiles = require("lib/bookshelf_profiles")
    local scope, allowed
    if scope_id == "current" then
        local query, err = Query.resolve(ref)
        if not query then return {}, false, err end
        scope = query.scope
        local files, failure = Query.paths(ref)
        if failure then return {}, false, failure end
        allowed = {}
        for _i, fp in ipairs(files) do allowed[fp] = true end
    elseif scope_id == "prose" or scope_id == "comics" then
        scope = Profiles.scope(Profiles.get(scope_id))
    elseif scope_id ~= "all" then
        return {}, false, "missing"
    end
    -- Membership filtering precedes the limit: a narrow shelf must not miss
    -- its matches merely because other shelves supplied the first 400 hits.
    local matches = not allowed and Repo.searchAll(text, scope, { book_limit = math.huge }) or nil
    local results, seen, groups = {}, {}, {}
    for _i, category in ipairs({ "folders", "authors", "series", "genres" }) do
        for _j, group in ipairs(matches and matches[category] or {}) do
            groups[#groups + 1] = { category = category, record = group }
        end
    end
    for _i, book in ipairs(matches and matches.books or Repo.searchBooks(text, nil, scope)) do
        if not seen[book.filepath] and (not allowed or allowed[book.filepath]) then
            seen[book.filepath] = true
            results[#results + 1] = book
        end
    end
    table.sort(results, function(a, b)
        local at = (a.title or a.filepath):lower()
        local bt = (b.title or b.filepath):lower()
        if at == bt then return a.filepath < b.filepath end
        return at < bt
    end)
    local truncated = #results + #groups > M.limit
    while #groups > M.limit do groups[#groups] = nil end
    while #results > M.limit - #groups do results[#results] = nil end
    return results, truncated, nil, groups
end

function M.results(text, scope_id, ref, opts)
    opts = opts or {}
    local ok, books, truncated, err, groups = pcall(M.search, text, scope_id, ref)
    if not ok or err then
        if not ok then require("logger").warn("OrbitUI search:", books) end
        Context.notify(_(err == "missing" and "This shelf is no longer available." or "Could not load books."))
        return
    end
    local Window = require("engines/sui_window")
    local window = Window:new{
        name = "sui_win_orbitui_search", title = _("Search results") .. ": " .. text,
        position = "bottom",
        navpager_mode = require("infra/sui_config").isNavpagerEnabled(),
        screens = { __root__ = function(ctx)
            local rows = {}
            if #books == 0 and #(groups or {}) == 0 then
                rows[#rows + 1] = Window.ListRow{ inner_w = ctx.inner_w, title = _("No matches.") }
            end
            if truncated then
                rows[#rows + 1] = Window.ListRow{ inner_w = ctx.inner_w,
                    title = _("Showing the first 400 matches. Narrow your search for more specific results.") }
            end
            for _i, item in ipairs(groups or {}) do
                local group = item.record
                rows[#rows + 1] = Window.ListRow{
                    inner_w = ctx.inner_w, title = group.label or group.series_name or group.path,
                    show_chevron = true, separator = true,
                    on_tap = function()
                        ctx.close()
                        Context.withShelf(scope_id ~= "all" and scope_id or nil, function(shelf)
                            local methods = { folders = "_expandFolder", authors = "_expandAuthor",
                                series = "_expandSeries", genres = "_expandGenre" }
                            shelf[methods[item.category]](shelf, group)
                        end)
                    end,
                }
            end
            for _i, book in ipairs(books) do
                local author = book.author or book.authors
                if type(author) == "table" then author = table.concat(author, ", ") end
                rows[#rows + 1] = Window.ListRow{
                    inner_w = ctx.inner_w, title = book.title or book.filename or book.filepath,
                    subtitle = author,
                    right_value = _("Open"), separator = true,
                    on_tap = function() (opts.open_book or Context.openBook)(book.filepath, book) end,
                    on_hold = function()
                        require("adapters/orbitui_book_panel").show(book.filepath, { open_book = opts.open_book })
                    end,
                }
            end
            return rows
        end },
        screen_footers = { __root__ = function(ctx)
            return Window.CenteredButtonFooter(ctx, { text = _("Search"), on_tap = function()
                ctx.close()
                M.show{ query = text, scope = scope_id, ref = ref, open_book = opts.open_book }
            end })
        end },
    }
    window:show()
    return window
end

function M.show(opts)
    opts = opts or {}
    local UIManager = require("ui/uimanager")
    local scope_id = opts.scope or (opts.ref and opts.ref.profile) or "all"
    local scopes = M.scopes(opts.ref)
    local valid = false
    for _i, item in ipairs(scopes) do if item.id == scope_id then valid = true end end
    if not valid then scope_id = "all" end
    local function input(prefill)
        local dialog
        local selected
        for _i, item in ipairs(scopes) do if item.id == scope_id then selected = item.text end end
        dialog = require("ui/widget/inputdialog"):new{
            title = _("Search OrbitUI"), input = prefill or "",
            buttons = {
                {{ text = _("Search in") .. ": " .. selected, callback = function()
                    local query = dialog:getInputText()
                    UIManager:close(dialog)
                    local picker
                    local rows = {}
                    for _i, item in ipairs(scopes) do
                        rows[#rows + 1] = {{ text = item.text, callback = function()
                            UIManager:close(picker); scope_id = item.id; input(query)
                        end }}
                    end
                    rows[#rows + 1] = {{ text = _("Cancel"), callback = function()
                        UIManager:close(picker); input(query)
                    end }}
                    picker = require("ui/widget/buttondialog"):new{ title = _("Search in"), buttons = rows }
                    UIManager:show(picker)
                end }},
                {
                    { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                    { text = _("Search"), is_enter_default = true, callback = function()
                        local query = (dialog:getInputText() or ""):match("^%s*(.-)%s*$")
                        if query == "" then return end
                        UIManager:close(dialog)
                        UIManager:nextTick(function() M.results(query, scope_id, opts.ref, opts) end)
                    end },
                },
            },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
        return dialog
    end
    return input(opts.query)
end

return M
