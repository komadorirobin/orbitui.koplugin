local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_dashboard")
local Adapter = require("adapters/orbitui_module_store")
local saved, writes, refreshes, failures, native_calls, registry, live
local pfx, native_id = "simpleui_hs_", "traca_cartao"
local card_id = assert(Model.moduleId("simpleui", native_id))
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end
local function entryId(e) return type(e) == "table" and e.id or e end
local function find(layout, id)
    for i, page in ipairs(layout.pages or {}) do
        for _, entry in ipairs(page.modules) do if entryId(entry) == id then return page, i end end
    end
end
local Store = { readSetting = function(_, k) return saved[k] end,
    saveSetting = function(_, k, v) saved[k] = copy(v); writes = writes + 1 end }
package.loaded["infra/sui_store"] = Store
package.loaded.logger = { warn = function() end }
package.loaded.device = { screen = {
    getWidth = function() return 1264 end, getHeight = function() return 1680 end,
    scaleBySize = function(_, n) return n end,
} }
package.loaded["infra/sui_core"] = { getContentHeight = function() return 1400 end, MOD_GAP = 12 }
package.loaded["infra/sui_config"] = { getModuleGapPx = function() return 12 end }
package.loaded["features/sui_module_chrome"] = {
    resolve = function() return {} end, boxInset = function() return 24 end }
package.loaded["screens/sui_homescreen"] = { getInstance = function() return live end }
local Layout
local function reset()
    saved, writes, refreshes, failures, native_calls, registry = {}, 0, 0, false, 0, {}
    live = nil
    saved.simpleui_layout = { custom = "keep", pages = {
        { id = 1, modules = { Model.id } }, { id = "my-page", modules = { "clock" } } } }
    saved[pfx .. "orbitui_dashboard_enabled"] = true
    saved[pfx .. "orbitui_dashboard_config"] = Model.config()
    saved.pet_state, saved.book_sync, saved.custom_layout = { name = "keep", mood = 7 }, true, { "untouched" }
    Layout = { entryId = entryId, findPage = find,
        load = function(prefix, key)
            return copy(saved[key or "simpleui_layout"] or { pages = {{ id = 1, modules = {} }} })
        end,
        save = function(layout, prefix, key, id, opts)
            native_calls = native_calls + 1
            if failures then error("save failed") end
            saved[key or "simpleui_layout"] = copy(layout)
            if not (opts and opts.silent) then refreshes = refreshes + 1 end
        end }
    package.loaded["infra/sui_layout"] = Layout
    Adapter.layout(Layout)
end
local function proposed(id)
    local draft = Layout.load()
    draft.pages[1].modules[#draft.pages[1].modules + 1] = id or native_id
    return draft
end
local function config() return Model.config(saved[pfx .. "orbitui_dashboard_config"]) end
H.test("new first-page Silverfish is a dashboard card, not a sibling after a full-page dashboard", function()
    reset()
    local old = copy(saved.simpleui_layout)
    local draft = proposed(); local page = draft.pages[1]
    Layout.save(draft)
    H.eq(#config().modules, 1); H.eq(config().modules[1].id, card_id)
    H.eq(config().modules[1].ref, native_id); H.eq(config().modules[1].width, 2)
    H.eq(find(saved.simpleui_layout, native_id), nil)
    H.eq(find(draft, native_id), nil); H.eq(draft.pages[1], page)
    H.eq(#saved.simpleui_layout.pages, #old.pages)
    H.eq(saved.simpleui_layout.pages[2].id, "my-page")
    H.eq(saved.simpleui_layout.custom, "keep"); H.eq(refreshes, 1)
    H.eq(saved.pet_state.mood, 7); H.eq(saved.book_sync, true)
    H.eq(saved.custom_layout[1], "untouched")
end)
H.test("old native placements, their scale, page and manual moves are never auto-migrated", function()
    reset()
    saved.simpleui_layout.pages[2].modules[2] = native_id
    saved[pfx .. native_id .. "_scale"] = 71
    local draft = Layout.load()
    table.remove(draft.pages[2].modules, 2)
    draft.pages[1].modules[2] = { id = native_id, width = 50 }
    Layout.save(draft)
    H.eq(find(saved.simpleui_layout, native_id), saved.simpleui_layout.pages[1])
    H.eq(saved.simpleui_layout.pages[1].modules[2].width, 50)
    H.eq(saved[pfx .. native_id .. "_scale"], 71); H.eq(#config().modules, 0)
end)
H.test("dashboard cards retain custom titles, hidden state, size and ordering without duplicates", function()
    reset()
    local c = config()
    c.modules = {{ id = card_id, kind = "simpleui", ref = native_id, label = "My pet", width = 1, size = "tall" }}
    c.order[#c.order + 1] = card_id; c.hidden[card_id] = true
    saved[pfx .. "orbitui_dashboard_config"] = Model.config(c)
    Layout.save(proposed())
    c = config(); H.eq(#c.modules, 1); H.eq(c.modules[1].label, "My pet")
    H.eq(c.modules[1].size, "tall"); H.eq(c.hidden[card_id], true)
    H.eq(find(saved.simpleui_layout, native_id), nil)
end)
H.test("new card falls back to its own page for an inactive or unsupported/full dashboard", function()
    for _, why in ipairs{ "disabled", "future", "full" } do
        reset()
        if why == "disabled" then saved[pfx .. "orbitui_dashboard_enabled"] = false
        elseif why == "future" then saved[pfx .. "orbitui_dashboard_config"] = {version=999, keep=true}
        else
            local c = config()
            for i = 1, Model.module_limit do c.modules[i] = { kind="action", ref="action_"..i } end
            saved[pfx .. "orbitui_dashboard_config"] = Model.config(c)
        end
        local before = copy(saved[pfx .. "orbitui_dashboard_config"])
        Layout.save(proposed())
        local _, index = find(saved.simpleui_layout, native_id)
        H.eq(index, 3); H.eq(#saved.simpleui_layout.pages[1].modules, 1)
        H.eq(saved.simpleui_layout.pages[2].id, "my-page")
        H.eq(saved[pfx .. "orbitui_dashboard_config"].version, before.version)
        H.eq(saved[pfx .. "orbitui_dashboard_config"].keep, before.keep)
    end
end)
H.test("plain Home keeps the first page only when fresh native geometry proves there is room", function()
    for _, height in ipairs{ 300, 1300 } do
        reset(); saved.simpleui_layout.pages[1].modules = { "clock" }
        saved[pfx .. "orbitui_dashboard_enabled"] = false
        live = { _current_page = 1, _layout_sw = 1264, _layout_content_h = 1400,
            _body = { getSize = function() return { w = 1200, h = height } end },
            _enabled_mods_cache = { pages_of_mods = {{ {id="clock"} }} },
        }
        registry[native_id] = { id=native_id, getHeight=function() return 256 end }
        package.loaded["modules/moduleregistry"] = { get=function(id) return registry[id] end }
        Layout.save(proposed())
        local _, index = find(saved.simpleui_layout, native_id)
        H.eq(index, height == 300 and 1 or 3)
        H.eq(#config().modules, 0)
    end
end)
H.test("unknown, rotated, landscape or a different visible page never guesses available space", function()
    for _, state in ipairs{ {}, {_current_page=2}, {_current_page=1,_layout_sw=1680} } do
        reset(); saved.simpleui_layout.pages[1].modules = { "clock" }; live=state
        Layout.save(proposed())
        local _, index = find(saved.simpleui_layout, native_id); H.eq(index, 3)
    end
end)
H.test("explicit other pages and Custom Screens are left to the native editor", function()
    reset()
    local draft = Layout.load(); draft.pages[2].modules[2] = native_id
    Layout.save(draft); local _, index = find(saved.simpleui_layout, native_id); H.eq(index, 2)
    H.eq(#config().modules, 0)
    reset()
    local custom = proposed()
    Layout.save(custom, "simpleui_cs_custom_", "custom_page", "custom", {silent=true})
    H.eq(find(saved.custom_page, native_id), saved.custom_page.pages[1])
    H.eq(#config().modules, 0); H.eq(refreshes, 0)
end)
H.test("failed native saves restore only the staged dashboard choice, leaving drafts and old data intact", function()
    reset(); failures = true
    local draft = proposed()
    assert(not pcall(Layout.save, draft))
    H.eq(#config().modules, 0); H.eq(#saved.simpleui_layout.pages[1].modules, 1)
    H.eq(#draft.pages[1].modules, 2); H.eq(saved.pet_state.mood, 7)
    H.eq(refreshes, 0)
end)
H.test("ordinary saves and repeated wrappers do not add work or touch unrelated modules", function()
    reset(); Adapter.layout(Layout); Adapter.layout(Layout)
    local draft = proposed("other_plugin"); Layout.save(draft, nil, nil, nil, {silent=true})
    H.eq(native_calls, 1); H.eq(#config().modules, 0)
    H.eq(saved.simpleui_layout.pages[1].modules[2], "other_plugin"); H.eq(refreshes, 0)
end)

-- Retain the real registry's legacy/default-on handling and Layout's copy,
-- membership flags, order, removal and refresh code; stub only services and
-- unrelated module builders. Never load the pet's main/init or saved data.
local native_registry, pet, descriptor, fallback_calls
local function native(fresh, reuse)
    if not reuse then reset() end
    if fresh then saved.simpleui_layout = nil end
    package.loaded["infra/sui_bento"] = {}
    package.loaded["infra/sui_i18n"] = { translate=function(s) return s end }
    package.loaded["screens/sui_homescreen"] = { _instance={}, refresh=function() refreshes=refreshes+1 end }
    native_registry = H.componentModule(root, "modules/moduleregistry")
    package.loaded["modules/moduleregistry"] = native_registry
    Adapter.registry(native_registry)
    native_registry.register({id=Model.id, enabled_key="orbitui_dashboard_enabled", default_on=false})
    native_registry.register({id="clock", default_on=true})
    fallback_calls = 0
    pet = { estado = saved.pet_state, cartaoSimpleUI = function() fallback_calls=fallback_calls+1; return "fallback" end }
    package.loaded["ui/screensaver"] = { traca_instancia=pet }
    descriptor = {id=native_id, enabled_key=native_id.."_enabled", default_on=true,
        getHeight=function() return 256 end, build=function() error("placement must not build") end}
    local write_count = writes
    native_registry.register(descriptor)
    H.eq(writes, write_count, "registration must not write settings")
    Layout = H.componentModule(root, "infra/sui_layout")
    package.loaded["infra/sui_layout"] = Layout
    local UI = require("adapters/orbitui_ui")
    assert(UI.modules["infra/sui_layout"]); UI.wrap("infra/sui_layout", Layout)
end
H.test("fresh real native legacy layout never auto-appends Silverfish before an explicit choice", function()
    native(true)
    local mod = native_registry.get(native_id)
    H.eq(mod.default_on, false); H.eq(descriptor.default_on, true)
    H.eq(native_registry.isEnabled(mod,pfx), false)
    H.eq(find(Layout.load(),native_id), nil); H.eq(pet:cartaoSimpleUI(), false)
    H.eq(saved[pfx..native_id.."_enabled"],nil); H.eq(fallback_calls,0)
end)
H.test("real native placement, enable flags, public toggle and restart retain a single dashboard card", function()
    native(true)
    H.eq(pet:cartaoSimpleUI(true),true)
    H.eq(pet:cartaoSimpleUI(),true); H.eq(#config().modules,1)
    H.eq(find(Layout.load(),native_id),nil); H.eq(refreshes,1)
    H.eq(native_registry.isEnabled(native_registry.get(native_id),pfx),false)
    local count=writes
    H.eq(pet:cartaoSimpleUI(true),true); H.eq(writes,count)
    native(false,true) -- fresh registry/layout/plugin instance over the same settings
    H.eq(pet:cartaoSimpleUI(),true); H.eq(pet:cartaoSimpleUI(true),true)
    H.eq(#config().modules,1); H.eq(find(Layout.load(),native_id),nil)
    H.eq(pet:cartaoSimpleUI(false),false); H.eq(#config().modules,0)
    H.eq(refreshes,2); H.eq(pet:cartaoSimpleUI(),false)
    count=writes; H.eq(pet:cartaoSimpleUI(false),false); H.eq(writes,count)
    H.eq(saved.pet_state.mood,7); H.eq(saved.book_sync,true)
    H.eq(saved.custom_layout[1],"untouched"); H.eq(fallback_calls,0)
end)
H.test("saved native choices, legacy order, opt-outs and Custom Screens keep their original defaults", function()
    for _, choice in ipairs{"native","legacy","off","custom","custom-off"} do
        reset()
        if choice=="native" then saved.simpleui_layout.pages[2].modules[2]=native_id
        elseif choice=="legacy" then
            saved.simpleui_layout=nil; saved[pfx.."module_order"]={Model.id,native_id}
        elseif choice=="off" then saved[pfx..native_id.."_enabled"]=false
        else
            saved.simpleui_custom_screens={{id="x",pfx="custom_",layout_key="custom_layout"}}
            if choice=="custom" then saved.custom_layout={pages={{id=1,modules={native_id}}}}
            else saved["custom_"..native_id.."_enabled"]=false end
        end
        native(false,true)
        H.eq(native_registry.get(native_id).default_on,true)
        if choice=="off" then H.eq(pet:cartaoSimpleUI(),false) end
        if choice=="native" or choice=="legacy" then
            H.eq(pet:cartaoSimpleUI(),true)
            local count=writes; H.eq(pet:cartaoSimpleUI(true),true); H.eq(writes,count)
            H.eq(#config().modules,0)
            H.eq(pet:cartaoSimpleUI(false),false)
            H.eq(find(Layout.load(),native_id),nil)
            H.eq(saved[pfx..native_id.."_enabled"],false)
        end
    end
end)
H.test("native save failure cannot fall through to the pet's legacy boolean writer", function()
    native()
    local original_save=Store.saveSetting
    Store.saveSetting=function(self,k,v)
        if k=="simpleui_layout" then error("storage failure before layout write") end
        return original_save(self,k,v)
    end
    local ok,err=pcall(pet.cartaoSimpleUI,pet,true)
    Store.saveSetting=original_save
    H.eq(ok,false); assert(tostring(err):find("storage failure",1,true))
    H.eq(#config().modules,0); H.eq(find(Layout.load(),native_id),nil)
    H.eq(saved[pfx..native_id.."_enabled"],nil); H.eq(fallback_calls,0)
    H.eq(refreshes,0)
end)
H.test("failed removal restores the existing dashboard card and its title/visibility", function()
    native(); pet:cartaoSimpleUI(true)
    local c=config(); c.modules[1].label="Keep name"; c.hidden[card_id]=true
    saved[pfx.."orbitui_dashboard_config"]=c
    local original_save=Store.saveSetting
    Store.saveSetting=function(self,k,v)
        if k=="simpleui_layout" then error("failed removal") end
        return original_save(self,k,v)
    end
    local ok=pcall(pet.cartaoSimpleUI,pet,false)
    Store.saveSetting=original_save
    H.eq(ok,false); H.eq(config().modules[1].label,"Keep name")
    H.eq(config().hidden[card_id],true); H.eq(pet:cartaoSimpleUI(),true)
end)
H.test("native and dashboard duplicates are removed together without affecting other cards or pages", function()
    native(); pet:cartaoSimpleUI(true)
    saved.simpleui_layout.pages[2].modules[2]=native_id
    local c=config(); c.modules[2]={kind="action",ref="keep"}; c=Model.config(c)
    saved[pfx.."orbitui_dashboard_config"]=c
    H.eq(pet:cartaoSimpleUI(false),false)
    H.eq(find(Layout.load(),native_id),nil); H.eq(#config().modules,1)
    H.eq(config().modules[1].ref,"keep"); H.eq(saved.simpleui_layout.pages[2].modules[1],"clock")
end)
H.test("registration wraps only the identified pet; repeated registration and missing modern API stay safe", function()
    native()
    local method=pet.cartaoSimpleUI
    Adapter.registry(native_registry); native_registry.register(descriptor)
    H.eq(pet.cartaoSimpleUI,method)
    local other={id="other",default_on=true}; native_registry.register(other)
    H.eq(native_registry.get("other"),other)
    package.loaded["infra/sui_layout"]={}
    H.eq(pet:cartaoSimpleUI(),"fallback"); H.eq(fallback_calls,1)
    H.eq(#config().modules,0)
end)
H.test("routed cards remain inside dashboard body bounds in portrait, landscape and small viewports", function()
    native(); pet:cartaoSimpleUI(true)
    for _,size in ipairs{{1264,1400},{1680,980},{600,660},{480,300}} do
        local c=config(); local first=Model.plan(size[1],size[2],c,1)
        local found=false
        for page=1,first.pages do
            local p=Model.plan(size[1],size[2],c,page); local r=p.cards[card_id]
            if r then
                found=true; assert(r.x>=0 and r.y>=0 and r.x+r.w<=p.w and r.y+r.h<=p.h)
            end
        end
        assert(found); H.eq(find(Layout.load(),native_id),nil)
    end
end)

local silverfish=os.getenv("ORBITUI_SILVERFISH_ROOT")
if silverfish then
    H.test("frozen Silverfish public Home methods route without initializing the full plugin or its saves", function()
        local f=assert(io.open(silverfish.."/main.lua","rb")); local source=f:read("*a"); f:close()
        local methods=assert(source:match("(local function cartaoNoLayout.-)\n%-%- Bookshelf 6%.1"))
        local Pet=assert((loadstring or load)("local Traca={}\n"..methods.."\nreturn Traca", "@frozen-silverfish-home-api"))()
        native()
        Layout=H.componentModule(root,"infra/sui_layout") -- unwrapped control
        package.loaded["infra/sui_layout"]=Layout
        local control=setmetatable({},{__index=Pet})
        H.eq(control:cartaoSimpleUI(true),true)
        H.eq(saved.simpleui_layout.pages[1].modules[1],Model.id)
        H.eq(saved.simpleui_layout.pages[1].modules[2],native_id)
        H.eq(#config().modules,0) -- exactly the reported full-page sibling
        native(true)
        pet=setmetatable({estado=saved.pet_state},{__index=Pet})
        package.loaded["ui/screensaver"].traca_instancia=pet
        native_registry.register(descriptor)
        H.eq(pet:cartaoSimpleUI(),false); H.eq(pet:cartaoSimpleUI(true),true)
        H.eq(#config().modules,1); H.eq(find(Layout.load(),native_id),nil)
        H.eq(pet:cartaoSimpleUI(false),false); H.eq(#config().modules,0)
        H.eq(saved.pet_state.mood,7); H.eq(saved[pfx..native_id.."_enabled"],nil)
    end)
end
H.finish()
