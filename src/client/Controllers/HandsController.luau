--!strict
-- "The primary button does what your hands allow" (beta-spec-ux §2.1):
--   empty hands / small loot → gadget (GadgetController, unchanged)
--   medium loot              → THROW: aim shows a dotted arc and a landing ring (max 10 studs, red when
--                              clamped, green "CATCH" when a teammate with free hands stands near it)
--   heavy loot               → ROLL on / off
-- Intercepts the primary inputs only while carrying, so gadgets never fire with full hands.
-- Sends LootThrow(target) / Roll(on); the server validates everything (beta-spec §9.2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local Audio = require(Lib.Audio)
local CharState = require(Lib.CharState)
local ClientState = require(Lib.ClientState)
local Device = require(Lib.Device)
local Hud = require(Lib.Hud)
local Theme = require(Lib.Theme)

local HandsController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local DOTS = 14
local folder: Folder
local dots: { Part } = {}
local ring: Part
local catchGui: BillboardGui
local catchLabel: TextLabel
local aimTarget: Vector3? = nil

local function carryConfig(key: string, default: number): number
	local carry = (Config :: any).Carry
	local value = if typeof(carry) == "table" then carry[key] else nil
	return if typeof(value) == "number" then value else default
end

local function throwRange(): number
	local fromPlayer = player:GetAttribute("ThrowRange")
	if typeof(fromPlayer) == "number" then
		return fromPlayer
	end
	return carryConfig("ThrowRange", Theme.UX.ThrowRange)
end

-- What the hands hold, when it changes the primary action: "Medium" | "Heavy" | "Help" | nil.
local function hands(): string?
	if ClientState.drone or ClientState.mode == "Cell" or ClientState.mode == "Carried" then
		return nil
	end
	local carry, role = CharState.carry()
	if not carry then
		return nil
	end
	if role == "Help" then
		return "Help"
	end
	return carry
end

local function root(): BasePart?
	return CharState.root()
end

local function screenRay(): Ray
	local cam = workspace.CurrentCamera or camera
	if Device.input() == "KeyboardAndMouse" then
		local mouse = UserInputService:GetMouseLocation()
		return cam:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local size = cam.ViewportSize
	return cam:ViewportPointToRay(size.X / 2, size.Y / 2)
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- Landing point: where you point, clamped to the throw range, dropped onto the floor.
local function computeTarget(): (Vector3?, boolean)
	local r = root()
	if not r then
		return nil, false
	end
	local params = rayParams()
	local ray = screenRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	local point = if hit then hit.Position else ray.Origin + ray.Direction * 30
	local offset = point - r.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local range = throwRange()
	local clamped = false
	if flat.Magnitude > range then
		clamped = true
		point = r.Position + flat.Unit * range
	elseif flat.Magnitude < 1 then
		point = r.Position + r.CFrame.LookVector * 3
	end
	local down = workspace:Raycast(point + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	if down then
		point = down.Position
	end
	return point, clamped
end

local function catcherNear(point: Vector3): Player?
	local range = carryConfig("CatchLanding", Theme.UX.CatchLanding)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local character = other.Character
			local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
			if character and otherRoot and otherRoot:IsA("BasePart") then
				local free = character:GetAttribute("CarryClass") == nil
					and character:GetAttribute("Captured") == nil
					and character:GetAttribute("Caught") ~= true
				local flat = Vector3.new(otherRoot.Position.X - point.X, 0, otherRoot.Position.Z - point.Z)
				if free and flat.Magnitude <= range then
					return other
				end
			end
		end
	end
	return nil
end

local function setVisible(on: boolean)
	folder.Parent = if on then workspace.CurrentCamera else nil
	catchGui.Enabled = false
end

local function stopAim()
	if ClientState.throwAiming then
		ClientState.set("throwAiming", false)
	end
	aimTarget = nil
	setVisible(false)
end

local function startAim()
	if hands() ~= "Medium" then
		return
	end
	ClientState.set("throwAiming", true)
	setVisible(true)
	Audio.play("UiTap", { pitch = 0.8 })
end

local function throw()
	if not ClientState.throwAiming and hands() ~= "Medium" then
		return
	end
	local target = aimTarget or computeTarget()
	stopAim()
	if target then
		Net.request("LootThrow", target)
		Audio.play("Throw")
	end
end

local function toggleRoll()
	if hands() ~= "Heavy" then
		return
	end
	local rolling = CharState.get("Rolling") == true
	Net.request("Roll", not rolling)
	Audio.play("UiTap", { pitch = if rolling then 0.8 else 1.1 })
end

local function updateAim()
	if not ClientState.throwAiming then
		return
	end
	if hands() ~= "Medium" then
		stopAim()
		return
	end
	local r = root()
	local target, clamped = computeTarget()
	if not r or not target then
		return
	end
	aimTarget = target
	local origin = r.Position + Vector3.new(0, 1.5, 0)
	local distance = (target - origin).Magnitude
	local height = math.max(2, carryConfig("ThrowArc", Theme.UX.ThrowArc) * distance)
	for index, dot in dots do
		local t = index / (DOTS + 1)
		local p = origin:Lerp(target, t) + Vector3.new(0, 4 * height * t * (1 - t), 0)
		dot.Position = p
	end
	local catcher = catcherNear(target)
	local color = if catcher
		then Theme.Colors.Good
		elseif clamped then Theme.Colors.Danger
		else Color3.new(1, 1, 1)
	ring.Color = color
	ring.CFrame = CFrame.new(target + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	for _, dot in dots do
		dot.Color = color
	end
	if catcher then
		catchGui.Enabled = true
		catchGui.Adornee = ring
		local crew = Theme.crew(catcher)
		catchLabel.Text = `{crew.glyph} CATCH`
		catchLabel.TextColor3 = Theme.Colors.Good
	else
		catchGui.Enabled = false
	end
end

local function build()
	folder = Instance.new("Folder")
	folder.Name = "ThrowAim"
	for index = 1, DOTS do
		local dot = Instance.new("Part")
		dot.Name = "Dot" .. index
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * 0.35
		dot.Material = Enum.Material.Neon
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Parent = folder
		dots[index] = dot
	end
	ring = Instance.new("Part")
	ring.Name = "Landing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, 3, 3)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = folder

	catchGui = Instance.new("BillboardGui")
	catchGui.Name = "CatchHint"
	catchGui.Size = UDim2.fromOffset(130, 36)
	catchGui.StudsOffset = Vector3.new(0, 2.5, 0)
	catchGui.AlwaysOnTop = true
	catchGui.Enabled = false
	catchLabel = Hud.text({
		Size = UDim2.fromScale(1, 1),
		Text = "CATCH",
		Display = true,
		MaxTextSize = 26,
		Stroke = 2,
	}, catchGui)
	catchGui.Parent = player:WaitForChild("PlayerGui")
end

function HandsController:Init()
	build()
end

function HandsController:Start()
	-- Mouse: press = aim, release = throw (medium); click = roll toggle (heavy).
	Actions.intercept("MouseAim", function(phase)
		local h = hands()
		if not h then
			return false
		end
		if h == "Medium" then
			if phase == "Begin" then
				startAim()
			elseif ClientState.throwAiming then
				throw()
			end
		elseif h == "Heavy" and phase == "Begin" then
			toggleRoll()
		end
		return true
	end)
	-- Gamepad: L2 = aim, R2 = throw / roll.
	Actions.intercept("Aim", function(phase)
		local h = hands()
		if not h then
			return false
		end
		if h == "Medium" then
			if phase == "Begin" then
				startAim()
			else
				stopAim()
			end
		end
		return true
	end)
	Actions.intercept("Primary", function(phase)
		local h = hands()
		if not h then
			return false
		end
		if phase == "Begin" then
			if h == "Medium" then
				throw()
			elseif h == "Heavy" then
				toggleRoll()
			end
		end
		return true
	end)
	-- Touch GADGET slot: tap = aim, tap again = throw (medium); tap = roll (heavy).
	Actions.intercept("TouchGadget", function(phase)
		local h = hands()
		if not h then
			return false
		end
		if phase == "Begin" then
			if h == "Medium" then
				if ClientState.throwAiming then
					throw()
				else
					startAim()
				end
			elseif h == "Heavy" then
				toggleRoll()
			end
		end
		return true
	end)
	Actions.intercept("Cancel", function(phase)
		if ClientState.throwAiming then
			if phase == "Begin" then
				stopAim()
			end
			return true
		end
		return false
	end)
	-- Gadget slots do nothing with full hands.
	for _, name in { "Slot1", "Slot2", "Slot3", "NextSlot" } do
		Actions.intercept(name, function()
			return hands() == "Medium" or hands() == "Heavy"
		end)
	end
	Actions.on("Roll", function(phase)
		if phase == "Begin" then
			toggleRoll()
		end
	end)

	CharState.Changed:Connect(function(name)
		if name == "CarryClass" or name == "Character" or name == "Captured" then
			if hands() ~= "Medium" then
				stopAim()
			end
		end
	end)
	RunService.RenderStepped:Connect(updateAim)
end

return HandsController
