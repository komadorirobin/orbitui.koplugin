local files = assert(io.popen("git ls-files --cached --others --exclude-standard"))
local count = 0
for path in files:lines() do
    if path:match("%.lua$") then
        assert(loadfile(path))
        count = count + 1
    end
end
assert(files:close())
print("LuaJIT syntax: " .. count .. " Lua files verified")
