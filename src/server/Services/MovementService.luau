--!strict
-- The only writer of Humanoid.WalkSpeed / JumpHeight (beta-spec §0, §9.1). The speed comes from Logic/Movement
-- with the player's stats (LoadoutService:StatsOf after perks, else Config defaults) and these character
-- attributes: Frozen, Caught, Captured, Hidden, Bubbled, Slipping, Operating, CarryClass, Rolling, CarryPartner,
-- Crouching, InGoo (GooZone cap, set by MapRuntimeService).
--   * Other services only set attributes; MovementService refreshes automatically when one changes. Calling
--     `MovementService:Refresh(player)` after a change is still good practice (integration.md).
--   * Anyone else writing WalkSpeed/JumpHeight is overwritten at once (prototype code in other packages still does).
--   * Handles the `Crouch(on)` request: refused with full hands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Movement = require(ReplicatedStorage.Shared.Logic.Movement)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)

local Optional = require(script.Parent.Parent.Lib.Optional)

local MovementService = {}

local DEFAULT_STATS = Perks.defaultsFrom(Config)

-- Attributes that change the speed.
local WATCHED = {
	Tags.Frozen,
	Tags.Caught,
	Tags.Captured,
	Tags.Hidden,
	Tags.Bubbled,
	Tags.Slipping,
	Tags.Operating,
	Tags.CarryClass,
	Tags.Rolling,
	Tags.CarryPartner,
	Tags.Crouching,
	Tags.InGoo, -- mechanics D (GooZone)
}

type Applied = { walk: number, jump: number }
local applied: { [Humanoid]: Applied } = {}
local lastCrouch: { [Player]: number } = {}

local function statsOf(player: Player): Movement.Stats
	local ok, stats = Optional.call("LoadoutService", "StatsOf", player)
	if ok and type(stats) == "table" and type(stats.Walk) == "number" then
		return stats :: any
	end
	return DEFAULT_STATS :: any
end

local function flagsOf(character: Model): Movement.Flags
	local function on(name: string): boolean
		local value = character:GetAttribute(name)
		return value ~= nil and value ~= false
	end
	local carryClass = character:GetAttribute(Tags.CarryClass)
	return {
		frozen = on(Tags.Frozen),
		caught = on(Tags.Caught) or on(Tags.Captured),
		hidden = on(Tags.Hidden),
		bubbled = on(Tags.Bubbled),
		slipping = on(Tags.Slipping),
		operating = on(Tags.Operating),
		carryClass = if type(carryClass) == "string" then carryClass else nil,
		rolling = on(Tags.Rolling),
		twoCarry = character:GetAttribute(Tags.CarryPartner) ~= nil,
		crouching = character:GetAttribute(Tags.Crouching) == true,
		speedCap = if on(Tags.InGoo) then Config.Movement.Goo else nil,
		jumpCap = if on(Tags.InGoo) then Config.Movement.GooJump else nil,
	}
end

-- What the player may do right now (speed, crouch, gadgets). nil without a character.
function MovementService:Resolve(player: Player): Movement.Result?
	local character = player.Character
	if not character then
		return nil
	end
	return Movement.resolve(flagsOf(character), statsOf(player))
end

-- Gadgets and the Crowbar are allowed (not frozen, caught, hidden …, hands not full).
function MovementService:CanGadget(player: Player): boolean
	local result = MovementService:Resolve(player)
	return result ~= nil and result.canGadget
end

function MovementService:Refresh(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local flags = flagsOf(character)
	-- Full hands cancel crouching (Operating keeps its own crouch pose for the drone camera).
	if flags.crouching and Movement.handsFull(flags.carryClass) then
		character:SetAttribute(Tags.Crouching, false)
		flags.crouching = false
	end
	local result = Movement.resolve(flags, statsOf(player))
	applied[humanoid] = { walk = result.walkSpeed, jump = result.jumpHeight }
	humanoid.UseJumpPower = false
	if humanoid.WalkSpeed ~= result.walkSpeed then
		humanoid.WalkSpeed = result.walkSpeed
	end
	if humanoid.JumpHeight ~= result.jumpHeight then
		humanoid.JumpHeight = result.jumpHeight
	end
end

local function hookCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	if character:GetAttribute(Tags.Crouching) == nil then
		character:SetAttribute(Tags.Crouching, false)
	end
	for _, name in WATCHED do
		character:GetAttributeChangedSignal(name):Connect(function()
			MovementService:Refresh(player)
		end)
	end
	-- Someone else wrote a speed: put ours back.
	local function enforce()
		local want = applied[humanoid]
		if want then
			if humanoid.WalkSpeed ~= want.walk then
				humanoid.WalkSpeed = want.walk
			end
			if humanoid.JumpHeight ~= want.jump then
				humanoid.JumpHeight = want.jump
			end
		end
	end
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(enforce)
	humanoid:GetPropertyChangedSignal("JumpHeight"):Connect(enforce)
	humanoid.AncestryChanged:Connect(function()
		if not humanoid:IsDescendantOf(game) then
			applied[humanoid] = nil
		end
	end)
	MovementService:Refresh(player)
end

local function onCrouch(player: Player, on: any)
	if type(on) ~= "boolean" then
		return
	end
	local now = os.clock()
	if now - (lastCrouch[player] or 0) < 0.15 then
		return
	end
	lastCrouch[player] = now
	local character = player.Character
	if not character or character:GetAttribute(Tags.Operating) then
		return
	end
	if on then
		local result = MovementService:Resolve(player)
		if not result or not result.canCrouch then
			if Movement.handsFull(character:GetAttribute(Tags.CarryClass) :: any) then
				Net.send(player, "Toast", "Hands full!")
			end
			return
		end
	end
	character:SetAttribute(Tags.Crouching, on)
	MovementService:Refresh(player)
end

function MovementService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			hookCharacter(player, character)
		end)
		if player.Character then
			task.spawn(hookCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCrouch[player] = nil
	end)
	-- MovementService owns `Crouch`. Registered deferred so it replaces the prototype handler in GadgetService
	-- (package C removes that one) whatever order the services start in.
	task.defer(function()
		Net.onRequest("Crouch", onCrouch)
	end)
end

return MovementService
