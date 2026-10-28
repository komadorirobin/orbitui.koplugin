package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_dashboard")
local saved, writes = {}, 0
local store = {
    readSetting = function(_, key) return saved[key] end,
    saveSetting = function(_, key, value) writes = writes + 1; saved[key] = value end,
}
package.loaded["infra/sui_store"] = store
package.loaded["logger"] = { warn = function() end }
package.loaded["infra/sui_i18n"] = { translate = function(s) return s end }
local Dashboard = require("adapters/orbitui_dashboard")
local Registry = dofile("components/simpleui/modules/moduleregistry.lua")
Registry.list = function() return { Dashboard } end
local pfx = "simpleui_hs_"
local function config(mask, prefix)
    local c = Model.config()
    for i, card in ipairs(Model.heading_cards) do
        c.hidden[card.key] = math.floor(mask / 2 ^ (i - 1)) % 2 == 1 or nil
    end
    saved[(prefix or pfx) .. "orbitui_dashboard_enabled"] = true
    saved[(prefix or pfx) .. "orbitui_dashboard_config"] = c
    return c
end
H.test("all 512 card layouts request statistics/counts only for visible local consumers", function()
    for mask = 0, 511 do
        local c = config(mask)
        local stats = not c.hidden.goal
        for _, id in ipairs(Model.stat_order) do stats = stats or not c.hidden[id] end
        H.eq(Registry.wantsData(pfx, "stats"), stats)
        H.eq(Registry.wantsData(pfx, "books"), not c.hidden.goal)
        H.eq(Registry.getRecentDemand(pfx), not c.hidden.ongoing and 30 or not c.hidden.hero and 1 or 0)
    end
    H.eq(writes, 0)
end)
H.test("remote goal selection does not load its provider or request local counts", function()
    local c = config(511); c.hidden.goal = nil
    for _, source in ipairs({ "auto", "local", "hardcover" }) do
        for _, enabled in ipairs({ false, true }) do
            c.goal = source; saved[pfx .. "hardcover"] = enabled
            local local_goal = source == "local" or source == "auto" and not enabled
            H.eq(Dashboard.needs.books(pfx), local_goal)
            H.eq(Dashboard.needs.stats(pfx), local_goal)
        end
    end
    H.eq(package.loaded["modules/module_hardcover"], nil)
    H.eq(package.loaded["modules/module_stats_provider"], nil)
    H.eq(package.loaded["modules/module_books_shared"], nil)
end)
H.test("visible Recent sources retain candidates independently of hero and ongoing", function()
    for _, id in ipairs({ "want", "new" }) do
        local c = config(511); c.hidden[id] = nil
        c.sources[id] = { kind = "native", id = "recent" }
        H.eq(Registry.getRecentDemand(pfx), 30)
        c.hidden[id] = true; H.eq(Registry.getRecentDemand(pfx), 0)
    end
end)
H.test("Home/custom screen scopes, unsupported config and disabled modules remain isolated", function()
    config(0); config(511, "simpleui_cs_other_")
    H.eq(Registry.wantsData("simpleui_cs_other_", "stats"), false)
    H.eq(Registry.getRecentDemand("simpleui_cs_other_"), 0)
    H.eq(Registry.getRecentDemand(pfx), 30)
    saved[pfx .. "orbitui_dashboard_enabled"] = false
    H.eq(Registry.wantsData(pfx, "stats"), false)
    H.eq(Registry.getRecentDemand(pfx), 0)
    saved[pfx .. "orbitui_dashboard_enabled"] = true
    saved[pfx .. "orbitui_dashboard_config"] = { version = 999 }
    H.eq(Registry.getRecentDemand(pfx), 0)
    H.eq(Registry.wantsData(pfx, "stats"), false)
    H.eq(Registry.wantsData(pfx, "books"), false)
end)
H.finish()
