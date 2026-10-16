--!strict
-- Sets up one heist round (beta-spec §6.1): builds the heist (MapService:Build), reads the level into `heistInfo`
-- (anchors, entrances, exits, hazards, routes, definition fields), runs Logic/RoundPlan.generate, applies
-- entrances / exits, spawns the loot, and calls the other packages' setup functions (integration.md):
-- AlarmService:Reset, CaptureService:Reset, GuardService:Spawn, HidingService/NpcService:Reset+Spawn,
-- ObjectiveService:Setup, MapRuntimeService:Setup — each skipped when that service or method does not exist yet.
--
-- A level without LootAnchors or Exits (map 1 before its retrofit) gets a temporary fallback layout: a van zone
-- around Points.Spawn, the main loot where the prototype's `Goal` was, and anchors along the fallback guard route.
--
-- Entry points: Apply(job, heistInfo?) → (plan, heistInfo), Teardown(), GetHeistInfo(), GetPlan(), GetJob(),
-- JobCard() (the `JobCard` payload).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Difficulty = require(ReplicatedStorage.Shared.Logic.Difficulty)
local RoundPlan = require(ReplicatedStorage.Shared.Logic.RoundPlan)

local Optional = require(script.Parent.Parent.Lib.Optional)
local LootService = require(script.Parent.LootService)
local MapService = require(script.Parent.MapService)

local SetupService = {}

export type Job = {
	cardId: string?,
	heistId: string,
	difficulty: string,
	modifierId: string?,
	isHotJob: boolean?,
	mostWanted: boolean?,
	seed: number,
	crewSize: number,
	roundId: string?,
	tier: Difficulty.Round?, -- the tier's numbers (filled by Apply)
}

-- Map 1's loot (beta-spec §2.1), used when a heist definition has no `Loot` yet.
local FALLBACK_LOOT: { RoundPlan.LootEntry } = {
	{ Type = "CheeseCube", Count = 6 },
	{ Type = "TipJar", Count = 2 },
	{ Type = "CashDrawer", Count = 1 },
	{ Type = "CheeseWheel", Count = 8 },
	{ Type = "BigWheel", Count = 2 },
	{ Type = "GoldenGouda", Count = 1 },
}
local FALLBACK_CLASSES = { "Medium", "Small", "Medium", "Heavy", "Medium", "Small", "Medium", "Small" }

local currentPlan: RoundPlan.Plan? = nil
local currentInfo: any = nil
local currentJob: Job? = nil

local function taggedIn(tag: string, root: Instance): { Instance }
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(root) then
			table.insert(list, inst)
		end
	end
	return list
end

local function str(value: any): string?
	return if type(value) == "string" and value ~= "" then value else nil
end

local function positionOf(inst: Instance): Vector3
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return Vector3.zero
end

-- Stable order for instances without ids: by name, then position.
local function sortStable(list: { Instance })
	table.sort(list, function(a, b)
		if a.Name ~= b.Name then
			return a.Name < b.Name
		end
		local pa, pb = positionOf(a), positionOf(b)
		if pa.X ~= pb.X then
			return pa.X < pb.X
		end
		return pa.Z < pb.Z
	end)
end

local function invisiblePart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function floorAt(position: Vector3, level: Instance): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { level, workspace.Terrain }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
	return if hit then hit.Position else position
end

--------------------------------------------------------------------------------------------------------------
-- Fallback layout (levels without the beta contract)
--------------------------------------------------------------------------------------------------------------

local function buildFallback(level: Instance, points: any, needExit: boolean, needAnchors: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "FallbackLayout"
	folder.Parent = level
	local spawn: Vector3 = if points and typeof(points.Spawn) == "Vector3"
		then points.Spawn
		else Vector3.new(0, 3, 0)

	if needExit then
		local exit = Instance.new("Model")
		exit.Name = "FallbackVan"
		exit:SetAttribute(Tags.ExitKind, "Van")
		exit.Parent = folder
		local zone =
			invisiblePart("BankZone", Vector3.new(12, 8, 12), CFrame.new(spawn + Vector3.new(0, 1, 0)), exit)
		zone:SetAttribute(Tags.Session, "Crew")
		CollectionService:AddTag(zone, Tags.BankZone)
		CollectionService:AddTag(exit, Tags.Exit)
	end

	if needAnchors then
		local count = 0
		local function anchor(class: string, ground: Vector3)
			count += 1
			local part = invisiblePart("LootAnchor", Vector3.new(1, 0.2, 1), CFrame.new(ground), folder)
			part:SetAttribute(Tags.AnchorClass, class)
			part:SetAttribute(Tags.AnchorId, `Fallback{count}`)
			part:SetAttribute(Tags.Zone, "Fallback")
			CollectionService:AddTag(part, Tags.LootAnchor)
		end
		-- Main loot where the prototype's Goal was; that Goal and its stand-in Gouda go.
		local goal = taggedIn(Tags.Goal, level)[1]
		local mainAt: Vector3? = nil
		if goal and goal:IsA("BasePart") then
			mainAt = floorAt(goal.Position, level)
			for _, sibling in (goal.Parent :: Instance):GetChildren() do
				if sibling.Name == "GoldenGouda" or sibling.Name == "GoudaStub" then
					sibling:Destroy()
				end
			end
			goal:Destroy()
		end
		local route = if points and type(points.GuardRoute) == "table" then points.GuardRoute else {}
		local spots: { Vector3 } = {}
		for index, point in route do
			local nextPoint = route[index % #route + 1]
			table.insert(spots, point)
			table.insert(spots, (point + nextPoint) / 2)
		end
		if mainAt == nil and #spots > 0 then
			local far, farDistance = spots[1], -1
			for _, spot in spots do
				local d = (spot - spawn).Magnitude
				if d > farDistance then
					far, farDistance = spot, d
				end
			end
			mainAt = floorAt(far, level)
		end
		if mainAt then
			anchor("Main", mainAt)
		end
		for index, spot in spots do
			anchor(FALLBACK_CLASSES[(index - 1) % #FALLBACK_CLASSES + 1], floorAt(spot, level))
		end
	end
	warn("[SetupService] level has no beta loot anchors/exits yet: using the fallback layout")
end

--------------------------------------------------------------------------------------------------------------
-- Reading the level
--------------------------------------------------------------------------------------------------------------

-- Reads `level` (built from `heist`) into the RoundPlan heistInfo plus the instances to apply the plan to.
function SetupService:ReadLevel(level: Instance, heist: any): any
	local points = MapService.Points
	local hasAnchors, hasExit = false, false
	for _, inst in taggedIn(Tags.LootAnchor, level) do
		local session = inst:GetAttribute(Tags.Session)
		if session == nil or session == "Crew" then
			hasAnchors = true
			break
		end
	end
	hasExit = #taggedIn(Tags.Exit, level) > 0
	local fallback = not hasAnchors or not hasExit
	if fallback then
		buildFallback(level, points, not hasExit, not hasAnchors)
	end

	local anchors: { RoundPlan.Anchor } = {}
	local anchorParts: { [string]: BasePart } = {}
	local unnamed = 0
	local anchorList = taggedIn(Tags.LootAnchor, level)
	sortStable(anchorList)
	for _, inst in anchorList do
		local session = inst:GetAttribute(Tags.Session)
		local class = str(inst:GetAttribute(Tags.AnchorClass))
		if inst:IsA("BasePart") and class and (session == nil or session == "Crew") then
			local id = str(inst:GetAttribute(Tags.AnchorId))
			if not id then
				unnamed += 1
				id = `{inst.Name}#{unnamed}`
			end
			if anchorParts[id :: string] then
				warn(`[SetupService] duplicate AnchorId {id}`)
			else
				anchorParts[id :: string] = inst
				table.insert(anchors, {
					Id = id :: string,
					Class = class :: string,
					Group = str(inst:GetAttribute(Tags.Group)),
					Fixed = inst:GetAttribute(Tags.Fixed) == true,
					Opener = inst:GetAttribute(Tags.Opener) == true,
					Zone = str(inst:GetAttribute(Tags.Zone)),
				})
			end
		end
	end

	local entrances: { string } = {}
	local entranceModels: { [string]: Instance } = {}
	local entranceList = taggedIn(Tags.Entrance, level)
	sortStable(entranceList)
	for _, inst in entranceList do
		local id = str(inst:GetAttribute(Tags.EntranceId)) or inst.Name
		if not entranceModels[id] then
			entranceModels[id] = inst
			table.insert(entrances, id)
		end
	end

	local exits: { RoundPlan.ExitInfo } = {}
	local exitModels: { [string]: Instance } = {}
	local exitList = taggedIn(Tags.Exit, level)
	sortStable(exitList)
	for _, inst in exitList do
		local id = inst.Name
		local n = 1
		while exitModels[id] do
			n += 1
			id = `{inst.Name}#{n}`
		end
		exitModels[id] = inst
		table.insert(exits, {
			Id = id,
			Kind = str(inst:GetAttribute(Tags.ExitKind)),
			Optional = inst:GetAttribute(Tags.Optional) == true,
		})
	end

	local hazards: { string } = {}
	local hazardParts: { [string]: Instance } = {}
	local hazardList = taggedIn(Tags.HazardAnchor, level)
	sortStable(hazardList)
	for index, inst in hazardList do
		local id = `{inst.Name}#{index}`
		hazardParts[id] = inst
		table.insert(hazards, id)
	end

	local stars = if heist and type(heist.Stars) == "table" then heist.Stars else { 500, 1500, 2500 }
	return {
		heistId = if heist then heist.Id else nil,
		heistName = if heist then heist.DisplayName else "Heist",
		def = heist,
		level = level,
		points = points,
		anchors = anchors,
		anchorParts = anchorParts,
		loot = if heist and type(heist.Loot) == "table" then heist.Loot else FALLBACK_LOOT,
		lootTypes = Config.Loot.Types,
		entrances = entrances,
		entranceModels = entranceModels,
		exits = exits,
		exitModels = exitModels,
		routes = if points and type(points.GuardRoutes) == "table" then points.GuardRoutes else nil,
		hazards = hazards,
		hazardParts = hazardParts,
		objectives = if heist then heist.Objectives else nil,
		guardBonus = if heist then heist.GuardBonus else nil,
		hasDog = if heist then heist.HasDog == true else false,
		hasKarel = true,
		extraNpcs = if heist then heist.ExtraNpcs else nil,
		stars = stars,
		roundSeconds = if heist then heist.RoundSeconds else nil,
		loudEscape = if heist then heist.LoudEscape else nil,
		fallback = fallback,
		rules = RoundPlan.rulesFrom(Config),
	}
end

--------------------------------------------------------------------------------------------------------------
-- Applying the plan
--------------------------------------------------------------------------------------------------------------

local function applyEntrances(plan: RoundPlan.Plan, info: any)
	for _, id in plan.lockedEntrances do
		local model = info.entranceModels[id]
		if model then
			-- Locked: the blocker stays; its Crowbar spots are switched off.
			for _, inst in model:GetDescendants() do
				if CollectionService:HasTag(inst, Tags.Pryable) then
					CollectionService:RemoveTag(inst, Tags.Pryable)
					inst:SetAttribute(Tags.Disabled, true)
					task.defer(function()
						for _, child in inst:GetChildren() do
							if child:IsA("ProximityPrompt") then
								child:Destroy()
							end
						end
					end)
				end
			end
		end
	end
	for _, id in plan.openEntrances do
		local model = info.entranceModels[id]
		local blocker = model and model:FindFirstChild("LockedBlocker")
		if blocker then
			blocker:Destroy()
		end
	end
end

local function applyExits(plan: RoundPlan.Plan, info: any)
	for _, id in plan.inactiveExits do
		local model = info.exitModels[id]
		if model then
			model:Destroy()
		end
		info.exitModels[id] = nil
	end
	for _, id in plan.activeExits do
		local model = info.exitModels[id]
		if model then
			for _, inst in model:GetDescendants() do
				if inst:IsA("BasePart") and CollectionService:HasTag(inst, Tags.BankZone) then
					inst.CanCollide = false
					inst.CanTouch = false
					inst.CanQuery = false
					if inst:GetAttribute(Tags.Session) == nil then
						inst:SetAttribute(Tags.Session, "Crew")
					end
				end
			end
		end
	end
end

-- Builds and sets up the round. `job` needs heistId, difficulty, seed and crewSize (modifierId, isHotJob, roundId
-- optional). Pass `heistInfo` only to reuse an already-read level.
function SetupService:Apply(job: Job, heistInfo: any?): (RoundPlan.Plan, any)
	local tierRow = Difficulty.tier(Config.DifficultyTiers :: any, job.difficulty)
	job.tier = Difficulty.apply(Difficulty.base(Config), tierRow)

	local info = heistInfo
	if info == nil then
		local ok, level = pcall(function()
			return MapService:Build(job.heistId)
		end)
		if not ok then
			warn(`[SetupService] building {job.heistId} failed: {level}; building the default heist`)
			level = MapService:Build()
		end
		info = SetupService:ReadLevel(level, MapService.CurrentHeist)
		job.heistId = info.heistId or job.heistId
	end

	local plan = RoundPlan.generate(job.seed, info :: any, job.crewSize, job :: any)
	if RunService:IsStudio() then
		for _, message in plan.warnings do
			if not info.fallback then
				warn(`[RoundPlan] {message}`)
			end
		end
	end
	currentPlan, currentInfo, currentJob = plan, info, job

	applyEntrances(plan, info)
	applyExits(plan, info)

	LootService:Clear("Crew")
	LootService:Spawn(plan.loot, info)

	Optional.call("AlarmService", "Reset")
	Optional.call("CaptureService", "Reset")
	Optional.call("HidingService", "Reset")
	Optional.call("HidingService", "Spawn", plan, info, job)
	Optional.call("NpcService", "Reset")
	Optional.call("NpcService", "Spawn", plan, info, job)
	Optional.call("GuardService", "Spawn", plan, info, job)
	Optional.call("ObjectiveService", "Setup", plan, info, job)
	Optional.call("MapRuntimeService", "Setup", info.level, info, job)
	return plan, info
end

-- Removes the round's NPCs, objectives and loot (the level itself stays until the next Build).
function SetupService:Teardown()
	Optional.call("GuardService", "Clear")
	Optional.call("NpcService", "Clear")
	Optional.call("HidingService", "Clear")
	Optional.call("ObjectiveService", "Clear")
	Optional.call("MapRuntimeService", "Clear")
	Optional.call("CaptureService", "Reset")
	LootService:Clear("Crew")
end

function SetupService:GetHeistInfo(): any
	return currentInfo
end

function SetupService:GetPlan(): RoundPlan.Plan?
	return currentPlan
end

function SetupService:GetJob(): Job?
	return currentJob
end

-- The `JobCard` payload (contracts.md §1.2).
function SetupService:JobCard(): { [string]: any }?
	local plan, info, job = currentPlan, currentInfo, currentJob
	if not plan or not info or not job then
		return nil
	end
	local mainName, mainZone, mainPos = "", "", Vector3.zero
	for _, item in plan.loot do
		if item.anchorId == plan.mainAnchor then
			local def = Config.Loot.Types[item.type]
			mainName = (def and def.Display) or item.type
			local part = info.anchorParts[item.anchorId]
			if part then
				mainPos = part.Position
				mainZone = str(part:GetAttribute(Tags.Zone)) or ""
			end
			break
		end
	end
	local objectives = {}
	for _, objective in plan.objectives do
		table.insert(objectives, {
			id = objective.id,
			type = objective.type,
			required = objective.required,
			bonusPct = objective.bonusPct,
		})
	end
	return {
		heistId = job.heistId,
		heistName = info.heistName,
		difficulty = job.difficulty,
		modifierId = job.modifierId,
		isHotJob = job.isHotJob == true,
		mainLootName = mainName,
		mainZone = mainZone,
		mainPos = mainPos,
		lockedEntrances = table.clone(plan.lockedEntrances),
		objectives = objectives,
		stars = table.clone(info.stars),
		secondExit = plan.secondExit,
	}
end

return SetupService
