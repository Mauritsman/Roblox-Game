--!strict
-- Het verloop van een run in fase 1:
--   * Gepakt door een bewaker = terug naar het busje (in fase 2 komt de beveiligingsruimte).
--   * De Golden Gouda aanraken = run geslaagd.
--   * Alarm op trede 3 = LOCKDOWN: 90 s om weg te raken, daarna mislukt.
-- Na afloop wordt het level opnieuw gebouwd.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local AlarmService = require(script.Parent.AlarmService)
local GadgetService = require(script.Parent.GadgetService)
local GuardService = require(script.Parent.GuardService)
local LoadoutService = require(script.Parent.LoadoutService)
local MapService = require(script.Parent.MapService)

local RoundService = {}

local runId = 0
local runStartedAt = os.clock()
local ending = false

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 7.2
	character:SetAttribute(Tags.Crouching, false)
	character:SetAttribute(Tags.Operating, false)
	character:SetAttribute("Caught", nil)
end

local function sendToVan(player: Player)
	local character = player.Character
	if character then
		local offset = Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
		character:PivotTo(CFrame.new(MapService.Points.Spawn + offset))
	end
end

function RoundService:Capture(player: Player)
	local character = player.Character
	if not character or character:GetAttribute("Caught") then
		return
	end
	character:SetAttribute("Caught", true)
	GadgetService:RecallDrone(player, "")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
	end
	Net.broadcast("Caught", player.DisplayName)
	task.delay(1.2, function()
		if player.Parent and player.Character == character then
			sendToVan(player)
			character:SetAttribute("Caught", nil)
			character:SetAttribute(Tags.Crouching, false)
			if humanoid then
				humanoid.WalkSpeed = Config.Player.WalkSpeed
			end
		end
	end)
end

function RoundService:Reset()
	runId += 1
	ending = false
	MapService:Build()
	AlarmService:Reset()
	LoadoutService:ResetRun()
	for _, player in Players:GetPlayers() do
		player:LoadCharacter()
	end
	runStartedAt = os.clock()
	Net.broadcast("RunStarted", Config.Difficulty, Config.windowSeconds(#Players:GetPlayers()))
	RoundService:HookGoal()
end

local function endRun(result: string, detail: string)
	if ending then
		return
	end
	ending = true
	local seconds = math.floor(os.clock() - runStartedAt)
	Net.broadcast("RunEnded", result, seconds, detail)
	local thisRun = runId
	task.delay(7, function()
		if runId == thisRun then
			RoundService:Reset()
		end
	end)
end

function RoundService:HookGoal()
	for _, goal in CollectionService:GetTagged(Tags.Goal) do
		if goal:IsA("BasePart") and not goal:GetAttribute("Hooked") then
			goal:SetAttribute("Hooked", true)
			goal.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player and not ending then
					endRun("SUCCESS", `{player.DisplayName} grabbed the Golden Gouda`)
				end
			end)
		end
	end
end

function RoundService:Start()
	GuardService:OnCapture(function(player)
		RoundService:Capture(player)
	end)

	AlarmService.LevelChanged:Connect(function(level)
		if level >= 3 and not ending then
			local thisRun = runId
			Net.broadcast("Lockdown", Config.Alarm.LockdownSeconds)
			task.delay(Config.Alarm.LockdownSeconds, function()
				if runId == thisRun and not ending then
					endRun("BUSTED", "The police arrived")
				end
			end)
		end
	end)

	Net.onRequest("RestartRun", function()
		-- Handig tijdens het testen: elke speler mag een run herstarten.
		if not ending then
			endRun("RESTART", "Run restarted")
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(setupCharacter)
		if player.Character then
			setupCharacter(player.Character)
		end
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(setupCharacter)
		if player.Character then
			setupCharacter(player.Character)
		end
	end

	LoadoutService:ResetRun()
	RoundService:HookGoal()
	runStartedAt = os.clock()
end

return RoundService
