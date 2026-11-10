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
    local _backup, existing_host = require("core/orbitui_backup").ensure()
    require("adapters/orbitui_setup").prepare(existing_host)
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
        require("adapters/orbitui_setup").started(self)
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
    require("adapters/orbitui_setup").stopped(self)
    Host.detach(self, require("pluginloader"))
end

function OrbitUI:onReaderReady()
    if self._orbitui_error or not self.ui.document then return end
    require("adapters/orbitui_book_panel").readerPins().attach(self.ui)
    local Dispatcher = require("dispatcher")
    local _ = require("core/orbitui_i18n")
    Dispatcher:registerAction("orbitui_reader_pins", { category = "none", event = "OrbitUIReaderPins",
        title = _("OrbitUI: pinned references"), reader = true })
    Dispatcher:registerAction("orbitui_pin_page", { category = "none", event = "OrbitUIPinPage",
        title = _("OrbitUI: pin current page"), reader = true })
end

function OrbitUI:onOrbitUIReaderPins()
    if not self._orbitui_error and self.ui.document then
        require("adapters/orbitui_book_panel").readerPins().show(self.ui)
    end
end

function OrbitUI:onOrbitUIPinPage()
    if not self._orbitui_error and self.ui.document then
        require("adapters/orbitui_book_panel").readerPins().pin(self.ui)
    end
end

function OrbitUI:addToMainMenu(items)
    items.orbitui = {
        text = "OrbitUI",
        sub_item_table = {
            {
                text = require("core/orbitui_i18n")("OrbitUI settings"),
                callback = function() require("adapters/orbitui_settings").show() end,
            },
            {
                text = "About this experimental build",
                callback = function()
                    self:notify("OrbitUI " .. require("orbitui_bootstrap").version(root)
                        .. "\n\nBookshelf 6.0.0 + SimpleUI 3.0"
                        .. "\n\nPreview build. Existing navigation is retained."
                        .. "\nSettings snapshot: settings/orbitui/before-first-run/"
                        .. (self._orbitui_error and ("\n\nStartup error: " .. self._orbitui_error) or ""))
                end,
            },
            { text = Updates.menuLabel, callback = Updates.show },
        },
    }
    if not self._orbitui_error and self.ui.document then
        local _ = require("core/orbitui_i18n")
        items.orbitui_reader_pins = { text = _("Pinned references"), sorting_hint = "tools",
            sub_item_table = {
                { text = _("Open reference drawer"), callback = function() self:onOrbitUIReaderPins() end },
                { text = _("Reference list"), callback = function()
                    require("adapters/orbitui_book_panel").readerPins().list(self.ui)
                end },
                { text = _("Pin current page"), callback = function() self:onOrbitUIPinPage() end },
                { text = _("Pin an EPUB image…"), enabled = self.ui.rolling ~= nil,
                    callback = function() require("adapters/orbitui_book_panel").readerPins().armImage(self.ui) end },
            } }
    end
end

return OrbitUI
