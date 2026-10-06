local M = {
    pack = "Authors",
    marker = "ornament-mann-photo-v3.updated",
    baseline = "assets/ornament-updates/mann-photo-v3.json",
    file = "Thomas Mann.png",
    notice = "THOMAS-MANN-SEITZ.txt",
}

function M.apply(root, ornaments_dir)
    return require("core/orbitui_single_ornament_update").apply(root, ornaments_dir, M)
end

return M
