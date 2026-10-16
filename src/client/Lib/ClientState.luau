--!strict
-- Shared state on the player's side (which gadget is selected, aiming, drone, control mode...).
-- `mode` is computed by CharState: Explore | Carry | Drone | Hidden | Cell | Carried | Van | Spectate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local ClientState = {
	selectedSlot = 1,
	aiming = false, -- aiming a gadget (GadgetController)
	aimPoint = nil :: Vector3?,
	drone = nil :: BasePart?,
	mode = "Explore",
	throwAiming = false, -- aiming a loot throw (HandsController)
	spectating = nil :: number?, -- UserId being watched from the Garage
	camIndex = nil :: number?, -- security camera shown in the cell feed
	Changed = Signal.new() :: Signal.Signal<string>,
}

function ClientState.set(key: string, value: any)
	(ClientState :: any)[key] = value
	ClientState.Changed:Fire(key)
end

return ClientState
