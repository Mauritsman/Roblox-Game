--!strict
-- Security cameras for every heist (CameraService contract, src/server/Map/README.md):
--   Model tagged SecurityCamera + Electronic + Spottable; attributes Disabled = false, SpotKind = "camera",
--   BaseLook (resting look direction). Children: `Body` (PrimaryPart, rotates) with a SpotLight `Cone`; `Led`
--   (IsLed = true); hood and lens welded to Body (unanchored, massless). The bracket parts are named `Mount*`,
--   stay anchored and are not welded (they do not turn with the body).
-- Mounts: "ceiling" (rod up to `ceilingY`), "wall" (arm back to `wallPoint`), "pole" (floor pole), "none".
-- The cone casts no shadows (light budget: ≤ 9 shadowed lights per heist).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Builder)

local C = Builder.Colors

local Security = {}

export type MountKind = "ceiling" | "wall" | "pole" | "none"

export type CameraOpts = {
	mount: MountKind?, -- default "ceiling"
	ceilingY: number?, -- ceiling: height of the ceiling/truss above the body (default mount.Y + 2)
	wallPoint: Vector3?, -- wall: point on the wall face behind the camera
	floorY: number?, -- pole: floor height (default 0)
}

local function bar(parent: Instance, name: string, from: Vector3, to: Vector3, thickness: number)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local dir = (to - from).Unit
	if math.abs(dir.Y) > 0.99 then
		-- Vertical: lookAt would be degenerate.
		Builder.block(
			parent,
			name,
			Vector3.new(thickness, length, thickness),
			CFrame.new((from + to) / 2),
			C.Metal,
			{ material = Enum.Material.Metal, shadow = false }
		)
		return
	end
	Builder.block(
		parent,
		name,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt((from + to) / 2, to),
		C.Metal,
		{ material = Enum.Material.Metal, shadow = false }
	)
end

function Security.camera(
	parent: Instance,
	name: string,
	mount: Vector3,
	lookAt: Vector3,
	opts: CameraOpts?
): Model
	local o: CameraOpts = opts or {}
	local model = Instance.new("Model")
	model.Name = name

	-- Bracket (anchored, does not turn).
	local kind = o.mount or "ceiling"
	if kind == "ceiling" then
		local top = Vector3.new(mount.X, o.ceilingY or (mount.Y + 2), mount.Z)
		bar(model, "MountRod", mount + Vector3.new(0, 0.6, 0), top, 0.3)
		Builder.block(model, "MountPlate", Vector3.new(1, 0.2, 1), CFrame.new(top), C.Metal, {
			material = Enum.Material.Metal,
		})
	elseif kind == "wall" then
		local wall = o.wallPoint or (mount - (lookAt - mount).Unit * 1.5)
		local back = Vector3.new(wall.X, mount.Y + 0.6, wall.Z)
		bar(model, "MountArm", mount + Vector3.new(0, 0.6, 0), back, 0.3)
		Builder.block(model, "MountPlate", Vector3.new(0.8, 1.2, 0.8), CFrame.new(back), C.Metal, {
			material = Enum.Material.Metal,
		})
	elseif kind == "pole" then
		local floorY = o.floorY or 0
		Builder.box(
			model,
			"MountPole",
			Vector3.new(mount.X - 0.35, floorY, mount.Z - 0.35),
			Vector3.new(mount.X + 0.35, mount.Y - 0.4, mount.Z + 0.35),
			C.Metal,
			{ material = Enum.Material.Metal }
		)
	end

	-- Body rotates (CameraService); the rest is welded to it and turns along.
	local body = Builder.block(
		model,
		"Body",
		Vector3.new(1.3, 1.2, 2.4),
		CFrame.lookAt(mount, lookAt),
		Color3.fromRGB(230, 232, 236)
	)
	local function attach(part: BasePart)
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
	local hood = Builder.block(
		model,
		"Hood",
		Vector3.new(1.5, 0.25, 2.8),
		body.CFrame * CFrame.new(0, 0.7, -0.1),
		Color3.fromRGB(60, 64, 72)
	)
	attach(hood)
	local lens = Builder.cylinder(
		model,
		"Lens",
		0.6,
		0.3,
		(body.CFrame * CFrame.new(0, -0.2, -1.3)).Position,
		Color3.fromRGB(16, 18, 24),
		{ material = Enum.Material.Glass }
	)
	lens.CFrame = body.CFrame * CFrame.new(0, -0.2, -1.3) * CFrame.Angles(0, math.rad(90), 0)
	attach(lens)
	-- CameraService puts the LED at body * (0, 0.3, -1.25) every frame; same spot here.
	local led = Builder.block(
		model,
		"Led",
		Vector3.new(0.25, 0.25, 0.2),
		body.CFrame * CFrame.new(0, 0.3, -1.25),
		Color3.fromRGB(255, 40, 40),
		{ material = Enum.Material.Neon }
	)
	led:SetAttribute("IsLed", true)
	local cone = Instance.new("SpotLight")
	cone.Name = "Cone"
	cone.Face = Enum.NormalId.Front
	cone.Angle = Config.SecurityCamera.ConeHalfAngle * 2
	cone.Range = Config.SecurityCamera.Range
	cone.Brightness = 2
	cone.Color = Color3.fromRGB(255, 60, 60)
	cone.Shadows = false
	cone.Parent = body
	model.PrimaryPart = body
	model:SetAttribute(Tags.Disabled, false)
	model:SetAttribute(Tags.SpotKind, "camera")
	model:SetAttribute("BaseLook", (lookAt - mount).Unit)
	CollectionService:AddTag(model, Tags.SecurityCamera)
	CollectionService:AddTag(model, Tags.Electronic)
	CollectionService:AddTag(model, Tags.Spottable)
	model.Parent = parent
	return model
end

return Security
