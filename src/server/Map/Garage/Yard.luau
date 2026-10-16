--!strict
-- Practice yard (z 38..64, the fourth arch): throw line, three baskets at 6/8/10 studs (mechanics:
-- PracticeTarget), two fixed wheel anchors and a Big Wheel on a ramp (Session = "Practice": practice loot never
-- banks and returns home), a rusty old van with a practice BankZone, two tall casks to hide in and a cardboard guard.
-- The only way in is the yard door from the lounge (x −14..−8); a 12-high fence faces the forecourt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Parent.Common.Builder)
local Kit = require(script.Parent.Kit)
local Style = require(script.Parent.Style)
local VanBay = require(script.Parent.VanBay)

local C = Builder.Colors
local S = Style.Colors
local V = Vector3.new

local SESSION = "Practice"
local THROW_X = -10

local Yard = {}

local function basket(k: Kit.Kit, parent: Instance, ground: Vector3, distance: number)
	local target = Kit.model(parent, "PracticeTarget", Tags.PracticeTarget, { Distance = distance })
	k.prop(target, "BasketTarget", ground, 90, {
		fallback = function(p, g)
			local m = Instance.new("Model")
			m.Name = "BasketStandIn"
			m.Parent = p
			Builder.block(m, "BasketFoot", V(1.8, 0.3, 1.8), CFrame.new(g + V(0, 0.15, 0)), C.Metal)
			local post = Builder.block(m, "BasketPost", V(0.4, 3.6, 0.4), CFrame.new(g + V(0, 2, 0)), C.Metal)
			Builder.cylinder(m, "Basket", 2.4, 1.2, g + V(0, 4.2, 0), Color3.fromRGB(176, 136, 80), {
				material = Enum.Material.Fabric,
			})
			Builder.cylinder(m, "BasketRim", 2.7, 0.2, g + V(0, 4.85, 0), S.Orange, { collide = false })
			return post
		end,
	})
	-- The catch volume at the basket's mouth (PrimaryPart).
	local catch = k.block(target, "Catch", V(2.8, 1.8, 2.8), CFrame.new(ground + V(0, 4.4, 0)), S.Orange, {
		transparency = 1,
		collide = false,
		query = false,
		shadow = false,
	})
	catch.CanTouch = true
	target.PrimaryPart = catch
	-- Distance mark on the floor in front of the basket.
	k.box(parent, "DistanceMark", ground + V(-2.2, 0, -1), ground + V(-1.8, 0.05, 1), C.Trim, Style.decal())
end

local function practiceLoot(k: Kit.Kit, parent: Instance, anchors: Instance)
	for i, z in { 50, 54 } do
		k.box(parent, "Pallet", V(-15.5, 0, z - 1.5), V(-12.5, 0.2, z + 1.5), C.Wood, {
			material = Enum.Material.WoodPlanks,
		})
		k.anchor(anchors, `PracticeWheel{i}`, CFrame.new(-14, 0.2, z), {
			AnchorClass = "Medium",
			AnchorId = `Garage_PracticeWheel{i}`,
			Zone = "PracticeYard",
			Fixed = true,
			Session = SESSION,
		}, Tags.LootAnchor)
	end
	-- Big Wheel on a 2-high platform with an 18° ramp down towards the throw line (for practising rolls).
	k.wedge(
		parent,
		"RollRamp",
		V(4, 2, 6),
		CFrame.new(9, 1, 44) * CFrame.Angles(0, math.rad(90), 0),
		S.Concrete,
		Style.concrete()
	)
	k.box(parent, "RollPlatform", V(12, 0, 42), V(16, 2, 46), S.Concrete, Style.concrete())
	k.box(parent, "PlatformEdge", V(12, 2, 41.8), V(16, 2.06, 42.2), C.Safety, Style.decal())
	k.anchor(anchors, "PracticeBigWheel", CFrame.new(14, 2, 44), {
		AnchorClass = "Heavy",
		AnchorId = "Garage_PracticeBigWheel",
		Zone = "PracticeYard",
		Fixed = true,
		Session = SESSION,
	}, Tags.LootAnchor)
end

local function oldVan(k: Kit.Kit, parent: Instance)
	local model = Kit.model(parent, "PracticeVan")
	-- Rear doors face −Z (towards the platform); the practice BankZone is right behind them.
	k.prop(model, "Van", V(10, 0, 57.5), 180, { fallback = VanBay.vanFallback(S.Rust) })
	k.zone(parent, "PracticeBankZone", V(5, 0, 46.5), V(15, 8, 51), { Session = SESSION }, Tags.BankZone)
end

local function cardboardGuard(k: Kit.Kit, parent: Instance)
	-- In the corner by the yard pier, out of the throwing and rolling lanes.
	k.prop(parent, "CardboardGuard", V(2, 0, 40.5), 90, {
		fallback = function(p, g, r)
			local m = Instance.new("Model")
			m.Name = "CardboardGuardStandIn"
			m.Parent = p
			local base = CFrame.new(g) * CFrame.Angles(0, math.rad(r), 0)
			local board =
				Builder.block(m, "Cutout", V(3, 4.4, 0.3), base * CFrame.new(0, 2.6, 0), C.PaintNavy, {
					material = Enum.Material.Cardboard,
				})
			Builder.block(
				m,
				"CutoutHead",
				V(1.6, 1.6, 0.3),
				base * CFrame.new(0, 5.4, 0),
				Color3.fromRGB(232, 190, 150),
				{
					material = Enum.Material.Cardboard,
				}
			)
			Builder.block(
				m,
				"CutoutStand",
				V(0.3, 2, 1.4),
				base * CFrame.new(0, 1, 0.8),
				Color3.fromRGB(196, 160, 110),
				{
					material = Enum.Material.Cardboard,
				}
			)
			return board
		end,
	})
end

function Yard.build(k: Kit.Kit, folder: Folder, anchors: Instance)
	local f = Builder.folder(folder, "Yard")
	-- Throw line and its sign (on a post, readable when you come out of the yard door).
	k.box(f, "ThrowLine", V(THROW_X - 0.2, 0, 44), V(THROW_X + 0.2, 0.06, 62), C.Trim, Style.decal())
	-- High on its post (bottom edge ≥ 8.5): people walk under it on their way in from the yard door.
	k.box(f, "SignPost", V(THROW_X - 0.15, 0, 43.45), V(THROW_X + 0.15, 8.9, 43.75), C.Metal, Style.metal())
	k.sign(f, "THROW LINE", V(THROW_X, 9.5, 43.3), V(0, 0, -1), 6.6, 1.2, V(-11, 5, 37.5))
	-- Beside the yard door on the lounge side: the arch springs right above the door, so no room over it.
	k.sign(f, "PRACTICE\nYARD", V(-5, 6.2, 33.8), V(0, 0, -1), 5.6, 2.4, V(-10, 5, 22))

	local baskets: { { at: Vector3, distance: number } } = {
		{ at = V(-4, 0, 44), distance = 6 },
		{ at = V(-2, 0, 53), distance = 8 },
		{ at = V(0, 0, 61), distance = 10 },
	}
	for _, spec in baskets do
		basket(k, f, spec.at, spec.distance)
	end
	practiceLoot(k, f, anchors)
	oldVan(k, f)
	cardboardGuard(k, f)
	for _, z in { 50, 54 } do
		Style.hideSpot(
			k,
			f,
			"TallCask",
			V(18, 0, z),
			V(3.6, 6, 3.6),
			V(-1, 0, 0),
			"TallCask",
			nil,
			Tags.HideSpot
		)
	end
	Style.pendant(k, f, V(0, 13.4, 51), Style.CROWN, 28, 1.1, false)
end

return Yard
