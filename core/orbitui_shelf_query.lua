local M = {}

function M.capture(widget, chip, include_drill)
    if not widget then return nil end
    local ref = { profile = widget.profile_key, chip = chip or widget.chip }
    if include_drill then
        local path = widget._drilldown_path or {}
        local tip = path[#path]
        if tip and tip.kind ~= "search" then
            local payload = tip.payload or {}
            ref.drill = { kind = tip.kind, id = payload.path or payload.series_name,
                label = tip.label }
        end
    end
    return ref
end

function M.resolve(ref)
    if type(ref) ~= "table" or not ref.chip then return nil, "missing" end
    local Profiles = require("lib/bookshelf_profiles")
    local profile = Profiles.get(ref.profile)
    local source, filter, sort, label
    if ref.profile then
        local chip = Profiles.chip(profile, ref.chip)
        if not chip then return nil, "missing" end
        label = chip.label
        source = { kind = chip.kind, id = chip.path }
        if chip.kind == "folder" or chip.kind == "bookorbit_want" then
            sort = Profiles.folderSortPriority(profile)
        end
    else
        local tab = require("lib/bookshelf_tab_model").getById(ref.chip)
        if not tab then return nil, "missing" end
        source, filter, sort, label = tab.source, tab.filter, tab.sort_priority, tab.label
    end
    if not source or source.kind == "opds" then return nil, "remote" end
    if ref.drill then
        local kinds = { folder = "folder", series = "single_series", author = "author",
            genre = "genre", tag = "collection", format = "format",
            rating = "rating", language = "language" }
        local kind = kinds[ref.drill.kind]
        if not kind or not ref.drill.id then return nil, "missing" end
        source = { kind = kind, id = ref.drill.id }
        label = ref.drill.label or ref.drill.id
    end
    return { source = source, filter = filter, sort = sort, label = label or ref.chip,
        scope = Profiles.scope(profile) }
end

function M.books(ref)
    local query, err = M.resolve(ref)
    if not query then return {}, err end
    local Repo = require("lib/bookshelf_book_repository")
    local source = {}
    for key, value in pairs(query.source) do source[key] = value end
    -- Flatten folders for cover modules, using the same repository's filter
    -- and sorting pipeline. Never walk folders or decode covers in UI code.
    if source.kind == "folder" then source.kind = "folder_flat"
    elseif source.kind == "all" then source.kind = "library" end
    local items
    if source.kind == "next" then
        items = Repo.getNextUnreadInSeries(math.huge, 0, query.scope, { light_only = true })
    else
        if source.kind == "bookorbit_want" then
            source.paths, source.id = require("lib/bookshelf_bookorbit_want_source").snapshot()
        end
        items = Repo.getBySource(source, query.filter, query.sort, 0, math.huge,
            query.scope, { light_only = true })
    end
    local books, seen = {}, {}
    local function add(item)
        if item.filepath and not seen[item.filepath] and not item.filepath:match("^OPDS://") then
            seen[item.filepath] = true
            books[#books + 1] = item
        elseif item.books then
            local members = item.books
            if item.books_meta and query.sort and #query.sort > 1 then
                local priority = {}
                for i = 2, #query.sort do priority[#priority + 1] = query.sort[i] end
                members = {}
                for i, book in ipairs(item.books_meta) do members[i] = book end
                require("lib/bookshelf_sort_engine").sort(members, priority)
            end
            for _, book in ipairs(members) do add(book) end
        end
    end
    for _, item in ipairs(items or {}) do add(item) end
    return books
end

function M.paths(ref)
    local books, err = M.books(ref)
    local paths = {}
    for _, book in ipairs(books) do paths[#paths + 1] = book.filepath end
    return paths, err
end

return M
