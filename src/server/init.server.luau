--!strict
-- Server bootstrap for Crowbar Crew.
-- Loads every ModuleScript in Services, calls Init() first and then Start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local servicesFolder = script:WaitForChild("Services")

type Service = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local services: { [string]: Service } = {}

for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = (require :: any)(module)
	end
end

for name, service in services do
	if service.Init then
		local ok, err = pcall(function()
			(service :: any):Init()
		end)
		if not ok then
			warn(`[Server] Init of {name} failed: {err}`)
		end
	end
end

for name, service in services do
	if service.Start then
		task.spawn(function()
			local ok, err = pcall(function()
				(service :: any):Start()
			end)
			if not ok then
				warn(`[Server] Start of {name} failed: {err}`)
			end
		end)
	end
end

print(`[Server] Crowbar Crew {Config.Version} started with {#servicesFolder:GetChildren()} services`)
