--!strict
-- Objectives beyond loot (beta-spec §7.3 and §13): the keycard, the optional safe with the Cheese Grater 3000,
-- and radio checks after a guard is bubbled.
--
--   Keycard     Required for its `KeycardDoor` (attribute `Card` = objective id). It lies on one of the
--               `Group = "Keycard"` anchors, or (50%) hangs on a guard: pickpocket it by holding USE behind him
--               for 1.5 s while he is not suspicious of you. It is small loot (a pocket slot) and drops when you
--               are caught. The door opens with a 1 s hold while it is in your pocket (`KeycardPrompt`).
--   Safe        Optional (+10%, max 1 per heist). Hold 2 s with empty hands at the `DeviceSpot` to place the
--               device (`DevicePrompt`); it runs `job.tier.deviceSeconds` (Easy 35 / Normal 45 / Hard 55), jams
--               1–2 times (plan.jamPoints, Logic/CrackDevice) and beeps every 3 s while jammed (noise radius 12)
--               until anyone holds "Restart" for 1.5 s. Done: the safe opens and its loot spawns.
--   Radio check Normal and Hard: 4 s after a guard is bubbled his radio squawks; a crew member holds "Answer" for
--               2 s within 6 s (`RadioPrompt`) → no alarm points. Missed → +40. Max 2 answers per round; then every
--               bubble costs +40. Logic/RadioCheck; this service takes over GuardService's +10 prank points.
--
-- Entry points (integration.md): Setup(plan, heistInfo, job), Clear(), GetResults() → {[id] = true when done}
-- (RoundService adds each done optional objective's bonusPct to RoundResult.objectives). Also
-- OnGuardBubbled(model, by) (GuardService.Bubbled does this already). Net: `Objective(id, state, data)` and
-- `RadioCheck(guardPos, endsAt, answersLeft)` to the crew.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local CrackDevice = require(ReplicatedStorage.Shared.Logic.CrackDevice)
local Difficulty = require(ReplicatedStorage.Shared.Logic.Difficulty)
local RadioCheck = require(ReplicatedStorage.Shared.Logic.RadioCheck)

local AlarmService = require(script.Parent.AlarmService)
local CarryService = require(script.Parent.CarryService)
local GuardService = require(script.Parent.GuardService)
local LootService = require(script.Parent.LootService)
local StatsService = require(script.Parent.StatsService)

local ObjectiveService = {}

local O = Config.Objectives
local KEYCARD = "Keycard"
local DEVICE_NAME = "Cheese Grater 3000"

type Objective = {
	id: string,
	type: string, -- "Keycard" | "Safe"
	required: boolean,
	bonusPct: number,
	state: string, -- "Locked" | "Active" | "Running" | "Jammed" | "Done" | "Failed"
	data: { [string]: any },
	-- keycard
	onGuard: boolean?,
	guard: Model?,
	guardTag: BasePart?,
	pickPrompt: ProximityPrompt?,
	holderId: number?,
	doors: { Instance },
	doorPrompts: { ProximityPrompt },
	-- safe
	safe: Instance?,
	spot: CFrame?,
	devicePrompt: ProximityPrompt?,
	device: Model?,
	deviceLight: BasePart?,
	crack: CrackDevice.State?,
	jamPoints: { number },
	loot: { any }?,
	lastSnapshot: number,
}

local objectives: { Objective } = {}
local results: { [string]: boolean } = {}
local info: any = nil
local active = false
local radio: RadioCheck.State? = nil
local radioPrompts: { [string]: ProximityPrompt } = {}
local guardIds: { [Model]: string } = {}
local guardsById: { [string]: Model } = {}
local nextGuardId = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isCrew(player: Player): boolean
	return player:GetAttribute(Tags.Activity) == "Crew"
end

local function crew(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if isCrew(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function sendCrew(name: string, ...: any)
	for _, player in crew() do
		Net.send(player, name, ...)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A crew member who can act now (not caught, hidden, frozen or bubbled).
local function free(player: Player): boolean
	local character = player.Character
	if not character or not isCrew(player) or not rootOf(player) then
		return false
	end
	for _, name in { Tags.Caught, Tags.Captured, Tags.Hidden, Tags.Frozen, Tags.Bubbled } do
		local value = character:GetAttribute(name)
		if value ~= nil and value ~= false then
			return false
		end
	end
	return true
end

local function stat(name: string, player: Player)
	local ok, err = pcall(function()
		(StatsService :: any):Event(name, player)
	end)
	if not ok then
		warn(`[ObjectiveService] stat {name} failed: {err}`)
	end
end

local function makePrompt(
	name: string,
	action: string,
	object: string,
	hold: number,
	icon: string,
	parent: Instance
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = O.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ContextIcon", icon)
	prompt.Parent = parent
	return prompt
end

local function firstPart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") and inst.PrimaryPart then
		return inst.PrimaryPart
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function displayName(objective: Objective): string
	return if objective.type == KEYCARD then "Keycard door" else "Crack the safe"
end

-- The `Objective` snapshot (contracts §1.2) to the crew, or to one player.
local function snapshot(objective: Objective, to: Player?)
	local data = table.clone(objective.data)
	data.name = displayName(objective)
	data.type = objective.type
	data.required = objective.required
	data.bonusPct = objective.bonusPct
	if to then
		Net.send(to, "Objective", objective.id, objective.state, data)
	else
		sendCrew("Objective", objective.id, objective.state, data)
	end
end

local function setState(objective: Objective, state: string)
	objective.state = state
	objective.lastSnapshot = os.clock()
	snapshot(objective)
end

local function complete(objective: Objective)
	if results[objective.id] then
		return
	end
	results[objective.id] = true
	objective.data.progress = 1
	setState(objective, "Done")
end

--------------------------------------------------------------------------------------------------------------
-- Keycard
--------------------------------------------------------------------------------------------------------------

local function doorParts(door: Instance): { BasePart }
	if door:IsA("BasePart") then
		return { door }
	end
	local named = {}
	for _, d in door:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Door" or d.Name == "Gate" or d.Name == "Slab") then
			table.insert(named, d)
		end
	end
	if #named > 0 then
		return named
	end
	local solid = {}
	for _, d in door:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.CanCollide
			and d.Name ~= "Reader"
			and d.Name ~= "Lamp"
			and d.Name ~= "Frame"
		then
			table.insert(solid, d)
		end
	end
	return solid
end

-- Slides the door up and out of the way.
local function openDoor(door: Instance)
	if door:GetAttribute(Tags.DoorState) == "Open" then
		return
	end
	door:SetAttribute(Tags.DoorState, "Open")
	for _, part in doorParts(door) do
		part.CanCollide = false
		part.CanQuery = false
		local target = part.CFrame + Vector3.new(0, part.Size.Y + 0.2, 0)
		TweenService
			:Create(part, TweenInfo.new(O.DoorOpenSeconds, Enum.EasingStyle.Quad), { CFrame = target })
			:Play()
	end
	local lamp = door:FindFirstChild("Lamp", true)
	if lamp and lamp:IsA("BasePart") then
		lamp.Color = Color3.fromRGB(80, 230, 110)
	end
	local part = firstPart(door)
	if part then
		local beep = Instance.new("Sound")
		beep.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		beep.PlaybackSpeed = 1.4
		beep.Parent = part
		beep:Play()
		task.delay(2, function()
			beep:Destroy()
		end)
	end
end

local function onKeycardDoor(objective: Objective, door: Instance, player: Player)
	if not active or not free(player) then
		return
	end
	if not CarryService:HasLootType(player, KEYCARD) then
		Net.send(player, "Toast", "Needs the KEYCARD")
		return
	end
	openDoor(door)
	for _, prompt in objective.doorPrompts do
		if prompt.Parent and prompt:IsDescendantOf(door) then
			prompt.Enabled = false
		end
	end
	sendCrew("Toast", `{player.DisplayName} opened the keycard door!`)
	complete(objective)
end

local function hookDoors(objective: Objective, keycardCount: number)
	local level = info and info.level
	for _, door in CollectionService:GetTagged(Tags.KeycardDoor) do
		local inLevel = level == nil or door:IsDescendantOf(level)
		local card = door:GetAttribute(Tags.Card)
		local matches = card == objective.id or (card == nil and keycardCount == 1)
		if inLevel and matches then
			table.insert(objective.doors, door)
			local reader = door:FindFirstChild("Reader", true)
			local parent = if reader and reader:IsA("BasePart") then reader else firstPart(door)
			if parent then
				local prompt =
					makePrompt("KeycardPrompt", "Open", "Keycard door", O.KeycardHold, "keycard", parent)
				prompt.Triggered:Connect(function(player)
					onKeycardDoor(objective, door, player)
				end)
				table.insert(objective.doorPrompts, prompt)
			end
		end
	end
	if #objective.doors == 0 and RunService:IsStudio() then
		warn(`[ObjectiveService] keycard {objective.id}: no KeycardDoor with Card = "{objective.id}"`)
	end
end

local function removePickpocket(objective: Objective)
	if objective.pickPrompt then
		objective.pickPrompt:Destroy()
		objective.pickPrompt = nil
	end
	if objective.guardTag then
		objective.guardTag:Destroy()
		objective.guardTag = nil
	end
end

-- Spawns the keycard at the player's feet and pockets it (a full pocket leaves it on the floor).
local function giveKeycard(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end
	local loot = LootService:SpawnAt(
		KEYCARD,
		CFrame.new(root.Position - Vector3.new(0, 3, 0)),
		"Crew",
		nil,
		(info and info.level) or workspace:FindFirstChild("Level") or workspace
	)
	local handler = LootService.OnPrompt
	if handler then
		handler(player, loot)
	end
end

-- Behind the guard (outside his front half) and he is not suspicious of you.
local function canPickpocket(player: Player, guard: Model): boolean
	local root = rootOf(player)
	local guardRoot = guard:FindFirstChild("HumanoidRootPart") or guard.PrimaryPart
	if not root or not guardRoot or not guardRoot:IsA("BasePart") then
		return false
	end
	local toPlayer = root.Position - guardRoot.Position
	local flat = Vector3.new(toPlayer.X, 0, toPlayer.Z)
	if flat.Magnitude < 0.1 then
		return false
	end
	local look = guardRoot.CFrame.LookVector
	local behind = Vector3.new(look.X, 0, look.Z).Unit:Dot(flat.Unit) < 0
	local state = guard:GetAttribute(Tags.GuardState)
	local meter = (GuardService :: any):MeterOn(player)
	local calm = state ~= "Alert"
		and state ~= "Carrying"
		and (type(meter) ~= "number" or meter < Config.Guard.SuspiciousAt)
	return behind and calm
end

local function hangOnGuard(objective: Objective, guard: Model)
	local guardRoot = guard:FindFirstChild("HumanoidRootPart") or guard.PrimaryPart
	if not guardRoot or not guardRoot:IsA("BasePart") then
		return
	end
	objective.guard = guard
	-- A keycard on a lanyard at his belt, on his back.
	local tag = Instance.new("Part")
	tag.Name = "KeycardTag"
	tag.Size = Vector3.new(0.8, 1.1, 0.1)
	tag.Color = Color3.fromRGB(70, 140, 255)
	tag.Material = Enum.Material.Neon
	tag.CanCollide = false
	tag.CanQuery = false
	tag.CanTouch = false
	tag.Massless = true
	tag.CFrame = guardRoot.CFrame * CFrame.new(0.6, -0.6, 0.65)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = guardRoot
	weld.Part1 = tag
	weld.Parent = tag
	tag.Parent = guard
	objective.guardTag = tag
	local prompt =
		makePrompt("PickpocketPrompt", "Pickpocket", "Keycard", O.PickpocketHold, "pickpocket", tag)
	prompt.MaxActivationDistance = 5
	prompt.Triggered:Connect(function(player)
		if not active or not free(player) or objective.guardTag == nil then
			return
		end
		if CarryService:HandsFull(player) then
			Net.send(player, "Toast", "Hands full!")
			return
		end
		if not canPickpocket(player, guard) then
			Net.send(player, "Toast", "He'd notice! Get behind him.")
			return
		end
		removePickpocket(objective)
		objective.onGuard = false
		objective.data.onGuard = false
		giveKeycard(player)
		snapshot(objective)
	end)
	objective.pickPrompt = prompt
end

local function setupKeycard(objective: Objective, plan: any, keycardCount: number)
	hookDoors(objective, keycardCount)
	if plan.onGuard and plan.guardIndex then
		local guard = (GuardService :: any):GetGuardModel(plan.guardIndex)
		if guard then
			objective.onGuard = true
			objective.data.onGuard = true
			hangOnGuard(objective, guard)
			return
		end
	end
	local anchorId = plan.anchorId
	if anchorId == nil and plan.anchors and #plan.anchors > 0 then
		anchorId = plan.anchors[1] -- the keycard was meant for a guard who did not spawn
	end
	if anchorId then
		LootService:Spawn({ { anchorId = anchorId, type = KEYCARD, class = "Small" } }, info)
	elseif RunService:IsStudio() then
		warn(`[ObjectiveService] keycard {objective.id}: no anchor and no guard`)
	end
	objective.data.onGuard = false
end

-- Who has the card now (holderId in the snapshot).
local function updateHolders()
	for _, objective in objectives do
		if objective.type == KEYCARD and objective.state ~= "Done" then
			local holder: number? = nil
			for _, player in crew() do
				if CarryService:HasLootType(player, KEYCARD) then
					holder = player.UserId
					break
				end
			end
			if holder ~= objective.holderId then
				objective.holderId = holder
				objective.data.holderId = holder
				snapshot(objective)
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Safe + Cheese Grater 3000
--------------------------------------------------------------------------------------------------------------

-- The anchor Group of an objective in the heist definition (default: its id).
local function groupOf(id: string): string
	local defs = if info and type(info.objectives) == "table" then info.objectives else {}
	for _, def in defs do
		if def.Id == id then
			return if type(def.Group) == "string" then def.Group else id
		end
	end
	return id
end

local function findSafe(objective: Objective, groupName: string, safeCount: number): Instance?
	local level = info and info.level
	local candidates = {}
	for _, safe in CollectionService:GetTagged(Tags.Safe) do
		if level == nil or safe:IsDescendantOf(level) then
			table.insert(candidates, safe)
		end
	end
	for _, safe in candidates do
		for _, key in { "SafeId", "Group", "Id", Tags.AnchorId } do
			local value = safe:GetAttribute(key)
			if value == groupName or value == objective.id then
				return safe
			end
		end
		if safe.Name == groupName or safe.Name == objective.id then
			return safe
		end
	end
	if #candidates == 1 and safeCount == 1 then
		return candidates[1]
	end
	return nil
end

local function buildDevice(spot: CFrame, parent: Instance): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "CheeseGrater3000"
	local props = ServerStorage:FindFirstChild("Props")
	local template = props and props:FindFirstChild("CheeseGrater")
	local body: BasePart
	if template and template:IsA("Model") then
		local clone = template:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			elseif d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		clone:PivotTo(spot)
		clone.Parent = model
		local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
		body = root :: BasePart
	else
		local part = Instance.new("Part")
		part.Name = "Body"
		part.Size = Vector3.new(2, 2.5, 1.5)
		part.Color = Color3.fromRGB(150, 155, 165)
		part.Material = Enum.Material.Metal
		part.Anchored = true
		part.CanCollide = false
		part.CFrame = spot * CFrame.new(0, 1.25, 0)
		part.Parent = model
		body = part
	end
	local light = Instance.new("Part")
	light.Name = "Light"
	light.Shape = Enum.PartType.Ball
	light.Size = Vector3.new(0.6, 0.6, 0.6)
	light.Material = Enum.Material.Neon
	light.Color = Color3.fromRGB(80, 230, 110)
	light.Anchored = true
	light.CanCollide = false
	light.CanQuery = false
	light.CFrame = body.CFrame * CFrame.new(0, body.Size.Y / 2 + 0.3, 0)
	light.Parent = model
	local glow = Instance.new("PointLight")
	glow.Range = 6
	glow.Color = light.Color
	glow.Parent = light
	model.Parent = parent
	return model, light
end

local function setDeviceLight(objective: Objective, color: Color3)
	local light = objective.deviceLight
	if light then
		light.Color = color
		local glow = light:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Color = color
		end
	end
end

local function beep(objective: Objective)
	local spot = objective.spot
	if not spot then
		return
	end
	local light = objective.deviceLight
	if light then
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sound.PlaybackSpeed = 0.8
		sound.Volume = 1
		sound.RollOffMaxDistance = O.BeepRadius * 3
		sound.Parent = light
		sound:Play()
		task.delay(2, function()
			sound:Destroy()
		end)
	end
	(GuardService :: any):HearNoise(spot.Position, O.BeepRadius, nil, "beep")
end

local function openSafe(objective: Objective)
	local safe = objective.safe
	if safe then
		safe:SetAttribute(Tags.DoorState, "Open")
		local door = safe:FindFirstChild("Door", true)
		if door and door:IsA("BasePart") then
			door.CanCollide = false
			local hinge = door.CFrame * CFrame.new(-door.Size.X / 2, 0, 0)
			local opened = hinge * CFrame.Angles(0, math.rad(-110), 0) * CFrame.new(door.Size.X / 2, 0, 0)
			TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Back), { CFrame = opened }):Play()
		end
	end
	if objective.loot and #objective.loot > 0 then
		LootService:Spawn(objective.loot, info)
	end
	if objective.device then
		local device = objective.device
		task.delay(2, function()
			device:Destroy()
		end)
		objective.device = nil
	end
	if objective.devicePrompt then
		objective.devicePrompt:Destroy()
		objective.devicePrompt = nil
	end
	sendCrew("Toast", `SAFE OPEN! +{math.floor(objective.bonusPct * 100 + 0.5)}%`)
	complete(objective)
end

local function jamsLeft(objective: Objective): number
	local crack = objective.crack
	return #objective.jamPoints - (if crack then crack.jamsHit else 0)
end

local function onDevicePrompt(objective: Objective, player: Player)
	if not active or not free(player) or objective.state == "Done" then
		return
	end
	local prompt = objective.devicePrompt
	if not prompt then
		return
	end
	if objective.crack == nil then
		-- Place the device.
		if CarryService:HandsFull(player) then
			Net.send(player, "Toast", "Hands full!")
			return
		end
		local spot = objective.spot :: CFrame
		local parent = (info and info.level) or workspace
		objective.device, objective.deviceLight = buildDevice(spot, parent)
		objective.crack = CrackDevice.new(objective.data.seconds, O.BeepInterval)
		objective.data.holderId = player.UserId
		objective.data.progress = 0
		objective.data.jamsLeft = jamsLeft(objective)
		prompt.Enabled = false
		prompt.ActionText = "Restart"
		prompt.HoldDuration = O.DeviceRestart
		sendCrew("Toast", `{player.DisplayName} placed the {DEVICE_NAME}`)
		setState(objective, "Running")
	elseif objective.crack.jammed then
		objective.crack = CrackDevice.restart(objective.crack)
		stat("DeviceRestart", player) -- Safecracker award
		prompt.Enabled = false
		setDeviceLight(objective, Color3.fromRGB(80, 230, 110))
		objective.data.holderId = player.UserId
		setState(objective, "Running")
	end
end

local function setupSafe(objective: Objective, plan: any, safeCount: number, tierSeconds: number)
	objective.jamPoints = plan.jamPoints or {}
	objective.loot = plan.loot
	objective.data.seconds = tierSeconds
	objective.data.jamsLeft = #objective.jamPoints
	objective.data.progress = 0
	local safe = findSafe(objective, groupOf(objective.id), safeCount)
	if not safe then
		if RunService:IsStudio() then
			warn(`[ObjectiveService] safe {objective.id}: no Safe in the level`)
		end
		objective.state = "Failed"
		return
	end
	objective.safe = safe
	local spotAttachment = safe:FindFirstChild("DeviceSpot", true)
	local promptParent: Instance? = nil
	if spotAttachment and spotAttachment:IsA("Attachment") then
		objective.spot = spotAttachment.WorldCFrame
		promptParent = spotAttachment
	else
		local part = firstPart(safe)
		if part then
			objective.spot = part.CFrame * CFrame.new(0, -part.Size.Y / 2, -part.Size.Z / 2 - 1.5)
			promptParent = part
		end
	end
	if not promptParent then
		objective.state = "Failed"
		return
	end
	local prompt = makePrompt("DevicePrompt", "Place", DEVICE_NAME, O.DevicePlace, "device", promptParent)
	prompt.Triggered:Connect(function(player)
		onDevicePrompt(objective, player)
	end)
	objective.devicePrompt = prompt
end

local function stepDevices(dt: number)
	for _, objective in objectives do
		local crack = objective.crack
		if objective.type == "Safe" and crack and not crack.done then
			local newState, events = CrackDevice.step(crack, dt, objective.jamPoints)
			objective.crack = newState
			objective.data.progress = math.floor(newState.progress * 100 + 0.5) / 100
			objective.data.jamsLeft = jamsLeft(objective)
			for _, event in events do
				if event == "jammed" then
					setDeviceLight(objective, Color3.fromRGB(255, 60, 60))
					if objective.devicePrompt then
						objective.devicePrompt.Enabled = true
					end
					sendCrew("Toast", `The {DEVICE_NAME} jammed! Hold RESTART`)
					setState(objective, "Jammed")
				elseif event == "beep" then
					beep(objective)
				elseif event == "done" then
					openSafe(objective)
				end
			end
			if objective.state == "Running" and os.clock() - objective.lastSnapshot >= O.ProgressInterval then
				objective.lastSnapshot = os.clock()
				snapshot(objective)
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Radio checks
--------------------------------------------------------------------------------------------------------------

local function guardId(model: Model): string
	local existing = guardIds[model]
	if existing then
		return existing
	end
	nextGuardId += 1
	local id = `G{nextGuardId}`
	guardIds[model] = id
	guardsById[id] = model
	return id
end

local function guardRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return if root and root:IsA("BasePart") then root else nil
end

local function removeRadioPrompt(id: string)
	local prompt = radioPrompts[id]
	radioPrompts[id] = nil
	if prompt then
		prompt:Destroy()
	end
end

local function addAlarm(reason: string, points: number)
	if points > 0 then
		AlarmService:Add(reason, points)
	end
end

-- A guard was bubbled (GuardService.Bubbled, or called directly). Starts a radio check on Normal/Hard.
function ObjectiveService:OnGuardBubbled(model: Model, _by: Player?)
	local state = radio
	if not active or not state or typeof(model) ~= "Instance" then
		return
	end
	RadioCheck.bubbled(state, guardId(model), now())
end

local function onAnswer(id: string, player: Player)
	local state = radio
	if not active or not state or not free(player) then
		return
	end
	if RadioCheck.answer(state, id, now()) then
		removeRadioPrompt(id)
		sendCrew("Toast", `{player.DisplayName} on the radio: "All quiet here!"`)
		RadioCheck.forget(state, id)
	end
end

local function squawk(state: RadioCheck.State, id: string)
	local model = guardsById[id]
	local root = model and model.Parent and guardRoot(model)
	if not model or not root then
		RadioCheck.cancel(state, id)
		return
	end
	local result, points = RadioCheck.squawk(state, id, now())
	if result == "NoAnswers" then
		addAlarm("RadioMissed", points)
		sendCrew("Toast", 'Radio: "Unit 3, report!" Nobody can answer anymore...')
	elseif result == "Window" then
		local check = state.checks[id]
		local endsAt = (check and check.endsAt) or (now() + O.RadioWindow)
		local prompt = makePrompt("RadioPrompt", "Answer", "Radio", O.RadioAnswerHold, "radio", root)
		prompt.Triggered:Connect(function(player)
			onAnswer(id, player)
		end)
		radioPrompts[id] = prompt
		sendCrew("RadioCheck", root.Position, endsAt, state.answersLeft)
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sound.PlaybackSpeed = 0.6
		sound.Parent = root
		sound:Play()
		task.delay(2, function()
			sound:Destroy()
		end)
	end
end

local function stepRadio()
	local state = radio
	if not active or not state then
		return
	end
	local t = now()
	for _, id in RadioCheck.due(state, t) do
		squawk(state, id)
	end
	local expired, points = RadioCheck.expire(state, t)
	if #expired > 0 then
		for _, id in expired do
			removeRadioPrompt(id)
			RadioCheck.forget(state, id)
		end
		addAlarm("RadioMissed", points)
		sendCrew("Toast", "Missed the radio check!")
	end
end

-- GuardService calls this instead of adding its +10 when a bubble pops.
local function onPrankPoints(model: Model)
	local state = radio
	if not active or not state then
		AlarmService:Add("PrankUsed")
		return
	end
	local id = guardId(model)
	addAlarm("PrankUsed", RadioCheck.popped(state, id))
	RadioCheck.forget(state, id)
end

--------------------------------------------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------------------------------------------

local function radioEnabled(job: any): boolean
	if not Config.Features.Objectives then
		return false
	end
	local tier = type(job) == "table" and job.tier
	if type(tier) == "table" and type(tier.radioChecks) == "boolean" then
		return tier.radioChecks
	end
	local row =
		Difficulty.tier(Config.DifficultyTiers :: any, if type(job) == "table" then job.difficulty else nil)
	return row.RadioChecks
end

local function deviceSeconds(job: any): number
	local tier = type(job) == "table" and job.tier
	if Config.Features.Difficulty and type(tier) == "table" and type(tier.deviceSeconds) == "number" then
		return tier.deviceSeconds
	end
	return O.DeviceSeconds
end

-- SetupService, after the guards spawned: the plan's objectives, the round's radio checks.
function ObjectiveService:Setup(plan: any, heistInfo: any, job: any)
	ObjectiveService:Clear()
	table.clear(results)
	info = heistInfo
	active = true
	radio = RadioCheck.new(radioEnabled(job), RadioCheck.rulesFrom(Config))
	if not Config.Features.Objectives or type(plan) ~= "table" or type(plan.objectives) ~= "table" then
		return
	end
	local keycards, safes = 0, 0
	for _, def in plan.objectives do
		if def.type == KEYCARD then
			keycards += 1
		elseif def.type == "Safe" then
			safes += 1
		end
	end
	for _, def in plan.objectives do
		if type(def) ~= "table" or type(def.id) ~= "string" then
			continue
		end
		local objective: Objective = {
			id = def.id,
			type = def.type,
			required = def.required == true,
			bonusPct = if type(def.bonusPct) == "number" then def.bonusPct else 0,
			state = "Active",
			data = {},
			doors = {},
			doorPrompts = {},
			jamPoints = {},
			lastSnapshot = 0,
		}
		local ok, err = pcall(function()
			if def.type == KEYCARD then
				setupKeycard(objective, def, keycards)
			elseif def.type == "Safe" then
				setupSafe(objective, def, safes, deviceSeconds(job))
			end
		end)
		if not ok then
			warn(`[ObjectiveService] setting up {def.id} failed: {err}`)
			objective.state = "Failed"
		end
		table.insert(objectives, objective)
		snapshot(objective)
	end
end

function ObjectiveService:Clear()
	active = false
	for _, objective in objectives do
		removePickpocket(objective)
		for _, prompt in objective.doorPrompts do
			prompt:Destroy()
		end
		if objective.devicePrompt then
			objective.devicePrompt:Destroy()
		end
		if objective.device then
			objective.device:Destroy()
		end
	end
	table.clear(objectives)
	for id in radioPrompts do
		removeRadioPrompt(id)
	end
	radio = nil
	info = nil
	table.clear(guardIds)
	table.clear(guardsById)
end

-- {[objectiveId] = true} for every objective done this round (kept until the next Setup).
function ObjectiveService:GetResults(): { [string]: boolean }
	return table.clone(results)
end

function ObjectiveService:Start()
	(GuardService :: any):SetPrankPointsHandler(onPrankPoints)
	local bubbled = (GuardService :: any).Bubbled
	if type(bubbled) == "table" then
		bubbled:Connect(function(model: Model, by: Player?)
			ObjectiveService:OnGuardBubbled(model, by)
		end)
	end

	local holderClock = 0
	RunService.Heartbeat:Connect(function(dt)
		if not active then
			return
		end
		stepDevices(dt)
		stepRadio()
		holderClock += dt
		if holderClock >= 0.5 then
			holderClock = 0
			updateHolders()
		end
	end)

	-- JUMP IN: the newcomer gets the objective list.
	local function onPlayer(player: Player)
		player:GetAttributeChangedSignal(Tags.Activity):Connect(function()
			if active and isCrew(player) then
				for _, objective in objectives do
					snapshot(objective, player)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return ObjectiveService
