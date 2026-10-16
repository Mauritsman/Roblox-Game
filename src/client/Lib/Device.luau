--!strict
-- Which input the player uses right now ("Touch", "Gamepad" or "KeyboardAndMouse") and the viewport size.
-- Fires Changed when either one changes, so layouts and button labels can follow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Device = {}

export type Input = "Touch" | "Gamepad" | "KeyboardAndMouse"

Device.Changed = Signal.new() :: Signal.Signal<string>

local function compute(): Input
	local ok, value = pcall(function()
		return (UserInputService :: any).PreferredInput
	end)
	if ok and value then
		local name = value.Name
		if name == "Touch" or name == "Gamepad" or name == "KeyboardAndMouse" then
			return name
		end
		if name == "MicroGamepad" then
			return "Gamepad"
		end
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	end
	if string.find(last.Name, "Gamepad") then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "KeyboardAndMouse"
end

local current: Input = compute()

function Device.input(): Input
	return current
end

function Device.isTouch(): boolean
	return current == "Touch"
end

function Device.viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local started = false
function Device.init()
	if started then
		return
	end
	started = true
	local function refresh()
		local value: Input = compute()
		if value ~= current then
			current = value :: Input
			Device.Changed:Fire("input")
		end
	end
	pcall(function()
		(UserInputService :: any):GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		task.defer(refresh)
	end)
	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				Device.Changed:Fire("viewport")
			end)
		end
		Device.Changed:Fire("viewport")
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

-- Short name of a key for on-screen key caps ("E", "X", "LMB"...).
function Device.keyName(action: string): string
	local gamepad = current == "Gamepad"
	local map: { [string]: { string } } = {
		Context = { "E", "X" },
		Primary = { "LMB", "R2" },
		Aim = { "LMB", "L2" },
		Crouch = { "C", "B" },
		Ping = { "Q", "R1" },
		Drop = { "G", "X" },
		Roll = { "V", "R2" },
		Cancel = { "R", "B" },
		Back = { "", "B" },
		CamPrev = { "A", "LB" },
		CamNext = { "D", "RB" },
	}
	local entry = map[action]
	if not entry then
		return ""
	end
	return if gamepad then entry[2] else entry[1]
end

return Device
