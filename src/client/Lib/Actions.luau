--!strict
-- Eén invoerlaag voor toetsenbord, controller en aanraakscherm.
-- Code luistert naar acties ("Fire", "Crouch"...) in plaats van naar knoppen; zo werkt alles op elk toestel.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Actions = {}

export type Phase = "Begin" | "End"
type Listener = (phase: Phase) -> ()

local listeners: { [string]: { Listener } } = {}

-- Toetsen per actie (§3.6). Muisknop 1 wordt apart afgehandeld (niet boven de UI).
local BINDINGS: { [string]: { Enum.KeyCode } } = {
	Slot1 = { Enum.KeyCode.One },
	Slot2 = { Enum.KeyCode.Two },
	Slot3 = { Enum.KeyCode.Three },
	NextSlot = { Enum.KeyCode.ButtonL1 },
	Aim = { Enum.KeyCode.ButtonL2 },
	Fire = { Enum.KeyCode.ButtonR2 },
	Cancel = { Enum.KeyCode.R },
	Crouch = { Enum.KeyCode.C, Enum.KeyCode.ButtonB },
	Spot = { Enum.KeyCode.Q, Enum.KeyCode.ButtonR1 },
	ChainCall = { Enum.KeyCode.G, Enum.KeyCode.ButtonY },
	Now = { Enum.KeyCode.Z, Enum.KeyCode.DPadUp },
	Wait = { Enum.KeyCode.X, Enum.KeyCode.DPadDown },
	DroneRecall = { Enum.KeyCode.F, Enum.KeyCode.DPadLeft },
	DroneUp = { Enum.KeyCode.Space },
	DroneDown = { Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift },
	Restart = { Enum.KeyCode.P },
}

function Actions.on(name: string, listener: Listener)
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, listener)
end

function Actions.fire(name: string, phase: Phase)
	local list = listeners[name]
	if list then
		for _, listener in list do
			task.spawn(listener, phase)
		end
	end
end

-- Houdt bij welke acties nu ingedrukt zijn (voor de drone: omhoog/omlaag vasthouden).
local held: { [string]: boolean } = {}
function Actions.isHeld(name: string): boolean
	return held[name] == true
end

function Actions.setHeld(name: string, isHeld: boolean)
	held[name] = isHeld
end

function Actions.preferredInput(): string
	local ok, value = pcall(function()
		return (UserInputService :: any).PreferredInput
	end)
	if ok and value then
		return value.Name -- "Touch", "Gamepad" of "KeyboardAndMouse"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "KeyboardAndMouse"
end

function Actions.init()
	for name, keys in BINDINGS do
		ContextActionService:BindAction("CC_" .. name, function(_, state)
			if state == Enum.UserInputState.Begin then
				held[name] = true
				Actions.fire(name, "Begin")
			elseif state == Enum.UserInputState.End then
				held[name] = false
				Actions.fire(name, "End")
			end
			-- Laat spatie/shift door naar Roblox (springen) als de drone niet vliegt.
			return Enum.ContextActionResult.Pass
		end, false, table.unpack(keys))
	end

	-- Linkermuisknop: richten bij indrukken, gooien bij loslaten (alleen buiten de UI).
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			held.Mouse = true
			Actions.fire("MouseAim", "Begin")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and held.Mouse then
			held.Mouse = false
			Actions.fire("MouseAim", "End")
		end
	end)
end

return Actions
