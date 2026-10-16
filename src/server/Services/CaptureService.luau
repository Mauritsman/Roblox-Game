--!strict
-- Getting caught (beta-spec §3.4, advisor §13): grab → carried to the cell → rescue or self-escape.
--   Grabbed  `Caught = true`, `Captured = "Carried"`; all loot drops (CarryService:DropAll), drone recalled, out
--            of hiding; welded to the guard's back, who walks at 8 to `CellDropoff` (40 s cap → placed in the cell)
--   Hero     a Bubble on the carrying guard, or a Noisemaker landing within 20 studs → captive dropped, 3 s immune
--   Cell     `Captured = "Cell"` on a free `CellSpot`, anchored; watches heist cameras (`ViewCam`), spots from them
--   Rescue   "Free crew" prompt on `CellDoor` (hold 2 s; perk Quick Hands 1.5 s) frees everyone → `CellExit`
--   Grate    `CrawlOut` once per round (Easy twice), 15 s after being celled (Escape Artist 12 s) → `CellGrate`
-- Without a cell on the map (prototype) the guard holds you for a moment and you are back at the van.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Capture = require(ReplicatedStorage.Shared.Logic.Capture)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)

local CameraService = require(script.Parent.CameraService)
local GuardService = require(script.Parent.GuardService)
local MapService = require(script.Parent.MapService)

local Npc = script.Parent.Parent:WaitForChild("Npc")
local Peers = require(Npc.Peers)
local Targets = require(Npc.Targets)

local CaptureService = {}

-- (player, stage): "grabbed" | "cell" | "dropped" | "rescued" | "grate" | "released"
CaptureService.Changed = Signal.new() :: Signal.Signal<Player, string>

type Stage = "Carried" | "Held" | "Cell" | "Respawn"

type Saved = { massless: { [BasePart]: boolean }, groups: { [BasePart]: string } }

type Captive = {
	player: Player,
	stage: Stage,
	guard: Model?,
	weld: Weld?,
	saved: Saved?,
	token: number,
	spot: number?,
}

local C = Config.Capture
local CAPTIVE_GROUP = "Captive"
local CARRY_OFFSET = CFrame.new(0, 2.2, 0.2) * CFrame.Angles(0, 0, math.rad(90)) -- over the shoulder

local captives: { [Player]: Captive } = {}
local nextToken = 0
local unhideHook: ((player: Player) -> ())? = nil
local viewCamAt: { [Player]: number } = {}
local holdTokens: { [Player]: number } = {}

-- HidingService: takes a player out of their hiding spot before a grab.
function CaptureService:SetUnhideHook(hook: (player: Player) -> ())
	unhideHook = hook
end

--------------------------------------------------------------------------------------------------------------
-- The cell (map contract: Cell folder with CellSpot ×≥4, CellDoor, CellDropoff, CellExit, CellGrate)
--------------------------------------------------------------------------------------------------------------

local function tagged(tag: string): { Instance }
	local level = MapService.Level
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(workspace) and (level == nil or inst:IsDescendantOf(level)) then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end

local function first(tag: string): Instance?
	return tagged(tag)[1]
end

local function standCFrame(inst: Instance?, offset: Vector3?): CFrame?
	if not inst then
		return nil
	end
	local cf = Targets.cframeOf(inst)
	if not cf then
		return nil
	end
	local position = cf.Position + Vector3.new(0, 3, 0) + (offset or Vector3.zero)
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 0.01 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + look)
end

local function hasCell(): boolean
	return #tagged(Tags.CellSpot) > 0
end

local function celledPlayers(): { Player }
	local list = {}
	for player, captive in captives do
		if captive.stage == "Cell" then
			table.insert(list, player)
		end
	end
	return list
end

local function updatePrompts()
	local anyone = #celledPlayers() > 0
	for _, door in CollectionService:GetTagged(Tags.CellDoor) do
		local prompt = door:FindFirstChild("FreePrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = anyone
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Attaching to a guard
--------------------------------------------------------------------------------------------------------------

local function ensureCaptiveGroup()
	if not PhysicsService:IsCollisionGroupRegistered(CAPTIVE_GROUP) then
		PhysicsService:RegisterCollisionGroup(CAPTIVE_GROUP)
	end
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable(CAPTIVE_GROUP, group.name, false)
	end
end

local function attach(captive: Captive, character: Model, guardModel: Model): boolean
	local guardRoot = guardModel:FindFirstChild("HumanoidRootPart")
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if
		not guardRoot
		or not guardRoot:IsA("BasePart")
		or not root
		or not root:IsA("BasePart")
		or not humanoid
	then
		return false
	end
	ensureCaptiveGroup()
	local saved: Saved = { massless = {}, groups = {} }
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			saved.massless[part] = part.Massless
			saved.groups[part] = part.CollisionGroup
			part.Massless = true
			part.CollisionGroup = CAPTIVE_GROUP
		end
	end
	root.Anchored = false
	humanoid.PlatformStand = true
	root.CFrame = guardRoot.CFrame * CARRY_OFFSET
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = guardRoot
	weld.Part1 = root
	weld.C0 = CARRY_OFFSET
	weld.Parent = guardRoot
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	captive.weld = weld
	captive.saved = saved
	return true
end

local function detach(captive: Captive, at: CFrame?)
	if captive.weld then
		captive.weld:Destroy()
		captive.weld = nil
	end
	local character = captive.player.Character
	local saved = captive.saved
	captive.saved = nil
	if saved then
		for part, massless in saved.massless do
			if part.Parent then
				part.Massless = massless
				part.CollisionGroup = saved.groups[part] or "Default"
			end
		end
	end
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
	if at then
		character:PivotTo(at)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and not root.Anchored and captive.player.Parent then
		pcall(function()
			root:SetNetworkOwner(captive.player)
		end)
	end
end

--------------------------------------------------------------------------------------------------------------
-- State changes
--------------------------------------------------------------------------------------------------------------

local function setAttrs(character: Model?, caught: boolean, captured: string?)
	if not character then
		return
	end
	character:SetAttribute(Tags.Caught, if caught then true else nil)
	character:SetAttribute(Tags.Captured, captured)
	if caught then
		character:SetAttribute(Tags.Crouching, false)
	end
end

local function anchorRoot(character: Model?, anchored: boolean)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = anchored
	end
end

local function stopGuard(captive: Captive)
	local guard = captive.guard
	captive.guard = nil
	if guard and GuardService:CarriedBy(guard) == captive.player then
		GuardService:StopCarry(guard)
	end
end

-- Frees a captive. `at` = where they stand; `immune` = 3 s immunity.
local function release(player: Player, at: CFrame?, immune: boolean, stage: string)
	local captive = captives[player]
	if not captive then
		return
	end
	captives[player] = nil
	captive.token += 1
	stopGuard(captive)
	detach(captive, nil)
	local character = player.Character
	anchorRoot(character, false)
	if character then
		if at then
			character:PivotTo(at)
		end
		setAttrs(character, false, nil)
		character:SetAttribute(Tags.SelfEscapeAt, nil)
		if immune then
			character:SetAttribute(Tags.ImmuneUntil, Targets.now() + C.ImmuneSeconds)
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and player.Parent then
			pcall(function()
				root:SetNetworkOwner(player)
			end)
		end
	end
	Peers.refreshMovement(player)
	updatePrompts()
	CaptureService.Changed:Fire(player, stage)
end

local function selfEscapesAllowed(): number
	return Targets.round().selfEscapes
end

local function putInCell(player: Player)
	local captive = captives[player]
	if not captive then
		return
	end
	stopGuard(captive)
	detach(captive, nil)
	local spots = tagged(Tags.CellSpot)
	if #spots == 0 then
		release(player, standCFrame(nil), true, "released")
		return
	end
	local occupied: { [number]: Player } = {}
	for other, entry in captives do
		if other ~= player and entry.stage == "Cell" and entry.spot then
			occupied[entry.spot] = other
		end
	end
	local index = Capture.freeSpot(occupied, #spots) or 1
	captive.stage = "Cell"
	captive.spot = index
	captive.token += 1
	local character = player.Character
	if character then
		local at = standCFrame(spots[index])
		if at then
			character:PivotTo(at)
		end
		anchorRoot(character, true)
		setAttrs(character, true, "Cell")
		local used = player:GetAttribute(Tags.SelfEscapeUsed)
		local stats = Peers.stats(player)
		character:SetAttribute(
			Tags.SelfEscapeAt,
			Capture.selfEscapeAt(
				Targets.now(),
				stats.SelfEscapeAfter,
				if typeof(used) == "number" then used else 0,
				selfEscapesAllowed()
			)
		)
	end
	Peers.refreshMovement(player)
	updatePrompts()
	Net.broadcast("Captured", player.UserId, "cell")
	CaptureService.Changed:Fire(player, "cell")
end

-- The grab (GuardService's grab handler). Returns true when the player is now carried (or held).
function CaptureService:Grab(player: Player, guardModel: Model): boolean
	if captives[player] then
		return false
	end
	local view = Targets.view(player)
	if not view or not Targets.isCrew(player) then
		return false
	end
	local character = view.character
	if character:GetAttribute(Tags.Caught) == true or character:GetAttribute(Tags.InVan) == true then
		return false
	end
	local immune = character:GetAttribute(Tags.ImmuneUntil)
	if typeof(immune) == "number" and Targets.now() < immune then
		return false
	end
	if character:GetAttribute(Tags.Hidden) == true and unhideHook then
		unhideHook(player)
	end

	nextToken += 1
	local captive: Captive = { player = player, stage = "Carried", guard = guardModel, token = nextToken }
	captives[player] = captive
	setAttrs(character, true, "Carried")
	Peers.call("CarryService", "DropAll", player, "captured")
	Peers.call("GadgetService", "RecallDrone", player, "")
	Peers.refreshMovement(player)
	Peers.event("timesCaught", player)

	local cellAvailable = hasCell()
	if cellAvailable and attach(captive, character, guardModel) then
		local dropoff = first(Tags.CellDropoff) or first(Tags.CellDoor)
		local destination = if dropoff then Targets.positionOf(dropoff) else nil
		GuardService:StartCarry(guardModel, player, destination, function()
			if captives[player] == captive and captive.stage == "Carried" then
				putInCell(player)
			end
		end)
		local token = captive.token
		task.delay(C.MaxCarrySeconds, function()
			if captives[player] == captive and captive.token == token and captive.stage == "Carried" then
				putInCell(player)
			end
		end)
	else
		-- Prototype map without a cell: held for a moment, then back to the van (immune).
		captive.stage = "Held"
		anchorRoot(character, true)
		GuardService:StartCarry(guardModel, player, nil, nil)
		local token = captive.token
		task.delay(C.NoCellHoldSeconds, function()
			if captives[player] == captive and captive.token == token then
				local spawn = MapService.Points.Spawn
				release(
					player,
					CFrame.new(spawn + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))),
					true,
					"released"
				)
			end
		end)
	end
	Net.broadcast("Captured", player.UserId, "grabbed")
	CaptureService.Changed:Fire(player, "grabbed")
	return true
end

-- Hero moment: the carrying guard was bubbled or heard a Noisemaker close by.
local function onCarryInterrupted(guardModel: Model, player: Player, _kind: string, by: Player?)
	local captive = captives[player]
	if not captive or captive.guard ~= guardModel then
		return
	end
	captive.guard = nil -- GuardService already stopped the carry
	local guardRoot = guardModel:FindFirstChild("HumanoidRootPart")
	local at: CFrame? = nil
	if guardRoot and guardRoot:IsA("BasePart") then
		at = guardRoot.CFrame * CFrame.new(3, 0, 0)
	end
	release(player, at, true, "dropped")
	Net.broadcast("Captured", player.UserId, "dropped")
	if by and by ~= player then
		Peers.event("heroDrops", by)
	end
end

local function rescue(rescuer: Player, door: Instance)
	local view = Targets.view(rescuer)
	if not view or not Targets.isCrew(rescuer) or captives[rescuer] then
		return
	end
	if view.character:GetAttribute(Tags.Caught) == true then
		return
	end
	local doorPos = Targets.positionOf(door)
	if doorPos and (doorPos - view.root.Position).Magnitude > 12 then
		return
	end
	local freed = celledPlayers()
	if #freed == 0 then
		return
	end
	local exit = first(Tags.CellExit) or door
	for index, player in freed do
		local offset = Vector3.new((index - 1) % 2 * 3 - 1.5, 0, math.floor((index - 1) / 2) * 3)
		release(player, standCFrame(exit, offset), true, "rescued")
		Net.broadcast("Rescued", player.UserId, rescuer.UserId, "rescue")
	end
	Peers.event("rescues", rescuer, { count = #freed })
end

local function crawlOut(player: Player)
	local captive = captives[player]
	local character = player.Character
	if not captive or not character then
		return
	end
	local used = player:GetAttribute(Tags.SelfEscapeUsed)
	local usedCount = if typeof(used) == "number" then used else 0
	local at = character:GetAttribute(Tags.SelfEscapeAt)
	local ok = Capture.canCrawlOut({
		captured = character:GetAttribute(Tags.Captured) :: any,
		selfEscapeAt = if typeof(at) == "number" then at else nil,
		used = usedCount,
		allowed = selfEscapesAllowed(),
	}, Targets.now())
	if not ok then
		return
	end
	player:SetAttribute(Tags.SelfEscapeUsed, usedCount + 1)
	local grate = first(Tags.CellGrate) or first(Tags.CellExit)
	release(player, standCFrame(grate), true, "grate")
	Net.broadcast("Rescued", player.UserId, 0, "grate")
end

local function setupDoor(door: Instance)
	local holder: Instance? = door
	if door:IsA("Model") then
		holder = door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
	end
	if not holder or not holder:IsA("BasePart") or holder:FindFirstChild("FreePrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FreePrompt"
	prompt.ActionText = "Free crew"
	prompt.ObjectText = "Cell"
	prompt.HoldDuration = C.RescueHold
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("ContextIcon", "Free")
	prompt.Enabled = #celledPlayers() > 0
	prompt.Parent = holder
	prompt.Triggered:Connect(function(player)
		holdTokens[player] = nil
		rescue(player, door)
	end)
	-- Quick Hands: a shorter hold than the prompt's own 2 s.
	prompt.PromptButtonHoldBegan:Connect(function(player)
		local hold = Peers.stats(player).RescueHold
		if hold >= prompt.HoldDuration - 0.05 then
			return
		end
		nextToken += 1
		local token = nextToken
		holdTokens[player] = token
		task.delay(hold, function()
			if holdTokens[player] == token then
				holdTokens[player] = nil
				rescue(player, door)
			end
		end)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		holdTokens[player] = nil
	end)
end

--------------------------------------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------------------------------------

-- Every given player is caught (grabbed, carried or celled). An empty list is never "all caught".
function CaptureService:AllCaught(players: { Player }): boolean
	local flags = {}
	for _, player in players do
		local character = player.Character
		table.insert(
			flags,
			captives[player] ~= nil or (character ~= nil and character:GetAttribute(Tags.Caught) == true)
		)
	end
	return Capture.allCaught(flags)
end

function CaptureService:IsCaptive(player: Player): boolean
	return captives[player] ~= nil
end

-- Frees a player at once (DevFree, round end). In the cell → at CellExit.
function CaptureService:Release(player: Player)
	local captive = captives[player]
	if not captive then
		return
	end
	local at = if captive.stage == "Cell" then standCFrame(first(Tags.CellExit)) else nil
	release(player, at, true, "released")
end

-- Straight into the cell (DevCapture; a captive who respawned).
function CaptureService:Jail(player: Player)
	if not captives[player] then
		nextToken += 1
		captives[player] = { player = player, stage = "Respawn", token = nextToken }
		Peers.call("CarryService", "DropAll", player, "captured")
	end
	putInCell(player)
end

-- New round: everyone free, self-escapes reset.
function CaptureService:Reset()
	for player in captives do
		release(player, nil, false, "released")
	end
	table.clear(captives)
	table.clear(holdTokens)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(Tags.SelfEscapeUsed, 0)
		local character = player.Character
		if character then
			character:SetAttribute(Tags.SelfEscapeAt, nil)
		end
	end
	updatePrompts()
end

function CaptureService:Init()
	ensureCaptiveGroup()
end

function CaptureService:Start()
	GuardService:SetGrabHandler(function(player, guardModel)
		return CaptureService:Grab(player, guardModel)
	end)
	GuardService.CarryInterrupted:Connect(onCarryInterrupted)

	for _, door in CollectionService:GetTagged(Tags.CellDoor) do
		setupDoor(door)
	end
	CollectionService:GetInstanceAddedSignal(Tags.CellDoor):Connect(setupDoor)

	MapService.LevelBuilt:Connect(function()
		-- A new heist: nobody can stay in the old cell.
		for player in captives do
			release(player, nil, false, "released")
		end
	end)

	Net.onRequest("CrawlOut", crawlOut)

	Net.onRequest("ViewCam", function(player: Player, index: any)
		if typeof(index) ~= "number" or index ~= index then
			return
		end
		local now = os.clock()
		if now - (viewCamAt[player] or -math.huge) < C.ViewCamCooldown * 0.9 then
			return
		end
		local captive = captives[player]
		local spectating = Targets.activity(player) == "Garage" and Targets.inHeist()
		if not (captive and captive.stage == "Cell") and not spectating then
			return
		end
		local cam = CameraService:GetCamera(math.floor(index))
		if not cam then
			return
		end
		viewCamAt[player] = now
		local position = Targets.positionOf(cam)
		if position then
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(position, Config.Round.StreamTimeout)
				end)
			end)
		end
	end)

	local function watchCharacter(player: Player, character: Model)
		local captive = captives[player]
		if captive and captive.stage ~= "Cell" and captive.stage ~= "Respawn" then
			-- Died while carried or held: the respawn goes to the cell.
			stopGuard(captive)
			captive.weld = nil
			captive.saved = nil
			captive.stage = "Respawn"
		end
		if captive then
			task.delay(0.5, function()
				if captives[player] == captive and player.Character == character then
					putInCell(player)
				end
			end)
		end
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				local entry = captives[player]
				if entry and entry.stage ~= "Respawn" then
					stopGuard(entry)
					if entry.weld then
						entry.weld:Destroy()
						entry.weld = nil
					end
					entry.saved = nil
					entry.spot = nil
					entry.stage = "Respawn"
					updatePrompts()
				end
			end)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local captive = captives[player]
		if captive then
			captives[player] = nil
			captive.token += 1
			stopGuard(captive)
			if captive.weld then
				captive.weld:Destroy()
			end
			updatePrompts()
			CaptureService.Changed:Fire(player, "released")
		end
		viewCamAt[player] = nil
		holdTokens[player] = nil
	end)
end

return CaptureService
