package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local device = { isTouchDevice = function() return true end }
package.loaded.device = device
package.loaded.logger = {}
package.loaded["ui/geometry"] = {}
package.loaded["ui/uimanager"] = {}
package.loaded["ui/widget/container/widgetcontainer"] = H.widget()
for _, name in ipairs({ "actions", "bar", "panel" }) do
    package.loaded["orbitui/fingertips/" .. name] = {}
end
package.preload["orbitui/fingertips/main"] = function() return dofile("components/fingertips/main.lua") end
local adapter = require("adapters/orbitui_fingertips")
local reader = {}
package.loaded["apps/reader/readerui"] = reader
local values = { language = "sv" }
G_reader_settings = {
    readSetting = function(_, key) return values[key] end,
    nilOrTrue = function(_, key) return values[key] ~= false end,
    saveSetting = function(_, key, value) values[key] = value end,
}
local loader = { enabled_plugins = {} }
local native = { onHold = function() return "native" end }
local function openReader()
    local ui = { document = {}, highlight = setmetatable({}, { __index = native }),
        view = { view_modules = {}, registerViewModule = function(self, key, widget)
            assert(not self.view_modules[key])
            self.view_modules[key] = widget
        end } }
    reader.instance = ui
    return ui
end

H.test("a standalone instance or enabled class takes priority in either load order", function()
    local ui = openReader()
    adapter.attach(ui, { enabled_plugins = { { name = "fingertips" } } })
    assert(not ui._orbitui_fingertips)
    local external = { enabled = true, showArrange = function(self) self.arranged = true end }
    ui.fingertips = external
    adapter.attach(ui, loader)
    adapter.menuItems()[2].callback()
    adapter.detach(ui)
    assert(external.arranged and external.enabled and not ui._orbitui_fingertips)
end)
H.test("the file browser and non-touch devices skip FingerTips", function()
    adapter.attach({ view = {} }, loader)
    local ui = openReader()
    device.isTouchDevice = function() return false end
    adapter.attach(ui, loader)
    device.isTouchDevice = function() return true end
    assert(not ui._orbitui_fingertips and not ui.highlight._fingertips_wrapped)
end)
H.test("reader lifetime, preferences and newer highlight hooks survive reattachment", function()
    local ui = openReader()
    adapter.attach(ui, loader)
    local ft = assert(ui._orbitui_fingertips)
    adapter.attach(ui, loader)
    assert(ft.enabled and ui.highlight._fingertips_wrapped == ft and ui.view.view_modules.fingertips == ft)
    assert(values.fingertips_enabled == nil)
    local rows = adapter.menuItems()
    H.eq(rows[1].text, "Textmarkering med FingerTips")
    assert(rows[1].checked_func() and rows[2].enabled_func())
    rows[1].callback()
    assert(values.fingertips_enabled == false and not ft.enabled and not rows[2].enabled_func())
    local captured = ui.highlight.onHold
    local outer = function(...) return captured(...) end
    ui.highlight.onHold = outer
    adapter.detach(ui)
    assert(not ui._orbitui_fingertips and not ui.view.view_modules.fingertips and not ui.highlight._fingertips_wrapped)
    assert(ui.highlight.onHold == outer and ui.highlight:onHold() == "native")
    assert(rawget(ui.highlight, "clear") == nil)
    local next_ui = openReader()
    adapter.attach(next_ui, loader)
    assert(next_ui._orbitui_fingertips ~= ft and not next_ui._orbitui_fingertips.enabled)
    adapter.menuItems()[1].callback()
    assert(next_ui._orbitui_fingertips.enabled and values.fingertips_enabled)
end)
H.finish()
