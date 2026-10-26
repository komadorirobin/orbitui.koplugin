local M = {}
local hosts = {
    ["api.github.com"] = true, ["github.com"] = true,
    ["release-assets.githubusercontent.com"] = true,
    ["objects.githubusercontent.com"] = true, ["github-releases.githubusercontent.com"] = true,
}

-- Carry only safe, bounded diagnostics through pcall/Trapper. Never display the
-- response body, signed asset URL or arbitrary headers in an error dialog.
local function failure(code, headers, body)
    local values = {}
    for key, value in pairs(headers or {}) do
        if type(key) == "string" then values[key:lower()] = value end
    end
    local now = os.time()
    local function bounded(value)
        value = tonumber(value)
        if value and value == value and value >= 0 and value <= 86400 then
            return math.ceil(value)
        end
    end
    local wait = bounded(values["retry-after"])
    local remaining = tonumber(values["x-ratelimit-remaining"])
    local reset = tonumber(values["x-ratelimit-reset"])
    local reset_wait = remaining == 0 and reset and bounded(reset - now)
    if reset_wait then wait = math.max(wait or 0, reset_wait) end
    local lower = type(body) == "string" and body:lower() or ""
    local limited = (code == 403 or code == 429) and (code == 429
        or remaining == 0 or wait ~= nil or lower:find("rate limit", 1, true)
        or lower:find("abuse detection", 1, true))
    return setmetatable({ orbitui_http_error = true, status = code,
        kind = limited and "rate_limit" or "http",
        retry_at = limited and (now + math.max(60, wait or 60)) or nil,
    }, { __tostring = M.message })
end

function M.errorInfo(value)
    if type(value) == "table" and value.orbitui_http_error == true then
        return { orbitui_http_error = true, status = value.status,
            kind = value.kind, retry_at = value.retry_at }
    end
end

function M.message(value)
    local err = M.errorInfo(value)
    if not err then return tostring(value) end
    local _ = require("core/orbitui_i18n")
    if err.kind == "rate_limit" then
        local minutes = math.max(1, math.ceil(((err.retry_at or os.time()) - os.time()) / 60))
        return string.format(_("GitHub is temporarily limiting requests (HTTP %d)."), err.status)
            .. "\n" .. string.format(_("Try again in %d minute(s)."), minutes)
    elseif err.status == 403 then
        return _("GitHub refused the request (HTTP 403). The response does not identify a rate limit. Try again later or check your network, VPN or proxy.")
    elseif err.status == 404 then
        return _("GitHub could not find the requested download (HTTP 404).")
    elseif err.status >= 500 and err.status <= 599 then
        return string.format(_("GitHub is temporarily unavailable (HTTP %d). Try again later."), err.status)
    end
    return string.format(_("GitHub request failed (HTTP %d)."), err.status)
end

function M.host(url)
    assert(type(url) == "string" and not url:find("[%z%c\\]"), "Invalid download URL")
    local host = url:match("^https://([^/]+)/")
    assert(hosts[host], "Only HTTPS GitHub release downloads are allowed")
    return host
end

function M.matchesHost(pattern, host)
    if type(pattern) ~= "string" or pattern:find("%z") then return false end
    pattern, host = pattern:lower(), host:lower()
    if pattern == host then return true end
    if pattern:sub(1, 2) ~= "*." then return false end
    return host:match("^[^.]+(%..*)$") == pattern:sub(2)
end

local function verifyHost(cert, host)
    if not cert then return false end
    if cert.checkhost then return cert:checkhost(host) == true end
    local ext = cert:extensions()
    local names = ext and ext["2.5.29.17"] and ext["2.5.29.17"].dNSName
    for _, name in ipairs(type(names) == "table" and names or {}) do
        if M.matchesHost(name, host) then return true end
    end
    return false
end

local function caFile()
    local root = assert(debug.getinfo(1, "S").source:match("^@(.+)/core/orbitui_http%.lua$"))
    for _, path in ipairs({ "data/ca-bundle.crt", root .. "/assets/ca-bundle.crt",
        "/etc/ssl/certs/ca-certificates.crt", "/etc/ssl/cert.pem" }) do
        local f = io.open(path, "rb")
        if f then f:close(); return path end
    end
    error("CA certificate bundle is missing; reinstall the complete OrbitUI package")
end

-- Called only inside Trapper's subprocess. Never disable TLS verification.
function M.get(url, target, limit)
    local http = require("socket.http")
    local https = require("ssl.https")
    local socketutil = require("socketutil")
    local ca = caFile()
    local timeout = target and 600 or 180
    local output
    local ok, result = pcall(function()
        socketutil:set_timeout(15, timeout)
        for _hop = 1, 6 do
            local host = M.host(url)
            local parts, count, started = {}, 0, os.time()
            if target then output = assert(io.open(target, "wb")) end
            local function sink(chunk, err)
                if err then return nil, err end
                if not chunk then return 1 end
                count = count + #chunk
                if count > limit then return nil, "Download exceeds size limit" end
                if os.time() - started > timeout then return nil, "Download timed out" end
                if output then return output:write(chunk) end
                parts[#parts + 1] = chunk
                return 1
            end
            local factory = https.tcp{ verify = "peer", cafile = ca, protocol = "any",
                options = { "all", "no_sslv2", "no_sslv3", "no_tlsv1", "no_tlsv1_1" } }
            local function create()
                local conn = factory()
                local connect = conn.connect
                function conn:connect(address, port)
                    assert(address == host, "Unexpected TLS host")
                    local connected, err = connect(self, address, port)
                    assert(connected, err)
                    if not verifyHost(self.sock:getpeercertificate(), host) then
                        self.sock:close()
                        error("TLS certificate does not match " .. host)
                    end
                    return connected
                end
                return conn
            end
            local _, code, headers = http.request{
                url = url, method = "GET", create = create, redirect = false,
                headers = { ["User-Agent"] = "KOReader-OrbitUI", ["Accept"] = "application/vnd.github+json",
                    ["Cache-Control"] = "no-cache" }, sink = sink,
            }
            if output then assert(output:close()); output = nil end
            code = tonumber(code) or code
            if code == 200 then return target and count or table.concat(parts) end
            if code == 301 or code == 302 or code == 303 or code == 307 or code == 308 then
                url = require("socket.url").absolute(url, assert(headers and headers.location))
                M.host(url)
            else
                if type(code) == "number" then error(failure(code, headers, table.concat(parts)), 0) end
                error("GitHub download failed: " .. tostring(code))
            end
        end
        error("Too many download redirects")
    end)
    if output then output:close() end
    socketutil:reset_timeout()
    if not ok then error(result, 0) end
    return result
end

return M
