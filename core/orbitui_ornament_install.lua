-- Additive artwork installation shared by author-bound and general ornaments.
local M = {}

local function copy(source, target)
    local input = assert(io.open(source, "rb"))
    local temporary, output = target .. ".orbitui-tmp"
    local ok, err = pcall(function()
        output = assert(io.open(temporary, "wb"))
        while true do
            local bytes, read_error = input:read(65536)
            assert(not read_error, read_error)
            if not bytes then break end
            assert(output:write(bytes))
        end
        assert(output:close())
        output = nil
        assert(os.rename(temporary, target))
    end)
    input:close()
    if output then pcall(output.close, output) end
    if not ok then os.remove(temporary); error(err) end
end

local function settingsDir()
    return require("datastorage"):getSettingsDir() .. "/orbitui"
end

function M.installed(marker)
    return require("libs/libkoreader-lfs").attributes(settingsDir() .. "/" .. marker, "mode") == "file"
end

function M.mark(source, marker)
    assert(require("lib/bookshelf_fs").ensureDir(settingsDir()), "Cannot create ornament marker folder")
    copy(source, settingsDir() .. "/" .. marker)
end

-- Independent markers avoid overwriting edits or resurrecting deleted packs.
function M.seed(root, ornaments_dir, packs)
    local fs = require("libs/libkoreader-lfs")
    local ensure = require("lib/bookshelf_fs").ensureDir
    local changed = false
    for _, pack in ipairs(packs) do
        if not M.installed(pack.marker) then
            local target = ornaments_dir .. "/" .. pack.name
            local source = root .. "/assets/ornaments/" .. pack.name .. "/"
            assert(ensure(settingsDir()) and ensure(target), "Cannot create ornament pack folder")
            for _, file in ipairs(pack.files) do
                if not fs.attributes(target .. "/" .. file, "mode") then
                    local parent = file:match("^(.+)/[^/]+$")
                    if parent then
                        assert(ensure(target .. "/" .. parent), "Cannot create ornament theme folder")
                    end
                    copy(source .. file, target .. "/" .. file)
                end
            end
            -- Commit only after all artwork and notices reached this pack.
            M.mark(source .. "README.txt", pack.marker)
            changed = true
        end
    end
    return changed
end

return M
