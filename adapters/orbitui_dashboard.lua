-- Opt-in Home page. It reads the existing providers, never replaces their data.
local Model = require("core/orbitui_dashboard")
local Sources = require("adapters/orbitui_dashboard_sources")
local _ = require("core/orbitui_i18n")
local M = {
    id = Model.id, name = _("Reading dashboard"), default_on = false,
    enabled_key = "orbitui_dashboard_enabled", owns_chrome = true,
    has_covers = true, is_book_mod = true,
    needs = { recent = 30, stats = true, books = true },
}

local function store() return require("infra/sui_store") end

function M.readConfig(pfx)
    pfx = pfx or "simpleui_hs_"
    local key = pfx .. "orbitui_dashboard_config"
    local raw = store():readSetting(key)
    local legacy = store():readSetting("simpleui_orbitui_dashboard_config_ready") ~= true
        and store():readSetting(pfx .. M.enabled_key) ~= nil
    local config = Model.config(raw, legacy)
    if raw == nil then store():saveSetting(key, config) end
    return config
end

function M.editConfig(pfx, edit, refresh)
    local config = M.readConfig(pfx)
    if config.unsupported then return false end
    edit(config)
    store():saveSetting((pfx or "simpleui_hs_") .. "orbitui_dashboard_config", Model.config(config))
    if refresh then refresh() else
        require("screens/sui_homescreen").rebuildLayout({ keep_wallpaper = true })
    end
    return true
end

local function headingKey(pfx, key)
    return (pfx or "simpleui_hs_") .. "orbitui_dashboard_heading_" .. key
end

function M.readHeadings(pfx)
    local headings = {}
    for _, card in ipairs(Model.heading_cards) do
        headings[card.key] = Model.normalizeHeading(store():readSetting(headingKey(pfx, card.key)))
    end
    return headings
end

local function headingLabel(card, pfx)
    if card.key == "want" or card.key == "new" then
        return Sources.label(M.readConfig(pfx).sources[card.key])
    end
    return _(card.label)
end

local function editHeading(card, refresh, pfx)
    local UIManager = require("ui/uimanager")
    local InputDialog = require("ui/widget/inputdialog")
    local key = headingKey(pfx, card.key)
    local dialog
    local function save(value)
        store():saveSetting(key, Model.normalizeHeading(value))
        UIManager:close(dialog)
        if refresh then refresh() else
            require("screens/sui_homescreen").rebuildLayout({ keep_wallpaper = true })
        end
    end
    dialog = InputDialog:new{
        title = _("Edit heading") .. ": " .. headingLabel(card, pfx),
        description = _("Only changes this dashboard card. Leave empty to use its automatic heading."),
        input = Model.normalizeHeading(store():readSetting(key)) or "",
        input_hint = headingLabel(card, pfx),
        buttons = {
            { { text = _("Restore default"), callback = function() save(nil) end } },
            {
                { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                { text = _("Save"), is_enter_default = true,
                    callback = function() save(dialog:getInputText()) end },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function M.headingItems(refresh, pfx)
    local items = {}
    for i, card in ipairs(Model.heading_cards) do
        local entry = card
        items[i] = {
            text_func = function()
                local value = Model.normalizeHeading(store():readSetting(headingKey(pfx, entry.key)))
                return headingLabel(entry, pfx) .. ": " .. (value or _("Automatic"))
            end,
            keep_menu_open = false,
            callback = function() editHeading(entry, refresh, pfx) end,
        }
    end
    return items
end

function M.isEnabled(pfx)
    return store():readSetting((pfx or "simpleui_hs_") .. M.enabled_key) == true
end

function M.install(registry)
    -- Snapshot old defaults before a newly enabled module can look like an upgrade.
    M.readConfig("simpleui_hs_")
    for _, screen in ipairs(store():readSetting("simpleui_custom_screens") or {}) do
        M.readConfig(screen.pfx)
    end
    if store():readSetting("simpleui_orbitui_dashboard_config_ready") ~= true then
        store():saveSetting("simpleui_orbitui_dashboard_config_ready", true)
    end
    registry.register(M)
end

function M.setHomeEnabled(enabled)
    M.readConfig("simpleui_hs_")
    local Layout = require("screens/sui_settings_window").LayoutService
    local layout = Model.withPage(Layout.load(), enabled)
    -- Also handles a page added through the native module picker.
    store():saveSetting("simpleui_hs_" .. M.enabled_key, enabled == true)
    Layout.save(layout)
    local HS = package.loaded["screens/sui_homescreen"]
    local screen = HS and HS.getInstance and HS.getInstance("hs")
    if screen then screen._current_page = 1 end
    if HS and HS.rebuildLayout then HS.rebuildLayout({ keep_wallpaper = true }) end
end

function M.menuItems(refresh, pfx, ctx_menu)
    pfx = pfx or "simpleui_hs_"
    return {
        { text = _("Show dashboard as first Home page"),
            help_text = _("Adds a separate page. Your existing Home pages and settings are kept."),
            checked_func = function() return M.isEnabled("simpleui_hs_") end,
            callback = function() M.setHomeEnabled(not M.isEnabled("simpleui_hs_")) end },
        { text = _("Dark continue-reading card"),
            checked_func = function() return store():readSetting(pfx .. "orbitui_dashboard_dark") ~= false end,
            callback = function()
                store():saveSetting(pfx .. "orbitui_dashboard_dark",
                    store():readSetting(pfx .. "orbitui_dashboard_dark") == false)
                if refresh then refresh() else
                    require("screens/sui_homescreen").rebuildLayout({ keep_wallpaper = true })
                end
            end },
        { text = _("Headings"), sub_item_table_func = function()
            return M.headingItems(refresh, pfx)
        end },
        { text = _("Cards and content"), sub_item_table_func = function()
            return require("adapters/orbitui_dashboard_settings").items(refresh, pfx, ctx_menu)
        end },
    }
end

function M.getMenuItems(ctx)
    local items = M.menuItems(ctx.refresh, ctx.pfx, ctx)
    table.remove(items, 1) -- Native layout editing owns this module's membership.
    return items
end

function M.wrapWantProvider(provider)
    if provider._orbitui_dashboard_wrapped then return end
    provider._orbitui_dashboard_wrapped = true
    local original = provider.shouldAutoRefreshHome
    provider.shouldAutoRefreshHome = function(pfx, key)
        if original(pfx, key) then return true end
        if not M.isEnabled(pfx) or store():readSetting("simpleui_bookorbit_want_auto_refresh") == false then return false end
        local config = M.readConfig(pfx)
        for _, card in ipairs({ "want", "new" }) do
            if Model.visible(config, card) and Sources.usesBookOrbit(config.sources[card]) then return true end
        end
        return false
    end
end

function M.wrapChrome(chrome)
    if chrome._orbitui_dashboard_wrapped then return end
    chrome._orbitui_dashboard_wrapped = true
    local original = chrome.skipsModuleChrome
    chrome.skipsModuleChrome = function(id)
        return id == M.id or original(id)
    end
end

function M.readData(ctx)
    local config = M.readConfig(ctx.pfx)
    local function visible(id) return Model.visible(config, id) end
    local SH = require("modules/module_books_shared")
    local function read(fp)
        return SH.getBookData(fp, ctx.prefetched and ctx.prefetched[fp], { skip_description = true })
    end
    local fp = ctx.current_fp or (ctx.recent_fps or {})[1]
    local want, want_error, new, new_error = {}, nil, {}, nil
    if visible("want") then want, want_error = Sources.files(config.sources.want, ctx) end
    if visible("new") then new, new_error = Sources.files(config.sources.new, ctx) end
    local goal
    local hc_enabled = config.goal == "hardcover" or config.goal == "auto"
        and store():readSetting((ctx.pfx or "simpleui_hs_") .. "hardcover") == true
    if visible("goal") and hc_enabled then
        local HC = require("modules/module_hardcover")
        local cached = HC._getCached()
        if cached then
            goal = { title = cached.description, value = tonumber(cached.progress) or 0,
                target = tonumber(cached.goal) or 0, source = "Hardcover",
                module = "hardcover", metric = cached.metric or "book" }
        end
        HC.ensureFresh()
    elseif visible("goal") then
        goal = { value = (ctx.stats or {}).books_year or 0,
            target = require("infra/sui_goals").get("annual"),
            module = "reading_goals", metric = "book", source = "KOReader" }
    end
    return {
        current = visible("hero") and fp and { file = fp, data = read(fp) } or nil,
        ongoing = visible("ongoing") and Model.ongoing(visible("hero") and fp or nil, ctx.recent_fps, read, 3) or {},
        want = want, new = new, want_error = want_error, new_error = new_error,
        config = config,
        source_labels = { want = Sources.label(config.sources.want), new = Sources.label(config.sources.new) },
        stats = ctx.stats or {}, goal = goal, hardcover = hc_enabled,
        dark = store():readSetting((ctx.pfx or "simpleui_hs_") .. "orbitui_dashboard_dark") ~= false,
        headings = M.readHeadings(ctx.pfx),
    }
end

function M.getHeight(ctx)
    local UI = require("infra/sui_core")
    local Config = require("infra/sui_config")
    local Screen = require("device").screen
    local screen = ctx and ctx._screen_widget
    local content_h = screen and screen._layout_content_h or UI.getContentHeight()
    local footer_h = Screen:scaleBySize(40)
    if screen then
        for _, footer in pairs({ screen._footer_dot, screen._footer_chevron }) do
            if footer and footer.widget then footer_h = math.max(footer_h, footer.widget:getSize().h) end
        end
    end
    local gap = Config.getModuleGapPx(M.id, ctx and ctx.pfx, UI.MOD_GAP)
    local top_gap = store():readSetting("simpleui_topbar_enabled") == false and UI.MOD_GAP or 0
    return math.max(1, content_h - footer_h - gap - top_gap - Screen:scaleBySize(8))
end

function M.build(w, ctx)
    return require("adapters/orbitui_dashboard_view").build(w, M.getHeight(ctx), ctx, M.readData(ctx))
end

-- These callbacks replace only this module's children. Cached cover buffers
-- remain borrowed by ImageWidget, exactly as in the native Home modules.
function M.updateStats(widget, ctx)
    widget:replaceContent(ctx, M.readData(ctx))
    return true
end

function M.updateCovers(widget)
    return widget:refreshCovers()
end

return M
