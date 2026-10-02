local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local Guard = require("core/orbitui_guard")
local Runtime = require("core/orbitui_runtime")
local Host = require("core/orbitui_host")
local root = assert(debug.getinfo(1, "S").source:match("^@(.+)/core/orbitui_plugin%.lua$"))
local Updates = require("adapters/orbitui_updates")

local OrbitUI = WidgetContainer:extend{ name = "orbitui", is_doc_only = false }
local startup_error

-- Install the resolver during discovery: plugins such as MyAnimeList may
-- require Bookshelf helpers before OrbitUI's instance is initialized.
local ok, err = pcall(function()
    local allowed, reason = Guard.check()
    assert(allowed, reason)
    require("core/orbitui_backup").ensure()
    Runtime.install(root)
end)
if not ok then startup_error = tostring(err) end

function OrbitUI:notify(message)
    UIManager:show(require("ui/widget/infomessage"):new{ text = message })
end

function OrbitUI:init()
    self.ui.menu:registerToMainMenu(self)
    local ready, failure = pcall(function()
        assert(not startup_error, startup_error)
        local allowed, reason = Guard.check(self.ui)
        assert(allowed, reason)
        Host.attach(self, Runtime.classes(root), require("pluginloader"), root)
        UIManager:nextTick(function() Updates.started() end)
    end)
    if not ready then
        Host.abort(self, require("pluginloader"))
        self._orbitui_error = tostring(failure)
        logger.err("OrbitUI initialization failed:", self._orbitui_error)
        UIManager:nextTick(function()
            self:notify("OrbitUI could not start.\n\n" .. self._orbitui_error
                .. "\n\nDisable OrbitUI and restart before returning to the standalone plugins.")
        end)
    end
end

function OrbitUI:propagateEvent(event)
    return Host.propagate(self, event, function(name, failure)
        logger.err("OrbitUI component handler failed:", name, event.handler, failure)
    end)
end

function OrbitUI:onTeardown()
    Host.detach(self, require("pluginloader"))
end

function OrbitUI:addToMainMenu(items)
    items.orbitui = {
        text = "OrbitUI",
        sub_item_table = {
            {
                text = "About this experimental build",
                callback = function()
                    self:notify("OrbitUI " .. require("orbitui_bootstrap").version(root)
                        .. "\n\nBookshelf 5.2.2.3 + SimpleUI 2.7.2-beta.5"
                        .. "\n\nPreview build. Existing navigation is retained."
                        .. "\nSettings snapshot: settings/orbitui/before-first-run/"
                        .. (self._orbitui_error and ("\n\nStartup error: " .. self._orbitui_error) or ""))
                end,
            },
            { text = "OrbitUI updates", callback = Updates.show },
        },
    }
end

return OrbitUI
