package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_dashboard")
local Sources = require("adapters/orbitui_dashboard_sources")
local Config = require("adapters/orbitui_dashboard_settings")
local Dashboard = require("adapters/orbitui_dashboard")
local saved, updates, shown = {}, 0
local home, custom = "simpleui_hs_", "simpleui_cs_test_"
local function key(pfx) return pfx .. "orbitui_dashboard_config" end
package.loaded["infra/sui_store"] = {
    readSetting = function(_, k) return saved[k] end,
    saveSetting = function(_, k, v) saved[k] = v end,
}
package.loaded["screens/sui_homescreen"] = { rebuildLayout = function() updates = updates + 1 end }
package.loaded["logger"] = { warn = function() end }
local Widget = H.widget()
package.loaded["ui/widget/sortwidget"] = Widget
package.loaded["ui/widget/confirmbox"] = Widget
package.loaded["ui/uimanager"] = { show = function(_, dialog) shown = dialog end }
local native_reads, remote_reads, goal_reads, book_reads = 0, 0, 0, 0
package.loaded["modules/module_books_shared"] = { getBookData = function(fp)
    book_reads = book_reads + 1
    return { title = fp, percent = .5 }
end }
package.loaded["integrations/sui_bookorbit_want"] = { getCachedFiles = function()
    remote_reads = remote_reads + 1; return { "/remote" }
end }
package.loaded["modules/module_hardcover"] = {
    _getCached = function() goal_reads = goal_reads + 1; return { goal = 100, progress = 4 } end,
    ensureFresh = function() goal_reads = goal_reads + 1 end,
}
package.loaded["infra/sui_goals"] = { get = function() return 50 end }
package.loaded["engines/sui_book_sources"] = {
    bind = function(id, params)
        native_reads = native_reads + 1
        return { getFileList = function(ctx)
            if id == "collection" then return { "/" .. params(ctx).coll } end
            return { "/" .. id, "/" .. id, "/hidden", { filepath = "/not-a-file" }, "OPDS://remote" }
        end, filterItem = function(fp) return fp ~= "/hidden" end }
    end,
    listCollectionNames = function() return { "Private", "Favorites" } end,
}
package.loaded["readcollection"] = { coll = { Private = {}, Favorites = {} } }
local sections = {{ key = "local", label = "My library", chips = {
    { key = "chosen", label = "Custom shelf", kind = "folder", source = { kind = "folder", id = "/library" } },
    { key = "remote", label = "Remote", kind = "bookorbit_want", source = { kind = "bookorbit_want" } },
} }}
local profiles = {
    list = function() return sections end,
    get = function(id) for _, p in ipairs(sections) do if p.key == id then return p end end end,
    chip = function(p, id) for _, c in ipairs(p and p.chips or {}) do if c.key == id then return c end end end,
    folderSortPriority = function() return { "title" } end,
    scope = function() return { roots = { "/library" } } end,
}
package.loaded["lib/bookshelf_profiles"] = profiles
local tabs = {
    { id = "valid", label = "Recent shelf", source = { kind = "recent" } },
    { id = "catalog", label = "Catalog", source = { kind = "opds" } },
    { id = "groups", label = "Groups", source = { kind = "shelves" } },
}
package.loaded["lib/bookshelf_tab_model"] = {
    load = function() return tabs end,
    getById = function(id) for _, t in ipairs(tabs) do if t.id == id then return t end end end,
}
package.loaded["lib/bookshelf_book_repository"] = { getBySource = function(source, filter, sort, offset, limit, scope, opts)
    H.eq(source.kind, "folder_flat"); H.eq(source.id, "/library")
    H.eq(sort[1], "title"); H.eq(scope.roots[1], "/library"); H.eq(opts.light_only, true)
    return {{ filepath = "/library/book" }, { books = {{ filepath = "/library/series1" }} }}
end }

H.test("old Home and Custom Screen dashboards migrate once without changing headings or layout", function()
    saved[home .. "orbitui_dashboard_enabled"], saved[custom .. "orbitui_dashboard_enabled"] = true, true
    saved.disabled_orbitui_dashboard_enabled = false
    saved.simpleui_custom_screens = {{ pfx = custom }, { pfx = "disabled_" }}
    saved[home .. "orbitui_dashboard_heading_want"] = "My own label"
    saved[home .. "orbitui_dashboard_dark"] = false
    local layout = { pages = { { modules = { Model.id, "quote" } } } }
    saved.simpleui_layout = layout
    Dashboard.install({ register = function(m) H.eq(m.id, Model.id) end })
    H.eq(Dashboard.readConfig(home).sources.want.kind, "bookorbit")
    H.eq(Dashboard.readConfig(custom).sources.want.kind, "bookorbit")
    H.eq(Dashboard.readConfig("disabled_").sources.want.kind, "bookorbit")
    H.eq(saved.simpleui_layout, layout)
    H.eq(saved[home .. "orbitui_dashboard_heading_want"], "My own label")
    H.eq(saved[home .. "orbitui_dashboard_dark"], false)
    local config = Dashboard.readConfig(home)
    config.order[1] = "new"
    H.eq(Dashboard.readConfig(home).order[1], "hero")
    local again = dofile("adapters/orbitui_dashboard.lua")
    again.install({ register = function() end })
    H.eq(again.readConfig(home).sources.want.kind, "bookorbit")
end)

H.test("fresh screens use local TBR even when enabled via the native picker", function()
    local pfx = "simpleui_cs_new_"
    saved[pfx .. "orbitui_dashboard_enabled"] = true
    H.eq(Dashboard.readConfig(pfx).sources.want.id, "tbr")
    H.eq(Dashboard.readConfig(pfx).sources.new.id, "new_books")
    H.eq(Dashboard.headingItems(nil, pfx)[8].text_func(), "To Be Read: Automatic")
    local data = Dashboard.readData({ pfx = pfx })
    H.eq(data.want[1], "/tbr"); H.eq(data.source_labels.want, "To Be Read")
    H.eq(remote_reads, 0)
end)

H.test("clean registration creates a local Home dashboard without enabling or replacing any page", function()
    local previous = saved
    saved = {}
    Dashboard.install({ register = function() end })
    H.eq(Dashboard.readConfig(home).sources.want.id, "tbr")
    H.eq(saved.simpleui_hs_orbitui_dashboard_enabled, nil)
    H.eq(saved.simpleui_layout, nil)
    H.eq(saved.simpleui_orbitui_dashboard_config_ready, true)
    saved = previous
end)

H.test("layout config normalizes duplicates and unknown keys without mutating its input", function()
    local raw = { version = 1, order = { "new", "oops", "new" }, stats_order = { "week", "week" },
        hidden = { new = true, hero = "false" }, sources = { want = false } }
    local c = Model.config(raw)
    H.eq(c.order[1], "new"); H.eq(c.order[2], "hero"); H.eq(#c.order, 6)
    H.eq(c.stats_order[1], "week"); H.eq(#c.stats_order, 4)
    H.eq(c.hidden.new, true); H.eq(c.hidden.hero, nil)
    H.eq(c.sources.want.kind, "unavailable"); H.eq(raw.order[2], "oops")
    local future = { version = 99, secret = "keep" }
    saved[key("future_")] = future
    H.eq(Dashboard.readConfig("future_").unsupported, true)
    H.eq(Dashboard.editConfig("future_", function() error("must not edit") end), false)
    H.eq(saved[key("future_")], future)
end)

H.test("all visibility combinations reflow without overlap for reordered and rotated layouts", function()
    for mask = 0, 511 do
        local c = Model.config()
        for i, card in ipairs(Model.heading_cards) do c.hidden[card.key] = math.floor(mask / 2 ^ (i - 1)) % 2 == 1 end
        for shift = 0, 5 do
            for i = 1, 6 do c.order[i] = Model.block_order[(i + shift - 1) % 6 + 1] end
            c.stats_order = { "week", "reading_today", "pages_today", "streak" }
            for _, size in ipairs({ { 600, 730 }, { 300, 400 }, { 800, 480 } }) do
                local p = Model.plan(size[1], size[2], c)
                local cards = {}
                for id, r in pairs(p.cards) do
                    H.eq(c.hidden[id], false)
                    assert(r.w > 0 and r.h > 0 and r.x >= 0 and r.y >= p.header_h)
                    assert(r.x + r.w <= p.w and r.y + r.h <= p.h)
                    cards[#cards + 1] = r
                end
                for _, card in ipairs(Model.heading_cards) do H.eq(p.cards[card.key] ~= nil, not c.hidden[card.key]) end
                for i, a in ipairs(cards) do
                    for j = i + 1, #cards do
                        local b = cards[j]
                        assert(a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y)
                    end
                end
            end
        end
    end
end)

H.test("hiding cards avoids source and metadata reads and hiding hero keeps current in ongoing", function()
    local pfx = "isolated_"
    Dashboard.editConfig(pfx, function(c)
        for _, card in ipairs(Model.heading_cards) do c.hidden[card.key] = true end
        c.sources.want = { kind = "bookorbit" }; c.goal = "hardcover"
    end)
    local before = { native_reads, remote_reads, goal_reads, book_reads }
    local ctx = { pfx = pfx, current_fp = "/current", recent_fps = { "/current", "/other" } }
    local data = Dashboard.readData(ctx)
    H.eq(native_reads, before[1]); H.eq(remote_reads, before[2]); H.eq(goal_reads, before[3]); H.eq(book_reads, before[4])
    H.eq(data.current, nil); H.eq(#data.ongoing, 0); H.eq(data.goal, nil)
    Dashboard.editConfig(pfx, function(c) c.hidden.ongoing = nil end)
    data = Dashboard.readData(ctx)
    H.eq(data.ongoing[1].file, "/current")
end)

H.test("native and collection bindings preserve order and filters and fail closed if deleted", function()
    local paths = Sources.files({ kind = "native", id = "new_books" }, {})
    H.eq(#paths, 1); H.eq(paths[1], "/new_books")
    paths = Sources.files({ kind = "native", id = "collection", coll = "Private" }, {})
    H.eq(paths[1], "/Private")
    package.loaded["readcollection"].coll.Private = nil
    local err
    paths, err = Sources.files({ kind = "native", id = "collection", coll = "Private" }, {})
    H.eq(#paths, 0); H.eq(err, true)
    paths, err = Sources.files({ kind = "native", id = "nonexistent" }, {})
    H.eq(#paths, 0); H.eq(err, true)
end)

H.test("saved shelf sources use native scope and flattening and never fall back when disabled", function()
    local source = { kind = "shelf", ref = { profile = "local", chip = "chosen" } }
    local choices = Sources.shelves()
    H.eq(#choices, 3); H.eq(choices[1].label, "My library / Custom shelf")
    H.eq(Sources.label(source), "Custom shelf")
    local files = Sources.files(source, {})
    H.eq(files[1], "/library/book"); H.eq(files[2], "/library/series1")
    local old = sections
    sections = {}
    local err
    files, err = Sources.files(source, {})
    H.eq(#files, 0); H.eq(err, true); H.eq(Sources.label(source), "Source unavailable")
    sections = old
end)

H.test("BookOrbit dashboard auto-refresh only covers visible BookOrbit sources", function()
    local provider = { shouldAutoRefreshHome = function(_, module) return module == "other_module" end }
    Dashboard.wrapWantProvider(provider)
    H.eq(provider.shouldAutoRefreshHome(home), true)
    Dashboard.editConfig(home, function(c) c.hidden.want = true end)
    H.eq(provider.shouldAutoRefreshHome(home), false)
    Dashboard.editConfig(home, function(c) c.sources.new = { kind = "shelf", ref = { profile = "local", chip = "remote" } } end)
    H.eq(provider.shouldAutoRefreshHome(home), true)
    saved.simpleui_bookorbit_want_auto_refresh = false
    H.eq(provider.shouldAutoRefreshHome(home), false)
    H.eq(provider.shouldAutoRefreshHome(home, "other_module"), true)
end)

H.test("source and goal menus edit only this screen and preserve headings and ordinary settings", function()
    local before = Dashboard.readConfig(home)
    local choices = Config.sourceItems("want", nil, custom)
    H.eq(choices[1].text, "To Be Read")
    choices[1].callback(); H.eq(choices[1].checked_func(), true)
    H.eq(Dashboard.readConfig(custom).sources.want.id, "tbr")
    H.eq(Dashboard.readConfig(home).sources.want.kind, before.sources.want.kind)
    local collection = choices[5].sub_item_table_func()[2]
    collection.callback()
    H.eq(Dashboard.readConfig(custom).sources.want.coll, "Favorites")
    local shelf = choices[6].sub_item_table_func()[1]
    shelf.callback(); H.eq(shelf.checked_func(), true)
    local items = Config.items(nil, custom)
    H.eq(#items, 12)
    items[3].sub_item_table_func()[1].callback() -- hero off
    H.eq(Dashboard.readConfig(custom).hidden.hero, true)
    local goal = items[9].sub_item_table_func()[3].sub_item_table_func()
    goal[3].callback(); H.eq(goal[3].checked_func(), true)
    H.eq(Dashboard.readData({ pfx = custom }).goal.source, "Hardcover")
    goal[2].callback()
    H.eq(Dashboard.readData({ pfx = custom }).goal.source, "KOReader")
    H.eq(saved[home .. "orbitui_dashboard_heading_want"], "My own label")
end)

H.test("native and SimpleUI arrange dialogs save current config without overwriting later edits", function()
    local items = Config.items(nil, custom)
    items[1].callback()
    H.eq(shown.title, "Arrange cards")
    local dialog = shown
    dialog.item_table[1], dialog.item_table[6] = dialog.item_table[6], dialog.item_table[1]
    Dashboard.editConfig(custom, function(c) c.hidden.week = true end)
    dialog.callback()
    H.eq(Dashboard.readConfig(custom).order[1], "new"); H.eq(Dashboard.readConfig(custom).hidden.week, true)
    local arrange
    items = Config.items(nil, custom, { show_arrange = function(args) arrange = args end })
    items[2].callback()
    H.eq(arrange.title, "Arrange statistics")
    arrange.items[1], arrange.items[4] = arrange.items[4], arrange.items[1]
    arrange.on_change(arrange.items)
    H.eq(Dashboard.readConfig(custom).stats_order[1], "week")
    H.eq(Dashboard.readConfig(home).stats_order[1], "pages_today")
end)

H.test("layout restore needs confirmation and retains source choices and labels", function()
    local before = Dashboard.readConfig(custom)
    local items = Config.items(nil, custom)
    items[#items].callback()
    H.eq(Dashboard.readConfig(custom).order[1], "new")
    shown.ok_callback()
    local after = Dashboard.readConfig(custom)
    H.eq(after.order[1], "hero"); H.eq(after.hidden.hero, nil); H.eq(after.hidden.week, nil)
    H.eq(Model.sourceKey(after.sources.want), Model.sourceKey(before.sources.want))
    H.eq(after.goal, "local")
end)

H.test("new configuration strings switch language without changing saved ids or labels", function()
    G_reader_settings = { readSetting = function() return "sv" end }
    H.eq(Config.items(nil, custom)[1].text, "Ordna kort")
    H.eq(Config.sourceItems("new", nil, custom)[1].text, "Vill läsa")
    G_reader_settings.readSetting = function() return "en" end
    H.eq(Config.items(nil, custom)[1].text, "Arrange cards")
    H.eq(Dashboard.readHeadings(home).want, "My own label")
end)

H.finish()
