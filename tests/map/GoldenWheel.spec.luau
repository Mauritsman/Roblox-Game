--!nocheck
-- The Golden Wheel, built in Lune without Studio (tests/map/MapHarness): contracts (docs/contracts.md §2.5, §3),
-- anchor counts, budgets (beta-spec-maps §12), sign rules (§2/§10), walkability with any two open entrances, and a
-- RoundPlan run over the real level. Run alone: `lune run tests/run` (all specs) or `lune run tests/map/report`.
local Harness = require("./MapHarness")
local RoundPlan = require("../../src/shared/Logic/RoundPlan")
local Config = require("../../src/shared/Config")

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local SPAWN_RADIUS_OPENER = 40
local PUBLIC = { Quay = true, Shop = true }

return function(t)
	local world
	local okBuild, buildErr = pcall(function()
		world = Harness.buildHeist("GoldenWheel")
	end)
	t.test("GoldenWheel builds (no math.random, no warnings)", function()
		t.ok(okBuild, tostring(buildErr))
		t.eq(#world.warnings, 0, table.concat(world.warnings, "; "))
	end)
	if not okBuild then
		return
	end
	local level, heist, Tags = world.level, world.heist, world.Tags

	local function tagged(tag)
		return Harness.tagged(level, tag)
	end
	local function attr(inst, name)
		return inst:GetAttribute(name)
	end
	local function isHiddenAnchor(part)
		return part:IsA("BasePart")
			and part.Anchored
			and part.Transparency == 1
			and not part.CanCollide
			and not part.CanQuery
			and not part.CanTouch
	end
	local function pointOf(inst)
		return inst.CFrame.Position
	end
	local function insideAnyVolume(tag, p)
		for _, v in tagged(tag) do
			if Harness.inside(v, p) then
				return true
			end
		end
		return false
	end

	t.test("budgets: ≤ 4,800 parts, ≤ 40 lights, ≤ 9 with shadows", function()
		local parts, lights, shadows = 0, 0, 0
		for _, d in level:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			elseif d:IsA("Light") then
				lights += 1
				if d.Shadows then
					shadows += 1
				end
			end
		end
		t.ok(parts <= 4800, `parts {parts}`)
		t.ok(lights <= 40, `lights {lights}`)
		t.ok(shadows <= 9, `shadowed lights {shadows}`)
		for _, d in level:GetDescendants() do
			if d:IsA("SurfaceLight") then
				error("SurfaceLight on " .. d.Parent:GetFullName() .. " (window lights are off on map 1)")
			end
		end
	end)

	t.test("loot anchors: contract, unique ids, counts per class", function()
		local seen, counts = {}, {}
		for _, a in tagged(Tags.LootAnchor) do
			t.ok(isHiddenAnchor(a), a.Name .. " must be invisible, anchored, no collide/query/touch")
			t.ok(
				a.Parent.Name == "Anchors" and a.Parent.Parent == level,
				a.Name .. " must live in Level.Anchors"
			)
			local id, class = attr(a, Tags.AnchorId), attr(a, Tags.AnchorClass)
			t.ok(type(id) == "string" and not seen[id], "duplicate or missing AnchorId " .. tostring(id))
			seen[id] = true
			t.ok(
				class == "Small" or class == "Medium" or class == "Heavy" or class == "Main",
				"class " .. tostring(class)
			)
			t.ok(type(attr(a, Tags.Zone)) == "string", id .. " has no Zone")
			local key = class .. (if attr(a, Tags.Group) then "/" .. attr(a, Tags.Group) else "")
			counts[key] = (counts[key] or 0) + 1
		end
		t.eq(counts.Main, 3, "Main")
		t.ok((counts.Heavy or 0) >= 4, "Heavy ≥ 4")
		t.ok((counts.Medium or 0) >= 12, "Medium ≥ 12")
		t.ok((counts.Small or 0) >= 12, "ungrouped Small ≥ 12")
		t.eq(counts["Small/Keycard"], 5, "keycard spots")
		t.eq(counts["Small/Drawer"], 2, "drawers")
		t.eq(counts["Small/Secret"], 2, "secrets")
		t.eq(counts["Small/OfficeSafe"], 2, "safe loot")
	end)

	t.test("openers: ≥ 2, public, ≤ 40 studs from the spawn", function()
		local n = 0
		for _, a in tagged(Tags.LootAnchor) do
			if attr(a, Tags.Opener) then
				n += 1
				t.ok(PUBLIC[attr(a, Tags.Zone)], attr(a, Tags.AnchorId) .. " opener is not public")
				local d = (pointOf(a) - heist.Points.Spawn).Magnitude
				t.ok(
					d <= SPAWN_RADIUS_OPENER,
					`{attr(a, Tags.AnchorId)} is {math.floor(d)} studs from the spawn`
				)
			end
		end
		t.ok(n >= 2, `only {n} openers`)
	end)

	t.test("rings: main loot is Secure, staff loot is in a StaffZone, public loot in none", function()
		for _, a in tagged(Tags.LootAnchor) do
			local p = pointOf(a) + Vector3.new(0, 0.5, 0)
			local id, zone = attr(a, Tags.AnchorId), attr(a, Tags.Zone)
			if attr(a, Tags.AnchorClass) == "Main" then
				t.ok(insideAnyVolume(Tags.SecureZone, p), id .. " is not inside a SecureZone")
			end
			if PUBLIC[zone] then
				t.ok(not insideAnyVolume(Tags.StaffZone, p), id .. " (public) lies in a StaffZone")
			else
				t.ok(insideAnyVolume(Tags.StaffZone, p), id .. " (" .. zone .. ") is outside every StaffZone")
			end
		end
	end)

	-- Feeds the real level into RoundPlan, like SetupService will.
	local function heistInfo()
		local anchors = {}
		for _, a in tagged(Tags.LootAnchor) do
			table.insert(anchors, {
				Id = attr(a, Tags.AnchorId),
				Class = attr(a, Tags.AnchorClass),
				Group = attr(a, Tags.Group),
				Fixed = attr(a, Tags.Fixed),
				Opener = attr(a, Tags.Opener),
				Zone = attr(a, Tags.Zone),
			})
		end
		local entrances, exits, hazards = {}, {}, {}
		for _, e in tagged(Tags.Entrance) do
			table.insert(entrances, attr(e, Tags.EntranceId))
		end
		for _, e in tagged(Tags.Exit) do
			if e:IsA("Model") then
				table.insert(
					exits,
					{ Id = e.Name, Kind = attr(e, Tags.ExitKind), Optional = attr(e, Tags.Optional) }
				)
			end
		end
		for _, h in tagged(Tags.HazardAnchor) do
			table.insert(hazards, attr(h, Tags.AnchorId))
		end
		return {
			heistId = heist.Id,
			anchors = anchors,
			loot = heist.Loot,
			lootTypes = Config.Loot.Types,
			entrances = entrances,
			exits = exits,
			routes = heist.Points.GuardRoutes,
			hazards = hazards,
			objectives = heist.Objectives,
			guardBonus = heist.GuardBonus,
			hasDog = heist.HasDog,
			extraNpcs = heist.ExtraNpcs,
			rules = RoundPlan.rulesFrom(Config),
		}
	end

	t.test("RoundPlan on the real level: 60 seeds × crew 1–4 give no warnings", function()
		local info = heistInfo()
		local mains = { G1 = 0, G2 = 0, G3 = 0 }
		for seed = 1, 60 do
			for crew = 1, 4 do
				local plan = RoundPlan.generate(seed * 7919, info, crew, { difficulty = "Normal" })
				t.eq(#plan.warnings, 0, `seed {seed} crew {crew}: {table.concat(plan.warnings, "; ")}`)
				t.ok(mains[plan.mainAnchor] ~= nil, "main loot on " .. tostring(plan.mainAnchor))
				mains[plan.mainAnchor] += 1
				t.eq(#plan.lockedEntrances, 2, "two entrances locked")
			end
		end
		for id, n in mains do
			t.ok(n > 0, id .. " never chosen")
		end
		-- Hard + Double Shift (most guards) still fits the routes and the NPC cap.
		local plan = RoundPlan.generate(4242, info, 4, { difficulty = "Hard", modifierId = "DoubleShift" })
		t.eq(#plan.warnings, 0, table.concat(plan.warnings, "; "))
	end)

	t.test("entrances: E1–E4 with a LockedBlocker, pryables inside; one loud-only shortcut", function()
		local ids = {}
		for _, e in tagged(Tags.Entrance) do
			t.ok(e:IsA("Model"), "Entrance must be a Model")
			local id = attr(e, Tags.EntranceId)
			t.ok(not ids[id], "duplicate EntranceId " .. tostring(id))
			ids[id] = true
			local blocker = e:FindFirstChild("LockedBlocker")
			t.ok(blocker ~= nil, id .. " has no LockedBlocker")
			local solid = false
			for _, p in blocker:GetDescendants() do
				if p:IsA("BasePart") and p.CanCollide then
					solid = true
				end
			end
			t.ok(solid, id .. " blocker is not solid")
		end
		for _, id in { "E1", "E2", "E3", "E4" } do
			t.ok(ids[id], id .. " missing")
		end
		local loud = 0
		for _, p in tagged(Tags.Pryable) do
			t.ok(type(attr(p, "PrySeconds")) == "number", p.Name .. " PrySeconds")
			t.eq(attr(p, Tags.DoorState), "Closed", p.Name .. " DoorState")
			t.eq(typeof(attr(p, Tags.ClosedCFrame)), "CFrame", p.Name .. " ClosedCFrame")
			if attr(p, Tags.LoudOnly) then
				loud += 1
			end
		end
		t.eq(loud, 1, "loud-only shortcuts")
		for _, name in { "StaffDoor", "DeliveryGate" } do
			local door = level:FindFirstChild(name, true)
			t.ok(door and door:HasTag(Tags.Pryable), name .. " (DevPry name) missing")
			local entrance = door.Parent
			t.ok(entrance:HasTag(Tags.Entrance), name .. " must sit inside its Entrance model")
		end
	end)

	t.test("exits: the van and the optional boat, each with BankZone + DrivePoint", function()
		local kinds = {}
		for _, e in tagged(Tags.Exit) do
			if e:IsA("Model") then
				local kind = attr(e, Tags.ExitKind)
				kinds[kind] = e
				local zone = e:FindFirstChild("BankZone")
				t.ok(zone and zone:HasTag(Tags.BankZone), kind .. " BankZone")
				t.eq(attr(zone, Tags.Session), "Crew", kind .. " BankZone Session")
				t.ok(
					not zone.CanCollide and zone.Transparency == 1,
					kind .. " BankZone must be invisible and walk-through"
				)
				t.ok(e:FindFirstChild("DrivePoint"), kind .. " DrivePoint")
			end
		end
		t.ok(kinds.Van and not attr(kinds.Van, Tags.Optional), "van exit (not optional)")
		t.ok(kinds.Boat and attr(kinds.Boat, Tags.Optional) == true, "optional boat exit")
		t.ok(kinds.Boat:FindFirstChild("Sloep"), "the boat sits inside its exit (destroyed with it)")
		local zone = kinds.Van.BankZone
		t.ok(not Harness.inside(zone, heist.Points.Spawn), "spawn must be outside the van's bank zone")
	end)

	t.test("hide spots: 10–12, contract, ≥ 4 tall, free space at Exit", function()
		local spots = tagged(Tags.HideSpot)
		t.ok(#spots >= 10 and #spots <= 12, `#hide spots {#spots}`)
		local solids = {}
		for _, p in level:GetDescendants() do
			if p:IsA("BasePart") and p.CanCollide then
				table.insert(solids, p)
			end
		end
		for _, h in spots do
			t.ok(h:IsA("Model") and type(attr(h, Tags.HideKind)) == "string", "HideSpot model + HideKind")
			local root = h.PrimaryPart
			t.ok(root ~= nil, h.Name .. " PrimaryPart")
			t.ok(root.Size.Y >= 4, h.Name .. " is lower than 4 studs")
			local inside, exit = root:FindFirstChild("Inside"), root:FindFirstChild(Tags.Exit)
			t.ok(inside and inside:IsA("Attachment"), h.Name .. " Inside attachment")
			t.ok(exit and exit:IsA("Attachment"), h.Name .. " Exit attachment")
			local exitPos = Harness.attachmentWorld(exit)
			for _, p in solids do
				if Harness.inside(p, exitPos) then
					error(`{h.Name} at {pointOf(root)}: Exit point is inside {p:GetFullName()}`)
				end
			end
		end
	end)

	t.test("hide spots near loot: each loot room has one within 15 studs, every spot within 25", function()
		local hides = {}
		for _, h in tagged(Tags.HideSpot) do
			table.insert(hides, h.PrimaryPart.CFrame.Position)
		end
		local roomBest = {}
		for _, a in tagged(Tags.LootAnchor) do
			local zone = attr(a, Tags.Zone)
			if not PUBLIC[zone] and attr(a, Tags.Group) ~= "Keycard" then
				local best = math.huge
				for _, p in hides do
					best = math.min(best, (p - pointOf(a)).Magnitude)
				end
				t.ok(best <= 25, `{attr(a, Tags.AnchorId)}: nearest hide spot {math.floor(best)} studs`)
				roomBest[zone] = math.min(roomBest[zone] or math.huge, best)
			end
		end
		for zone, best in roomBest do
			t.ok(best <= 15, `{zone}: nearest hide spot {math.floor(best)} studs`)
		end
	end)

	t.test(
		"cell: folder in Level, 4 spots, door, dropoff, exit, grate ≥ 15 studs away, see-through bars",
		function()
			local cell = level:FindFirstChild("Cell")
			t.ok(cell and cell:HasTag(Tags.Cell), "Level.Cell tagged Cell")
			local function inCell(tag)
				local out = {}
				for _, d in cell:GetDescendants() do
					if d:HasTag(tag) then
						table.insert(out, d)
					end
				end
				return out
			end
			local spots = inCell(Tags.CellSpot)
			t.eq(#spots, 4, "CellSpots")
			for _, tag in { Tags.CellDoor, Tags.CellDropoff, Tags.CellExit, Tags.CellGrate } do
				t.eq(#inCell(tag), 1, tag)
			end
			local door = inCell(Tags.CellDoor)[1]
			t.ok(door:IsA("BasePart") and door.CanCollide, "CellDoor is a solid part (holds the prompt)")
			t.ok(door:HasTag(Tags.SeeThrough), "CellDoor see-through")
			local grate = pointOf(inCell(Tags.CellGrate)[1])
			for _, s in spots do
				t.ok((pointOf(s) - grate).Magnitude >= 15, "CellGrate closer than 15 studs to a CellSpot")
			end
			local bars = 0
			for _, d in cell:GetDescendants() do
				if d.Name == "CellBar" then
					bars += 1
					t.ok(d:HasTag(Tags.SeeThrough), "bar not SeeThrough")
				end
			end
			t.ok(bars >= 10, "bars")
		end
	)

	t.test("Boef, Karel, hazards and zones", function()
		t.ok(#tagged(Tags.DogZone) >= 1, "DogZone")
		t.eq(#tagged(Tags.KarelHome), 1, "KarelHome")
		t.eq(#tagged(Tags.HazardAnchor), 10, "HazardAnchors")
		t.ok(#tagged(Tags.StaffZone) >= 1 and #tagged(Tags.SecureZone) == 3, "Staff/Secure volumes")
		for _, p in heist.Points.DogRoute do
			t.ok(
				insideAnyVolume(Tags.DogZone, p + Vector3.new(0, 1, 0)),
				`DogRoute point {p} outside the DogZone`
			)
		end
		local home = pointOf(tagged(Tags.KarelHome)[1])
		t.ok(
			not insideAnyVolume(Tags.StaffZone, home + Vector3.new(0, 1, 0)),
			"KarelHome stays in the public shop"
		)
		for _, v in tagged(Tags.StaffZone) do
			t.ok(isHiddenAnchor(v), v.Name .. " volume must be invisible and non-colliding")
		end
	end)

	t.test("objectives and set pieces: keycard gate, safe, Cheese Chute, landmark", function()
		local gates = tagged(Tags.KeycardDoor)
		t.eq(#gates, 1, "KeycardDoor")
		t.eq(attr(gates[1], Tags.Card), "Office", "Card")
		local door = gates[1].PrimaryPart
		t.ok(door and door.Size.Z >= 6, "office gate 6 wide")
		local safes = tagged(Tags.Safe)
		t.eq(#safes, 1, "Safe")
		local spot = safes[1]:FindFirstChild("DeviceSpot", true)
		t.ok(spot and spot:IsA("Attachment"), "Safe DeviceSpot")
		local rides = tagged(Tags.Ride)
		t.eq(#rides, 1, "Ride")
		local ride = rides[1]
		t.eq(attr(ride, Tags.RideId), "CheeseChute", "RideId")
		t.ok(attr(ride, Tags.Seats) == 1 and attr(ride, Tags.Speed) > 0, "Seats/Speed")
		local path = heist.Points.Rides[attr(ride, Tags.RideId)]
		t.ok(path and #path >= 2, "Points.Rides path")
		local stations = 0
		for _, d in ride:GetDescendants() do
			if d:IsA("Attachment") and d.Name == "Station" then
				stations += 1
				t.ok(
					type(attr(d, Tags.Boarding)) == "boolean" and type(attr(d, Tags.Stop)) == "boolean",
					"Station attrs"
				)
			end
		end
		t.eq(stations, 2, "chute stations")
		local length = 0
		for i = 2, #path do
			length += (path[i] - path[i - 1]).Magnitude
		end
		t.near(length / attr(ride, Tags.Speed), 2.5, 0.3, "chute ride ≈ 2.5 s")
		for _, d in ride:GetDescendants() do
			if d:IsA("BasePart") then
				t.ok(d.Anchored and not d.CanCollide, d.Name .. ": ride parts are anchored and walk-through")
			end
		end
		local wheel = tagged(Tags.Spinner)
		t.eq(#wheel, 1, "landmark Spinner")
		t.ok(wheel[1].PrimaryPart and attr(wheel[1], "SpinSeconds") > 0, "Spinner PrimaryPart + SpinSeconds")
	end)

	t.test("cameras: SecurityCamera contract, cones without shadows", function()
		local cams = tagged(Tags.SecurityCamera)
		t.eq(#cams, 6, "cameras")
		for _, cam in cams do
			t.ok(cam:HasTag(Tags.Electronic) and cam:HasTag(Tags.Spottable), cam.Name .. " tags")
			t.eq(attr(cam, Tags.Disabled), false, cam.Name .. " Disabled")
			t.eq(attr(cam, Tags.SpotKind), "camera", cam.Name .. " SpotKind")
			t.eq(typeof(attr(cam, "BaseLook")), "Vector3", cam.Name .. " BaseLook")
			local body = cam:FindFirstChild("Body")
			t.ok(body and cam.PrimaryPart == body and body.Anchored, cam.Name .. " Body")
			local cone = body:FindFirstChild("Cone")
			t.ok(cone and cone:IsA("SpotLight") and not cone.Shadows, cam.Name .. " Cone")
			local led
			for _, c in cam:GetChildren() do
				if c:IsA("BasePart") and c:GetAttribute("IsLed") then
					led = c
				elseif c:IsA("BasePart") and c ~= body and string.sub(c.Name, 1, 5) ~= "Mount" then
					t.ok(
						not c.Anchored and c:FindFirstChildOfClass("WeldConstraint"),
						c.Name .. " must be welded to Body"
					)
				end
			end
			t.ok(led ~= nil, cam.Name .. " Led")
		end
	end)

	t.test("lamps: PointLight, Electronic, Disabled = false", function()
		for _, lamp in tagged(Tags.Lamp) do
			t.ok(lamp:FindFirstChildOfClass("PointLight"), lamp.Name .. " has no PointLight")
			t.ok(lamp:HasTag(Tags.Electronic), lamp.Name .. " not Electronic")
			t.eq(attr(lamp, Tags.Disabled), false, lamp.Name)
		end
	end)

	t.test("signs: English caps, ≤ 2 lines of ≤ 16, big enough, nothing in front", function()
		local blockers = {}
		for _, p in level:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 0.5 and p.Name ~= "SignFrame" then
				table.insert(blockers, p)
			end
		end
		local signs = 0
		for _, board in level:GetDescendants() do
			local gui = board:IsA("BasePart") and board:FindFirstChild("SignText")
			if gui then
				signs += 1
				local text = gui:FindFirstChildOfClass("TextLabel").Text
				local where = `"{text}" at {pointOf(board)}`
				t.ok(gui:FindFirstChildOfClass("TextLabel").TextScaled, where .. ": TextScaled")
				t.ok(not string.find(text, "[^%u%d%s%p]"), where .. ": ALL CAPS, plain ASCII")
				local lines = string.split(text, "\n")
				t.ok(#lines <= 2, where .. ": more than 2 lines")
				for _, line in lines do
					t.ok(#line <= 16, where .. ": a line longer than 16")
				end
				local viewFrom = attr(board, "ViewFrom")
				t.ok(typeof(viewFrom) == "Vector3", where .. ": no ViewFrom")
				local cf, size = board.CFrame, board.Size
				local distance = (viewFrom - cf.Position).Magnitude
				t.ok(
					size.Y >= distance / 12 - 1e-6,
					`{where}: {size.Y} high, read from {math.floor(distance)} studs`
				)
				local front = cf.LookVector:Dot(viewFrom - cf.Position) > 0
				local faces = 0
				for _, c in board:GetChildren() do
					if c.Name == "SignText" then
						faces += 1
					end
				end
				t.ok(front or faces >= 2, where .. ": read from behind")
				local face = if front then -size.Z / 2 - 0.01 else size.Z / 2 + 0.01
				for _, c in { { 0, 0 }, { -0.42, -0.4 }, { 0.42, -0.4 }, { -0.42, 0.4 }, { 0.42, 0.4 } } do
					local target = cf * Vector3.new(c[1] * size.X, c[2] * size.Y, face)
					local a = viewFrom:Min(target)
					local b = viewFrom:Max(target)
					for _, p in blockers do
						if p ~= board then
							local pa, pb = Harness.aabb(p)
							if
								pb.X >= a.X
								and pa.X <= b.X
								and pb.Y >= a.Y
								and pa.Y <= b.Y
								and pb.Z >= a.Z
								and pa.Z <= b.Z
							then
								if Harness.rayHitsBox(p, viewFrom, target) then
									error(`{where}: {p:GetFullName()} blocks the view from {viewFrom}`)
								end
							end
						end
					end
				end
			end
		end
		t.ok(signs >= 15, `only {signs} signs`)
	end)

	t.test("guard routes: ≥ 6 routes × 2 variants, ≤ 25 s loops, legs clear of walls", function()
		local routes = heist.Points.GuardRoutes
		t.ok(#routes >= 6, "routes")
		local raster = Harness.rasterize(level, { minX = -30, maxX = 67, minZ = -50, maxZ = 47, floorY = 0 })
		for _, route in routes do
			t.ok(#route.Variants >= 2, route.Id .. " variants")
			for v, points in route.Variants do
				local length, waits = 0, 0
				for i, wp in points do
					local nextWp = points[i % #points + 1]
					length += (nextWp.Pos - wp.Pos).Magnitude
					waits += wp.Wait or 0
					-- Sample the leg: an agent of radius 1.5 must fit everywhere along it.
					local steps = math.ceil((nextWp.Pos - wp.Pos).Magnitude)
					for s = 0, steps do
						local p = wp.Pos:Lerp(nextWp.Pos, s / math.max(steps, 1))
						local free = Harness.freeAt(raster, p, 1.5)
						t.ok(free, `{route.Id} V{v}: leg blocked at {p}`)
						if not free then
							break
						end
					end
				end
				t.ok(length / 6 + waits <= 25, `{route.Id} V{v}: loop {math.floor(length / 6 + waits)} s`)
			end
		end
	end)

	-- Ground-floor walkability. Pried doors are open (except the loud-only Fire Exit); blockers are solid only for
	-- the locked entrances of a scenario.
	local blockers, pryables = {}, {}
	for _, e in tagged(Tags.Entrance) do
		blockers[attr(e, Tags.EntranceId)] = e.LockedBlocker
	end
	for _, p in tagged(Tags.Pryable) do
		pryables[p] = true
	end
	local function skipDoorsAndBlockers(part)
		if pryables[part] and not attr(part, Tags.LoudOnly) then
			return true
		end
		for _, b in blockers do
			if part:IsDescendantOf(b) then
				return true
			end
		end
		return false
	end
	local ground = Harness.rasterize(level, {
		minX = -56,
		maxX = 67,
		minZ = -58,
		maxZ = 47,
		floorY = 0,
		skip = skipDoorsAndBlockers,
	})
	local function blockerParts(ids)
		local out = {}
		for _, id in ids do
			for _, p in blockers[id]:GetDescendants() do
				if p:IsA("BasePart") and p.CanCollide then
					table.insert(out, p)
				end
			end
		end
		return out
	end
	local groundTargets = {}
	for _, a in tagged(Tags.LootAnchor) do
		local p = pointOf(a)
		if p.Y > -1 and p.Y < 9 then
			table.insert(groundTargets, { attr(a, Tags.AnchorId), p })
		end
	end
	table.insert(groundTargets, { "office stair", Vector3.new(30.8, 0, 21.6) })
	table.insert(groundTargets, { "cellar trench", Vector3.new(26, 0, -43) })
	table.insert(groundTargets, { "closet door", Vector3.new(-3.5, 0, -24.5) })
	table.insert(
		groundTargets,
		{ "chute exit", heist.Points.Rides.CheeseChute[#heist.Points.Rides.CheeseChute] }
	)
	table.insert(groundTargets, { "boat jetty", Vector3.new(41, 0, -50) })

	-- Rooms a pathfinding agent (radius 2.25) must reach: one point per room or yard.
	local rooms = {
		{ "shop", Vector3.new(-14, 0, -24) },
		{ "security room", Vector3.new(-5, 0, -9) },
		{ "courtyard", Vector3.new(-10, 0, 20) },
		{ "hall west", Vector3.new(6, 0, -10) },
		{ "hall centre", Vector3.new(26, 0, 0) },
		{ "hall east", Vector3.new(46, 0, -14) },
		{ "office stair foot", Vector3.new(33, 0, 21.6) },
		{ "Back Yard", Vector3.new(40, 0, -36) },
		{ "trench head", Vector3.new(31, 0, -43) },
		{ "jetty", Vector3.new(41, 0, -49) },
		{ "Dock Apron", Vector3.new(64, 0, 0) },
		{ "Back Alley", Vector3.new(30, 0, 36) },
		{ "Bin Alley", Vector3.new(-10, 0, 44) },
		{ "Back Lane", Vector3.new(-10, 0, -44) },
	}

	t.test("walkable: any two open entrances let players reach every ground-floor loot spot", function()
		local ids = { "E1", "E2", "E3", "E4" }
		for i = 1, 4 do
			for j = i + 1, 4 do
				local locked = {}
				for k = 1, 4 do
					if k ~= i and k ~= j then
						table.insert(locked, ids[k])
					end
				end
				local parts = blockerParts(locked)
				-- Players (radius 1.25) reach the loot within grab range…
				local players = Harness.flood(ground, heist.Points.Spawn, 1.25, parts)
				t.ok(players.startFree, "spawn blocked")
				for _, target in groundTargets do
					t.ok(
						players.at(target[2], 5),
						`open {ids[i]}+{ids[j]}: {target[1]} at {target[2]} unreachable`
					)
				end
				-- …and pathfinding agents (radius 2.25) reach every room.
				local agents = Harness.flood(ground, heist.Points.Spawn, 2.25, parts)
				for _, room in rooms do
					t.ok(agents.at(room[2], 1.5), `open {ids[i]}+{ids[j]}: agents cannot reach the {room[1]}`)
				end
			end
		end
	end)

	t.test("B-002: main doorways pass a radius-2.9 agent (6-wide openings)", function()
		local reach = Harness.flood(ground, heist.Points.Spawn, 2.9)
		t.ok(reach.at(Vector3.new(-11, 0, -24), 1), "shop front door")
		t.ok(reach.at(Vector3.new(8, 0, -18), 1), "staff door E1 into the hall")
		t.ok(reach.at(Vector3.new(-10, 0, 20), 1), "delivery gate E2")
		t.ok(reach.at(Vector3.new(-10, 0, -44), 1), "Back Lane E3")
		t.ok(reach.at(Vector3.new(-10, 0, 44), 1), "Bin Alley E4")
		t.ok(reach.at(Vector3.new(55, 0, 16), 1), "Loading Dock")
		t.ok(reach.at(Vector3.new(-6, 0, 22), 1), "courtyard back door")
	end)

	t.test("office and cellar floors reach their loot from the stair / door", function()
		local office = Harness.rasterize(level, {
			minX = -1,
			maxX = 31,
			minZ = 10,
			maxZ = 26,
			floorY = 9.2,
			skip = skipDoorsAndBlockers,
		})
		local reach = Harness.flood(office, Vector3.new(16, 9.2, 17), 1.5)
		for _, id in { "G2", "D2", "S11", "OS1", "OS2" } do
			local a
			for _, x in tagged(Tags.LootAnchor) do
				if attr(x, Tags.AnchorId) == id then
					a = x
				end
			end
			t.ok(reach.at(pointOf(a), 3.5), "office: " .. id)
		end
		t.ok(reach.at(heist.Points.Rides.CheeseChute[1], 1.5), "office: chute station")
		local cellar = Harness.rasterize(level, {
			minX = -23,
			maxX = 28,
			minZ = -47,
			maxZ = -19,
			floorY = -9.8,
			skip = skipDoorsAndBlockers,
		})
		local creach = Harness.flood(cellar, Vector3.new(-3, -9.8, -43), 1.25)
		for _, id in { "G3", "M11", "M12", "S12", "X1" } do
			local a
			for _, x in tagged(Tags.LootAnchor) do
				if attr(x, Tags.AnchorId) == id then
					a = x
				end
			end
			t.ok(creach.at(pointOf(a), 5), "cellar: " .. id)
		end
		local agents = Harness.flood(cellar, Vector3.new(-3, -9.8, -43), 2.25)
		t.ok(agents.at(Vector3.new(6, -9.8, -43), 1), "cellar: agents out through the door into the trench")
		t.ok(agents.at(Vector3.new(-16, -9.8, -37), 1.5), "cellar: agents reach the Gouda spot G3")
		t.ok(agents.at(Vector3.new(-15, -9.8, -24), 1.5), "cellar: agents reach the north end")
	end)

	t.test("retrofit: no gadget pedestals, no Goal part, no labels on loot", function()
		t.eq(#tagged(Tags.GadgetPedestal), 0, "GadgetPedestal")
		t.eq(#tagged(Tags.Goal), 0, "Goal")
		local labels = 0
		for _, d in level:GetDescendants() do
			if d:IsA("BillboardGui") then
				labels += 1
			end
		end
		t.ok(labels <= 1, `{labels} billboard labels (only THE VAN)`)
	end)

	t.test("deterministic: a second build is identical", function()
		local again = Harness.buildHeist("GoldenWheel")
		local function fingerprint(root)
			local parts, sum = 0, Vector3.zero
			local colors = 0
			for _, d in root:GetDescendants() do
				if d:IsA("BasePart") then
					parts += 1
					sum += d.CFrame.Position
					colors += d.Color.R + d.Color.G * 2 + d.Color.B * 3
				end
			end
			return parts, sum, colors
		end
		local p1, s1, c1 = fingerprint(level)
		local p2, s2, c2 = fingerprint(again.level)
		t.eq(p2, p1, "part count")
		t.ok((s2 - s1).Magnitude < 1e-3, "positions")
		t.near(c2, c1, 1e-3, "colours")
	end)
end
