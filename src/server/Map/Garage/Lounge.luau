--!strict
-- Lounge arch (z 14..34): the trophy wall with 12 slots (meta/ux: TrophyWall + TrophySlot), the "Most Goudas"
-- board (meta writes the text: TrophyBoard), the collection book on a lectern (CollectionBook), the TV where you
-- WATCH the crew (ux: GarageTV) and the sofa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MetaTags = require(ReplicatedStorage.Shared.MetaTags)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Parent.Common.Builder)
local Kit = require(script.Parent.Kit)
local Style = require(script.Parent.Style)

local C = Builder.Colors
local S = Style.Colors
local V = Vector3.new

local BACK = Style.BACK
local SIGN_X = BACK - 0.2

local Lounge = {}

-- Shelf heights and slot columns: Index 1–4 on the top shelf (left to right as you face the wall), 5–8 middle,
-- 9–12 bottom.
local SHELVES = { 7.6, 4.9, 2.2 }
local COLUMNS = { 18.75, 22.25, 25.75, 29.25 }

local function trophyWall(k: Kit.Kit, parent: Instance)
	local wall = Kit.model(parent, "TrophyWall", MetaTags.TrophyWall)
	local backboard = k.box(wall, "Backboard", V(BACK - 0.4, 1.8, 17), V(BACK, 10.2, 31), S.WoodDark, {
		material = Enum.Material.WoodPlanks,
	})
	local index = 0
	for _, y in SHELVES do
		k.box(wall, "Shelf", V(BACK - 1.6, y - 0.25, 17.2), V(BACK - 0.4, y, 30.8), S.Wood, Style.wood())
		for _, z in COLUMNS do
			index += 1
			-- Gold rim where a trophy goes.
			k.box(wall, "SlotMark", V(BACK - 1.4, y, z - 0.8), V(BACK - 0.6, y + 0.06, z + 0.8), C.Gold, {
				material = Enum.Material.Foil,
				collide = false,
				shadow = false,
			})
			-- The slot itself: an invisible box above the shelf; ux draws the player's trophy here.
			local slot =
				k.block(wall, `TrophySlot{index}`, V(1, 2.4, 2), CFrame.new(BACK - 1, y + 1.2, z), C.Gold, {
					transparency = 1,
					collide = false,
					query = false,
					shadow = false,
				})
			slot.CanTouch = false
			Kit.mark(slot, MetaTags.TrophySlot, { Index = index })
		end
	end
	Kit.station(wall, backboard, k.at(16.5, 13.6, 24))
	k.sign(parent, "CREW WALL", V(SIGN_X, 11.4, 24), V(-1, 0, 0), 9, 1.6, V(8, 5, 24))
end

-- "Most Goudas in this Garage": meta writes the leaders into Text.Label (SurfaceGui on the board's front).
local function trophyBoard(k: Kit.Kit, parent: Instance)
	local center = k.at(13, 5, 14.15)
	local board = Builder.block(
		parent,
		"TrophyBoard",
		V(6, 4, 0.3),
		CFrame.lookAt(center, center + k.dir(V(0, 0, 1))),
		Color3.fromRGB(24, 26, 30),
		{ material = Enum.Material.SmoothPlastic }
	)
	Kit.mark(board, Tags.TrophyBoard)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "NO GOUDAS YET"
	label.TextColor3 = C.Gold
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = board
	k.sign(parent, "MOST GOUDAS", V(13, 8.2, 14.2), V(0, 0, 1), 8, 1.3, V(4, 5, 22))
end

local function collectionBook(k: Kit.Kit, parent: Instance)
	local lectern = Kit.model(parent, "CollectionBook", MetaTags.CollectionBook)
	k.box(lectern, "LecternBase", V(-12.8, 0, 17.2), V(-11.2, 0.25, 18.8), S.WoodDark, Style.wood())
	k.box(lectern, "LecternPost", V(-12.3, 0.25, 17.7), V(-11.7, 3.1, 18.3), S.WoodDark, Style.wood())
	-- Slanted top, rising towards −X (the reader stands on the +X side).
	local slant = CFrame.new(-12, 3.35, 18) * CFrame.Angles(0, 0, math.rad(-22))
	k.block(lectern, "LecternTop", V(1.8, 0.2, 1.5), slant, S.Wood, Style.wood())
	local book = k.block(lectern, "Book", V(1.5, 0.18, 1.2), slant * CFrame.new(0, 0.19, 0), C.Gold, {
		material = Enum.Material.Fabric,
	})
	Kit.station(lectern, book, k.at(-12, 6.4, 18))
end

local function tvCorner(k: Kit.Kit, parent: Instance)
	local tv = Kit.model(parent, "GarageTV", Tags.GarageTV)
	-- CrtTv prop against the yard pier, screen facing −Z (towards the sofa).
	k.prop(tv, "CrtTv", V(0, 0, 32.8), 0, {
		fallback = function(p, g)
			local m = Instance.new("Model")
			m.Name = "TvStandIn"
			m.Parent = p
			Builder.block(m, "TvStand", V(2.8, 1.4, 2), CFrame.new(g + V(0, 0.7, 0)), C.WoodDark, {
				material = Enum.Material.Wood,
			})
			return Builder.block(
				m,
				"TvBox",
				V(3, 2.4, 2.2),
				CFrame.new(g + V(0, 2.6, 0)),
				Color3.fromRGB(60, 56, 52)
			)
		end,
	})
	-- The screen ux puts the WATCH view on (front face = −Z).
	local screenPos = k.at(0, 2.6, 31.62)
	local screen = Builder.block(
		tv,
		"Screen",
		V(2.2, 1.7, 0.1),
		CFrame.lookAt(screenPos, screenPos + k.dir(V(0, 0, -1))),
		Color3.fromRGB(110, 150, 220),
		{ material = Enum.Material.Neon, collide = false, shadow = false }
	)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Range = 10
	glow.Brightness = 0.8
	glow.Angle = 100
	glow.Color = Color3.fromRGB(150, 180, 255)
	glow.Parent = screen
	Kit.station(tv, screen, k.at(0, 5.6, 31))

	-- Sofa facing the TV, a rug and a floor lamp.
	k.prop(parent, "Sofa", V(0, 0, 24), 180, {
		fallback = function(p, g)
			local m = Instance.new("Model")
			m.Name = "SofaStandIn"
			m.Parent = p
			local leather = Color3.fromRGB(120, 66, 40)
			local seat = Builder.block(m, "SofaSeat", V(7, 1.6, 3.2), CFrame.new(g + V(0, 0.8, 0)), leather, {
				material = Enum.Material.Fabric,
			})
			Builder.block(m, "SofaBack", V(7, 2, 0.8), CFrame.new(g + V(0, 2.5, -1.2)), leather, {
				material = Enum.Material.Fabric,
			})
			for _, sx in { -3.2, 3.2 } do
				Builder.block(m, "SofaArm", V(0.6, 2.4, 3.2), CFrame.new(g + V(sx, 1.2, 0)), leather, {
					material = Enum.Material.Fabric,
				})
			end
			return seat
		end,
	})
	k.box(parent, "Rug", V(-4, 0, 26), V(4, 0.08, 30.8), Color3.fromRGB(170, 96, 52), Style.decal())
	-- Floor lamp in the front corner between the window and the door (nobody walks there).
	k.box(parent, "FloorLampPole", V(-17.95, 0, 24.35), V(-17.65, 5.2, 24.65), C.Metal, Style.metal())
	local shade = k.cylinder(parent, "FloorLampShade", 1.6, 1, V(-17.8, 5.6, 24.5), S.Tungsten, {
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	Builder.pointLight(shade, 14, 0.9, S.Tungsten, false)
end

local function clutter(k: Kit.Kit, parent: Instance)
	local f = Builder.folder(parent, "LoungeClutter")
	-- An old arcade cabinet in the front corner, clear of the doorway (z 26..32).
	k.box(f, "Arcade", V(-18.6, 0, 14.3), V(-16.2, 5.6, 16.7), Color3.fromRGB(40, 44, 90), Style.wood())
	k.box(f, "ArcadeScreen", V(-16.25, 3.2, 14.7), V(-16.1, 4.8, 16.3), Color3.fromRGB(90, 220, 160), {
		material = Enum.Material.Neon,
		shadow = false,
	})
	-- Orange frame around the yard door (lounge side).
	local d = Style.YARD_DOOR
	k.box(f, "YardDoorFrame", V(d[1], 0, 33.7), V(d[1] + 0.25, 9.25, 34), S.Orange, Style.metal())
	k.box(f, "YardDoorFrame", V(d[2] - 0.25, 0, 33.7), V(d[2], 9.25, 34), S.Orange, Style.metal())
	k.box(f, "YardDoorFrame", V(d[1], 9, 33.7), V(d[2], 9.25, 34), S.Orange, Style.metal())
end

function Lounge.build(k: Kit.Kit, folder: Folder)
	local f = Builder.folder(folder, "Lounge")
	trophyWall(k, f)
	trophyBoard(k, f)
	collectionBook(k, f)
	tvCorner(k, f)
	clutter(k, f)
	Style.pendant(k, f, V(2, 13.4, 24), Style.CROWN, 30, 1.3, true)
end

return Lounge
