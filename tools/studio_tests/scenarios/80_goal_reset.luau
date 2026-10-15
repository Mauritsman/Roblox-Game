-- datamodel: Client
-- play: yes
-- goal: touching the Golden Gouda → RunEnded SUCCESS, and after 7 s a completely new level and a new character at the van
-- Takes ~12 s. Also cleans up the test state right away (open doors, gadgets, alarm).

return T.run("80 Golden Gouda → run ends and level is rebuilt", "Client", function()
	T.listen()
	local goal = T.tagged("Goal")[1]
	if
		not T.step(
			"Goal block (tag Goal) exists",
			goal ~= nil and goal:IsA("BasePart"),
			goal and goal:GetFullName()
		)
	then
		return
	end
	local goalPart = goal :: BasePart
	-- Make something "dirty", so we can see that the reset puts everything back.
	T.take("Crowbar")
	local oldLevel = T.level()
	local oldCharacter = T.character(10) :: Model
	local oldGuard = T.guard()

	-- Stand next to the goal block inside the cage and walk into it (Touched).
	local t0 = os.clock()
	local beside = goalPart.Position + Vector3.new(-3.5, 0, 0)
	T.teleport(Vector3.new(beside.X, goalPart.Position.Y, beside.Z), goalPart.Position)
	local humanoid = oldCharacter:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid:MoveTo(goalPart.Position)
	local ended = T.waitMessage("RunEnded", 5, t0)
	T.step(
		"RunEnded with SUCCESS",
		ended ~= nil and ended.args[1] == "SUCCESS",
		ended
				and string.format(
					"%s, %s s, '%s'",
					tostring(ended.args[1]),
					tostring(ended.args[2]),
					tostring(ended.args[3])
				)
			or "no RunEnded within 5 s"
	)
	if not ended then
		return
	end

	-- After 7 s: RoundService:Reset() → new level, alarm 0, gadgets cleared, everyone respawns.
	local started = T.waitMessage("RunStarted", 12, t0)
	T.step(
		"RunStarted received",
		started ~= nil,
		started
			and string.format(
				"%s, window %s s, %.1f s after RunEnded",
				tostring(started.args[1]),
				tostring(started.args[2]),
				started.t - ended.t
			)
	)
	local newLevel = T.waitFor(function()
		local level = T.level()
		return level ~= nil and level ~= oldLevel and level
	end, 5)
	T.step(
		"workspace.Level is a new instance, the old one is gone",
		newLevel ~= nil and (oldLevel == nil or oldLevel.Parent == nil)
	)

	local doorsClosed = T.waitFor(function()
		for _, name in T.Doors do
			local door = T.door(name)
			if
				not door
				or not door.CanCollide
				or not T.CS:HasTag(door, "Pryable")
				or not door:FindFirstChild("PryPrompt")
			then
				return false
			end
		end
		return true
	end, 5)
	T.step("3 doors closed again, Pryable and with a prompt", doorsClosed ~= nil)
	T.step("gadgets reset (empty)", T.waitFor(function()
		return #T.gadgets() == 0
	end, 3) ~= nil, T.player():GetAttribute("Gadgets"))
	T.step("alarm back at 0", T.waitFor(function()
		return T.alarmLevel() == 0
	end, 3) ~= nil, tostring(T.alarmLevel()))

	local newCharacter = T.waitFor(function()
		local character = T.player().Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return character ~= oldCharacter and root and character
	end, 8, 0.05)
	local root = newCharacter and newCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	T.step("new character", newCharacter ~= nil)
	T.step(
		"new character stands at the van",
		root ~= nil and T.flat(root.Position, T.P.Spawn) <= 6,
		root and string.format("%.1f studs from the spawn", T.flat(root.Position, T.P.Spawn)) or nil
	)
	local guard = T.waitFor(function()
		local g = T.guard()
		return g ~= oldGuard and g
	end, 3)
	T.step(
		"new guard in Patrol",
		guard ~= nil and T.guardState(guard) == "Patrol",
		guard and T.guardState(guard)
	)
	T.step("5 pedestals back", #T.tagged("GadgetPedestal") == 5)
	T.step("Goal present again", #T.tagged("Goal") == 1)
end)
