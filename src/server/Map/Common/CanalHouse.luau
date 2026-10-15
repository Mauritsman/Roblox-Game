--!strict
-- A Dutch canal house as background: facade with paned windows, door, cornice and gable.
-- origin = bottom centre of the facade; the LookVector of origin points towards the street.

local Builder = require(script.Parent.Builder)

local C = Builder.Colors

local CanalHouse = {}

export type HouseSpec = {
	width: number,
	floors: number,
	depth: number?,
	color: Color3,
	brick: boolean?,
	gable: "step" | "spout" | "bell" | "flat",
	door: boolean?,
	litChance: number?,
}

local FLOOR_HEIGHT = 7
local GROUND_FLOOR = 8

local function gable(
	parent: Instance,
	origin: CFrame,
	width: number,
	baseY: number,
	style: string,
	color: Color3,
	opts: Builder.PartOpts
)
	if style == "step" then
		-- Step gable: three steps that get narrower.
		local steps = 3
		local stepH = 3
		for i = 1, steps do
			local w = width - (i - 1) * (width / (steps + 1)) * 1.1
			Builder.block(
				parent,
				"GableStep",
				Vector3.new(w, stepH, 1.2),
				origin * CFrame.new(0, baseY + (i - 0.5) * stepH, 0.6),
				color,
				opts
			)
			Builder.block(
				parent,
				"GableCap",
				Vector3.new(w + 0.4, 0.4, 1.6),
				origin * CFrame.new(0, baseY + i * stepH, 0.6),
				C.Trim
			)
		end
		Builder.block(
			parent,
			"GableTop",
			Vector3.new(width * 0.22, 2, 1.2),
			origin * CFrame.new(0, baseY + steps * stepH + 1, 0.6),
			color,
			opts
		)
	elseif style == "spout" or style == "bell" then
		-- Neck gable: narrow centre piece with sloping shoulders.
		local neckW = width * 0.45
		local neckH = if style == "bell" then 9 else 7
		Builder.block(
			parent,
			"GableNeck",
			Vector3.new(neckW, neckH, 1.2),
			origin * CFrame.new(0, baseY + neckH / 2, 0.6),
			color,
			opts
		)
		local shoulderW = (width - neckW) / 2
		for _, side in { -1, 1 } do
			local w = Builder.wedge(
				parent,
				"GableShoulder",
				Vector3.new(1.2, 4, shoulderW),
				origin
					* CFrame.new(side * (neckW / 2 + shoulderW / 2), baseY + 2, 0.6)
					* CFrame.Angles(0, math.rad(side * 90), 0),
				color,
				opts
			)
			local _ = w
		end
		Builder.block(
			parent,
			"GableCap",
			Vector3.new(neckW + 0.6, 0.5, 1.6),
			origin * CFrame.new(0, baseY + neckH, 0.6),
			C.Trim
		)
		if style == "bell" then
			Builder.cylinder(
				parent,
				"GableRound",
				neckW * 0.7,
				1.2,
				(origin * CFrame.new(0, baseY + neckH + 0.6, 0.6)).Position,
				color,
				opts
			)
		end
		-- Hoist beam: typical of canal houses.
		Builder.block(
			parent,
			"HoistBeam",
			Vector3.new(0.5, 0.5, 2.4),
			origin * CFrame.new(0, baseY + neckH - 1.2, -0.9),
			C.WoodDark
		)
	else
		Builder.block(
			parent,
			"Cornice",
			Vector3.new(width + 0.8, 1.2, 1.8),
			origin * CFrame.new(0, baseY + 0.6, 0.4),
			C.Trim
		)
	end
end

function CanalHouse.build(parent: Instance, origin: CFrame, spec: HouseSpec, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "CanalHouse"
	local depth = spec.depth or 14
	local height = GROUND_FLOOR + spec.floors * FLOOR_HEIGHT
	local wallOpts: Builder.PartOpts = if spec.brick
		then { material = Enum.Material.Brick, variant = "CC_Brick" }
		else { material = Enum.Material.Plaster }

	-- Body (behind the facade, +Z in object space).
	Builder.block(
		model,
		"Body",
		Vector3.new(spec.width, height, depth),
		origin * CFrame.new(0, height / 2, depth / 2),
		spec.color,
		wallOpts
	)
	-- Roof behind the gable.
	Builder.block(
		model,
		"Roof",
		Vector3.new(spec.width - 0.4, 1, depth - 2),
		origin * CFrame.new(0, height + 0.5, depth / 2 + 1),
		C.StoneDark,
		{
			material = Enum.Material.Slate,
			variant = "CC_Roof",
		}
	)

	-- Plinth and cornice.
	Builder.block(
		model,
		"Plinth",
		Vector3.new(spec.width + 0.2, 1, 0.6),
		origin * CFrame.new(0, 0.5, -0.2),
		C.StoneDark,
		{
			material = Enum.Material.Slate,
		}
	)
	Builder.block(
		model,
		"Cornice",
		Vector3.new(spec.width + 0.6, 0.8, 1),
		origin * CFrame.new(0, height - 0.4, -0.3),
		C.Trim
	)
	gable(model, origin, spec.width, height, spec.gable, spec.color, wallOpts)

	-- Windows per floor.
	local cols = if spec.width >= 14 then 3 elseif spec.width >= 9 then 2 else 1
	local spacing = spec.width / cols
	local litChance = spec.litChance or 0.5
	for floor = 1, spec.floors do
		local y = GROUND_FLOOR + (floor - 0.5) * FLOOR_HEIGHT
		for col = 1, cols do
			local x = -spec.width / 2 + spacing * (col - 0.5)
			Builder.window(model, origin * CFrame.new(x, y, -0.2), 2.4, 3.8, rng:NextNumber() < litChance)
		end
	end
	-- Ground floor: door + window.
	if spec.door ~= false then
		local doorX = if cols > 1 then -spec.width / 2 + spacing * 0.5 else 0
		Builder.block(
			model,
			"DoorFrame",
			Vector3.new(3.2, 6.6, 0.3),
			origin * CFrame.new(doorX, 3.3 + 0.8, -0.15),
			C.Trim
		)
		Builder.block(
			model,
			"Door",
			Vector3.new(2.6, 6, 0.3),
			origin * CFrame.new(doorX, 3 + 0.8, -0.3),
			if rng:NextNumber() < 0.5 then C.DoorGreen else C.DoorBlue
		)
		Builder.block(
			model,
			"Step",
			Vector3.new(3.6, 0.8, 1.6),
			origin * CFrame.new(doorX, 0.4, -0.8),
			C.Stone,
			{ material = Enum.Material.Slate }
		)
		Builder.block(
			model,
			"Fanlight",
			Vector3.new(2.4, 0.9, 0.3),
			origin * CFrame.new(doorX, 7.4, -0.3),
			C.WindowLit,
			{
				material = Enum.Material.Neon,
			}
		)
		for col = 2, cols do
			local x = -spec.width / 2 + spacing * (col - 0.5)
			Builder.window(model, origin * CFrame.new(x, 4.2, -0.2), 2.6, 3.6, rng:NextNumber() < litChance)
		end
	end
	model.Parent = parent
	return model
end

-- A row of houses along a line. from/to = points on the facade line, facing = direction towards the street.
function CanalHouse.row(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	facing: Vector3,
	rng: Random,
	opts: { depth: number?, maxFloors: number? }?
)
	local palette = {
		{ color = C.BrickRed, brick = true },
		{ color = C.BrickDark, brick = true },
		{ color = C.BrickWarm, brick = true },
		{ color = C.Cream, brick = false },
		{ color = C.PaintGreen, brick = false },
		{ color = C.PaintNavy, brick = false },
		{ color = C.PaintOchre, brick = false },
	}
	local gables = { "step", "spout", "bell", "flat", "step", "spout" }
	local dir = (to - from)
	local length = dir.Magnitude
	local unit = dir.Unit
	local pos = 0
	while pos < length - 0.5 do
		local width = math.min(rng:NextInteger(10, 17), length - pos)
		if length - pos - width < 9 then
			width = length - pos -- no gaps at the end of the row
		end
		local center = from + unit * (pos + width / 2)
		local origin = CFrame.lookAt(center, center + facing)
		local style = palette[rng:NextInteger(1, #palette)]
		CanalHouse.build(parent, origin, {
			width = width,
			floors = rng:NextInteger(2, (opts and opts.maxFloors) or 4),
			depth = (opts and opts.depth) or 16,
			color = style.color,
			brick = style.brick,
			gable = gables[rng:NextInteger(1, #gables)] :: any,
			litChance = 0.55,
		}, rng)
		pos += width
	end
end

return CanalHouse
