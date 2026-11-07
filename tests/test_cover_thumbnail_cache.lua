local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
H.simpleuiMemory()
package.loaded.logger = { dbg = function() end, warn = function() end }
local Host = require("core/orbitui_host")
local function read(path) local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s end
local function compile(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then return setfenv(assert(loadstring(code)), env)() end
    return assert(load(code, "actual thumbnail path", "t", env))()
end
local native_source = read(os.getenv("ORBITUI_OLD_THUMB_SOURCE")
    or root .. "/components/bookshelf/lib/bookshelf_spine_widget.lua")
local body = assert(native_source:match("(local THUMB_CAP =.-\nSpineWidget%._thumbFor = _thumbFor)"))
local function buffer(w, h, id, bpp)
    local b = { stride = w * (bpp or 4), id = id or "art", rotation = 0, inverse = 0, kind = bpp or 4 }
    function b:getWidth() return w end
    function b:getHeight() return h end
    function b:getType() return self.kind end
    function b:getRotation() return self.rotation end
    function b:getInverse() return self.inverse end
    function b:free() error("a borrowed image was freed") end
    return b
end
local function fixture(legacy)
    local class, calls, fail = {}, {}, false
    local renderer = {}
    function renderer:scaleBlitBuffer(src, w, h, disposable)
        H.eq(disposable, false)
        calls[src.id] = (calls[src.id] or 0) + 1
        if fail then error("temporary scaler failure") end
        local out = buffer(w, h, src.id, src.kind)
        out.rotation, out.inverse = src.rotation, src.inverse
        return out
    end
    package.loaded["ui/renderimage"] = renderer
    compile(body, { SpineWidget = class, require = function(n)
        H.eq(n, "ui/renderimage"); return renderer
    end })
    if not legacy and Host.coverThumbnails then Host.coverThumbnails(class) end
    return class, calls, function(v) fail = v end
end
H.test("a recently used cover survives new arrivals instead of being FIFO-evicted", function()
    local class, calls = fixture()
    local hot = buffer(400, 600, "hot")
    local first = class._thumbFor("/hot", hot, 60, 90)
    for i = 1, 95 do class._thumbFor("/cold" .. i, buffer(400, 600, tostring(i)), 60, 90) end
    H.eq(class._thumbFor("/hot", hot, 60, 90), first)
    class._thumbFor("/new", buffer(400, 600, "new"), 60, 90)
    H.eq(class._thumbFor("/hot", hot, 60, 90), first, "recent hit must promote the thumbnail")
    H.eq(calls.hot, 1)
end)
H.test("cached thumbnails cannot pin canonical source images after their native cache evicts them", function()
    local class = fixture()
    local source = buffer(800, 1200)
    local weak = setmetatable({ source }, { __mode = "v" })
    local thumb = class._thumbFor("/source", source, 60, 90)
    source = nil; collectgarbage("collect"); collectgarbage("collect")
    H.eq(weak[1], nil, "thumbnail cache retained the large source")
    H.eq(thumb:getWidth(), 60)
end)
H.test("source identity geometry rotation inverse and buffer type cannot reuse stale pixels", function()
    local class, calls = fixture()
    local source = buffer(400, 600)
    local first = class._thumbFor("/a", source, 60, 90)
    H.eq(class._thumbFor("/a", source, 60, 90), first)
    assert(class._thumbFor("/a", source, 61, 90) ~= first)
    local replacement = buffer(400, 600, "replacement")
    local second = class._thumbFor("/a", replacement, 60, 90); assert(second ~= first)
    replacement.inverse = 1
    local inverse = class._thumbFor("/a", replacement, 60, 90); H.eq(inverse.inverse, 1); assert(inverse ~= second)
    replacement.rotation = 1
    local rotated = class._thumbFor("/a", replacement, 60, 90); assert(rotated ~= inverse)
    replacement.kind = 1
    assert(class._thumbFor("/a", replacement, 60, 90) ~= rotated)
    H.eq(calls.art, 2)
end)
H.test("failed scaling retries and does not poison an already live image", function()
    local class, calls, failure = fixture()
    local source = buffer(400, 600)
    local first = class._thumbFor("/a", source, 60, 90)
    failure(true)
    H.eq(class._thumbFor("/a", source, 61, 90), nil)
    H.eq(class._thumbFor("/a", source, 60, 90), first)
    failure(false)
    assert(class._thumbFor("/a", source, 61, 90))
    H.eq(calls.art, 3)
end)
H.test("a normal colour page stays warm and retained copies obey byte and entry bounds", function()
    local class, calls = fixture()
    local sources = {}
    for i = 1, 24 do sources[i] = buffer(600, 900, tostring(i)); class._thumbFor("/" .. i, sources[i], 200, 300) end
    for i = 1, 24 do class._thumbFor("/" .. i, sources[i], 200, 300); H.eq(calls[tostring(i)], 1) end
    local cache = assert(class._orbitui_cover_thumbnails)
    H.eq(cache:count(), 24); H.eq(cache:bytes(), 24 * 200 * 300 * 4)
    for i = 25, 120 do class._thumbFor("/" .. i, buffer(600, 900), 200, 300) end
    assert(cache:count() <= 96 and cache:bytes() <= 12 * 1024 * 1024)
    -- Like the other shared LRUs, one oversized newest image remains usable.
    local big = class._thumbFor("/big", buffer(2200, 2400), 2000, 2000)
    H.eq(cache:count(), 1); H.eq(cache:bytes(), 16000000); H.eq(big:getWidth(), 2000)
end)
H.test("native cover invalidations clear only derived copies and preserve native results and errors", function()
    local class = fixture()
    local source = buffer(400, 600)
    local disk_calls = 0
    local native = {}
    for _, name in ipairs{ "drop", "dropMemory", "clear" } do
        native[name] = function(self, a, b)
            H.eq(self, native); disk_calls = disk_calls + 1
            if a == "error" then error(b) end
            return nil, a, nil, b
        end
    end
    Host.thumbnailSourceCache(native)
    local drop = native.drop; Host.thumbnailSourceCache(native); H.eq(native.drop, drop)
    local one = class._thumbFor("/a", source, 60, 90)
    local two = class._thumbFor("/b", source, 60, 90)
    local a, b, c, d = native:drop("/a", "kept"); H.eq(a, nil); H.eq(b, "/a"); H.eq(c, nil); H.eq(d, "kept")
    assert(class._thumbFor("/a", source, 60, 90) ~= one)
    H.eq(class._thumbFor("/b", source, 60, 90), two)
    native:dropMemory()
    assert(class._thumbFor("/b", source, 60, 90) ~= two)
    class._thumbFor("/a", source, 60, 90); native:clear(); H.eq(class._orbitui_cover_thumbnails:count(), 0)
    local reason = {}; local ok, err = pcall(native.drop, native, "error", reason); H.eq(ok, false); H.eq(err, reason)
    H.eq(disk_calls, 4)
end)
H.test("teardown drops references without freeing live widgets and can reset after reattachment", function()
    local class = fixture()
    local source = buffer(400, 600)
    local thumb = class._thumbFor("/a", source, 60, 90)
    require("infra/sui_memory").reset()
    H.eq(class._orbitui_cover_thumbnails:count(), 0); H.eq(thumb:getWidth(), 60)
    class._thumbFor("/a", source, 60, 90)
    require("infra/sui_memory").reset()
    H.eq(class._orbitui_cover_thumbnails:count(), 0)
end)
H.test("installation is lazy idempotent and preserves external thumbnail owners", function()
    local class = {}
    local function foreign() return "external" end
    class.coverThumbFor = foreign; Host.coverThumbnails(class); H.eq(class.coverThumbFor, foreign)
    class = {}; Host.coverThumbnails(class)
    local own = class.coverThumbFor; Host.coverThumbnails(class); H.eq(class.coverThumbFor, own)
    H.eq(class._orbitui_cover_thumbnails, nil)
end)
local render_cover = assert(native_source:match("(function SpineWidget:_renderCover%(bb%).-\nend)\n"))
H.test("the complete native warm-cover renderer uses the service without decoding or owning its pixels", function()
    local class, calls = fixture()
    local source = buffer(400, 600)
    compile(render_cover, { SpineWidget = class, CARD_BORDER = 2,
        ScaledCoverCache = { get = function() return source end },
        _thumbFor = class._thumbFor,
        _getRepo = function() error("unexpected warm-cover decode") end,
        ImageWidget = { new = function(_, args) return args end } })
    local widget = setmetatable({ book = { filepath = "/cover" }, cover_fill = true,
        _cardDimensions = function() return 64, 94 end,
        _wrapCoverInCard = function(_, image) return image end }, { __index = class })
    local first = widget:_renderCover()
    for _i = 1, 10 do
        local image = widget:_renderCover()
        H.eq(image.image, first.image); H.eq(image.image_disposable, false)
        H.eq(image.width, 60); H.eq(image.height, 90)
    end
    H.eq(calls.art, 1)
end)
H.test("external replacement covers reuse exact-size copies instead of rescaling on every rebuild", function()
    local class, calls = fixture()
    local source, stamp = buffer(400, 600), "/external/v1"
    class.externalCoverKey = function() return stamp end
    compile(render_cover, { SpineWidget = class, CARD_BORDER = 2,
        ScaledCoverCache = { get = function(_, key) H.eq(key, stamp); return source end },
        _thumbFor = class._thumbFor,
        _getRepo = function() error("unexpected external-cover decode") end,
        ImageWidget = { new = function(_, args)
            -- Native ImageWidget scales a supplied larger bitmap during _render.
            if args.image:getWidth() ~= args.width or args.image:getHeight() ~= args.height then
                args.image = package.loaded["ui/renderimage"]:scaleBlitBuffer(
                    args.image, args.width, args.height, args.image_disposable)
            end
            return args
        end } })
    local widget = setmetatable({ book = { filepath = "/book", cover_image_path = "/external.jpg" }, cover_fill = true,
        _cardDimensions = function() return 64, 94 end,
        _wrapCoverInCard = function(_, image) return image end }, { __index = class })
    local first = widget:_renderCover()
    local last
    for _i = 1, 19 do last = widget:_renderCover() end
    H.eq(calls.art, 1, "external cover must scale once, not once per rebuild")
    H.eq(last.image, first.image)
    stamp, source = "/external/v2", buffer(400, 600, "replacement")
    assert(widget:_renderCover().image ~= first.image); H.eq(calls.replacement, 1)
end)
local native_image = os.getenv("ORBITUI_NATIVE_THUMB_IMAGE_WIDGET")
local native_bb = os.getenv("ORBITUI_NATIVE_BB_DIR")
if jit and native_image and native_bb then
    local ffi = require("ffi")
    ffi.cdef[[void *malloc(size_t); void *calloc(size_t,size_t); void free(void *);]]
    package.loaded["ffi/posix_h"] = true
    package.loaded["ffi/util"] = { idiv = function(a, b) return math.floor(a / b) end }
    ffi.loadlib = function() return ffi.load(assert(os.getenv("ORBITUI_NATIVE_BB_LIB"))) end
    local BB = dofile(native_bb .. "/ffi/blitbuffer.lua")
    local image_source = read(native_image)
    H.test("actual ImageWidget and native grey/RGB buffers preserve pixels flags borrowing and weak cdata sources", function()
        for _, kind in ipairs{ BB.TYPE_BB8, BB.TYPE_BBRGB32 } do
            for _, cbb in ipairs{ false, true } do
                BB:setUseCBB(cbb)
                for _, inverse in ipairs{ 0, 1 } do
                    local class = {}; Host.coverThumbnails(class)
                    compile(body, { SpineWidget = class })
                    local scales = 0
                    local renderer = { scaleBlitBuffer = function(_, src, w, h, disposable)
                        H.eq(disposable, false); scales = scales + 1
                        return src:scale(w, h) -- native BB scaler stand-in, not a MuPDF benchmark
                    end }
                    package.loaded["ui/renderimage"] = renderer
                    local image = {}
                    local env = { ImageWidget = image, RenderImage = renderer, logger = package.loaded.logger, DPI_SCALE = 1 }
                    for _, method in ipairs{ "_loadimage", "_render", "free" } do
                        compile(assert(image_source:match("(function ImageWidget:" .. method .. "%(%).-\nend)\n")), env)
                    end
                    function image:new(args)
                        args.rotation_angle, args.scale_for_dpi = 0, false
                        args.center_x_ratio, args.center_y_ratio = .5, .5
                        args._max_off_center_x_ratio, args._max_off_center_y_ratio = 0, 0
                        setmetatable(args, { __index = self }); args:_render(); return args
                    end
                    local src = BB.new(80, 120, kind)
                    src:paintRect(0, 0, 80, 120, BB.Color8(51))
                    src:paintRect(20, 30, 40, 60, BB.Color8(200)); src:setInverse(inverse)
                    local ref = src:scale(40, 60)
                    local actual = class._thumbFor("/native", src, 40, 60)
                    local first = image:new{ image = actual, image_disposable = false, width = 40, height = 60 }
                    for y = 0, 59 do for x = 0, 39 do
                        H.eq(first._bb:getPixel(x, y):getColor8().a, ref:getPixel(x, y):getColor8().a)
                    end end
                    local second = image:new{ image = class._thumbFor("/native", src, 40, 60),
                        image_disposable = false, width = 40, height = 60 }
                    H.eq(scales, 1); H.eq(src:getInverse(), inverse); H.eq(second._bb_disposable, false)
                    first:free(); H.eq(second._bb:getWidth(), 40)
                    local function exerciseExternal(owner, code)
                        owner.externalCoverKey = function() return "/native-external-stamp" end
                        compile(code, { SpineWidget = owner, CARD_BORDER = 2, ImageWidget = image,
                            ScaledCoverCache = { get = function() return src end } })
                        local w = setmetatable({ book = { cover_image_path = "/external.jpg" }, cover_fill = true,
                            _cardDimensions = function() return 44, 64 end,
                            _wrapCoverInCard = function(_, img) return img end }, { __index = owner })
                        local before = scales
                        for _i = 1, 20 do
                            local img = w:_renderCover()
                            H.eq(img._bb:getPixel(10, 15):getColor8().a, ref:getPixel(10, 15):getColor8().a)
                            img:free()
                        end
                        return scales - before
                    end
                    local old_spine = os.getenv("ORBITUI_NATIVE_THUMB_BASELINE")
                    if old_spine then
                        local old_render = assert(read(old_spine):match("(function SpineWidget:_renderCover%(bb%).-\nend)\n"))
                        H.eq(exerciseExternal({}, old_render), 20, "exact baseline must reproduce repeat scaling")
                    end
                    H.eq(exerciseExternal(class, render_cover), 1, "new external covers must reuse scaled pixels")
                    local weak = setmetatable({ src }, { __mode = "v" })
                    src = nil; collectgarbage("collect"); collectgarbage("collect"); H.eq(weak[1], nil)
                    require("infra/sui_memory").reset(); H.eq(second._bb:getHeight(), 60)
                    second:free(); ref:free()
                end
            end
        end
    end)
end
H.finish()
