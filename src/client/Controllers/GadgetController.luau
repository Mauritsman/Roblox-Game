--!strict
-- Gadgets gebruiken aan de kant van de speler: selecteren, richten, gooien, drone starten, hurken.
-- Alles wat telt, beslist de server; hier tonen we alleen een richtpunt en sturen we een verzoek.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local ClientState = require(Lib.ClientState)
local Hud = require(Lib.Hud)

local GadgetController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local aimFolder: Folder
local aimDisc: Part
local aimRing: Part
local droneWarning: BillboardGui

local THROWABLE = { Noisemaker = true, EMP = true, BubbleBlaster = true }

local function gadgets(): { string }
	local raw = player:GetAttribute(Tags.Gadgets)
	local list = {}
	if typeof(raw) == "string" and raw ~= "" then
		for name in string.gmatch(raw, "[^,]+") do
			table.insert(list, name)
		end
	end
	return list
end

local function selectedGadget(): string?
	local list = gadgets()
	if #list == 0 then
		return nil
	end
	local index = math.clamp(ClientState.selectedSlot, 1, #list)
	return list[index]
end

local function refreshHud()
	local list = gadgets()
	local selected = selectedGadget()
	local entries = {}
	for _, name in list do
		local charges = player:GetAttribute(Tags.Charges .. name)
		table.insert(entries, {
			name = name,
			label = Config.Gadgets[name].Label or name,
			charges = if typeof(charges) == "number" then charges else nil,
			selected = name == selected,
			step = Config.Gadgets[name].Step,
		})
	end
	local slots = player:GetAttribute(Tags.Slots)
	local battery = player:GetAttribute("DroneBattery")
	Hud.setLoadout(
		entries,
		if typeof(slots) == "number" then slots else 1,
		if typeof(battery) == "number" then battery else nil
	)
end

local function characterRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function screenRay(): Ray
	if Actions.preferredInput() == "KeyboardAndMouse" then
		local mouse = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

-- Waar wijst de speler naar? Gedeeld met de ping- en Chain Call-controllers.
function GadgetController.pointerHit(maxDistance: number?): RaycastResult?
	local ray = screenRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { aimFolder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(ray.Origin, ray.Direction * (maxDistance or 250), params)
end

local function computeAimPoint(gadgetName: string): Vector3?
	local root = characterRoot()
	if not root then
		return nil
	end
	local hit = GadgetController.pointerHit()
	local ray = screenRay()
	local point = if hit then hit.Position else ray.Origin + ray.Direction * 40
	local range = Config.Gadgets[gadgetName].ThrowRange
	local offset = point - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > range then
		point = root.Position + flat.Unit * range + Vector3.new(0, offset.Y, 0)
	end
	return point
end

local function setAiming(on: boolean)
	ClientState.set("aiming", on)
	if not on then
		ClientState.aimPoint = nil
	end
	aimFolder.Parent = if on then camera else nil
	if not on then
		droneWarning.Enabled = false
	end
end

local function throw()
	local gadgetName = selectedGadget()
	if not gadgetName or not THROWABLE[gadgetName] or not ClientState.aiming then
		return
	end
	local point = ClientState.aimPoint or computeAimPoint(gadgetName)
	setAiming(false)
	if point then
		Net.request("Throw", gadgetName, point)
	end
end

-- "Gebruiken" zonder richten: drone starten, of uitleg bij de Crowbar.
local function useSelected()
	local gadgetName = selectedGadget()
	if not gadgetName then
		Hud.toast("No gadget. Walk into a pedestal at the van.", Hud.Colors.Warn)
		return
	end
	if gadgetName == "Drone" then
		if ClientState.drone then
			Net.request("Drone", "recall")
		else
			Net.request("Drone", "launch")
		end
	elseif gadgetName == "Crowbar" then
		Hud.toast("Crowbar: hold E (or the on-screen button) at the cage door", Hud.Colors.Open)
	elseif THROWABLE[gadgetName] then
		setAiming(not ClientState.aiming)
	end
end

local function selectSlot(index: number)
	local list = gadgets()
	if #list == 0 then
		return
	end
	if ClientState.aiming then
		setAiming(false)
	end
	ClientState.set("selectedSlot", math.clamp(index, 1, #list))
	refreshHud()
end

local function updateAimVisual()
	if not ClientState.aiming or ClientState.drone then
		return
	end
	local gadgetName = selectedGadget()
	if not gadgetName or not THROWABLE[gadgetName] then
		setAiming(false)
		return
	end
	local point = computeAimPoint(gadgetName)
	ClientState.aimPoint = point
	if not point then
		return
	end
	local radius = if gadgetName == "EMP"
		then Config.Gadgets.EMP.Radius
		elseif gadgetName == "BubbleBlaster" then Config.Gadgets.BubbleBlaster.HitRadius
		else Config.Gadgets.Noisemaker.HearRadius
	aimDisc.CFrame = CFrame.new(point + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	aimRing.Size = Vector3.new(0.12, radius * 2, radius * 2)
	aimRing.CFrame = CFrame.new(point + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	aimRing.Color = if gadgetName == "EMP"
		then Color3.fromRGB(80, 220, 255)
		elseif gadgetName == "BubbleBlaster" then Color3.fromRGB(255, 150, 225)
		else Color3.fromRGB(255, 210, 60)

	-- §4.4: laat zien dat je eigen drone (of die van een teamgenoot) in de straal hangt.
	local warned = false
	if gadgetName == "EMP" then
		for _, drone in CollectionService:GetTagged(Tags.Drone) do
			if drone:IsA("BasePart") and (drone.Position - point).Magnitude <= radius then
				droneWarning.Adornee = drone
				droneWarning.Enabled = true
				warned = true
				break
			end
		end
	end
	if not warned then
		droneWarning.Enabled = false
	end
end

local function buildAimVisuals()
	aimFolder = Instance.new("Folder")
	aimFolder.Name = "AimVisuals"
	aimDisc = Instance.new("Part")
	aimDisc.Name = "Disc"
	aimDisc.Shape = Enum.PartType.Cylinder
	aimDisc.Size = Vector3.new(0.2, 2, 2)
	aimDisc.Material = Enum.Material.Neon
	aimDisc.Color = Color3.new(1, 1, 1)
	aimDisc.Anchored = true
	aimDisc.CanCollide = false
	aimDisc.CanQuery = false
	aimDisc.CastShadow = false
	aimDisc.Parent = aimFolder
	aimRing = Instance.new("Part")
	aimRing.Name = "Radius"
	aimRing.Shape = Enum.PartType.Cylinder
	aimRing.Material = Enum.Material.ForceField
	aimRing.Transparency = 0.2
	aimRing.Anchored = true
	aimRing.CanCollide = false
	aimRing.CanQuery = false
	aimRing.CastShadow = false
	aimRing.Parent = aimFolder

	droneWarning = Instance.new("BillboardGui")
	droneWarning.Name = "DroneWarning"
	droneWarning.Size = UDim2.fromOffset(170, 34)
	droneWarning.StudsOffset = Vector3.new(0, 2, 0)
	droneWarning.AlwaysOnTop = true
	droneWarning.Enabled = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "DRONE IN RANGE!"
	label.Parent = droneWarning
	droneWarning.Parent = player:WaitForChild("PlayerGui")
end

local function setCrouch(on: boolean)
	Net.request("Crouch", on) -- de camera volgt zodra de server het attribuut zet
end

function GadgetController:Init()
	buildAimVisuals()
end

function GadgetController:Start()
	for index = 1, 3 do
		Actions.on("Slot" .. index, function(phase)
			if phase == "Begin" then
				selectSlot(index)
			end
		end)
	end
	Actions.on("NextSlot", function(phase)
		if phase == "Begin" then
			local count = #gadgets()
			if count > 0 then
				selectSlot(ClientState.selectedSlot % count + 1)
			end
		end
	end)

	-- Muis: indrukken = richten (of gebruiken), loslaten = gooien.
	Actions.on("MouseAim", function(phase)
		if ClientState.drone then
			return -- in dronemodus is klikken = SPOT (DroneController)
		end
		local gadgetName = selectedGadget()
		if phase == "Begin" then
			if gadgetName and THROWABLE[gadgetName] then
				setAiming(true)
			else
				useSelected()
			end
		elseif phase == "End" and ClientState.aiming then
			throw()
		end
	end)

	-- Controller: L2 richten, R2 gooien/gebruiken.
	Actions.on("Aim", function(phase)
		local gadgetName = selectedGadget()
		if gadgetName and THROWABLE[gadgetName] and not ClientState.drone then
			setAiming(phase == "Begin")
		end
	end)
	Actions.on("Fire", function(phase)
		if phase ~= "Begin" or ClientState.drone then
			return
		end
		if ClientState.aiming then
			throw()
		else
			useSelected()
		end
	end)
	-- Aanraakscherm: gadgetknop = richten aan/uit (of gebruiken); THROW-knop = gooien.
	Actions.on("TouchGadget", function(phase)
		if phase == "Begin" and not ClientState.drone then
			useSelected()
		end
	end)
	Actions.on("Cancel", function(phase)
		if phase == "Begin" and ClientState.aiming then
			setAiming(false)
		end
	end)

	-- Hurken volgt het attribuut van de server (dat ook uitgaat na gepakt worden of na de drone).
	local function isCrouching(): boolean
		local character = player.Character
		return character ~= nil and character:GetAttribute(Tags.Crouching) == true
	end
	Actions.on("Crouch", function(phase)
		if phase == "Begin" and not ClientState.drone then
			setCrouch(not isCrouching())
		end
	end)
	local function watchCharacter(character: Model)
		setAiming(false)
		character:GetAttributeChangedSignal(Tags.Crouching):Connect(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and not ClientState.drone then
				humanoid.CameraOffset = if character:GetAttribute(Tags.Crouching) == true
					then Vector3.new(0, -1.6, 0)
					else Vector3.zero
			end
		end)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	-- Chain Call: op NOW gaat een klaargezette EMP of Noisemaker automatisch af (§3.4).
	ClientState.Changed:Connect(function(key)
		if key == "ChainNow" and ClientState.aiming then
			throw()
		end
	end)

	player.AttributeChanged:Connect(function(name)
		if
			name == Tags.Gadgets
			or name == Tags.Slots
			or name == "DroneBattery"
			or string.sub(name, 1, #Tags.Charges) == Tags.Charges
		then
			refreshHud()
		end
	end)
	refreshHud()

	RunService.RenderStepped:Connect(updateAimVisual)
end

return GadgetController
