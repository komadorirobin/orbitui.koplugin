local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local f = assert(io.open(root .. "/components/bookshelf/lib/bookshelf_library_modal.lua"))
local source = f:read("*a"); f:close()
local body = assert(source:match("(function LibraryModal:_renderTitleBar%b().-\nend)\n"))
local W = H.widget()
function W:getSize()
    if self.dimen then return self.dimen end
    if self.text then return {w=math.min(#self.text * 10, self.max_width or math.huge),h=26} end
    if self.width then return {w=self.width,h=self.height or 26} end
    local w,h=0,0
    for _,child in ipairs(self) do local d=child:getSize(); w=w+d.w; h=math.max(h,d.h) end
    return {w=w,h=h}
end
function W:setMaxWidth(width) self.max_width=width end
local LibraryModal={}
local env=setmetatable({LibraryModal=LibraryModal, Space={px=function(n) return n end},
    BFont={getFace=function() return {},true end}, Geom=W, VerticalGroup=W,
    HorizontalSpan=W, Blitbuffer={COLOR_BLACK=0},
    Device={screen={scaleBySize=function(_,n) return n end}},
    require=function(name)
        if name=="ui/font" then return {} end
        return W
    end}, {__index=_G})
if setfenv then setfenv(assert(loadstring(body)),env)()
else assert(load(body,"modal title bounds","t",env))() end
local function render(title,width,tabs,close)
    local modal=setmetatable({config={title=title,tabs=tabs and {true} or nil}}, {__index=LibraryModal})
    function modal:_renderTabSegments() return W:new{width=tabs} end
    function modal:_closeOnlyAction() return close and {on_tap=function() end} end
    local bar=modal:_renderTitleBar(width,width+20)
    local row=bar[1]
    local left,right=row[1],row[2]
    assert(left[1]:getSize().w<=left.dimen.w,"title glyphs escape their reserved column")
    assert(left.dimen.w+right:getSize().w<=width,"header columns exceed the content width")
    return left[1],left,right
end
H.test("long multilingual library/tag titles are bounded before the tab controls",function()
    local title,left=render("Liknande böcker och serier: "..string.rep("Lång serietitel ÅÄÖ — ",30),500,210)
    H.eq(left.dimen.w,290); H.eq(title.max_width,282)
    assert(title:getSize().w<left.dimen.w)
end)
H.test("a short title keeps its native text and the header height",function()
    local title,left=render("Tags",500,200)
    H.eq(title.text,"Tags"); H.eq(title:getSize().w,40); H.eq(left.dimen.h,42)
end)
H.test("the close-only icon is included in the reserved right-hand width",function()
    local title,left,right=render(string.rep("Title ",100),500,150,true)
    H.eq(right:getSize().w,186); H.eq(left.dimen.w,314); H.eq(title.max_width,306)
end)
H.test("narrow headers retain a positive title bound and a gap before their controls",function()
    local title,left=render(string.rep("Title ",100),190,170)
    H.eq(left.dimen.w,20); H.eq(title.max_width,12)
end)
H.finish()
