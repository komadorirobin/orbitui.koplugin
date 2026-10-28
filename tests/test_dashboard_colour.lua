package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local M = require("core/orbitui_dashboard")
local function luminance(hex)
    local function linear(c)
        c = tonumber(c, 16) / 255
        return c <= .04045 and c / 12.92 or ((c + .055) / 1.055) ^ 2.4
    end
    return .2126 * linear(hex:sub(2, 3)) + .7152 * linear(hex:sub(4, 5)) + .0722 * linear(hex:sub(6, 7))
end
H.test("colour modes are opt-in and have no layout or provider side effects", function()
    for _, v in ipairs({ false, {}, "", "unknown", "OFF" }) do H.eq(M.colourMode(v), "off") end
    H.eq(M.colourMode(nil), "off"); H.eq(M.colourMode("accents"), "accents")
    H.eq(M.colourMode("tinted"), "tinted"); H.eq(M.cardColours("goal", "off"), nil)
    H.eq(M.cardColours("goal", "accents").fill, nil)
end)
H.test("tinted cards keep black day text and white night text above accessible contrast", function()
    for _, entry in ipairs(M.heading_cards) do
        local day = M.cardColours(entry.key, "tinted", false)
        local night = M.cardColours(entry.key, "tinted", true)
        assert((luminance(day.fill) + .05) / .05 >= 7, entry.key .. " day contrast")
        assert(1.05 / (luminance(night.fill) + .05) >= 7, entry.key .. " night contrast")
        assert((luminance(night.accent) + .05) / .05 >= 4.5, entry.key .. " night accent")
        H.eq(M.cardColours(entry.key, "tinted", false).fill, day.fill)
    end
end)
H.test("hero colours keep white day and native-inverted black night text readable", function()
    for _, hex in ipairs({ "#FF0000", "#00FF00", "#0000FF", "#EFEF00", "#550099", "#222222" }) do
        local day = M.cardColours("hero", "accents", false, hex)
        local night = M.cardColours("hero", "accents", true, hex)
        assert(1.05 / (luminance(day.deep) + .05) >= 7)
        assert((luminance(night.deep) + .05) / .05 >= 7)
    end
    H.eq(M.cardColours("hero", "tinted", false, nil).deep, nil)
    H.eq(M.cardColours("hero", "tinted", false, "invalid").deep, nil)
end)
H.test("cover sampling is bounded to 64 reads and excludes grey and transparent pixels", function()
    local reads = 0
    H.eq(M.coverColour(2, 3, function(x, y)
        assert(x >= 0 and x < 2 and y >= 0 and y < 3)
        reads = reads + 1; return 20, 100, 180, 255
    end), "#1464B4")
    H.eq(reads, 64)
    H.eq(M.coverColour(100, 150, function() return 120, 120, 120, 255 end), nil)
    H.eq(M.coverColour(100, 150, function() return 255, 0, 0, 0 end), nil)
    H.eq(M.coverColour(0, 1, function() error("must not sample") end), nil)
    H.eq(M.coverColour(1, 0, function() error("must not sample") end), nil)
end)
H.test("white lettering does not wash out a saturated cover region", function()
    H.eq(M.coverColour(80, 80, function(x)
        if x > 20 then return 240, 240, 240, 255 end
        return 160, 50, 80, 255
    end), "#A03250")
end)
H.test("bilingual static settings search finds card colours without loading dashboard providers", function()
    local settings = require("adapters/orbitui_settings")
    for _, query in ipairs({ "kortfärger", "tonade", "accents", "tinted", "card colours" }) do
        H.eq(settings.find(query)[1].id, "home_dashboard")
    end
    H.eq(package.loaded["modules/module_books_shared"], nil)
end)
H.finish()
