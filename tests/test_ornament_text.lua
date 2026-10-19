package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local Text = require("core/orbitui_ornament_text")
local record = { info = "original", info_source = "original", info_en = "English", info_sv = "Svenska" }

H.test("Swedish locales choose Swedish; all other settings fall back to English", function()
    for _, language in ipairs({ "sv", "sv_SE", "sv-SE", "SV_se" }) do
        H.eq(Text.resolve(record, language), "Svenska")
    end
    for _, language in ipairs({ "en", "en_GB", "de", "ja", "fr", "", "svx", false, 2 }) do
        H.eq(Text.resolve(record, language), "English")
    end
    H.eq(Text.resolve(record), "English")
end)
H.test("missing translations fall back without hiding native or custom captions", function()
    H.eq(Text.resolve({ info = "original", info_source = "original", info_en = "English" }, "sv"), "English")
    H.eq(Text.resolve({ info = "original", info_source = "original", info_sv = {} }), "original")
    H.eq(Text.resolve({ info = "original" }), "original")
    H.eq(Text.resolve({}), nil)
    local edited = { info = "My notes", info_source = "original", info_en = "English", info_sv = "Svenska" }
    H.eq(Text.resolve(edited, "en"), "My notes")
    edited.info = ""
    H.eq(Text.resolve(edited, "sv"), "")
end)

package.loaded.logger = { warn = function() end }
package.loaded["ui/widget/widget"] = { extend = function(_, t) return t end }
local O = dofile("components/bookshelf/lib/bookshelf_ornaments.lua")
H.test("native layer precedence resolves the language within the winning caption only", function()
    local e = { name = "Pack/A.png", lookup = { "Pack/A.png", "A.png" }, _reader_at = 1 }
    local layers = { {}, { ["A.png"] = record } }
    O._applyLayers(e, layers); H.eq(e.info, "original")
    O.resolveInfo = function(r) return Text.resolve(r, "en") end
    O._applyLayers(e, layers); H.eq(e.info, "English")
    layers[1][e.name] = { scale = 1.2 }
    O._applyLayers(e, layers); H.eq(e.info, "English"); H.eq(e.scale, 1.2)
    O.resolveInfo = function(r) return Text.resolve(r, "sv") end
    O._applyLayers(e, layers); H.eq(e.info, "Svenska")
    layers[1][e.name].info = "Reader's notes"
    O._applyLayers(e, layers); H.eq(e.info, "Reader's notes")
end)
H.finish()
