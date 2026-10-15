-- datamodel: Client
-- play: yes
-- goal: the guard sees a player standing in front of him (Alert), catches him and the player goes back to the van
-- Alert → capture takes only ~0.3 s, so states are recorded through attribute signals instead of polling.

return T.run("50 guard detects and catches", "Client", function()
	T.listen()
	local guard = T.guard()
	if
		not T.step("guard found", guard ~= nil and T.guardRoot(guard) ~= nil, guard and T.guardState(guard))
	then
		return
	end
	local g = guard :: Model
	local character = T.character(10) :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	T.step("player is not caught at the start", character:GetAttribute("Caught") == nil)

	-- Record every change: guard state, Caught and WalkSpeed.
	local states = { tostring(T.guardState(g)) }
	local caughtSeen, speeds = false, {}
	table.insert(
		T.conns,
		g:GetAttributeChangedSignal("GuardState"):Connect(function()
			table.insert(states, tostring(g:GetAttribute("GuardState")))
		end)
	)
	table.insert(
		T.conns,
		character:GetAttributeChangedSignal("Caught"):Connect(function()
			if character:GetAttribute("Caught") == true then
				caughtSeen = true
			end
		end)
	)
	table.insert(
		T.conns,
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			table.insert(speeds, humanoid.WalkSpeed)
		end)
	)

	-- Put the player 7 studs in front of the guard (facing him) until he reacts; then stand still.
	local t0 = os.clock()
	local placedAt: Vector3? = nil
	local reacted, seconds = T.waitFor(function()
		if table.find(states, "Alert") or caughtSeen or T.waitMessage("GuardAlert", 0, t0) then
			return true
		end
		local groot = T.guardRoot(g) :: BasePart
		local look = groot.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			flat = Vector3.new(1, 0, 0)
		end
		local spot = groot.Position + flat.Unit * 7
		placedAt = spot
		T.teleport(Vector3.new(spot.X, groot.Position.Y, spot.Z), groot.Position)
		return false
	end, 10, 0.05)
	local alertMessage = T.waitMessage("GuardAlert", 1, t0)
	T.step(
		"guard detects the player (GuardAlert message or Alert state)",
		reacted ~= nil and (alertMessage ~= nil or table.find(states, "Alert") ~= nil),
		string.format(
			"%s, player at %s",
			if seconds then string.format("after %.1f s", seconds) else "no reaction in 10 s",
			placedAt and T.v3(placedAt) or "?"
		)
	)
	T.step("GuardAlert message received", T.waitMessage("GuardAlert", 1, t0) ~= nil)

	-- The player stands still: the guard walks up and catches him.
	local caught = T.waitFor(function()
		return caughtSeen or T.waitMessage("Caught", 0, t0) ~= nil
	end, 6, 0.05)
	T.step("guard catches the player (Caught)", caught ~= nil, "states: " .. table.concat(states, " → "))
	-- The "!" moment must reach the client: if Alert and the capture happen in the same server frame, the
	-- client only sees Suspicious → Search and the player gets caught without warning (bug B-003).
	T.step(
		"Alert state visible to the client before the capture",
		table.find(states, "Alert") ~= nil,
		"states seen by the client: " .. table.concat(states, " → ")
	)
	T.step(
		"WalkSpeed 0 while caught",
		table.find(speeds, 0) ~= nil,
		"WalkSpeed values: " .. table.concat(speeds, ",")
	)

	-- After 1.2 s back to the van at normal speed.
	local back, backSeconds = T.waitFor(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root and character:GetAttribute("Caught") == nil and T.flat(root.Position, T.P.Spawn) <= 6
	end, 5)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	T.step(
		"sent back to the van",
		back ~= nil,
		root
				and string.format(
					"%.1f studs from the spawn%s",
					T.flat(root.Position, T.P.Spawn),
					if backSeconds then string.format(", after %.1f s", backSeconds) else ""
				)
			or "no root part"
	)
	T.step(
		"Caught cleared and WalkSpeed 16",
		character:GetAttribute("Caught") == nil and humanoid.WalkSpeed == 16,
		humanoid.WalkSpeed
	)
	T.step("same character (no respawn needed)", T.player().Character == character)
	T.step("guard lets go (no longer Alert)", T.waitFor(function()
		return T.guardState(g) ~= "Alert"
	end, 3) ~= nil, T.guardState(g))
	local captures = 0
	for _, message in T.messages do
		if message.name == "Caught" then
			captures += 1
		end
	end
	T.step("caught exactly once", captures == 1, `{captures} Caught message(s)`)
	T.info("alarm level now: " .. tostring(T.alarmLevel()))
end)
