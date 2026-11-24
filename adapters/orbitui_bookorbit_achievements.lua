-- BookOrbit owns account authentication and achievements. OrbitUI only reads them.
local _ = require("core/orbitui_i18n")
local M = {}
local ID = "orbitui_bookorbit_achievements"
local CACHE = "simpleui_" .. ID .. "_cache"
local TTL = 900
local pending, last_attempt, key_record = {}, nil, nil
local messages = {
    unavailable = "Install and connect the BookOrbit plugin first.",
    disabled = "BookOrbit is disabled in OrbitUI.",
    unsupported = "Update the BookOrbit plugin to view achievements.",
    offline = "Connect to Wi-Fi to load achievements.",
    unauthorized = "Reconnect your BookOrbit account to load achievements.",
    key_unavailable = "This BookOrbit server could not open the full catalogue with an API key.",
    key_rejected = "BookOrbit did not accept the API key. Check it in OrbitUI settings.",
    no_summary = "BookOrbit returned no achievement information.",
    error = "Could not load BookOrbit achievements.",
    loading = "Loading achievements…",
}
local function store() return require("infra/sui_store") end
local function account()
    return require("adapters/orbitui_bookorbit_rows").account("enabled")
end
local function keyPath()
    return require("datastorage"):getSettingsDir() .. "/orbitui/bookorbit_achievements.key"
end
local function cleanKey(value)
    if type(value) ~= "string" then return nil end
    value = value:match("^%s*(.-)%s*$")
    if #value == 53 and value:match("^bok_[A-Za-z0-9]+$") then return value end
end
local function savedKey(owner)
    if not key_record then
        local raw = require("orbitui_bootstrap").read(keyPath(), 128) or ""
        local fingerprint, value = raw:match("^([^\n]+)\n([^\n]+)\n$")
        key_record = { owner = fingerprint, value = cleanKey(value) }
    end
    if key_record.owner == owner then return key_record.value end
end
local function setKey(owner, value)
    if account() ~= owner then return false, "unavailable" end
    local token = cleanKey(value)
    if value ~= nil and not token then return false, "invalid" end
    local ok = pcall(require("orbitui_bootstrap").atomicWrite, keyPath(), token and (owner .. "\n" .. token .. "\n") or "")
    if not ok then return false, "save_error" end
    key_record = { owner = owner, value = token }
    local engine = package.loaded["engines/sui_screen_engine"]
    if engine and engine.markAllStale then engine.markAllStale() end
    return true
end
local function cacheScope(owner, token)
    return token and require("ffi/sha2").sha256(owner .. "\n" .. token) or owner
end
local function language()
    local value = G_reader_settings and G_reader_settings:readSetting("language")
    return type(value) == "string" and value:lower():match("^%a%a%a?") or "en"
end
local function label(err)
    return _(messages[err] or messages.error)
end
local function clean(value, limit)
    if type(value) == "string" and #value <= limit then
        value = value:gsub("%c", " "):match("^%s*(.-)%s*$")
        if value ~= "" then return value end
    end
end
local function count(value)
    if type(value) == "number" and value >= 0 and value < 1e12 then return value end
end
local function integer(value)
    local n = count(value)
    return n and math.floor(n) == n and n or nil
end
local function array(value, limit)
    if type(value) ~= "table" or #value > limit then return nil end
    local size, used = #value, 0
    for k in pairs(value) do
        if type(k) ~= "number" or k < 1 or k > size or k ~= math.floor(k) then return nil end
        used = used + 1
    end
    if used == size then return value end
end
local function badge(item, earned)
    if type(item) ~= "table" then return nil end
    if not earned and item.hidden == true then return { secret = true, earned = false } end
    local title = clean(item.name, 400)
    if not title then return nil end
    local stamp = earned and clean(item.awardedAt, 40) or nil
    local day = stamp and stamp:match("^(%d%d%d%d%-%d%d%-%d%d)T")
    local icon = clean(item.iconName, 64)
    return { icon = icon and icon:match("^[a-z0-9][a-z0-9%-]*$"), rarity = clean(item.rarity, 32),
        title = title, description = clean(item.description, 2000), earned = earned,
        awarded_at = day and stamp or nil, day = day,
        group = not earned and clean(item.groupKey, 80) or nil,
        goal = not earned and count(item.threshold) or nil,
        progress = not earned and count(item.currentProgress) or nil }
end
local function normalise(body, full)
    if type(body) ~= "table" then return nil, "error" end
    local earned = integer(full and body.totalEarned or not full and body.earned)
    local total = integer(full and body.totalAvailable or not full and body.total)
    if not earned or not total or earned > total then return nil, "error" end
    local items, earned_items = {}, {}
    local function add(item)
        items[#items + 1] = item
        if item.earned then earned_items[#earned_items + 1] = item end
    end
    if full then
        local groups = array(body.categories, 64)
        if not groups or total > 2000 then return nil, "error" end
        for _, group in ipairs(groups) do
            local entries = type(group) == "table" and array(group.achievements, 2000 - #items)
            if not entries then return nil, "error" end
            for _, entry in ipairs(entries) do
                local item = type(entry) == "table" and type(entry.earned) == "boolean" and badge(entry, entry.earned)
                if not item then return nil, "error" end
                add(item)
            end
        end
        if #items ~= total or #earned_items ~= earned then return nil, "error" end
    else
        local latest, next_badge = badge(body.latest, true), badge(body.next, false)
        if latest then add(latest) end
        if next_badge then add(next_badge) end
    end
    local order = {}
    for i, item in ipairs(earned_items) do order[item] = i end
    table.sort(earned_items, function(a, b)
        local a_time, b_time = a.awarded_at or "", b.awarded_at or ""
        if a_time ~= b_time then return a_time > b_time end
        return order[a] < order[b]
    end)
    -- Persist each badge once. Earned badges precede the remaining ones.
    for _, item in ipairs(items) do
        if not item.earned then earned_items[#earned_items + 1] = item end
    end
    return { full = full, earned = earned, total = total, items = earned_items }
end

local function fetch(client, locale, token)
    local issue
    if token then
        if type(client.request) ~= "function" then return nil, "unsupported" end
        -- Retain BookOrbit's URL, redirect policy and subprocess depth. Send
        -- only the API key to the web route, using the same configured origin.
        local api = setmetatable({}, getmetatable(client))
        for k, v in pairs(client) do api[k] = v end
        api.username, api.userkey = nil, nil
        local body, err = api:request("GET", "/achievements", nil, { ["X-Api-Key"] = token, ["Accept-Language"] = locale })
        if body then return normalise(body, true) end
        if err == 401 or err == 403 then issue = "key_rejected"
        elseif err == 404 or err == 405 or err == 501 then issue = "key_unavailable"
        else return nil, err end
    end
    if type(client.catalogDashboard) ~= "function" then return nil, issue or "unsupported" end
    local dashboard, err = client:catalogDashboard()
    if not dashboard then
        if issue then return { status = issue } end
        return nil, err
    end
    if type(dashboard) ~= "table" then return nil, "error" end
    if dashboard.achievements == nil then return { status = issue or "no_summary" } end
    local data, failure = normalise(dashboard.achievements, false)
    if data then data.issue = issue end
    return data, failure
end
M.fetch = fetch

local function snapshot()
    local owner, err = account()
    if not owner then return nil, err end
    local key = cacheScope(owner, savedKey(owner))
    local cache = store():readSetting(CACHE)
    if type(cache) == "table" and (cache.version == 2 or cache.version == 3) and cache.account == key and cache.language == language()
            and type(cache.data) == "table" and type(cache.at) == "number" then
        -- Older snapshots still supply offline text. Refresh their missing artwork metadata on the next visible visit.
        return cache.data, cache.data.status or cache.data.issue, cache.version == 3 and cache.at or nil
    end
    if last_attempt and last_attempt.account == key and last_attempt.language == language() then
        return nil, last_attempt.error
    end
end
M.snapshot = snapshot

function M.refresh(observer, force)
    local owner, err, plugin = account()
    if not owner then return false, err end
    local token, locale = savedKey(owner), language()
    local key = cacheScope(owner, token)
    local job_id = key .. ":" .. locale
    local UI, Device = require("ui/uimanager"), require("device")
    local function visible(entry)
        return not Device.screen_saver_mode and UI:isWidgetShown(entry.owner) and entry.current()
    end
    if not visible(observer) then return false end
    local function observe(job)
        for i = #job.observers, 1, -1 do
            local entry = job.observers[i]
            if entry.owner == observer.owner or not UI:isWidgetShown(entry.owner) then table.remove(job.observers, i) end
        end
        job.observers[#job.observers + 1] = observer
    end
    if pending[job_id] and pending[job_id].plugin == plugin then
        observe(pending[job_id])
        return true
    end
    local cached, failure, at = snapshot()
    local now = os.time()
    local freshness = cached and (cached.status or cached.issue) and 60 or TTL
    if not force and at and now >= at and now - at < freshness then return false, failure end
    if not force and last_attempt and last_attempt.account == key and last_attempt.language == locale
            and now >= last_attempt.at and now - last_attempt.at < 60 then return false, last_attempt.error end
    local network = require("ui/network/manager")
    if not network:isConnected() then return false, "offline" end
    local guard = require("adapters/orbitui_integrations").bookOrbitGuard("enabled")
    local job = { plugin = plugin, observers = {} }
    pending[job_id] = job
    observe(job)
    local function sessionCurrent()
        local current, _, instance = account()
        return guard and guard() and current == owner and savedKey(owner) == token and instance == plugin
            and language() == locale
            and not Device.screen_saver_mode
    end
    local function observed()
        for _, entry in ipairs(job.observers) do if visible(entry) then return true end end
        return false
    end
    UI:scheduleIn(.1, function()
        require("ui/trapper"):wrap(function()
            local ok, data, failure = pcall(function()
                if not sessionCurrent() or not observed() then return nil, "stale" end
                local client = plugin:newClient()
                if not client or type(client.canForkSubprocess) ~= "function"
                        or type(client.runInSubprocess) ~= "function" or not client:canForkSubprocess() then
                    return nil, "unsupported"
                end
                local completed, result = client:runInSubprocess(function() return fetch(client, locale, token) end)
                if completed and type(result) == "table" then return result.body, result.err end
                return nil, "error"
            end)
            if pending[job_id] ~= job then return end
            pending[job_id] = nil
            if not sessionCurrent() or failure == "stale" then return end
            if not ok then data, failure = nil, "error" end
            if failure == 401 or failure == 403 then data, failure = { status = "unauthorized" }, "unauthorized" end
            failure = data and (data.status or data.issue) or failure or (not data and "error" or nil)
            -- A successful read discarded after navigation must not throttle
            -- the next visit. A server rejection still retires old badges.
            if not observed() and not (data and failure) then return end
            local saved_at = os.time()
            last_attempt = { account = key, language = locale, at = saved_at, error = failure }
            if data then
                store():saveSetting(CACHE, { version = 3, account = key, language = locale, at = saved_at, data = data })
            end
            for _, entry in ipairs(job.observers) do if visible(entry) then entry.done(failure) end end
        end)
    end)
    return true
end

local function title(item)
    return item.secret and _("Secret achievement") or item.title
end
local function details(item)
    if item.secret then return _("Keep reading to reveal this achievement.") end
    return item.description
end
local function countLine(data)
    return string.format(_("%d of %d earned"), data.earned, data.total)
end
local function progress(item)
    if item.earned then return item.day or _("Earned") end
    if item.progress and item.goal and item.goal > 0 then
        return string.format("%g / %g", item.progress, item.goal)
    end
    return _("Remaining")
end

-- The dashboard returns its chosen next badge. The full catalogue uses the
-- same rule as BookOrbit: highest unfinished fraction, first match on a tie.
local function nextMilestone(data)
    local best, fraction = nil, -1
    for _, item in ipairs(data.items) do
        if not item.earned and not item.secret and item.goal and item.progress and item.progress < item.goal then
            local ratio = item.progress / item.goal
            if ratio > fraction then best, fraction = item, ratio end
        end
    end
    return best
end

local remaining_units = {
    books_finished = { "1 book left", "%g books left" },
    pages_read = { "1 page left", "%g pages left" },
    hours_read = { "1 hour left", "%g hours left" },
    streak = { "1 day left", "%g days left" },
}
local function remaining(item)
    local units = remaining_units[item.group]
    if not units then return progress(item) end
    local left = item.goal - item.progress
    if left == 1 then return _(units[1]) end
    return string.format(_(units[2]), left)
end

local function textWidget(text, w, h, size, bold)
    return require("ui/widget/textboxwidget"):new{ text = text, width = w, height = h, height_adjust = false,
        height_overflow_show_ellipsis = true, face = require("ui/font"):getFace("cfont", size), bold = bold }
end

-- Rendering is limited to the displayed badges. Both views reserve the
-- same column for the medal; narrow cards keep the text area usable.
local function medalRow(item, width, height, max_size, content)
    local screen = require("device").screen
    local size = math.min(height, screen:scaleBySize(max_size), math.floor(width * .28))
    local image = require("adapters/orbitui_achievement_medal").widget(item, size)
    if not image then return content(width) end
    local gap = math.min(screen:scaleBySize(7), math.floor(width / 12))
    return require("ui/widget/horizontalgroup"):new{ align = "center", image,
        require("ui/widget/horizontalspan"):new{ width = gap }, content(width - size - gap) }
end

function M.openKey(on_change)
    local owner, err = account()
    local Context = require("core/orbitui_context")
    if not owner then Context.notify(label(err)); return end
    local UI = require("ui/uimanager")
    local dialog
    local function save(value)
        local ok, failure = setKey(owner, value)
        if not ok then
            local message = failure == "invalid" and _("Enter a valid BookOrbit API key beginning with bok_.")
                or failure == "save_error" and _("Could not save the BookOrbit API key on this device.") or label(failure)
            Context.notify(message)
            return
        end
        UI:close(dialog)
        if on_change then UI:nextTick(on_change) end
    end
    local buttons = { {
        { text = _("Cancel"), id = "close", callback = function() UI:close(dialog) end },
        { text = _("Save"), is_enter_default = true, callback = function() save(dialog:getInputText()) end },
    } }
    local configured = savedKey(owner)
    if configured then
        buttons[#buttons + 1] = { { text = _("Remove API key"), callback = function() save(nil) end } }
    end
    dialog = require("ui/widget/inputdialog"):new{
        title = _("BookOrbit achievements API key"),
        description = _("Create a read-only API key in BookOrbit under Settings › You › API keys, using the same account as the KOReader plugin."),
        input_hint = configured and _("Paste a replacement key") or _("Paste the BookOrbit API key"),
        input = "", text_type = "password", allow_newline = false, buttons = buttons, _sui_keep_homescreen = true,
    }
    UI:show(dialog)
    dialog:onShowKeyboard()
    return dialog
end

function M.open(ctx)
    local UI = require("ui/uimanager")
    local Modal = require("lib/bookshelf_library_modal")
    local modal, data, failure
    local tab, rows = "all", {}
    local function rebuild()
        data, failure = snapshot()
        rows = {}
        for _, item in ipairs(data and data.items or {}) do
            if tab == "all" or (tab == "earned" and item.earned) or (tab == "remaining" and not item.earned) then
                rows[#rows + 1] = item
            end
        end
    end
    local function refresh(force)
        local function redraw(err)
            rebuild()
            failure = err or failure
            modal:refresh()
        end
        local started, err = M.refresh({ owner = modal,
            current = function() return UI:getTopmostVisibleWidget() == modal end, done = redraw }, force)
        redraw(started and "loading" or err)
    end
    local config = {
        title = _("Achievements"), no_search = true, grid_cols = 1,
        tabs = { { key = "all", label = _("All") }, { key = "earned", label = _("Earned") },
            { key = "remaining", label = _("Remaining") } },
        on_tab_change = function(key) tab = key; rebuild() end,
        item_count = function() return #rows end, item_at = function(i) return rows[i] end,
        cells_per_page = function()
            local screen = require("device").screen
            return screen:getWidth() > screen:getHeight() and 4 or 5
        end,
        header_actions = {
            { label = _("API key…"), on_tap = function() M.openKey(function()
                if UI:getTopmostVisibleWidget() == modal then refresh(false) end
            end) end },
            { label = _("Refresh"), on_tap = function() refresh(true) end },
        },
        footer_actions = { { key = "close", label = _("Close"), on_tap = function() UI:close(modal) end } },
        empty_state = function(w, h)
            local value
            if failure then value = label(failure)
            elseif data and data.full then
                value = tab == "earned" and _("No achievements earned yet.") or _("No achievements to show.")
            else value = _("Add a BookOrbit API key to see the full catalogue.") end
            return textWidget(value, w, h, 16, false)
        end,
        cell_renderer = function(item, dimen)
            return medalRow(item, dimen.w, dimen.h, 56, function(width)
                return Modal.sheetRow({ title = title(item), subtitle = progress(item) }, { w = width, h = dimen.h })
            end)
        end,
        on_cell_tap = function(item)
            local copy = title(item) .. "\n" .. progress(item)
            local desc = details(item)
            if desc then copy = copy .. "\n\n" .. desc end
            UI:show(require("ui/widget/infomessage"):new{ text = copy, _sui_keep_homescreen = true })
        end,
        on_closed = function()
            local owner = ctx._screen_widget
            if ctx.orbitui_dashboard_hosted and owner then owner = (getmetatable(owner) or {}).__index or owner end
            if not ctx.refresh_fn or not owner then return end
            UI:nextTick(function()
                if UI:getTopmostVisibleWidget() == owner then ctx.refresh_fn() end
            end)
        end,
    }
    rebuild()
    -- The fallback notice remains visible when the summary has some badges.
    config.intro = function()
        if not data or not data.items then return nil end
        local count_line = countLine(data)
        if not data.full and not data.issue then
            count_line = count_line .. "\n" .. _("Add a BookOrbit API key to see the full catalogue.")
        end
        if failure and failure ~= "loading" then count_line = count_line .. "\n" .. label(failure) end
        return count_line
    end
    modal = Modal:new{ _sui_keep_homescreen = true, config = config }
    UI:show(modal)
    refresh(false)
    return modal
end

-- Earned items are already sorted newest first. Reserve the last visible
-- place for the next milestone when the card can show both.
local function cardItems(data, milestone, capacity)
    local items = {}
    local earned_limit = math.max(1, capacity - (milestone and 1 or 0))
    for _, item in ipairs(data and data.items or {}) do
        if not item.earned or #items == earned_limit then break end
        items[#items + 1] = item
    end
    if milestone and #items < capacity then items[#items + 1] = milestone end
    return items
end

local function listRow(item, w, h)
    local screen = require("device").screen
    local heading, detail = title(item), nil
    if h >= screen:scaleBySize(44) then
        if item.earned then detail = item.day
        else heading, detail = _("Next milestone") .. " · " .. heading, remaining(item) end
    elseif not item.earned then
        heading = remaining(item) .. " · " .. heading
    end
    return medalRow(item, w, h, 48, function(width)
        if not detail then
            local size = h < screen:scaleBySize(25) and 13 or 15
            return textWidget(heading, width, math.min(h, screen:scaleBySize(30)), size, true)
        end
        local half = math.floor(h / 2)
        return require("ui/widget/verticalgroup"):new{ align = "left",
            textWidget(heading, width, half, 15, true), textWidget(detail, width, h - half, 14, false) }
    end)
end

local function medalTile(item, w, h)
    local screen = require("device").screen
    local Text = require("ui/widget/textwidget")
    local Font = require("ui/font")
    local function caption(value, size, bold)
        return Text:new{ text = value, face = Font:getFace("cfont", size), bold = bold,
            padding = 0, max_width = math.max(1, w - screen:scaleBySize(4)) }
    end
    local name = caption(title(item), 12, true)
    local detail
    if h >= screen:scaleBySize(76) then
        local value = item.earned and item.day
        if not item.earned then value = remaining(item) end
        if value then detail = caption(value, 12, false) end
    end
    local space = h - name:getSize().h - (detail and detail:getSize().h or 0)
    local image = require("adapters/orbitui_achievement_medal").widget(item, math.min(space, w, screen:scaleBySize(54)))
    local tile = require("ui/widget/verticalgroup"):new{}
    if image then tile[#tile + 1] = image end
    tile[#tile + 1] = name
    if detail then tile[#tile + 1] = detail end
    return require("ui/widget/container/centercontainer"):new{
        dimen = require("ui/geometry"):new{ w = w, h = h }, tile }
end

local function cardContent(data, failure, preview, w, h)
    local screen = require("device").screen
    local group = require("ui/widget/verticalgroup"):new{ align = "left" }
    local body_h = h
    if preview or h >= screen:scaleBySize(68) then
        local header = data and data.items and countLine(data) or _("Latest achievements")
        local header_h = math.min(h, screen:scaleBySize(24))
        group[#group + 1] = textWidget(header .. "  ›", w, header_h, 16, true)
        body_h = math.max(1, h - header_h)
    end
    if preview then return group end

    local grid = w >= screen:scaleBySize(150)
    local rows = math.max(1, math.min(3, math.floor(body_h / screen:scaleBySize(42))))
    local list_capacity = math.max(1, math.min(6, math.floor(body_h / screen:scaleBySize(21))))
    local milestone = data and data.items and nextMilestone(data)
    local items = cardItems(data, milestone, grid and rows * 3 or list_capacity)
    if #items == 0 then
        local copy = data and data.items and _("No recent achievements to show.") or label(failure or "loading")
        local message = textWidget(copy, w, body_h, 14, false)
        group[#group + 1] = message
        return group, message
    end
    if grid and (#items >= 3 or #items == 2 and list_capacity == 1) then
        local columns = (#items == 4 or #items == 2) and 2 or 3
        local row_h = math.floor(body_h / math.ceil(#items / columns))
        for first = 1, #items, columns do
            local row = require("ui/widget/horizontalgroup"):new{}
            for i = first, math.min(first + columns - 1, #items) do
                row[#row + 1] = medalTile(items[i], math.floor(w / columns), row_h)
            end
            group[#group + 1] = row
        end
    else
        local row_h = math.floor(body_h / #items)
        for _, item in ipairs(items) do group[#group + 1] = listRow(item, w, row_h) end
    end
    return group
end

local function getHeight()
    return require("device").screen:scaleBySize(142)
end
local function build(w, ctx)
    local UI, Screen = require("ui/uimanager"), require("device").screen
    local owner = ctx._screen_widget
    if ctx.orbitui_dashboard_hosted and owner then owner = (getmetatable(owner) or {}).__index or owner end
    local preview = ctx.preview or not owner
    local data, failure
    if not preview then data, failure = snapshot() end
    local h = ctx.orbitui_dashboard_hosted and ctx.height or getHeight()
    local pad = math.min(Screen:scaleBySize(6), math.floor(w / 20), math.floor(h / 18))
    local inner, usable = math.max(1, w - pad * 2), math.max(1, h - pad * 2)
    local group, message = cardContent(data, failure, preview, inner, usable)
    local clip = require("lib/bookshelf_clip_container"):new{ w = w, h = h,
        require("ui/widget/container/framecontainer"):new{ padding = pad, bordersize = 0,
            require("ui/widget/container/topcontainer"):new{
                dimen = require("ui/geometry"):new{ w = inner, h = usable }, group } } }
    if preview then return clip end
    local page, dashboard_page, navigation = owner._current_page, owner._orbitui_dashboard_module_page, UI._simpleui_navigation_generation
    local painted, disposed = false, false
    local function current()
        return not disposed and not owner._closed and not owner._suspended and not owner._parked
            and owner._current_page == page and UI._simpleui_navigation_generation == navigation
            and (not ctx.orbitui_dashboard_hosted or owner._orbitui_dashboard_module_page == dashboard_page)
            and UI:getTopmostVisibleWidget() == owner
    end
    local paint, free = clip.paintTo, clip.free
    function clip:paintTo(...)
        paint(self, ...)
        if painted or not current() then return end
        painted = true
        local started, err = M.refresh({ owner = owner, current = current, done = function()
            if ctx.refresh_fn then ctx.refresh_fn() end
        end })
        if not started and err == "offline" and not data and not failure then
            UI:nextTick(function()
                if current() then
                    message:setText(label("offline"))
                    UI:setDirty(owner, "ui", self.dimen)
                end
            end)
        end
    end
    function clip:free(...)
        disposed = true
        if free then return free(self, ...) end
    end
    if ctx.orbitui_dashboard_hosted then return clip end
    local dimen = require("ui/geometry"):new{ w = w, h = h }
    return require("ui/widget/container/inputcontainer"):new{ dimen = dimen, clip,
        ges_events = { TapAchievements = { require("ui/gesturerange"):new{ ges = "tap", range = dimen } } },
        onTapAchievements = function() M.open(ctx); return true end }
end

function M.install(registry)
    if registry._orbitui_bookorbit_achievements then return end
    registry._orbitui_bookorbit_achievements = true
    registry.register{ id = ID, name = _("BookOrbit achievements"), label = _("BookOrbit achievements"),
        category = "stats", text_elems = { "label" }, enabled_key = ID .. "_enabled", default_on = false, build = build, getHeight = getHeight, on_tap = M.open }
end
return M
