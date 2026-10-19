local Model = require("core/orbitui_addons")
local F = require("core/orbitui_addon_files")
local _ = require("core/orbitui_i18n")
local M = {}
local store, busy, reload, refresh_menu
local function info(message) require("core/orbitui_context").notify(message) end
local function rootPath()
    return assert(debug.getinfo(1, "S").source:match("^@(.+)/adapters/orbitui_addons%.lua$"))
end
local function getStore(root, legacy)
    if not store then
        store = Model.new(root or rootPath(), require("datastorage"):getSettingsDir() .. "/orbitui/addons", legacy)
    elseif legacy then store.legacy = legacy end
    return store
end
function M.changed()
    if reload then reload() end
    local themes = package.loaded["lib/bookshelf_theme_pack"]
    if themes and themes.invalidate then themes.invalidate() end
    require("adapters/orbitui_appearance").changed()
    if refresh_menu then refresh_menu() end
end

function M.ornaments(orn, root)
    local Text = require("core/orbitui_ornament_text")
    orn.resolveInfo = function(record)
        return Text.resolve(record, G_reader_settings and G_reader_settings:readSetting("language"))
    end
    local native_roots = orn.roots
    -- Never seed either OrbitUI artwork or upstream's template/cactus on startup.
    orn.ensureTemplate = function() F.mkdir(orn.dir()) end
    local current_roots, accept, enabled = {}, function() return true end, function() return true end
    local caches = setmetatable({}, { __mode = "k" })
    reload = function()
        local s = getStore(root, native_roots())
        current_roots, accept, enabled = s:view()
        local bindings, placements = {}, {}
        for _, record in pairs(s:registry().packs) do
            if not record.removed then
                for _, folder in ipairs(record.pack.folders) do
                    placements[folder] = Model.placement(record.placement)
                end
            end
            if record.enabled ~= false then
                local manifest = F.json(s:versionRoot(record) .. "/manifest.json")
                for path, binding in pairs(manifest.bindings or {}) do bindings[path] = binding end
            end
        end
        require("core/orbitui_author_ornaments").setBindings(bindings)
        require("core/orbitui_author_ornaments").setPlacements(placements)
        require("core/orbitui_manga_ornaments").setBindings(bindings)
        caches = setmetatable({}, { __mode = "k" }); orn.invalidate()
    end
    local loaded = false
    local function ensure()
        if loaded then return end
        loaded = true
        local ok, err = pcall(reload)
        if not ok then require("logger").warn("[OrbitUI] Add-ons unavailable; existing ornaments kept", err) end
    end
    orn.roots = function()
        ensure()
        local roots = native_roots()
        for _, path in ipairs(current_roots) do roots[#roots + 1] = path end
        return roots
    end
    orn.acceptFile = function(...) return accept(...) end
    orn.addonDisabled = function(entry) ensure(); return not enabled(entry) end
    local native_pack = orn.packDir
    if native_pack then
        orn.packDir = function(pack)
            ensure()
            local native = native_pack(pack)
            local ok, path = pcall(function() return getStore():packDir(pack, native) end)
            return ok and path or native
        end
    end
    orn.packGroup = function(pack)
        if pack == "Manga II" or pack == "Manga III" then return "Manga" end
        return pack
    end
    for _, key in ipairs({ "list", "listFor" }) do
        local native = orn[key]
        orn[key] = function(...)
            ensure()
            local all = native(...)
            if caches[all] then return caches[all] end
            local out = {}
            for _, e in ipairs(all) do if enabled(e) then out[#out + 1] = e end end
            caches[all] = out
            return out
        end
    end
end
function M.browser(browser, root)
    local items = browser._items
    browser._items = function(self)
        local out = items(self)
        local orn = require("lib/bookshelf_ornaments")
        for _, item in ipairs(out) do
            if orn.addonDisabled and orn.addonDisabled(item.entry) then item.off, item.pack_off = true, true end
        end
        return out
    end
    local function enableEntries(entries)
        local s, changed = getStore(root), false
        local groups = {}; for _, item in ipairs(entries) do groups[item.entry.pack or ""] = true end
        for key, r in pairs(s:registry().packs) do
            if not r.removed and r.enabled == false then
                for _, folder in ipairs(r.pack.folders) do
                    if groups[folder] then s:enable(key, true); changed = true; break end
                end
            end
        end
        if changed then M.changed() end
    end
    for _, method in ipairs({ "_toggle", "_pick" }) do
        local native, name = browser[method], method
        browser[method] = function(self, item)
            if name == "_pick" or item.off then enableEntries({ item }) end
            return native(self, item)
        end
    end
    local all = browser._setAll
    browser._setAll = function(self, on)
        if on then enableEntries(self.items or {}) end
        return all(self, on)
    end
    browser._addButton = function(self)
        return { key = "add", label = _("Ornament add-ons"), on_tap = function()
            M.show(root, function() self:_changed(true) end)
        end }
    end
end

local function protected(fn)
    local ok, err = pcall(fn)
    if not ok then
        require("logger").warn("[OrbitUI] Ornament operation failed", err)
        info(_("The ornament operation failed. Existing settings were kept. Check the connection and free storage, then try again."))
    end
    return ok
end
local function online(operation, label, done)
    if busy then info(_("An ornament operation is already running.")); return end
    require("ui/network/manager"):runWhenOnline(function()
        if busy then return end
        busy = true
        require("adapters/orbitui_updates").runTask(operation, label, function(result)
            busy = false
            if result and result.ok then protected(function() done(result.value) end)
            else
                require("logger").warn("[OrbitUI] Ornament download stopped", result and result.error)
                info(_("No changes were applied. The download was cancelled or could not be verified."))
            end
        end)
    end)
end
function M.check()
    online(Model.fetchCatalog, _("Checking ornament updates..."), function(c)
        getStore():saveCatalog(c); if refresh_menu then refresh_menu() end
        info(_("Ornament catalog updated. Open a pack to install or update it. OrbitUI itself is unchanged."))
    end)
end
local function confirm(message, action)
    require("ui/uimanager"):show(require("ui/widget/confirmbox"):new{
        text = message, ok_text = _("Continue"), ok_callback = function() protected(action) end,
    })
end
function M.install(pack)
    confirm(pack.name .. "\n\n" .. _("Download size") .. ": " .. string.format("%.1f MB", pack.size / 1048576)
        .. "\n\n" .. _("Install or update this ornament pack? Own edits, disabled ornaments and shelf choices are kept."), function()
        -- Load the ornament adapter first, including the native migration roots.
        require("lib/bookshelf_ornaments").listAll()
        local s = getStore()
        online(function() return s:prepare(pack) end, _("Downloading ornaments..."), function(plan)
            s:activate(plan); M.changed()
            info(_("Ornament pack installed. You can use it on the current shelf from the pack menu. No restart is needed."))
        end)
    end)
end
function M.use(pack)
    local sw = require("lib/bookshelf_theme_pack").switches()
    local own = {}; for _, folder in ipairs(pack.folders) do own[folder] = true end
    for _, entry in ipairs(require("lib/bookshelf_ornaments").listAll()) do
        if own[entry.pack] then sw.setOff(entry.name, false); sw.setPackOff(entry.pack, false) end
    end
    getStore():enable(pack.id, true); M.changed()
end
function M.preview(pack)
    local function show(path)
        local aspect = Model.png(path)
        require("lib/bookshelf_ornament_zoom").show({ name = pack.name, path = path, aspect = aspect,
            info = _(pack.description) .. "\n\n" .. _("Artwork credits and licenses are included in each downloaded pack. These vary by image; manga fan art is unofficial."),
            night_invert = false })
    end
    local s = getStore()
    local r = s:registry().packs[pack.id]
    if r and not r.removed then
        for _, path in ipairs(F.walk(s:versionRoot(r))) do
            if path:match("%.png$") and not path:find("/theme/", 1, true) then show(s:versionRoot(r) .. "/" .. path); return end
        end
    end
    if not pack.preview or type(pack.preview) ~= "table" then info(_("Check ornament updates to load the download catalog.")); return end
    online(function()
        local a = Model.asset(pack.preview)
        F.mkdir(s.directory .. "/previews")
        local path = s.directory .. "/previews/" .. a.sha256 .. ".png"
        require("core/orbitui_http").get(a.url, path, a.size)
        assert(F.attr(path).size == a.size and require("core/orbitui_ota").hashFile(path) == a.sha256, "Preview checksum mismatch")
        Model.png(path)
        return path
    end, _("Downloading preview..."), show)
end
function M.credits(pack)
    local s = getStore(); local r = assert(s:registry().packs[pack.id])
    local root, parts = s:versionRoot(r), {}
    for _, folder in ipairs(pack.folders) do
        for _, path in ipairs(F.walk(root .. "/" .. folder)) do
            if path:match("%.txt$") and not path:match("README") then
                parts[#parts + 1] = folder .. "/" .. path .. "\n\n" .. (F.read(root .. "/" .. folder .. "/" .. path, 128 * 1024) or "")
            end
        end
    end
    require("ui/uimanager"):show(require("ui/widget/textviewer"):new{
        title = _("Credits and licenses") .. ": " .. pack.name, text = table.concat(parts, "\n\n----------------\n\n"),
    })
end
local function placementLabel(mode)
    return mode == "random" and _("Random") or _("Match books (default)")
end
function M.placementMenu(pack)
    local s, host = getStore()
    local rows = {}
    for _i, mode in ipairs({ "matched", "random" }) do
        local value = mode
        rows[#rows + 1] = { text = placementLabel(value), radio = true,
            help_text = (value == "matched"
                and _("Author busts stay beside matching authors; manga ornaments stay beside matching series. Other ornaments remain mixed.")
                or _("Mix this pack without matching authors or series, with at most one ordinary ornament per row."))
                .. "\n\n" .. _("Applies wherever this pack is enabled. Does not enable the pack or change shelf and theme choices."),
            checked_func = function()
                local r = s:registry().packs[pack.id]
                return Model.placement(r and r.placement) == value
            end,
            callback = function()
                protected(function() s:setPlacement(pack.id, value); M.changed() end)
                if host and not host._closed then host._shim.updateItems() end
            end,
        }
    end
    host = require("lib/bookshelf_menu_host").show{ title = _("Placement") .. ": " .. pack.name,
        item_table = rows, close_callback = require("adapters/orbitui_appearance").refreshVisible }
    return host
end
function M.packMenu(pack)
    local s = getStore(); local r = s:registry().packs[pack.id]
    local installed = r and not r.removed
    local buttons = {}
    local dialog
    local function row(label, fn, enabled)
        buttons[#buttons + 1] = {{ text = label, enabled = enabled ~= false, callback = function()
            require("ui/uimanager"):close(dialog); protected(fn)
        end }}
    end
    row(_("Preview and information"), function() M.preview(pack) end)
    if not installed or pack.version > r.pack.version then
        row(installed and _("Update ornaments") or _("Install ornament pack"), function() M.install(pack) end, pack.url ~= nil)
    end
    if installed then
        row(_("Credits and licenses"), function() M.credits(pack) end)
        row(_("Placement") .. ": " .. placementLabel(Model.placement(r.placement)), function() M.placementMenu(pack) end)
        row(r.enabled == false and _("Enable pack") or _("Disable pack"), function()
            s:enable(pack.id, r.enabled == false); M.changed()
        end)
        row(_("Use in current theme"), function() M.use(pack) end)
        row(_("Uninstall pack"), function()
            confirm(_("Remove downloaded, unchanged pack files? Own modified files and pre-existing ornament folders are kept."), function()
                s:uninstall(pack.id); M.changed()
            end)
        end)
    end
    row(_("Close"), function() end)
    dialog = require("ui/widget/buttondialog"):new{ title = pack.name .. "\n" .. _(pack.description), buttons = buttons }
    require("ui/uimanager"):show(dialog)
end
function M.items()
    local s = getStore(); local state = s:registry()
    local out = { { text = _("Check ornament updates"), callback = M.check } }
    local packs, present = {}, {}
    for _, p in ipairs(s:catalog().packs) do packs[#packs + 1] = p; present[p.id] = true end
    for key, r in pairs(state.packs) do
        if not present[key] and not r.removed then packs[#packs + 1] = r.pack end
    end
    for _i, p in ipairs(packs) do
        local pack, r = p, state.packs[p.id]
        local status = _("Not installed")
        if not r then
            for _root_index, native in ipairs(s.legacy or {}) do
                for _folder_index, folder in ipairs(p.folders) do
                    if F.attr(native .. "/" .. folder) then status = _("Local files; not managed") end
                end
            end
        end
        if r and not r.removed then
            status = r.enabled == false and _("Disabled") or _("Installed")
            status = status .. " v" .. r.pack.version
            if p.version > r.pack.version then status = status .. " / " .. _("Update available") end
        end
        out[#out + 1] = { text = p.name .. " - " .. status, callback = function() protected(function() M.packMenu(pack) end) end }
    end
    return out
end
function M.show(root, after)
    protected(function()
        getStore(root)
        require("lib/bookshelf_ornaments").roots()
        local host
        host = require("lib/bookshelf_menu_host").show{ title = _("Ornament add-ons"), item_table = M.items(),
            close_callback = function()
                refresh_menu = nil
                if after then after() end
                require("adapters/orbitui_appearance").refreshVisible()
            end }
        refresh_menu = function()
            if host and not host._closed then
                local rows = host._shim.liveItems()
                for i = #rows, 1, -1 do rows[i] = nil end
                for i, row in ipairs(M.items()) do rows[i] = row end
                host._shim.updateItems()
            end
        end
    end)
end
return M
