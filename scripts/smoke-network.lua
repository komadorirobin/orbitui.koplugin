package.path = "./?.lua;" .. package.path
package.loaded.socketutil = {
    set_timeout = function(_, block)
        require("socket.http").TIMEOUT = block
        require("ssl.https").TIMEOUT = block
    end,
    reset_timeout = function() end,
}
local HTTP = require("core/orbitui_http")
local body = HTTP.get("https://api.github.com/repos/komadorirobin/orbitui.koplugin", nil, 1024 * 1024)
assert(require("cjson").decode(body).private == false)
print("PASS anonymous GitHub HTTPS request with real LuaSocket/LuaSec, CA and hostname verification")
