--!strict
-- What guards, cameras, snitches and Boef need to know about a player and the round, read from attributes
-- (docs/contracts.md §2). Shared by the package-B services so every viewer uses the same rules.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Detection = require(ReplicatedStorage.Shared.Logic.Detection)
local Difficulty = require(ReplicatedStorage.Shared.Logic.Difficulty)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Targets = {}

export type View = {
	player: Player,
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
}

function Targets.now(): number
	return workspace:GetServerTimeNow()
end

-- A living character with a root part, or nil.
function Targets.view(player: Player): View?
	local character = player.Character
	if not character or character.Parent == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return { player = player, character = character, root = root, humanoid = humanoid }
end

-- Player attribute Activity. Before RoundService sets it (prototype), everyone counts as crew.
function Targets.activity(player: Player): string
	local activity = player:GetAttribute(Tags.Activity)
	return if typeof(activity) == "string" then activity else "Crew"
end

function Targets.isCrew(player: Player): boolean
	return Targets.activity(player) == "Crew"
end

-- Crew players with a living character.
function Targets.crewViews(): { View }
	local list = {}
	for _, player in Players:GetPlayers() do
		if Targets.isCrew(player) then
			local view = Targets.view(player)
			if view then
				table.insert(list, view)
			end
		end
	end
	return list
end

-- Guards, cameras and snitches ignore this player (caught, hidden, not crew, immune, unmasked).
function Targets.ignored(player: Player, character: Model, now: number): boolean
	local immune = character:GetAttribute(Tags.ImmuneUntil)
	local masked = character:GetAttribute(Tags.Masked)
	local ignored = Detection.isIgnored({
		activity = Targets.activity(player),
		caught = character:GetAttribute(Tags.Caught) == true,
		hidden = character:GetAttribute(Tags.Hidden) == true,
		immuneUntil = if typeof(immune) == "number" then immune else nil,
		masked = if Config.Features.MaskUp and typeof(masked) == "boolean" then masked else nil,
	}, now)
	return ignored
end

-- Carry class for detection: rolling and two-carry count as heavy (beta-spec §3.1).
function Targets.carryClass(character: Model): string?
	local class = character:GetAttribute(Tags.CarryClass)
	if
		character:GetAttribute(Tags.Rolling) == true
		or typeof(character:GetAttribute(Tags.CarryPartner)) == "number"
	then
		return "Heavy"
	end
	return if typeof(class) == "string" then class else nil
end

-- Carrying anything (hands or pockets)?
function Targets.hasLoot(character: Model): boolean
	local pockets = character:GetAttribute(Tags.Pockets)
	return typeof(character:GetAttribute(Tags.CarryClass)) == "string"
		or (typeof(pockets) == "number" and pockets > 0)
end

-- Display name → loot type key (for PocketItems / CarryLoot, which hold display names).
local typeByDisplay: { [string]: string } = {}
for typeName, def in Config.Loot.Types do
	typeByDisplay[def.Display or typeName] = typeName
	typeByDisplay[typeName] = typeName
end

-- Loot models this player carries (hands and pockets), by CarrierId.
function Targets.carriedLoot(player: Player): { Instance }
	local list = {}
	for _, loot in CollectionService:GetTagged(Tags.Loot) do
		if loot:GetAttribute(Tags.CarrierId) == player.UserId then
			local state = loot:GetAttribute(Tags.LootState)
			if state == nil or state == "Carried" then
				table.insert(list, loot)
			end
		end
	end
	return list
end

local function typeOf(loot: Instance): string?
	local lootType = loot:GetAttribute(Tags.LootType)
	return if typeof(lootType) == "string" then lootType else nil
end

local function isSmelly(typeName: string?): boolean
	local def = if typeName then Config.Loot.Types[typeName] else nil
	return def ~= nil and def.Smelly == true
end

-- Does this player carry smelly loot (Boef)? Pocket loot counts.
function Targets.smelly(player: Player, character: Model): boolean
	for _, loot in Targets.carriedLoot(player) do
		if isSmelly(typeOf(loot)) then
			return true
		end
	end
	local held = character:GetAttribute(Tags.CarryLoot)
	if typeof(held) == "string" and isSmelly(typeByDisplay[held]) then
		return true
	end
	local pocket = character:GetAttribute(Tags.PocketItems)
	if typeof(pocket) == "string" then
		for name in string.gmatch(pocket, "[^,]+") do
			local trimmed = string.match(name, "^%s*(.-)%s*$") or name
			if isSmelly(typeByDisplay[trimmed]) then
				return true
			end
		end
	end
	return false
end

-- A smelly small loot model in this player's pockets (Boef's treat), or nil.
function Targets.smellySmall(player: Player): Instance?
	for _, loot in Targets.carriedLoot(player) do
		local typeName = typeOf(loot)
		local def = if typeName then Config.Loot.Types[typeName] else nil
		if def and def.Smelly and def.Class == "Small" then
			return loot
		end
	end
	return nil
end

-- Round context ---------------------------------------------------------------------------------------------

-- Is a heist running? (RoundPhase nil = prototype: always.)
function Targets.inHeist(): boolean
	local phase = ReplicatedStorage:GetAttribute(Tags.RoundPhase)
	return phase == nil or phase == "Heist" or phase == "Lockdown"
end

function Targets.lockdown(): boolean
	return ReplicatedStorage:GetAttribute(Tags.RoundPhase) == "Lockdown"
end

function Targets.modifier(): string?
	local modifier = ReplicatedStorage:GetAttribute(Tags.Modifier)
	return if typeof(modifier) == "string" and modifier ~= "" then modifier else nil
end

-- The round's difficulty numbers (Config.DifficultyTiers; Normal without a Difficulty attribute or with the
-- feature switched off).
function Targets.round(): Difficulty.Round
	local base = Difficulty.base(Config)
	if not Config.Features.Difficulty then
		return base
	end
	local name = ReplicatedStorage:GetAttribute(Tags.Difficulty)
	local tier =
		Difficulty.tier(Config.DifficultyTiers :: any, if typeof(name) == "string" then name else nil)
	return Difficulty.apply(base, tier)
end

function Targets.alarmLevel(): number
	local level = ReplicatedStorage:GetAttribute(Tags.AlarmLevel)
	return if typeof(level) == "number" then level else 0
end

-- Is this point inside the part's box?
function Targets.insidePart(part: BasePart, point: Vector3, margin: number?): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.one * (margin or 0)
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

-- World position of a Model, BasePart or Attachment.
function Targets.positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return nil
end

-- World CFrame of a Model, BasePart or Attachment.
function Targets.cframeOf(inst: Instance): CFrame?
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("Attachment") then
		return inst.WorldCFrame
	end
	return nil
end

return Targets
