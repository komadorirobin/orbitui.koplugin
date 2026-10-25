-- sui_screen_nav.lua — Simple UI
-- Leaving the open screen (the built-in Homescreen or a Custom Screen) for
-- another view and coming back to it.
--
-- A screen closed on purpose keeps its cached state (current page, books), so
-- reopening it is a warm start instead of a cold rebuild.
--
-- Public API
-- ----------
--   ScreenNav.handOff(open) -> id?
--       Runs `open`, which shows a widget that closes the open screen by
--       itself, and keeps the screen's state. Returns the id of that screen,
--       nil when none is open.
--   ScreenNav.close()       -> id?
--       Closes the open screen, keeping its state. Returns its id.
--   ScreenNav.reopen(id)
--       Shows the screen `id` again.

local UIManager = require("ui/uimanager")
local UI        = require("infra/sui_core")
local logger    = require("logger")
local _         = require("infra/sui_i18n").translate

local ScreenNav = {}
local first_load_error

local function traceback(err)
    return debug.traceback(tostring(err), 2)
end

local function reportHomeError(stage, err)
    local details = tostring(err)
    logger.err("simpleui: Home " .. stage .. " failed:\n" .. details)
    -- Keep the first real error readable on-device; full traces stay in the
    -- log. Reporting must not create a second uncaught UI error.
    local summary = (details:match("^[^\n]+") or details):sub(1, 1000)
    local ok, failure = pcall(function()
        UIManager:show(require("ui/widget/infomessage"):new{
            text = _("Homescreen not available.") .. "\n\n" .. summary,
            _navbar_closing_intentionally = true,
        })
    end)
    if not ok then logger.err("simpleui: Home error notification failed: " .. tostring(failure)) end
end

-- Shared by boot/resume, reader return and the Home action. Do not discard a
-- failed require's actual error behind a generic unavailable message. LuaJIT
-- can retain a failed-load sentinel; keep its original cause until a successful
-- load, without purging other plugins' modules or altering settings.
function ScreenNav.loadHome()
    local names = { "screens/sui_homescreen", "engines/sui_screen_engine" }
    local before = {}
    for _, name in ipairs(names) do before[name] = package.loaded[name] end
    local ok, home = xpcall(function() return require("screens/sui_homescreen") end, traceback)
    if ok and type(home) == "table" and type(home.show) == "function" then
        first_load_error = nil
        return home
    end
    -- A new failed-load sentinel is not a screen (LuaJIT can expose it as a
    -- number). Leaving it here makes package.loaded observers crash on wake/
    -- return. Only restore absent entries for these two table-valued owned
    -- modules, never valid tables, pre-existing values or third-party state.
    if not ok then
        for _, name in ipairs(names) do
            if not before[name] and type(package.loaded[name]) ~= "table" then
                package.loaded[name] = before[name]
            end
        end
    end
    if ok then home = "Home module does not provide show()" end
    first_load_error = first_load_error or home
    reportHomeError("load", first_load_error)
end

-- The built-in Home keeps the engine's public table identity. Protect its
-- factory and first-run hook at that facade so every caller gets the same
-- behavior, including scheduled startup/reader-return calls.
function ScreenNav.openHome(engine, config, on_qa_tap, on_goal_tap)
    local previous = engine._instance
    local ok, result = xpcall(function()
        return engine._open(config, on_qa_tap, on_goal_tap)
    end, traceback)
    if ok then return result end
    local partial = engine._instance
    if partial and partial ~= previous then
        -- Closing this failed destination must not schedule another Home.
        partial._navbar_closing_intentionally = true
        pcall(UIManager.close, UIManager, partial)
        if engine._instance == partial then engine._instance = nil end
    end
    reportHomeError("open", result)
end

function ScreenNav.handOff(open)
    local id, screen = UI.getOpenScreen()
    if screen then screen._navbar_closing_intentionally = true end
    open()
    if screen then screen._navbar_closing_intentionally = nil end
    return id
end

function ScreenNav.close()
    local _id, screen = UI.getOpenScreen()
    if not screen then return nil end
    return ScreenNav.handOff(function() pcall(UIManager.close, UIManager, screen) end)
end

-- The built-in Homescreen and the Custom Screens share one engine table,
-- which exposes both ways of showing a screen.
function ScreenNav.reopen(id)
    local ScreenEngine = ScreenNav.loadHome()
    if not ScreenEngine then return end
    if id == "hs" then
        ScreenEngine.show()
    elseif ScreenEngine.showCustomScreen then
        ScreenEngine.showCustomScreen(id)
    end
end

return ScreenNav
