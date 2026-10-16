--!strict
-- Captured and cell view (beta-spec-ux §1.10):
--   * Carried: the camera pulls back to show the guard carrying you; the cluster shows only PING.
--   * Cell: your camera becomes the security cameras — a CCTV frame, "CAM 2/5 · SHOP", ◀ ▶ (56 px).
--     Tap a guard in the feed (or Q / R1 / R2 at the centre) to SPOT him for the crew. A/D or ←/→,
--     LB/RB switch cameras. CRAWL OUT is the context button once the grate timer is done.
-- The server streams around the camera when asked with `ViewCam(index)`.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local Audio = require(Lib.Audio)
local CharState = require(Lib.CharState)
local ClientState = require(Lib.ClientState)
local Device = require(Lib.Device)
local Hud = require(Lib.Hud)
local RoundState = require(Lib.RoundState)
local Theme = require(Lib.Theme)
local UiScale = require(Lib.UiScale)

local PingController = require(script.Parent.PingController)

local CellController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

local overlay: Frame? = nil
local camLabel: TextLabel? = nil
local comingLabel: TextLabel? = nil
local renderConnection: RBXScriptConnection? = nil
local cams: { Model } = {}
local camIndex = 1
local lastViewCamAt = 0
local pendingViewCam: number? = nil
local savedZoom: number? = nil
local inCell = false

local function collectCams(): { Model }
	local list = {}
	for _, inst in CollectionService:GetTagged("SecurityCamera") do
		if inst:IsA("Model") and inst:IsDescendantOf(workspace) and inst:FindFirstChild("Body") then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end

local function zoneOf(cam: Model): string
	local zone = cam:GetAttribute("Zone")
	if typeof(zone) == "string" and zone ~= "" then
		return string.upper(zone)
	end
	local parent = cam.Parent
	if parent and parent.Name ~= "Level" and parent ~= workspace then
		return string.upper(parent.Name)
	end
	return string.upper(cam.Name)
end

-- Tell the server which camera we watch (max 1 per second; the last switch always gets sent).
local function requestViewCam(index: number)
	pendingViewCam = index
	local wait = math.max(0, 1 - (os.clock() - lastViewCamAt))
	task.delay(wait, function()
		if pendingViewCam == index then
			pendingViewCam = nil
			lastViewCamAt = os.clock()
			Net.request("ViewCam", index)
		end
	end)
end

local function showCam(index: number)
	cams = collectCams()
	if #cams == 0 then
		if camLabel then
			camLabel.Text = "NO SIGNAL"
		end
		return
	end
	camIndex = ((index - 1) % #cams) + 1
	ClientState.set("camIndex", camIndex)
	if camLabel then
		camLabel.Text = `CAM {camIndex}/{#cams} · {zoneOf(cams[camIndex])}`
	end
	Audio.play("UiTap", { pitch = 0.7 })
	requestViewCam(camIndex)
end

local function step()
	local camera = workspace.CurrentCamera
	local cam = cams[camIndex]
	local body = cam and cam:FindFirstChild("Body")
	if camera and body and body:IsA("BasePart") then
		camera.CameraType = Enum.CameraType.Scriptable
		local look = body.CFrame.LookVector
		local origin = body.Position + look * 1.2
		camera.CFrame = CFrame.lookAt(origin, origin + look + Vector3.new(0, -0.25, 0))
	end
	-- "SAM IS COMING" when a free teammate is near.
	local label = comingLabel
	local root = CharState.root()
	if label and root then
		local coming: Player? = nil
		for _, other in Players:GetPlayers() do
			if other ~= player and RoundState.activity(other) == "Crew" then
				local character = other.Character
				local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
				if
					character
					and otherRoot
					and otherRoot:IsA("BasePart")
					and character:GetAttribute("Captured") == nil
					and (otherRoot.Position - root.Position).Magnitude < 30
				then
					coming = other
					break
				end
			end
		end
		label.Visible = coming ~= nil
		if coming then
			label.Text = `{string.upper(Hud.shortName(coming.DisplayName, 10))} IS COMING`
		end
	end
end

local function arrowButton(parent: Instance, text: string, xScale: number, anchorX: number, onPress: () -> ())
	local button = Hud.button({
		AnchorPoint = Vector2.new(anchorX, 0.5),
		Position = UDim2.new(xScale, if anchorX == 0 then 16 else -16, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		Text = text,
		Kind = "ghost",
		MaxTextSize = 30,
		Radius = 999,
	}, parent)
	button.Activated:Connect(onPress)
	return button
end

local function enterCell()
	if inCell then
		return
	end
	inCell = true
	local layer = UiScale.root("Fullscreen")
	local root = Hud.frame({ Name = "CellFeed", Size = UDim2.fromScale(1, 1) }, layer)
	overlay = root
	-- Tapping the feed spots what is under the finger.
	local feed = Hud.make("TextButton", {
		Name = "Feed",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
	}, root)
	feed.Activated:Connect(function(input: InputObject?)
		if input then
			PingController.spotAtScreen(Vector2.new(input.Position.X, input.Position.Y), true)
		end
	end)
	local frame = Hud.frame({
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
	}, root)
	Hud.make("UIStroke", { Color = C.Good, Thickness = 3, Transparency = 0.35 }, frame)
	Hud.text({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(120, 24),
		Text = "● CCTV",
		TextColor3 = C.Danger,
		TextXAlignment = Enum.TextXAlignment.Left,
		Heavy = true,
		MaxTextSize = 20,
		Stroke = 1.5,
	}, frame)
	camLabel = Hud.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(300, 26),
		Text = "CAM",
		Display = true,
		MaxTextSize = 22,
		Stroke = 2,
	}, frame)
	comingLabel = Hud.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 102),
		Size = UDim2.fromOffset(300, 24),
		Text = "",
		TextColor3 = C.Good,
		Heavy = true,
		MaxTextSize = 20,
		Stroke = 1.5,
		Visible = false,
	}, frame)
	Hud.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(360, 22),
		Text = if Device.input() == "Touch" then "Tap a guard to mark him" else "Aim at a guard and SPOT",
		TextColor3 = C.Muted,
		MaxTextSize = 17,
		Stroke = 1.5,
	}, frame)
	arrowButton(frame, "◀", 0, 0, function()
		showCam(camIndex - 1)
	end)
	arrowButton(frame, "▶", 1, 1, function()
		showCam(camIndex + 1)
	end)
	Actions.bindTemporary("CamPrev", { Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.ButtonL1 })
	Actions.bindTemporary("CamNext", { Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.ButtonR1 })
	showCam(camIndex)
	renderConnection = RunService.RenderStepped:Connect(step)
end

local function leaveCell()
	if not inCell then
		return
	end
	inCell = false
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	Actions.unbindTemporary("CamPrev")
	Actions.unbindTemporary("CamNext")
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	camLabel = nil
	comingLabel = nil
	ClientState.set("camIndex", nil)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function refresh()
	local captured = CharState.captured()
	if captured == "Carried" then
		if not savedZoom then
			local current = player.CameraMinZoomDistance
			savedZoom = current
			player.CameraMinZoomDistance = math.max(current, 14)
		end
	elseif savedZoom then
		player.CameraMinZoomDistance = savedZoom
		savedZoom = nil
	end
	if captured == "Cell" then
		enterCell()
	else
		leaveCell()
	end
end

function CellController:Start()
	Actions.on("CamPrev", function(phase)
		if phase == "Begin" and inCell then
			showCam(camIndex - 1)
		end
	end)
	Actions.on("CamNext", function(phase)
		if phase == "Begin" and inCell then
			showCam(camIndex + 1)
		end
	end)
	-- R2 / LMB in the cell: spot at the centre of the feed.
	Actions.intercept("Primary", function(phase)
		if inCell then
			if phase == "Begin" then
				local camera = workspace.CurrentCamera
				if camera then
					PingController.spotAtScreen(camera.ViewportSize / 2)
				end
			end
			return true
		end
		return false
	end)
	CharState.Changed:Connect(function(name)
		if name == "Captured" or name == "Caught" or name == "Character" then
			refresh()
		end
	end)
	refresh()
end

return CellController
