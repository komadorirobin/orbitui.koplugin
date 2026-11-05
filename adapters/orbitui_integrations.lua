-- Settings inspection stays passive. Online tags require a user action;
-- reading-status checks additionally require the explicit opt-in below.
local _ = require("core/orbitui_i18n")
local M = {}
local policy_generation = 0
local policy_keys = {
    enabled = "simpleui_orbitui_bookorbit_enabled",
    want = "simpleui_orbitui_bookorbit_want",
    actions = "simpleui_orbitui_bookorbit_actions",
    tags = "simpleui_orbitui_bookorbit_tags",
    status = "simpleui_orbitui_bookorbit_status",
}
local function store() return require("infra/sui_store") end
function M.bookOrbitEnabled(feature)
    -- Unset flags preserve existing installations. Never touch BookOrbit's own
    -- credentials, sync preferences, caches or account lifecycle.
    local ok, settings = pcall(store)
    if not ok then return false end
    if settings:readSetting(policy_keys.enabled) == false then return false end
    if feature == "status" then return settings:readSetting(policy_keys.status) == true end
    return not feature or settings:readSetting(assert(policy_keys[feature])) ~= false
end
function M.setBookOrbitEnabled(feature, value)
    store():saveSetting(assert(policy_keys[feature]), value == true)
    policy_generation = policy_generation + 1
    if M.statusImport then M.statusImport.policyChanged() end
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
        toggle("enabled", "Enable BookOrbit features in OrbitUI", "Controls OrbitUI's BookOrbit lists, menu actions, online tags and optional status import only. BookOrbit's own reading-progress sync is unchanged. Saved lists, sources and layouts are kept."),
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
            info("Optional device and server patches are documented at github.com/komadorirobin/bookorbit-extras. Online tag matching requires its server API addition; embedded EPUB tags do not. Undo opening requires both the device patch and a compatible server extension. The reviewed BookOrbit 3.6.0 source package supports tags and undo together; never use the old 3.2.0 overlay on a newer server. The Hardcover single-writer device patch leaves BookOrbit as the automatic writer. OrbitUI does not install, disable or deploy these patches. Do not remove undo support while a protected opening is pending; resolve it with the patch first.") end },
    }
    rows[#rows + 1] = { text = _("Import reading status from BookOrbit…"), callback = function()
        if close then close() end
        M.statusImport.showSettings()
    end }
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
local index_failed = false
local snapshot_revision
local run_serial = 0
local function tagCache()
    tag_disk = tag_disk or require("lib/bookshelf_keyed_cache").new("orbitui_epub_tags", 1)
    return tag_disk
end
local function tagRun()
    run_serial = run_serial + 1
    return tostring(os.time()) .. ":" .. tostring(require("ui/time").now()) .. ":"
        .. tostring(math.random(1, 1073741824)) .. ":" .. run_serial
end
function M.embeddedTagSnapshotRevision()
    if snapshot_revision == nil then
        local value = tagCache().read("shelf_revision_v1")
        snapshot_revision = value and type(value.value) == "string" and value.value or "0"
    end
    return snapshot_revision
end
function M.invalidateEmbeddedTagSnapshots()
    snapshot_revision = tagRun()
    tagCache().write("shelf_revision_v1", { value = snapshot_revision })
end
-- Literal EPUB tags, never the native collection/genre filter language.
-- A compact bounded rule is shared by saved chips and the explicit search.
function M.embeddedTagRule(value)
    if type(value) == "string" then value = { version = 1, mode = "all", tags = { value } } end
    if type(value) ~= "table" or value.version ~= 1 or (value.mode ~= "all" and value.mode ~= "any")
            or not array(value.tags, 16) or #value.tags == 0 then return nil end
    local tags, seen = {}, {}
    for _, tag in ipairs(value.tags) do
        if type(tag) ~= "string" or #tag > 800 or not tag:find("%S") or tag:find("%c") then return nil end
        if not seen[tag] then tags[#tags + 1] = tag; seen[tag] = true end
    end
    table.sort(tags)
    return { version = 1, mode = value.mode, tags = tags }
end

function M.embeddedTagMatches(tags, rule)
    rule = M.embeddedTagRule(rule)
    if not rule or not tags then return false end
    local set = {}; for _, tag in ipairs(tags) do set[tag] = true end
    for _, tag in ipairs(rule.tags) do
        if rule.mode == "all" and not set[tag] then return false end
        if rule.mode == "any" and set[tag] then return true end
    end
    return rule.mode == "all"
end

function M.embeddedTagSnapshot(key, value)
    tag_disk = tag_disk or require("lib/bookshelf_keyed_cache").new("orbitui_epub_tags", 1)
    if value then return tag_disk.write("shelf_v1:" .. key, value) end
    return tag_disk.read("shelf_v1:" .. key)
end

local function tagStamp(attrs)
    if attrs and attrs.mode == "file" then
        return tostring(attrs.modification) .. ":" .. tostring(attrs.change) .. ":" .. tostring(attrs.size)
    end
end

-- Derived, disposable data ONLY, never BIM/reading/settings databases. Open on
-- explicit tag actions, not paint/startup. Bound reads and writes; SQLite faults
-- fall back to the authoritative per-EPUB path without deleting any cache.
function M.openEmbeddedTagIndex(existing_only)
    if index_failed then return nil end
    local db, epoch
    local ok = pcall(function()
        local dir = require("datastorage"):getDataDir() .. "/cache"
        local fs = require("libs/libkoreader-lfs")
        local path = dir .. "/bookshelf/orbitui_epub_tag_index_v1.sqlite3"
        if existing_only and fs.attributes(path, "mode") ~= "file" then return end
        pcall(fs.mkdir, dir); pcall(fs.mkdir, dir .. "/bookshelf")
        db = require("lua-ljsqlite3/init").open(path)
        tag_disk = tag_disk or require("lib/bookshelf_keyed_cache").new("orbitui_epub_tags", 1)
        db:exec("PRAGMA busy_timeout=25; PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")
        db:exec([[CREATE TABLE IF NOT EXISTS files (fp TEXT PRIMARY KEY, stamp TEXT NOT NULL, epoch INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS tags (fp TEXT NOT NULL, tag TEXT COLLATE BINARY NOT NULL, PRIMARY KEY(fp,tag));
            CREATE INDEX IF NOT EXISTS tags_by_name ON tags(tag,fp);]])
        local marker = tag_disk.read("index_epoch_v1")
        epoch = marker and marker.epoch
        if type(epoch) ~= "number" or epoch < 1 or epoch >= 4503599627370496 or epoch % 1 ~= 0 then
            -- Missing/corrupt marker never revives an older generation.
            epoch = tonumber(db:rowexec("SELECT COALESCE(MAX(epoch),0)+1 FROM files"))
            assert(epoch and epoch < 4503599627370496)
            assert(tag_disk.write("index_epoch_v1", { epoch = epoch }))
        end
    end)
    if not ok then if db then pcall(db.close, db) end; return nil end
    if not db then return nil end
    local pending, count = {}, 0
    local store = {}
    local function failed()
        index_failed = true
        -- A fault must not revive stale same-stamp rows after restart. Advance
        -- the tiny independent epoch marker; old index rows become misses, not
        -- a deleted/recreated DB. The per-file cache remains available.
        pcall(tag_disk.write, "index_epoch_v1", { epoch = epoch + 1 })
        if db then pcall(db.exec, db, "ROLLBACK;"); pcall(db.close, db); db = nil end
        return nil
    end
    function store.prefetch(files, first, tag)
        if not db or index_failed then return nil end
        local rule = tag ~= nil and M.embeddedTagRule(tag)
        if tag ~= nil and not rule then return nil end
        local ok_read, out = pcall(function()
            local marks, args, predicates = {}, {}, {}
            for _, name in ipairs(rule and rule.tags or {}) do
                predicates[#predicates + 1] = "EXISTS(SELECT 1 FROM tags t WHERE t.fp=f.fp AND t.tag=?)"
                args[#args + 1] = name
            end
            args[#args + 1] = epoch
            for i = first, math.min(first + 127, #files) do
                marks[#marks + 1] = "?"; args[#args + 1] = files[i]
            end
            local expression = rule and table.concat(predicates, rule.mode == "all" and " AND " or " OR ") or "0"
            local stmt = db:prepare("SELECT f.fp,f.stamp,(" .. expression .. ") "
                .. "FROM files f WHERE f.epoch=? AND f.fp IN (" .. table.concat(marks, ",") .. ")")
            local unpack_fn = unpack or table.unpack
            stmt:bind(unpack_fn(args))
            local rows, row = {}, stmt:step()
            while row do
                assert(type(row[1]) == "string" and type(row[2]) == "string")
                local match = tonumber(row[3]); assert(match == 0 or match == 1)
                rows[row[1]] = { stamp = row[2], matches = match == 1 }
                row = stmt:step()
            end
            stmt:close()
            return rows
        end)
        if not ok_read then return failed() end
        return out
    end
    function store.put(file, stamp, tags)
        if not db or index_failed then return end
        if pending[file] == nil then count = count + 1 end
        pending[file] = { stamp = stamp, tags = tags }
    end
    function store.flush()
        if not db or index_failed then return false end
        if count == 0 then return true end
        local ok_write = pcall(function()
            db:exec("BEGIN IMMEDIATE;")
            local remove = db:prepare("DELETE FROM tags WHERE fp=?")
            local put = db:prepare("INSERT OR REPLACE INTO files(fp,stamp,epoch) VALUES(?,?,?)")
            local add = db:prepare("INSERT OR IGNORE INTO tags(fp,tag) VALUES(?,?)")
            for file, entry in pairs(pending) do
                remove:reset():bind(file):step()
                put:reset():bind(file, entry.stamp, epoch):step()
                for _, tag in ipairs(entry.tags) do add:reset():bind(file, tag):step() end
            end
            remove:close(); put:close(); add:close()
            db:exec("COMMIT;")
        end)
        if not ok_write then failed(); return false end
        pending, count = {}, 0
        return true
    end
    function store.close()
        local saved = store.flush()
        if db then pcall(db.close, db); db = nil end
        return saved
    end
    return store
end

function M.embeddedTags(file, refresh, defer_index, cache_only, run, durable)
    local fs = require("libs/libkoreader-lfs")
    local attrs = type(file) == "string" and file:sub(1, 1) == "/" and fs.attributes(file)
    if not attrs or attrs.mode ~= "file" then return nil, "missing" end
    if not file:lower():match("%.epub$") then return nil, "not_epub" end
    tag_disk = tag_disk or require("lib/bookshelf_keyed_cache").new("orbitui_epub_tags", 1)
    local stamp = tagStamp(attrs)
    if not refresh or run then
        local cached = tag_disk.read(file)
        if cached and (not refresh or cached.reread_run == run) and cached.stamp == stamp and array(cached.tags, 200) then
            local valid = true
            for _, tag in ipairs(cached.tags) do
                if type(tag) ~= "string" or #tag > 800 or not tag:find("%S") or tag:find("%c") then valid = false; break end
            end
            if valid then return cached.tags, nil, true, stamp end
        end
    end
    if cache_only then return nil, "unindexed", true end
    local ok, tags, err = pcall(epubMetadata, file)
    if not ok or not tags then return nil, err or "invalid_epub" end
    local after = fs.attributes(file)
    if not after or after.size ~= attrs.size or after.modification ~= attrs.modification or after.change ~= attrs.change then
        return nil, "changed"
    end
    local saved = tag_disk.write(file, { stamp = stamp, tags = tags, reread_run = run })
    if durable and saved == false then return nil, "cache_write" end
    if not defer_index then
        local index = M.openEmbeddedTagIndex(true)
        if index then index.put(file, stamp, tags); index.close() end
        M.invalidateEmbeddedTagSnapshots()
    end
    return tags, nil, false, stamp
end

local embeddedTags = M.embeddedTags
function M.embeddedTags(...)
    local ok, tags, err, cached, stamp = pcall(embeddedTags, ...)
    if ok then return tags, err, cached, stamp end
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
    local source = { embedded = true, identity = identity }
    function source:current()
        local ok, value = pcall(libraryIdentity)
        return ok and value == identity
    end
    return source
end

-- Cache hits share a bounded 8ms/32-entry turn; at most one metadata archive
-- attempt per turn, also on Android. No forked crengine/SQLite worker. A small
-- positive delay yields to input even on native queues that drain due tasks.
function M.embeddedTagRequest(source, task, current, done)
    local UI = require("ui/uimanager")
    local time = require("ui/time")
    local inline = type(task.on_progress) == "function" and not task.file
    local progress = not inline and require("ui/widget/infomessage"):new{
        text = _("Reading EPUB tags… Tap to cancel."), sui_native = true, _sui_keep_homescreen = true,
    }
    local cancelled, finished = false, false
    local files, cursor, paths, skipped, truncated = nil, 1, {}, 0, false
    local rule = not task.file and not task.index_only and M.embeddedTagRule(task.rule or task.tag)
    local stamps, unindexed = {}, 0
    local reread, reused = 0, 0
    local index, indexed, index_end, pending = nil, {}, 0, 0
    local last_update, last_flush, last_matches = time.now(), time.now(), 0
    local function snapshot()
        local out = {}; for i, file in ipairs(paths) do out[i] = file end
        local copied = {}; for file, stamp in pairs(stamps) do copied[file] = stamp end
        return { paths = out, stamps = copied, unindexed = unindexed, skipped = skipped, truncated = truncated,
            reread = reread, reused = reused,
            scanned = cursor - 1, total = files and #files or 0,
            complete = files ~= nil and cursor > #files and not truncated and unindexed == 0 }
    end
    local function finish(body, err)
        if finished then return end
        finished = true
        if index then index.close(); index = nil end
        if progress and UI:isWidgetShown(progress) then UI:close(progress) end
        if current() then done(body, err)
        elseif task.on_retired then task.on_retired() end
    end
    local control = { cancel = function()
        cancelled = true
        finish(inline and snapshot() or nil, "cancelled")
    end }
    if progress then progress.dismiss_callback = control.cancel end
    local function step()
        if finished then return end
        if not current() then finish(); return end
        if cancelled or progress and not UI:isWidgetShown(progress) then control.cancel(); return end
        if source and not source:current() then finish(nil, "stale"); return end
        if not task.file and not task.index_only and not rule then finish(nil, "invalid_epub"); return end
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
                if task.profile then
                    local profile = assert(Profiles.get(task.profile), "missing library")
                    add(Profiles.scope(profile))
                else
                    add(nil)
                    for _, profile in ipairs(Profiles.list()) do add(Profiles.scope(profile)) end
                end
                table.sort(out)
                -- Validate the clicked book first so an initial result need
                -- not wait for unrelated archives. Still scan ALL profiles.
                if not task.profile and type(task.origin) == "string" and task.origin:sub(1, 1) == "/" and task.origin:lower():match("%.epub$") then
                    if seen[task.origin] then
                        for i, file in ipairs(out) do if file == task.origin then table.remove(out, i); break end end
                    end
                    table.insert(out, 1, task.origin)
                end
                return out
            end)
            if not ok then finish(nil, "invalid_epub"); return end
            files = value
            -- Ephemeral shared inventory for optional series discovery. Never
            -- serialize it into tag snapshots or widen the tag predicate.
            if source and not task.file then source.inventory = files end
            if not task.file then index = M.openEmbeddedTagIndex() end
        end
        local start = time.now()
        for _i = 1, 32 do
            local file = files[cursor]
            if not file then finish(snapshot()); return end
            if index and index_failed then index.close(); index, indexed = nil, {} end
            if index and not task.refresh and cursor > index_end then
                indexed = index.prefetch(files, cursor, not task.index_only and (task.rule or task.tag) or nil)
                index_end = cursor + 127
                if not indexed then index.close(); index, indexed = nil, {} end
            end
            local hit = indexed[file]
            if hit and tagStamp(require("libs/libkoreader-lfs").attributes(file)) ~= hit.stamp then hit = nil end
            local tags, err, cached, stamp
            if hit and not task.refresh then
                tags, cached, stamp = not task.index_only and hit.matches and rule.tags or {}, true, hit.stamp
            else
                tags, err, cached, stamp = M.embeddedTags(file, task.refresh, not task.file, task.cache_only, task.run, task.index_only)
                if index and tags then index.put(file, stamp, tags); pending = pending + 1 end
            end
            if task.file then finish(tags and { tags = tags } or nil, err); return end
            if not tags then
                if err == "unindexed" then unindexed = unindexed + 1 else skipped = skipped + 1 end
            elseif not task.index_only and M.embeddedTagMatches(tags, rule) then
                if #paths == 400 then truncated = true; finish(snapshot()); return end
                paths[#paths + 1], stamps[file] = file, stamp
            end
            if tags then
                if cached then reused = reused + 1 else reread = reread + 1 end
            end
            cursor = cursor + 1
            if not cached or time.to_us(time.since(start)) >= 8000 then break end
        end
        if index and (pending >= 32 or time.to_us(time.since(last_flush)) >= 1000000) then
            if not index.flush() then index.close(); index, indexed = nil, {} end
            pending, last_flush = 0, time.now()
        end
        local painted = false
        if inline and (last_matches == 0 and #paths > 0 or time.to_us(time.since(last_update)) >= 250000) then
            task.on_progress(snapshot())
            -- Native handleInput repeats _checkTasks after a repaint dirties
            -- its task queue. If painting outlasts the 1ms next-step timer,
            -- that loop never polls touch. Drain paint BEFORE starting it.
            UI:forceRePaint()
            painted = true
            last_update, last_matches = time.now(), #paths
        end
        -- Android's frame bookkeeping can itself outlast 1ms even after
        -- forceRePaint. Reserve an input window after visible updates only;
        -- ordinary cached batches keep their short continuation.
        UI:scheduleIn(painted and 0.05 or 0.001, step)
    end
    if progress then UI:show(progress) end
    UI:nextTick(step)
    return control
end

local active_index
local function readIndexJob()
    local value = tagCache().read("index_job_v1")
    if value == nil then return nil end
    if type(value) ~= "table" or value.version ~= 1 or type(value.run) ~= "string" or #value.run > 160
            or not value.run:find("%S") or value.run:find("%c") or type(value.identity) ~= "string"
            or (value.mode ~= "update" and value.mode ~= "reread")
            or not ({ running = true, paused = true, complete = true, errors = true })[value.phase] then return nil, "invalid_job" end
    for _i, key in ipairs{ "scanned", "total", "skipped", "reread", "reused" } do
        local n = value[key]
        if type(n) ~= "number" or n < 0 or n > 10000000 or n % 1 ~= 0 then return nil, "invalid_job" end
    end
    return value
end
function M.embeddedTagIndexStatus()
    local value, err = readIndexJob()
    if not value then return nil, err end
    local out = {}; for key, field in pairs(value) do out[key] = field end
    out.current_scope = value.identity == libraryIdentity()
    if out.phase == "running" and not active_index then out.phase = "paused" end
    return out
end

-- One explicit all-library job, never limited by a tag or its result cap.
-- The journal contains only scalar progress/identity. Per-file reread markers
-- in the existing derived cache survive restart; resume still validates stamps.
function M.startEmbeddedTagIndex(mode, resume, current, changed, replace_invalid)
    local previous, failure = readIndexJob()
    if failure and not replace_invalid then return nil, failure end
    if active_index then return nil, "busy" end
    local source = M.embeddedTagSession()
    local job
    if resume then
        if not previous or previous.phase == "complete" or previous.identity ~= source.identity then return nil, "stale" end
        job = previous
    else
        if mode ~= "update" and mode ~= "reread" then return nil, "invalid_job" end
        job = { version = 1, mode = mode, run = tagRun(), identity = source.identity }
    end
    job.phase = "running"
    for _i, key in ipairs{ "scanned", "total", "skipped", "reread", "reused" } do job[key] = 0 end
    if tagCache().write("index_job_v1", job) == false then return nil, "journal_failed" end
    M.invalidateEmbeddedTagSnapshots()
    local controller, retired, journal_error = {}, false, false
    active_index = controller
    local function save(result, phase)
        if result then
            for _i, key in ipairs{ "scanned", "total", "skipped", "reread", "reused" } do job[key] = result[key] or 0 end
        end
        job.phase = phase
        return tagCache().write("index_job_v1", job) ~= false
    end
    local function retire(err)
        if retired then return end
        retired, active_index = true, nil
        local saved = save(nil, "paused")
        M.invalidateEmbeddedTagSnapshots()
        -- Release controls even after work ownership expires. The recipient
        -- may clear busy/Close state, but must not adopt stale running work.
        changed(M.embeddedTagIndexStatus(), saved and err or "journal_failed")
    end
    local function valid()
        if retired then return false end
        if not current() then retire("cancelled"); return false end
        if not source:current() then retire("stale"); return false end
        return true
    end
    controller.worker = M.embeddedTagRequest(source, { index_only = true, refresh = job.mode == "reread",
        run = job.mode == "reread" and job.run or nil,
        on_progress = function(result)
            if not valid() then return end
            if not save(result, "running") then
                journal_error = true
                controller.worker.cancel()
                return
            end
            changed(M.embeddedTagIndexStatus())
        end,
    }, valid, function(result, err)
        if retired then return end
        local phase = err == "cancelled" and "paused" or result and result.complete
            and (result.skipped == 0 and "complete" or "errors") or "paused"
        local saved = save(result, phase)
        retired, active_index = true, nil
        M.invalidateEmbeddedTagSnapshots()
        if journal_error or not saved then err = "journal_failed" end
        changed(M.embeddedTagIndexStatus(), err)
    end)
    function controller.cancel() if not retired then controller.worker.cancel() end end
    return controller
end

-- Optional status import. Reuse this installed path; API-1 has no spare paths.
-- The worker performs GETs/reads only. Sidecar publication belongs to the UI
-- process, in small slices, never to a fork that can outlive cancellation.
do
    local S = {}; M.statusImport = S
    local RESULT = "simpleui_orbitui_bookorbit_status_result"
    local ATTEMPT = "simpleui_orbitui_bookorbit_status_attempt"
    local INTERVAL, BATCH = 15 * 60, 200
    local owners = setmetatable({}, { __mode = "k" })
    local timer, busy, epoch, sleeping = nil, nil, 0, false
    local statuses = { read = "complete", skimmed = "complete", reading = "reading",
        rereading = "reading", on_hold = "abandoned", abandoned = "abandoned" }
    -- Reporting only: preserve the decision order and the no-sidecar-I/O fast
    -- path. Worker reports cross the fork boundary as bounded return values.
    local SAMPLE_LIMIT = 50
    local reasons = {
        { "updated", "updated", "Updated" },
        { "server_unchanged", "unchanged", "Unchanged server status (local data not read)" },
        { "local_unchanged", "unchanged", "Already the same local status" },
        { "missing_file", "missing", "Local book file not found" },
        { "missing_data", "missing", "Local reading data not found or unreadable" },
        { "unsafe_sidecar", "protected", "Unsafe or competing reading-data files" },
        { "identity_mismatch", "protected", "Local book identity could not be verified" },
        { "active_reader", "protected", "Book open in the reader" },
        { "pending_undo", "protected", "Pending Undo or uncertain opening state" },
        { "file_changed", "protected", "Book file changed during the check" },
        { "local_changed", "protected", "Local reading data changed during the check" },
        { "newer_local", "conflict", "Newer local status" },
        { "uncertain_date", "protected", "Uncertain or missing local status date" },
        { "neutral", "ignored", "Unread / Want to read is not imported" },
        { "server_missing", "ignored", "No status returned by the server" },
    }
    local reason_by_code = {}; for _, row in ipairs(reasons) do reason_by_code[row[1]] = row end
    local function newReport()
        local counts = {}; for _, row in ipairs(reasons) do counts[row[1]] = 0 end
        return { counts = counts, details = {} }
    end
    local function record(report, code, file)
        local row = assert(reason_by_code[code])
        report.counts[code] = report.counts[code] + 1
        if (row[2] == "missing" or row[2] == "protected" or row[2] == "conflict")
                and #report.details < SAMPLE_LIMIT then
            local name = (file:match("([^/]+)$") or "…"):gsub("[%c]", " ")
            -- Bound bytes without leaving a cut UTF-8 sequence at the end.
            if #name > 160 then name = name:sub(1, 160):gsub("[\194-\244][\128-\191]*$", "") .. "…" end
            report.details[#report.details + 1] = { name = name, reason = code }
        end
    end
    local function totals(counts)
        local out = { updated = 0, unchanged = 0, missing = 0, protected = 0, conflict = 0, ignored = 0 }
        for _, row in ipairs(reasons) do out[row[2]] = out[row[2]] + counts[row[1]] end
        out.skipped = out.missing + out.protected + out.conflict
        return out
    end
    local function validCounts(result)
        if result.report_version ~= 1 or type(result.counts) ~= "table" then return end
        local sum = 0
        for _, row in ipairs(reasons) do
            local n = result.counts[row[1]]
            if type(n) ~= "number" or n ~= n or n < 0 or n > 50000 or n % 1 ~= 0 then return end
            sum = sum + n
        end
        if sum > 50000 then return end
        local t = totals(result.counts)
        if t.updated ~= result.changed or t.skipped ~= result.skipped then return end
        return t
    end
    function S.summary(result)
        local t = validCounts(result)
        if t then return string.format(_("Reading status: %d updated, %d unchanged, %d skipped."), t.updated, t.unchanged, t.skipped) end
        -- Older saved results cannot be retrospectively split into reasons.
        local function count(n) return type(n) == "number" and n == n and n >= 0 and n <= 50000 and math.floor(n) or 0 end
        return string.format(_("Reading status: %d updated, %d skipped. Run a new check for reasons."), count(result.changed), count(result.skipped))
    end
    local function UI() return require("ui/uimanager") end
    local function identity(client)
        if not client or type(client.server_url) ~= "string" or type(client.username) ~= "string"
                or type(client.userkey) ~= "string" then return end
        return require("ffi/sha2").sha256(client.server_url .. "\n" .. client.username .. "\n" .. client.userkey)
    end
    local function activeFile(file)
        local reader = package.loaded["apps/reader/readerui"]
        local live = reader and reader.instance
        return live and live.document and live.document.file == file
    end
    local function protected(file)
        local all = G_reader_settings and G_reader_settings:readSetting("bookorbit_openings")
        if all == nil then return false end
        if type(all) ~= "table" then return true end
        for _, account in pairs(all) do
            if type(account) ~= "table" then return true end
            local row = account.opening
            if row and (type(row) ~= "table" or (row.file == file and row.phase ~= "done" and row.phase ~= "undone")) then return true end
        end
        return false
    end
    local function visible()
        if sleeping then return false end
        local top = UI():getTopmostVisibleWidget()
        return top and (top.name == "homescreen" or top.name == "bookshelf")
    end
    local function idle(plugin)
        if type(plugin.getSyncCoordinatorStatus) ~= "function" then return false end
        local status = plugin:getSyncCoordinatorStatus()
        return type(status) == "table" and not status.current and (status.pending_count or 0) == 0
    end
    local function day(value)
        if type(value) ~= "string" then return end
        local y, m, d = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
        y, m, d = tonumber(y), tonumber(m), tonumber(d)
        if not y or y < 1970 or y > 2100 or m < 1 or m > 12 or d < 1 or d > 31 then return end
        local t = os.time{ year = y, month = m, day = d, hour = 12 }
        if t and os.date("%Y-%m-%d", t) == value then return y, m, d end
    end
    local function instant(value)
        if type(value) ~= "string" then return end
        local date, h, m, s = value:match("^(%d%d%d%d%-%d%d%-%d%d)T(%d%d):(%d%d):(%d%d)%.%d%d%dZ$")
        local y, mo, d = day(date)
        h, m, s = tonumber(h), tonumber(m), tonumber(s)
        if not y or h > 23 or m > 59 or s > 59 then return end
        -- Gregorian civil date -> UTC epoch, independent of host DST/timezone.
        local yy = y - (mo <= 2 and 1 or 0)
        local era = math.floor(yy / 400); local yo = yy - era * 400
        local mp = mo + (mo > 2 and -3 or 9)
        local days = era * 146097 + yo * 365 + math.floor(yo / 4) - math.floor(yo / 100)
            + math.floor((153 * mp + 2) / 5) + d - 1 - 719468
        return days * 86400 + h * 3600 + m * 60 + s
    end
    function S.decide(summary, remote, now)
        if type(remote.status) ~= "string" or (not statuses[remote.status]
                and remote.status ~= "unread" and remote.status ~= "want_to_read") then return nil, "invalid" end
        local status = statuses[remote.status]
        if not status then return nil, "ignored" end -- Unread/WTR never erase a local read.
        local updated = instant(remote.updatedAt)
        if not updated or updated > now + 300 then return nil, "invalid" end
        if summary.status == status then return nil, "unchanged" end
        if summary.modified ~= nil then
            local y, m, d = day(summary.modified)
            if not y then return nil, "conflict", "uncertain_date" end
            -- KOReader timestamps status only to a local calendar DAY. Refuse
            -- same-day/ambiguous conflicts instead of inventing last-writer wins.
            local after_day = os.time{ year = y, month = m, day = d + 1, hour = 0 }
            if not after_day or updated < after_day + 60 then
                local before_day = os.time{ year = y, month = m, day = d, hour = 0 }
                return nil, "conflict", before_day and updated < before_day and "newer_local" or "uncertain_date"
            end
        elseif summary.status and summary.status ~= "new" then return nil, "conflict", "uncertain_date" end
        local date = remote.updatedAt:sub(1, 10)
        if status == "complete" and remote.finishedAt ~= nil then
            local finished = instant(remote.finishedAt)
            if not finished or finished > now + 300 then return nil, "invalid" end
            date = remote.finishedAt:sub(1, 10)
        end
        return { status = status, modified = date }
    end
    local function signature(ds)
        local summary = ds:readSetting("summary") or {}
        assert(type(summary) == "table", "invalid summary")
        -- Includes reading positions: a local read during a GET also retires it.
        local fields = { summary.status, summary.modified, ds:readSetting("percent_finished"),
            ds:readSetting("last_xpointer"), ds:readSetting("last_page"), ds:readSetting("partial_md5_checksum") }
        local parts = {}
        for i = 1, 6 do parts[i] = tostring(fields[i]) end
        return table.concat(parts, "\0"), summary
    end
    local function readSidecar(file)
        local DS = require("docsettings")
        local source = DS:findSidecarFile(file, true)
        if not source then return nil, nil, "missing_data" end
        assert(type(source) == "string" and source:sub(1, 1) == "/" and source ~= file
            and source:match("%.lua$"), "invalid sidecar path")
        local attr = require("libs/libkoreader-lfs").symlinkattributes(source)
        if not attr or attr.mode ~= "file" or type(attr.size) ~= "number" or attr.size > 4 * 1024 * 1024 then return nil, nil, "unsafe_sidecar" end
        local fs = require("libs/libkoreader-lfs")
        if DS.getSidecarDir and DS.getSidecarFilename and DS.isHashLocationEnabled then
            local locations = { "doc", "dir" }
            if DS.isHashLocationEnabled() then locations[#locations + 1] = "hash" end
            local alternatives = { file .. ".kpdfview.lua" }
            for _, location in ipairs(locations) do
                local directory = DS:getSidecarDir(file, location)
                local candidate = directory .. "/" .. DS.getSidecarFilename(file)
                alternatives[#alternatives + 1] = candidate
                alternatives[#alternatives + 1] = candidate .. ".old"
            end
            alternatives[#alternatives + 1] = DS:getSidecarDir(file, "doc") .. "/" .. file:match("([^/]+)$") .. ".lua"
            if DS.getHistoryPath then alternatives[#alternatives + 1] = DS:getHistoryPath(file) end
            -- Native open() resolves competing locations/backups by MRU and
            -- may repair corruption. Do not let an automatic import turn an
            -- older preferred copy into the newest authoritative reading data.
            for _, candidate in ipairs(alternatives) do
                if candidate ~= source and candidate ~= source .. ".old" and fs.symlinkattributes(candidate) then return nil, nil, "unsafe_sidecar" end
            end
        end
        -- DocSettings:open() can DELETE invalid candidates, even in a child.
        -- Its light reader neither repairs nor creates files. Keep that rule
        -- in the parent too; atomically replace only this validated sidecar.
        local ds = DS.openSettingsFile(source)
        return ds, source, not ds and "missing_data" or nil
    end
    local function capture()
        local guard = M.bookOrbitGuard("status")
        if not guard then return nil, "disabled" end
        local plugin = require("core/orbitui_context").plugin("bookorbit")
        if not plugin or not plugin.isLoggedIn or not plugin:isLoggedIn() then return nil, "unavailable" end
        if not idle(plugin) then return nil, "busy" end
        local client = plugin:newClient()
        local key = identity(client)
        local manager = require("bookorbit_state_manager")
        if not key or type(client.request) ~= "function" or type(client.query) ~= "function"
                or type(manager.session) ~= "function" or type(manager.commit) ~= "function"
                or type(manager.generation) ~= "function" then return nil, "unsupported" end
        local session = { client = client, key = key, plugin = plugin, manager = manager,
            generation = manager.generation(), epoch = epoch, guard = guard }
        function session:current()
            return self.epoch == epoch and self.guard() and not sleeping
                and require("core/orbitui_context").plugin("bookorbit") == plugin
                and identity(plugin:newClient()) == key and manager.generation() == self.generation
                and idle(plugin)
        end
        return session
    end
    local function refresh(changed)
        if not next(changed) then return end
        local repo = package.loaded["lib/bookshelf_book_repository"]
        local shared = package.loaded["modules/module_books_shared"]
        for file in pairs(changed) do
            require("ui/widget/booklist").setBookInfoCacheProperty(file, "status", changed[file])
            if repo and repo.invalidateProgressCache then repo.invalidateProgressCache(file) end
            if shared and shared.invalidateSidecarCache then shared.invalidateSidecarCache(file) end
        end
        if repo and repo.invalidateBookCache then repo.invalidateBookCache("bookorbit-status-import") end
        local engine = package.loaded["engines/sui_screen_engine"]
        if engine and engine.markAllStale then engine.markAllStale() end
        local widget = package.loaded["lib/bookshelf_widget"]
        if widget and widget.live then widget.live._metadata_dirty_force_full_refresh = true end
        -- No rebuild, cover decode or full Home/config invalidation here.
    end
    local function acknowledge(job)
        if not next(job.ack) then return end
        local s = job.session
        -- A local canonical-state acknowledgement prevents the existing native
        -- sync owner from echoing this import as a fresh completion. No upload.
        if require("core/orbitui_context").plugin("bookorbit") ~= s.plugin
                or identity(s.plugin:newClient()) ~= s.key then job.ack = {}; return end
        local expected = s.manager.generation()
        local result = s.manager.commit(expected, function(state)
            for digest, entry in pairs(job.ack) do
                local book = state.books[digest]
                if book and book.file == entry.file and bookId(book.bookId) == entry.id
                        and book.statusSynced == entry.synced and book.statusSyncedModified == entry.synced_date then
                    book.statusSyncedKnown, book.statusSynced = true, entry.value.status
                    book.statusSyncedModified = entry.value.modified
                end
            end
        end)
        assert(result, "canonical acknowledgement failed")
        s.generation, job.ack = s.manager.generation(), {}
    end
    local arm
    local function finish(job, reason)
        if busy ~= job then return end
        local ok = pcall(acknowledge, job)
        pcall(refresh, job.changed)
        busy = nil
        local result = { account = job.session.key, at = os.time(), changed = job.count,
            skipped = job.skipped, error = not ok and "storage" or reason,
            report_version = 1, counts = job.report.counts }
        if not result.error and not pcall(function() store():saveSetting(RESULT, result) end) then result.error = "storage" end
        -- Never persist filenames/paths. A separate object also protects stores
        -- that retain the supplied table until their eventual flush.
        local recent = {}; for key, value in pairs(result) do recent[key] = value end
        recent.details = job.report.details
        S.last = recent
        if job.done then pcall(job.done, recent) end
        arm(60)
    end
    local function worker(job, task, done)
        require("adapters/orbitui_updates").runTask(function()
            job.session.client.subprocess_depth = 1 -- Child only; no nested API worker.
            return task()
        end, false, function(result)
            if busy ~= job then return end
            local ok, current = pcall(job.session.current, job.session)
            if not ok or not current then finish(job, "retired"); return end
            if not result or not result.ok then finish(job, "interrupted"); return end
            local safe = pcall(done, result.value)
            if not safe then finish(job, "invalid") end
        end)
    end
    local function links(job)
        local candidates, ids, owners_by_file = {}, {}, {}
        for digest, book in pairs(job.session.manager.session().books) do
            local id, file = bookId(book.bookId), book.file
            if id and type(digest) == "string" and #digest == 32 and digest:match("^%x+$")
                    and type(file) == "string" and file:sub(1, 1) == "/" then
                if candidates[id] then candidates[id] = false
                elseif candidates[id] == nil then candidates[id] = { id = id, file = file, digest = digest,
                    synced = book.statusSynced, synced_date = book.statusSyncedModified, known = book.statusSyncedKnown == true } end
                if owners_by_file[file] then owners_by_file[file] = false
                elseif owners_by_file[file] == nil then owners_by_file[file] = id end
            end
        end
        for id, entry in pairs(candidates) do
            if entry and owners_by_file[entry.file] == id then ids[#ids + 1] = entry end
            assert(#ids <= 50000, "too many matched files")
        end
        table.sort(ids, function(a, b) return a.id < b.id end)
        return ids
    end
    local nextBatch
    local function skip(job, code, file)
        job.skipped = job.skipped + 1
        record(job.report, code, file)
    end
    local function apply(job, rows, index)
        local safe, current = pcall(job.session.current, job.session)
        if not safe or not current or not visible() then finish(job, "retired"); return end
        local ok = pcall(function()
            for i = index, math.min(index + 3, #rows) do
                local entry = rows[i]
                local attr = require("libs/libkoreader-lfs").attributes(entry.file)
                if activeFile(entry.file) then skip(job, "active_reader", entry.file)
                elseif protected(entry.file) then skip(job, "pending_undo", entry.file)
                elseif not attr or attr.mode ~= "file" then skip(job, "missing_file", entry.file)
                elseif attr.size ~= entry.size or attr.modification ~= entry.mtime then skip(job, "file_changed", entry.file)
                else
                    local ds, source, why = readSidecar(entry.file)
                    local sig, summary
                    if ds then sig, summary = signature(ds) end
                    if ds and source == entry.sidecar and sig == entry.signature
                            and ds:readSetting("partial_md5_checksum") == entry.digest then
                        local copy = {}; for key, value in pairs(summary) do copy[key] = value end
                        copy.status, copy.modified = entry.value.status, entry.value.modified
                        local data = {}; for key, value in pairs(ds.data) do data[key] = value end
                        data.summary = copy
                        assert(not require("libs/libkoreader-lfs").symlinkattributes(source .. ".tmp"), "sidecar temp exists")
                        require("orbitui_bootstrap").atomicWrite(source, "return " .. require("dump")(data, nil, true) .. "\n")
                        job.count = job.count + 1; job.changed[entry.file] = copy.status
                        job.ack[entry.digest] = entry
                        record(job.report, "updated")
                    elseif not ds then skip(job, why, entry.file)
                    elseif ds:readSetting("partial_md5_checksum") ~= entry.digest then skip(job, "identity_mismatch", entry.file)
                    else skip(job, "local_changed", entry.file) end
                end
            end
        end)
        if not ok then finish(job, "storage"); return end
        if index + 4 <= #rows then UI():scheduleIn(.05, function() apply(job, rows, index + 4) end)
        else
            if not pcall(acknowledge, job) then finish(job, "storage"); return end
            local invalidated = pcall(refresh, job.changed)
            if invalidated then job.changed = {} end
            UI():scheduleIn(.05, function() nextBatch(job) end)
        end
    end
    nextBatch = function(job)
        if busy ~= job then return end
        local ok, current = pcall(job.session.current, job.session)
        if not ok or not current or not visible() then finish(job, "retired"); return end
        if job.index > #job.links then finish(job); return end
        local batch = {}
        for i = job.index, math.min(job.index + BATCH - 1, #job.links) do batch[#batch + 1] = job.links[i] end
        job.index = job.index + #batch
        worker(job, function()
            local ids, allowed = {}, {}
            local fs = require("libs/libkoreader-lfs")
            for _, entry in ipairs(batch) do
                ids[#ids + 1], allowed[entry.id] = tostring(entry.id), entry
            end
            local client = job.session.client
            local body, err = client:request("GET", client:query("/koreader/plugin/catalog/read-statuses", { ids = table.concat(ids, ",") }))
            if not body then return { error = (err == 404 and "server_support" or "network") } end
            assert(type(body) == "table" and body.version == 1 and array(body.items, #ids), "invalid response")
            local found, seen, report = {}, {}, newReport()
            for _, row in ipairs(body.items) do
                assert(type(row) == "table", "invalid row")
                local id = bookId(row.id); local entry = allowed[id]
                assert(entry and not seen[id], "unexpected identity"); seen[id] = true
                -- An unchanged canonical status needs no sidecar read. In
                -- particular, do not undo an intentional unsynced local edit.
                assert(type(row.status) == "string" and (statuses[row.status] or row.status == "unread"
                    or row.status == "want_to_read"), "invalid status")
                assert(instant(row.updatedAt), "invalid status date")
                if statuses[row.status] and not (entry.known and entry.synced == statuses[row.status]) then
                    local attr = fs.attributes(entry.file)
                    if attr and attr.mode == "file" then
                        local ds, source, reason = readSidecar(entry.file)
                        if ds then entry.signature, entry.summary = signature(ds) end
                        if ds and ds:readSetting("partial_md5_checksum") == entry.digest then
                            local value, why, reason = S.decide(entry.summary, row, os.time())
                            assert(why ~= "invalid", "invalid status date")
                            if value then
                                entry.summary, entry.value = nil, value
                                entry.sidecar = source
                                entry.size, entry.mtime = attr.size, attr.modification
                                found[#found + 1] = entry
                            elseif why == "conflict" then record(report, reason, entry.file)
                            elseif why == "unchanged" then record(report, "local_unchanged") end
                        elseif not ds then record(report, reason, entry.file)
                        else record(report, "identity_mismatch", entry.file) end
                    else record(report, "missing_file", entry.file) end
                elseif statuses[row.status] then record(report, "server_unchanged")
                else record(report, "neutral") end
            end
            for _, entry in ipairs(batch) do if not seen[entry.id] then record(report, "server_missing") end end
            return { items = found, skipped = totals(report.counts).skipped, report = report }
        end, function(result)
            assert(type(result) == "table", "invalid worker result")
            if result.error then finish(job, result.error); return end
            assert(array(result.items, BATCH), "invalid candidates")
            assert(type(result.report) == "table" and validCounts{ report_version = 1,
                counts = result.report.counts, changed = 0, skipped = result.skipped }, "invalid counts")
            for _, row in ipairs(reasons) do
                job.report.counts[row[1]] = job.report.counts[row[1]] + result.report.counts[row[1]]
            end
            assert(array(result.report.details, SAMPLE_LIMIT), "invalid details")
            for _, sample in ipairs(result.report.details) do
                assert(type(sample) == "table" and reason_by_code[sample.reason]
                    and type(sample.name) == "string" and #sample.name <= 163, "invalid detail")
                if #job.report.details < SAMPLE_LIMIT then job.report.details[#job.report.details + 1] = sample end
            end
            job.skipped = job.skipped + (result.skipped or 0)
            apply(job, result.items, 1)
        end)
    end
    function S.request(opts)
        opts = opts or {}
        if busy then return false, "busy" end
        if not visible() then return false, "not_visible" end
        if not M.bookOrbitEnabled("status") then return false, "disabled" end
        if not require("ui/network/manager"):isOnline() then return false, "offline" end
        local ok, session, err = pcall(capture)
        if not ok or not session then return false, err or "unavailable" end
        local attempt = store():readSetting(ATTEMPT)
        if not opts.force and type(attempt) == "table" and attempt.account == session.key
                and type(attempt.at) == "number" and math.abs(os.time() - attempt.at) < INTERVAL then return false, "throttled" end
        store():saveSetting(ATTEMPT, { account = session.key, at = os.time() })
        local job = { session = session, index = 1, count = 0, skipped = 0, changed = {}, ack = {}, done = opts.done, report = newReport() }
        busy = job
        worker(job, function() return links(job) end, function(result)
            assert(array(result, 50000), "invalid links")
            job.links = result; nextBatch(job)
        end)
        return true
    end
    local request = S.request
    function S.request(opts)
        local ok, started, reason = pcall(request, opts)
        if ok then return started, reason end
        if busy then pcall(finish, busy, "unavailable") end
        return false, "unavailable"
    end
    arm = function(delay)
        if timer then UI():unschedule(timer); timer = nil end
        if sleeping or not next(owners) or not M.bookOrbitEnabled("status") then return end
        timer = function()
            timer = nil
            if not busy then
                local ok = pcall(S.request)
                if not ok and busy then finish(busy, "unavailable") end
            end
            if not busy then arm(60) end
        end
        UI():scheduleIn(delay, timer)
    end
    function S.started(owner) owners[owner] = true; arm(2) end
    function S.stopped(owner)
        owners[owner] = nil
        if not next(owners) then epoch = epoch + 1 end
        arm(2)
    end
    function S.policyChanged() epoch = epoch + 1; arm(2) end
    function S.event(handler)
        if handler == "onSuspend" then sleeping = true; epoch = epoch + 1
        elseif handler == "onResume" then sleeping = false
        elseif handler == "onShowingReader" or handler == "onSetupShowReader" or handler == "onReaderReady"
                or handler == "onSetRotationMode" then epoch = epoch + 1 end
        arm(2)
    end
    function S.isRunning() return busy ~= nil end
    local errors = {
        server_support = "The server needs the read-statuses v1 extension. No server was changed.",
        network = "Status check failed: connection or server unavailable.",
        invalid = "Status check stopped: unsupported or invalid response.",
        interrupted = "Status check interrupted; it will be retried later.",
        retired = "Status check retired after navigation, account or local-state changes.",
        storage = "Status check stopped: local data could not be safely saved.",
    }
    local function reports()
        local plugin = require("core/orbitui_context").plugin("bookorbit")
        local ok, key = pcall(function() return identity(plugin and plugin:newClient()) end)
        local function scoped(r)
            if ok and key and type(r) == "table" and r.account == key and type(r.at) == "number"
                    and r.at == r.at and r.at > 0 and r.at <= 32503680000 then return r end
        end
        local raw = scoped(store():readSetting(RESULT))
        -- Stored records are counts-only, including when reading old or edited
        -- settings. Never treat a persisted details field as session samples.
        local saved = raw and { account = raw.account, at = raw.at, changed = raw.changed,
            skipped = raw.skipped, report_version = raw.report_version, counts = raw.counts }
        return saved, scoped(S.last) or saved
    end
    function S.details(result)
        local lines = { S.summary(result) }
        if result.error then
            lines[#lines + 1] = _(errors[result.error] or errors.network)
            lines[#lines + 1] = _("Incomplete check: counts cover only processed entries.")
        end
        local t = validCounts(result)
        if not t then return table.concat(lines, "\n\n") end
        local groups = { { "updated", "Updated" }, { "unchanged", "Unchanged" },
            { "missing", "Missing local files or reading data" }, { "protected", "Protected" },
            { "conflict", "Conflicts" }, { "ignored", "Not imported" } }
        for _i, group in ipairs(groups) do
            lines[#lines + 1] = string.format("%s: %d", _(group[2]), t[group[1]])
            if group[1] ~= "updated" then
                for _j, row in ipairs(reasons) do
                    if row[2] == group[1] and result.counts[row[1]] > 0 then
                        lines[#lines + 1] = string.format("  %s: %d", _(row[3]), result.counts[row[1]])
                    end
                end
            end
        end
        lines[#lines + 1] = _("An unchanged server status is not reapplied and does not read local data. This preserves intentional unsynced local changes.")
        lines[#lines + 1] = _("Only unique saved BookOrbit matches are checked, not every book on the device. Skipped books are left untouched; they are not all conflicts.")
        if result.details then
            if #result.details > 0 then
                lines[#lines + 1] = string.format(_("Showing %d of %d skipped books. Filenames are kept only until KOReader restarts."), #result.details, t.skipped)
                for _i, sample in ipairs(result.details) do
                    lines[#lines + 1] = sample.name .. " — " .. _(reason_by_code[sample.reason][3])
                end
            end
        elseif t.skipped > 0 then
            lines[#lines + 1] = _("Only counts were saved. Run a new check to see example filenames.")
        end
        return table.concat(lines, "\n\n")
    end
    function S.showDetails()
        local recent = select(2, reports()) -- Recheck account on activation, not just menu construction.
        if not recent then return end
        UI():show(require("ui/widget/textviewer"):new{
            title = _("Status check details"), text = S.details(recent),
        })
    end
    function S.items()
        local result, recent = reports()
        local report = recent and recent.error and _(errors[recent.error] or "Status check failed: connection or server unavailable.")
            or (recent and S.summary(recent))
            or _("No status check in this session")
        return {
            { text = _("Automatic reading-status import"), checked_func = function() return M.bookOrbitEnabled("status") end,
                enabled_func = function() return M.bookOrbitEnabled() end,
                callback = function() M.setBookOrbitEnabled("status", not M.bookOrbitEnabled("status")) end },
            { text = _("Update reading status now"), enabled_func = function() return M.bookOrbitEnabled("status") and not busy end,
                callback = function(shim)
                    shim.closeMenu()
                    UI():scheduleIn(.2, function()
                        local started = S.request{ force = true, done = function(r)
                            require("core/orbitui_context").notify(r.error and _("Reading status could not be fully imported. Existing reading data is kept; check server support and try again.")
                                or (S.summary(r) .. "\n" .. _("See Status check details for reasons.")))
                        end }
                        if not started then require("core/orbitui_context").notify(_("Reading-status import is unavailable or offline. Open Home or a shelf and try again.")) end
                    end)
                end },
            { text = string.format(_("Last successful status check: %s"), result and os.date("%Y-%m-%d %H:%M", result.at) or _("Never")) },
            { text = report },
            { text = _("Status check details…"), enabled_func = function() local _, r = reports(); return r ~= nil end,
                callback = S.showDetails },
            { text = _("How reading-status import works"), callback = function()
                require("core/orbitui_context").notify(_("Off by default. After Home or a shelf is visible, checks saved BookOrbit matches at most every 15 minutes. No EPUB scan, cover reload, download or remote write. Requires the read-statuses v1 server extension. Offline, unsupported servers and interrupted checks keep local data. Open books, pending Undo, newer local status and ambiguous same-day changes are protected. Unread/Want to Read never reset a local read; page position, history, ratings and reviews are unchanged. Previously imported books remain imported when disabled. BookOrbit's own sync preferences are untouched."))
            end },
        }
    end
    function S.showSettings()
        return require("lib/bookshelf_menu_host").show{ title = _("Import reading status from BookOrbit"),
            item_table = S.items(), on_back = function() require("adapters/orbitui_settings").open("bookorbit") end }
    end
end

return M
