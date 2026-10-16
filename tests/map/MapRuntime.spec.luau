--!nocheck
-- Map runtime contract (mechanics D, src/server/MapRuntime/README.md), checked on every heist built in Lune
-- (tests/map/MapHarness): rides have a usable path, stations on it and seat-able cars; spinners, rhythm machines,
-- lockdown switches, zones, cell doors and exits carry what MapRuntimeService reads.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Harness = require("./MapHarness")
local RidePath = require("../../src/shared/Logic/RidePath")

local Vector3 = roblox.Vector3

local ACTIONS = { Close = true, Open = true, Speed = true, On = true, Off = true }

local function vecs(list)
	local out = {}
	for _, p in list do
		table.insert(out, { x = p.X, y = p.Y, z = p.Z })
	end
	return out
end

local function isCarName(name)
	return string.match(name, "^Car%d*$") ~= nil
end

local function heistIds()
	local ids = {}
	for _, name in fs.readDir("src/server/Map/Heists") do
		if fs.isDir("src/server/Map/Heists/" .. name) then
			table.insert(ids, name)
		end
	end
	table.sort(ids)
	return ids
end

return function(t)
	for _, heistId in heistIds() do
		local ok, world = pcall(Harness.buildHeist, heistId)
		if not ok then
			continue -- the map's own spec reports build errors
		end
		local level, heist, Tags, Config = world.level, world.heist, world.Tags, world.Config
		local prefix = `[{heistId}] `
		local function tagged(tag)
			return Harness.tagged(level, tag)
		end

		t.test(prefix .. "rides: path, stations on it, cars with seats", function()
			local rides = (heist.Points and heist.Points.Rides) or {}
			for _, folder in tagged(Tags.Ride) do
				local id = folder:GetAttribute(Tags.RideId)
				t.ok(type(id) == "string", "RideId on " .. folder.Name)
				local points = rides[id]
				t.ok(type(points) == "table" and #points >= 2, `Points.Rides["{id}"]`)
				local path = RidePath.build(vecs(points), folder:GetAttribute(Tags.Loop))
				t.ok(path.length > 0, id .. " path length")
				t.ok((folder:GetAttribute(Tags.Seats) or 1) >= 1, id .. " Seats")
				local stations = 0
				for _, d in folder:GetDescendants() do
					if d.Name == "Station" and d:IsA("Attachment") then
						stations += 1
						local w = Harness.attachmentWorld(d)
						local _, distance = RidePath.project(path, { x = w.X, y = w.Y, z = w.Z })
						t.ok(distance <= 3, `{id}: a Station is {distance} studs off the path`)
					end
				end
				t.ok(stations >= 1, id .. " has a Station")
				local cars = 0
				for _, d in folder:GetDescendants() do
					if isCarName(d.Name) and d:IsA("Model") then
						cars += 1
						t.ok(d.PrimaryPart ~= nil, id .. " car PrimaryPart")
						local seat = false
						for _, part in d:GetDescendants() do
							if part:IsA("Seat") or (part:IsA("BasePart") and part.Name == "Seat") then
								seat = true
							end
						end
						t.ok(seat, id .. " car has a Seat")
					end
				end
				t.ok(cars >= 1 or folder:GetAttribute(Tags.Cars) ~= nil, id .. " has cars (or Cars)")
				if not path.loop then
					t.ok(cars <= 1, id .. ": a shuttle uses one car")
				end
				for _, name in { Tags.LootDelay, Tags.ExitNoise, Tags.Speed, Tags.LockdownSpeed } do
					local value = folder:GetAttribute(name)
					t.ok(value == nil or (type(value) == "number" and value >= 0), `{id} {name} is a number`)
				end
			end
		end)

		t.test(prefix .. "spinners, machines, switches", function()
			for _, inst in tagged(Tags.Spinner) do
				local seconds = inst:GetAttribute(Tags.SpinSeconds)
				t.ok(
					seconds == nil or (type(seconds) == "number" and seconds > 0),
					inst.Name .. " SpinSeconds"
				)
				local axis = inst:GetAttribute(Tags.SpinAxis)
				t.ok(axis == nil or typeof(axis) == "Vector3", inst.Name .. " SpinAxis")
				t.ok(
					inst:IsA("BasePart") or (inst:IsA("Model") and inst.PrimaryPart ~= nil),
					inst.Name .. " pivot"
				)
			end
			for _, inst in tagged(Tags.RhythmMachine) do
				local kind = inst:GetAttribute(Tags.Kind)
				t.ok(
					type(kind) == "string" and Config.MapRuntime.Rhythm[kind] ~= nil,
					inst.Name .. " Kind " .. tostring(kind)
				)
			end
			for _, inst in tagged(Tags.LockdownSwitch) do
				local action = inst:GetAttribute(Tags.Action)
				t.ok(action == nil or ACTIONS[action], inst.Name .. " Action " .. tostring(action))
				if action == "Close" and inst:GetAttribute(Tags.ClosedCFrame) ~= nil then
					t.ok(
						typeof(inst:GetAttribute(Tags.ClosedCFrame)) == "CFrame",
						inst.Name .. " ClosedCFrame"
					)
				end
			end
		end)

		t.test(prefix .. "zones have parts; cell doors and exits carry their attributes", function()
			for _, tag in { Tags.ColdZone, Tags.GooZone, Tags.StaffZone, Tags.SecureZone, Tags.LaserGrid } do
				for _, inst in tagged(tag) do
					local parts = inst:IsA("BasePart") and 1 or #Harness.ofClass(inst, "BasePart")
					t.ok(parts > 0, `{tag} {inst.Name} has parts`)
				end
			end
			for _, door in tagged(Tags.CellDoor) do
				local open = door:GetAttribute(Tags.OpenCFrame)
				t.ok(open == nil or typeof(open) == "CFrame", "CellDoor OpenCFrame")
			end
			for _, exit in tagged(Tags.Exit) do
				local arrives = exit:GetAttribute(Tags.ArrivesAt)
				t.ok(arrives == nil or type(arrives) == "number", exit.Name .. " ArrivesAt")
				if arrives ~= nil then
					t.ok(
						exit:IsA("Model") or exit:IsA("BasePart"),
						exit.Name .. ": an arriving exit is a Model"
					)
				end
				local offset = exit:GetAttribute(Tags.DepartOffset)
				t.ok(offset == nil or typeof(offset) == "Vector3", exit.Name .. " DepartOffset")
			end
			local _ = Vector3
		end)
	end
end
