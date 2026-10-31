local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local values, writes, flushes, refreshes, launched, language = {}, {}, 0, 0, {}, "en"
local key = "simpleui_app_launcher_settings_target"
G_reader_settings = {
    readSetting = function(_, k) if k == "language" then return language end; return values[k] end,
    saveSetting = function(_, k, v) values[k] = v; writes[#writes + 1] = k end,
    flush = function() flushes = flushes + 1 end,
}
local W = H.widget()
for _, name in ipairs({ "container/centercontainer", "container/framecontainer", "container/inputcontainer",
        "horizontalgroup", "horizontalspan", "imagewidget", "infomessage", "textwidget",
        "verticalgroup", "verticalspan" }) do
    package.loaded["ui/widget/" .. name] = W
end
package.loaded["ui/geometry"], package.loaded["ui/gesturerange"] = W, W
package.loaded.device = { screen = { scaleBySize = function(_, n) return n end } }
package.loaded["ffi/blitbuffer"] = { gray = function(n) return n end, COLOR_BLACK = 0 }
package.loaded["ui/font"] = { getFace = function() return {} end }
package.loaded.logger = { dbg = function() end, info = function() end,
    warn = function(message) error(message) end }
package.loaded["ui/uimanager"] = { show = function() end }
package.loaded["infra/sui_core"] = { PAD = 5 }
package.loaded["infra/sui_config"] = {
    getModuleScale = function() return 1 end, makeScaleItem = function(o) return o end,
}
-- Only JNI and primitive widgets are fake: module/widget/menu/tap code is real.
local env, vm, activity = {}, {}, {}
local api = {}
env[0] = api
vm[0] = { AttachCurrentThread = function(_, out) out[0] = env; return 0 end }
package.loaded.android = { app = { activity = { vm = vm, clazz = activity } },
    dictLookup = function() error("JNI must succeed, not silently fall back") end }
package.loaded.ffi = {
    cdef = function() end, cast = function(_, value) return value end,
    new = function(kind)
        local array = {}
        for i = 0, tonumber(kind:match("%[(%d+)%]")) - 1 do array[i] = {} end
        return array
    end,
}
function api.GetObjectClass(_, object) return object end
function api.GetMethodID(_, _, method) return method end
function api.CallObjectMethod(_, _, method) H.eq(method, "getPackageManager"); return {} end
function api.FindClass(_, name) H.eq(name, "android/content/Intent"); return {} end
function api.NewStringUTF(_, text) return text end
function api.DeleteLocalRef() end
function api.ExceptionCheck() return 0 end
function api.NewObjectA(_, _, method, args)
    H.eq(method, "<init>"); return { action = args[0].l }
end
function api.CallObjectMethodA(_, object, method, args)
    if method == "getLaunchIntentForPackage" then return { package = args[0].l } end
    H.eq(method, "addFlags"); object.flags = args[0].i; return object
end
function api.CallVoidMethodA(_, object, method, args)
    H.eq(object, activity); H.eq(method, "startActivity")
    launched[#launched + 1] = args[0].l
end
package.loaded.util = { trim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end }
package.loaded["infra/sui_paths"] = { getPluginDir = function() return root .. "/components/simpleui/" end }
package.loaded.gettext = setmetatable({}, { __call = function(_, text) return text end })
local I18n = H.componentModule(root, "infra/sui_i18n")
local M = H.componentModule(root, "modules/module_app_launcher")
local function build(pfx)
    values[pfx .. "app_launcher_enabled"] = true
    -- Reuse disk icons. Fetching Android artwork is unrelated to intent routing.
    local open = io.open
    io.open = function(path, ...)
        if path:find("/sdcard/koreader/simpleui_icons/", 1, true) == 1 then return { close = function() end } end
        return open(path, ...)
    end
    local ok, widget = pcall(M.build, 1000, { pfx = pfx })
    io.open = open
    assert(ok, widget)
    return widget[1]
end
local row = build("simpleui_hs_")
local function menu(pfx)
    return M.getMenuItems{ pfx = pfx or "simpleui_hs_", _ = I18n.translate,
        refresh = function() refreshes = refreshes + 1 end }[1]
end
local function tapSettings()
    H.eq(row[7]:onTapApp(), true)
    local intent = launched[#launched]
    H.eq(intent.flags, 0x10000000)
    H.eq(intent.package, nil) -- no private component/fragment and no settings writes
    return intent.action
end
H.test("absent, normal and unknown destinations preserve the existing Android Settings intent", function()
    for _, value in ipairs({ false, "settings", "unknown", "android.settings.WIFI_SETTINGS" }) do
        values[key] = value or nil
        H.eq(tapSettings(), "android.settings.SETTINGS")
        local options = menu().sub_item_table
        H.eq(options[1].checked_func(), true); H.eq(options[2].checked_func(), false)
    end
    H.eq(#writes, 0); H.eq(flushes, 0)
end)
H.test("explicit Developer options choice changes just one persisted preference and the very next tap", function()
    local item = menu()
    H.eq(item.text, "Settings shortcut"); H.eq(item.value_func(), "Android settings")
    item.sub_item_table[2].callback()
    H.eq(values[key], "developer"); H.eq(#writes, 1); H.eq(writes[1], key)
    H.eq(flushes, 1); H.eq(refreshes, 1)
    H.eq(item.sub_item_table[2].checked_func(), true)
    H.eq(item.value_func(), "Developer options")
    -- Reuse the previously built widget to reject stale captured target values.
    H.eq(tapSettings(), "android.settings.APPLICATION_DEVELOPMENT_SETTINGS")
    H.eq(menu("simpleui_custom_").sub_item_table[2].checked_func(), true)
    H.eq(build("simpleui_custom_")[7]:onTapApp(), true)
    H.eq(launched[#launched].action, "android.settings.APPLICATION_DEVELOPMENT_SETTINGS")
    H.eq(#writes, 1) -- launching/painting never changes Android or KOReader preferences
end)
H.test("other five applications and the Settings icon/label are unchanged", function()
    local expected = { "org.mozilla.firefox", "com.sand.airdroid", "com.tailscale.ipn",
        [5] = "com.android.vending", [6] = "com.google.android.apps.nbu.files" }
    for i, pkg in pairs(expected) do
        H.eq(row[2 * i - 1]:onTapApp(), true)
        local intent = launched[#launched]
        H.eq(intent.package, pkg); H.eq(intent.action, nil); H.eq(intent.flags, 0x10000000)
    end
    H.eq(row[7][1][1][1][1].file, "/sdcard/koreader/simpleui_icons/com.android.settings_rw.png")
    H.eq(row[7][1][3][1].text, "Inställningar")
    H.eq(#writes, 1)
end)
H.test("choice is reversible and all new labels/help have Swedish and English translations", function()
    local en = menu()
    en.sub_item_table[1].callback()
    H.eq(tapSettings(), "android.settings.SETTINGS")
    H.eq(#writes, 2); H.eq(writes[2], key); H.eq(flushes, 2); H.eq(refreshes, 2)
    language = "sv_SE"; I18n.reset()
    local sv = menu()
    H.eq(sv.text, "Inställningar-genväg"); H.eq(sv.value_func(), "Android-inställningar")
    H.eq(sv.sub_item_table[1].text, "Android-inställningar")
    H.eq(sv.sub_item_table[2].text, "Utvecklaralternativ")
    H.eq(sv.help_text, "Välj vart Inställningar-ikonen leder på den här enheten. Utvecklaralternativ aktiverar inte felsökning och ändrar inga Android-inställningar.")
    sv.sub_item_table[2].callback()
    H.eq(sv.value_func(), "Utvecklaralternativ")
    language = "en"; I18n.reset()
    H.eq(menu().text, en.text); H.eq(menu().help_text, en.help_text)
end)
H.finish()
