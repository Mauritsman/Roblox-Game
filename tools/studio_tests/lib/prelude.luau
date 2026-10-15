-- Crowbar Crew: shared test helpers for the Studio scenarios ("prelude").
-- Do NOT run this on its own: `python3 tools/studio_tests/bundle.py <scenario>` pastes this block in front of a scenario.
-- Everything lives in one table `T` (Luau allows only 200 locals per function).
--
-- Works in all three datamodels. Which helpers work where:
--   Edit   : T.step/T.info/T.waitFor/T.find (no player, no remotes)
--   Server : + T.player/T.character/T.teleport, pathfinding, LogService, Stats. The Server datamodel of execute_luau
--            has its OWN module cache: you do NOT get the state of the running services. Work through instances,
--            attributes and tags instead.
--   Client : + T.request (Studio-only DevService remotes), T.listen/T.waitMessage (messages from the server),
--            T.take/T.drop/T.pry/T.respawn
-- Anything a scenario creates in Server/Client disappears automatically when the playtest stops.

local T = {
	Players = game:GetService("Players"),
	RS = game:GetService("ReplicatedStorage"),
	CS = game:GetService("CollectionService"),
	Run = game:GetService("RunService"),
	PFS = game:GetService("PathfindingService"),
	Log = game:GetService("LogService"),
	Stats = game:GetService("Stats"),
	UIS = game:GetService("UserInputService"),
	lines = {},
	passed = 0,
	total = 0,
	conns = {},
	messages = {},
	listening = false,
	humanKeys = {},
	started = os.clock(),

	-- Copy of the key positions (heist Points in src/server/Map/Heists/GoldenWheel). Update when the map changes.
	P = {
		Spawn = Vector3.new(-36, 3, -10), -- Points.Spawn / CrewSpawn
		Van = Vector3.new(-40, 0, 4), -- Quay: Builder.prop("Van")
		Goal = Vector3.new(55, 3, 0), -- Warehouse: invisible Goal block inside the cage
		GuardStart = Vector3.new(8, 3, -18),
		-- Pathfinding targets (snapped to the floor below with T.floorAt).
		Shop = Vector3.new(-11, 4, -27), -- shop (x -22..0, z -40..-14)
		Courtyard = Vector3.new(-11, 4, 18), -- courtyard (z 4..40)
		Security = Vector3.new(-14, 4, -8), -- security room (z -14..4), only reachable through the hall
		Hall = Vector3.new(30, 4, 0), -- ripening hall, centre aisle between the racks
		Office = Vector3.new(13, 13, 15), -- office on the mezzanine (floor y 9.2)
		Cage = Vector3.new(52, 4, 4), -- inside the cage (x 50..58, z -6..6), next to the plinth
	},
	Gadgets = { "Drone", "Noisemaker", "EMP", "BubbleBlaster", "Crowbar" }, -- Config.GadgetOrder
	Doors = { "StaffDoor", "DeliveryGate", "CageDoor" }, -- the three Pryable objects
	WindowSolo = 12, -- Config.windowSeconds(1): Normal 10 + solo 2
}

T.datamodel = if not T.Run:IsRunning() then "Edit" elseif T.Run:IsServer() then "Server" else "Client"

--------------------------------------------------------------------------------
-- Results
--------------------------------------------------------------------------------

-- One step: PASS or FAIL with a short explanation. Returns ok, so you can stop when something is missing.
function T.step(name: string, ok: any, detail: any?): boolean
	T.total += 1
	if ok then
		T.passed += 1
	end
	local suffix = if detail ~= nil then " — " .. tostring(detail) else ""
	table.insert(T.lines, (if ok then "PASS  " else "FAIL  ") .. name .. suffix)
	return if ok then true else false
end

-- Information without a verdict (does not count towards RESULT).
function T.info(text: any)
	table.insert(T.lines, "INFO  " .. tostring(text))
end

-- Client only: waits until nobody has pressed a key or mouse button for `quiet` seconds (max `timeout`).
-- A person playing in the Studio window has priority: scenarios never teleport a character that is being steered.
function T.waitIdle(quiet: number?, timeout: number?): boolean
	local need, limit = quiet or 5, timeout or 30
	local last = os.clock()
	local connection = T.UIS.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Keyboard or kind == Enum.UserInputType.MouseButton1 then
			last = os.clock()
		end
	end)
	local start = os.clock()
	while os.clock() - start < limit do
		if #T.UIS:GetKeysPressed() > 0 then
			last = os.clock()
		end
		if os.clock() - last >= need then
			connection:Disconnect()
			return true
		end
		task.wait(0.2)
	end
	connection:Disconnect()
	return false
end

-- Runs the scenario, catches errors and returns the final text ("RESULT: x/y").
-- expected = "Client", "Server", "Edit", or several separated by a slash, e.g. "Server/Client".
-- In Client: first waits for an idle moment (see T.waitIdle) and skips the scenario if a person keeps playing.
-- Key presses by a person during the run turn every FAIL into WARN ("disturbed, re-run when idle").
function T.run(title: string, expected: string, body: () -> ()): string
	local skipped = false
	if not table.find(string.split(expected, "/"), T.datamodel) then
		T.step("correct datamodel", false, `this scenario belongs in {expected}, not in {T.datamodel}`)
	elseif T.datamodel == "Client" and not T.waitIdle(5, 30) then
		skipped = true
		T.info(
			"SKIPPED: someone is playing in the Studio window (input within the last 5 s for 30 s); re-run later"
		)
	else
		if T.datamodel == "Client" then
			table.insert(
				T.conns,
				T.UIS.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Keyboard then
						table.insert(T.humanKeys, input.KeyCode.Name)
					end
				end)
			)
		end
		local ok, err = xpcall(body, debug.traceback)
		if not ok then
			T.step("scenario ran without a script error", false, tostring(err))
		end
	end
	for _, connection in T.conns do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(T.conns)
	local warned = 0
	if #T.humanKeys > 0 then
		for index, line in T.lines do
			if string.sub(line, 1, 6) == "FAIL  " then
				T.lines[index] = "WARN  " .. string.sub(line, 7)
				warned += 1
			end
		end
		T.info(
			`DISTURBED: {#T.humanKeys} key presses by a person during this scenario `
				.. `({table.concat(T.humanKeys, ",", 1, math.min(#T.humanKeys, 12))}); FAIL → WARN, re-run when idle`
		)
	end
	local header = string.format("== %s [%s, %.1f s]", title, T.datamodel, os.clock() - T.started)
	local result = if skipped
		then "\nRESULT: SKIPPED"
		else string.format(
			"\nRESULT: %d/%d%s",
			T.passed,
			T.total,
			if warned > 0 then ` ({warned} WARN: disturbed)` else ""
		)
	return header .. "\n" .. table.concat(T.lines, "\n") .. result
end

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

-- Waits until predicate() returns something truthy (errors count as "not yet"). Returns (value, seconds) or nil.
function T.waitFor(predicate: () -> any, timeout: number?, interval: number?): (any, number?)
	local limit = timeout or 5
	local start = os.clock()
	repeat
		local ok, value = pcall(predicate)
		if ok and value then
			return value, os.clock() - start
		end
		task.wait(interval or 0.1)
	until os.clock() - start > limit
	return nil, nil
end

function T.v3(v: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

function T.flat(a: Vector3, b: Vector3): number
	local d = a - b
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

function T.sameColor(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
end

function T.rgb(c: Color3): string
	return string.format(
		"%d,%d,%d",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

function T.level(): Instance?
	return workspace:FindFirstChild("Level")
end

-- First descendant with this name (in workspace.Level by default).
function T.find(name: string, root: Instance?): Instance?
	local base = root or T.level()
	return base and base:FindFirstChild(name, true)
end

function T.tagged(tag: string, name: string?): { Instance }
	local list = {}
	for _, inst in T.CS:GetTagged(tag) do
		if name == nil or inst.Name == name then
			table.insert(list, inst)
		end
	end
	return list
end

function T.attr(inst: Instance?, name: string): any
	return if inst then inst:GetAttribute(name) else nil
end

-- Floor below a point (ignores players, guards and non-colliding parts). Returns (position, part) or nil.
function T.floorAt(position: Vector3, up: number?): (Vector3?, Instance?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, player in T.Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, guard in T.CS:GetTagged("Guard") do
		table.insert(ignore, guard)
	end
	params.FilterDescendantsInstances = ignore
	pcall(function()
		(params :: any).RespectCanCollide = true
	end)
	local hit = workspace:Raycast(position + Vector3.new(0, up or 0, 0), Vector3.new(0, -40, 0), params)
	if hit then
		return hit.Position, hit.Instance
	end
	return nil, nil
end

--------------------------------------------------------------------------------
-- Player (Server and Client)
--------------------------------------------------------------------------------

function T.player(): Player
	if T.datamodel == "Client" then
		return T.Players.LocalPlayer
	end
	return T.Players:GetPlayers()[1]
end

-- Living character with a HumanoidRootPart and a Humanoid (waits up to timeout).
function T.character(timeout: number?): Model?
	return T.waitFor(function()
		local player = T.player()
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and root and humanoid and humanoid.Health > 0 then
			return character
		end
		return nil
	end, timeout or 10)
end

function T.root(): BasePart?
	local character = T.character(10)
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function T.humanoid(): Humanoid?
	local character = T.character(10)
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Puts the player at a position (optionally facing lookAt). The client owns its character,
-- so from Client this replicates to the server straight away.
function T.teleport(position: Vector3, lookAt: Vector3?): Model
	local character = T.character(10)
	assert(character, "no character")
	local cf = if lookAt
		then CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
		else CFrame.new(position)
	character:PivotTo(cf)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	task.wait(0.15)
	return character
end

--------------------------------------------------------------------------------
-- Network (Client only): DevService remotes and messages from the server
--------------------------------------------------------------------------------

function T.remote(name: string): RemoteEvent
	local folder = T.RS:WaitForChild("Remotes", 5)
	assert(folder, "ReplicatedStorage.Remotes is missing")
	local remote = folder:WaitForChild(name, 5)
	assert(remote, "Remote " .. name .. " is missing")
	return remote :: RemoteEvent
end

-- Request to the server, like Net.request("DevTake", "EMP").
function T.request(name: string, ...: any)
	assert(T.datamodel == "Client", "T.request only works in the Client datamodel")
	T.remote("ToServer"):FireServer(name, ...)
end

-- Start recording messages from the server (Toast, RunEnded, Caught, EMP, Window, Crack, ...).
function T.listen()
	assert(T.datamodel == "Client", "T.listen only works in the Client datamodel")
	if T.listening then
		return
	end
	T.listening = true
	table.insert(
		T.conns,
		T.remote("ToClient").OnClientEvent:Connect(function(name: any, ...: any)
			table.insert(T.messages, { name = name, args = table.pack(...), t = os.clock() })
		end)
	)
end

-- Waits for a message `name` that arrived after time `since` (and optionally matches predicate(args...)).
function T.waitMessage(name: string, timeout: number?, since: number?, predicate: ((...any) -> boolean)?): any
	return T.waitFor(function()
		for _, message in T.messages do
			if message.name == name and message.t >= (since or 0) then
				if predicate == nil or predicate(table.unpack(message.args, 1, message.args.n)) then
					return message
				end
			end
		end
		return nil
	end, timeout or 5, 0.05)
end

-- All toasts since `since`, as one string (useful as the explanation of a FAIL).
function T.toasts(since: number?): string
	local list = {}
	for _, message in T.messages do
		if message.name == "Toast" and message.t >= (since or 0) then
			table.insert(list, tostring(message.args[1]))
		end
	end
	return table.concat(list, " | ")
end

-- Fresh run with a fresh character: RestartRun → RunEnded "RESTART" → after 7 s Reset (new level, LoadCharacter).
-- Returns the new character (or nil). Calls T.listen itself.
function T.respawn(timeout: number?): Model?
	T.listen()
	local old = T.player().Character
	T.request("RestartRun")
	return T.waitFor(function()
		local character = T.player().Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return character ~= old and root and character
	end, timeout or 14, 0.05)
end

--------------------------------------------------------------------------------
-- Gadgets and doors (Client, through the Studio-only DevService)
--------------------------------------------------------------------------------

function T.gadgets(): { string }
	local player = T.player()
	local value = player and player:GetAttribute("Gadgets")
	local list = {}
	if typeof(value) == "string" then
		for name in string.gmatch(value, "[^,]+") do
			table.insert(list, name)
		end
	end
	return list
end

function T.has(name: string): boolean
	return table.find(T.gadgets(), name) ~= nil
end

-- Take a gadget (DevTake = the pedestal prompt). Does nothing if you already have it.
function T.take(name: string, timeout: number?): boolean
	if T.has(name) then
		return true
	end
	T.request("DevTake", name)
	return T.waitFor(function()
		return T.has(name)
	end, timeout or 3) ~= nil
end

-- Return a gadget (DevTake on a gadget you hold).
function T.drop(name: string, timeout: number?): boolean
	if not T.has(name) then
		return true
	end
	T.request("DevTake", name)
	return T.waitFor(function()
		return not T.has(name)
	end, timeout or 3) ~= nil
end

function T.dropAll(): boolean
	for _, name in T.gadgets() do
		T.drop(name)
	end
	return #T.gadgets() == 0
end

-- Door by name, also when it is already open (the Pryable tag is gone then).
function T.door(name: string): BasePart?
	for _, inst in T.CS:GetTagged("Pryable") do
		if inst.Name == name and inst:IsA("BasePart") then
			return inst
		end
	end
	local found = T.find(name)
	return if found and found:IsA("BasePart") then found else nil
end

function T.isOpen(door: BasePart?): boolean
	return door ~= nil and not door.CanCollide and not T.CS:HasTag(door, "Pryable")
end

-- Pry a door open through DevPry (takes the Crowbar first). Returns (ok, explanation).
function T.pry(name: string, timeout: number?): (boolean, string)
	if not T.take("Crowbar") then
		T.dropAll()
		if not T.take("Crowbar") then
			return false, "could not take the Crowbar"
		end
	end
	local door = T.door(name)
	if not door then
		return false, "door " .. name .. " not found"
	end
	if T.isOpen(door) then
		return true, "was already open"
	end
	T.request("DevPry", name)
	local _, seconds = T.waitFor(function()
		return T.isOpen(door)
	end, timeout or 3)
	if seconds then
		return true, string.format("open after %.2f s", seconds)
	end
	return false, "stayed closed"
end

--------------------------------------------------------------------------------
-- Guards and alarm
--------------------------------------------------------------------------------

function T.guard(): Model?
	local guard = T.CS:GetTagged("Guard")[1]
	return if guard and guard:IsA("Model") then guard else nil
end

function T.guardState(guard: Model?): string?
	local g = guard or T.guard()
	return g and g:GetAttribute("GuardState")
end

function T.guardRoot(guard: Model?): BasePart?
	local g = guard or T.guard()
	local root = g and (g:FindFirstChild("HumanoidRootPart") or g.PrimaryPart)
	return if root and root:IsA("BasePart") then root else nil
end

function T.alarmLevel(): number?
	return T.RS:GetAttribute("AlarmLevel")
end

--------------------------------------------------------------------------------
-- Console (LogService)
--------------------------------------------------------------------------------

-- Lines that come from Roblox itself (not from our code).
T.LOG_IGNORE = {
	"CorePackages",
	"CoreGui",
	"CoreScript",
	"UIBlox",
	"FoundationProvider",
	"VirtualInputManager",
	"SerializationService",
	"live editing session",
}
-- Markers of our code.
T.LOG_OURS = {
	"ServerScriptService",
	"StarterPlayerScripts",
	"ReplicatedStorage.Shared",
	"Workspace.Level",
	"[Server]",
	"[Client]",
	"[Net]",
	"[GuardService]",
	"[MapService]",
	"Crowbar Crew",
}

local function containsAny(text: string, needles: { string }): boolean
	for _, needle in needles do
		if string.find(text, needle, 1, true) then
			return true
		end
	end
	return false
end

-- Returns three lists: errors/warnings from our code, other unknown errors (not Roblox core), and the rest.
function T.logProblems(): ({ string }, { string }, { string })
	local ours, unknown, ignored = {}, {}, {}
	for _, entry in T.Log:GetLogHistory() do
		local kind = entry.messageType
		if kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning then
			local text = (if kind == Enum.MessageType.MessageError then "[E] " else "[W] ") .. entry.message
			if containsAny(entry.message, T.LOG_OURS) then
				table.insert(ours, text)
			elseif containsAny(entry.message, T.LOG_IGNORE) then
				table.insert(ignored, text)
			else
				table.insert(unknown, text)
			end
		end
	end
	return ours, unknown, ignored
end

-- ===================== end of prelude, the scenario follows =====================
