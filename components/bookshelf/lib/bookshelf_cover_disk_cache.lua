--[[--
Disk backing for ScaledCoverCache.

ScaledCoverCache is memory-only, so every launch re-derives every visible
cover: BookInfoManager hands back a compressed cover, we decompress it and
scale it to the slot. Measured on a PW5, a first render of the Series chip
spent ~900ms doing that for the ~24 covers of one page, about a quarter of a
3.5s cold start, and paid it again on the next launch.

The covers are already persisted -- in BIM's database -- so this does not
store anything new. It stores the RESULT: the scaled blitbuffer, raw, so a
later launch reads it back instead of decompressing and rescaling. Reading a
262x393 8bpp buffer off the PW5 measured 2.9ms against ~37ms to rebuild it.

Deliberately dumb about correctness. Every way a cover can change already
funnels through ScaledCoverCache:drop (the stale sweep, and the widget when
BIM finishes a fresh extraction) or :clear (a cover-size settings change), so
this mirrors those and owns no invalidation logic of its own. On top of that
each file carries the filepath and geometry it was written for and is rejected
if either disagrees, which turns a hash collision or a half-written file into
a miss rather than a wrong cover on screen.
]]--

local lfs = require("libs/libkoreader-lfs")
local Blitbuffer = require("ffi/blitbuffer")
local logger = require("logger")

local M = {}

local MAGIC = "BSC1"
-- Bounded in BYTES, for the reason ScaledCoverCache gives for bounding RAM
-- the same way: entry size varies ~5x between a shelf cover and a hero one and
-- ~4x between 8bpp grayscale and RGB32, so a file COUNT maps to wildly
-- different amounts of disk. The sweep already stats each file for its mtime;
-- taking the size from the same call makes the byte bound free.
-- 96MB (was 32). One page of shelf covers is ~2.4MB, so this holds ~40 pages
-- -- enough that a deep paging session survives a restart instead of paying
-- the decode+scale again for everything beyond the first dozen pages (the
-- post-restart "first visit to every page is slow" report). Still a cache,
-- not a mirror of the library, and still modest next to BIM's cover
-- database -- the largest thing bookshelf touches on a Kindle.
M.MAX_BYTES = 96 * 1024 * 1024
M.ORNAMENT_MAX_BYTES = 24 * 1024 * 1024
M.DISK_SHARE, M.PRUNE_TO = 0.25, 0.85
M.SWEEP_DELAY, M._auto = 15, true
local ORNAMENT_PREFIX = "ornament:"
local TOUCH_AFTER = 24 * 60 * 60

local _dir            -- resolved cache directory, or false when unavailable
local _entries, _bytes, _indexed = {}, 0, false
local _cover_bytes, _ornament_bytes = 0, 0
local _task, _dir_handle
local _active = true
local _write_generation = 0

local function record(path, size, mtime)
    local old = _entries[path]
    _bytes = _bytes - (old and old.b or 0) + (size or 0)
    local ornament = path:match("/o[0-9a-f]+_%d+$") ~= nil
    if ornament then
        _ornament_bytes = _ornament_bytes - (old and old.b or 0) + (size or 0)
    else
        _cover_bytes = _cover_bytes - (old and old.b or 0) + (size or 0)
    end
    _entries[path] = size and { p = path, b = size, m = mtime or 0, ornament = ornament } or nil
end

local function cancelMaintenance()
    if _task then
        _task.ui:unschedule(_task.tick)
        _task = nil
    end
    if _dir_handle then
        pcall(function() _dir_handle:close() end)
        _dir_handle = nil
    end
end

local function dir()
    if _dir ~= nil then return _dir or nil end
    local ok, DataStorage = pcall(require, "datastorage")
    if not (ok and DataStorage and DataStorage.getDataDir) then
        _dir = false
        return nil
    end
    local d = require("lib/bookshelf_paths").cacheFile("scaled_covers")
    if lfs.attributes(d, "mode") ~= "directory" then
        local ok_mk = pcall(lfs.mkdir, d)
        if not ok_mk or lfs.attributes(d, "mode") ~= "directory" then
            _dir = false
            return nil
        end
    end
    _dir = d
    return d
end

-- djb2 over the path. Multiplication and addition only: KOReader runs LuaJIT,
-- which is Lua 5.1, where the binary `~` xor operator does not exist (it
-- parses on newer LuaJIT builds and on the 5.4 interpreter the tests use,
-- which is exactly why the mistake would have survived to the device). The
-- intermediate stays under 2^53, so it is exact in a double.
--
-- Only has to spread filenames across a directory. Book paths share long
-- prefixes, so trailing bytes -- where they actually differ -- dominate. A
-- collision is caught by the filepath stored in the file header.
local function keyFor(filepath)
    local h = 5381
    for i = 1, #filepath do
        h = (h * 33 + filepath:byte(i)) % 4294967296
    end
    local kind = filepath:sub(1, #ORNAMENT_PREFIX) == ORNAMENT_PREFIX and "o" or ""
    return string.format("%s%08x_%d", kind, h, #filepath)
end

local function pathFor(filepath)
    local d = dir()
    if not d then return nil end
    return d .. "/" .. keyFor(filepath)
end

-- The book a cache file was written for, without reading its pixels. Used only
-- by the over-budget branch of the sweep, so the common case never pays it.
local function bookOf(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local header = f:read("*l")
    local fp
    if header then
        local magic, _w, _h, _s, _t, fplen =
            header:match("^(%S+) (%d+) (%d+) (%d+) (%d+) (%d+)$")
        if magic == MAGIC then fp = f:read(tonumber(fplen) or 0) end
    end
    f:close()
    return fp
end

-- Reuse upstream's separate budgets and free-space cap, but keep OrbitUI's
-- bounded/cancellable index and pruning: no full directory walk in a paint.
function M._freeBytes(path)
    local ok, bytes = pcall(function()
        local ffi = require("ffi")
        require("ffi/posix_h")
        local st = ffi.new("struct statvfs")
        if ffi.C.statvfs(path, st) ~= 0 then return nil end
        return tonumber(st.f_bavail) * tonumber(st.f_frsize)
    end)
    if ok and type(bytes) == "number" and bytes >= 0 and bytes < math.huge then return bytes end
end

local function caps(d)
    local c, o = M.MAX_BYTES, M.ORNAMENT_MAX_BYTES
    local free = M._freeBytes(d)
    if free and c + o > 0 then
        local factor = math.min(1, (free + _bytes) * M.DISK_SHARE / (c + o))
        c, o = math.floor(c * factor), math.floor(o * factor)
    end
    return c, o
end

-- Index existing files once, then account for every store/drop. Automatic
-- maintenance yields between small batches of filesystem operations.
local function sweep(yield_step)
    yield_step = yield_step or function() end
    local d = dir()
    if not d then return end
    if not _indexed then
        local iter, handle = lfs.dir(d)
        _dir_handle = handle
        for entry in iter, handle do
            if entry:sub(1, 1) ~= "." then
                local p = d .. "/" .. entry
                local a = lfs.attributes(p) or {}
                if a.mode == "file" then record(p, a.size, a.modification) end
                yield_step()
            end
        end
        _dir_handle = nil
        _indexed = true
    end
    local cover_cap, ornament_cap = caps(d)
    local cover_over, ornament_over = _cover_bytes > cover_cap, _ornament_bytes > ornament_cap
    if not cover_over and not ornament_over then return end
    local entries = {}
    for _, entry in pairs(_entries) do entries[#entries + 1] = entry end
    -- Over budget. Before falling back to age, drop covers whose book is no
    -- longer there: those can never be used again, while an old cover for a
    -- book still on the shelf may well be wanted on the next launch.
    --
    -- This is the ONLY place that check happens, deliberately. Dropping a
    -- deleted book's cover eagerly (say, from the stale sweep, which already
    -- knows which files have gone) would churn every session for anyone whose
    -- library lives on removable media: unmounted reads as deleted, and the
    -- covers would be discarded and rebuilt on every mount. Doing it only when
    -- space is actually short means an unmounted card costs nothing until the
    -- cache is full, and even then it costs a rebuild rather than a wrong
    -- cover.
    local orphans = 0
    for i = 1, #entries do
        local fp = bookOf(entries[i].p)
        -- No readable header is its own kind of orphan: nothing can use it.
        local legacy = false
        if fp and fp:sub(1, #ORNAMENT_PREFIX) == ORNAMENT_PREFIX then
            legacy = not entries[i].ornament
            fp = fp:match("^ornament:(.-)|") or fp
        end
        entries[i].orphan = legacy or (fp == nil) or (lfs.attributes(fp, "mode") == nil)
        if entries[i].orphan then orphans = orphans + 1 end
        yield_step()
    end
    table.sort(entries, function(a, b)
        if a.orphan ~= b.orphan then return a.orphan end   -- orphans first
        return a.m < b.m                                    -- then oldest
    end)
    local pruned = 0
    for i = 1, #entries do
        local cover_needed = cover_over and _cover_bytes > math.floor(cover_cap * M.PRUNE_TO)
        local ornament_needed = ornament_over and _ornament_bytes > math.floor(ornament_cap * M.PRUNE_TO)
        if not cover_needed and not ornament_needed then break end
        local entry = entries[i]
        local needed = (entry.ornament and ornament_needed) or (not entry.ornament and cover_needed)
        -- A foreground render may have replaced this file while we yielded.
        if needed and _entries[entry.p] == entry then
            local ok, removed = pcall(os.remove, entry.p)
            if (ok and removed) or lfs.attributes(entry.p, "mode") == nil then
                record(entry.p, nil)
                pruned = pruned + 1
            end
        end
        yield_step()
    end
    logger.dbg(string.format(
        "[bookshelf] cover disk cache: pruned %d of %d files (%d orphaned), now %d KB",
        pruned, #entries, orphans, math.floor(_bytes / 1024)))
end

-- Explicit maintenance stays synchronous for tools/tests. Normal writes only
-- queue bounded I/O steps; the byte ledger includes writes between steps.
function M.sweep()
    cancelMaintenance()
    _entries, _bytes, _indexed = {}, 0, false
    _cover_bytes, _ornament_bytes = 0, 0
    local ok, err = pcall(sweep)
    if not ok then
        cancelMaintenance()
        logger.warn("[bookshelf] cover cache sweep:", err)
    end
end

local function maybeSweep()
    if not _active or not M._auto or _task then return end
    if _indexed then
        local c, o = caps(dir())
        if _cover_bytes <= c and _ornament_bytes <= o then return end
    end
    local ok, ui = pcall(require, "ui/uimanager")
    if not ok or not ui.scheduleIn or not ui.unschedule then return end
    local task = { ui = ui, generation = _write_generation }
    local co = coroutine.create(function()
        local operations = 0
        sweep(function()
            operations = operations + 1
            if operations >= 8 then operations = 0; coroutine.yield() end
        end)
    end)
    _task = task
    task.tick = function()
        if _task ~= task then return end
        local resumed, err = coroutine.resume(co)
        if not resumed or coroutine.status(co) == "dead" then
            cancelMaintenance()
            if not resumed then logger.warn("[bookshelf] cover cache sweep:", err) end
            -- A render can add files after this sweep built its candidate
            -- list. Retry for those writes, but never spin on failed deletes.
            if resumed and task.generation ~= _write_generation then maybeSweep() end
        else
            ui:scheduleIn(0.02, task.tick)
        end
    end
    ui:scheduleIn(M.SWEEP_DELAY, task.tick)
end

-- Explicit check uses the already-exact session ledger when it can. A new
-- process indexes lazily in bounded steps; no stale persistent tally is trusted.
function M._check()
    local d = dir()
    if not d then return end
    local c, o = caps(d)
    if _indexed and _cover_bytes <= c and _ornament_bytes <= o then return end
    M.sweep()
end

function M.setActive(active)
    _active = active == true
    if _active then maybeSweep() else cancelMaintenance() end
end

-- C stdio through the ffi, for the pixels: read and written straight
-- between the file and the buffer. Through Lua they went via a string the
-- size of the image (a cover ~260 KB, an ornament ~480 KB on a PW5): garbage
-- on every load and store, and a full collect walks everything in use. nil
-- when it cannot be had; the Lua way then stands.
function M._cstdio()
    if M._stdio ~= nil then return M._stdio or nil end
    local ok_ffi, ffi = pcall(require, "ffi")
    if not ok_ffi then M._stdio = false; return nil end
    pcall(require, "ffi/posix_h")
    pcall(ffi.cdef, "typedef struct _IO_FILE FILE;")
    pcall(ffi.cdef, "FILE *fopen(const char *, const char *);")
    pcall(ffi.cdef, "size_t fread(void *, size_t, size_t, FILE *);")
    pcall(ffi.cdef, "size_t fwrite(const void *, size_t, size_t, FILE *);")
    pcall(ffi.cdef, "int fclose(FILE *);")
    pcall(ffi.cdef, "int fseek(FILE *, long, int);")
    local ok = pcall(function()
        local C = ffi.C
        assert(C.fopen and C.fread and C.fwrite and C.fclose and C.fseek)
    end)
    M._stdio = ok and ffi or false
    return M._stdio or nil
end

--- Write a scaled cover. Returns true when it landed on disk.
function M.store(filepath, bb)
    if type(filepath) ~= "string" or filepath == "" or not bb then return false end
    local p = pathFor(filepath)
    if not p then return false end
    local size, file
    local tmp = p .. ".tmp"
    local ok = pcall(function()
        local ffi = require("ffi")
        local w, h = bb:getWidth(), bb:getHeight()
        local stride = tonumber(bb.stride)
        local btype  = tonumber(bb:getType())
        if not (w and h and stride and btype) or w <= 0 or h <= 0 then
            error("unusable blitbuffer")
        end
        -- Refuse anything Blitbuffer.new(w, h, type, nil, stride) would not
        -- reproduce exactly. The header carries w, h, stride and type, and the
        -- reader rebuilds from those alone, so a buffer holding state outside
        -- that set must be a miss rather than a subtly wrong cover.
        --
        -- Two things live outside it. pixel_stride is derived from stride and
        -- bpp on the way back in, so a buffer whose own pixel_stride disagrees
        -- would come back reshaped. Rotation and inversion live in the config
        -- byte, which the header has nowhere to put, and an inverted cover
        -- reloaded as a normal one is a photo negative on the shelf.
        --
        -- Note this does NOT reject viewport buffers, and does not need to: a
        -- viewport keeps its parent's stride, so its extra columns sit beyond
        -- w and are never painted, and its rows round-trip as they are.
        local bpp = Blitbuffer.TYPE_TO_BPP and Blitbuffer.TYPE_TO_BPP[btype]
        if not bpp then error("unknown buffer type") end
        if tonumber(bb.pixel_stride) ~= math.floor(stride * 8 / bpp) then
            error("non-derivable pixel stride (viewport or padded buffer)")
        end
        if (bb.getRotation and bb:getRotation() or 0) ~= 0 then error("rotated") end
        if (bb.getInverse  and bb:getInverse()  or 0) ~= 0 then error("inverted") end
        -- Write to a sibling and rename, so a crash mid-write cannot leave a
        -- truncated file that later reads as a valid header with short data.
        -- Every write and the close checked: on a full disk a short file
        -- renamed over a good one would be re-decoded and rewritten every
        -- session. A failure keeps the good copy and removes the temp file.
        local f = assert(io.open(tmp, "wb"))
        file = f
        local header = string.format("%s %d %d %d %d %d\n%s\n",
            MAGIC, w, h, stride, btype, #filepath, filepath)
        local ok_w, ok_c
        local cs = M._cstdio()
        if cs then
            ok_w = f:write(header)
            ok_c = f:close()
            if ok_w and ok_c then
                local fp = cs.C.fopen(tmp, "ab")
                if fp == nil then ok_w = false
                else
                    ok_w = tonumber(cs.C.fwrite(bb.data, 1, stride * h, fp)) == stride * h
                    ok_c = cs.C.fclose(fp) == 0
                end
            end
        else
            ok_w = f:write(header) and f:write(ffi.string(bb.data, stride * h))
            ok_c = f:close()
        end
        if not (ok_w and ok_c) then
            os.remove(tmp)
            error("write failed")
        end
        file = nil
        assert(os.rename(tmp, p))
        size = #header + stride * h
    end)
    if ok then
        record(p, size, os.time())
        _write_generation = _write_generation + 1
        maybeSweep()
    else
        if file then pcall(file.close, file) end
        os.remove(tmp)
    end
    return ok
end

--- Read a scaled cover back, or nil. Never returns a buffer for a different
--- book or a different geometry than it was written with.
function M.load(filepath)
    if type(filepath) ~= "string" or filepath == "" then return nil end
    local p = pathFor(filepath)
    if not p then return nil end
    local ok, bb = pcall(function()
        local f = io.open(p, "rb")
        if not f then return nil end
        local header = f:read("*l")
        if not header then f:close(); return nil end
        local magic, w, h, stride, btype, fplen =
            header:match("^(%S+) (%d+) (%d+) (%d+) (%d+) (%d+)$")
        if magic ~= MAGIC then f:close(); return nil end
        w, h, stride, btype, fplen =
            tonumber(w), tonumber(h), tonumber(stride), tonumber(btype), tonumber(fplen)
        local stored_fp = f:read(fplen)
        f:read(1)  -- the newline after the path
        if stored_fp ~= filepath then f:close(); return nil end   -- hash collision
        local want = stride * h
        local cs = M._cstdio()
        local out
        if cs then
            local off = f:seek()
            f:close()
            out = Blitbuffer.new(w, h, btype, nil, stride)
            if not out then return nil end
            local fp = cs.C.fopen(p, "rb")
            local got = 0
            if fp ~= nil then
                if cs.C.fseek(fp, off, 0) == 0 then
                    got = tonumber(cs.C.fread(out.data, 1, want, fp))
                end
                cs.C.fclose(fp)
            end
            if got ~= want then out:free(); return nil end         -- truncated
        else
            local data = f:read(want)
            f:close()
            if not data or #data ~= want then return nil end       -- truncated
            out = Blitbuffer.new(w, h, btype, nil, stride)
            if not out then return nil end
            local ffi = require("ffi")
            ffi.copy(out.data, data, want)
        end
        local mt, now = lfs.attributes(p, "modification"), os.time()
        if mt and now - mt > TOUCH_AFTER and lfs.touch then
            local touched, result = pcall(lfs.touch, p, now, now)
            if touched and result and _entries[p] then record(p, _entries[p].b, now) end
        end
        return out
    end)
    return ok and bb or nil
end

function M.drop(filepath)
    local p = pathFor(filepath)
    if p then
        local ok, removed = pcall(os.remove, p)
        if (ok and removed) or not lfs.attributes(p, "mode") then record(p, nil) end
    end
end

function M.clear()
    cancelMaintenance()
    local d = dir()
    if not d then return end
    pcall(function()
        for entry in lfs.dir(d) do
            if entry ~= "." and entry ~= ".." then pcall(os.remove, d .. "/" .. entry) end
        end
    end)
    _entries, _bytes, _indexed = {}, 0, false
    _cover_bytes, _ornament_bytes = 0, 0
end

return M
