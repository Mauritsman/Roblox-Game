--!strict
-- Gameplay markers for every heist (docs/contracts.md §2.5 and §3, beta-spec §2.6, §4.1, §6.1):
-- loot anchors, hide spots, exits with their bank zone, zone volumes, hazard anchors and other point anchors.
--
-- A point anchor is an invisible, anchored part with CanCollide, CanQuery and CanTouch off. Its CFrame is the
-- item's bottom centre, facing -Z (turned by rotY degrees). Zone volumes are invisible boxes (no collision, no
-- queries). Point anchors and volumes live under `Level.Anchors`; hide spots and exits are Models with their props.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Builder)

local C = Builder.Colors

local Anchors = {}

export type AttrValue = string | number | boolean | Vector3 | CFrame

-- The `Anchors` folder in the level (created on first use).
function Anchors.folder(level: Instance): Folder
	local existing = level:FindFirstChild("Anchors")
	if existing and existing:IsA("Folder") then
		return existing
	end
	return Builder.folder(level, "Anchors")
end

local function hidden(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- An invisible point anchor at `ground` (bottom centre), turned rotY degrees, with a tag and attributes.
function Anchors.point(
	parent: Instance,
	name: string,
	tag: string?,
	ground: Vector3,
	attrs: { [string]: AttrValue }?,
	rotY: number?
): Part
	local part = Builder.block(
		parent,
		name,
		Vector3.new(1, 1, 1),
		CFrame.new(ground) * CFrame.Angles(0, math.rad(rotY or 0), 0),
		C.Gold
	)
	hidden(part)
	if attrs then
		for key, value in attrs do
			part:SetAttribute(key, value)
		end
	end
	if tag then
		CollectionService:AddTag(part, tag)
	end
	return part
end

export type LootOpts = {
	group: string?, -- only loot entries/objectives with this Group (Drawer, Keycard, Secret, a safe id)
	fixed: boolean?, -- always filled (mini-job)
	opener: boolean?, -- first-loot spot near the spawn (Public, ≤ 40 studs)
	rotY: number?,
}

-- A loot anchor (tag LootAnchor; AnchorClass, AnchorId, Zone, Group?, Fixed?, Opener?).
function Anchors.loot(
	parent: Instance,
	id: string,
	class: string,
	ground: Vector3,
	zone: string,
	opts: LootOpts?
): Part
	local o: LootOpts = opts or {}
	local part = Anchors.point(parent, `Loot_{id}`, Tags.LootAnchor, ground, {
		[Tags.AnchorClass] = class,
		[Tags.AnchorId] = id,
		[Tags.Zone] = zone,
	}, o.rotY)
	if o.group then
		part:SetAttribute(Tags.Group, o.group)
	end
	if o.fixed then
		part:SetAttribute(Tags.Fixed, true)
	end
	if o.opener then
		part:SetAttribute(Tags.Opener, true)
	end
	return part
end

-- An invisible zone box between two corners, with a tag (StaffZone, SecureZone, DogZone, ColdZone, …).
function Anchors.volume(
	parent: Instance,
	name: string,
	tag: string,
	a: Vector3,
	b: Vector3,
	attrs: { [string]: AttrValue }?
): Part
	local part = Builder.box(parent, name, a, b, C.Safety)
	hidden(part)
	if attrs then
		for key, value in attrs do
			part:SetAttribute(key, value)
		end
	end
	CollectionService:AddTag(part, tag)
	return part
end

-- Hazard anchor (Wet Floor puddles): point anchor with tag HazardAnchor and an AnchorId.
function Anchors.hazard(parent: Instance, index: number, ground: Vector3): Part
	return Anchors.point(parent, `Hazard{index}`, Tags.HazardAnchor, ground, { [Tags.AnchorId] = `H{index}` })
end

-- Hide spot props: size (W × H × D) of the AI prop and of its block fallback.
local HIDE_SIZES: { [string]: Vector3 } = {
	TallCask = Vector3.new(3.6, 6, 3.6),
	Dumpster = Vector3.new(6, 5.6, 4),
	Locker = Vector3.new(2.4, 7, 2.4),
	Crate = Vector3.new(5.8, 5.5, 5.8), -- the Crate prop × 1.45
}
Anchors.HideSizes = HIDE_SIZES

local function hideFallback(kind: string, size: Vector3): (Instance, Vector3, number) -> Instance
	return function(p: Instance, g: Vector3, rotY: number): Instance
		local model = Instance.new("Model")
		model.Name = `{kind}Stub`
		local cf = CFrame.new(g) * CFrame.Angles(0, math.rad(rotY), 0)
		if kind == "TallCask" then
			Builder.cylinder(model, "Cask", size.X, size.Y, g + Vector3.new(0, size.Y / 2, 0), C.WoodDark, {
				material = Enum.Material.Wood,
			})
			for _, y in { 1, size.Y - 1 } do
				Builder.cylinder(
					model,
					"Hoop",
					size.X + 0.15,
					0.3,
					g + Vector3.new(0, y, 0),
					C.Metal,
					{ material = Enum.Material.Metal }
				)
			end
		elseif kind == "Dumpster" then
			Builder.block(
				model,
				"Bin",
				Vector3.new(size.X, size.Y - 0.4, size.Z),
				cf * CFrame.new(0, (size.Y - 0.4) / 2, 0),
				Color3.fromRGB(46, 96, 60),
				{ material = Enum.Material.Metal }
			)
			Builder.block(
				model,
				"Lid",
				Vector3.new(size.X + 0.2, 0.4, size.Z + 0.2),
				cf * CFrame.new(0, size.Y - 0.2, 0),
				Color3.fromRGB(34, 70, 44),
				{ material = Enum.Material.Metal }
			)
		elseif kind == "Locker" then
			Builder.block(
				model,
				"Cabinet",
				size,
				cf * CFrame.new(0, size.Y / 2, 0),
				Color3.fromRGB(120, 128, 136),
				{ material = Enum.Material.Metal }
			)
			Builder.block(
				model,
				"Vents",
				Vector3.new(size.X * 0.6, 0.8, 0.05),
				cf * CFrame.new(0, size.Y - 1.2, -size.Z / 2 - 0.02),
				Color3.fromRGB(60, 64, 70),
				{ collide = false, shadow = false }
			)
		else
			Builder.block(model, "CrateBox", size, cf * CFrame.new(0, size.Y / 2, 0), C.Wood, {
				material = Enum.Material.WoodPlanks,
			})
		end
		model.Parent = p
		return model
	end
end

export type HideOpts = {
	scale: number?, -- Crate only (default 1.45)
}

-- A hide spot (contract: Model tagged HideSpot, HideKind; PrimaryPart `Root` with Attachments `Inside` and `Exit`).
-- `ground` = bottom centre of the prop; the front (where you climb out) faces -Z turned by rotY degrees.
-- Hidden players are made invisible and parked at `Inside`; `Exit` is 2.5 studs in front of the prop.
function Anchors.hide(parent: Instance, kind: string, ground: Vector3, rotY: number?, opts: HideOpts?): Model
	local model = Instance.new("Model")
	model.Name = `HideSpot_{kind}`
	model:SetAttribute(Tags.HideKind, kind)
	CollectionService:AddTag(model, Tags.HideSpot)
	local rot = rotY or 0
	local size = HIDE_SIZES[kind] or Vector3.new(4, 5.5, 4)
	local scale = 1
	if kind == "Crate" then
		scale = (opts and opts.scale) or 1.45
		size = Vector3.new(4, 3.8, 4) * scale
	end
	local root = Builder.block(
		model,
		"Root",
		size,
		CFrame.new(ground + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, math.rad(rot), 0),
		C.Safety
	)
	hidden(root)
	local inside = Instance.new("Attachment")
	inside.Name = "Inside"
	inside.CFrame = CFrame.new(0, -size.Y / 2 + 3, 0)
	inside.Parent = root
	local exit = Instance.new("Attachment")
	exit.Name = Tags.Exit
	exit.CFrame = CFrame.new(0, -size.Y / 2 + 3, -(size.Z / 2 + 2.5))
	exit.Parent = root
	Builder.prop(model, kind, ground, rot, {
		scale = if kind == "Crate" then scale else nil,
		fallback = hideFallback(kind, size),
	})
	model.PrimaryPart = root
	model.Parent = parent
	return model
end

export type ExitSpec = {
	kind: string, -- ExitKind: Van | Boat | Bike | Balloon
	name: string?,
	bankMin: Vector3, -- BankZone box corners
	bankMax: Vector3,
	drivePoint: Vector3, -- where the DrivePrompt goes (driver's door, helm)
	optional: boolean?,
	quietOnly: boolean?,
	lockdownOnly: boolean?,
	arrivesAt: number?,
	session: string?, -- BankZone Session (default "Crew")
}

-- An exit (contract: Model tagged Exit, ExitKind, Optional?, QuietOnly?, LockdownOnly?, ArrivesAt?; children
-- `BankZone` (tag BankZone, Session) and `DrivePoint`). Put the vehicle's parts inside the model: an inactive
-- optional exit is destroyed as a whole.
function Anchors.exit(parent: Instance, spec: ExitSpec): Model
	local model = Instance.new("Model")
	model.Name = spec.name or `Exit_{spec.kind}`
	model:SetAttribute(Tags.ExitKind, spec.kind)
	if spec.optional then
		model:SetAttribute(Tags.Optional, true)
	end
	if spec.quietOnly then
		model:SetAttribute(Tags.QuietOnly, true)
	end
	if spec.lockdownOnly then
		model:SetAttribute(Tags.LockdownOnly, true)
	end
	if spec.arrivesAt then
		model:SetAttribute(Tags.ArrivesAt, spec.arrivesAt)
	end
	CollectionService:AddTag(model, Tags.Exit)
	local zone = Builder.box(model, "BankZone", spec.bankMin, spec.bankMax, C.CrewOrange)
	hidden(zone)
	zone:SetAttribute(Tags.Session, spec.session or "Crew")
	CollectionService:AddTag(zone, Tags.BankZone)
	Anchors.point(model, "DrivePoint", nil, spec.drivePoint)
	model.PrimaryPart = zone
	model.Parent = parent
	return model
end

return Anchors
