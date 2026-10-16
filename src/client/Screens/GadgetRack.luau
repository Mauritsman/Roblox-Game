--!strict
-- Gadget rack (beta-spec-ux §1.4, beta-spec-meta §5.2): pick 2 of the gadgets; the Crowbar is always
-- carried. Cards show icon, name, a ≤ 4-word line, charges and the crew shapes of teammates who picked it.
-- Selected cards show "1" / "2"; a third tap replaces the oldest. DONE sends SetLoadout({a, b}).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Device = require(Lib.Device)
local Hud = require(Lib.Hud)
local Juice = require(Lib.Juice)
local Profile = require(Lib.Profile)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)

local Common = require(script.Parent.Common)

local GadgetRack = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local BASE = { "Drone", "Noisemaker", "EMP", "BubbleBlaster" }

export type Context = { onLoadout: (() -> ())? }

local picked: { string } = {}

-- Gadgets from meta's Catalog (Kind "Gadget"); one only appears once mechanics defines Config.Gadgets[id].
local function pickable(): { string }
	local out = {}
	local gadgets = (Config :: any).Gadgets
	for _, item in Catalog.List do
		if item.Kind == "Gadget" and item.Id ~= Catalog.AlwaysCarried then
			if typeof(gadgets) ~= "table" or gadgets[item.Id] ~= nil then
				table.insert(out, item.Id)
			end
		end
	end
	if #out == 0 then
		return table.clone(BASE)
	end
	return out
end

local function rank(): number
	return math.max(1, Profile.number("rank", "Rank"))
end

local function owned(id: string): boolean
	local item = Catalog.get(id)
	if not item then
		return table.find(BASE, id) ~= nil
	end
	if item.Free and rank() >= item.MinRank then
		return true
	end
	local ownedMap = Profile.get("owned")
	return typeof(ownedMap) == "table" and ownedMap[id] ~= nil
end

local function charges(id: string): number?
	local gadgets = (Config :: any).Gadgets
	local entry = if typeof(gadgets) == "table" then gadgets[id] else nil
	local value = if typeof(entry) == "table" then entry.Charges else nil
	return if typeof(value) == "number" and value < 100 then value else nil
end

-- "BUY 2,000" / "RANK 5" / "NEED 300 MORE" for a gadget you don't own.
local function buyText(id: string): string
	local item = Catalog.get(id)
	if not item or not item.Price then
		return "Locked"
	end
	if rank() < item.MinRank then
		return `RANK {item.MinRank}`
	end
	local missing = item.Price - Profile.number("cash", "Cash")
	if missing > 0 then
		return `NEED {Hud.formatNumber(missing)} MORE`
	end
	return `TAP TO BUY · {Hud.formatNumber(item.Price)}`
end

local function teammatesWith(id: string): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			local list = Profile.list(p:GetAttribute("Loadout"))
			if table.find(list, id) then
				table.insert(out, p)
			end
		end
	end
	return out
end

local function toggle(id: string)
	local at = table.find(picked, id)
	if at then
		table.remove(picked, at)
	else
		if #picked >= 2 then
			table.remove(picked, 1)
		end
		table.insert(picked, id)
	end
end

function GadgetRack.create(ctx: Context): any
	return {
		title = "GADGET RACK",
		size = Vector2.new(760, 430),
		build = function(body: Frame): (() -> ())?
			if #picked == 0 then
				picked = table.clone(Profile.loadout())
			end
			local inRound = player:GetAttribute("InRound") == true
			local content = Common.content(body, 60)
			local list = pickable()
			local narrow = Device.viewport().X < 700 or #list > 4
			local grid = Hud.make("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -30),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 5,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Selectable = false,
			}, content)
			Hud.make("UIGridLayout", {
				CellSize = if narrow then UDim2.new(0.5, -6, 0, 104) else UDim2.new(0.25, -6, 0, 200),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, grid)
			Hud.padding(grid, 4, 4)
			for index, id in list do
				local entry = UiText.gadget(id)
				local slot = table.find(picked, id)
				local have = owned(id)
				local card = Hud.make("TextButton", {
					Name = "Gadget_" .. id,
					BackgroundColor3 = if slot then C.Accent else C.PanelLight,
					BackgroundTransparency = if have then 0.05 else 0.5,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
					LayoutOrder = index,
					Selectable = true,
				}, grid)
				Hud.corner(card, 12)
				local textColor = if slot then C.Panel else C.Text
				Hud.text({
					Position = UDim2.fromOffset(8, 6),
					Size = if narrow then UDim2.fromOffset(44, 44) else UDim2.new(1, -16, 0, 64),
					Text = entry.glyph or "●",
					TextColor3 = textColor,
					Display = true,
					MaxTextSize = if narrow then 36 else 56,
				}, card)
				Hud.text({
					Position = if narrow then UDim2.fromOffset(58, 8) else UDim2.fromOffset(8, 76),
					Size = if narrow then UDim2.new(1, -66, 0, 24) else UDim2.new(1, -16, 0, 26),
					Text = entry.name,
					TextColor3 = textColor,
					Display = true,
					MaxTextSize = 20,
					TextXAlignment = if narrow then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				}, card)
				Hud.text({
					Position = if narrow then UDim2.fromOffset(58, 34) else UDim2.fromOffset(8, 104),
					Size = if narrow then UDim2.new(1, -66, 0, 20) else UDim2.new(1, -16, 0, 36),
					Text = if have then ((Catalog.get(id) or {} :: any).Blurb or entry.line) else buyText(id),
					TextColor3 = if slot then C.Panel else C.Muted,
					MaxTextSize = 15,
					TextXAlignment = if narrow then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				}, card)
				local n = charges(id)
				local mates = teammatesWith(id)
				local shapes = {}
				for _, mate in mates do
					table.insert(shapes, Theme.crew(mate).glyph)
				end
				Hud.text({
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 8, 1, -6),
					Size = UDim2.new(1, -16, 0, 20),
					Text = (if n then `×{n}` else "")
						.. (if #shapes > 0 then "   " .. table.concat(shapes, " ") else ""),
					TextColor3 = textColor,
					Heavy = true,
					MaxTextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, card)
				if slot then
					local badge = Hud.text({
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -6, 0, 6),
						Size = UDim2.fromOffset(28, 28),
						Text = tostring(slot),
						TextColor3 = C.Accent,
						BackgroundColor3 = C.Panel,
						BackgroundTransparency = 0,
						Display = true,
						MaxTextSize = 20,
					}, card)
					Hud.corner(badge, 999)
				end
				card.Activated:Connect(function()
					if not have then
						local item = Catalog.get(id)
						if
							item
							and item.Price
							and rank() >= item.MinRank
							and Profile.number("cash", "Cash") >= item.Price
						then
							Net.request("BuyItem", id)
						else
							Hud.toast(buyText(id), C.Muted)
						end
						return
					end
					toggle(id)
					Screens.refresh()
					Juice.pop(card, 1.05)
				end)
			end
			Hud.text({
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 26),
				Text = `{UiText.gadget("Crowbar").glyph} CROWBAR · always with you`,
				TextColor3 = C.Muted,
				MaxTextSize = 17,
			}, content)

			local footer = Common.footer(body, 60)
			Hud.text({
				Size = UDim2.new(1, -170, 0, 40),
				Text = if inRound then "Locked during a job" else `Picked {#picked}/2`,
				TextColor3 = if inRound then C.Warn else C.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 17,
				LayoutOrder = 1,
			}, footer)
			local done = Hud.button({
				Name = "Done",
				Size = UDim2.fromOffset(150, 64),
				Text = "DONE",
				Kind = if #picked == 2 and not inRound then "primary" else "disabled",
				MaxTextSize = 24,
				LayoutOrder = 2,
			}, footer)
			done.Activated:Connect(function()
				if inRound then
					Hud.toast("Not during a job", C.Warn)
					return
				end
				if #picked ~= 2 then
					Hud.toast("Pick two gadgets", C.Warn)
					return
				end
				Net.request("SetLoadout", { picked[1], picked[2] })
				if ctx.onLoadout then
					ctx.onLoadout()
				end
				Screens.close()
			end)
			return function()
				-- Keep the picks while the screen rebuilds; reset when it closes.
				if Screens.current() ~= "GadgetRack" then
					picked = {}
				end
			end
		end,
		onClose = function()
			picked = {}
		end,
	}
end

return GadgetRack
