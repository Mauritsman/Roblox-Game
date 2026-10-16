--!strict
-- Workshop arch (z −34..−14): the gadget rack on the back wall (meta: GadgetRack), the workbench (perks:
-- Workbench) and the mirror (cosmetics: Mirror). meta's LobbyService puts the prompts on each PrimaryPart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MetaTags = require(ReplicatedStorage.Shared.MetaTags)

local Builder = require(script.Parent.Parent.Common.Builder)
local Kit = require(script.Parent.Kit)
local Style = require(script.Parent.Style)

local C = Builder.Colors
local S = Style.Colors
local V = Vector3.new

local BACK = Style.BACK
local SIGN_X = BACK - 0.05 - 0.15 -- a 0.3-deep sign against the back wall

local Workshop = {}

local function gadgetRack(k: Kit.Kit, parent: Instance)
	local rack = Kit.model(parent, "GadgetRack", MetaTags.GadgetRack)
	local board = k.box(rack, "Pegboard", V(BACK - 0.5, 1, -32), V(BACK, 8.4, -22), S.Cork, {
		material = Enum.Material.WoodPlanks,
	})
	for _, y in { 0.85, 8.55 } do
		k.box(
			rack,
			"RackTrim",
			V(BACK - 0.6, y - 0.15, -32.2),
			V(BACK, y + 0.15, -21.8),
			S.Orange,
			Style.metal()
		)
	end
	-- Tool outlines on the pegboard.
	for i, z in { -30.8, -29.6, -28.4 } do
		k.box(
			rack,
			"ToolOutline",
			V(BACK - 0.55, 4.6 + i * 0.3, z - 0.2),
			V(BACK - 0.5, 6.6, z + 0.2),
			C.StoneDark,
			{
				shadow = false,
			}
		)
	end
	-- The Crowbar on its hook (always in the loadout).
	k.box(rack, "Hook", V(BACK - 0.8, 6.6, -24.2), V(BACK - 0.5, 6.8, -23.8), C.Metal, Style.metal())
	k.block(
		rack,
		"Crowbar",
		V(0.25, 4.2, 0.25),
		CFrame.new(BACK - 0.75, 4.6, -24) * CFrame.Angles(math.rad(8), 0, 0),
		Builder.GadgetColors.Crowbar,
		Style.metal()
	)
	-- Four pedestals with the base gadgets in their fixed colours.
	local items = {
		{ name = "Drone", z = -30.6 },
		{ name = "Noisemaker", z = -28.2 },
		{ name = "EMP", z = -25.8 },
		{ name = "BubbleBlaster", z = -23.4 },
	}
	for _, item in items do
		local color = Builder.GadgetColors[item.name]
		local x, z = 17.4, item.z
		k.cylinder(rack, "Pedestal", 1.6, 2.6, V(x, 1.3, z), S.Concrete, Style.concrete())
		local cap = k.cylinder(
			rack,
			"PedestalTop",
			1.9,
			0.25,
			V(x, 2.72, z),
			color,
			{ material = Enum.Material.Neon }
		)
		cap:SetAttribute("Gadget", item.name)
		if item.name == "Drone" then
			k.block(rack, "DroneModel", V(1.4, 0.35, 1.4), CFrame.new(x, 3.05, z), color)
		elseif item.name == "Noisemaker" then
			k.cylinder(rack, "NoisemakerModel", 0.8, 0.9, V(x, 3.3, z), color, {})
		elseif item.name == "EMP" then
			k.block(
				rack,
				"EmpModel",
				V(1, 1, 1),
				CFrame.new(x, 3.35, z),
				color,
				{ shape = Enum.PartType.Ball }
			)
		else
			k.block(rack, "BubbleBlasterModel", V(0.6, 0.6, 1.4), CFrame.new(x, 3.15, z), color)
		end
	end
	Kit.station(rack, board, k.at(16, 11.8, -27))
	k.sign(parent, "GEAR", V(SIGN_X, 9.6, -27), V(-1, 0, 0), 5, 1.6, V(10, 5, -24))
end

local function workbench(k: Kit.Kit, parent: Instance)
	local station = Kit.model(parent, MetaTags.Workbench, MetaTags.Workbench)
	local prop = k.prop(station, "Workbench", V(16.5, 0, -19), 0, {
		fallback = function(p, g)
			local m = Instance.new("Model")
			m.Name = "WorkbenchStandIn"
			m.Parent = p
			local top = Builder.block(m, "BenchTop", V(6, 0.4, 3), CFrame.new(g + V(0, 3.8, 0)), C.WoodDark, {
				material = Enum.Material.WoodPlanks,
			})
			for _, sx in { -2.7, 2.7 } do
				for _, sz in { -1.2, 1.2 } do
					Builder.block(m, "BenchLeg", V(0.4, 3.6, 0.4), CFrame.new(g + V(sx, 1.8, sz)), C.Metal)
				end
			end
			Builder.block(m, "BenchShelf", V(5.6, 0.2, 2.6), CFrame.new(g + V(0, 1, 0)), C.WoodDark, {
				material = Enum.Material.WoodPlanks,
			})
			Builder.block(m, "Vise", V(0.8, 0.8, 1), CFrame.new(g + V(-2.4, 4.4, -1)), S.Enamel, {
				material = Enum.Material.Metal,
			})
			return top
		end,
	})
	local main = Kit.mainPart(prop)
	assert(main, "[Garage] workbench without parts")
	Kit.station(station, main, k.at(14.5, 7, -19))
	-- Arm lamp on the bench.
	k.box(station, "LampArm", V(18.9, 4, -18.1), V(19.1, 5.4, -17.9), C.Metal, Style.metal())
	local bulb = k.block(station, "LampBulb", V(0.6, 0.6, 0.6), CFrame.new(18.9, 5.6, -18), S.Tungsten, {
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		collide = false,
		shadow = false,
	})
	Builder.pointLight(bulb, 10, 0.9, S.Tungsten, false)
	k.sign(parent, "WORKBENCH", V(SIGN_X, 7.4, -19), V(-1, 0, 0), 5.6, 1.1, V(10, 5, -22))
end

local function mirror(k: Kit.Kit, parent: Instance)
	local station = Kit.model(parent, MetaTags.Mirror, MetaTags.Mirror)
	local prop = k.prop(station, "StandMirror", V(-8, 0, -33.3), 180, {
		fallback = function(p, g)
			local m = Instance.new("Model")
			m.Name = "MirrorStandIn"
			m.Parent = p
			local frame =
				Builder.block(m, "MirrorFrame", V(3, 7, 0.3), CFrame.new(g + V(0, 3.5, 0)), C.Gold, {
					material = Enum.Material.Foil,
				})
			local glass =
				Builder.block(m, "MirrorGlass", V(2.4, 6.3, 0.1), CFrame.new(g + V(0, 3.5, 0.18)), C.Trim, {
					material = Enum.Material.Glass,
				})
			glass.Reflectance = 0.5
			Builder.block(m, "MirrorFeet", V(3, 0.3, 1.2), CFrame.new(g + V(0, 0.15, 0)), C.Gold)
			return frame
		end,
	})
	local main = Kit.mainPart(prop)
	assert(main, "[Garage] mirror without parts")
	Kit.station(station, main, k.at(-8, 11, -31))
	k.cylinder(parent, "MirrorRug", 5, 0.08, V(-8, 0.04, -29), Color3.fromRGB(150, 60, 50), Style.decal())
	k.sign(parent, "LOOKS", V(-8, 9.2, -33.8), V(0, 0, 1), 5, 1.4, V(-8, 5, -24))
end

local function clutter(k: Kit.Kit, parent: Instance)
	local f = Builder.folder(parent, "WorkshopClutter")
	-- Steel shelving against the west pier.
	for _, x in { 4, 13.7 } do
		k.box(f, "ShelfUpright", V(x, 0, -33.9), V(x + 0.3, 7, -32.5), C.Metal, Style.metal())
	end
	for _, y in { 1, 3.5, 6 } do
		k.box(f, "Shelf", V(4, y - 0.2, -33.9), V(14, y, -32.5), C.Metal, Style.metal())
	end
	for i, spot in { V(5.5, 1, -33.2), V(8.6, 1, -33.2), V(6.6, 3.5, -33.2), V(11.4, 6, -33.2) } do
		k.box(
			f,
			"Box",
			spot + V(-1, 0, -0.6),
			spot + V(1, 1.6, 0.6),
			if i % 2 == 0 then S.Cork else Color3.fromRGB(196, 160, 110),
			{ material = Enum.Material.Cardboard }
		)
	end
	-- Tyres and oil drums by the front wall.
	for i = 0, 2 do
		k.block(
			f,
			"Tyre",
			V(0.9, 2.6, 2.6),
			CFrame.new(-16.5, 0.45 + i * 0.9, -28.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(30, 30, 32),
			{ shape = Enum.PartType.Cylinder, material = Enum.Material.Rubber }
		)
	end
	for i, spot in { V(-17, 0, -32.4), V(-14.2, 0, -32.6) } do
		k.prop(f, "Barrel", spot, i * 70, {
			scale = 1.3,
			fallback = function(p, g)
				return Builder.cylinder(p, "Drum", 2.4, 3.2, g + V(0, 1.6, 0), S.Enamel, {
					material = Enum.Material.Metal,
				})
			end,
		})
	end
end

function Workshop.build(k: Kit.Kit, folder: Folder)
	local f = Builder.folder(folder, "Workshop")
	gadgetRack(k, f)
	workbench(k, f)
	mirror(k, f)
	clutter(k, f)
	Style.pendant(k, f, V(2, 13.4, -24), Style.CROWN, 30, 1.3, true)
end

return Workshop
