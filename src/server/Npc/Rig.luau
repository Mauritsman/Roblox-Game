--!strict
-- Building NPC models (guards, Karel, the Inspector, Boef) and their floating state icons.
-- Humanoid NPCs try a real R15 character first and fall back to blocks. All NPC parts use the "Guards"
-- collision group (registered by MapService and GuardService), so GuardDoor parts let them through and they walk
-- through player characters ("Players", bug B-007).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Rig = {}

export type Colors = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
}

export type Billboard = {
	gui: BillboardGui,
	icon: TextLabel,
	bar: Frame,
	fill: Frame,
}

local function blockRig(colors: Colors): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 4.5, 1.5)
	root.Color = colors.shirt
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = colors.skin
	head.CFrame = root.CFrame * CFrame.new(0, 2.95, 0)
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.75
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- A humanoid NPC: R15 from a HumanoidDescription, or a block figure when that fails.
function Rig.humanoid(name: string, colors: Colors): Model
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = colors.skin
		description.LeftArmColor = colors.shirt
		description.RightArmColor = colors.shirt
		description.TorsoColor = colors.shirt
		description.LeftLegColor = colors.pants
		description.RightLegColor = colors.pants
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	local rig: Model
	if ok and model then
		rig = model
	else
		warn(`[Rig] CreateHumanoidModelFromDescription failed for {name}, using blocks:`, model)
		rig = blockRig(colors)
	end
	rig.Name = name
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	-- No tripping, ragdolling or climbing: NPCs that bumped into something fell over or climbed it (B-007, B-010).
	for _, state in
		{
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Climbing,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
	return rig
end

-- Boef: a small dog built from blocks with a Humanoid (MoveTo works on any model with a root and a Humanoid).
function Rig.dog(): Model
	local model = Instance.new("Model")
	model.Name = "Boef"
	local fur = Color3.fromRGB(150, 100, 60)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(1.4, 1.4, 3)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end
	piece("Body", Vector3.new(1.3, 1.2, 2.6), CFrame.new(0, 0, 0), fur)
	local head = piece("Head", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0.6, -1.6), fur)
	piece("Snout", Vector3.new(0.6, 0.5, 0.6), CFrame.new(0, 0.45, -2.3), Color3.fromRGB(60, 40, 30))
	piece("EarL", Vector3.new(0.3, 0.6, 0.3), CFrame.new(-0.4, 1.3, -1.6), Color3.fromRGB(90, 60, 35))
	piece("EarR", Vector3.new(0.3, 0.6, 0.3), CFrame.new(0.4, 1.3, -1.6), Color3.fromRGB(90, 60, 35))
	piece(
		"Tail",
		Vector3.new(0.25, 0.25, 1),
		CFrame.new(0, 0.5, 1.6) * CFrame.Angles(math.rad(35), 0, 0),
		fur
	)
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.9, 0.9 } do
			piece("Leg", Vector3.new(0.35, 1, 0.35), CFrame.new(x, -1, z), fur)
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 1.4
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.Parent = model
	model.PrimaryPart = root
	local _ = head
	return model
end

-- A small prop welded to a body part (cap, clipboard, broom).
function Rig.attach(
	model: Model,
	partName: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	name: string
)
	local base = model:FindFirstChild(partName) or model:FindFirstChild("HumanoidRootPart")
	if not base or not base:IsA("BasePart") then
		return
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
end

-- Floating icon ("?", "!") with an optional meter bar above the head.
function Rig.billboard(model: Model, height: number?): Billboard
	local head = model:FindFirstChild("Head") :: BasePart?
	local gui = Instance.new("BillboardGui")
	gui.Name = "NpcState"
	gui.Size = UDim2.fromOffset(60, 70)
	gui.StudsOffset = Vector3.new(0, height or 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local adornee: BasePart? = head or model.PrimaryPart
	if adornee then
		gui.Adornee = adornee
	end
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 52)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBlack
	icon.TextScaled = true
	icon.TextStrokeTransparency = 0
	icon.Text = ""
	icon.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Meter"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 56)
	bar.Size = UDim2.new(0.8, 0, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bar.BackgroundTransparency = 0.3
	bar.Visible = false
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	gui.Parent = model
	return { gui = gui, icon = icon, bar = bar, fill = fill }
end

function Rig.setIcon(board: Billboard, text: string, color: Color3)
	board.icon.Text = text
	board.icon.TextColor3 = color
end

-- Shows a meter (0..1); hidden near 0 or when `hide` is true.
function Rig.setMeter(board: Billboard, value: number, hide: boolean?, color: Color3?)
	board.bar.Visible = value > 0.02 and not hide
	board.fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
	board.fill.BackgroundColor3 = color or Color3.fromRGB(255, 220, 60)
end

-- Roblox's default R15 walk animation (only for R15 rigs with an Animator).
function Rig.walkTrack(humanoid: Humanoid): AnimationTrack?
	local model = humanoid.Parent
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if
		not animator
		or humanoid.RigType ~= Enum.HumanoidRigType.R15
		or not model
		or not model:FindFirstChild("UpperTorso")
	then
		return nil
	end
	local walk = Instance.new("Animation")
	walk.AnimationId = "rbxassetid://507777826"
	local ok, track = pcall(function()
		return animator:LoadAnimation(walk)
	end)
	return if ok then track else nil
end

-- Plays the walk while moving, at a speed that matches the feet. Start and stop thresholds differ so a guard
-- creeping at about 0.5 studs/s no longer starts and stops the animation every frame (B-010).
function Rig.updateWalk(track: AnimationTrack?, root: BasePart)
	if not track then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if not track.IsPlaying then
		if speed > 1.5 then
			track:Play(0.2)
		end
	elseif speed < 0.5 then
		track:Stop(0.2)
	else
		local rate = math.clamp(speed / 14, 0.5, 1.4) -- the default walk matches about 14 studs/s
		if math.abs(track.Speed - rate) > 0.1 then
			track:AdjustSpeed(rate)
		end
	end
end

-- Puts the model in the world: collision group, server network ownership, tags.
function Rig.place(model: Model, parent: Instance, at: CFrame, tags: { string })
	model:PivotTo(at)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Guards"
		end
	end
	model.Parent = parent
	for _, tag in tags do
		CollectionService:AddTag(model, tag)
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

-- A short sound at a part (Roblox built-in sounds only).
function Rig.sound(parent: Instance, soundId: string, speed: number?, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed or 1
	sound.Volume = volume or 0.8
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	task.delay(3, function()
		sound:Destroy()
	end)
end

-- The folder NPCs live in (inside the heist level so a rebuild removes them).
function Rig.folder(level: Instance?, name: string): Folder
	local parent: Instance = level or workspace
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

return Rig
