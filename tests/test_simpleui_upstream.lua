package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local function read(path)
    local f = assert(io.open("components/simpleui/" .. path))
    local source = f:read("*a"); f:close()
    return source
end
local function compile(body, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then
        local fn = assert(loadstring(body)); setfenv(fn, env); return fn()
    end
    return assert(load(body, "upstream regression", "t", env))()
end
local function method(source, declaration)
    local first = assert(source:find(declaration, 1, true))
    local last = assert(source:find("\nend", first, true))
    return source:sub(first, last + 3)
end

local metadata = read("features/library/sui_metadata_providers.lua")
local inflate_source = metadata:sub(assert(metadata:find("local function openZlib", 1, true)),
    assert(metadata:find("-- Find EOCD", 1, true)) - 1)
local real_ffi = package.loaded.ffi
local function inflater(android, bits, libraries, init_result)
    local loads, calls = {}, { inflate = 0, finish = 0 }
    local good = {
        inflateInit2_ = function(_, window)
            H.eq(window, -15); return init_result or 0
        end,
        inflate = function(stream, flush)
            H.eq(flush, 4); calls.inflate = calls.inflate + 1
            stream.total_out = 3; return 1
        end,
        inflateEnd = function() calls.finish = calls.finish + 1 end,
    }
    local function library(name)
        loads[#loads + 1] = name
        local value = libraries[name]
        if value == "good" then return good end
        if value then return value end
        error("library unavailable: " .. name)
    end
    package.loaded.ffi = {
        cdef = function() end, load = library,
        loadlib = function(name, version) H.eq(version, 1); return library(name) end,
        abi = function(name) H.eq(name, "64bit"); return bits == 64 end,
        new = function() return {} end, sizeof = function() return 112 end,
        cast = function(_, value) return value end,
        string = function(_, size) H.eq(size, 3); return "xml" end,
    }
    local fn = compile(inflate_source .. "\nreturn rawInflate", { is_android = android })
    return fn, loads, calls
end

H.test("available zlib symbols use the normal loader without Android fallbacks", function()
    local fn, loads, calls = inflater(true, 64, { z = "good" })
    H.eq(fn("compressed", 3), "xml"); H.eq(fn("again", 3), "xml")
    H.eq(table.concat(loads, "|"), "z")
    H.eq(calls.inflate, 2); H.eq(calls.finish, 2)
end)
H.test("each missing FFI inflate symbol is caught before the 64-bit Android fallback", function()
    for _, missing in ipairs({ "inflateInit2_", "inflate", "inflateEnd" }) do
        local broken = setmetatable({}, { __index = function(_, symbol)
            if symbol == missing then error("undefined symbol: " .. symbol) end
            return function() error("invalid library must never inflate") end
        end })
        local fn, loads = inflater(true, 64, {
            z = broken, ["libz.so"] = broken, ["/system/lib64/libz.so"] = "good",
        })
        H.eq(fn("compressed", 3), "xml")
        H.eq(table.concat(loads, "|"), "z|libz.so|/system/lib64/libz.so")
    end
end)
H.test("32-bit Android uses lib rather than lib64", function()
    local fn, loads = inflater(true, 32, { ["/system/lib/libz.so"] = "good" })
    H.eq(fn("compressed", 3), "xml")
    H.eq(loads[#loads], "/system/lib/libz.so")
end)
H.test("missing zlib safely returns no metadata and does not retry every book", function()
    local fn, loads = inflater(true, 64, {})
    H.eq(fn("compressed", 3), nil); H.eq(fn("again", 3), nil)
    H.eq(#loads, 3)
end)
H.test("non-Android metadata extraction never loads Android system libraries", function()
    local fn, loads = inflater(false, 64, {})
    H.eq(fn("compressed", 3), nil); H.eq(#loads, 1)
end)
H.test("an inflate initialization failure does not run an invalid stream", function()
    local fn, _, calls = inflater(true, 64, { z = "good" }, -6)
    H.eq(fn("compressed", 3), nil)
    H.eq(calls.inflate, 0); H.eq(calls.finish, 0)
end)
package.loaded.ffi = real_ffi

local memory, invalidations, writes = {}, 0, 0
package.loaded["infra/sui_store"] = {
    get = function(_, key) return memory[key] end,
    set = function(_, key, value) memory[key] = value; writes = writes + 1 end,
}
package.loaded["modules/module_stats_provider"] = {
    invalidateStreak = function() invalidations = invalidations + 1 end,
}
local Streak = dofile("components/simpleui/infra/sui_streak.lua")
H.test("streak mode changes invalidate stats while invalid modes do nothing", function()
    Streak.setStreakMode("invalid"); H.eq(writes, 0); H.eq(invalidations, 0)
    Streak.setStreakMode("real"); H.eq(invalidations, 1)
    Streak.setStreakMode("freezes"); H.eq(invalidations, 2)
end)
H.test("spending a freeze invalidates once and duplicate spending is a no-op", function()
    memory.simpleui_streak_freezes_available = 2
    H.eq(Streak.spendFreezeForYesterday(), true)
    H.eq(memory.simpleui_streak_freezes_available, 1)
    H.eq(invalidations, 3)
    H.eq(Streak.spendFreezeForYesterday(), false)
    H.eq(invalidations, 3)
end)
H.test("streak mutators do not eagerly load the statistics provider", function()
    package.loaded["modules/module_stats_provider"] = nil
    Streak.setStreakMode("real")
    H.eq(package.loaded["modules/module_stats_provider"], nil)
end)

local screen = read("engines/sui_screen_engine.lua")
local W = H.widget()
function W:getSize() return self.dimen or { w = 20, h = 10 } end
local env = {
    PAD = 5,
    Config = { getSectionLabelScale = function() return 1 end },
    SUIStyle = { FS_BODY = 16, FS_DETAIL = 12, FACE_REGULAR = "regular",
        COLOR = { text_primary = 0, text_secondary = 1 } },
    Font = { getFace = function() return {} end },
    UI = { makeColoredText = function(args) return W:new(args) end, LABEL_PAD_BOT = 2 },
    LeftContainer = W, CenterContainer = W, HorizontalGroup = W,
    HorizontalSpan = W, FrameContainer = W, Geom = W,
}
local buttons = {}
package.loaded["engines/sui_book_grid"] = {
    buildPageNavButtons = function(_, _, _, turn)
        local prev, next_button = W:new{ callback = function() turn(-1) end },
            W:new{ callback = function() turn(1) end }
        buttons[#buttons + 1] = next_button
        return prev, next_button
    end,
}
local section = compile(method(screen, "local function sectionLabel(") .. "\nreturn sectionLabel", env)
local PageState = compile(read("engines/sui_section_label.lua"):match(
    "(local PageState = {}.-)\n%-%- %-%-%-%-" ) .. "\nreturn PageState", { M = {} })
local pageNav = compile(method(screen, "local function pageNavFor(") .. "\nreturn pageNavFor",
    { SectionLabel = { PageState = PageState } })
local signature = compile(method(screen, "local function sectionLabelSignature(")
    .. "\nreturn sectionLabelSignature", env)
H.test("fresh header widgets keep pagination callbacks bound to the owning screen", function()
    local calls, labels = {}, {}
    for i, id in ipairs({ "hs", "hs", "custom" }) do
        local owner = { _id = id, _turnBookModPage = function(_, mod, delta)
            H.eq(mod, "library"); H.eq(delta, 1); calls[i] = (calls[i] or 0) + 1
        end }
        local nav = pageNav(owner, { id = "library" },
            { _row_npages_library = 3, _row_page_library = 1 })
        H.eq(nav.screen_id, id)
        labels[i] = section("Books", 300, "library", "1/3", nav, 1, "simpleui_hs_")
        buttons[#buttons].callback()
    end
    assert(labels[1] ~= labels[2] and labels[2] ~= labels[3])
    H.eq(calls[1], 1); H.eq(calls[2], 1); H.eq(calls[3], 1)
end)
H.test("primitive label signatures retain screen identity without retaining widgets", function()
    local nav = { screen_id = "hs", mod_id = "library", page = 1, npages = 3 }
    local first = signature("Books", 300, "library", "1/3", nav, 1, "prefix")
    nav.screen_id = "custom"
    assert(first ~= signature("Books", 300, "library", "1/3", nav, 1, "prefix"))
end)
H.test("freeze refresh touches live screen stats without clearing book data", function()
    local calls = {}
    local engine = { refreshScreen = function(id, keep, books, stats)
        calls[#calls + 1] = id
        H.eq(keep, false); H.eq(books, false); H.eq(stats, true)
    end }
    compile(method(screen, "function ScreenEngine.refreshAllLiveStats("), {
        ScreenEngine = engine, _liveScreenIds = function() return { "hs", "custom" } end,
    })
    engine.refreshAllLiveStats(); H.eq(table.concat(calls, "|"), "hs|custom")
end)
H.test("the freeze dialog refreshes live stats only after a successful spend", function()
    local success, stats, repaint, refresh = false, 0, 0, 0
    package.loaded["engines/sui_screen_engine"] = {
        refreshAllLiveStats = function() stats = stats + 1 end,
    }
    local source = read("screens/sui_stats_windows.lua")
    local body = assert(source:match("(local function useFreeze%(%).-)\n        end"))
    local use = compile(body .. "\nend\nreturn useFreeze", {
        SUIStreak = { spendFreezeForYesterday = function() return success end },
        refreshStreaks = function() refresh = refresh + 1 end,
        ctx = { repaint = function() repaint = repaint + 1 end },
    })
    use(); H.eq(stats, 0); H.eq(refresh, 0); H.eq(repaint, 1)
    success = true; use()
    H.eq(stats, 1); H.eq(refresh, 1); H.eq(repaint, 2)
end)
H.finish()
