-- OrbitUI owns only this optional presentation. Never initialize the pet,
-- load its saves, advance its clock, copy its artwork or replace its files.
local _ = require("core/orbitui_i18n")
local M = { id = "orbitui_reading_silverfish", enabled_key = "orbitui_reading_silverfish_enabled",
    default_on = false, category = "books", has_covers = true, is_book_mod = true,
    owns_chrome = true, needs = { recent = 1 }, wants_minute_tick = true }
M.name = _("Currently reading + Silverfish")
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < 1e12 end
local function text(s, fallback)
    return type(s) == "string" and #s <= 512 and s:gsub("[%c]", " ") or fallback
end
local function livePet()
    local ss = package.loaded["ui/screensaver"]
    return type(ss) == "table" and ss.traca_instancia or nil
end
local function callable(fn)
    -- KOReader's PluginLoader replaces on* functions with HandlerSandbox
    -- objects. Keep that error boundary instead of unwrapping the handler.
    local mt = type(fn) == "table" and getmetatable(fn)
    return type(fn) == "function" or type(mt) == "table" and type(mt.__call) == "function"
end

function M.snapshot(now)
    local pet = livePet()
    if type(pet) ~= "table" then return nil, _("Enable Silverfish and restart KOReader to show your companion here.") end
    -- Fail closed on unreviewed releases, not on guessed method compatibility.
    local version, draw, state, species = package.loaded.traca_versao, package.loaded.traca_desenho,
        package.loaded.traca_estado, package.loaded.traca_species
    if type(version) ~= "table" or version.numero ~= "2.0.0" or version.publica ~= true
            or type(draw) ~= "table" or draw.LARGURA ~= 64 or draw.ALTURA ~= 64
            or type(draw.pintarSprite) ~= "function" or type(draw.sprite) ~= "function"
            or type(state) ~= "table" or type(state.fase) ~= "function" or type(state.sprite) ~= "function"
            or type(species) ~= "table" or type(species.current) ~= "function"
            or type(species.texto) ~= "function" or not callable(pet.onMostrarTraca) then
        return nil, _("This Silverfish version is not supported by this card. Update OrbitUI or use Silverfish's own card.")
    end
    local ok, result = pcall(function()
        local s, active = pet.estado, species.current()
        assert(type(s) == "table" and type(active) == "table"
            and (active.id == "gato" or active.id == "traca"))
        assert((s.especie or "traca") == active.id, "Species is changing")
        local phase, sprite = state.fase(s), state.sprite(s, now or os.time())
        assert(type(phase) == "table" and type(sprite) == "string" and #sprite <= 80)
        local rows = draw.sprite(sprite)
        assert(type(rows) == "table" and #rows == 64)
        local x0, y0, x1, y1 = 64, 64, -1, -1
        for y, row in ipairs(rows) do
            assert(type(row) == "string" and #row == 64)
            local a, b = row:find("[^ ]"), row:reverse():find("[^ ]")
            if a then
                x0, x1 = math.min(x0, a - 1), math.max(x1, 64 - b)
                y0, y1 = math.min(y0, y - 1), math.max(y1, y - 1)
            end
        end
        assert(x1 >= x0 and y1 >= y0)
        local titles = { ovo = "Egg", ninfa = "Nymph", jovem = "Young", adulta = "Adult",
            ancia = "Elder", filhote = "Kitten", adulto = "Adult", velho = "Elder" }
        local finished, count = 0, 0
        for title, record in pairs(type(s.livros) == "table" and s.livros or {}) do
            count = count + 1
            if count > 5000 then finished = nil; break end
            if type(record) == "table" and record.terminado
                    and (type(s.meus_livros) ~= "table" or s.meus_livros[title]) then finished = finished + 1 end
        end
        local birth, stamp = s.nascimento, now or os.time()
        local days = finite(birth) and math.max(1, math.floor((stamp - birth) / 86400) + 1) or nil
        return { pet = pet, state = s, species = active.id, draw = draw, version = version,
            species_module = species, sprite = sprite, bounds = { x0, y0, x1 - x0 + 1, y1 - y0 + 1 },
            name = text(s.nome, _(active.id == "gato" and "Ash Cat" or "Silverfish")),
            stage = _(active.id == "gato" and "Ash Cat" or "Silverfish") .. " · " .. _(titles[phase.nome] or "Companion"),
            days = days, finished = finished,
            generation = finite(s.geracao) and math.max(1, math.floor(s.geracao)) or 1 }
    end)
    if ok then return result end
    require("logger").warn("OrbitUI: Silverfish card unavailable", result)
    return nil, _("Silverfish is not ready. Open Silverfish, then reopen this page.")
end

function M.current(s)
    local ok, result = pcall(function()
        return s and livePet() == s.pet and s.pet.estado == s.state
            and package.loaded.traca_versao == s.version and s.version.numero == "2.0.0" and s.version.publica == true
            and package.loaded.traca_desenho == s.draw and package.loaded.traca_species == s.species_module
            and callable(s.pet.onMostrarTraca)
            and (s.state.especie or "traca") == s.species and s.species_module.current().id == s.species
    end)
    return ok and result == true
end

function M.getHeight(ctx)
    local screen = require("device").screen
    local owner = ctx and ctx._screen_widget
    local available = owner and owner._layout_content_h or require("infra/sui_core").getContentHeight()
    if not finite(available) or available < 1 then available = screen:getHeight() end
    return math.max(1, math.min(screen:scaleBySize(300), math.floor(available * .42)))
end

-- Fixed, card-local rectangles. The two original reading modules are unrelated.
function M.plan(w, h, dpi)
    w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
    -- Fonts follow display density, not a wide card's short aspect ratio.
    -- Reserve the full card height for the cover/book; only the companion
    -- column needs a name/stage header. Compact cards elide text, not shrink it.
    local scale = math.min(w / 618, finite(dpi) and dpi > 0 and dpi or 1)
    local pad = math.max(1, math.floor(12 * scale))
    local header = math.ceil(58 * scale)
    local body_h = math.max(1, h - 2 * pad - math.ceil(5 * scale))
    local cover_w = math.max(1, math.floor(math.min(w * .22, body_h * 2 / 3)))
    local cover_h = math.max(1, math.floor(cover_w * 3 / 2))
    local pet_x, pet_w = pad + cover_w + pad, math.max(1, math.floor(w * .30))
    local tx = pet_x + pet_w + pad
    local function rect(x, y, width, height)
        x, y = math.max(0, math.min(w - 1, x)), math.max(0, math.min(h - 1, y))
        return { x = x, y = y, w = math.max(1, math.min(w - x, width)), h = math.max(1, math.min(h - y, height)) }
    end
    return { w = w, h = h, scale = scale, pad = pad, header = header,
        companion = rect(pet_x, pad, pet_w, body_h),
        cover = rect(pad, pad + math.floor((body_h - cover_h) / 2), cover_w, cover_h),
        pet = rect(pet_x, pad + header, pet_w, math.max(1, body_h - header)),
        book = rect(tx, pad, math.max(1, w - tx - 2 * pad), body_h) }
end

local Card, Sprite
local function widgets()
    if Card then return end
    local Input, Widget = require("ui/widget/container/inputcontainer"), require("ui/widget/widget")
    local Geom = require("ui/geometry")
    Card = Input:extend{}
    function Card:paintTo(bb, x, y)
        self.dimen.x, self.dimen.y = x, y
        Input.paintTo(self, bb, x, y)
    end
    function Card:onReadingPetTap(_arg, ges)
        if self.disposed or not ges or not ges.pos or require("device").screen_saver_mode then return false end
        local owner = self.ctx._screen_widget
        if owner and (owner._suspended or owner._parked) then return false end
        local x, y = ges.pos.x - self.dimen.x, ges.pos.y - self.dimen.y
        if x < 0 or y < 0 or x >= self.dimen.w or y >= self.dimen.h then return false end
        local r = self.plan.pet
        if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
            if M.current(self.pet) then pcall(self.pet.pet.onMostrarTraca, self.pet.pet) end
        elseif self.file and self.ctx.open_fn then
            self.ctx.open_fn(self.file)
        end
        return true
    end
    function Card:free(full)
        if self.disposed then return end
        self.disposed = true; Input.free(self, full)
    end
    Sprite = Widget:extend{}
    function Sprite:getSize() return Geom:new{ w = self.w, h = self.h } end
    function Sprite:paintTo(bb, x, y)
        if not M.current(self.pet) then return end
        local b = self.pet.bounds
        local size = math.min(32, math.floor(math.min(self.w / b[3], self.h / b[4])))
        if size < 1 then return end
        self.pet.draw.pintarSprite(bb, self.pet.sprite,
            x + math.floor((self.w - b[3] * size) / 2) - b[1] * size,
            y + math.floor((self.h - b[4] * size) / 2) - b[2] * size, size)
    end
end

function M.build(w, ctx)
    widgets()
    local BB, Geom, Overlap = require("ffi/blitbuffer"), require("ui/geometry"), require("ui/widget/overlapgroup")
    local Frame, Style, UI = require("ui/widget/container/framecontainer"), require("features/sui_style"), require("infra/sui_core")
    local SH, Sources = require("modules/module_books_shared"), require("adapters/orbitui_dashboard_sources")
    local h = finite(ctx.height) and ctx.height > 0 and ctx.height or M.getHeight(ctx)
    local dpi = require("device").screen:scaleBySize(1000) / 1000
    local p = M.plan(w, h, dpi)
    if p.w < 120 or p.h < math.max(90, 100 * p.scale) then
        return Sources.moduleContainer(nil, Overlap:new{dimen=Geom:new{w=1,h=1}}, p.w, p.h, BB.COLOR_WHITE)
    end
    local card = Card:new{ dimen = Geom:new{ w = p.w, h = p.h }, ctx = ctx, plan = p }
    local group = Overlap:new{ dimen = Geom:new{ w = p.w, h = p.h }, allow_mirroring = false }
    card[1], card.group = group, group
    local function add(child, x, y)
        child.overlap_offset = { x, y }; group[#group + 1] = child; return child
    end
    local function label(value, x, y, width, size, bold, lines, color)
        local pixels = math.max(7, size * p.scale)
        local face, is_bold = Style.getStyledFace(nil, pixels / dpi, bold and "bold" or "regular")
        local args = { text = value or "", face = face, bold = is_bold, padding = 0,
            fgcolor = color or BB.COLOR_BLACK, width = math.max(1, math.floor(width)), max_width = math.max(1, math.floor(width)) }
        if lines then
            args.max_lines, args.height_adjust, args.height_overflow_show_ellipsis = lines, false, true
            args.height = math.max(1, math.floor(pixels * 1.4 * lines))
            return add(UI.makeTextBox(args, true), x, y)
        end
        return add(UI.makeColoredText(args), x, y)
    end
    local shadow = math.max(1, math.floor(p.scale * 5))
    local function frame(x, y, fill, border)
        add(Frame:new{ dimen = Geom:new{ w = p.w - shadow, h = p.h - shadow },
            width = p.w - shadow, height = p.h - shadow, background = fill, color = BB.COLOR_BLACK,
            radius = 0, margin = 0, padding = 0, bordersize = border,
            Overlap:new{ dimen = Geom:new{ w = 1, h = 1 } } }, x, y)
    end
    frame(shadow, shadow, BB.COLOR_BLACK, 0); frame(0, 0, BB.COLOR_WHITE, math.max(1, math.floor(p.scale * 2)))
    local pet, reason = M.snapshot()
    card.pet = pet
    local c = p.companion
    label(pet and pet.name or "Silverfish", c.x, c.y, c.w, 24, true, 1)
    local reason_y = c.y + math.ceil(34 * p.scale)
    label(pet and pet.stage or reason, c.x, reason_y, c.w, 13, false,
        pet and 1 or math.max(1, math.floor((c.h - 34 * p.scale) / (13 * p.scale * 1.4))), BB.COLOR_DARK_GRAY)
    if pet then
        local sprite = Sprite:new{ pet = pet, w = p.pet.w, h = p.pet.h }
        add(Sources.moduleContainer(sprite, Overlap:new{ dimen = Geom:new{ w=1,h=1 } },
            p.pet.w, p.pet.h, BB.COLOR_WHITE), p.pet.x, p.pet.y)
    end
    local file = type(ctx.current_fp) == "string" and ctx.current_fp
        or type(ctx.recent_fps) == "table" and ctx.recent_fps[1]
    if type(file) == "string" and file ~= "" then
        card.file = file
        local ok, data = pcall(SH.getBookData, file, ctx.prefetched and ctx.prefetched[file], { skip_description = true })
        if not ok or type(data) ~= "table" then data = {} end
        local loaded, image = pcall(SH.getBookCover, file, p.cover.w, p.cover.h, false)
        if not loaded then image = nil end
        card.cover_done = image ~= nil
        if not image then
            loaded, image = pcall(SH.coverPlaceholder, data.title, data.authors, p.cover.w, p.cover.h, false)
            if not loaded then image = nil end
        end
        if image then add(image, p.cover.x, p.cover.y); card.cover_index = #group end
        local title_lines = p.book.h >= 170 * p.scale and 2 or 1
        local title_h = math.ceil(18 * p.scale * 1.4 * title_lines)
        label(text(data.title, _("Untitled")), p.book.x, p.book.y, p.book.w, 18, true, title_lines)
        local author_y = p.book.y + title_h + math.ceil(5 * p.scale)
        if p.book.h >= 105 * p.scale then
            label(text(data.authors, ""), p.book.x, author_y, p.book.w, 13, false, 1, BB.COLOR_DARK_GRAY)
        end
        local percent = require("core/orbitui_dashboard").fraction(data.percent)
        local bottom = p.book.y + p.book.h
        local bar_y = bottom - math.ceil((pet and 29 or 8) * p.scale)
        local percent_y = bar_y - math.ceil(24 * p.scale)
        if percent_y >= author_y then
            label(SH.pctStr(percent), p.book.x, percent_y, p.book.w, 14, true, 1)
            add(UI.progressBar(p.book.w, percent, math.max(1, math.floor(4 * p.scale)), BB.COLOR_BLACK, BB.COLOR_LIGHT_GRAY),
                p.book.x, bar_y)
        end
    else
        label(_("No books to show yet."), p.book.x, p.book.y, p.book.w, 15, false, 2)
    end
    if pet then
        label(string.format(_("Days: %s · Books: %s · Gen: %s"), pet.days or "—", pet.finished or "—", pet.generation),
            p.book.x, p.book.y + p.book.h - math.ceil(17 * p.scale), p.book.w, 11, false, 1, BB.COLOR_DARK_GRAY)
    end
    card.ges_events = { ReadingPetTap = { require("ui/gesturerange"):new{ ges = "tap", range = function() return card.dimen end } } }
    if ctx.orbitui_dashboard_hosted then return card end
    local wrapper = Sources.moduleContainer(card, Overlap:new{ dimen=Geom:new{w=1,h=1} }, p.w, p.h, BB.COLOR_WHITE)
    wrapper.orbitui_reading_pet = card
    return wrapper
end

function M.updateCovers(widget, ctx)
    local card = widget.orbitui_reading_pet or widget
    -- Native Home's contract is (all_done, changed), not just changed.
    if card.disposed or not card.file or not card.cover_index or card.cover_done then return true, false end
    local current = ctx.current_fp or ctx.recent_fps and ctx.recent_fps[1]
    if current ~= card.file then return true, false end
    local r = card.plan.cover
    local ok, image = pcall(require("modules/module_books_shared").getBookCover, card.file, r.w, r.h, false)
    if not ok then return true, false end
    if not image then
        local config = package.loaded["infra/sui_config"]
        card.cover_done = config and type(config.isCoverMissing) == "function" and config.isCoverMissing(card.file) or false
        return card.cover_done, false
    end
    local old = card.group[card.cover_index]
    image.overlap_offset = { r.x, r.y }; card.group[card.cover_index] = image
    if old ~= image then old:free() end
    card.cover_done = true
    return true, true
end

function M.install(registry)
    if type(registry.register) ~= "function" or registry._orbitui_reading_pet then return end
    registry._orbitui_reading_pet = true
    registry.register(M)
end
return M
