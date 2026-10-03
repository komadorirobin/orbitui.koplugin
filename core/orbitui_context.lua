local M = {}
local navigation = 0

function M.plugin(name)
    return require("pluginloader"):getPluginInstance(name)
end

function M.notify(text)
    require("ui/uimanager"):show(require("ui/widget/infomessage"):new{ text = text })
end

function M.refresh(file)
    local shared = package.loaded["modules/module_books_shared"]
    if shared then
        shared.invalidateSidecarCache(file)
        shared.invalidateSeriesCache(file)
    end
    local engine = package.loaded["engines/sui_screen_engine"]
    if engine then engine.invalidateAllCfgAndRefresh(true) end
end

function M.openBook(file)
    navigation = navigation + 1
    -- Keep the normal ReaderUI lifecycle: profile autoexec and the external
    -- BookOrbit/undo-opening hooks see the real file, just as on Home.
    return require("engines/sui_screen_engine").openBook(file)
end

function M.withShelf(profile, action)
    local plugin = M.plugin("bookshelf")
    local function unavailable()
        M.notify(require("core/orbitui_i18n")(
            "Could not open the library. Try again from the library view."))
    end
    if not plugin then unavailable(); return false end
    navigation = navigation + 1
    local request = navigation
    plugin:onOpenBookshelfProfile(profile)
    local UIManager = require("ui/uimanager")
    local attempts = 0
    local function ready()
        if request ~= navigation then return end
        -- A parked reader can replace its plugin during the transition.
        local current = M.plugin("bookshelf")
        local widget = current and current._widget
        if widget and not widget._closed and UIManager:isWidgetShown(widget) then
            -- Hot reader parking may restore a different profile. Switch the
            -- visible shelf explicitly, including nil for the unscoped library.
            if widget.profile_key ~= profile then widget:setProfile(profile) end
            action(widget)
            return
        end
        attempts = attempts + 1
        if attempts < 20 then
            UIManager:scheduleIn(0.05, ready)
        else
            unavailable()
        end
    end
    UIManager:nextTick(ready)
    return true
end

return M
