--!strict
-- Hiding visuals only (beta-spec §4.1, ux §5): the barrel-ring vignette, a peek camera, the sniff warning in the
-- last 5 s before the ACHOO, and the spot wobbling. Inputs (`HideExit`, the OUT button) belong to ux's
-- ContextController; this controller sends nothing.
-- Reads character attributes `Hidden` and `HideEndsAt` (server time of the sneeze).

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lib = script.Parent.Parent:WaitForChild("Lib")

local HidingController = {}

local player = Players.LocalPlayer
local WARN_BEFORE = 5 -- seconds before the sneeze the shaking starts (WarnAt 15 / SneezeAt 20; Barrel Lungs 20 / 25)
local PEEK = Vector3.new(0, 2, 0)

local gui: ScreenGui? = nil
local ring: Frame? = nil
local label: TextLabel? = nil
local hiddenSince = 0
local wobbleSpot: Model? = nil
local wobbleBase: CFrame? = nil
local nextSniff = 0
local active = false

local audio: any = nil
local function play(key: string)
	if audio == nil then
		local module = Lib:FindFirstChild("Audio")
		audio = if module and module:IsA("ModuleScript") then (require :: any)(module) else false
	end
	if audio and type(audio.play) == "function" then
		pcall(audio.play, key)
	end
end

local function buildGui(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "HidingVignette"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = -1 -- below the HUD
	screen.Enabled = false
	local frame = Instance.new("Frame")
	frame.Name = "Ring"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.82, 0.74)
	frame.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 900
	stroke.Color = Color3.fromRGB(20, 14, 8)
	stroke.Transparency = 0.3
	stroke.Parent = frame
	frame.Parent = screen
	local text = Instance.new("TextLabel")
	text.Name = "State"
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, 56)
	text.Size = UDim2.fromOffset(260, 36)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 244, 214)
	text.TextStrokeTransparency = 0.4
	text.Text = "HIDDEN"
	text.Parent = screen
	screen.Parent = player:WaitForChild("PlayerGui")
	gui, ring, label = screen, frame, text
	return screen
end

local function nearestSpot(position: Vector3): Model?
	local best: Model? = nil
	local bestDistance = 8
	for _, inst in CollectionService:GetTagged("HideSpot") do
		if inst:IsA("Model") then
			local distance = (inst:GetPivot().Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = inst, distance
			end
		end
	end
	return best
end

local function setPeek(character: Model, on: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = if on then PEEK else Vector3.zero
	end
end

local function stopWobble()
	if wobbleSpot and wobbleBase and wobbleSpot.Parent then
		wobbleSpot:PivotTo(wobbleBase)
	end
	wobbleSpot, wobbleBase = nil, nil
end

local function setHidden(character: Model, hidden: boolean)
	if hidden == active then
		return
	end
	active = hidden
	local screen = gui or buildGui()
	screen.Enabled = hidden
	setPeek(character, hidden)
	if hidden then
		hiddenSince = os.clock()
		nextSniff = 0
		play("BarrelIn")
	else
		stopWobble()
		play("BarrelOut")
	end
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function update()
	local character = player.Character
	if not character then
		return
	end
	local hidden = character:GetAttribute("Hidden") == true
	setHidden(character, hidden)
	if not hidden or not ring or not label then
		return
	end
	local endsAt = character:GetAttribute("HideEndsAt")
	local left = if typeof(endsAt) == "number" then endsAt - serverNow() else math.huge
	local warning = left <= WARN_BEFORE
	local ringFrame = ring :: Frame
	local text = label :: TextLabel
	if warning then
		text.Text = if left > 0 then `SNIFF… {math.ceil(left)}` else "ACHOO!"
		text.TextColor3 = Color3.fromRGB(255, 120, 90)
		local now = os.clock()
		if now >= nextSniff then
			nextSniff = now + 2
			play("Sniff")
		end
		if not GuiService.ReducedMotionEnabled then
			local shake = math.sin(now * 40) * 4
			ringFrame.Position = UDim2.new(0.5, shake, 0.5, 0)
			local root = character:FindFirstChild("HumanoidRootPart")
			if wobbleSpot == nil and root and root:IsA("BasePart") then
				wobbleSpot = nearestSpot(root.Position)
				wobbleBase = if wobbleSpot then wobbleSpot:GetPivot() else nil
			end
			if wobbleSpot and wobbleBase then
				wobbleSpot:PivotTo(wobbleBase * CFrame.Angles(0, 0, math.rad(math.sin(now * 30) * 3)))
			end
		end
	else
		text.Text = if os.clock() - hiddenSince < 1.5 then "HIDDEN" else ""
		text.TextColor3 = Color3.fromRGB(255, 244, 214)
		ringFrame.Position = UDim2.fromScale(0.5, 0.5)
	end
end

function HidingController:Start()
	RunService.RenderStepped:Connect(update)
	player.CharacterAdded:Connect(function()
		active = false
		stopWobble()
		if gui then
			gui.Enabled = false
		end
	end)
end

return HidingController
