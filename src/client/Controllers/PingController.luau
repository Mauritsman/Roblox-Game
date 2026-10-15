--!strict
-- Pings tonen en sturen (§3.5).
-- SPOT: icoon op wat je aanwijst (Q / R1 / PING-knop). NOW en WAIT: Z / X of de kleine knoppen.
-- Elk soort ping heeft een eigen vorm én de kleur van de speler (kleurenblind-vriendelijk).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local ClientState = require(Lib.ClientState)
local Hud = require(Lib.Hud)

local GadgetController = require(script.Parent.GadgetController)

local PingController = {}

local player = Players.LocalPlayer

local KIND_STYLE: { [string]: { glyph: string, label: string } } = {
	guard = { glyph = "◆", label = "GUARD" },
	camera = { glyph = "■", label = "CAMERA" },
	lock = { glyph = "▲", label = "OPEN HERE" },
	loot = { glyph = "★", label = "LOOT" },
	drone = { glyph = "●", label = "DRONE" },
	go = { glyph = "▼", label = "GO HERE" },
}

local QUICK_STYLE: { [string]: { glyph: string, color: Color3 } } = {
	NOW = { glyph = "▶", color = Color3.fromRGB(90, 210, 120) },
	WAIT = { glyph = "✋", color = Color3.fromRGB(255, 200, 60) },
}

local activeByTarget: { [Instance]: BillboardGui } = {}

local function playPing(pitch: number)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.PlaybackSpeed = pitch
	sound.Volume = 0.5
	SoundService:PlayLocalSound(sound)
	task.delay(3, function()
		sound:Destroy()
	end)
end

local function adorneeFor(target: Instance?): BasePart?
	if not target then
		return nil
	end
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		local head = target:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head
		end
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function showPing(data: { [string]: any })
	local style = KIND_STYLE[data.kind] or KIND_STYLE.go
	local adornee = adorneeFor(data.target)
	local anchor: Part? = nil
	if not adornee and typeof(data.position) == "Vector3" then
		local newAnchor = Instance.new("Part")
		newAnchor.Anchored = true
		newAnchor.CanCollide = false
		newAnchor.CanQuery = false
		newAnchor.Transparency = 1
		newAnchor.Size = Vector3.one * 0.2
		newAnchor.Position = data.position
		newAnchor.Parent = workspace.CurrentCamera
		anchor = newAnchor
		adornee = newAnchor
	end
	if not adornee then
		return
	end

	-- Dezelfde target opnieuw gepingd: oude markering vervangen.
	if data.target and activeByTarget[data.target] then
		activeByTarget[data.target]:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Ping"
	gui.Size = UDim2.fromOffset(120, 54)
	gui.StudsOffset = Vector3.new(0, if data.kind == "guard" then 3.6 else 2.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local glyph = Instance.new("TextLabel")
	glyph.Size = UDim2.new(1, 0, 0, 30)
	glyph.BackgroundTransparency = 1
	glyph.Font = Enum.Font.GothamBlack
	glyph.TextScaled = true
	glyph.Text = style.glyph
	glyph.TextColor3 = data.color
	glyph.TextStrokeTransparency = 0
	glyph.Parent = gui
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.new(1, 0, 0, 20)
	caption.Position = UDim2.fromOffset(0, 32)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBold
	caption.TextScaled = true
	caption.Text = if data.auto then style.label else `{style.label} · {data.from}`
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.TextStrokeTransparency = 0.2
	caption.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	if data.target then
		activeByTarget[data.target] = gui
	end
	if not data.auto then
		playPing(if data.kind == "guard" then 1.3 else 1)
	end
	task.delay(data.duration or 8, function()
		if gui.Parent then
			gui:Destroy()
		end
		if data.target and activeByTarget[data.target] == gui then
			activeByTarget[data.target] = nil
		end
		if anchor then
			anchor:Destroy()
		end
	end)
end

local function showQuick(fromName: string, preset: string, color: Color3, userId: number)
	local style = QUICK_STYLE[preset] or QUICK_STYLE.NOW
	Hud.toast(`{style.glyph} {fromName}: {preset}`, style.color)
	playPing(if preset == "NOW" then 1.6 else 0.8)
	local sender = Players:GetPlayerByUserId(userId)
	local head = sender and sender.Character and sender.Character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(110, 40)
		gui.StudsOffset = Vector3.new(0, 2.8, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = color
		label.BackgroundTransparency = 0.1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = `{style.glyph} {preset}`
		label.Parent = gui
		local cornerUi = Instance.new("UICorner")
		cornerUi.CornerRadius = UDim.new(0, 999)
		cornerUi.Parent = label
		gui.Parent = player:WaitForChild("PlayerGui")
		task.delay(2.5, function()
			gui:Destroy()
		end)
	end
end

function PingController:Start()
	Net.on("Ping", showPing)
	Net.on("Quick", showQuick)

	Actions.on("Spot", function(phase)
		if phase ~= "Begin" or ClientState.drone then
			return
		end
		local hit = GadgetController.pointerHit(300)
		if hit then
			Net.request("Spot", hit.Instance, hit.Position)
		end
	end)
	Actions.on("Now", function(phase)
		if phase == "Begin" then
			Net.request("Quick", "NOW")
		end
	end)
	Actions.on("Wait", function(phase)
		if phase == "Begin" then
			Net.request("Quick", "WAIT")
		end
	end)
end

return PingController
