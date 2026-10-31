-- Settings inspection stays passive. Tag requests below require a user action.
local _ = require("core/orbitui_i18n")
local M = {}
local policy_generation = 0
local policy_keys = {
    enabled = "simpleui_orbitui_bookorbit_enabled",
    want = "simpleui_orbitui_bookorbit_want",
    actions = "simpleui_orbitui_bookorbit_actions",
    tags = "simpleui_orbitui_bookorbit_tags",
}
local function store() return require("infra/sui_store") end
function M.bookOrbitEnabled(feature)
    -- Unset flags preserve existing installations. Never touch BookOrbit's own
    -- credentials, sync preferences, caches or account lifecycle.
    local ok, settings = pcall(store)
    if not ok then return false end
    if settings:readSetting(policy_keys.enabled) == false then return false end
    return not feature or settings:readSetting(assert(policy_keys[feature])) ~= false
end
function M.setBookOrbitEnabled(feature, value)
    store():saveSetting(assert(policy_keys[feature]), value == true)
    policy_generation = policy_generation + 1
    local engine = package.loaded["engines/sui_screen_engine"]
    if engine and engine.markAllStale then engine.markAllStale() end
    local widget = package.loaded["lib/bookshelf_widget"]
    local live = widget and widget.live
    if live and not live._closed then
        if live._cancelChipPreload then live:_cancelChipPreload() end
        live._spine_fetch_cache, live._warmed_chip_keys = nil, nil
        -- Use the existing return hook; never rebuild over settings/a reader.
        live._orbitui_navbar_pending = true
    end
    require("core/orbitui_context").refresh()
    local appearance = package.loaded["adapters/orbitui_appearance"]
    if appearance and appearance.refreshVisible then appearance.refreshVisible() end
end
function M.bookOrbitGuard(feature)
    if not M.bookOrbitEnabled(feature) then return nil end
    local generation = policy_generation
    return function() return generation == policy_generation and M.bookOrbitEnabled(feature) end
end
function M.wantProvider(provider)
    if provider._orbitui_policy then return end
    provider._orbitui_policy = true
    provider.requestGuard = M.bookOrbitGuard
    local cached, auto, id = provider.getCachedFiles, provider.shouldAutoRefreshHome, provider.getBookId
    provider.getCachedFiles = function(...)
        if not M.bookOrbitEnabled("want") then return {} end
        return cached(...)
    end
    provider.shouldAutoRefreshHome = function(...)
        return M.bookOrbitEnabled("want") and auto(...)
    end
    provider.getBookId = function(...)
        if M.bookOrbitEnabled("actions") then return id(...) end
    end
end
function M.wantSnapshot(source)
    if source._orbitui_policy then return end
    source._orbitui_policy = true
    local snapshot = source.snapshot
    source.snapshot = function(...)
        if not M.bookOrbitEnabled("want") then return {}, "orbitui:bookorbit:disabled" end
        return snapshot(...)
    end
end
function M.wantModule(module)
    if module._orbitui_policy then return end
    module._orbitui_policy = true
    module.name, module.label = _("Want to read [BookOrbit]"), _("Want to read [BookOrbit]")
    module._section_label = module.label
    module.getLabel = function(ctx)
        local label = _("Want to read [BookOrbit]")
        if not M.bookOrbitEnabled("want") then label = label .. " · " .. _("Disabled") end
        return require("engines/sui_section_label").makeDescriptor(module.id, label, ctx)
    end
    local menu = module.getMenuItems
    module.getMenuItems = function(ctx)
        local rows = menu(ctx)
        table.insert(rows, 1, { text = _("BookOrbit integration settings"), callback = function()
            require("adapters/orbitui_settings").open("bookorbit")
        end })
        return rows
    end
end
function M.bookOrbitItems(close)
    local function info(text) require("core/orbitui_context").notify(_(text)) end
    local function toggle(feature, label, help_text)
        return { orbitui_id = "bookorbit_" .. feature, text = _(label), help_text = _(help_text),
            checked_func = function() return feature == "enabled" and M.bookOrbitEnabled() or M.bookOrbitEnabled(feature) end,
            enabled_func = function() return feature == "enabled" or M.bookOrbitEnabled() end,
            callback = function()
                if feature ~= "enabled" and not M.bookOrbitEnabled() then return end
                M.setBookOrbitEnabled(feature, not M.bookOrbitEnabled(feature))
                if close then close() end
                require("adapters/orbitui_settings").open("bookorbit")
            end }
    end
    local entries = M.entries()
    local last = tonumber(store():readSetting("simpleui_bookorbit_want_updated_at"))
    if not last or last ~= last or last <= 0 or last > 32503680000 then last = nil end
    local rows = {
        { text = "BookOrbit: " .. _(entries[1].available and "Detected (not connection-tested)" or "Not detected"),
            callback = function() info("Install and connect the separate BookOrbit KOReader plugin. This page never tests a connection automatically. A successful list refresh verifies only that request, not every optional server feature.") end },
        toggle("enabled", "Enable BookOrbit features in OrbitUI", "Controls OrbitUI's BookOrbit lists, menu actions and online tags only. BookOrbit's own reading-progress sync is unchanged. Saved lists, sources and layouts are kept."),
        toggle("want", "Want to read [BookOrbit]", "Shows the BookOrbit Want to Read list, matched to books already on this device. It does not download books. This source needs the connected BookOrbit plugin, not the optional tags or undo server patch."),
        { text = _("Refresh whenever Home opens"), checked_func = function()
                return store():readSetting("simpleui_bookorbit_want_auto_refresh") ~= false end,
            enabled_func = function() return M.bookOrbitEnabled("want") end,
            callback = function()
                if M.bookOrbitEnabled("want") then store():saveSetting("simpleui_bookorbit_want_auto_refresh",
                    store():readSetting("simpleui_bookorbit_want_auto_refresh") == false) end
            end, keep_menu_open = true },
        { text = _("Refresh from BookOrbit now"), enabled_func = function() return M.bookOrbitEnabled("want") end,
            callback = function()
                if not M.bookOrbitEnabled("want") then return end
                require("integrations/sui_bookorbit_want").requestRefresh{ delay = 0, force_local_scan = true,
                    on_done = function(result)
                        if result.ok then require("core/orbitui_context").refresh() end
                        info(result.ok and "BookOrbit list refreshed. Only matched books on this device are shown."
                            or "BookOrbit list could not be refreshed. Check the plugin connection and network, then try again.")
                    end }
                if close then close() end
            end },
        { text = string.format(_("Last successful list refresh: %s"), last and os.date("%Y-%m-%d %H:%M", last) or _("Never")),
            callback = function() info("This timestamp describes the saved list, not the current connection. Disabling BookOrbit keeps its cache but stops OrbitUI from displaying or refreshing it.") end },
        { text = _("Want to read (local, no account)"), callback = function()
            info("Want to read [Local] uses KOReader's local To Be Read collection. Add it through Home (SimpleUI) > Layout & modules, or choose it as a Reading dashboard source. It works offline and stays separate from Want to read [BookOrbit]; disabling BookOrbit never replaces one list with the other.") end },
        toggle("actions", "BookOrbit reading-status menu actions", "Shows OrbitUI's manual Add/Remove Want to Read actions for linked books. These actions DO change BookOrbit's read status (Want to Read / Unread). They are not automatic reading-progress sync."),
        toggle("tags", "Online BookOrbit tags", "Explicitly load tags for a linked book and find matching linked files on this device, across all profiles. Exact online tag matching needs the optional BookOrbit server API patch. Local EPUB tags remain available without BookOrbit or this switch."),
        { text = _("BookOrbit extras: installation & compatibility"), callback = function()
            info("Optional device and server patches are documented at github.com/komadorirobin/bookorbit-extras. Online tag matching requires its server API addition; embedded EPUB tags do not. Undo opening requires both the device patch and a compatible server overlay. The Hardcover single-writer device patch leaves BookOrbit as the automatic writer. OrbitUI does not install, disable or deploy these patches. Do not remove undo support while a protected opening is pending; resolve it with the patch first.") end },
    }
    return rows
end
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
    local guard = M.bookOrbitGuard("tags")
    if not guard then return nil, "disabled" end
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
        if not guard() then return false end
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
        if not self:current() then return nil, "stale" end
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
        if not self:current() then return nil, "stale" end
        if type(tag) ~= "string" or tag == "" or #tag > 800 or tag:find("%c") then return nil, "invalid" end
        local by_id, ids = paths()
        local found, seen = {}, {}
        for first = 1, #ids, 200 do
            if not self:current() then return nil, "stale" end
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
    if err == "disabled" then return _("BookOrbit features are disabled in OrbitUI. Enable online tags in Integrations > BookOrbit.") end
    if err == "stale" then return _("The BookOrbit connection or local links changed. Refresh and try again.") end
    if err == 404 then return _("Online tag matching needs a compatible BookOrbit server API extension. See Integrations > BookOrbit.") end
    if err == "unsupported" then return _("Update BookOrbit to use tag search.") end
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

-- EPUB tags are a local, independent provider. No BookOrbit client, document
-- engine, shell command, cover decoder or account state is involved.
local function xmlText(text)
    return (text:gsub("&([^;]+);", function(entity)
        local named = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }
        if named[entity] then return named[entity] end
        local cp = entity:match("^#x(%x+)$")
        cp = cp and tonumber(cp, 16) or tonumber(entity:match("^#(%d+)$"))
        assert(cp and cp > 0 and cp <= 1114111 and not (cp >= 55296 and cp <= 57343), "invalid XML entity")
        if cp < 128 then return string.char(cp) end
        if cp < 2048 then return string.char(192 + math.floor(cp / 64), 128 + cp % 64) end
        if cp < 65536 then return string.char(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64) end
        return string.char(240 + math.floor(cp / 262144), 128 + math.floor(cp / 4096) % 64,
            128 + math.floor(cp / 64) % 64, 128 + cp % 64)
    end))
end

-- A bounded non-expanding XML reader for OPF/container metadata, not an HTML
-- parser. Comments/CDATA/quoted > and numeric entities cannot create fake meta
-- elements. DTDs and external entities are rejected, never fetched or expanded.
local function xmlElements(text, consume)
    assert(type(text) == "string" and #text <= 1024 * 1024, "invalid XML size")
    local pos, count, roots, stack = 1, 0, 0, {}
    local function content(value, literal)
        if #stack > 0 then
            local top = stack[#stack]
            if top.localname == "meta" then top.text[#top.text + 1] = literal and value or xmlText(value) end
        else assert(not value:find("%S"), "text outside XML root") end
    end
    local function finish(name)
        local node = assert(stack[#stack], "unexpected XML end")
        assert(node.name == name, "mismatched XML end")
        stack[#stack] = nil
        consume(node, stack[#stack])
    end
    text = text:gsub("^\239\187\191", "")
    while pos <= #text do
        local first = text:find("<", pos, true)
        if not first then content(text:sub(pos)); break end
        content(text:sub(pos, first - 1))
        if text:sub(first, first + 3) == "<!--" then
            pos = assert(text:find("-->", first + 4, true), "unterminated XML comment") + 3
        elseif text:sub(first, first + 8) == "<![CDATA[" then
            local last = assert(text:find("]]>", first + 9, true), "unterminated CDATA")
            content(text:sub(first + 9, last - 1), true); pos = last + 3
        elseif text:sub(first, first + 1) == "<?" then
            pos = assert(text:find("?>", first + 2, true), "unterminated XML instruction") + 2
        else
            assert(text:sub(first, first + 1) ~= "<!", "unsupported XML declaration")
            local last, quote = first + 1, nil
            while last <= #text do
                local ch = text:sub(last, last)
                if quote then if ch == quote then quote = nil end
                elseif ch == '"' or ch == "'" then quote = ch
                elseif ch == ">" then break end
                last = last + 1
            end
            assert(last <= #text and not quote, "unterminated XML element")
            local body = text:sub(first + 1, last - 1)
            local ending = body:match("^/([%a_][%w_.:%-]*)%s*$")
            if ending then finish(ending)
            else
                local name, rest = body:match("^([%a_][%w_.:%-]*)(.*)$")
                assert(name, "invalid XML name")
                local empty = rest:match("/%s*$") ~= nil
                if empty then rest = rest:gsub("/%s*$", "") end
                local attrs, n = {}, 0
                while rest:find("%S") do
                    local key, delimiter, tail = rest:match("^%s+([%a_][%w_.:%-]*)%s*=%s*(['\"])(.*)$")
                    assert(key and attrs[key] == nil and n < 128, "invalid XML attribute")
                    local stop = assert(tail:find(delimiter, 1, true), "unterminated XML attribute")
                    attrs[key] = xmlText(tail:sub(1, stop - 1))
                    rest, n = tail:sub(stop + 1), n + 1
                end
                count = count + 1
                assert(count <= 20000 and #stack < 64, "XML complexity limit")
                if #stack == 0 then roots = roots + 1; assert(roots == 1, "multiple XML roots") end
                stack[#stack + 1] = { name = name, localname = name:match("([^:]+)$"), attrs = attrs, text = {}, depth = #stack + 1 }
                if empty then finish(name) end
            end
            pos = last + 1
        end
    end
    assert(#stack == 0 and roots == 1, "incomplete XML")
end

function M.embeddedTagsFromOpf(opf)
    local tags, seen, metadata = {}, {}, false
    local ok = pcall(xmlElements, opf, function(node, parent)
        if node.depth == 2 and node.localname == "metadata" and parent and parent.localname == "package" then metadata = true end
        if node.depth ~= 3 or node.localname ~= "meta" or not parent or parent.localname ~= "metadata" then return end
        local key = node.attrs.property or node.attrs.name
        if key ~= "bookorbit:tags" then return end
        local json = node.attrs.content or table.concat(node.text)
        assert(json:match("^%s*%["), "tags must be a JSON array")
        local values = require("rapidjson").decode(json)
        assert(array(values, 200), "invalid tags array")
        for _, tag in ipairs(values) do
            assert(type(tag) == "string" and #tag <= 800 and tag:find("%S") and not tag:find("%c"), "invalid tag")
            if not seen[tag] then tags[#tags + 1] = tag; seen[tag] = true end
            assert(#tags <= 200, "too many tags")
        end
    end)
    if not ok or not metadata then return nil, "invalid_epub" end
    return tags
end

local function epubMetadata(file)
    local reader = require("ffi/archiver").Reader:new()
    local ok, result = pcall(function()
        assert(reader:open(file), "EPUB open failed")
        local seen, count = {}, 0
        for entry in reader:iterate() do
            count = count + 1
            assert(count <= 20000 and not seen[entry.path], "invalid EPUB entries")
            seen[entry.path] = true
        end
        assert(not reader.err, "EPUB listing failed")
        local function read(path, limit)
            local entry = assert(reader.entries[path], "missing EPUB metadata")
            local size = tonumber(entry.size)
            assert(entry.mode == "file" and size and size >= 0 and size <= limit, "EPUB metadata size limit")
            local data = assert(reader:extractToMemory(path), "EPUB metadata read failed")
            assert(#data == size, "short EPUB metadata read")
            return data
        end
        local path
        xmlElements(read("META-INF/container.xml", 128 * 1024), function(node, parent)
            if node.localname == "rootfile" and parent and parent.localname == "rootfiles"
                    and (not node.attrs["media-type"] or node.attrs["media-type"] == "application/oebps-package+xml") then
                assert(not path, "ambiguous EPUB rootfile"); path = node.attrs["full-path"]
            end
        end)
        assert(type(path) == "string" and #path <= 1024 and path:sub(1, 1) ~= "/" and not path:find("[%c\\]"), "invalid OPF path")
        for part in path:gmatch("[^/]+") do assert(part ~= ".." and part ~= ".", "invalid OPF path") end
        return assert(M.embeddedTagsFromOpf(read(path, 1024 * 1024)))
    end)
    pcall(reader.close, reader)
    if ok then return result end
    return nil, "invalid_epub"
end

local tag_disk
function M.embeddedTags(file, refresh)
    local fs = require("libs/libkoreader-lfs")
    local attrs = type(file) == "string" and file:sub(1, 1) == "/" and fs.attributes(file)
    if not attrs or attrs.mode ~= "file" then return nil, "missing" end
    if not file:lower():match("%.epub$") then return nil, "not_epub" end
    tag_disk = tag_disk or require("lib/bookshelf_keyed_cache").new("orbitui_epub_tags", 1)
    local stamp = tostring(attrs.modification) .. ":" .. tostring(attrs.change) .. ":" .. tostring(attrs.size)
    if not refresh then
        local cached = tag_disk.read(file)
        if cached and cached.stamp == stamp and array(cached.tags, 200) then
            local valid = true
            for _, tag in ipairs(cached.tags) do
                if type(tag) ~= "string" or #tag > 800 or not tag:find("%S") or tag:find("%c") then valid = false; break end
            end
            if valid then return cached.tags end
        end
    end
    local ok, tags, err = pcall(epubMetadata, file)
    if not ok or not tags then return nil, err or "invalid_epub" end
    local after = fs.attributes(file)
    if not after or after.size ~= attrs.size or after.modification ~= attrs.modification or after.change ~= attrs.change then
        return nil, "changed"
    end
    tag_disk.write(file, { stamp = stamp, tags = tags })
    return tags
end

local embeddedTags = M.embeddedTags
function M.embeddedTags(...)
    local ok, tags, err = pcall(embeddedTags, ...)
    if ok then return tags, err end
    return nil, "invalid_epub"
end

function M.embeddedTagError(err)
    if err == "not_epub" then return _("Embedded tags are available for EPUB files. Genres and collections remain below.") end
    return _("Could not read EPUB tags. The file may be unavailable, damaged or too large to inspect safely. Try Refresh.")
end

local function libraryIdentity()
    local parts = { tostring(G_reader_settings and G_reader_settings:readSetting("home_dir")) }
    parts[#parts + 1] = tostring(require("lib/bookshelf_settings_store").read("latest_walk_depth"))
    for _, profile in ipairs(require("lib/bookshelf_profiles").list()) do
        parts[#parts + 1] = profile.key
        for _, path in ipairs(profile.roots or {}) do parts[#parts + 1] = path end
    end
    return table.concat(parts, "\0")
end
function M.embeddedTagSession()
    local identity = libraryIdentity()
    local source = { embedded = true }
    function source:current()
        local ok, value = pcall(libraryIdentity)
        return ok and value == identity
    end
    return source
end

-- One bounded metadata archive per event-loop turn, also on Android. Avoid
-- forked crengine/SQLite workers and leave Cancel/Back/touch processing live.
function M.embeddedTagRequest(source, task, current, done)
    local UI = require("ui/uimanager")
    local progress = require("ui/widget/infomessage"):new{
        text = _("Reading EPUB tags… Tap to cancel."), sui_native = true, _sui_keep_homescreen = true,
    }
    local cancelled, finished = false, false
    progress.dismiss_callback = function() cancelled = true end
    local function finish(body, err)
        if finished then return end
        finished = true
        if UI:isWidgetShown(progress) then UI:close(progress) end
        if current() then done(body, err) end
    end
    local files, cursor, paths, skipped, truncated = nil, 1, {}, 0, false
    local function step()
        if not current() then finish(); return end
        if cancelled or not UI:isWidgetShown(progress) then finish(nil, "cancelled"); return end
        if source and not source:current() then finish(nil, "stale"); return end
        if not files then
            local ok, value = pcall(function()
                if task.file then return { task.file } end
                local Repo, Profiles = require("lib/bookshelf_book_repository"), require("lib/bookshelf_profiles")
                local out, seen = {}, {}
                local function add(scope)
                    for _, file in ipairs(Repo.getAllFilepaths(scope)) do
                        if type(file) == "string" and file:sub(1, 1) == "/" and file:lower():match("%.epub$") and not seen[file] then
                            seen[file] = true; out[#out + 1] = file
                        end
                    end
                end
                add(nil)
                for _, profile in ipairs(Profiles.list()) do add(Profiles.scope(profile)) end
                table.sort(out)
                -- The clicked book may sit outside the configured roots.
                if task.origin and not seen[task.origin] then out[#out + 1] = task.origin end
                return out
            end)
            if not ok then finish(nil, "invalid_epub"); return end
            files = value
        end
        local file = files[cursor]
        if not file then finish({ paths = paths, skipped = skipped, truncated = truncated }); return end
        local tags, err = M.embeddedTags(file, task.refresh)
        if task.file then finish(tags and { tags = tags } or nil, err); return end
        if not tags then skipped = skipped + 1
        else
            for _, tag in ipairs(tags) do
                if tag == task.tag then
                    if #paths == 400 then truncated = true; finish({ paths = paths, skipped = skipped, truncated = true }); return end
                    paths[#paths + 1] = file; break
                end
            end
        end
        cursor = cursor + 1
        UI:scheduleIn(0.01, step)
    end
    UI:show(progress)
    UI:nextTick(step)
end

return M
