--!strict
-- Wet Floor (beta-spec §6.2, Hot Job modifier "WetFloor"): puddles on the plan's hazard anchors. Entering one
-- faster than 10 studs/s (crouching is safe) → a 1 s slip (`Slipping` + MovementService:Refresh), a SQUEAK
-- (noise radius 15) and medium loot drops from your hands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Peers = require(script.Parent.Peers)
local Rig = require(script.Parent.Rig)
local Targets = require(script.Parent.Targets)

local W = Config.Modifiers.WetFloor
local RADIUS = 4

local Puddles = {}

type Puddle = { part: BasePart, inside: { [Player]: boolean? } }

local puddles: { Puddle } = {}
local hearNoise: ((position: Vector3, radius: number, kind: string, by: Player?) -> ())? = nil

function Puddles.setNoise(fn: (position: Vector3, radius: number, kind: string, by: Player?) -> ())
	hearNoise = fn
end

local function floorBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
	return if hit then hit.Position else position
end

-- hazardIds = plan.hazards; parts = heistInfo.hazardParts (id → anchor instance).
function Puddles.spawn(parent: Instance, hazardIds: { string }?, parts: { [string]: Instance }?)
	Puddles.clear()
	if not hazardIds or not parts then
		return
	end
	local folder = Rig.folder(parent, "Puddles")
	for _, id in hazardIds do
		local anchor = parts[id]
		local position = if anchor then Targets.positionOf(anchor) else nil
		if position then
			local floor = floorBelow(position)
			local part = Instance.new("Part")
			part.Name = "Puddle"
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(0.1, RADIUS * 2, RADIUS * 2)
			part.CFrame = CFrame.new(floor + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Material = Enum.Material.Glass
			part.Color = Color3.fromRGB(120, 180, 230)
			part.Transparency = 0.35
			part:SetAttribute("Hazard", "WetFloor")
			part.Parent = folder
			local puddle: Puddle = { part = part :: BasePart, inside = {} }
			table.insert(puddles, puddle)
		end
	end
end

function Puddles.clear()
	for _, puddle in puddles do
		if puddle.part.Parent then
			puddle.part:Destroy()
		end
	end
	table.clear(puddles)
end

local function slip(player: Player, character: Model, puddle: Puddle)
	character:SetAttribute(Tags.Slipping, true)
	Peers.refreshMovement(player)
	Rig.sound(puddle.part, "rbxasset://sounds/swoosh.wav", 1.8, 1)
	if character:GetAttribute(Tags.CarryClass) == "Medium" then
		Peers.call("CarryService", "DropHands", player, "slip")
	end
	if hearNoise then
		hearNoise(puddle.part.Position, W.SqueakRadius, "squeak", player)
	end
	task.delay(Config.Movement.SlipSeconds, function()
		if player.Character == character then
			character:SetAttribute(Tags.Slipping, nil)
			Peers.refreshMovement(player)
		end
	end)
end

-- Call about every 0.1 s.
function Puddles.step()
	if #puddles == 0 then
		return
	end
	for _, view in Targets.crewViews() do
		local character = view.character
		local position = view.root.Position
		for _, puddle in puddles do
			local center = puddle.part.Position
			local flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z).Magnitude
			local inside = flat <= RADIUS and math.abs(position.Y - 3 - center.Y) < 4
			local was = puddle.inside[view.player] == true
			puddle.inside[view.player] = if inside then true else nil
			if inside and not was then
				local velocity = view.root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if
					speed > W.SlipSpeed
					and character:GetAttribute(Tags.Crouching) ~= true
					and character:GetAttribute(Tags.Slipping) ~= true
					and character:GetAttribute(Tags.Caught) ~= true
				then
					slip(view.player, character, puddle)
				end
			end
		end
	end
end

return Puddles
