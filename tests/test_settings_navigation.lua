package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
local translate = require("core/orbitui_i18n")
local lang, writes, native_builds, opened, current_profile = "en", 0, 0, nil, nil
G_reader_settings = { readSetting = function(_, key) if key == "language" then return lang end end }
local shown, dialogs, profile_changes = {}, {}, 0
local nativeSettings, widget, plugin
local UI = { show = function(_, dialog) dialogs[#dialogs + 1] = dialog end,
    close = function(_, dialog) dialog.closed = true end,
    isWidgetShown = function(_, w) return w == widget end,
}
package.loaded["ui/uimanager"] = UI
package.loaded["core/orbitui_context"] = {
    plugin = function() return plugin end,
    withShelf = function(profile, fn) profile_changes = profile_changes + 1; current_profile = profile; fn(widget) end,
    notify = function(text) dialogs[#dialogs + 1] = { text = text } end,
}
package.loaded["lib/bookshelf_menu_host"] = {
    show = function(opts) shown[#shown + 1] = opts; return opts end,
    close = function(host) host.closed = true end,
}
package.loaded["ui/widget/buttondialog"] = { new = function(_, dialog) return dialog end }
package.loaded["ui/widget/inputdialog"] = { new = function(_, dialog)
    dialog.getInputText = function(self) return self.input end
    dialog.onShowKeyboard = function(self) self.keyboard = true end
    return dialog
end }
local stored = { hero_regions = { title = { template = "CUSTOM", disabled = false }, tags = {
    disabled = false, show_genres = true, show_collections = false, font_size = 17 },
    rating = { disabled = true }, progress = { template = "MY_PROGRESS" } } }
local store = { read = function(key) return stored[key] end,
    save = function(key, value) writes = writes + 1; stored[key] = value end,
    flush = function() end, generation = function() return writes end }
package.loaded["lib/bookshelf_settings_store"] = store
-- Use the real region resolver and complete native settings module. Only the
-- KOReader native UI boundary is stubbed, not the preference-writing callbacks.
package.loaded["lib/status_line"] = { DEFAULTS = { template = "%clock" } }
local R = dofile(root .. "/components/bookshelf/lib/bookshelf_hero_regions.lua")
package.loaded["lib/bookshelf_hero_regions"] = R
local function loadModule(path, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadfile(path)), env)() end
    return assert(loadfile(path, "t", env))()
end
local dependencies = {
    ["lib/bookshelf_settings_store"] = store, ["ui/uimanager"] = UI,
    ["lib/bookshelf_i18n"] = { gettext = translate },
    ["ffi/util"] = { template = function(text, ...) local args = { ... }
        return (text:gsub("%%(%d)", function(i) return tostring(args[tonumber(i)]) end)) end },
    ["lib/bookshelf_menu_icons"] = { RESET = "reset", label = function(_, text) return text end },
    ["lib/bookshelf_fonts"] = { getUIFontFace = function() return nil end },
}
nativeSettings = loadModule(root .. "/components/bookshelf/lib/bookshelf_settings.lua", {
    require = function(name) return dependencies[name] or package.loaded[name] or {} end,
})
package.loaded["lib/bookshelf_settings"] = nativeSettings
widget = { profile_key = "prose", profile = { key = "prose", label = "Prosa", chips = {} },
    _swapHeroInPlace = function() end, _swapHeroRightColumnInPlace = function() end }
plugin = { _widget = widget }
local Settings = require("adapters/orbitui_settings")
local function find(rows, id)
    for _, row in ipairs(rows) do if row.orbitui_id == id then return row end end
    error("Missing settings ID: " .. tostring(id))
end
local function latest() return shown[#shown] end
local function hit(query, id)
    for _, result in ipairs(Settings.find(query)) do if result.id == id then return result end end
    error("Missing search result: " .. query .. " / " .. id)
end
H.test("the root is search plus exactly five translated task areas, never a growing list of profiles", function()
    for _, locale in ipairs({ "en", "sv_SE" }) do
        lang = locale
        local rows = Settings.items()
        H.eq(#rows, 6)
        H.eq(rows[2].text, translate("Home (SimpleUI)"))
        H.eq(rows[3].orbitui_id, "bookshelf"); H.eq(rows[6].orbitui_id, "system")
    end
end)
H.test("every catalog label and every scope has an explicit Swedish and English representation", function()
    local ids = {}
    for _, item in ipairs(Settings.catalog()) do
        assert(not ids[item.id]); ids[item.id] = true
        H.eq(translate(item.label, "en"), item.label)
        -- Product names are the same in both languages, not missing prose.
        if item.label ~= "Bookshelf" and item.label ~= "BookOrbit" then
            assert(translate(item.label, "sv") ~= item.label, item.label)
        end
        local english = Settings.scopeRow(item.scope).text
        assert(type(english) == "string" and #english > 0)
    end
    for _, scope in ipairs({ "home", "screens", "bookshelf", "theme", "navigation", "system", "integrations", "mixed", "library", "shelf" }) do
        lang = "en"; local en = Settings.scopeRow(scope, "My Library").text
        lang = "sv"; assert(Settings.scopeRow(scope, "My Library").text ~= en)
    end
end)
H.test("settings search is bilingual, case-insensitive, literal and bounded in either UI language", function()
    for _, locale in ipairs({ "en", "sv" }) do
        lang = locale
        hit("VISA GENRER", "panel_show_genres"); hit("Show genres", "panel_show_genres")
        hit("OMSLAG", "covers"); hit("navigation", "navigation"); hit("säkerhetsläge", "safety")
        hit("baksidestext", "panel"); hit("Home SimpleUI", "home")
        hit("Hide single-book series", "maintenance"); hit("Dölj serier och genrer", "maintenance")
        hit("Raka omslagshörn", "covers"); hit("Square cover corners", "covers")
        hit("Bakgrund bakom mapptext", "themes")
        hit("Ordna bibliotek", "libraries"); hit("Order chips", "libraries")
        hit("Placera före", "libraries"); hit("Source", "libraries")
        H.eq(#Settings.find("[.*]"), 0); H.eq(#Settings.find("  "), 0)
        assert(#Settings.find(" ") == 0 and #Settings.find("a") <= 40)
    end
end)
H.test("all statically indexed native phrases are bilingual, with correct UTF-8 and unchanged placeholders", function()
    local count = 0
    for _, item in ipairs(Settings.catalog()) do
        for _, term in ipairs(item.terms) do
            count = count + 1
            assert(not term:find("â", 1, true), term)
            local sv = translate(term, "sv")
            assert(sv ~= term or term == "Normal" or term == "MB" or term == "Metadata", term)
            H.eq(translate(term, "en"), term)
        end
    end
    assert(count >= 300)
end)
H.test("cataloguing and searching never build native settings, open a shelf or write preferences", function()
    local original = nativeSettings._settingsSubItems
    nativeSettings._settingsSubItems = function() native_builds = native_builds + 1; error("eager native build") end
    local before, changed = writes, profile_changes
    Settings.catalog(); Settings.find("covers"); Settings.search("genres")
    H.eq(native_builds, 0); H.eq(writes, before); H.eq(profile_changes, changed)
    nativeSettings._settingsSubItems = original
end)
H.test("the real genre checkbox changes only the existing tags field and repaints through its native callback", function()
    lang = "sv"; local before = writes
    Settings.open("panel", { profile = "prose" })
    local rows = latest().item_table
    assert(rows[1].text:find("alla Bookshelf", 1, true))
    local genre = find(rows, "show_genres"); H.eq(genre.text, "Visa genrer"); H.eq(genre.checked_func(), true)
    genre.callback(); H.eq(genre.checked_func(), false); H.eq(writes, before + 1)
    H.eq(stored.hero_regions.tags.show_collections, false); H.eq(stored.hero_regions.tags.font_size, 17)
    H.eq(stored.hero_regions.title.template, "CUSTOM"); H.eq(stored.hero_regions.progress.template, "MY_PROGRESS")
    genre.callback(); H.eq(genre.checked_func(), true)
end)
H.test("visible on-off switches preserve native defaults and do not require long-press or rewrite templates", function()
    local rows = latest().item_table
    local rating, title = find(rows, "rating"), find(rows, "title")
    H.eq(rating.checked_func(), false); rating.callback(); H.eq(rating.checked_func(), true)
    title.callback(); H.eq(title.checked_func(), false); H.eq(stored.hero_regions.title.template, "CUSTOM")
    title.callback(); H.eq(title.checked_func(), true)
    assert(find(rows, "advanced").sub_item_table_func)
end)
H.test("label switches reflect actual visibility and can re-enable the line without resetting other categories", function()
    local rows = latest().item_table
    local labels, genres = find(rows, "tags"), find(rows, "show_genres")
    labels.callback(); H.eq(labels.checked_func(), false); H.eq(genres.checked_func(), false)
    genres.callback(); H.eq(labels.checked_func(), true); H.eq(genres.checked_func(), true)
    H.eq(stored.hero_regions.tags.show_collections, false); H.eq(stored.hero_regions.tags.font_size, 17)
end)
H.test("a search result opens its one live control, never changes the preference just by opening", function()
    lang = "en"; local before = writes
    Settings.search("Show genres")
    local results = latest(); find(results.item_table, "panel_show_genres").callback()
    assert(results.closed)
    local rows = latest().item_table
    H.eq(#rows, 3); H.eq(rows[2].orbitui_id, "show_genres"); H.eq(writes, before)
    assert(latest().on_back); latest().on_back()
    H.eq(latest().title, "Search settings"); find(latest().item_table, "panel_show_genres")
end)
H.test("Back returns through canonical categories instead of closing the entire settings tree", function()
    Settings.open("panel", { profile = "prose" })
    H.eq(latest().parent_title, "Bookshelf"); latest().on_back()
    H.eq(latest().title, "OrbitUI settings / Bookshelf"); latest().on_back()
    H.eq(latest().title, "OrbitUI settings")
end)
H.test("the real menu host distinguishes nested Back, parent Back and explicit close-all", function()
    local mocked = package.loaded["lib/bookshelf_menu_host"]
    local menu = { new = function(_, opts)
        -- Match actual Menu:init: constructor-supplied paths are discarded.
        opts.paths = {}; opts.page = 1
        opts.page_return_arrow = { enableDisable = function(self, enabled) self.enabled = enabled end }
        opts.switchItemTable = function(self, title, rows) self.title = title; self.item_table = rows end
        return opts
    end }
    package.loaded["ui/widget/menu"] = menu
    package.loaded.device = { screen = { getWidth = function() return 600 end, getHeight = function() return 800 end } }
    package.loaded["lib/bookshelf_i18n"] = { gettext = translate }
    local Host = dofile(root .. "/components/bookshelf/lib/bookshelf_menu_host.lua")
    local backs, closes = 0, 0
    local function show()
        return Host.show{ title = "Panel", item_table = {}, parent_title = "Bookshelf",
            on_back = function() backs = backs + 1 end, close_callback = function() closes = closes + 1 end }
    end
    local h = show(); H.eq(#h._menu.paths, 1); H.eq(h._menu.page_return_arrow.enabled, true)
    h:_push("Nested", {}, {}); h._menu.onReturn(); H.eq(backs, 0); H.eq(#h._stack, 1)
    h._menu.onReturn(); H.eq(backs, 1); H.eq(closes, 1); assert(h._closed)
    h._menu.onReturn(); H.eq(backs, 1)
    h = show(); h._menu.onCloseAllMenus(); H.eq(backs, 1); H.eq(closes, 2)
    package.loaded["lib/bookshelf_menu_host"] = mocked
end)
H.test("visible profile context is preserved but global BookShelf settings are honestly labelled global", function()
    local before = profile_changes
    Settings.open("panel"); H.eq(profile_changes, before); H.eq(widget.profile_key, "prose")
    assert(latest().item_table[1].text:find("all Bookshelf", 1, true))
    Settings.open("panel", { profile = "comics" }); H.eq(current_profile, "comics")
end)
H.test("a newer settings destination cancels a deferred library opener before it can display stale settings", function()
    local C = package.loaded["core/orbitui_context"]
    local old, deferred, guard = C.withShelf
    C.withShelf = function(_, callback, opts) deferred, guard = callback, opts.is_current end
    Settings.library("comics")
    assert(guard()); Settings.open("home"); assert(not guard())
    local expected = latest(); deferred(widget); H.eq(latest(), expected)
    C.withShelf = old
end)
H.test("native controls are selected by stable IDs and unclassified future controls remain available", function()
    local rows = nativeSettings:_settingsSubItems()
    H.eq(find(rows, "settings.covers").text, "Cover display")
    H.eq(find(rows, "settings.text").text, "Text size")
    local build = nativeSettings._settingsSubItems
    nativeSettings._settingsSubItems = function(self)
        local result = build(self); table.insert(result, 1, { orbitui_id = "future", text = "Future upstream control" }); return result
    end
    Settings.open("covers"); H.eq(#latest().item_table, 2)
    H.eq(latest().item_table[2].orbitui_id, "settings.covers")
    local old = nativeSettings._coverDisplaySubItems
    nativeSettings._coverDisplaySubItems = function() return { { text = "Native child", sub_item_table = { { text = "Nested" } } } } end
    local sub = latest().item_table[2].sub_item_table_func()
    H.eq(sub[1].text, "Applies to: all Bookshelf libraries"); H.eq(sub[2].text, "Native child")
    H.eq(sub[2].sub_item_table_func()[1].text, "Applies to: all Bookshelf libraries")
    nativeSettings._coverDisplaySubItems = old
    Settings.open("bookshelf_advanced"); H.eq(find(latest().item_table, "future").text, "Future upstream control")
    nativeSettings._settingsSubItems = build
end)
H.test("SimpleUI titles distinguish Home, global controls and a named custom screen without changing context", function()
    local state = { screen_id = "hs", pfx = "simpleui_hs_", layout_key = "simpleui_layout" }
    local titles = { pages = function() return "Pages" end, bars_settings = "Bars", style_settings = "Style" }
    Settings.homeTitles(titles, state)
    H.eq(titles.home_screen_settings, "Home (SimpleUI)"); H.eq(titles.pages(), "Pages — Home (SimpleUI)")
    H.eq(titles.bars_settings(), "Bars — All SimpleUI screens")
    state.screen_id, state.screen_name = "custom_1", "My Manga"
    H.eq(titles.pages(), "Pages — SimpleUI screen: My Manga")
    H.eq(state.layout_key, "simpleui_layout"); H.eq(state.pfx, "simpleui_hs_")
end)
H.test("the complete SimpleUI settings window applies hosted titles before constructing or painting its native window", function()
    local expected, constructed = nil, 0
    local deps = {
        ["ui/uimanager"] = UI, ["infra/sui_core"] = {},
        ["infra/sui_i18n"] = { translate = translate },
        ["engines/sui_window"] = { paramsTitle = function(default)
            return function(ctx) local cur = ctx.current(); return cur and cur.params and cur.params.title or default end
        end, new = function(_, opts)
            constructed = constructed + 1
            if expected then H.eq(opts.screen_titles.__root__, expected) end
            opts._nav_stack = { { id = "__root__" } }
            opts.show = function(self) self.painted = true end
            return opts
        end },
        ["infra/sui_config"] = { isNavpagerEnabled = function() return false end },
        ["infra/sui_layout"] = { load = function() return { pages = {} } end },
    }
    local function loadWindow()
        return loadModule(root .. "/components/simpleui/screens/sui_settings_window.lua", {
            require = function(name) return deps[name] or {} end,
        })
    end
    local native = loadWindow(); local standalone = native:show(nil, "pages")
    assert(standalone.painted); H.eq(standalone._nav_stack[2].id, "pages")
    local hosted = require("adapters/orbitui_ui").wrap("screens/sui_settings_window", loadWindow())
    expected = "Advanced SimpleUI settings"
    local win = hosted:show(nil, "pages")
    H.eq(win.screen_titles.home_screen_settings, "Home (SimpleUI)")
    assert(win.screen_titles.pages():find("Home (SimpleUI)", 1, true))
    lang = "sv"; expected = "Avancerade SimpleUI-inställningar"
    win = hosted:show(nil, "pages", { screen_id = "custom", screen_name = "Min egen skärm", pfx = "unchanged_" })
    assert(win.screen_titles.pages():find("SimpleUI-skärm: Min egen skärm", 1, true))
    H.eq(constructed, 3); lang = "en"
end)
H.test("book-panel shortcut preserves the real details action and cancellation writes nothing", function()
    local book, details = { filepath = "/book.epub" }, 0
    widget._showBookDetail = function(_, b, opts) H.eq(b, book); H.eq(opts.active, "edit"); details = details + 1 end
    local before = writes; local dialog = Settings.heroMenu(widget, book)
    dialog.buttons[2][1].callback(); H.eq(details, 1); assert(dialog.closed)
    dialog = Settings.heroMenu(widget, book); dialog.buttons[3][1].callback(); H.eq(writes, before)
    dialog = Settings.heroMenu(widget, book); dialog.buttons[1][1].callback()
    H.eq(latest().title, "OrbitUI settings / Book panel at the top"); H.eq(writes, before)
end)
H.test("search dialog cancel, empty results and HTML-like text are inert", function()
    local before = writes; local dialog = Settings.search()
    assert(dialog.keyboard); dialog.buttons[1][1].callback(); assert(dialog.closed)
    dialog = Settings.search(); dialog.input = "<script>.*"; dialog.buttons[1][2].callback()
    H.eq(#latest().item_table, 2); H.eq(writes, before)
end)
H.test("native translator bridge preserves pre-existing translations and never replaces global gettext", function()
    local Integration = require("adapters/orbitui_ui")
    local original = package.loaded.gettext
    local native = { gettext = function(text) return text == "Custom" and "User patch" or text end }
    Integration.wrap("lib/bookshelf_i18n", native)
    lang = "sv"; H.eq(native.gettext("Show tags line"), "Visa etikettraden"); H.eq(native.gettext("Custom"), "User patch")
    lang = "en"; H.eq(native.gettext("Show tags line"), "Show tags line"); H.eq(package.loaded.gettext, original)
end)
H.finish()
