package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Updates = require("adapters/orbitui_updates")
local root = H.root()
local bookshelf = Updates.component("bookshelf", root)
local simpleui = Updates.component("simpleui", root)
local messages = {}
package.loaded["ui/uimanager"] = { show = function(_, msg) messages[#messages + 1] = msg.text end }
package.loaded["ui/widget/infomessage"] = { new = function(_, msg) return msg end }

local function source(path)
    local file = assert(io.open(path))
    local text = file:read("*a")
    file:close()
    return text
end

-- Exercise the real menu builders without loading the KOReader widget stack.
local function compile(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "update menus", "t", env))()
end
local function translate(text) return text end
local function componentRequire(name)
    if name == "lib/bookshelf_updater" then return bookshelf end
    if name == "infra/sui_updater" then return simpleui end
    if name == "infra/sui_paths" then
        return { getPluginDirNoSlash = function() return root .. "/components/simpleui" end }
    end
    error("Unexpected menu dependency: " .. name)
end

local update_body = assert(source("components/bookshelf/lib/bookshelf_settings.lua")
    :match("\nfunction Settings:_updateSubItems%(%)\n(.-)\nend\n"))
local buildBookshelfItems = compile("return function(self)\n" .. update_body .. "\nend", {
    _ = translate, require = componentRequire, ICON_RESET = "",
})
local settings = {
    _updateSubItems = buildBookshelfItems,
    _plugin = { checkForUpdates = function() bookshelf.check() end },
}
local bookshelf_entry = assert(source("components/bookshelf/main.lua")
    :match("menu_items%.bookshelf_updates = ({.-})\n\n    menu_items%.bookshelf_about"))
local buildBookshelfEntry = compile("return function() return " .. bookshelf_entry .. " end", {
    _ = translate, require = componentRequire, S = settings,
    MenuIcons = { label = function(_, text) return text end },
})

local about_body = assert(source("components/simpleui/screens/sui_menu.lua")
    :match("local function makeAboutMenuItems%(ctx_menu%)\n(.-)\n    end\n    plugin%.makeAboutMenuItems"))
local buildSimpleUIItems = compile("return function(ctx_menu)\n" .. about_body .. "\nend", {
    _ = translate, require = componentRequire,
    dofile = function() return { name = "simpleui" } end,
})

local function findItem(items, text)
    for _, item in ipairs(items) do
        if (item.text_func and item.text_func() or item.text) == text then return item end
    end
    error("Missing menu item: " .. text)
end

local function opensOrbitUI(item)
    local before = #messages
    item.callback()
    H.eq(#messages, before + 1)
    assert(messages[#messages]:find("OrbitUI", 1, true))
end

H.test("Bookshelf update menu and check action show the common label", function()
    local entry = buildBookshelfEntry()
    H.eq(entry.text_func(), "Uppdatera OrbitUI")
    local action = entry.sub_item_table_func()[1]
    H.eq(action.text_func and action.text_func() or action.text, "Uppdatera OrbitUI")
    opensOrbitUI(action)
end)
H.test("SimpleUI About update action shows the common label and opens OrbitUI", function()
    opensOrbitUI(findItem(buildSimpleUIItems(), "Uppdatera OrbitUI"))
end)
H.test("component menus retain their standalone labels without adapter metadata", function()
    bookshelf.menuLabel, bookshelf.menuItems, simpleui.menuLabel = nil, nil, nil
    bookshelf.getInstalledVersion = function() return "5.3.1" end
    H.eq(buildBookshelfEntry().text_func(), "Updates")
    assert(buildBookshelfItems(settings)[1].text_func():find("Check for updates", 1, true))
    assert(findItem(buildSimpleUIItems(), "Check for Updates").callback)
end)
H.test("hosted Bookshelf menus contain only real OrbitUI version and channel controls", function()
    local saved, flushes = { orbitui_update_preview = false }, 0
    G_reader_settings = {
        readSetting = function(_, key) return saved[key] end,
        isTrue = function(_, key) return saved[key] == true end,
        saveSetting = function(_, key, value) saved[key] = value end,
        flush = function() flushes = flushes + 1 end,
    }
    Updates.configure{ root = root, version = "0.1.0-beta.42", slot = "factory" }
    bookshelf.menuItems = Updates.menuItems
    local items = buildBookshelfItems(settings)
    H.eq(items[1].text, "Installed: OrbitUI 0.1.0-beta.42")
    local preview = findItem(items, "Include preview releases")
    H.eq(preview.checked_func(), false) -- Explicit old choice still wins.
    preview.callback(); H.eq(saved.orbitui_update_preview, true)
    findItem(items, "Check daily when online").callback()
    H.eq(saved.orbitui_update_auto, true); H.eq(flushes, 2)
    for _, item in ipairs(items) do
        local label = item.text_func and item.text_func() or item.text
        assert(not label:find("6.0.", 1, true) and not label:find("branch", 1, true))
        assert(not label:find("wake", 1, true) and not label:find("changelog", 1, true))
    end
    H.eq(saved.bookshelf_dev_branch, nil); H.eq(saved.bookshelf_check_updates, nil)
    saved.language = "sv"
    H.eq(buildBookshelfItems(settings)[1].text, "Installerad: OrbitUI 0.1.0-beta.42")
    saved.language = "en"
    local shown, closed
    package.loaded["ui/uimanager"].show = function(_, value) shown = value end
    package.loaded["ui/uimanager"].close = function() closed = (closed or 0) + 1 end
    package.loaded["ui/widget/buttondialog"] = { new = function(_, value) return value end }
    Updates.show()
    H.eq(shown.title, "OrbitUI 0.1.0-beta.42")
    H.eq(shown.buttons[1][1].enabled, false)
    assert(shown.buttons[3][1].text:find("[x] Include preview releases", 1, true))
    shown.buttons[3][1].callback()
    H.eq(saved.orbitui_update_preview, false); H.eq(closed, 1)
    assert(shown.buttons[3][1].text:find("[ ] Include preview releases", 1, true))
    shown.buttons[4][1].callback()
    H.eq(saved.orbitui_update_auto, false); H.eq(closed, 2)
    H.eq(shown.buttons[5][1].enabled, false)
    H.eq(shown.buttons[6][1].enabled, false)
end)
H.finish()
