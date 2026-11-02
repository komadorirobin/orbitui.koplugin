local M = { limit = 400 }
local _ = require("core/orbitui_i18n")
local Query = require("core/orbitui_shelf_query")
local Context = require("core/orbitui_context")
local HISTORY = "orbitui_search_history"
local TYPOS = "orbitui_search_typos"
local session = 0
M.sorts = { { id = "relevance", text = "Relevance" }, { id = "title", text = "Title" },
    { id = "author", text = "Author" }, { id = "series", text = "Series" } }

local text_lower
function M.lower(value)
    if not text_lower then
        local ok, Text = pcall(require, "infra/sui_text")
        text_lower = ok and type(Text) == "table" and Text.lower or string.lower
    end
    return text_lower(value or "")
end

local function author(book)
    local value = book.author or book.authors or ""
    return type(value) == "table" and table.concat(value, ", ") or value
end

function M.sortBooks(books, sort, query, matches)
    local keys, q = {}, M.lower(query)
    local function score(value, weight)
        if q == "" then return 0 end
        if value == q then return weight * 4 end
        if value:sub(1, #q) == q then return weight * 2 end
        return value:find(q, 1, true) and weight or 0
    end
    for _, book in ipairs(books) do
        local title, name, series = M.lower(book.title or book.filename or book.filepath),
            M.lower(author(book)), M.lower(book.series or book.series_name)
        keys[book] = { title = title, author = name, series = series,
            relevance = score(title, 100) + score(name, 20) + score(series, 10) }
    end
    table.sort(books, function(a, b)
        local ak, bk = keys[a], keys[b]
        local field = sort == "author" and "author" or sort == "series" and "series"
            or sort == "title" and "title" or "relevance"
        if field == "relevance" and matches and matches[a] ~= matches[b] then
            return (matches[a] or 0) < (matches[b] or 0)
        end
        if ak[field] ~= bk[field] then
            if field == "relevance" then return ak[field] > bk[field] end
            -- Unknown author/series sorts last, rather than hiding named hits.
            if ak[field] == "" then return false end
            if bk[field] == "" then return true end
            return ak[field] < bk[field]
        end
        if ak.title ~= bk.title then return ak.title < bk.title end
        return a.filepath < b.filepath
    end)
    return books
end

local function store()
    local ok, value = pcall(require, "infra/sui_store")
    return ok and value or nil
end

-- Independent host-side matcher: no second library index, cover access or
-- metadata writer. Native repository scope and genre preferences still apply.
local folds = {}
for plain, letters in pairs({ a = "àáâãäåÀÁÂÃÄÅ", e = "èéêëÈÉÊË", i = "ìíîïÌÍÎÏ",
        o = "òóôõöøÒÓÔÕÖØ", u = "ùúûüÙÚÛÜ", y = "ýÿÝŸ", c = "çÇ", n = "ñÑ",
        ae = "æÆ", oe = "œŒ", ss = "ß" }) do
    for letter in letters:gmatch("[\194-\244][\128-\191]*") do folds[letter] = plain end
end
function M.normalize(text)
    return M.lower(text):gsub("[\194-\244][\128-\191]*", folds)
        :gsub("’", ""):gsub("'", ""):gsub("[%c%p]", " ")
end
local function characters(text, limit)
    local out = {}
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        out[#out + 1] = char
        if limit and #out >= limit then break end
    end
    return out
end
local function distance(query, target, cap)
    local n = #query
    if #target < n - cap then return end
    local previous, older = {}, nil
    for j = 0, math.min(#target, n + cap) do previous[j] = j end
    for i = 1, n do
        local row = { [0] = i }
        for j = 1, math.min(#target, n + cap) do
            local cost = query[i] == target[j] and 0 or 1
            row[j] = math.min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + cost)
            if older and j > 1 and query[i] == target[j - 1] and query[i - 1] == target[j] then
                row[j] = math.min(row[j], older[j - 2] + 1)
            end
        end
        older, previous = previous, row
    end
    local best = cap + 1
    for j = math.max(1, n - cap), math.min(#target, n + cap) do best = math.min(best, previous[j]) end
    return best <= cap and best or nil
end
function M.typosEnabled()
    local settings = store()
    return not settings or settings:get(TYPOS) ~= false
end
function M.matcher(query, forgiving)
    local raw_words, words = {}, {}
    for word in M.lower(query):gmatch("%S+") do raw_words[#raw_words + 1] = word end
    for word in M.normalize(query):gmatch("%S+") do words[#words + 1] = { text = word, chars = characters(word, 65) } end
    local memo, memo_size = {}, 0
    return function(book, _native_words, skip_genres)
        local parts = { book.title or "", author(book), book.series_name or book.series or "", book.filename or "" }
        if not skip_genres then
            for _, genre in ipairs(book.genres or {}) do parts[#parts + 1] = genre end
        end
        local raw = M.lower(table.concat(parts, " "))
        local exact = true
        for _, word in ipairs(raw_words) do if not raw:find(word, 1, true) then exact = false; break end end
        if exact then return 0 end
        if not forgiving or #words == 0 then return end
        local normalized, tokens = M.normalize(raw), nil
        local edits = 0
        for _, word in ipairs(words) do
            if not normalized:find(word.text, 1, true) then
                local length = #word.chars
                local cap = length >= 8 and 2 or length >= 4 and 1 or 0
                if cap == 0 or length > 64 or #words > 16 then return end
                if not tokens then
                    tokens = {}
                    for token in normalized:gmatch("%S+") do tokens[#tokens + 1] = token end
                end
                local best
                for _, token in ipairs(tokens) do
                    local key = word.text .. "\0" .. token:sub(1, 264)
                    local value = memo[key]
                    if value == nil then
                        value = distance(word.chars, characters(token, 66), cap) or false
                        if memo_size >= 2048 then memo, memo_size = {}, 0 end
                        memo[key], memo_size = value, memo_size + 1
                    end
                    if value and (not best or value < best) then best = value end
                end
                if not best then return end
                edits = edits + best
            end
        end
        -- All exact spelling, including Swedish å/ä/ö, ranks first.
        return edits == 0 and 100 or 200 + edits
    end
end

function M.history()
    local settings = store()
    local value = settings and settings:get(HISTORY)
    local out = {}
    if type(value) ~= "table" or value.schema ~= 1 or type(value.items) ~= "table" then return out end
    for _, item in ipairs(value.items) do
        if type(item) == "table" and type(item.query) == "string" and #item.query <= 512
                and item.query:find("%S") and type(item.scope) == "string" and #item.scope <= 128 then
            out[#out + 1] = { query = item.query, scope = item.scope }
            if #out == 10 then break end
        end
    end
    return out
end

function M.remember(query, scope)
    if #query > 512 then return end
    local settings = store()
    if not settings then return end
    local old = settings:get(HISTORY)
    -- A future schema belongs to its writer; do not silently replace it.
    if old ~= nil and (type(old) ~= "table" or old.schema ~= 1) then return end
    if old and type(old.items) == "table" and type(old.items[1]) == "table"
            and old.items[1].query == query and old.items[1].scope == scope then return end
    local items = { { query = query, scope = scope } }
    for _, item in ipairs(M.history()) do
        if not (M.lower(item.query) == M.lower(query) and item.scope == scope) and #items < 10 then
            items[#items + 1] = item
        end
    end
    settings:set(HISTORY, { schema = 1, items = items })
end

function M.clearHistory()
    local settings = store()
    if settings then settings:del(HISTORY) end
end

function M.scopes(ref)
    local scopes = {
        { id = "all", text = _("Entire library") },
    }
    for _i, section in ipairs(require("lib/bookshelf_profiles").list()) do
        scopes[#scopes + 1] = { id = section.key, text = _(section.label) }
    end
    if ref and Query.resolve(ref) then
        scopes[#scopes + 1] = { id = "current", text = _("Current shelf") }
    end
    return scopes
end

function M.search(text, scope_id, ref, sort, forgiving)
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
    elseif Profiles.get(scope_id) then
        scope = Profiles.scope(Profiles.get(scope_id))
    elseif scope_id ~= "all" then
        return {}, false, "missing"
    end
    -- Membership filtering precedes the limit: a narrow shelf must not miss
    -- its matches merely because other shelves supplied the first 400 hits.
    if forgiving == nil then forgiving = M.typosEnabled() end
    local match, scores = M.matcher(text, forgiving), {}
    local match_opts = { book_limit = math.huge, match_book = function(book, words, skip_genres)
        local score = match(book, words, skip_genres)
        scores[book] = score
        return score ~= nil
    end, match_group = function(label) return match({ title = label }, nil, true) ~= nil end }
    local matches = not allowed and Repo.searchAll(text, scope, match_opts) or nil
    local results, seen, groups = {}, {}, {}
    for _i, category in ipairs({ "folders", "authors", "series", "genres" }) do
        for _j, group in ipairs(matches and matches[category] or {}) do
            groups[#groups + 1] = { category = category, record = group }
        end
    end
    for _i, book in ipairs(matches and matches.books or Repo.searchBooks(text, nil, scope, match_opts)) do
        if not seen[book.filepath] and (not allowed or allowed[book.filepath]) then
            seen[book.filepath] = true
            results[#results + 1] = book
        end
    end
    M.sortBooks(results, sort, text, scores)
    local truncated = #results + #groups > M.limit
    while #groups > M.limit do groups[#groups] = nil end
    while #results > M.limit - #groups do results[#results] = nil end
    return results, truncated, nil, groups
end

function M.results(text, scope_id, ref, opts)
    opts = opts or {}
    local UI = require("ui/uimanager")
    local navigation = UI._simpleui_navigation_generation
    session = session + 1
    local request, retired = session, false
    local function current()
        return not retired and request == session and navigation == UI._simpleui_navigation_generation
    end
    local ok, books, truncated, err, groups = pcall(M.search, text, scope_id, ref, opts.sort)
    if not ok or err then
        if not ok then require("logger").warn("OrbitUI search:", books) end
        Context.notify(_(err == "missing" and "This shelf is no longer available." or "Could not load books."))
        return
    end
    local saved, failure = pcall(M.remember, text, scope_id)
    if not saved then require("logger").warn("OrbitUI search history:", failure) end
    local Window = require("engines/sui_window")
    local window = Window:new{
        name = "sui_win_orbitui_search", title = _("Search results") .. ": " .. text,
        position = "bottom",
        navpager_mode = require("infra/sui_config").isNavpagerEnabled(),
        on_close = function() retired = true end,
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
                        if not current() then return end
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
                    on_tap = function()
                        if current() then (opts.open_book or Context.openBook)(book.filepath, book) end
                    end,
                    on_hold = function()
                        if not current() then return end
                        require("adapters/orbitui_book_panel").show(book.filepath, { open_book = opts.open_book })
                    end,
                }
            end
            return rows
        end },
        screen_footers = { __root__ = function(ctx)
            local sort_label = _("Relevance")
            for _i, item in ipairs(M.sorts) do if item.id == opts.sort then sort_label = _(item.text) end end
            return Window.CenteredButtonFooter(ctx, { text = string.format(_("%d books"), #books)
                .. " · " .. sort_label .. " ▾", on_tap = function()
                if not current() then return end
                ctx.close()
                M.show{ query = text, scope = scope_id, ref = ref, open_book = opts.open_book, sort = opts.sort }
            end })
        end },
    }
    window:show()
    return window
end

local function tagSearch(tag, opts)
    opts = opts or {}
    local Integration = require("adapters/orbitui_integrations")
    local embedded = opts.embedded == true
    local rule = embedded and Integration.embeddedTagRule(opts.rule or tag)
    if embedded and not rule then return end
    local title = embedded and _("EPUB tags (offline)") or _("BookOrbit tags")
    local intro = embedded and _("Only EPUBs on this device. All library profiles are included; the library's scan-depth setting applies. No connection is needed.")
        or _("Only BookOrbit-linked books on this device. All library profiles are included.")
    if embedded and opts.profile then intro = _("Only EPUBs in the selected library. The scan-depth setting applies. No connection is needed.") end
    intro = intro .. " " .. _("Tap a title to select the book on its shelf.")
    local function failureText(err)
        if embedded and err == "stale" then return _("Library folders changed. Refresh and try again.") end
        return embedded and Integration.embeddedTagError(err) or Integration.bookOrbitError(err)
    end
    local UI, Screen = require("ui/uimanager"), require("device").screen
    local fs = require("libs/libkoreader-lfs")
    local modal, retired, busy, data_session = nil, false, false, nil
    local sleeping, paused = false, false
    local worker
    local records, visible, query = {}, {}, ""
    local generation = UI._simpleui_navigation_generation
    session = session + 1
    local request = session
    local function alive()
        return not retired and modal and UI:isWidgetShown(modal)
    end
    local function current()
        return alive() and not sleeping
            and request == session and generation == UI._simpleui_navigation_generation
            and (not opts.is_current or opts.is_current())
    end
    local function render()
        if alive() and not sleeping then modal:refresh() end
    end
    local function retireWork()
        busy, worker, paused = false, nil, true
        if not alive() then return end
        records, visible, data_session = {}, {}, nil
        modal.config.intro = _("Search paused. Close and reopen the tag search to continue. Completed tag reads are kept.")
        render()
    end
    local function available(file) return fs.attributes(file, "mode") == "file" end
    local function filter()
        visible = {}
        if data_session and not data_session:current() then
            records, data_session = {}, nil
            modal.config.intro = failureText("stale")
        end
        for _, book in ipairs(records) do
            if M.lower(book.filename):find(M.lower(query), 1, true) then visible[#visible + 1] = book end
        end
    end
    local function fetch(reread)
        if not current() or busy then return end
        local source, err
        if embedded then
            local ok, value = pcall(Integration.embeddedTagSession)
            if ok then source = value end
        else source, err = Integration.bookOrbitSession() end
        if not source then modal.config.intro = failureText(err); modal:refresh(); return end
        busy, paused = true, false
        records, visible, data_session = {}, {}, nil
        modal.config.intro = intro
        modal:refresh()
        local function update(result, failure, partial)
            if not current() then return end
            if result then
                if opts.on_result then opts.on_result(result) end
                data_session = source
                local previous = {}; for _, book in ipairs(records) do previous[book.filepath] = book end
                records = {}
                for _, file in ipairs(result.paths) do
                    if available(file) then records[#records + 1] = previous[file] or { filepath = file, filename = file:match("([^/]+)$") or file } end
                end
                table.sort(records, function(a, b) return M.lower(a.filepath) < M.lower(b.filepath) end)
                modal.config.intro = intro
                if embedded and (partial or failure == "cancelled") then
                    modal.config.intro = intro .. " " .. string.format(_(failure == "cancelled"
                        and "Search stopped: %d of %d files checked. Results are incomplete. Refresh to continue."
                        or "Checking EPUB tags: %d of %d files. Results are incomplete."), result.scanned, result.total)
                end
                if result.truncated then modal.config.intro = modal.config.intro .. " " .. _("Showing the first 400 matches.") end
                if (result.skipped or 0) > 0 then
                    modal.config.intro = modal.config.intro .. " " .. string.format(_("%d EPUBs could not be read; results may be incomplete. Refresh to retry."), result.skipped)
                end
            else
                records, data_session = {}, nil
                modal.config.intro = failure == "cancelled" and _("Search cancelled. Tap Refresh to try again.")
                    or failureText(failure)
            end
            filter(); if not partial then modal.page = 1 end; modal:refresh()
        end
        local function done(result, failure)
            busy, worker = false, nil
            update(result, failure, false)
        end
        if embedded then
            worker = Integration.embeddedTagRequest(source, { tag = tag, rule = rule, profile = opts.profile,
                origin = opts.origin, refresh = reread == true,
                on_retired = retireWork,
                on_progress = function(result) update(result, nil, true) end }, current, done)
        else Integration.bookOrbitRequest(source, function(s) return s:matches(tag) end, current, done) end
    end
    local function bookMeta(book)
        if not book.title and available(book.filepath) then
            local ok, value = pcall(require("lib/bookshelf_book_repository").buildBookMeta, book.filepath, { want_cover = false })
            if ok and value then
                book.title, book.author = value.title, author(value)
            end
        end
        return book
    end
    local function canOpen(book)
        if type(book) ~= "table" or not current() or busy and not embedded or not data_session or not data_session:current() then return false end
        if not available(book.filepath) then Context.notify(_("This book is no longer on the device.")); return false end
        if embedded then
            local tags = Integration.embeddedTags(book.filepath)
            local matches = Integration.embeddedTagMatches(tags, rule)
            if not matches then Context.notify(_("This file's tags changed or could not be read. Refresh the results.")); return false end
        end
        return true
    end
    local footer = {{ { label = _("Refresh"), label_func = function()
        return _(embedded and busy and "Stop search" or "Refresh")
    end, enabled_when = function()
        return current() or embedded and busy and worker ~= nil
    end, on_tap = function()
        if embedded and busy and worker then worker.cancel() else fetch(false) end
    end },
        { label = _("Close"), on_tap = function() if alive() then modal:onClose() end end } }}
    if embedded then
        footer[#footer + 1] = {{ label = _("Reread all EPUB tags…"), enabled_when = function() return current() and not busy end, on_tap = function()
            if not current() or busy then return end
            modal:onClose()
            M.tagIndex{ confirm_reread = true }
        end }}
    end
    modal = require("lib/bookshelf_library_modal"):new{ _sui_keep_homescreen = true, config = {
        title = title .. ": " .. (rule and table.concat(rule.tags, rule.mode == "all" and " + " or " / ") or tag),
        intro = intro,
        search_placeholder = function() return _("Filter by filename") end,
        on_search_submit = function(value)
            if not current() then return end
            query = value or ""; filter(); modal.page = 1; modal:refresh()
        end,
        grid_cols = 1, rows_per_page = 4,
        cells_per_page = function() return Screen:getWidth() > Screen:getHeight() and 3 or 4 end,
        item_count = function() filter(); return #visible end,
        item_at = function(index) return visible[index] end,
        empty_state = function(w, h)
            return require("lib/bookshelf_picker_cell").render({ label = _(busy and "Loading…" or "No matches.") }, { w = w, h = h })
        end,
        cell_renderer = function(book, dimen)
            bookMeta(book)
            return require("lib/bookshelf_picker_cell").render({ label = book.title or book.filename,
                subtitle = book.author or book.filename }, dimen)
        end,
        on_cell_tap = function(book)
            if not canOpen(book) then return end
            local reveal = opts.reveal_book or Context.revealBook
            modal:onClose()
            -- A tag hit is navigation/preview, never a ReaderUI open (even
            -- when a caller supplied its usual open_book callback).
            reveal(book.filepath)
        end,
        cell_long_tap = function(book)
            if canOpen(book) then
                if embedded and worker then worker.cancel() end
                require("adapters/orbitui_book_panel").show(book.filepath, { open_book = opts.open_book })
            end
        end,
        footer_rows = footer,
        on_closed = function()
            retired = true; if worker then worker.cancel(); worker = nil end
            if opts.on_closed then opts.on_closed() end
        end,
    } }
    function modal:onSuspend()
        if not embedded then return end
        sleeping = true
        if worker then worker.cancel() end
    end
    function modal:onResume()
        if not embedded then return end
        sleeping = false
        if busy and not current() then
            if worker then worker.cancel() end
            retireWork()
        elseif paused then render() end
    end
    UI:show(modal)
    fetch()
    return modal
end

function M.bookOrbitTag(tag, opts) return tagSearch(tag, opts or {}) end
function M.embeddedTag(tag, opts)
    local options = {}
    for key, value in pairs(opts or {}) do options[key] = value end
    options.embedded = true
    return tagSearch(tag, options)
end

function M.tagIndex(opts)
    opts = opts or {}
    local I, UI = require("adapters/orbitui_integrations"), require("ui/uimanager")
    local modal, worker, retired, busy = nil, nil, false, false
    local sleeping = false
    local status, failure = I.embeddedTagIndexStatus()
    local generation = UI._simpleui_navigation_generation
    local function alive()
        return not retired and modal and UI:isWidgetShown(modal)
    end
    local function current()
        return alive() and not sleeping and generation == UI._simpleui_navigation_generation
    end
    local function render()
        if current() then modal:refresh() end
    end
    local function update(value, err)
        -- Retirement must release controls even for an expired generation.
        -- Never paint or adopt running work for a stale/sleeping owner.
        if not current() then
            busy, worker = false, nil
            if not alive() then return end
            status, failure = I.embeddedTagIndexStatus(), err ~= "cancelled" and err or nil
            if not sleeping then modal:refresh() end
            return
        end
        status, failure = value, err ~= "cancelled" and err or nil
        busy = value and value.phase == "running" and not err or false
        if not busy then worker = nil end
        render()
    end
    local function start(mode, resume, replace_invalid)
        if not current() or busy then return end
        failure = nil
        local control, err = I.startEmbeddedTagIndex(mode, resume, current, update, replace_invalid)
        if not control then failure = err; render(); return end
        worker, busy, status = control, true, I.embeddedTagIndexStatus()
        render()
    end
    local function confirm(mode)
        if not current() or busy then return end
        UI:show(require("ui/widget/confirmbox"):new{
            sui_native = true, _sui_keep_homescreen = true,
            text = failure == "invalid_job" and _("Replace the unreadable indexing-job record and start a new job? Only its saved progress is replaced. Existing tag caches, books and reading data are kept.")
                or _("Reread tags from every EPUB in all configured libraries? This bypasses old tags and may take a long time. You can pause and continue later, including after restarting KOReader. No books or reading data are edited."),
            ok_text = mode == "reread" and _("Reread all EPUB tags…") or _("Update tag index"),
            ok_callback = function() if current() then start(mode, false, failure == "invalid_job") end end,
        })
    end
    local function summary()
        if generation ~= UI._simpleui_navigation_generation then
            return _("Library view changed. Close and reopen this page to continue. Completed tag reads are kept.")
        end
        if failure then
            if failure == "stale" then return _("Library folders or scan depth changed. Start a new index update.") end
            if failure == "invalid_job" then return _("The saved indexing job is unreadable or from a newer version. Starting a new job requires confirmation; tag caches are kept.") end
            return _("Indexing could not continue. Check free space and try again. Completed tag reads are kept.")
        end
        if not status then return _("No indexing job yet. Choose Update tag index to check all configured libraries.") end
        if not status.current_scope then return _("Library folders or scan depth changed. Start a new index update.") end
        local phase = ({ running = "Indexing…", paused = "Indexing paused. Continue when ready.",
            complete = "Tag indexing complete.", errors = "Indexing finished with unreadable files. Continue to retry them." })[status.phase]
        return _(phase or "Indexing paused. Continue when ready.")
    end
    modal = require("lib/bookshelf_library_modal"):new{ _sui_keep_homescreen = true, config = {
        title = _("Tags and indexing"),
        -- The native picker subtitle is single-line; phase/errors need the
        -- modal's wrapping hint instead, not a newline that would be clipped.
        intro = function() return summary() .. "\n\n" .. _("All configured libraries at the current scan depth, without a 400-file limit. No account needed. Closing pauses; completed reads are kept. Pause before replacing EPUB files.") end,
        no_search = true, grid_cols = 1, rows_per_page = 1,
        item_count = function() return 1 end, item_at = function() return true end,
        cell_renderer = function(_value, dimen)
            local counts = status and string.format(_("%d of %d EPUB files checked"), status.scanned, status.total) or _("Ready to index")
            local text = status and string.format(_("Read: %d · Reused: %d · Failed: %d"), status.reread, status.reused, status.skipped) or ""
            return require("lib/bookshelf_picker_cell").render({ label = counts, subtitle = text }, dimen)
        end,
        footer_rows = {
            {{ label = _("Update tag index"), enabled_when = function() return current() and not busy end,
                on_tap = function() if failure == "invalid_job" then confirm("update") else start("update", false) end end },
             { label = _("Continue indexing"), enabled_when = function()
                return current() and not busy and status ~= nil and status.current_scope and status.phase ~= "complete"
             end, on_tap = function() start(nil, true) end }},
            {{ label = _("Reread all EPUB tags…"), enabled_when = function() return current() and not busy end,
                on_tap = function() confirm("reread") end },
             { label = _("Pause indexing"), enabled_when = function() return current() and busy end,
                on_tap = function() if current() and worker then worker.cancel() end end }},
            {{ label = _("Close"), on_tap = function() if alive() then modal:onClose() end end }},
        },
        on_closed = function() retired = true; if worker then worker.cancel(); worker = nil end end,
    } }
    function modal:onSuspend()
        sleeping = true
        if worker then worker.cancel() end
    end
    function modal:onResume()
        sleeping = false
        if worker and not current() then worker.cancel() end
        if alive() then
            status = I.embeddedTagIndexStatus()
            modal:refresh()
        end
    end
    UI:show(modal)
    if opts.confirm_reread then confirm("reread") end
    return modal
end

function M.show(opts)
    opts = opts or {}
    local UIManager = require("ui/uimanager")
    session = session + 1
    local request, native_generation = session, UIManager._simpleui_navigation_generation
    local active
    local function current()
        return request == session and native_generation == UIManager._simpleui_navigation_generation
    end
    local function guarded(fn, owner)
        return function(...) if current() and active == owner() then return fn(...) end end
    end
    local function pickerDialog(title, rows)
        local picker
        for _i, row in ipairs(rows) do
            for _j, button in ipairs(row) do
                if button.callback then button.callback = guarded(button.callback, function() return picker end) end
            end
        end
        picker = require("ui/widget/buttondialog"):new{ title = title, buttons = rows }
        active = picker
        return picker
    end
    local scope_id = opts.scope or (opts.ref and opts.ref.profile) or "all"
    local scopes = M.scopes(opts.ref)
    local valid = false
    for _i, item in ipairs(scopes) do if item.id == scope_id then valid = true end end
    if not valid then
        if opts.scope then Context.notify(_("This shelf is no longer available.")); return end
        scope_id = "all"
    end
    local sort_id = opts.sort or "relevance"
    local function sortText()
        for _i, item in ipairs(M.sorts) do if item.id == sort_id then return _(item.text) end end
        sort_id = "relevance"; return _("Relevance")
    end
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
                    picker = pickerDialog(_("Search in"), rows)
                    UIManager:show(picker)
                end }},
                {
                    { text = _("Cancel"), id = "close", callback = function()
                        session = session + 1; UIManager:close(dialog)
                    end },
                    { text = _("Search"), is_enter_default = true, callback = function()
                        local query = (dialog:getInputText() or ""):match("^%s*(.-)%s*$")
                        if query == "" then return end
                        UIManager:close(dialog)
                        UIManager:nextTick(function()
                            if not current() then return end
                            M.results(query, scope_id, opts.ref, { sort = sort_id, open_book = opts.open_book })
                        end)
                    end },
                },
                {{ text = _("Sort results") .. ": " .. sortText(), callback = function()
                    local query = dialog:getInputText()
                    UIManager:close(dialog)
                    local picker
                    local rows = {}
                    for _i, item in ipairs(M.sorts) do
                        rows[#rows + 1] = {{ text = _(item.text), callback = function()
                            UIManager:close(picker); sort_id = item.id; input(query)
                        end }}
                    end
                    rows[#rows + 1] = {{ text = _("Cancel"), callback = function()
                        UIManager:close(picker); input(query)
                    end }}
                    picker = pickerDialog(_("Sort results"), rows)
                    UIManager:show(picker)
                end }},
                {{ text = _("Recent searches"), callback = function()
                    local query = dialog:getInputText()
                    UIManager:close(dialog)
                    local history, scopes_by_id = M.history(), {}
                    for _, item in ipairs(scopes) do scopes_by_id[item.id] = item.text end
                    local function short(value, count)
                        local ok, Text = pcall(require, "infra/sui_text")
                        return ok and Text.truncate(value, count) or value
                    end
                    local function page(index)
                        local picker, rows = nil, {}
                        for i = (index - 1) * 5 + 1, math.min(index * 5, #history) do
                            local item = history[i]
                            rows[#rows + 1] = {{ text = short(item.query, 40) .. " — " .. short(scopes_by_id[item.scope]
                                    or _("Unavailable scope"), 28), callback = function()
                                if not scopes_by_id[item.scope] then
                                    Context.notify(_("This shelf is no longer available.")); return
                                end
                                UIManager:close(picker); scope_id = item.scope; input(item.query)
                            end }}
                        end
                        if #rows == 0 then rows[1] = {{ text = _("No recent searches."), enabled = false }} end
                        if #history > 5 then
                            rows[#rows + 1] = {
                                { text = "‹", enabled = index > 1, callback = function()
                                    UIManager:close(picker); page(1)
                                end },
                                { text = "›", enabled = index == 1, callback = function()
                                    UIManager:close(picker); page(2)
                                end },
                            }
                        end
                        rows[#rows + 1] = {{ text = _("Clear search history"), callback = function()
                            M.clearHistory(); UIManager:close(picker); input(query)
                        end }}
                        rows[#rows + 1] = {{ text = _("Cancel"), callback = function()
                            UIManager:close(picker); input(query)
                        end }}
                        picker = pickerDialog(_("Recent searches"), rows)
                        UIManager:show(picker)
                    end
                    page(1)
                end }},
                {{ text = _("Typo-tolerant search") .. ": " .. _(M.typosEnabled() and "On" or "Off"),
                    callback = function()
                        local query = dialog:getInputText()
                        local settings = store()
                        if not settings then return end
                        settings:set(TYPOS, not M.typosEnabled())
                        UIManager:close(dialog); input(query)
                    end }},
            },
        }
        for _i, row in ipairs(dialog.buttons) do
            for _j, button in ipairs(row) do
                if button.callback then button.callback = guarded(button.callback, function() return dialog end) end
            end
        end
        active = dialog
        UIManager:show(dialog)
        dialog:onShowKeyboard()
        return dialog
    end
    return input(opts.query)
end

local search = M.search
function M.search(...)
    return require("core/orbitui_host").measure("search", search, ...)
end
return M
