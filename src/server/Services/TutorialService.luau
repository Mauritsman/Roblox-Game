--!strict
-- The mini-job "Corner Cheese" (beta-spec §1.6, ux §3.1): a solo tutorial of about 3 minutes for new players, in
-- one of 2 parallel slots (a third newcomer waits in the Garage until a slot frees up). It cannot be failed:
-- no gadgets, no Karel/Boef/cameras, and one sleeping guard who is not a real guard.
--
-- Flow: MapService:BuildMiniJob(slot) → loot on every Fixed anchor (session "Tutorial<slot>") → the player is
-- placed at Points.Spawn (Activity "Tutorial", player attribute Session) → steps with `Hint`s:
--   grab the wheel → bank it → sneak past the guard (TutorialTrigger) → pocket a cube → lift the Gouda
--   (60 s lockdown, the guard follows but trips just short) → roll it to the van → hold to drive
-- Funnel steps go to meta by name (Lib/Meta → AnalyticsTracker:OnboardingStep: Spawned, Moved, FirstLootGrabbed,
-- FirstLootBanked, SneakedPastGuard, GoudaLifted; meta adds MiniJobEscaped and GarageReached). The end settles
-- with heistId "MiniJob" (meta pays the welcome bonus and sets onboarding.done), frees the slot and sends the
-- player to the Garage. Lockdown running out = an automatic drive. Without the mini-job map it is skipped.
--
-- Entry points (integration.md): Start(player, force?) → true when started, IsInTutorial(player), Stop(player).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local RoundPlan = require(ReplicatedStorage.Shared.Logic.RoundPlan)
local RoundStats = require(ReplicatedStorage.Shared.Logic.RoundStats)
local TutorialGuard = require(ReplicatedStorage.Shared.Logic.TutorialGuard)

local Server = script.Parent.Parent
local Meta = require(Server.Lib.Meta)
local Rig = require(Server.Npc.Rig)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)

local TutorialService = {}

local T = Config.Tutorial
local RULES = TutorialGuard.rulesFrom(Config)
local MAP: any = MapService -- BuildMiniJob & co. belong to map B and may not exist yet

-- Funnel step numbers (ux §3.2) for a TutorialTrigger whose `Step` is a number.
local STEP_NAMES: { [number]: string } = {
	[1] = "Spawned",
	[2] = "Moved",
	[3] = "FirstLootGrabbed",
	[4] = "FirstLootBanked",
	[5] = "SneakedPastGuard",
	[6] = "GoudaLifted",
}

-- Fallback loot per anchor class when the mini-job definition has no Loot list.
local CLASS_LOOT: { [string]: string } = {
	Small = "CheeseCube",
	Medium = "CheeseWheel",
	Heavy = "BigWheel",
	Main = "GoldenGouda",
}

type Run = {
	player: Player,
	slot: number,
	session: string,
	folder: Instance,
	points: { [string]: any },
	roundId: string,
	startedAt: number,
	spawn: CFrame,
	van: Vector3,
	gouda: Vector3?,
	wheel: Vector3?,
	triggers: { BasePart },
	-- progress
	moved: boolean,
	grabbed: boolean,
	banked: boolean,
	sneaked: boolean,
	pocketUntil: number?,
	pocketed: boolean,
	lifted: boolean,
	mainBanked: boolean,
	hintKey: string,
	lockdownEndsAt: number?,
	ending: boolean,
	-- the sleeping guard
	guard: Model?,
	guardRoot: BasePart?,
	board: Rig.Billboard?,
	guardSeat: CFrame?,
	guardAwake: boolean,
	tripUntil: number,
	stirHintAt: number,
	hideHinted: boolean,
	lastPlayerPos: Vector3?,
	drivePrompt: ProximityPrompt?,
	connections: { RBXScriptConnection },
}

local runs: { [Player]: Run } = {}
local slotOwner: { [number]: Player } = {}
local waiting: { Player } = {}
local warned = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function charAttr(player: Player, name: string): any
	local character = player.Character
	return if character then character:GetAttribute(name) else nil
end

local function inside(part: BasePart, position: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y + 4
		and math.abs(localPos.Z) <= half.Z
end

local function slotCount(): number
	local count = T.MaxSlots
	if type(MAP.MiniJobSlotCount) == "function" then
		local ok, n = pcall(MAP.MiniJobSlotCount, MAP)
		if ok and type(n) == "number" then
			count = math.min(count, n)
		end
	end
	return count
end

local function freeSlot(): number?
	for slot = 1, slotCount() do
		if not slotOwner[slot] then
			return slot
		end
	end
	return nil
end

local function hint(run: Run, key: string, text: string, icon: string, worldPos: Vector3?)
	run.hintKey = key
	Net.send(run.player, "Hint", key, text, icon, worldPos)
end

local function step(run: Run, name: string)
	Meta.OnboardingStep(run.player, name)
end

--------------------------------------------------------------------------------------------------------------
-- Building the slot
--------------------------------------------------------------------------------------------------------------

local function taggedIn(tag: string, root: Instance): { Instance }
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(root) then
			table.insert(list, inst)
		end
	end
	return list
end

-- Every anchor, bank zone and trigger of the slot carries the slot's session.
local function stampSession(folder: Instance, session: string)
	for _, tag in { Tags.LootAnchor, Tags.BankZone, Tags.TutorialTrigger } do
		for _, inst in taggedIn(tag, folder) do
			if inst:GetAttribute(Tags.Session) == nil then
				inst:SetAttribute(Tags.Session, session)
			end
		end
	end
end

-- Loot on the slot's anchors (all Fixed: no randomness, no Blue Moon).
local function spawnLoot(folder: Instance, session: string)
	local anchors: { RoundPlan.Anchor } = {}
	local parts: { [string]: BasePart } = {}
	for index, inst in taggedIn(Tags.LootAnchor, folder) do
		local class = inst:GetAttribute(Tags.AnchorClass)
		if inst:IsA("BasePart") and type(class) == "string" then
			local id = inst:GetAttribute(Tags.AnchorId)
			local anchorId = if type(id) == "string"
				then `{session}:{id}`
				else `{session}:{inst.Name}#{index}`
			parts[anchorId] = inst
			local group = inst:GetAttribute(Tags.Group)
			table.insert(anchors, {
				Id = anchorId,
				Class = class,
				Group = if type(group) == "string" then group else nil,
				Fixed = true,
				Opener = inst:GetAttribute(Tags.Opener) == true,
			})
		end
	end
	if #anchors == 0 then
		return
	end
	local def = MAP.MiniJobDef
	local lootList = if type(def) == "table" and type(def.Loot) == "table" then def.Loot else nil
	local placed: { any } = {}
	local ok = false
	if lootList then
		ok = pcall(function()
			local rules = table.clone(RoundPlan.rulesFrom(Config))
			rules.RareChance = 0
			local plan = RoundPlan.generate(
				1,
				{
					heistId = "MiniJob",
					anchors = anchors,
					loot = lootList,
					lootTypes = Config.Loot.Types :: any,
					hasKarel = false,
					rules = rules,
				} :: any,
				1,
				{ heistId = "MiniJob" }
			)
			placed = plan.loot
		end)
	end
	if not ok or #placed == 0 then
		placed = {}
		for _, anchor in anchors do
			local lootType = CLASS_LOOT[anchor.Class] or "CheeseCube"
			table.insert(placed, { anchorId = anchor.Id, type = lootType, class = anchor.Class })
		end
	end
	LootService:Spawn(placed, { anchorParts = parts, session = session })
end

local function positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return nil
end

local function vector(value: any): Vector3?
	return if typeof(value) == "Vector3" then value else nil
end

-- The snoozing guard on his chair: a guard figure (B's Rig), anchored, moved by this service.
local function buildGuard(run: Run)
	local seatPos = vector(run.points.SleepingGuard)
	local marker = run.folder:FindFirstChild("SleepingGuard", true)
	if not seatPos and marker then
		seatPos = positionOf(marker)
	end
	if not seatPos then
		return
	end
	local facing = vector(run.points.SleepingGuardFacing) or Vector3.new(-1, 0, 0)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(-1, 0, 0)
	end
	local model = Rig.humanoid("SleepingGuard", {
		skin = Color3.fromRGB(234, 184, 146),
		shirt = Color3.fromRGB(40, 52, 90),
		pants = Color3.fromRGB(30, 30, 40),
	})
	Rig.attach(
		model,
		"Head",
		Vector3.new(1.4, 0.4, 1.5),
		CFrame.new(0, 0.8, 0),
		Color3.fromRGB(30, 36, 70),
		"Cap"
	)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part == root
			part.CanCollide = false
		end
	end
	local standing = CFrame.lookAt(seatPos + Vector3.new(0, 3, 0), seatPos + Vector3.new(0, 3, 0) + flat.Unit)
	run.guardSeat = standing
	-- Asleep: slumped back in his chair.
	local slumped = standing * CFrame.new(0, -0.8, 0) * CFrame.Angles(math.rad(-18), 0, 0)
	Rig.place(model, run.folder, slumped, {})
	local board = Rig.billboard(model)
	Rig.setIcon(board, "Zzz", Color3.fromRGB(200, 220, 255))
	run.guard = model
	run.guardRoot = root
	run.board = board
end

local function findDrivePart(run: Run): Instance?
	for _, exit in taggedIn(Tags.Exit, run.folder) do
		local point = exit:FindFirstChild("DrivePoint", true)
		if point and (point:IsA("BasePart") or point:IsA("Attachment")) then
			return point
		end
	end
	local zones = taggedIn(Tags.BankZone, run.folder)
	return zones[1]
end

local function vanPosition(run: Run): Vector3
	local zones = taggedIn(Tags.BankZone, run.folder)
	local zone = zones[1]
	if zone and zone:IsA("BasePart") then
		return zone.Position
	end
	return vector(run.points.BankZone) or vector(run.points.Van) or run.spawn.Position
end

--------------------------------------------------------------------------------------------------------------
-- Steps and hints
--------------------------------------------------------------------------------------------------------------

-- The hint for the first step not done yet (steps may be done out of order).
local function showNextHint(run: Run)
	if run.ending then
		return
	end
	local guardPos = if run.guardRoot then run.guardRoot.Position else nil
	if run.lifted and not run.mainBanked then
		hint(run, "roll", "Roll it to the van", "roll", run.van)
	elseif run.mainBanked then
		hint(run, "drive", "Hold to drive away", "van", run.van)
	elseif not run.grabbed then
		hint(run, "grab", "Grab the cheese", "wheel", run.wheel)
	elseif not run.banked then
		hint(run, "bank", "Bring it to the van", "van", run.van)
	elseif not run.sneaked then
		hint(run, "sneak", "Sneak past the guard", "crouch", guardPos)
	elseif not run.pocketed then
		hint(run, "pocket", "Pocket the small cheese", "pocket", nil)
	else
		hint(run, "gouda", "Grab the Golden Gouda", "crown", run.gouda)
	end
end

-- A short extra hint ("Crouch!", "Hide!"), then back to the step hint.
local function flashHint(run: Run, key: string, text: string, icon: string)
	hint(run, key, text, icon, nil)
	task.delay(2.5, function()
		if runs[run.player] == run and run.hintKey == key then
			showNextHint(run)
		end
	end)
end

local function finish(run: Run, outcome: string)
	if run.ending then
		return
	end
	run.ending = true
	if run.drivePrompt then
		run.drivePrompt.Enabled = false
	end
	Net.send(run.player, "Hint", "", "")
	local character = run.player.Character
	if character then
		character:SetAttribute(Tags.Frozen, true)
	end
	local vanLoot = LootService:GetVanTotal(run.session)
	local mainBanked = LootService:MainBanked(run.session)
	local escaped = outcome == "Escaped"
	if escaped then
		Net.send(
			run.player,
			"Escaped",
			if run.lockdownEndsAt then math.max(0, run.lockdownEndsAt - now()) else 0
		)
	end
	local result = {
		roundId = run.roundId,
		heistId = "MiniJob",
		difficulty = "Normal",
		isHotJob = false,
		outcome = outcome,
		vanLoot = vanLoot,
		stars = RoundStats.stars(vanLoot, mainBanked, escaped, T.Stars),
		mainLootBanked = mainBanked,
		maxAlarmTier = 0,
		lockdownAtEnd = run.lockdownEndsAt ~= nil,
		durationSeconds = math.max(0, math.floor(now() - run.startedAt)),
		objectives = {},
		banked = LootService:GetBanked(run.session),
		crew = { { player = run.player, inVanAtEnd = escaped, award = "FreshCrook", stats = {} } },
	}
	task.spawn(Meta.SettleRound, result)
	task.delay(T.DriveAwaySeconds, function()
		TutorialService:Stop(run.player, true)
	end)
end

local function onDrive(run: Run, player: Player)
	if player ~= run.player or run.ending then
		return
	end
	if charAttr(player, Tags.InVan) ~= true then
		Net.send(player, "Toast", "Get in the van first!")
		return
	end
	finish(run, "Escaped")
end

local function makeDrivePrompt(run: Run)
	local parent = findDrivePart(run)
	if not parent then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Van"
	prompt.HoldDuration = Config.Round.DriveHoldSeconds
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- after the first bank
	prompt:SetAttribute("ContextIcon", "drive")
	prompt.Parent = parent
	prompt.Triggered:Connect(function(player)
		onDrive(run, player)
	end)
	run.drivePrompt = prompt
end

local function onBanked(run: Run, main: boolean)
	if not run.banked then
		run.banked = true
		run.grabbed = true
		step(run, "FirstLootGrabbed")
		step(run, "FirstLootBanked")
		if run.drivePrompt then
			run.drivePrompt.Enabled = true
		end
	end
	if main then
		run.mainBanked = true
	end
	showNextHint(run)
end

local function onLifted(run: Run)
	if run.lifted then
		return
	end
	run.lifted = true
	run.grabbed = true
	step(run, "GoudaLifted")
	local seconds = T.LockdownSeconds
	run.lockdownEndsAt = now() + seconds
	Net.send(run.player, "Lockdown", run.lockdownEndsAt, "MainLoot")
	Net.send(run.player, "Window", "POLICE", seconds, run.van)
	-- The guard wakes up.
	run.guardAwake = true
	if run.guard and run.guardSeat then
		run.guard:PivotTo(run.guardSeat)
	end
	if run.board then
		Rig.setIcon(run.board, "!", Color3.fromRGB(255, 60, 60))
	end
	showNextHint(run)
end

--------------------------------------------------------------------------------------------------------------
-- The tick
--------------------------------------------------------------------------------------------------------------

local function updateGuard(run: Run, root: BasePart, dt: number)
	local guardRoot = run.guardRoot
	local guard = run.guard
	if not guard or not guardRoot or not guard.Parent then
		return
	end
	local offset = root.Position - guardRoot.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local distance = flat.Magnitude
	local crouching = charAttr(run.player, Tags.Crouching) == true
	local hidden = charAttr(run.player, Tags.Hidden) == true
	local t = os.clock()

	if not run.guardAwake then
		if TutorialGuard.stirs(distance, crouching, RULES) then
			if run.board then
				Rig.setIcon(run.board, "Hmm?", Color3.fromRGB(255, 220, 60))
			end
			if t - run.stirHintAt >= T.StirHintCooldown then
				run.stirHintAt = t
				flashHint(run, "crouch", "Crouch!", "crouch")
			end
		elseif run.board and t - run.stirHintAt > 1.5 then
			Rig.setIcon(run.board, "Zzz", Color3.fromRGB(200, 220, 255))
		end
		return
	end

	-- Lockdown: follows, never catches; trips when the player stands still.
	if t < run.tripUntil or distance < 0.01 then
		return
	end
	local lastPos = run.lastPlayerPos
	local moving = lastPos == nil or (root.Position - lastPos).Magnitude > 0.05
	run.lastPlayerPos = root.Position
	local look = flat.Unit
	if hidden then
		if run.board then
			Rig.setIcon(run.board, "?", Color3.fromRGB(255, 220, 60))
		end
		return
	end
	local stepLength, tripped = TutorialGuard.follow(distance, moving, dt, RULES)
	local target = guardRoot.Position + look * stepLength
	-- Walls stop him (he is anchored: no physics).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { guard }
	if run.player.Character then
		table.insert(ignore, run.player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	if stepLength > 0 and workspace:Raycast(guardRoot.Position, look * (stepLength + 1), params) then
		target = guardRoot.Position
	end
	guard:PivotTo(CFrame.lookAt(target, target + look))
	if tripped then
		run.tripUntil = t + RULES.tripSeconds
		guard:PivotTo(
			CFrame.lookAt(target, target + look) * CFrame.new(0, -1.5, 0) * CFrame.Angles(math.rad(-70), 0, 0)
		)
		if run.board then
			Rig.setIcon(run.board, "Whoa!", Color3.fromRGB(255, 220, 60))
		end
		task.delay(RULES.tripSeconds, function()
			if guard.Parent and run.board then
				guard:PivotTo(CFrame.lookAt(target, target + look))
				Rig.setIcon(run.board, "!", Color3.fromRGB(255, 60, 60))
			end
		end)
	end
	local dot = guardRoot.CFrame.LookVector:Dot(look)
	if not run.hideHinted and TutorialGuard.sees(distance, dot, hidden, RULES) and distance < 8 then
		run.hideHinted = true
		flashHint(run, "hide", "Hide!", "hide")
	end
end

local function tickRun(run: Run, dt: number)
	if run.ending then
		return
	end
	local player = run.player
	local root = rootOf(player)
	if not root then
		return
	end
	if not run.moved and (root.Position - run.spawn.Position).Magnitude >= T.MovedDistance then
		run.moved = true
		step(run, "Moved")
	end
	if
		not run.grabbed
		and (charAttr(player, Tags.CarryClass) ~= nil or (charAttr(player, Tags.Pockets) or 0) > 0)
	then
		run.grabbed = true
		step(run, "FirstLootGrabbed")
		showNextHint(run)
	end
	if not run.sneaked then
		local passed = false
		local stepName = "SneakedPastGuard"
		for _, trigger in run.triggers do
			if trigger.Parent and inside(trigger, root.Position) then
				passed = true
				local value = trigger:GetAttribute(Tags.Step)
				local number = tonumber(value)
				if number and STEP_NAMES[number] then
					stepName = STEP_NAMES[number]
				elseif type(value) == "string" and value ~= "" then
					stepName = value
				end
				break
			end
		end
		local door = vector(run.points.FrontDoor)
		if not passed and #run.triggers == 0 and door and (root.Position - door).Magnitude <= 5 then
			passed = true
		end
		if passed then
			run.sneaked = true
			run.pocketUntil = now() + T.PocketHintSeconds
			step(run, stepName)
			showNextHint(run)
		end
	end
	if run.sneaked and not run.pocketed then
		local pockets = charAttr(player, Tags.Pockets)
		if (type(pockets) == "number" and pockets > 0) or (run.pocketUntil and now() >= run.pocketUntil) then
			run.pocketed = true
			showNextHint(run)
		end
	end
	updateGuard(run, root, dt)
	if run.lockdownEndsAt and now() >= run.lockdownEndsAt then
		finish(run, "Escaped") -- the police come: the van drives off on its own
	end
end

--------------------------------------------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------------------------------------------

local function place(run: Run)
	local player = run.player
	local character = player.Character
	if not character then
		character = player.CharacterAdded:Wait()
	end
	if not character or runs[player] ~= run then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	character:SetAttribute(Tags.Frozen, nil)
	character:SetAttribute(Tags.Caught, nil)
	character:SetAttribute(Tags.Captured, nil)
	character:SetAttribute(Tags.Masked, false)
	pcall(function()
		player:RequestStreamAroundAsync(run.spawn.Position, Config.Round.StreamTimeout)
	end)
	if runs[player] == run and character.Parent then
		character:PivotTo(run.spawn)
	end
end

local function begin(player: Player, slot: number): boolean
	slotOwner[slot] = player
	local ok, folder, points = pcall(function()
		return MAP:BuildMiniJob(slot)
	end)
	if not ok or typeof(folder) ~= "Instance" then
		warn(`[TutorialService] building mini-job slot {slot} failed: {folder}`)
		slotOwner[slot] = nil
		return false
	end
	local session = `Tutorial{slot}`
	if type(MAP.MiniJobSession) == "function" then
		local okSession, name = pcall(MAP.MiniJobSession, MAP, slot)
		if okSession and type(name) == "string" then
			session = name
		end
	end
	local pts: { [string]: any } = if type(points) == "table" then points else {}
	stampSession(folder, session)
	LootService:Clear(session)
	LootService:ResetSession(session)
	spawnLoot(folder, session)

	local spawnPos = vector(pts.Spawn)
	if not spawnPos then
		local spawnPart = folder:FindFirstChild("Spawn", true)
		spawnPos = if spawnPart then positionOf(spawnPart) else nil
	end
	local origin = spawnPos or (folder:IsA("Model") and folder:GetPivot().Position) or Vector3.new(0, 5, 0)
	local facing = vector(pts.SpawnFacing) or Vector3.new(0, 0, 1)
	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	if flatFacing.Magnitude < 0.01 then
		flatFacing = Vector3.new(0, 0, 1)
	end

	local triggers: { BasePart } = {}
	for _, inst in taggedIn(Tags.TutorialTrigger, folder) do
		if inst:IsA("BasePart") then
			table.insert(triggers, inst)
		end
	end

	local run: Run = {
		player = player,
		slot = slot,
		session = session,
		folder = folder,
		points = pts,
		roundId = HttpService:GenerateGUID(false),
		startedAt = now(),
		spawn = CFrame.lookAt(origin, origin + flatFacing.Unit),
		van = Vector3.zero,
		gouda = vector(pts.Gouda),
		wheel = vector(pts.Wheel),
		triggers = triggers,
		moved = false,
		grabbed = false,
		banked = false,
		sneaked = false,
		pocketUntil = nil,
		pocketed = false,
		lifted = false,
		mainBanked = false,
		hintKey = "",
		lockdownEndsAt = nil,
		ending = false,
		guard = nil,
		guardRoot = nil,
		board = nil,
		guardSeat = nil,
		guardAwake = false,
		tripUntil = 0,
		stirHintAt = -math.huge,
		hideHinted = false,
		lastPlayerPos = nil,
		drivePrompt = nil,
		connections = {},
	}
	run.van = vanPosition(run)
	runs[player] = run
	buildGuard(run)
	makeDrivePrompt(run)

	player:SetAttribute(Tags.Session, session)
	player:SetAttribute(Tags.Activity, "Tutorial")
	player:SetAttribute(Tags.InRound, true)
	-- Died in the mini-job: back by the van (it cannot be failed).
	table.insert(
		run.connections,
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if runs[player] == run and not run.ending then
				place(run)
				Net.send(player, "Toast", "Close one!")
			end
		end)
	)
	task.spawn(function()
		place(run)
		if runs[player] == run then
			step(run, "Spawned")
			showNextHint(run)
		end
	end)
	print(`[TutorialService] {player.Name} started the mini-job in slot {slot}`)
	return true
end

local boot: () -> ()

-- Two jobs under one name: the server bootstrap calls Start() without a player (boot), and other services call
-- Start(player, force?) to start the mini-job for a newcomer (RoundService on join) or anyone with `force`
-- (DevTutorial). Returns true when it started; false when skipped (done before, in a crew round, no mini-job
-- map) or queued (slots full).
function TutorialService:Start(player: Player?, force: boolean?): boolean
	if player == nil then
		boot()
		return true
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not player.Parent or runs[player] then
		return false
	end
	if not force and Meta.IsTutorialDone(player) then
		return false
	end
	local activity = player:GetAttribute(Tags.Activity)
	if activity == "Crew" then
		if force then
			Net.send(player, "Toast", "Finish the job first")
		end
		return false
	end
	if type(MAP.BuildMiniJob) ~= "function" then
		if not warned then
			warned = true
			warn(
				"[TutorialService] no MapService:BuildMiniJob (mini-job map not built yet): skipping the mini-job"
			)
		end
		return false
	end
	local slot = freeSlot()
	if not slot then
		if not table.find(waiting, player) then
			table.insert(waiting, player)
			Net.send(player, "Toast", "The practice job is busy. You're next!")
		end
		return false
	end
	return begin(player, slot)
end

function TutorialService:IsInTutorial(player: Player): boolean
	return runs[player] ~= nil
end

local function serveQueue()
	while #waiting > 0 and freeSlot() do
		local player = table.remove(waiting, 1) :: Player
		if
			player.Parent
			and player:GetAttribute(Tags.Activity) == "Garage"
			and not Meta.IsTutorialDone(player)
		then
			TutorialService:Start(player)
		end
	end
end

-- Ends a run without settling (left, or after `finish`). `toGarage` = respawn the player in the Garage.
function TutorialService:Stop(player: Player, toGarage: boolean?)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	run.ending = true
	for _, connection in run.connections do
		connection:Disconnect()
	end
	if run.drivePrompt then
		run.drivePrompt:Destroy()
	end
	LootService:Clear(run.session)
	LootService:ResetSession(run.session)
	if run.guard then
		run.guard:Destroy()
	end
	if type(MAP.DestroyMiniJob) == "function" then
		pcall(MAP.DestroyMiniJob, MAP, run.slot)
	elseif run.folder.Parent then
		run.folder:Destroy()
	end
	slotOwner[run.slot] = nil
	if player.Parent then
		player:SetAttribute(Tags.Session, nil)
		player:SetAttribute(Tags.Activity, "Garage")
		player:SetAttribute(Tags.InRound, false)
		if toGarage then
			-- A fresh character clears the run's attributes; RoundService puts it in the Garage.
			task.spawn(function()
				pcall(function()
					player:LoadCharacterAsync()
				end)
			end)
		end
	end
	task.defer(serveQueue)
end

function TutorialService:Init()
	LootService.Banked:Connect(function(player: Player, _lootType: string, _value: number, session: string)
		local run = runs[player]
		if run and run.session == session then
			onBanked(run, LootService:MainBanked(session))
		end
	end)
	LootService.MainLootLifted:Connect(function(player: Player, _name: string, session: string)
		local run = runs[player]
		if run and run.session == session then
			onLifted(run)
		end
	end)
end

function boot()
	Players.PlayerRemoving:Connect(function(player)
		local index = table.find(waiting, player)
		if index then
			table.remove(waiting, index)
		end
		TutorialService:Stop(player, false)
	end)
	RunService.Heartbeat:Connect(function(dt)
		for _, run in runs do
			local ok, err = pcall(function()
				tickRun(run, dt)
			end)
			if not ok then
				warn(`[TutorialService] tick failed: {err}`)
			end
		end
	end)
	-- Newcomers who waited for a free slot.
	task.spawn(function()
		while true do
			task.wait(T.WaitCheckSeconds)
			serveQueue()
		end
	end)
end

return TutorialService
