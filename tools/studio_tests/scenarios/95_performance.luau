-- datamodel: Server
-- play: yes
-- goal: performance baseline: parts and lights in the level, memory and server heartbeat (average over 5 s)
-- The numbers matter most (INFO lines). The PASS/FAIL limits are provisional budgets (see README).
-- Note: in Studio the server and the client run in the same process, so memory and frame time are measured together.

local BUDGET = {
	PartsInLevel = 6000, -- BaseParts in workspace.Level
	Lights = 60, -- PointLight/SpotLight/SurfaceLight in workspace
	ShadowLights = 12, -- lights with Shadows = true (expensive on mobile)
	HeartbeatAvgMs = 20, -- average server frame time (60 Hz = 16.7 ms)
	HeartbeatMaxMs = 100, -- longest frame in the measuring period
}

return T.run("95 performance baseline", "Server", function()
	local level = T.level()
	if not T.step("workspace.Level exists", level ~= nil) then
		return
	end

	local parts, meshParts, runtimeMeshes, unions, transparent = 0, 0, 0, 0, 0
	for _, d in (level :: Instance):GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.Transparency >= 0.98 then
				transparent += 1
			end
			if d:IsA("MeshPart") then
				meshParts += 1
				if string.find(d.MeshId, "rbxruntime://", 1, true) then
					runtimeMeshes += 1
				end
			elseif d:IsA("UnionOperation") then
				unions += 1
			end
		end
	end
	local lights, enabledLights, shadowLights = 0, 0, 0
	local byClass = { PointLight = 0, SpotLight = 0, SurfaceLight = 0 }
	for _, d in workspace:GetDescendants() do
		if d:IsA("Light") then
			lights += 1
			byClass[d.ClassName] = (byClass[d.ClassName] or 0) + 1
			if d.Enabled then
				enabledLights += 1
			end
			if d.Shadows then
				shadowLights += 1
			end
		end
	end
	local instances = #workspace:GetDescendants()

	T.info(
		string.format(
			"parts in Level: %d (%d MeshPart, %d Union, %d invisible)",
			parts,
			meshParts,
			unions,
			transparent
		)
	)
	T.info(
		string.format(
			"MeshParts with an rbxruntime:// mesh (AI props not yet saved as assets): %d",
			runtimeMeshes
		)
	)
	T.info(
		string.format(
			"lights in workspace: %d (%d on, %d with shadows) — Point %d, Spot %d, Surface %d",
			lights,
			enabledLights,
			shadowLights,
			byClass.PointLight,
			byClass.SpotLight,
			byClass.SurfaceLight
		)
	)
	T.info(string.format("instances in workspace: %d", instances))

	local memory = T.Stats:GetTotalMemoryUsageMb()
	local tags = {}
	for _, tagName in { "Script", "PhysicsParts", "GraphicsMeshParts", "GraphicsTexture", "Instances", "Gui" } do
		local ok, value = pcall(function()
			return T.Stats:GetMemoryUsageMbForTag((Enum.DeveloperMemoryTag :: any)[tagName])
		end)
		if ok then
			table.insert(tags, string.format("%s %.0f", tagName, value))
		end
	end
	T.info(string.format("total memory: %.0f MB (%s)", memory, table.concat(tags, ", ")))

	-- Server heartbeat: measure every frame time for 5 s.
	local samples = {}
	local connection = T.Run.Heartbeat:Connect(function(dt)
		table.insert(samples, dt)
	end)
	table.insert(T.conns, connection)
	task.wait(5)
	connection:Disconnect()
	table.sort(samples)
	local sum = 0
	for _, dt in samples do
		sum += dt
	end
	local avgMs = if #samples > 0 then sum / #samples * 1000 else math.huge
	local maxMs = if #samples > 0 then samples[#samples] * 1000 else math.huge
	local p95Ms = if #samples > 0 then samples[math.max(1, math.floor(#samples * 0.95))] * 1000 else math.huge
	local extra = {}
	for _, prop in
		{
			"HeartbeatTimeMs",
			"PhysicsStepTimeMs",
			"PrimitivesCount",
			"MovingPrimitivesCount",
			"ContactsCount",
		}
	do
		local ok, value = pcall(function()
			return (T.Stats :: any)[prop]
		end)
		if ok and typeof(value) == "number" then
			table.insert(extra, string.format("%s %.2f", prop, value))
		end
	end
	T.info(
		string.format(
			"heartbeat over 5 s: %d frames, average %.2f ms (%.0f fps), p95 %.2f ms, max %.2f ms",
			#samples,
			avgMs,
			1000 / avgMs,
			p95Ms,
			maxMs
		)
	)
	T.info(
		"Stats: "
			.. table.concat(extra, ", ")
			.. string.format(", physics fps %.0f", workspace:GetRealPhysicsFPS())
	)
	T.info("players: " .. #T.Players:GetPlayers() .. ", guards: " .. #T.tagged("Guard"))

	T.step(`parts in Level ≤ {BUDGET.PartsInLevel}`, parts <= BUDGET.PartsInLevel, parts)
	T.step(`lights ≤ {BUDGET.Lights}`, lights <= BUDGET.Lights, lights)
	T.step(`lights with shadows ≤ {BUDGET.ShadowLights}`, shadowLights <= BUDGET.ShadowLights, shadowLights)
	-- Memory is INFO only: in Studio it is the whole editor process (edit + server + client datamodels).
	-- Measure real numbers on a phone with the Developer Console (F9 → Memory).
	T.step(
		`heartbeat average ≤ {BUDGET.HeartbeatAvgMs} ms`,
		avgMs <= BUDGET.HeartbeatAvgMs,
		string.format("%.2f ms", avgMs)
	)
	T.step(
		`heartbeat max ≤ {BUDGET.HeartbeatMaxMs} ms`,
		maxMs <= BUDGET.HeartbeatMaxMs,
		string.format("%.2f ms", maxMs)
	)
end)
