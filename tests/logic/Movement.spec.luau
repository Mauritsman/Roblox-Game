--!nocheck
local Movement = require("../../src/shared/Logic/Movement")
local Config = require("../../src/shared/Config")

local stats = Config.Movement

return function(t)
	t.test("walk: 16 and full jump, may crouch and use gadgets", function()
		local r = Movement.resolve({}, stats)
		t.eq(r.walkSpeed, 16)
		t.eq(r.jumpHeight, 7.2)
		t.ok(r.canCrouch and r.canGadget)
		t.eq(r.state, "Walk")
	end)

	t.test("crouch: 8, gadgets still allowed", function()
		local r = Movement.resolve({ crouching = true }, stats)
		t.eq(r.walkSpeed, 8)
		t.ok(r.canGadget)
		t.eq(r.state, "Crouch")
	end)

	t.test("pocket (small) loot changes nothing", function()
		t.eq(Movement.resolve({ carryClass = "Small" }, stats).walkSpeed, 16)
		local r = Movement.resolve({ carryClass = "Small", crouching = true }, stats)
		t.eq(r.walkSpeed, 8)
		t.ok(r.canGadget)
	end)

	t.test("medium: 12, small jump, no crouch, no gadgets", function()
		local r = Movement.resolve({ carryClass = "Medium" }, stats)
		t.eq(r.walkSpeed, 12)
		t.eq(r.jumpHeight, 3.5)
		t.ok(not r.canCrouch and not r.canGadget)
	end)

	t.test("heavy alone 7, rolling 11, together 12", function()
		t.eq(Movement.resolve({ carryClass = "Heavy" }, stats).walkSpeed, 7)
		t.eq(Movement.resolve({ carryClass = "Heavy", rolling = true }, stats).walkSpeed, 11)
		t.eq(Movement.resolve({ carryClass = "Heavy", twoCarry = true }, stats).walkSpeed, 12)
		-- two-carry wins over a stale rolling flag
		t.eq(Movement.resolve({ carryClass = "Heavy", twoCarry = true, rolling = true }, stats).walkSpeed, 12)
		local r = Movement.resolve({ carryClass = "Heavy" }, stats)
		t.eq(r.jumpHeight, stats.HeavyJump)
		t.ok(not r.canCrouch and not r.canGadget)
	end)

	t.test("main loot moves like heavy", function()
		t.eq(Movement.resolve({ carryClass = "Main" }, stats).walkSpeed, 7)
		t.eq(Movement.resolve({ carryClass = "Main", rolling = true }, stats).walkSpeed, 11)
		t.eq(Movement.resolve({ carryClass = "Main", twoCarry = true }, stats).walkSpeed, 12)
	end)

	t.test("carry beats crouch", function()
		local r = Movement.resolve({ carryClass = "Medium", crouching = true }, stats)
		t.eq(r.walkSpeed, 12)
		t.eq(r.state, "CarryMedium")
	end)

	t.test("stopping states: speed 0, no jump, nothing allowed", function()
		for _, key in { "frozen", "caught", "hidden", "bubbled", "slipping", "operating" } do
			local r = Movement.resolve({ [key] = true }, stats)
			t.eq(r.walkSpeed, 0, key)
			t.eq(r.jumpHeight, 0, key)
			t.ok(not r.canCrouch and not r.canGadget, key)
		end
	end)

	t.test("priority Frozen > Caught > Hidden > Bubbled > Slipping > Operating > carry > crouch", function()
		local flags = {
			frozen = true,
			caught = true,
			hidden = true,
			bubbled = true,
			slipping = true,
			operating = true,
			carryClass = "Heavy",
			crouching = true,
		}
		local order = { "frozen", "caught", "hidden", "bubbled", "slipping", "operating" }
		local states = { "Frozen", "Caught", "Hidden", "Bubbled", "Slipping", "Operating" }
		for index, key in order do
			t.eq(Movement.resolve(flags, stats).state, states[index])
			flags[key] = nil
		end
		t.eq(Movement.resolve(flags, stats).state, "CarryHeavy")
		flags.carryClass = nil
		t.eq(Movement.resolve(flags, stats).state, "Crouch")
		flags.crouching = nil
		t.eq(Movement.resolve(flags, stats).state, "Walk")
	end)

	t.test("uses the player's stats (perks)", function()
		local custom = table.clone(stats)
		custom.Crouch = 9
		custom.HeavySolo = 8
		t.eq(Movement.resolve({ crouching = true }, custom).walkSpeed, 9)
		t.eq(Movement.resolve({ carryClass = "Heavy" }, custom).walkSpeed, 8)
	end)

	t.test("handsFull: medium, heavy and main only", function()
		t.ok(Movement.handsFull("Medium"))
		t.ok(Movement.handsFull("Heavy"))
		t.ok(Movement.handsFull("Main"))
		t.ok(not Movement.handsFull("Small"))
		t.ok(not Movement.handsFull(nil))
	end)

	t.test("goo caps speed and jump, never raises them", function()
		local r = Movement.resolve({ speedCap = 4, jumpCap = 2 }, stats)
		t.eq(r.walkSpeed, 4)
		t.eq(r.jumpHeight, 2)
		t.eq(r.state, "Walk")
		t.eq(Movement.resolve({ carryClass = "Heavy", speedCap = 4 }, stats).walkSpeed, 4)
		t.eq(Movement.resolve({ frozen = true, speedCap = 4 }, stats).walkSpeed, 0)
		t.eq(Movement.resolve({ crouching = true, speedCap = 9 }, stats).walkSpeed, 8)
	end)
end
