--!strict
-- Daily contracts (beta-spec-meta §3.5): 3 rows with progress and reward, one free reroll a day, and the
-- time until new contracts. Data: ProfileSync.daily; request RerollContract(index).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Hud = require(Lib.Hud)
local Profile = require(Lib.Profile)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)

local Common = require(script.Parent.Common)

local Contracts = {}

local C = Theme.Colors

function Contracts.list(): { { [string]: any } }
	local daily = Profile.get("daily")
	local list = if typeof(daily) == "table" then daily.contracts else nil
	local out = {}
	if typeof(list) == "table" then
		for _, contract in list do
			if typeof(contract) == "table" then
				table.insert(out, contract)
			end
		end
	end
	return out
end

local function freeRerolls(): number
	local left = Profile.get("rerollsLeft")
	if typeof(left) == "number" then
		return left
	end
	local daily = Profile.get("daily")
	local used = if typeof(daily) == "table" and typeof(daily.rerolls) == "number" then daily.rerolls else 0
	return math.max(0, MetaConfig.Contracts.FreeRerollsPerDay - used)
end

-- Player text for a contract id (MetaConfig.Contracts.Templates[*].Text).
function Contracts.text(id: string): string
	for _, template in MetaConfig.Contracts.Templates do
		if template.Id == id then
			return template.Text
		end
	end
	return UiText.Contracts[id] or UiText.pretty(id)
end

function Contracts.create(): any
	return {
		title = "CONTRACTS",
		size = Vector2.new(600, 380),
		build = function(body: Frame): (() -> ())?
			local list = Contracts.list()
			if #list == 0 then
				Profile.request()
				Common.empty(body, "No contracts yet", "They arrive with your profile")
				return nil
			end
			local content = Common.content(body, 40)
			Hud.list(content, Enum.FillDirection.Vertical, 8)
			local rerolls = freeRerolls()
			for index, contract in list do
				local id = if typeof(contract.id) == "string" then contract.id else "?"
				local target = if typeof(contract.target) == "number" then contract.target else 1
				local progress = if typeof(contract.progress) == "number" then contract.progress else 0
				local done = contract.done == true
				local text = if typeof(contract.text) == "string" then contract.text else Contracts.text(id)
				local row = Common.card(content, { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = index })
				Hud.text({
					Position = UDim2.fromOffset(12, 6),
					Size = UDim2.new(1, -200, 0, 24),
					Text = (if done then "✓ " else "") .. text,
					TextColor3 = if done then C.Good else C.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Heavy = true,
					MaxTextSize = 18,
				}, row)
				local _, fill = Hud.bar(row, {
					Position = UDim2.fromOffset(12, 38),
					Size = UDim2.new(1, -200, 0, 10),
					Radius = 5,
				}, if done then C.Good else C.Accent)
				fill.Size = UDim2.fromScale(math.clamp(progress / math.max(target, 1), 0, 1), 1)
				Hud.text({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -120, 0, 8),
					Size = UDim2.fromOffset(70, 22),
					Text = `{math.min(progress, target)}/{target}`,
					TextColor3 = C.Muted,
					MaxTextSize = 16,
				}, row)
				Hud.text({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -120, 0, 32),
					Size = UDim2.fromOffset(70, 22),
					Text = `+{Hud.formatNumber(
						if typeof(contract.reward) == "number" then contract.reward else 0
					)}`,
					TextColor3 = C.Gold,
					Display = true,
					MaxTextSize = 18,
				}, row)
				if not done then
					local reroll = Hud.button({
						Name = "Reroll" .. index,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(100, 48),
						Text = "REROLL",
						Kind = if rerolls > 0 then "ghost" else "disabled",
						MaxTextSize = 15,
					}, row)
					reroll.Activated:Connect(function()
						if rerolls > 0 then
							Net.request("RerollContract", index)
						else
							Hud.toast("One free reroll a day", C.Muted)
						end
					end)
				end
			end
			local footer = Common.footer(body, 40)
			local resetsAt = Profile.get("dayResetsAt")
			local left = if typeof(resetsAt) == "number" then resetsAt - os.time() else nil
			Hud.text({
				Size = UDim2.new(1, 0, 0, 30),
				Text = if left and left > 0
					then `New contracts in {math.floor(left / 3600)}h {math.floor(left % 3600 / 60)}m`
					else "New contracts every day",
				TextColor3 = C.Muted,
				MaxTextSize = 16,
			}, footer)
			return nil
		end,
	}
end

return Contracts
