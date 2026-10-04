local archive = arg[1] or "dist/orbitui.koplugin.zip"
local quoted = "'" .. archive:gsub("'", "'\\''") .. "'"
local listing = assert(io.popen("unzip -Z1 " .. quoted))
local entries, count = {}, 0
local prefix = "orbitui.koplugin/"
for path in listing:lines() do
    assert(path:sub(1, #prefix) == prefix, "Unexpected archive root: " .. path)
    assert(not entries[path], "Duplicate archive entry: " .. path)
    for segment in path:gmatch("[^/]+") do
        assert(segment ~= "." and segment ~= "..", "Unsafe archive path: " .. path)
        assert(segment ~= ".git" and segment ~= ".github" and segment ~= "tests",
            "Development file in runtime archive: " .. path)
    end
    assert(not path:match("^orbitui%.koplugin/components/.*%.koplugin/"),
        "Nested KOReader plugin: " .. path)
    entries[path] = true
    count = count + 1
end
assert(listing:close(), "Could not list runtime archive")
local function expect(path)
    assert(entries[prefix .. path], "Missing runtime file: " .. path)
end
for _, path in pairs(dofile("core/orbitui_module_map.lua")) do expect(path) end
for _, path in ipairs({
    "main.lua", "_meta.lua", "orbitui_bootstrap.lua", "VERSION", "manifest.json", "LICENSE", "README.md", "sources.json",
    "docs/MIGRATION.md", "docs/TESTING.md", "docs/UPSTREAM.md",
    "docs/INTEGRATION_CONTRACTS.md", "docs/MERGE_LOG.md",
    "docs/OTA.md",
    "assets/ca-bundle.crt", "assets/CA-LICENSE", "assets/CA-NOTICE.txt",
    "assets/material-symbols/MaterialSymbolsRounded.ttf",
    "assets/material-symbols/LICENSE", "assets/material-symbols/NOTICE.txt",
    "assets/material-symbols/generated.json", "assets/material-symbols/selection.json",
    "assets/material-symbols/icons/manga.svg", "assets/material-symbols/icons/comic_bubble.svg",
    "core/orbitui_icons.lua", "core/orbitui_material_catalogue.lua", "adapters/orbitui_icons.lua",
    "core/orbitui_vector_icons.lua",
    "core/orbitui_author_ornaments.lua", "core/orbitui_japan_ornaments.lua",
    "core/orbitui_ornament_install.lua", "adapters/orbitui_ornaments.lua",
    "assets/vector-icons/selection.json", "assets/vector-icons/generated.json", "assets/vector-icons/NOTICE.txt",
    "assets/vector-icons/SOLAR-LICENSE.txt", "assets/vector-icons/TABLER-LICENSE.txt",
    "assets/vector-icons/custom/manga-outline.svg", "assets/vector-icons/custom/manga-duotone.svg",
    "components/bookshelf/main.lua", "components/bookshelf/_meta.lua",
    "components/bookshelf/LICENSE", "components/bookshelf/assets/bookshelf-logo.png",
    "components/simpleui/main.lua", "components/simpleui/_meta.lua", "components/simpleui/LICENSE",
}) do expect(path) end
for _, module in ipairs({ "core/orbitui_author_ornaments", "core/orbitui_japan_ornaments" }) do
    for _, pack in ipairs(require(module).packs) do
        for _, file in ipairs(pack.files) do
            expect("assets/ornaments/" .. pack.name .. "/" .. file)
        end
    end
end
for _, icon in ipairs(dofile("core/orbitui_material_catalogue.lua")) do
    expect("assets/material-symbols/icons/" .. icon.name .. ".svg")
    for _, weight in ipairs(require("core/orbitui_icons").weights) do
        expect("assets/material-symbols/icons/" .. weight .. "/" .. icon.name .. ".svg")
    end
end
for _, source in ipairs(require("core/orbitui_vector_icons").sources) do
    expect(source.module .. ".lua")
    for _, icon in ipairs(require("core/orbitui_vector_icons").catalogue(source.key)) do
        expect("assets/vector-icons/" .. source.key .. "/" .. icon.name .. ".svg")
    end
end
local tracked = assert(io.popen("git ls-files"))
for path in tracked:lines() do
    if path:match("^core/.*%.lua$") or path:match("^adapters/.*%.lua$")
            or path:match("^components/bookshelf/fonts/")
            or path:match("^components/bookshelf/assets/wallpapers/")
            or path:match("^components/bookshelf/assets/planks/")
            or path:match("^components/bookshelf/assets/shadows/")
            or path:match("^components/simpleui/icons/")
            or path:match("^components/[^/]+/locale/.*%.po$") then
        expect(path)
    end
end
assert(tracked:close())
print("Runtime archive: " .. count .. " entries; modules, assets, licenses and recovery docs verified")
