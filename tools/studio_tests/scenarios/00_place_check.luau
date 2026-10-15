-- datamodel: Edit
-- play: no
-- goal: place is ready and clean: scripts synced, props present, HttpEnabled off, no test leftovers
-- Run this before the playtests and again at the very end (clean-up check).

return T.run("00 place check (Edit)", "Edit", function()
	local SSS = game:GetService("ServerScriptService")
	local SS = game:GetService("ServerStorage")
	local SP = game:GetService("StarterPlayer")

	T.step("Studio is in Edit (no playtest running)", not T.Run:IsRunning())
	T.step("HttpEnabled is off", game:GetService("HttpService").HttpEnabled == false)

	-- Scripts as Rojo places them (tools/studio_sync.py).
	local server = SSS:FindFirstChild("Server")
	local services = server and server:FindFirstChild("Services")
	local serviceCount = 0
	if services then
		for _, child in services:GetChildren() do
			if child:IsA("ModuleScript") then
				serviceCount += 1
			end
		end
	end
	T.step(
		"ServerScriptService.Server (Script) with Services",
		server and server:IsA("Script") and serviceCount >= 10,
		`{serviceCount} services`
	)
	local map = server and server:FindFirstChild("Map")
	T.step(
		"map code present (Map.Registry + Map.Heists)",
		map ~= nil and map:FindFirstChild("Registry") ~= nil and map:FindFirstChild("Heists") ~= nil
	)
	local client = SP.StarterPlayerScripts:FindFirstChild("Client")
	T.step("StarterPlayerScripts.Client (LocalScript)", client ~= nil and client:IsA("LocalScript"))
	local shared = T.RS:FindFirstChild("Shared")
	local missingShared = {}
	for _, name in { "Config", "Net", "Tags", "Signal" } do
		if not (shared and shared:FindFirstChild(name)) then
			table.insert(missingShared, name)
		end
	end
	T.step(
		"ReplicatedStorage.Shared complete",
		#missingShared == 0,
		if #missingShared > 0 then "missing: " .. table.concat(missingShared, ", ") else nil
	)
	local dev = services and services:FindFirstChild("DevService")
	T.step("DevService present (needed by the Client scenarios)", dev ~= nil)

	-- AI props (tools/props.json). When they are missing, Builder builds block stand-ins.
	local expectedProps = {
		"Van",
		"Crate",
		"StreetLamp",
		"PendantLamp",
		"Bicycle",
		"TulipBox",
		"TulipBoxTall",
		"CheeseWheel",
		"CheeseWheelTall",
		"GoldenGouda",
		"Forklift",
		"Barrel",
		"Kennel",
	}
	local props = SS:FindFirstChild("Props")
	local missingProps = {}
	for _, name in expectedProps do
		if not (props and props:FindFirstChild(name)) then
			table.insert(missingProps, name)
		end
	end
	T.step(
		"ServerStorage.Props complete (13)",
		#missingProps == 0,
		if #missingProps > 0 then "missing: " .. table.concat(missingProps, ", ") else nil
	)

	-- No test leftovers or DevTools in the place.
	local leftovers = {}
	local suspicious = { "StudioTest", "__CC", "DevTools", "TestFolder", "TmpServer", "Preview" }
	for _, root in { workspace, SS, T.RS, SSS, game:GetService("StarterGui"), game:GetService("Lighting") } do
		for _, child in root:GetChildren() do
			for _, word in suspicious do
				if string.find(child.Name, word, 1, true) then
					table.insert(leftovers, root.Name .. "." .. child.Name)
				end
			end
		end
	end
	-- A second copy of Server (studio_dump.luau makes one temporarily) must not be left behind either.
	if SS:FindFirstChild("Server") then
		table.insert(leftovers, "ServerStorage.Server")
	end
	T.step(
		"no test folders/temporary modules",
		#leftovers == 0,
		if #leftovers > 0 then table.concat(leftovers, ", ") else nil
	)

	local scripts = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			table.insert(scripts, d:GetFullName())
		end
	end
	T.step(
		"no stray scripts in Workspace",
		#scripts == 0,
		if #scripts > 0 then table.concat(scripts, ", ") else nil
	)
end)
