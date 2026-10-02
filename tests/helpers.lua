local M = { count = 0 }

function M.eq(actual, expected, message)
    assert(actual == expected, (message or "Mismatch") .. ": expected " .. tostring(expected)
        .. ", got " .. tostring(actual))
end

function M.test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    M.count = M.count + 1
    print("PASS " .. name)
end

function M.finish()
    print("OrbitUI suite: " .. M.count .. " tests passed")
end

function M.root()
    local f = assert(io.popen("pwd"))
    local dir = assert(f:read("*l"))
    f:close()
    return dir
end

function M.widget()
    local Widget = {}
    function Widget:extend(o)
        self.__index = self
        return setmetatable(o or {}, self)
    end
    function Widget:new(o)
        o = self:extend(o)
        if o._init then o:_init() end
        if o.init then o:init() end
        return o
    end
    function Widget:propagateEvent(event)
        for _, child in ipairs(self) do
            if child:handleEvent(event) then return true end
        end
        return false
    end
    function Widget:handleEvent(event)
        if self:propagateEvent(event) then return true end
        local handler = self[event.handler]
        if handler then
            local args = event.args or {}
            return handler(self, (unpack or table.unpack)(args, 1, args.n or #args))
        end
    end
    return Widget
end

return M
