--!strict
-- Client-bootstrap voor Crowbar Crew.
-- Laadt elke ModuleScript in Controllers, roept eerst Init() en daarna Start() aan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Actions = require(script:WaitForChild("Lib"):WaitForChild("Actions"))
local Hud = require(script.Lib:WaitForChild("Hud"))

-- Eerst de gedeelde UI en invoer, daarna de controllers die ze gebruiken.
Hud.init()
Actions.init()

local controllersFolder = script:WaitForChild("Controllers")

type Controller = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local controllers: { [string]: Controller } = {}

for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = (require :: any)(module)
	end
end

for name, controller in controllers do
	if controller.Init then
		local ok, err = pcall(function()
			(controller :: any):Init()
		end)
		if not ok then
			warn(`[Client] Init van {name} faalde: {err}`)
		end
	end
end

for name, controller in controllers do
	if controller.Start then
		task.spawn(function()
			local ok, err = pcall(function()
				(controller :: any):Start()
			end)
			if not ok then
				warn(`[Client] Start van {name} faalde: {err}`)
			end
		end)
	end
end

print(`[Client] Crowbar Crew {Config.Version} gestart`)
