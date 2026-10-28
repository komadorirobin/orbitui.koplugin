package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
local function read(path)
    local f = assert(io.open(root .. "/components/" .. path))
    local s = f:read("*a"); f:close(); return s
end
local function run(source, env)
    env = setmetatable(env or {}, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(source)), env)() end
    return assert(load(source, "October 28 merge", "t", env))()
end
local function section(source, first, last)
    local a = assert(source:find(first, 1, true))
    return source:sub(a, assert(source:find(last, a + #first, true)) - 1)
end
local function assetsFixture()
    local modes, children = {}, {}
    local lfs = {
        attributes = function(path, key) if key == "mode" then return modes[path] end end,
        dir = function(path)
            local n = 0
            return function() n = n + 1; return (children[path] or {})[n] end
        end,
    }
    local deps = {
        datastorage = { getSettingsDir = function() return "/settings" end },
        ["libs/libkoreader-lfs"] = lfs,
        util = { makePath = function() error("listing must not write") end },
        ["infra/sui_paths"] = { getPluginDir = function() return "/plugin/" end },
        ["infra/sui_raster_cache"] = { clear = function() end },
    }
    local assets = run(read("simpleui/modules/critter/assets.lua"), {
        require = function(name) return assert(deps[name], name) end,
    })
    return assets, modes, children, lfs
end
H.test("sealed Hazel retains every upstream PNG and all twelve moods without writing files", function()
    local assets = assetsFixture()
    local list = assets.list(); H.eq(#list, 1); H.eq(list[1].id, "hazel")
    local n = 0
    for mood, path in pairs(list[1].files) do
        n = n + 1
        local data = assert(assets.imageData(path))
        H.eq(data:sub(1, 8), "\137PNG\13\10\26\10")
        local f = io.open("components/simpleui/modules/critter/assets/hazel/" .. mood .. ".png", "rb")
        if f then H.eq(data, f:read("*a")); f:close() end
        H.eq(assets.imagePath(list[1], mood), path)
        H.eq(assets.imageData(path), data)
    end
    H.eq(n, 12)
    H.eq(assets.imagePath(list[1], "unknown"), list[1].files.neutral)
    H.eq(assets.imageData("/user/hazel.png"), nil)
    H.eq(assets.imageData("orbitui-critter:hazel:missing.png"), nil)
end)
H.test("real bundled Hazel and custom critters override the embedded fallback without changing defaults", function()
    local assets, modes, children = assetsFixture()
    local bundled, user = "/plugin/modules/critter/assets", assets.userDir()
    modes[bundled], children[bundled] = "directory", { "hazel", "suey" }
    for _, id in ipairs({ "hazel", "suey" }) do
        modes[bundled .. "/" .. id] = "directory"
        modes[bundled .. "/" .. id .. "/neutral.png"] = "file"
    end
    H.eq(assets.get("hazel").files.neutral, bundled .. "/hazel/neutral.png")
    H.eq(assets.get("unknown").id, "suey")
    modes[user], children[user] = "directory", { "hazel.png" }
    modes[user .. "/hazel.png"] = "file"
    assets.relist()
    H.eq(assets.get("hazel").files.neutral, user .. "/hazel.png")
    H.eq(assets.imagePath(assets.get("hazel"), "happy"), user .. "/hazel.png")
    H.eq(assets.DEFAULT_ID, "suey")
end)
H.test("whole Sprite renders embedded PNGs through minimum-reader data API and retains native alpha night and cache paths", function()
    local assets, _, _, lfs = assetsFixture()
    local entry = assets.get("hazel")
    local calls, cache = {}, {}
    local function bitmap(w, h)
        return { getWidth = function() return w end, getHeight = function() return h end,
            getType = function() return 32 end,
            getPixel = function() return { getColorRGB32 = function() return { alpha = 255 } end } end,
            free = function() end, scale = function(_, nw, nh) return bitmap(nw, nh) end }
    end
    local render = {
        renderImageData = function(_, data, size, frames, width, height)
            H.eq(size, #data); H.eq(frames, false); H.eq(data:sub(2, 4), "PNG")
            calls[#calls + 1] = "data"
            return bitmap(width or 48, height or 48)
        end,
        renderImageFile = function(_, path, frames)
            H.eq(path, "/custom.png"); H.eq(frames, false)
            calls[#calls + 1] = "file"; return bitmap(48, 48)
        end,
    }
    local screen = { night_mode = true, sw_dithering = true }
    local deps = {
        ["ffi/blitbuffer"] = { TYPE_BB8A = 8, TYPE_BBRGB32 = 32 },
        device = { screen = screen }, ["ui/geometry"] = { new = function(_, v) return v end },
        ["ui/renderimage"] = render, ["ui/widget/widget"] = H.widget(),
        ["libs/libkoreader-lfs"] = lfs, logger = { warn = function() error("decode failed") end },
        ["modules/critter/assets"] = assets,
        ["infra/sui_raster_cache"] = { get = function(_, key, builder, ...)
            if not cache[key] then cache[key] = builder(...) end
            return cache[key]
        end },
    }
    local Sprite = run(read("simpleui/modules/critter/sprite.lua"), {
        require = function(name) return assert(deps[name], name) end,
    })
    local painted = {}
    local dst = {
        invertRect = function() painted[#painted + 1] = "invert" end,
        ditherpmulalphablitFrom = function() painted[#painted + 1] = "dither-alpha" end,
    }
    for mood, path in pairs(entry.files) do
        local sprite = Sprite:new{ path = path, max_w = 100, max_h = 100 }
        H.eq(sprite.pixel, 2); H.eq(sprite.dimen.w, 96)
        local count = #calls
        sprite:paintTo(dst, 10, 20); sprite:paintTo(dst, 10, 20)
        H.eq(#calls, count, mood .. " bypassed cache")
    end
    H.eq(#calls, 12); H.eq(painted[1], "invert"); H.eq(painted[2], "dither-alpha")
    H.eq(painted[3], "invert")
    Sprite:new{ path = entry.files.neutral, max_w = 24, max_h = 24 }
    H.eq(#calls, 14, "small box retains native rescale branch")
    Sprite:new{ path = "/custom.png", max_w = 100, max_h = 100 }
    H.eq(calls[#calls], "file")
end)

local engine = read("simpleui/engines/sui_screen_engine.lua")
H.test("whole cover poll repaints legacy one-result providers but skips explicitly unchanged native providers", function()
    for _, flag in ipairs({ "legacy", false, true }) do
        local ScreenWidget, timer, dirty = {}, nil, 0
        local widget = { _id = "home", _ctx_cache = {}, _cover_mod_slots = {
            sample = { widget = { dimen = { w = 10, h = 20 } }, mod = {
                updateCovers = function() if flag == "legacy" then return true end; return true, flag end,
            } },
        } }
        local Config = { getBookInfoManager = function() end, flushCoverQueue = function() end }
        run(section(engine, "function ScreenWidget:_scheduleCoverPoll()", "function ScreenWidget:onShow()"), {
            ScreenWidget = ScreenWidget, Config = Config,
            _sget = function() return widget end,
            logger = { dbg = function() end, warn = function() error("poll failed") end },
            UIManager = { scheduleIn = function(_, _, fn) timer = fn end,
                setDirty = function(_, _, region) local mode, rect, dith = region()
                    H.eq(mode, "ui"); H.eq(rect.w, 10); H.eq(dith, true); dirty = dirty + 1
                end },
        })
        ScreenWidget._scheduleCoverPoll(widget); assert(timer)()
        H.eq(dirty, flag == false and 0 or 1)
        H.eq(next(widget._cover_mod_slots), nil); H.eq(Config.cover_extraction_pending, false)
    end
end)
H.test("group cover polling resolves each slot once and retries failed ImageWidget construction", function()
    local GroupCell, fail, requests = {}, true, 0
    local bb = {}
    run(section(read("simpleui/engines/sui_group_cell.lua"), "function GroupCell.updateCovers(",
        "-- Interaction"), {
        GroupCell = GroupCell,
        Config = { getCroppedCoverBB = function() requests = requests + 1; return bb end,
            isCoverMissing = function() return false end },
        ImageWidget = { new = function() if fail then error("not ready") end; return { image = bb } end },
    })
    local slot = { kind = "quad", fp = "book", w = 20, h = 30, idx = 1, container = {} }
    local widget = { _cover_slots = { slot } }
    local done, changed = GroupCell.updateCovers(widget)
    H.eq(done, false); H.eq(changed, false)
    fail = false; done, changed = GroupCell.updateCovers(widget)
    H.eq(done, true); H.eq(changed, true); H.eq(slot.done, true)
    done, changed = GroupCell.updateCovers(widget)
    H.eq(done, true); H.eq(changed, false); H.eq(requests, 2)
end)
H.test("Android picked-colour borders restore inverse state even if the native paint fails", function()
    local Color = run(read("bookshelf/lib/bookshelf_color.lua"), { require = function(name)
        if name == "ffi/blitbuffer" then return { isColor8 = function() return false end } end
        H.eq(name, "device"); return { isAndroid = function() return true end }
    end })
    local inverse, fail = 1, true
    local bb = { getInverse = function() return inverse end,
        setInverse = function(_, n) inverse = n end,
        paintBorderRGB32 = function() H.eq(inverse, 0); if fail then error("native paint error", 0) end end }
    local ok, err = pcall(Color.paintBorder, bb, 0, 0, 20, 30, 1, {}, 2)
    H.eq(ok, false); H.eq(err, "native paint error"); H.eq(inverse, 1)
    fail = false; Color.paintBorder(bb, 0, 0, 20, 30, 1, {}, 2); H.eq(inverse, 1)
end)

local patches = read("simpleui/infra/sui_patches.lua")
H.test("shared BookList hooks release dropped owners and do not stack across reader instances", function()
    local BookList = { new = function(_, attrs) return attrs end }
    local original, M = BookList.new, {}
    local helpers = section(patches, "local function _acquireHooks(", "-- Ensure the goal-tap")
    local code = 'local BOOKLIST_STATE = "_simpleui_booklist"\n' ..
        section(patches, "function M.patchBookList(", 'local COLLECTIONS_STATE =')
    local release = run(helpers .. "\n" .. code .. "\nreturn _releaseHooks", {
        M = M, UI = { fitToContentArea = function(attrs) attrs.height = 600 end },
        require = function(name) H.eq(name, "ui/widget/booklist"); return BookList end,
    })
    local owner = {}; M.patchBookList(owner)
    local wrapped = BookList.new
    for _ = 1, 50 do local temporary = {}; M.patchBookList(temporary) end
    collectgarbage("collect"); collectgarbage("collect")
    H.eq(BookList.new, wrapped); H.eq(BookList:new({}).height, 600)
    local n = 0; for _ in pairs(BookList._simpleui_booklist.users) do n = n + 1 end
    H.eq(n, 1, "hook state retained old reader instances")
    H.eq(release(BookList, "_simpleui_booklist", owner), true); H.eq(BookList.new, original)
end)
H.test("new page flash setting is opt-in and translated without changing the saved choice", function()
    local translate = dofile(root .. "/core/orbitui_i18n.lua")
    H.eq(translate("Flash on every page turn", "sv"), "Blinka vid varje sidbyte")
    H.eq(translate("Flash on every page turn", "en"), "Flash on every page turn")
    local flash = section(engine, "local function _flashAllPages()", "function ScreenWidget:_refresh(")
    for _, value in ipairs({ false, true }) do
        local fn = run(flash .. "\nreturn _flashAllPages", {
            SUISettings = { isTrue = function(_, key) H.eq(key, "simpleui_hs_flash_all_pages"); return value end },
        })
        H.eq(fn(), value)
    end
end)
H.test("page turns respect the saved flash options while OrbitUI's one-shot full repaint keeps precedence", function()
    local ScreenWidget, mode, all_pages, covers = {}, nil, false, false
    run(section(engine, "function ScreenWidget:_refresh(", "function ScreenWidget:_setCoverdeckIdx("), {
        ScreenWidget = ScreenWidget,
        _flashAllPages = function() return all_pages end,
        _flashCoverImages = function() return covers end,
        UIManager = { setDirty = function(_, _, m) mode = m end },
    })
    local widget = { _body = {}, _ctx_cache = {}, _page_has_covers = true,
        _updatePage = function(self) self._page_has_covers = false end }
    ScreenWidget._refresh(widget, true, nil, nil, true); H.eq(mode, "ui")
    all_pages = true
    ScreenWidget._refresh(widget, true, nil, nil, true); H.eq(mode, "flashui")
    ScreenWidget._refresh(widget, true); H.eq(mode, "ui", "not a page turn")
    all_pages, covers = false, true; widget._page_has_covers = true
    ScreenWidget._refresh(widget, true, nil, nil, true); H.eq(mode, "flashui", "covers on previous page")
    widget._force_full_repaint_once = true
    ScreenWidget._refresh(widget, true, nil, nil, true)
    H.eq(mode, "full"); H.eq(widget._force_full_repaint_once, nil)
end)
H.test("deferred chooser lists once on exposure and preserves instance callbacks on success and error", function()
    for _, fail in ipairs({ false, true }) do
        local fc, calls, FileChooser = { name = "filemanager" }, 0, {}
        local own_refresh = function() calls = calls + 1 end
        fc.refreshPath = own_refresh
        local fm = { file_chooser = fc }
        local code = "local _lazy_listing_pending = true\n" ..
            section(patches, "FileChooser.init = function(fc_self)", "-- When an external caller") ..
            section(patches, "local function _materializeLazyListing()", "-- Runs `fn`") ..
            "\nreturn _materializeLazyListing"
        local materialize = run(code, {
            M = {}, FileChooser = FileChooser, liveFM = function() return fm end,
            UI = { getContentHeight = function() return 600 end, getContentTop = function() return 40 end },
            orig_fc_init = function(self)
                self:refreshPath()
                if fail then error("chooser init error", 0) end
            end,
        })
        local ok, err = pcall(FileChooser.init, fc)
        H.eq(ok, not fail); H.eq(calls, 0); H.eq(fc.refreshPath, own_refresh)
        H.eq(fc.height, 600); H.eq(fc.y, 40)
        if fail then
            H.eq(err, "chooser init error"); H.eq(fc._sui_lazy_listing, nil)
        else
            H.eq(fc._sui_lazy_listing, true)
            materialize(); materialize(); H.eq(calls, 1); H.eq(fc._sui_lazy_listing, nil)
        end
    end
end)
H.test("top-window selection ignores toasts without mistaking a genuine dialog for Home", function()
    local M, stack = {}, {}
    M.getWindowStack = function() return stack end
    run(section(read("simpleui/infra/sui_core.lua"), "function M.getTopWindow()", "-- Shared settings menu"), { M = M })
    H.eq(M.getTopWindow(), nil)
    local home, dialog, toast = { name = "homescreen" }, { name = "dialog" }, { toast = true }
    stack[1], stack[2], stack[3] = { widget = home }, { widget = dialog }, { widget = toast }
    H.eq(M.getTopWindow().widget, dialog)
    table.remove(stack, 2); H.eq(M.getTopWindow().widget, home)
end)
H.finish()
