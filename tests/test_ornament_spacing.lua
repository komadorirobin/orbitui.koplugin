package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local Adapter = require("adapters/orbitui_ornaments")
local Spacing = require("core/orbitui_ornament_spacing")
local Authors = require("core/orbitui_author_ornaments")

local f = assert(io.open("components/bookshelf/lib/bookshelf_spine_shelf.lua"))
local source = f:read("*a")
f:close()
local row = assert(source:match("function SpineShelf%.rowWidget%(opts%)\n(.-)\nend\n"))
local geometry = assert(row:match("(    local content_w = 0\n.-)\n    group%[%#group %+ 1%] = HorizontalSpan"))
local end_piece = assert(row:match("%-%- The row's end piece.-(    local ornament\n.-)\n    %-%-"))
local lead_piece = assert(row:match("(            if i == opts.row.first and lead_pl then.-)\n            if #group"))
local gap_piece = assert(row:match("(                if e.ornament then.-)\n                group%["))

local function compile(code, env)
    setmetatable(env, { __index = _G })
    if setfenv then
        local fn = assert(loadstring(code))
        setfenv(fn, env)
        return fn
    end
    return assert(load(code, "ornament spacing", "t", env))
end

local function placement(side, width, name, pad)
    return { side=side, w=width, h=180, above=180, pad_px=pad,
        entry={name=name or "Ukiyo-e Gallery/Print.png"} }
end

local function options(pl, widths, width, height, gap, lead)
    local entries = {}
    for i, w in ipairs(widths) do entries[i] = {w=w} end
    entries[1].lead_ornament = lead
    return { width=width or 1000, height=height or 300, gap=gap or 20,
        row={first=1, last=#entries, ornament=pl}, plan={entries=entries} }
end

-- Execute the native row's reservation, centering and ornament painter blocks.
-- Only the framebuffer widgets are stubbed; the same overlap offsets feed paint
-- and tap targets on the device, with no new layout or image decoding here.
local function render(opts, enabled)
    local SS = {
        plankUnit=function(h) return math.floor(h / 25) end,
        endMargin=function(h) return math.floor(h / 25) end,
        ornamentY=function(pl, stand) return stand - pl.h end,
        behindAbove=function() return false end,
        noteOrn=function(list, widget) list[#list+1] = widget end,
    }
    for _, name in ipairs({"ornPad", "rowEndRoom"}) do
        local fn = assert(source:match("(function SpineShelf%." .. name .. "%b()\n.-\nend)"))
        compile(fn, {SpineShelf=SS})()
    end
    if enabled then Adapter.wrap("lib/bookshelf_spine_shelf", SS, "/unused") end
    local env = {opts=opts, SpineShelf=SS}
    local g = compile(geometry .. [[
        return {lead=lead, content_w=content_w, lead_pl=lead_pl, lead_pad=lead_pad}
    ]], env)()
    for k, v in pairs(g) do env[k] = v end
    local Orn = {Ornament={new=function(_, t) return t end}}
    env.require = function(name)
        H.eq(name, "lib/bookshelf_ornaments")
        return Orn
    end
    env._nightMode = function() return false end
    env.b, env.stand_h = SS.plankUnit(opts.height), opts.height - 25
    env.i, env.cursor = opts.row.first, g.lead
    env.HorizontalSpan = H.widget()
    env.group, env.hanging, env.gap_ornaments, env.orn_list = {}, {}, {}, {}
    compile(lead_piece, env)()
    local first = env.cursor
    local ending = compile(end_piece .. "\nreturn ornament", env)()
    if opts.row.ornament then assert(ending, "native pcall hid a failed end ornament") end
    if g.lead_pl then assert(env.gap_ornaments[1], "native pcall hid a failed lead ornament") end
    return {ending=ending, leading=env.gap_ornaments[1], first=first,
        lead=g.lead, last=g.lead+g.content_w, margin=SS.endMargin(opts.height),
        env=env, noted=env.orn_list}
end

local function balanced(widget, left, right, pad)
    local x, w = widget.overlap_offset[1], widget.placement.w
    local before, after = x-left, right-x-w
    assert(math.abs(before-after) <= 1, "uneven margins: " .. before .. ", " .. after)
    assert(before >= pad and after >= pad, "reserved padding was consumed")
end

H.test("the shelf module is opt-in and does not seed packs or replace its API", function()
    H.eq(Adapter.modules["lib/bookshelf_spine_shelf"], true)
    local rowWidget = function() end
    local shelf = {rowWidget=rowWidget}
    H.eq(Adapter.wrap("lib/bookshelf_spine_shelf", shelf, "/unused"), shelf)
    H.eq(shelf.positionOrnamentX, Spacing.positionX)
    H.eq(shelf.rowWidget, rowWidget)
    H.eq(shelf.listAll, nil)
end)

H.test("the reported left painting gains space from its book without moving any book", function()
    local pl = placement("left", 240)
    local opts = options(pl, {180, 140, 140})
    local old, new = render(opts, false), render(opts, true)
    local old_x, new_x = old.ending.overlap_offset[1], new.ending.overlap_offset[1]
    H.eq(old_x, 130)
    H.eq(new_x, 81)
    balanced(new.ending, new.margin, new.first, 20)
    H.eq(new.first, old.first)
    H.eq(new.last, old.last)
    H.eq(new.ending.overlap_offset[2], old.ending.overlap_offset[2])
    H.eq(new.ending.placement, pl)
    H.eq(new.noted[1], new.ending)
    H.eq(pl.w, 240); H.eq(pl.side, "left"); H.eq(pl.x, nil)
    H.eq(opts.row.first, 1); H.eq(opts.row.last, 3)
    H.eq(opts.plan.entries[1].w, 180)
end)

H.test("right-end ornaments use the mirrored free slot", function()
    local opts = options(placement("right", 240), {180, 140, 140})
    local old, new = render(opts, false), render(opts, true)
    balanced(new.ending, new.last, opts.width-new.margin, 20)
    assert(new.ending.overlap_offset[1] > old.ending.overlap_offset[1])
    H.eq(new.first, old.first); H.eq(new.last, old.last)
end)

H.test("sparse and full rows balance at different DPI, cover sizes and ornament widths", function()
    for _, scale in ipairs({1, 2, 3}) do
        for _, width in ipairs({800, 1001, 1400}) do
            for _, piece_w in ipairs({80, 160, 300}) do
                for _, side in ipairs({"left", "right"}) do
                    local opts = options(placement(side, piece_w*scale), {100*scale, 160*scale},
                        width*scale, 300*scale, 20*scale)
                    local r = render(opts, true)
                    balanced(r.ending, side == "left" and r.margin or r.last,
                        side == "left" and r.first or opts.width-r.margin, 20*scale)
                    local old = render(opts, false)
                    H.eq(r.first, old.first); H.eq(r.last, old.last)
                end
            end
        end
    end
    for _, side in ipairs({"left", "right"}) do
        local opts = options(placement(side, 240), {696}) -- exactly fills the row
        local old, new = render(opts, false), render(opts, true)
        balanced(new.ending, side == "left" and new.margin or new.last,
            side == "left" and new.first or opts.width-new.margin, 20)
        H.eq(new.ending.overlap_offset[1], old.ending.overlap_offset[1])
    end
end)

H.test("ordinary section-leading ornaments share slack without shifting their book", function()
    local opts = options(nil, {180, 140}, nil, nil, nil, placement("left", 240))
    local old, new = render(opts, false), render(opts, true)
    balanced(new.leading, new.margin, new.first, 20)
    assert(new.leading.overlap_offset[1] < old.leading.overlap_offset[1])
    H.eq(new.first, old.first); H.eq(new.last, old.last)
    H.eq(new.leading.overlap_offset[2], old.leading.overlap_offset[2])
    H.eq(new.noted[1], new.leading)
end)

H.test("a leading piece cannot move over a separate left-end ornament", function()
    local opts = options(placement("left", 100), {180}, nil, nil, nil, placement("left", 160))
    local old, new = render(opts, false), render(opts, true)
    H.eq(new.leading.overlap_offset[1], old.leading.overlap_offset[1])
    assert(new.ending.overlap_offset[1]+100+20 <= new.leading.overlap_offset[1])
end)

H.test("all author busts stay book-adjacent and keep their native padding", function()
    for name in pairs(Authors.pieces) do
        local opts = options(nil, {180}, nil, nil, nil, placement("left", 150, name))
        local old, new = render(opts, false), render(opts, true)
        H.eq(new.leading.overlap_offset[1], old.leading.overlap_offset[1], name)
        H.eq(new.first, old.first)
        H.eq(Spacing.positionX(placement("right", 150, name), 30, 0, 1000, 20), 30)
    end
end)

H.test("explicit tight or overlapping padding is not overridden", function()
    for _, pad in ipairs({-1, -10, -30, -1000}) do
        for _, side in ipairs({"left", "right"}) do
            local opts = options(placement(side, 200, nil, pad), {180, 140})
            local old, new = render(opts, false), render(opts, true)
            H.eq(new.ending.overlap_offset[1], old.ending.overlap_offset[1])
            H.eq(new.first, old.first)
        end
        local opts = options(nil, {180}, nil, nil, nil, placement("left", 200, nil, pad))
        local old, new = render(opts, false), render(opts, true)
        H.eq(new.leading.overlap_offset[1], old.leading.overlap_offset[1])
    end
end)

H.test("positive padding remains a minimum and cramped slots keep native fallback", function()
    local pl = placement("left", 160, nil, 30)
    local opts = options(pl, {180, 140})
    local r = render(opts, true)
    balanced(r.ending, r.margin, r.first, 50)
    for _, width in ipairs({40, 160, 180, 199}) do
        H.eq(Spacing.positionX(pl, 12, 0, width, 20), 12)
    end
    local tight = options(placement("left", 240), {730})
    H.eq(render(tight, true).ending.overlap_offset[1], render(tight, false).ending.overlap_offset[1])
    local overwide = options(placement("right", 1100), {180})
    H.eq(render(overwide, true).ending.overlap_offset[1], render(overwide, false).ending.overlap_offset[1])
end)

H.test("middle-gap ornaments remain centered natively", function()
    local r = render(options(nil, {180}), true)
    r.env.cursor, r.env.gap_w = 220, 300
    r.env.e = {ornament=placement(nil, 180)}
    compile(gap_piece, r.env)()
    local widget = r.env.gap_ornaments[1]
    assert(widget, "native pcall hid a failed gap ornament")
    H.eq(widget.overlap_offset[1], 280)
    H.eq(r.env.orn_list[1], widget)
end)

H.test("native paint and gesture ranges follow the repositioned ornament", function()
    local file = assert(io.open("components/bookshelf/lib/bookshelf_ornaments.lua"))
    local orn_source = file:read("*a")
    file:close()
    local painted, tapped, held
    local Orn = {Ornament=H.widget(), handlers={
        tap=function(entry) tapped=entry; return true end,
        hold=function(entry, pl, dimen) held=dimen; return true end,
    }, paintPlacement=function(bb, x, y, pl)
        painted = {x=x, y=y, placement=pl}
    end}
    local env = {M=Orn, require=function(name)
        assert(name == "ui/geometry" or name == "ui/gesturerange")
        return H.widget()
    end}
    setmetatable(env, { __index = _G })
    compile(assert(orn_source:match("(function M%.hits%b()\n.-\nend)")), env)()
    for _, name in ipairs({"init", "paintTo", "onTapOrnament", "onHoldOrnament"}) do
        compile(assert(orn_source:match("(function M%.Ornament:" .. name .. "%b()\n.-\nend)")), env)()
    end
    local pl = placement("left", 240)
    pl.entry.tap = "zoom"
    local r = render(options(pl, {180, 140, 140}), true)
    local widget = Orn.Ornament:new{placement=pl, overlap_offset=r.ending.overlap_offset}
    widget:paintTo({}, 35+widget.overlap_offset[1], 600+widget.overlap_offset[2])
    H.eq(painted.x, 116)
    H.eq(painted.placement, pl)
    for _, kind in ipairs({"TapOrnament", "HoldOrnament"}) do
        local range = widget.ges_events[kind][1].range
        H.eq(range.x, painted.x); H.eq(range.y, painted.y)
        H.eq(range.w, pl.w); H.eq(range.h, pl.h)
    end
    H.eq(widget:onTapOrnament(), true); H.eq(tapped, pl.entry)
    H.eq(widget:onHoldOrnament(), true); H.eq(held, widget.dimen)
end)

H.test("ornament taps cannot cover pagination above the embedded dock", function()
    local f = assert(io.open("components/bookshelf/lib/bookshelf_widget.lua"))
    local source = f:read("*a"); f:close()
    local body = assert(source:match("blocked = function%(pos%)\n(.-)\n            end,"))
    local shelf = {height=1680, _simpleUIReservedBottom=function() return 120 end,
        _paginationFooterReserveHeight=function() return 72 end}
    local blocked = compile("return function(pos)\n" .. body .. "\nend", {shelf=shelf})()
    H.eq(blocked({y=1487}),false)
    H.eq(blocked({y=1488}),true)
    H.eq(blocked({y=1600}),true)
end)

H.finish()
