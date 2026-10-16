--!nocheck
-- Mini-job "Corner Cheese" (beta-spec-maps §5, ux §3.1): fixed loot, the van exit with the slot's Session, the
-- sleeping guard spot, the barrel, tutorial triggers, two flat rolling routes, signs and budgets.
local roblox = require("@lune/roblox")
local Mock = require("./MockRoblox")
local Geometry = require("./Geometry")
local Checks = require("./Checks")

local Vector3 = roblox.Vector3

local PROPS = {
	Van = Vector3.new(8.125, 8.381, 13.046),
	Barrel = Vector3.new(2.6, 2.41, 2.12),
	Crate = Vector3.new(4, 3.821, 3.987),
	StreetLamp = Vector3.new(2.289, 13, 2.278),
	MarketStall = Vector3.new(8, 7, 5),
}

local function build(withProps, slot)
	local world = Mock.world({ props = if withProps then PROPS else nil })
	local MapService = world.require(world.server.Services.MapService)
	local folder, points = MapService:BuildMiniJob(slot or 1)
	return world, MapService, folder, points
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function pathLength(points)
	local total = 0
	for i = 1, #points - 1 do
		total += (flat(points[i + 1]) - flat(points[i])).Magnitude
	end
	return total
end

return function(t)
	for _, withProps in { false, true } do
		local label = if withProps then " (props)" else " (stand-ins)"

		t.test("MiniJob: part and light budget" .. label, function()
			local _, MapService, folder = build(withProps)
			local budget = MapService.MiniJobDef.Budget
			local counts = Checks.counts(folder)
			t.ok(counts.parts <= budget.Parts, `parts {counts.parts} > {budget.Parts}`)
			t.ok(counts.lights <= budget.Lights, `lights {counts.lights} > {budget.Lights}`)
			t.ok(counts.shadowed <= budget.Shadowed, `shadowed lights {counts.shadowed} > {budget.Shadowed}`)
			t.ok(counts.parts > 200, "the mini-job is actually built")
		end)

		t.test("MiniJob: fixed loot anchors with the slot's Session" .. label, function()
			local world, _, folder, points = build(withProps, 2)
			local Tags = world.require(world.shared.Tags)
			local anchors = Checks.tagged(folder, Tags.LootAnchor)
			t.eq(#anchors, 7)
			local classes, openers, drawers = {}, {}, 0
			for _, anchor in anchors do
				Checks.anchorContract(t, anchor)
				t.eq(anchor:GetAttribute("Fixed"), true)
				t.eq(anchor:GetAttribute("Session"), "Tutorial2")
				local class = anchor:GetAttribute("AnchorClass")
				classes[class] = (classes[class] or 0) + 1
				if anchor:GetAttribute("Opener") then
					table.insert(openers, anchor)
				end
				if anchor:GetAttribute("Group") == "Drawer" then
					drawers += 1
				end
				if class == "Main" then
					t.eq(anchor:GetAttribute("Scale"), 0.6, "mini Gouda")
					t.near((anchor.Position - points.Gouda).Magnitude, 0, 1e-6, "Points.Gouda")
				end
			end
			t.eq(classes.Medium, 2)
			t.eq(classes.Small, 4)
			t.eq(classes.Main, 1)
			t.eq(drawers, 1, "one till (Group Drawer)")
			t.eq(#openers, 1, "only the stall wheel is the Opener")
			t.near((openers[1].Position - points.Wheel).Magnitude, 0, 1e-6, "Points.Wheel")
			Checks.uniqueAnchorIds(t, anchors)
			-- Loot entries cover every anchor (RoundPlan fills Fixed anchors per class/group).
			local Config = world.require(world.shared.Config)
			local wanted = {}
			for _, entry in world.require(world.server.Map.MiniJob).Loot do
				local def = Config.Loot.Types[entry.Type]
				t.ok(def, "known loot type " .. entry.Type)
				local key = def.Class .. "/" .. tostring(entry.Group)
				wanted[key] = (wanted[key] or 0) + entry.Count
			end
			t.eq(wanted["Medium/nil"], 2)
			t.eq(wanted["Small/nil"], 3)
			t.eq(wanted["Small/Drawer"], 1)
			t.eq(wanted["Main/nil"], 1)
		end)

		t.test("MiniJob: wheel 15 studs from the spawn, first bank close by" .. label, function()
			local world, _, folder, points = build(withProps)
			local Tags = world.require(world.shared.Tags)
			local distance = (flat(points.Wheel) - flat(points.Spawn)).Magnitude
			t.ok(math.abs(distance - 15) <= 1.5, string.format("wheel %.1f studs from the spawn", distance))
			t.ok(
				points.SpawnFacing:Dot((flat(points.Wheel) - flat(points.Spawn)).Unit) > 0.99,
				"spawn faces it"
			)
			local exits = Checks.tagged(folder, Tags.Exit)
			t.eq(#exits, 1)
			local exit = exits[1]
			t.eq(exit:GetAttribute("ExitKind"), "Van")
			local bank = exit:FindFirstChild("BankZone")
			t.ok(bank and bank:HasTag(Tags.BankZone), "BankZone child")
			t.eq(bank:GetAttribute("Session"), "Tutorial1")
			t.ok(exit:FindFirstChild("DrivePoint"), "DrivePoint child")
			t.ok(not Geometry.pointInside(points.Spawn, bank, 0), "spawn is not in the bank zone")
			local toBank = (flat(points.Wheel) - flat(points.BankZone)).Magnitude
			t.ok(toBank <= 10, string.format("wheel → bank %.1f studs", toBank))
			t.eq(#Checks.tagged(folder, Tags.BankZone), 1, "one BankZone")
		end)

		t.test("MiniJob: sleeping guard, barrel and tutorial triggers" .. label, function()
			local world, _, folder, points = build(withProps)
			local Tags = world.require(world.shared.Tags)
			local guard = folder.Anchors:FindFirstChild("SleepingGuard")
			t.ok(guard, "SleepingGuard anchor")
			t.near((guard.Position - points.SleepingGuard).Magnitude, 0, 1e-6)
			t.ok(guard.CFrame.LookVector:Dot(points.SleepingGuardFacing) > 0.99, "guard faces the quay")
			-- 5 studs from the front door's centre line (beta-spec-maps §5).
			t.near(math.abs(guard.Position.Z - points.FrontDoor.Z), 5, 0.5, "guard beside the door")
			local hides = Checks.tagged(folder, Tags.HideSpot)
			t.eq(#hides, 1)
			Checks.hideSpotContract(t, hides[1])
			t.eq(hides[1]:GetAttribute("HideKind"), "Barrel")
			local steps = {}
			for _, trigger in Checks.tagged(folder, Tags.TutorialTrigger) do
				steps[trigger:GetAttribute("Step")] = trigger
				t.eq(trigger:GetAttribute("Session"), "Tutorial1")
				t.eq(trigger.CanCollide, false)
			end
			t.ok(steps.SneakedPastGuard, "SneakedPastGuard trigger")
			t.ok(steps.GuardAhead, "GuardAhead trigger")
			-- Walking in through the front door crosses the SneakedPastGuard trigger.
			t.ok(
				Geometry.pointInside(points.FrontDoor + Vector3.new(1.5, 3, 0), steps.SneakedPastGuard, 0),
				"inside"
			)
		end)

		t.test("MiniJob: signs are readable" .. label, function()
			local _, _, folder = build(withProps)
			local texts = Checks.signTexts(folder)
			for _, want in { "CORNER CHEESE", "CHEESE", "SIDE DOOR", "TO THE VAN" } do
				t.ok(texts[want], "sign " .. want)
			end
			local problems = Checks.signProblems(folder)
			t.eq(#problems, 0, table.concat(problems, "; "))
		end)

		t.test("MiniJob: lanes and both rolling routes are clear and flat" .. label, function()
			local world, MapService, folder, points = build(withProps)
			local o = world.require(world.shared.Config).World.MiniJobOrigins[1]
			local origin = Vector3.new(o.X, o.Y, o.Z)
			local lanes = MapService.MiniJobDef.Lanes
			local problems = Checks.lanes(folder, origin, lanes)
			t.eq(#problems, 0, table.concat(problems, "; "))
			local bank = Checks.tagged(folder, "BankZone")[1]
			for _, lane in lanes do
				if string.sub(lane.Name, 1, 4) == "Roll" then
					local first = origin + lane.Points[1]
					local last = origin + lane.Points[#lane.Points]
					t.ok(
						(flat(first) - flat(points.Gouda)).Magnitude <= 4,
						lane.Name .. " starts at the Gouda"
					)
					t.ok(
						Geometry.pointInside(last + Vector3.new(0, 1, 0), bank, 0),
						lane.Name .. " ends in the van zone"
					)
					for _, p in lane.Points do
						t.eq(p.Y, 0, lane.Name .. " is flat")
					end
				end
			end
			local front = pathLength(lanes[4].Points)
			local alley = pathLength(lanes[5].Points)
			t.ok(front >= 30 and front <= 48, string.format("route past the guard %.0f studs", front))
			t.ok(alley >= 45 and alley <= 62, string.format("route through the alley %.0f studs", alley))
		end)
	end

	t.test("MiniJob: two slots side by side keep their own ids and sessions", function()
		local world = Mock.world()
		local MapService = world.require(world.server.Services.MapService)
		local Tags = world.require(world.shared.Tags)
		local f1 = MapService:BuildMiniJob(1)
		local f2 = MapService:BuildMiniJob(2)
		local all = {}
		for _, folder in { f1, f2 } do
			for _, anchor in Checks.tagged(folder, Tags.LootAnchor) do
				table.insert(all, anchor)
			end
		end
		t.eq(#all, 14)
		Checks.uniqueAnchorIds(t, all)
		t.eq(Checks.tagged(f2, Tags.BankZone)[1]:GetAttribute("Session"), "Tutorial2")
		t.ok((f1.Anchors.Gouda.Position - f2.Anchors.Gouda.Position).Magnitude >= 2000, "slots far apart")
	end)
end
