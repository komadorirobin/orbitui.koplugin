package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = assert(io.open("components/simpleui/" .. path))
    local source = f:read("*a"); f:close(); return source
end
local function compile(body, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then
        local fn = assert(loadstring(body)); setfenv(fn, env); return fn()
    end
    return assert(load(body, "October upstream regression", "t", env))()
end
local function section(source, first, last)
    return source:sub(assert(source:find(first, 1, true)),
        assert(source:find(last, 1, true)) - 1)
end
local function method(source, first)
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find("\nend", start, true)) + 3)
end

local layout_code = section(read("screens/sui_settings_window.lua"),
    "local LayoutService = {}", "function LayoutService.getModuleName")
local function layoutFixture(initial, key, prefix)
    key, prefix = key or "simpleui_layout", prefix or "simpleui_hs_"
    local memory = { [key] = initial, [prefix .. "clock_on"] = false,
        [prefix .. "date_on"] = true, [prefix .. "quote_on"] = true }
    local changes, resets, refreshes = {}, {}, {}
    -- Match LuaSettings: reads and saves retain table references, not copies.
    local store = { readSetting = function(_, k) return memory[k] end,
        saveSetting = function(_, k, v) memory[k] = v end }
    local mods = {
        { id = "clock", text_elems = { "clock", "date" }, setEnabled = function(pfx, on)
            changes[#changes + 1] = { pfx, on }
            memory[pfx .. "clock_on"] = on
            if not on then memory[pfx .. "date_on"] = false end
        end },
        { id = "quote", enabled_key = "quote_on", text_elems = { "quote" } },
        { id = "library", enabled_key = "library_on" },
    }
    local registry = {
        list = function() return mods end,
        get = function(id) for _, m in ipairs(mods) do if m.id == id then return m end end end,
        loadOrder = function() return { "clock", "quote", "library" } end,
        isEnabled = function(mod, pfx)
            if mod.id == "clock" then return memory[pfx .. "clock_on"] or memory[pfx .. "date_on"] end
            return memory[pfx .. mod.enabled_key]
        end,
    }
    local config = {
        resetTextStyles = function(id, _, pfx) resets[#resets + 1] = pfx .. id end,
        setBentoWidth = function(w, id, pfx) memory[pfx .. id .. "_width"] = w end,
    }
    local service = compile(layout_code .. "\nreturn LayoutService", {
        SettingsWindow = {}, SUISettings = store, Registry = registry,
        require = function(name) H.eq(name, "infra/sui_config"); return config end,
        package = { loaded = { ["screens/sui_homescreen"] = {
            _instance = {}, refresh = function() refreshes[#refreshes + 1] = "hs" end,
            refreshScreen = function(id) refreshes[#refreshes + 1] = id end,
        } } },
    })
    return service, memory, changes, resets, refreshes
end
local function layout(...)
    return { pages = { { id = 1, modules = { ... } } } }
end

H.test("layout editing does not mutate the stored membership before saving", function()
    local service, memory = layoutFixture(layout("clock", "quote"))
    local draft = service.load()
    table.remove(draft.pages[1].modules, 1)
    H.eq(memory.simpleui_layout.pages[1].modules[1], "clock")
end)
H.test("repeated saves preserve hidden clock elements but detect later removal and re-add", function()
    local service, memory, changes, resets = layoutFixture(layout("clock", "quote"))
    local draft = service.load()
    service.save(draft); service.save(draft)
    H.eq(#changes, 0); H.eq(memory.simpleui_hs_clock_on, false)
    H.eq(memory.simpleui_hs_date_on, true)
    table.remove(draft.pages[1].modules, 1)
    service.save(draft)
    H.eq(#changes, 1); H.eq(changes[1][2], false)
    H.eq(memory.simpleui_hs_date_on, false); H.eq(resets[1], "simpleui_hs_clock")
    table.insert(draft.pages[1].modules, "clock")
    service.save(draft)
    H.eq(#changes, 2); H.eq(changes[2][2], true)
    H.eq(memory.simpleui_hs_clock_on, true); H.eq(#resets, 1)
end)
H.test("new modules enable once and removing another module only clears its styles", function()
    local service, memory, changes, resets = layoutFixture(layout("clock", "quote"))
    local draft = service.load()
    table.insert(draft.pages[1].modules, "library"); service.save(draft)
    H.eq(memory.simpleui_hs_library_on, true)
    table.remove(draft.pages[1].modules, 2); service.save(draft)
    H.eq(memory.simpleui_hs_quote_on, false); H.eq(resets[1], "simpleui_hs_quote")
    H.eq(memory.simpleui_hs_date_on, true); H.eq(#changes, 0)
end)
H.test("reordering or moving a module between pages leaves element visibility intact", function()
    local service, memory, changes, resets = layoutFixture(layout("clock", "quote"))
    local draft = service.load()
    draft.pages[1].modules = { "quote" }
    draft.pages[2] = { id = 2, modules = { "clock", "quote" } }
    service.save(draft)
    H.eq(#changes, 0); H.eq(#resets, 0); H.eq(memory.simpleui_hs_clock_on, false)
end)
H.test("custom-screen changes use their own settings and refresh target", function()
    local service, memory, changes, _, refreshes = layoutFixture(layout("clock"), "custom_layout", "custom_")
    memory.simpleui_layout = layout("clock")
    local draft = service.load("custom_", "custom_layout")
    service.save(draft, "custom_", "custom_layout", "custom")
    draft.pages[1].modules = {}
    service.save(draft, "custom_", "custom_layout", "custom")
    H.eq(changes[1][1], "custom_"); H.eq(memory.custom_date_on, false)
    H.eq(memory.simpleui_layout.pages[1].modules[1], "clock")
    H.eq(table.concat(refreshes, "|"), "custom|custom")
end)
H.test("legacy entry normalization and first-save layout derivation remain supported", function()
    local service, memory = layoutFixture(layout({ id = "clock", width = 0.5 }))
    local draft = service.load()
    H.eq(draft.pages[1].modules[1], "clock"); H.eq(memory.simpleui_hs_clock_width, 0.5)
    draft.pages[1].modules = {}; service.save(draft)
    H.eq(memory.simpleui_hs_date_on, false)
    local fresh, settings, changes = layoutFixture(nil)
    local first = fresh.load()
    table.insert(first.pages[1].modules, "library"); fresh.save(first)
    H.eq(settings.simpleui_hs_library_on, true); H.eq(#changes, 0)
end)

local config = read("infra/sui_config.lua")
local preference = "filemanager"
local Config = compile("local M = {}\n" .. section(config,
    "local START_WITH_KEY", "function M.homeLabel") .. "\nreturn M", {
    G_reader_settings = { readSetting = function() return preference end,
        saveSetting = function(_, key, value) H.eq(key, "start_with"); preference = value end },
})
H.test("start-view checks track native setting changes without a stale cache", function()
    Config.setStartWithHomescreen(true); H.eq(Config.isStartWithHomescreen(), true)
    preference = "last"; H.eq(Config.isStartWithHomescreen(), false)
    Config.setStartWithHomescreen(false); H.eq(preference, "last")
    Config.setStartWithHomescreen(true); Config.setStartWithHomescreen(false)
    H.eq(preference, "filemanager")
end)
H.test("native startup radio callbacks remain intact and Home is patched once", function()
    local native = function() preference = "last" end
    local menu = { getStartWithMenuTable = function()
        return { sub_item_table = { { radio = true, callback = native } },
            text_func = function() return "Native start view" end }
    end }
    local patch = compile("local M = {}\n" .. method(read("infra/sui_patches.lua"),
        "function M.patchStartWithMenu()") .. "\nreturn M", {
        Config = Config, _ = function(s) return s end,
        package = { loaded = { ["apps/filemanager/filemanagermenu"] = menu } },
    })
    patch.patchStartWithMenu(); patch.patchStartWithMenu()
    for _ = 1, 2 do
        local result = menu.getStartWithMenuTable()
        H.eq(#result.sub_item_table, 2)
        H.eq(result.sub_item_table[2].callback, native)
        result.sub_item_table[1].callback(); H.eq(result.text_func(), "Start with: Home Screen")
        native(); H.eq(result.sub_item_table[1].checked_func(), false)
        H.eq(result.text_func(), "Native start view")
    end
end)

local filter = read("features/library/sui_filter_state.lua")
local function lowerFixture(util, utf8)
    return compile(filter, { require = function(name)
        if name == "util" then return util end
        H.eq(name, "ffi/utf8proc"); if not utf8 then error("unavailable") end; return utf8
    end })
end
H.test("series keys prefer the native Unicode helper", function()
    local f = lowerFixture({ stringLower = function(s) return "native:" .. s end },
        { lowercase = function() error("should prefer core helper") end })
    H.eq(f.seriesKey("Series"), "native:Series"); H.eq(f.seriesKey(nil), nil)
end)
H.test("older readers fall back to utf8proc and finally plain lowercasing", function()
    local f = lowerFixture({}, { lowercase = function(s) return s:gsub("\195\150", "\195\182"):lower() end })
    H.eq(f.seriesKey("\195\150VNINGAR"), "\195\182vningar")
    H.eq(lowerFixture({}, nil).seriesKey("SERIES"), "series")
    H.eq(lowerFixture({}, {}).seriesKey("SERIES"), "series")
end)

local quote = read("modules/module_quote.lua")
local NBSP, WJ = "\194\160", "\226\129\160"
local textbox = { use_xtext = true }
local breaks = compile(section(quote, "local NBSP =", "local function buildWidget(")
    .. "\nreturn controlLineBreaks", {
    TextBoxWidget = textbox, Screen = { getWidth = function() return 1264 end },
    RenderText = { sizeUtf8Text = function(_, _, _, _, text)
        return { x = #text * 10 }
    end },
})
H.test("quote line-break control keeps only short final pairs together", function()
    H.eq(breaks("First line last two", {}, 200), "First line last" .. NBSP .. "two")
    H.eq(breaks("longer final words", {}, 100), "longer final words")
    H.eq(breaks("", {}, 100), "")
end)
H.test("compound binding respects width and only uses word joiners with xtext", function()
    H.eq(breaks("well-read", {}, 200), "well-" .. WJ .. "read")
    H.eq(breaks("well-read", {}, 30), "well-read")
    H.eq(breaks("- -- end-", {}, 30), "- -- end-")
    textbox.use_xtext = false
    H.eq(breaks("well-read", {}, 200), "well-read")
end)

H.test("action-list rows use the chrome-provided width without a second inset", function()
    local W, widths = H.widget(), {}
    local build = compile(method(read("modules/module_action_list.lua"), "local function buildListWidget(")
        .. "\nreturn buildListWidget", {
        PAD = 10, VerticalGroup = W, VerticalSpan = W, FrameContainer = W,
        QA = { filterValidIds = function(ids) return ids end },
        QARenderer = { buildListRow = function(_, args) widths[#widths + 1] = args.inner_w; return W:new{} end },
    })
    for _, width in ipairs({ 160, 300, 600 }) do
        local frame = build(width, { "search", "history" }, true, "right", function() end,
            { row_h = 24, row_gap = 4 }, { blk = 0, sub = 1 })
        H.eq(widths[#widths], width); H.eq(frame.padding, 0); H.eq(frame.fit_align, "right")
    end
end)
H.finish()
