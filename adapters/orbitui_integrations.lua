-- Settings inspection stays passive. Tag requests below require a user action.
local _ = require("core/orbitui_i18n")
local M = {}
local help = {
    bookorbit = "BookOrbit is optional. Install and connect its KOReader plugin, then choose BookOrbit as a shelf or dashboard source. Library Sync can help match downloaded files. Local books work without it.",
    hardcover = "Hardcover is optional. Configure its API key in the Hardcover module settings, then select it as the dashboard goal source. The local reading goal needs no account.",
    mal = "MyAnimeList is optional. Its separate plugin provides ratings for linked folders and series. Books and series boxes work without ratings.",
}

function M.entries()
    local loader = package.loaded.pluginloader
    local plugins = loader and loader.loaded_plugins or {}
    local ratings = package.loaded.bookshelf_folder_badge_providers
    local key = G_reader_settings and G_reader_settings:readSetting("simpleui_hc_api_key")
    return {
        { name = "BookOrbit", available = plugins.bookorbit ~= nil, text = help.bookorbit },
        { name = "Hardcover", available = type(key) == "string" and key:match("%S") ~= nil, text = help.hardcover },
        { name = "MyAnimeList", available = type(ratings) == "table" and type(ratings.myanimelist) == "function", text = help.mal },
    }
end

function M.items(show)
    local rows = {}
    for _i, entry in ipairs(M.entries()) do
        local text = entry.text
        rows[#rows + 1] = {
            text = entry.name .. ": " .. _(entry.available and "Detected (not connection-tested)" or "Not detected"),
            callback = function()
                if show then return show(_(text)) end
                require("ui/uimanager"):show(require("ui/widget/infomessage"):new{ text = _(text) })
            end,
        }
    end
    return rows
end

local function bookId(raw)
    local id = tonumber(raw)
    if id and id > 0 and id < 9007199254740992 and id == math.floor(id) then return id end
end
local function array(value, limit)
    if type(value) ~= "table" or #value > limit then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > #value or key ~= math.floor(key) then return false end
        count = count + 1
    end
    return count == #value
end

function M.bookOrbitSession()
    local ok, plugin = pcall(require("core/orbitui_context").plugin, "bookorbit")
    if not ok or not plugin or type(plugin.newClient) ~= "function"
            or (plugin.isLoggedIn and not plugin:isLoggedIn()) then return nil, "unavailable" end
    local loaded, manager = pcall(require, "bookorbit_state_manager")
    if not loaded or type(manager.onDeviceMaps) ~= "function" or type(manager.generation) ~= "function"
            or type(manager.setAccount) ~= "function" then
        return nil, "unsupported"
    end
    local created, client = pcall(plugin.newClient, plugin)
    if not created or not client or type(client.runInSubprocess) ~= "function"
            or type(client.canForkSubprocess) ~= "function" or type(client.catalogBook) ~= "function"
            or type(client.query) ~= "function" or type(client.request) ~= "function" then return nil, "unsupported" end
    local generation = manager.generation()
    local session = { client = client }
    function session:current()
        local safe, current = pcall(function()
            if require("core/orbitui_context").plugin("bookorbit") ~= plugin
                    or manager.generation() ~= generation then return false end
            local fresh = plugin:newClient()
            return fresh.server_url == client.server_url and fresh.username == client.username and fresh.userkey == client.userkey
        end)
        return safe and current == true
    end
    local function paths()
        local by_id, ids, candidates, owners = {}, {}, {}, {}
        local fs = require("libs/libkoreader-lfs")
        for raw, path in pairs((manager.onDeviceMaps() or {}).byBookId or {}) do
            local id = bookId(raw)
            if id and type(path) == "string" and path:sub(1, 1) == "/"
                    and fs.attributes(path, "mode") == "file" then
                if candidates[id] == nil then candidates[id] = path
                elseif candidates[id] ~= path then candidates[id] = false end
                if owners[path] == nil then owners[path] = id
                elseif owners[path] ~= id then owners[path] = false end
            end
        end
        for id, path in pairs(candidates) do
            if type(path) == "string" and owners[path] == id then by_id[id] = path; ids[#ids + 1] = id end
        end
        table.sort(ids)
        return by_id, ids
    end
    function session:detail(file)
        local by_id, ids = paths()
        for _, id in ipairs(ids) do
            if by_id[id] == file then
                local detail, err = client:catalogBook(id)
                if not detail then return nil, err == 404 and "not_linked" or err end
                if type(detail) ~= "table" or bookId(detail.id) ~= id or not array(detail.tags, 201) then return nil, "invalid" end
                local tags, seen = {}, {}
                for _, tag in ipairs(detail.tags) do
                    if type(tag) ~= "string" or #tag > 800 or tag == "" or tag:find("%c") then return nil, "invalid" end
                    if not seen[tag] then tags[#tags + 1] = tag; seen[tag] = true end
                    if #tags > 200 then return nil, "too_many_tags" end
                end
                return { tags = tags }
            end
        end
        return nil, "not_linked"
    end
    function session:matches(tag)
        if type(tag) ~= "string" or tag == "" or #tag > 800 or tag:find("%c") then return nil, "invalid" end
        local by_id, ids = paths()
        local found, seen = {}, {}
        for first = 1, #ids, 200 do
            local batch, allowed = {}, {}
            for i = first, math.min(first + 199, #ids) do
                batch[#batch + 1] = tostring(ids[i]); allowed[ids[i]] = true
            end
            local body, err = client:request("GET", client:query("/koreader/plugin/catalog/tag-matches",
                { ids = table.concat(batch, ","), tag = tag }))
            if not body then return nil, err end
            if type(body) ~= "table" or not array(body.bookIds, #batch) then return nil, "invalid" end
            for _, raw in ipairs(body.bookIds) do
                local id = bookId(raw)
                if not id or not allowed[id] then return nil, "invalid" end
                local file = by_id[id]
                if not seen[file] and require("libs/libkoreader-lfs").attributes(file, "mode") == "file" then
                    seen[file] = true; found[#found + 1] = file
                    if #found == 401 then
                        found[#found] = nil
                        return { paths = found, truncated = true }
                    end
                end
            end
        end
        return { paths = found, truncated = false }
    end
    return session
end

local bookOrbitSession = M.bookOrbitSession
function M.bookOrbitSession()
    local ok, value, err = pcall(bookOrbitSession)
    if ok then return value, err end
    return nil, "unavailable"
end

function M.bookOrbitError(err)
    if err == "stale" then return _("The BookOrbit connection or local links changed. Refresh and try again.") end
    if err == 404 or err == "unsupported" then return _("Update BookOrbit to use tag search.") end
    if err == "unavailable" then return _("Install and connect the BookOrbit plugin first.") end
    if err == "not_linked" then return _("This file is not linked to BookOrbit. Match it in BookOrbit first.") end
    if err == "too_many_tags" then return _("This book has too many tags to display here.") end
    return _("Could not load BookOrbit tags. Check the connection and try again.")
end

function M.bookOrbitRequest(session, task, current, done)
    local UI = require("ui/uimanager")
    local function active()
        if not current() then return false end
        if not session:current() then done(nil, "stale"); return false end
        return true
    end
    local function run()
        if not active() then return end
        return require("ui/trapper"):wrap(function()
            if not active() then return end
            if not session.client:canForkSubprocess() then done(nil, "unsupported"); return end
            local progress = require("ui/widget/infomessage"):new{
                text = _("Loading BookOrbit tags… Tap to cancel."), sui_native = true,
                _sui_keep_homescreen = true,
            }
            UI:show(progress)
            UI:forceRePaint()
            local ok, completed, result = pcall(session.client.runInSubprocess, session.client,
                function() return task(session) end, progress)
            if UI:isWidgetShown(progress) then UI:close(progress) end
            if not active() then return end
            if not ok then done(nil, "request_failed")
            elseif not completed then done(nil, "cancelled")
            else done(result and result.body, result and result.err) end
        end)
    end
    local network = require("ui/network/manager")
    if network:willRerunWhenConnected(run) then return end
    UI:nextTick(run)
end

return M
