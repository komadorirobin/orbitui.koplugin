-- Stable OTA bootstrap. Changes to this file require a manual installation.
local M = { API = 1, contexts = {} }

function M.read(path, limit)
    local f, err, code = io.open(path, "rb")
    if not f then return nil, err, code end
    local data, read_error = f:read((limit or 4096) + 1)
    f:close()
    if read_error then return nil, read_error end
    data = data or ""
    if #data <= (limit or 4096) then return data end
    return nil, "OrbitUI record exceeds size limit"
end

function M.atomicWrite(path, data)
    local f = assert(io.open(path .. ".tmp", "wb"))
    local ok, err = pcall(function()
        assert(f:write(data))
        assert(f:flush())
        local loaded, util = pcall(require, "ffi/util")
        if loaded and util.fsyncOpenedFile then assert(util.fsyncOpenedFile(f)) end
    end)
    local closed, close_err = f:close()
    if not ok or not closed then
        os.remove(path .. ".tmp")
        error(err or close_err)
    end
    assert(os.rename(path .. ".tmp", path))
    local loaded, util = pcall(require, "ffi/util")
    if loaded and util.fsyncDirectory then util.fsyncDirectory(path) end
end

function M.validSlot(slot)
    return slot == "factory" or (type(slot) == "string" and #slot == 64
        and slot:match("^[0-9a-f]+$") ~= nil)
end

function M.path(root, slot)
    assert(M.validSlot(slot), "Invalid OrbitUI version slot")
    return slot == "factory" and root or root .. "/.orbitui-versions/" .. slot
end

function M.version(root)
    local value = M.read(root .. "/VERSION", 80)
    value = value and value:match("^([%w.%-]+)%s*$")
    assert(value and value:match("^%d+%.%d+%.%d+"), "Missing/invalid OrbitUI VERSION")
    return value
end

function M.state(root)
    local data, err, code = M.read(root .. "/.orbitui-active", 256)
    if not data then
        assert(code == 2, err or "Unreadable OrbitUI activation record")
        return { current = "factory", previous = "none", pending = false }
    end
    local current, previous, pending = data:match("^([^\n]+)\n([^\n]+)\n([01])\n$")
    assert(M.validSlot(current) and (previous == "none" or M.validSlot(previous)),
        "Invalid OrbitUI activation record; see docs/OTA.md for recovery")
    return { current = current, previous = previous, pending = pending == "1" }
end

function M.save(root, state)
    assert(M.validSlot(state.current) and (state.previous == "none" or M.validSlot(state.previous)))
    M.atomicWrite(root .. "/.orbitui-active", state.current .. "\n" .. state.previous
        .. "\n" .. (state.pending and "1" or "0") .. "\n")
end

function M.begin(root)
    if M.contexts[root] then return M.contexts[root] end
    local state = M.state(root)
    local notice
    if state.pending and M.read(root .. "/.orbitui-booting", 80) == state.current then
        assert(state.previous ~= "none", "No OrbitUI rollback version")
        M.version(M.path(root, state.previous))
        state = { current = state.previous, previous = "none", pending = false }
        M.save(root, state)
        os.remove(root .. "/.orbitui-booting")
        notice = "The previous OrbitUI update did not complete startup. The previous version was restored."
    end
    local runtime = M.path(root, state.current)
    if state.pending then M.atomicWrite(root .. "/.orbitui-booting", state.current) end
    local version = M.version(runtime)
    local context = { root = root, runtime = runtime, version = version,
        slot = state.current, notice = notice }
    M.contexts[root] = context
    return context
end

function M.healthy(root)
    local context = assert(M.contexts[root])
    local state = M.state(root)
    if state.pending and state.current == context.slot then
        state.pending = false
        M.save(root, state)
        os.remove(root .. "/.orbitui-booting")
    end
end

function M.activate(root, slot)
    local context = assert(M.contexts[root], "OrbitUI has not started")
    local state = M.state(root)
    assert(not state.pending and state.current == context.slot, "Restart KOReader before another update")
    assert(slot ~= state.current, "That version is already installed")
    M.version(M.path(root, slot))
    M.save(root, { current = slot, previous = state.current, pending = true })
end

function M.rollback(root)
    local state = M.state(root)
    assert(state.previous ~= "none", "No previous OrbitUI version is available")
    M.version(M.path(root, state.previous))
    if state.pending then
        M.save(root, { current = state.previous, previous = "none", pending = false })
        os.remove(root .. "/.orbitui-booting")
    else
        M.activate(root, state.previous)
    end
end

function M.resolver(context)
    local function searcher(name)
        if not (name:match("^core/orbitui_[%w_]+$") or name:match("^adapters/orbitui_[%w_]+$")) then
            return "\n\tnot an OrbitUI core module"
        end
        return assert(loadfile(context.runtime .. "/" .. name .. ".lua"))
    end
    table.insert(package.searchers or package.loaders, 2, searcher)
end

function M.metadata(root)
    local ok, version = pcall(function()
        local state = M.state(root)
        return M.version(M.path(root, state.current))
    end)
    return {
        name = "orbitui",
        fullname = "OrbitUI (preview)",
        description = "Combined SimpleUI and Bookshelf. Disable both standalone plugins and restart before enabling OrbitUI.",
        version = ok and version or "recovery required",
    }
end

return M
