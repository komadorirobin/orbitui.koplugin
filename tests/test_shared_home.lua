package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local data, registry, queries, paths, custom = {}, {}, {}, {}, {}
local key = "simpleui_orbitui_home_shelves"
local Store = { readSetting = function(_, k) return data[k] end,
    saveSetting = function(_, k, value) data[k] = value end }
package.loaded["infra/sui_store"] = Store
local Query = { resolve = function(ref) return queries[ref.chip], "missing" end,
    paths = function(ref) return paths[ref.chip] or {} end }
package.loaded["core/orbitui_shelf_query"] = Query
local refreshes, nav = 0
package.loaded["core/orbitui_context"] = {
    refresh = function() refreshes = refreshes + 1 end,
    notify = function() end,
    withShelf = function(profile, fn)
        fn({ _selectChip = function(_, chip) nav = { profile, chip } end })
    end,
}
local Layout = {
    load = function() return data.simpleui_layout end,
    save = function(value) data.simpleui_layout = value end,
    entryId = function(e) return type(e) == "table" and e.id or e end,
}
package.loaded["screens/sui_settings_window"] = { LayoutService = Layout }
package.loaded["infra/sui_custom_screens"] = { list = function() return custom end }
package.loaded["modules/moduleregistry"] = {
    register = function(m) registry[m.id] = m end,
    unregister = function(id) registry[id] = nil end,
}
package.loaded["engines/sui_book_grid"] = { makeModule = function(spec)
    return { id = spec.id, spec = spec, build = function(_, ctx) return { files = spec.getFileList(ctx) } end }
end }
package.loaded["modules/module_coverdeck"] = {
    build = function(_, ctx) return { ctx = ctx, files = ctx.orbitui_files() } end,
    getHeight = function() return 120 end,
    updateCovers = function() return true end,
}
package.loaded["ui/widget/textboxwidget"] = H.widget()
package.loaded["ui/font"] = { getFace = function() return {} end }
package.loaded["infra/sui_config"] = {
    makeCoverHoldModeItem = function(opts) return opts end,
    applyLabelToggle = function(mod, label) mod.label = label end,
}
local Shelves = require("adapters/orbitui_home_shelves")
local initial = { pages = { { id = "existing", modules = {
    { id = "coverdeck", width = 0.5 }, { id = "currently", width = 0.5 }, "reading_goal",
} } }, custom_option = "preserve" }
data.simpleui_layout = initial
data.simpleui_hs_coverdeck_enabled = true
data.simpleui_hs_coverdeck_collection = "My TBR"
queries.fiction = { label = "Fiction" }
queries.next = { label = "Next volume" }
local first, second
H.test("pinning creates an isolated page without overwriting the current Bento layout", function()
    first = assert(Shelves.pin({ profile = "prose", chip = "fiction" }, "row"))
    H.eq(#data.simpleui_layout.pages, 2)
    H.eq(#initial.pages, 1)
    H.eq(data.simpleui_layout.pages[1].modules[1].width, 0.5)
    H.eq(data.simpleui_layout.pages[1].modules[3], "reading_goal")
    H.eq(data.simpleui_layout.custom_option, "preserve")
    H.eq(data.simpleui_hs_coverdeck_collection, "My TBR")
    H.eq(data.simpleui_hs_coverdeck_enabled, true)
    H.eq(registry[first.id].spec.default_on, false)
end)
H.test("pinning the same shelf changes its mode without duplicates", function()
    local pin, existing = Shelves.pin(first.ref, "carousel")
    H.eq(pin.id, first.id); H.eq(existing, true)
    H.eq(#Shelves.list(), 1); H.eq(#data.simpleui_layout.pages, 2)
    H.eq(data[key][1].mode, "carousel")
    first = pin
end)
H.test("adding another profile shelf gets a stable independent module id", function()
    second = assert(Shelves.pin({ profile = "comics", chip = "next" }, "carousel"))
    assert(first.id ~= second.id)
    H.eq(#data.simpleui_layout.pages, 3)
    H.eq(data[key][2].ref.chip, "next")
    H.eq(data[key][2].ref.files, nil)
end)
H.test("pin references and modules survive restart and resolve changed membership", function()
    registry = {}
    package.loaded["adapters/orbitui_home_shelves"] = nil
    Shelves = require("adapters/orbitui_home_shelves")
    Shelves.install(package.loaded["modules/moduleregistry"])
    assert(registry[first.id] and registry[second.id])
    paths.fiction = { "/new-book" }
    H.eq(registry[first.id].spec.getFileList()[1], "/new-book")
    paths.fiction = { "/other-book" }
    H.eq(registry[first.id].spec.getFileList()[1], "/other-book")
    queries.fiction.label = "Renamed shelf"
    H.eq(registry[first.id].spec.label_fn(), "Renamed shelf")
end)
H.test("two cover carousels retain independent positions and never move the existing TBR deck", function()
    paths.next = { "/volume-2" }
    local refreshed
    local ctx = { coverdeck_cur_idx = 7, coverdeck_center_stats = "old",
        _screen_widget = { _refreshBookModSlot = function(_, id) refreshed = id; return true end } }
    local a = registry[first.id].build(500, ctx)
    local b = registry[second.id].build(500, ctx)
    assert(a.ctx.pfx ~= b.ctx.pfx)
    H.eq(a.ctx.orbitui_module_id, first.id)
    H.eq(a.ctx.coverdeck_center_stats, nil)
    a.ctx.orbitui_set_index(3)
    H.eq(refreshed, first.id)
    H.eq(registry[first.id].build(500, ctx).ctx.coverdeck_cur_idx, 3)
    H.eq(registry[second.id].build(500, ctx).ctx.coverdeck_cur_idx, 1)
    H.eq(ctx.coverdeck_cur_idx, 7)
    H.eq(data.simpleui_hs_coverdeck_collection, "My TBR")
end)
H.test("empty or deleted shelves do not fall back to unrelated recently opened books", function()
    paths.fiction = {}
    H.eq(registry[first.id].build(500, {}).text, "This shelf has no books.")
    queries.fiction = nil
    H.eq(registry[first.id].build(500, {}).text, "This shelf is no longer available.")
    queries.fiction = { label = "Fiction" }
end)
H.test("source errors leave a safe empty placeholder", function()
    local saved, warnings = Query.paths, 0
    Query.paths = function() error("broken source") end
    package.loaded.logger = { warn = function() warnings = warnings + 1 end }
    assert(registry[first.id].build(500, {}).text)
    H.eq(warnings, 1)
    Query.paths = saved
end)
H.test("shelf settings reflect mode changes and opening navigates to the correct profile", function()
    local items = Shelves.menuItems()
    H.eq(items[1].sub_item_table[3].checked_func(), true)
    items[1].sub_item_table[2].callback()
    H.eq(items[1].sub_item_table[2].checked_func(), true)
    H.eq(items[1].sub_item_table[3].checked_func(), false)
    items[2].sub_item_table[1].callback()
    H.eq(nav[1], "comics"); H.eq(nav[2], "next")
end)
H.test("unpin removes only its own module and empty generated page", function()
    H.eq(Shelves.remove(first.id), true)
    H.eq(#data.simpleui_layout.pages, 2)
    H.eq(data.simpleui_layout.pages[1].id, "existing")
    H.eq(#data.simpleui_layout.pages[1].modules, 3)
    H.eq(registry[first.id], nil)
    H.eq(#data[key], 1)
    H.eq(Shelves.remove("not-there"), false)
end)
H.test("unpinning on Home preserves a module used on a Custom Screen", function()
    custom = { { layout_key = "custom_layout" } }
    data.custom_layout = { pages = { { id = "mine", modules = { second.id } } } }
    H.eq(Shelves.remove(second.id), true)
    H.eq(#data.simpleui_layout.pages, 1)
    H.eq(data.custom_layout.pages[1].modules[1], second.id)
    assert(registry[second.id])
    H.eq(#data[key], 1)
    local again, existing = Shelves.pin(second.ref, "row")
    H.eq(again.id, second.id); H.eq(existing, false)
    H.eq(#data.simpleui_layout.pages, 2)
end)
H.test("returned pin tables cannot mutate persisted settings", function()
    local list = Shelves.list()
    list[1].ref.chip = "broken"
    H.eq(Shelves.list()[1].ref.chip, "next")
end)
H.test("native Cover Deck honors an empty OrbitUI source without its usual fallback", function()
    local f = assert(io.open("components/simpleui/modules/module_coverdeck.lua"))
    local source = f:read("*a"); f:close()
    local body = assert(source:match("local function getFps%(source, ctx%)\n(.-)\nend\n"))
    local code = "return function(source, ctx)\n" .. body .. "\nend"
    local loader = loadstring or load
    local getFps = assert(loader(code))()
    -- No fallback helpers exist in this test environment: calling one fails.
    H.eq(#getFps("recent", { orbitui_files = function() return {} end }), 0)
    H.eq(getFps("recent", { orbitui_files = function() return { "/only" } end })[1], "/only")
end)
H.finish()
