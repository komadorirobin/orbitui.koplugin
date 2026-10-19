package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Model = require("core/orbitui_setup")
local Libraries = require("core/orbitui_libraries")
local function snapshot()
    return { libraries = { version = 1, sections = {
        { key = "comics", label = "Manga", roots = { "/Books/Manga" }, chips = {
            { key = "oneshots", label = "Oneshots", source = { kind = "folder", id = "/Books/Manga/Oneshots" }, group_folder_name = "Oneshots" },
        } },
    } }, layout = { pages = { { id = 5, modules = { { id = "currently", width = 60 }, "hardcover" }, gap = 22 } } },
        order = { "currently", "hardcover", "bookorbit_want", "__page_break__", "recent" },
        tabs = { "homescreen", "bookshelf_comics", "custom_qa_2" }, start = "last", dashboard = false }
end

H.test("existing setup defaults to keeping everything with zero preference writes", function()
    local current = snapshot()
    local draft = Model.draft(current)
    H.eq(draft.home, "keep"); H.eq(draft.bar, "keep")
    H.eq(#Model.plan(draft, current), 0)
end)
H.test("appearance drafts write only the preset and reject concurrent changes or invalid IDs", function()
    local current = snapshot(); current.appearance = "classic"
    local draft = Model.draft(current); draft.appearance = "minimal"
    local writes = Model.plan(draft, current)
    H.eq(#writes, 1); H.eq(writes[1].store, "setup"); H.eq(writes[1].key, "appearance")
    H.eq(writes[1].value.preset, "minimal"); H.eq(current.appearance, "classic")
    current.appearance = "native"; H.eq(pcall(Model.plan, draft, current), false)
    current.appearance = "classic"; draft.appearance = "unknown"; H.eq(pcall(Model.plan, draft, current), false)
end)
H.test("draft folder and label changes do not touch originals or lose stable shelf settings", function()
    local current = snapshot()
    local draft = Model.draft(current)
    draft.libraries.sections[1].label = "Comics"
    Model.relocate(draft.libraries.sections[1], "/Books/Manga", "/SD/Comics")
    local plan = Model.plan(draft, current, { directory = function(path) return path == "/SD/Comics" end })
    H.eq(#plan, 1); H.eq(plan[1].store, "bookshelf")
    H.eq(plan[1].value.sections[1].chips[1].source.id, "/SD/Comics/Oneshots")
    H.eq(plan[1].value.sections[1].chips[1].group_folder_name, "Oneshots")
    H.eq(current.libraries.sections[1].roots[1], "/Books/Manga")
    H.eq(current.libraries.sections[1].label, "Manga")
end)
H.test("new sections use unique generic IDs and local sources", function()
    local draft = Model.draft(snapshot())
    H.eq(Model.add(draft, "Poetry", "/Poetry/"), "section_1")
    H.eq(Model.add(draft, "History", "/History"), "section_2")
    for _, section in ipairs(draft.libraries.sections) do
        for _, chip in ipairs(section.chips) do assert(chip.source.kind ~= "bookorbit_want") end
    end
    H.eq(draft.libraries.sections[2].roots[1], "/Poetry")
    assert(not pcall(Model.add, draft, "Bad", "/../Books"))
end)
H.test("dashboard adds a separate page without changing existing pages, sources or book-close target", function()
    local current = snapshot()
    local draft = Model.draft(current); draft.home = "dashboard"
    local changes = Model.plan(draft, current)
    local by_key = {}
    for _, change in ipairs(changes) do by_key[change.key] = change.value end
    H.eq(by_key.start_with, "homescreen_simpleui")
    H.eq(by_key.simpleui_layout.pages[1].modules[1], "orbitui_dashboard")
    assert(Model.equal(by_key.simpleui_layout.pages[2], current.layout.pages[1]))
    H.eq(by_key.simpleui_hs_orbitui_dashboard_enabled, true)
    assert(not by_key.simpleui_hs_book_close_target)
    assert(not by_key.simpleui_hs_orbitui_dashboard_config)
    for _, id in ipairs(by_key.simpleui_hs_module_order) do assert(id ~= "__page_break__") end
    H.eq(#current.layout.pages, 1)
end)
H.test("Home or file browser choices change only the launch target", function()
    for _, choice in ipairs({ "home", "files" }) do
        local current = snapshot(); local draft = Model.draft(current); draft.home = choice
        local changes = Model.plan(draft, current)
        H.eq(#changes, 1); H.eq(changes[1].key, "start_with")
        H.eq(changes[1].value, choice == "files" and "filemanager" or "homescreen_simpleui")
    end
end)
H.test("bottom bar requires valid unique actions and respects the navigation-pager limit", function()
    local current = snapshot(); local draft = Model.draft(current)
    draft.bar = "custom"; draft.tabs = { "homescreen", "orbitui_library_section_1" }
    local options = { max_tabs = 4, actions = { homescreen = true, orbitui_library_section_1 = true } }
    local changes = Model.plan(draft, current, options)
    H.eq(#changes, 2); H.eq(changes[1].value[2], "orbitui_library_section_1")
    draft.tabs[3] = "homescreen"; assert(not pcall(Model.plan, draft, current, options))
    draft.tabs = { "unknown", "homescreen" }; assert(not pcall(Model.plan, draft, current, options))
    draft.tabs = { "homescreen" }; assert(not pcall(Model.plan, draft, current, options))
    options.max_tabs = 1; draft.tabs[2] = "orbitui_library_section_1"
    assert(not pcall(Model.plan, draft, current, options))
end)
H.test("stale drafts, nonexistent new folders and unknown schemas fail before storage", function()
    local current = snapshot(); local draft = Model.draft(current)
    current.start = "filemanager"
    assert(not pcall(Model.plan, draft, current))
    current = snapshot(); draft = Model.draft(current); Model.add(draft, "Missing", "/missing")
    assert(not pcall(Model.plan, draft, current, { directory = function() return false end }))
    draft = Model.draft(current); draft.libraries.version = 999
    assert(not pcall(Model.plan, draft, current))
end)
H.test("unavailable old removable-drive roots are preserved on unrelated edits", function()
    local current = snapshot(); local draft = Model.draft(current)
    draft.libraries.sections[1].label = "My manga"
    H.eq(#Model.plan(draft, current, { directory = function() return false end }), 1)
end)
H.test("save failures restore touched values including absent keys, without resetting unrelated data", function()
    local data, count = { history = "untouched", first = "old" }, 0
    local store = { read = function(key) return data[key] end, write = function(key, value) data[key] = value end,
        flush = function() count = count + 1; if count == 1 then error("disk full") end end }
    local ok, err, restored = Model.commit({ { store = "s", key = "first", value = "new" },
        { store = "s", key = "second", value = "added" } }, { s = store })
    H.eq(ok, nil); assert(err:find("disk full")); H.eq(restored, true)
    H.eq(data.first, "old"); H.eq(data.second, nil); H.eq(data.history, "untouched")
end)
H.test("completion marker is flushed last, and persistent rollback failures are reported", function()
    local order = {}
    local function store(name)
        return { read = function() end, write = function() end, flush = function() order[#order + 1] = name end }
    end
    assert(Model.commit({ { store = "prefs", key = "x", value = true },
        { store = "setup", key = "setup", value = true } }, { prefs = store("prefs"), setup = store("setup") }))
    H.eq(table.concat(order, ","), "prefs,setup")
    local bad = store("bad"); bad.flush = function() error("still full") end
    local ok, _, restored = Model.commit({ { store = "bad", key = "x" } }, { bad = bad })
    H.eq(ok, nil); H.eq(restored, false)
end)
H.finish()
