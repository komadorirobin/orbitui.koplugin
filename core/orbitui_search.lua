local M = { limit = 400 }
local _ = require("core/orbitui_i18n")
local Query = require("core/orbitui_shelf_query")
local Context = require("core/orbitui_context")
local HISTORY = "orbitui_search_history"
local TYPOS = "orbitui_search_typos"
local SUGGESTIONS = "orbitui_search_word_suggestions"
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

function M.suggestionsEnabled()
    local settings = store()
    return settings and settings:get(SUGGESTIONS) == true or false
end

-- Independent, ephemeral vocabulary; no files, DB, covers or search producers.
-- Each book contributes a word once. Bounds cover broken/huge metadata too.
function M.wordVocabulary()
    local entries, keys, seen, count = {}, {}, {}, 0
    local stopped = {}
    for word in ("the and for with from this that vol volume och att ett med fran " ..
            "som till den det der die das und les des une los las"):gmatch("%S+") do stopped[word] = true end
    local vocabulary = { entries = entries, keys = keys }
    function vocabulary:add(book)
        if not book or type(book.filepath) ~= "string" or count >= 10000 or seen[book.filepath] then return end
        seen[book.filepath], count = true, count + 1
        local in_book = {}
        local function add(text)
            if type(text) ~= "string" then return end
            local last = math.min(#text, 512)
            -- Do not cut a valid UTF-8 character at the field byte budget.
            while last > 0 and text:byte(last + 1) and text:byte(last + 1) >= 128
                    and text:byte(last + 1) <= 191 do last = last - 1 end
            local clipped = #text > last
            text = text:sub(1, last)
            if clipped then text = text:gsub("%S+$", "") end -- no invented partial words
            text = text:gsub("[/\\]", " "):gsub("–", " "):gsub("—", " ")
                :gsub("’", " "):gsub("“", " "):gsub("”", " ")
            -- Punctuation separates tokens; retain the original Unicode spelling.
            for word in text:gmatch("[^%s%c%p]+") do
                local key = M.normalize(word)
                if not key:find("%s") and not key:find("%d") and not stopped[key]
                        and #word <= 96 and #characters(word) >= 3 and not in_book[key] then
                    in_book[key] = true
                    local entry = entries[key]
                    if entry then entry.count = entry.count + 1
                    elseif #keys < 12000 then
                        keys[#keys + 1] = key
                        entries[key] = { text = word, count = 1, length = #characters(word) }
                    end
                end
            end
        end
        add(book.title)
        local names = book.authors or book.author
        if type(names) == "table" then
            for i = 1, math.min(8, #names) do add(names[i]) end
        else add(names) end
        add(book.series_name or book.series)
    end
    function vocabulary:finish() table.sort(keys); self.ready = true end
    return vocabulary
end

-- Complete only the final word, with the cursor at the end and no selection.
-- No byte arithmetic on cursor positions (KOReader uses Unicode character positions).
function M.completionPrefix(text, cursor, selection)
    if type(text) ~= "string" or #text > 512 or selection
            or cursor ~= #characters(text) + 1 then return end
    local before, word = text:match("^(.-)([^%s%c%p]+)$")
    if not word or #characters(word) < 2 or #word > 96 then return end
    return M.normalize(word), before, word
end

function M.wordSuggestions(vocabulary, text, cursor, selection)
    local prefix = M.completionPrefix(text, cursor, selection)
    if not prefix or not vocabulary or not vocabulary.ready then return {} end
    local keys, entries = vocabulary.keys, vocabulary.entries
    local lo, hi = 1, #keys + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if keys[mid] < prefix then lo = mid + 1 else hi = mid end
    end
    local out = {}
    -- A broad two-letter prefix must not scan the entire vocabulary per key.
    for i = lo, math.min(#keys, lo + 255) do
        local key = keys[i]
        if key:sub(1, #prefix) ~= prefix then break end
        if key ~= prefix then out[#out + 1] = entries[key] end
    end
    table.sort(out, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        if a.length ~= b.length then return a.length < b.length end
        return a.text < b.text
    end)
    return { out[1] and out[1].text, out[2] and out[2].text, out[3] and out[3].text }
end

function M.completeWord(text, cursor, word, selection)
    local prefix, before = M.completionPrefix(text, cursor, selection)
    if not prefix or type(word) ~= "string" or M.normalize(word):sub(1, #prefix) ~= prefix then return end
    return before .. word .. " "
end

local function suggestionSnapshot(scope_id, ref)
    local Profiles = require("lib/bookshelf_profiles")
    local scope, query
    if scope_id == "current" then
        query = Query.resolve(ref)
        if not query then return end
        scope = query.scope
        -- Use the exact warm native shape, never a new getBySource call.
        local source = query.source
        query = { source = {}, filter = query.filter, sort = query.sort }
        for key, value in pairs(source) do query.source[key] = value end
        if query.source.kind == "folder" then query.source.kind = "folder_flat"
        elseif query.source.kind == "all" then query.source.kind = "library" end
    elseif scope_id ~= "all" then
        local profile = Profiles.get(scope_id)
        if not profile then return end
        scope = Profiles.scope(profile)
    end
    local Repo = require("lib/bookshelf_book_repository")
    return Repo.cachedSearchSnapshot and Repo.cachedSearchSnapshot(scope, query)
end

-- Native InputDialog extension on this instance only. Fixed native buttons
-- handle fitting, focus, night mode and touch; no reinit/reopened keyboard per key.
function M.attachWordSuggestions(dialog, opts)
    local UI = opts.ui
    local pending, retired, vocabulary, snapshot = nil, false, nil, nil
    local width, height
    local function dimensions()
        local ok, Device = pcall(require, "device")
        if ok and Device.screen then return Device.screen:getWidth(), Device.screen:getHeight() end
    end
    width, height = dimensions()
    local function valid()
        if retired or not opts.current() or (UI.isWidgetShown and not UI:isWidgetShown(dialog)) then return false end
        if UI.getTopmostVisibleWidget then
            local top = UI:getTopmostVisibleWidget()
            top = top and (top.widget or top)
            local keyboard = dialog._input_widget and dialog._input_widget.keyboard
            if top and top ~= dialog and top ~= keyboard then return false end
        end
        local w, h = dimensions()
        return w == width and h == height
            and (not snapshot or snapshot.current())
    end
    local function retire()
        retired = true
        if pending and UI.unschedule then UI:unschedule(pending) end
        pending, vocabulary, snapshot = nil, nil, nil
    end
    local function schedule(delay, fn)
        if pending then UI:unschedule(pending) end
        pending = function()
            pending = nil
            local ok = pcall(function() if valid() then fn() else retire() end end)
            if not ok then retire() end
        end
        UI:scheduleIn(delay, pending)
    end
    local choices, choice_text = {}, nil
    local function inputState()
        local widget = dialog._input_widget
        return dialog:getInputText(), widget and widget.charpos,
            widget and (widget.do_select or widget.selection_start_pos ~= nil)
    end
    local function paint()
        if not valid() then retire(); return end
        local text, cursor, selection = inputState()
        local next_choices = M.wordSuggestions(vocabulary, text, cursor, selection)
        local changed = false
        for i = 1, 3 do
            local button = dialog.button_table and dialog.button_table:getButtonById("orbitui_word_" .. i)
            if button then
                local label = next_choices[i] or (i == 1 and _("Word suggestions") or "—")
                if choices[i] ~= next_choices[i] or choice_text == nil then
                    button:setText(label, button.width)
                    button:enableDisable(next_choices[i] ~= nil)
                    changed = true
                end
            end
        end
        choices, choice_text = next_choices, text
        if changed then dialog:refreshButtons() end
    end
    dialog.strike_callback = function()
        if not valid() then retire(); return end
        -- Do not cancel the bounded vocabulary producer on every keystroke.
        if vocabulary and vocabulary.ready then schedule(0.18, paint) end
    end
    for i = 1, 3 do
        local index = i
        local button = dialog.buttons[#dialog.buttons][i]
        button.callback = function()
            if not valid() then retire(); return end
            local text, cursor, selection = inputState()
            if text ~= choice_text or not choices[index] then return end
            local completed = M.completeWord(text, cursor, choices[index], selection)
            if not completed then return end
            dialog:setInputText(completed, true, false)
            dialog._input_widget:goToEnd()
            paint() -- explicit choice only fills input; never a reader/search launch
        end
        local native = dialog.button_table and dialog.button_table:getButtonById("orbitui_word_" .. i)
        if native then native.callback = button.callback end
    end
    -- InputDialog passes the hook to InputText during init; this is an instance
    -- assignment after init, not a global native class replacement.
    if dialog._input_widget then dialog._input_widget.strike_callback = dialog.strike_callback end
    for _, name in ipairs{ "onClose", "onCloseWidget", "onSuspend", "onSetRotationMode" } do
        local original = dialog[name]
        dialog[name] = function(self, ...)
            retire()
            if original then return original(self, ...) end
        end
    end
    if not UI.scheduleIn or not UI.unschedule then return end
    schedule(0.05, function()
        local ok, value = pcall(opts.snapshot)
        snapshot = ok and type(value) == "table" and type(value.next) == "function"
            and type(value.current) == "function" and value or nil
        if not snapshot then paint(); return end
        vocabulary = M.wordVocabulary()
        local ticks = 0
        local function step()
            local ok = pcall(function()
                local started = os.clock()
                for _i = 1, 8 do
                    local book = snapshot.next()
                    ticks = ticks + 1
                    if book == nil or ticks > 10000 then
                        vocabulary:finish(); paint(); return
                    end
                    if book then vocabulary:add(book) end
                    if os.clock() - started >= 0.008 then break end
                end
                schedule(0.01, step)
            end)
            if not ok then retire() end -- optional completion cannot break Search/Close
        end
        if valid() then step() else retire() end
    end)
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
    local similar = opts.similar == true
    local rule = embedded and Integration.embeddedTagRule(opts.rule or tag)
    if embedded and not rule and not similar then return end
    local title = similar and _("Similar books and series") or embedded and _("EPUB tags (offline)") or _("BookOrbit tags")
    local intro = embedded and _("Only EPUBs on this device. All library profiles are included; the library's scan-depth setting applies. No connection is needed.")
        or _("Only BookOrbit-linked books on this device. All library profiles are included.")
    if embedded and opts.profile then intro = _("Only EPUBs in the selected library. The scan-depth setting applies. No connection is needed.") end
    if similar then intro = _("Local recommendations ranked by shared EPUB tags, across your libraries. The current book and its series are excluded. Only current indexed tags are used; no AI or server is needed.") end
    local function failureText(err)
        if similar and err == "no_tags" then return _("This EPUB has no separate embedded tags. Add tags to the EPUB and update the tag index. Genres are not used as substitute tags.") end
        if similar and err == "stale" then return _("Library metadata or tags changed. Refresh and try again.") end
        if embedded and err == "stale" then return _("Library folders changed. Refresh and try again.") end
        return embedded and Integration.embeddedTagError(err) or Integration.bookOrbitError(err)
    end
    local UI, Screen = require("ui/uimanager"), require("device").screen
    local fs = require("libs/libkoreader-lfs")
    local modal, retired, busy, data_session = nil, false, false, nil
    local sleeping, paused = false, false
    local worker
    local records, visible, query = {}, {}, ""
    local Series = require("core/orbitui_shelf_query")
    local series_state, series_paused, base_intro = nil, false, intro
    local similar_snapshot
    local result_capped, missing_metadata = false, false
    local view_profile = opts.view_profile or opts.profile
    if not view_profile and opts.origin then
        local ok, key = pcall(require("lib/bookshelf_profiles").matchFile, opts.origin)
        if ok then view_profile = key end
    end
    local preference = (similar and "orbitui_similar_result_view_" or "orbitui_tag_result_view_") .. (view_profile or "all")
    local ok_store, store = pcall(require, "lib/bookshelf_settings_store")
    local ok_saved, saved = pcall(function() return ok_store and store.read(preference) end)
    local view = ok_saved and (saved == "series" or saved == "volumes") and saved
        or (view_profile == "manga" or view_profile == "comics") and "series" or "volumes"
    local function dropSeries()
        if series_state then series_state.cancel(); series_state = nil end
        similar_snapshot = nil
    end
    local generation = UI._simpleui_navigation_generation
    session = session + 1
    local request = session
    local function alive()
        return not retired and modal ~= nil and UI:isWidgetShown(modal)
    end
    local function validView()
        return not retired and not sleeping
            and request == session and generation == UI._simpleui_navigation_generation
            and (not opts.is_current or opts.is_current()) or false
    end
    local function current() return alive() and validView() end
    local filter
    local function render()
        if alive() and not sleeping then
            if similar and filter then filter() end
            modal.config.intro = base_intro
            if similar then
                if result_capped then modal.config.intro = modal.config.intro .. " " .. _("Showing the best 400 results.") end
                if missing_metadata then modal.config.intro = modal.config.intro .. " " .. _("Some cached series metadata is missing. Those books are not recommended; update library metadata and refresh.") end
            end
            if view == "series" and (data_session or base_intro == intro) then
                modal.config.intro = modal.config.intro .. " " .. _("Tap a series to show it on its shelf with its first available volume selected.")
                if series_state and series_state.busy and not similar then
                    modal.config.intro = modal.config.intro .. " " .. _("Grouping cached series metadata… No EPUB files are opened.")
                elseif series_state and series_state.unavailable and not similar then
                    modal.config.intro = modal.config.intro .. " " .. _("Some series metadata is unavailable. Unknown books remain listed separately; update library metadata and refresh.")
                end
            elseif data_session or base_intro == intro then
                modal.config.intro = modal.config.intro .. " " .. _("Tap a title to select the book on its shelf.")
            end
            if similar and series_state and series_state.busy then
                modal.config.intro = modal.config.intro .. " " .. _("Grouping cached series metadata… No EPUB files are opened.")
            elseif similar and series_paused and series_state and not series_state.finished then
                modal.config.intro = modal.config.intro .. " " .. _("Series discovery paused. Tap Refresh to continue.")
            end
            modal:refresh()
        end
    end
    local function ensureSeries()
        if view ~= "series" and not similar or not data_session or not current() then return end
        if similar and #records == 0 then dropSeries(); return end
        if not series_state then
            series_state = Series.tagSeriesSession{
                current = function() return current() and data_session and data_session:current() end,
                profile = opts.profile,
                inventory = function() return data_session and data_session.inventory end,
                changed = render,
            }
        end
        series_state.update(records)
        if not series_paused then series_state.start() end
    end
    local function retireWork()
        busy, worker, paused = false, nil, true
        dropSeries()
        if not alive() then return end
        records, visible, data_session = {}, {}, nil
        base_intro = _("Search paused. Close and reopen the tag search to continue. Completed tag reads are kept.")
        render()
    end
    local function available(file) return fs.attributes(file, "mode") == "file" end
    filter = function()
        visible = {}
        if data_session and not data_session:current() then
            records, data_session = {}, nil
            dropSeries(); base_intro = failureText("stale")
            modal.config.intro = base_intro
        end
        local rows = view == "series" and series_state and series_state.rows() or records
        result_capped, missing_metadata = false, false
        if similar then
            -- Native count/repaint/filter callbacks may repeat. Rank once per
            -- checked snapshot/view, not on every paint or text submission.
            local finished, unavailable = series_state and series_state.finished, series_state and series_state.unavailable
            if not similar_snapshot or similar_snapshot.records ~= records or similar_snapshot.discovery ~= series_state
                    or similar_snapshot.view ~= view or similar_snapshot.finished ~= finished
                    or similar_snapshot.unavailable ~= unavailable then
                local ranked, incomplete = Series.similarRows(records, series_state, opts.origin, view)
                similar_snapshot = { records = records, discovery = series_state, view = view,
                    finished = finished, unavailable = unavailable, rows = ranked, incomplete = incomplete }
            end
            rows, missing_metadata = similar_snapshot.rows, similar_snapshot.incomplete
        end
        for _, book in ipairs(rows) do
            local text = table.concat({ book.filename or "", book.title or "", book.author or "" }, " ")
            if M.lower(text):find(M.lower(query), 1, true) then
                if not similar or #visible < 400 then visible[#visible + 1] = book else result_capped = true end
            end
        end
    end
    local function fetch(reread)
        if not current() or busy then return end
        local source, err
        if embedded then
            local ok, value = pcall(Integration.embeddedTagSession)
            if ok then source = value end
        else source, err = Integration.bookOrbitSession() end
        if not source then base_intro = failureText(err); render(); return end
        if similar then
            local Repo = require("lib/bookshelf_book_repository")
            local revision = Repo.dataGeneration()
            local source_current = source.current
            source.current = function(self)
                return source_current(self) and revision == Repo.dataGeneration()
                    and (not self.similar_revision or self.similar_revision == Integration.embeddedTagSnapshotRevision())
            end
        end
        busy, paused, series_paused = true, false, false
        dropSeries()
        records, visible, data_session = {}, {}, nil
        base_intro = intro
        render()
        local function update(result, failure, partial)
            if not current() then return end
            if result then
                if opts.on_result then opts.on_result(result) end
                data_session = source
                local previous = {}; for _, book in ipairs(records) do previous[book.filepath] = book end
                records = {}
                for _, file in ipairs(result.paths) do
                    if available(file) then
                        local record = previous[file] or { filepath = file, filename = file:match("([^/]+)$") or file }
                        record.similar_score = result.scores and result.scores[file]
                        record.similar_stamp = result.stamps and result.stamps[file]
                        records[#records + 1] = record
                    end
                end
                table.sort(records, function(a, b) return M.lower(a.filepath) < M.lower(b.filepath) end)
                base_intro = intro
                if embedded and (partial or failure == "cancelled") then
                    base_intro = intro .. " " .. string.format(_(failure == "cancelled"
                        and "Search stopped: %d of %d files checked. Results are incomplete. Refresh to continue."
                        or "Checking EPUB tags: %d of %d files. Results are incomplete."), result.scanned, result.total)
                end
                if result.truncated then base_intro = base_intro .. " " .. _("Showing the first 400 matches.")
                    .. " " .. _("Series are grouped from those matching volumes only.") end
                if (result.skipped or 0) > 0 then
                    base_intro = base_intro .. " " .. string.format(_("%d EPUBs could not be read; results may be incomplete. Refresh to retry."), result.skipped)
                end
                if similar and (result.unindexed or 0) > 0 then
                    base_intro = base_intro .. " " .. string.format(_("%d EPUBs have no current cached tags. Update the tag index for complete recommendations."), result.unindexed)
                end
            else
                records, data_session = {}, nil
                dropSeries()
                base_intro = failure == "cancelled" and _("Search cancelled. Tap Refresh to try again.")
                    or failureText(failure)
            end
            ensureSeries(); filter(); if not partial then modal.page = 1 end; render()
        end
        local function done(result, failure)
            busy, worker = false, nil
            update(result, failure, false)
        end
        if embedded then
            worker = Integration.embeddedTagRequest(source, { tag = tag, rule = rule, profile = opts.profile,
                origin = opts.origin, refresh = reread == true, similar = similar,
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
            if similar and (not series_state or not series_state.finished or series_state.unavailable) then return false end
            local matches
            if similar then
                local origin_meta, meta = series_state.metadata[opts.origin], series_state.metadata[book.filepath]
                if book.filepath == opts.origin or not origin_meta or not origin_meta._tag_known or not meta or not meta._tag_known then return false end
                local origin_key = Series.tagSeriesKey(origin_meta, "")
                if origin_key and origin_key == Series.tagSeriesKey(meta, "") then return false end
                -- The aggregate index is authoritative for this checked
                -- snapshot too: a pruned per-file JSON cache must not make
                -- valid SQL-backed recommendations unselectable.
                for _, checked in ipairs(records) do
                    if checked.filepath == book.filepath then
                        matches = (checked.similar_score or 0) > 0
                            and Integration.embeddedTagIsCurrent(book.filepath, checked.similar_stamp)
                            and Integration.embeddedTagIsCurrent(opts.origin, data_session.similar_stamp)
                        break
                    end
                end
            else matches = Integration.embeddedTagMatches(Integration.embeddedTags(book.filepath), rule) end
            if not matches then Context.notify(_("This file's tags changed or could not be read. Refresh the results.")); return false end
        end
        return true
    end
    local footer = {{ { label = _("Refresh"), label_func = function()
        return _((embedded and busy or series_state and series_state.busy) and "Stop search" or "Refresh")
    end, enabled_when = function()
        return validView() or embedded and busy and worker ~= nil
    end, on_tap = function()
        if embedded and busy and worker then
            series_paused = true
            if series_state then series_state.pause() end
            worker.cancel()
        elseif series_state and series_state.busy then series_paused = true; series_state.pause(); render()
        else fetch(false) end
    end },
        { label = _("Close"), on_tap = function() if alive() then modal:onClose() end end } }}
    if embedded then
        footer[#footer + 1] = {{ label = _(similar and "Update tag index…" or "Reread all EPUB tags…"), enabled_when = function() return validView() and not busy end, on_tap = function()
            if not current() or busy then return end
            modal:onClose()
            M.tagIndex{ confirm_reread = not similar }
        end }}
    end
    modal = require("lib/bookshelf_library_modal"):new{ _sui_keep_homescreen = true, config = {
        title = title .. ": " .. (similar and (opts.title or opts.origin:match("([^/]+)$"))
            or rule and table.concat(rule.tags, rule.mode == "all" and " + " or " / ") or tag),
        intro = intro,
        tabs = {{ key = "series", label = _("Series", nil, "tag-results") }, { key = "volumes", label = _(similar and "Books" or "Volumes") }},
        initial_tab = view,
        on_tab_change = function(key)
            if not current() or (key ~= "series" and key ~= "volumes") then return end
            view, query, series_paused = key, "", false
            if key == "volumes" and series_state and not similar then series_state.pause() end
            if ok_store and store.saveDeferred then pcall(store.saveDeferred, preference, key) end
            ensureSeries(); filter(); render()
        end,
        search_placeholder = function() return _(view == "series" and "Filter by series, title or author" or "Filter by filename") end,
        on_search_submit = function(value)
            if not current() then return end
            query = value or ""; filter(); modal.page = 1
            if similar then render() else modal:refresh() end
        end,
        grid_cols = 1, rows_per_page = 4,
        cells_per_page = function() return Screen:getWidth() > Screen:getHeight() and 3 or 4 end,
        item_count = function() filter(); return #visible end,
        item_at = function(index) return visible[index] end,
        empty_state = function(w, h)
            return require("lib/bookshelf_picker_cell").render({ label = _((busy or similar and series_state and series_state.busy) and "Loading…" or "No matches.") }, { w = w, h = h })
        end,
        cell_renderer = function(book, dimen)
            if book.tag_series then
                local note = string.format(_("%d matching volumes · %d available"), #book.matched, #book.members)
                if similar then note = string.format(_("Shared tags: %d · Available volumes: %d"), book.similar_score, #book.members) end
                local first = book.members[1]
                if first and tonumber(first.series_num) and tonumber(first.series_num) > 1 then
                    note = note .. " · " .. _("Volume 1 is not in cached metadata")
                elseif not first or not tonumber(first.series_num) then
                    note = note .. " · " .. _("Volume order is unknown")
                end
                return Series.tagSeriesCell(book, dimen, (book.author and book.author .. " · " or "") .. note)
            end
            if view == "volumes" and not similar then bookMeta(book) end
            local label = book.title or book.filename
            if view == "series" and book.tag_section_first then
                label = _(book.tag_section == "standalone" and "Standalone books" or "Unknown series metadata") .. " — " .. label
            end
            return require("lib/bookshelf_picker_cell").render({ label = label,
                subtitle = similar and ((book.author and book.author .. " · " or "")
                    .. string.format(_("Shared tags: %d"), book.similar_score)) or book.author or book.filename }, dimen)
        end,
        on_cell_tap = function(book)
            if book.tag_series then
                if not current() or not data_session or not data_session:current() then return end
                if not series_state or not series_state.finished or series_state.unavailable then
                    Context.notify(_("Series metadata is not complete yet. Wait, refresh, or switch to Volumes.")); return
                end
                local matching = false
                for _, member in ipairs(book.matched) do if canOpen(member) then matching = true; break end end
                if not matching then return end
                local source = data_session
                local reveal = opts.reveal_series or Context.revealSeries
                modal:onClose()
                reveal(book, { is_current = function() return source:current() end })
                return
            end
            if not canOpen(book) then return end
            local reveal = opts.reveal_book or Context.revealBook
            modal:onClose()
            -- A tag hit is navigation/preview, never a ReaderUI open (even
            -- when a caller supplied its usual open_book callback).
            reveal(book.filepath)
        end,
        cell_long_tap = function(book)
            if book.tag_series then
                if series_state and series_state.finished and not series_state.unavailable then
                    local first = book.matched[1]
                    if canOpen(first) then
                        if embedded and worker then worker.cancel() end
                        require("adapters/orbitui_book_panel").show(book.filepath, { open_book = opts.open_book })
                    end
                end
                return
            end
            if canOpen(book) then
                if embedded and worker then worker.cancel() end
                require("adapters/orbitui_book_panel").show(book.filepath, { open_book = opts.open_book })
            end
        end,
        footer_rows = footer,
        on_closed = function()
            retired = true; dropSeries(); if worker then worker.cancel(); worker = nil end
            if opts.on_closed then opts.on_closed() end
        end,
    } }
    function modal:onSuspend()
        dropSeries()
        if not embedded then return end
        sleeping = true
        if similar then
            series_paused, paused = true, true
            base_intro = _("Search paused. Close and reopen the tag search to continue. Completed tag reads are kept.")
        end
        if worker then worker.cancel() end
    end
    function modal:onResume()
        if not embedded then return end
        sleeping = false
        if busy and not current() then
            if worker then worker.cancel() end
            retireWork()
        elseif paused then render() else ensureSeries(); render() end
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

function M.similarBooks(file, opts)
    if type(file) ~= "string" or file:sub(1, 1) ~= "/" or not file:lower():match("%.epub$") then return end
    local options = {}; for key, value in pairs(opts or {}) do options[key] = value end
    options.embedded, options.similar, options.origin = true, true, file
    return tagSearch(nil, options)
end

function M.tagIndex(opts)
    opts = opts or {}
    local I, UI = require("adapters/orbitui_integrations"), require("ui/uimanager")
    local modal, worker, retired, busy = nil, nil, false, false
    local sleeping = false
    local status, failure = I.embeddedTagIndexStatus()
    local generation = UI._simpleui_navigation_generation
    local function alive()
        return not retired and modal ~= nil and UI:isWidgetShown(modal)
    end
    local function validView()
        return not retired and not sleeping and generation == UI._simpleui_navigation_generation
    end
    local function current() return alive() and validView() end
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
            {{ label = _("Update tag index"), enabled_when = function() return validView() and not busy end,
                on_tap = function() if failure == "invalid_job" then confirm("update") else start("update", false) end end },
             { label = _("Continue indexing"), enabled_when = function()
                return validView() and not busy and status ~= nil and status.current_scope and status.phase ~= "complete"
             end, on_tap = function() start(nil, true) end }},
            {{ label = _("Reread all EPUB tags…"), enabled_when = function() return validView() and not busy end,
                on_tap = function() confirm("reread") end },
             { label = _("Pause indexing"), enabled_when = function() return validView() and busy end,
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
        local definition = {
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
                    end },
                    { text = _("Word suggestions") .. ": " .. _(M.suggestionsEnabled() and "On" or "Off"),
                    hold_callback = function()
                        Context.notify(_("Complete the last word from cached local titles, authors and series. Tap a suggestion to fill it in, then Search. Suggestions need two letters, the cursor at the end and warm metadata in the selected scope. They can be incomplete; no files or network are read. Reopen search after sleep or rotation."))
                    end,
                    callback = function()
                        local query = dialog:getInputText()
                        local settings = store()
                        if not settings then return end
                        settings:set(SUGGESTIONS, not M.suggestionsEnabled())
                        UIManager:close(dialog); input(query)
                    end }},
            },
        }
        if M.suggestionsEnabled() then
            local row = {}
            for i = 1, 3 do
                row[i] = { id = "orbitui_word_" .. i, text = i == 1 and _("Word suggestions") or "—",
                    enabled = false, callback = function() end }
            end
            definition.buttons[#definition.buttons + 1] = row
        end
        dialog = require("ui/widget/inputdialog"):new(definition)
        for _i, row in ipairs(dialog.buttons) do
            for _j, button in ipairs(row) do
                if button.callback then button.callback = guarded(button.callback, function() return dialog end) end
                if button.hold_callback then button.hold_callback = guarded(button.hold_callback, function() return dialog end) end
            end
        end
        active = dialog
        UIManager:show(dialog)
        dialog:onShowKeyboard()
        if M.suggestionsEnabled() then
            M.attachWordSuggestions(dialog, { ui = UIManager,
                current = function() return current() and active == dialog end,
                snapshot = function() return suggestionSnapshot(scope_id, opts.ref) end })
        end
        return dialog
    end
    return input(opts.query)
end

local search = M.search
function M.search(...)
    return require("core/orbitui_host").measure("search", search, ...)
end
return M
