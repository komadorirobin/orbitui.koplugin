package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = os.getenv("ORBITUI_TEST_ROOT") or H.root()
local file = assert(io.open(root .. "/components/simpleui/infra/sui_patches.lua"))
local source = file:read("*a"); file:close()
local start = assert(source:find("function M.patchMenuForNavpager(plugin)", 1, true))
source = source:sub(start, assert(source:find("\nend\n", start, true)) + 4)
local function noop() end
local function fixture()
    local calls, queue, enabled, stack = { native = 0, dirty = 0, subtitles = 0, arrows = 0 }, {}, true, {}
    local Menu = { updatePageInfo = function() calls.native = calls.native + 1 end }
    local FM = { updateTitleBarPath = noop }
    local fm = { _navbar_container = {}, file_chooser = {}, title_bar = {} }
    local plugin = { ui = fm, active_action = "files" }
    local env = {
        M = {}, NAVPAGER_STATE = "navpager", _ = function(s) return s end,
        _acquireHooks = function() return {} end,
        _addHook = function(_, class, key, fn) class[key] = fn end,
        SUISettings = { isTrue = function() return enabled end },
        UI = { getWindowStack = function() return stack end },
        UIManager = {
            setDirty = function(_, target, kind, dimen)
                calls.dirty = calls.dirty + 1; calls.dirty_target = target; calls.dimen = dimen
            end,
            scheduleIn = function(_, delay, fn) queue[#queue + 1] = fn end,
        },
        Bottombar = { syncNavpagerArrows = function(target, action, prev, next_page)
            calls.arrows = calls.arrows + 1; calls.target = target
            calls.action, calls.prev, calls.next_page = action, prev, next_page
        end },
        require = function(name)
            if name == "ui/widget/menu" then return Menu end
            if name == "apps/filemanager/filemanager" then return FM end
            if name == "ffi/util" then return { template = function(_, p, n) return p .. "/" .. n end } end
            error("unexpected dependency " .. name)
        end,
    }
    setmetatable(env, { __index = _G })
    local fn
    if setfenv then fn = assert(loadstring(source)); setfenv(fn, env)
    else fn = assert(load(source, "native navpager", "t", env)) end
    fn(); env.M.patchMenuForNavpager(plugin)
    local function title()
        return { subtitle_widget = {}, setSubTitle = function(_, text)
            calls.subtitles = calls.subtitles + 1; calls.subtitle = text
        end }
    end
    local function flush() local q = queue; queue = {}; for _, cb in ipairs(q) do cb() end end
    return { calls = calls, menu = Menu, fm = fm, env = env, title = title, flush = flush,
        stack = stack, queued = function() return #queue end, enable = function(v) enabled = v end }
end
H.test("foreign paginated menus retain native updates without subtitle or navbar work", function()
    local f = fixture()
    local foreign = { title_bar = f.title(), page = 2, page_num = 9, page_info = { dimen = {} } }
    f.menu.updatePageInfo(foreign, 3); f.flush()
    H.eq(f.calls.native, 1); H.eq(f.calls.subtitles, 0); H.eq(f.calls.arrows, 0)
    H.eq(f.calls.dirty, 0); H.eq(f.queued(), 0)
end)
H.test("live file chooser still synchronizes subtitle and coalesced current page arrows", function()
    local f = fixture(); local chooser = f.fm.file_chooser
    chooser.title_bar, chooser.page, chooser.page_num = f.title(), 1, 5
    f.menu.updatePageInfo(chooser); chooser.page = 3; f.menu.updatePageInfo(chooser)
    H.eq(f.calls.subtitles, 2); H.eq(f.calls.subtitle, "3/5"); H.eq(f.queued(), 1)
    f.flush(); H.eq(f.calls.arrows, 1); H.eq(f.calls.target, f.fm)
    H.eq(f.calls.prev, true); H.eq(f.calls.next_page, true)
end)
H.test("injected fullscreen menus keep targeted page-info paint and their own navbar", function()
    local f = fixture()
    local overlay = { _navbar_injected = true, _navbar_container = {}, covers_fullscreen = true,
        title_bar = f.title(), page = 4, page_num = 4, page_info = { dimen = {} } }
    f.stack[1] = { widget = overlay }
    f.menu.updatePageInfo(overlay); f.flush()
    H.eq(f.calls.dirty, 1); H.eq(f.calls.dirty_target, overlay)
    H.eq(f.calls.dimen, overlay.page_info.dimen); H.eq(f.calls.subtitle, "4/4")
    H.eq(f.calls.target, overlay); H.eq(f.calls.prev, true); H.eq(f.calls.next_page, false)
end)
H.test("a replaced file chooser is no longer a navbar owner", function()
    local f = fixture(); local old = f.fm.file_chooser
    old.title_bar, old.page, old.page_num = f.title(), 1, 4
    f.env.M.patchMenuForNavpager({ ui = { file_chooser = {} } })
    f.menu.updatePageInfo(old); f.flush()
    H.eq(f.calls.native, 1); H.eq(f.calls.subtitles, 0); H.eq(f.calls.arrows, 0)
end)
H.test("disabled pager preferences preserve injected dirty repair without scheduling arrows", function()
    local f = fixture(); f.enable(false)
    f.menu.updatePageInfo({ _navbar_injected = true, page_info = { dimen = {} } }); f.flush()
    H.eq(f.calls.native, 1); H.eq(f.calls.dirty, 1)
    H.eq(f.calls.subtitles, 0); H.eq(f.calls.arrows, 0)
end)
H.finish()
