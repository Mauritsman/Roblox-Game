--!strict
-- The Health Inspector (beta-spec §6.2, Hot Job modifier "HealthInspector"): walks a spare guard route at 6 and
-- snitches like Karel (range 25, fill ×0.67): a whistle, +20 alarm, the 2 nearest guards investigate. Catches
-- nobody. Unlike Karel he can be bubbled (8 s: stands still and sees nothing).
-- Tagged `Guard` as well as `Npc` so the Bubble Blaster's hit test treats him like a guard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Patrol = require(ReplicatedStorage.Shared.Logic.Patrol)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Mover = require(script.Parent.Mover)
local Rig = require(script.Parent.Rig)
local SnitchEye = require(script.Parent.SnitchEye)

local Inspector = {}
Inspector.__index = Inspector

export type Hooks = {
	addAlarm: (reason: string, points: number?, player: Player?) -> (),
	alertNearest: (position: Vector3, count: number) -> (),
}

type Data = {
	kind: string,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	mover: Mover.Mover,
	board: Rig.Billboard,
	eye: SnitchEye.SnitchEye,
	route: { Patrol.Step },
	routeIndex: number,
	waitUntil: number,
	waited: boolean,
	stunUntil: number,
	bubblePart: BasePart?,
	visionTimer: number,
}

export type Inspector = typeof(setmetatable({} :: Data, Inspector))

function Inspector.new(parent: Instance, route: { Patrol.Step }, start: number, hooks: Hooks): Inspector?
	if #route == 0 then
		return nil
	end
	local model = Rig.humanoid("Inspector", {
		skin = Color3.fromRGB(230, 190, 160),
		shirt = Color3.fromRGB(245, 245, 245),
		pants = Color3.fromRGB(60, 60, 70),
	})
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = Config.Snitch.InspectorSpeed
	Rig.attach(
		model,
		"Head",
		Vector3.new(1.2, 0.5, 1.2),
		CFrame.new(0, 0.8, 0),
		Color3.fromRGB(250, 250, 250),
		"Hat"
	)
	Rig.attach(
		model,
		"LeftHand",
		Vector3.new(0.9, 1.2, 0.1),
		CFrame.new(0, 0, -0.4),
		Color3.fromRGB(150, 110, 70),
		"Clipboard"
	)
	local board = Rig.billboard(model)
	model:SetAttribute(Tags.NpcKind, "Inspector")
	model:SetAttribute("NpcState", "Patrol")
	model:SetAttribute(Tags.SpotKind, "guard")
	local first = route[start].pos :: Vector3
	Rig.place(
		model,
		parent,
		CFrame.new(first + Vector3.new(0, 3, 0)),
		{ Tags.Npc, Tags.Guard, Tags.Spottable }
	)

	local self: Data = {
		kind = "Inspector",
		model = model,
		humanoid = humanoid,
		root = root,
		mover = Mover.new(humanoid, root),
		board = board,
		eye = nil :: any,
		route = route,
		routeIndex = Patrol.nextIndex(start, #route),
		waitUntil = 0,
		waited = false,
		stunUntil = 0,
		bubblePart = nil,
		visionTimer = 0,
	}
	local inspector = setmetatable(self, Inspector)
	inspector.eye = SnitchEye.new(model, root, board, Config.Snitch.InspectorFill, function(player, position)
		Rig.sound(root, "rbxasset://sounds/electronicpingshort.wav", 2.2, 1)
		Net.broadcast("Toast", 'Inspector: "*WHISTLE* VIOLATION!"')
		Net.broadcast("Spotted", player.UserId, "snitch")
		hooks.addAlarm("Snitch", Config.Snitch.Points, player)
		hooks.alertNearest(position, Config.Snitch.GuardsAlerted)
	end)
	return inspector
end

function Inspector.step(self: Inspector, dt: number)
	local now = os.clock()
	if self.stunUntil > now then
		self.mover:stop()
		self.eye.blind = true
		self.eye:step(dt)
		return
	end
	if self.bubblePart then
		self.bubblePart:Destroy()
		self.bubblePart = nil
		self.model:SetAttribute(Tags.Bubbled, nil)
		self.model:SetAttribute("NpcState", "Patrol")
		Net.broadcast("Toast", 'Inspector: "This will be in my report!"')
	end
	self.eye.blind = false
	self.visionTimer += dt
	if self.visionTimer >= 0.1 then
		self.eye:step(self.visionTimer)
		self.visionTimer = 0
	end
	if self.waitUntil > now then
		return
	end
	local step = self.route[self.routeIndex]
	local point = step.pos :: Vector3
	local floorY = self.root.Position.Y - 3
	local usePath = math.abs(point.Y - floorY) > Config.Guard.FloorStep
	if
		Patrol.arrived(
			self.mover:flatDistance(point),
			floorY,
			point,
			Config.Guard.ArriveDistance,
			Config.Guard.FloorStep
		) or self.mover:stuck()
	then
		if step.wait > 0 and not self.waited then
			self.waited = true
			self.waitUntil = now + step.wait
			self.mover:stop()
			return
		end
		self.waited = false
		self.routeIndex = Patrol.nextIndex(self.routeIndex, #self.route)
		point = self.route[self.routeIndex].pos :: Vector3
	end
	self.mover:moveTo(point, usePath)
	self.mover:step()
end

-- The Bubble Blaster works on him (8 s).
function Inspector.bubble(self: Inspector, seconds: number, _by: Player?): boolean
	self.stunUntil = os.clock() + seconds
	self.model:SetAttribute(Tags.Bubbled, true)
	self.model:SetAttribute("NpcState", "Stunned")
	if not self.bubblePart then
		local bubble = Instance.new("Part")
		bubble.Name = "Bubble"
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.new(7, 7, 7)
		bubble.Material = Enum.Material.Glass
		bubble.Transparency = 0.55
		bubble.Color = Color3.fromRGB(190, 230, 255)
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.Massless = true
		bubble.CFrame = self.root.CFrame * CFrame.new(0, 0.5, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = self.root
		weld.Part1 = bubble
		weld.Parent = bubble
		bubble.Parent = self.model
		self.bubblePart = bubble
	end
	return true
end

function Inspector.destroy(self: Inspector)
	self.mover:stop()
	if self.model.Parent then
		self.model:Destroy()
	end
end

return Inspector
