local M = {
    pack = "Authors II",
    marker = "ornament-hemingway-photo-v1.updated",
    baseline = "assets/ornament-updates/hemingway-photo-v1.json",
    file = "Ernest Hemingway.png",
    notice = "ERNEST-HEMINGWAY.txt",
}

function M.apply(root, ornaments_dir)
    return require("core/orbitui_single_ornament_update").apply(root, ornaments_dir, M)
end

return M
