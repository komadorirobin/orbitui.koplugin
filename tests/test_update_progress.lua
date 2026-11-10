local root = os.getenv("ORBITUI_TEST_ROOT") or "."
package.path = root .. "/?.lua;./?.lua;" .. package.path
local H = require("tests/helpers")
local OTA = require("core/orbitui_ota")
local function quote(path) return "'" .. path:gsub("'", "'\\''") .. "'" end
local function shell(cmd)
    local ok, _, code = os.execute(cmd)
    return ok == 0 or ok == true and code == 0
end
local dirs, fs = {}, {}
function fs.mkdir(path)
    local ok = shell("mkdir " .. quote(path) .. " 2>/dev/null")
    if ok then dirs[#dirs + 1] = path end
    return ok
end
function fs.rmdir(path) return shell("rmdir " .. quote(path) .. " 2>/dev/null") end
function fs.symlinkattributes(path, key)
    local attr
    if shell("test -L " .. quote(path)) then attr = { mode = "link" }
    elseif shell("test -d " .. quote(path)) then attr = { mode = "directory" }
    else
        local f = io.open(path,"rb")
        if f then attr = { mode = "file", size = f:seek("end") }; f:close() end
    end
    return attr and (key and attr[key] or attr)
end
package.loaded["libs/libkoreader-lfs"] = fs
local scratch = os.tmpname(); assert(os.remove(scratch)); assert(fs.mkdir(scratch))
local context = { root = scratch }
local function write(path, data) local f = assert(io.open(path,"wb")); assert(f:write(data)); assert(f:close()) end

H.test("release notes remain bounded plain text, never markup, URLs or installer inputs", function()
    local notes = OTA.releaseNotes("## New release\n- **A feature** with [details](https://example.test)\n![image](https://bad.test/a.png)\n<script>bad()</script>\nhttps://example.test\n- Svenska åäö\0")
    assert(notes:find("A feature with details",1,true) and notes:find("Svenska åäö",1,true))
    assert(not notes:find("http",1,true) and not notes:find("script",1,true) and not notes:find("![",1,true))
    H.eq(OTA.releaseNotes(nil),nil); H.eq(OTA.releaseNotes({}),nil)
    local lines = {}; for _i=1,100 do lines[#lines+1]="Another line" end
    local result = OTA.releaseNotes(table.concat(lines,"\n")); H.eq(select(2,result:gsub("\n","")),7)
    H.eq(OTA.releaseNotes(string.rep("å",5000)),nil)
end)
H.test("status directories are exclusive and one channel cannot retire another", function()
    local a = assert(OTA.progressChannel(context)); local first = dirs[#dirs]
    local b = assert(OTA.progressChannel(context)); local second = dirs[#dirs]
    assert(first ~= second)
    a.write{phase="downloading",received=100,total=1000}
    b.write{phase="downloading",received=500,total=1000}
    H.eq(a.read().received,100); H.eq(b.read().received,500)
    a.close(); H.eq(fs.symlinkattributes(first),nil); H.eq(b.read().received,500)
    a.write{phase="verifying",received=1000,total=1000}; H.eq(fs.symlinkattributes(first),nil)
    b.close(); H.eq(fs.symlinkattributes(second),nil)
end)
H.test("real files publish only changed five-percent buckets and a verification transition", function()
    local c = assert(OTA.progressChannel(context))
    H.eq(c.read(),nil)
    c.write{phase="downloading",received=550,total=1000}; H.eq(c.read().received,550)
    c.write{phase="downloading",received=570,total=1000}; H.eq(c.read().received,550)
    c.write{phase="downloading",received=600,total=1000}; H.eq(c.read().received,600)
    c.write{phase="verifying",received=1000,total=1000}; H.eq(c.read().phase,"verifying")
    c.close(); c.close(); H.eq(c.read(),nil)
end)
H.test("malformed, oversized, negative and nonfinite snapshots are ignored without exposing file contents", function()
    local c = assert(OTA.progressChannel(context)); local path = dirs[#dirs] .. "/status"
    for _, data in ipairs{"secret URL https://private.invalid",string.rep("x",129),"downloading -1 12\n","other 1 2\n","downloading 9999999999 12\n"} do
        write(path,data); H.eq(c.read(),nil)
    end
    assert(os.remove(path))
    for _, value in ipairs{ {}, {phase="bad"}, {phase="downloading",received=-1}, {phase="downloading",received=0/0}, {phase="downloading",received=math.huge}, {phase="downloading",received="1"} } do
        c.write(value); H.eq(c.read(),nil)
    end
    c.close()
end)
H.test("unknown status links or entries survive cleanup and never overwrite a foreign file", function()
    local c = assert(OTA.progressChannel(context)); local dir = dirs[#dirs]
    local foreign = scratch .. "/foreign"; write(foreign,"keep")
    assert(shell("ln -s " .. quote(foreign) .. " " .. quote(dir .. "/status")))
    c.write{phase="downloading",received=100,total=1000}; H.eq(c.read(),nil)
    c.close(); H.eq(fs.symlinkattributes(dir .. "/status","mode"),"link")
    local f = assert(io.open(foreign)); H.eq(f:read("*a"),"keep"); f:close()
    assert(os.remove(dir .. "/status")); assert(fs.rmdir(dir)); assert(os.remove(foreign))
end)
H.test("unavailable progress storage falls back without removing unknown leftovers", function()
    local mkdir = fs.mkdir; fs.mkdir = function() return false end
    H.eq(OTA.progressChannel(context),nil)
    fs.mkdir = mkdir
    H.eq(OTA.progressChannel{root=scratch .. "/missing"},nil)
end)
assert(fs.rmdir(scratch))
H.finish()
