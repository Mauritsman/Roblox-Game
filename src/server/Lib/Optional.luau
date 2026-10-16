--!strict
-- Runtime lookups of services that a parallel work package builds (docs/team/integration.md): mechanics code calls
-- them through here, so every package compiles and runs on its own. A missing service or method is skipped
-- quietly; an error inside the call is caught and printed. Once everything is merged the orchestrator may replace
-- these lookups with direct requires.
--
--   Optional.get("GuardService")                       → the module table or nil
--   Optional.has("GuardService", "Spawn")              → true when the method exists
--   Optional.call("GuardService", "Spawn", plan, …)    → (called, results…) — `called` is false when skipped/failed

local Optional = {}

local servicesFolder: Instance? = nil
local cache: { [string]: any } = {}
local missing: { [string]: boolean } = {}

local function folder(): Instance?
	if servicesFolder == nil then
		local server = script.Parent.Parent
		servicesFolder = server:FindFirstChild("Services")
	end
	return servicesFolder
end

function Optional.get(name: string): any
	local cached = cache[name]
	if cached ~= nil then
		return cached
	end
	if missing[name] then
		return nil
	end
	local services = folder()
	local module = services and services:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		missing[name] = true
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok or type(result) ~= "table" then
		warn(`[Optional] could not load {name}: {result}`)
		missing[name] = true
		return nil
	end
	cache[name] = result
	return result
end

function Optional.has(name: string, method: string): boolean
	local service = Optional.get(name)
	return service ~= nil and type(service[method]) == "function"
end

-- Calls service:method(...) when both exist. Returns (true, results…) or (false).
function Optional.call(name: string, method: string, ...: any): (boolean, ...any)
	local service = Optional.get(name)
	if service == nil then
		return false
	end
	local fn = service[method]
	if type(fn) ~= "function" then
		return false
	end
	local results = table.pack(pcall(fn, service, ...))
	if not results[1] then
		warn(`[Optional] {name}:{method} failed: {results[2]}`)
		return false
	end
	return true, table.unpack(results, 2, results.n)
end

return Optional
