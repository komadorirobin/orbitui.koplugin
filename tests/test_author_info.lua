package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Update = require("core/orbitui_author_info")
local real_open, real_rename, real_remove = io.open, os.rename, os.remove
local root, folder = "/slot", "/settings/bookshelf/ornaments"
local files, documents, sequence, fail_rename, fail_write, fail_close
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
local function source(pack) return root .. "/assets/ornaments/" .. pack.name .. "/" end
local function target(pack) return folder .. "/" .. pack.name .. "/" end
local function marker(pack) return "/settings/orbitui/" .. pack.marker end
local function current(pack) return decode(files[target(pack) .. "ornaments.json"]) end
local function fixture()
    files, documents, sequence = {}, {}, 0
    fail_rename, fail_write, fail_close = nil, nil, nil
    local baseline = { packs = {} }
    for _, pack in ipairs(Update.packs) do
        local before = {
            ["one.png"] = { info = "original image credits", tap = "zoom", lift = -.02, scale = 1 },
            ["two.png"] = { info = "other image credits", tap = "zoom", anchor = "bottom" },
        }
        baseline.packs[pack.name] = { metadata = before, readme = "old README" }
        files[target(pack) .. "ornaments.json"] = encode(before)
        local after = clone(before)
        for _, entry in pairs(after) do entry.info = "Biography\n\n" .. entry.info end
        files[source(pack) .. "ornaments.json"] = encode(after)
        files[target(pack) .. "README.txt"] = "old README"
        files[source(pack) .. "README.txt"] = "new README"
        files[target(pack) .. "one.png"] = "CUSTOM IMAGE"
        files[target(pack) .. "ATTRIBUTION.txt"] = "original licences"
        files[target(pack) .. "prompts.json"] = "original prompts"
    end
    files[root .. "/" .. Update.baseline] = encode(baseline)
    files[folder .. "/ornaments.json"] = "CUSTOM READER OVERRIDES"
    files[folder .. "/Modernists-Preview/ornaments.json"] = "TRIAL PACK"
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
        close = function()
            if fail_close == path then return nil, "close failed" end
            return true
        end,
    }
end
os.rename = function(from, to)
    if fail_rename == to then return nil, "rename failed" end
    files[to], files[from] = files[from], nil; return true
end
os.remove = function(path) files[path] = nil; return true end
local function apply() return Update.apply(root, folder) end
local first, second = Update.packs[1], Update.packs[2]

H.test("author defaults gain offline biographies while all other fields and files stay intact", function()
    fixture()
    local before = clone(files)
    H.eq(apply(), true)
    for _, pack in ipairs(Update.packs) do
        local prior, after = decode(before[target(pack) .. "ornaments.json"]), current(pack)
        for name, entry in pairs(prior) do
            H.eq(after[name].info, "Biography\n\n" .. entry.info)
            for field, value in pairs(entry) do
                if field ~= "info" then H.eq(after[name][field], value) end
            end
        end
        H.eq(files[target(pack) .. "README.txt"], "new README")
        assert(files[marker(pack)])
        before[target(pack) .. "ornaments.json"] = files[target(pack) .. "ornaments.json"]
        before[target(pack) .. "README.txt"] = "new README"
    end
    for path, bytes in pairs(before) do H.eq(files[path], bytes, path) end
    H.eq(apply(), false)
end)
H.test("completed info markers avoid loading or writing metadata on later startups", function()
    fixture(); apply()
    files[root .. "/" .. Update.baseline] = nil
    for _, pack in ipairs(Update.packs) do
        files[target(pack) .. "ornaments.json"] = "LATER USER EDIT"
        files[source(pack) .. "ornaments.json"] = nil
    end
    H.eq(apply(), false)
    H.eq(files[target(first) .. "ornaments.json"], "LATER USER EDIT")
end)
H.test("custom captions including blank and deleted info are not overwritten", function()
    for _, value in ipairs({ "My author notes", "", false }) do
        fixture()
        local prior = current(first)
        prior["one.png"].info = value or nil
        files[target(first) .. "ornaments.json"] = encode(prior)
        apply()
        H.eq(current(first)["one.png"].info, value or nil)
        H.eq(current(first)["two.png"].info, "Biography\n\nother image credits")
    end
end)
H.test("generic biography migration leaves replaced art to artwork-aware upgrades", function()
    for _, name in ipairs({ "Franz Kafka.png", "Thomas Mann.png", "August Strindberg.png",
        "Knut Hamsun.png", "Fyodor Dostoevsky.png", "Dylan Thomas.png",
        "Stanislaw Lem.png", "Robert Musil.png" }) do
        fixture()
        local prior = current(second)
        prior[name] = { info = "old artwork caption" }
        files[target(second) .. "ornaments.json"] = encode(prior)
        local base = decode(files[root .. "/" .. Update.baseline])
        base.packs.Authors.metadata[name] = clone(prior[name])
        files[root .. "/" .. Update.baseline] = encode(base)
        local new = decode(files[source(second) .. "ornaments.json"])
        new[name] = { info = "new artwork biography and credits" }
        files[source(second) .. "ornaments.json"] = encode(new)
        apply()
        H.eq(current(second)[name].info, "old artwork caption")
    end
end)
H.test("caption-only changes preserve custom placement taps disables and foreign records", function()
    fixture()
    local prior = current(first)
    prior["one.png"] = { info = prior["one.png"].info, tap = "off", lift = .3,
        scale = .6, anchor = "top", enabled = false, night = "on", custom = "future field" }
    prior["foreign.png"] = { info = "my art" }
    files[target(first) .. "ornaments.json"] = encode(prior)
    apply()
    for key, value in pairs(prior["one.png"]) do
        if key ~= "info" then H.eq(current(first)["one.png"][key], value) end
    end
    H.eq(current(first)["foreign.png"].info, "my art")
    H.eq(files[folder .. "/ornaments.json"], "CUSTOM READER OVERRIDES")
end)
H.test("retired Lispector keeps its old metadata without requiring a bundled replacement", function()
    fixture()
    local prior = current(second)
    prior["Clarice Lispector.png"] = { info = "old Lispector caption", lift = .3 }
    files[target(second) .. "ornaments.json"] = encode(prior)
    local base = decode(files[root .. "/" .. Update.baseline])
    base.packs.Authors.metadata["Clarice Lispector.png"] = clone(prior["Clarice Lispector.png"])
    files[root .. "/" .. Update.baseline] = encode(base)
    H.eq(apply(), true)
    H.eq(current(second)["Clarice Lispector.png"].info, "old Lispector caption")
    H.eq(current(second)["Clarice Lispector.png"].lift, .3)
    H.eq(current(second)["one.png"].info, "Biography\n\noriginal image credits")
end)
H.test("removed records edited notices and deleted files stay removed or edited", function()
    fixture()
    local prior = current(first); prior["one.png"] = nil
    files[target(first) .. "ornaments.json"] = encode(prior)
    files[target(first) .. "one.png"] = nil
    files[target(first) .. "README.txt"] = "my notes"
    files[target(second) .. "README.txt"] = nil
    apply()
    H.eq(current(first)["one.png"], nil)
    H.eq(files[target(first) .. "one.png"], nil)
    H.eq(files[target(first) .. "README.txt"], "my notes")
    H.eq(files[target(second) .. "README.txt"], nil)
end)
H.test("absent packs stay absent and freshly seeded packs need no rewrite", function()
    fixture()
    for path in pairs(files) do
        if path:sub(1, #target(first)) == target(first) then files[path] = nil end
    end
    apply(); assert(files[marker(first)])
    H.eq(files[target(first) .. "ornaments.json"], nil)
    fixture()
    for _, pack in ipairs(Update.packs) do
        for _, name in ipairs({ "README.txt", "ornaments.json" }) do
            files[target(pack) .. name] = files[source(pack) .. name]
        end
    end
    local bytes = files[target(first) .. "ornaments.json"]
    H.eq(apply(), false); H.eq(files[target(first) .. "ornaments.json"], bytes)
end)
H.test("invalid JSON leaves existing metadata unchanged and the update retryable", function()
    for _, path in ipairs({ root .. "/" .. Update.baseline,
        source(first) .. "ornaments.json", target(first) .. "ornaments.json" }) do
        fixture(); files[path] = "INVALID"
        local before = files[target(first) .. "ornaments.json"]
        H.eq(pcall(apply), false); H.eq(files[path], "INVALID")
        H.eq(files[target(first) .. "ornaments.json"], before)
        H.eq(files[marker(first)], nil)
    end
end)
H.test("malformed or oversized UTF8 bundled captions fail before replacing the old metadata", function()
    for _, value in ipairs({ false, "", string.rep("\195\165", 2001) }) do
        fixture()
        local new = decode(files[source(first) .. "ornaments.json"])
        new["one.png"].info = value
        files[source(first) .. "ornaments.json"] = encode(new)
        local before = files[target(first) .. "ornaments.json"]
        H.eq(pcall(apply), false)
        H.eq(files[target(first) .. "ornaments.json"], before)
        H.eq(files[marker(first)], nil)
    end
end)
H.test("failed atomic writes close or rename preserve metadata and retry without leftovers", function()
    for _, failure in ipairs({ "write", "close", "rename" }) do
        fixture()
        local path = target(first) .. "ornaments.json"
        local before = files[path]
        if failure == "write" then fail_write = path .. ".orbitui-tmp"
        elseif failure == "close" then fail_close = path .. ".orbitui-tmp"
        else fail_rename = path end
        H.eq(pcall(apply), false); H.eq(files[marker(first)], nil)
        H.eq(files[path], before); H.eq(files[path .. ".orbitui-tmp"], nil)
        fail_write, fail_close, fail_rename = nil, nil, nil
        H.eq(apply(), true); assert(files[marker(first)])
    end
end)
H.test("an interrupted second pack retains the first pack marker and subsequent reader edits", function()
    fixture(); fail_rename = target(second) .. "ornaments.json"
    H.eq(pcall(apply), false)
    assert(files[marker(first)]); H.eq(files[marker(second)], nil)
    files[target(first) .. "ornaments.json"] = "LATER READER EDIT"
    fail_rename = nil
    H.eq(apply(), true)
    H.eq(files[target(first) .. "ornaments.json"], "LATER READER EDIT")
    assert(files[marker(second)])
end)
H.test("interrupted README or marker writes retry safely after an intervening caption edit", function()
    for _, path in ipairs({ target(first) .. "README.txt", marker(first) }) do
        fixture(); fail_rename = path
        H.eq(pcall(apply), false); H.eq(files[marker(first)], nil)
        local prior = current(first)
        H.eq(prior["one.png"].info, "Biography\n\noriginal image credits")
        prior["one.png"].info = "my revised bio"
        files[target(first) .. "ornaments.json"] = encode(prior)
        fail_rename = nil; apply()
        H.eq(current(first)["one.png"].info, "my revised bio")
        assert(files[marker(first)])
    end
end)
io.open, os.rename, os.remove = real_open, real_rename, real_remove

H.test("author startup always runs retirement between artwork and caption updates", function()
    local Authors = require("core/orbitui_author_ornaments")
    for _, seeded in ipairs({ true, false }) do
        for _, updated in ipairs({ true, false }) do
            for _, retired in ipairs({ true, false }) do
                for _, mann in ipairs({ true, false }) do
                  for _, sculptures in ipairs({ true, false }) do
                   for _, hemingway in ipairs({ true, false }) do
                    local called = {}
                    package.loaded["core/orbitui_kafka_update"] = { apply = function(r, dir)
                        H.eq(r, root); H.eq(dir, folder)
                        called[#called+1] = "artwork"; return false
                    end }
                    package.loaded["core/orbitui_lispector_retirement"] = { apply = function(r, dir)
                        H.eq(r, root); H.eq(dir, folder)
                        called[#called+1] = "retire"; return retired
                    end }
                    package.loaded["core/orbitui_mann_update"] = { apply = function(r, dir)
                        H.eq(r, root); H.eq(dir, folder)
                        called[#called+1] = "mann"; return mann
                    end }
                    package.loaded["core/orbitui_sculpture_updates"] = { apply = function(r, dir)
                        H.eq(r, root); H.eq(dir, folder)
                        called[#called+1] = "sculptures"; return sculptures
                    end }
                    package.loaded["core/orbitui_hemingway_update"] = { apply = function(r, dir)
                        H.eq(r, root); H.eq(dir, folder)
                        called[#called+1] = "hemingway"; return hemingway
                    end }
                    package.loaded["core/orbitui_ornament_install"] = { seed = function(r, dir, packs)
                        H.eq(r, root); H.eq(dir, folder); H.eq(packs, Authors.packs)
                        called[#called+1] = "seed"; return seeded
                    end }
                    package.loaded["core/orbitui_author_info"] = { apply = function(r, dir)
                        H.eq(r, root); H.eq(dir, folder)
                        called[#called+1] = "info"; return updated
                    end }
                    H.eq(Authors.seed(root, folder), seeded or updated or retired or mann or sculptures or hemingway)
                    H.eq(table.concat(called, ","), "seed,artwork,mann,hemingway,sculptures,retire,info")
                   end
                  end
                end
            end
        end
    end
end)
H.finish()
