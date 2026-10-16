--!strict
-- Building helpers for areas built away from the world origin (the Garage and the mini-job slots). Every position
-- you pass is LOCAL to the area's origin CFrame; Kit turns it into a world position and calls Common/Builder.
-- Also: anchors, zones, station models, simple windows and low-detail background houses.
-- The mini-job uses this module too (script.Parent.Parent.Garage.Kit). Candidate for Common once map package A's
-- Common/Anchors exists.
--
-- Contracts (beta-spec-maps §1, docs/contracts.md §2.5):
-- - Anchor = invisible, anchored part with CanCollide, CanQuery and CanTouch false; its CFrame is the item's
--   bottom centre, facing −Z.
-- - Zone = invisible, non-colliding volume (BankZone, GarageVan, triggers); CanTouch stays on so Touched works.
-- - Multi-part interactive models stream in as a whole (ModelStreamingMode Atomic) for StreamingEnabled.

local CollectionService = game:GetService("CollectionService")

local Builder = require(script.Parent.Parent.Common.Builder)

local Kit = {}

export type Attrs = { [string]: any }

export type SignStyle = {
	bg: Color3?,
	fg: Color3?,
	frame: Color3?,
	depth: number?,
}

export type Kit = {
	origin: CFrame,
	-- Local → world.
	at: (x: number, y: number, z: number) -> Vector3,
	world: (v: Vector3) -> Vector3,
	cf: (localCf: CFrame) -> CFrame,
	dir: (v: Vector3) -> Vector3,
	-- Parts (local coordinates).
	box: (
		parent: Instance,
		name: string,
		a: Vector3,
		b: Vector3,
		color: Color3,
		opts: Builder.PartOpts?
	) -> Part,
	block: (
		parent: Instance,
		name: string,
		size: Vector3,
		localCf: CFrame,
		color: Color3,
		opts: Builder.PartOpts?
	) -> Part,
	wedge: (
		parent: Instance,
		name: string,
		size: Vector3,
		localCf: CFrame,
		color: Color3,
		opts: Builder.PartOpts?
	) -> WedgePart,
	cylinder: (
		parent: Instance,
		name: string,
		diameter: number,
		height: number,
		center: Vector3,
		color: Color3,
		opts: Builder.PartOpts?
	) -> Part,
	prop: (
		parent: Instance,
		templateName: string,
		ground: Vector3,
		rotY: number?,
		opts: Builder.PropOpts?
	) -> Instance?,
	sign: (
		parent: Instance,
		text: string,
		center: Vector3,
		facing: Vector3,
		width: number,
		height: number,
		viewFrom: Vector3,
		style: SignStyle?
	) -> Part,
	window: (
		parent: Instance,
		localCf: CFrame,
		width: number,
		height: number,
		lit: boolean,
		frame: Color3?
	) -> (),
	-- Gameplay markers.
	anchor: (parent: Instance, name: string, localCf: CFrame, attrs: Attrs?, tag: string?) -> Part,
	zone: (parent: Instance, name: string, a: Vector3, b: Vector3, attrs: Attrs?, tag: string?) -> Part,
}

-- Tags an instance (CollectionService) and sets attributes.
function Kit.mark(inst: Instance, tag: string?, attrs: Attrs?)
	if tag then
		CollectionService:AddTag(inst, tag)
	end
	if attrs then
		for key, value in attrs do
			inst:SetAttribute(key, value)
		end
	end
end

-- An empty Model that streams in as a whole.
function Kit.model(parent: Instance, name: string, tag: string?, attrs: Attrs?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	Kit.mark(model, tag, attrs)
	model.Parent = parent
	return model
end

-- Attachment at a world position on a part (e.g. HideSpot Inside/Exit, station Beacon).
function Kit.attachment(part: BasePart, name: string, worldPos: Vector3): Attachment
	local att = Instance.new("Attachment")
	att.Name = name
	att.Position = part.CFrame:PointToObjectSpace(worldPos)
	att.Parent = part
	return att
end

-- Station model (meta's Garage tags): sets the PrimaryPart (prompts go there) and a "Beacon" attachment where ux
-- draws the tour beacon.
function Kit.station(model: Model, primary: BasePart, beaconWorld: Vector3?): Model
	model.PrimaryPart = primary
	if beaconWorld then
		Kit.attachment(primary, "Beacon", beaconWorld)
	end
	return model
end

-- The first BasePart of a prop clone or fallback (a BasePart itself, or the biggest part inside a Model).
function Kit.mainPart(inst: Instance?): BasePart?
	if inst == nil then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	local best: BasePart? = nil
	local bestVolume = -1
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			local volume = d.Size.X * d.Size.Y * d.Size.Z
			if volume > bestVolume then
				best = d
				bestVolume = volume
			end
		end
	end
	return best
end

local INVISIBLE: Builder.PartOpts = { transparency = 1, collide = false, query = false, shadow = false }

function Kit.new(origin: CFrame): Kit
	local _, yaw, _ = origin:ToOrientation()
	local yawDeg = math.deg(yaw)

	local function world(v: Vector3): Vector3
		return origin * v
	end
	local function cf(localCf: CFrame): CFrame
		return origin * localCf
	end

	local kit = {} :: Kit
	kit.origin = origin
	kit.at = function(x: number, y: number, z: number): Vector3
		return origin * Vector3.new(x, y, z)
	end
	kit.world = world
	kit.cf = cf
	kit.dir = function(v: Vector3): Vector3
		return origin:VectorToWorldSpace(v)
	end

	kit.box = function(parent, name, a, b, color, opts)
		local minV = a:Min(b)
		local maxV = a:Max(b)
		return Builder.block(parent, name, maxV - minV, cf(CFrame.new((minV + maxV) / 2)), color, opts)
	end
	kit.block = function(parent, name, size, localCf, color, opts)
		return Builder.block(parent, name, size, cf(localCf), color, opts)
	end
	kit.wedge = function(parent, name, size, localCf, color, opts)
		local w = Builder.wedge(parent, name, size, cf(localCf), color, opts)
		if opts and opts.shadow ~= nil then
			w.CastShadow = opts.shadow
		end
		return w
	end
	kit.cylinder = function(parent, name, diameter, height, center, color, opts)
		return Builder.cylinder(parent, name, diameter, height, world(center), color, opts)
	end
	kit.prop = function(parent, templateName, ground, rotY, opts)
		return Builder.prop(parent, templateName, world(ground), (rotY or 0) + yawDeg, opts)
	end

	-- A readable sign (Builder.sign) whose front faces `facing`; `viewFrom` (local) is where players read it,
	-- stored as the world attribute ViewFrom for the tester's line-of-sight test (beta-spec-maps §2).
	kit.sign = function(parent, text, center, facing, width, height, viewFrom, style)
		local c = world(center)
		local board = Builder.sign(
			parent,
			CFrame.lookAt(c, c + origin:VectorToWorldSpace(facing)),
			Vector3.new(width, height, (style and style.depth) or 0.3),
			text,
			(style and style.bg) or Color3.fromRGB(34, 30, 28),
			(style and style.fg) or Color3.fromRGB(255, 236, 200),
			nil,
			{ frame = (style and style.frame) or Builder.Colors.CrewOrange }
		)
		board:SetAttribute("ViewFrom", world(viewFrom))
		return board
	end

	-- A simple framed window (4 parts, no lights). localCf = centre of the glass, LookVector = outwards.
	kit.window = function(parent, localCf, width, height, lit, frame)
		local frameColor = frame or Builder.Colors.Trim
		Builder.block(
			parent,
			"WindowFrame",
			Vector3.new(width + 0.6, height + 0.6, 0.3),
			cf(localCf * CFrame.new(0, 0, 0.05)),
			frameColor,
			{ shadow = false }
		)
		Builder.block(
			parent,
			"WindowGlass",
			Vector3.new(width, height, 0.3),
			cf(localCf * CFrame.new(0, 0, -0.1)),
			if lit then Builder.Colors.WindowLit else Builder.Colors.WindowDark,
			{ material = if lit then Enum.Material.Neon else Enum.Material.Glass, shadow = false }
		)
		Builder.block(
			parent,
			"Mullion",
			Vector3.new(0.18, height, 0.2),
			cf(localCf * CFrame.new(0, 0, -0.3)),
			frameColor,
			{ shadow = false }
		)
		Builder.block(
			parent,
			"Transom",
			Vector3.new(width, 0.18, 0.2),
			cf(localCf * CFrame.new(0, height * 0.15, -0.3)),
			frameColor,
			{ shadow = false }
		)
	end

	kit.anchor = function(parent, name, localCf, attrs, tag)
		local part =
			Builder.block(parent, name, Vector3.new(1, 1, 1), cf(localCf), Color3.new(1, 1, 1), INVISIBLE)
		part.CanTouch = false
		Kit.mark(part, tag, attrs)
		return part
	end

	kit.zone = function(parent, name, a, b, attrs, tag)
		local minV = a:Min(b)
		local maxV = a:Max(b)
		local part = Builder.block(
			parent,
			name,
			maxV - minV,
			cf(CFrame.new((minV + maxV) / 2)),
			Color3.new(1, 1, 1),
			INVISIBLE
		)
		part.CanTouch = true
		Kit.mark(part, tag, attrs)
		return part
	end

	return kit
end

-- A low-detail background house (one block per window, no lights): body, roof, cornice and a simple gable.
-- localCf = bottom centre of the facade; its LookVector points at the street.
function Kit.farHouse(
	k: Kit,
	parent: Instance,
	localCf: CFrame,
	width: number,
	floors: number,
	color: Color3,
	rng: Random
)
	local C = Builder.Colors
	local height = 8 + floors * 7
	local depth = 10
	local brick = rng:NextNumber() < 0.6
	local opts: Builder.PartOpts = if brick
		then { material = Enum.Material.Brick, variant = "CC_Brick" }
		else { material = Enum.Material.Plaster }
	k.block(
		parent,
		"FarHouse",
		Vector3.new(width, height, depth),
		localCf * CFrame.new(0, height / 2, depth / 2),
		color,
		opts
	)
	k.block(
		parent,
		"FarCornice",
		Vector3.new(width + 0.4, 0.6, 0.8),
		localCf * CFrame.new(0, height - 0.3, -0.2),
		C.Trim,
		{ shadow = false }
	)
	local gableW = width * 0.5
	k.block(
		parent,
		"FarGable",
		Vector3.new(gableW, 4, 1),
		localCf * CFrame.new(0, height + 2, 0.5),
		color,
		opts
	)
	local cols = if width >= 12 then 3 else 2
	local spacing = width / cols
	for floor = 1, floors do
		for col = 1, cols do
			local lit = rng:NextNumber() < 0.5
			k.block(
				parent,
				"FarWindow",
				Vector3.new(2.2, 3.4, 0.2),
				localCf * CFrame.new(-width / 2 + spacing * (col - 0.5), 8 + (floor - 0.5) * 7, -0.1),
				if lit then Builder.WindowGlows[rng:NextInteger(1, 4)] else C.WindowDark,
				{ material = if lit then Enum.Material.Neon else Enum.Material.Glass, shadow = false }
			)
		end
	end
end

-- A row of low-detail houses along a line (local), facing `facing`.
function Kit.farRow(k: Kit, parent: Instance, from: Vector3, to: Vector3, facing: Vector3, rng: Random)
	local C = Builder.Colors
	local palette = { C.BrickRed, C.BrickDark, C.BrickWarm, C.Cream, C.PaintGreen, C.PaintNavy, C.PaintOchre }
	local delta = to - from
	local length = delta.Magnitude
	local unit = delta.Unit
	local pos = 0
	while pos < length - 0.5 do
		local width = math.min(rng:NextInteger(10, 15), length - pos)
		if length - pos - width < 8 then
			width = length - pos
		end
		local center = from + unit * (pos + width / 2)
		Kit.farHouse(
			k,
			parent,
			CFrame.lookAt(center, center + facing),
			width,
			rng:NextInteger(2, 3),
			palette[rng:NextInteger(1, #palette)],
			rng
		)
		pos += width
	end
end

return Kit
