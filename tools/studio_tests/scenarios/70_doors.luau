-- datamodel: Client
-- play: yes
-- goal: the 3 Pryable doors (StaffDoor, DeliveryGate, CageDoor) only open with the Crowbar
-- After this scenario all doors are open: run 40_pathfinding again (expected: everything reachable).

return T.run("70 open the Pryable doors", "Client", function()
	T.listen()
	local expectedHold = { StaffDoor = 1.5, DeliveryGate = 3, CageDoor = 3 } -- PrySeconds (Config.Gadgets.Crowbar)

	-- Without the Crowbar: nothing happens, but there is a toast.
	T.dropAll()
	local staff = T.door("StaffDoor")
	local t0 = os.clock()
	T.request("DevPry", "StaffDoor")
	local refused = T.waitMessage("Toast", 2, t0, function(text)
		return string.find(text, "Needs the CROWBAR", 1, true) ~= nil
	end)
	task.wait(0.3)
	T.step(
		"without the Crowbar StaffDoor stays closed (+ toast)",
		refused ~= nil and staff ~= nil and not T.isOpen(staff),
		T.toasts(t0)
	)

	if not T.step("take the Crowbar", T.take("Crowbar"), T.player():GetAttribute("Gadgets")) then
		return
	end

	for _, name in T.Doors do
		local door = T.door(name)
		if
			not T.step(
				`{name}: found, closed and Pryable`,
				door ~= nil and door.CanCollide and T.CS:HasTag(door, "Pryable"),
				door and door:GetFullName() or "missing"
			)
		then
			continue
		end
		local part = door :: BasePart
		local prompt = part:FindFirstChild("PryPrompt")
		local hold = if prompt and prompt:IsA("ProximityPrompt") then prompt.HoldDuration else nil
		T.step(
			`{name}: PryPrompt with hold {expectedHold[name]} s`,
			hold ~= nil and math.abs(hold - expectedHold[name]) < 0.01,
			hold
					and string.format(
						"hold %.1f s, range %.0f",
						hold,
						(prompt :: ProximityPrompt).MaxActivationDistance
					)
				or "PryPrompt missing"
		)

		local look = part.CFrame.LookVector
		local t1 = os.clock()
		local ok, detail = T.pry(name)
		T.step(`{name}: opens (CanCollide off, tag removed)`, ok, detail)
		task.wait(0.5) -- the swing animation takes 0.35 s
		local angle = math.deg(math.acos(math.clamp(look:Dot(part.CFrame.LookVector), -1, 1)))
		T.step(`{name}: swings open (~100°)`, angle > 80 and angle < 120, string.format("%.0f°", angle))
		T.step(`{name}: no longer hit by raycasts (CanQuery off)`, part.CanQuery == false)
		T.step(`{name}: CRACK message`, T.waitMessage("Crack", 1, t1) ~= nil)
		T.step(`{name}: prompt disappears`, T.waitFor(function()
			return part:FindFirstChild("PryPrompt") == nil
		end, 2.5) ~= nil)
	end

	-- Prying an open door again must not do anything (door already open, tag removed).
	local t2 = os.clock()
	T.request("DevPry", "CageDoor")
	task.wait(0.4)
	T.step("second DevPry on an open door does nothing", T.waitMessage("Crack", 0.2, t2) == nil)
	T.info("alarm level now: " .. tostring(T.alarmLevel()) .. " | guard: " .. tostring(T.guardState()))
	T.drop("Crowbar")
end)
