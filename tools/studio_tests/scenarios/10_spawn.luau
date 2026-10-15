-- datamodel: Client
-- play: yes
-- goal: the player spawns at the van with the right starting values
-- If the character is not at the spawn (someone walked away, or an earlier scenario moved it), this scenario
-- forces a fresh spawn with RestartRun (~8 s) and measures right after spawning.

return T.run("10 spawn at the van", "Client", function()
	local character = T.character(15)
	if not T.step("character loaded", character ~= nil) then
		return
	end
	local root = (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	if T.flat(root.Position, T.P.Spawn) > 6 then
		T.info(
			string.format(
				"character was at %s (not at the spawn): forcing a fresh spawn with RestartRun",
				T.v3(root.Position)
			)
		)
		character = T.respawn()
		if not T.step("fresh character after RestartRun", character ~= nil) then
			return
		end
		root = (character :: Model):WaitForChild("HumanoidRootPart", 5) :: BasePart
		task.wait(0.3) -- give RoundService time to set up the character
	end
	local char = character :: Model
	local humanoid = char:FindFirstChildOfClass("Humanoid") :: Humanoid
	local player = T.player()

	local distance = T.flat(root.Position, T.P.Spawn)
	T.step(
		"stands at the spawn (≤ 6 studs)",
		distance <= 6,
		string.format("%.1f studs from %s, at %s", distance, T.v3(T.P.Spawn), T.v3(root.Position))
	)

	local spawn = T.find("CrewSpawn")
	T.step(
		"CrewSpawn is a neutral SpawnLocation at the spawn point",
		spawn and spawn:IsA("SpawnLocation") and spawn.Neutral and T.flat(spawn.Position, T.P.Spawn) < 1,
		spawn and T.v3((spawn :: BasePart).Position) or "missing"
	)

	local van = T.find("Van")
	local vanPos = if van and van:IsA("Model")
		then van:GetPivot().Position
		elseif van and van:IsA("BasePart") then van.Position
		else nil
	T.step(
		"van is close to the spawn (≤ 20 studs)",
		vanPos ~= nil and T.flat(vanPos, T.P.Spawn) <= 20,
		vanPos and string.format("%s, %.1f studs", van.ClassName, T.flat(vanPos, T.P.Spawn)) or "Van missing"
	)

	-- Starting values set by RoundService/LoadoutService.
	T.step("WalkSpeed 16", humanoid.WalkSpeed == 16, humanoid.WalkSpeed)
	T.step("JumpHeight 7.2", math.abs(humanoid.JumpHeight - 7.2) < 0.01, humanoid.JumpHeight)
	T.step(
		"not caught / not crouching / not operating",
		char:GetAttribute("Caught") == nil
			and char:GetAttribute("Crouching") ~= true
			and char:GetAttribute("Operating") ~= true
	)
	T.step("solo: 3 gadget slots", player:GetAttribute("Slots") == 3, tostring(player:GetAttribute("Slots")))
	T.step("starts without gadgets", #T.gadgets() == 0, tostring(player:GetAttribute("Gadgets")))
	T.step("alarm at 0", (T.alarmLevel() or 0) == 0, tostring(T.alarmLevel()))

	-- The level and the guard exist.
	T.step("workspace.Level exists", T.level() ~= nil)
	local guard = T.guard()
	T.step(
		"1 guard in Patrol",
		#T.tagged("Guard") == 1 and T.guardState(guard) == "Patrol",
		`{#T.tagged("Guard")} guard(s), state {tostring(T.guardState(guard))}`
	)

	-- HUD (owned by ux): at least one ScreenGui of ours in PlayerGui.
	local guis = {}
	for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
		if gui:IsA("ScreenGui") then
			table.insert(guis, gui.Name)
		end
	end
	T.info("ScreenGuis: " .. table.concat(guis, ", "))
end)
