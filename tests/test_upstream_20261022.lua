package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local file = assert(io.open("components/bookshelf/micromodules/shelf_size.lua"))
local source = file:read("*a"); file:close()
local prefix = assert(source:match("^(.-)\n%-%- The last finished tally"))
local freed = 0
local deps = {
    ["lib/bookshelf_i18n"] = { gettext = function(s) return "translated:" .. s end },
    ["lib/bookshelf_fonts"] = { getFace = function(_, _, size) return { size = size } end },
    ["lib/bookshelf_colour_text"] = { new = function(_, t)
        return {
            getSize = function() return { w = #t.text * t.face.size } end,
            free = function() freed = freed + 1 end,
        }
    end },
}
local env = setmetatable({ require = function(name) return assert(deps[name], name) end },
    { __index = _G })
local code = prefix .. '\nreturn _fitStatusRow, function() return _("Books") end'
local chunk
if setfenv then
    chunk = assert(loadstring(code)); setfenv(chunk, env)
else
    chunk = assert(load(code, "shelf size fit", "t", env))
end
local fit, translate = chunk()

H.test("wrapped shelf statistics never overwrite the translator on repaint", function()
    local counts = { reading = 10, unread = 20000, on_hold = 5, finished = 300 }
    for _, width in ipairs({ 50, 150, 50 }) do
        local h, c, cols = fit(width, 100, counts, 1)
        H.eq(cols, 2); H.eq(h, 12); H.eq(c, 18)
        H.eq(translate(), "translated:Books")
    end
    assert(freed > 0)
end)

H.test("wide shelf statistics keep one row and cached fitting", function()
    local _, _, cols = fit(2000, 100, {}, 2)
    H.eq(cols, 4)
    local before = freed
    fit(2000, 100, {}, 2)
    H.eq(freed, before)
    H.eq(translate(), "translated:Books")
end)
H.finish()
