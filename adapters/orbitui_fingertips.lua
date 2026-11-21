local M = {}
local key = "fingertips_enabled"

function M.attach(ui, loader)
    if not (ui and ui.document and ui.highlight and ui.view and ui.view.registerViewModule)
            or ui._orbitui_fingertips or ui.fingertips or ui.highlight._fingertips_wrapped then return end
    local device = require("device")
    if not (device.isTouchDevice and device:isTouchDevice()) then return end
    -- Reader plugins are instantiated in path order. The enabled class list
    -- is complete even when the standalone instance has not been created yet.
    for _, class in ipairs(loader.enabled_plugins or {}) do
        if class.name == "fingertips" then return end
    end
    local instance = require("orbitui/fingertips/main"):new{ ui = ui }
    ui._orbitui_fingertips = instance
    instance:onReaderReady()
end

function M.detach(ui)
    local instance = ui and ui._orbitui_fingertips
    if instance then
        instance:detach()
        ui._orbitui_fingertips = nil
    end
end

function M.menuItems()
    local _ = require("core/orbitui_i18n")
    local reader = package.loaded["apps/reader/readerui"]
    local ui = reader and reader.instance
    local ft = ui and (ui._orbitui_fingertips or ui.fingertips)
    local function enabled() return G_reader_settings:readSetting(key) ~= false end
    return {
        { text = _("FingerTips text selection"), checked_func = enabled, keep_menu_open = true,
            help_text = _("Show the text above your finger while selecting, then drag the handles to adjust it."),
            callback = function()
                local on = not enabled()
                G_reader_settings:saveSetting(key, on)
                if ft then
                    ft.enabled = on
                    if not on then ft:closeBar(); ft.phase = nil; ft:update() end
                end
            end },
        { text = _("Show or hide selection actions"), enabled_func = function()
                return ft ~= nil and ft.enabled and ft.showArrange ~= nil
            end,
            callback = function() if ft and ft.enabled then ft:showArrange() end end },
    }
end

return M
