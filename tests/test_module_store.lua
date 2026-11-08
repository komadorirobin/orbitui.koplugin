local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end
local files, directories, links, fail_save, rename_fail = {}, {}, {}, false, false
local function digest(s)
    local n = 5381; for i = 1, #s do n = (n * 33 + s:byte(i)) % 4294967296 end
    return string.rep(string.format("%08x", n), 8)
end
local F = {}
function F.attr(path)
    if links[path] then return { mode = "link" } end
    if files[path] then return { mode = "file", size = #files[path].content } end
    if directories[path] then return { mode = "directory" } end
    for key in pairs(files) do if key:sub(1, #path + 1) == path .. "/" then return { mode = "directory" } end end
end
function F.mkdir(path) assert(not F.attr(path) or F.attr(path).mode == "directory"); directories[path] = true end
function F.read(path) return files[path] and files[path].content end
function F.write(path, value) files[path] = { content = value } end
function F.json(path, optional)
    if not files[path] and optional then return nil end
    return copy(assert(files[path], path).json)
end
function F.save(path, value)
    if fail_save and path:match("installed%.json$") then error("disk full") end
    files[path] = { content = "json", json = copy(value) }
end
function F.remove(path)
    for _, t in ipairs({files, directories, links}) do
        for key in pairs(t) do if key == path or key:sub(1, #path + 1) == path .. "/" then t[key] = nil end end
    end
end
function F.walk(path)
    local out = {}
    for key in pairs(files) do if key:sub(1, #path + 1) == path .. "/" then out[#out + 1] = key:sub(#path + 2) end end
    for key in pairs(links) do assert(key:sub(1, #path + 1) ~= path .. "/", "link") end
    return out
end
package.loaded["core/orbitui_addon_files"] = F
package.loaded["libs/libkoreader-lfs"] = { dir = function(path)
    local names, seen = {}, {}
    for _, t in ipairs({files, directories, links}) do
        for key in pairs(t) do
            if key:sub(1, #path + 1) == path .. "/" then
                local name = key:sub(#path + 2):match("^[^/]+")
                if not seen[name] then names[#names + 1] = name; seen[name] = true end
            end
        end
    end
    local i = 0; return function() i = i + 1; return names[i] end
end }
local OTA = require("core/orbitui_ota")
OTA.hashFile = function(path) return digest(assert(files[path], path).content) end
local M = require("core/orbitui_module_store")
local function reset()
    files, directories, links, fail_save, rename_fail = {}, {}, {}, false, false
end
local function pack()
    local p = M.bundled().plugins[1]; p.version = "2.0.1"; p.size, p.sha256 = 3, digest("zip"); return p
end
local function store(p)
    local s = M.new("/plugins", "/settings/store", { "/plugins", "/extra" })
    local c = M.bundled(); c.revision = 2; c.plugins = {p or pack()}; s:saveCatalog(c)
    return s
end
local archive, closed, download = {}, 0, 0
local function entry(path, content, mode, size)
    return { path = path, content = content or "return {}", mode = mode or "file", size = size or #(content or "return {}") }
end
local function goodArchive()
    archive = { entry("silverfish.koplugin/", "", "directory"),
        entry("silverfish.koplugin/main.lua", "error('must never execute')"),
        entry("silverfish.koplugin/_meta.lua"), entry("LICENSE", "license"), entry("LICENSE-ART.md", "art license"),
        entry("silverfish.koplugin/fontes/OFL.txt", "font license") }
end
package.loaded["ffi/archiver"] = { Reader = { new = function()
    local a = {}
    function a:open() return true end
    function a:iterate() local i = 0; return function() i = i + 1; return archive[i] end end
    function a:extractToMemory(path) for _, e in ipairs(archive) do if e.path == path then return e.content end end end
    function a:close() closed = closed + 1 end
    return a
end } }
package.loaded["core/orbitui_http"] = { get = function(url, target, limit)
    download = download + 1; H.eq(url, M.url(pack())); H.eq(limit, 3); F.write(target, "zip")
end }
local rename = os.rename
os.rename = function(from, to)
    if rename_fail then return nil end
    assert(not F.attr(to), "overwrite forbidden")
    for _, t in ipairs({files, directories}) do
        local out = {}
        for key, v in pairs(t) do
            if key == from or key:sub(1, #from + 1) == from .. "/" then out[to .. key:sub(#from + 1)] = v; t[key] = nil end
        end
        for key, v in pairs(out) do t[key] = v end
    end
    return true
end
H.test("catalog is pinned, bounded and source/evidence explicit; never a latest URL", function()
    reset(); local c = M.bundled(); M.catalog(c)
    assert(M.url(c.plugins[1]):find("/v2.0.0/", 1, true))
    for _, change in ipairs({
        function(c) c.api = 2 end, function(c) c.plugins[1].folder = "orbitui.koplugin" end,
        function(c) c.plugins[1].repository = "evil/x?query" end,
        function(c) c.plugins[1].tag = "../main" end, function(c) c.plugins[1].size = 1e9 end,
        function(c) c.plugins[1].test.scope = "certified" end,
        function(c) c.plugins[1].sha256 = "x" end, function(c) c.plugins[2] = copy(c.plugins[1]) end,
        function(c) c.plugins[1].conflicts = {"../traca"} end,
        function(c) c.plugins[1].version = "v2.0.0" end,
        function(c) c.plugins[1].version = "2.0.0-beta.01" end,
    }) do local bad = copy(c); change(bad); assert(not pcall(M.catalog, bad)) end
    local s = store(); local rogue = pack(); rogue.sha256 = digest("other")
    assert(not pcall(s.prepare, s, rogue)); H.eq(download, 0)
end)
H.test("catalog rollback, same-revision edits and reused versions are rejected across removals", function()
    reset(); local s = store(); local c = copy(s:catalog())
    c.plugins[1].description = "changed"; assert(not pcall(s.saveCatalog, s, c))
    c.revision = 3; c.plugins[1].sha256 = digest("other"); assert(not pcall(s.saveCatalog, s, c))
    c.plugins = {}; s:saveCatalog(c)
    c.revision = 4; c.plugins = {pack()}; c.plugins[1].version = "1.0.0"
    assert(not pcall(s.saveCatalog, s, c)); H.eq(s:catalog().revision, 3)
end)
H.test("prepare stages only, activate installs atomically without executing metadata or main", function()
    reset(); goodArchive(); local s, p = store(), pack()
    local plan = s:prepare(p)
    assert(not F.attr("/plugins/silverfish.koplugin")); H.eq(s:status(p), "missing")
    -- Tampered worker payload is discarded; the checked original archive wins.
    F.write(plan.directory .. "/payload/main.lua", "bad")
    s:activate(plan); H.eq(s:status(p), "verified")
    H.eq(F.read("/plugins/silverfish.koplugin/main.lua"), "error('must never execute')")
    H.eq(F.read("/plugins/silverfish.koplugin/orbitui-catalog-docs/LICENSE-ART.md"), "art license")
    assert(not F.attr(plan.directory)); assert(not pcall(s.prepare, s, p))
    F.write("/plugins/silverfish.koplugin/main.lua", "return {new=true}")
    H.eq(s:status(p), "unverified"); assert(not pcall(s.prepare, s, p))
    F.mkdir("/extra/traca.koplugin"); H.eq(s:status(p), "unmanaged")
end)
H.test("legacy, extra-path, manual and symlink conflicts are never overwritten", function()
    for _, path in ipairs({"/plugins/traca.koplugin", "/extra/silverfish.koplugin", "/plugins/silverfish.koplugin"}) do
        reset(); local s, p = store(), pack(); F.mkdir(path)
        H.eq(s:status(p), "unmanaged"); assert(not pcall(s.prepare, s, p)); assert(F.attr(path))
    end
    reset(); links["/plugins"] = true
    assert(not pcall(M.new, "/plugins", "/settings/store", {"/plugins"}))
end)
H.test("cancel, checksum failure, destination races and disk-full leave active plugins unchanged", function()
    reset(); goodArchive(); local s, p = store(), pack(); local plan = s:prepare(p)
    -- Cancel means activation is never called. Later cleanup removes only staging.
    F.write("/settings/traca.lua", "pet save"); s:cleanup()
    assert(not F.attr(plan.directory)); H.eq(F.read("/settings/traca.lua"), "pet save")
    plan = s:prepare(p); F.write(plan.directory .. "/download.zip", "tamper")
    assert(not pcall(s.activate, s, plan)); assert(not F.attr("/plugins/silverfish.koplugin"))
    s:cleanup(); plan = s:prepare(p); F.mkdir("/plugins/silverfish.koplugin")
    assert(not pcall(s.activate, s, plan)); assert(F.attr("/plugins/silverfish.koplugin"))
    F.remove("/plugins/silverfish.koplugin"); fail_save = true
    assert(not pcall(s.activate, s, plan)); assert(not F.attr("/plugins/silverfish.koplugin"))
    fail_save = false; rename_fail = true
    assert(not pcall(s.activate, s, plan)); H.eq(s:status(p), "missing")
    rename_fail = false; s:activate(plan); H.eq(s:status(p), "verified")
    H.eq(F.read("/settings/traca.lua"), "pet save")
end)
H.test("unsafe archive paths, code formats, links, duplicates and limits fail closed", function()
    local cases = {
        entry("silverfish.koplugin/../escape.lua"), entry("other.koplugin/main.lua"),
        entry("silverfish.koplugin/x.so"), entry("silverfish.koplugin/a.lua", "return {}", "link"),
        entry("silverfish.koplugin/MAIN.lua"), entry("silverfish.koplugin/x.lua", "syntax !!!"),
        entry("silverfish.koplugin/x.lua", string.char(27) .. "Lua"),
        entry("silverfish.koplugin/x.lua", "x", "file", 20 * 1048576),
        entry("silverfish.koplugin/x.lua", "x", "file", 10),
        entry("silverfish.koplugin/.hidden.lua"), entry("silverfish.koplugin/a\\b.lua"),
    }
    for _, e in ipairs(cases) do
        reset(); goodArchive(); archive[#archive + 1] = e
        local before = closed; assert(not pcall(M.extract, "zip", "/stage", pack()), e.path); H.eq(closed, before + 1)
        assert(not F.attr("/plugins/silverfish.koplugin"))
    end
    reset(); archive = { entry("silverfish.koplugin/main.lua") }
    assert(not pcall(M.extract, "zip", "/stage", pack()))
    reset(); goodArchive()
    for i=1,513 do archive[#archive+1]=entry("silverfish.koplugin/x"..i..".lua") end
    assert(not pcall(M.extract, "zip", "/stage", pack()))
end)
H.test("foreign plans, corrupt registry and changed catalog fail without installation", function()
    reset(); goodArchive(); local s, p = store(), pack(); local plan = s:prepare(p)
    local bad = copy(plan); bad.directory = "/other/" .. bad.directory
    assert(not pcall(s.activate, s, bad))
    F.save("/settings/store/installed.json", {schema=2,plugins={}})
    assert(not pcall(s.activate, s, plan)); assert(not F.attr("/plugins/silverfish.koplugin"))
    F.remove("/settings/store/installed.json")
    local c = s:catalog(); c.revision = 3; c.plugins = {}; s:saveCatalog(c)
    assert(not pcall(s.activate, s, plan)); assert(not F.attr("/plugins/silverfish.koplugin"))
end)
H.test("independent releases choose only the reviewed catalog channel, not plugin latest", function()
    reset(); local c = M.bundled(); c.revision = 2
    local url = "https://github.com/komadorirobin/orbitui.koplugin/releases/download/modules-2/module-catalog.json"
    local releases = {{ tag_name="v99.0.0", assets={} }, { tag_name="modules-2", assets={{name="module-catalog.json",browser_download_url=url}} },
        {tag_name="modules-99",draft=true,assets={}}, {tag_name="modules-98",prerelease=true,assets={}}}
    package.loaded.rapidjson = { decode = function(body) return copy(body == "list" and releases or c) end }
    package.loaded["core/orbitui_http"] = { get = function(address)
        if address:find("api.github.com", 1, true) then return "list" end
        H.eq(address,url); return "catalog"
    end }
    H.eq(M.fetchCatalog().revision, 2); c.revision = 3; assert(not pcall(M.fetchCatalog))
    releases = {}; H.eq(M.fetchCatalog(), nil)
end)
local Adapter = require("adapters/orbitui_module_store")
local notices, dialog, task, repaint, window_closed = {}, nil, nil, 0, false
package.loaded.logger = {warn=function() end}
package.loaded["core/orbitui_context"] = {notify=function(t) notices[#notices+1]=t end}
package.loaded["ui/uimanager"] = {show=function(_,w) dialog=w end}
package.loaded["ui/widget/confirmbox"] = {new=function(_,o) return o end}
package.loaded["ui/widget/textviewer"] = {new=function(_,o) return o end}
package.loaded["ui/network/manager"] = {runWhenOnline=function(_,fn) fn() end}
package.loaded["adapters/orbitui_updates"] = {runTask=function(op,label,done) task={op=op,done=done,label=label} end}
local settings = {}
G_reader_settings = {readSetting=function(_,key) return settings[key] end}
package.loaded.datastorage = {getDataDir=function() return "/data" end,getSettingsDir=function() return "/settings" end}
H.test("plugin root follows native discovery without changing custom search paths or disabled preferences", function()
    reset(); local s = Adapter.store(); H.eq(s.root, "/data/plugins")
    settings.extra_plugin_paths = {"/elsewhere"}; assert(not pcall(Adapter.store))
    settings.extra_plugin_paths = {"/data/plugins/", "/elsewhere"}
    s = Adapter.store(); H.eq(#s.roots,3); settings.plugins_disabled={silverfish=true}
    H.eq(settings.plugins_disabled.silverfish,true)
end)
H.test("download requires confirmation and cancellation cannot commit; busy prevents duplicate jobs", function()
    reset(); local p=pack(); local original=Adapter.store; local commits=0
    Adapter.store=function() return {cleanup=function()end,prepare=function()return{}end,activate=function()commits=commits+1 end} end
    Adapter.install(p); H.eq(task,nil); assert(dialog.ok_callback)
    dialog.ok_callback(); assert(task and task.label); local first=task
    Adapter.install(p); dialog.ok_callback(); H.eq(task,first)
    first.done({error="cancel"}); H.eq(commits,0)
    Adapter.install(p); dialog.ok_callback(); task.done({ok=true,value={}}); H.eq(commits,1)
    Adapter.store=original
end)
H.test("catalog closing retires late repaints and reopening performs fresh verification", function()
    reset(); local on_close, ctx
    local original = Adapter.store
    local checks = 0
    Adapter.store = function() return {catalog=function()return M.bundled()end,status=function() checks=checks+1; return "missing" end} end
    package.loaded["screens/sui_settings_window"] = {show=function(_,closed,nav)
        on_close=closed; ctx={repaint=function() repaint=repaint+1 end}
        local build=nav[1].params.items_func
        local items=build(ctx); build(ctx)
        H.eq(checks,1) -- no repeat hashes on repaint
        items[1].callback(); on_close(); return {}
    end}
    Adapter.show(); local old=repaint
    task.done({ok=true,value=nil}); H.eq(repaint,old)
    Adapter.show(); H.eq(checks,2)
    task.done({ok=true,value=nil}); Adapter.store=original
end)
H.test("owned catalog wording is bilingual and external names/state stay unchanged", function()
    local translate=require("core/orbitui_i18n")
    for _, key in ipairs({"Get more modules…","Module library","Desktop adapter test","Install plugin",
        "Installed files changed; version unverified","Check reviewed catalog"}) do
        assert(translate(key,"sv")~=key); H.eq(translate(key,"en"),key)
    end
    local p=M.bundled().plugins[1]; settings.language="sv"
    H.eq(M.localized(p,"description"),p.description_sv)
    H.eq(M.localized(p,"data_note","en"),p.data_note)
    assert(Adapter.details(p,"missing"):find("Ingen säkerhetscertifiering",1,true))
    settings.language="en"; assert(Adapter.details(p,"missing"):find("Not a safety certificate",1,true))
    H.eq(p.id,"silverfish"); H.eq(p.folder,"silverfish.koplugin")
end)
os.rename = rename
H.finish()
