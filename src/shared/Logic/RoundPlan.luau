--!strict
-- The randomised setup of one round (beta-spec §6.1). Deterministic: the same seed, heist info, crew size and
-- job always give the same plan (DevJob replays a seed). SetupService reads the level into `heistInfo`, calls
-- RoundPlan.generate and applies the result.
--
-- Rules: loot per heist Loot entry on unused anchors of its class (Fixed anchors always filled, ≥ 1 Opener anchor
-- filled when there is one), RareChance per wheel to become the rare type (max RareMax), the main loot on 1 Main
-- anchor, LockedEntrances of the entrances locked (never all), each optional exit active with SecondExitChance,
-- guard routes by lowest Priority first (ties shuffled) with a random variant, start waypoint and ±WaitJitter
-- waits, Wet Floor puddles on hazard anchors, the keycard spot (or a guard), safe jam points.
-- Inputs are sorted by Id first, so the order CollectionService returns them in does not matter.

local Rng = if script then require(script.Parent.Rng) else require("./Rng")
local NpcBudget = if script then require(script.Parent.NpcBudget) else require("./NpcBudget")
local CrackDevice = if script then require(script.Parent.CrackDevice) else require("./CrackDevice")

local RoundPlan = {}

type Random = typeof(Rng.new(1))

export type Anchor = {
	Id: string, -- AnchorId
	Class: string, -- AnchorClass: "Small" | "Medium" | "Heavy" | "Main"
	Group: string?, -- only for loot entries/objectives with this Group
	Fixed: boolean?, -- always gets loot (mini-job)
	Opener: boolean?, -- first-loot spot near the spawn: at least one is filled
	Zone: string?,
}

export type LootEntry = { Type: string, Count: number, Group: string? }

export type LootTypeDef = { Class: string, RareSwap: string? }

export type ExitInfo = { Id: string, Kind: string?, Optional: boolean? }

export type Waypoint = { Pos: any?, Wait: number? }

export type RouteInfo = { Id: string, Priority: number?, Variants: { { Waypoint } } }

export type ObjectiveDef = {
	Id: string,
	Type: string, -- "Keycard" | "Safe"
	Required: boolean?,
	BonusPct: number?,
	Group: string?,
	Loot: { LootEntry }?,
}

export type Rules = {
	CountByCrew: { number },
	NpcCap: number,
	RareChance: number,
	RareMax: number,
	LockedEntrances: number,
	SecondExitChance: number,
	WaitJitter: number,
	MaxOptional: number,
	DeviceJams: { number }, -- {min, max}
	JamWindow: { number }, -- {from, to} fractions of progress
	KeycardOnGuardChance: number,
	ObjectiveBonusPct: number,
	TierExtraGuards: { [string]: number },
	ModifierGuards: { [string]: number },
	ModifierNpcs: { [string]: number },
	ModifierHazards: { [string]: number },
}

export type HeistInfo = {
	heistId: string?,
	anchors: { Anchor },
	loot: { LootEntry },
	lootTypes: { [string]: LootTypeDef }, -- Config.Loot.Types
	entrances: { string }?,
	exits: { ExitInfo }?,
	routes: { RouteInfo }?,
	hazards: { string }?,
	objectives: { ObjectiveDef }?,
	guardBonus: number?,
	hasDog: boolean?,
	hasKarel: boolean?, -- default true (every heist except the mini-job)
	extraNpcs: number?,
	rules: Rules, -- RoundPlan.rulesFrom(Config)
}

export type Job = {
	heistId: string?,
	difficulty: string?, -- "Easy" | "Normal" | "Hard"
	modifierId: string?,
}

export type PlacedLoot = { anchorId: string, type: string, class: string }

export type GuardPlan = {
	routeId: string?, -- nil = no GuardRoutes: use the heist's fallback GuardRoute
	variant: number,
	start: number, -- first waypoint index
	waits: { number }, -- per waypoint of the variant
}

export type ObjectivePlan = {
	id: string,
	type: string,
	required: boolean,
	bonusPct: number, -- 0 for required objectives
	anchorId: string?, -- keycard spot
	onGuard: boolean?, -- keycard hangs on a guard (pickpocket)
	guardIndex: number?, -- index into plan.guards
	jamPoints: { number }?, -- safe: device jam points (fractions of progress)
	loot: { PlacedLoot }?, -- safe: loot that spawns when the device is done
	anchors: { string }?, -- all anchors of the objective's Group
}

export type Plan = {
	seed: number,
	heistId: string?,
	difficulty: string?,
	modifierId: string?,
	loot: { PlacedLoot },
	rareCount: number,
	mainAnchor: string?, -- where the main loot is (job card)
	lockedEntrances: { string },
	openEntrances: { string },
	activeExits: { string },
	inactiveExits: { string },
	secondExit: boolean, -- an optional exit is active
	guardCount: number,
	otherNpcs: number,
	guards: { GuardPlan },
	inspector: GuardPlan?, -- Health Inspector on the next spare route
	hazards: { string },
	objectives: { ObjectivePlan },
	warnings: { string }, -- map problems worth printing (too few anchors, routes, …)
}

-- Builds Rules from the Config table.
function RoundPlan.rulesFrom(config: any): Rules
	local tierGuards: { [string]: number } = {}
	for name, tier in config.DifficultyTiers.Tiers do
		tierGuards[name] = tier.ExtraGuards
	end
	return {
		CountByCrew = config.Guard.CountByCrew,
		NpcCap = config.Npc.Cap,
		RareChance = config.Loot.RareChance,
		RareMax = config.Loot.RareMax,
		LockedEntrances = config.Plan.LockedEntrances,
		SecondExitChance = config.Plan.SecondExitChance,
		WaitJitter = config.Plan.WaitJitter,
		MaxOptional = config.Plan.MaxOptionalObjectives,
		DeviceJams = config.Objectives.DeviceJams,
		JamWindow = config.Plan.DeviceJamWindow,
		KeycardOnGuardChance = config.Objectives.KeycardOnGuardChance,
		ObjectiveBonusPct = config.Objectives.BonusPct,
		TierExtraGuards = tierGuards,
		ModifierGuards = { DoubleShift = config.Modifiers.DoubleShift.ExtraGuards },
		ModifierNpcs = { HealthInspector = config.Modifiers.HealthInspector.Npcs },
		ModifierHazards = { WetFloor = config.Modifiers.WetFloor.Puddles },
	}
end

local function sortedStrings(list: { string }?): { string }
	local copy = if list then table.clone(list) else {}
	table.sort(copy)
	return copy
end

local function sortedAnchors(list: { Anchor }): { Anchor }
	local copy = table.clone(list)
	table.sort(copy, function(a, b)
		return a.Id < b.Id
	end)
	return copy
end

local function lookup(map: { [string]: number }, key: string?): number
	if key == nil then
		return 0
	end
	return map[key] or 0
end

local function matches(anchor: Anchor, class: string, group: string?): boolean
	if group ~= nil then
		return anchor.Group == group
	end
	return anchor.Group == nil and anchor.Class == class
end

-- Places loot entries on unused anchors (marks them used).
local function allocate(
	rng: Random,
	anchors: { Anchor },
	used: { [string]: boolean },
	entries: { LootEntry },
	lootTypes: { [string]: LootTypeDef },
	opener: Anchor?,
	warnings: { string },
	groupOverride: string?
): { PlacedLoot }
	local placed = {}
	for _, entry in entries do
		local def = lootTypes[entry.Type]
		if def == nil then
			table.insert(warnings, `unknown loot type {entry.Type}`)
			continue
		end
		local group = entry.Group or groupOverride
		local fixed, free = {}, {}
		for _, anchor in anchors do
			if not used[anchor.Id] and matches(anchor, def.Class, group) then
				table.insert(if anchor.Fixed then fixed else free, anchor)
			end
		end
		free = rng:shuffle(free)
		if opener and not used[opener.Id] then
			for index, anchor in free do
				if anchor.Id == opener.Id then
					table.remove(free, index)
					table.insert(free, 1, anchor)
					break
				end
			end
		end
		local fixedCount = #fixed
		local ordered = table.move(free, 1, #free, fixedCount + 1, fixed)
		local count = math.max(entry.Count, fixedCount)
		if count > #ordered then
			table.insert(warnings, `{entry.Type}: wanted {count}, only {#ordered} anchors`)
			count = #ordered
		end
		for index = 1, count do
			local anchor = ordered[index]
			used[anchor.Id] = true
			table.insert(placed, { anchorId = anchor.Id, type = entry.Type, class = def.Class })
		end
	end
	return placed
end

local function makeGuard(rng: Random, route: RouteInfo?, jitter: number): GuardPlan
	if route == nil or #route.Variants == 0 then
		return { routeId = if route then route.Id else nil, variant = 1, start = 1, waits = {} }
	end
	local variant = rng:int(1, #route.Variants)
	local points = route.Variants[variant]
	local start = if #points > 0 then rng:int(1, #points) else 1
	local waits = {}
	for _, point in points do
		local wait = (point.Wait or 0) + (rng:next() * 2 - 1) * jitter
		table.insert(waits, math.max(0, wait))
	end
	return { routeId = route.Id, variant = variant, start = start, waits = waits }
end

-- Routes by Priority (lowest first), ties shuffled.
local function orderRoutes(rng: Random, routes: { RouteInfo }?): { RouteInfo }
	local sorted: { RouteInfo } = if routes then table.clone(routes) else {}
	table.sort(sorted, function(a, b)
		local pa, pb = a.Priority or 0, b.Priority or 0
		if pa ~= pb then
			return pa < pb
		end
		return a.Id < b.Id
	end)
	local ordered = {}
	local i = 1
	while i <= #sorted do
		local priority = sorted[i].Priority or 0
		local group = {}
		while i <= #sorted and (sorted[i].Priority or 0) == priority do
			table.insert(group, sorted[i])
			i += 1
		end
		for _, route in rng:shuffle(group) do
			table.insert(ordered, route)
		end
	end
	return ordered
end

function RoundPlan.generate(seed: number, heistInfo: HeistInfo, crewSize: number, job: Job): Plan
	local rules = heistInfo.rules
	local rng = Rng.new(seed)
	local warnings: { string } = {}
	local modifier = job.modifierId
	local anchors = sortedAnchors(heistInfo.anchors)
	local used: { [string]: boolean } = {}

	-- Opener: one random first-loot anchor whose class is wanted.
	local wantedClass: { [string]: boolean } = {}
	for _, entry in heistInfo.loot do
		local def = heistInfo.lootTypes[entry.Type]
		if def and entry.Count > 0 and entry.Group == nil then
			wantedClass[def.Class] = true
		end
	end
	local openers = {}
	for _, anchor in anchors do
		if anchor.Opener and anchor.Group == nil and wantedClass[anchor.Class] then
			table.insert(openers, anchor)
		end
	end
	local opener = if #openers > 0 then openers[rng:int(1, #openers)] else nil

	-- Loot, then rare swaps.
	local loot = allocate(rng, anchors, used, heistInfo.loot, heistInfo.lootTypes, opener, warnings, nil)
	local rareCount = 0
	for _, item in loot do
		local def = heistInfo.lootTypes[item.type]
		if def and def.RareSwap then
			local roll = rng:next()
			local rareDef = heistInfo.lootTypes[def.RareSwap]
			if rareDef and roll < rules.RareChance and rareCount < rules.RareMax then
				item.type = def.RareSwap
				item.class = rareDef.Class
				rareCount += 1
			end
		end
	end
	local mainAnchor: string? = nil
	for _, item in loot do
		if item.class == "Main" then
			mainAnchor = item.anchorId
			break
		end
	end

	-- Entrances: lock some, never all.
	local entrances = rng:shuffle(sortedStrings(heistInfo.entrances))
	local lockCount = math.clamp(rules.LockedEntrances, 0, math.max(0, #entrances - 1))
	local locked, open = {}, {}
	for index, id in entrances do
		table.insert(if index <= lockCount then locked else open, id)
	end
	table.sort(locked)
	table.sort(open)

	-- Exits: required ones always, optional ones by chance.
	local exits: { ExitInfo } = if heistInfo.exits then table.clone(heistInfo.exits) else {}
	table.sort(exits, function(a, b)
		return a.Id < b.Id
	end)
	local activeExits, inactiveExits = {}, {}
	local secondExit = false
	for _, exit in exits do
		if exit.Optional then
			if rng:next() < rules.SecondExitChance then
				table.insert(activeExits, exit.Id)
				secondExit = true
			else
				table.insert(inactiveExits, exit.Id)
			end
		else
			table.insert(activeExits, exit.Id)
		end
	end
	if #activeExits == 0 and #inactiveExits > 0 then
		table.insert(warnings, "no required exit: forced the first optional exit active")
		table.insert(activeExits, table.remove(inactiveExits, 1) :: string)
		secondExit = true
	end

	-- Guards within the NPC budget.
	local inspectorNpcs = lookup(rules.ModifierNpcs, modifier)
	local otherNpcs = NpcBudget.others({
		karel = heistInfo.hasKarel ~= false,
		dog = heistInfo.hasDog == true,
		extra = heistInfo.extraNpcs,
		inspector = inspectorNpcs,
	})
	local bonuses = {
		heistInfo.guardBonus or 0,
		lookup(rules.ModifierGuards, modifier),
		lookup(rules.TierExtraGuards, job.difficulty),
	}
	local guardCount = NpcBudget.guardCount(crewSize, rules.CountByCrew, bonuses, otherNpcs, rules.NpcCap)

	local routes = orderRoutes(rng, heistInfo.routes)
	local guards = {}
	if #routes == 0 then
		table.insert(warnings, "no GuardRoutes: guards use the fallback route")
	elseif #routes < guardCount then
		table.insert(warnings, `only {#routes} guard routes for {guardCount} guards: routes reused`)
	end
	for index = 1, guardCount do
		local route = if #routes > 0 then routes[(index - 1) % #routes + 1] else nil
		table.insert(guards, makeGuard(rng, route, rules.WaitJitter))
	end
	local inspector: GuardPlan? = nil
	if inspectorNpcs > 0 then
		local spare = routes[guardCount + 1]
		if spare then
			inspector = makeGuard(rng, spare, rules.WaitJitter)
		else
			table.insert(warnings, "no spare route for the Inspector")
		end
	end

	-- Hazards (Wet Floor).
	local hazards = {}
	local puddles = lookup(rules.ModifierHazards, modifier)
	if puddles > 0 then
		local pool = rng:shuffle(sortedStrings(heistInfo.hazards))
		if #pool < puddles then
			table.insert(warnings, `wanted {puddles} hazard anchors, only {#pool}`)
		end
		for index = 1, math.min(puddles, #pool) do
			table.insert(hazards, pool[index])
		end
		table.sort(hazards)
	end

	-- Objectives: every required one, at most MaxOptional optional ones.
	local defs: { ObjectiveDef } = heistInfo.objectives or {}
	local optional = {}
	for _, def in defs do
		if not def.Required then
			table.insert(optional, def.Id)
		end
	end
	local keepOptional: { [string]: boolean } = {}
	local shuffledOptional = rng:shuffle(optional)
	for index = 1, math.min(rules.MaxOptional, #shuffledOptional) do
		keepOptional[shuffledOptional[index]] = true
	end

	local objectives = {}
	for _, def in defs do
		local required = def.Required == true
		if not required and not keepOptional[def.Id] then
			continue
		end
		local plan: ObjectivePlan = {
			id = def.Id,
			type = def.Type,
			required = required,
			bonusPct = if required then 0 else (def.BonusPct or rules.ObjectiveBonusPct),
		}
		local group = def.Group or (if def.Type == "Keycard" then "Keycard" else def.Id)
		local groupAnchors = {}
		for _, anchor in anchors do
			if anchor.Group == group then
				table.insert(groupAnchors, anchor.Id)
			end
		end
		plan.anchors = groupAnchors

		if def.Type == "Keycard" then
			local free = {}
			for _, id in groupAnchors do
				if not used[id] then
					table.insert(free, id)
				end
			end
			local onGuard = guardCount > 0 and rng:next() < rules.KeycardOnGuardChance
			if onGuard or (#free == 0 and guardCount > 0) then
				plan.onGuard = true
				plan.guardIndex = rng:int(1, guardCount)
			elseif #free > 0 then
				local id = free[rng:int(1, #free)]
				used[id] = true
				plan.onGuard = false
				plan.anchorId = id
			else
				table.insert(warnings, `keycard {def.Id}: no anchor and no guard`)
			end
		elseif def.Type == "Safe" then
			local minJams, maxJams = rules.DeviceJams[1] or 1, rules.DeviceJams[2] or rules.DeviceJams[1] or 1
			local count = rng:int(minJams, math.max(minJams, maxJams))
			local rolls = {}
			for _ = 1, count do
				table.insert(rolls, rng:next())
			end
			plan.jamPoints = CrackDevice.jamPoints(rolls, rules.JamWindow)
			if def.Loot then
				plan.loot = allocate(rng, anchors, used, def.Loot, heistInfo.lootTypes, nil, warnings, group)
			end
		end
		table.insert(objectives, plan)
	end

	return {
		seed = seed,
		heistId = heistInfo.heistId or job.heistId,
		difficulty = job.difficulty,
		modifierId = modifier,
		loot = loot,
		rareCount = rareCount,
		mainAnchor = mainAnchor,
		lockedEntrances = locked,
		openEntrances = open,
		activeExits = activeExits,
		inactiveExits = inactiveExits,
		secondExit = secondExit,
		guardCount = guardCount,
		otherNpcs = otherNpcs,
		guards = guards,
		inspector = inspector,
		hazards = hazards,
		objectives = objectives,
		warnings = warnings,
	}
end

return RoundPlan
