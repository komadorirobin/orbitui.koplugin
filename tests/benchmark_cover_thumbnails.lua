-- Synthetic cache work/reference accounting, NOT device or end-to-end timings.
-- Run with lua/luajit from the repository; optionally supply the frozen old
-- SpineWidget source via ORBITUI_OLD_THUMB_SOURCE.
local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers"); H.simpleuiMemory()
package.loaded.logger = { dbg = function() end, warn = function() end }
local Host = require("core/orbitui_host")
local function read(path) local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s end
local function compile(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "thumbnail benchmark fixture", "t", env))()
end
local function buffer(w, h)
    return { stride = w * 4, getWidth = function() return w end, getHeight = function() return h end,
        getType = function() return 5 end, getRotation = function() return 0 end, getInverse = function() return 0 end }
end
local function run(legacy)
    require("infra/sui_memory").reset()
    local class, scales, refs = {}, 0, setmetatable({}, { __mode = "v" })
    local source = read(legacy and (os.getenv("ORBITUI_OLD_THUMB_SOURCE")
        or root .. "/components/bookshelf/lib/bookshelf_spine_widget.lua")
        or root .. "/components/bookshelf/lib/bookshelf_spine_widget.lua")
    local renderer = { scaleBlitBuffer = function(_, _, w, h, disposable)
        assert(disposable == false); scales = scales + 1; return buffer(w, h)
    end }
    package.loaded["ui/renderimage"] = renderer
    compile(assert(source:match("(local THUMB_CAP =.-\nSpineWidget%._thumbFor = _thumbFor)")),
        { SpineWidget = class, require = function() return renderer end })
    if not legacy then Host.coverThumbnails(class) end
    local hot = buffer(400, 600)
    class._thumbFor("/hot", hot, 60, 90)
    for i = 1, 384 do
        local src = buffer(400, 600); refs[i] = src
        class._thumbFor("/book" .. i, src, 60, 90)
        class._thumbFor("/hot", hot, 60, 90)
    end
    collectgarbage("collect"); collectgarbage("collect")
    local retained = 0
    for _i in pairs(refs) do retained = retained + 1 end
    print(string.format("%s mixed_trace scales=%d requests=%d retained_cold_sources=%d source_pixel_bytes=%d",
        legacy and "baseline" or "optimized", scales, 769, retained, retained * 400 * 600 * 4))
    -- Pixel buffers are symbolic here; this accounts references/bytes, not RSS.
    local page, page_scales = {}, scales
    for i = 1, 24 do
        page[i] = buffer(600, 900)
        class._thumbFor("/page" .. i, page[i], 200, 300)
    end
    for _round = 1, 10 do for i = 1, 24 do class._thumbFor("/page" .. i, page[i], 200, 300) end end
    print(string.format("%s repeated_colour_page scales=%d requests=%d", legacy and "baseline" or "optimized",
        scales - page_scales, 264))
    for i = 1, 200 do class._thumbFor("/large" .. i, buffer(600, 900), 200, 300) end
    if class._orbitui_cover_thumbnails then
        local cache = class._orbitui_cover_thumbnails
        print(string.format("optimized retained_thumbnail_bytes=%d entries=%d limit_bytes=%d",
            cache:bytes(), cache:count(), cache._max_bytes))
    else print("baseline 96_colour_thumbnails_pixel_bytes=" .. 96 * 200 * 300 * 4) end
end
run(true)
run(false)
