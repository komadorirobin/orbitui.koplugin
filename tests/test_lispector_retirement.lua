package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Update = require("core/orbitui_lispector_retirement")
local Authors = require("core/orbitui_author_ornaments")
local root, dir = "/slot", "/settings/bookshelf/ornaments"
local folder = dir .. "/Authors"
local path = folder .. "/" .. Update.file
local remove = os.remove
local files, modes, marked, hashes, removals, failure
local function fixture()
    files = {
        [path] = Update.sha256,
        [folder .. "/ornaments.json"] = "custom captions and placement",
        [dir .. "/ornaments.json"] = "native reader overrides",
        [folder .. "/Franz Kafka.png"] = "Kafka",
        [folder .. "/README.txt"] = "annotated README",
        [folder .. "/ATTRIBUTION.txt"] = "annotated credits",
        [folder .. "/prompts.json"] = "annotated prompts",
        [dir .. "/My portraits/Clarice Lispector.png"] = Update.sha256,
    }
    modes = { [folder] = "directory" }
    marked, hashes, removals, failure = false, 0, 0, nil
end
package.loaded["core/orbitui_ornament_install"] = {
    installed = function(marker) H.eq(marker, Update.marker); return marked end,
    mark = function(source, marker)
        H.eq(source, root .. "/assets/ornaments/Authors/README.txt")
        H.eq(marker, Update.marker)
        assert(failure ~= "marker", "marker write failed")
        marked = true
    end,
}
package.loaded["libs/libkoreader-lfs"] = { symlinkattributes = function(p)
    return modes[p] or (files[p] and "file")
end }
package.loaded["core/orbitui_ota"] = { hashFile = function(p)
    H.eq(p, path); hashes = hashes + 1
    assert(failure ~= "hash", "image read failed")
    return assert(files[p])
end }
os.remove = function(p)
    H.eq(p, path); removals = removals + 1
    if failure == "remove" then return nil, "read-only filesystem" end
    files[p] = nil; return true
end
local function apply() return Update.apply(root, dir) end

H.test("only the exact old default is removed; metadata settings and other packs survive", function()
    fixture()
    local before = {}; for p, bytes in pairs(files) do before[p] = bytes end
    H.eq(apply(), true); H.eq(files[path], nil); H.eq(removals, 1)
    for p, bytes in pairs(before) do if p ~= path then H.eq(files[p], bytes, p) end end
    H.eq(marked, true)
end)
H.test("a custom replacement is retained byte for byte and only checked once", function()
    fixture(); files[path] = "custom portrait"
    H.eq(apply(), false); H.eq(files[path], "custom portrait")
    H.eq(removals, 0); H.eq(hashes, 1)
    H.eq(apply(), false); H.eq(hashes, 1)
end)
H.test("missing images and deleted packs are not recreated or hashed", function()
    for _, missing in ipairs({ "image", "pack" }) do
        fixture(); files[path] = nil
        if missing == "pack" then modes[folder] = nil end
        H.eq(apply(), false); H.eq(files[path], nil)
        H.eq(hashes, 0); H.eq(removals, 0); H.eq(marked, true)
    end
end)
H.test("removal does not depend on readable or present ornament metadata", function()
    fixture(); files[folder .. "/ornaments.json"] = nil
    H.eq(apply(), true); H.eq(files[path], nil)
    H.eq(files[folder .. "/ornaments.json"], nil)
end)
H.test("symbolic links and non-regular files are never followed or deleted", function()
    for _, p in ipairs({ folder, path }) do
        for _, mode in ipairs({ "link", "directory", "socket" }) do
            if not (p == folder and mode == "directory") then
                fixture(); modes[p] = mode
                H.eq(apply(), false); H.eq(files[path], Update.sha256)
                H.eq(hashes, 0); H.eq(removals, 0)
            end
        end
    end
end)
H.test("hash and deletion failures leave the migration pending for a safe retry", function()
    for _, kind in ipairs({ "hash", "remove" }) do
        fixture(); failure = kind
        H.eq(pcall(apply), false); H.eq(marked, false)
        H.eq(files[path], Update.sha256)
        failure = nil
        H.eq(apply(), true); H.eq(files[path], nil); H.eq(marked, true)
    end
end)
H.test("interrupted marker writes retry without restoring deleted artwork", function()
    fixture(); failure = "marker"
    H.eq(pcall(apply), false); H.eq(marked, false); H.eq(files[path], nil)
    failure = nil
    H.eq(apply(), false); H.eq(hashes, 1); H.eq(removals, 1); H.eq(marked, true)
end)
H.test("a custom image added after an interrupted retirement is preserved", function()
    fixture(); failure = "marker"; H.eq(pcall(apply), false)
    files[path] = "new reader portrait"; failure = nil
    H.eq(apply(), false); H.eq(files[path], "new reader portrait"); H.eq(removals, 1)
end)
H.test("a completed marker does not touch later images even if they match the retired hash", function()
    fixture(); apply(); files[path] = Update.sha256
    H.eq(apply(), false); H.eq(hashes, 1); H.eq(removals, 1)
    H.eq(files[path], Update.sha256)
end)
H.test("new installs omit Lispector but retain author binding for custom replacements", function()
    for _, pack in ipairs(Authors.packs) do
        if pack.name == "Authors" then
            for _, name in ipairs(pack.files) do assert(name ~= Update.file) end
        end
    end
    H.eq(Authors.pieces["Authors/" .. Update.file], "clarice lispector")
    H.eq(Authors.authorOf({ author = "Lispector, Clarice" }), "clarice lispector")
end)
os.remove = remove
H.finish()
