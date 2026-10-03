local M = {}
local Icons = require("core/orbitui_icons")
local _ = require("core/orbitui_i18n")

M.modules = {
    ["infra/sui_config"] = true,
    ["features/sui_style"] = true,
    ["features/sui_quickactions"] = true,
    ["lib/bookshelf_icons_library"] = true,
    ["lib/bookshelf_start_menu_model"] = true,
}

function M.show(on_select, on_cancel, image_only)
    local UIManager = require("ui/uimanager")
    local LibraryModal = require("lib/bookshelf_library_modal")
    local Library = require("lib/bookshelf_icons_library")
    local Screen = require("device").screen
    local state = { group = "all", query = "" }
    local items, key, modal, selected
    local function list()
        local next_key = state.group .. "\0" .. state.query
        if key ~= next_key then
            items, key = Icons.filtered(state.group, state.query), next_key
        end
        return items
    end
    modal = LibraryModal:new{ config = {
        title = "Material Symbols Rounded",
        chip_strip = function()
            local out = {}
            for _, group in ipairs({ "all", "Reading", "Navigation", "System", "Tools" }) do
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
            on_select(image_only and item.file or item.value)
        end,
        footer_actions = { { key = "close", label = _("Cancel"), on_tap = function()
            UIManager:close(modal)
        end } },
        on_closed = function()
            if not selected and on_cancel then UIManager:nextTick(on_cancel) end
        end,
    } }
    UIManager:show(modal)
    return modal
end

function M.wrap(name, module)
    if name == "infra/sui_config" then
        local glyph = module.iconGlyph
        module.iconGlyph = function(value)
            local char, font = Icons.glyph(value)
            if char then return char, font end
            return glyph(value)
        end
    elseif name == "features/sui_style" then
        local safe, register = module.safeIconPath, module.registerTabIconName
        module.safeIconPath = function(path, fallback, slot)
            return safe(Icons.rebaseImage(path) or path, fallback, slot)
        end
        module.registerTabIconName = function(slot, path)
            return register(slot, Icons.imageFile(path) or Icons.rebaseImage(path) or path)
        end
        local list, apply = module.listPacks, module.applyPack
        module.listPacks = function()
            local packs = list()
            table.insert(packs, 1, { name = "Material Symbols Rounded", path = Icons.pack_id, is_zip = false })
            return packs
        end
        module.applyPack = function(path)
            if path ~= Icons.pack_id then return apply(path) end
            local QA = require("features/sui_quickactions")
            local result = { applied = 0, skipped = 0, errors = 0 }
            for id, icon in pairs(Icons.actions) do
                QA.setDefaultActionIcon(id, "material:" .. icon)
                result.applied = result.applied + 1
            end
            for _, slot in ipairs(module.SLOTS) do
                local icon = Icons.slots[slot.id]
                if icon then
                    local value = "material:" .. icon
                    module.setIcon(slot.id, slot.group == "sui_tabbar_icons" and Icons.imageFile(value) or value)
                    result.applied = result.applied + 1
                end
            end
            if module.refreshLiveTabBars then module.refreshLiveTabBars() end
            return result
        end
    elseif name == "features/sui_quickactions" then
        module.extraIconPickers = { {
            text = "Material Symbols Rounded...",
            show = function(current, on_select, on_cancel, allow_font)
                return M.show(on_select, on_cancel, not allow_font)
            end,
        } }
    elseif name == "lib/bookshelf_icons_library" then
        module.extra_sources = { {
            key = "material", label = "Material", requires_svg = true,
            items = Icons.bookshelfCells,
        } }
    elseif name == "lib/bookshelf_start_menu_model" then
        module.imageIconFile = Icons.imageFile
    end
    return module
end

return M
