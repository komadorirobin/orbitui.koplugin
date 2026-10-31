-- Exercise the real view-page model/callbacks, without a native window.
return function(owner, draft)
    local src = assert(io.open("lib/bookshelf_chip_editor.lua")):read("*a")
    local body = assert(src:match("function Editor:_pickGroupDisplay%(draft, on_change, chrome%)\n(.-)\nend\n"))
    local spec, applied, refreshes = nil, 0, 0
    local Editor = {
        _menu = function(o) spec = o; return {refresh=function() refreshes=refreshes+1 end} end,
        _faceOutText = function() return "None" end,
        _capFirst = function(s) return s end,
    }
    local env = setmetatable({Editor=Editor, _=function(s) return s end,
        _highAnchor=function() end,
        TabModel={isShelves=function() return false end},
        ViewMode=require("lib/bookshelf_view_mode"),
        require=function(n)
            if n=="lib/bookshelf_ornaments" then return {FREQ_DEFAULT=1} end
            if n=="lib/bookshelf_stack_display" then return {} end
            if n=="lib/bookshelf_book_binding" then return package.loaded[n] or {label=function(s) return s end} end
            return require(n)
        end,
    }, {__index=_G})
    local fn = assert(load("return function(self,draft,on_change,chrome)\n"..body.."\nend", "view page", "t", env))()
    fn(owner or {}, draft, function() applied=applied+1 end)
    return {
        control=function(label)
            for _,b in ipairs(spec.page().blocks) do if b.label==label then return b end end
        end,
        applied=function() return applied end,
        refreshes=function() return refreshes end,
    }
end
