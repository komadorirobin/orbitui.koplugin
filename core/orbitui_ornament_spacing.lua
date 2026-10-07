local Authors = require("core/orbitui_author_ornaments")
local M = {}

-- Balance unused end space without moving books or changing the plan's reserve.
function M.positionX(pl, x, left, right, pad)
    if Authors.pieces[pl.entry and pl.entry.name]
            or (pl.pad_px or 0) < 0 or pad < 0 then
        return x
    end
    if pl.w <= 0 or right - left < pl.w + 2 * pad then return x end
    return math.floor((left + right - pl.w) / 2)
end

return M
