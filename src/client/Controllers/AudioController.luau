--!strict
-- Music and state loops (beta-spec-ux §4–5): Garage groove, sneaking loop, chase/lockdown music, payout,
-- the Gouda moment (hard stop → silence → ding → sirens), busted sting; rolling rumble and drone hum.
-- Tracks with placeholder ids stay silent until real sounds are filled in (src/shared/Sounds.luau).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Audio = require(Lib.Audio)
local CharState = require(Lib.CharState)
local ClientState = require(Lib.ClientState)
local RoundState = require(Lib.RoundState)
local Screens = require(Lib.Screens)

local AudioController = {}

local player = Players.LocalPlayer

local CHASE_HOLD = 3 -- seconds unseen before the chase music fades out
local chaseUntil = 0
local suppressUntil = 0 -- silence after the Gouda lift / busted sting

local function guardChasingMe(): boolean
	local root = CharState.root()
	if not root then
		return false
	end
	for _, guard in CollectionService:GetTagged("Guard") do
		if guard:IsA("Model") and guard:GetAttribute("GuardState") == "Alert" then
			if (guard:GetPivot().Position - root.Position).Magnitude < 45 then
				return true
			end
		end
	end
	return false
end

local function desired(): (string?, number)
	if os.clock() < suppressUntil then
		return nil, 0
	end
	if Screens.current() == "Payout" then
		return "MusicPayout", 1
	end
	local mode = RoundState.statusMode()
	if mode ~= "Heist" then
		return "MusicGarage", 1.5
	end
	if RoundState.isLoud() then
		return "MusicChase", 1
	end
	if os.clock() < chaseUntil then
		return "MusicChase", 1
	end
	return "MusicSneak", 2
end

local function update()
	local key, fade = desired()
	if os.clock() < suppressUntil then
		return
	end
	Audio.music(key, fade)
end

function AudioController:Start()
	Net.on("Spotted", function(userId: any)
		if userId == player.UserId then
			chaseUntil = os.clock() + CHASE_HOLD + 2
			update()
		end
	end)
	Net.on("GoudaLifted", function()
		-- Hard stop, 0.6 s silence (the ding plays in MomentsController), lockdown music at +1.2 s.
		Audio.stopMusic()
		suppressUntil = os.clock() + 1.2
		task.delay(1.25, update)
	end)
	Net.on("Busted", function()
		Audio.stopMusic()
		suppressUntil = os.clock() + 3
		Audio.music("MusicBusted", 0)
		task.delay(3.1, update)
	end)
	RoundState.Changed:Connect(function(name)
		if name == "RoundPhase" or name == "Approach" then
			update()
		end
	end)
	CharState.Changed:Connect(function(name)
		if name == "Rolling" or name == "Character" then
			local root = CharState.root()
			Audio.loop("RollRumble", CharState.get("Rolling") == true, root)
		elseif name == "Player:Activity" then
			update()
		end
	end)
	ClientState.Changed:Connect(function(key)
		if key == "drone" then
			Audio.loop("DroneHum", ClientState.drone ~= nil, ClientState.drone)
		end
	end)
	Screens.Changed:Connect(update)

	update()
	while true do
		task.wait(0.5)
		if RoundState.statusMode() == "Heist" and guardChasingMe() then
			chaseUntil = math.max(chaseUntil, os.clock() + CHASE_HOLD)
		end
		update()
	end
end

return AudioController
