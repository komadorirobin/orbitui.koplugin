local Model = require("core/orbitui_module_store")
local _ = require("core/orbitui_i18n")
local M, busy = {}, false
local function info(message) require("core/orbitui_context").notify(message) end
local function protected(fn)
    local ok, err = pcall(fn)
    if not ok then
        require("logger").warn("[OrbitUI] Module catalog operation failed", err)
        info(_("The module operation could not finish. Existing plugins and settings were kept. Check storage and the connection, then retry."))
    end
    return ok
end
function M.store()
    local Data = require("datastorage")
    local data = Data:getDataDir()
    local root = data == "." and "plugins" or data .. "/plugins"
    local roots, seen = { "plugins" }, { plugins = true }
    local extra = G_reader_settings:readSetting("extra_plugin_paths")
    if extra == nil then extra = { root } elseif type(extra) == "string" then extra = { extra } end
    assert(type(extra) == "table", "Invalid plugin lookup directories")
    local reachable = root == "plugins"
    for _, path in ipairs(extra) do
        assert(type(path) == "string", "Invalid plugin lookup directory")
        path = path:gsub("/+$", "")
        if path == root then reachable = true end
        if not seen[path] then roots[#roots + 1] = path; seen[path] = true end
    end
    assert(reachable, "Data plugin directory is not in KOReader's search paths; kept")
    return Model.new(root, Data:getSettingsDir() .. "/orbitui/module-store", roots)
end
local function online(operation, label, done)
    if busy then info(_("A module operation is already running.")); return end
    require("ui/network/manager"):runWhenOnline(function()
        if busy then return end
        busy = true
        local ok, err = pcall(require("adapters/orbitui_updates").runTask, operation, label, function(result)
            busy = false
            if result and result.ok then protected(function() done(result.value) end)
            else info(_("Module download cancelled or unverifiable. No plugin was activated.")) end
        end)
        if not ok then busy = false; error(err) end
    end)
end
function M.check(refresh)
    online(Model.fetchCatalog, _("Checking the reviewed module catalog…"), function(c)
        if c then M.store():saveCatalog(c); info(_("Module catalog updated. Nothing was installed automatically."))
        else info(_("No separate module catalog has been published yet. The bundled reviewed catalog is still available.")) end
        if refresh then refresh() end
    end)
end
function M.install(p, refresh)
    require("ui/uimanager"):show(require("ui/widget/confirmbox"):new{
        text = p.name .. " " .. p.version .. "\n" .. Model.url(p) .. "\n\n"
            .. _("Install this executable plugin? It has KOReader's access to files and the network; it is not sandboxed. Only its dashboard adapters were desktop-tested, not the full plugin on Bigme.")
            .. "\n\n" .. _("Existing plugins are never overwritten. After restart, enable it in KOReader's plugin manager if needed, then add its card from the module picker. Plugin-owned startup or screensaver options may also appear.")
            .. "\n\n" .. Model.localized(p, "license") .. "\n" .. Model.localized(p, "data_note"),
        ok_text = _("Install plugin"), ok_callback = function()
            protected(function()
                local s = M.store()
                online(function() s:cleanup(); return s:prepare(p) end, _("Downloading and verifying module… Tap to cancel."), function(plan)
                    s:activate(plan)
                    if refresh then refresh() end
                    info(_("Plugin installed. Restart KOReader to load it, then add its card. Your existing plugin settings and data were not changed."))
                end)
            end)
        end,
    })
end
local statuses = {
    missing = "Not installed", unmanaged = "Existing plugin or legacy conflict; not managed",
    unverified = "Installed files changed; version unverified", verified = "Matches the tested archive",
    ["other-tested"] = "Different catalog version installed; no automatic update",
}
function M.details(p, status)
    return p.name .. " " .. p.version .. "\n\n" .. Model.localized(p, "description")
        .. "\n\n" .. _("Test scope: dashboard adapters on desktop only. Not a safety certificate or a Bigme test.")
        .. "\nKOReader: " .. _(p.test.koreader) .. "\nOrbitUI: " .. p.test.orbitui .. "\n" .. p.test.date
        .. "\n" .. p.test.evidence .. "\n\n" .. _(statuses[status])
        .. "\n\n" .. _("Source") .. ": " .. p.repository .. " @ " .. p.commit
        .. "\n" .. Model.url(p) .. "\nSHA-256: " .. p.sha256
        .. "\n" .. _("Download size") .. ": " .. string.format("%.2f MiB", p.size / 1048576)
        .. "\n\n" .. Model.localized(p, "license") .. "\n" .. Model.localized(p, "data_note")
        .. "\n\n" .. _("First installations only. Updates, rollback and removal remain manual; back up the plugin's own data before changing versions. The catalog never enables a disabled plugin or takes over its updater.")
end
function M.items(refresh, cached)
    local s, items = M.store(), {}
    items[1] = { text = _("Check reviewed catalog"), callback = function() M.check(refresh) end }
    for _i, entry in ipairs(s:catalog().plugins) do
        local p = entry
        -- Verification is explicit, never in Home's paint or startup path.
        local function status()
            local key = p.id .. ":" .. p.sha256
            if not cached then return s:status(p) end
            if not cached[key] then cached[key] = s:status(p) end
            return cached[key]
        end
        status()
        items[#items + 1] = { text = p.name .. " " .. p.version .. " · " .. _("Desktop adapter test"),
            value_func = function() return "" end, -- no eager sub-menu build while painting
            sub_item_table_func = function()
                return {
                    { text = _("Information and test scope"), callback = function()
                        require("ui/uimanager"):show(require("ui/widget/textviewer"):new{
                            title = p.name, text = M.details(p, status()),
                        })
                    end },
                    { text_func = function() return _(statuses[status()]) end, dim = true },
                    { text = _("Install plugin"), enabled_func = function() return status() == "missing" and not busy end,
                        callback = function() M.install(p, refresh) end },
                }
            end }
    end
    return items
end
function M.show(pfx)
    protected(function()
        local alive, cached = true, {}
        return require("screens/sui_settings_window"):show(function() alive = false end, {{ id = "nested_menu", params = {
            title = _("Module library"), items_func = function(ctx)
                return M.items(function()
                    for k in pairs(cached) do cached[k] = nil end
                    if alive and ctx.repaint then ctx.repaint() end
                end, cached)
            end,
        } }}, { pfx = pfx or "simpleui_hs_" })
    end)
end
return M
