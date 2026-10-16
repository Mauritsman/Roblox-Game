--!strict
-- The context button (beta-spec-ux §2.2, §7.2): custom-style ProximityPrompts become one action.
--   * Keyboard/gamepad: a world label with the key cap (E / X), the action and a hold ring.
--   * Touch: the CONTEXT button in the cluster shows the action; holding it holds the prompt.
-- The server owns every prompt (Triggered runs there); the client only renders and forwards holds.
-- When no prompt is shown, the context falls back to the action your state allows:
--   cell → CRAWL OUT (after the grate timer) · hidden → OUT · drone → BACK · carrying → DROP / LET GO.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local Audio = require(Lib.Audio)
local CharState = require(Lib.CharState)
local ClientState = require(Lib.ClientState)
local Device = require(Lib.Device)
local Hud = require(Lib.Hud)
local RoundState = require(Lib.RoundState)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)

local ContextController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

export type State = {
	label: string,
	sub: string?,
	subColor: Color3?,
	color: Color3,
	kind: string, -- "prompt" | "virtual"
	hold: number,
	glyph: string?,
	lockedFor: number?, -- seconds until usable (cell grate)
	lockedTotal: number?,
}

ContextController.Changed = Signal.new() :: Signal.Signal<>

type Shown = { prompt: ProximityPrompt, gui: BillboardGui, ring: Hud.Ring, label: TextLabel, cap: TextLabel }

local shown: { Shown } = {}
local highlight: Highlight
local holdStartedAt: number? = nil
local holdDuration = 0
local lastState: State? = nil

local ICONS: { [string]: string } = {
	grab = "✋",
	pocket = Theme.Loot.Small.glyph,
	lift = Theme.Loot.Heavy.glyph,
	hide = "◍",
	pry = "⚒",
	free = "⛓",
	drive = "▣",
	open = "▯",
	jumpin = "➜",
	board = "☰",
	gadgets = "⚙",
	mirror = "◐",
}

local function currentPrompt(): ProximityPrompt?
	for index = #shown, 1, -1 do
		local entry = shown[index]
		if entry.prompt.Parent and entry.prompt.Enabled then
			return entry.prompt
		end
	end
	return nil
end

local function targetOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		parent = parent.Parent
	end
	if not parent or not parent:IsA("BasePart") then
		return parent
	end
	local model = parent:FindFirstAncestorWhichIsA("Model")
	if model and model ~= workspace and model.Parent ~= workspace then
		local ok, size = pcall(function()
			return model:GetExtentsSize()
		end)
		if ok and size.Magnitude < 40 then
			return model
		end
	end
	return parent
end

local function isDrive(prompt: ProximityPrompt): boolean
	return prompt.Name == "DrivePrompt"
		or prompt.Name == "Drive"
		or string.find(string.upper(prompt.ActionText), "DRIVE") ~= nil
end

-- Free teammates outside the van ("LEAVES 1 BEHIND").
local function leftBehind(): number
	local count = 0
	for _, p in RoundState.crew() do
		if p ~= player then
			local character = p.Character
			if character then
				local caught = character:GetAttribute("Captured") ~= nil
					or character:GetAttribute("Caught") == true
				if not caught and character:GetAttribute("InVan") ~= true then
					count += 1
				end
			end
		end
	end
	return count
end

local function promptState(prompt: ProximityPrompt): State
	local iconName = prompt:GetAttribute("ContextIcon")
	local state: State = {
		label = string.upper(prompt.ActionText),
		color = C.Accent,
		kind = "prompt",
		hold = prompt.HoldDuration,
		glyph = if typeof(iconName) == "string" then ICONS[string.lower(iconName)] else nil,
	}
	if isDrive(prompt) then
		state.color = C.Good
		local behind = leftBehind()
		if behind > 0 then
			state.sub = `LEAVES {behind} BEHIND`
			state.subColor = C.Warn
		end
	end
	return state
end

-- The fallback action for your state (nil = none).
local function virtualState(): (State?, (() -> ())?)
	local mode = ClientState.mode
	if mode == "Cell" then
		-- SelfEscapeUsed = count used this round; the difficulty tier sets how many are allowed.
		local used = CharState.playerAttr("SelfEscapeUsed")
		local tiers = (Config :: any).DifficultyTiers
		local tier = tiers and tiers.Tiers and tiers.Tiers[RoundState.string("Difficulty") or "Normal"]
		local capture = (Config :: any).Capture
		local allowed = if tier and typeof(tier.SelfEscapes) == "number"
			then tier.SelfEscapes
			elseif capture and typeof(capture.SelfEscapes) == "number" then capture.SelfEscapes
			else 1
		if used == true or (typeof(used) == "number" and used >= allowed) then
			return nil, nil
		end
		local at = CharState.get("SelfEscapeAt")
		local left = if typeof(at) == "number" then at - RoundState.now() else 0
		if left > 0 then
			return {
				label = `GRATE {Hud.formatTime(left)}`,
				color = C.Dim,
				kind = "virtual",
				hold = 0,
				lockedFor = left,
				lockedTotal = 15,
			},
				nil
		end
		return { label = "CRAWL OUT", color = C.Good, kind = "virtual", hold = 0 }, function()
			Net.request("CrawlOut")
			Audio.play("GrateCrawl")
		end
	end
	if mode == "Carried" then
		return nil, nil
	end
	if mode == "Hidden" then
		return { label = "OUT", color = C.Info, kind = "virtual", hold = 0 }, function()
			Net.request("HideExit")
		end
	end
	if mode == "Drone" then
		return { label = "BACK", color = C.Info, kind = "virtual", hold = 0 }, function()
			Actions.fire("DroneRecall", "Begin")
			task.defer(function()
				Actions.fire("DroneRecall", "End")
			end)
		end
	end
	return nil, nil
end

local function carryState(): (State?, (() -> ())?)
	local carry, role = CharState.carry()
	if not carry then
		return nil, nil
	end
	if role == "Help" then
		return { label = "LET GO", color = C.Muted, kind = "virtual", hold = 0 }, function()
			Net.request("LetGo")
		end
	end
	return { label = "DROP", color = C.Muted, kind = "virtual", hold = 0 }, function()
		Net.request("Drop")
	end
end

-- What the context button shows right now, and what pressing it does (virtual only).
function ContextController.state(): (State?, (() -> ())?)
	if Screens.isOpen() then
		return nil, nil
	end
	local vState, vPress = virtualState()
	if vState then
		return vState, vPress
	end
	local prompt = currentPrompt()
	if prompt then
		return promptState(prompt), nil
	end
	return carryState()
end

-- Hold progress of the current prompt (0–1), or nil when nothing is held.
function ContextController.progress(): number?
	if not holdStartedAt then
		return nil
	end
	if holdDuration <= 0 then
		return 1
	end
	return math.clamp((os.clock() - holdStartedAt) / holdDuration, 0, 1)
end

local touchHolding: ProximityPrompt? = nil

-- Touch CONTEXT button (and tapping a world label): began = finger down.
function ContextController.press(began: boolean)
	local state, onPress = ContextController.state()
	if began then
		if not state then
			return
		end
		if state.kind == "prompt" then
			local prompt = currentPrompt()
			if prompt then
				touchHolding = prompt
				prompt:InputHoldBegin()
			end
		elseif onPress and not state.lockedFor then
			Audio.play("UiTap")
			onPress()
		end
	else
		local prompt = touchHolding
		touchHolding = nil
		if prompt then
			prompt:InputHoldEnd()
		end
	end
end

-- ── World labels for keyboard/gamepad ────────────────────────────────────────────────────────────

local function keyFor(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return (string.gsub(name, "Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return ""
	end
	return prompt.KeyboardKeyCode.Name
end

local function buildLabel(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): Shown
	local gui = Instance.new("BillboardGui")
	gui.Name = "ContextPrompt"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(220, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
	gui.MaxDistance = 60
	gui.Active = true
	gui.Adornee = prompt.Parent :: any
	local holder = Hud.frame({ Size = UDim2.fromScale(1, 1) }, gui)
	Hud.list(
		holder,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)

	local capHolder = Hud.frame({ Size = UDim2.fromOffset(48, 48), LayoutOrder = 1 }, holder)
	local ring = Hud.progressRing(capHolder, 48, C.Good, 1)
	local cap = Hud.make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.Text,
		BorderSizePixel = 0,
		FontFace = Theme.Fonts.UiHeavy,
		Text = keyFor(prompt, inputType),
		TextSize = 20,
		TextColor3 = C.Panel,
		AutoButtonColor = false,
		ZIndex = 2,
	}, capHolder)
	Hud.corner(cap, 999)
	cap.Visible = inputType ~= Enum.ProximityPromptInputType.Touch
	cap.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			touchHolding = prompt
			prompt:InputHoldBegin()
		end
	end)
	cap.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			if touchHolding == prompt then
				touchHolding = nil
				prompt:InputHoldEnd()
			end
		end
	end)

	local textHolder = Hud.panel({
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		BackgroundTransparency = 0.2,
	}, holder)
	Hud.padding(textHolder, 10, 2)
	Hud.list(
		textHolder,
		Enum.FillDirection.Vertical,
		0,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	local label = Hud.make("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.UiHeavy,
		Text = string.upper(prompt.ActionText),
		TextSize = 20,
		TextColor3 = C.Text,
		LayoutOrder = 1,
	}, textHolder)
	if prompt.ObjectText ~= "" then
		Hud.make("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 14),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Ui,
			Text = prompt.ObjectText,
			TextSize = 13,
			TextColor3 = C.Muted,
			LayoutOrder = 2,
		}, textHolder)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	return { prompt = prompt, gui = gui, ring = ring, label = label, cap = cap }
end

local function removeShown(prompt: ProximityPrompt)
	for index = #shown, 1, -1 do
		if shown[index].prompt == prompt then
			shown[index].gui:Destroy()
			table.remove(shown, index)
		end
	end
	if touchHolding == prompt then
		touchHolding = nil
	end
end

local function refreshHighlight()
	local prompt = currentPrompt()
	local target = if prompt then targetOf(prompt) else nil
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
end

local function stateKey(state: State?): string
	if not state then
		return ""
	end
	return `{state.label}|{state.sub or ""}|{state.kind}|{state.hold}`
end

local function notify()
	local state = ContextController.state()
	if stateKey(state) ~= stateKey(lastState) then
		lastState = state
		ContextController.Changed:Fire()
	end
end

function ContextController:Init()
	highlight = Instance.new("Highlight")
	highlight.Name = "ContextTarget"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = player:WaitForChild("PlayerGui")
end

function ContextController:Start()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		removeShown(prompt)
		table.insert(shown, buildLabel(prompt, inputType))
		refreshHighlight()
		notify()
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		removeShown(prompt)
		if holdStartedAt and currentPrompt() == nil then
			holdStartedAt = nil
		end
		refreshHighlight()
		notify()
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
		if who == player then
			holdStartedAt = os.clock()
			holdDuration = prompt.HoldDuration
			if prompt.HoldDuration >= 1 then
				Audio.play("UiTap", { pitch = 0.9 })
			end
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(_prompt, who)
		if who == player then
			holdStartedAt = nil
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player then
			holdStartedAt = nil
			Audio.play("UiTap", { pitch = 1.3 })
			for _, entry in shown do
				if entry.prompt == (prompt :: any) then
					entry.ring.set(1)
					task.delay(0.15, function()
						entry.ring.set(0)
					end)
				end
			end
		end
	end)

	-- Keyboard E / gamepad X when no prompt is shown: run the fallback action.
	Actions.on("Context", function(phase)
		if phase ~= "Begin" then
			return
		end
		local state, onPress = ContextController.state()
		if state and state.kind == "virtual" and onPress and not state.lockedFor then
			onPress()
		end
	end)
	Actions.on("Drop", function(phase)
		if phase ~= "Begin" then
			return
		end
		local carry, role = CharState.carry()
		if carry then
			Net.request(if role == "Help" then "LetGo" else "Drop")
		end
	end)

	-- Menus hide world prompts.
	Screens.Changed:Connect(function(name)
		ProximityPromptService.Enabled = name == nil
		notify()
	end)
	ClientState.Changed:Connect(function(key)
		if key == "mode" then
			notify()
		end
	end)
	CharState.Changed:Connect(notify)
	Device.Changed:Connect(notify)

	RunService.RenderStepped:Connect(function()
		local progress = ContextController.progress()
		local current = currentPrompt()
		for _, entry in shown do
			entry.ring.set(if entry.prompt == current and progress then progress else 0)
		end
	end)
	-- Timers (grate countdown, LEAVES n BEHIND) change without events: re-check a few times a second.
	while true do
		task.wait(0.25)
		notify()
	end
end

return ContextController
