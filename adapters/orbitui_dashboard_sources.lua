-- Read-only bindings to existing owners. Missing sources never become all books.
local _ = require("core/orbitui_i18n")
local Query = require("core/orbitui_shelf_query")
local M = {}
local labels = { tbr = "To Be Read", recent = "Recent", new_books = "Recently added" }

function M.label(source)
    if source.kind == "bookorbit" then
        local label = _("Want to read [BookOrbit]")
        if not require("adapters/orbitui_integrations").bookOrbitEnabled("want") then label = label .. " · " .. _("Disabled") end
        return label
    end
    if source.kind == "native" then
        if labels[source.id] then return _(labels[source.id]) end
        if source.id == "collection" then return source.coll or _("Collection") end
    elseif source.kind == "shelf" then
        local ok, query = pcall(Query.resolve, source.ref)
        if ok and query then return query.label end
    end
    return _("Source unavailable")
end

function M.usesBookOrbit(source)
    if source.kind == "bookorbit" then return true end
    if source.kind == "shelf" then
        local ok, query = pcall(Query.resolve, source.ref)
        return ok and query and query.source.kind == "bookorbit_want" or false
    end
    return false
end

function M.files(source, ctx)
    if M.usesBookOrbit(source) and not require("adapters/orbitui_integrations").bookOrbitEnabled("want") then
        return {}, true
    end
    local ok, files, err = pcall(function()
        if source.kind == "bookorbit" then
            return require("integrations/sui_bookorbit_want").getCachedFiles()
        elseif source.kind == "shelf" then return Query.paths(source.ref)
        elseif source.kind == "native" and (labels[source.id] or source.id == "collection") then
            if source.id == "collection" then
                local rc = require("readcollection")
                if not source.coll or not (rc.coll and rc.coll[source.coll]) then return {}, "missing" end
            end
            local bound = require("engines/sui_book_sources").bind(source.id, function()
                return { coll = source.coll }
            end)
            local result = {}
            for _, file in ipairs(bound.getFileList(ctx)) do
                if not bound.filterItem or bound.filterItem(file, ctx) then result[#result + 1] = file end
            end
            return result
        end
        return {}, "missing"
    end)
    if not ok or err or type(files) ~= "table" then
        require("logger").warn("OrbitUI dashboard: book source unavailable")
        return {}, true
    end
    local result, seen = {}, {}
    for _, file in ipairs(files) do
        if type(file) == "string" and file ~= "" and not file:match("^OPDS://") and not seen[file] then
            seen[file], result[#result + 1] = true, file
        end
    end
    return result
end

function M.shelves()
    local choices = {}
    local function add(ref, label)
        local query = Query.resolve(ref)
        if query and query.source.kind ~= "shelves" then
            choices[#choices + 1] = { label = label, source = { kind = "shelf", ref = ref } }
        end
    end
    for _, section in ipairs(require("lib/bookshelf_profiles").list()) do
        for _, chip in ipairs(section.chips) do
            add({ profile = section.key, chip = chip.key }, section.label .. " / " .. chip.label)
        end
    end
    for _i, tab in ipairs(require("lib/bookshelf_tab_model").load()) do
        add({ chip = tab.id }, _("Library") .. " / " .. tab.label)
    end
    return choices
end

-- Optional card producers. Use their public registries, never require a path
-- from saved settings or scan plugin folders ourselves. Enumeration is only
-- requested by the picker; selected-card lookups use the owners' lazy caches.
function M.resolveModule(entry)
    local ok, result = pcall(function()
        if entry.kind == "simpleui" then
            local registry = require("modules/moduleregistry")
            if entry.ref == "orbitui_dashboard" or registry.isInstance(entry.ref) then return end
            local def = registry.get(entry.ref)
            if type(def) == "table" and type(def.build) == "function" then return def end
        elseif entry.kind == "bookshelf" then
            local def = require("lib/bookshelf_start_menu_modules").get(entry.ref, true)
            if type(def) == "table" and not def.hero_only and type(def.render) == "function" then return def end
        elseif entry.kind == "action" then
            local qa = require("features/sui_quickactions")
            local valid = qa.isRegistered(entry.ref)
            if not valid then
                valid = qa.getCustomQAValid()[entry.ref] == true
            end
            if valid then return { title = qa.getEntry(entry.ref).label } end
        end
    end)
    return ok and result or nil
end

function M.moduleChoices(kind)
    local choices = {}
    local ok, err = pcall(function()
        local function add(ref, label, network)
            if require("core/orbitui_dashboard").moduleId(kind, ref) then
                choices[#choices + 1] = { kind = kind, ref = ref,
                    label = type(label) == "string" and label or ref, network = network }
            end
        end
        if kind == "simpleui" then
            local registry = require("modules/moduleregistry")
            for _, def in ipairs(registry.list()) do
                if def.id ~= "orbitui_dashboard" and not registry.isInstance(def.id)
                        and type(def.build) == "function" then add(def.id, def.name) end
            end
        elseif kind == "bookshelf" then
            local registry = require("lib/bookshelf_start_menu_modules")
            for _, id in ipairs(registry.keys()) do
                local def = registry.get(id, true)
                if def and not def.hero_only and type(def.render) == "function" then add(id, def.title, def.network) end
            end
        elseif kind == "action" then
            local qa, seen = require("features/sui_quickactions"), {}
            for _, list in ipairs({ qa.allIds(), qa.getCustomQAList() }) do
                for _, id in ipairs(list) do
                    if not seen[id] then seen[id] = true; add(id, qa.getEntry(id).label) end
                end
            end
        end
    end)
    if not ok then require("logger").warn("OrbitUI dashboard: module picker unavailable", err) end
    table.sort(choices, function(a, b) return a.label:lower() < b.label:lower() end)
    return choices
end

function M.shortcutPlugin()
    local fm, reader = package.loaded["apps/filemanager/filemanager"], package.loaded["apps/reader/readerui"]
    local plugin = fm and fm.instance and (fm.instance.simpleui or fm.instance._simpleui_plugin)
        or reader and reader.instance and reader.instance.simpleui
    return plugin and type(plugin._rebuildAllNavbars) == "function" and plugin or nil
end

function M.moduleNeed(config, pfx, need)
    local result = need == "recent" and 0 or false
    for _, entry in ipairs(config.modules or {}) do
        if entry.kind == "simpleui" and not config.hidden[entry.id] then
            local def = M.resolveModule(entry)
            local value = def and type(def.needs) == "table" and def.needs[need]
            local ok = true
            if type(value) == "function" then ok, value = pcall(value, pfx) end
            if ok then
                if need == "recent" and type(value) == "number" and value == value then
                    result = math.max(result, math.min(100, math.max(0, value)))
                elseif need ~= "recent" and value then result = true end
            end
        end
    end
    return result
end

function M.buildModule(entry, w, h, ctx)
    local def = M.resolveModule(entry)
    if not def then return nil end
    if entry.kind == "action" then return nil, def end
    local child, regions, args
    local ok, err = pcall(function()
        -- A shallow child context prevents module-local caches/geometry from
        -- overwriting the dashboard's context. Native data owners stay borrowed.
        args = {}
        for k, v in pairs(ctx) do args[k] = v end
        -- Native Clock writes its mounted-widget bookkeeping here. Keep that
        -- private to the card, never replace another Home clock's live slots.
        if ctx._screen_widget then args._screen_widget = setmetatable({}, { __index = ctx._screen_widget }) end
        args.col_w, args.grow_h, args.width, args.height = w, h, w, h
        if entry.kind == "simpleui" then
            args.orbitui_dashboard_hosted = true
            child = def.build(w, args)
        else
            args.entry = { id = entry.id, module = entry.ref }
            args.config = require("lib/bookshelf_module_kit").entryConfig(args.entry)
            args.preview, args.surface, args.scale, args.max_height = false, "orbitui_dashboard", 100, h
            args.refresh = ctx.refresh_fn
            args.set_tap_regions = function(value) regions = value end
            child = def.render(args)
        end
        assert(type(child) == "table" and type(child.getSize) == "function", "No module widget")
        local size = child:getSize()
        assert(size and type(size.w) == "number" and type(size.h) == "number"
            and size.w > 0 and size.h > 0 and size.w < 100000 and size.h < 100000, "Invalid module size")
    end)
    if not ok then
        if child and type(child.free) == "function" then pcall(child.free, child) end
        require("logger").warn("OrbitUI dashboard: module build failed", entry.id, err)
        return nil
    end
    return child, def, regions, args
end

function M.tapModule(entry, def, ctx, regions, x, y)
    local ok, err = pcall(function()
        if entry.kind == "action" then
            -- Native Home owns the close/restore/navigation dance for actions.
            if ctx.on_qa_tap then ctx.on_qa_tap(entry.ref) end
        elseif entry.kind == "bookshelf" and type(def.on_tap) == "function" then
            local kit = require("lib/bookshelf_module_kit")
            local args = { entry = { id = entry.id, module = entry.ref }, surface = "orbitui_dashboard",
                refresh = ctx.refresh_fn, menu = { close = function() end, _reload = ctx.refresh_fn } }
            args.config = kit.entryConfig(args.entry)
            args.tapped_region = kit.hitRegion(regions, x, y)
            def.on_tap(args)
            local keep = def.keep_open
            if type(keep) == "function" then keep = keep(args) end
            if keep and ctx.refresh_fn then ctx.refresh_fn() end
        end
    end)
    if not ok then require("logger").warn("OrbitUI dashboard: module action failed", entry.id, err) end
end

function M.tickModule(entry, def, refresh)
    -- A hosted clock must not claim the module-global native Home timer.
    if def.wants_minute_tick or entry.kind == "simpleui" and type(def.scheduleRefresh) == "function" then
        refresh()
        if type(def.on_minute) ~= "function" then return end
    end
    if type(def.on_minute) ~= "function" then return end
    local args = { entry = { id = entry.id, module = entry.ref }, surface = "orbitui_dashboard", refresh = refresh }
    args.config = require("lib/bookshelf_module_kit").entryConfig(args.entry)
    local ok, err = pcall(def.on_minute, args)
    if not ok then require("logger").warn("OrbitUI dashboard: module tick failed", entry.id, err) end
end

local Guard
function M.moduleContainer(child, fallback, w, h, bg)
    if not Guard then
        local Clip = require("lib/bookshelf_clip_container")
        Guard = Clip:extend{}
        function Guard:paintTo(bb, x, y)
            if self.failed then
                local original = self[1]; self[1] = self.fallback
                local ok, err = pcall(Clip.paintTo, self, bb, x, y)
                self[1] = original
                if not ok then require("logger").warn("OrbitUI dashboard: fallback paint failed", err) end
                return
            end
            local ok, err = pcall(Clip.paintTo, self, bb, x, y)
            if not ok then
                self.failed = true
                require("logger").warn("OrbitUI dashboard: module paint failed", err)
                self:paintTo(bb, x, y)
            end
        end
        function Guard:handleEvent(event)
            if self.failed then return false end
            local ok, result = pcall(Clip.handleEvent, self, event)
            if not ok then
                self.failed = true
                require("logger").warn("OrbitUI dashboard: module input failed", result)
            end
            return ok and result or false
        end
        function Guard:free(full)
            if self.disposed then return end
            self.disposed = true
            if self[1] and self[1].free then pcall(self[1].free, self[1], full) end
            if self.fallback ~= self[1] and self.fallback.free then pcall(self.fallback.free, self.fallback, full) end
        end
    end
    return Guard:new{ w = w, h = h, bg = bg, pass_gestures = true, fallback = fallback, child or fallback }
end

return M
