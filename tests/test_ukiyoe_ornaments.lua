package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Gallery = require("core/orbitui_ukiyoe_ornaments")
local Adapter = require("adapters/orbitui_ornaments")
local original_open, original_rename, original_remove = io.open, os.rename, os.remove
local pack = Gallery.packs[1]
local source = "/slot/assets/ornaments/" .. pack.name .. "/"
local root = "/settings/bookshelf/ornaments"
local target = root .. "/" .. pack.name .. "/"
local marker = "/settings/orbitui/" .. pack.marker
local files, dirs, failed_dir, warnings, scans
local function fixture()
    files, dirs, failed_dir, warnings, scans = {}, {}, nil, 0, 0
    for _, file in ipairs(pack.files) do files[source .. file] = "source:" .. file end
end
package.loaded.datastorage = { getSettingsDir = function() return "/settings" end }
package.loaded["libs/libkoreader-lfs"] = {
    attributes = function(path)
        if files[path] then return "file" end
        if dirs[path] then return "directory" end
    end,
    dir = function(path)
        local children = {}
        for file in pairs(files) do
            if file:sub(1, #path + 1) == path .. "/" then
                local name = file:sub(#path + 2)
                if not name:find("/", 1, true) then children[#children+1] = name end
            end
        end
        local i = 0
        return function() i = i+1; return children[i] end
    end,
}
package.loaded["lib/bookshelf_fs"] = { ensureDir = function(path)
    if path == failed_dir then return false end
    dirs[path] = true; return true
end }
package.loaded.logger = { warn = function() warnings = warnings + 1 end }
package.loaded["core/orbitui_author_ornaments"] = { seed = function() end }
package.loaded["core/orbitui_japan_ornaments"] = { seed = function() end }
package.loaded["lib/bookshelf_ornament_deck"] = { sync = function() end, shuffle = function() end }
-- Installation must not read, enable, disable or activate any theme preference.
package.loaded["lib/bookshelf_settings_store"] = setmetatable({}, {
    __index = function() error("gallery install touched user preferences") end,
})
io.open = function(path, mode)
    if mode == "rb" and not files[path] then return nil, "missing source" end
    if mode == "wb" then
        assert(dirs[path:match("^(.+)/[^/]+$")], "parent directory not created: " .. path)
        files[path] = ""
    end
    local cursor = 1
    return {
        read = function(_, count)
            if count == "*a" then return files[path] end
            if cursor > #files[path] then return nil end
            local bytes = files[path]:sub(cursor, cursor+count-1)
            cursor = cursor+#bytes; return bytes
        end,
        write = function(self, bytes) files[path] = files[path] .. bytes; return self end,
        close = function() return true end,
    }
end
os.rename = function(from, to) files[to], files[from] = files[from], nil; return true end
os.remove = function(path) files[path] = nil; return true end
local orn = { dir = function() return root end }
local function seed() return Gallery.seed("/slot", orn) end

H.test("gallery copies nested theme files and commits its independent marker last", function()
    fixture(); H.eq(seed(), true)
    for _, file in ipairs(pack.files) do H.eq(files[target .. file], files[source .. file]) end
    assert(dirs[target .. "theme"]); assert(files[marker])
end)
H.test("existing artwork and theme customizations survive initial installation", function()
    fixture()
    local custom = { "Hokusai - Great Wave.png", "ornaments.json", "theme/theme.json",
                     "theme/wallpaper.jpg", "theme/plank.Hinoki.middle.png" }
    for _, file in ipairs(custom) do
        files[target .. file] = "custom:" .. file
    end
    seed()
    for _, file in ipairs(custom) do
        H.eq(files[target .. file], "custom:" .. file)
    end
end)
H.test("completed installation never restores deleted prints or theme files", function()
    fixture(); seed()
    files[target .. "theme/wallpaper.jpg"] = nil
    files[target .. "Hokusai - Great Wave.png"] = nil
    H.eq(seed(), false)
    H.eq(files[target .. "theme/wallpaper.jpg"], nil)
    H.eq(files[target .. "Hokusai - Great Wave.png"], nil)
end)
H.test("deleting the entire gallery remains respected on later startups", function()
    fixture(); seed()
    for _, file in ipairs(pack.files) do files[target .. file] = nil end
    H.eq(seed(), false)
    for _, file in ipairs(pack.files) do H.eq(files[target .. file], nil) end
end)
H.test("missing artwork leaves the marker unset and retries without overwriting", function()
    fixture(); files[source .. "Utamaro - Cleaning Combs.png"] = nil
    H.eq(pcall(seed), false); H.eq(files[marker], nil)
    files[target .. "Hokusai - Great Wave.png"] = "interrupted install edit"
    files[source .. "Utamaro - Cleaning Combs.png"] = "retry"
    H.eq(seed(), true); assert(files[marker])
    H.eq(files[target .. "Hokusai - Great Wave.png"], "interrupted install edit")
    H.eq(files[target .. "Utamaro - Cleaning Combs.png"], "retry")
end)
H.test("theme directory failures cannot commit an incomplete pack", function()
    fixture(); failed_dir = target .. "theme"
    H.eq(pcall(seed), false); H.eq(files[marker], nil)
    for path in pairs(files) do assert(not path:match("%.orbitui%-tmp$")) end
    failed_dir = nil; H.eq(seed(), true); assert(files[marker])
end)
H.test("a gallery failure is guarded and only attempted once per process", function()
    fixture(); files[source .. "Hokusai - Great Wave.png"] = nil
    local module = Adapter.wrap("lib/bookshelf_ornaments", {
        dir = orn.dir, listAll = function() scans = scans+1; return { "existing" }, { "Authors" } end,
    }, "/slot")
    for _ = 1, 4 do H.eq(module.listAll()[1], "existing") end
    H.eq(scans, 4); H.eq(warnings, 1); H.eq(files[marker], nil)
end)
H.test("the actual upstream theme scanner discovers the gallery and named plank", function()
    fixture(); seed()
    local Theme = dofile("components/bookshelf/lib/bookshelf_theme_pack.lua")
    Theme._orn = { dir = orn.dir, listAll = function() return {}, { pack.name } end }
    Theme._decode = function(bytes)
        H.eq(bytes, "source:theme/theme.json")
        return { name = "Ukiyo-e Gallery", shelf = "light", plank = "Hinoki" }
    end
    local themes = Theme.themePacks()
    H.eq(#themes, 1); H.eq(themes[1].pack, pack.name); H.eq(themes[1].plank, "Hinoki")
    local theme = Theme.theme(pack.name)
    H.eq(theme.wallpaper.base, "wallpaper.jpg")
    H.eq(#theme.planks, 1); H.eq(theme.planks[1].name, "Hinoki")
    H.eq(theme.planks[1].middle, target .. "theme/plank.Hinoki.middle.png")
end)
io.open, os.rename, os.remove = original_open, original_rename, original_remove
H.finish()
