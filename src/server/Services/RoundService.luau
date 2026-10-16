--!strict
-- The round state machine (beta-spec §1): one crew per server.
--   Garage ─(van countdown)─▶ Briefing ─(5 s)─▶ Heist ⇄ Lockdown ─(drive / police / all caught)─▶ Getaway ─▶
--   Payout ─▶ NextJob ─▶ Briefing (≥ 1 ready) or Garage. Everyone leaving mid-round aborts to the Garage.
-- Timers come from Logic/RoundClock, decisions from Logic/RoundFlow. All times are workspace:GetServerTimeNow().
--
-- * Garage: standing in the `GarageVan` zone starts the countdown (VanDepartAt). Without a Garage map (before
--   map B's Garage exists) every Garage player boards automatically after 3 s, so solo/Studio play just works.
-- * Briefing: Meta.GetSelectedJob → SetupService:Apply (builds the heist, plan, loot, other packages) → crew
--   streamed and placed at Points.Spawn, Frozen; `JobCard` to the crew.
-- * Heist/Lockdown: 8:00 cap, SHIFT CHANGE at 7:00, LOCKDOWN once (main loot lifted or alarm tier 3) = police at
--   min(round end, now + tier LockdownSeconds). HOLD TO DRIVE (`DrivePrompt` on each exit's BankZone), police
--   time, all caught (CaptureService:AllCaught, else everyone `Caught`) → Getaway. JUMP IN for late joiners.
-- * Getaway: `RoundResult` → Meta.SettleRound (once), teardown, crew back to the Garage.
--
-- Entry points (integration.md): PhaseChanged (Signal: phase), GetState(), StartLockdown(reason), GetCrew(),
-- IsCrew(player). Requests: JumpIn, NextJob, ReturnToGarage, Spectate; Studio: DevJob, DevClock, DevPhase,
-- DevRestart (+ legacy RestartRun).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)
local RoundClock = require(ReplicatedStorage.Shared.Logic.RoundClock)
local RoundFlow = require(ReplicatedStorage.Shared.Logic.RoundFlow)
local RoundStats = require(ReplicatedStorage.Shared.Logic.RoundStats)

local Server = script.Parent.Parent
local Registry = require(Server.Map.Registry)
local Meta = require(Server.Lib.Meta)
local Optional = require(Server.Lib.Optional)
local CarryService = require(script.Parent.CarryService)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)
local SetupService = require(script.Parent.SetupService)
local StatsService = require(script.Parent.StatsService)

local RoundService = {}
RoundService.PhaseChanged = Signal.new() :: Signal.Signal<string>

local R = Config.Round
local ACTIVE = { Briefing = true, Heist = true, Lockdown = true }

type Round = {
	id: string,
	job: SetupService.Job,
	info: any,
	plan: any,
	crew: { Player },
	startedAt: number?,
	roundSeconds: number,
	lockdownAt: number?,
	lockdownSeconds: number,
	lockdownReason: string?,
	shiftAnnounced: boolean,
	maxAlarm: number,
	allCaughtSince: number?,
	driveWarnAt: { [Player]: number },
	vanEnteredAt: { [Player]: number },
	inVan: { [Player]: boolean },
	outcome: string?,
	settled: boolean,
	prompts: { ProximityPrompt },
}

local phase = "Garage"
local phaseStartedAt = 0
local round: Round? = nil
local lastRound: Round? = nil
local vanDepartAt: number? = nil
local ready: { [Player]: boolean } = {}
local answered: { [Player]: boolean } = {}
local lastCrew: { Player } = {}
local requestTimes: { [Player]: { [string]: number } } = {}
local jumpInPrompt: ProximityPrompt? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function allow(player: Player, name: string, interval: number): boolean
	local times = requestTimes[player]
	if not times then
		times = {}
		requestTimes[player] = times
	end
	local t = os.clock()
	if t - (times[name] or 0) < interval then
		return false
	end
	times[name] = t
	return true
end

local function setRS(name: string, value: any)
	if ReplicatedStorage:GetAttribute(name) ~= value then
		ReplicatedStorage:SetAttribute(name, value)
	end
end

local function rootOf(player: Player?): BasePart?
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function charAttr(player: Player, name: string): any
	local character = player.Character
	return if character then character:GetAttribute(name) else nil
end

local function isCaught(player: Player): boolean
	return charAttr(player, Tags.Caught) == true or charAttr(player, Tags.Captured) ~= nil
end

local function setActivity(player: Player, activity: string)
	player:SetAttribute(Tags.Activity, activity)
	player:SetAttribute(Tags.InRound, activity ~= "Garage")
end

local function setPhase(newPhase: string)
	phase = newPhase
	phaseStartedAt = now()
	setRS(Tags.RoundPhase, newPhase)
	RoundService.PhaseChanged:Fire(newPhase)
end

local function presentCrew(): { Player }
	local list = {}
	if round then
		for _, player in round.crew do
			if player.Parent == Players then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function garagePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(Tags.Activity) == "Garage" and rootOf(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function inside(part: BasePart, position: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local function garageVan(): BasePart?
	for _, inst in CollectionService:GetTagged(Tags.GarageVan) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			return inst
		end
	end
	return nil
end

--------------------------------------------------------------------------------------------------------------
-- Placing players
--------------------------------------------------------------------------------------------------------------

local function spawnPoint(): Vector3
	local points = MapService.Points :: any
	return if points and typeof(points.Spawn) == "Vector3" then points.Spawn else Vector3.new(0, 5, 0)
end

-- Where players land in the Garage: parts/attachments named "Arrival", else the Garage SpawnLocation.
local function garageArrival(index: number): CFrame?
	local garage = workspace:FindFirstChild("Garage")
	if not garage then
		return nil
	end
	local arrivals: { CFrame } = {}
	for _, d in garage:GetDescendants() do
		if d.Name == "Arrival" then
			if d:IsA("BasePart") then
				table.insert(arrivals, d.CFrame)
			elseif d:IsA("Attachment") then
				table.insert(arrivals, d.WorldCFrame)
			end
		end
	end
	if #arrivals > 0 then
		return arrivals[(index - 1) % #arrivals + 1] + Vector3.new(0, 3, 0)
	end
	local spawn = garage:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		local offset = RoundFlow.ringOffsets(math.max(index, 1), 3)[index] or { x = 0, z = 0 }
		return spawn.CFrame + Vector3.new(offset.x, 3, offset.z)
	end
	return nil
end

-- Streams the area first (StreamingEnabled), then moves the character. Yields: call in task.spawn.
local function teleport(player: Player, cframe: CFrame)
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, R.StreamTimeout)
	end)
	local character = player.Character
	if character and character.Parent then
		character:PivotTo(cframe)
	end
end

local function placeInHeist(players: { Player }, frozen: boolean)
	local spawn = spawnPoint()
	local offsets = RoundFlow.ringOffsets(#players, 3)
	for index, player in players do
		local character = player.Character
		if character then
			character:SetAttribute(Tags.Frozen, if frozen then true else nil)
			character:SetAttribute(Tags.Masked, false)
			character:SetAttribute(Tags.Caught, nil)
			character:SetAttribute(Tags.Captured, nil)
		end
		local offset = offsets[index]
		task.spawn(teleport, player, CFrame.new(spawn + Vector3.new(offset.x, 0, offset.z)))
	end
end

local function setupCharacter(player: Player, character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end)
	character:WaitForChild("HumanoidRootPart", 10)
	task.defer(function()
		if player.Character ~= character then
			return
		end
		local activity = player:GetAttribute(Tags.Activity)
		if activity == "Crew" and ACTIVE[phase] and RoundService:IsCrew(player) then
			-- Died during the heist: back at the heist van (CaptureService puts caught players in the cell).
			if phase == "Briefing" then
				character:SetAttribute(Tags.Frozen, true)
			end
			character:SetAttribute(Tags.Masked, false)
			local spawn = spawnPoint()
			task.spawn(teleport, player, CFrame.new(spawn))
		elseif activity == "Garage" then
			local arrival = garageArrival(1)
			if arrival then
				task.spawn(teleport, player, arrival)
			end
		end
	end)
end

--------------------------------------------------------------------------------------------------------------
-- Exits and drive prompts
--------------------------------------------------------------------------------------------------------------

local function lockdownOn(): boolean
	return round ~= nil and round.lockdownAt ~= nil
end

local function exitOf(inst: Instance): Instance?
	local current: Instance? = inst
	while current and current ~= workspace do
		if CollectionService:HasTag(current, Tags.Exit) then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Can this exit be used now (bank, count as in the van, drive)?
function RoundService:IsExitUsable(exit: Instance): boolean
	if not round or not ACTIVE[phase] then
		return true
	end
	local arrives = exit:GetAttribute(Tags.ArrivesAt)
	local lockdownAt = round.lockdownAt
	return RoundFlow.exitUsable({
		quietOnly = exit:GetAttribute(Tags.QuietOnly) == true,
		lockdownOnly = exit:GetAttribute(Tags.LockdownOnly) == true,
		arrivesAt = if type(arrives) == "number" and lockdownAt then lockdownAt + arrives else nil,
	}, lockdownOn(), now())
end

local onDrive: (player: Player, exit: Instance) -> ()

local function createDrivePrompts(r: Round)
	for _, exit in r.info.exitModels do
		local zone: BasePart? = nil
		for _, d in exit:GetDescendants() do
			if d:IsA("BasePart") and CollectionService:HasTag(d, Tags.BankZone) then
				zone = d
				break
			end
		end
		if zone then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "DrivePrompt"
			prompt.ActionText = "Drive"
			local kind = exit:GetAttribute(Tags.ExitKind)
			prompt.ObjectText = if type(kind) == "string" then kind else "Van"
			prompt.HoldDuration = R.DriveHoldSeconds
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = math.max(zone.Size.X, zone.Size.Z) / 2 + 4
			prompt:SetAttribute("ContextIcon", "drive")
			prompt.Enabled = false
			prompt.Parent = zone
			prompt.Triggered:Connect(function(player: Player)
				onDrive(player, exit)
			end)
			table.insert(r.prompts, prompt)
		end
	end
end

local function updatePrompts()
	local r = round
	if r then
		local heist = phase == "Heist" or phase == "Lockdown"
		for _, prompt in r.prompts do
			if prompt.Parent then
				local exit = exitOf(prompt)
				prompt.Enabled = heist and exit ~= nil and RoundService:IsExitUsable(exit)
			end
		end
	end
	local van = garageVan()
	if van and (jumpInPrompt == nil or jumpInPrompt.Parent ~= van) then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "JumpInPrompt"
		prompt.ActionText = "Jump in"
		prompt.ObjectText = "Crew on a job"
		prompt.HoldDuration = 0
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = math.max(van.Size.X, van.Size.Z) / 2 + 4
		prompt:SetAttribute("ContextIcon", "jumpin")
		prompt.Parent = van
		prompt.Triggered:Connect(function(player: Player)
			RoundService:JumpIn(player)
		end)
		jumpInPrompt = prompt
	end
	if jumpInPrompt then
		local until_ = ReplicatedStorage:GetAttribute(Tags.JumpInUntil)
		jumpInPrompt.Enabled = (phase == "Heist" or phase == "Lockdown")
			and type(until_) == "number"
			and now() < until_
			and #presentCrew() < R.MaxCrew
	end
end

--------------------------------------------------------------------------------------------------------------
-- Settlement
--------------------------------------------------------------------------------------------------------------

local function buildResult(r: Round, outcome: string): { [string]: any }
	local crew = presentCrew()
	local awards = StatsService:Awards(crew)
	local escaped = outcome == "Escaped"
	local vanLoot = LootService:GetVanTotal("Crew")
	local mainBanked = LootService:MainBanked("Crew")
	local objectives = {}
	local ok, results = Optional.call("ObjectiveService", "GetResults")
	if ok and type(results) == "table" and r.plan then
		for _, objective in r.plan.objectives do
			if not objective.required and results[objective.id] == true then
				table.insert(objectives, { id = objective.id, bonusPct = objective.bonusPct })
			end
		end
	end
	local members = {}
	for _, player in crew do
		table.insert(members, {
			player = player,
			inVanAtEnd = escaped and r.inVan[player] == true,
			award = awards[player.UserId],
			stats = StatsService:CrewStats(player),
		})
	end
	return {
		roundId = r.id,
		heistId = r.job.heistId,
		difficulty = r.job.difficulty,
		modifierId = r.job.modifierId,
		isHotJob = r.job.isHotJob == true,
		outcome = outcome,
		vanLoot = vanLoot,
		stars = RoundStats.stars(vanLoot, mainBanked, escaped, if r.info then r.info.stars else nil),
		mainLootBanked = mainBanked,
		maxAlarmTier = r.maxAlarm,
		lockdownAtEnd = r.lockdownAt ~= nil,
		durationSeconds = if r.startedAt then math.max(0, math.floor(now() - r.startedAt)) else 0,
		objectives = objectives,
		banked = LootService:GetBanked("Crew"),
		crew = members,
	}
end

-- Once per round. `wait` = settle in this thread (shutdown); otherwise in the background (saving yields).
local function settle(r: Round, outcome: string, wait: boolean?)
	if r.settled then
		return
	end
	r.settled = true
	local result = buildResult(r, outcome)
	if wait then
		Meta.SettleRound(result)
	else
		task.spawn(Meta.SettleRound, result)
	end
end

--------------------------------------------------------------------------------------------------------------
-- Phases
--------------------------------------------------------------------------------------------------------------

local function clearTimers()
	for _, name in
		{
			Tags.RoundStartedAt,
			Tags.RoundEndsAt,
			Tags.ShiftChangeAt,
			Tags.LockdownEndsAt,
			Tags.PoliceAt,
			Tags.JumpInUntil,
			Tags.ExitArrivesAt,
			Tags.VanDepartAt,
		}
	do
		setRS(name, nil)
	end
end

local function toGarage()
	round = nil
	vanDepartAt = nil
	table.clear(ready)
	table.clear(answered)
	clearTimers()
	setPhase("Garage")
end

-- Ends a round nobody plays any more (everyone left, dev restart): no payout.
local function abort(reason: string, settleIt: boolean)
	local r = round
	if not r then
		return
	end
	if settleIt then
		settle(r, "Aborted")
	else
		r.settled = true
	end
	print(`[RoundService] round aborted: {reason}`)
	Optional.call("GuardService", "SetLockdown", false)
	SetupService:Teardown()
	CarryService:Reset()
	for _, player in r.crew do
		if player.Parent == Players then
			setActivity(player, "Garage")
			task.spawn(function()
				player:LoadCharacterAsync()
			end)
		end
	end
	lastRound = r
	toGarage()
end

local function startBriefing(boarders: { Player }, override: RoundFlow.Job?, seedOverride: number?)
	if #boarders == 0 then
		return
	end
	local crew = table.move(boarders, 1, math.min(#boarders, R.MaxCrew), 1, {})
	local id = HttpService:GenerateGUID(false)
	local picked: any = override or Meta.GetSelectedJob(crew, id)
	local job = RoundFlow.sanitizeJob(
		picked,
		Registry.Heists,
		Config.DifficultyTiers.Tiers,
		Config.Modifiers,
		Registry.DefaultHeist,
		Config.DifficultyTiers.Default
	)
	local seed = seedOverride or Random.new():NextInteger(1, 2147483646)
	local setupJob: SetupService.Job = {
		cardId = job.cardId,
		heistId = job.heistId :: string,
		difficulty = job.difficulty :: string,
		modifierId = job.modifierId,
		isHotJob = job.isHotJob,
		mostWanted = type(picked) == "table" and picked.mostWanted == true,
		seed = seed,
		crewSize = #crew,
		roundId = id,
	}
	local r: Round = {
		id = id,
		job = setupJob,
		info = nil,
		plan = nil,
		crew = crew,
		startedAt = nil,
		roundSeconds = R.RoundSeconds,
		lockdownAt = nil,
		lockdownSeconds = Config.Alarm.LockdownSeconds,
		lockdownReason = nil,
		shiftAnnounced = false,
		maxAlarm = 0,
		allCaughtSince = nil,
		driveWarnAt = {},
		vanEnteredAt = {},
		inVan = {},
		outcome = nil,
		settled = false,
		prompts = {},
	}
	round = r
	vanDepartAt = nil
	table.clear(ready)
	table.clear(answered)
	clearTimers()
	StatsService:Reset()
	LootService:ResetSession("Crew")
	CarryService:Reset()
	for _, player in crew do
		setActivity(player, "Crew")
		player:SetAttribute(Tags.SelfEscapeUsed, 0)
	end
	setRS(Tags.RoundId, id)
	setRS(Tags.HeistId, setupJob.heistId)
	setRS(Tags.Difficulty, setupJob.difficulty)
	setRS(Tags.Modifier, setupJob.modifierId)
	setRS(Tags.Approach, "Stealth")
	setRS(Tags.VanLoot, 0)
	setRS(Tags.CrewSize, #crew)
	setPhase("Briefing")

	local ok, plan, info = pcall(function()
		return SetupService:Apply(setupJob)
	end)
	if not ok then
		warn(`[RoundService] setting up {setupJob.heistId} failed: {plan}`)
		abort("setup failed", false)
		return
	end
	r.plan = plan
	r.info = info
	setRS(Tags.HeistId, setupJob.heistId)
	setRS(Tags.JobName, info.heistName)
	r.roundSeconds = RoundFlow.roundSeconds(
		R.RoundSeconds,
		info.roundSeconds,
		setupJob.modifierId,
		Config.Modifiers.RushJob.RoundSeconds
	)
	if setupJob.tier then
		r.lockdownSeconds = setupJob.tier.lockdownSeconds
	end
	createDrivePrompts(r)

	-- Gadgets: Crowbar + 2 picks with fresh charges (package C); the prototype LoadoutService resets globally.
	if not Optional.call("LoadoutService", "ResetRound", crew, setupJob) then
		Optional.call("LoadoutService", "ResetRun")
	end
	Optional.call("GadgetService", "ResetRound", crew, setupJob)

	placeInHeist(crew, true)
	local card = SetupService:JobCard()
	if card then
		for _, player in crew do
			Net.send(player, "JobCard", card)
		end
	end
	local modifierText = if setupJob.modifierId then ", " .. setupJob.modifierId else ""
	print(
		`[RoundService] job {setupJob.heistId} ({setupJob.difficulty}{modifierText}) for {#crew}, seed {seed}`
	)
end

local function startHeist()
	local r = round
	if not r then
		return
	end
	local t = now()
	r.startedAt = t
	local status = RoundClock.status(t, t, r.roundSeconds, nil, r.lockdownSeconds, R.ShiftWarningSeconds)
	setRS(Tags.RoundStartedAt, t)
	setRS(Tags.RoundEndsAt, status.roundEndsAt)
	setRS(Tags.ShiftChangeAt, status.shiftChangeAt)
	setRS(Tags.PoliceAt, status.policeAt)
	setRS(Tags.JumpInUntil, t + R.JumpInSeconds)
	setRS(Tags.LockdownEndsAt, nil)
	setPhase("Heist")
	for _, player in presentCrew() do
		local character = player.Character
		if character then
			character:SetAttribute(Tags.Frozen, nil)
		end
	end
end

local function endRound(outcome: string)
	local r = round
	if not r or r.outcome or not (phase == "Heist" or phase == "Lockdown") then
		return
	end
	r.outcome = outcome
	local t = now()
	local policeAt = ReplicatedStorage:GetAttribute(Tags.PoliceAt)
	local police = if type(policeAt) == "number" then policeAt else t
	for _, player in presentCrew() do
		r.inVan[player] = outcome == "Escaped"
			and charAttr(player, Tags.InVan) == true
			and not isCaught(player)
		local entered = r.vanEnteredAt[player]
		if r.inVan[player] and entered and RoundClock.justMadeIt(entered, police, R.JustMadeItSeconds) then
			StatsService:Event("JustMadeIt", player)
		end
		local character = player.Character
		if character then
			character:SetAttribute(Tags.Frozen, true)
		end
	end
	if outcome == "Escaped" then
		Net.broadcast("Escaped", math.max(0, police - t))
	else
		Net.broadcast("Busted")
	end
	setRS(Tags.JumpInUntil, nil)
	for _, prompt in r.prompts do
		prompt.Enabled = false
	end
	Optional.call("GuardService", "SetLockdown", false)
	setPhase("Getaway")
	settle(r, outcome)
end

local function finishGetaway()
	local r = round
	if not r then
		toGarage()
		return
	end
	SetupService:Teardown()
	CarryService:Reset()
	lastCrew = presentCrew()
	for _, player in lastCrew do
		setActivity(player, "Garage")
		-- A fresh character clears every round attribute (caught, frozen, carry …) and lands in the Garage.
		task.spawn(function()
			player:LoadCharacterAsync()
		end)
	end
	lastRound = r
	round = nil
	table.clear(ready)
	table.clear(answered)
	clearTimers()
	setPhase("Payout")
end

local function resolveNextJob()
	local boarders = {}
	for _, player in Players:GetPlayers() do
		if ready[player] and player:GetAttribute(Tags.Activity) == "Garage" then
			table.insert(boarders, player)
		end
	end
	table.clear(ready)
	table.clear(answered)
	if #boarders > 0 then
		startBriefing(boarders, nil, nil)
	else
		toGarage()
	end
end

function RoundService:StartLockdown(reason: string?): boolean
	local r = round
	if not r or phase ~= "Heist" or r.lockdownAt or not r.startedAt then
		return false
	end
	local t = now()
	r.lockdownAt = t
	r.lockdownReason = RoundFlow.lockdownReason(reason)
	local status = RoundClock.status(
		t,
		r.startedAt :: number,
		r.roundSeconds,
		t,
		r.lockdownSeconds,
		R.ShiftWarningSeconds
	)
	setRS(Tags.LockdownEndsAt, status.lockdownEndsAt)
	setRS(Tags.PoliceAt, status.policeAt)
	setRS(Tags.Approach, "Loud")
	local arrives: number? = nil
	for _, exit in r.info.exitModels do
		local seconds = exit:GetAttribute(Tags.ArrivesAt)
		if exit:GetAttribute(Tags.LockdownOnly) == true and type(seconds) == "number" then
			arrives = math.min(arrives or math.huge, t + seconds)
		end
	end
	setRS(Tags.ExitArrivesAt, arrives)
	for _, player in presentCrew() do
		local character = player.Character
		if character and Config.Features.MaskUp then
			character:SetAttribute(Tags.Masked, true)
		end
	end
	setPhase("Lockdown")
	Net.broadcast("Lockdown", status.policeAt, r.lockdownReason)
	Optional.call("GuardService", "SetLockdown", true)
	return true
end

--------------------------------------------------------------------------------------------------------------
-- Ticks
--------------------------------------------------------------------------------------------------------------

local function allCaught(crew: { Player }): boolean
	local ok, result = Optional.call("CaptureService", "AllCaught", crew)
	if ok and type(result) == "boolean" then
		return result
	end
	for _, player in crew do
		if not isCaught(player) then
			return false
		end
	end
	return #crew > 0
end

local function tickGarage(t: number)
	local players = garagePlayers()
	local van = garageVan()
	local boarders = {}
	if van then
		for _, player in players do
			local root = rootOf(player)
			if root and inside(van, root.Position) then
				table.insert(boarders, player)
			end
		end
	else
		boarders = players -- no Garage map yet: everyone boards (solo/Studio fallback)
	end
	vanDepartAt =
		RoundFlow.departAt(t, vanDepartAt, #boarders, #players, R.GarageCountdown, R.AllAboardCountdown)
	setRS(Tags.VanDepartAt, vanDepartAt)
	if vanDepartAt and t >= vanDepartAt then
		startBriefing(boarders, nil, nil)
	end
end

local function tickHeist(t: number)
	local r = round
	if not r or not r.startedAt then
		return
	end
	local crew = presentCrew()
	if #crew == 0 then
		abort("everyone left", true)
		return
	end
	local status = RoundClock.status(
		t,
		r.startedAt :: number,
		r.roundSeconds,
		r.lockdownAt,
		r.lockdownSeconds,
		R.ShiftWarningSeconds
	)
	setRS(Tags.PoliceAt, status.policeAt)
	setRS(Tags.ShiftChangeAt, status.shiftChangeAt)
	if status.shiftChange and not r.shiftAnnounced then
		r.shiftAnnounced = true
		Net.broadcast("ShiftChange", status.roundEndsAt)
	end
	local alarm = ReplicatedStorage:GetAttribute(Tags.AlarmLevel)
	if type(alarm) == "number" and alarm > r.maxAlarm then
		r.maxAlarm = alarm
	end
	for _, player in crew do
		local inVan = charAttr(player, Tags.InVan) == true
		if inVan and not r.vanEnteredAt[player] then
			r.vanEnteredAt[player] = t
		elseif not inVan then
			r.vanEnteredAt[player] = nil
		end
	end
	if status.over then
		local freeInVan = 0
		for _, player in crew do
			if charAttr(player, Tags.InVan) == true and not isCaught(player) then
				freeInVan += 1
			end
		end
		endRound(RoundFlow.policeOutcome(freeInVan))
		return
	end
	if allCaught(crew) then
		if not r.allCaughtSince then
			r.allCaughtSince = t
		elseif t - (r.allCaughtSince :: number) >= R.BustedDelay then
			endRound("Busted")
		end
	else
		r.allCaughtSince = nil
	end
end

local function tick()
	local t = now()
	local elapsed = t - phaseStartedAt
	if phase == "Garage" then
		tickGarage(t)
	elseif phase == "Briefing" then
		if elapsed >= R.BriefingSeconds then
			startHeist()
		end
	elseif phase == "Heist" or phase == "Lockdown" then
		tickHeist(t)
	elseif phase == "Getaway" then
		if elapsed >= R.GetawaySeconds then
			finishGetaway()
		end
	elseif phase == "Payout" then
		local crew, readyCount = 0, 0
		for _, player in lastCrew do
			if player.Parent == Players then
				crew += 1
				if ready[player] then
					readyCount += 1
				end
			end
		end
		if RoundFlow.payoutDone(elapsed, readyCount, crew, R.PayoutMinSeconds, R.PayoutSeconds) then
			if crew > 0 and readyCount >= crew then
				resolveNextJob()
			else
				setPhase("NextJob")
			end
		end
	elseif phase == "NextJob" then
		local crew, answeredCount = 0, 0
		for _, player in lastCrew do
			if player.Parent == Players then
				crew += 1
				if answered[player] then
					answeredCount += 1
				end
			end
		end
		if RoundFlow.nextJobDone(elapsed, answeredCount, crew, R.NextJobSeconds) then
			resolveNextJob()
		end
	end
	updatePrompts()
end

--------------------------------------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------------------------------------

onDrive = function(player: Player, exit: Instance)
	local r = round
	if not r or not (phase == "Heist" or phase == "Lockdown") or not RoundService:IsCrew(player) then
		return
	end
	if isCaught(player) or charAttr(player, Tags.InVan) ~= true or not RoundService:IsExitUsable(exit) then
		return
	end
	local outside = {}
	for _, member in presentCrew() do
		if not isCaught(member) and charAttr(member, Tags.InVan) ~= true then
			table.insert(outside, member.UserId)
		end
	end
	local t = now()
	local decision = RoundFlow.driveDecision(
		#outside,
		LootService:GetVanTotal("Crew"),
		r.driveWarnAt[player],
		t,
		R.DriveConfirmSeconds
	)
	if decision == "Warn" then
		r.driveWarnAt[player] = t
		if #outside > 0 then
			Net.send(player, "DriveWarning", outside)
		else
			Net.send(player, "Toast", "The van is empty! Hold again to leave.")
		end
		return
	end
	endRound("Escaped")
end

function RoundService:JumpIn(player: Player): boolean
	local r = round
	if not r or not r.startedAt or not (phase == "Heist" or phase == "Lockdown") then
		return false
	end
	if player:GetAttribute(Tags.Activity) ~= "Garage" or RoundService:IsCrew(player) then
		return false
	end
	if not RoundClock.canJumpIn(now(), r.startedAt :: number, R.JumpInSeconds, #presentCrew(), R.MaxCrew) then
		Net.send(player, "Toast", "Too late to jump in. Next job soon!")
		return false
	end
	table.insert(r.crew, player)
	setActivity(player, "Crew")
	player:SetAttribute(Tags.SelfEscapeUsed, 0)
	setRS(Tags.CrewSize, #presentCrew())
	if not Optional.call("LoadoutService", "ResetRound", { player }, r.job) then
		Optional.call("LoadoutService", "ResetRun")
	end
	Optional.call("GadgetService", "ResetRound", { player }, r.job)
	placeInHeist({ player }, false)
	Meta.RoundStep(player, r.id, "VanDeparted")
	Net.broadcast("Toast", `{player.DisplayName} jumped in!`)
	return true
end

local function onNextJob(player: Player)
	if not allow(player, "NextJob", 0.5) or not (phase == "Payout" or phase == "NextJob") then
		return
	end
	if player:GetAttribute(Tags.Activity) ~= "Garage" then
		return
	end
	ready[player] = true
	answered[player] = true
end

local function onReturnToGarage(player: Player)
	if not allow(player, "ReturnToGarage", 0.5) or not (phase == "Payout" or phase == "NextJob") then
		return
	end
	ready[player] = nil
	answered[player] = true
end

local function onSpectate(player: Player, userId: any)
	if type(userId) ~= "number" or not allow(player, "Spectate", 1) then
		return
	end
	if not ACTIVE[phase] or player:GetAttribute(Tags.Activity) ~= "Garage" then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	local root = rootOf(target)
	if not target or not root or not RoundService:IsCrew(target) then
		return
	end
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(root.Position, 2)
		end)
	end)
end

--------------------------------------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------------------------------------

function RoundService:GetState(): { [string]: any }
	local r = round
	return {
		phase = phase,
		phaseStartedAt = phaseStartedAt,
		roundId = if r then r.id else nil,
		heistId = if r then r.job.heistId else nil,
		difficulty = if r then r.job.difficulty else nil,
		modifierId = if r then r.job.modifierId else nil,
		isHotJob = if r then r.job.isHotJob == true else false,
		startedAt = if r then r.startedAt else nil,
		roundSeconds = if r then r.roundSeconds else nil,
		lockdown = r ~= nil and r.lockdownAt ~= nil,
		lockdownAt = if r then r.lockdownAt else nil,
		lockdownReason = if r then r.lockdownReason else nil,
		policeAt = ReplicatedStorage:GetAttribute(Tags.PoliceAt),
		job = if r then r.job else nil,
		crew = presentCrew(),
	}
end

function RoundService:GetCrew(): { Player }
	return presentCrew()
end

function RoundService:IsCrew(player: Player): boolean
	return round ~= nil and table.find((round :: Round).crew, player) ~= nil
end

function RoundService:GetPhase(): string
	return phase
end

-- Studio --------------------------------------------------------------------------------------------------

function RoundService:DevJob(heistId: string?, difficulty: string?, modifierId: string?, seed: number?)
	local players = presentCrew()
	for _, player in garagePlayers() do
		if not table.find(players, player) then
			table.insert(players, player)
		end
	end
	if round and phase ~= "Getaway" then
		abort("dev job", false)
	elseif round then
		finishGetaway()
	end
	startBriefing(players, {
		heistId = heistId or (if lastRound then lastRound.job.heistId else nil),
		difficulty = difficulty,
		modifierId = modifierId,
		isHotJob = false,
	}, seed)
end

function RoundService:DevClock(elapsed: number)
	local r = round
	if not r or not r.startedAt then
		return
	end
	local t = now()
	r.startedAt = t - elapsed
	local status = RoundClock.status(
		t,
		r.startedAt :: number,
		r.roundSeconds,
		r.lockdownAt,
		r.lockdownSeconds,
		R.ShiftWarningSeconds
	)
	r.shiftAnnounced = status.shiftChangeAt ~= nil and t >= (status.shiftChangeAt :: number) + 1
	setRS(Tags.RoundStartedAt, r.startedAt)
	setRS(Tags.RoundEndsAt, status.roundEndsAt)
	setRS(Tags.JumpInUntil, (r.startedAt :: number) + R.JumpInSeconds)
end

function RoundService:DevPhase(target: string)
	if target == "Lockdown" then
		RoundService:StartLockdown("dev")
	elseif target == "Getaway" or target == "Escaped" then
		endRound("Escaped")
	elseif target == "Busted" then
		endRound("Busted")
	elseif target == "Payout" and phase == "Getaway" then
		finishGetaway()
	elseif target == "NextJob" and phase == "Payout" then
		setPhase("NextJob")
	elseif target == "Garage" then
		if round then
			abort("dev", false)
		else
			toGarage()
		end
	elseif target == "Briefing" then
		RoundService:DevJob(nil, nil, nil, nil)
	end
end

function RoundService:DevRestart()
	local job = if round then round.job elseif lastRound then lastRound.job else nil
	RoundService:DevJob(
		if job then job.heistId else nil,
		if job then job.difficulty else nil,
		if job then job.modifierId else nil,
		nil
	)
end

--------------------------------------------------------------------------------------------------------------

-- Prototype guards (before package B's CaptureService): caught = drop the loot, back to the van after 1.2 s.
local function fallbackCapture(player: Player)
	local character = player.Character
	if not character or character:GetAttribute(Tags.Caught) or not RoundService:IsCrew(player) then
		return
	end
	if not (phase == "Heist" or phase == "Lockdown") then
		return
	end
	character:SetAttribute(Tags.Caught, true)
	CarryService:DropAll(player, "capture")
	StatsService:Event("Caught", player)
	Optional.call("GadgetService", "RecallDrone", player, "")
	Net.broadcast("Toast", `{player.DisplayName} got caught!`)
	task.delay(1.2, function()
		if player.Parent and player.Character == character then
			character:SetAttribute(Tags.Caught, nil)
			character:SetAttribute(Tags.Crouching, false)
			character:SetAttribute(Tags.ImmuneUntil, now() + Config.Capture.ImmuneSeconds)
			if ACTIVE[phase] then
				character:PivotTo(CFrame.new(spawnPoint()))
			end
		end
	end)
end

function RoundService:Init()
	setRS(Tags.RoundPhase, "Garage")
	setRS(Tags.VanLoot, 0)
	setRS(Tags.CrewSize, 0)
	setRS(Tags.Approach, "Stealth")
	phaseStartedAt = now()
	LootService.ZoneFilter = function(zone: BasePart): boolean
		local exit = exitOf(zone)
		return exit == nil or RoundService:IsExitUsable(exit)
	end
end

function RoundService:Start()
	LootService.MainLootLifted:Connect(function(_player: Player, _name: string, session: string)
		if session == "Crew" then
			RoundService:StartLockdown("main")
		end
	end)
	local alarm = Optional.get("AlarmService")
	if alarm and type(alarm.LevelChanged) == "table" then
		alarm.LevelChanged:Connect(function(level: number)
			if type(level) == "number" and level >= 3 then
				RoundService:StartLockdown("alarm")
			end
		end)
	end
	if not Optional.get("CaptureService") and Optional.has("GuardService", "OnCapture") then
		Optional.call("GuardService", "OnCapture", fallbackCapture)
	end

	Net.onRequest("JumpIn", function(player: Player)
		if allow(player, "JumpIn", 0.5) then
			RoundService:JumpIn(player)
		end
	end)
	Net.onRequest("NextJob", onNextJob)
	Net.onRequest("ReturnToGarage", onReturnToGarage)
	Net.onRequest("Spectate", onSpectate)
	if RunService:IsStudio() then
		Net.onRequest(
			"DevJob",
			function(_player: Player, heistId: any, difficulty: any, modifierId: any, seed: any)
				RoundService:DevJob(
					if type(heistId) == "string" then heistId else nil,
					if type(difficulty) == "string" then difficulty else nil,
					if type(modifierId) == "string" then modifierId else nil,
					if type(seed) == "number" then seed else nil
				)
			end
		)
		Net.onRequest("DevClock", function(_player: Player, elapsed: any)
			if type(elapsed) == "number" then
				RoundService:DevClock(elapsed)
			end
		end)
		Net.onRequest("DevPhase", function(_player: Player, target: any)
			if type(target) == "string" then
				RoundService:DevPhase(target)
			end
		end)
		Net.onRequest("DevRestart", function()
			RoundService:DevRestart()
		end)
		Net.onRequest("RestartRun", function() -- prototype HUD key P (ux removes it)
			RoundService:DevRestart()
		end)
	end

	local function onPlayer(player: Player)
		setActivity(player, "Garage")
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
		if player.Character then
			task.spawn(setupCharacter, player, player.Character)
		end
		task.spawn(function()
			-- New players start in the mini-job (package C's TutorialService) once their data is in.
			if Optional.has("TutorialService", "Start") and Meta.WaitForData(player, 30) then
				if player.Parent and not Meta.IsTutorialDone(player) then
					Optional.call("TutorialService", "Start", player)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		answered[player] = nil
		requestTimes[player] = nil
		local r = round
		if r then
			local index = table.find(r.crew, player)
			if index then
				table.remove(r.crew, index)
				setRS(Tags.CrewSize, #presentCrew())
			end
		end
	end)

	Meta.OnBeforeShutdown(function()
		local r = round
		if r and not r.settled and ACTIVE[phase] then
			settle(r, "Shutdown", true)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			xpcall(tick, function(err)
				warn(`[RoundService] tick failed: {err}\n{debug.traceback()}`)
			end)
		end
	end)
end

return RoundService
