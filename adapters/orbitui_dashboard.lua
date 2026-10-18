-- Opt-in Home page. It reads the existing providers, never replaces their data.
local Model = require("core/orbitui_dashboard")
local _ = require("core/orbitui_i18n")
local M = {
    id = Model.id, name = _("Reading dashboard"), default_on = false,
    enabled_key = "orbitui_dashboard_enabled", owns_chrome = true,
    has_covers = true, is_book_mod = true,
    needs = { recent = 30, stats = true, books = true },
}

local function store() return require("infra/sui_store") end

function M.isEnabled(pfx)
    return store():readSetting((pfx or "simpleui_hs_") .. M.enabled_key) == true
end

function M.install(registry)
    registry.register(M)
end

function M.setHomeEnabled(enabled)
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

function M.menuItems(refresh, pfx)
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
    }
end

function M.getMenuItems(ctx)
    local items = M.menuItems(ctx.refresh, ctx.pfx)
    table.remove(items, 1) -- Native layout editing owns this module's membership.
    return items
end

function M.wrapWantProvider(provider)
    if provider._orbitui_dashboard_wrapped then return end
    provider._orbitui_dashboard_wrapped = true
    local original = provider.shouldAutoRefreshHome
    provider.shouldAutoRefreshHome = function(pfx, key)
        return original(pfx, key) or (M.isEnabled(pfx)
            and store():readSetting("simpleui_bookorbit_want_auto_refresh") ~= false)
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

local function safeList(fn)
    local ok, files = pcall(fn)
    if ok and type(files) == "table" then return files end
    require("logger").warn("OrbitUI dashboard: book source unavailable")
    return {}, true
end

function M.readData(ctx)
    local SH = require("modules/module_books_shared")
    local function read(fp)
        return SH.getBookData(fp, ctx.prefetched and ctx.prefetched[fp], { skip_description = true })
    end
    local fp = ctx.current_fp or (ctx.recent_fps or {})[1]
    local want, want_error = safeList(function()
        return require("integrations/sui_bookorbit_want").getCachedFiles()
    end)
    local new, new_error = safeList(function()
        local source = require("engines/sui_book_sources").bind("new_books")
        local result = {}
        for _, file in ipairs(source.getFileList(ctx)) do
            if not source.filterItem or source.filterItem(file, ctx) then result[#result + 1] = file end
        end
        return result
    end)
    local goal
    local hc_enabled = store():readSetting((ctx.pfx or "simpleui_hs_") .. "hardcover") == true
    if hc_enabled then
        local HC = require("modules/module_hardcover")
        local cached = HC._getCached()
        if cached then
            goal = { title = cached.description, value = tonumber(cached.progress) or 0,
                target = tonumber(cached.goal) or 0, source = "Hardcover",
                module = "hardcover", metric = cached.metric or "book" }
        end
        HC.ensureFresh()
    else
        goal = { value = (ctx.stats or {}).books_year or 0,
            target = require("infra/sui_goals").get("annual"),
            module = "reading_goals", metric = "book", source = "KOReader" }
    end
    return {
        current = fp and { file = fp, data = read(fp) } or nil,
        ongoing = Model.ongoing(fp, ctx.recent_fps, read, 3),
        want = want, new = new, want_error = want_error, new_error = new_error,
        stats = ctx.stats or {}, goal = goal, hardcover = hc_enabled,
        dark = store():readSetting((ctx.pfx or "simpleui_hs_") .. "orbitui_dashboard_dark") ~= false,
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
