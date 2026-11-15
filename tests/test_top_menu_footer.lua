local H = require("tests/helpers")
local Navbar = require("adapters/orbitui_navbar")
local value, mirrored = nil, false
package.loaded["ui/bidi"] = { mirroredUILayout = function() return mirrored end }
package.loaded["ui/size"] = { span = { horizontal_default = 8 } }
package.loaded["infra/sui_store"] = {
    readSetting = function() return value end,
    saveSetting = function(_, key, visible)
        H.eq(key, "simpleui_orbitui_top_menu_status")
        value = visible
    end,
}

local function widget(width)
    return {
        w = width,
        getSize = function(self) return { w = self.w, h = 20 } end,
        paintTo = function(self, _, x, y) self.x, self.y = x, y end,
    }
end

local function fixture()
    value, mirrored = nil, false
    local back, pages, status = widget(50), widget(0), widget(108)
    local page_text = widget(110)
    function page_text:setMaxWidth(w) self.max_width = w end
    function pages:getSize() return { w = 60 + math.min(page_text.w, page_text.max_width), h = 20 } end
    function pages:resetLayout() end
    local footer = widget(340)
    local function container(child, token)
        return { child, handleEvent = function(_, event) return event == token end }
    end
    footer[1], footer[2], footer[3] = container(back, "back"), container(pages, "next"), container(status, "date")
    local menu = { footer = footer, page_num = 4, page_info_text = page_text,
        page_info = pages, device_info = status, page_info_left_chev = widget(30), page_info_right_chev = widget(30) }
    Navbar.adaptTopMenuFooter(menu)
    local paint = footer.paintTo
    Navbar.adaptTopMenuFooter(menu)
    H.eq(footer.paintTo, paint)
    local function repaint()
        back.x, pages.x, status.x = nil, nil, nil
        footer:paintTo(nil, 0, 0)
    end
    return menu, back, pages, status, repaint
end

H.test("pagination moves off center far enough to keep a gap from visible status in both directions", function()
    local menu, back, pages, status, repaint = fixture()
    menu.footer.w = 350
    repaint()
    H.eq(back.x, 0); H.eq(pages.x, 64)
    H.eq(status.x, 242)
    mirrored = true
    repaint()
    H.eq(back.x, 300); H.eq(pages.x, 116); H.eq(status.x, 0)
end)

H.test("status yields to pagination on narrow screens and returns on a single-page tab", function()
    local menu, _, pages, status, repaint = fixture()
    menu.footer.w = 245
    repaint()
    H.eq(pages.x, 58); H.eq(status.x, nil)
    assert(menu.footer:propagateEvent("next"))
    assert(not menu.footer:propagateEvent("date"))
    menu.page_num = 1
    repaint()
    H.eq(pages.x, nil); H.eq(status.x, 137)
    assert(menu.footer:propagateEvent("date"))
    assert(not menu.footer:propagateEvent("next"))
end)

H.test("turning off the clock and battery removes the date hit target", function()
    local menu, _, pages, status, repaint = fixture()
    menu.footer.w = 380
    local toggle = Navbar.quickControlsItems()[3]
    assert(toggle.checked_func())
    repaint()
    assert(menu.footer:propagateEvent("date"))
    toggle.callback()
    H.eq(toggle.checked_func(), false)
    repaint()
    H.eq(pages.x, 105); H.eq(status.x, nil)
    assert(menu.footer:propagateEvent("back"))
    assert(menu.footer:propagateEvent("next"))
    assert(not menu.footer:propagateEvent("date"))
    toggle.callback()
    repaint()
    assert(menu.footer:propagateEvent("date"))
end)

H.test("a very wide translated page label is bounded by the arrows and the back control", function()
    local menu, _, pages, status, repaint = fixture()
    menu.page_info_text.w = 700
    repaint()
    H.eq(pages.x, 58); H.eq(status.x, nil)
    H.eq(pages.x + pages:getSize().w, 340)
end)

H.finish()
