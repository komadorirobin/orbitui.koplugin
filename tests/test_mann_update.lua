package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
for _, module in ipairs({ "core/orbitui_mann_update", "core/orbitui_hemingway_update" }) do
local Update = require(module)
local real_open, real_rename, real_remove = io.open, os.rename, os.remove
local root, dir = "/slot", "/settings/bookshelf/ornaments"
local source, target = root .. "/assets/ornaments/" .. Update.pack .. "/", dir .. "/" .. Update.pack .. "/"
local marker = "/settings/orbitui/" .. Update.marker
local files, documents, sequence, failure, hashes, modes
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = clone(v) end
    return result
end
local function encode(value)
    sequence = sequence + 1
    local key = "json:" .. sequence; documents[key] = clone(value); return key
end
local function decode(bytes) return clone(assert(documents[bytes], "invalid JSON")) end
local function current() return decode(files[target .. "ornaments.json"]) end
local function fixture()
    files, documents, sequence, failure, hashes = {}, {}, 0, nil, 0
    modes = { [dir .. "/" .. Update.pack] = "directory" }
    local old = { info = "old short caption", scale = .996, anchor = "bottom", lift = -.01,
        night = "off", mirror = "off", tap = "zoom", pad = .035 }
    local new = clone(old); new.info = "Mann biography / Seitz photo credits"
    new.scale, new.lift = 1, -.0235
    files[target .. "ornaments.json"] = encode({ [Update.file] = old, ["other.png"] = { info = "untouched" } })
    files[source .. "ornaments.json"] = encode({ [Update.file] = new })
    files[target .. Update.file], files[source .. Update.file] = "old image", "new image"
    files[root .. "/" .. Update.baseline] = encode({
        old_sha256 = { "old image", "local AI image" }, new_sha256 = "new image",
        old_info = { "old short caption", "old biography with ivory credits", "local AI credits" },
        old_placements = { { scale = .996, anchor = "bottom", lift = -.01 },
            { scale = .996, anchor = "bottom", lift = -.018 } },
        documents = { ["README.txt"] = { "old README", "unpublished README" },
            ["ATTRIBUTION.txt"] = { "old credits" }, ["prompts.json"] = { "old prompts" },
            [Update.notice] = { "old AI notice" } },
    })
    for _, pair in ipairs({ {"README.txt", "README"}, {"ATTRIBUTION.txt", "credits"}, {"prompts.json", "prompts"} }) do
        files[target .. pair[1]], files[source .. pair[1]] = "old " .. pair[2], "new " .. pair[2]
    end
    files[source .. Update.notice] = "licensed photo notice"
    files[dir .. "/ornaments.json"] = "native reader overrides"
    files[target .. "other.png"] = "other artwork"
end
package.loaded.rapidjson = { decode = decode, encode = encode }
package.loaded.datastorage = { getSettingsDir = function() return "/settings" end }
package.loaded["libs/libkoreader-lfs"] = {
    attributes = function(path) if files[path] then return "file" end end,
    symlinkattributes = function(path) return modes[path] or (files[path] and "file") end,
}
package.loaded["lib/bookshelf_fs"] = { ensureDir = function() return true end }
package.loaded["core/orbitui_ota"] = { hashFile = function(path)
    hashes = hashes + 1; return assert(files[path], "missing hash input")
end }
io.open = function(path, mode)
    if mode == "rb" and not files[path] then return nil, "missing file" end
    if mode == "wb" then files[path] = "" end
    local cursor = 1
    return {
        read = function(_, count)
            if count == "*a" then return files[path] end
            if cursor > #files[path] then return nil end
            local bytes = files[path]:sub(cursor, cursor+count-1); cursor = cursor + #bytes; return bytes
        end,
        write = function(self, bytes) files[path] = files[path] .. bytes; return self end,
        close = function() return true end,
    }
end
os.rename = function(from, to)
    if failure == to then return nil, "write interrupted" end
    files[to], files[from] = files[from], nil; return true
end
os.remove = function(path) files[path] = nil; return true end
local function apply() return Update.apply(root, dir) end

H.test("old Mann image captions default base offset and credits upgrade together", function()
    for _, caption in ipairs({ "old short caption", "old biography with ivory credits" }) do
        fixture(); local metadata = current(); metadata[Update.file].info = caption
        files[target .. "ornaments.json"] = encode(metadata)
        H.eq(apply(), true)
        H.eq(files[target .. Update.file], "new image")
        H.eq(current()[Update.file].info, "Mann biography / Seitz photo credits")
        H.eq(current()[Update.file].lift, -.0235)
        H.eq(current()[Update.file].scale, 1)
        H.eq(files[target .. "ATTRIBUTION.txt"], "new credits")
        H.eq(files[target .. "prompts.json"], "new prompts")
        H.eq(files[target .. "README.txt"], "new README")
        H.eq(files[target .. Update.notice], "licensed photo notice")
        H.eq(current()["other.png"].info, "untouched")
        H.eq(files[target .. "other.png"], "other artwork")
        H.eq(files[dir .. "/ornaments.json"], "native reader overrides")
        assert(files[marker])
    end
end)
H.test("local AI image and notice upgrade despite the completed v1 marker", function()
    fixture()
    files["/settings/orbitui/ornament-mann-seitz-v1.updated"] = "v1 complete"
    files[target .. Update.file] = "local AI image"
    files[target .. Update.notice] = "old AI notice"
    local metadata = current()
    metadata[Update.file].info, metadata[Update.file].lift = "local AI credits", -.018
    files[target .. "ornaments.json"] = encode(metadata)
    H.eq(apply(), true)
    H.eq(files[target .. Update.file], "new image")
    H.eq(files[target .. Update.notice], "licensed photo notice")
    H.eq(current()[Update.file].info, "Mann biography / Seitz photo credits")
    H.eq(current()[Update.file].scale, 1)
    H.eq(current()[Update.file].lift, -.0235)
    H.eq(files["/settings/orbitui/ornament-mann-seitz-v1.updated"], "v1 complete")
    assert(files[marker])
end)
H.test("interrupted local v1 replacement finishes its credits on retry", function()
    fixture()
    files[target .. Update.file] = "local AI image"
    files[target .. Update.notice] = "old AI notice"
    failure = target .. Update.notice
    H.eq(pcall(apply), false)
    H.eq(files[marker], nil)
    failure = nil
    apply()
    H.eq(files[target .. Update.file], "new image")
    H.eq(files[target .. Update.notice], "licensed photo notice")
    assert(files[marker])
end)
H.test("alpha22 completion markers do not block new artwork migrations", function()
    fixture()
    files["/settings/orbitui/ornament-mann-photo-v2.updated"] = "complete"
    files["/settings/orbitui/ornament-authors-ii-v1.installed"] = "complete"
    H.eq(apply(), true)
    H.eq(files[target .. Update.file], "new image")
    H.eq(files["/settings/orbitui/ornament-mann-photo-v2.updated"], "complete")
    H.eq(files["/settings/orbitui/ornament-authors-ii-v1.installed"], "complete")
    assert(files[marker])
end)
H.test("custom artwork retains its captions placements and notices", function()
    fixture(); files[target .. Update.file] = "custom artwork"
    local before = clone(files)
    H.eq(apply(), false)
    for path, bytes in pairs(before) do H.eq(files[path], bytes, path) end
    H.eq(files[target .. Update.notice], nil)
    assert(files[marker])
end)
H.test("custom or blank captions and all custom placement values are preserved", function()
    for _, value in ipairs({ "my caption", "", false }) do
        fixture(); local metadata = current()
        metadata[Update.file] = { info = value or nil, lift = .3, scale = .5, anchor = "top",
            tap = "off", enabled = false, night = "on", extra = "extension" }
        files[target .. "ornaments.json"] = encode(metadata)
        files[target .. "ATTRIBUTION.txt"] = "my credits"
        files[target .. "prompts.json"] = "my provenance"
        apply()
        for key, v in pairs(metadata[Update.file]) do H.eq(current()[Update.file][key], v) end
        H.eq(current()[Update.file].info, value or nil)
        H.eq(files[target .. "ATTRIBUTION.txt"], "my credits")
        H.eq(files[target .. "prompts.json"], "my provenance")
        H.eq(files[target .. Update.notice], "licensed photo notice")
    end
end)
H.test("a custom scale or anchor prevents changing even the old default lift", function()
    for key, value in pairs({ scale = .5, anchor = "top" }) do
        fixture(); local metadata = current(); metadata[Update.file][key] = value
        files[target .. "ornaments.json"] = encode(metadata)
        apply(); H.eq(current()[Update.file].lift, -.01)
    end
end)
H.test("deleted images metadata records and packs are not recreated", function()
    for _, kind in ipairs({ "image", "metadata", "record", "pack" }) do
        fixture()
        if kind == "record" then
            local metadata = current(); metadata[Update.file] = nil
            files[target .. "ornaments.json"] = encode(metadata)
        elseif kind == "pack" then
            for path in pairs(files) do if path:sub(1, #target) == target then files[path] = nil end end
        else files[target .. (kind == "image" and Update.file or "ornaments.json")] = nil end
        local before = clone(files)
        H.eq(apply(), false)
        for path, bytes in pairs(before) do H.eq(files[path], bytes) end
        for path in pairs(files) do if path ~= marker then assert(before[path]) end end
    end
end)
H.test("completed marker avoids hashing or opening any artwork on later starts", function()
    fixture(); apply(); local count = hashes
    files[root .. "/" .. Update.baseline] = nil
    files[source .. Update.file] = nil
    files[target .. Update.file] = "later custom image"
    H.eq(apply(), false); H.eq(hashes, count)
    H.eq(files[target .. Update.file], "later custom image")
end)
H.test("freshly seeded current defaults are not rewritten", function()
    fixture()
    for _, name in ipairs({ Update.file, "ornaments.json", "README.txt", "ATTRIBUTION.txt", "prompts.json", Update.notice }) do
        files[target .. name] = files[source .. name]
    end
    local before = clone(files); H.eq(apply(), false)
    for path, bytes in pairs(before) do H.eq(files[path], bytes) end
end)
H.test("wrong source checksum invalid JSON or oversized caption fail before image copy", function()
    for _, kind in ipairs({ "hash", "json", "caption", "notice" }) do
        fixture()
        if kind == "hash" then files[source .. Update.file] = "corrupt image"
        elseif kind == "json" then files[source .. "ornaments.json"] = "invalid"
        elseif kind == "caption" then
            files[source .. "ornaments.json"] = encode({ [Update.file] = { info = string.rep("x", 4001) } })
        else files[source .. Update.notice] = nil end
        H.eq(pcall(apply), false); H.eq(files[marker], nil)
        H.eq(files[target .. Update.file], "old image")
    end
end)
H.test("interrupted notice image metadata documentation and marker writes retry safely", function()
    for _, name in ipairs({ Update.notice, Update.file, "ornaments.json", "ATTRIBUTION.txt", "prompts.json", "README.txt", "marker" }) do
        fixture(); failure = name == "marker" and marker or target .. name
        H.eq(pcall(apply), false); H.eq(files[marker], nil)
        H.eq(files[failure .. ".orbitui-tmp"], nil)
        if name == Update.file then H.eq(files[target .. Update.file], "old image") end
        failure = nil; apply()
        H.eq(files[target .. Update.file], "new image")
        H.eq(current()[Update.file].info, "Mann biography / Seitz photo credits")
        assert(files[marker]); H.eq(apply(), false)
    end
end)
H.test("edits made after an interrupted upgrade survive its retry", function()
    fixture(); failure = marker; H.eq(pcall(apply), false)
    local metadata = current(); metadata[Update.file].info = "revised notes"
    metadata[Update.file].lift = .4
    files[target .. "ornaments.json"] = encode(metadata)
    files[target .. Update.notice] = "annotated notice"
    failure = nil; apply()
    H.eq(current()[Update.file].info, "revised notes")
    H.eq(current()[Update.file].lift, .4)
    H.eq(files[target .. Update.notice], "annotated notice")
end)
H.test("linked pack image or metadata is never followed or replaced", function()
    for _, path in ipairs({ dir .. "/" .. Update.pack, target .. Update.file, target .. "ornaments.json" }) do
        fixture(); modes[path] = "link"
        local before = clone(files)
        H.eq(apply(), false); H.eq(hashes, 0)
        for name, bytes in pairs(before) do H.eq(files[name], bytes, name) end
    end
end)
H.test("linked shared notices remain untouched while the known image is upgraded", function()
    fixture()
    for _, name in ipairs({ "README.txt", "ATTRIBUTION.txt", "prompts.json", Update.notice }) do
        modes[target .. name] = "link"
    end
    H.eq(apply(), true)
    H.eq(files[target .. Update.file], "new image")
    H.eq(files[target .. "README.txt"], "old README")
    H.eq(files[target .. "ATTRIBUTION.txt"], "old credits")
    H.eq(files[target .. "prompts.json"], "old prompts")
    H.eq(files[target .. Update.notice], nil)
end)
H.test("UTF8 caption limit counts bytes and malformed entries do not overwrite artwork", function()
    for _, caption in ipairs({ false, "", string.rep("\\195\\165", 2001) }) do
        fixture()
        files[source .. "ornaments.json"] = encode({ [Update.file] = { info = caption } })
        H.eq(pcall(apply), false)
        H.eq(files[marker], nil)
        H.eq(files[target .. Update.file], "old image")
    end
end)
io.open, os.rename, os.remove = real_open, real_rename, real_remove
end
H.finish()
