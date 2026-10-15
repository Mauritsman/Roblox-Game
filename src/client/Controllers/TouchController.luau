--!strict
-- Knoppen voor telefoon en tablet (§3.6). Alleen zichtbaar als aanraken de voorkeursinvoer is.
-- De standaard Roblox-joystick (linksonder) en springknop (rechtsonder) blijven vrij;
-- onze knoppen staan in een boog erboven en ernaast. Hoofdknoppen ≥ 64 px, kleine ≥ 52 px.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Lib = script.Parent.Parent.Lib
local Actions = require(Lib.Actions)
local ClientState = require(Lib.ClientState)
local Hud = require(Lib.Hud)

local TouchController = {}

local player = Players.LocalPlayer

type ButtonSpec = {
	name: string,
	text: string,
	size: number,
	x: number, -- afstand van de rechterrand tot de rechterkant van de knop
	y: number, -- afstand van de onderrand tot de onderkant van de knop
	color: Color3?,
}

local container: Frame
local buttons: { [string]: TextButton } = {}

local function addButton(spec: ButtonSpec, onPress: (() -> ())?, onHold: ((boolean) -> ())?): TextButton
	local button = Hud.button({
		Name = spec.name,
		Text = spec.text,
		Size = UDim2.fromOffset(spec.size, spec.size),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -spec.x, 1, -spec.y),
		BackgroundColor3 = spec.color or Hud.Colors.Panel,
	}, container)
	if onPress then
		button.Activated:Connect(onPress)
	end
	if onHold then
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				onHold(true)
			end
		end)
		button.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				onHold(false)
			end
		end)
	end
	buttons[spec.name] = button
	return button
end

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

local function refresh()
	if not container then
		return
	end
	local list = gadgets()
	local flying = ClientState.drone ~= nil
	local selected = list[math.clamp(ClientState.selectedSlot, 1, math.max(1, #list))]
	local gadget = buttons.Gadget
	gadget.Text = if selected then (Config.Gadgets[selected].Label or selected):upper() else "NO GADGET"
	if selected then
		local step = Config.Gadgets[selected].Step
		gadget.BackgroundColor3 = if step == "EYES"
			then Hud.Colors.Eyes
			elseif step == "CLEAR" then Color3.fromRGB(190, 150, 30)
			else Hud.Colors.Open
	end
	gadget.Visible = not flying
	buttons.Throw.Visible = ClientState.aiming and not flying
	buttons.Crouch.Visible = not flying
	buttons.Call.Visible = not flying
	buttons.Up.Visible = flying
	buttons.Down.Visible = flying
	buttons.Back.Visible = flying
	buttons.Ping.Text = if flying then "SPOT" else "PING"
	for index = 1, 3 do
		local slotButton = buttons["Slot" .. index]
		local name = list[index]
		slotButton.Visible = name ~= nil and #list > 1 and not flying
		slotButton.Text = if name then string.sub(name, 1, 1) .. string.lower(string.sub(name, 2, 3)) else ""
		local stroke = slotButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = if index == ClientState.selectedSlot then 0 else 0.6
		end
	end
end

local function build()
	container = Instance.new("Frame")
	container.Name = "TouchButtons"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = Hud.gui()

	local function fire(action: string): () -> ()
		-- (tap = Begin gevolgd door End)
		return function()
			Actions.fire(action, "Begin")
			task.defer(function()
				Actions.fire(action, "End")
			end)
		end
	end

	addButton({ name = "Gadget", text = "GADGET", size = 84, x = 150, y = 110 }, fire("TouchGadget"))
	addButton(
		{ name = "Throw", text = "THROW", size = 72, x = 150, y = 206, color = Hud.Colors.Accent },
		fire("Fire")
	)
	addButton({ name = "Crouch", text = "CROUCH", size = 64, x = 160, y = 24 }, fire("Crouch"))
	addButton({ name = "Ping", text = "PING", size = 60, x = 246, y = 24 }, fire("Spot"))
	addButton(
		{ name = "Call", text = "CALL", size = 60, x = 246, y = 100, color = Hud.Colors.Accent },
		fire("ChainCall")
	)
	addButton(
		{ name = "Now", text = "NOW", size = 54, x = 326, y = 24, color = Color3.fromRGB(40, 120, 70) },
		fire("Now")
	)
	addButton(
		{ name = "Wait", text = "WAIT", size = 54, x = 326, y = 90, color = Color3.fromRGB(140, 110, 20) },
		fire("Wait")
	)
	for index = 1, 3 do
		addButton(
			{ name = "Slot" .. index, text = "", size = 52, x = 150 + (index - 1) * 60, y = 300 },
			function()
				Actions.fire("Slot" .. index, "Begin")
			end
		)
	end
	-- Dronemodus.
	addButton({ name = "Up", text = "▲", size = 60, x = 246, y = 100 }, nil, function(down)
		Actions.setHeld("DroneUp", down)
	end)
	addButton({ name = "Down", text = "▼", size = 64, x = 160, y = 24 }, nil, function(down)
		Actions.setHeld("DroneDown", down)
	end)
	addButton(
		{ name = "Back", text = "BACK", size = 72, x = 150, y = 110, color = Hud.Colors.Eyes },
		fire("DroneRecall")
	)

	refresh()
end

function TouchController:Start()
	local function apply()
		local touch = Actions.preferredInput() == "Touch"
		if touch and not container then
			build()
		end
		if container then
			container.Visible = touch
		end
		Hud.setCrosshair(touch or Actions.preferredInput() == "Gamepad" or ClientState.drone ~= nil)
	end
	apply()
	pcall(function()
		(UserInputService :: any):GetPropertyChangedSignal("PreferredInput"):Connect(apply)
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		task.defer(apply)
	end)

	ClientState.Changed:Connect(function(key)
		if key == "aiming" or key == "drone" or key == "selectedSlot" then
			refresh()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if name == Tags.Gadgets then
			refresh()
		end
	end)
end

return TouchController
