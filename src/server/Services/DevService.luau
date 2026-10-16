--!strict
-- Test helpers, ONLY active in Roblox Studio (RunService:IsStudio()). They do nothing in the published game.
-- From the Client datamodel: `game.ReplicatedStorage.Remotes.ToServer:FireServer("<Name>", ...)`.
--
--   DevTake(gadget)     carry that gadget with full charges (LoadoutService:DevTake)
--   DevPry(name?)       open a Pryable (by name, e.g. "CageDoor"), as if you held the Crowbar
--   DevAlarm(points?)   add alarm points (no number = straight to LOCKDOWN)
--   DevCapture()        straight into the cell (CaptureService:Jail)
--   DevFree()           free yourself (CaptureService:Release)
--   DevTutorial()       start the mini-job now, even when it was done before (TutorialService:Start)
-- DevJob, DevClock, DevPhase, DevRestart (RoundService) and DevGive (LootService) are registered by their own
-- services (contracts §1.4); meta's are in MetaDevService.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Optional = require(script.Parent.Parent.Lib.Optional)
local GadgetService = require(script.Parent.GadgetService)
local LoadoutService = require(script.Parent.LoadoutService)

local DevService = {}

local function toast(player: Player, text: string)
	Net.send(player, "Toast", `DEV: {text}`)
end

-- Calls service:method(...) or tells the tester which service is missing.
local function call(player: Player, service: string, method: string, ...: any): boolean
	if not Optional.has(service, method) then
		toast(player, `{service}:{method} is not available`)
		return false
	end
	return (Optional.call(service, method, ...))
end

function DevService:Start()
	if not RunService:IsStudio() then
		return
	end

	Net.onRequest("DevTake", function(player: Player, gadgetName: any)
		if type(gadgetName) == "string" and not LoadoutService:DevTake(player, gadgetName) then
			toast(player, `unknown gadget "{gadgetName}"`)
		end
	end)

	Net.onRequest("DevPry", function(player: Player, targetName: any)
		for _, target in CollectionService:GetTagged(Tags.Pryable) do
			local nameOk = type(targetName) ~= "string" or target.Name == targetName
			if target:IsA("BasePart") and nameOk then
				GadgetService:Pry(player, target, true)
				return
			end
		end
		toast(player, "no Pryable found")
	end)

	Net.onRequest("DevAlarm", function(player: Player, points: any)
		if type(points) == "number" and points == points then
			call(player, "AlarmService", "Add", "Dev", math.clamp(points, 0, 1000))
		else
			call(player, "AlarmService", "ForceLockdown", "Dev")
		end
	end)

	Net.onRequest("DevCapture", function(player: Player)
		call(player, "CaptureService", "Jail", player)
	end)

	Net.onRequest("DevFree", function(player: Player)
		call(player, "CaptureService", "Release", player)
	end)

	Net.onRequest("DevTutorial", function(player: Player)
		local ok, started = Optional.call("TutorialService", "Start", player, true)
		if not ok or started ~= true then
			toast(player, "mini-job not started (in a crew round, already running, or no mini-job map)")
		end
	end)
end

return DevService
