-- datamodel: Client
-- play: yes
-- goal: take and return gadgets, charges, pedestal feedback and the slot limit (solo 3)

return T.run("30 take/return gadgets", "Client", function()
	T.listen()
	local player = T.player()
	T.step("start empty-handed", T.dropAll(), player:GetAttribute("Gadgets"))

	local function pedestalOf(name: string): BasePart?
		for _, pedestal in T.tagged("GadgetPedestal") do
			if pedestal:GetAttribute("Gadget") == name and pedestal:IsA("BasePart") then
				return pedestal
			end
		end
		return nil
	end

	-- Take: attribute, charges, pedestal half transparent, toast.
	local t0 = os.clock()
	T.step("take the Drone", T.take("Drone"), player:GetAttribute("Gadgets"))
	T.step(
		"Charges_Drone = 1",
		player:GetAttribute("Charges_Drone") == 1,
		tostring(player:GetAttribute("Charges_Drone"))
	)
	local pedestal = pedestalOf("Drone")
	T.step("pedestal shows 'taken' (Transparency 0.75)", T.waitFor(function()
		return pedestal and math.abs(pedestal.Transparency - 0.75) < 0.01
	end, 2) ~= nil, pedestal and pedestal.Transparency)
	T.step("toast 'Took the DRONE (EYES)'", T.waitMessage("Toast", 2, t0, function(text)
		return string.find(text, "Took the DRONE", 1, true) ~= nil
	end) ~= nil, T.toasts(t0))

	-- Return with the same prompt.
	local t1 = os.clock()
	T.step("return the Drone", T.drop("Drone"), player:GetAttribute("Gadgets"))
	T.step("pedestal free again (Transparency 0)", T.waitFor(function()
		return pedestal and pedestal.Transparency == 0
	end, 2) ~= nil)
	T.step(
		"Charges_Drone cleared after returning",
		player:GetAttribute("Charges_Drone") == nil,
		tostring(player:GetAttribute("Charges_Drone"))
	)
	T.step("toast 'Returned the DRONE'", T.waitMessage("Toast", 2, t1, function(text)
		return string.find(text, "Returned the DRONE", 1, true) ~= nil
	end) ~= nil, T.toasts(t1))

	-- Charges per gadget (Config.Gadgets.*.Charges; Crowbar = infinite → -1).
	local expected = { Noisemaker = 3, EMP = 2, BubbleBlaster = 3, Crowbar = -1 }
	for _, name in { "Noisemaker", "EMP", "BubbleBlaster" } do
		T.take(name)
		T.step(
			`{name}: Charges_{name} = {expected[name]}`,
			player:GetAttribute("Charges_" .. name) == expected[name],
			tostring(player:GetAttribute("Charges_" .. name))
		)
	end

	-- Slot limit: solo has 3 slots, a fourth gadget is refused.
	T.step("3 gadgets at once", #T.gadgets() == 3, player:GetAttribute("Gadgets"))
	local t2 = os.clock()
	T.request("DevTake", "Crowbar")
	local refused = T.waitMessage("Toast", 2, t2, function(text)
		return string.find(text, "slots full", 1, true) ~= nil
	end)
	T.step("4th gadget refused with a toast", refused ~= nil and not T.has("Crowbar"), T.toasts(t2))

	-- After returning one gadget the Crowbar fits.
	T.drop("BubbleBlaster")
	T.step("take the Crowbar after freeing a slot", T.take("Crowbar"), player:GetAttribute("Gadgets"))
	T.step(
		"Charges_Crowbar = -1 (infinite)",
		player:GetAttribute("Charges_Crowbar") == -1,
		tostring(player:GetAttribute("Charges_Crowbar"))
	)

	-- Unknown name: nothing may happen.
	local before = player:GetAttribute("Gadgets")
	T.request("DevTake", "Jetpack")
	task.wait(0.4)
	T.step(
		"unknown gadget is ignored",
		player:GetAttribute("Gadgets") == before,
		player:GetAttribute("Gadgets")
	)

	T.step("everything returned", T.dropAll(), player:GetAttribute("Gadgets"))
	local free = 0
	for _, p in T.tagged("GadgetPedestal") do
		if p:IsA("BasePart") and p.Transparency == 0 then
			free += 1
		end
	end
	T.step("all 5 pedestals free again", free == 5, `{free}/5`)
end)
