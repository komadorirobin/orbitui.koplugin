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

-- Silverfish's public Home toggle appends to page one. Route only a NEW
-- first-page placement; never migrate a saved native/dashboard placement.
-- The official plugin/archive/save format stays untouched.
local PET, HOME, PREFIX = "traca_cartao", "simpleui_layout", "simpleui_hs_"
local function settings() return require("infra/sui_store") end
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end
local function entryId(e) return type(e) == "table" and e.id or e end
local function pageWith(layout, id)
    if type(layout) ~= "table" or type(layout.pages) ~= "table" then return end
    for i, page in ipairs(layout.pages) do
        if type(page) == "table" and type(page.modules) == "table" then
            for _i, entry in ipairs(page.modules) do if entryId(entry) == id then return page, i end end
        end
    end
end
local function petConfig()
    local D = require("core/orbitui_dashboard")
    local key = PREFIX .. "orbitui_dashboard_config"
    local raw = settings():readSetting(key)
    local legacy = settings():readSetting("simpleui_orbitui_dashboard_config_ready") ~= true
        and settings():readSetting(PREFIX .. "orbitui_dashboard_enabled") ~= nil
    return D.config(raw, legacy), key, raw, D.moduleId("simpleui", PET)
end
local function petCard()
    local c, _key, _raw, id = petConfig()
    return require("core/orbitui_dashboard").module(c, id)
end
local function fitsFirstPage(before, page)
    if #page.modules == 0 then return true end
    -- Unknown geometry is not permission to overflow. Use an already built,
    -- matching portrait page, not builds/scans/guessed stock module heights.
    local ok, fits = pcall(function()
        local HS = package.loaded["screens/sui_homescreen"]
        local screen = HS and HS.getInstance and HS.getInstance("hs")
        local Display = require("device").screen
        if not screen or screen._current_page ~= 1 or screen._layout_sw ~= Display:getWidth()
                or Display:getWidth() >= Display:getHeight() then return false end
        local cached = screen._enabled_mods_cache and screen._enabled_mods_cache.pages_of_mods
        local mods = cached and cached[1]
        if not mods or #mods ~= #page.modules then return false end
        for i, mod in ipairs(mods) do
            if mod.id ~= entryId(page.modules[i]) then return false end
        end
        local original = before.pages[1]
        if not original or #original.modules ~= #page.modules then return false end
        for i, e in ipairs(original.modules) do if entryId(e) ~= entryId(page.modules[i]) then return false end end
        local mod = require("modules/moduleregistry").get(PET)
        if not mod or type(mod.getHeight) ~= "function" or mod.label then return false end
        local h = mod.getHeight{ pfx = PREFIX, _screen_widget = screen }
        local body = screen._body and screen._body:getSize()
        local available = screen._layout_content_h
        local function finite(n) return type(n) == "number" and n == n and n >= 0 and n < 100000 end
        if not finite(h) or h == 0 or not body or not finite(body.h) or not finite(available) then return false end
        local Chrome, Config, UI = require("features/sui_module_chrome"), require("infra/sui_config"), require("infra/sui_core")
        local extra = Chrome.boxInset(Chrome.resolve(PREFIX, PET))
        local gap = Config.getModuleGapPx(PET, PREFIX, UI.MOD_GAP)
        if not finite(extra) or not finite(gap) then return false end
        local footer = Display:scaleBySize(40)
        for _i, name in ipairs{ "_footer_dot", "_footer_chevron" } do
            local f = screen[name]
            if f and f.widget then footer = math.max(footer, f.widget:getSize().h) end
        end
        return body.h + h + extra + gap + footer + Display:scaleBySize(8) <= available
    end)
    return ok and fits == true
end
function M.layout(Layout)
    if Layout._orbitui_pet_placement then return end
    Layout._orbitui_pet_placement = true
    local save = Layout.save
    Layout.save = function(layout, pfx, key, screen_id, opts)
        if (pfx and pfx ~= PREFIX) or (key and key ~= HOME) or (screen_id and screen_id ~= "hs") then
            return save(layout, pfx, key, screen_id, opts)
        end
        local _, index = pageWith(layout, PET)
        if index ~= 1 then return save(layout, pfx, key, screen_id, opts) end
        local before = Layout.load(pfx, key)
        if pageWith(before, PET) then return save(layout, pfx, key, screen_id, opts) end
        local D = require("core/orbitui_dashboard")
        local plan = copy(layout)
        local page = plan.pages[1]
        for i = #page.modules, 1, -1 do if entryId(page.modules[i]) == PET then table.remove(page.modules, i) end end
        local c, config_key, old, id = petConfig()
        local dashboard = pageWith(plan, D.id)
        local active = dashboard and (settings():readSetting(PREFIX .. "orbitui_dashboard_enabled") == true
            or not pageWith(before, D.id))
        local changed = false
        if active and not c.unsupported and (D.module(c, id) or #c.modules < D.module_limit) then
            if not D.module(c, id) then
                c.modules[#c.modules + 1] = { id = id, kind = "simpleui", ref = PET, width = 2, size = "normal" }
                c.order[#c.order + 1] = id
                changed = true
            end
        elseif not dashboard and fitsFirstPage(before, page) then
            return save(layout, pfx, key, screen_id, opts)
        else
            local used, next_id = {}, 1
            for _i, p in ipairs(plan.pages) do used[p.id] = true end
            while used[next_id] do next_id = next_id + 1 end
            local moved
            for _i, e in ipairs(layout.pages[1].modules) do
                if entryId(e) == PET then moved = copy(e); break end
            end
            plan.pages[#plan.pages + 1] = { id = next_id, modules = { moved } }
        end
        if changed then settings():saveSetting(config_key, D.config(c)) end
        local ok, result = pcall(save, plan, pfx, key, screen_id, opts)
        if not ok then
            if changed then settings():saveSetting(config_key, old) end
            error(result, 0)
        end
        -- Keep editor page objects alive, but reflect the actual saved choice.
        for i, p in ipairs(plan.pages) do
            if layout.pages[i] then layout.pages[i].modules = copy(p.modules)
            else layout.pages[i] = copy(p) end
        end
        return result
    end
end

function M.silverfish(pet)
    if pet._orbitui_home_placement or type(pet.cartaoSimpleUI) ~= "function" then return end
    pet._orbitui_home_placement = true
    local original = pet.cartaoSimpleUI
    pet.cartaoSimpleUI = function(self, enabled)
        local loaded, Layout = pcall(require, "infra/sui_layout")
        if not loaded or type(Layout) ~= "table" or type(Layout.load) ~= "function"
                or type(Layout.save) ~= "function" or type(Layout.remove) ~= "function" then
            return original(self, enabled)
        end
        -- Use the public native layout API directly. Silverfish's legacy
        -- fallback catches save errors and can otherwise enable a standalone
        -- card even when the modern placement failed.
        local layout = Layout.load()
        local native = pageWith(layout, PET) ~= nil
        local managed = petCard()
        if enabled == nil then return native or managed ~= nil end
        enabled = not not enabled
        if enabled and (native or managed) then return true end
        if not enabled and not native and not managed then return false end
        local old, config_key
        if enabled == false and managed then
            local c, key, raw, id = petConfig()
            old, config_key = raw, key
            for i = #c.modules, 1, -1 do if c.modules[i].id == id then table.remove(c.modules, i) end end
            for i = #c.order, 1, -1 do if c.order[i] == id then table.remove(c.order, i) end end
            c.hidden[id] = nil
            settings():saveSetting(key, require("core/orbitui_dashboard").config(c))
        end
        local ok, result = pcall(function()
            if enabled then
                if not layout.pages[1] then layout.pages[1] = { id = 1, modules = {} } end
                table.insert(layout.pages[1].modules, PET)
            elseif native then
                Layout.remove(layout, nil, PET)
            end
            Layout.save(layout)
            return pageWith(layout, PET) ~= nil or petCard() ~= nil
        end)
        if not ok then
            if config_key then settings():saveSetting(config_key, old) end
            error(result, 0)
        end
        return result
    end
end
function M.registry(Registry)
    if Registry._orbitui_pet_placement then return end
    Registry._orbitui_pet_placement = true
    local register = Registry.register
    Registry.register = function(mod)
        local screensaver = package.loaded["ui/screensaver"]
        local pet = screensaver and screensaver.traca_instancia
        if type(mod) == "table" and mod.id == PET and type(mod.enabled_key) == "string"
                and pet and type(pet.cartaoSimpleUI) == "function" then
            M.silverfish(pet)
            local explicit = settings():readSetting(PREFIX .. mod.enabled_key) ~= nil
                or pageWith(settings():readSetting(HOME), PET)
            local order = settings():readSetting(PREFIX .. "module_order") or {}
            local screens = settings():readSetting("simpleui_custom_screens") or {}
            if type(order) ~= "table" or type(screens) ~= "table" then return register(mod) end
            for _i, id in ipairs(order) do
                if id == PET then explicit = true end
            end
            for _i, screen in ipairs(screens) do
                if type(screen) == "table" and type(screen.layout_key) == "string" and type(screen.pfx) == "string"
                        and (pageWith(settings():readSetting(screen.layout_key), PET)
                            or settings():readSetting(screen.pfx .. mod.enabled_key) ~= nil) then explicit = true end
            end
            if not explicit then
                local clone = {}; for k, value in pairs(mod) do clone[k] = value end
                mod = clone; mod.default_on = false
            end
        end
        return register(mod)
    end
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
