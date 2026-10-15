-- datamodel: Client
-- play: yes
-- goal: 5 gadget pedestals at the van, each with a working Take/Return prompt

return T.run("20 gadget pedestals with prompt", "Client", function()
	local pedestals = T.tagged("GadgetPedestal")
	T.step("exactly 5 pedestals (tag GadgetPedestal)", #pedestals == 5, `{#pedestals} found`)

	local seen = {}
	for _, pedestal in pedestals do
		local gadget = pedestal:GetAttribute("Gadget")
		if typeof(gadget) == "string" then
			seen[gadget] = pedestal
		end
	end
	local missing = {}
	for _, name in T.Gadgets do
		if not seen[name] then
			table.insert(missing, name)
		end
	end
	T.step(
		"one pedestal per gadget (Config.GadgetOrder)",
		#missing == 0,
		if #missing > 0 then "missing: " .. table.concat(missing, ", ") else table.concat(T.Gadgets, ", ")
	)

	for _, name in T.Gadgets do
		local pedestal = seen[name]
		if pedestal and pedestal:IsA("BasePart") then
			local prompt = pedestal:FindFirstChild("TakePrompt")
			local okPrompt = prompt ~= nil
				and prompt:IsA("ProximityPrompt")
				and prompt.Enabled
				and prompt.ActionText == "Take / Return"
				and prompt.HoldDuration == 0
				and math.abs(prompt.MaxActivationDistance - 4.5) < 0.01
				and prompt.KeyboardKeyCode == Enum.KeyCode.E
				and prompt.GamepadKeyCode == Enum.KeyCode.ButtonX
				and prompt.RequiresLineOfSight == false
			local detail = if prompt and prompt:IsA("ProximityPrompt")
				then string.format(
					"ObjectText %s, range %.1f, hold %.1f",
					prompt.ObjectText,
					prompt.MaxActivationDistance,
					prompt.HoldDuration
				)
				else "TakePrompt missing"
			T.step(`{name}: TakePrompt correct`, okPrompt, detail)

			-- Reachable: the player stands on the quay in front of the crate (x -32.6), root part ~3 studs up.
			local stand = Vector3.new(-32.6, pedestal.Position.Y, pedestal.Position.Z)
			local floor = T.floorAt(stand + Vector3.new(0, 4, 0))
			local rootPos = if floor then floor + Vector3.new(0, 3, 0) else stand
			local reach = (rootPos - pedestal.Position).Magnitude
			T.step(
				`{name}: prompt within reach from the quay`,
				floor ~= nil and reach <= 4.5,
				string.format("pedestal at %s, distance %.1f studs", T.v3(pedestal.Position), reach)
			)
			T.step(
				`{name}: free and visible (Transparency 0)`,
				pedestal.Transparency == 0,
				pedestal.Transparency
			)
		end
	end

	-- All of them at the van / gadget rack.
	local far = {}
	for _, pedestal in pedestals do
		if pedestal:IsA("BasePart") and T.flat(pedestal.Position, T.P.Van) > 25 then
			table.insert(far, pedestal.Name)
		end
	end
	T.step(
		"pedestals are at the van (≤ 25 studs)",
		#far == 0,
		if #far > 0 then table.concat(far, ", ") else nil
	)
end)
