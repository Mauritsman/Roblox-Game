--!strict
-- Trophy wall (beta-spec-meta §4.6, §5.5): your Goudas and other main loot, newest first, plus your stars
-- per heist and difficulty. Data: ProfileSync (trophies, stats, heists, totalStars).

local Lib = script.Parent.Parent.Lib
local Hud = require(Lib.Hud)
local Profile = require(Lib.Profile)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)

local Common = require(script.Parent.Common)

local TrophyWall = {}

local C = Theme.Colors

function TrophyWall.create(): any
	return {
		title = "TROPHY WALL",
		size = Vector2.new(760, 430),
		build = function(body: Frame): (() -> ())?
			local view = Profile.view
			if not view then
				Profile.request()
				Common.empty(body, "Loading your trophies…")
				return nil
			end
			local trophies = if typeof(view.trophies) == "table" then view.trophies else {}
			local stats = if typeof(view.stats) == "table" then view.stats else {}
			local mainLoot = if typeof(stats.mainLoot) == "number" then stats.mainLoot else #trophies
			local totalStars = if typeof(view.totalStars) == "number" then view.totalStars else 0

			local left = Hud.panel({ Size = UDim2.new(0.45, -6, 1, 0), BackgroundTransparency = 0.3 }, body)
			Hud.padding(left, 10, 8)
			Hud.list(left, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left)
			Hud.text({
				Size = UDim2.new(1, 0, 0, 34),
				Text = `{Theme.Loot.Main.glyph} {mainLoot} GOUDAS STOLEN`,
				TextColor3 = C.Gold,
				Display = true,
				MaxTextSize = 26,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}, left)
			Hud.text({
				Size = UDim2.new(1, 0, 0, 26),
				Text = `★ {totalStars} / 27 STARS`,
				TextColor3 = C.Text,
				Display = true,
				MaxTextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}, left)
			for index, heistId in UiText.HeistOrder do
				local row = Hud.frame({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2 + index }, left)
				Hud.text({
					Size = UDim2.new(1, 0, 0, 18),
					Text = UiText.heist(heistId).name,
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 16,
				}, row)
				local parts = {}
				for _, tier in UiText.TierOrder do
					local info = (UiText.Tiers :: any)[tier]
					table.insert(
						parts,
						`{string.sub(info.name, 1, 1)} {Common.stars(Profile.stars(heistId, tier))}`
					)
				end
				Hud.text({
					Position = UDim2.fromOffset(0, 19),
					Size = UDim2.new(1, 0, 0, 18),
					Text = table.concat(parts, "   "),
					TextColor3 = C.Gold,
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 16,
				}, row)
			end

			local right = Hud.frame({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.55, -6, 1, 0),
			}, body)
			if #trophies == 0 then
				Common.empty(right, "No trophies yet", "Bank the Golden Gouda and escape")
				return nil
			end
			local list = Common.scroller(right, false)
			for index = #trophies, 1, -1 do
				local trophy = trophies[index]
				if typeof(trophy) == "table" then
					local card = Common.card(list, {
						Size = UDim2.new(1, -8, 0, 52),
						LayoutOrder = #trophies - index,
					})
					Hud.text({
						Position = UDim2.fromOffset(10, 4),
						Size = UDim2.new(1, -20, 0, 24),
						Text = `{Theme.Loot.Main.glyph} {UiText.pretty(trophy.loot)}`,
						TextColor3 = C.Gold,
						TextXAlignment = Enum.TextXAlignment.Left,
						Display = true,
						MaxTextSize = 20,
					}, card)
					local when = if typeof(trophy.at) == "number" then os.date("%d %b", trophy.at) else ""
					local tier = if typeof(trophy.tier) == "string" then " · " .. trophy.tier else ""
					local crew = if typeof(trophy.crew) == "number" and trophy.crew > 1
						then ` · crew of {trophy.crew}`
						else ""
					Hud.text({
						Position = UDim2.fromOffset(10, 28),
						Size = UDim2.new(1, -20, 0, 18),
						Text = `{UiText.heist(trophy.heist).name}{tier}{crew}   {when}`,
						TextColor3 = C.Muted,
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 15,
					}, card)
				end
			end
			return nil
		end,
	}
end

return TrophyWall
