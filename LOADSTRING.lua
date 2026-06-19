
local _url = "https://raw.githubusercontent.com/Freezewo/null/main/loader.lua"

local _http = request or http_request or (syn and syn.request) or (http and http.request)
if not _http then
	warn("[Pulsehack] HTTP not available")
	return
end

local ok, res = pcall(_http, {
	Url = _url,
	Method = "GET",
	Headers = {
		["User-Agent"] = "Pulsehack",
		["Cache-Control"] = "no-cache"
	}
})

if not ok or not res or res.StatusCode ~= 200 or not res.Body then
	warn("[Pulsehack] failed to fetch loader: " .. tostring(res and res.StatusCode or res))
	return
end

local fn, err = loadstring(res.Body)
if not fn then
	warn("[Pulsehack] compile error: " .. tostring(err))
	return
end

fn()
