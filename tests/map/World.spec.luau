--!nocheck
-- MapService world support (beta-spec-maps §1): Garage, mini-job slots, heists at the origin, Terrain by bounds.
-- Runs MapService in the mock engine (tests/map/MockRoblox), so no Studio is needed.
local roblox = require("@lune/roblox")
local Mock = require("./MockRoblox")

local Vector3 = roblox.Vector3

local function newWorld(opts)
	local world = Mock.world(opts)
	local MapService = world.require(world.server.Services.MapService)
	local Registry = world.require(world.server.Map.Registry)
	return world, MapService, Registry
end

-- A tiny stand-in heist (its build only places a floor and a SpawnLocation).
local function stubHeist(id, bounds)
	return {
		Id = id,
		DisplayName = id,
		Seed = 1,
		Atmosphere = {},
		Points = {
			Spawn = Vector3.new(0, 3, 0),
			GuardStart = Vector3.new(0, 3, 0),
			GuardRoute = { Vector3.new(0, 0, 0) },
		},
		Bounds = bounds,
		Build = function(level)
			local floor = Mock.new("Part")
			floor.Name = "Floor"
			floor.Parent = level
			local spawn = Mock.new("SpawnLocation")
			spawn.Name = "HeistSpawn"
			spawn.Parent = level
		end,
	}
end

local function terrainCalls(world, kind)
	local out = {}
	for _, entry in world.log do
		if entry.kind == kind then
			table.insert(out, entry)
		end
	end
	return out
end

return function(t)
	t.test("World: Init builds the Garage and the default heist", function()
		local world, MapService = newWorld()
		MapService:Init()
		local garage = world.workspace:FindFirstChild("Garage")
		t.ok(garage, "workspace.Garage")
		t.eq(garage:GetAttribute("Area"), "Garage")
		t.eq(MapService.Garage, garage)
		t.ok(world.workspace:FindFirstChild("Level"), "workspace.Level")
		t.eq(MapService.CurrentHeist.Id, "GoldenWheel")
		t.eq(#terrainCalls(world, "Clear"), 0, "never Terrain:Clear()")
		-- BuildGarage is idempotent.
		t.eq(MapService:BuildGarage(), garage)
		local count = 0
		for _, child in world.workspace:GetChildren() do
			if child.Name == "Garage" then
				count += 1
			end
		end
		t.eq(count, 1, "one Garage")
	end)

	t.test("World: Garage points are in world space at Config.World.GarageOrigin", function()
		local world, MapService = newWorld()
		MapService:BuildGarage()
		local Config = world.require(world.shared.Config)
		local o = Config.World.GarageOrigin
		local origin = Vector3.new(o.X, o.Y, o.Z)
		t.near(
			(MapService.GaragePoints.Spawn - (origin + MapService.GarageDef.Points.Spawn)).Magnitude,
			0,
			1e-6
		)
		t.eq(#MapService.GaragePoints.Arrivals, 4)
		t.ok((MapService.GaragePoints.JobBoard - origin).Magnitude < 100, "job board near the origin")
	end)

	t.test("World: switching heists clears only the previous heist's Bounds", function()
		local world, MapService, Registry = newWorld()
		Registry.Heists.TestA =
			stubHeist("TestA", { Min = Vector3.new(-10, -5, -20), Max = Vector3.new(10, 5, 20) })
		Registry.Heists.TestB = stubHeist("TestB", nil)
		MapService:Build("TestA")
		MapService:Build("TestA") -- same heist again: nothing cleared
		t.eq(#terrainCalls(world, "FillBlock"), 0)
		MapService:Build("TestB")
		local fills = terrainCalls(world, "FillBlock")
		t.eq(#fills, 1)
		t.eq(fills[1].material, roblox.Enum.Material.Air)
		t.near((fills[1].size - Vector3.new(20, 10, 40)).Magnitude, 0, 1e-6)
		t.near(fills[1].cframe.Position.Magnitude, 0, 1e-6)
		-- TestB has no Bounds: the Config default box.
		MapService:Build("TestA")
		fills = terrainCalls(world, "FillBlock")
		t.eq(#fills, 2)
		t.near((fills[2].size - Vector3.new(400, 120, 400)).Magnitude, 0, 1e-6)
		t.eq(#terrainCalls(world, "Clear"), 0)
		t.eq(MapService.CurrentHeist.Id, "TestA")
		t.eq(world.workspace.Level:GetAttribute("HeistId"), "TestA")
	end)

	t.test("World: the Garage spawn is the only enabled SpawnLocation", function()
		local world, MapService, Registry = newWorld()
		Registry.Heists.TestA = stubHeist("TestA", nil)
		MapService:BuildGarage()
		MapService:Build("TestA")
		local enabled = {}
		for _, d in world.workspace:GetDescendants() do
			if d:IsA("SpawnLocation") and d.Enabled then
				table.insert(enabled, d)
			end
		end
		t.eq(#enabled, 1)
		t.ok(enabled[1]:IsDescendantOf(world.workspace.Garage), "it is the Garage's")
	end)

	t.test("World: mini-job slots build at their origins and are destroyed again", function()
		local world, MapService = newWorld()
		local Config = world.require(world.shared.Config)
		t.eq(MapService:MiniJobSlotCount(), #Config.World.MiniJobOrigins)
		local f1, p1 = MapService:BuildMiniJob(1)
		local f2, p2 = MapService:BuildMiniJob(2)
		t.eq(f1.Name, "MiniJob_1")
		t.eq(f2.Name, "MiniJob_2")
		t.eq(f1:GetAttribute("Session"), "Tutorial1")
		t.eq(MapService:MiniJobSession(2), "Tutorial2")
		for slot, points in { p1, p2 } do
			local o = Config.World.MiniJobOrigins[slot]
			local expected = Vector3.new(o.X, o.Y, o.Z) + MapService.MiniJobDef.Points.Spawn
			t.near((points.Spawn - expected).Magnitude, 0, 1e-6, "slot " .. slot .. " spawn")
		end
		t.eq(MapService:GetMiniJob(1).Folder, f1)
		-- Rebuilding a slot replaces it.
		local again = MapService:BuildMiniJob(1)
		t.ok(f1.Parent == nil, "old slot 1 destroyed")
		t.eq(again.Parent, world.workspace)
		MapService:DestroyMiniJob(1)
		t.ok(world.workspace:FindFirstChild("MiniJob_1") == nil, "slot 1 gone")
		t.ok(MapService:GetMiniJob(1) == nil, "record gone")
		t.ok(world.workspace:FindFirstChild("MiniJob_2"), "slot 2 untouched")
		MapService:DestroyMiniJob(1) -- no-op
		t.ok(not pcall(function()
			MapService:BuildMiniJob(#Config.World.MiniJobOrigins + 1)
		end), "unknown slot errors")
	end)
end
