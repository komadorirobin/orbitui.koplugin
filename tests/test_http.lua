package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local HTTP = require("core/orbitui_http")
local responses, request_index, timeout_reset, cert_name, observed, closed
local old_open = io.open
io.open = function(path, mode)
    if path == "data/ca-bundle.crt" then return { close = function() end } end
    return old_open(path, mode)
end
package.loaded.socketutil = {
    set_timeout = function() end,
    reset_timeout = function() timeout_reset = true end,
}
package.loaded["ssl.https"] = { tcp = function(params)
    H.eq(params.verify, "peer")
    H.eq(params.cafile, "data/ca-bundle.crt")
    return function()
        return {
            connect = function() return true end,
            sock = { close = function() closed = true end,
                getpeercertificate = function() return { extensions = function()
                    return { ["2.5.29.17"] = { dNSName = { cert_name } } }
                end } end },
        }
    end
end }
package.loaded["socket.url"] = { absolute = function(_, to) return to end }
package.loaded["socket.http"] = { request = function(spec)
    H.eq(spec.redirect, false)
    observed[#observed + 1] = spec.url
    spec.create():connect(HTTP.host(spec.url), 443)
    request_index = request_index + 1
    local response = responses[request_index]
    local ok, err = spec.sink(response.body or "body")
    if not ok then return nil, err end
    return 1, response.code, response.headers or {}
end }
local function fixture()
    responses, request_index, observed = {}, 0, {}
    cert_name, timeout_reset, closed = "api.github.com", false, false
end
H.test("HTTPS verifies CA and hostname and restores socket timeouts", function()
    fixture()
    responses = {{ code = 200, body = "[]" }}
    H.eq(HTTP.get("https://api.github.com/releases", nil, 10), "[]")
    assert(timeout_reset)
end)
H.test("hostname mismatch fails even for a CA-verified certificate", function()
    fixture()
    cert_name = "other.example.com"
    assert(not pcall(HTTP.get, "https://api.github.com/releases", nil, 10))
    assert(timeout_reset and closed)
end)
H.test("redirects cannot downgrade TLS or leave GitHub's asset hosts", function()
    for _, target in ipairs({ "http://github.com/file", "https://evil.test/file" }) do
        fixture()
        responses = {{ code = 302, headers = { location = target } }}
        assert(not pcall(HTTP.get, "https://api.github.com/releases", nil, 10))
        H.eq(#observed, 1)
        assert(timeout_reset)
    end
end)
H.test("size limits and HTTP failures remain failures", function()
    fixture()
    responses = {{ code = 200, body = string.rep("x", 50) }}
    assert(not pcall(HTTP.get, "https://api.github.com/releases", nil, 10))
    assert(timeout_reset)
    fixture()
    responses = {{ code = 403 }}
    assert(not pcall(HTTP.get, "https://api.github.com/releases", nil, 10))
    assert(timeout_reset)
end)
io.open = old_open
H.finish()
