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

return M
