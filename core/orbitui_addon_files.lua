-- Filesystem operations confined to an add-on's own staging/version directories.
local F = {}
local function fs() return require("libs/libkoreader-lfs") end
function F.attr(path) return fs().symlinkattributes(path) end
function F.mkdir(path)
    local a = F.attr(path)
    if a then assert(a.mode == "directory", "Not a plain directory: " .. path); return end
    local parent = path:match("^(.*)/[^/]+$")
    if parent and parent ~= "" then F.mkdir(parent) end
    assert(fs().mkdir(path))
end
function F.read(path, limit)
    local a = F.attr(path)
    if not a then return nil end
    assert(a.mode == "file" and a.size <= (limit or 2 * 1024 * 1024), "Invalid/oversized data file")
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a"); f:close()
    return assert(text)
end
function F.write(path, data)
    F.mkdir(assert(path:match("^(.*)/[^/]+$")))
    local temporary = F.attr(path .. ".tmp")
    assert(not temporary or temporary.mode == "file", "Unexpected temporary file")
    if temporary then assert(os.remove(path .. ".tmp")) end
    local f = assert(io.open(path .. ".tmp", "wb"))
    local ok, err = pcall(function()
        assert(f:write(data)); assert(f:flush())
        local loaded, util = pcall(require, "ffi/util")
        if loaded and util.fsyncOpenedFile then assert(util.fsyncOpenedFile(f)) end
    end)
    local closed, cerr = f:close()
    if not ok or not closed then os.remove(path .. ".tmp"); error(err or cerr) end
    local renamed, rerr = os.rename(path .. ".tmp", path)
    if not renamed then os.remove(path .. ".tmp"); error(rerr) end
    local loaded, util = pcall(require, "ffi/util")
    if loaded and util.fsyncDirectory then util.fsyncDirectory(path) end
end
function F.json(path, optional)
    local text = F.read(path)
    if not text and optional then return nil end
    assert(text, "Missing data file: " .. path)
    local value = require("rapidjson").decode(text)
    assert(type(value) == "table", "Invalid JSON object")
    return value
end
function F.save(path, value) F.write(path, require("rapidjson").encode(value)) end
function F.copy(source, target)
    F.write(target, assert(F.read(source, 16 * 1024 * 1024)))
end
function F.remove(path)
    local a = F.attr(path)
    if not a then return end
    if a.mode == "directory" then
        for name in fs().dir(path) do
            if name ~= "." and name ~= ".." then F.remove(path .. "/" .. name) end
        end
        assert(fs().rmdir(path))
    else assert(os.remove(path)) end
end
function F.walk(path, prefix, out)
    out, prefix = out or {}, prefix or ""
    if not F.attr(path) then return out end
    assert(F.attr(path).mode == "directory", "Not a plain directory")
    for name in fs().dir(path) do
        if name ~= "." and name ~= ".." then
            local a = assert(F.attr(path .. "/" .. name))
            assert(a.mode == "file" or a.mode == "directory", "Links are not allowed in managed packs")
            if a.mode == "directory" then F.walk(path .. "/" .. name, prefix .. name .. "/", out)
            else out[#out + 1] = prefix .. name end
        end
    end
    return out
end
return F
