--!strict
-- De Chain Call aan de kant van de speler (§3.4).
-- G / Y / CALL-knop: geen call actief → start een call op wat je aanwijst;
-- jij bent de beller → GO; iemand anders belde → I'M IN.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local ClientState = require(Lib.ClientState)
local Hud = require(Lib.Hud)

local GadgetController = require(script.Parent.GadgetController)

local ChainCallController = {}

local player = Players.LocalPlayer

local function tick(pitch: number)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/clickfast.wav"
	sound.PlaybackSpeed = pitch
	sound.Volume = 0.7
	SoundService:PlayLocalSound(sound)
	sound:Destroy()
end

local function amIn(snapshot: { [string]: any }): boolean
	for _, name in snapshot.slots or {} do
		if name == player.DisplayName then
			return true
		end
	end
	return false
end

local function modeFor(snapshot: { [string]: any }): string?
	if snapshot.counting then
		return nil
	end
	if snapshot.callerId == player.UserId then
		return "caller"
	end
	if not amIn(snapshot) then
		return "join"
	end
	return nil
end

local function press()
	local call = ClientState.chainCall
	if call then
		if call.callerId == player.UserId then
			Net.request("ChainGo")
		elseif not amIn(call) then
			Net.request("ChainJoin")
		end
		return
	end
	local hit = GadgetController.pointerHit(300)
	Net.request("ChainCall", hit and hit.Instance, hit and hit.Position)
end

function ChainCallController:Start()
	Actions.on("ChainCall", function(phase)
		if phase == "Begin" then
			press()
		end
	end)
	Hud.chainButton().Activated:Connect(press)

	Net.on("ChainCall", function(snapshot: { [string]: any })
		local isNew = ClientState.chainCall == nil or ClientState.chainCall.id ~= snapshot.id
		ClientState.set("chainCall", snapshot)
		Hud.showChain(snapshot, modeFor(snapshot))
		if isNew then
			tick(1.4)
			if snapshot.callerId ~= player.UserId then
				Hud.toast(`{snapshot.caller} started a CHAIN CALL. Press G / CALL: I'M IN`, Hud.Colors.Accent)
			end
		end
	end)
	Net.on("ChainCountdown", function(_id: number, seconds: number, snapshot: { [string]: any })
		ClientState.set("chainCall", snapshot)
		Hud.showChain(snapshot, nil)
		Hud.countdown(seconds)
		for i = 0, seconds - 1 do
			task.delay(i, tick, 1)
		end
	end)
	Net.on("ChainNow", function()
		tick(1.8)
		ClientState.Changed:Fire("ChainNow")
	end)
	Net.on("ChainEnd", function(_id: number, reason: string)
		ClientState.set("chainCall", nil)
		task.delay(if reason == "now" then 1 else 0, function()
			if ClientState.chainCall == nil then
				Hud.showChain(nil)
			end
		end)
		if reason == "expired" then
			Hud.toast("Chain Call expired: nobody joined", Hud.Colors.Muted)
		end
	end)
end

return ChainCallController
