--!strict
-- The mini-job's street (beta-spec-maps §5): quay and canal (part water), house rows on both banks, a bridge, road
-- barriers at the ends, the van exit (mechanics: Exit + BankZone with this slot's Session + DrivePoint), the market
-- stall with the first wheel (15 studs from the spawn) and the sleeping guard's chair.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Builder = require(script.Parent.Parent.Common.Builder)
local CanalHouse = require(script.Parent.Parent.Common.CanalHouse)
local Kit = require(script.Parent.Parent.Garage.Kit)
local Style = require(script.Parent.Parent.Garage.Style)
local VanBay = require(script.Parent.Parent.Garage.VanBay)

local C = Builder.Colors
local V = Vector3.new

export type Context = {
	k: Kit.Kit,
	folder: Folder,
	anchors: Folder,
	slot: number,
	session: string,
	points: {
		Spawn: Vector3,
		Wheel: Vector3,
		Van: Vector3,
		DrivePoint: Vector3,
		SleepingGuard: Vector3,
		SleepingGuardFacing: Vector3,
		Gouda: Vector3,
		Barrel: Vector3,
	},
}

local Street = {}

local QUAY_X = -34 -- canal edge
local FACADE_X = -12 -- our row of houses and the shop

local function ground(ctx: Context, rng: Random)
	local k = ctx.k
	local f = Builder.folder(ctx.folder, "Ground")
	k.box(f, "Quay", V(QUAY_X, -8, -46), V(FACADE_X, 0, 46), C.Cobble, {
		material = Enum.Material.Cobblestone,
		variant = "CC_Cobble",
	})
	k.box(f, "Pavement", V(FACADE_X, -8, -46), V(14, 0, 46), Color3.fromRGB(128, 126, 122), {
		material = Enum.Material.Slate,
	})
	k.box(f, "QuayEdge", V(QUAY_X - 0.4, 0, -46), V(QUAY_X + 0.6, 0.3, 46), C.Stone, {
		material = Enum.Material.Granite,
	})
	k.box(f, "QuayWall", V(QUAY_X - 1, -8, -46), V(QUAY_X - 0.4, 0, 46), C.BrickDark, Style.brick())
	k.box(f, "CanalBed", V(-46, -12, -46), V(QUAY_X - 1, -8, 46), Color3.fromRGB(40, 46, 44), {
		material = Enum.Material.Mud,
	})
	k.box(f, "CanalWater", V(-46, -8, -46), V(QUAY_X - 1, -3, 46), Style.Colors.Water, {
		transparency = 0.15,
		collide = false,
		shadow = false,
		query = false,
	})
	k.box(f, "FarQuayWall", V(-46.6, -8, -46), V(-46, 0, 46), C.BrickDark, Style.brick())
	k.box(f, "FarBank", V(-70, -8, -46), V(-46.6, 0, 46), C.Cobble, { material = Enum.Material.Cobblestone })
	Kit.farRow(k, f, V(-50, 0, -46), V(-50, 0, 46), V(1, 0, 0), rng)
	-- Painted spot where the player arrives.
	local spawn = ctx.points.Spawn
	k.cylinder(f, "ArrivalMark", 4, 0.05, V(spawn.X, 0.025, spawn.Z), C.CrewOrange, Style.decal())
end

-- Our rows of canal houses beside the shop (full detail, but without window lights: the light budget is 10).
local function houses(ctx: Context, rng: Random)
	local k = ctx.k
	local f = Builder.folder(ctx.folder, "Houses")
	local facing = k.dir(V(-1, 0, 0))
	CanalHouse.row(f, k.at(FACADE_X, 0, -46), k.at(FACADE_X, 0, -8), facing, rng, { maxFloors = 3 })
	CanalHouse.row(f, k.at(FACADE_X, 0, 22), k.at(FACADE_X, 0, 46), facing, rng, { maxFloors = 3 })
	for _, d in f:GetDescendants() do
		if d:IsA("Light") then
			d:Destroy()
		end
	end
end

local function edges(ctx: Context)
	local k = ctx.k
	local f = Builder.folder(ctx.folder, "Edges")
	local invisible: Builder.PartOpts = { transparency = 1, query = false, shadow = false }
	k.box(f, "EdgeCanal", V(QUAY_X, 0, -23), V(QUAY_X + 0.6, 16, 29), C.Stone, invisible)
	k.box(f, "EdgeSouth", V(QUAY_X, 0, -22.6), V(FACADE_X, 16, -22), C.Stone, invisible)
	k.box(f, "EdgeNorth", V(QUAY_X, 0, 28), V(FACADE_X, 16, 28.6), C.Stone, invisible)
	-- Red and white road barriers: the visible reason the street ends.
	for _, z in { -22.3, 28.3 } do
		for i = 0, 3 do
			local x0 = QUAY_X + 1 + i * 5.4
			k.box(
				f,
				"RoadBarrier",
				V(x0, 0.9, z - 0.3),
				V(x0 + 4.6, 2.3, z + 0.3),
				if i % 2 == 0 then Color3.fromRGB(220, 60, 50) else C.Trim
			)
			k.box(f, "BarrierFoot", V(x0 + 2, 0, z - 0.6), V(x0 + 2.6, 0.9, z + 0.6), C.Metal, Style.metal())
		end
	end
	-- A bridge over the canal beyond the north barrier (scenery).
	k.box(f, "BridgeDeck", V(-47, 0, 34), V(QUAY_X + 0.6, 0.8, 40), C.BrickRed, Style.brick())
	k.box(f, "BridgeArch", V(-45, -3, 34.2), V(QUAY_X - 1.5, 0, 39.8), C.BrickDark, Style.brick())
	for _, z in { 34.3, 39.7 } do
		k.box(
			f,
			"BridgeParapet",
			V(-47, 0.8, z - 0.3),
			V(QUAY_X + 0.6, 2.4, z + 0.3),
			C.BrickDark,
			Style.brick()
		)
	end
	Style.streetLamp(k, f, V(-40, 0.8, 37), 20)
end

-- The van exit (contract: Model tagged Exit, ExitKind; children BankZone (+ Session) and DrivePoint).
local function vanExit(ctx: Context)
	local k, p = ctx.k, ctx.points
	local exit = Kit.model(ctx.folder, "VanExit", Tags.Exit, { ExitKind = "Van" })
	-- Nose south (−Z), rear doors facing the stall (+Z).
	k.prop(exit, "Van", p.Van, 0, { fallback = VanBay.vanFallback(C.CrewOrange) })
	local bank =
		k.zone(exit, "BankZone", V(-32, 0, -6.5), V(-24, 8, -1.5), { Session = ctx.session }, Tags.BankZone)
	k.anchor(exit, "DrivePoint", CFrame.lookAt(p.DrivePoint, p.DrivePoint + V(0, 0, -1)))
	exit.PrimaryPart = bank
	-- The van glows a little, so new players see where to bring the loot.
	local glow = k.block(exit, "VanGlow", V(1, 1, 1), CFrame.new(p.Van + V(0, 6, 6.2)), C.CrewOrange, {
		transparency = 1,
		collide = false,
		query = false,
		shadow = false,
	})
	glow.CanTouch = false
	Builder.pointLight(glow, 12, 1.2, C.CrewOrange, false)
end

local STRIPES = { Color3.fromRGB(200, 50, 50), C.Trim }

local function marketStall(ctx: Context)
	local k = ctx.k
	local f = Builder.folder(ctx.folder, "MarketStall")
	local wheel = ctx.points.Wheel
	local base = V(wheel.X, 0, 2.9) -- 8 wide (x), 5 deep (z); counter on the south side, facing the spawn
	k.prop(f, "MarketStall", base, 0, {
		fallback = function(parent, g)
			local m = Instance.new("Model")
			m.Name = "MarketStallStandIn"
			m.Parent = parent
			local counter =
				Builder.block(m, "StallCounter", V(8, 2.6, 2), CFrame.new(g + V(0, 1.3, -1.5)), C.Wood, {
					material = Enum.Material.WoodPlanks,
				})
			Builder.block(m, "StallBack", V(8, 1.6, 2), CFrame.new(g + V(0, 0.8, 1.4)), C.WoodDark, {
				material = Enum.Material.WoodPlanks,
			})
			for _, sx in { -3.8, 3.8 } do
				for _, sz in { -2.3, 2.3 } do
					Builder.block(
						m,
						"StallPost",
						V(0.3, 6.7, 0.3),
						CFrame.new(g + V(sx, 3.35, sz)),
						C.WoodDark
					)
				end
			end
			for i = 0, 4 do
				Builder.block(
					m,
					"StallRoof",
					V(1.6, 0.3, 5.4),
					CFrame.new(g + V(-3.2 + i * 1.6, 6.85, 0)),
					STRIPES[i % 2 + 1],
					{ material = Enum.Material.Fabric }
				)
			end
			return counter
		end,
	})
	-- The first loot: a wheel on the counter, 15 studs in front of the spawn.
	k.anchor(ctx.anchors, "StallWheel", CFrame.new(wheel), {
		AnchorClass = "Medium",
		AnchorId = `T{ctx.slot}_StallWheel`,
		Zone = "Quay",
		Fixed = true,
		Opener = true,
		Session = ctx.session,
	}, Tags.LootAnchor)
	-- Header board on the stall roof, readable from the spawn.
	for _, sx in { -2, 2 } do
		k.box(f, "BoardPost", V(wheel.X + sx - 0.1, 7, 0.55), V(wheel.X + sx + 0.1, 7.4, 0.75), C.WoodDark)
	end
	k.sign(f, "CHEESE", V(wheel.X, 7.95, 0.5), V(0, 0, -1), 5, 1.4, ctx.points.Spawn + V(0, 1.5, 0), {
		bg = Color3.fromRGB(242, 196, 64),
		fg = Color3.fromRGB(60, 36, 20),
		frame = Color3.fromRGB(200, 50, 50),
	})
	local lantern = k.block(f, "StallLantern", V(0.7, 0.9, 0.7), CFrame.new(wheel.X, 5.9, 0.9), C.LampWarm, {
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	Builder.pointLight(lantern, 12, 1, C.LampWarm, false)
end

-- The sleeping guard's chair by the shop door; mechanics places the static guard at the SleepingGuard anchor.
local function guardSpot(ctx: Context)
	local k, p = ctx.k, ctx.points
	local seat = p.SleepingGuard
	local f = Builder.folder(ctx.folder, "GuardChair")
	k.box(
		f,
		"ChairSeat",
		V(seat.X - 1, 1.5, seat.Z - 1),
		V(seat.X + 1, 1.8, seat.Z + 1),
		C.WoodDark,
		Style.wood()
	)
	-- He faces the canal (−X): the backrest is on the shop side.
	k.box(
		f,
		"ChairBack",
		V(seat.X + 0.8, 1.8, seat.Z - 1),
		V(seat.X + 1, 4.4, seat.Z + 1),
		C.WoodDark,
		Style.wood()
	)
	for _, sx in { -0.85, 0.85 } do
		for _, sz in { -0.85, 0.85 } do
			k.box(
				f,
				"ChairLeg",
				V(seat.X + sx - 0.12, 0, seat.Z + sz - 0.12),
				V(seat.X + sx + 0.12, 1.5, seat.Z + sz + 0.12),
				C.WoodDark,
				Style.wood()
			)
		end
	end
	k.anchor(
		ctx.anchors,
		"SleepingGuard",
		CFrame.lookAt(seat, seat + p.SleepingGuardFacing),
		{ Session = ctx.session }
	)
end

local function quayDetails(ctx: Context)
	local k = ctx.k
	local f = Builder.folder(ctx.folder, "QuayDetails")
	-- By the houses next to the arrival spot (out of the van's and the lanes' way).
	Style.streetLamp(k, f, V(-13.6, 0, -14), 30, true)
	Style.streetLamp(k, f, V(-33, 0, 20), 26)
	k.prop(f, "Crate", V(-31.2, 0, 12.5), 15, {
		fallback = function(parent, g)
			return Builder.block(parent, "Crate", V(4, 3.8, 4), CFrame.new(g + V(0, 1.9, 0)), C.Wood, {
				material = Enum.Material.WoodPlanks,
			})
		end,
	})
	k.prop(f, "Barrel", V(-31.4, 0, 16.6), 30, {
		scale = 1.3,
		fallback = function(parent, g)
			return Builder.cylinder(parent, "Barrel", 2.4, 3.2, g + V(0, 1.6, 0), C.Wood, {
				material = Enum.Material.Wood,
			})
		end,
	})
end

function Street.build(ctx: Context, rng: Random)
	ground(ctx, rng)
	houses(ctx, rng)
	edges(ctx)
	vanExit(ctx)
	marketStall(ctx)
	guardSpot(ctx)
	quayDetails(ctx)
end

return Street
