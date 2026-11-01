local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local values, writes, flushes, refreshes, launched, language = {}, {}, 0, 0, {}, "en"
local saved, app_writes, shown, closed, warnings = {}, {}, {}, {}, {}
local apps_key = "simpleui_app_launcher_apps_v1"
local query_rows, queries, frames, pending_exception, query_fault, android_device = {}, 0, 0, 0, nil, true
local key = "simpleui_app_launcher_settings_target"
G_reader_settings = {
    data = values,
    readSetting = function(_, k) if k == "language" then return language end; return values[k] end,
    saveSetting = function(_, k, v) values[k] = v; writes[#writes + 1] = k end,
    flush = function() flushes = flushes + 1 end,
}
local W = H.widget()
function W:getSize() return self.dimen or { w = self.max_width or #(self.text or "") * 6, h = 20 } end
function W:getInputText() return self.input end
function W:onShowKeyboard() self.keyboard_shown = true end
for _, name in ipairs({ "container/centercontainer", "container/framecontainer", "container/inputcontainer",
        "horizontalgroup", "horizontalspan", "imagewidget", "infomessage", "textwidget",
        "verticalgroup", "verticalspan" }) do
    package.loaded["ui/widget/" .. name] = W
end
package.loaded["ui/geometry"], package.loaded["ui/gesturerange"] = W, W
package.loaded.device = { isAndroid = function() return android_device end,
    screen = { scaleBySize = function(_, n) return n end, getWidth = function() return 1000 end } }
package.loaded["ffi/blitbuffer"] = { gray = function(n) return n end, COLOR_BLACK = 0 }
package.loaded["ui/font"] = { getFace = function() return {} end }
package.loaded.logger = { dbg = function() end, info = function() end,
    warn = function(message) warnings[#warnings + 1] = message end }
package.loaded["ui/uimanager"] = {
    show = function(_, widget) shown[#shown + 1] = widget end,
    close = function(_, widget) assert(widget); closed[widget] = true end,
}
for _, name in ipairs({"menu", "inputdialog", "confirmbox"}) do package.loaded["ui/widget/" .. name] = W end
package.loaded["infra/sui_store"] = {
    readSetting = function(_, k) return saved[k] end,
    saveSetting = function(_, k, v) saved[k] = v; app_writes[#app_writes + 1] = k end,
}
package.loaded["engines/sui_page_nav"] = { buildPager = function(page, total, h, text, gap, turn)
    return W:new{ _test_pager = true, page = page, total = total, turn = turn, text = text, height = h }, {}
end }
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
    string = function(buf, n) return buf.text:sub(1, n) end,
    new = function(kind, size)
        local array = {}
        for i = 0, (size or tonumber(kind:match("%[(%d+)%]"))) - 1 do array[i] = {} end
        return array
    end,
}
function api.GetObjectClass(_, object) return object end
function api.GetMethodID(_, _, method) return method end
function api.CallObjectMethod(_, _, method) H.eq(method, "getPackageManager"); return {} end
function api.FindClass(_, name) return name end
function api.NewStringUTF(_, text) return text end
function api.DeleteLocalRef() end
function api.ExceptionCheck() return pending_exception end
function api.ExceptionClear() pending_exception = 0 end
function api.PushLocalFrame() frames = frames + 1; return 0 end
function api.PopLocalFrame() frames = frames - 1; assert(frames >= 0) end
function api.GetFieldID(_, _, field) return field end
function api.GetObjectField(_, object, field) return object[field] end
function api.CallIntMethodA(_, object, method)
    H.eq(method, "size"); return #object
end
function api.GetArrayLength(_, bytes) return #bytes end
function api.GetByteArrayRegion(_, bytes, offset, n, buf)
    H.eq(offset, 0); H.eq(n, #bytes); buf.text = bytes
end
function api.NewObjectA(_, _, method, args)
    H.eq(method, "<init>"); return { action = args[0].l }
end
function api.CallObjectMethodA(_, object, method, args)
    if method == query_fault then pending_exception = 1; return nil end
    if method == "getPackageManager" then return {} end
    if method == "queryIntentActivities" then
        queries = queries + 1
        H.eq(args[0].l.action, "android.intent.action.MAIN")
        H.eq(args[0].l.category, "android.intent.category.LAUNCHER"); H.eq(args[1].i, 0)
        return query_rows
    end
    if method == "addCategory" then object.category = args[0].l; return object end
    if method == "get" then return object[args[0].i + 1] end
    if method == "loadLabel" then return object.label end
    if method == "toString" then return object end
    if method == "getBytes" then H.eq(args[0].l, "UTF-8"); return object end
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
package.loaded["infra/sui_i18n"] = I18n
local M = H.componentModule(root, "modules/module_app_launcher")
local function build(pfx, width, ctx)
    values[pfx .. "app_launcher_enabled"] = true
    -- Reuse disk icons. Fetching Android artwork is unrelated to intent routing.
    local open = io.open
    io.open = function(path, ...)
        if path:find("/sdcard/koreader/simpleui_icons/", 1, true) == 1 then return { close = function() end } end
        return open(path, ...)
    end
    ctx = ctx or {}; ctx.pfx = pfx
    local ok, widget = pcall(M.build, width or 1000, ctx)
    io.open = open
    assert(ok, widget)
    return widget[1], widget
end
local row = build("simpleui_hs_")
local function menu(pfx)
    local items = M.getMenuItems{ pfx = pfx or "simpleui_hs_", _ = I18n.translate,
        refresh = function() refreshes = refreshes + 1 end }
    for _, item in ipairs(items) do if item.text == I18n.translate("Settings shortcut") then return item end end
    error("Settings target menu missing")
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

local function fixture(list)
    values, writes, flushes, refreshes, launched = {}, {}, 0, 0, {}
    G_reader_settings.data = values
    saved, app_writes, shown, closed, warnings = {}, {}, {}, {}, {}
    saved[apps_key] = list
    query_rows, queries, frames, pending_exception, query_fault, android_device = {}, 0, 0, 0, nil, true
    language = "en"; I18n.reset()
    M = H.componentModule(root, "modules/module_app_launcher")
end
local function app(pkg, label) return { package = pkg, label = label or pkg } end
local function appMenu()
    local items = M.getMenuItems{ pfx = "simpleui_hs_", _ = I18n.translate,
        refresh = function() refreshes = refreshes + 1 end }
    H.eq(items[1].text, I18n.translate("Apps"))
    return items[1].sub_item_table_func(), items[1]
end
local function picker()
    appMenu()[1].callback()
    return shown[#shown]
end
local function nativeApp(pkg, label) return { activityInfo = { packageName = pkg }, label = label or pkg } end
local function sheet(pkg)
    for _, item in ipairs(appMenu()) do
        if item.sub_item_table_func then
            local list = item.sub_item_table_func()
            -- The package is a stable identity even after rename/reorder.
            local current = saved[apps_key]
            for i, entry in ipairs(current or {}) do
                if entry.package == pkg and item.text == string.format("%d. %s", i, entry.label) then return list end
            end
        end
    end
    error("missing app " .. pkg)
end
local function findPager(widget)
    if type(widget) ~= "table" then return end
    if widget._test_pager then return widget end
    for _, child in ipairs(widget) do local found = findPager(child); if found then return found end end
end
H.test("cold load, paint and settings construction never query apps or write preferences", function()
    fixture()
    local row = build("simpleui_hs_")
    H.eq(#row, 11); H.eq(select(2, appMenu()).value_func(), "6")
    H.eq(queries, 0); H.eq(#app_writes, 0); H.eq(#writes, 0)
    H.eq(row[1].ges_events.HoldMod, nil) -- existing module wrapper owns hold/release
end)
H.test("newly enabled modules start empty and an empty placeholder can open its settings", function()
    fixture()
    M.setEnabled("simpleui_hs_", true)
    H.eq(#saved[apps_key], 0); H.eq(#app_writes, 1)
    local opened
    local _, widget = build("simpleui_hs_", 1000, { open_settings_fn = function(id) opened = id end })
    H.eq(widget:onTapApp(), true); H.eq(opened, "app_launcher")
    H.eq(menu().enabled_func(), false)
    H.eq(M.getHeight{ pfx = "simpleui_hs_", col_w = 1000 }, widget.dimen.h)
    M = H.componentModule(root, "modules/module_app_launcher")
    H.eq(select(2, appMenu()).value_func(), "0"); H.eq(queries, 0)
end)
H.test("a legacy module on any custom page keeps the old choices when enabling another page", function()
    fixture()
    values.simpleui_cs_test_app_launcher_enabled = true
    M.setEnabled("simpleui_hs_", true)
    H.eq(saved[apps_key], nil); H.eq(select(2, appMenu()).value_func(), "6")
    H.eq(#app_writes, 0)
end)
H.test("the public launcher query deduplicates and sorts native UTF-8 names without launching anything", function()
    fixture({ app("org.example.beta", "Existing") })
    query_rows = {
        nativeApp("org.example.books", "📚 中文"), nativeApp("org.example.beta", "beta"),
        nativeApp("org.example.alpha", "Alpha"), nativeApp("org.example.alpha", "Duplicate activity"),
        { label = "No activity" }, nativeApp("../../bad", "Invalid"),
    }
    local p = picker()
    H.eq(queries, 1); H.eq(frames, 0); H.eq(pending_exception, 0)
    H.eq(#p.item_table, 4); H.eq(p.item_table[2].text, "Alpha  (org.example.alpha)")
    H.eq(p.item_table[3].text, "beta  (org.example.beta)"); H.eq(p.item_table[3].enabled, false)
    H.eq(p.item_table[4].text, "📚 中文  (org.example.books)")
    H.eq(#launched, 0); H.eq(#app_writes, 0)
    p.item_table[4].callback()
    H.eq(saved[apps_key][2].package, "org.example.books"); H.eq(saved[apps_key][2].label, "📚 中文")
    H.eq(closed[p], true); H.eq(#app_writes, 1); H.eq(app_writes[1], apps_key); H.eq(refreshes, 1)
    M = H.componentModule(root, "modules/module_app_launcher")
    H.eq(select(2, appMenu()).value_func(), "2")
end)
H.test("duplicate adds cannot overwrite an existing custom name or duplicate the entry", function()
    fixture({ app("org.example.alpha", "My Alpha") })
    query_rows = { nativeApp("org.example.alpha", "Alpha") }
    local p = picker()
    H.eq(p.item_table[2].enabled, false)
    p.item_table[2].callback()
    H.eq(saved[apps_key][1].label, "My Alpha"); H.eq(#saved[apps_key], 1); H.eq(#app_writes, 0)
end)
H.test("query exceptions release both JNI frames, clear Java errors and offer manual entry", function()
    for _, fault in ipairs({ "queryIntentActivities", "get", "loadLabel", "getBytes" }) do
        fixture({})
        query_rows = { nativeApp("org.example.alpha", "Alpha") }; query_fault = fault
        local p = picker()
        H.eq(frames, 0, fault); H.eq(pending_exception, 0, fault)
        H.eq(#p.item_table, 2); H.eq(p.item_table[1].text, "Add by package name…")
        H.eq(p.item_table[2].enabled, false); H.eq(#app_writes, 0); H.eq(#warnings, 1)
        assert(not warnings[1]:find("Alpha", 1, true), "installed inventory must not enter logs")
    end
end)
H.test("oversized discovery results fail boundedly, and non-Android never enters JNI", function()
    fixture({})
    for i = 1, 2049 do query_rows[i] = nativeApp("org.example.a" .. i) end
    H.eq(#picker().item_table, 2); H.eq(frames, 0); H.eq(#app_writes, 0)
    fixture({}); android_device = false
    H.eq(#picker().item_table, 2); H.eq(queries, 0); H.eq(frames, 0)
end)
H.test("manual entry cancels cleanly, rejects unsafe package/path strings and persists only a valid choice", function()
    fixture({})
    local p = picker(); p.item_table[1].callback()
    local dialog = shown[#shown]
    H.eq(dialog.keyboard_shown, true); H.eq(#app_writes, 0)
    dialog.buttons[1][1].callback(); H.eq(closed[dialog], true); H.eq(#app_writes, 0)
    p.item_table[1].callback(); dialog = shown[#shown]
    for _, bad in ipairs({ "", "../../evil", "org..app", "org.app.", "org/app", "org.example;rm", "org.app\nother" }) do
        dialog.input = bad; dialog.buttons[1][2].callback()
        H.eq(#app_writes, 0, bad); H.eq(closed[dialog], nil)
    end
    dialog.input = "  org.example.manual  "; dialog.buttons[1][2].callback()
    H.eq(saved[apps_key][1].package, "org.example.manual"); H.eq(#app_writes, 1)
    H.eq(closed[dialog], true); H.eq(closed[p], true); H.eq(#launched, 0)
end)
H.test("rename is cancellable, Unicode-safe and preserves the package/action", function()
    fixture({ { package = "com.android.settings", label = "Settings", action = "android.settings.SETTINGS" } })
    sheet("com.android.settings")[2].callback()
    local dialog = shown[#shown]
    dialog.input = "Cancelled"; dialog.buttons[1][1].callback()
    H.eq(saved[apps_key][1].label, "Settings"); H.eq(#app_writes, 0)
    sheet("com.android.settings")[2].callback(); dialog = shown[#shown]
    for _, bad in ipairs({ "", string.rep("å", 129) }) do
        dialog.input = bad; dialog.buttons[1][2].callback(); H.eq(#app_writes, 0)
    end
    dialog.input = "Min 📚 中文"; dialog.buttons[1][2].callback()
    H.eq(saved[apps_key][1].label, "Min 📚 中文")
    H.eq(saved[apps_key][1].action, "android.settings.SETTINGS"); H.eq(#app_writes, 1)
end)
H.test("move describes the exact neighbour and immediately exposes the new position", function()
    fixture({ app("org.example.a", "A"), app("org.example.b", "B"), app("org.example.c", "C") })
    local a = sheet("org.example.a")
    H.eq(a[1].text, "Position 1 of 3"); H.eq(a[3].enabled, false); H.eq(a[4].text, "Move after B")
    a[4].callback()
    H.eq(saved[apps_key][1].label, "B"); H.eq(saved[apps_key][2].label, "A")
    local updated = sheet("org.example.a")
    H.eq(updated[1].text, "Position 2 of 3"); H.eq(updated[3].text, "Move before B")
    H.eq(updated[4].text, "Move after C"); H.eq(appMenu()[3].text, "2. A")
    updated[3].callback(); H.eq(saved[apps_key][1].label, "A"); H.eq(#app_writes, 2)
end)
H.test("remove requires confirmation, resolves stale indices by package and never uninstalls apps", function()
    fixture({ app("org.example.a", "A"), app("org.example.b", "B") })
    local old_a = sheet("org.example.a")
    old_a[5].callback(); local confirm = shown[#shown]
    assert(confirm.text:find("will not be uninstalled", 1, true)); H.eq(#app_writes, 0)
    -- Cancelled confirmations never call ok_callback.
    sheet("org.example.b")[5].callback(); shown[#shown].ok_callback()
    H.eq(#saved[apps_key], 1); H.eq(saved[apps_key][1].label, "A")
    confirm.ok_callback(); H.eq(#saved[apps_key], 0)
    confirm.ok_callback(); H.eq(#app_writes, 2) -- no accidental other deletion on a stale callback
    H.eq(#launched, 0); H.eq(queries, 0)
    M = H.componentModule(root, "modules/module_app_launcher")
    H.eq(select(2, appMenu()).value_func(), "0") -- empty stays empty across restart
end)
H.test("removing and re-adding Settings retains the device-local Developer options destination", function()
    fixture({ app("com.android.settings", "Settings") })
    values[key] = "developer"
    H.eq(menu().enabled_func(), true)
    sheet("com.android.settings")[5].callback(); shown[#shown].ok_callback()
    query_rows = { nativeApp("com.android.settings", "Settings") }
    picker().item_table[2].callback()
    local row = build("simpleui_hs_")
    row[1]:onTapApp()
    H.eq(launched[#launched].action, "android.settings.APPLICATION_DEVELOPMENT_SETTINGS")
    H.eq(values[key], "developer"); H.eq(#writes, 0)
end)
H.test("invalid saved lists are safe in memory, with no automatic repair/write or legacy-list resurrection", function()
    for _, list in ipairs({ "corrupt", { false, app("../bad"), app("org.example.good", "Good"),
            app("org.example.good", "Duplicate"), { package = "org.example.other", label = 42 } } }) do
        fixture(list)
        local _, item = appMenu()
        H.eq(item.value_func(), type(list) == "string" and "0" or "2")
        build("simpleui_hs_"); H.eq(saved[apps_key], list); H.eq(#app_writes, 0); H.eq(queries, 0)
    end
end)
H.test("additional apps paginate, page turns never write settings, and removal clamps the last page", function()
    local list = {}; for i = 1, 7 do list[i] = app("org.example.a" .. i, "App " .. i) end
    fixture(list)
    local turns = 0
    local ctx = { refresh_fn = function() turns = turns + 1 end }
    local content, widget = build("simpleui_hs_", 1000, ctx)
    local pager = assert(findPager(widget)); H.eq(pager.page, 1); H.eq(pager.total, 2)
    H.eq(#content[1], 11)
    pager.turn(1); H.eq(turns, 1); H.eq(#app_writes, 0); H.eq(#writes, 0)
    content, widget = build("simpleui_hs_", 1000, ctx)
    H.eq(findPager(widget).page, 2); H.eq(content[1][1][1][3][1].text, "App 7")
    content[1][1]:onTapApp(); H.eq(launched[#launched].package, "org.example.a7")
    saved[apps_key] = { list[1] }
    content, widget = build("simpleui_hs_", 1000, ctx)
    H.eq(findPager(widget), nil); H.eq(content[1][1][3][1].text, "App 1")
    H.eq(queries, 0); H.eq(#app_writes, 0)
end)
H.test("narrow bento widths fit icons and use more pages rather than overflowing", function()
    local list = {}; for i = 1, 7 do list[i] = app("org.example.a" .. i, "App " .. i) end
    fixture(list)
    for _, width in ipairs({ 180, 60 }) do
        local content, widget = build("simpleui_hs_", width)
        local pager = assert(findPager(widget))
        H.eq(pager.total, width == 180 and 4 or 7)
        local first = content[1][1]
        assert(first.dimen.w <= width - 10)
        H.eq(first[1][3][1].max_width, first.dimen.w)
        assert(M.getHeight{ pfx = "simpleui_hs_", col_w = width } > first.dimen.h)
    end
end)
H.test("the actual pager contributes widgets only and accepts input across overflow pages", function()
    local old_pager, old_core = package.loaded["engines/sui_page_nav"], package.loaded["infra/sui_core"]
    package.loaded["ui/bidi"] = { mirroredUILayout = function() return false end }
    package.loaded["ui/size"] = { padding = { button = 4 } }
    package.loaded["ui/widget/widget"] = W
    package.loaded["infra/sui_aa_paint"] = {}
    package.loaded["features/sui_style"] = { COLOR = { disabled = 1 },
        glyphFace = function() return {} end, icon = function(s) return s end }
    package.loaded["infra/sui_core"] = { PAD = 5, makeColoredText = function(o) return W:new(o) end,
        runWithTapFeedback = function(_, fn) fn() end }
    package.loaded["engines/sui_page_nav"] = H.componentModule(root, "engines/sui_page_nav")
    local list = {}; for i = 1, 7 do list[i] = app("org.example.a" .. i, "App " .. i) end
    fixture(list)
    local turns = 0
    for _, delta in ipairs({ 1, -1 }) do
        local _, widget = build("simpleui_hs_", 1000, { refresh_fn = function() turns = turns + 1 end })
        local arrows = {}
        local function walk(w)
            assert(type(w.handleEvent) == "function", "non-widget in pager input tree")
            if w.onTapPageNav then arrows[#arrows + 1] = w end
            for _, child in ipairs(w) do walk(child) end
        end
        walk(widget)
        H.eq(widget:handleEvent{ handler = "onUnrelatedTouch", args = {} }, nil)
        local native_dir = os.getenv("ORBITUI_NATIVE_INPUT_DIR")
        if native_dir then
            local Native = assert(loadfile(native_dir .. "/widgetcontainer.lua"))()
            local ok, err = pcall(Native.propagateEvent, widget, { handler = "onUnrelatedTouch", args = {} })
            assert(ok, err)
        end
        H.eq(#arrows, 1); arrows[1]:onTapPageNav()
    end
    H.eq(turns, 2); H.eq(#app_writes, 0)
    package.loaded["engines/sui_page_nav"], package.loaded["infra/sui_core"] = old_pager, old_core
end)
H.test("the bounded list refuses a 129th app without discarding existing choices", function()
    local list = {}; for i = 1, 128 do list[i] = app("org.example.a" .. i, "App " .. i) end
    fixture(list)
    query_rows = { nativeApp("org.example.extra", "Extra") }
    picker().item_table[2].callback()
    H.eq(saved[apps_key], list); H.eq(#app_writes, 0)
end)
H.test("all new app-management strings and module name have real Swedish and English translations", function()
    fixture({})
    local strings = {
        "Android apps", "Apps", "Add app…", "Add Android apps…", "Add Android app", "Add by package name…",
        "Android package name (for example org.mozilla.firefox)", "Enter a valid Android package name.",
        "Android did not provide an app list. You can add an app by package name.",
        "This app is already in the module.", "You can add up to %d apps.", "No apps selected.",
        "This app is no longer in the module.", "Position %d of %d", "App name",
        "Enter an app name of at most 128 characters.", "Move before %s", "Move after %s", "Already first", "Already last",
        "Remove from module", "Remove %s from this module? The Android app will not be uninstalled.",
        "Choose apps for this device. Tap an app to rename, move or remove it. Removing a shortcut does not uninstall the app.",
        "Opening %s…", "Could not open %s. The app may be unavailable.",
    }
    for _, text in ipairs(strings) do H.eq(I18n.translate(text), text) end
    language = "sv_SE"; I18n.reset()
    for _, text in ipairs(strings) do assert(I18n.translate(text) ~= text, text) end
    M = H.componentModule(root, "modules/module_app_launcher")
    H.eq(M.name, "Android-appar"); H.eq(appMenu()[1].text, "Lägg till app…")
end)
H.finish()
