-- Run via the Studio MCP: execute_luau, datamodel "Edit", after `python3 tools/studio_sync.py`.
-- Fetches build/studio_payload.json from 127.0.0.1:34999 and puts all scripts into the place.
local HttpService = game:GetService("HttpService")
local wasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, body = pcall(function()
	return HttpService:GetAsync("http://127.0.0.1:34999/studio_payload.json", true)
end)
HttpService.HttpEnabled = wasEnabled
if not ok then
	return "HTTP failed: " .. tostring(body)
end
local items = HttpService:JSONDecode(body)

local function resolve(path, classes)
	local current: Instance = game
	for index, name in path do
		local wanted = classes[index]
		local child = if index == 1 then game:GetService(name) else current:FindFirstChild(name)
		if index > 1 and child and wanted and child.ClassName ~= wanted then
			child:Destroy()
			child = nil
		end
		if not child then
			child = Instance.new(wanted or "Folder")
			child.Name = name
			child.Parent = current
		end
		current = child
	end
	return current
end

local keep = {}
local updated = 0
for _, item in items do
	local inst = resolve(item.path, item.classes)
	keep[inst] = true
	if item.source and inst:IsA("LuaSourceContainer") and (inst :: any).Source ~= item.source then
		(inst :: any).Source = item.source
		updated += 1
	end
end

local removed = 0
for _, rootPath in { { "ReplicatedStorage", "Shared" }, { "ServerScriptService", "Server" }, { "StarterPlayer", "StarterPlayerScripts", "Client" }, { "ReplicatedFirst" } } do
	local root: Instance? = game:GetService(rootPath[1])
	for i = 2, #rootPath do
		root = root and root:FindFirstChild(rootPath[i])
	end
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("LuaSourceContainer") and not keep[d] then
				d:Destroy()
				removed += 1
			end
		end
	end
end
return `Sync: {#items} items, {updated} updated, {removed} removed; HttpEnabled={tostring(HttpService.HttpEnabled)}`
