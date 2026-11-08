-- Read-only catalog adapter. No book open, download, status/sync write or local
-- library scan. The external plugin owns login, stable file links and HTTP.
local Model = require("core/orbitui_dashboard")
local _ = require("core/orbitui_i18n")
local M = { ttl = 900, max_books = 10000, max_sources = 1000 }
local CACHE = "simpleui_orbitui_bookorbit_rows_cache"
local queue, pending, running, attempts, errors = {}, {}, false, {}, {}
local function store() return require("infra/sui_store") end
local function integration() return require("adapters/orbitui_integrations") end
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end
local function array(t, limit)
    if type(t) ~= "table" or #t > limit then return false end
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > #t or k ~= math.floor(k) then return false end
        n = n + 1
    end
    return n == #t
end
local function id(n)
    n = tonumber(n)
    if n and n > 0 and n < 9007199254740992 and n == math.floor(n) then return n end
end
local function timestamp(n)
    return type(n) == "number" and n == n and n > 0 and n <= os.time() + 300 and n or nil
end
local function plugin()
    local ok, p = pcall(require("core/orbitui_context").plugin, "bookorbit")
    return ok and p or nil
end
function M.account()
    if not integration().bookOrbitEnabled("rows") then return nil, "disabled" end
    local p = plugin()
    local s = p and p.settings
    if not p or type(p.newClient) ~= "function" or type(s) ~= "table"
            or type(s.server_url) ~= "string" or s.server_url == ""
            or type(s.username) ~= "string" or s.username == ""
            or type(s.userkey) ~= "string" or s.userkey == "" then return nil, "unavailable" end
    return require("ffi/sha2").sha256(s.server_url:gsub("/+$", "") .. "\n" .. s.username .. "\n" .. s.userkey), nil, p
end
local function key(source) return source.section .. ":" .. string.format("%.0f", source.id) end
local function cache(account)
    local c = store():readSetting(CACHE)
    if type(c) == "table" and c.version == 1 and c.account == account then return c end
    return { version = 1, account = account, catalog = {}, rows = {} }
end
local function pathValid(path)
    return type(path) == "string" and #path < 4096 and path:sub(1, 1) == "/"
        and not path:find("%c")
end
local function exists(path)
    return pathValid(path) and require("libs/libkoreader-lfs").attributes(path, "mode") == "file"
end
M.fileExists = exists
function M.catalog()
    local account, err = M.account()
    if not account then return {}, err end
    local out, c = {}, cache(account)
    if array(c.catalog, M.max_sources) then
        for _, source in ipairs(c.catalog) do
            source = Model.bookOrbitSource(source)
            if source and source.account == account then out[#out + 1] = source end
        end
    end
    return out, nil, timestamp(c.catalog_at)
end
-- Fast path: saved paths only. Never construct a client, enumerate a manifest,
-- resolve all IDs, or request the network from widget build/paint.
function M.snapshot(source)
    source = Model.bookOrbitSource(source)
    if not source then return { files = {}, error = "source" } end
    local account, err = M.account()
    if not account then return { files = {}, error = err } end
    if account ~= source.account then return { files = {}, error = "account" } end
    local c = cache(account)
    local row = type(c.rows) == "table" and c.rows[key(source)]
    local files, seen = {}, {}
    if type(row) == "table" and array(row.files, M.max_books) then
        for _, path in ipairs(row.files) do
            -- These were existence-checked by the worker. Revalidate only the
            -- displayed covers in the view, not 10,000 paths on every paint.
            if pathValid(path) and not seen[path] then seen[path] = true; files[#files + 1] = path end
        end
    else row = nil end
    return { files = row and row.missing and {} or files, at = row and timestamp(row.at), total = row and tonumber(row.total),
        error = row and row.missing and "missing" or errors[account .. ":" .. key(source)] }
end
local messages = {
    disabled = "BookOrbit cards are disabled.",
    unavailable = "Connect the BookOrbit KOReader plugin first.",
    unsupported = "Update the BookOrbit plugin/server: the catalog API is required.",
    account = "This card belongs to another BookOrbit connection. Choose its source again.",
    missing = "This BookOrbit source is missing or no longer accessible. Choose another source.",
    source = "Choose a BookOrbit shelf or smartscope for this card.",
    offline = "Offline. Saved results are kept.",
    stale = "The connection or view changed. Saved results are kept.",
}
function M.message(err)
    return _(messages[err] or "BookOrbit could not refresh this list. Saved results are kept; check the connection and retry.")
end
function M.caption(snapshot)
    if snapshot.error then return M.message(snapshot.error) end
    if not snapshot.at then return _("Not refreshed yet. Only linked books on this device will be shown.") end
    return string.format(_("%d on device · %s"), #snapshot.files, os.date("%m-%d %H:%M", snapshot.at))
end
local function connected()
    local ok, value = pcall(function() return require("ui/network/manager"):isConnected() end)
    return ok and value == true
end
local function observers(job)
    local live = false
    for _, o in ipairs(job.observers) do
        local ok, value = pcall(o.current or function() return true end)
        if ok and value then live = true end
    end
    return live
end
-- Fail closed if a plugin version would execute HTTP inline. Requiring its
-- native subprocess API avoids a "background" request blocking Home instead.
local function session(job)
    local account, _, p = M.account()
    if account ~= job.account or not job.guard() or not observers(job) then return nil, "stale" end
    if not connected() then return nil, "offline" end
    local client = p:newClient()
    if type(client.runInSubprocess) ~= "function" or type(client.canForkSubprocess) ~= "function"
            or not client:canForkSubprocess() or type(client.catalogSection) ~= "function"
            or type(client.catalogBooks) ~= "function" then return nil, "unsupported" end
    local manager = require("bookorbit_state_manager")
    if type(manager.computeOnDeviceMaps) ~= "function" or type(manager.generation) ~= "function" then
        return nil, "unsupported"
    end
    local generation = manager.generation()
    return { client = client, manager = manager, current = function()
        return job.guard() and M.account() == account and plugin() == p
            and manager.generation() == generation and observers(job)
            and not require("device").screen_saver_mode
    end }
end
local function fetchCatalog(client, account, only)
    local out, seen = {}, {}
    for _, section in ipairs(only and { only } or { "libraries", "collections", "smart-scopes" }) do
        local count = 0
        for page = 1, 20 do
            local body, err = client:catalogSection(section, { page = page, size = 100 })
            if not body then return nil, (err == 404 or err == 501) and "unsupported" or err end
            if not array(body.items, M.max_sources) then return nil, "invalid" end
            local added = 0
            for _, item in ipairs(body.items) do
                local source = type(item) == "table" and Model.bookOrbitSource{
                    account = account, section = section, id = id(item.id), title = item.title }
                if not source then return nil, "invalid" end
                if not seen[key(source)] then
                    out[#out + 1], seen[key(source)], added = source, true, added + 1
                    count = count + 1
                end
            end
            if #out > M.max_sources then return nil, "limit" end
            local more = body.hasNext == true or tonumber(body.total) and tonumber(body.total) > count
            -- Older section APIs return the complete array without pagination.
            if not more then break end
            if added == 0 or page == 20 then return nil, "incomplete" end
        end
    end
    return out
end
local function fetchBooks(s, source)
    local ids, seen = {}, {}
    -- Do not trust a removed/mistyped filter to keep narrowing the catalog.
    -- Confirm the exact source is still visible before asking for its books.
    local catalog, err = fetchCatalog(s.client, source.account, source.section)
    if not catalog then return nil, err == 403 and "missing" or err end
    local found = false
    for _, item in ipairs(catalog) do if item.id == source.id then found = true; break end end
    if not found then return nil, "missing" end
    local param = ({ libraries = "libraryId", collections = "collectionId", ["smart-scopes"] = "smartScopeId" })[source.section]
    for page = 1, 100 do
        local query = { sort = "title", order = "asc", page = page, size = 100 }
        query[param] = source.id
        local body, err = s.client:catalogBooks(query)
        if not body then return nil, (err == 404 or err == 403) and "missing" or err end
        if not array(body.items, 1000) then return nil, "invalid" end
        local total = tonumber(body.total)
        if total and (total ~= total or total < 0 or total > M.max_books or total ~= math.floor(total)) then return nil, "limit" end
        if type(body.hasNext) ~= "boolean" and total == nil then return nil, "unsupported" end
        local added = 0
        for _, book in ipairs(body.items) do
            local n = type(book) == "table" and id(book.id)
            if not n then return nil, "invalid" end
            if not seen[n] then ids[#ids + 1], seen[n], added = n, true, added + 1 end
        end
        if #ids > M.max_books then return nil, "limit" end
        local more = body.hasNext == true or tonumber(body.total) and tonumber(body.total) > #ids
        if not more then
            local computed = s.manager.computeOnDeviceMaps()
            if type(computed) ~= "table" or not array(computed.bookEntries, 50000) then return nil, "invalid_maps" end
            local by_id, owners, files, used = {}, {}, {}, {}
            for _, entry in ipairs(computed.bookEntries) do
                local n, path = id(entry.id), entry.file
                if n and pathValid(path) then
                    if by_id[n] == nil then by_id[n] = path
                    elseif by_id[n] ~= path then by_id[n] = false end
                    if owners[path] == nil then owners[path] = n
                    elseif owners[path] ~= n then owners[path] = false end
                end
            end
            for _, n in ipairs(ids) do
                local path = by_id[n]
                if path and owners[path] == n and not used[path] and exists(path) then
                    files[#files + 1], used[path] = path, true
                end
            end
            return { files = files, total = #ids }
        end
        if added == 0 then return nil, "incomplete" end
    end
    return nil, "limit"
end
local function finish(job, result)
    pending[job.key], running = nil, false
    errors[job.key] = not result.ok and result.error or nil
    for _, o in ipairs(job.observers) do
        local ok, value = pcall(o.current or function() return true end)
        if ok and value and o.on_done then pcall(o.on_done, result) end
    end
end
local pump
pump = function()
    if running or #queue == 0 then return end
    local job = table.remove(queue, 1)
    running = true
    require("ui/uimanager"):scheduleIn(0.15, function()
        require("ui/trapper"):wrap(function()
            local ok, err = pcall(function()
                local s, why = session(job)
                if not s then return { ok = false, error = why } end
                local complete, result = s.client:runInSubprocess(function()
                    if job.source then return fetchBooks(s, job.source) end
                    return fetchCatalog(s.client, job.account)
                end)
                if not complete then return { ok = false, error = "cancelled" } end
                if not s.current() then return { ok = false, error = "stale" } end
                if not result or result.body == nil then
                    local failure = result and result.err or "request"
                    -- A definitive access/removal failure suppresses an old
                    -- row without deleting its last successful cached files.
                    if job.source and failure == "missing" then
                        local c = copy(cache(job.account)); c.rows = c.rows or {}
                        local row = c.rows[key(job.source)]
                        if row then row.missing = true; store():saveSetting(CACHE, c) end
                    end
                    return { ok = false, error = failure }
                end
                local c = copy(cache(job.account))
                if job.source then
                    local payload = result.body
                    if not array(payload.files, M.max_books) then return { ok = false, error = "invalid" } end
                    local files = payload.files
                    c.rows = type(c.rows) == "table" and c.rows or {}
                    local k = key(job.source)
                    c.rows[k] = { files = files, total = payload.total, at = os.time() }
                    -- Bounded owned cache, not BookOrbit's links or sync state.
                    local keys, bytes = {}, 0
                    for row_key, row in pairs(c.rows) do
                        local size = 0
                        if type(row) == "table" and array(row.files, M.max_books) then
                            for _, path in ipairs(row.files) do
                                if pathValid(path) then size = size + #path else size = size + 4096 end
                            end
                        end
                        keys[#keys + 1] = { key = row_key, at = type(row) == "table" and timestamp(row.at) or 0, bytes = size }
                        bytes = bytes + size
                    end
                    table.sort(keys, function(a, b)
                        if a.key == k then return true end
                        if b.key == k then return false end
                        return a.at > b.at or a.at == b.at and a.key < b.key
                    end)
                    for i = #keys, 1, -1 do
                        if keys[i].key ~= k and (i > 32 or bytes > 2 * 1024 * 1024) then
                            c.rows[keys[i].key] = nil; bytes = bytes - keys[i].bytes
                        end
                    end
                    if bytes > 2 * 1024 * 1024 then return { ok = false, error = "limit" } end
                else c.catalog, c.catalog_at = result.body, os.time() end
                if not s.current() then return { ok = false, error = "stale" } end
                store():saveSetting(CACHE, c)
                return { ok = true }
            end)
            finish(job, ok and err or { ok = false, error = "request" })
            pump()
        end)
    end)
end
function M.refresh(source, opts)
    opts = opts or {}
    local account, err = M.account()
    local invalid = source ~= nil and not Model.bookOrbitSource(source)
    source = source ~= nil and Model.bookOrbitSource(source) or nil
    local function reject(why)
        if opts.on_done then opts.on_done{ ok = false, error = why } end
        return false, why
    end
    if not account then return reject(err) end
    if invalid or opts.source_required and not source then return reject("source") end
    if source and source.account ~= account then return reject("account") end
    local k = account .. ":" .. (source and key(source) or "catalog")
    if pending[k] then pending[k].observers[#pending[k].observers + 1] = opts; return true end
    if not opts.force then
        local at
        if source then at = M.snapshot(source).at else at = select(3, M.catalog()) end
        if at and os.time() - at >= 0 and os.time() - at < M.ttl then return false, "fresh" end
        if attempts[k] and os.time() - attempts[k] >= 0 and os.time() - attempts[k] < 60 then return false, "recent_attempt" end
    end
    if #queue >= Model.module_limit then return reject("busy") end
    attempts[k] = os.time()
    local job = { key = k, account = account, source = source, guard = integration().bookOrbitGuard("rows"), observers = { opts } }
    pending[k], queue[#queue + 1] = job, job
    pump()
    return true
end
return M
