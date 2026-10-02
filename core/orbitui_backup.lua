local M = {}

local function copyFile(source, target)
    local input, err = io.open(source, "rb")
    if not input then error(err) end
    local output
    local ok, failure = pcall(function()
        output = assert(io.open(target .. ".tmp", "wb"))
        while true do
            local chunk, read_err = input:read(65536)
            if read_err then error(read_err) end
            if not chunk then break end
            assert(output:write(chunk))
        end
        assert(output:close())
        output = nil
        assert(os.rename(target .. ".tmp", target))
    end)
    input:close()
    if output then output:close() end
    if not ok then
        os.remove(target .. ".tmp")
        error(failure)
    end
end

function M.ensure()
    local lfs = require("libs/libkoreader-lfs")
    local DS = require("datastorage")
    local settings = DS:getSettingsDir()
    local parent = settings .. "/orbitui"
    local backup = parent .. "/before-first-run"
    local marker = backup .. "/COMPLETE"
    if lfs.attributes(marker, "mode") == "file" then return backup end
    for _, dir in ipairs({ parent, backup }) do
        if lfs.attributes(dir, "mode") ~= "directory" then
            assert(lfs.mkdir(dir))
        end
    end
    local stem = backup .. "/attempt-" .. os.date("%Y%m%d-%H%M%S")
    local attempt, suffix = stem, 0
    while lfs.attributes(attempt, "mode") do
        suffix = suffix + 1
        attempt = stem .. "-" .. suffix
    end
    assert(lfs.mkdir(attempt))
    local files = {}
    for name in lfs.dir(settings) do
        if name:match("^bookshelf.*%.lua$") or name:match("^bookshelf.*%.lua%.old$") then
            files[#files + 1] = { settings .. "/" .. name, name }
        end
    end
    for _, suffix in ipairs({ "", ".old" }) do
        files[#files + 1] = {
            settings .. "/simpleui/sui_settings.lua" .. suffix,
            "simpleui-settings.lua" .. suffix,
        }
    end
    files[#files + 1] = {
        G_reader_settings.file or (DS:getDataDir() .. "/settings.reader.lua"),
        "settings.reader.lua",
    }
    table.sort(files, function(a, b) return a[2] < b[2] end)
    local copied = {}
    for _, file in ipairs(files) do
        if lfs.attributes(file[1], "mode") == "file" then
            -- A failed attempt remains inspectable; retries take a new snapshot.
            copyFile(file[1], attempt .. "/" .. file[2])
            copied[#copied + 1] = file[2]
        end
    end
    local f = assert(io.open(marker .. ".tmp", "wb"))
    local ok, err = f:write("OrbitUI pre-first-run settings snapshot\n",
        attempt:match("([^/]+)$"), "\n", table.concat(copied, "\n"), "\n")
    local closed, close_err = f:close()
    assert(ok, err)
    assert(closed, close_err)
    assert(os.rename(marker .. ".tmp", marker))
    return backup
end

return M
