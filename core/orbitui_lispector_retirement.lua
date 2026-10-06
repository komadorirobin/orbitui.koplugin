-- Retire only the shipped portrait, never a reader's replacement or metadata.
local M = {
    marker = "ornament-lispector-original-v1.retired",
    file = "Clarice Lispector.png",
    sha256 = "bee7a3d24770d1931d4144b3e5ad1c8b71beaac0d10b5acbf9f43d317524343a",
}

function M.apply(root, ornaments_dir)
    local Install = require("core/orbitui_ornament_install")
    if Install.installed(M.marker) then return false end
    local fs = require("libs/libkoreader-lfs")
    local folder = ornaments_dir .. "/Authors"
    local path = folder .. "/" .. M.file
    local changed = false
    if fs.symlinkattributes(folder, "mode") == "directory"
        and fs.symlinkattributes(path, "mode") == "file"
        and require("core/orbitui_ota").hashFile(path) == M.sha256 then
        assert(os.remove(path))
        changed = true
    end
    -- Retry failed deletion/marker writes; later starts do not rehash artwork.
    Install.mark(root .. "/assets/ornaments/Authors/README.txt", M.marker)
    return changed
end

return M
