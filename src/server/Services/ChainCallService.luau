--!strict
-- The Chain Call (§3.4): a countdown without voice.
-- 1. Someone calls a Chain Call on a chain point.
-- 2. Teammates tap "I'M IN"; their gadget automatically fills EYES, CLEAR or OPEN.
-- 3. Everything filled (or the caller taps GO) → 3-2-1 for everyone at once → NOW.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local LoadoutService = require(script.Parent.LoadoutService)

local ChainCallService = {}

type Call = {
	id: number,
	caller: Player,
	target: Instance?,
	position: Vector3?,
	slots: { [string]: any }, -- step -> Player
	expiresAt: number,
	counting: boolean,
}

local active: Call? = nil
local cooldownUntil = 0
local nextId = 0

local function stepsFor(player: Player): { string }
	local steps = {}
	for _, gadgetName in Config.GadgetOrder do
		if LoadoutService:Has(player, gadgetName) then
			local step = Config.Gadgets[gadgetName].Step
			if not table.find(steps, step) then
				table.insert(steps, step)
			end
		end
	end
	return steps
end

local function occupiedBy(call: Call, player: Player): string?
	for step, who in call.slots do
		if who == player then
			return step
		end
	end
	return nil
end

-- Puts the player in a free slot that matches one of their gadgets.
local function assign(call: Call, player: Player): string?
	local existing = occupiedBy(call, player)
	if existing then
		return existing
	end
	for _, step in stepsFor(player) do
		if call.slots[step] == nil then
			call.slots[step] = player
			return step
		end
	end
	return nil
end

local function snapshot(call: Call): { [string]: any }
	local slots: { [string]: string } = {}
	for step, who in call.slots do
		slots[step] = who.DisplayName
	end
	return {
		id = call.id,
		caller = call.caller.DisplayName,
		callerId = call.caller.UserId,
		target = call.target,
		position = call.position,
		slots = slots,
		secondsLeft = math.max(0, call.expiresAt - os.clock()),
		counting = call.counting,
	}
end

local function isFull(call: Call): boolean
	for _, step in Config.ChainCall.Steps do
		if call.slots[step] == nil then
			return false
		end
	end
	return true
end

local function finish(call: Call, reason: string)
	if active ~= call then
		return
	end
	active = nil
	cooldownUntil = os.clock() + Config.ChainCall.Cooldown
	Net.broadcast("ChainEnd", call.id, reason)
end

local function startCountdown(call: Call)
	if call.counting then
		return
	end
	call.counting = true
	Net.broadcast("ChainCountdown", call.id, Config.ChainCall.CountdownSeconds, snapshot(call))
	task.delay(Config.ChainCall.CountdownSeconds, function()
		if active == call then
			Net.broadcast("ChainNow", call.id)
			finish(call, "now")
		end
	end)
end

function ChainCallService:Start()
	Net.onRequest("ChainCall", function(player: Player, target: any, position: any)
		local now = os.clock()
		if active then
			Net.send(player, "Toast", "A Chain Call is already running")
			return
		end
		if now < cooldownUntil then
			return
		end
		nextId += 1
		local call: Call = {
			id = nextId,
			caller = player,
			target = if typeof(target) == "Instance" then target else nil,
			position = if typeof(position) == "Vector3" then position else nil,
			slots = {},
			expiresAt = now + Config.ChainCall.JoinSeconds,
			counting = false,
		}
		active = call
		assign(call, player)
		Net.broadcast("ChainCall", snapshot(call))
		if #Players:GetPlayers() <= 1 or isFull(call) then
			startCountdown(call)
			return
		end
		task.delay(Config.ChainCall.JoinSeconds, function()
			if active == call and not call.counting then
				-- Not everyone joined: count down anyway if at least two people are in.
				local count = 0
				for _ in call.slots do
					count += 1
				end
				if count >= 2 then
					startCountdown(call)
				else
					finish(call, "expired")
				end
			end
		end)
	end)

	Net.onRequest("ChainJoin", function(player: Player)
		local call = active
		if not call or call.counting then
			return
		end
		local step = assign(call, player)
		if not step then
			Net.send(player, "Toast", "Your gadget isn't needed in this chain")
		end
		Net.broadcast("ChainCall", snapshot(call))
		if isFull(call) then
			startCountdown(call)
		end
	end)

	Net.onRequest("ChainGo", function(player: Player)
		local call = active
		if call and call.caller == player then
			startCountdown(call)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local call = active
		if call then
			if call.caller == player then
				finish(call, "left")
			else
				for step, who in call.slots do
					if who == player then
						call.slots[step] = nil
					end
				end
			end
		end
	end)
end

return ChainCallService
