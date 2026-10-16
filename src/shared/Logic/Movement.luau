--!strict
-- How fast a player may move right now. MovementService is the only writer of WalkSpeed/JumpHeight and asks
-- this module (beta-spec §9.6). Priority, first match wins:
--   Frozen > Caught > Hidden > Bubbled > Slipping > Operating > carry > crouch > walk.
-- `stats` are the player's numbers (Config.Movement after perks, see Logic/Perks).

local Movement = {}

export type Flags = {
	frozen: boolean?,
	caught: boolean?,
	hidden: boolean?,
	bubbled: boolean?,
	slipping: boolean?,
	operating: boolean?, -- flying a drone or watching camera feeds
	carryClass: string?, -- "Small" | "Medium" | "Heavy" | "Main" | nil (Small = pocket only, no effect)
	rolling: boolean?, -- heavy loot rolled alone
	twoCarry: boolean?, -- heavy loot carried as leader or helper
	crouching: boolean?,
}

export type Stats = {
	Walk: number,
	Crouch: number,
	Medium: number,
	HeavySolo: number,
	HeavyRoll: number,
	TwoCarry: number,
	Jump: number,
	MediumJump: number,
	HeavyJump: number,
}

export type Result = {
	walkSpeed: number,
	jumpHeight: number,
	canCrouch: boolean,
	canGadget: boolean, -- gadgets and the Crowbar
	state: string, -- which rule won (for debugging and tests)
}

local function still(state: string): Result
	return { walkSpeed = 0, jumpHeight = 0, canCrouch = false, canGadget = false, state = state }
end

-- Medium, heavy and main loot fill your hands; pocket loot does not.
function Movement.handsFull(carryClass: string?): boolean
	return carryClass == "Medium" or carryClass == "Heavy" or carryClass == "Main"
end

function Movement.resolve(flags: Flags, stats: Stats): Result
	if flags.frozen then
		return still("Frozen")
	elseif flags.caught then
		return still("Caught")
	elseif flags.hidden then
		return still("Hidden")
	elseif flags.bubbled then
		return still("Bubbled")
	elseif flags.slipping then
		return still("Slipping")
	elseif flags.operating then
		return still("Operating")
	end

	local class = flags.carryClass
	if class == "Medium" then
		return {
			walkSpeed = stats.Medium,
			jumpHeight = stats.MediumJump,
			canCrouch = false,
			canGadget = false,
			state = "CarryMedium",
		}
	elseif class == "Heavy" or class == "Main" then
		local speed, state
		if flags.twoCarry then
			speed, state = stats.TwoCarry, "CarryTogether"
		elseif flags.rolling then
			speed, state = stats.HeavyRoll, "Rolling"
		else
			speed, state = stats.HeavySolo, "CarryHeavy"
		end
		return {
			walkSpeed = speed,
			jumpHeight = stats.HeavyJump,
			canCrouch = false,
			canGadget = false,
			state = state,
		}
	end

	if flags.crouching then
		return {
			walkSpeed = stats.Crouch,
			jumpHeight = stats.Jump,
			canCrouch = true,
			canGadget = true,
			state = "Crouch",
		}
	end
	return {
		walkSpeed = stats.Walk,
		jumpHeight = stats.Jump,
		canCrouch = true,
		canGadget = true,
		state = "Walk",
	}
end

return Movement
