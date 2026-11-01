local M = {}
M.tag_kind = "orbitui_epub_tags"

-- Saved rules are settings; these bounded snapshots are disposable cache data.
-- Rendering never walks a library, opens EPUBs or starts a worker. Only the
-- visible chip schedules a cache-only check; explicit Refresh may read EPUBs.
local tag_states, tag_order = {}, {}
local function tagContext(source)
    if type(source) ~= "table" or source.kind ~= M.tag_kind or source.version ~= 1
            or (source.scope ~= "library" and source.scope ~= "all") then return end
    local I = require("adapters/orbitui_integrations")
    local rule = I.embeddedTagRule(source.rule)
    local P = require("lib/bookshelf_profiles")
    local profile = P.get(source.profile)
    if not rule or not profile then return end
    local parts = { source.profile, source.scope, rule.mode, tostring(#rule.tags), I.embeddedTagSnapshotRevision() }
    local function add(text) parts[#parts + 1] = #text .. ":" .. text end
    for _, tag in ipairs(rule.tags) do add(tag) end
    -- Include all roots/depth/home, even for all-library rules. Removed roots
    -- cannot revive a snapshot merely because its query/name stayed the same.
    add(tostring(G_reader_settings and G_reader_settings:readSetting("home_dir")))
    add(tostring(require("lib/bookshelf_settings_store").read("latest_walk_depth")))
    local profiles = P.list()
    add(tostring(#profiles))
    for _, p in ipairs(profiles) do
        add(p.key); add(tostring(#p.roots))
        for _, root in ipairs(p.roots) do add(root) end
    end
    return table.concat(parts, "|"), rule
end

function M.tagKey(source) return tagContext(source) end

local function tagState(source)
    local key, rule = tagContext(source)
    if not key then return end
    local state = tag_states[key]
    if not state then
        if #tag_order == 32 then tag_states[table.remove(tag_order, 1)] = nil end
        tag_order[#tag_order + 1] = key
        local ok, result = pcall(require("adapters/orbitui_integrations").embeddedTagSnapshot, key)
        state = { result = ok and result or nil }
        tag_states[key] = state
    end
    return state, key, rule
end

function M.tagPaths(source)
    local state = tagState(source)
    local result = state and state.result
    local paths, seen = {}, {}
    if type(result) ~= "table" or type(result.paths) ~= "table" or #result.paths > 400
            or type(result.stamps) ~= "table" then return paths end
    local fs = require("libs/libkoreader-lfs")
    local P, Model = require("lib/bookshelf_profiles"), require("core/orbitui_libraries")
    local roots = {}
    if source.scope == "library" then roots = P.get(source.profile).roots
    else
        for _, p in ipairs(P.list()) do for _, root in ipairs(p.roots) do roots[#roots + 1] = root end end
        local home = G_reader_settings and G_reader_settings:readSetting("home_dir")
        if type(home) == "string" then roots[#roots + 1] = home end
    end
    for _, file in ipairs(result.paths) do
        local inside = false
        for _, root in ipairs(roots) do inside = inside or Model.contains(file, root) end
        if inside and type(file) == "string" and file:sub(1, 1) == "/" and file:lower():match("%.epub$") and not seen[file] then
            local a = fs.attributes(file)
            local stamp = a and a.mode == "file" and tostring(a.modification) .. ":" .. tostring(a.change) .. ":" .. tostring(a.size)
            if stamp and stamp == result.stamps[file] then paths[#paths + 1] = file; seen[file] = true end
        end
    end
    return paths
end

function M.tagStatus(source)
    local _ = require("core/orbitui_i18n")
    local state = tagState(source)
    local result = state and state.result
    local text = _("Indexed matches only. Update to check missing or changed EPUB tags.")
    if type(result) == "table" then
        if result.truncated then text = text .. " " .. _("Showing the first 400 matches.") end
        if type(result.unindexed) == "number" and result.unindexed > 0 then
            text = text .. " " .. string.format(_("%d EPUBs have no current cached tags."), result.unindexed)
        end
        if type(result.skipped) == "number" and result.skipped > 0 then
            text = text .. " " .. string.format(_("%d EPUBs could not be read; results may be incomplete. Refresh to retry."), result.skipped)
        end
    end
    return text
end

function M.tagResult(source, result)
    local state, key = tagState(source)
    if not state then return end
    state.result = result
    require("adapters/orbitui_integrations").embeddedTagSnapshot(key, result)
end

function M.tagCheck(source, current, changed)
    local state, key, rule = tagState(source)
    if not state or state.manual or state.busy or state.checked and os.time() - state.checked < 60 then return end
    state.busy, state.checked = true, os.time()
    local I = require("adapters/orbitui_integrations")
    state.worker = I.embeddedTagRequest(I.embeddedTagSession(), {
        rule = rule, profile = source.scope == "library" and source.profile or nil, cache_only = true,
        on_progress = function(result)
            state.result = result
            if changed then changed() end
        end,
    }, function()
        local valid = not state.manual and current() and M.tagKey(source) == key
        if not valid then state.busy, state.checked, state.worker = false, nil, nil end
        return valid
    end, function(result)
        state.busy, state.worker = false, nil
        if result then M.tagResult(source, result) else state.checked = nil end
        if changed then changed() end
    end)
    return state.worker
end

function M.tagRefresh(source, opts)
    opts = opts or {}
    local key, rule = tagContext(source)
    if not key then return end
    local state = tagState(source)
    state.manual = true
    if state.worker then state.worker.cancel(); state.worker = nil end
    state.busy = false
    return require("core/orbitui_search").embeddedTag(rule.tags[1], {
        rule = rule, profile = source.scope == "library" and source.profile or nil,
        open_book = opts.open_book,
        is_current = function() return M.tagKey(source) == key and (not opts.is_current or opts.is_current()) end,
        on_result = function(result) M.tagResult(source, result) end,
        on_closed = function()
            state.manual, state.checked = false, os.time()
            if opts.on_closed then opts.on_closed() end
        end,
    })
end

function M.tagRepository(repo)
    local native = repo.getBySource
    repo.getBySource = function(source, filter, sort, offset, limit, scope, opts)
        if not source or source.kind ~= M.tag_kind then return native(source, filter, sort, offset, limit, scope, opts) end
        local key = M.tagKey(source)
        if not key then return {}, 0 end
        local paths = M.tagPaths(source)
        -- Reuse native explicit-path hydration/filter/sort/pagination, not a
        -- second book producer or a cover decode for every matching file.
        local scoped = source.scope == "library" and require("lib/bookshelf_profiles").scope(
            require("lib/bookshelf_profiles").get(source.profile)) or nil
        local options = opts or (scope and not scope.roots and scope) or nil
        return native({ kind = "bookorbit_want", id = key .. table.concat(paths, "\0"), paths = paths },
            filter, sort or {{ key = "title" }}, offset, limit, scoped, options)
    end
end

function M.tagSources(sources)
    sources.register(M.tag_kind, { api = 1, picker = false, library = false,
        label = function() return require("core/orbitui_i18n")("Smart EPUB tag chip") end,
        available = function() return true end,
        list = function(source)
            local out = {}; for _, file in ipairs(M.tagPaths(source)) do out[#out + 1] = { filepath = file } end
            return out
        end,
    })
end

function M.tagWidget(widget)
    local function selected(self)
        if #(self._drilldown_path or {}) > 0 then return end
        local chip = self.profile and self:_profileChip()
        return chip and chip.source and chip.source.kind == M.tag_kind and chip.source or nil
    end
    local function current(self, key, generation)
        local reader = package.loaded["apps/reader/readerui"]
        local park = package.loaded["lib/bookshelf_reader_park"]
        if reader and reader.instance and not (park and park.isParked()) then return false end
        return not self._closed and require("ui/uimanager"):isWidgetShown(self)
            and generation == require("ui/uimanager")._simpleui_navigation_generation
            and M.tagKey(selected(self)) == key
    end
    local fetch = widget._fetchChipItems
    widget._fetchChipItems = function(self, ...)
        local source = selected(self)
        if source and not self._orbitui_tag_check_pending then
            self._orbitui_tag_check_pending = true
            local UI = require("ui/uimanager")
            local key, generation = M.tagKey(source), UI._simpleui_navigation_generation
            UI:nextTick(function()
                self._orbitui_tag_check_pending = nil
                if not key or not current(self, key, generation) then return end
                M.tagCheck(source, function() return current(self, key, generation) end, function()
                    if not current(self, key, generation) then return end
                    if self._spine_fetch_cache then self._spine_fetch_cache.at = 0 end
                    self:_rebuild(); UI:setDirty(self, "ui")
                end)
            end)
        end
        return fetch(self, ...)
    end
    local refresh = widget._refreshLibrary
    widget._refreshLibrary = function(self, ...)
        local source = selected(self)
        if not source then return refresh(self, ...) end
        local key, UI = M.tagKey(source), require("ui/uimanager")
        local generation = UI._simpleui_navigation_generation
        return M.tagRefresh(source, { is_current = function() return current(self, key, generation) end,
            open_book = function(file, book) self:_openBook(book or { filepath = file }) end,
            on_closed = function()
                if current(self, key, generation) then
                    if self._spine_fetch_cache then self._spine_fetch_cache.at = 0 end
                    self:_rebuild(); UI:setDirty(self, "ui")
                end
            end })
    end
    local counter = widget._pageCounterText
    widget._pageCounterText = function(self, ...)
        local text = counter(self, ...)
        local source = selected(self)
        if source then
            local state = tagState(source)
            return require("core/orbitui_i18n")(state and state.result and state.result.truncated and "Indexed (400+)" or "Indexed") .. " · " .. text
        end
        return text
    end
    local launch = widget._launchReader
    widget._launchReader = function(self, file, ...)
        local source = selected(self)
        local state = source and tagState(source)
        local from_matches = false
        for _i, path in ipairs(state and state.result and state.result.paths or {}) do
            if path == file then from_matches = true; break end
        end
        -- Guard a cached tag result, not unrelated global-search/panel routes
        -- that happen to reuse the same shelf's native opener.
        if from_matches then
            local I = require("adapters/orbitui_integrations")
            if not M.tagKey(source) or not I.embeddedTagMatches(I.embeddedTags(file), source.rule) then
                require("core/orbitui_context").notify(require("core/orbitui_i18n")(
                    "This file's tags changed or could not be read. Refresh the results."))
                return
            end
        end
        return launch(self, file, ...)
    end
end

function M.capture(widget, chip, include_drill)
    if not widget then return nil end
    local ref = { profile = widget.profile_key, chip = chip or widget.chip }
    if include_drill then
        local path = widget._drilldown_path or {}
        local tip = path[#path]
        if tip and tip.kind ~= "search" then
            local payload = tip.payload or {}
            ref.drill = { kind = tip.kind, id = payload.path or payload.series_name,
                label = tip.label, whole = tip.whole or nil }
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
        source = chip.source or { kind = chip.kind, id = chip.path }
        filter, sort = chip.filter, chip.sort_priority
        if chip.kind == "folder" or chip.kind == "bookorbit_want" then
            sort = sort or Profiles.folderSortPriority(profile)
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
        -- Book-detail pills open the whole group, but folder drills still
        -- inherit the shelf filter. Neither changes the stored shelf or scope.
        if ref.drill.whole and ref.drill.kind ~= "folder" then filter = nil end
    end
    if source.kind == M.tag_kind then label = (label or ref.chip) .. " · " .. require("core/orbitui_i18n")("Indexed") end
    return { source = source, filter = filter, sort = sort, label = label or ref.chip,
        scope = Profiles.scope(profile) }
end

function M.books(ref, opts)
    local query, err = M.resolve(ref)
    if not query then return {}, err end
    -- A browse order asks the same native producer to prepare its date/history
    -- keys. This changes only the resolved query, never the saved chip sort.
    if opts and opts.sort then query.sort = opts.sort end
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
            local members = item.books_meta or item.books
            if query.sort and #query.sort > 1 then
                local priority = {}
                for i = 2, #query.sort do priority[#priority + 1] = query.sort[i] end
                members = {}
                for i, book in ipairs(item.books_meta or item.books) do members[i] = book end
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
