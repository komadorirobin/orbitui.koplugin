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
function M.plan(w, h, dpi, measured_title_h)
    w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
    -- Three visual anchors: full-height creature, one coherent text stack,
    -- right-aligned cover. Typography follows density, never the row's height.
    local scale = math.min(w / 618, finite(dpi) and dpi > 0 and dpi or 1)
    local pad = math.max(1, math.floor(12 * scale))
    local shadow = math.max(1, math.ceil(5 * scale))
    local body_h = math.max(1, h - 2 * pad - shadow)
    local cover_w = math.max(1, math.floor(math.min(w * .22, body_h * 2 / 3)))
    local cover_h = math.max(1, math.floor(cover_w * 3 / 2))
    local cover_x = w - pad - shadow - cover_w
    local pet_w = math.max(1, math.floor(w * .24))
    local tx = 2 * pad + pet_w
    local tw = math.max(1, cover_x - pad - tx)
    local function rect(x, y, width, height)
        x, y = math.max(0, math.min(w - 1, x)), math.max(0, math.min(h - 1, y))
        return { x = x, y = y, w = math.max(1, math.min(w - x, width)), h = math.max(1, math.min(h - y, height)) }
    end
    local function line(size, count) return math.ceil(math.max(7, size * scale) * 1.4 * (count or 1)) end
    local gap, small_gap = math.max(1, math.ceil(6 * scale)), math.max(1, math.ceil(4 * scale))
    local header_h, author_h, footer_h = line(18), line(14), line(14)
    local bar_h = math.max(1, math.ceil(4 * scale))
    if header_h + line(22) + author_h + footer_h + bar_h + 2 * gap + 2 * small_gap > body_h then gap = small_gap end
    local show_header = header_h + line(22) + footer_h + bar_h + 2 * gap + small_gap <= body_h
    if not show_header then header_h = 0 end
    local fixed = (show_header and header_h + gap or 0) + gap + small_gap + footer_h + bar_h
    local show_author = fixed + line(22) + small_gap + author_h <= body_h
    if not show_author then author_h = 0 end
    if show_author then fixed = fixed + small_gap + author_h end
    local title_lines = fixed + line(22, 2) <= body_h and 2 or 1
    local title_h = line(22, title_lines)
    if finite(measured_title_h) and measured_title_h > 0 then
        title_h = math.max(1, math.min(title_h, math.ceil(measured_title_h)))
    end
    local stack_h = fixed + title_h
    local y = pad + math.max(0, math.floor((body_h - stack_h) / 2))
    local p = { w = w, h = h, scale = scale, pad = pad,
        readable = w >= 120 and stack_h <= body_h,
        cover = rect(cover_x, pad + math.floor((body_h - cover_h) / 2), cover_w, cover_h),
        pet = rect(pad, pad, pet_w, body_h),
        book = rect(tx, y, tw, math.min(body_h, stack_h)), title_lines = title_lines }
    if show_header then
        p.companion = rect(tx, y, tw, header_h)
        local name_w = math.floor(tw * .4)
        p.name = rect(tx, y, name_w, header_h)
        p.stage = rect(tx + name_w + small_gap, y + math.floor((header_h - line(13)) / 2),
            tw - name_w - small_gap, line(13))
        y = y + header_h + gap
    end
    p.title = rect(tx, y, tw, title_h)
    p.empty = rect(tx, y, tw, math.max(1, p.book.y + p.book.h - y))
    y = y + title_h
    if show_author then
        y = y + small_gap
        p.author = rect(tx, y, tw, author_h)
        y = y + author_h
    end
    y = y + gap
    local percent_w = math.max(1, math.ceil(48 * scale))
    p.percent = rect(tx, y, percent_w, footer_h)
    p.metrics = rect(tx + percent_w + gap, y + math.floor((footer_h - line(12)) / 2),
        tw - percent_w - gap, line(12))
    p.bar = rect(tx, y + footer_h + small_gap, tw, bar_h)
    return p
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
        local function hit(r) return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end
        if hit(self.plan.pet) or hit(self.plan.companion) then
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
    if not p.readable then
        return Sources.moduleContainer(nil, Overlap:new{dimen=Geom:new{w=1,h=1}}, p.w, p.h, BB.COLOR_WHITE)
    end
    local function newLabel(value, r, size, bold, lines, adjust)
        local pixels = math.max(7, size * p.scale)
        local face, is_bold = Style.getStyledFace(nil, pixels / dpi, bold and "bold" or "regular")
        return UI.makeTextBox({ text = value or "", face = face, bold = is_bold, padding = 0,
            fgcolor = BB.COLOR_BLACK, width = r.w, max_width = r.w,
            max_lines = lines or 1, height_adjust = adjust or false, height_overflow_show_ellipsis = true,
            height = r.h }, true)
    end
    local file = type(ctx.current_fp) == "string" and ctx.current_fp
        or type(ctx.recent_fps) == "table" and ctx.recent_fps[1]
    local data, title_widget = {}, nil
    if type(file) == "string" and file ~= "" then
        local ok, result = pcall(SH.getBookData, file, ctx.prefetched and ctx.prefetched[file], { skip_description = true })
        if ok and type(result) == "table" then data = result end
        -- Use the native text widget's measured height, not byte/character
        -- counts. Retain this very widget: no second shaping pass or resource.
        title_widget = newLabel(text(data.title, _("Untitled")), p.title, 22, true, p.title_lines, true)
        local measured, size = pcall(title_widget.getSize, title_widget)
        if measured and type(size) == "table" and finite(size.h) and size.h > 0 and size.h <= p.title.h then
            p = M.plan(w, h, dpi, size.h)
        else
            title_widget:free(); title_widget = nil
        end
    end
    local card = Card:new{ dimen = Geom:new{ w = p.w, h = p.h }, ctx = ctx, plan = p }
    local group = Overlap:new{ dimen = Geom:new{ w = p.w, h = p.h }, allow_mirroring = false }
    card[1], card.group = group, group
    local function add(child, x, y)
        child.overlap_offset = { x, y }; group[#group + 1] = child; return child
    end
    local function label(value, r, size, bold, lines)
        if not r then return end
        return add(newLabel(value, r, size, bold, lines), r.x, r.y)
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
    label(pet and pet.name or "Silverfish", p.name, 18, true)
    if pet then label(pet.stage, p.stage, 13)
    else label(reason, p.pet, 13, false, math.max(1, math.floor(p.pet.h / (13 * p.scale * 1.4)))) end
    if pet then
        local sprite = Sprite:new{ pet = pet, w = p.pet.w, h = p.pet.h }
        add(Sources.moduleContainer(sprite, Overlap:new{ dimen = Geom:new{ w=1,h=1 } },
            p.pet.w, p.pet.h, BB.COLOR_WHITE), p.pet.x, p.pet.y)
    end
    if type(file) == "string" and file ~= "" then
        card.file = file
        local loaded, image = pcall(SH.getBookCover, file, p.cover.w, p.cover.h, false)
        if not loaded then image = nil end
        card.cover_done = image ~= nil
        if not image then
            loaded, image = pcall(SH.coverPlaceholder, data.title, data.authors, p.cover.w, p.cover.h, false)
            if not loaded then image = nil end
        end
        if image then add(image, p.cover.x, p.cover.y); card.cover_index = #group end
        if title_widget then add(title_widget, p.title.x, p.title.y)
        else label(text(data.title, _("Untitled")), p.title, 22, true, p.title_lines) end
        label(text(data.authors, ""), p.author, 14)
        local percent = require("core/orbitui_dashboard").fraction(data.percent)
        label(SH.pctStr(percent), p.percent, 14, true)
        add(UI.progressBar(p.bar.w, percent, p.bar.h, BB.COLOR_BLACK, BB.COLOR_LIGHT_GRAY), p.bar.x, p.bar.y)
    else
        label(_("No books to show yet."), p.empty, 15, false, 2)
    end
    if pet then
        label(string.format(_("Days: %s · Books: %s · Gen: %s"), pet.days or "—", pet.finished or "—", pet.generation),
            p.metrics, 12)
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
