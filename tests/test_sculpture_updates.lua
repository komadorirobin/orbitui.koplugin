package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Update = require("core/orbitui_sculpture_updates")
local real_open = io.open
local root, dir = "/slot", "/ornaments"
local source, target = root .. "/assets/ornaments/Authors/", dir .. "/Authors/"
local names = { "August Strindberg.png", "Stanislaw Lem.png" }
local files, documents, sequence, marked, modes, failure, hashes
local function clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}; for k, v in pairs(value) do copy[k] = clone(v) end; return copy
end
local function encode(value)
    sequence = sequence + 1
    local key = "json:" .. sequence; documents[key] = clone(value); return key
end
local function decode(bytes) return clone(assert(documents[bytes], "invalid JSON")) end
local function metadata() return decode(files[target .. "ornaments.json"]) end
local function write(path, bytes)
    assert(path ~= failure, "interrupted write")
    files[path] = assert(bytes, "missing source")
end
local function fixture()
    files, documents, sequence, marked, failure, hashes = {}, {}, 0, false, nil, 0
    modes = { [dir .. "/Authors"] = "directory" }
    local old, new, baseline = {}, {}, { assets = {}, documents = { ["README.txt"] = { "old README" } } }
    for _, name in ipairs(names) do
        old[name] = { info = "old " .. name, scale = 1, lift = -.01, anchor = "bottom", tap = "zoom" }
        new[name] = { info = "photo " .. name, scale = 1.02, lift = -.02, anchor = "bottom", tap = "zoom" }
        baseline.assets[#baseline.assets+1] = { file = name, old_sha256 = "old " .. name,
            new_sha256 = "new " .. name, old_info = { old[name].info },
            old_placement = { scale = 1, lift = -.01, anchor = "bottom" } }
        files[target .. name], files[source .. name] = "old " .. name, "new " .. name
    end
    old["custom.png"] = { info = "leave alone" }
    files[target .. "ornaments.json"], files[source .. "ornaments.json"] = encode(old), encode(new)
    files[root .. "/" .. Update.baseline] = encode(baseline)
    files[source .. Update.notice] = "per-file photo credits"
    files[target .. "README.txt"], files[source .. "README.txt"] = "old README", "new README"
end
package.loaded.rapidjson = { decode = decode, encode = encode }
package.loaded["libs/libkoreader-lfs"] = { symlinkattributes = function(path)
    return modes[path] or (files[path] and "file")
end }
package.loaded["core/orbitui_ota"] = { hashFile = function(path)
    hashes = hashes + 1; return assert(files[path], "missing image")
end }
package.loaded["core/orbitui_ornament_install"] = {
    installed = function(marker) H.eq(marker, Update.marker); return marked end,
    copy = function(from, to) write(to, files[from]) end,
    write = write,
    mark = function(from, marker)
        H.eq(marker, Update.marker); assert(files[from]); assert(failure ~= "marker"); marked = true
    end,
}
io.open = function(path)
    if not files[path] then return nil end
    return { read = function() return files[path] end, close = function() end }
end
local function apply() return Update.apply(root, dir) end
H.test("sculpture batch upgrades images captions placement and independent credits", function()
    fixture(); H.eq(apply(), true)
    for _, name in ipairs(names) do
        H.eq(files[target .. name], "new " .. name)
        H.eq(metadata()[name].info, "photo " .. name)
        H.eq(metadata()[name].scale, 1.02); H.eq(metadata()[name].lift, -.02)
    end
    H.eq(metadata()["custom.png"].info, "leave alone")
    H.eq(files[target .. "README.txt"], "new README")
    H.eq(files[target .. Update.notice], "per-file photo credits")
    assert(marked)
end)
H.test("custom image skips only that author and keeps its metadata", function()
    fixture(); files[target .. names[1]] = "reader art"
    apply(); H.eq(files[target .. names[1]], "reader art")
    H.eq(metadata()[names[1]].info, "old " .. names[1])
    H.eq(metadata()[names[1]].lift, -.01)
    H.eq(files[target .. names[2]], "new " .. names[2])
end)
H.test("custom captions placement and shared notices survive default image replacement", function()
    fixture(); local current = metadata()
    current[names[1]].info = "my biography"; current[names[1]].scale = .5
    current[names[2]].info = nil; current[names[2]].tap = "off"
    files[target .. "ornaments.json"] = encode(current)
    files[target .. "README.txt"] = "my documentation"
    apply(); H.eq(metadata()[names[1]].info, "my biography")
    H.eq(metadata()[names[1]].scale, .5); H.eq(metadata()[names[1]].lift, -.01)
    H.eq(metadata()[names[2]].info, nil); H.eq(metadata()[names[2]].tap, "off")
    H.eq(files[target .. "README.txt"], "my documentation")
end)
H.test("deleted or linked records images metadata and packs are not replaced", function()
    for _, kind in ipairs({ "record", "image", "link", "metadata", "pack" }) do
        fixture()
        if kind == "record" then
            local current = metadata(); current[names[1]] = nil
            files[target .. "ornaments.json"] = encode(current)
        elseif kind == "image" then files[target .. names[1]] = nil
        elseif kind == "link" then modes[target .. names[1]] = "link"
        elseif kind == "metadata" then modes[target .. "ornaments.json"] = "link"
        else modes[dir .. "/Authors"] = "link" end
        local before = files[target .. names[1]]
        apply(); H.eq(files[target .. names[1]], before)
        if kind == "record" then H.eq(metadata()[names[1]], nil) end
    end
end)
H.test("each interrupted batch stage resumes without losing already upgraded authors", function()
    for _, path in ipairs({ target .. Update.notice, target .. names[1], target .. names[2],
        target .. "ornaments.json", target .. "README.txt", "marker" }) do
        fixture(); failure = path
        H.eq(pcall(apply), false); H.eq(marked, false)
        failure = nil; apply()
        for _, name in ipairs(names) do
            H.eq(files[target .. name], "new " .. name)
            H.eq(metadata()[name].info, "photo " .. name)
        end
        assert(marked)
    end
end)
H.test("invalid source hash and caption fail before replacing that image", function()
    for _, kind in ipairs({ "hash", "caption", "json", "notice" }) do
        fixture()
        if kind == "hash" then files[source .. names[1]] = "corrupt"
        elseif kind == "caption" then
            local current = decode(files[source .. "ornaments.json"])
            current[names[1]].info = string.rep("a", 4001)
            files[source .. "ornaments.json"] = encode(current)
        elseif kind == "json" then files[source .. "ornaments.json"] = "corrupt"
        else files[source .. Update.notice] = nil end
        H.eq(pcall(apply), false); H.eq(marked, false)
        H.eq(files[target .. names[1]], "old " .. names[1])
    end
end)
H.test("fresh defaults need no rewrite and completion marker avoids later hashing", function()
    fixture()
    for _, name in ipairs({ names[1], names[2], "ornaments.json", "README.txt", Update.notice }) do
        files[target .. name] = files[source .. name]
    end
    H.eq(apply(), false); local count = hashes
    files[root .. "/" .. Update.baseline] = nil
    H.eq(apply(), false); H.eq(hashes, count)
end)
io.open = real_open
H.finish()
