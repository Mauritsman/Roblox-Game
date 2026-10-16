--!strict
-- Client bootstrap for Crowbar Crew.
-- Starts the shared UI and input libraries, then loads every ModuleScript in Controllers:
-- Init() first and then Start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)

local Lib = script:WaitForChild("Lib")
local Device = require(Lib:WaitForChild("Device"))
local UiScale = require(Lib:WaitForChild("UiScale"))
local Settings = require(Lib:WaitForChild("Settings"))
local Audio = require(Lib:WaitForChild("Audio"))
local Hud = require(Lib:WaitForChild("Hud"))
local Actions = require(Lib:WaitForChild("Actions"))
local RoundState = require(Lib:WaitForChild("RoundState"))
local CharState = require(Lib:WaitForChild("CharState"))
local Profile = require(Lib:WaitForChild("Profile"))
local Screens = require(Lib:WaitForChild("Screens"))

-- First the shared UI and input, then the controllers that use them.
Device.init()
UiScale.init()
Settings.init()
Audio.init()
Hud.init()
Actions.init()
RoundState.init()
CharState.init()
Profile.init()
Screens.init()

-- The reset button would let players skip the cell; the server handles deaths (beta-spec §1.5).
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

local controllersFolder = script:WaitForChild("Controllers")

type Controller = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local controllers: { [string]: Controller } = {}

for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, module)
		if ok then
			controllers[module.Name] = result :: any
		else
			warn(`[Client] Loading {module.Name} failed: {result}`)
		end
	end
end

for name, controller in controllers do
	if controller.Init then
		local ok, err = pcall(function()
			(controller :: any):Init()
		end)
		if not ok then
			warn(`[Client] Init of {name} failed: {err}`)
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
				warn(`[Client] Start of {name} failed: {err}`)
			end
		end)
	end
end

print(`[Client] Crowbar Crew {Config.Version} started`)
