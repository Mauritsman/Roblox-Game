-- datamodel: Client
-- play: yes
-- goal: a real EMP throw turns off the lamps in its radius, and after the window their own colour and material return
-- Takes ~16 s (solo window = 12 s). Target: the bluish SecurityLamp, so a wrong restore colour stands out.

return T.run("60 EMP turns lamps off and restores their colour", "Client", function()
	T.listen()
	local player = T.player()
	T.dropAll()
	if not T.step("take the EMP", T.take("EMP"), player:GetAttribute("Gadgets")) then
		return
	end
	local chargesBefore = player:GetAttribute("Charges_EMP")

	local targetLamp = T.find("SecurityLamp")
	if not T.step("SecurityLamp found", targetLamp ~= nil and targetLamp:IsA("BasePart")) then
		return
	end
	local lampPart = targetLamp :: BasePart
	local target = Vector3.new(lampPart.Position.X, 0.5, lampPart.Position.Z)

	-- Same rule as GadgetService: horizontal ≤ 14 studs (Config.Gadgets.EMP.Radius) and height difference ≤ 16.
	local affected = {}
	for _, lamp in T.tagged("Lamp") do
		if lamp:IsA("BasePart") then
			local d = lamp.Position - target
			if Vector3.new(d.X, 0, d.Z).Magnitude <= 14 and math.abs(d.Y) <= 16 then
				local light = lamp:FindFirstChildOfClass("PointLight")
				table.insert(affected, {
					part = lamp,
					color = lamp.Color,
					material = lamp.Material,
					light = light,
					lightOn = light and light.Enabled,
				})
			end
		end
	end
	local names = {}
	for _, a in affected do
		table.insert(names, a.part.Name .. "(" .. T.rgb(a.color) .. ", " .. a.material.Name .. ")")
	end
	T.step("lamps inside the EMP radius", #affected > 0, table.concat(names, "; "))

	-- Throw from the quay (within the 40-stud throw range).
	T.teleport(Vector3.new(-30, 3, -6), target)
	local t0 = os.clock()
	T.request("Throw", "EMP", target)
	local landed = T.waitMessage("EMP", 4, t0)
	T.step(
		"EMP lands (EMP message)",
		landed ~= nil,
		landed
				and string.format(
					"hitCameras=%s hitLamps=%s",
					tostring(landed.args[3]),
					tostring(landed.args[4])
				)
			or T.toasts(t0)
	)
	T.step("window 'LIGHTS OFF' started", T.waitMessage("Window", 1, t0, function(kind)
		return kind == "LIGHTS OFF"
	end) ~= nil)
	T.step("charge used (2 → 1)", T.waitFor(function()
		return player:GetAttribute("Charges_EMP") == (chargesBefore or 0) - 1
	end, 2) ~= nil, tostring(chargesBefore) .. " → " .. tostring(player:GetAttribute("Charges_EMP")))

	local off = T.waitFor(function()
		for _, a in affected do
			local p = a.part
			if
				p:GetAttribute("Disabled") ~= true
				or (a.light and a.light.Enabled)
				or not T.sameColor(p.Color, Color3.fromRGB(50, 50, 50))
			then
				return false
			end
		end
		return true
	end, 2)
	local offDetail = {}
	for _, a in affected do
		table.insert(
			offDetail,
			string.format(
				"%s:%s/%s",
				a.part.Name,
				tostring(a.part:GetAttribute("Disabled")),
				T.rgb(a.part.Color)
			)
		)
	end
	T.step(
		"all lamps in the radius off (Disabled, light off, grey)",
		off ~= nil,
		table.concat(offDetail, "; ")
	)

	-- Second throw straight away: cooldown (30 s).
	local t1 = os.clock()
	T.request("Throw", "EMP", target)
	T.step("second throw refused (EMP recharging)", T.waitMessage("Toast", 2, t1, function(text)
		return string.find(text, "recharging", 1, true) ~= nil
	end) ~= nil, T.toasts(t1))

	-- After the window they come back on.
	local back, seconds = T.waitFor(function()
		for _, a in affected do
			if a.part:GetAttribute("Disabled") ~= false then
				return false
			end
		end
		return true
	end, T.WindowSolo + 5, 0.25)
	T.step(
		"lamps back on after the window",
		back ~= nil,
		if seconds then string.format("after %.1f s more (window %d s)", seconds, T.WindowSolo) else nil
	)

	local wrong = {}
	for _, a in affected do
		local p = a.part
		local lightOk = a.light == nil or a.light.Enabled == a.lightOn
		if not T.sameColor(p.Color, a.color) or p.Material ~= a.material or not lightOk then
			table.insert(
				wrong,
				string.format(
					"%s: colour %s (was %s), %s (was %s), light %s",
					p.Name,
					T.rgb(p.Color),
					T.rgb(a.color),
					p.Material.Name,
					a.material.Name,
					tostring(a.light and a.light.Enabled)
				)
			)
		end
	end
	T.step(
		"original colour, material and light restored",
		#wrong == 0,
		if #wrong > 0 then table.concat(wrong, "; ") else `{#affected} lamp(s) correct`
	)
	T.drop("EMP")
end)
