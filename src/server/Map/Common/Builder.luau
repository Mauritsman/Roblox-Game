--!strict
-- Building helpers for all heists: blocks, cylinders, windows, labels and props.
-- Props come from ServerStorage.Props (AI-generated models, saved in the place).
-- If a prop is missing, we build a simple stand-in, so the map always works.

local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local Builder = {}

Builder.Colors = {
	BrickRed = Color3.fromRGB(128, 54, 42),
	BrickDark = Color3.fromRGB(86, 44, 36),
	BrickWarm = Color3.fromRGB(150, 78, 54),
	Cream = Color3.fromRGB(226, 210, 176),
	Plaster = Color3.fromRGB(196, 186, 160),
	PaintGreen = Color3.fromRGB(46, 74, 62),
	PaintNavy = Color3.fromRGB(38, 52, 84),
	PaintOchre = Color3.fromRGB(178, 128, 56),
	Trim = Color3.fromRGB(236, 232, 220),
	DoorGreen = Color3.fromRGB(30, 70, 52),
	DoorBlue = Color3.fromRGB(32, 54, 96),
	Stone = Color3.fromRGB(110, 112, 118),
	StoneDark = Color3.fromRGB(70, 72, 78),
	Cobble = Color3.fromRGB(92, 96, 104),
	Concrete = Color3.fromRGB(150, 150, 146),
	Wood = Color3.fromRGB(150, 104, 62),
	WoodDark = Color3.fromRGB(92, 60, 38),
	Metal = Color3.fromRGB(70, 74, 82),
	RackBlue = Color3.fromRGB(40, 86, 150),
	RackOrange = Color3.fromRGB(230, 120, 30),
	Cheese = Color3.fromRGB(242, 196, 64),
	Gold = Color3.fromRGB(255, 205, 40),
	CrewOrange = Color3.fromRGB(255, 128, 32),
	WindowLit = Color3.fromRGB(255, 196, 120),
	WindowDark = Color3.fromRGB(28, 34, 50),
	LampWarm = Color3.fromRGB(255, 190, 120),
	Safety = Color3.fromRGB(240, 196, 30),
}

local C = Builder.Colors

-- Colour per gadget (pedestals of the gadget rack): the same in every heist, so players recognise them.
Builder.GadgetColors = {
	Drone = Color3.fromRGB(70, 160, 255),
	Noisemaker = Color3.fromRGB(255, 210, 60),
	EMP = Color3.fromRGB(80, 220, 255),
	BubbleBlaster = Color3.fromRGB(255, 140, 220),
	Crowbar = Color3.fromRGB(255, 90, 80),
}

-- Height of the pavement along the facades (x -28..-22).
Builder.SIDEWALK = 0.3

-- Lit windows: warm tints, now and then the blue glow of a TV.
Builder.WindowGlows = {
	Color3.fromRGB(255, 178, 92),
	Color3.fromRGB(255, 196, 120),
	Color3.fromRGB(255, 160, 74),
	Color3.fromRGB(255, 208, 140),
	Color3.fromRGB(150, 178, 255),
}
Builder.Curtains = {
	Color3.fromRGB(150, 40, 40),
	Color3.fromRGB(40, 90, 60),
	Color3.fromRGB(220, 200, 160),
	Color3.fromRGB(60, 70, 130),
}

function Builder.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function applyVariant(part: BasePart, variant: string?)
	if variant and MaterialService:FindFirstChild(variant, true) then
		part.MaterialVariant = variant
	end
end

export type PartOpts = {
	material: Enum.Material?,
	variant: string?,
	transparency: number?,
	collide: boolean?,
	shadow: boolean?,
	shape: Enum.PartType?,
	query: boolean?,
}

-- An anchored block. size in studs, cframe = centre.
function Builder.block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	opts: PartOpts?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if opts then
		if opts.material then
			p.Material = opts.material
		end
		applyVariant(p, opts.variant)
		if opts.transparency then
			p.Transparency = opts.transparency
		end
		if opts.collide ~= nil then
			p.CanCollide = opts.collide
		end
		if opts.shadow ~= nil then
			p.CastShadow = opts.shadow
		end
		if opts.shape then
			p.Shape = opts.shape
		end
		if opts.query ~= nil then
			p.CanQuery = opts.query
		end
	end
	p.Parent = parent
	return p
end

-- Block between two corners (handy for walls and floors): min = (x1,y1,z1), max = (x2,y2,z2).
function Builder.box(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	color: Color3,
	opts: PartOpts?
): Part
	local minV = a:Min(b)
	local maxV = a:Max(b)
	local size = maxV - minV
	return Builder.block(parent, name, size, CFrame.new((minV + maxV) / 2), color, opts)
end

function Builder.wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	opts: PartOpts?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
	if opts then
		applyVariant(w, opts.variant)
		if opts.collide ~= nil then
			w.CanCollide = opts.collide
		end
	end
	w.Parent = parent
	return w
end

-- Cylinder with a vertical axis (Roblox cylinders lie along X by default).
function Builder.cylinder(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	center: Vector3,
	color: Color3,
	opts: PartOpts?
): Part
	local o: PartOpts = opts or {}
	o.shape = Enum.PartType.Cylinder
	return Builder.block(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		o
	)
end

-- A framed window on a facade. cf = centre of the glass, facing outwards.
function Builder.window(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	lit: boolean,
	frameColor: Color3?
)
	Builder.block(
		parent,
		"WindowFrame",
		Vector3.new(width + 0.6, height + 0.6, 0.3),
		cf * CFrame.new(0, 0, 0.05),
		frameColor or C.Trim
	)
	local glowColor = Builder.WindowGlows[math.random(1, #Builder.WindowGlows)]
	local glass = Builder.block(
		parent,
		"WindowGlass",
		Vector3.new(width, height, 0.3),
		cf * CFrame.new(0, 0, -0.1),
		if lit then glowColor else C.WindowDark,
		{
			material = if lit then Enum.Material.Neon else Enum.Material.Glass,
			shadow = false,
		}
	)
	if lit and math.random() < 0.45 then
		-- Curtain on one side: makes the lit windows less monotonous.
		local side = if math.random() < 0.5 then -1 else 1
		local curtain = Builder.Curtains[math.random(1, #Builder.Curtains)]
		Builder.block(
			parent,
			"Curtain",
			Vector3.new(width * 0.38, height, 0.1),
			cf * CFrame.new(side * width * 0.31, 0, -0.28),
			curtain,
			{ material = Enum.Material.Fabric, shadow = false }
		)
	end
	-- Glazing bars (a cross) for that typical Dutch paned window.
	Builder.block(
		parent,
		"Mullion",
		Vector3.new(0.18, height, 0.2),
		cf * CFrame.new(0, 0, -0.3),
		frameColor or C.Trim,
		{ shadow = false }
	)
	Builder.block(
		parent,
		"Transom",
		Vector3.new(width, 0.18, 0.2),
		cf * CFrame.new(0, height * 0.15, -0.3),
		frameColor or C.Trim,
		{ shadow = false }
	)
	if lit and math.random() < 0.15 then
		-- A few windows cast real light outside.
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Range = 10
		light.Brightness = 0.6
		light.Color = glowColor
		light.Angle = 80
		light.Parent = glass
	end
end

function Builder.label(adornee: BasePart, text: string, color: Color3, offsetY: number, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(170, 34)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 60
	gui.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Parent = gui
	gui.Parent = adornee
end

export type SignOpts = {
	doubleSided: boolean?, -- text on the front and back (hanging sign at right angles to the facade)
	frame: Color3?, -- thin frame around the board
	material: Enum.Material?,
}

-- A board with text. Readable in the dark (LightInfluence 0), with padding around the text so nothing gets
-- cut off, and a dark outline around the letters for contrast.
function Builder.sign(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	text: string,
	bg: Color3,
	fg: Color3,
	font: Enum.Font?,
	opts: SignOpts?
): Part
	local board = Builder.block(parent, "Sign", size, cf, bg, {
		material = (opts and opts.material) or Enum.Material.Wood,
	})
	local faces = { Enum.NormalId.Front }
	if opts and opts.doubleSided then
		table.insert(faces, Enum.NormalId.Back)
	end
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignText"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui.MaxDistance = 250
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = text
		t.TextColor3 = fg
		t.TextScaled = true
		t.TextWrapped = false
		t.Font = font or Enum.Font.FredokaOne
		t.TextStrokeColor3 = bg:Lerp(Color3.new(0, 0, 0), 0.65)
		t.TextStrokeTransparency = 0.45
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.06, 0)
		pad.PaddingRight = UDim.new(0.06, 0)
		pad.PaddingTop = UDim.new(0.12, 0)
		pad.PaddingBottom = UDim.new(0.12, 0)
		pad.Parent = t
		t.Parent = gui
		gui.Parent = board
	end
	if opts and opts.frame then
		local w, h = size.X, size.Y
		local depth = size.Z + 0.08
		for _, edge in
			{
				{ Vector3.new(w + 0.24, 0.12, depth), Vector3.new(0, h / 2 + 0.06, 0) },
				{ Vector3.new(w + 0.24, 0.12, depth), Vector3.new(0, -h / 2 - 0.06, 0) },
				{ Vector3.new(0.12, h, depth), Vector3.new(w / 2 + 0.06, 0, 0) },
				{ Vector3.new(0.12, h, depth), Vector3.new(-w / 2 - 0.06, 0, 0) },
			}
		do
			Builder.block(
				parent,
				"SignFrame",
				edge[1],
				cf * CFrame.new(edge[2]),
				opts.frame,
				{ shadow = false }
			)
		end
	end
	return board
end

function Builder.pointLight(
	parent: Instance,
	range: number,
	brightness: number,
	color: Color3?,
	shadows: boolean?
): PointLight
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color or C.LampWarm
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

export type PropOpts = {
	scale: number?,
	collide: boolean?,
	shadow: boolean?,
	fallback: ((parent: Instance, ground: Vector3, rotY: number) -> Instance)?,
}

-- Places a prop with its bottom at `ground` (x, floor y, z) and rotation rotY (degrees).
function Builder.prop(
	parent: Instance,
	templateName: string,
	ground: Vector3,
	rotY: number?,
	opts: PropOpts?
): Instance?
	local props = ServerStorage:FindFirstChild("Props")
	local template = props and props:FindFirstChild(templateName)
	local rot = CFrame.Angles(0, math.rad(rotY or 0), 0)
	if not template then
		if opts and opts.fallback then
			return opts.fallback(parent, ground, rotY or 0)
		end
		return nil
	end
	local clone = template:Clone()
	if clone:IsA("Model") then
		if opts and opts.scale then
			clone:ScaleTo(clone:GetScale() * opts.scale)
		end
		local bboxCf, size = clone:GetBoundingBox()
		local pivotOffset = bboxCf:ToObjectSpace(clone:GetPivot())
		local target = CFrame.new(ground + Vector3.new(0, size.Y / 2, 0)) * rot
		clone:PivotTo(target * pivotOffset)
	elseif clone:IsA("BasePart") then
		if opts and opts.scale then
			clone.Size *= opts.scale
		end
		clone.CFrame = CFrame.new(ground + Vector3.new(0, clone.Size.Y / 2, 0)) * rot
	end
	local collide = if opts and opts.collide ~= nil then opts.collide else true
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
			if opts and opts.shadow ~= nil then
				d.CastShadow = opts.shadow
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- safety: props must never bring code along
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = collide
	end
	clone.Parent = parent
	return clone
end

-- A canal tree (elm): trunk with a crown of balls. The crown does not collide (the drone may fly through).
function Builder.tree(parent: Instance, ground: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = rng:NextNumber(8, 10.5)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), 0, math.rad(rng:NextNumber(-3, 3)))
	local trunk = Builder.block(
		model,
		"Trunk",
		Vector3.new(height, 1.1, 1.1),
		CFrame.new(ground + Vector3.new(0, height / 2, 0)) * lean * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(70, 54, 42),
		{ material = Enum.Material.Wood, shape = Enum.PartType.Cylinder }
	)
	local top = (trunk.CFrame * CFrame.new(height / 2, 0, 0)).Position
	local greens = { Color3.fromRGB(46, 84, 50), Color3.fromRGB(58, 98, 56), Color3.fromRGB(40, 72, 48) }
	for i = 1, 6 do
		local d = rng:NextNumber(4.5, 7.5)
		local offset =
			Vector3.new(rng:NextNumber(-2.6, 2.6), rng:NextNumber(-0.5, 2.8), rng:NextNumber(-2.6, 2.6))
		if i == 1 then
			offset = Vector3.new(0, 1.5, 0)
			d = 8
		end
		Builder.block(
			model,
			"Leaves",
			Vector3.new(d, d, d),
			CFrame.new(top + offset),
			greens[rng:NextInteger(1, #greens)],
			{
				material = Enum.Material.LeafyGrass,
				shape = Enum.PartType.Ball,
				collide = false,
			}
		)
	end
	-- Tree ring: a border of paving bricks around the trunk.
	Builder.block(
		model,
		"TreeRing",
		Vector3.new(3, 0.12, 3),
		CFrame.new(ground + Vector3.new(0, 0.06, 0)),
		Color3.fromRGB(58, 46, 36),
		{
			material = Enum.Material.Ground,
			collide = false,
		}
	)
	model.Parent = parent
	return model
end

-- A sloop (small boat) on the water; the bow points towards +Z.
function Builder.boat(parent: Instance, waterCenter: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name = "Sloep"
	local cf = CFrame.new(waterCenter)
	Builder.block(
		model,
		"Hull",
		Vector3.new(4.2, 1.4, 9),
		cf * CFrame.new(0, 0, -0.5),
		color,
		{ material = Enum.Material.Wood }
	)
	Builder.wedge(
		model,
		"Bow",
		Vector3.new(4.2, 1.4, 2.4),
		cf * CFrame.new(0, 0, 5.2) * CFrame.Angles(0, math.rad(180), 0),
		color,
		{
			material = Enum.Material.Wood,
		}
	)
	Builder.block(
		model,
		"Deck",
		Vector3.new(3.4, 0.2, 8.4),
		cf * CFrame.new(0, 0.55, -0.5),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	Builder.block(
		model,
		"Gunwale",
		Vector3.new(4.4, 0.3, 9.2),
		cf * CFrame.new(0, 0.75, -0.5),
		C.Trim,
		{ material = Enum.Material.Wood }
	)
	Builder.block(
		model,
		"Bench",
		Vector3.new(3.4, 0.3, 1),
		cf * CFrame.new(0, 1, 1),
		C.WoodDark,
		{ material = Enum.Material.Wood }
	)
	Builder.block(
		model,
		"Cushion",
		Vector3.new(3.2, 0.4, 2.6),
		cf * CFrame.new(0, 1, -3),
		Color3.fromRGB(176, 60, 50),
		{
			material = Enum.Material.Fabric,
		}
	)
	model.Parent = parent
	return model
end

-- Highest point (y) of a part or model; handy for putting something on top of a prop.
function Builder.topOf(inst: Instance?): number?
	if not inst then
		return nil
	end
	if inst:IsA("Model") then
		local cf, size = inst:GetBoundingBox()
		return cf.Position.Y + size.Y / 2
	elseif inst:IsA("BasePart") then
		return inst.Position.Y + inst.Size.Y / 2
	end
	return nil
end

return Builder
