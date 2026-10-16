-- sui_raster_cache.lua — Simple UI
-- Byte-budgeted LRU for rasters that depend only on their geometry:
-- anti-aliased masks, shadows and sprites that are built once and blitted on
-- every paint.
--
-- An entry is a table. Its Blitbuffer fields are freed when the entry is
-- evicted or cleared, so an entry is only valid until the next get(): callers
-- fetch it and blit straight away, and never keep a reference.
--
-- Entries are grouped by kind. Keys are scoped to their kind, so each kind
-- picks the cheapest key for its geometry. The byte budget is shared by all
-- kinds; when it is exceeded the least recently used entries are dropped,
-- never the one just built.

local LRU    = require("infra/sui_lru")
local Memory = require("infra/sui_memory")

local RasterCache = {}

RasterCache.bbBytes = Memory.bbBytes

local function isBuffer(field)
    return type(field) == "cdata"
        or (type(field) == "table" and type(field.free) == "function"
            and type(field.getHeight) == "function")
end

local function entryBytes(value)
    local bytes = 0
    for _, field in pairs(value) do
        if isBuffer(field) then bytes = bytes + RasterCache.bbBytes(field) end
    end
    return bytes
end

local function freeEntry(value)
    for _, field in pairs(value) do
        if isBuffer(field) then field:free() end
    end
end

local _entries = LRU.new{ max_bytes = math.min(3 * 1024 * 1024, Memory.budgets().raster), max_entries = 64, free = freeEntry }

-- Returns the entry cached under (kind, key), building it with
-- build(...) on a miss. `build` returns the entry table.
function RasterCache.get(kind, key, build, ...)
    local value = _entries:get(key, kind)
    if value then return value end
    value = build(...)
    return _entries:put(key, value, entryBytes(value), kind)
end

-- Frees every entry of `kind`, or of all kinds when `kind` is nil.
function RasterCache.clear(kind)
    if kind == nil then
        _entries:clear()
    else
        _entries:removeScope(kind)
    end
end

return RasterCache
