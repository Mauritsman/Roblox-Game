--!strict
-- Carrying loot (beta-spec §2.3–§2.5): pockets (small, max StatsOf.PocketSlots), hands (medium alone; heavy/main
-- alone, rolling or with a helper), throwing and catching medium loot on a server-moved arc (Logic/Throw), dropping,
-- letting go, and the bank loop (every Config.Loot.BankCheckInterval: walking into a BankZone of your session banks
-- everything you carry; loose loot lying in one banks for whoever last held it). Never free physics.
--
-- Requests: LootThrow(target: Vector3), Drop(), LetGo(), Roll(on: boolean). Prompts: GrabPrompt (LootService).
-- Character attributes: CarryClass, CarryLoot, CarryLootId, CarryPartner, CarryRole, Rolling, Pockets, PocketItems,
-- InVan (inside a usable escape/bank zone of your session), Masked (first grab in a crew round).
--
-- Entry points (integration.md): HandsFull(player), IsCarrying(player), DropAll(player, reason).
-- Extra: DropHands(player, reason) (Wet Floor slip), GetPockets(player), HasSmelly(player),
-- ConsumePocket(player, lootType?) (Boef treat), HasLootType(player, lootType) (keycard doors).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local LootRules = require(ReplicatedStorage.Shared.Logic.LootRules)
local Perks = require(ReplicatedStorage.Shared.Logic.Perks)
local Throw = require(ReplicatedStorage.Shared.Logic.Throw)

local Meta = require(script.Parent.Parent.Lib.Meta)
local Optional = require(script.Parent.Parent.Lib.Optional)
local LootService = require(script.Parent.LootService)
local MovementService = require(script.Parent.MovementService)
local StatsService = require(script.Parent.StatsService)

type Loot = LootService.Loot

local CarryService = {}

type Carry = {
	pockets: { Loot },
	hands: Loot?, -- medium/heavy/main where this player leads (or carries alone)
	helping: Loot?, -- heavy/main where this player is the helper
	rolling: boolean,
	lastThrowAt: number,
	lastPromptAt: number,
	lastPos: Vector3?,
	firstPickRound: string?,
}

type Flight = {
	loot: Loot,
	thrower: Player,
	from: Vector3,
	to: Vector3,
	height: number,
	duration: number,
	elapsed: number,
	last: Vector3,
}

local L = Config.Loot
local C = Config.Carry
local DEFAULT_STATS = Perks.defaultsFrom(Config)

local MEDIUM_OFFSET = CFrame.new(0, 0.2, -1.8)
local HEAVY_OFFSET = CFrame.new(0, -0.9, -2.8)
local ROLL_OFFSET = CFrame.new(0, -1.1, -3.2) * CFrame.Angles(0, 0, math.rad(90))

local carries: { [Player]: Carry } = {}
local flights: { Flight } = {}
local requestTimes: { [Player]: { [string]: number } } = {}

local REFUSAL_TEXT: { [string]: string } = {
	TooSlow = "Too slow!",
	PocketFull = "Pocket full!",
	HandsFull = "Hands full!",
	TooFar = "Too far!",
}

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

local function carryOf(player: Player): Carry
	local carry = carries[player]
	if not carry then
		carry = {
			pockets = {},
			hands = nil,
			helping = nil,
			rolling = false,
			lastThrowAt = 0,
			lastPromptAt = 0,
			lastPos = nil,
			firstPickRound = nil,
		}
		carries[player] = carry
	end
	return carry
end

local function rootOf(player: Player?): BasePart?
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function statsOf(player: Player): any
	local ok, stats = Optional.call("LoadoutService", "StatsOf", player)
	if ok and type(stats) == "table" and type(stats.PocketSlots) == "number" then
		return stats
	end
	return DEFAULT_STATS
end

-- Not caught, hidden, frozen, slipping, bubbled, flying a drone, and alive.
local function isFree(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end
	for _, name in
		{ Tags.Caught, Tags.Captured, Tags.Hidden, Tags.Frozen, Tags.Slipping, Tags.Bubbled, Tags.Operating }
	do
		local value = character:GetAttribute(name)
		if value ~= nil and value ~= false then
			return false
		end
	end
	return true
end

local function heavy(loot: Loot): boolean
	return loot.class == "Heavy" or loot.class == "Main"
end

local function offsetFor(loot: Loot, rolling: boolean): CFrame
	if heavy(loot) then
		return if rolling then ROLL_OFFSET else HEAVY_OFFSET
	end
	return MEDIUM_OFFSET
end

local function roundId(): string?
	local id = ReplicatedStorage:GetAttribute(Tags.RoundId)
	return if type(id) == "string" then id else nil
end

local function hearNoise(position: Vector3, radius: number, seconds: number?, kind: string)
	Optional.call("GuardService", "HearNoise", position, radius, seconds, kind)
end

--------------------------------------------------------------------------------------------------------------
-- Attributes
--------------------------------------------------------------------------------------------------------------

local function publish(player: Player)
	local character = player.Character
	local carry = carries[player]
	if not character or not carry then
		return
	end
	local held = carry.hands or carry.helping
	if held then
		character:SetAttribute(Tags.CarryClass, held.class)
		character:SetAttribute(Tags.CarryLoot, held.name)
		character:SetAttribute(Tags.CarryLootId, held.id)
		character:SetAttribute(Tags.CarryRole, if carry.helping then "Help" else "Lead")
		character:SetAttribute(Tags.CarryPartner, if carry.helping then held.carrierId else held.helperId)
	else
		character:SetAttribute(Tags.CarryClass, nil)
		character:SetAttribute(Tags.CarryLoot, nil)
		character:SetAttribute(Tags.CarryLootId, nil)
		character:SetAttribute(Tags.CarryRole, nil)
		character:SetAttribute(Tags.CarryPartner, nil)
	end
	character:SetAttribute(Tags.Rolling, if carry.rolling and carry.hands then true else nil)
	local names = {}
	for _, loot in carry.pockets do
		table.insert(names, loot.name)
	end
	character:SetAttribute(Tags.Pockets, #carry.pockets)
	character:SetAttribute(Tags.PocketItems, table.concat(names, ","))
	-- ux's throw arc reads the perk-adjusted range from the player.
	player:SetAttribute("ThrowRange", statsOf(player).ThrowRange)
	MovementService:Refresh(player)
end

-- Removes every reference to `loot` from every carry (banked, cleared, caught …).
local function forget(loot: Loot)
	for player, carry in carries do
		local changed = false
		if carry.hands == loot then
			carry.hands = nil
			carry.rolling = false
			changed = true
		end
		if carry.helping == loot then
			carry.helping = nil
			changed = true
		end
		local index = table.find(carry.pockets, loot)
		if index then
			table.remove(carry.pockets, index)
			changed = true
		end
		if changed then
			publish(player)
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Floor, water and dropping
--------------------------------------------------------------------------------------------------------------

local function worldParams(): RaycastParams
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, loot in LootService:All() do
		if loot.model then
			table.insert(ignore, loot.model)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = false
	return params
end

-- The floor under a point: (position, isWater). nil position = void.
local function floorBelow(position: Vector3, params: RaycastParams): (Vector3?, boolean)
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -80, 0), params)
	if not hit then
		return nil, false
	end
	local water = hit.Instance == workspace.Terrain and hit.Material == Enum.Material.Water
	return hit.Position, water
end

-- Puts loot on the floor near `position` (banks it when that is inside a bank zone of its session).
-- Returns "Banked" | "Dropped" | "Splash".
local function dropAt(loot: Loot, position: Vector3, by: Player?, yaw: number?): string
	if not LootService:Get(loot.id) then
		return "Banked"
	end
	local params = worldParams()
	local floor, water = floorBelow(position, params)
	local size = Vector3.new(0, 1, 0)
	local handle = loot.handle
	if handle then
		size = handle.Size
	end
	local rotation = CFrame.Angles(0, yaw or 0, 0)
	if floor == nil or water then
		-- Splash: back to its home anchor after a moment (beta-spec §2.3).
		LootService:PlaceAt(loot, CFrame.new(floor or position) * rotation)
		LootService:MarkDropped(loot, if by then by.UserId else nil)
		if by then
			Net.send(by, "Toast", "Splash!")
		end
		task.delay(L.SplashReturn, function()
			if LootService:Get(loot.id) and loot.state == "Dropped" then
				LootService:ReturnHome(loot.id)
			end
		end)
		return "Splash"
	end
	local resting = floor + Vector3.new(0, size.Y / 2, 0)
	if
		LootService:BankZoneAt(resting, loot.session)
		and loot.session ~= "Practice"
		and not loot.objective
	then
		LootService:PlaceAt(loot, CFrame.new(resting) * rotation)
		LootService:SetState(loot, "Dropped")
		LootService:Bank(loot, by)
		return "Banked"
	end
	LootService:PlaceAt(loot, CFrame.new(resting) * rotation)
	LootService:MarkDropped(loot, if by then by.UserId else nil)
	LootService:SendSession(loot.session, "LootDropped", if by then by.UserId else 0, loot.name, resting)
	if loot.session == "Practice" then
		task.delay(L.PracticeReturn, function()
			if LootService:Get(loot.id) and loot.state == "Dropped" then
				LootService:ReturnHome(loot.id)
			end
		end)
	end
	return "Dropped"
end

-- A point `distance` studs in front of the player, pulled back from walls.
local function frontPoint(root: BasePart, distance: number): Vector3
	local from = root.Position
	local direction = root.CFrame.LookVector * distance
	local hit = workspace:Raycast(from, direction, worldParams())
	if hit then
		return hit.Position - root.CFrame.LookVector * 0.8
	end
	return from + direction
end

local function yawOf(root: BasePart?): number
	if not root then
		return 0
	end
	local look = root.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

--------------------------------------------------------------------------------------------------------------
-- Holding
--------------------------------------------------------------------------------------------------------------

-- `player` carries `loot` alone (after a pick, a catch, or the partner leaving).
local function holdAlone(player: Player, loot: Loot)
	local root = rootOf(player)
	local carry = carryOf(player)
	if not root then
		return
	end
	loot.carrierId = player.UserId
	loot.helperId = nil
	loot.lastHolderId = player.UserId
	carry.hands = loot
	carry.helping = nil
	carry.rolling = false
	LootService:WeldTo(loot, root, offsetFor(loot, false))
	LootService:SetState(loot, "Carried")
	publish(player)
end

local function midpointCFrame(a: BasePart, b: BasePart): CFrame
	local mid = (a.Position + b.Position) / 2 + Vector3.new(0, -1, 0)
	local look = a.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(mid, mid + flat.Unit)
end

-- The helper stops helping; the leader keeps carrying alone.
local function helperLetsGo(loot: Loot, helper: Player, text: string?)
	local carry = carries[helper]
	if carry and carry.helping == loot then
		carry.helping = nil
		publish(helper)
	end
	if text then
		Net.send(helper, "Toast", text)
	end
	local leader = if loot.carrierId then Players:GetPlayerByUserId(loot.carrierId) else nil
	if leader and carries[leader] and carries[leader].hands == loot then
		holdAlone(leader, loot)
		Net.send(leader, "Toast", `{helper.DisplayName} let go`)
	else
		loot.helperId = nil
	end
end

--------------------------------------------------------------------------------------------------------------
-- Picking up (GrabPrompt)
--------------------------------------------------------------------------------------------------------------

local function afterPick(player: Player, loot: Loot)
	loot.lastHolderId = player.UserId
	LootService:SendSession(loot.session, "LootPicked", player.UserId, loot.name, loot.class, loot.value)
	StatsService:Event("LootPicked", player, { value = loot.value })
	local character = player.Character
	if loot.session == "Crew" then
		if character and Config.Features.MaskUp then
			character:SetAttribute(Tags.Masked, true)
		end
		local carry = carryOf(player)
		local id = roundId()
		if id and carry.firstPickRound ~= id then
			carry.firstPickRound = id
			Meta.RoundStep(player, id, "FirstLootGrabbed")
		end
	elseif loot.session ~= "Practice" then
		Meta.OnboardingStep(player, "FirstLootGrabbed")
	end
	if loot.main then
		LootService:NotifyLifted(loot, player)
	end
end

local function onPrompt(player: Player, loot: Loot)
	local carry = carryOf(player)
	local t = os.clock()
	if t - carry.lastPromptAt < 0.2 then
		return
	end
	carry.lastPromptAt = t
	local root = rootOf(player)
	local handle = loot.handle
	if not root or not handle then
		return
	end
	if (handle.Position - root.Position).Magnitude > L.GrabRange + 4 then
		return
	end
	local carrierDistance: number? = nil
	if loot.state == "Carried" and loot.carrierId then
		local carrierRoot = rootOf(Players:GetPlayerByUserId(loot.carrierId))
		if carrierRoot then
			carrierDistance = (carrierRoot.Position - root.Position).Magnitude
		end
	end
	local held = carry.hands or carry.helping
	local ok, action = LootRules.canPick({
		userId = player.UserId,
		free = isFree(player),
		session = LootService:SessionOf(player),
		handsClass = if held then held.class else nil,
		pocketCount = #carry.pockets,
		pocketSlots = statsOf(player).PocketSlots,
	}, {
		state = loot.state,
		class = loot.class,
		session = loot.session,
		carrierId = loot.carrierId,
		helperId = loot.helperId,
		carrierDistance = carrierDistance,
	}, L.GrabRange)
	if not ok then
		local text = REFUSAL_TEXT[action]
		if text then
			Net.send(player, "Toast", text)
		end
		return
	end

	if action == "Pocket" then
		loot.carrierId = player.UserId
		loot.helperId = nil
		LootService:SetState(loot, "Carried")
		LootService:DestroyModel(loot)
		table.insert(carry.pockets, loot)
		publish(player)
		afterPick(player, loot)
	elseif action == "Grab" or action == "Lift" then
		holdAlone(player, loot)
		afterPick(player, loot)
	elseif action == "Help" then
		local leader = if loot.carrierId then Players:GetPlayerByUserId(loot.carrierId) else nil
		local leaderRoot = rootOf(leader)
		if not leader or not leaderRoot then
			return
		end
		local leaderCarry = carryOf(leader)
		loot.helperId = player.UserId
		carry.helping = loot
		leaderCarry.rolling = false
		LootService:PlaceAt(loot, midpointCFrame(leaderRoot, root))
		LootService:SetState(loot, "Carried")
		loot.carrierId = leader.UserId
		loot.helperId = player.UserId
		publish(leader)
		publish(player)
		StatsService:Event("CarriedTogether", leader)
		StatsService:Event("CarriedTogether", player)
	end
end

--------------------------------------------------------------------------------------------------------------
-- Throwing and catching
--------------------------------------------------------------------------------------------------------------

local function v3(t: Throw.Vec3): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local function tv(v: Vector3): Throw.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function findCatcher(flight: Flight, position: Vector3, landed: boolean): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local carry = carries[player]
		local root = rootOf(player)
		if
			root
			and not (landed and player == flight.thrower) -- your own throw is only yours again in flight
			and isFree(player)
			and LootService:SessionOf(player) == flight.loot.session
			and not (carry and (carry.hands or carry.helping))
		then
			local distance = (root.Position - position).Magnitude
			if
				distance < bestDistance
				and Throw.canCatch(distance, flight.elapsed, player == flight.thrower, landed, C)
			then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

local function catch(flight: Flight, catcher: Player)
	local loot = flight.loot
	holdAlone(catcher, loot)
	LootService:SendSession(loot.session, "LootCaught", catcher.UserId, loot.name, flight.thrower.UserId)
	if catcher ~= flight.thrower then
		StatsService:Event("ThrowCaught", flight.thrower)
	end
end

local function land(flight: Flight, position: Vector3)
	local loot = flight.loot
	local catcher = findCatcher(flight, position, true)
	if catcher then
		catch(flight, catcher)
		return
	end
	local result = dropAt(loot, position, flight.thrower, yawOf(rootOf(flight.thrower)))
	if result == "Dropped" then
		hearNoise(position, L.ThudRadius, nil, "thud")
		StatsService:Event("UncaughtDrop", flight.thrower)
		if loot.fragile then
			local def = Config.Loot.Types[loot.type]
			LootService:ApplyDamage(loot.id, (def and def.FragilePenalty) or L.FragilePenalty, "landing")
		end
	end
end

local function onThrow(player: Player, target: any)
	if typeof(target) ~= "Vector3" or not allow(player, "LootThrow", 0.1) then
		return
	end
	if target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z or target.Magnitude > 1e6 then
		return
	end
	local carry = carries[player]
	local loot = carry and carry.hands
	if not carry or not loot or loot.class ~= "Medium" or loot.helperId ~= nil or not isFree(player) then
		return
	end
	local t = os.clock()
	if t - carry.lastThrowAt < C.ThrowCooldown then
		return
	end
	carry.lastThrowAt = t
	local handle = loot.handle
	local root = rootOf(player)
	if not handle or not root then
		return
	end
	local origin = handle.Position
	local clamped = Throw.clampTarget(tv(origin), tv(target), statsOf(player).ThrowRange)
	local distance = Throw.distance(tv(origin), clamped)
	local duration = Throw.timing(distance, C.ThrowSpeed, C.ThrowMin, C.ThrowMax)
	local height = Throw.height(distance, C.ThrowArc, C.ThrowArcMin)

	carry.hands = nil
	carry.rolling = false
	publish(player)
	loot.lastHolderId = player.UserId
	LootService:PlaceAt(loot, CFrame.new(origin) * CFrame.Angles(0, yawOf(root), 0))
	LootService:SetState(loot, "Thrown")
	loot.carrierId = player.UserId
	local to = v3(clamped)
	LootService:SendSession(loot.session, "LootThrown", player.UserId, loot.name, origin, to, duration)
	table.insert(flights, {
		loot = loot,
		thrower = player,
		from = origin,
		to = to,
		height = height,
		duration = duration,
		elapsed = 0,
		last = root.Position, -- the first wall check starts at the body: hands already in a wall still bounce off it
	})
end

local function updateFlights(dt: number)
	if #flights == 0 then
		return
	end
	local params = worldParams()
	for index = #flights, 1, -1 do
		local flight = flights[index]
		local loot = flight.loot
		local handle = loot.handle
		if not LootService:Get(loot.id) or loot.state ~= "Thrown" or not handle then
			table.remove(flights, index)
			continue
		end
		flight.elapsed += dt
		local alpha = math.min(1, flight.elapsed / flight.duration)
		local position = v3(Throw.point(tv(flight.from), tv(flight.to), alpha, flight.height))
		local stopped = false
		local step = position - flight.last
		if step.Magnitude > 0.01 then
			local hit = workspace:Raycast(flight.last, step, params)
			if hit then
				-- Wall: stop half a stud off it, then it drops straight down.
				position = hit.Position + hit.Normal * 0.5
				stopped = true
			end
		end
		handle.CFrame = CFrame.new(position) * handle.CFrame.Rotation
		flight.last = position
		local catcher = findCatcher(flight, position, false)
		if catcher then
			table.remove(flights, index)
			catch(flight, catcher)
		elseif alpha >= 1 or stopped then
			table.remove(flights, index)
			land(flight, position)
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Dropping, letting go, rolling
--------------------------------------------------------------------------------------------------------------

-- Drops what is in the hands (leader) or lets go (helper). Returns true when something dropped.
local function dropHands(player: Player, reason: string, at: Vector3?): boolean
	local damaging = reason == "capture" or reason == "slip"
	local deliberate = reason == "drop"
	local carry = carries[player]
	if not carry then
		return false
	end
	local dropped = false
	local root = rootOf(player)
	local loot = carry.hands
	if loot then
		carry.hands = nil
		carry.rolling = false
		local helper = if loot.helperId then Players:GetPlayerByUserId(loot.helperId) else nil
		if helper and carries[helper] and carries[helper].helping == loot and not deliberate then
			-- The leader is gone or caught: the helper takes over alone.
			carries[helper].helping = nil
			holdAlone(helper, loot)
		else
			if helper and carries[helper] and carries[helper].helping == loot then
				carries[helper].helping = nil
				publish(helper)
			end
			local point = at or (if root then frontPoint(root, 2) else nil)
			if point then
				dropAt(loot, point, player, yawOf(root))
				dropped = true
				if loot.fragile and damaging then
					local def = Config.Loot.Types[loot.type]
					LootService:ApplyDamage(loot.id, (def and def.FragilePenalty) or L.FragilePenalty, reason)
				end
			end
		end
	end
	local helping = carry.helping
	if helping then
		helperLetsGo(helping, player, nil)
	end
	publish(player)
	return dropped
end

local function dropAll(player: Player, reason: string, at: Vector3?)
	local carry = carries[player]
	if not carry then
		return
	end
	local root = rootOf(player)
	local base = at or (if root then root.Position else carry.lastPos)
	local void = base ~= nil and base.Y < workspace.FallenPartsDestroyHeight + 20
	local dropped = false
	if void and carry.hands and not carry.hands.helperId then
		local loot = carry.hands
		carry.hands = nil
		carry.rolling = false
		LootService:PlaceAt(loot, loot.home)
		LootService:SetState(loot, "Dropped")
		LootService:ReturnHome(loot.id)
	end
	dropped = dropHands(player, reason, base) or dropped
	local pockets = carry.pockets
	carry.pockets = {}
	for index, loot in pockets do
		if base == nil or void then
			LootService:PlaceAt(loot, loot.home)
			LootService:SetState(loot, "Dropped")
			LootService:ReturnHome(loot.id)
		else
			local angle = (index / math.max(1, #pockets)) * math.pi * 2
			local radius = Config.Capture.Scatter * (0.5 + 0.5 * ((index % 2) + 0.5) / 1.5)
			local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			dropAt(loot, base + offset, player, angle)
			dropped = true
		end
	end
	publish(player)
	if dropped and (reason == "capture" or reason == "slip") then
		StatsService:Event("UncaughtDrop", player)
	end
end

local function onDrop(player: Player)
	if not allow(player, "Drop", 0.25) then
		return
	end
	local carry = carries[player]
	if carry and carry.hands then
		dropHands(player, "drop", nil)
	end
end

local function onLetGo(player: Player)
	if not allow(player, "LetGo", 0.25) then
		return
	end
	local carry = carries[player]
	local loot = carry and carry.helping
	if loot then
		helperLetsGo(loot, player, nil)
	end
end

local function onRoll(player: Player, on: any)
	if type(on) ~= "boolean" or not allow(player, "Roll", 0.25) then
		return
	end
	local carry = carries[player]
	local loot = carry and carry.hands
	local root = rootOf(player)
	if not carry or not loot or not root or not heavy(loot) or not loot.canRoll or loot.helperId ~= nil then
		return
	end
	if carry.rolling == on then
		return
	end
	carry.rolling = on
	LootService:WeldTo(loot, root, offsetFor(loot, on))
	publish(player)
end

--------------------------------------------------------------------------------------------------------------
-- Loops: two-carry, banking, anti-teleport, rumble
--------------------------------------------------------------------------------------------------------------

local function updateTwoCarry()
	for _, loot in LootService:All() do
		if loot.state == "Carried" and loot.helperId and loot.carrierId and loot.handle then
			local leader = Players:GetPlayerByUserId(loot.carrierId)
			local helper = Players:GetPlayerByUserId(loot.helperId)
			local a, b = rootOf(leader), rootOf(helper)
			if leader and helper and a and b then
				if LootRules.gripLost((a.Position - b.Position).Magnitude, C.Tether) then
					helperLetsGo(loot, helper, "Lost grip!")
				else
					loot.handle.CFrame = midpointCFrame(a, b)
				end
			elseif helper and not a then
				local carry = carries[helper]
				if carry then
					carry.helping = nil
				end
				holdAlone(helper, loot)
			elseif leader and not b then
				holdAlone(leader, loot)
			end
		end
	end
end

local function bankFor(player: Player, carry: Carry)
	local any = false
	for _, loot in table.clone(carry.pockets) do
		if not loot.objective and LootService:Bank(loot, player) then
			forget(loot)
			any = true
		end
	end
	local held = carry.hands or carry.helping
	if held and LootService:Bank(held, player) then
		forget(held)
		any = true
	end
	if any then
		publish(player)
	end
end

local function bankLoop()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = rootOf(player)
		if character and root then
			local session = LootService:SessionOf(player)
			local zone = LootService:BankZoneAt(root.Position, session)
			local inVan = zone ~= nil and session ~= "Practice"
			if (character:GetAttribute(Tags.InVan) == true) ~= inVan then
				character:SetAttribute(Tags.InVan, inVan)
			end
			local carry = carries[player]
			if zone and carry and session ~= "Practice" and isFree(player) then
				bankFor(player, carry)
			end
		end
	end
	-- Loose loot lying in a bank zone banks for whoever held it last.
	for _, loot in LootService:All() do
		local handle = loot.handle
		if loot.state == "Dropped" and handle and loot.session ~= "Practice" and not loot.objective then
			if LootService:BankZoneAt(handle.Position, loot.session) then
				local holder = if loot.lastHolderId then Players:GetPlayerByUserId(loot.lastHolderId) else nil
				LootService:Bank(loot, holder)
			end
		elseif loot.state == "Carried" and handle and not handle.Anchored then
			-- Safety: a welded item whose carrier vanished must never fall with free physics.
			local weld = handle:FindFirstChild("CarryWeld")
			local part0: BasePart? = if weld and weld:IsA("WeldConstraint") then weld.Part0 else nil
			if not part0 or not part0:IsDescendantOf(workspace) then
				forget(loot)
				LootService:PlaceAt(loot, CFrame.new(handle.Position))
				LootService:MarkDropped(loot, loot.lastHolderId)
			end
		end
	end
end

local function guardLoop()
	for player, carry in carries do
		local root = rootOf(player)
		local carrying = carry.hands or carry.helping or #carry.pockets > 0
		if root and carrying and carry.lastPos then
			if LootRules.teleported((root.Position - carry.lastPos).Magnitude, L.TeleportGuardStuds) then
				warn(`[CarryService] {player.Name} moved too far while carrying: loot dropped`)
				dropAll(player, "teleport", carry.lastPos)
			end
		end
		carry.lastPos = if root then root.Position else nil
	end
end

local function rumbleLoop()
	for player, carry in carries do
		local root = rootOf(player)
		if carry.rolling and carry.hands and root then
			hearNoise(root.Position, C.RumbleRadius, C.RumbleSearch, "rumble")
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------------------------------------

-- Medium, heavy or main loot in the hands (as leader or helper): gadgets, the Crowbar and crouching refuse.
function CarryService:HandsFull(player: Player): boolean
	local carry = carries[player]
	return carry ~= nil and (carry.hands ~= nil or carry.helping ~= nil)
end

function CarryService:IsCarrying(player: Player): boolean
	local carry = carries[player]
	return carry ~= nil and (carry.hands ~= nil or carry.helping ~= nil or #carry.pockets > 0)
end

-- Everything drops at the player's position (pockets scatter). reason: "capture" | "death" | "leave" | "slip" |
-- "teleport" | other. A two-player carry passes to the partner instead.
function CarryService:DropAll(player: Player, reason: string?)
	dropAll(player, reason or "drop", nil)
end

-- Only the hands (Wet Floor slip drops medium loot; pockets stay).
function CarryService:DropHands(player: Player, reason: string?)
	dropHands(player, reason or "drop", nil)
end

function CarryService:GetPockets(player: Player): { Loot }
	local carry = carries[player]
	return if carry then table.clone(carry.pockets) else {}
end

-- Any smelly loot carried, pocket included (Boef).
function CarryService:HasSmelly(player: Player): boolean
	local carry = carries[player]
	if not carry then
		return false
	end
	for _, loot in carry.pockets do
		if loot.smelly then
			return true
		end
	end
	local held = carry.hands or carry.helping
	return held ~= nil and held.smelly
end

function CarryService:HasLootType(player: Player, lootType: string): boolean
	for _, loot in CarryService:GetPockets(player) do
		if loot.type == lootType then
			return true
		end
	end
	local carry = carries[player]
	local held = carry and (carry.hands or carry.helping)
	return held ~= nil and held.type == lootType
end

-- Removes one pocket item (of `lootType`, or any smelly one when nil) for good. Returns its type or nil.
function CarryService:ConsumePocket(player: Player, lootType: string?): string?
	local carry = carries[player]
	if not carry then
		return nil
	end
	for index, loot in carry.pockets do
		if (lootType and loot.type == lootType) or (lootType == nil and loot.smelly) then
			table.remove(carry.pockets, index)
			LootService:Remove(loot)
			publish(player)
			return loot.type
		end
	end
	return nil
end

-- Forgets every carry (round teardown; the loot itself is cleared by LootService).
function CarryService:Reset()
	for player, carry in carries do
		carry.pockets = {}
		carry.hands = nil
		carry.helping = nil
		carry.rolling = false
		publish(player)
	end
	table.clear(flights)
end

function CarryService:Init()
	LootService.OnPrompt = onPrompt
end

function CarryService:Start()
	Net.onRequest("LootThrow", onThrow)
	Net.onRequest("Drop", onDrop)
	Net.onRequest("LetGo", onLetGo)
	Net.onRequest("Roll", onRoll)

	LootService.Cleared:Connect(function(session: string)
		for player, carry in carries do
			local changed = false
			for index = #carry.pockets, 1, -1 do
				if carry.pockets[index].session == session then
					table.remove(carry.pockets, index)
					changed = true
				end
			end
			for _, key in { "hands", "helping" } do
				local held = (carry :: any)[key]
				if held and held.session == session then
					(carry :: any)[key] = nil
					carry.rolling = false
					changed = true
				end
			end
			if changed then
				publish(player)
			end
		end
	end)

	local function onCharacter(player: Player, character: Model)
		local carry = carryOf(player)
		carry.lastPos = nil
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				dropAll(player, "death", nil)
			end)
		end
		publish(player)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		-- Respawned or replaced without dying: nothing may stay welded to the old body.
		player.CharacterRemoving:Connect(function()
			if CarryService:IsCarrying(player) then
				dropAll(player, "death", nil)
			end
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropAll(player, "leave", nil)
		carries[player] = nil
		requestTimes[player] = nil
	end)

	local bankTimer, guardTimer, rumbleTimer = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		updateFlights(dt)
		updateTwoCarry()
		bankTimer += dt
		guardTimer += dt
		rumbleTimer += dt
		if bankTimer >= L.BankCheckInterval then
			bankTimer = 0
			bankLoop()
		end
		if guardTimer >= 0.5 then
			guardTimer = 0
			guardLoop()
		end
		if rumbleTimer >= C.RumbleInterval then
			rumbleTimer = 0
			rumbleLoop()
		end
	end)
end

return CarryService
