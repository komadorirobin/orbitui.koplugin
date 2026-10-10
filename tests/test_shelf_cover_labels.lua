package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local saved, flushes, pending = {}, 0, {}
package.loaded["lib/bookshelf_settings_store"] = {
    read = function(k) return saved[k] end,
    save = function(k, v) saved[k] = v end,
    delete = function(k) saved[k] = nil end,
    flush = function() flushes = flushes + 1 end,
}
package.loaded["ui/uimanager"] = {
    setDirty = function() end,
    show = function() end, close = function() end,
    scheduleIn = function(_, _, fn) pending[fn] = true end,
    unschedule = function(_, fn) pending[fn] = nil end,
}
package.loaded["lib/bookshelf_i18n"] = { gettext = function(t) return t end }
package.loaded["lib/bookshelf_settings"] = { _pickToken = function() end }
package.loaded["lib/bookshelf_book_repository"] = { dataGeneration = function() return 1 end }
package.loaded["lib/bookshelf_tokens"] = {
    BAR_PREVIEW = "<bar>",
    menuPreview = function(template, book)
        return (template:gsub("%%(%w+)", function(key) return book[key] or "" end))
    end,
}
package.loaded["lib/bookshelf_token_record"] = { wrap = function(book) return book end }
local edit
package.loaded["lib/bookshelf_line_editor"] = { edit = function(opts) edit = opts end }
local menu
package.loaded["lib/bookshelf_menu_host"] = {
    show = function(opts) menu = opts; return opts end,
    close = function(host) host.closed = true end,
}
local tabs = {
    {id="home", label="Home", source={kind="all"}, theme="washi", spine_cover_size_pct=120},
    {id="authors", label="Authors", source={kind="authors"}},
    {id="child", label="Child", parent="home", source={kind="folder"}},
}
package.loaded["lib/bookshelf_tab_model"] = {
    load = function() return tabs end,
    getById = function(id) for _, t in ipairs(tabs) do if t.id == id then return t end end end,
    save = function(t) tabs = t; flushes = flushes + 1 end,
}
local P = require("lib/bookshelf_profiles")
local M = require("adapters/orbitui_cover_labels")
local CL = require("lib/bookshelf_cover_label")
local function source(file)
    local f = assert(io.open(file)); local s = f:read("*a"); f:close(); return s
end
local widget_src = source("components/bookshelf/lib/bookshelf_widget.lua")
local function compile(code, env)
    setmetatable(env, {__index=_G})
    if setfenv then local f = assert(loadstring(code)); setfenv(f, env); return f end
    return assert(load(code, "cover labels", "t", env))
end
local function method(name)
    local args, body = widget_src:match("function BookshelfWidget:" .. name .. "%((.-)%)\n(.-)\nend")
    assert(body, name)
    return compile("return function(self" .. (args ~= "" and "," .. args or "") .. ")\n" .. body .. "\nend",
        { BookshelfSettings = package.loaded["lib/bookshelf_settings_store"] })()
end
local Class = { _gridLabelsKey = method("_gridLabelsKey"),
    _shelfLabelMode = method("_shelfLabelMode"), _gridDrawsLabels = method("_gridDrawsLabels"),
    _noteGridLabels = method("_noteGridLabels"), _groupLabelMode = function() return nil end,
    _groupDisplayMode = function() return "none" end,
    _rebuild = function(self) self.builds = (self.builds or 0) + 1 end,
    _selectChip = function(self, chip) self.chip = chip; self:_rebuild() end,
    _isSpineMode = function(self) return self.physical end,
}
package.loaded["lib/bookshelf_stack_display"] = {
    resolve = function(mode) return mode end,
    anyExternalLabel = function(items, _, labels) return #items > 0 and labels.books end,
}
M.widget(Class)
local function widget(chip, profile)
    return setmetatable({chip=chip or "home", profile=P.get(profile), physical=true}, {__index=Class})
end

H.test("untouched chips retain grid labels without adding bands to physical shelves", function()
    saved.expanded_shelf_label = "author"
    local w = widget()
    H.eq(w:_bookLabelMode(), "author"); H.eq(w:spineCoverLabel(), nil)
    H.eq(w:_shelfLabelMode(), "author")
    H.eq(next(saved, "expanded_shelf_label"), nil)
end)

H.test("native, child, Library and Manga chips keep independent modes and custom text", function()
    local before = flushes
    M.save("home", "title")
    M.save("child", "none")
    M.save("authors", "series")
    M.save("orbitui:prose:authors", "custom", {template="%title - %author", bold=true})
    M.save("orbitui:comics:authors", "none")
    H.eq(M.mode("home", true), "title"); H.eq(M.mode("child", true), "none")
    H.eq(M.mode("authors", true), "series")
    H.eq(M.mode("orbitui:prose:authors", true), "custom")
    H.eq(M.mode("orbitui:comics:authors", true), "none")
    H.eq(flushes, before + 5)
    H.eq(tabs[1].theme, "washi"); H.eq(tabs[1].spine_cover_size_pct, 120)
    H.eq(saved.expanded_shelf_label, "author"); H.eq(saved.expanded_shelf_label_custom, nil)
    package.loaded["lib/bookshelf_profiles"] = nil
    P = require("lib/bookshelf_profiles")
    H.eq(M.line("orbitui:prose:authors").template, "%title - %author")
    H.eq(M.line("orbitui:prose:authors").bold, true)
    H.eq(M.mode("orbitui:comics:authors", true), "none")
end)

H.test("profile updates preserve theme/layout and template when changing mode", function()
    local p = P.get("prose")
    local t = P.shelfSettings(p, "authors")
    t.theme, t.spine_cover_size_pct = "hinoki", 130
    P.saveShelfSettings(p, "authors", t)
    M.save("orbitui:prose:authors", "title")
    t = P.shelfSettings(p, "authors")
    H.eq(t.theme, "hinoki"); H.eq(t.spine_cover_size_pct, 130)
    H.eq(t.cover_label_custom.template, "%title - %author")
    local copy = M.line("orbitui:prose:authors"); copy.template = "mutated"
    H.eq(M.line("orbitui:prose:authors").template, "%title - %author")
    H.eq(M.save("missing", "title"), false)
    H.eq(M.save("home", "invalid"), false)
end)

H.test("native grid strip and label cache obey scoped modes, including after a drill", function()
    local w = widget()
    H.eq(w:_shelfLabelMode(), "title")
    local title_key = w:_gridLabelsKey()
    M.save("home", "none")
    assert(w:_gridLabelsKey() ~= title_key)
    H.eq(w:_noteGridLabels({{filepath="book"}}), false)
    H.eq(w:_shelfLabelMode(), nil)
    M.save("home", "custom", {template="%author"})
    H.eq(w:_noteGridLabels({{filepath="book"}}), true)
    H.eq(w:_shelfLabelMode(), "custom"); H.eq(w:_coverLabelLine().template, "%author")
    w._drilldown_path = {{kind="series", payload={name="A"}}}
    H.eq(w:_shelfLabelMode(), "custom")
    local prose, comics = widget("authors", "prose"), widget("authors", "comics")
    M.save(M.id(comics), "title")
    assert(prose:_gridLabelsKey() ~= comics:_gridLabelsKey())
end)

H.test("physical covers get the selected label; empty templates and group proxies get none", function()
    local w = widget()
    local book = {filepath="one.epub", title="A title", author="An author", series="A series"}
    for _, mode in ipairs({"title", "author", "series"}) do
        M.save("home", mode)
        H.eq(w:spineCoverLabel()(book).text, book[mode])
    end
    M.save("home", "custom", {template="%title / %author", bold=true})
    local resolve = w:spineCoverLabel()
    H.eq(resolve(book).text, "A title / An author"); H.eq(resolve(book).bold, true)
    H.eq(resolve({books={book}, filepath="group"}), nil)
    H.eq(resolve({filepath="folder", is_directory=true}), nil)
    H.eq(resolve({add_subshelf=true}), nil)
    M.save("home", "custom", {template=""})
    H.eq(w:spineCoverLabel()(book), nil)
    M.save("home", "none"); H.eq(w:spineCoverLabel(), nil)
end)

H.test("physical label choices also work before full metadata hydration", function()
    local w = widget()
    M.save("home", "title")
    H.eq(w:spineCoverLabel()({filepath="/books/Uncached title.epub"}).text,"Uncached title")
    M.save("home", "series")
    local book = {filepath="/books/one.epub", series_name="A series", series_num=2}
    H.eq(w:spineCoverLabel()(book).text,"A series #2")
    H.eq(w:spineCoverLabel()({filepath="/books/standalone.epub"}).text,"None")
    M.save("home", "author")
    H.eq(w:spineCoverLabel()({filepath="/books/one.epub", authors={"First", "Second"}}).text,"First, Second")
end)

H.test("custom editor debounces scoped previews and cancels without saving", function()
    local w = widget()
    M.save("home", "none")
    require("lib/bookshelf_cover_label_editor").show(w, nil, nil, false, M.editorTarget(w, "home"))
    local t = {template="draft %title"}
    edit.on_preview(t)
    assert(next(pending)); H.eq(w:_bookLabelMode(), "none")
    t.template = "changed after scheduling"
    for fn in pairs(pending) do pending[fn] = nil; fn() end
    H.eq(w:_bookLabelMode(), "custom")
    H.eq(w:_coverLabelLine().template, "draft %title")
    H.eq(w:spineCoverLabel()({filepath="x", title="A"}).text, "draft A")
    edit.on_cancel()
    H.eq(w:_bookLabelMode(), "none"); H.eq(w:spineCoverLabel(), nil)
    edit.on_preview({template="late"}); edit.on_cancel()
    H.eq(next(pending), nil); H.eq(M.mode("home", true), "none")
end)

H.test("saving a custom draft cannot leak across profiles or overwrite other edits", function()
    local w = widget("authors", "prose")
    local id = M.id(w)
    require("lib/bookshelf_cover_label_editor").show(w, nil, nil, false, M.editorTarget(w, id))
    edit.on_preview({template="new %title"})
    w.profile = P.get("comics")
    for fn in pairs(pending) do pending[fn] = nil; fn() end
    H.eq(w:_bookLabelMode(), "title")
    local values = P.shelfSettings(P.get("prose"), "authors")
    values.theme = "fresh-theme"
    P.saveShelfSettings(P.get("prose"), "authors", values)
    edit.on_save({template="saved %title", uppercase=true})
    H.eq(next(pending), nil); H.eq(w._orbitui_cover_label_preview, nil)
    H.eq(M.mode(id, true), "custom")
    H.eq(M.line(id).template, "saved %title")
    H.eq(P.shelfSettings(P.get("prose"), "authors").theme, "fresh-theme")
    H.eq(M.mode(M.id(w), true), "title")
    H.eq(saved.expanded_shelf_label_custom, nil)
end)

H.test("a late preview on another chip cannot reappear after Cancel", function()
    local w = widget()
    M.save("home", "none")
    require("lib/bookshelf_cover_label_editor").show(w, nil, nil, false, M.editorTarget(w, "home"))
    edit.on_preview({template="late draft"})
    w.chip = "child"
    for fn in pairs(pending) do pending[fn] = nil; fn() end
    edit.on_cancel()
    w.chip = "home"
    H.eq(w._orbitui_cover_label_preview, nil)
    H.eq(w:_bookLabelMode(), "none")
end)

H.test("chip menu edits the held chip, not the previously active chip", function()
    local w = widget()
    M.save("home", "none")
    M.show(w, "child")
    H.eq(w.chip, "child"); H.eq(#menu.item_table, 6)
    menu.item_table[1].callback()
    H.eq(M.mode("child", true), "title"); H.eq(M.mode("home", true), "none")
    H.eq(menu.item_table[1].checked_func(), true)
    menu.item_table[4].callback()
    H.eq(menu.closed, true)
    H.eq(edit.settings_module._bw, w)
    H.eq(type(edit.settings_module._pickToken), "function")
    edit.on_save({template="child text"})
    H.eq(M.mode("child", true), "custom")
end)

H.test("placement persists per native, nested and profile chip without changing content", function()
    H.eq(M.position("home"), "bottom")
    H.eq(M.position("missing"), "bottom")
    H.eq(M.savePosition("missing", "above"), false)
    H.eq(M.savePosition("home", "invalid"), false)
    local mode = M.mode("home", true)
    local template = M.line("child").template
    for _, id in ipairs({"home", "child", "orbitui:prose:authors"}) do
        H.eq(M.savePosition(id, "above"), true)
    end
    H.eq(M.position("authors"), "bottom")
    H.eq(M.position("orbitui:comics:authors"), "bottom")
    H.eq(M.mode("home", true), mode)
    H.eq(M.line("child").template, template)
    M.save("child", "title")
    H.eq(M.position("child"), "above")
    package.loaded["lib/bookshelf_profiles"] = nil
    P = require("lib/bookshelf_profiles")
    H.eq(M.position("orbitui:prose:authors"), "above")
    H.eq(P.shelfSettings(P.get("prose"), "authors").theme, "fresh-theme")
    local w = widget("authors", "prose")
    w._drilldown_path = {{kind="series", payload={name="Series"}}}
    H.eq(w:coverLabelPosition(), "above")
    w.profile = P.get("comics")
    H.eq(w:coverLabelPosition(), "bottom")
    for _, id in ipairs({"home", "child", "orbitui:prose:authors"}) do M.savePosition(id, "bottom") end
end)

H.test("placement menu applies to the held chip without enabling text or leaking after navigation", function()
    local w = widget()
    M.save("child", "none")
    M.show(w, "child")
    local choices = menu.item_table[6].sub_item_table_func()
    H.eq(#choices, 2); H.eq(choices[1].checked_func(), true)
    local builds = w.builds
    choices[2].callback()
    H.eq(w.builds, builds+1); H.eq(choices[2].checked_func(), true)
    H.eq(M.mode("child", true), "none"); H.eq(w:spineCoverLabel(), nil)
    w.chip = "home"
    builds = w.builds
    choices[1].callback()
    H.eq(w.builds, builds); H.eq(M.position("child"), "bottom")
end)

H.test("only the old global book-label row is removed, not group labels", function()
    local S = { _coverDisplaySubItems = function() return {
        {id="book_cover_label"}, {id="group_label"}, {id="progress"},
    } end }
    M.settings(S)
    local items = S:_coverDisplaySubItems()
    H.eq(#items, 2); H.eq(items[1].id, "group_label")
end)

local dpi, text_count, text_frees = 1, 0, 0
package.loaded["device"] = {screen={scaleBySize=function(_, n) return math.floor(n*dpi+.5) end}}
package.loaded["ffi/blitbuffer"] = {COLOR_WHITE="white", COLOR_BLACK="black"}
package.loaded["lib/bookshelf_fonts"] = {getFace=function(_, _, n, style) return n, style and style.bold end}
package.loaded["lib/bookshelf_colour_text"] = {new=function(_, opts)
    text_count = text_count + 1
    return {
        getSize = function() return {w=math.min(#opts.text*opts.face*dpi*.6, opts.max_width), h=math.ceil(opts.face*dpi*1.3)} end,
        paintTo = function(_, bb, x, y) bb.text = {x=x,y=y,opts=opts} end,
        free = function() text_frees = text_frees + 1 end,
    }
end}

H.test("physical labels stay inside the card at all DPI/sizes and clear progress", function()
    local Band = require("adapters/orbitui_cover_label_band")
    for _, d in ipairs({1, 2, 3}) do
        dpi = d
        for _, wh in ipairs({{20,20}, {55,80}, {120,180}, {250,350}}) do
            for _, progress in ipairs({false,true}) do
                local w, h = wh[1]*dpi, wh[2]*dpi
                local dimen = {w=w,h=h}
                local paints, frees, faded = 0, 0, 0
                local card = {border_size=dpi, fade_by=.4, getSize=function() return dimen end,
                    paintTo=function(_, _, x, y) paints=paints+1; dimen.x=x; dimen.y=y end,
                    free=function() frees=frees+1 end}
                local bb = {
                    paintRect=function(_, x,y,bw,bh,color)
                        assert(paints > 0)
                        assert(x>=10+dpi and x+bw<=10+w-dpi)
                        assert(y>=20+dpi and y+bh<=20+h-dpi-(progress and 14*dpi or 0))
                        H.eq(color,"black")
                    end,
                    lightenRect=function(_, _,_,_,_,amount) H.eq(amount,.4); faded=faded+1 end,
                }
                local made, freed = text_count, text_frees
                Band.decorate(card, {text=string.rep("Long title ", 30), bold=true}, progress)
                card:paintTo(bb,10,20)
                H.eq(card:getSize(),dimen); H.eq(dimen.x,10); H.eq(dimen.y,20)
                H.eq(paints,1)
                if wh[1]>20 then assert(bb.text); H.eq(faded,1) end
                card:free(); H.eq(frees,1)
                H.eq(text_count-made,text_frees-freed)
            end
        end
    end
    dpi = 1
end)

H.test("only opted-in physical cards are decorated, before native badges", function()
    local seen = 0
    local S = { _renderShadowedCard=function(_, c) seen=seen+1; return c end }
    M.cover(S)
    local function card() return {getSize=function() return {w=100,h=150} end,
        paintTo=function() end, free=function() end} end
    local w = setmetatable({cover_label={text="Title"}, _statusIndicators=function() return {bar=true} end}, {__index=S})
    local plain = card(); local paint = plain.paintTo
    w:_renderShadowedCard(plain); H.eq(plain.paintTo,paint)
    w.spine_face_out = true
    local c = card(); paint=c.paintTo; w._cover_card=c
    H.eq(w:_renderShadowedCard(c),c); assert(c.paintTo~=paint)
    H.eq(w._cover_card,c); H.eq(seen,2); c:free()
    w.cover_label.position = "above"
    c = card(); paint=c.paintTo
    H.eq(w:_renderShadowedCard(c),c); H.eq(c.paintTo,paint)
end)

local function primitive(_, o) return o end
local Geom = {new=primitive}
local Input = {new=function(_, o)
    function o:getSize() return self.dimen end
    function o:free() for _, child in ipairs(self) do if child.free then child:free() end end end
    return o
end}
local Group = {new=function(_, o)
    function o:getSize()
        local w, h = 0, 0
        for _, child in ipairs(self) do local s=child:getSize(); w=math.max(w,s.w); h=h+s.h end
        return {w=w,h=h}
    end
    function o:free() for _, child in ipairs(self) do if child.free then child:free() end end end
    return o
end}
local Span = {new=function(_, o) return {getSize=function() return {w=0,h=o.width} end} end}
package.loaded["ui/geometry"] = Geom
package.loaded["ui/gesturerange"] = {new=primitive}
package.loaded["ui/widget/container/inputcontainer"] = Input
package.loaded["ui/widget/verticalgroup"] = Group
package.loaded["ui/widget/verticalspan"] = Span

H.test("above-label geometry uses headroom, bounds shrinking and releases its text", function()
    local Above = require("adapters/orbitui_cover_label_above")
    for _, d in ipairs({1,2,3}) do
        dpi = d
        for _, scale in ipairs({50,100,200}) do
            saved.expanded_shelf_font_scale = scale
            for _, dims in ipairs({{20,20}, {55,80}, {120,180}, {250,350}}) do
                for _, slack in ipairs({0,50}) do
                    local w,h = dims[1]*d,dims[2]*d
                    local made,freed = text_count,text_frees
                    local label,ch = Above.new({text=string.rep("Long title ",40),bold=true},w,h+slack*d,h)
                    if label then
                        local s = label:getSize()
                        assert(ch>0 and ch<=h and ch+s.h<=h+slack*d)
                        if slack>0 then H.eq(ch,h) end
                        label.cover = {_cover_card={fade_by=.4}}
                        local bb = {paintRect=function(_,x,y,rw,rh)
                            H.eq(x,10); H.eq(y,20); H.eq(rw,w); H.eq(rh,s.h-3*d)
                        end, lightenRect=function(_,x,y,rw,rh,amount) H.eq(amount,.4) end}
                        label:paintTo(bb,10,20)
                        assert(bb.text and bb.text.opts.bold)
                        assert(bb.text.x>=10 and bb.text.y>=20)
                        H.eq(label.ges_events.Tap[1].range.x,10)
                        label:free()
                    else H.eq(ch,h) end
                    H.eq(text_count-made,text_frees-freed)
                end
            end
        end
    end
    dpi=1; saved.expanded_shelf_font_scale=nil
end)

H.test("above labels share the cover's tap, hold and opening target", function()
    M.save("home", "title"); M.savePosition("home", "above")
    local w = widget()
    local resolve = w:spineCoverLabel()
    H.eq(resolve({filepath="group",books={}}),nil)
    local spec = resolve({filepath="book",title="Title"})
    H.eq(spec.position,"above")
    local label = spec:above(100,180,150)
    local tapped,held,opened = 0,0,0
    label.cover = {
        onTap=function(self,_,ges) tapped=tapped+1; H.eq(self,label.cover); H.eq(ges,"tap"); return true end,
        onHold=function(self) held=held+1; H.eq(self,label.cover); return true end,
        onDoubleTap=function(self) opened=opened+1; H.eq(self,label.cover); return true end,
    }
    H.eq(label:onTap(nil,"tap"),true); H.eq(label:onHold(),true); H.eq(label:onDoubleTap(),true)
    H.eq(tapped,1); H.eq(held,1); H.eq(opened,1)
    label:free()
    M.savePosition("home","bottom")
end)

H.test("native physical row puts the label above the page block without moving the foot", function()
    local src = source("components/bookshelf/lib/bookshelf_spine_shelf.lua")
    local body = assert(src:match("elseif not tile and e.face_out then(.-)\n            end\n            if _tile_t0"))
    local block = {new=function(_,o) o.getSize=function(self) return self.dimen end; return o end}
    package.loaded["lib/bookshelf_spine_widget"] = {new=function(_,o)
        o.dimen={w=o.width,h=o.height}; o.getSize=function(self) return self.dimen end
        return o
    end}
    local render = compile("return function(e, opts, is_sel)\n"
        .."local stand_h,inset,b,fh,surf = 200,5,10,4,16\nlocal tile,fx_here\n"..body
        .."\nreturn tile, fx_here end", {
            Screen=package.loaded["device"].screen, Space={px=function(n) return n end}, Geom=Geom,
            SpineShelf={plankLift=function() return 20 end}, FaceOutTopBlock=block,
            OverlapGroup=block, FaceOutFeet=block, LiftShadow=block,
        })()
    local columns = compile("local SpineShelf={}\n" .. assert(src:match(
        "(function SpineShelf.recessColumns.-)\n%-%- paintShadowAssets"))
        .. "\nreturn SpineShelf.recessColumns",{})()
    for _, selected in ipairs({false,true}) do
        for _, h in ipairs({100,190}) do
            local function entry() return {w=100,h=195,face_h=h,depth=5,face_out=true,book={filepath="x"}} end
            local plain,fx = render(entry(),{},selected)
            local e=entry()
            local labelled = render(e,{cover_label=function() return {
                text="Title",above=require("adapters/orbitui_cover_label_above").new,position="above"}
            end},selected)
            H.eq(labelled:getSize().h,plain:getSize().h)
            local label, label_y, cover_y, cover, y = nil,nil,nil,nil,0
            for _, child in ipairs(labelled) do
                if child.cover then label=child; label_y=y end
                if child[1] and child[1].spine_face_out then cover=child[1]; cover_y=y end
                y=y+child:getSize().h
            end
            assert(label and cover); H.eq(label.cover,cover)
            H.eq(label_y+label:getSize().h+5,cover_y)
            H.eq(e._drawn_h,cover.height+5)
            local original_h = math.min(h,190)
            if selected and original_h+26>195 then original_h=169 end
            H.eq(cover.width,math.floor(100*cover.height/original_h))
            local col=columns(e,30,5)[1]
            H.eq(col.w,cover.width); H.eq(col.x,30+math.floor((100-cover.width)/2))
            H.eq(col.h,cover.height+5)
            H.eq(cover_y+cover.height,195-(selected and 21 or 0))
            H.eq(cover.faceout_fx.below,fx.below)
            assert(label_y>=0); label:free()
        end
    end
end)

H.test("grid and expanded slots reorder the same strip above the cover, including true aspect", function()
    local row_src = source("components/bookshelf/lib/bookshelf_shelf_row.lua")
    local body = assert(row_src:match("(local slot_dimen = Geom:new.-row%[#row %+ 1%] = slot)"))
    local SW = {repaintOverhangGlyphs=function() error("Above label must not repaint bottom glyphs") end}
    local render = compile("return function(position, spine_h, title, fallback)\n"
        .."local opts={label_position=position}; local item={filepath='book'}\n"
        .."local slot_w,slot_h,cover_h,label_gap,title_block_h = 100,180,156,4,24\n"
        .."local spine={is_fallback=fallback,getSize=function() return {w=100,h=spine_h} end}\n"
        .."local row={}; local true_aspect,draw_label=true,true\n"
        .."local function _labelFor() return title end\n"
        .."local function plated(w) return w end\nlocal function plateTextWidth(w) return w end\n"
        ..body.."\nreturn row[1],spine end",{
            Geom=Geom,VerticalGroup=Group,VerticalSpan=Span,InputContainer=Input,SpineWidget=SW,
            GestureRange={new=primitive}, TextWidget={new=function(_,o)
                o.getSize=function() return {w=90,h=20} end; return o end},
        })()
    for _, h in ipairs({100,156}) do
        for _, title in ipairs({"Title",""}) do
            for _, fallback in ipairs({false,true}) do
                for _, pos in ipairs({"above","bottom"}) do
                    local slot,spine = render(pos,h,title,fallback)
                    H.eq(slot[1]:getSize().h,180)
                    local y,cover_y,label_y=0,nil,nil
                    for _, child in ipairs(slot[1]) do
                        if child==spine then cover_y=y elseif child.text then label_y=y end
                        y=y+child:getSize().h
                    end
                    H.eq(cover_y+h,pos=="above" and 180 or 156)
                    if title~="" and not fallback then
                        assert(label_y); H.eq(pos=="above",label_y<cover_y)
                    else H.eq(label_y,nil) end
                    slot:onTap(); H.eq(SW.last_tapped,spine)
                    slot:onDoubleTap(); H.eq(SW.last_tapped,spine)
                end
            end
        end
    end
end)

H.test("native seams route labels only to face-outs; series boxes retain their own labels", function()
    local row = source("components/bookshelf/lib/bookshelf_spine_shelf.lua")
    assert(row:find("local cover_label = opts.cover_label and opts.cover_label(e.book)",1,true))
    assert(row:find("elseif not tile and e.face_out then",1,true))
    assert(widget_src:find("local cover_label = self.spineCoverLabel and self:spineCoverLabel()",1,true))
    assert(widget_src:find("label_position    = self.coverLabelPosition and self:coverLabelPosition()",1,true))
    local hold = source("adapters/orbitui_home_shelves.lua")
    assert(hold:find('require("adapters/orbitui_cover_labels").show(widget, chip)',1,true))
    local UI = require("adapters/orbitui_ui")
    H.eq(UI.modules["lib/bookshelf_settings"],true)
    H.eq(UI.modules["lib/bookshelf_spine_widget"],true)
    G_reader_settings = {readSetting=function() return "sv_SE" end}
    H.eq(require("core/orbitui_i18n")("Cover text"),"Omslagstext")
    H.eq(require("core/orbitui_i18n")("Above the cover"),"Ovanför omslaget")
end)

H.finish()
