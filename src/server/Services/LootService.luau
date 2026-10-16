--!strict
-- Loot registry (beta-spec §2): spawning on anchors, models, GrabPrompts, states, banking, sessions, fragile damage
-- and the Karel return API. Carrying itself (pockets, hands, throw, roll, two-carry, the bank loop) is CarryService.
--
-- A loot item is a record (the truth) plus, while it is in the world, a Model in `<area>.Loot` with PrimaryPart
-- `Handle` (invisible, anchored unless welded to a carrier) and a `Visual` welded to it with a `Weld` named
-- `VisualWeld` (clients animate its C0 for rolling and smoothing). Pocketed loot has no model; it is rebuilt when
-- it falls out. Never free physics: Placed/Dropped/Thrown/two-carry = anchored, Carried/Returning = welded.
--
-- Entry points (integration.md): Spawn(planLoot, heistInfo), Clear(session?), ReturnHome(lootPart),
-- ApplyDamage(lootPart, factor, reason), GetVanTotal(session?), Banked (Signal: player, lootType, value, session),
-- MainLootLifted (Signal: player, lootName, session). Extra for Karel (package B): SetReturning(lootPart, carrier).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)
local LootRules = require(ReplicatedStorage.Shared.Logic.LootRules)

local Meta = require(script.Parent.Parent.Lib.Meta)
local StatsService = require(script.Parent.StatsService)

local LootService = {}

export type Loot = {
	id: string,
	type: string,
	class: string, -- "Small" | "Medium" | "Heavy" | "Main"
	name: string,
	value: number,
	baseValue: number,
	session: string, -- "Crew" | "Tutorial1" | "Tutorial2" | "Practice"
	state: string, -- "Placed" | "Carried" | "Thrown" | "Dropped" | "Returning" | "Banked"
	model: Model?,
	handle: BasePart?,
	prompt: ProximityPrompt?,
	carrierId: number?,
	helperId: number?,
	homeAnchor: string?,
	home: CFrame,
	area: Instance, -- the top-level area the loot belongs to (Level, Garage, MiniJob_1, …)
	main: boolean, -- the heist's main loot (lifting starts LOCKDOWN)
	canRoll: boolean,
	smelly: boolean,
	fragile: boolean,
	objective: boolean, -- never banked for Cash (keycard)
	lifted: boolean,
	lastHolderId: number?,
	droppedAt: number?,
	zone: string?,
}

LootService.Banked = Signal.new() :: Signal.Signal<Player, string, number, string>
LootService.MainLootLifted = Signal.new() :: Signal.Signal<Player, string, string>
-- Fired when the records of a session were removed (CarryService forgets what players held).
LootService.Cleared = Signal.new() :: Signal.Signal<string>
-- Set by CarryService: what a GrabPrompt trigger does.
LootService.OnPrompt = nil :: ((player: Player, loot: Loot) -> ())?
-- Set by RoundService: may this BankZone be used now (exit usable)? nil = always.
LootService.ZoneFilter = nil :: ((zone: BasePart) -> boolean)?

local L = Config.Loot
local Types = L.Types

local records: { [string]: Loot } = {}
local nextId = 0
local vanTotals: { [string]: number } = {}
local bankedLists: { [string]: { { lootId: string, name: string, class: string, value: number } } } = {}
local mainBanked: { [string]: boolean } = {}
local firstBank: { [number]: boolean } = {}

local HANDLE_SIZE: { [string]: Vector3 } = {
	Small = Vector3.new(1.2, 1, 1.2),
	Medium = Vector3.new(3, 1, 3),
	Heavy = Vector3.new(4.2, 1.6, 4.2),
	Main = Vector3.new(4.2, 2, 4.2),
}

local CHEESE = Color3.fromRGB(242, 196, 64)
local GOLD = Color3.fromRGB(255, 205, 40)

type Look = {
	prop: string?,
	shape: string, -- "Disc" | "Block" | "Jar"
	size: Vector3, -- primitive size (disc: x = diameter, y = height)
	color: Color3,
	material: Enum.Material,
	stripTexture: boolean?,
}

local LOOKS: { [string]: Look } = {
	CheeseCube = {
		shape = "Block",
		size = Vector3.new(1.1, 0.9, 1.1),
		color = CHEESE,
		material = Enum.Material.SmoothPlastic,
	},
	TipJar = {
		shape = "Jar",
		size = Vector3.new(0.9, 1, 0.9),
		color = Color3.fromRGB(200, 230, 240),
		material = Enum.Material.Glass,
	},
	CashDrawer = {
		shape = "Block",
		size = Vector3.new(1.2, 0.6, 1.1),
		color = Color3.fromRGB(60, 90, 70),
		material = Enum.Material.Metal,
	},
	Keycard = {
		shape = "Block",
		size = Vector3.new(0.9, 0.1, 0.6),
		color = Color3.fromRGB(70, 140, 255),
		material = Enum.Material.Neon,
	},
	CheeseWheel = {
		prop = "CheeseWheel",
		shape = "Disc",
		size = Vector3.new(3, 0.9, 3),
		color = CHEESE,
		material = Enum.Material.SmoothPlastic,
	},
	BlueMoon = {
		prop = "CheeseWheel",
		shape = "Disc",
		size = Vector3.new(3, 0.9, 3),
		color = Color3.fromRGB(110, 150, 235),
		material = Enum.Material.SmoothPlastic,
		stripTexture = true,
	},
	BigWheel = {
		prop = "CheeseWheel",
		shape = "Disc",
		size = Vector3.new(4.2, 1.5, 4.2),
		color = Color3.fromRGB(230, 170, 40),
		material = Enum.Material.SmoothPlastic,
	},
	GoldenGouda = {
		prop = "GoldenGouda",
		shape = "Disc",
		size = Vector3.new(4.2, 2, 4.2),
		color = GOLD,
		material = Enum.Material.Foil,
		stripTexture = true,
	},
}

local CLASS_COLOR: { [string]: Color3 } = {
	Small = Color3.fromRGB(240, 220, 120),
	Medium = CHEESE,
	Heavy = Color3.fromRGB(230, 170, 40),
	Main = GOLD,
}

local function now(): number
	return workspace:GetServerTimeNow()
end

--------------------------------------------------------------------------------------------------------------
-- Sessions
--------------------------------------------------------------------------------------------------------------

-- The loot session a player plays in: player attribute `Session` (TutorialService may set "Tutorial2"), else
-- Activity Crew → "Crew", Tutorial → "Tutorial1", Garage → "Practice".
function LootService:SessionOf(player: Player): string
	local override = player:GetAttribute("Session")
	if type(override) == "string" and override ~= "" then
		return override
	end
	local activity = player:GetAttribute(Tags.Activity)
	if activity == "Crew" then
		return "Crew"
	elseif activity == "Tutorial" then
		return "Tutorial1"
	end
	return "Practice"
end

function LootService:SessionPlayers(session: string): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if LootService:SessionOf(player) == session then
			table.insert(list, player)
		end
	end
	return list
end

function LootService:SendSession(session: string, name: string, ...: any)
	for _, player in LootService:SessionPlayers(session) do
		Net.send(player, name, ...)
	end
end

--------------------------------------------------------------------------------------------------------------
-- Models
--------------------------------------------------------------------------------------------------------------

local function typeDef(lootType: string): Config.LootType
	return Types[lootType] or { Class = "Medium", Value = 0 }
end

local function areaOf(inst: Instance): Instance
	local current = inst
	while current.Parent and current.Parent ~= workspace do
		current = current.Parent
	end
	return if current.Parent == workspace then current else workspace
end

local function lootFolder(area: Instance): Folder
	local folder = area:FindFirstChild("Loot")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "Loot"
	created.Parent = area
	return created
end

local function primitive(look: Look, class: string): Part
	local part = Instance.new("Part")
	part.Name = "Visual"
	part.Color = look.color
	part.Material = look.material
	if look.shape == "Disc" or look.shape == "Jar" then
		part.Shape = Enum.PartType.Cylinder
		-- A cylinder's axis is its X: size = (height, diameter, diameter); the weld turns it upright.
		part.Size = Vector3.new(look.size.Y, look.size.X, look.size.Z)
	else
		part.Size = look.size
	end
	if look.material == Enum.Material.Glass then
		part.Transparency = 0.35
	end
	if class == "Main" then
		part.Reflectance = 0.15
	end
	return part
end

-- The visible part of the loot: a prop from ServerStorage.Props (by type name or the look's prop), else a primitive.
-- Returns (visual instance, root part, rotation for the weld).
local function makeVisual(lootType: string, class: string, size: Vector3): (Instance, BasePart, CFrame)
	local fallback: Look = {
		shape = "Block",
		size = size * 0.9,
		color = CLASS_COLOR[class] or CHEESE,
		material = Enum.Material.SmoothPlastic,
	}
	local look: Look = LOOKS[lootType] or fallback
	local props = ServerStorage:FindFirstChild("Props")
	local template = props
		and (props:FindFirstChild(lootType) or (look.prop and props:FindFirstChild(look.prop)))
	if template and (template:IsA("Model") or template:IsA("BasePart")) then
		local clone = template:Clone()
		local parts: { BasePart } = {}
		if clone:IsA("BasePart") then
			table.insert(parts, clone)
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			elseif d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		if #parts > 0 then
			-- Fit the prop inside the handle box.
			if clone:IsA("Model") then
				local _, extents = clone:GetBoundingBox()
				local scale = math.min(size.X / extents.X, size.Y / extents.Y, size.Z / extents.Z)
				if scale > 0 and scale < math.huge then
					clone:ScaleTo(clone:GetScale() * scale)
				end
			else
				local part = clone :: BasePart
				local scale = math.min(size.X / part.Size.X, size.Y / part.Size.Y, size.Z / part.Size.Z)
				part.Size *= scale
			end
			for _, part in parts do
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.Massless = true
				if look.stripTexture and part:IsA("MeshPart") then
					part.TextureID = ""
					part.Color = look.color
					part.Material = look.material
					if class == "Main" then
						part.Reflectance = 0.15
					end
				end
			end
			clone.Name = "Visual"
			local root = if clone:IsA("Model") then (clone.PrimaryPart or parts[1]) else clone :: BasePart
			return clone, root, CFrame.identity
		end
		clone:Destroy()
	end
	local part = primitive(look, class)
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = true
	local rotation = if part.Shape == Enum.PartType.Cylinder
		then CFrame.Angles(0, 0, math.rad(90))
		else CFrame.identity
	return part, part, rotation
end

local function setQueryable(loot: Loot, on: boolean)
	local model = loot.model
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= loot.handle then
			d.CanQuery = on
		end
	end
end

local function promptText(loot: Loot): (string, boolean)
	if loot.state == "Carried" then
		local heavy = loot.class == "Heavy" or loot.class == "Main"
		return LootRules.ActionText.Help, heavy and loot.helperId == nil
	end
	local open = loot.state == "Placed" or loot.state == "Dropped" or loot.state == "Returning"
	local action = if loot.class == "Small"
		then LootRules.ActionText.Pocket
		elseif loot.class == "Medium" then LootRules.ActionText.Grab
		else LootRules.ActionText.Lift
	return action, open
end

local function refreshPrompt(loot: Loot)
	local prompt = loot.prompt
	if prompt then
		local text, enabled = promptText(loot)
		prompt.ActionText = text
		prompt.Enabled = enabled
		-- ux's context-button icons: pocket / grab / lift.
		prompt:SetAttribute(
			"ContextIcon",
			if text == LootRules.ActionText.Pocket
				then "pocket"
				elseif text == LootRules.ActionText.Grab then "grab"
				else "lift"
		)
	end
end

local function writeAttributes(loot: Loot)
	local model = loot.model
	if not model then
		return
	end
	model:SetAttribute(Tags.LootId, loot.id)
	model:SetAttribute(Tags.LootType, loot.type)
	model:SetAttribute(Tags.LootName, loot.name)
	model:SetAttribute(Tags.LootClass, loot.class)
	model:SetAttribute(Tags.Value, loot.value)
	model:SetAttribute(Tags.BaseValue, loot.baseValue)
	model:SetAttribute(Tags.LootState, loot.state)
	model:SetAttribute(Tags.CarrierId, loot.carrierId)
	model:SetAttribute(Tags.HomeAnchor, loot.homeAnchor)
	model:SetAttribute(Tags.DroppedAt, loot.droppedAt)
	model:SetAttribute(Tags.Session, loot.session)
	model:SetAttribute(Tags.SpotKind, "loot")
end

local function buildModel(loot: Loot, cframe: CFrame)
	local size = HANDLE_SIZE[loot.class] or HANDLE_SIZE.Medium
	local model = Instance.new("Model")
	model.Name = loot.type

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Transparency = 1
	handle.Anchored = true
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = cframe
	handle.Parent = model
	model.PrimaryPart = handle

	local visual, root, rotation = makeVisual(loot.type, loot.class, size)
	if visual:IsA("Model") then
		local target = cframe * rotation
		visual:PivotTo(target)
		-- Centre the prop's bounding box on the handle.
		local box = visual:GetBoundingBox()
		visual:PivotTo(target * box:ToObjectSpace(visual:GetPivot()))
	else
		(visual :: BasePart).CFrame = cframe * rotation
	end
	visual.Parent = model
	if visual:IsA("Model") then
		for _, d in visual:GetDescendants() do
			if d:IsA("BasePart") and d ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	local visualWeld = Instance.new("Weld")
	visualWeld.Name = "VisualWeld"
	visualWeld.Part0 = handle
	visualWeld.Part1 = root
	visualWeld.C0 = handle.CFrame:ToObjectSpace(root.CFrame)
	visualWeld.Parent = handle
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= handle then
			d.Anchored = false
		end
	end

	if loot.main then
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = handle
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ObjectText = loot.name
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = if loot.class == "Heavy" or loot.class == "Main" then L.HeavyGrabHold else 0
	prompt.MaxActivationDistance = L.GrabRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = handle
	prompt.Triggered:Connect(function(player: Player)
		local handler = LootService.OnPrompt
		if handler and records[loot.id] == loot then
			handler(player, loot)
		end
	end)

	loot.model = model
	loot.handle = handle
	loot.prompt = prompt
	writeAttributes(loot)
	refreshPrompt(loot)
	CollectionService:AddTag(model, Tags.Loot)
	CollectionService:AddTag(model, Tags.Spottable)
	if loot.main then
		CollectionService:AddTag(model, Tags.MainLoot)
	end
	model.Parent = lootFolder(loot.area)
end

-- Removes the model (pocketed or banked loot).
function LootService:DestroyModel(loot: Loot)
	if loot.model then
		loot.model:Destroy()
	end
	loot.model = nil
	loot.handle = nil
	loot.prompt = nil
end

local function clearTrace(loot: Loot)
	local model = loot.model
	if model and CollectionService:HasTag(model, Tags.Trace) then
		CollectionService:RemoveTag(model, Tags.Trace)
		model:SetAttribute(Tags.TraceKind, nil)
		model:SetAttribute(Tags.TraceBy, nil)
	end
end

local function detach(loot: Loot)
	local handle = loot.handle
	if handle then
		for _, child in handle:GetChildren() do
			if child.Name == "CarryWeld" then
				child:Destroy()
			end
		end
	end
end

-- Changes the state, attributes and prompt. Use the helpers below for physics.
function LootService:SetState(loot: Loot, state: string)
	loot.state = state
	if state ~= "Dropped" then
		loot.droppedAt = nil
		clearTrace(loot)
	end
	if state ~= "Carried" and state ~= "Thrown" then
		loot.carrierId = nil
		loot.helperId = nil
	end
	writeAttributes(loot)
	refreshPrompt(loot)
	setQueryable(loot, state ~= "Carried" and state ~= "Thrown" and state ~= "Returning")
end

-- Anchored at a CFrame (Placed, Dropped, Thrown, two-carry). Rebuilds the model if it was pocketed.
function LootService:PlaceAt(loot: Loot, cframe: CFrame)
	if not loot.model or not loot.model.Parent then
		buildModel(loot, cframe)
	end
	detach(loot)
	local handle = loot.handle :: BasePart
	handle.Anchored = true
	handle.CFrame = cframe
end

-- Welded to a part (a carrier's root, Karel). The handle becomes part of that assembly.
function LootService:WeldTo(loot: Loot, part: BasePart, offset: CFrame)
	if not loot.model or not loot.model.Parent then
		buildModel(loot, part.CFrame * offset)
	end
	detach(loot)
	local handle = loot.handle :: BasePart
	handle.Anchored = true
	handle.CFrame = part.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = part
	weld.Part1 = handle
	weld.Parent = handle
	handle.Anchored = false
end

-- Dropped on the floor: Trace for Karel, DroppedAt.
function LootService:MarkDropped(loot: Loot, byUserId: number?)
	LootService:SetState(loot, "Dropped")
	loot.droppedAt = now()
	local model = loot.model
	if model then
		model:SetAttribute(Tags.DroppedAt, loot.droppedAt)
		if loot.session == "Crew" then
			model:SetAttribute(Tags.TraceKind, "DroppedLoot")
			model:SetAttribute(Tags.TraceBy, byUserId)
			CollectionService:AddTag(model, Tags.Trace)
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------------------------------------------------

-- Creates a loot item at `cframe` (its bottom centre, like an anchor) in `session`.
function LootService:SpawnAt(
	lootType: string,
	cframe: CFrame,
	session: string?,
	anchorId: string?,
	area: Instance?
): Loot
	local def = typeDef(lootType)
	nextId += 1
	local class = def.Class
	local size = HANDLE_SIZE[class] or HANDLE_SIZE.Medium
	local home = cframe * CFrame.new(0, size.Y / 2, 0)
	local loot: Loot = {
		id = `L{nextId}`,
		type = lootType,
		class = class,
		name = def.Display or lootType,
		value = def.Value,
		baseValue = def.Value,
		session = session or "Crew",
		state = "Placed",
		model = nil,
		handle = nil,
		prompt = nil,
		carrierId = nil,
		helperId = nil,
		homeAnchor = anchorId,
		home = home,
		area = area or (workspace:FindFirstChild("Level") or workspace),
		main = def.Lockdown == true or class == "Main",
		canRoll = def.CanRoll == true,
		smelly = def.Smelly == true,
		fragile = def.Fragile == true,
		objective = def.Objective == true,
		lifted = false,
		lastHolderId = nil,
		droppedAt = nil,
		zone = nil,
	}
	records[loot.id] = loot
	buildModel(loot, home)
	return loot
end

-- Spawns the plan's loot (RoundPlan PlacedLoot list) on the anchors in heistInfo.anchorParts.
-- heistInfo.session overrides the anchors' `Session` attribute (TutorialService).
function LootService:Spawn(planLoot: { any }, heistInfo: any): { Loot }
	local spawned = {}
	local parts: { [string]: BasePart } = if heistInfo and heistInfo.anchorParts
		then heistInfo.anchorParts
		else {}
	for _, item in planLoot do
		local anchor = parts[item.anchorId]
		if not anchor then
			for _, tagged in CollectionService:GetTagged(Tags.LootAnchor) do
				if tagged:IsA("BasePart") and tagged:GetAttribute(Tags.AnchorId) == item.anchorId then
					anchor = tagged
					break
				end
			end
		end
		if anchor then
			local sessionAttr = anchor:GetAttribute(Tags.Session)
			local session = (heistInfo and heistInfo.session)
				or (if type(sessionAttr) == "string" then sessionAttr else "Crew")
			local loot = LootService:SpawnAt(item.type, anchor.CFrame, session, item.anchorId, areaOf(anchor))
			local zone = anchor:GetAttribute(Tags.Zone)
			loot.zone = if type(zone) == "string" then zone else nil
			table.insert(spawned, loot)
		else
			warn(`[LootService] no anchor {item.anchorId} for {item.type}`)
		end
	end
	return spawned
end

-- Removes every loot item of a session (default "Crew"). Van totals stay until ResetSession.
function LootService:Clear(session: string?)
	local which = session or "Crew"
	for id, loot in records do
		if loot.session == which then
			LootService:DestroyModel(loot)
			records[id] = nil
		end
	end
	LootService.Cleared:Fire(which)
end

-- Removes one item for good (eaten by Boef, used up). It is not banked.
function LootService:Remove(target: Instance | string | Loot)
	local loot: Loot? = if type(target) == "table" then target :: Loot else LootService:Get(target :: any)
	if loot and records[loot.id] == loot then
		LootService:DestroyModel(loot)
		records[loot.id] = nil
	end
end

-- New round for a session: van total 0, banked list empty, first-bank funnel reset.
function LootService:ResetSession(session: string?)
	local which = session or "Crew"
	vanTotals[which] = 0
	bankedLists[which] = {}
	mainBanked[which] = false
	if which == "Crew" then
		table.clear(firstBank)
		ReplicatedStorage:SetAttribute(Tags.VanLoot, 0)
	end
end

-- The record for a loot Model, any part of it, or a LootId.
function LootService:Get(target: Instance | string | nil): Loot?
	if type(target) == "string" then
		return records[target]
	end
	if typeof(target) ~= "Instance" then
		return nil
	end
	local inst: Instance? = target :: Instance
	while inst and inst ~= workspace do
		local id = inst:GetAttribute(Tags.LootId)
		if type(id) == "string" then
			return records[id]
		end
		inst = inst.Parent
	end
	return nil
end

function LootService:All(): { [string]: Loot }
	return records
end

function LootService:GetVanTotal(session: string?): number
	return vanTotals[session or "Crew"] or 0
end

function LootService:GetBanked(
	session: string?
): { { lootId: string, name: string, class: string, value: number } }
	return table.clone(bankedLists[session or "Crew"] or {})
end

function LootService:MainBanked(session: string?): boolean
	return mainBanked[session or "Crew"] == true
end

--------------------------------------------------------------------------------------------------------------
-- Zones and banking
--------------------------------------------------------------------------------------------------------------

local function inside(part: BasePart, position: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

-- The usable BankZone of `session` containing `position`, or nil.
function LootService:BankZoneAt(position: Vector3, session: string): BasePart?
	for _, zone in CollectionService:GetTagged(Tags.BankZone) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(workspace) then
			local zoneSession = zone:GetAttribute(Tags.Session)
			local zs = if type(zoneSession) == "string" then zoneSession else "Crew"
			if zs == session and inside(zone, position) then
				local filter = LootService.ZoneFilter
				if filter == nil or filter(zone) then
					return zone
				end
			end
		end
	end
	return nil
end

-- Banks one item for `player` (pocket and hands are banked by CarryService through this). Returns success.
function LootService:Bank(loot: Loot, player: Player?): boolean
	if loot.state == "Banked" or loot.objective or not records[loot.id] then
		return false
	end
	if not LootRules.canBank(loot.session, loot.session) then
		return false
	end
	local session = loot.session
	LootService:SetState(loot, "Banked")
	LootService:DestroyModel(loot)
	records[loot.id] = nil

	vanTotals[session] = (vanTotals[session] or 0) + loot.value
	local list = bankedLists[session]
	if not list then
		list = {}
		bankedLists[session] = list
	end
	table.insert(list, { lootId = loot.type, name = loot.name, class = loot.class, value = loot.value })
	if loot.main then
		mainBanked[session] = true
	end
	local total = vanTotals[session]
	if session == "Crew" then
		ReplicatedStorage:SetAttribute(Tags.VanLoot, total)
	end

	local userId = if player then player.UserId else 0
	LootService:SendSession(session, "LootBanked", userId, loot.name, loot.class, loot.value, total)
	if player then
		StatsService:Event("LootBanked", player, { value = loot.value, class = loot.class, main = loot.main })
		if not firstBank[player.UserId] then
			firstBank[player.UserId] = true
			if session == "Crew" then
				Meta.RoundStep(
					player,
					ReplicatedStorage:GetAttribute(Tags.RoundId) :: string?,
					"FirstLootBanked"
				)
			end
		end
		if session ~= "Crew" and session ~= "Practice" then
			Meta.OnboardingStep(player, "FirstLootBanked")
		end
		LootService.Banked:Fire(player, loot.type, loot.value, session)
	end
	return true
end

-- The first lift of main loot: fires MainLootLifted once per item (RoundService starts LOCKDOWN).
function LootService:NotifyLifted(loot: Loot, player: Player)
	if not loot.main or loot.lifted then
		return
	end
	loot.lifted = true
	if loot.session == "Crew" then
		Net.broadcast("MainLootLifted", player.UserId, loot.name)
		Meta.RoundStep(player, ReplicatedStorage:GetAttribute(Tags.RoundId) :: string?, "MainLootLifted")
	else
		LootService:SendSession(loot.session, "MainLootLifted", player.UserId, loot.name)
		if loot.session ~= "Practice" then
			Meta.OnboardingStep(player, "GoudaLifted")
		end
	end
	LootService.MainLootLifted:Fire(player, loot.name, loot.session)
end

--------------------------------------------------------------------------------------------------------------
-- Value changes, Karel
--------------------------------------------------------------------------------------------------------------

-- Lowers the value by factor × base value (fragile landing, melting …), never below FragileMinFactor × base.
-- Returns the new value (nil = not loot).
function LootService:ApplyDamage(target: Instance | string, factor: number, reason: string?): number?
	local loot = LootService:Get(target)
	if not loot or loot.state == "Banked" or type(factor) ~= "number" or factor <= 0 then
		return if loot then loot.value else nil
	end
	local floor = math.floor(loot.baseValue * L.FragileMinFactor + 0.5)
	local value = math.max(floor, math.floor(loot.value - loot.baseValue * factor + 0.5))
	if value == loot.value then
		return value
	end
	loot.value = value
	writeAttributes(loot)
	local pct = if loot.baseValue > 0 then math.floor(value / loot.baseValue * 100 + 0.5) else 0
	LootService:SendSession(loot.session, "LootDamaged", loot.name, value, pct)
	if RunService:IsStudio() and reason then
		print(`[LootService] {loot.name} damaged ({reason}): {value}`)
	end
	return value
end

-- Karel picks up dropped loot to carry it home: welded to `carrier`, state Returning. Players may snatch it back
-- (the GrabPrompt stays on). Returns success.
function LootService:SetReturning(target: Instance | string, carrier: BasePart): boolean
	local loot = LootService:Get(target)
	if not loot or (loot.state ~= "Dropped" and loot.state ~= "Placed") or not loot.model then
		return false
	end
	LootService:WeldTo(loot, carrier, CFrame.new(0, 0, -2))
	LootService:SetState(loot, "Returning")
	return true
end

-- Puts loot back on its home anchor (Karel, splash, practice). Refused while a player carries it or after banking.
function LootService:ReturnHome(target: Instance | string): boolean
	local loot = LootService:Get(target)
	if not loot or loot.state == "Banked" or loot.state == "Carried" then
		return false
	end
	LootService:PlaceAt(loot, loot.home)
	LootService:SetState(loot, "Placed")
	LootService:SendSession(loot.session, "LootReturned", loot.name, loot.home.Position)
	return true
end

--------------------------------------------------------------------------------------------------------------
-- Practice yard and dev
--------------------------------------------------------------------------------------------------------------

local PRACTICE_TYPE: { [string]: string } = {
	Small = "CheeseCube",
	Medium = "CheeseWheel",
	Heavy = "BigWheel",
	Main = "BigWheel",
}

-- Loot on every practice anchor (LootAnchor with Session = "Practice", e.g. the Garage yard) that has none.
function LootService:SpawnPractice()
	local taken: { [string]: boolean } = {}
	for _, loot in records do
		if loot.session == "Practice" and loot.homeAnchor then
			taken[loot.homeAnchor] = true
		end
	end
	for _, anchor in CollectionService:GetTagged(Tags.LootAnchor) do
		if
			anchor:IsA("BasePart")
			and anchor:GetAttribute(Tags.Session) == "Practice"
			and anchor:IsDescendantOf(workspace)
		then
			local id = anchor:GetAttribute(Tags.AnchorId)
			local anchorId = if type(id) == "string" then id else anchor:GetFullName()
			if not taken[anchorId] then
				local class = anchor:GetAttribute(Tags.AnchorClass)
				local lootType = PRACTICE_TYPE[if type(class) == "string" then class else "Medium"]
					or "CheeseWheel"
				LootService:SpawnAt(lootType, anchor.CFrame, "Practice", anchorId, areaOf(anchor))
			end
		end
	end
end

-- Studio: spawn loot at the player's feet and hand it over (DevGive).
function LootService:DevGive(player: Player, lootType: string): boolean
	if not RunService:IsStudio() or Types[lootType] == nil then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local loot = LootService:SpawnAt(
		lootType,
		CFrame.new(root.Position - Vector3.new(0, 3, 0)),
		LootService:SessionOf(player),
		nil,
		workspace:FindFirstChild("Level") or workspace
	)
	local handler = LootService.OnPrompt
	if handler then
		handler(player, loot)
	end
	return true
end

function LootService:Start()
	LootService:ResetSession("Crew")
	LootService:SpawnPractice()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Garage" then
			task.delay(1, function()
				LootService:SpawnPractice()
			end)
		end
	end)
	if RunService:IsStudio() then
		Net.onRequest("DevGive", function(player: Player, lootType: any)
			if type(lootType) == "string" then
				LootService:DevGive(player, lootType)
			end
		end)
	end
end

return LootService
