--!strict
-- Mirror (beta-spec-ux §1.5, beta-spec-meta §5.3–5.4): masks are the main cosmetic. Tabs MASKS / HATS / VAN,
-- a grid of items (price / OWNED / EQUIPPED / RANK n / reward source) and a preview with one action:
-- "BUY 1,500" / "EQUIP" / "EQUIPPED" / greyed "NEED 300 MORE". Cash only in the beta.
-- Data: Catalog (meta) + ProfileSync / attributes (owned, MaskId/HatId/VanId); requests BuyItem, EquipItem.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Hud = require(Lib.Hud)
local Profile = require(Lib.Profile)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)

local Common = require(script.Parent.Common)

local Mirror = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local TABS =
	{ { id = "Mask", label = "MASKS" }, { id = "Hat", label = "HATS" }, { id = "Van", label = "VAN" } }

local tab = "Mask"
local selectedId: string? = nil

type Item = {
	id: string,
	kind: string,
	name: string,
	price: number?,
	minRank: number,
	source: string,
	free: boolean,
	color: Color3?,
}

local SOURCE_TEXT: { [string]: string } = {
	Starter = "Starter",
	Rank = "Rank reward",
	MostWanted = "Most Wanted",
	Collection = "Collection",
	Mastery = "3★ on Hard",
	Stars = "Star reward",
}

local function toColor(rgb: any): Color3?
	if typeof(rgb) == "table" and typeof(rgb[1]) == "number" then
		return Color3.fromRGB(rgb[1], rgb[2] or 0, rgb[3] or 0)
	end
	return nil
end

-- Cosmetics from meta's Catalog (Mask / Hat / Van).
local function catalog(): { Item }
	local out: { Item } = {}
	for _, entry in Catalog.List do
		if entry.Kind == "Mask" or entry.Kind == "Hat" or entry.Kind == "Van" then
			table.insert(out, {
				id = entry.Id,
				kind = entry.Kind :: string,
				name = entry.Name,
				price = entry.Price,
				minRank = entry.MinRank,
				source = entry.Source,
				free = entry.Free == true,
				color = toColor(entry.Color) or toColor(entry.Fallback and entry.Fallback.Color),
			})
		end
	end
	table.sort(out, function(a, b)
		local pa = a.price or (if a.free then 0 else 1e9)
		local pb = b.price or (if b.free then 0 else 1e9)
		if pa ~= pb then
			return pa < pb
		end
		return a.name < b.name
	end)
	return out
end

local function rank(): number
	return math.max(1, Profile.number("rank", "Rank"))
end

local function isOwned(item: Item): boolean
	if item.free and rank() >= item.minRank then
		return true
	end
	local owned = Profile.get("owned")
	return typeof(owned) == "table" and owned[item.id] ~= nil
end

local EQUIP_ATTRIBUTE: { [string]: string } = { Mask = "MaskId", Hat = "HatId", Van = "VanId" }

local function isEquipped(item: Item): boolean
	local attribute = EQUIP_ATTRIBUTE[item.kind]
	local fromAttribute = attribute and player:GetAttribute(attribute)
	if typeof(fromAttribute) == "string" then
		return fromAttribute == item.id
	end
	local equipped = Profile.get("equipped")
	return typeof(equipped) == "table" and equipped[item.kind] == item.id
end

local function cash(): number
	return Profile.number("cash", "Cash")
end

-- What the action button says and whether it works.
local function action(item: Item): (string, string, boolean)
	if isEquipped(item) then
		return "EQUIPPED", "disabled", false
	end
	if isOwned(item) then
		return "EQUIP", "primary", true
	end
	if not item.price then
		if item.free then
			return `RANK {item.minRank}`, "disabled", false
		end
		return string.upper(SOURCE_TEXT[item.source] or item.source), "disabled", false
	end
	if rank() < item.minRank then
		return `RANK {item.minRank}`, "disabled", false
	end
	local missing = item.price - cash()
	if missing > 0 then
		return `NEED {Hud.formatNumber(missing)} MORE`, "disabled", false
	end
	return `BUY {Hud.formatNumber(item.price)}`, "gold", true
end

local function preview(parent: Instance, item: Item?): () -> ()
	local box = Hud.panel({
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.2,
	}, parent)
	if not item then
		Hud.text({
			Size = UDim2.fromScale(1, 1),
			Text = "Tap an item to try it",
			TextColor3 = C.Muted,
			MaxTextSize = 18,
		}, box)
		return function() end
	end
	local folder = ReplicatedStorage:FindFirstChild("Cosmetics")
	local model = folder and folder:FindFirstChild(item.id)
	local spin: RBXScriptConnection? = nil
	if model then
		local viewport = Hud.make("ViewportFrame", {
			Size = UDim2.new(1, 0, 1, -30),
			BackgroundTransparency = 1,
			LightColor = Color3.new(1, 1, 1),
			Ambient = Color3.fromRGB(180, 180, 190),
		}, box)
		local clone = model:Clone()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		cam.Parent = viewport
		viewport.CurrentCamera = cam
		local pivot: CFrame, size: Vector3
		if clone:IsA("Model") then
			pivot, size = clone:GetBoundingBox()
		elseif clone:IsA("Accessory") then
			local handle = clone:FindFirstChild("Handle")
			pivot = if handle and handle:IsA("BasePart") then handle.CFrame else CFrame.identity
			size = if handle and handle:IsA("BasePart") then handle.Size else Vector3.one * 2
		elseif clone:IsA("BasePart") then
			pivot, size = clone.CFrame, clone.Size
		else
			pivot, size = CFrame.identity, Vector3.one * 2
		end
		clone.Parent = viewport
		local distance = math.max(size.Magnitude, 1) * 1.6
		local angle = 0
		spin = RunService.RenderStepped:Connect(function(dt: number)
			angle += dt * 0.8
			cam.CFrame = CFrame.lookAt(
				pivot.Position
					+ Vector3.new(math.sin(angle) * distance, size.Y * 0.2, math.cos(angle) * distance),
				pivot.Position
			)
		end)
	else
		local swatch = Hud.panel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(96, 96),
			BackgroundColor3 = item.color or C.PanelLight,
			BackgroundTransparency = 0,
			Radius = 24,
		}, box)
		Hud.text({
			Size = UDim2.fromScale(1, 1),
			Text = if item.kind == "Mask" then "◐" elseif item.kind == "Hat" then "♚" else "▣",
			TextColor3 = C.Text,
			Display = true,
			MaxTextSize = 56,
			Stroke = 2,
		}, swatch)
	end
	Hud.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -4),
		Size = UDim2.new(1, -16, 0, 26),
		Text = item.name,
		Display = true,
		MaxTextSize = 22,
	}, box)
	return function()
		if spin then
			spin:Disconnect()
		end
	end
end

function Mirror.create(): any
	return {
		title = "MIRROR",
		size = Vector2.new(820, 440),
		build = function(body: Frame): (() -> ())?
			local items = catalog()
			if #items == 0 then
				Common.empty(body, "The mirror is being polished", "Masks arrive soon. Keep stealing!")
				return nil
			end
			local left = Hud.frame({ Size = UDim2.new(0.38, -6, 1, 0) }, body)
			local right = Hud.frame({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.62, -6, 1, 0),
			}, body)

			local current: Item? = nil
			for _, item in items do
				if item.id == selectedId then
					current = item
				end
			end
			local stopPreview = preview(left, current)
			local label, kind, enabled = "PICK ONE", "disabled", false
			if current then
				label, kind, enabled = action(current)
			end
			local actionButton = Hud.button({
				Name = "Action",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 56),
				Text = label,
				Kind = kind,
				MaxTextSize = 22,
			}, left)
			actionButton.Activated:Connect(function()
				if not current or not enabled then
					return
				end
				if isOwned(current) then
					Net.request("EquipItem", current.id)
				else
					Net.request("BuyItem", current.id)
				end
			end)

			-- Tabs
			local tabs = Hud.frame({ Size = UDim2.new(1, 0, 0, 48) }, right)
			Hud.list(
				tabs,
				Enum.FillDirection.Horizontal,
				6,
				Enum.HorizontalAlignment.Left,
				Enum.VerticalAlignment.Center
			)
			for index, t in TABS do
				local button = Hud.button({
					Name = "Tab_" .. t.id,
					Size = UDim2.fromOffset(96, 48),
					Text = t.label,
					Kind = if tab == t.id then "primary" else "ghost",
					MaxTextSize = 17,
					LayoutOrder = index,
				}, tabs)
				button.Activated:Connect(function()
					tab = t.id
					Screens.refresh()
				end)
			end
			Hud.text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 10),
				Size = UDim2.fromOffset(150, 28),
				Text = `● {Hud.formatNumber(cash())}`,
				TextColor3 = C.Gold,
				TextXAlignment = Enum.TextXAlignment.Right,
				Display = true,
				MaxTextSize = 22,
			}, right)

			local grid = Hud.make("ScrollingFrame", {
				Position = UDim2.fromOffset(0, 54),
				Size = UDim2.new(1, 0, 1, -54),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 5,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Selectable = false,
			}, right)
			Hud.make("UIGridLayout", {
				CellSize = UDim2.new(0.333, -6, 0, 76),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, grid)
			Hud.padding(grid, 2, 2)
			local order = 0
			for _, item in items do
				if item.kind == tab then
					order += 1
					local owned = isOwned(item)
					local equipped = isEquipped(item)
					local tile = Hud.make("TextButton", {
						Name = "Item_" .. item.id,
						BackgroundColor3 = if item.id == selectedId then C.Accent else C.PanelLight,
						BackgroundTransparency = 0.05,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						Text = "",
						LayoutOrder = order,
						Selectable = true,
					}, grid)
					Hud.corner(tile, 10)
					if equipped then
						Common.outline(tile, C.Good, 2)
					end
					local dark = item.id == selectedId
					Hud.text({
						Position = UDim2.fromOffset(6, 6),
						Size = UDim2.new(1, -12, 0, 36),
						Text = item.name,
						TextColor3 = if dark then C.Panel else C.Text,
						Heavy = true,
						MaxTextSize = 16,
					}, tile)
					local status = if equipped
						then "EQUIPPED"
						elseif owned then "OWNED"
						elseif item.price and rank() < item.minRank then `RANK {item.minRank}`
						elseif item.price then `● {Hud.formatNumber(item.price)}`
						elseif item.free then `RANK {item.minRank}`
						else string.upper(SOURCE_TEXT[item.source] or item.source)
					Hud.text({
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 6, 1, -6),
						Size = UDim2.new(1, -12, 0, 20),
						Text = status,
						TextColor3 = if dark
							then C.Panel
							elseif equipped then C.Good
							elseif owned then C.Muted
							else C.Gold,
						MaxTextSize = 15,
					}, tile)
					tile.Activated:Connect(function()
						selectedId = item.id
						Screens.refresh()
					end)
				end
			end
			if order == 0 then
				Common.empty(grid, "Nothing here yet")
			end
			return stopPreview
		end,
		onClose = function()
			selectedId = nil
		end,
	}
end

return Mirror
