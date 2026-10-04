package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Japan = require("core/orbitui_japan_ornaments")
local Authors = require("core/orbitui_author_ornaments")
local Adapter = require("adapters/orbitui_ornaments")
package.loaded["lib/bookshelf_ornament_deck"] = { sync = function() end, shuffle = function() end }
local open, rename, remove = io.open, os.rename, os.remove
local files, settings, saves, invalidations, warnings, fail_save, unreadable
local root = "/settings/bookshelf/ornaments/"
local old = "/icons/bookshelf.ornaments/"
local source = "/slot/assets/ornaments/Japan/"
local marker = "/settings/orbitui/" .. Japan.packs[1].marker
local defaults = "/settings/orbitui/" .. Japan.defaults_marker
local ornament = {
    CACTUS_NAME = "cactus.svg", CACTUS_SVG = "exact native cactus",
    TEMPLATE_NAME = "template.svg", TEMPLATE_SVG = "exact native plant",
    OFF_KEY = "ornaments_off", PACKS_OFF_KEY = "ornament_packs_off",
    dir = function() return root:sub(1, -2) end,
    roots = function() return { root:sub(1, -2), old:sub(1, -2) } end,
    invalidate = function() invalidations = invalidations + 1 end,
}
local function fixture()
    files, settings, saves, invalidations, warnings, fail_save = {}, {}, 0, 0, 0, false
    unreadable = nil
    for _, pack in ipairs(Japan.packs) do
        for _, file in ipairs(pack.files) do files[source .. file] = "complete " .. file end
    end
    for _, pack in ipairs(Authors.packs) do
        for _, file in ipairs(pack.files) do
            files["/slot/assets/ornaments/" .. pack.name .. "/" .. file] = "author " .. file
        end
    end
    files[root .. "cactus.svg"], files[root .. "template.svg"] = ornament.CACTUS_SVG, ornament.TEMPLATE_SVG
    settings.ornaments_off = { ["Authors/Franz Kafka.png"] = true, ["My ornaments/cactus.svg"] = true }
    settings.ornament_packs_off = { Modernists = true }
    settings.ornament_frequency = 0
end
package.loaded.datastorage = { getSettingsDir = function() return "/settings" end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(path) return files[path] and "file" end }
package.loaded["lib/bookshelf_fs"] = { ensureDir = function() return true end }
package.loaded["lib/bookshelf_settings_store"] = {
    read = function(key) return settings[key] end,
    save = function(key, value)
        if fail_save == "false" then return false end
        if fail_save then error("settings disk full") end
        settings[key] = value; saves = saves + 1
    end,
}
package.loaded.logger = { warn = function() warnings = warnings + 1 end }
io.open = function(path, mode)
    if mode == "rb" and path == unreadable then return nil, "unreadable file" end
    if mode == "rb" and not files[path] then return nil, "missing file" end
    if mode == "wb" then files[path] = "" end
    local cursor = 1
    return {
        read = function(_, n)
            if cursor > #files[path] then return nil end
            local value = files[path]:sub(cursor, cursor + n - 1)
            cursor = cursor + #value; return value
        end,
        write = function(self, value) files[path] = files[path] .. value; return self end,
        close = function() return true end,
    }
end
os.rename = function(a, b) files[b], files[a] = files[a], nil; return true end
os.remove = function(path) files[path] = nil; return true end
local function seed() return Japan.seed("/slot", ornament) end

H.test("Japan installs byte-for-byte and disables only the unchanged stock plants once", function()
    fixture(); H.eq(seed(), true)
    for _, file in ipairs(Japan.packs[1].files) do
        H.eq(files[root .. "Japan/" .. file], files[source .. file])
    end
    assert(files[marker] and files[defaults])
    H.eq(settings.ornaments_off["cactus.svg"], true)
    H.eq(settings.ornaments_off["template.svg"], true)
    H.eq(files[root .. "cactus.svg"], ornament.CACTUS_SVG)
    H.eq(files[root .. "template.svg"], ornament.TEMPLATE_SVG)
    H.eq(settings.ornaments_off["Authors/Franz Kafka.png"], true)
    H.eq(settings.ornaments_off["My ornaments/cactus.svg"], true)
    H.eq(settings.ornament_packs_off.Modernists, true)
    H.eq(settings.ornament_frequency, 0)
    H.eq(saves, 1); H.eq(invalidations, 1)
end)

H.test("re-enabling a stock plant and deleting new artwork survive later startups", function()
    settings.ornaments_off["cactus.svg"] = nil
    settings.ornament_packs_off.Japan = true
    files[root .. "Japan/Pine Bonsai.png"] = "custom bonsai"
    files[root .. "Japan/Sleeping Calico.png"] = nil
    H.eq(seed(), false)
    H.eq(settings.ornaments_off["cactus.svg"], nil)
    H.eq(settings.ornament_packs_off.Japan, true)
    H.eq(files[root .. "Japan/Pine Bonsai.png"], "custom bonsai")
    H.eq(files[root .. "Japan/Sleeping Calico.png"], nil)
    H.eq(saves, 1)
    for _, file in ipairs(Japan.packs[1].files) do files[root .. "Japan/" .. file] = nil end
    H.eq(seed(), false); H.eq(files[root .. "Japan/Daruma.png"], nil)
end)

H.test("custom stock filenames and pre-existing Japan metadata are never overwritten", function()
    fixture()
    files[root .. "cactus.svg"] = "user cactus drawing"
    files[root .. "template.svg"] = ornament.TEMPLATE_SVG .. " custom edit"
    files[root .. "Japan/ornaments.json"] = "custom placement"
    files[root .. "Japan/Maneki Neko.png"] = "custom cat"
    seed()
    H.eq(settings.ornaments_off["cactus.svg"], nil)
    H.eq(settings.ornaments_off["template.svg"], nil)
    H.eq(files[root .. "Japan/ornaments.json"], "custom placement")
    H.eq(files[root .. "Japan/Maneki Neko.png"], "custom cat")
    H.eq(saves, 0)
end)

H.test("legacy stock plants are disabled without creating, deleting or moving them", function()
    fixture()
    files[old .. "cactus.svg"], files[root .. "cactus.svg"] = files[root .. "cactus.svg"], nil
    files[old .. "template.svg"], files[root .. "template.svg"] = files[root .. "template.svg"], nil
    seed()
    H.eq(settings.ornaments_off["cactus.svg"], true)
    H.eq(settings.ornaments_off["template.svg"], true)
    H.eq(files[root .. "cactus.svg"], nil)
    H.eq(files[old .. "cactus.svg"], ornament.CACTUS_SVG)
end)

H.test("a current custom file shadows the legacy stock file", function()
    fixture()
    files[old .. "cactus.svg"] = ornament.CACTUS_SVG
    files[root .. "cactus.svg"] = "custom preferred cactus"
    seed(); H.eq(settings.ornaments_off["cactus.svg"], nil)
end)

H.test("an unreadable current file cannot fall through to legacy stock detection", function()
    fixture()
    unreadable = root .. "cactus.svg"
    files[root .. "cactus.svg"] = "unreadable custom cactus"
    files[old .. "cactus.svg"] = ornament.CACTUS_SVG
    seed(); H.eq(settings.ornaments_off["cactus.svg"], nil)
end)

H.test("missing stock files stay absent instead of being restored or disabled by name", function()
    fixture(); files[root .. "cactus.svg"], files[root .. "template.svg"] = nil, nil
    H.eq(seed(), true)
    H.eq(files[root .. "cactus.svg"], nil); H.eq(files[root .. "template.svg"], nil)
    H.eq(settings.ornaments_off["cactus.svg"], nil)
    H.eq(settings.ornaments_off["template.svg"], nil)
    assert(files[defaults]); H.eq(saves, 0)
end)

H.test("an already disabled Japan pack leaves the old plants enabled", function()
    fixture(); settings.ornament_packs_off.Japan = true
    seed()
    H.eq(settings.ornaments_off["cactus.svg"], nil)
    H.eq(settings.ornaments_off["template.svg"], nil)
    assert(files[marker] and files[defaults]); H.eq(saves, 0)
end)

H.test("missing artwork cannot commit either marker or switch off the stock plants", function()
    fixture(); files[source .. "Maple Bonsai.png"] = nil
    H.eq(pcall(seed), false)
    H.eq(files[marker], nil); H.eq(files[defaults], nil)
    H.eq(settings.ornaments_off["cactus.svg"], nil); H.eq(saves, 0)
    files[source .. "Maple Bonsai.png"] = "retry maple"
    files[root .. "Japan/Pine Bonsai.png"] = "edit during interrupted copy"
    H.eq(seed(), true)
    H.eq(files[root .. "Japan/Maple Bonsai.png"], "retry maple")
    H.eq(files[root .. "Japan/Pine Bonsai.png"], "edit during interrupted copy")
end)

H.test("a defaults save failure retries independently of the installed artwork", function()
    fixture(); fail_save = true
    H.eq(pcall(seed), false)
    assert(files[marker]); H.eq(files[defaults], nil)
    H.eq(settings.ornaments_off["cactus.svg"], nil, "failed migration must not mutate the live set")
    files[root .. "Japan/Daruma.png"] = nil
    fail_save = false
    H.eq(seed(), true); assert(files[defaults])
    H.eq(files[root .. "Japan/Daruma.png"], nil)
end)

H.test("an explicit failed save does not commit defaults or mutate live settings", function()
    fixture(); fail_save = "false"
    H.eq(pcall(seed), false)
    assert(files[marker]); H.eq(files[defaults], nil)
    H.eq(settings.ornaments_off["cactus.svg"], nil)
    H.eq(settings.ornaments_off["template.svg"], nil)
    H.eq(invalidations, 0)
end)

H.test("the guarded adapter installs both kinds of packs and keeps normal list caching", function()
    fixture()
    local calls = 0
    local all, packs = { "native entries" }, { "Japan", "Authors" }
    local module = {}
    for key, value in pairs(ornament) do module[key] = value end
    module.listAll = function() calls = calls + 1; return all, packs end
    Adapter.wrap("lib/bookshelf_ornaments", module, "/slot")
    for _ = 1, 3 do
        local actual, actual_packs = module.listAll()
        H.eq(actual, all); H.eq(actual_packs, packs)
    end
    H.eq(calls, 3); H.eq(warnings, 0); H.eq(saves, 1)
    assert(files[marker] and files[defaults])
    assert(files[root .. "Authors/Franz Kafka.png"])
    assert(files[root .. "Modernists/James Joyce.png"])
    for _, file in ipairs(Japan.packs[1].files) do H.eq(Authors.pieces["Japan/" .. file], nil) end
end)

H.test("a failed Japan install leaves author ornaments and the browser working", function()
    fixture(); files[source .. "Daruma.png"] = nil
    local module = {}
    for key, value in pairs(ornament) do module[key] = value end
    module.listAll = function() return { "existing" }, { "existing pack" } end
    Adapter.wrap("lib/bookshelf_ornaments", module, "/slot")
    for _ = 1, 3 do H.eq(module.listAll()[1], "existing") end
    H.eq(warnings, 1); H.eq(files[marker], nil)
    H.eq(settings.ornaments_off["cactus.svg"], nil)
    assert(files[root .. "Modernists/James Joyce.png"])
end)

io.open, os.rename, os.remove = open, rename, remove
H.finish()
