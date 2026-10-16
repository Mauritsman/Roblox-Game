--!strict
-- Perk tree at the Workbench (beta-spec-meta §4.4): 3 branches × 3 rows (cost 1 / 2 / 3 skill points),
-- a row needs the row above it in the same branch, max 3 equipped, free respec.
-- Data: ProfileSync (perks.unlocked, perks.equipped, skillPoints); requests UnlockPerk, EquipPerks,
-- RespecPerks. Hidden behind mechanics' Config.Features.Perks (shown as "coming soon" while off).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Hud = require(Lib.Hud)
local Profile = require(Lib.Profile)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)

local Common = require(script.Parent.Common)

local PerkTree = {}

local C = Theme.Colors

local selectedPerk: string? = nil

type Branch = { id: string, name: string, perks: { string } }

local function branches(): { Branch }
	local tree = (Config :: any).PerkTree
	if typeof(tree) == "table" and typeof(tree.Branches) == "table" then
		local out: { Branch } = {}
		for _, default in UiText.PerkBranches do
			local perks = tree.Branches[default.id]
			if typeof(perks) == "table" then
				table.insert(out, { id = default.id, name = default.name, perks = perks })
			end
		end
		if #out > 0 then
			return out
		end
	end
	return UiText.PerkBranches
end

local function rowCost(row: number): number
	local tree = (Config :: any).PerkTree
	local costs = if typeof(tree) == "table" then tree.RowCost else nil
	local value = if typeof(costs) == "table" then costs[row] else nil
	return if typeof(value) == "number" then value else row
end

local function maxEquipped(): number
	local tree = (Config :: any).PerkTree
	local value = if typeof(tree) == "table" then tree.MaxEquipped else nil
	return if typeof(value) == "number" then value else 3
end

local function enabled(): boolean
	local features = (Config :: any).Features
	if typeof(features) == "table" and features.Perks == false then
		return false
	end
	return true
end

local function perkState(): ({ [string]: boolean }, { string }, number)
	local perks = Profile.get("perks")
	local unlocked: { [string]: boolean } = {}
	local equipped: { string } = {}
	if typeof(perks) == "table" then
		if typeof(perks.unlocked) == "table" then
			for id, value in perks.unlocked do
				if value then
					unlocked[tostring(id)] = true
				end
			end
		end
		if typeof(perks.equipped) == "table" then
			for _, id in perks.equipped do
				if typeof(id) == "string" then
					table.insert(equipped, id)
				end
			end
		end
	end
	local spent = 0
	for _, branch in branches() do
		for row, id in branch.perks do
			if unlocked[id] then
				spent += rowCost(row)
			end
		end
	end
	local view = Profile.view
	local free: number
	if view and typeof(view.freeSkillPoints) == "number" then
		free = view.freeSkillPoints
	elseif view and typeof(view.skillPoints) == "number" then
		free = math.max(0, view.skillPoints - spent)
	else
		free = math.max(0, Profile.number("rank", "Rank") - 1 - spent)
	end
	return unlocked, equipped, free
end

local function locate(id: string): (Branch?, number)
	for _, branch in branches() do
		local row = table.find(branch.perks, id)
		if row then
			return branch, row
		end
	end
	return nil, 0
end

function PerkTree.create(): any
	return {
		title = "WORKBENCH · PERKS",
		size = Vector2.new(760, 440),
		build = function(body: Frame): (() -> ())?
			local on = enabled()
			local unlocked, equipped, free = perkState()

			-- Top: skill points, equipped slots, respec.
			local top = Hud.frame({ Size = UDim2.new(1, 0, 0, 48) }, body)
			Hud.list(
				top,
				Enum.FillDirection.Horizontal,
				6,
				Enum.HorizontalAlignment.Left,
				Enum.VerticalAlignment.Center
			)
			Hud.chip(
				top,
				`SKILL POINTS {free}`,
				C.Gold,
				{ LayoutOrder = 1, TextSize = 16, Size = UDim2.fromOffset(0, 32) }
			)
			for slot = 1, maxEquipped() do
				local id = equipped[slot]
				Hud.chip(top, if id then UiText.perk(id).name else "EMPTY", if id then C.Good else C.Muted, {
					LayoutOrder = 1 + slot,
					TextSize = 14,
					Size = UDim2.fromOffset(0, 32),
				})
			end
			local respec = Hud.button({
				Name = "Respec",
				Size = UDim2.fromOffset(100, 48),
				Text = "RESPEC",
				Kind = if on then "ghost" else "disabled",
				MaxTextSize = 16,
				LayoutOrder = 10,
			}, top)
			respec.Activated:Connect(function()
				if on then
					Net.request("RespecPerks")
				end
			end)

			-- Grid: one column per branch, rows 1–3.
			local grid =
				Hud.frame({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54 - 64) }, body)
			Hud.list(grid, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
			for index, branch in branches() do
				local column = Hud.frame({ Size = UDim2.new(0.333, -6, 1, 0), LayoutOrder = index }, grid)
				Hud.list(column, Enum.FillDirection.Vertical, 5)
				Hud.text({
					Size = UDim2.new(1, 0, 0, 20),
					Text = branch.name,
					TextColor3 = C.Gold,
					Display = true,
					MaxTextSize = 18,
					LayoutOrder = 0,
				}, column)
				for row, id in branch.perks do
					local have = unlocked[id] == true
					local isOn = table.find(equipped, id) ~= nil
					local reachable = row == 1 or unlocked[branch.perks[row - 1]] == true
					local tile = Hud.make("TextButton", {
						Name = "Perk_" .. id,
						Size = UDim2.new(1, 0, 0, 50),
						BackgroundColor3 = if isOn then C.Good elseif have then C.PanelLight else C.Panel,
						BackgroundTransparency = if have or reachable then 0.05 else 0.5,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						Text = "",
						LayoutOrder = row,
						Selectable = true,
					}, column)
					Hud.corner(tile, 10)
					if id == selectedPerk then
						Common.outline(tile, C.Accent, 2)
					end
					local dark = isOn
					Hud.text({
						Position = UDim2.fromOffset(8, 4),
						Size = UDim2.new(1, -16, 0, 22),
						Text = UiText.perk(id).name,
						TextColor3 = if dark then C.Panel else C.Text,
						Heavy = true,
						MaxTextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, tile)
					Hud.text({
						Position = UDim2.fromOffset(8, 27),
						Size = UDim2.new(1, -16, 0, 18),
						Text = if isOn
							then "EQUIPPED"
							elseif have then "OWNED"
							elseif reachable then `{rowCost(row)} POINT{if rowCost(row) == 1
								then ""
								else "S"}`
							else "LOCKED",
						TextColor3 = if dark then C.Panel elseif have then C.Muted else C.Gold,
						MaxTextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left,
					}, tile)
					tile.Activated:Connect(function()
						selectedPerk = id
						Screens.refresh()
					end)
				end
			end

			-- Detail row for the selected perk.
			local footer = Common.footer(body, 60)
			if not on then
				Hud.text({
					Size = UDim2.new(1, 0, 0, 40),
					Text = "Perks unlock soon. Keep ranking up!",
					TextColor3 = C.Muted,
					MaxTextSize = 17,
				}, footer)
				return nil
			end
			local id = selectedPerk
			local branch: Branch? = nil
			local row = 0
			if id then
				branch, row = locate(id)
			end
			if not id or not branch then
				Hud.text({
					Size = UDim2.new(1, 0, 0, 40),
					Text = "Tap a perk · 1 skill point per rank",
					TextColor3 = C.Muted,
					MaxTextSize = 17,
				}, footer)
				return nil
			end
			local perkId: string = id
			local info = UiText.perk(perkId)
			Hud.text({
				Size = UDim2.new(1, -330, 0, 44),
				Text = `{info.name}: {info.line}`,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 17,
				LayoutOrder = 1,
			}, footer)
			local have = unlocked[perkId] == true
			local isOn = table.find(equipped, perkId) ~= nil
			if not have then
				local reachable = row == 1 or unlocked[branch.perks[row - 1]] == true
				local cost = rowCost(row)
				local can = reachable and free >= cost
				local unlock = Hud.button({
					Name = "Unlock",
					Size = UDim2.fromOffset(150, 52),
					Text = if not reachable
						then "ROW ABOVE FIRST"
						elseif can then `UNLOCK · {cost}`
						else "NEED POINTS",
					Kind = if can then "gold" else "disabled",
					MaxTextSize = 16,
					LayoutOrder = 2,
				}, footer)
				unlock.Activated:Connect(function()
					if can then
						Net.request("UnlockPerk", perkId)
					end
				end)
			else
				local full = #equipped >= maxEquipped() and not isOn
				local equip = Hud.button({
					Name = "Equip",
					Size = UDim2.fromOffset(150, 52),
					Text = if isOn then "UNEQUIP" elseif full then "3 EQUIPPED" else "EQUIP",
					Kind = if isOn then "secondary" elseif full then "disabled" else "primary",
					MaxTextSize = 16,
					LayoutOrder = 2,
				}, footer)
				equip.Activated:Connect(function()
					local list = table.clone(equipped)
					local at = table.find(list, perkId)
					if at then
						table.remove(list, at)
					elseif #list < maxEquipped() then
						table.insert(list, perkId)
					else
						Hud.toast("Max 3 equipped", C.Warn)
						return
					end
					Net.request("EquipPerks", list)
				end)
			end
			return nil
		end,
		onClose = function()
			selectedPerk = nil
		end,
	}
end

return PerkTree
