local M = {}
local Icons = require("core/orbitui_icons")
local _ = require("core/orbitui_i18n")

M.modules = {
    ["features/sui_style"] = true,
    ["features/sui_quickactions"] = true,
    ["lib/bookshelf_icons_library"] = true,
    ["lib/bookshelf_start_menu_model"] = true,
}

local function weightAction(get_weight, set_weight, get_modal)
    return {
        key = "material_weight",
        label_func = function() return _("Line thickness") .. ": " .. get_weight() .. "..." end,
        on_tap = function()
            local UIManager = require("ui/uimanager")
            local ButtonDialog = require("ui/widget/buttondialog")
            local modal = get_modal()
            if not modal then return end
            modal:_dismissKeyboard()
            local labels = { [200] = "Thin", [300] = "Light", [400] = "Regular", [500] = "Medium" }
            local buttons, dialog = {}
            for _i, weight in ipairs(Icons.weights) do
                local chosen_weight = weight
                local label = weight .. " - " .. _(labels[weight])
                if weight == Icons.default_weight then label = label .. " (" .. _("default") .. ")" end
                if weight == get_weight() then label = "\226\156\147 " .. label end
                buttons[#buttons + 1] = { { text = label, callback = function()
                    UIManager:close(dialog)
                    set_weight(chosen_weight)
                    modal:refresh()
                end } }
            end
            buttons[#buttons + 1] = { { text = _("Cancel"), callback = function()
                UIManager:close(dialog)
            end } }
            dialog = ButtonDialog:new{ title = _("Material icon line thickness"), buttons = buttons }
            UIManager:show(dialog)
        end,
    }
end

function M.show(on_select, on_cancel, current)
    local UIManager = require("ui/uimanager")
    local LibraryModal = require("lib/bookshelf_library_modal")
    local Library = require("lib/bookshelf_icons_library")
    local Screen = require("device").screen
    local entry = Icons.entry(current)
    local state = { group = "all", query = "", weight = entry and entry.weight or Icons.default_weight }
    local items, key, modal, selected
    local function list()
        local next_key = state.group .. "\0" .. state.query .. "\0" .. state.weight
        if key ~= next_key then
            items, key = Icons.filtered(state.group, state.query, state.weight), next_key
        end
        return items
    end
    modal = LibraryModal:new{ config = {
        title = "Material Symbols Rounded",
        chip_strip = function()
            local out = {}
            for _i, group in ipairs({ "all", "Reading", "Navigation", "System", "Tools" }) do
                out[#out + 1] = { key = group, label = _(group == "all" and "All" or group),
                    is_active = state.group == group }
            end
            return out
        end,
        on_chip_tap = function(group) state.group = group end,
        search_placeholder = function() return _("Search icons (e.g. manga)") end,
        on_search_submit = function(query) state.query = query or "" end,
        grid_cols = function() return Screen:getWidth() > Screen:getHeight() and 5 or 4 end,
        cells_per_page = function() return Screen:getWidth() > Screen:getHeight() and 15 or 16 end,
        item_count = function() return #list() end,
        item_at = function(i) return list()[i] end,
        cell_renderer = Library._renderCell,
        cell_long_tap = Library._showCellTooltip,
        on_cell_tap = function(item)
            selected = true
            UIManager:close(modal)
            on_select(item.file)
        end,
        footer_actions = { { key = "close", label = _("Cancel"), on_tap = function()
            UIManager:close(modal)
        end }, weightAction(function() return state.weight end, function(weight)
            state.weight = weight
        end, function() return modal end) },
        on_closed = function()
            if not selected and on_cancel then UIManager:nextTick(on_cancel) end
        end,
    } }
    UIManager:show(modal)
    return modal
end

function M.wrap(name, module)
    if name == "features/sui_style" then
        local safe, register = module.safeIconPath, module.registerTabIconName
        module.safeIconPath = function(path, fallback, slot)
            return safe(Icons.imageFile(path) or Icons.rebaseImage(path) or path, fallback, slot)
        end
        module.registerTabIconName = function(slot, path)
            return register(slot, Icons.imageFile(path) or Icons.rebaseImage(path) or path)
        end
        local apply = module.applyPack
        module.applyPack = function(path)
            -- Reject stale callers too: Material is a picker source, never a preset.
            if path == Icons.legacy_pack_id then
                return { applied = 0, skipped = 0, errors = 1 }
            end
            return apply(path)
        end
    elseif name == "features/sui_quickactions" then
        module.extraIconPickers = { {
            text = "Material Symbols Rounded...",
            show = function(current, on_select, on_cancel)
                return M.show(on_select, on_cancel, current)
            end,
        } }
    elseif name == "lib/bookshelf_icons_library" then
        module.extra_sources = { {
            key = "material", label = "Material", requires_svg = true,
            items = Icons.bookshelfCells,
        } }
        module.configurePicker = function(config, opts, get_modal)
            if not opts.svg then return end
            local entry = Icons.entry(opts.current_icon)
            local weight = entry and entry.weight or Icons.default_weight
            local item_at = config.item_at
            config.item_at = function(i)
                local item = item_at(i)
                return item and (Icons.forWeight(item.icon, weight) or item)
            end
            config.footer_actions[#config.footer_actions + 1] = weightAction(
                function() return weight end, function(value) weight = value end, get_modal)
        end
    elseif name == "lib/bookshelf_start_menu_model" then
        module.imageIconFile = Icons.imageFile
    end
    return module
end

return M
