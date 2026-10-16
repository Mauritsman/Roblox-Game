--!strict
-- The other NPCs (beta-spec §4.2–4.4, §6.2): Boef (map 1, outdoors), Karel (every heist except the mini-job) and
-- the Health Inspector (Hot Job modifier), plus the round's modifier effects that are not guard numbers:
-- Power Cut (CameraService switches cameras and lamps off) and Wet Floor (puddles on the plan's hazard anchors).
-- Guards + these NPCs never exceed Config.Npc.Cap (7, Logic/NpcBudget): RoundPlan already sizes the guards, and
-- here the extras are skipped (Inspector, then Boef, then Karel) if the cap would still be exceeded.
-- Entry points (integration.md): Reset(), Spawn(plan, heistInfo, job), Clear().

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local NpcBudget = require(ReplicatedStorage.Shared.Logic.NpcBudget)
local Patrol = require(ReplicatedStorage.Shared.Logic.Patrol)
local Tags = require(ReplicatedStorage.Shared.Tags)

local AlarmService = require(script.Parent.AlarmService)
local CameraService = require(script.Parent.CameraService)
local GuardService = require(script.Parent.GuardService)
local HidingService = require(script.Parent.HidingService)
local MapService = require(script.Parent.MapService)

local Npc = script.Parent.Parent:WaitForChild("Npc")
local Boef = require(Npc.Boef)
local Inspector = require(Npc.Inspector)
local Karel = require(Npc.Karel)
local Puddles = require(Npc.Puddles)
local Rig = require(Npc.Rig)
local Targets = require(Npc.Targets)

local NpcService = {}

type Entry = {
	kind: string,
	model: Model,
	step: (self: any, dt: number) -> (),
	destroy: (self: any) -> (),
	bubble: (self: any, seconds: number, by: Player?) -> boolean,
}

local npcs: { Entry } = {}
local boef: Boef.Boef? = nil

local function hearNoise(position: Vector3, radius: number, kind: string, by: Player?)
	GuardService:HearNoise(position, radius, nil, kind, by)
end

local function addAlarm(reason: string, points: number?, player: Player?)
	AlarmService:Add(reason, points, player)
end

local function alertNearest(position: Vector3, count: number)
	GuardService:AlertNearest(position, count)
end

local function taggedIn(tag: string, level: Instance?): { Instance }
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

local function positions(list: any): { Vector3 }
	local result = {}
	if type(list) == "table" then
		for _, item in list do
			if typeof(item) == "Vector3" then
				table.insert(result, item)
			elseif type(item) == "table" and typeof(item.Pos) == "Vector3" then
				table.insert(result, item.Pos)
			end
		end
	end
	return result
end

local function spawnKarel(folder: Instance, level: Instance?): boolean
	local homeInst = taggedIn(Tags.KarelHome, level)[1]
	local route = positions(MapService.Points.KarelRoute)
	local home = if homeInst then Targets.positionOf(homeInst) else route[1]
	if not home then
		return false
	end
	local karel = Karel.new(folder, home, route, {
		addAlarm = addAlarm,
		alertNearest = alertNearest,
		endDistraction = function(position: Vector3)
			GuardService:EndDistraction(position, Config.Gadgets.Noisemaker.HearRadius)
		end,
		alarmLevel = function(): number
			return AlarmService.Level
		end,
	})
	table.insert(npcs, karel :: any)
	return true
end

local function spawnBoef(folder: Instance, level: Instance?): boolean
	local zones: { BasePart } = {}
	for _, inst in taggedIn(Tags.DogZone, level) do
		if inst:IsA("BasePart") then
			table.insert(zones, inst)
		end
	end
	if #zones == 0 then
		return false
	end
	local dog = Boef.new(folder, zones, positions(MapService.Points.DogRoute), {
		hearNoise = hearNoise,
		hiddenPlayers = function()
			return HidingService:HiddenPlayers()
		end,
	})
	boef = dog
	table.insert(npcs, dog :: any)
	return true
end

local function spawnInspector(folder: Instance, plan: any, heistInfo: any): boolean
	local guardPlan = plan and plan.inspector
	if not guardPlan then
		return false
	end
	local routes = (heistInfo and heistInfo.routes) or MapService.Points.GuardRoutes
	local variant = Patrol.variant(routes, guardPlan.routeId, guardPlan.variant)
	if not variant then
		return false
	end
	local steps = Patrol.steps(variant, guardPlan.waits)
	local inspector = Inspector.new(folder, steps, Patrol.startIndex(guardPlan.start, #steps), {
		addAlarm = addAlarm,
		alertNearest = alertNearest,
	})
	if not inspector then
		return false
	end
	table.insert(npcs, inspector :: any)
	return true
end

--------------------------------------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------------------------------------

function NpcService:Clear()
	for _, npc in npcs do
		local ok, err = pcall(function()
			npc:destroy()
		end)
		if not ok then
			warn("[NpcService] destroy failed:", err)
		end
	end
	table.clear(npcs)
	boef = nil
	Puddles.clear()
	CameraService:SetPowerCut(false)
end

function NpcService:Reset()
	NpcService:Clear()
end

function NpcService:Count(): number
	return #npcs
end

function NpcService:Spawn(plan: any, heistInfo: any, job: any)
	NpcService:Clear()
	local level: Instance? = (heistInfo and heistInfo.level) or MapService.Level
	local folder = Rig.folder(level, "Npcs")
	local modifier = (job and job.modifierId) or (plan and plan.modifierId)
	local guards = if plan and type(plan.guardCount) == "number"
		then plan.guardCount
		else GuardService:Count()
	local wantKarel = heistInfo == nil or heistInfo.hasKarel ~= false
	local wantDog = heistInfo ~= nil and heistInfo.hasDog == true
	local wantInspector = modifier == "HealthInspector"
	local extra = if heistInfo and type(heistInfo.extraNpcs) == "number" then heistInfo.extraNpcs else 0
	local room = Config.Npc.Cap - guards - extra

	-- Priority: Karel, Boef, Inspector (the cap check only bites when the plan was sized for fewer NPCs).
	local others = 0
	if wantKarel and others < room and spawnKarel(folder, level) then
		others += 1
	end
	if wantDog and others < room and spawnBoef(folder, level) then
		others += 1
	end
	if wantInspector and others < room and spawnInspector(folder, plan, heistInfo) then
		others += 1
	end
	local expected = NpcBudget.others({
		karel = wantKarel,
		dog = wantDog,
		inspector = if wantInspector then 1 else 0,
	})
	if others < expected and RunService:IsStudio() then
		warn(`[NpcService] spawned {others} of {expected} NPCs (missing KarelHome / DogZone / spare route?)`)
	end

	if modifier == "PowerCut" then
		CameraService:SetPowerCut(true)
	end
	if modifier == "WetFloor" and plan and heistInfo then
		Puddles.spawn(level or workspace, plan.hazards, heistInfo.hazardParts)
	end
end

function NpcService:Start()
	Puddles.setNoise(hearNoise)
	GuardService:SetNpcBubbleHandler(function(model: Instance, seconds: number, by: Player?): boolean
		for _, npc in npcs do
			if npc.model == model or model:IsDescendantOf(npc.model) then
				return npc:bubble(seconds, by)
			end
		end
		return false
	end)
	GuardService.Noise:Connect(function(position: Vector3, _radius: number, kind: string, by: Player?)
		local dog = boef
		if dog then
			dog:noise(position, kind, by)
		end
	end)
	MapService.LevelBuilt:Connect(function()
		-- The NPCs went with the old level; forget them (SetupService spawns the new ones).
		for index = #npcs, 1, -1 do
			if npcs[index].model.Parent == nil then
				table.remove(npcs, index)
			end
		end
		if boef and boef.model.Parent == nil then
			boef = nil
		end
		Puddles.clear()
	end)

	local puddleTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		for index = #npcs, 1, -1 do
			local npc = npcs[index]
			if npc.model.Parent == nil then
				table.remove(npcs, index)
				continue
			end
			local ok, err = pcall(function()
				npc:step(dt)
			end)
			if not ok then
				warn(`[NpcService] {npc.kind} update failed:`, err)
			end
		end
		puddleTimer += dt
		if puddleTimer >= 0.1 then
			puddleTimer = 0
			Puddles.step()
		end
	end)
end

return NpcService
