local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_dashboard")
local Sources = require("adapters/orbitui_dashboard_sources")
local Settings = require("adapters/orbitui_dashboard_settings")
local Dashboard = require("adapters/orbitui_dashboard")
local saved, writes, refreshes, shown = {}, 0, 0
local pfx, other = "simpleui_hs_", "simpleui_cs_other_"
package.loaded["infra/sui_store"] = {
    readSetting = function(_, key) return saved[key] end,
    saveSetting = function(_, key, value) writes = writes + 1; saved[key] = value end,
    set = function(_, key, value) saved[key] = value end,
}
package.loaded.logger = { warn = function() end, dbg = function() end }
package.loaded["infra/sui_i18n"] = { translate = function(s) return s end }
local registry = H.componentModule(root, "modules/moduleregistry")
package.loaded["modules/moduleregistry"] = registry
local W = H.widget()
function W:getSize() return self.dimen or { w = self.width or 10, h = self.height or 10 } end
function W:free()
    assert(not self.freed, "double free")
    self.freed = true
    for _, child in ipairs(self) do child:free() end
end
function W:paintTo(bb, x, y)
    self.dimen = self.dimen or self:getSize()
    self.dimen.x, self.dimen.y = x, y
    for _, child in ipairs(self) do
        local offset = child.overlap_offset or { 0, 0 }
        child:paintTo(bb, x + offset[1], y + offset[2])
    end
end
local built, taps, ticks, child_args = 0, 0, 0
local mod = { id = "external_pet", name = "Pet", default_on = false,
    needs = { stats = true, recent = function(prefix) H.eq(prefix, pfx); return 17 end, charts = true },
    build = function(w, ctx)
        built, child_args = built + 1, ctx
        ctx.foreign_cache = true
        if ctx._screen_widget then ctx._screen_widget._clock_live = { "private card" } end
        return W:new{ width = w, height = 50 }
    end }
registry.register(mod)
registry.register(Dashboard)
local micro_keys, micro_gets = 0, 0
local micro = { key = "pet", title = "Shelf pet", render = function(ctx)
    H.eq(type(ctx), "table"); H.eq(ctx.preview, false)
    H.eq(ctx.surface, "orbitui_dashboard"); H.eq(ctx.entry.module, "pet")
    built = built + 1
    return W:new{ width = ctx.width, height = ctx.height }
end, on_tap = function(ctx) taps = taps + 1; H.eq(ctx.tapped_region, "eye") end,
on_minute = function(ctx) ticks = ticks + 1; ctx.refresh() end }
package.loaded["lib/bookshelf_start_menu_modules"] = {
    keys = function() micro_keys = micro_keys + 1; return { "pet" } end,
    get = function(id, force) micro_gets = micro_gets + 1; H.eq(force, true); return id == "pet" and micro end,
}
package.loaded["lib/bookshelf_module_kit"] = {
    entryConfig = function(entry) return { entry = entry } end,
    hitRegion = function() return "eye" end,
}
local custom, registered = { "custom_qa_1" }, { launch_pet = true }
package.loaded["features/sui_quickactions"] = {
    allIds = function() return { "launch_pet" } end,
    isRegistered = function(id) return registered[id] end,
    getCustomQAValid = function() return { custom_qa_1 = true } end,
    getCustomQAList = function() return custom end,
    getEntry = function(id) return { label = "Action " .. id } end,
}
local function entry(kind, ref, size, width)
    return { id = Model.moduleId(kind, ref), kind = kind, ref = ref,
        label = ref, width = width or 2, size = size or "normal" }
end
local function only(...)
    local c = Model.config()
    for _, card in ipairs(Model.heading_cards) do c.hidden[card.key] = true end
    c.modules = { ... }
    c = Model.config(c)
    saved[pfx .. "orbitui_dashboard_config"] = c
    return c
end
local function changed() refreshes = refreshes + 1 end

H.test("add is explicit, bounded, screen-scoped and keeps ordinary layouts and plugin settings", function()
    local layout, plugin_state = { "my page" }, { mood = "happy" }
    saved.simpleui_layout, saved.pet_state = layout, plugin_state
    H.eq(#Dashboard.readConfig(pfx).modules, 0)
    H.eq(micro_keys, 0); H.eq(micro_gets, 0); H.eq(built, 0)
    assert(Settings.add(entry("simpleui", "external_pet"), changed, pfx))
    H.eq(#Dashboard.readConfig(pfx).modules, 1); H.eq(Dashboard.readConfig(pfx).version, 2)
    H.eq(#Dashboard.readConfig(other).modules, 0)
    H.eq(saved.simpleui_layout, layout); H.eq(saved.pet_state, plugin_state)
    local count = writes
    H.eq(Settings.add(entry("simpleui", "external_pet"), changed, pfx), false)
    H.eq(writes, count); H.eq(built, 0); H.eq(micro_keys, 0)
end)
H.test("normalization deduplicates stable ids, bounds entries and retains missing plugins", function()
    local raw = { version = 1, modules = { entry("simpleui", "missing"), entry("simpleui", "missing"),
        { kind = "file", ref = "/tmp/inject.lua" }, { kind = "action", ref = "bad\nref" } },
        order = { "module:simpleui:missing", "new" } }
    local c = Model.config(raw)
    H.eq(#c.modules, 1); H.eq(c.order[1], "module:simpleui:missing"); H.eq(raw.version, 1)
    H.eq(c.version, 2); H.eq(c.modules[1].ref, "missing")
    for i = 1, 50 do raw.modules[#raw.modules + 1] = entry("action", tostring(i)) end
    H.eq(#Model.config(raw).modules, Model.module_limit)
    saved[other .. "orbitui_dashboard_config"] = { version = 500, preserve = true }
    H.eq(Settings.add(entry("action", "launch_pet"), changed, other), false)
    H.eq(saved[other .. "orbitui_dashboard_config"].preserve, true)
end)
H.test("picker uses both real registry APIs without rendering and sees late registrations", function()
    local before = built
    local choices = Sources.moduleChoices("simpleui")
    H.eq(#choices, 1); H.eq(choices[1].ref, "external_pet")
    registry.register({ id = "late_plugin", name = "Late", build = mod.build })
    H.eq(#Sources.moduleChoices("simpleui"), 2)
    registry.unregister("late_plugin")
    H.eq(#Sources.moduleChoices("simpleui"), 1)
    local shelf = Sources.moduleChoices("bookshelf")
    H.eq(shelf[1].ref, "pet"); H.eq(micro_keys, 1)
    H.eq(#Sources.moduleChoices("action"), 2)
    assert(Sources.resolveModule(entry("action", "custom_qa_1")))
    H.eq(built, before)
end)
H.test("selected SimpleUI data demands are inherited without enabling a standalone module", function()
    local c = only(entry("simpleui", "external_pet"))
    H.eq(registry.isEnabled(mod, pfx), false)
    H.eq(Dashboard.needs.stats(pfx), true); H.eq(Dashboard.needs.recent(pfx), 17)
    H.eq(Dashboard.needs.books(pfx), false); H.eq(Dashboard.needs.charts(pfx), true)
    c.hidden[c.modules[1].id] = true
    H.eq(Dashboard.needs.stats(pfx), false); H.eq(Dashboard.needs.recent(pfx), 0)
    H.eq(Sources.resolveModule(entry("simpleui", Model.id)), nil)
end)
H.test("all sizes and extra pages are bounded, nonoverlapping and keep every selected card", function()
    for _, size in ipairs({ {600,730}, {300,400}, {800,480}, {1264,1400} }) do
        local c = Model.config()
        for i = 1, 16 do c.modules[i] = entry("action", tostring(i),
            i % 5 == 0 and "page" or i % 3 == 0 and "tall" or "normal", i % 2 + 1) end
        c = Model.config(c)
        local first, seen = Model.plan(size[1], size[2], c), {}
        assert(first.pages > 1)
        for page = 1, first.pages do
            local p, cards = Model.plan(size[1], size[2], c, page), {}
            H.eq(p.page, page)
            for id, r in pairs(p.cards) do
                assert(not seen[id], "card repeated on another page"); seen[id] = true
                assert(r.w > 0 and r.h > 0 and r.x >= 0 and r.y >= p.header_h)
                assert(r.x + r.w <= p.w and r.y + r.h <= p.h)
                for _, b in ipairs(cards) do
                    assert(r.x+r.w <= b.x or b.x+b.w <= r.x or r.y+r.h <= b.y or b.y+b.h <= r.y)
                end
                cards[#cards + 1] = r
            end
        end
        for _, e in ipairs(c.modules) do assert(seen[e.id]) end
        H.eq(Model.plan(size[1], size[2], c, 999).page, first.pages)
        H.eq(Model.plan(size[1], size[2], c, 0/0).page, 1)
    end
end)
H.test("native module builders receive a private context and Bookshelf's table render contract", function()
    local original = { "ordinary clock" }
    local ctx = { pfx = pfx, _screen_widget = { _clock_live = original } }
    local child = Sources.buildModule(entry("simpleui", "external_pet"), 200, 80, ctx)
    assert(child); H.eq(child_args.grow_h, 80); H.eq(ctx.foreign_cache, nil)
    H.eq(ctx._screen_widget._clock_live, original); assert(child_args._screen_widget ~= ctx._screen_widget)
    child:free()
    child = Sources.buildModule(entry("bookshelf", "pet"), 200, 80, ctx)
    H.eq(child:getSize().h, 80); child:free()
    local count = built
    H.eq(Sources.buildModule(entry("simpleui", "gone"), 200, 80, ctx), nil)
    H.eq(built, count)
end)
H.test("bad builds are contained and newly returned malformed widgets are freed", function()
    registry.register({ id = "broken", build = function() error("plugin error") end })
    H.eq(Sources.buildModule(entry("simpleui", "broken"), 50, 50, {}), nil)
    local child = W:new{ width = -1 }
    registry.register({ id = "broken", build = function() return child end })
    H.eq(Sources.buildModule(entry("simpleui", "broken"), 50, 50, {}), nil)
    H.eq(child.freed, true)
    registry.unregister("broken")
end)
H.test("native actions retain Home navigation and Bookshelf tap regions", function()
    local routed
    Sources.tapModule(entry("action", "launch_pet"), {}, { on_qa_tap = function(ref) routed = ref end })
    H.eq(routed, "launch_pet")
    Sources.tapModule(entry("bookshelf", "pet"), micro, {}, {}, 1, 2)
    H.eq(taps, 1)
end)

-- Real clipping container, with deterministic buffers; native FFI supplement
-- can replace these buffers without changing the adapter/widget tree below.
local native_bb = os.getenv("ORBITUI_NATIVE_BB_DIR")
local BB
if native_bb then
    package.path = native_bb .. "/?.lua;" .. package.path
    local ffi = require("ffi")
    ffi.cdef[[void *malloc(size_t); void *calloc(size_t,size_t); void free(void *);]]
    package.loaded["ffi/posix_h"] = true
    package.loaded["ffi/util"] = { idiv = function(a, b) return math.floor(a / b) end }
    ffi.loadlib = function(name) return ffi.load(os.getenv("ORBITUI_NATIVE_BB_LIB") or name) end
    BB = require("ffi/blitbuffer")
else
    BB = { COLOR_BLACK = 0, COLOR_WHITE = 255, COLOR_DARK_GRAY = 80,
        COLOR_LIGHT_GRAY = 200, COLOR_GRAY = 128, Color8 = function(value) return value end }
    function BB.new(w, h, kind)
        return { getType = function() return kind or 1 end, fill = function() end,
            blitFrom = function() end, free = function() end }
    end
end
package.loaded["ffi/blitbuffer"] = BB
for _, name in ipairs({ "ui/geometry", "ui/widget/widget", "ui/gesturerange",
    "ui/widget/container/widgetcontainer", "ui/widget/container/inputcontainer",
    "ui/widget/container/framecontainer", "ui/widget/overlapgroup" }) do package.loaded[name] = W end
local queued, scheduled, top = {}, {}, nil
package.loaded["ui/uimanager"] = {
    nextTick = function(_, fn) queued[#queued + 1] = fn end,
    scheduleIn = function(_, seconds, fn) H.eq(seconds, 60); scheduled[fn] = true end,
    unschedule = function(_, fn) scheduled[fn] = nil end,
    getTopmostVisibleWidget = function() return top end,
    setDirty = function() end,
    show = function(_, value) shown = value end,
}
package.loaded.device = { hasKeys = function() return false end,
    screen = { night_mode = false, scaleBySize = function(_, n) return n end,
        getWidth = function() return 600 end, getHeight = function() return 800 end } }
local Event = { new = function(_, name, ...)
    return { handler = "on" .. name, args = { n = select("#", ...), ... } }
end }
package.loaded["ui/event"] = Event
local Range = W:extend{}
function Range:match(ges)
    local r = type(self.range) == "function" and self.range() or self.range
    return ges.ges == self.ges and ges.pos and r and ges.pos.x >= (r.x or 0)
        and ges.pos.y >= (r.y or 0) and ges.pos.x < (r.x or 0) + r.w and ges.pos.y < (r.y or 0) + r.h
end
package.loaded["ui/gesturerange"] = Range
local native_input = os.getenv("ORBITUI_NATIVE_INPUT_DIR")
if native_input then
    local Base = W:extend{}
    function Base:handleEvent(event)
        local fn = self[event.handler]
        if fn then return fn(self, (unpack or table.unpack)(event.args, 1, event.args.n or #event.args)) end
    end
    package.loaded["ui/widget/widget"], package.loaded.depgraph = Base, {}
    package.loaded.gettext = function(s) return s end
    package.loaded["ui/widget/container/widgetcontainer"] = assert(loadfile(native_input .. "/widgetcontainer.lua"))()
    package.loaded["ui/widget/container/inputcontainer"] = assert(loadfile(native_input .. "/inputcontainer.lua"))()
end
package.loaded["lib/bookshelf_clip_container"] = H.componentModule(root, "lib/bookshelf_clip_container")
package.loaded["features/sui_style"] = { getStyledFace = function(_, size) return { size = size } end }
local function text(args) return W:new{ text = args.text, width = args.width, height = 20 } end
package.loaded["infra/sui_core"] = { makeColoredText = text, makeTextBox = text }
package.loaded["modules/module_books_shared"] = {}
local View = require("adapters/orbitui_dashboard_view")
local function view(c)
    local ctx = { pfx = pfx, _screen_widget = {}, refresh_fn = changed }
    top = ctx._screen_widget
    local data = { config = c, stats = {}, headings = {}, want = {}, new = {}, ongoing = {} }
    local v = View.build(600, 730, ctx, data)
    v.dimen.x, v.dimen.y = 0, 0
    return v, ctx, data
end
H.test("clock-style refreshes rebuild only their own card and retire old child callbacks", function()
    registry.register({ id = "clock_fixture", name = "Clock", build = mod.build,
        scheduleRefresh = function() error("must not steal the native Home timer") end })
    local v = view(only(entry("simpleui", "clock_fixture", "normal", 1), entry("simpleui", "external_pet", "normal", 1)))
    local tick, old_callback = v._module_tick, child_args.refresh_fn
    assert(tick)
    local count, before = built, refreshes
    tick(); local task = queued[#queued]; queued = {}; task()
    H.eq(built, count + 1); H.eq(refreshes, before)
    -- Refresh the second card through its own builder callback; the replaced
    -- child's retained callback must become inert without rebuilding its peer.
    old_callback(); local next_task = queued[#queued]; queued = {}; assert(next_task); next_task()
    H.eq(built, count + 2)
    old_callback(); H.eq(#queued, 0)
    v:free(); registry.unregister("clock_fixture")
end)
H.test("guard catches paint/input failures, preserves the fallback and frees every owned child once", function()
    local child, fallback = W:new{ width = 200, height = 100 }, W:new{ width = 40, height = 20 }
    child.paintTo = function() error("foreign paint") end
    local guard = Sources.moduleContainer(child, fallback, 100, 80, BB.COLOR_WHITE)
    local bb = BB.new(600, 730, native_bb and BB.TYPE_BB8 or 1)
    guard:paintTo(bb, 30, 50); H.eq(guard.failed, true)
    H.eq(guard:handleEvent({}), false)
    guard:free(); H.eq(child.freed, true); H.eq(fallback.freed, true)
    guard:free(); bb:free()
    child, fallback = W:new{}, W:new{}
    child.handleEvent = function() error("foreign event") end
    guard = Sources.moduleContainer(child, fallback, 100, 80)
    H.eq(guard:handleEvent({ handler = "onSomething" }), false)
    H.eq(guard.failed, true); guard:free()
end)
H.test("only current-page modules build; page changes retire ticks and queued refresh callbacks", function()
    local c = only(entry("simpleui", "external_pet", "page"), entry("bookshelf", "pet", "page"))
    local before = built
    local v, ctx, data = view(c)
    H.eq(built, before + 1); H.eq(next(scheduled), nil)
    v._module_page = 2; v:replaceContent(ctx, data)
    H.eq(built, before + 2); assert(v._module_tick)
    local tick = v._module_tick
    local count = refreshes
    tick(); H.eq(ticks, 1); H.eq(#queued, 1)
    v._module_page = 1; v:replaceContent(ctx, data)
    H.eq(scheduled[tick], nil)
    queued[1](); queued = {}; H.eq(refreshes, count)
    tick(); H.eq(ticks, 1)
    v:free()
end)
H.test("covered, parked, sleeping and disposed views do no module tick or deferred refresh work", function()
    local v, ctx = view(only(entry("bookshelf", "pet")))
    local tick, before = v._module_tick, ticks
    top = {}; tick(); H.eq(ticks, before)
    top = ctx._screen_widget; ctx._screen_widget._parked = true; tick(); H.eq(ticks, before)
    ctx._screen_widget._parked = false; v:onSuspend(); tick(); H.eq(ticks, before)
    H.eq(scheduled[tick], nil, "a dequeued pre-suspend timer must not rearm itself")
    v:onResume(); tick(); H.eq(ticks, before + 1)
    local fn = queued[#queued]
    local count = refreshes
    v:free(); H.eq(scheduled[tick], nil)
    fn(); H.eq(refreshes, count); tick(); H.eq(ticks, before + 1)
end)
H.test("a module closing the view inside its minute hook cannot resurrect the timer", function()
    local v = view(only(entry("bookshelf", "pet")))
    local previous = micro.on_minute
    micro.on_minute = function() v:free() end
    local tick = v._module_tick
    tick(); H.eq(scheduled[tick], nil)
    micro.on_minute = previous
end)
H.test("missing modules keep a selectable placeholder and removal never unregisters the plugin", function()
    local c = only(entry("simpleui", "absent"))
    local v = view(c)
    local id, called = c.modules[1].id
    v.editModules = function(_, value) called = value end
    local area = v._plan.cards[id]
    v:onDashboardTap(nil, { pos = { x = area.x+3, y = area.y+3 } })
    H.eq(called, id)
    v:onDashboardHold(nil, { pos = { x = area.x+3, y = area.y+3 } }); v:onDashboardHoldRelease()
    H.eq(called, id)
    local items = Settings.moduleItems(id, changed, pfx)
    items[3].callback()
    H.eq(#Dashboard.readConfig(pfx).modules, 0); assert(registry.get("external_pet"))
    v:free()
end)
H.test("dashboard page buttons, plus and hold preferences stay independent of Home and book navigation", function()
    local c = only(entry("simpleui", "external_pet", "page"), entry("bookshelf", "pet", "page"))
    local v, ctx, data = view(c)
    local chosen
    v.editModules = function(_, id) chosen = id or "root" end
    local next_button = v._actions[4]
    assert(next_button)
    v:onDashboardTap(nil, { pos = { x = next_button.x + 2, y = next_button.y + 2 } })
    H.eq(v._plan.page, 2); H.eq(ctx._screen_widget._orbitui_dashboard_module_page, 2)
    H.eq(ctx._screen_widget._current_page, nil)
    local plus = v._actions[2]
    v:onDashboardTap(nil, { pos = { x = plus.x+2, y = plus.y+2 } }); H.eq(chosen, "add")
    v:free()
    local rebuilt = View.build(600, 730, ctx, data)
    H.eq(rebuilt._plan.page, 2)
    rebuilt:free()
    saved.simpleui_hs_settings_on_hold = false
    local disabled = view(only(entry("simpleui", "external_pet")))
    H.eq(disabled:onDashboardHold(nil, { pos = { x = 30, y = 30 } }), nil)
    H.eq(disabled._held, nil); disabled:free()
    saved.simpleui_hs_settings_on_hold = nil
end)
H.test("module size/menu edits are scoped and creation delegates to the existing action editor", function()
    only(entry("simpleui", "external_pet"))
    local id = Model.moduleId("simpleui", "external_pet")
    local items = Settings.moduleItems(id, changed, pfx)
    items[2].sub_item_table_func()[4].callback()
    H.eq(Dashboard.readConfig(pfx).modules[1].size, "page")
    local plugin = { _rebuildAllNavbars = function() end }
    package.loaded["apps/filemanager/filemanager"] = { instance = { _simpleui_plugin = plugin } }
    package.loaded["features/sui_quickactions"].showQuickActionDialog = function(p, old, done)
        H.eq(p, plugin); H.eq(old, nil)
        custom[#custom + 1] = "custom_qa_2"; done()
    end
    local actions = Settings.pickerItems(changed, pfx)[3].sub_item_table_func()
    assert(actions[#actions].enabled_func()); actions[#actions].callback()
    H.eq(Dashboard.readConfig(pfx).modules[2].ref, "custom_qa_2")
end)
H.test("the native editor defers Home refresh until close and never writes another screen's layout", function()
    local args
    package.loaded["screens/sui_settings_window"] = { show = function(_, on_close, nav, state)
        args = { on_close = on_close, nav = nav, state = state }; return args
    end }
    package.loaded["engines/sui_window"] = { makeCtxMenu = function() return { show_arrange = function() end } end }
    local before, paints = refreshes, 0
    local menu_ctx = { repaint = function() paints = paints + 1 end }
    local handle = Settings.show(pfx, { refresh_fn = changed }, "add")
    H.eq(args.nav[1].id, "nested_menu"); H.eq(args.state.pfx, pfx)
    local choices = args.nav[1].params.items_func(menu_ctx)[2].sub_item_table_func()
    choices[1].callback()
    H.eq(refreshes, before); H.eq(paints, 1)
    handle.on_close(); H.eq(refreshes, before + 1)
    local id = Model.moduleId("simpleui", "external_pet")
    mod.getMenuItems = function(ctx) H.eq(ctx.pfx, pfx); return {{ text = "Native plugin settings" }} end
    local items = Settings.moduleItems(id, changed, pfx)
    items[#items].callback()
    H.eq(args.nav[1].id, "nested_menu", "must not enter the layout-saving module_settings screen")
    H.eq(args.nav[1].params.items_func(menu_ctx)[1].text, "Native plugin settings")
    mod.getMenuItems = nil
end)
H.test("network modules need explicit confirmation and discovery never renders or fetches", function()
    local def = micro
    micro = { title = "Network card", render = function() error("picker must not render") end, network = { "example.invalid" } }
    package.loaded["ui/widget/confirmbox"] = W
    local count = #Dashboard.readConfig(pfx).modules
    -- The existing pet is already selected; choose a different screen.
    saved[other .. "orbitui_dashboard_config"] = nil
    local rows = Settings.pickerItems(changed, other)[2].sub_item_table_func()
    rows[1].callback()
    H.eq(#Dashboard.readConfig(other).modules, 0); assert(shown.ok_callback)
    shown.ok_callback(); H.eq(#Dashboard.readConfig(other).modules, 1)
    H.eq(#Dashboard.readConfig(pfx).modules, count)
    micro = def
end)
H.test("all owned new picker and recovery wording is translated without renaming plugin state", function()
    local tr = require("core/orbitui_i18n")
    for _, value in ipairs({ "Home modules (SimpleUI)", "Shelf modules (Bookshelf)", "Action shortcuts",
        "Card size", "Half-width", "Full-width", "Tall card", "Whole page", "Remove card", "Unavailable",
        "Module unavailable. Long-press to configure.", "Tap to open", "Module settings…", "Create shortcut…",
        "Settings are shared with this module on other Home pages.",
        "Removes only this dashboard card, not the plugin or its data.",
        "Choose a card supplied by an installed plugin, a Home module, or an action shortcut. Plugins stay separate. More cards use extra dashboard pages.",
        "This module uses the network. Add it to the dashboard?",
        "No compatible modules available. Enable the plugin and restart KOReader." }) do
        assert(tr(value, "sv") ~= value, value); H.eq(tr(value, "en"), value)
    end
end)

local silverfish = os.getenv("ORBITUI_SILVERFISH_ROOT")
if silverfish then
    -- Full, unmodified external adapters from the reviewed frozen checkout.
    -- Creature state/sprites/fonts are boundary fixtures, not the real pet's
    -- state: this never initializes its main.lua, reads user data or installs it.
    package.path = silverfish .. "/?.lua;" .. package.path
    local opened, painted = 0, 0
    local pet = { path = silverfish, estado = { paginas = 9 }, onMostrarTraca = function() opened = opened + 1 end }
    package.loaded["traca_lingua"] = { t = function() return "Silverfish" end }
    package.loaded["traca_guarda"] = { padrao = { envolver = function() end } }
    package.loaded["traca_species"] = { current = function() return { id = "fixture" } end }
    package.loaded["traca_estado"] = {
        fase = function() return { nome = "ninfa" } end,
        expressao = function() return "awake" end,
        passarTempo = function() end,
        sprite = function() return "ninfa" end,
        falaQueCabe = function() return "Reading together", 1 end,
    }
    package.loaded["traca_desenho"] = { ALTURA = 64, LARGURA = 64,
        caminhoFonte = function(name) return name end,
        resolver = function(name) return name end,
        sprite = function() return { "##", "##" } end,
        pintarSprite = function(bb, _, x, y, scale)
            painted = painted + 1
            if bb.paintRect then bb:paintRect(x, y, scale * 2, scale * 2, BB.COLOR_BLACK) end
        end,
    }
    package.loaded["ui/screensaver"] = { traca_instancia = pet }
    package.loaded["ui/font"] = { getFace = function(_, _, size) return { size = size } end }
    local Text = W:extend{}
    function Text:init() self.vertical_string_list = {{ width = math.min(self.width, 90) }} end
    for _, name in ipairs({ "ui/widget/textboxwidget", "ui/widget/textwidget" }) do package.loaded[name] = Text end
    for _, name in ipairs({ "ui/widget/horizontalgroup", "ui/widget/horizontalspan", "ui/widget/verticalgroup",
        "ui/widget/verticalspan", "ui/widget/progresswidget", "ui/widget/container/leftcontainer" }) do package.loaded[name] = W end
    local qa = package.loaded["features/sui_quickactions"]
    qa.register = function(def) registered[def.id] = true end
    H.test("Silverfish's real SimpleUI adapter registers, builds and opens through native input", function()
        require("traca_simpleui").registrar(pet)
        assert(registry.get("traca_cartao"))
        local c = only(entry("simpleui", "traca_cartao"))
        local v = view(c)
        local bb = BB.new(600, 730, native_bb and BB.TYPE_BB8 or 1)
        -- Paint only the real clipped module, not schematic dashboard text.
        local clip = v[1][#v[1]]
        local xy = clip.overlap_offset
        clip:paintTo(bb, xy[1], xy[2])
        H.eq(clip.failed, nil); assert(painted > 0)
        if native_input then
            assert(v:handleEvent(Event:new("Gesture", { ges = "tap", pos = { x = xy[1] + 10, y = xy[2] + 300 } })))
            H.eq(opened, 1)
        end
        v:free(); bb:free()
    end)
    H.test("Silverfish's real Bookshelf drop-in renders with cell geometry and opens its own plugin", function()
        local def = assert(loadfile(silverfish .. "/bookshelf_modules/traca.lua"))(silverfish .. "/bookshelf_modules")
        H.eq(def.key, "silverfish")
        local modules = package.loaded["lib/bookshelf_start_menu_modules"]
        local get = modules.get
        modules.get = function(ref, force) if ref == "silverfish" then return def end; return get(ref, force) end
        local before = painted
        local e = entry("bookshelf", "silverfish")
        local child, actual = Sources.buildModule(e, 550, 300, {})
        H.eq(actual, def); assert(child)
        local bb = BB.new(600, 730, native_bb and BB.TYPE_BB8 or 1)
        local clip = Sources.moduleContainer(child, W:new{}, 550, 300, BB.COLOR_WHITE)
        clip:paintTo(bb, 20, 20)
        H.eq(clip.failed, nil); assert(painted > before)
        local count = opened
        Sources.tapModule(e, def, {})
        H.eq(opened, count + 1)
        clip:free(); bb:free()
    end)
end
H.finish()
