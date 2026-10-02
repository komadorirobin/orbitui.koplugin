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
    "main.lua", "_meta.lua", "LICENSE", "README.md", "sources.json",
    "docs/MIGRATION.md", "docs/TESTING.md", "docs/UPSTREAM.md",
    "docs/INTEGRATION_CONTRACTS.md", "docs/MERGE_LOG.md",
    "components/bookshelf/main.lua", "components/bookshelf/_meta.lua",
    "components/bookshelf/LICENSE", "components/bookshelf/assets/bookshelf-logo.png",
    "components/simpleui/main.lua", "components/simpleui/_meta.lua", "components/simpleui/LICENSE",
}) do expect(path) end
local tracked = assert(io.popen("git ls-files"))
for path in tracked:lines() do
    if path:match("^core/.*%.lua$") or path:match("^adapters/.*%.lua$")
            or path:match("^components/bookshelf/fonts/")
            or path:match("^components/bookshelf/assets/wallpapers/")
            or path:match("^components/simpleui/icons/")
            or path:match("^components/[^/]+/locale/.*%.po$") then
        expect(path)
    end
end
assert(tracked:close())
print("Runtime archive: " .. count .. " entries; modules, assets, licenses and recovery docs verified")
