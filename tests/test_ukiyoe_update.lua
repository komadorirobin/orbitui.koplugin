package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Update = require("core/orbitui_ukiyoe_update")
local real_open, real_rename, real_remove = io.open, os.rename, os.remove
local root, folder = "/slot", "/settings/bookshelf/ornaments"
local source = root .. "/assets/ornaments/Ukiyo-e Gallery/"
local target = folder .. "/Ukiyo-e Gallery/"
local marker = "/settings/orbitui/" .. Update.marker
local previous_marker = "/settings/orbitui/" .. Update.previous_marker
local files, documents, sequence, fail_rename, fail_write
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = clone(v) end
    return result
end
local function encode(value)
    sequence = sequence + 1
    local key = "json:" .. sequence
    documents[key] = clone(value)
    return key
end
local function decode(bytes) return clone(assert(documents[bytes], "invalid JSON")) end
local function fixture()
    files, documents, sequence, fail_rename, fail_write = {}, {}, 0, nil, nil
    local before = {
        ["wave.png"] = { lift = 0, scale = .95, anchor = "bottom", info = "old wave", tap = "zoom" },
        ["snow.png"] = { lift = 0, scale = .95, anchor = "bottom", info = "old snow", tap = "zoom" },
    }
    local after = clone(before)
    for _, entry in pairs(after) do entry.lift = .20; entry.info = entry.info .. " expanded" end
    local placement = {}
    for name in pairs(before) do placement[name] = { lift = .12, anchor = "bottom", scale = .95 } end
    files[root .. "/" .. Update.previous_baseline] = encode({ placement = placement,
        files = { ["README.txt"] = "v2 README.txt" } })
    local old = { ["ornaments.json"] = encode(before) }
    files[source .. "ornaments.json"] = encode(after)
    files[target .. "ornaments.json"] = old["ornaments.json"]
    for _, name in ipairs({ "provenance.json", "ATTRIBUTION.txt", "README.txt" }) do
        old[name] = "old " .. name
        files[target .. name] = old[name]
        files[source .. name] = "new " .. name
    end
    files[root .. "/" .. Update.baseline] = encode({ files = old })
    files[target .. "wave.png"] = "CUSTOM IMAGE"
    files[target .. "theme/theme.json"] = "CUSTOM THEME"
    return before, after
end
package.loaded.rapidjson = { decode = decode, encode = encode }
package.loaded.datastorage = { getSettingsDir = function() return "/settings" end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path)
    if files[path] then return "file" end
end }
package.loaded["lib/bookshelf_fs"] = { ensureDir = function() return true end }
io.open = function(path, mode)
    if mode == "rb" and not files[path] then return nil, "missing file" end
    if mode == "wb" then files[path] = "" end
    local cursor = 1
    return {
        read = function(_, count)
            if count == "*a" then return files[path] end
            if cursor > #files[path] then return nil end
            local bytes = files[path]:sub(cursor, cursor+count-1)
            cursor = cursor + #bytes
            return bytes
        end,
        write = function(self, bytes)
            if fail_write == path then return nil, "write failed" end
            files[path] = files[path] .. bytes; return self
        end,
        close = function() return true end,
    }
end
os.rename = function(from, to)
    if fail_rename == to then return nil, "rename failed" end
    files[to], files[from] = files[from], nil; return true
end
os.remove = function(path) files[path] = nil; return true end
local function apply() return Update.apply(root, folder) end
local function current() return decode(files[target .. "ornaments.json"]) end
local function v2fixture()
    local _, after = fixture()
    for _, entry in pairs(after) do entry.lift = .12 end
    files[target .. "ornaments.json"] = encode(after)
    files[target .. "README.txt"] = "v2 README.txt"
    files[previous_marker] = "already updated"
    return after
end

H.test("v1 gallery defaults gain wall clearance and sourced info without touching images or theme", function()
    local _, after = fixture()
    H.eq(apply(), true)
    for name, entry in pairs(current()) do
        H.eq(entry.lift, .20); H.eq(entry.info, after[name].info)
        H.eq(entry.scale, .95); H.eq(entry.tap, "zoom")
    end
    for _, name in ipairs({ "provenance.json", "ATTRIBUTION.txt", "README.txt" }) do
        H.eq(files[target .. name], files[source .. name])
    end
    H.eq(files[target .. "wave.png"], "CUSTOM IMAGE")
    H.eq(files[target .. "theme/theme.json"], "CUSTOM THEME")
    assert(files[marker]); H.eq(apply(), false)
end)
H.test("pack field edits and foreign entries are kept independently", function()
    local before = fixture()
    before["wave.png"].info = "My own caption"
    before["snow.png"].lift = .3
    before["other.png"] = { info = "Other pack art", lift = 0 }
    files[target .. "ornaments.json"] = encode(before)
    apply()
    H.eq(current()["wave.png"].info, "My own caption")
    H.eq(current()["wave.png"].lift, .20)
    H.eq(current()["snow.png"].lift, .3)
    H.eq(current()["snow.png"].info, "old snow expanded")
    H.eq(current()["other.png"].lift, 0)
end)
H.test("reader height anchor or size adjustments retain their old effective placement", function()
    for _, field in ipairs({ "lift", "anchor", "scale" }) do
        fixture()
        local settings = encode({ ["Ukiyo-e Gallery/wave.png"] = {
            [field] = field == "anchor" and "top" or .25, info = "Reader info" } })
        files[folder .. "/ornaments.json"] = settings
        apply()
        H.eq(current()["wave.png"].lift, 0)
        H.eq(current()["snow.png"].lift, .20)
        H.eq(files[folder .. "/ornaments.json"], settings)
    end
end)
H.test("pack anchor and size changes prevent moving a manually placed frame", function()
    for _, field in ipairs({ "anchor", "scale" }) do
        local before = fixture()
        before["wave.png"][field] = field == "anchor" and "top" or 1.5
        files[target .. "ornaments.json"] = encode(before)
        apply(); H.eq(current()["wave.png"].lift, 0)
    end
end)
H.test("removed records edited notices and deleted files are never restored", function()
    local before = fixture()
    before["wave.png"] = nil
    files[target .. "ornaments.json"] = encode(before)
    files[target .. "wave.png"] = nil
    files[target .. "README.txt"] = "my notes"
    files[target .. "ATTRIBUTION.txt"] = nil
    apply()
    H.eq(current()["wave.png"], nil); H.eq(files[target .. "wave.png"], nil)
    H.eq(files[target .. "README.txt"], "my notes"); H.eq(files[target .. "ATTRIBUTION.txt"], nil)
end)
H.test("an absent pack stays absent and a fresh install needs no metadata rewrite", function()
    fixture()
    for path in pairs(files) do if path:sub(1, #target) == target then files[path] = nil end end
    H.eq(apply(), false); assert(files[marker]); H.eq(files[target .. "ornaments.json"], nil)
    fixture()
    for _, name in ipairs({ "ornaments.json", "provenance.json", "README.txt", "ATTRIBUTION.txt" }) do
        files[target .. name] = files[source .. name]
    end
    local bytes = files[target .. "ornaments.json"]
    H.eq(apply(), false); H.eq(files[target .. "ornaments.json"], bytes)
end)
H.test("invalid pack or reader JSON is preserved and leaves the update retryable", function()
    for _, path in ipairs({ target .. "ornaments.json", folder .. "/ornaments.json" }) do
        fixture(); files[path] = "INVALID"
        H.eq(pcall(apply), false); H.eq(files[path], "INVALID"); H.eq(files[marker], nil)
    end
end)
H.test("failed atomic writes preserve old metadata and retry cleanly", function()
    for _, failure in ipairs({ "write", "rename" }) do
        fixture()
        local old = files[target .. "ornaments.json"]
        if failure == "write" then fail_write = target .. "ornaments.json.orbitui-tmp"
        else fail_rename = target .. "ornaments.json" end
        H.eq(pcall(apply), false); H.eq(files[marker], nil)
        H.eq(files[target .. "ornaments.json"], old)
        H.eq(files[target .. "ornaments.json.orbitui-tmp"], nil)
        fail_write, fail_rename = nil, nil
        H.eq(apply(), true); H.eq(current()["wave.png"].lift, .20)
    end
end)
H.test("a partial update retries without replacing edits made between startups", function()
    fixture(); fail_rename = target .. "provenance.json"
    H.eq(pcall(apply), false); H.eq(files[marker], nil)
    H.eq(current()["wave.png"].lift, .20)
    local edited = current(); edited["wave.png"].info = "Edited between starts"
    files[target .. "ornaments.json"] = encode(edited)
    fail_rename = nil; H.eq(apply(), true)
    H.eq(current()["wave.png"].info, "Edited between starts"); assert(files[marker])
end)
H.test("alpha.20 defaults rise again despite the existing v2 marker without changing info or artwork", function()
    local before = v2fixture()
    local provenance, attribution = files[target .. "provenance.json"], files[target .. "ATTRIBUTION.txt"]
    H.eq(apply(), true)
    for name, entry in pairs(current()) do
        H.eq(entry.lift, .20)
        for field, value in pairs(before[name]) do
            if field ~= "lift" then H.eq(entry[field], value) end
        end
    end
    H.eq(files[target .. "provenance.json"], provenance)
    H.eq(files[target .. "ATTRIBUTION.txt"], attribution)
    H.eq(files[target .. "README.txt"], files[source .. "README.txt"])
    H.eq(files[target .. "wave.png"], "CUSTOM IMAGE")
    H.eq(files[target .. "theme/theme.json"], "CUSTOM THEME")
    H.eq(files[previous_marker], "already updated")
    assert(files[marker]); H.eq(apply(), false)
end)
H.test("alpha.20 reader positioning and edited pack positions keep their exact effective height", function()
    for _, field in ipairs({ "lift", "anchor", "scale" }) do
        local before = v2fixture()
        local settings = encode({ ["Ukiyo-e Gallery/wave.png"] = {
            [field] = field == "anchor" and "top" or 0 } })
        files[folder .. "/ornaments.json"] = settings
        before["snow.png"][field] = field == "anchor" and "top" or .33
        files[target .. "ornaments.json"] = encode(before)
        apply()
        H.eq(current()["wave.png"].lift, .12)
        H.eq(current()["snow.png"].lift, before["snow.png"].lift)
        H.eq(files[folder .. "/ornaments.json"], settings)
    end
end)
H.test("v3 does not replay v2 or resurrect deleted alpha.20 records notices or packs", function()
    local before = v2fixture()
    before["wave.png"].lift, before["wave.png"].info = 0, "old wave"
    before["snow.png"] = nil
    before["foreign.png"] = { lift = .12, anchor = "bottom", scale = .95 }
    files[target .. "ornaments.json"] = encode(before)
    files[target .. "README.txt"] = "my notes"
    files[target .. "ATTRIBUTION.txt"] = nil
    H.eq(apply(), false)
    H.eq(current()["wave.png"].lift, 0); H.eq(current()["wave.png"].info, "old wave")
    H.eq(current()["snow.png"], nil); H.eq(current()["foreign.png"].lift, .12)
    H.eq(files[target .. "README.txt"], "my notes"); H.eq(files[target .. "ATTRIBUTION.txt"], nil)
    v2fixture()
    for path in pairs(files) do if path:sub(1, #target) == target then files[path] = nil end end
    H.eq(apply(), false); assert(files[marker]); H.eq(files[target .. "ornaments.json"], nil)
end)
H.test("v3 rejects corrupt metadata and retries failed atomic writes without losing overrides", function()
    for _, path in ipairs({ target .. "ornaments.json", folder .. "/ornaments.json" }) do
        v2fixture(); files[path] = "INVALID"
        H.eq(pcall(apply), false); H.eq(files[path], "INVALID"); H.eq(files[marker], nil)
    end
    for _, failure in ipairs({ "write", "rename" }) do
        v2fixture()
        local before = files[target .. "ornaments.json"]
        if failure == "write" then fail_write = target .. "ornaments.json.orbitui-tmp"
        else fail_rename = target .. "ornaments.json" end
        H.eq(pcall(apply), false); H.eq(files[marker], nil)
        H.eq(files[target .. "ornaments.json"], before)
        H.eq(files[target .. "ornaments.json.orbitui-tmp"], nil)
        fail_write, fail_rename = nil, nil
        H.eq(apply(), true); H.eq(current()["wave.png"].lift, .20)
    end
end)
H.test("v3 retries interrupted notices or marker writes without moving later manual edits", function()
    for _, path in ipairs({ target .. "README.txt", marker }) do
        v2fixture(); fail_rename = path
        H.eq(pcall(apply), false); H.eq(files[marker], nil)
        H.eq(current()["wave.png"].lift, .20)
        local edited = current(); edited["wave.png"].lift = .35
        files[target .. "ornaments.json"] = encode(edited)
        fail_rename = nil; apply()
        H.eq(current()["wave.png"].lift, .35); assert(files[marker])
    end
end)
io.open, os.rename, os.remove = real_open, real_rename, real_remove

H.test("actual native placement keeps portrait and wide gallery frames clear of both planks", function()
    local function load_method(path, name, env)
        local f = assert(io.open(path)); local text = f:read("*a"); f:close()
        local body = assert(text:match("\n(function " .. name:gsub("%.", "%%.") .. "%([^\n]*\n.-\nend)\n"))
        local chunk
        if setfenv then chunk = assert(loadstring(body)); setfenv(chunk, env)
        else chunk = assert(load(body, name, "t", env)) end
        chunk()
    end
    local orn, shelf = "components/bookshelf/lib/bookshelf_ornaments.lua", "components/bookshelf/lib/bookshelf_spine_shelf.lua"
    local f = assert(io.open(shelf)); local source = f:read("*a"); f:close()
    local function constant(name)
        return assert(tonumber(source:match("SpineShelf%." .. name .. "%s*=%s*([%d.]+)")))
    end
    local env = setmetatable({ M = { HEIGHT_FRAC = .8 }, SpineShelf = {
        PLANK_INSET_UNITS = constant("PLANK_INSET_UNITS"),
        PLANK_DEPTH_FACTOR = constant("PLANK_DEPTH_FACTOR"),
    }, SpineLayout = dofile("components/bookshelf/lib/bookshelf_spine_layout.lua"),
        Screen = {} }, { __index = _G })
    load_method(orn, "M.sizeFor", env); load_method(orn, "M.place", env)
    for _, name in ipairs({ "ornamentY", "plankUnit", "plankFace", "plankInset", "plankSurface" }) do
        load_method(shelf, "SpineShelf." .. name, env)
    end
    local S = env.SpineShelf
    local old_overlap = false
    for _, dpi in ipairs({ 1, 1.5, 2, 3 }) do
        env.Screen.scaleBySize = function(_, n) return math.floor(n * dpi + .5) end
        for _, row_dp in ipairs({ 80, 200, 350, 700 }) do
            local row_h = math.floor(row_dp * dpi)
            local stand_h = row_h - S.plankFace(row_h) - S.plankInset(S.plankUnit(row_h))
            -- ShelfPlank:paintTo paints the back edge here, not at stand_h.
            local back_y = row_h - S.plankFace(row_h) - S.plankSurface(row_h)
            for _, aspect in ipairs({ .4, .7, 1, 1.5, 2 }) do
                for _, width in ipairs({ 30, 120, 600 }) do
                    local entry = { aspect = aspect, scale = .95,
                        lift = .20, anchor = "bottom", overhang = 0 }
                    local frame = env.M.place(entry, width * dpi, stand_h, {}, 1)
                    local y = S.ornamentY(frame, stand_h, {})
                    assert(y >= 0, "frame crosses the upper shelf")
                    assert(back_y - (y + frame.h) >= math.floor(stand_h * .05),
                        "frame must clear the visible plank surface, not just its foot line")
                    frame.offset = .12
                    if S.ornamentY(frame, stand_h, {}) + frame.h >= back_y then old_overlap = true end
                end
            end
        end
    end
    assert(old_overlap, "regression fixture must reproduce alpha.20's visible overlap")
end)
H.finish()
