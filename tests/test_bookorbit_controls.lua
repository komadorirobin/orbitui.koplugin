local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local saved, queue, client_calls, writes, flushes, during, refreshes = {}, {}, 0, 0, 0, nil, 0
local file = "/books/one.epub"
local UI = { scheduleIn = function(_, _, fn) queue[#queue + 1] = fn end,
    nextTick = function(_, fn) queue[#queue + 1] = fn end }
local Store = { readSetting = function(_, key) return saved[key] end,
    saveSetting = function(_, key, value) saved[key] = value end,
    setNoFlush = function(_, key, value) writes = writes + 1; saved[key] = value end,
    flush = function() flushes = flushes + 1 end,
    nilOrTrue = function(_, key) return saved[key] ~= false end }
package.loaded["infra/sui_store"] = Store
package.loaded["ui/uimanager"] = UI
package.loaded["ui/network/manager"] = { isConnected = function() return true end }
package.loaded["ui/trapper"] = { wrap = function(_, fn) fn() end }
package.loaded.logger = { warn = function() end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path, key)
    if path == file then return key == "mode" and "file" or { mode = "file" } end
end }
local client = { runInSubprocess = function(_, fn)
    local body, err = fn()
    if during then local fn_during = during; during = nil; fn_during() end
    return true, { body = body, err = err }
end, catalogDashboardSection = function()
    client_calls = client_calls + 1
    return { section = { books = { { id = 1 } } } }
end, catalogSetReadStatus = function(_, id, status)
    H.eq(id, "1"); assert(status == "want_to_read" or status == "unread")
    client_calls = client_calls + 1; return { libraryVersion = 2 }
end }
local plugin = { newClient = function() return client end, isLoggedIn = function() return true end }
package.loaded.pluginloader = { loaded_plugins = { bookorbit = plugin }, getPluginInstance = function(_, name)
    if name == "bookorbit" then return plugin end
end }
package.loaded["bookorbit_state_manager"] = { hasOnDeviceMaps = function() return true end,
    onDeviceMaps = function() return { byBookId = { [1] = file } } end,
    applyLibraryVersion = function() error("retired requests must not adopt server state") end }
package.loaded["core/orbitui_context"] = { refresh = function() refreshes = refreshes + 1 end,
    notify = function() end }
local Integration = require("adapters/orbitui_integrations")
local provider = dofile(root .. "/components/simpleui/integrations/sui_bookorbit_want.lua")
Integration.wantProvider(provider)
local function reset()
    saved, queue, client_calls, writes, flushes, during = {
        simpleui_bookorbit_want_files = { file },
        simpleui_bookorbit_want_id_paths = { ["1"] = file },
        simpleui_tbr_list = { "/books/local.epub" },
        simpleui_hs_pages = { "bookorbit_want", "tbr" },
        foreign_bookorbit_sync = true,
    }, {}, 0, 0, 0, nil
    provider._resetForTests()
end
local function drain() while #queue > 0 do table.remove(queue, 1)() end end
H.test("unset flags preserve existing behaviour and settings inspection stays passive", function()
    reset()
    local rows = Integration.bookOrbitItems()
    H.eq(#rows, 10); H.eq(#queue, 0); H.eq(client_calls, 0); H.eq(writes, 0)
    assert(Integration.bookOrbitEnabled("want") and Integration.bookOrbitEnabled("actions") and Integration.bookOrbitEnabled("tags"))
    H.eq(rows[1].text, "BookOrbit: Detected (not connection-tested)")
end)
H.test("master hides cached remote lists without modifying local TBR, layouts or external sync", function()
    reset()
    local cache, tbr, pages = saved.simpleui_bookorbit_want_files, saved.simpleui_tbr_list, saved.simpleui_hs_pages
    Integration.setBookOrbitEnabled("enabled", false)
    H.eq(#provider.getCachedFiles(), 0); H.eq(provider.getBookId(file), nil)
    H.eq(provider.shouldAutoRefreshHome(), false)
    H.eq(saved.simpleui_bookorbit_want_files, cache); H.eq(saved.simpleui_tbr_list, tbr)
    H.eq(saved.simpleui_hs_pages, pages); H.eq(saved.foreign_bookorbit_sync, true)
    local result, err = Integration.bookOrbitSession(); H.eq(result, nil); H.eq(err, "disabled")
    Integration.setBookOrbitEnabled("enabled", true)
    H.eq(provider.getCachedFiles()[1], file)
end)
H.test("subswitches stay independent and survive a master off/on cycle", function()
    reset()
    Integration.setBookOrbitEnabled("tags", false)
    Integration.setBookOrbitEnabled("actions", false)
    H.eq(#provider.getCachedFiles(), 1); H.eq(provider.getBookId(file), nil)
    Integration.setBookOrbitEnabled("enabled", false)
    Integration.setBookOrbitEnabled("enabled", true)
    H.eq(Integration.bookOrbitEnabled("tags"), false); H.eq(Integration.bookOrbitEnabled("actions"), false)
    H.eq(Integration.bookOrbitEnabled("want"), true)
end)
H.test("the actual settings callbacks reopen the same page and keep disabled subpreferences", function()
    reset()
    local old_settings, closed, reopened = package.loaded["adapters/orbitui_settings"], 0, 0
    package.loaded["adapters/orbitui_settings"] = { open = function(id)
        H.eq(id, "bookorbit"); reopened = reopened + 1
    end }
    local rows = Integration.bookOrbitItems(function() closed = closed + 1 end)
    assert(rows[2].checked_func() and rows[2].enabled_func())
    rows[8].callback(); H.eq(saved.simpleui_orbitui_bookorbit_actions, false)
    rows[2].callback(); H.eq(saved.simpleui_orbitui_bookorbit_enabled, false)
    H.eq(rows[8].enabled_func(), false)
    rows[8].callback(); H.eq(saved.simpleui_orbitui_bookorbit_actions, false)
    rows[2].callback(); H.eq(saved.simpleui_orbitui_bookorbit_enabled, true)
    H.eq(rows[8].checked_func(), false); H.eq(closed, 3); H.eq(reopened, 3)
    package.loaded["adapters/orbitui_settings"] = old_settings
end)
H.test("policy changes retire Home data and defer shelf rebuilds without changing position", function()
    reset()
    local old_engine = package.loaded["engines/sui_screen_engine"]
    local old_widget = package.loaded["lib/bookshelf_widget"]
    local stale, cancelled = 0, 0
    local live = { profile_key = "books", chip = "tbr", page = 4, _spine_fetch_cache = {}, _warmed_chip_keys = {},
        _cancelChipPreload = function() cancelled = cancelled + 1 end,
        _rebuild = function() error("must not rebuild over a modal/reader") end }
    package.loaded["engines/sui_screen_engine"] = { markAllStale = function() stale = stale + 1 end }
    package.loaded["lib/bookshelf_widget"] = { live = live }
    Integration.setBookOrbitEnabled("enabled", false)
    H.eq(stale, 1); H.eq(cancelled, 1); H.eq(live._spine_fetch_cache, nil)
    H.eq(live._warmed_chip_keys, nil); H.eq(live._orbitui_navbar_pending, true)
    H.eq(live.profile_key, "books"); H.eq(live.chip, "tbr"); H.eq(live.page, 4)
    package.loaded["engines/sui_screen_engine"], package.loaded["lib/bookshelf_widget"] = old_engine, old_widget
end)
H.test("the Bookshelf persisted-cache fallback is gated, never replaced by local TBR", function()
    reset()
    local reads = 0
    local source = { snapshot = function() reads = reads + 1; return { file }, "saved" end }
    Integration.wantSnapshot(source); Integration.wantSnapshot(source)
    H.eq(select(2, source.snapshot()), "saved")
    Integration.setBookOrbitEnabled("want", false)
    local paths, signature = source.snapshot(); H.eq(#paths, 0); H.eq(signature, "orbitui:bookorbit:disabled")
    H.eq(reads, 1)
    Integration.setBookOrbitEnabled("want", true); H.eq(source.snapshot()[1], file)
end)
H.test("disabled requests reject before scheduling or networking", function()
    reset(); Integration.setBookOrbitEnabled("enabled", false)
    local result
    H.eq(provider.requestRefresh{ on_done = function(value) result = value end }, false)
    H.eq(provider.setWantToRead(file, true), false)
    drain(); H.eq(result.error, "disabled"); H.eq(client_calls, 0); H.eq(writes, 0)
end)
H.test("queued refresh and status writes retire even across rapid off/on", function()
    for _, kind in ipairs{ "want", "actions" } do
        reset(); local result
        local opts = { on_done = function(value) result = value end }
        if kind == "want" then assert(provider.requestRefresh(opts))
        else assert(provider.setWantToRead(file, true, opts)) end
        Integration.setBookOrbitEnabled("enabled", false); Integration.setBookOrbitEnabled("enabled", true)
        drain(); H.eq(client_calls, 0); H.eq(writes, 0); H.eq(result.error, "disabled")
        H.eq(provider.isRefreshing(), false); H.eq(provider.isStatusUpdateRunning(file), false)
    end
end)
H.test("work already sent may finish but cannot adopt a retired response or erase caches", function()
    for _, kind in ipairs{ "want", "actions" } do
        reset(); local result
        local cache = saved.simpleui_bookorbit_want_files
        during = function() Integration.setBookOrbitEnabled("enabled", false) end
        local opts = { on_done = function(value) result = value end }
        if kind == "want" then assert(provider.requestRefresh(opts))
        else assert(provider.setWantToRead(file, false, opts)) end
        drain(); H.eq(client_calls, 1); H.eq(writes, 0); H.eq(result.error, "disabled")
        H.eq(saved.simpleui_bookorbit_want_files, cache)
    end
end)
H.test("unchanged successful membership still persists the refresh timestamp", function()
    reset(); local result
    assert(provider.requestRefresh{ on_done = function(value) result = value end })
    drain(); H.eq(result.ok, true); H.eq(result.changed, false)
    assert(saved.simpleui_bookorbit_want_updated_at > 0); H.eq(flushes, 1)
end)
H.test("component source names are bilingual without changing gettext or canonical IDs", function()
    reset()
    local native_gettext = package.loaded.gettext
    local scoped = require("adapters/orbitui_ui").wrap("infra/sui_i18n", { translate = function(text) return text end })
    local _ = require("core/orbitui_i18n")
    H.eq(scoped.translate("BookOrbit Want to Read"), "Want to read [BookOrbit]")
    H.eq(scoped.translate("To Be Read"), "Want to read [Local]")
    H.eq(_("BookOrbit Want to Read", "sv"), "Vill läsa [BookOrbit]")
    H.eq(_("To Be Read", "sv"), "Vill läsa [Lokalt]")
    H.eq(scoped.translate("Unrelated native label"), "Unrelated native label")
    H.eq(package.loaded.gettext, native_gettext)
end)
H.test("all new settings rows and help texts have Swedish translations", function()
    reset()
    local _ = require("core/orbitui_i18n")
    for _i, row in ipairs(Integration.bookOrbitItems()) do
        if row.help_text then assert(_(row.help_text, "sv") ~= row.help_text, row.help_text) end
    end
    for _i, text in ipairs{ "Want to read [BookOrbit]", "Want to read [Local]", "Online BookOrbit tags",
        "Enable BookOrbit features in OrbitUI", "BookOrbit reading-status menu actions" } do
        assert(_(text, "sv") ~= text, text)
    end
end)
H.test("extras help describes the reviewed source package without deploying or disabling undo", function()
    reset()
    local context, notice = package.loaded["core/orbitui_context"], nil
    local original_notify = context.notify
    context.notify = function(text) notice = text end
    local rows = Integration.bookOrbitItems()
    rows[#rows].callback()
    context.notify = original_notify
    assert(notice:find("3.6.0", 1, true) and notice:find("3.2.0", 1, true))
    assert(notice:find("does not install, disable or deploy", 1, true))
    local translated = require("core/orbitui_i18n")(notice, "sv")
    assert(translated ~= notice and translated:find("serverutökning", 1, true))
    H.eq(client_calls, 0); H.eq(writes, 0); H.eq(#queue, 0)
    assert(Integration.bookOrbitEnabled())
end)
H.finish()
