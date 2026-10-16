--!strict
-- Shop (owner: meta): buying and equipping cosmetics, the 2-gadget loadout, cosmetics rendering (auto Mask Up)
-- and van paint. docs/beta-spec-meta.md §5.2–5.4. The server checks price, rank and ownership; the client only
-- sends ids.
--
-- For mechanics: ShopService:GetLoadout(player) → {"Crowbar", a, b} (read at Briefing and JUMP IN).
-- Mask Up: mechanics sets the character attribute Masked = true; this service then puts the mask on.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local MetaTags = require(ReplicatedStorage.Shared.MetaTags)
local Net = require(ReplicatedStorage.Shared.Net)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local Shop = require(ReplicatedStorage.Shared.Logic.Shop)

local Meta = script.Parent.Parent.Meta
local Access = require(Meta.Access)
local Clock = require(Meta.Clock)
local RequestGuard = require(Meta.RequestGuard)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type PlayerData = DataSchema.PlayerData

local SLOT_RANK = MetaConfig.Progression.SlotRank
local ITEMS: { [string]: Shop.Item } = Catalog.ById :: any
local COSMETIC_ATTR = "MetaCosmetic"
local HIDDEN_ATTR = "MetaHiddenTransparency"

local ShopService = {}

local buying: { [Player]: boolean } = {}
local currentVan = Catalog.DefaultEquipped.Van

-- Gadgets that exist in this build: in the catalog AND defined by mechanics in Config.Gadgets.
function ShopService:AvailableGadgets(): { [string]: boolean }
	local gadgets = (Config :: any).Gadgets
	local set: { [string]: boolean } = {}
	for _, item in Catalog.List do
		if item.Kind == "Gadget" and type(gadgets) == "table" and gadgets[item.Id] ~= nil then
			set[item.Id] = true
		end
	end
	return set
end

local function ownedOf(data: PlayerData): Shop.Owned
	return { owned = data.owned, robuxOwned = data.robuxOwned, rank = Access.rank(data) }
end

-- {"Crowbar", a, b}: the stored picks if still valid, else the default picks.
function ShopService:GetLoadout(player: Player): { string }
	local data = DataService:Get(player)
	local picks = Catalog.DefaultLoadout
	if data then
		picks = Shop.sanitizeLoadout(
			data.loadout,
			ITEMS,
			ownedOf(data),
			ShopService:AvailableGadgets(),
			Catalog.DefaultLoadout
		)
	end
	return { Catalog.AlwaysCarried, picks[1], picks[2] }
end

function ShopService:Owns(player: Player, itemId: string): boolean
	local data = DataService:Get(player)
	local item = Catalog.get(itemId)
	return data ~= nil and item ~= nil and Shop.owns(item, ownedOf(data))
end

-- Cosmetics rendering ----------------------------------------------------------------------------------------

local function color3(rgb: { number }?): Color3
	if not rgb then
		return Color3.new(1, 1, 1)
	end
	return Color3.fromRGB(rgb[1] or 255, rgb[2] or 255, rgb[3] or 255)
end

local function material(name: string?): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name or "SmoothPlastic"]
	end)
	return if ok and value then value else Enum.Material.SmoothPlastic
end

local function vec(list: { number }?, default: number): Vector3
	if not list then
		return Vector3.new(default, default, default)
	end
	return Vector3.new(list[1] or default, list[2] or default, list[3] or default)
end

-- A code-built accessory from Catalog Fallback (used until ReplicatedStorage.Cosmetics.<Id> exists).
local function buildFallback(item: Catalog.Item): Accessory?
	local fb = item.Fallback
	if not fb then
		return nil
	end
	local isHat = item.Kind == "Hat"
	local accessory = Instance.new("Accessory")
	accessory.AccessoryType = if isHat then Enum.AccessoryType.Hat else Enum.AccessoryType.Face
	local handle: BasePart
	if fb.Shape == "Wedge" then
		handle = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if fb.Shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif fb.Shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		handle = part
	end
	handle.Name = "Handle"
	handle.Size = vec(fb.Size, 1)
	handle.Color = color3(fb.Color)
	handle.Material = material(fb.Material)
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = accessory
	local attachment = Instance.new("Attachment")
	attachment.Name = if isHat then "HatAttachment" else "FaceFrontAttachment"
	attachment.Position = -vec(fb.Offset, 0)
	if fb.Shape == "Cylinder" then
		-- Cylinders run along X: stand hats up, point masks forward.
		attachment.Orientation = if isHat then Vector3.new(0, 0, 90) else Vector3.new(0, 90, 0)
	end
	attachment.Parent = handle
	return accessory
end

local function makeAccessory(itemId: string): Accessory?
	local item = Catalog.get(itemId)
	if not item then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("Cosmetics")
	local model = folder and folder:FindFirstChild(itemId)
	local accessory: Accessory?
	if model and model:IsA("Accessory") then
		accessory = model:Clone()
	else
		accessory = buildFallback(item)
	end
	if accessory then
		accessory.Name = `Cosmetic_{itemId}`
		accessory:SetAttribute(COSMETIC_ATTR, item.Kind)
	end
	return accessory
end

-- Hides (or restores) the avatar's own accessories of one type while our cosmetic takes that spot.
local function hideOwn(character: Model, accessoryType: Enum.AccessoryType, hide: boolean)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute(COSMETIC_ATTR) == nil then
			if child.AccessoryType == accessoryType then
				local handle = child:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					local stored = handle:GetAttribute(HIDDEN_ATTR)
					if hide and stored == nil then
						handle:SetAttribute(HIDDEN_ATTR, handle.Transparency)
						handle.Transparency = 1
					elseif not hide and type(stored) == "number" then
						handle.Transparency = stored
						handle:SetAttribute(HIDDEN_ATTR, nil)
					end
				end
			end
		end
	end
end

function ShopService:ApplyCosmetics(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local data = DataService:Get(player)
	local hatId = if data then data.equipped.Hat else nil
	local maskId = if data then data.equipped.Mask or Catalog.DefaultEquipped.Mask else nil
	local masked = character:GetAttribute(MetaTags.Masked) == true

	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute(COSMETIC_ATTR) ~= nil then
			child:Destroy()
		end
	end
	hideOwn(character, Enum.AccessoryType.Hat, hatId ~= nil)
	hideOwn(character, Enum.AccessoryType.Face, masked and maskId ~= nil)
	if hatId then
		local hat = makeAccessory(hatId)
		if hat then
			humanoid:AddAccessory(hat)
		end
	end
	if masked and maskId then
		local mask = makeAccessory(maskId)
		if mask then
			humanoid:AddAccessory(mask)
		end
	end
	player:SetAttribute(MetaTags.MaskId, maskId)
end

-- Van paint --------------------------------------------------------------------------------------------------

local function paintPart(part: Instance)
	local item = Catalog.get(currentVan) or Catalog.get(Catalog.DefaultEquipped.Van)
	if item and part:IsA("BasePart") then
		part.Color = color3(item.Color)
		part.Material = material(item.Material)
	end
end

-- Paints every VanPaint part in this player's van colour (LobbyService: the first boarder). nil = default.
function ShopService:PaintVan(player: Player?)
	local vanId = Catalog.DefaultEquipped.Van
	local data = if player then DataService:Get(player) else nil
	if data and data.equipped.Van and Catalog.get(data.equipped.Van) then
		vanId = data.equipped.Van
	end
	currentVan = vanId
	for _, part in CollectionService:GetTagged(MetaTags.VanPaint) do
		paintPart(part)
	end
end

-- Requests ---------------------------------------------------------------------------------------------------

local function result(player: Player, action: string, ok: boolean, id: string?, reason: string?)
	Net.send(player, "MetaResult", action, ok, id or "", reason or "")
end

local function onBuy(player: Player, itemId: any)
	local id = RequestGuard.id(itemId)
	if not id then
		return
	end
	if buying[player] then
		result(player, "Buy", false, id, "Busy")
		return
	end
	if RequestGuard.inRound(player) then
		result(player, "Buy", false, id, "InRound")
		return
	end
	local data = DataService:Get(player)
	if not data then
		result(player, "Buy", false, id, "Busy")
		return
	end
	local item = Catalog.get(id)
	if item and item.Kind == "Gadget" and not ShopService:AvailableGadgets()[id] then
		item = nil -- a sidegrade only exists once mechanics defines it
	end
	local ok, reason = Shop.canBuy(item, ownedOf(data), data.cash, SLOT_RANK)
	if ok and item then
		buying[player] = true
		local price = item.Price :: number
		ok, reason = EconomyService:Spend(player, price, id, function(d)
			d.owned[id] = Clock.now()
		end)
	end
	buying[player] = nil
	result(player, "Buy", ok, id, reason)
	if ok then
		task.spawn(function()
			DataService:SaveNowAsync(player, "Buy")
		end)
	end
end

local function onEquip(player: Player, itemId: any)
	local id = RequestGuard.id(itemId)
	if not id then
		return
	end
	if RequestGuard.inRound(player) then
		result(player, "Equip", false, id, "InRound")
		return
	end
	local data = DataService:Get(player)
	if not data then
		result(player, "Equip", false, id, "Busy")
		return
	end
	local item = Catalog.get(id)
	local ok, reason = Shop.canEquip(item, ownedOf(data), SLOT_RANK)
	if ok and item then
		local def = item
		ok = DataService:Update(player, "Equip", function(d)
			Shop.equip(d.equipped, def)
		end)
		reason = if ok then nil else "Busy"
	end
	result(player, "Equip", ok, id, reason)
	if ok then
		ShopService:ApplyCosmetics(player)
	end
end

local function onSetLoadout(player: Player, picks: any)
	if RequestGuard.inRound(player) then
		result(player, "Loadout", false, nil, "InRound")
		return
	end
	local data = DataService:Get(player)
	if not data then
		result(player, "Loadout", false, nil, "Busy")
		return
	end
	local ok, reason, clean = Shop.validateLoadout(
		picks,
		ITEMS,
		ownedOf(data),
		ShopService:AvailableGadgets(),
		#Catalog.DefaultLoadout
	)
	if ok and clean then
		local list = clean
		ok = DataService:Update(player, "SetLoadout", function(d)
			d.loadout = list
		end)
		reason = if ok then nil else "Busy"
	end
	result(player, "Loadout", ok, if clean then table.concat(clean, ",") else nil, reason)
end

local function watchCharacter(player: Player, character: Model)
	character:GetAttributeChangedSignal(MetaTags.Masked):Connect(function()
		ShopService:ApplyCosmetics(player)
	end)
	-- Avatar accessories load after the character: hide late arrivals too.
	character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") and child:GetAttribute(COSMETIC_ATTR) == nil then
			task.defer(function()
				local data = DataService:Get(player)
				hideOwn(character, Enum.AccessoryType.Hat, data ~= nil and data.equipped.Hat ~= nil)
				hideOwn(character, Enum.AccessoryType.Face, character:GetAttribute(MetaTags.Masked) == true)
			end)
		end
	end)
	task.spawn(function()
		DataService:WaitForData(player, 30)
		if player.Character == character then
			ShopService:ApplyCosmetics(player)
		end
	end)
end

function ShopService:Start()
	RequestGuard.on("BuyItem", onBuy, { burst = 3, perSecond = 1 })
	RequestGuard.on("EquipItem", onEquip)
	RequestGuard.on("SetLoadout", onSetLoadout)

	local function added(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			watchCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		buying[player] = nil
	end)

	-- Repair a stored loadout that is no longer valid (e.g. a gadget left the game).
	DataService.Loaded:Connect(function(player: Player, data: PlayerData)
		local clean = Shop.sanitizeLoadout(
			data.loadout,
			ITEMS,
			ownedOf(data),
			ShopService:AvailableGadgets(),
			Catalog.DefaultLoadout
		)
		if clean[1] ~= data.loadout[1] or clean[2] ~= data.loadout[2] or #data.loadout ~= #clean then
			DataService:Update(player, "LoadoutRepair", function(d)
				d.loadout = clean
			end)
		end
	end)

	CollectionService:GetInstanceAddedSignal(MetaTags.VanPaint):Connect(paintPart)
	ShopService:PaintVan(nil)
end

return ShopService
