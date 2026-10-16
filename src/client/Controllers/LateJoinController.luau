--!strict
-- "Crew on a job" (beta-spec-ux §1.17): a player in the Garage while the crew is out sees how long the job
-- still runs, can JUMP IN during the first 2 minutes (JumpIn(), or the Garage van prompt), and can WATCH the
-- crew full screen (Spectate(userId); ◀ ▶ / A D / LB RB switch, B or ✕ leaves). The Garage TV (tag GarageTV)
-- gets a local "Watch" prompt.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local Audio = require(Lib.Audio)
local ClientState = require(Lib.ClientState)
local EdgeArrows = require(Lib.EdgeArrows)
local Hud = require(Lib.Hud)
local Juice = require(Lib.Juice)
local RoundState = require(Lib.RoundState)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)
local World = require(Lib.World)

local LateJoinController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

local bar: Frame
local barText: TextLabel
local actions: Frame
local jumpButton: TextButton
local watchButton: TextButton
local tvPrompts: { [Instance]: ProximityPrompt } = {}
local watchIndex = 1
local spectateShow: ((index: number) -> ())? = nil

local function maxCrew(): number
	local round = (Config :: any).Round
	return if typeof(round) == "table" and typeof(round.MaxCrew) == "number" then round.MaxCrew else 4
end

local function canJumpIn(): (boolean, number)
	local left = RoundState.left("JumpInUntil")
	if not left or left <= 0 then
		return false, 0
	end
	return #RoundState.crew() < maxCrew(), left
end

local function refresh()
	local lateJoin = RoundState.statusMode() == "LateJoin"
	bar.Visible = lateJoin
	actions.Visible = lateJoin
	for _, prompt in tvPrompts do
		prompt.Enabled = lateJoin
	end
	if not lateJoin then
		EdgeArrows.clear("JumpIn")
		return
	end
	local seconds = RoundState.timer()
	local timeText = if seconds then ` · {Hud.formatTime(seconds)} LEFT` else ""
	barText.Text = `CREW ON A JOB{timeText}`
	local can, left = canJumpIn()
	jumpButton.Visible = can
	if can then
		jumpButton.Text = `JUMP IN · {Hud.formatTime(left)}`
		if not EdgeArrows.has("JumpIn") then
			EdgeArrows.set("JumpIn", {
				target = function()
					return World.position(World.tagged("GarageVan"))
				end,
				glyph = "➜",
				color = C.Gold,
				label = "JUMP IN",
			})
		end
	else
		EdgeArrows.clear("JumpIn")
	end
	watchButton.Text = if can then "WATCH" else "WATCH CREW · next job soon"
	watchButton.Size = UDim2.fromOffset(if can then 110 else 250, 48)
end

-- ── Spectate ─────────────────────────────────────────────────────────────────────────────────────

local function humanoidOf(target: Player): Humanoid?
	local character = target.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function buildSpectate(body: Frame): (() -> ())?
	local alive = true
	local crew = RoundState.crew()
	local label = Hud.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 34),
		Text = "",
		Display = true,
		MaxTextSize = 26,
		Stroke = 2,
	}, body)
	local close = Hud.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(48, 48),
		Text = "✕",
		Kind = "ghost",
		Sound = "UiBack",
		MaxTextSize = 24,
	}, body)
	close.Activated:Connect(function()
		Screens.close("Spectate")
	end)
	if #crew == 0 then
		label.Text = "Nobody to watch right now"
		return function()
			alive = false
		end
	end
	local function show(index: number)
		crew = RoundState.crew()
		if #crew == 0 then
			label.Text = "The crew is back"
			return
		end
		watchIndex = ((index - 1) % #crew) + 1
		local target = crew[watchIndex]
		ClientState.set("spectating", target.UserId)
		Net.request("Spectate", target.UserId)
		local crewStyle = Theme.crew(target)
		label.Text = `{crewStyle.glyph} WATCHING {string.upper(Hud.shortName(target.DisplayName, 12))}`
		label.TextColor3 = crewStyle.color
		Audio.play("UiTap", { pitch = 0.8 })
	end
	for _, spec in
		{ { text = "◀", x = 0, anchor = 0, delta = -1 }, { text = "▶", x = 1, anchor = 1, delta = 1 } }
	do
		local button = Hud.button({
			AnchorPoint = Vector2.new(spec.anchor, 0.5),
			Position = UDim2.new(spec.x, if spec.anchor == 0 then 16 else -16, 0.5, 0),
			Size = UDim2.fromOffset(56, 56),
			Text = spec.text,
			Kind = "ghost",
			MaxTextSize = 28,
			Radius = 999,
		}, body)
		button.Activated:Connect(function()
			show(watchIndex + spec.delta)
		end)
	end
	Actions.bindTemporary("CamPrev", { Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.ButtonL1 })
	Actions.bindTemporary("CamNext", { Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.ButtonR1 })
	spectateShow = show
	show(watchIndex)
	-- Follow the target (it may stream in a moment later).
	local connection = RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		local targetId = ClientState.spectating
		local target = if targetId then Players:GetPlayerByUserId(targetId) else nil
		local humanoid = target and humanoidOf(target)
		if camera and humanoid and camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
		if not RoundState.heistRunning() and alive then
			alive = false
			task.defer(function()
				Screens.close("Spectate")
			end)
		end
	end)
	return function()
		alive = false
		spectateShow = nil
		connection:Disconnect()
	end
end

local function stopSpectating()
	Actions.unbindTemporary("CamPrev")
	Actions.unbindTemporary("CamNext")
	ClientState.set("spectating", nil)
	Net.request("Spectate", 0)
	local camera = workspace.CurrentCamera
	local humanoid = humanoidOf(player)
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
end

local function addTvPrompt(tv: Instance)
	if tvPrompts[tv] then
		return
	end
	local part = if tv:IsA("BasePart")
		then tv
		elseif tv:IsA("Model") then tv.PrimaryPart or tv:FindFirstChildWhichIsA("BasePart")
		else nil
	if not part then
		return
	end
	-- A local prompt (only this client sees it); GarageController opens the screen named in "Screen".
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WatchPrompt"
	prompt.ActionText = "Watch"
	prompt.ObjectText = "Crew cam"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = RoundState.statusMode() == "LateJoin"
	prompt:SetAttribute("Screen", "Spectate")
	prompt.Parent = part
	tvPrompts[tv] = prompt
end

function LateJoinController:Init()
	bar = Hud.panel({
		Name = "LateJoinBar",
		Size = UDim2.fromOffset(340, 44),
		LayoutOrder = 1,
		Visible = false,
	}, Hud.slot("Status"))
	barText = Hud.text({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 1, -12),
		Text = "CREW ON A JOB",
		Display = true,
		MaxTextSize = 22,
		Stroke = 1.5,
	}, bar)
	actions = Hud.frame({
		Name = "LateJoinActions",
		Size = UDim2.fromOffset(340, 50),
		LayoutOrder = 2,
		Visible = false,
	}, Hud.slot("Status"))
	Hud.list(
		actions,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	jumpButton = Hud.button({
		Name = "JumpIn",
		Size = UDim2.fromOffset(170, 48),
		Text = "JUMP IN",
		Kind = "gold",
		MaxTextSize = 18,
		LayoutOrder = 1,
		Visible = false,
	}, actions)
	jumpButton.Activated:Connect(function()
		Net.request("JumpIn")
		Juice.pop(jumpButton, 1.1)
	end)
	watchButton = Hud.button({
		Name = "Watch",
		Size = UDim2.fromOffset(110, 48),
		Text = "WATCH",
		Kind = "ghost",
		MaxTextSize = 16,
		LayoutOrder = 2,
	}, actions)
	watchButton.Activated:Connect(function()
		Screens.open("Spectate")
	end)

	Screens.register("Spectate", {
		title = "WATCH",
		fullscreen = true,
		build = buildSpectate,
		onClose = stopSpectating,
	})
end

function LateJoinController:Start()
	Actions.on("CamPrev", function(phase)
		local show = spectateShow
		if phase == "Begin" and show then
			show(watchIndex - 1)
		end
	end)
	Actions.on("CamNext", function(phase)
		local show = spectateShow
		if phase == "Begin" and show then
			show(watchIndex + 1)
		end
	end)
	for _, tv in CollectionService:GetTagged("GarageTV") do
		addTvPrompt(tv)
	end
	CollectionService:GetInstanceAddedSignal("GarageTV"):Connect(addTvPrompt)
	RoundState.Changed:Connect(function(name)
		if name == "RoundPhase" or name == "JumpInUntil" then
			refresh()
		end
	end)
	while true do
		refresh()
		task.wait(0.5)
	end
end

return LateJoinController
