local M = {}
local names = { "bookshelf", "simpleui" }

function M.attach(owner, classes, loader, root)
    assert(owner.ui, "OrbitUI requires a FileManager or ReaderUI host")
    local prefix = owner.ui.document and "reader" or "filemanager"
    owner._orbitui_components = {}
    for _, name in ipairs(names) do
        assert(not owner.ui[name], "Host already owns " .. name)
        assert(classes[name], "Missing component " .. name)
    end
    -- Allocate both first so cross-component callbacks resolve during init.
    for _, name in ipairs(names) do
        local class = assert(classes[name], "Missing component " .. name)
        local instance = class:extend{
            ui = owner.ui,
            path = root .. "/components/" .. name,
            name = prefix .. name,
            _orbitui_owned = true,
        }
        owner._orbitui_components[name] = instance
        owner.ui[name] = instance
        if loader.loaded_plugins then loader.loaded_plugins[name] = instance end
        owner[#owner + 1] = instance
    end
    for _, name in ipairs(names) do
        local instance = owner._orbitui_components[name]
        if instance._init then instance:_init() end
        if instance.init then instance:init() end
    end
end

function M.detach(owner, loader)
    for _, name in ipairs(names) do
        local instance = owner._orbitui_components and owner._orbitui_components[name]
        if instance then
            if owner.ui[name] == instance then owner.ui[name] = nil end
            if owner.ui._simpleui_plugin == instance then owner.ui._simpleui_plugin = nil end
            if loader.loaded_plugins and loader.loaded_plugins[name] == instance then
                loader.loaded_plugins[name] = nil
            end
        end
    end
end

function M.abort(owner, loader)
    for i = #owner, 1, -1 do
        local instance = owner[i]
        if instance._cancelReaderPrewarm then pcall(instance._cancelReaderPrewarm, instance) end
        if instance.onTeardown then pcall(instance.onTeardown, instance) end
        owner[i] = nil
    end
    M.detach(owner, loader)
end

function M.propagate(owner, event, report)
    for _, instance in ipairs(owner) do
        local ok, consumed = pcall(instance.handleEvent, instance, event)
        if not ok then
            report(instance.name, consumed)
        elseif consumed then
            return true
        end
    end
    return false
end

return M
