-- datamodel: Server
-- play: yes
-- goal: the pathfinder (agent radius 2) reaches the key places from the spawn, depending on which doors are open
-- Run it twice: with all doors closed (before 70_doors) and with all doors open (after 70_doors).
-- Expected: shop always; courtyard/hall/office/security only through an open door; cage only if CageDoor is open too.

return T.run("40 pathfinding reachability", "Server", function()
	local AGENT = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = false }

	local open = {}
	local states = {}
	for _, name in T.Doors do
		local door = T.door(name)
		open[name] = T.isOpen(door)
		table.insert(
			states,
			name .. "=" .. (if door == nil then "missing" elseif open[name] then "open" else "closed")
		)
	end
	T.info(
		"doors: "
			.. table.concat(states, ", ")
			.. string.format(" | agent radius %d, height %d", AGENT.AgentRadius, AGENT.AgentHeight)
	)

	local inside = open.StaffDoor or open.DeliveryGate -- hall reachable through the shop or the courtyard
	local expect = {
		Shop = true,
		Courtyard = open.DeliveryGate or open.StaffDoor, -- through the gate, or through the hall + back door
		Hall = inside,
		Office = inside,
		Security = inside,
		Cage = inside and open.CageDoor,
	}
	local labels = {
		Shop = "shop",
		Courtyard = "courtyard",
		Hall = "hall",
		Office = "office (mezzanine)",
		Security = "security room",
		Cage = "cage",
	}

	local startFloor = T.floorAt(T.P.Spawn + Vector3.new(0, 3, 0))
	if
		not T.step(
			"start point on the floor at the spawn",
			startFloor ~= nil,
			startFloor and T.v3(startFloor)
		)
	then
		return
	end
	local start = (startFloor :: Vector3) + Vector3.new(0, 2.5, 0)

	for _, key in { "Shop", "Courtyard", "Hall", "Office", "Security", "Cage" } do
		local floor, floorPart = T.floorAt(T.P[key])
		if not floor then
			T.step(labels[key] .. ": target point on the floor", false, "no floor below " .. T.v3(T.P[key]))
			continue
		end
		local goal = floor + Vector3.new(0, 2.5, 0)
		local path = T.PFS:CreatePath(AGENT)
		local okCompute, err = pcall(function()
			path:ComputeAsync(start, goal)
		end)
		local reached = false
		local detail
		if not okCompute then
			detail = "ComputeAsync failed: " .. tostring(err)
		else
			local waypoints = path:GetWaypoints()
			local last = waypoints[#waypoints]
			local endDistance = if last then (last.Position - goal).Magnitude else math.huge
			reached = path.Status == Enum.PathStatus.Success and endDistance < 4
			local length = 0
			for i = 2, #waypoints do
				length += (waypoints[i].Position - waypoints[i - 1].Position).Magnitude
			end
			detail = string.format(
				"%s, %d waypoints, %.0f studs long, ends %.1f studs from target (floor: %s)",
				path.Status.Name,
				#waypoints,
				length,
				if endDistance == math.huge then -1 else endDistance,
				floorPart and floorPart.Name or "?"
			)
		end
		local want = expect[key] and true or false
		if want and not reached then
			-- Diagnosis: is a narrow opening the problem? Try a slimmer agent (radius 1.5).
			local slim = T.PFS:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true })
			local okSlim = pcall(function()
				slim:ComputeAsync(start, goal)
			end)
			local slimOk = okSlim and slim.Status == Enum.PathStatus.Success
			detail ..= if slimOk
				then " | WITH radius 1.5 it IS reachable: an opening on the route is too narrow for radius 2"
				else " | also not reachable with radius 1.5"
		end
		local verdict = if want then "reachable" else "NOT reachable (door closed)"
		T.step(`{labels[key]}: {verdict}`, reached == want, detail)
		task.wait()
	end
end)
