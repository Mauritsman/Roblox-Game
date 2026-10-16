--!strict
-- Small helpers shared by the map runtime modules (MapRuntimeService and src/server/MapRuntime/*): attribute
-- readers that tolerate missing or wrong-typed attributes, volumes, crew lookups and the runtime calls into other
-- packages (GuardService, AlarmService, StatsService, MovementService), which are skipped when a service is absent.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Optional = require(script.Parent.Parent.Lib.Optional)

local Util = {}

-- What every runtime module gets in setup/phase/step.
export type Context = {
	level: Instance,
	info: any, -- SetupService heistInfo
	job: any, -- SetupService Job (seed, heistId, difficulty, modifierId, …)
	plan: any, -- RoundPlan plan (may be nil)
	seed: number,
	folder: Folder, -- parts the runtime creates live here (inside the level)
	phase: string,
	lockdown: boolean,
	lockdownAt: number?,
	startedAt: number?,
	roundEndsAt: number?,
}

-- A disconnect list per module.
export type Bag = { RBXScriptConnection }

function Util.now(): number
	return workspace:GetServerTimeNow()
end

--------------------------------------------------------------------------------------------------------------
-- Attributes
--------------------------------------------------------------------------------------------------------------

function Util.num(inst: Instance, name: string, default: number): number
	local value = inst:GetAttribute(name)
	return if type(value) == "number" and value == value then value else default
end

function Util.optNum(inst: Instance, name: string): number?
	local value = inst:GetAttribute(name)
	return if type(value) == "number" and value == value then value else nil
end

function Util.bool(inst: Instance, name: string, default: boolean): boolean
	local value = inst:GetAttribute(name)
	return if type(value) == "boolean" then value else default
end

function Util.str(inst: Instance, name: string): string?
	local value = inst:GetAttribute(name)
	return if type(value) == "string" and value ~= "" then value else nil
end

function Util.vec(inst: Instance, name: string): Vector3?
	local value = inst:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else nil
end

-- Sets an attribute only when it changes (fewer replication messages).
function Util.set(inst: Instance, name: string, value: any)
	if inst:GetAttribute(name) ~= value then
		inst:SetAttribute(name, value)
	end
end

--------------------------------------------------------------------------------------------------------------
-- Instances and volumes
--------------------------------------------------------------------------------------------------------------

-- Every instance with `tag` inside `root` (the level).
function Util.tagged(tag: string, root: Instance): { Instance }
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst == root or inst:IsDescendantOf(root) then
			table.insert(list, inst)
		end
	end
	return list
end

function Util.positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return nil
end

function Util.cframeOf(inst: Instance): CFrame?
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("Attachment") then
		return inst.WorldCFrame
	end
	return nil
end

-- The instance itself when it is a BasePart, plus every BasePart inside it.
function Util.parts(inst: Instance): { BasePart }
	local list: { BasePart } = {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- An oriented box for a part (its own box) or a model / folder (the bounding box of its parts).
function Util.box(inst: Instance): (CFrame?, Vector3?)
	if inst:IsA("BasePart") then
		return inst.CFrame, inst.Size
	elseif inst:IsA("Model") then
		local ok, cf, size = pcall(function()
			return inst:GetBoundingBox()
		end)
		if ok then
			return cf, size
		end
	end
	local parts = Util.parts(inst)
	if #parts == 0 then
		return nil, nil
	end
	local min, max = parts[1].Position, parts[1].Position
	for _, part in parts do
		local half = part.Size / 2
		min = min:Min(part.Position - half)
		max = max:Max(part.Position + half)
	end
	return CFrame.new((min + max) / 2), max - min
end

function Util.inBox(cf: CFrame, size: Vector3, position: Vector3, pad: number?): boolean
	local p = cf:PointToObjectSpace(position)
	local half = size / 2 + Vector3.one * (pad or 0)
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- A static volume read once: boxes of the instance's parts (a ball part counts as a sphere).
export type Volume = { boxes: { { cf: CFrame, size: Vector3, ball: boolean } } }

function Util.volume(inst: Instance): Volume
	local boxes = {}
	for _, part in Util.parts(inst) do
		local ball = part:IsA("Part") and part.Shape == Enum.PartType.Ball
		table.insert(boxes, { cf = part.CFrame, size = part.Size, ball = ball })
	end
	return { boxes = boxes }
end

function Util.inVolume(volume: Volume, position: Vector3): boolean
	for _, box in volume.boxes do
		if box.ball then
			if (position - box.cf.Position).Magnitude <= box.size.X / 2 then
				return true
			end
		elseif Util.inBox(box.cf, box.size, position) then
			return true
		end
	end
	return false
end

-- Moves a part or model (anchored parts) to a CFrame.
function Util.pivot(inst: Instance, cf: CFrame)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
	elseif inst:IsA("Model") then
		inst:PivotTo(cf)
	end
end

function Util.part(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--------------------------------------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------------------------------------

export type View = { player: Player, character: Model, root: BasePart, humanoid: Humanoid }

function Util.view(player: Player): View?
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

-- Crew members (Activity "Crew") with a living character.
function Util.crewViews(): { View }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(Tags.Activity) == "Crew" then
			local view = Util.view(player)
			if view then
				table.insert(list, view)
			end
		end
	end
	return list
end

local BLOCKING =
	{ Tags.Caught, Tags.Captured, Tags.Hidden, Tags.Frozen, Tags.Slipping, Tags.Bubbled, Tags.Operating }

-- Not caught, carried, hidden, frozen, slipping, bubbled or flying a drone.
function Util.isFree(character: Model): boolean
	for _, name in BLOCKING do
		local value = character:GetAttribute(name)
		if value ~= nil and value ~= false then
			return false
		end
	end
	return true
end

-- Ignored by guards and cameras (same rules as Logic/Detection.isIgnored): caught, hidden, immune, unmasked.
function Util.ignored(character: Model, now: number): boolean
	if character:GetAttribute(Tags.Caught) == true or character:GetAttribute(Tags.Captured) ~= nil then
		return true
	elseif character:GetAttribute(Tags.Hidden) == true then
		return true
	end
	local immune = character:GetAttribute(Tags.ImmuneUntil)
	if type(immune) == "number" and now < immune then
		return true
	end
	return Config.Features.MaskUp and character:GetAttribute(Tags.Masked) == false
end

-- Guards and cameras ignore immune players (Logic/Detection). Map effects that hide you (mist, wrapper) extend the
-- immunity instead of shortening anyone else's; returns the value now set.
function Util.extendImmunity(character: Model, untilTime: number): number
	local current = character:GetAttribute(Tags.ImmuneUntil)
	local value = if type(current) == "number" then math.max(current, untilTime) else untilTime
	Util.set(character, Tags.ImmuneUntil, value)
	return value
end

-- Ends an immunity this runtime set (only when nobody extended it since).
function Util.endImmunity(character: Model, written: number?)
	if written and character:GetAttribute(Tags.ImmuneUntil) == written then
		character:SetAttribute(Tags.ImmuneUntil, Util.now())
	end
end

--------------------------------------------------------------------------------------------------------------
-- Other packages (runtime lookups)
--------------------------------------------------------------------------------------------------------------

function Util.hearNoise(
	position: Vector3,
	radius: number,
	seconds: number?,
	kind: string,
	by: Player?
): number
	local ok, heard = Optional.call("GuardService", "HearNoise", position, radius, seconds, kind, by)
	return if ok and type(heard) == "number" then heard else 0
end

function Util.alarm(reason: string, points: number, player: Player?)
	Optional.call("AlarmService", "Add", reason, points, player)
end

function Util.event(name: string, player: Player, data: { [string]: any }?)
	Optional.call("StatsService", "Event", name, player, data or {})
end

function Util.refresh(player: Player)
	Optional.call("MovementService", "Refresh", player)
end

function Util.guards(): { Model }
	local ok, list = Optional.call("GuardService", "GetGuards")
	if ok and type(list) == "table" then
		return list
	end
	local found = {}
	for _, inst in CollectionService:GetTagged(Tags.Guard) do
		if inst:IsA("Model") and inst:IsDescendantOf(workspace) then
			table.insert(found, inst)
		end
	end
	return found
end

function Util.toast(text: string)
	Net.broadcast("Toast", text)
end

function Util.disconnect(bag: Bag)
	for _, connection in bag do
		connection:Disconnect()
	end
	table.clear(bag)
end

return Util
