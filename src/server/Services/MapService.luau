--!strict
-- Bouwt de graybox van ketenpunt 2 (de rijpingshal, §10.2) uit code.
-- Zo staat het level als tekst in Git en kan Claude het aanpassen en opnieuw bouwen.
--
-- Indeling (studs, bovenkant baseplate = y 0):
--   x -30..-10  buiten: spawn, busje, gadgetrek
--   x   0.. 60  de hal (muren 16 hoog), deuropening west op z -4..4
--   rekken op z ±9 (x 12..38), kooi met de Golden Gouda op x 50..58
--   twee camera's op palen bij (44, 9, ±10), bewaker loopt een lus van ±25 s

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)

local MapService = {}
MapService.LevelBuilt = Signal.new() :: Signal.Signal<Folder>
MapService.Level = nil :: Folder?

-- Belangrijke posities die andere services gebruiken.
MapService.Points = {
	Spawn = Vector3.new(-25, 3, 0),
	GuardStart = Vector3.new(8, 3, -18),
	GuardRoute = {
		Vector3.new(8, 0, -18),
		Vector3.new(48, 0, -18),
		Vector3.new(48, 0, 18),
		Vector3.new(8, 0, 18),
	},
}

local COLORS = {
	Floor = Color3.fromRGB(70, 72, 80),
	Wall = Color3.fromRGB(96, 100, 112),
	Shelf = Color3.fromRGB(120, 88, 60),
	Cheese = Color3.fromRGB(240, 196, 70),
	Gold = Color3.fromRGB(255, 205, 40),
	Cage = Color3.fromRGB(60, 62, 70),
	Van = Color3.fromRGB(255, 128, 32),
	Camera = Color3.fromRGB(35, 35, 40),
	LampWarm = Color3.fromRGB(255, 196, 130),
}

local GADGET_COLORS: { [string]: Color3 } = {
	Drone = Color3.fromRGB(70, 160, 255),
	Noisemaker = Color3.fromRGB(255, 210, 60),
	EMP = Color3.fromRGB(80, 220, 255),
	BubbleBlaster = Color3.fromRGB(255, 140, 220),
	Crowbar = Color3.fromRGB(255, 90, 80),
}
MapService.GadgetColors = GADGET_COLORS

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function block(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	extra: { [string]: any }?
): Part
	local part = make("Part", {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Anchored = true,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, nil)
	if extra then
		for key, value in extra do
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

local function label(adornee: BasePart, text: string, color: Color3, offsetY: number)
	local gui = make("BillboardGui", {
		Name = "Label",
		Size = UDim2.fromOffset(160, 36),
		StudsOffset = Vector3.new(0, offsetY, 0),
		AlwaysOnTop = false,
		MaxDistance = 60,
		Adornee = adornee,
	}, adornee)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}, gui)
end

local function wheel(
	name: string,
	position: Vector3,
	diameter: number,
	height: number,
	color: Color3,
	parent: Instance
): Part
	-- Een kaaswiel: cilinder met verticale as (Roblox-cilinders liggen standaard langs X).
	local part = block(
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		parent
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(28, 30, 44)
	Lighting.OutdoorAmbient = Color3.fromRGB(46, 50, 72)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.FogEnd = 400
end

local function buildOutside(level: Folder)
	local outside = make("Folder", { Name = "Outside" }, level)

	make("SpawnLocation", {
		Name = "CrewSpawn",
		Size = Vector3.new(6, 1, 6),
		CFrame = CFrame.new(-25, 0.5, 0),
		Anchored = true,
		Neutral = true,
		Duration = 0,
		Color = COLORS.Van,
		Material = Enum.Material.SmoothPlastic,
	}, outside)

	local van = block("Van", Vector3.new(6, 6, 12), CFrame.new(-25, 3, -12), COLORS.Van, outside)
	label(van, "THE VAN", Color3.new(1, 1, 1), 5)

	-- Gadgetrek: bij een sokkel op E (of de knop op het scherm) om het gadget te nemen of terug te leggen.
	for index, gadgetName in Config.GadgetOrder do
		local z = -7.5 + (index - 1) * 5
		local pedestal = block(
			"Pedestal_" .. gadgetName,
			Vector3.new(3, 1.2, 3),
			CFrame.new(-16, 0.6, z),
			GADGET_COLORS[gadgetName],
			outside,
			{ Material = Enum.Material.Neon }
		)
		pedestal:SetAttribute("Gadget", gadgetName)
		CollectionService:AddTag(pedestal, Tags.GadgetPedestal)
		label(
			pedestal,
			(Config.Gadgets[gadgetName].Label or gadgetName):upper(),
			GADGET_COLORS[gadgetName],
			2.5
		)
	end
end

local function buildHall(level: Folder)
	local hall = make("Folder", { Name = "Hall" }, level)
	block("Floor", Vector3.new(60, 0.2, 50), CFrame.new(30, 0.1, 0), COLORS.Floor, hall, {
		Material = Enum.Material.Concrete,
	})

	-- Muren (hoogte 16) met een deuropening in het westen.
	block("WallNorth", Vector3.new(62, 16, 1), CFrame.new(30, 8, 25.5), COLORS.Wall, hall)
	block("WallSouth", Vector3.new(62, 16, 1), CFrame.new(30, 8, -25.5), COLORS.Wall, hall)
	block("WallEast", Vector3.new(1, 16, 52), CFrame.new(60.5, 8, 0), COLORS.Wall, hall)
	block("WallWestA", Vector3.new(1, 16, 21.5), CFrame.new(-0.5, 8, -14.75), COLORS.Wall, hall)
	block("WallWestB", Vector3.new(1, 16, 21.5), CFrame.new(-0.5, 8, 14.75), COLORS.Wall, hall)
	block("WallWestLintel", Vector3.new(1, 6, 8), CFrame.new(-0.5, 13, 0), COLORS.Wall, hall)
	block("Roof", Vector3.new(62, 1, 52), CFrame.new(30, 16.5, 0), COLORS.Wall, hall)

	-- Rekken met kaaswielen (dekking voor spelers).
	for _, z in { -9, 9 } do
		local shelf = block("Shelf", Vector3.new(26, 8, 3), CFrame.new(25, 4, z), COLORS.Shelf, hall, {
			Material = Enum.Material.WoodPlanks,
		})
		shelf:SetAttribute("Cover", true)
		for i = 0, 5 do
			wheel("CheeseDecor", Vector3.new(14 + i * 4.4, 8.75, z), 2.6, 1.5, COLORS.Cheese, hall)
		end
	end

	-- Hanglampen (vallen uit door een EMP: donker = bewakers zien je op halve afstand).
	local lampPositions = {
		Vector3.new(10, 13, 0),
		Vector3.new(26, 13, -17),
		Vector3.new(26, 13, 17),
		Vector3.new(46, 12, 0),
	}
	for index, position in lampPositions do
		local lamp =
			block(`Lamp{index}`, Vector3.new(2, 0.6, 2), CFrame.new(position), COLORS.LampWarm, hall, {
				Material = Enum.Material.Neon,
			})
		make("PointLight", {
			Name = "Light",
			Range = 22,
			Brightness = 1.6,
			Color = COLORS.LampWarm,
			Shadows = true,
		}, lamp)
		lamp:SetAttribute(Tags.Disabled, false)
		CollectionService:AddTag(lamp, Tags.Lamp)
		CollectionService:AddTag(lamp, Tags.Electronic)
	end
end

local function buildCage(level: Folder)
	local cage = make("Folder", { Name = "Cage" }, level)
	local fence = { Transparency = 0.45, Material = Enum.Material.DiamondPlate }
	block("CageNorth", Vector3.new(8, 10, 0.4), CFrame.new(54, 5, 6), COLORS.Cage, cage, fence)
	block("CageSouth", Vector3.new(8, 10, 0.4), CFrame.new(54, 5, -6), COLORS.Cage, cage, fence)
	block("CageEast", Vector3.new(0.4, 10, 12), CFrame.new(58, 5, 0), COLORS.Cage, cage, fence)
	block("CageWestA", Vector3.new(0.4, 10, 4), CFrame.new(50, 5, -4), COLORS.Cage, cage, fence)
	block("CageWestB", Vector3.new(0.4, 10, 4), CFrame.new(50, 5, 4), COLORS.Cage, cage, fence)
	block("CageTop", Vector3.new(8, 0.4, 12), CFrame.new(54, 10, 0), COLORS.Cage, cage, fence)

	local door = block("CageDoor", Vector3.new(0.6, 10, 4), CFrame.new(50, 5, 0), COLORS.Cage, cage, {
		Transparency = 0.2,
		Material = Enum.Material.DiamondPlate,
	})
	door:SetAttribute("PrySeconds", Config.Gadgets.Crowbar.CageSeconds)
	door:SetAttribute(Tags.SpotKind, "lock")
	CollectionService:AddTag(door, Tags.Pryable)
	CollectionService:AddTag(door, Tags.Spottable)
	make("PointLight", { Range = 6, Brightness = 0.6, Color = Color3.fromRGB(255, 80, 80) }, door)

	local gouda = wheel("GoldenGouda", Vector3.new(55, 1.2, 0), 4, 2, COLORS.Gold, cage)
	gouda.Material = Enum.Material.Foil
	gouda:SetAttribute(Tags.SpotKind, "loot")
	CollectionService:AddTag(gouda, Tags.Goal)
	CollectionService:AddTag(gouda, Tags.Spottable)
	label(gouda, "GOLDEN GOUDA", COLORS.Gold, 3)
	make("PointLight", { Range = 8, Brightness = 1, Color = COLORS.Gold }, gouda)
end

local function buildSecurityCamera(parent: Instance, name: string, mount: Vector3, lookAt: Vector3)
	local model = make("Model", { Name = name }, parent)
	block(
		"Pole",
		Vector3.new(0.6, mount.Y, 0.6),
		CFrame.new(mount.X, mount.Y / 2, mount.Z),
		COLORS.Camera,
		model
	)
	local body = block("Body", Vector3.new(1.2, 1.2, 2.4), CFrame.lookAt(mount, lookAt), COLORS.Camera, model)
	local led = block(
		"Led",
		Vector3.new(0.3, 0.3, 0.2),
		body.CFrame * CFrame.new(0, 0.3, -1.25),
		Color3.fromRGB(255, 40, 40),
		model,
		{
			Material = Enum.Material.Neon,
		}
	)
	-- De rode spotlight toont waar de camera kijkt (kinderen hoeven niet te raden).
	make("SpotLight", {
		Name = "Cone",
		Face = Enum.NormalId.Front,
		Angle = Config.SecurityCamera.ConeHalfAngle * 2,
		Range = Config.SecurityCamera.Range,
		Brightness = 2,
		Color = Color3.fromRGB(255, 60, 60),
		Shadows = true,
	}, body)
	model.PrimaryPart = body
	model:SetAttribute(Tags.Disabled, false)
	model:SetAttribute(Tags.SpotKind, "camera")
	model:SetAttribute("BaseLook", (lookAt - mount).Unit)
	led:SetAttribute("IsLed", true)
	CollectionService:AddTag(model, Tags.SecurityCamera)
	CollectionService:AddTag(model, Tags.Electronic)
	CollectionService:AddTag(model, Tags.Spottable)
end

local function buildCameras(level: Folder)
	local cams = make("Folder", { Name = "Cameras" }, level)
	buildSecurityCamera(cams, "CameraNorth", Vector3.new(44, 9, 10), Vector3.new(50, 0, -2))
	buildSecurityCamera(cams, "CameraSouth", Vector3.new(44, 9, -10), Vector3.new(50, 0, 2))
end

-- Bouwt (of herbouwt) het hele level in Workspace.Level.
function MapService:Build(): Folder
	local old = workspace:FindFirstChild("Level")
	if old then
		old:Destroy()
	end
	local level = make("Folder", { Name = "Level" }, nil)
	buildOutside(level)
	buildHall(level)
	buildCage(level)
	buildCameras(level)
	level.Parent = workspace
	self.Level = level
	self.LevelBuilt:Fire(level)
	return level
end

local function setupCollisionGroups()
	-- De drone botst met muren, maar niet met spelers of bewakers (hij mag niemand wegduwen).
	for _, group in { "Players", "Guards", "Drone" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Drone", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Drone", "Guards", false)
end

function MapService:Init()
	setupCollisionGroups()
	setupLighting()
	self:Build()
end

return MapService
