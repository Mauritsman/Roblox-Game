--!strict
-- Carried-loot visuals on the player's side (beta-spec §9.1). Visuals only: ux's HandsController/ContextController
-- own the inputs, the throw arc and the requests (LootThrow, Drop, LetGo, Roll). This controller
--   * hides the GrabPrompt on loot you hold yourself (no "Help carry" on your own wheel),
--   * spins a rolling wheel with the carrier's speed,
--   * smooths two-player carries (follows both bodies every frame instead of the server's network rate),
--   * flies thrown loot along the same arc as the server (Logic/Throw) from the `LootThrown` message.
-- It only moves a loot's Visual through its `VisualWeld` (C0); the Handle stays where the server puts it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Throw = require(ReplicatedStorage.Shared.Logic.Throw)

local CarryController = {}

local player = Players.LocalPlayer
local C = Config.Carry

local baseC0: { [Weld]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local spin: { [Weld]: number } = setmetatable({}, { __mode = "k" }) :: any

type ThrowAnim = { weld: Weld, from: Vector3, to: Vector3, height: number, duration: number, started: number }
local throws: { ThrowAnim } = {}

local function lootModels(): { [string]: Model }
	local byId = {}
	for _, inst in CollectionService:GetTagged(Tags.Loot) do
		local id = inst:GetAttribute(Tags.LootId)
		if inst:IsA("Model") and type(id) == "string" then
			byId[id] = inst
		end
	end
	return byId
end

local function visualWeld(model: Model): Weld?
	local handle = model.PrimaryPart or model:FindFirstChild("Handle")
	local weld = handle and handle:FindFirstChild("VisualWeld")
	if weld and weld:IsA("Weld") then
		if not baseC0[weld] then
			baseC0[weld] = weld.C0
		end
		return weld
	end
	return nil
end

local function tv(v: Vector3): Throw.Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function v3(t: Throw.Vec3): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local function rootOf(p: Player?): BasePart?
	local c = p and p.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function update(dt: number)
	local models = lootModels()

	-- Your own held loot: no prompt for yourself.
	local myCharacter = player.Character
	local ownId = myCharacter and myCharacter:GetAttribute(Tags.CarryLootId)
	local own = if type(ownId) == "string" then models[ownId] else nil
	local ownHandle = own and own.PrimaryPart
	local ownPrompt = ownHandle and ownHandle:FindFirstChild("GrabPrompt")
	if ownPrompt and ownPrompt:IsA("ProximityPrompt") and ownPrompt.Enabled then
		ownPrompt.Enabled = false
	end

	local animated: { [Weld]: boolean } = {}
	local t = os.clock()
	for index = #throws, 1, -1 do
		local anim = throws[index]
		local handle = anim.weld.Part0
		local alpha = (t - anim.started) / anim.duration
		if alpha >= 1 or not handle or not anim.weld.Parent then
			table.remove(throws, index)
		else
			local desired = v3(Throw.point(tv(anim.from), tv(anim.to), alpha, anim.height))
			anim.weld.C0 = handle.CFrame:ToObjectSpace(CFrame.new(desired) * handle.CFrame.Rotation)
				* (baseC0[anim.weld] or CFrame.identity)
			animated[anim.weld] = true
		end
	end

	for _, p in Players:GetPlayers() do
		local c = p.Character
		local id = c and c:GetAttribute(Tags.CarryLootId)
		local model = if type(id) == "string" then models[id] else nil
		local weld = model and visualWeld(model)
		if c and weld and not animated[weld] and c:GetAttribute(Tags.CarryRole) == "Lead" then
			local base = baseC0[weld] or CFrame.identity
			local handle = weld.Part0
			local partnerId = c:GetAttribute(Tags.CarryPartner)
			if c:GetAttribute(Tags.Rolling) == true then
				local root = rootOf(p)
				local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				spin[weld] = ((spin[weld] or 0) + speed * dt / 2) % (math.pi * 2)
				weld.C0 = CFrame.Angles(0, -(spin[weld] :: number), 0) * base
			elseif type(partnerId) == "number" and handle then
				local a, b = rootOf(p), rootOf(Players:GetPlayerByUserId(partnerId))
				if a and b then
					local mid = (a.Position + b.Position) / 2 + Vector3.new(0, -1, 0)
					local look = a.CFrame.LookVector
					local flat = Vector3.new(look.X, 0, look.Z)
					local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
					weld.C0 = handle.CFrame:ToObjectSpace(CFrame.lookAt(mid, mid + facing)) * base
				end
			elseif weld.C0 ~= base then
				weld.C0 = base
			end
			animated[weld] = true
		end
	end

	-- Everything else rests where the server put it.
	for weld, base in baseC0 do
		if not animated[weld] and weld.Parent and weld.C0 ~= base then
			weld.C0 = base
		end
	end
end

local function onThrown(userId: any, _lootName: any, from: any, to: any, duration: any)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or type(duration) ~= "number" then
		return
	end
	task.defer(function()
		for _, inst in CollectionService:GetTagged(Tags.Loot) do
			if
				inst:IsA("Model")
				and inst:GetAttribute(Tags.LootState) == "Thrown"
				and inst:GetAttribute(Tags.CarrierId) == userId
			then
				local weld = visualWeld(inst)
				if weld then
					table.insert(throws, {
						weld = weld,
						from = from,
						to = to,
						height = Throw.height((to - from).Magnitude, C.ThrowArc, C.ThrowArcMin),
						duration = math.max(0.05, duration),
						started = os.clock(),
					})
				end
				return
			end
		end
	end)
end

function CarryController:Start()
	Net.on("LootThrown", onThrown)
	RunService.RenderStepped:Connect(update)
end

return CarryController
