-- Cooperative, read-only BIM refresh. Never fork on Android or borrow BIM's
-- live connection; each tick reads a small rowid window without cover blobs.
local M = { active = false, invalidated = false }
local job, request
local columns = "directory, filename, title, authors, series, series_index, keywords, language, "
    .. "pages, description, has_meta, has_cover, ignore_cover, ignore_meta, cover_sizetag, cover_fetched, cover_w, cover_h"
local fields = { "title", "authors", "series", "series_index", "keywords", "language",
    "pages", "description", "has_meta", "has_cover", "ignore_cover", "ignore_meta", "cover_sizetag", "cover_fetched", "cover_w", "cover_h" }

-- Cover dimensions and extraction flags belong to the raw row. A new cover
-- does not change the already resolved title, authors or series of a volume.
local function sameMetadata(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return a.title == b.title and a.authors == b.authors and a.series == b.series
        and a.series_index == b.series_index and a.keywords == b.keywords
        and a.language == b.language and a.pages == b.pages and a.description == b.description
        and a.has_meta == b.has_meta and a.ignore_meta == b.ignore_meta
end

function M.replaceRows(scopes, rows)
    for key, entry in pairs(scopes) do
        if entry.rows then
            -- Iterate only materialized records. A keyed lookup on the lazy
            -- map would derive metadata for books nobody has asked about.
            for path in pairs(entry.map) do
                if not sameMetadata(entry.rows[path], rows[path]) then
                    rawset(entry.map, path, nil)
                end
            end
            entry.rows = rows
        else
            -- No batch on the previous read: rebuild a proper lazy map.
            scopes[key] = nil
        end
    end
end

local function cancel()
    local old = job
    job = nil
    if not old then return end
    old.ui:unschedule(old.tick)
    if old.conn then pcall(old.conn.close, old.conn); old.conn = nil end
end

local function start()
    if not M.active or job or M.rows or not request then return end
    local ok, ui = pcall(require, "ui/uimanager")
    if not ok or not ui.scheduleIn or not ui.unschedule then return end
    local opts = request
    local current = { ui = ui, last = 0, rows = {}, batch = 8 }
    job = current
    current.tick = function()
        if job ~= current or not M.active then return end
        local success, err = pcall(function()
            if not current.conn then
                current.fingerprint = opts.fingerprint()
                if not current.fingerprint then error("BIM database unavailable") end
                local path = require("datastorage"):getSettingsDir() .. "/bookinfo_cache.sqlite3"
                current.conn = require("lua-ljsqlite3/init").open(path, "ro")
                current.conn:exec("PRAGMA busy_timeout=0;")
                current.version = tonumber(current.conn:exec("PRAGMA data_version;")[1][1])
            end
            local rows = current.conn:exec("SELECT rowid, in_progress, " .. columns
                .. " FROM bookinfo WHERE rowid > " .. current.last
                .. " ORDER BY rowid LIMIT " .. current.batch .. ";")
            local n = rows and rows[1] and #rows[1] or 0
            for i = 1, n do
                current.last = assert(tonumber(rows[1][i]))
                if tonumber(rows[2][i]) == 0 then
                    local fp = (rows[3][i] or "") .. (rows[4][i] or "")
                    local info = {}
                    for col, field in ipairs(fields) do
                        info[field] = rows[col + 4] and rows[col + 4][i]
                    end
                    info.pages = tonumber(info.pages)
                    info.series_index = tonumber(info.series_index)
                    info.cover_w = tonumber(info.cover_w)
                    info.cover_h = tonumber(info.cover_h)
                    current.rows[fp] = info
                end
            end
            if n < current.batch then
                local version = tonumber(current.conn:exec("PRAGMA data_version;")[1][1])
                if version ~= current.version or opts.fingerprint() ~= current.fingerprint then
                    error("BIM changed during metadata refresh")
                end
                cancel()
                request = nil
                M.rows, M.invalidated = current.rows, false
                M.fingerprint = current.fingerprint
                opts.done(current.rows, current.fingerprint)
            else
                ui:scheduleIn(0.02, current.tick)
            end
        end)
        if not success then
            cancel()
            -- Retry on the next visible request, not in a busy/error loop.
            request = nil
            require("logger").warn("[bookshelf] deferred metadata refresh:", err)
        end
    end
    ui:scheduleIn(2, current.tick)
end

function M.request(opts)
    -- Revalidate completed memory after a later library extraction (581),
    -- without restoring upstream's blocking full-table SELECT.
    if M.rows then
        local now = opts.fingerprint()
        if now and now ~= M.fingerprint then M.rows, M.invalidated = nil, true end
    end
    request = opts
    start()
end

function M.setActive(active)
    M.active = active == true
    if M.active then start() else cancel() end
end

function M.invalidate()
    cancel()
    request = nil
    M.rows, M.invalidated, M.fingerprint = nil, true, nil
end

return M
