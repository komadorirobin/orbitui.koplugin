package.path = "./?.lua;" .. package.path
local H = require("tests/helpers")
local HTTP = require("core/orbitui_http")
local responses, request_index, timeout_reset, cert_name, observed, closed, timeout
local old_open = io.open
io.open = function(path, mode)
    if path == "data/ca-bundle.crt" then return { close = function() end } end
    return old_open(path, mode)
end
package.loaded.socketutil = {
    set_timeout = function(_, block, total) H.eq(block, 15); timeout = total end,
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
    H.eq(timeout, 180)
    assert(timeout_reset)
end)
H.test("file downloads get a longer bounded timeout without loosening byte limits", function()
    local path = os.tmpname()
    local old_time, now = os.time, 0
    os.time = function() now = now + 200; return now end
    fixture()
    responses = {{ code = 200, body = "data" }}
    H.eq(HTTP.get("https://api.github.com/file", path, 4), 4)
    H.eq(timeout, 600)
    assert(timeout_reset)
    fixture()
    responses = {{ code = 200, body = "data" }}
    assert(not pcall(HTTP.get, "https://api.github.com/file", path, 3))
    assert(timeout_reset)
    fixture()
    os.time = function() now = now + 601; return now end
    responses = {{ code = 200, body = "data" }}
    local ok, err = pcall(HTTP.get, "https://api.github.com/file", path, 4)
    assert(not ok and tostring(err):find("Download timed out", 1, true))
    assert(timeout_reset)
    os.time = old_time
    assert(os.remove(path))
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
H.test("rate-limit diagnostics retain the longest bounded header wait without body or paths", function()
    fixture()
    local old_time = os.time
    os.time = function() return 100000 end
    responses = {{ code = "403", body = "private body", headers = {
        ["X-RateLimit-Remaining"] = "0", ["X-RateLimit-Reset"] = "100180",
        ["Retry-After"] = "90", authorization = "secret",
    } }}
    local ok, err = pcall(HTTP.get, "https://api.github.com/releases", nil, 100)
    assert(not ok and timeout_reset)
    local safe = assert(HTTP.errorInfo(err))
    H.eq(safe.kind, "rate_limit"); H.eq(safe.status, 403); H.eq(safe.retry_at, 100180)
    H.eq(safe.body, nil); H.eq(safe.headers, nil)
    local text = tostring(err)
    assert(text:find("3 minute", 1, true) and not text:find("orbitui_http.lua", 1, true))
    assert(not text:find("private", 1, true) and not text:find("secret", 1, true))
    os.time = old_time
end)
H.test("secondary limits and 429s use bounded retry hints but generic 403s are not mislabelled", function()
    for _, case in ipairs({
        { 403, "API rate limit exceeded", {}, "rate_limit" },
        { 429, "", {}, "rate_limit" },
        { 403, "", { ["retry-after"] = "120" }, "rate_limit" },
        { 403, "blocked by policy", {}, "http" },
        { 404, "private", {}, "http" }, { 503, "private", {}, "http" },
    }) do
        fixture(); responses = {{ code = case[1], body = case[2], headers = case[3] }}
        local ok, err = pcall(HTTP.get, "https://api.github.com/releases", nil, 100)
        assert(not ok and timeout_reset)
        H.eq(HTTP.errorInfo(err).kind, case[4])
        assert(not tostring(err):find("private", 1, true))
        if case[1] == 403 and case[4] == "http" then
            assert(tostring(err):find("does not identify a rate limit", 1, true))
        end
    end
    fixture()
    responses = {{ code = 429, headers = { ["retry-after"] = "inf", ["x-ratelimit-reset"] = "99999999999999" } }}
    local ok, err = pcall(HTTP.get, "https://api.github.com/releases", nil, 100)
    assert(not ok)
    assert(err.retry_at <= os.time() + 60)
end)
H.test("HTTP diagnostic messages follow the reader language", function()
    local old = G_reader_settings
    G_reader_settings = { readSetting = function() return "sv_SE" end }
    fixture(); responses = {{ code = 429 }}
    local ok, err = pcall(HTTP.get, "https://api.github.com/releases", nil, 100)
    assert(not ok and tostring(err):find("GitHub begränsar", 1, true))
    G_reader_settings = old
end)
io.open = old_open
H.finish()
