

local _cfg = {
	_r = "Freezewo/null",
	_b = "main"
}
local _raw = "https://raw.githubusercontent.com/"

local _http = request or http_request or (syn and syn.request) or (http and http.request)


local function _fetch(path)
	local url = _raw .. _cfg._r .. "/" .. _cfg._b .. "/" .. path .. "?_=" .. tostring(tick())
	print("[pulsehack] fetching: " .. path)

	if _http then
		local ok, res = pcall(_http, {
			Url = url,
			Method = "GET",
			Headers = {
				["User-Agent"] = "Pulsehack",
				["Cache-Control"] = "no-cache"
			}
		})
		if ok and res and res.StatusCode == 200 and res.Body then
			return res.Body
		end
		if ok then
			warn("[pulsehack] " .. path .. " -> HTTP " .. tostring(res and res.StatusCode))
		else
			warn("[pulsehack] request() error: " .. tostring(res))
		end
	end

	
	local ok2, body = pcall(function() return game:HttpGet(url, true) end)
	if ok2 and body and body ~= "" then
		return body
	end
	if not ok2 then warn("[pulsehack] HttpGet error: " .. tostring(body)) end

	warn("[pulsehack] ALL METHODS FAILED for: " .. path)
	return nil
end

local function _exec(file)
	print("[loader] loading: " .. file)
	local body = _fetch(file)
	if not body then return false end

	local fn, err = loadstring(body)
	if not fn then
		warn("[loader] compile error in " .. file .. ": " .. tostring(err))
		return false
	end

	local ok, runerr = pcall(fn)
	if not ok then
		warn("[loader] runtime error in " .. file .. ": " .. tostring(runerr))
		return false
	end

	print("[loader] OK: " .. file)
	return true
end

_exec("utilities.lua")
task.wait(0.1)
_exec("Pulsehack.lua")
