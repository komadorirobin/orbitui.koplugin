package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local OTA = require("core/orbitui_ota")
local HTTP = require("core/orbitui_http")
local function release(version, preview)
    local base = "https://github.com/" .. OTA.REPO .. "/releases/download/v" .. version .. "/"
    return { tag_name = "v" .. version, prerelease = preview, assets = {
        { name = OTA.ASSET, browser_download_url = base .. OTA.ASSET, size = 4096 },
        { name = OTA.ASSET .. ".sha256", browser_download_url = base .. OTA.ASSET .. ".sha256", size = 88 },
    } }
end
H.test("semantic versions order alpha beta rc and stable correctly", function()
    assert(OTA.newer("0.1.0-alpha.10", "0.1.0-alpha.2"))
    assert(OTA.newer("0.1.0-beta.1", "0.1.0-alpha.99"))
    assert(OTA.newer("0.1.0-rc.1", "0.1.0-beta.9"))
    assert(OTA.newer("0.1.0", "0.1.0-rc.99"))
    assert(not OTA.newer("0.1.0-alpha.2", "0.1.0"))
    assert(not OTA.newer("0.1.0", "0.1.0"))
    assert(not OTA.version("1.2.3-injected/path"))
end)
H.test("preview channel finds prereleases but stable channel never downgrades to one", function()
    local list = { release("0.1.0-alpha.10", true), release("0.1.0-alpha.2", true) }
    H.eq(OTA.select(list, true).version, "0.1.0-alpha.10")
    H.eq(OTA.select(list, false), nil)
    list[#list + 1] = release("0.1.0", false)
    H.eq(OTA.select(list, true).version, "0.1.0")
    H.eq(OTA.select(list, false).version, "0.1.0")
    list[#list + 1] = release("0.2.0", false)
    list[#list].draft = true
    H.eq(OTA.select(list, true).version, "0.1.0")
end)
H.test("newest release without required assets fails rather than pretending up to date", function()
    local latest = release("0.2.0", false)
    latest.assets = {}
    assert(not pcall(OTA.select, { release("0.1.0", false), latest }, false))
end)
H.test("release assets must belong to the exact OrbitUI release", function()
    local value = release("0.1.0", false)
    value.assets[1].browser_download_url = "https://github.com/other/repo/releases/download/v0.1.0/orbitui.koplugin.zip"
    assert(not pcall(OTA.select, { value }, true))
end)
H.test("archive paths cannot traverse or create hidden/nested plugins", function()
    for _, path in ipairs({ "../x", "core/../../x", "/root/x", "x\\evil", "x/./y", "x//y",
        "x:y", "x\0y", ".orbitui-active", "components/x.koplugin/main.lua", "x./y" }) do
        assert(not OTA.safePath(path), path)
    end
    assert(OTA.safePath("components/simpleui/icons/Book.svg"))
end)
H.test("TLS URLs and wildcard hostname matching are strict", function()
    H.eq(HTTP.host("https://api.github.com/repos/x/y"), "api.github.com")
    for _, url in ipairs({ "http://github.com/x", "https://github.com.evil/x", "https://github.com@evil/x", "https://evil/x" }) do
        assert(not pcall(HTTP.host, url))
    end
    assert(HTTP.matchesHost("*.githubusercontent.com", "release-assets.githubusercontent.com"))
    assert(not HTTP.matchesHost("*.githubusercontent.com", "a.b.githubusercontent.com"))
    assert(not HTTP.matchesHost("*.githubusercontent.com", "githubusercontent.com"))
    assert(not HTTP.matchesHost("github.com\0.evil", "github.com"))
end)

local base = os.tmpname()
os.remove(base)
assert(os.execute("mkdir -p " .. base))
local entries, extraction_error, closed
package.loaded["ffi/archiver"] = { Reader = { new = function()
    local arc = { index = 0 }
    function arc:open() return true end
    function arc:iterate()
        return function()
            self.index = self.index + 1
            if not entries[self.index] then self.err = extraction_error end
            return entries[self.index]
        end
    end
    function arc:extractToMemory() return entries[self.index].data end
    function arc:close() closed = true end
    return arc
end } }
H.test("extractor writes bytes without calling archive filesystem extraction", function()
    entries = { { path = "orbitui.koplugin/VERSION", mode = "file", size = 3, data = "abc" } }
    closed = false
    H.eq(OTA.extract("unused", base)[1], "VERSION")
    assert(closed)
    H.eq(require("orbitui_bootstrap").read(base .. "/VERSION"), "abc")
end)
H.test("extractor rejects symlinks duplicates short reads and wrong roots", function()
    for _, invalid in ipairs({
        {{ path = "orbitui.koplugin/x", mode = "link", size = 0 }},
        {{ path = "other.koplugin/x", mode = "file", size = 0, data = "" }},
        {{ path = "orbitui.koplugin/../x", mode = "file", size = 0, data = "" }},
        {{ path = "orbitui.koplugin/x", mode = "file", size = 4, data = "abc" }},
        {{ path = "orbitui.koplugin/x", mode = "file", size = 0, data = "" },
         { path = "orbitui.koplugin/X", mode = "file", size = 0, data = "" }},
    }) do
        entries, closed = invalid, false
        assert(not pcall(OTA.extract, "unused", base))
        assert(closed)
    end
end)
H.test("late archive errors are not lost when the reader closes", function()
    entries, extraction_error, closed = {}, "broken archive", false
    assert(not pcall(OTA.extract, "unused", base))
    assert(closed)
    extraction_error = nil
end)
assert(os.execute("rm -rf " .. base))
H.finish()
