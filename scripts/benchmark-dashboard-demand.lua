-- Headless DATA-DEMAND baseline, not a UI/device latency benchmark.
-- Run before and after a change with the same interpreter and source tree.
package.path = "./?.lua;" .. package.path
local saved = {}
package.loaded["infra/sui_store"] = {
    readSetting = function(_, key) return saved[key] end,
    saveSetting = function(_, key, value) saved[key] = value end,
}
local Model = require("core/orbitui_dashboard")
local Dashboard = require("adapters/orbitui_dashboard")
local prefix = "simpleui_hs_"
local cases = {
    { "all-local", { "hero", "ongoing", "goal", "want", "new", "pages_today", "reading_today", "streak", "week" } },
    { "book-rows-only", { "hero", "ongoing", "want", "new" } },
    { "hero-only", { "hero" } },
    { "remote-goal-only", { "goal" }, "hardcover" },
    { "local-goal-only", { "goal" }, "local" },
    { "recent-source-only", { "new" }, nil, "recent" },
    { "all-hidden", {} },
}
print("Headless declared demand only; not total RAM, actual provider calls or device latency.")
print("layout,recent_candidates,statistics_requested,book_counts_requested")
for _, case in ipairs(cases) do
    local config = Model.config()
    for _, card in ipairs(Model.heading_cards) do config.hidden[card.key] = true end
    for _, id in ipairs(case[2]) do config.hidden[id] = nil end
    config.goal = case[3] or "auto"
    if case[4] then config.sources.new = { kind = "native", id = case[4] } end
    saved[prefix .. "orbitui_dashboard_config"] = config
    saved.simpleui_orbitui_dashboard_config_ready = true
    local function demand(key)
        local value = Dashboard.needs[key]
        if type(value) == "function" then return value(prefix) end
        return value
    end
    print(table.concat({ case[1], tostring(demand("recent")), tostring(demand("stats")), tostring(demand("books")) }, ","))
end
