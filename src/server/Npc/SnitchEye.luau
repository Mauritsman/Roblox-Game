--!strict
-- A snitch's eyes (beta-spec §4.3, §6.2): Karel and the Health Inspector see crew like a guard (70° cone,
-- range 25, the same crouch/carry/difficulty factors) but slower (Karel ×0.5, Inspector ×0.67). A full meter calls
-- `onReport(player, position)` once per player per Config.Snitch.Cooldown; the meter shows above their head.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Detection = require(ReplicatedStorage.Shared.Logic.Detection)
local Snitch = require(ReplicatedStorage.Shared.Logic.Snitch)
local Tags = require(ReplicatedStorage.Shared.Tags)

local Rig = require(script.Parent.Rig)
local Targets = require(script.Parent.Targets)

local S = Config.Snitch
local G = Config.Guard
local COS_HALF = math.cos(math.rad(G.ConeHalfAngle))
local RATES = {
	CrouchFillRate = G.CrouchFillRate,
	CarryFillRate = G.CarryFillRate,
	LockdownFillRate = G.LockdownFillRate,
	SleepyFillRate = Config.Modifiers.SleepyGuards.FillRate,
}

local SnitchEye = {}
SnitchEye.__index = SnitchEye

type Data = {
	model: Model,
	root: BasePart,
	board: Rig.Billboard,
	fill: number,
	meters: { [Player]: number },
	lastReport: { [Player]: number },
	onReport: (player: Player, position: Vector3) -> (),
	blind: boolean,
}

export type SnitchEye = typeof(setmetatable({} :: Data, SnitchEye))

function SnitchEye.new(
	model: Model,
	root: BasePart,
	board: Rig.Billboard,
	fill: number,
	onReport: (player: Player, position: Vector3) -> ()
): SnitchEye
	local self: Data = {
		model = model,
		root = root,
		board = board,
		fill = fill,
		meters = {},
		lastReport = {},
		onReport = onReport,
		blind = false,
	}
	return setmetatable(self, SnitchEye)
end

local function params(model: Model): RaycastParams
	local ignore: { Instance } = { model }
	for _, tag in { Tags.SeeThrough, Tags.Npc, Tags.Loot, Tags.Guard, Tags.Drone } do
		for _, inst in CollectionService:GetTagged(tag) do
			table.insert(ignore, inst)
		end
	end
	local result = RaycastParams.new()
	result.FilterType = Enum.RaycastFilterType.Exclude
	result.FilterDescendantsInstances = ignore
	return result
end

-- Call about every 0.1 s.
function SnitchEye.step(self: SnitchEye, dt: number)
	local maxMeter = 0
	if self.blind or not Targets.inHeist() then
		table.clear(self.meters)
		Rig.setMeter(self.board, 0, true)
		return
	end
	local now = Targets.now()
	local eye = self.root.Position + Vector3.new(0, G.HeadHeight, 0)
	local look = self.root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.zAxis
	local rayParams: RaycastParams? = nil
	local sleepy = Targets.modifier() == "SleepyGuards"
	local lockdown = Targets.lockdown()
	local tierFill = Targets.round().fillRate
	for _, view in Targets.crewViews() do
		local player = view.player
		local meter = self.meters[player] or 0
		local rate = 0
		if not Targets.ignored(player, view.character, now) then
			local offset = view.root.Position - eye
			local distance = offset.Magnitude
			if distance <= S.Range and distance > 0.01 then
				local dir = offset.Unit
				local flatDir = Vector3.new(dir.X, dir.Y * 0.5, dir.Z).Unit
				if flatLook:Dot(flatDir) >= COS_HALF then
					rayParams = rayParams or params(self.model)
					local hit = workspace:Raycast(eye, offset, rayParams :: RaycastParams)
					if hit == nil or hit.Instance:IsDescendantOf(view.character) then
						local factors = Detection.factorsFor({
							crouching = view.character:GetAttribute(Tags.Crouching) == true,
							carryClass = Targets.carryClass(view.character),
							sleepyGuards = sleepy,
							lockdown = lockdown,
							tierFillRate = tierFill,
							extra = self.fill,
						}, RATES)
						rate = Detection.fillRate(distance, S.Range, factors)
					end
				end
			end
		end
		local full
		meter, full = Snitch.step(meter, dt, rate, G.DecayPerSecond)
		if full then
			meter = 0
			if Snitch.canReport(self.lastReport[player], now, S.Cooldown) then
				self.lastReport[player] = now
				task.spawn(self.onReport, player, view.root.Position)
			end
		end
		self.meters[player] = meter
		maxMeter = math.max(maxMeter, meter)
	end
	Rig.setMeter(self.board, maxMeter, false, Color3.fromRGB(255, 160, 200))
end

function SnitchEye.reset(self: SnitchEye)
	table.clear(self.meters)
	table.clear(self.lastReport)
end

return SnitchEye
