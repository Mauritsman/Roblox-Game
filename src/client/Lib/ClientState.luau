--!strict
-- Gedeelde toestand aan de kant van de speler (welk gadget geselecteerd, richten, drone...).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local ClientState = {
	selectedSlot = 1,
	aiming = false,
	aimPoint = nil :: Vector3?,
	drone = nil :: BasePart?,
	chainCall = nil :: { [string]: any }?,
	Changed = Signal.new() :: Signal.Signal<string>,
}

function ClientState.set(key: string, value: any)
	(ClientState :: any)[key] = value
	ClientState.Changed:Fire(key)
end

return ClientState
