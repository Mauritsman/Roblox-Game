--!strict
-- One input layer for keyboard, controller and touchscreen (beta-spec-ux §2.1).
-- Code listens to actions ("Primary", "Crouch"...) instead of buttons, so everything works on every device.
--
--   Actions.on(name, fn)          listen (fn(phase) with phase "Begin" | "End")
--   Actions.fire(name, phase)     used by the touch buttons
--   Actions.intercept(name, fn)   fn(phase) returns true to swallow the action (e.g. THROW instead of a gadget)
--   Actions.setBlocker(fn)        fn(name) returns true to drop an action (a menu is open)
--   Actions.bindTemporary(...)    extra keys while a mode is active (cell camera switching); sinks the keys
--
-- Aliases keep older listeners working: "Primary" also fires "Fire" (GadgetController, DroneController).

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Device)

local Actions = {}

export type Phase = "Begin" | "End"
type Listener = (phase: Phase) -> ()
type Interceptor = (phase: Phase) -> boolean

local listeners: { [string]: { Listener } } = {}
local interceptors: { [string]: { Interceptor } } = {}
local blocker: ((name: string) -> boolean)? = nil

local K = Enum.KeyCode

-- Keys per action. Mouse button 1 is handled separately ("MouseAim", only outside the UI).
local BINDINGS: { [string]: { Enum.KeyCode } } = {
	Slot1 = { K.One },
	Slot2 = { K.Two },
	Slot3 = { K.Three },
	NextSlot = { K.ButtonL1 },
	Aim = { K.ButtonL2 },
	Primary = { K.ButtonR2 }, -- gadget use / THROW / ROLL ("the primary button does what your hands allow")
	Cancel = { K.R },
	Crouch = { K.C, K.ButtonB },
	Spot = { K.Q, K.ButtonR1 }, -- tap = SPOT, hold = quick wheel
	Context = { K.E, K.ButtonX }, -- prompts handle E/X themselves; this covers DROP, CRAWL OUT, OUT
	Drop = { K.G },
	Roll = { K.V },
	QuickGo = { K.Z, K.DPadUp },
	QuickWait = { K.X, K.DPadDown },
	QuickHelp = { K.DPadLeft },
	QuickVan = { K.DPadRight },
	DroneRecall = { K.F, K.ButtonY },
	DroneUp = { K.Space, K.ButtonA },
	DroneDown = { K.LeftControl, K.ButtonB },
	Back = { K.ButtonB },
}

local ALIASES: { [string]: { string } } = {
	Primary = { "Fire" },
}

function Actions.on(name: string, listener: Listener)
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, listener)
end

function Actions.intercept(name: string, interceptor: Interceptor)
	local list = interceptors[name]
	if not list then
		list = {}
		interceptors[name] = list
	end
	table.insert(list, interceptor)
end

function Actions.setBlocker(fn: ((name: string) -> boolean)?)
	blocker = fn
end

local function dispatch(name: string, phase: Phase)
	local list = listeners[name]
	if list then
		for _, listener in list do
			task.spawn(listener, phase)
		end
	end
end

function Actions.fire(name: string, phase: Phase)
	if blocker and blocker(name) then
		return
	end
	local intercepting = interceptors[name]
	if intercepting then
		for _, interceptor in intercepting do
			local ok, swallowed = pcall(interceptor, phase)
			if ok and swallowed then
				return
			end
		end
	end
	dispatch(name, phase)
	local aliases = ALIASES[name]
	if aliases then
		for _, alias in aliases do
			dispatch(alias, phase)
		end
	end
end

-- Tracks which actions are currently held down (for the drone: holding up/down).
local held: { [string]: boolean } = {}
function Actions.isHeld(name: string): boolean
	return held[name] == true
end

function Actions.setHeld(name: string, isHeld: boolean)
	held[name] = isHeld
end

function Actions.preferredInput(): string
	return Device.input()
end

local function handler(name: string, sink: boolean)
	return function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			held[name] = true
			Actions.fire(name, "Begin")
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			if held[name] then
				held[name] = false
				Actions.fire(name, "End")
			end
		end
		-- Pass space/E/X through to Roblox (jumping, prompts) unless this binding must win.
		return if sink then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end
end

-- Extra keys for a mode (e.g. A/D and LB/RB switch cell cameras). Bound last, so they win over others.
function Actions.bindTemporary(name: string, keys: { Enum.KeyCode })
	ContextActionService:BindActionAtPriority(
		"CC_Temp_" .. name,
		handler(name, true),
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(keys)
	)
end

function Actions.unbindTemporary(name: string)
	ContextActionService:UnbindAction("CC_Temp_" .. name)
	held[name] = false
end

function Actions.init()
	for name, keys in BINDINGS do
		ContextActionService:BindAction("CC_" .. name, handler(name, false), false, table.unpack(keys))
	end

	-- Left mouse button: press = aim / use, release = throw (only outside the UI).
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
