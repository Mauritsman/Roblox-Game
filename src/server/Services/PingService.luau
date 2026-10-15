--!strict
-- Pings (§3.5): icon markers in the world ("SPOT") and fixed quick messages (NOW / WAIT).
-- No free text: players cannot type anything themselves, so everyone may use them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local PingService = {}

-- Colour-blind-friendly player colours (blue, orange, green, pink); every ping also has a shape.
local PLAYER_COLORS = {
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(90, 210, 120),
	Color3.fromRGB(240, 110, 200),
}

local spotTimes: { [Player]: { number } } = {}
local quickUntil: { [Player]: number } = {}
local nextPingId = 0

function PingService:ColorOf(player: Player): Color3
	local index = player:GetAttribute("CrewColor")
	if typeof(index) ~= "number" then
		return PLAYER_COLORS[1]
	end
	return PLAYER_COLORS[index]
end

local function assignColors()
	local used: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local index = player:GetAttribute("CrewColor")
		if typeof(index) == "number" then
			used[index] = true
		end
	end
	for _, player in Players:GetPlayers() do
		if typeof(player:GetAttribute("CrewColor")) ~= "number" then
			for index = 1, #PLAYER_COLORS do
				if not used[index] then
					used[index] = true
					player:SetAttribute("CrewColor", index)
					break
				end
			end
		end
	end
end

local function spottableRoot(inst: Instance): Instance?
	local current: Instance? = inst
	while current and current ~= workspace do
		if CollectionService:HasTag(current, Tags.Spottable) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function rateLimited(player: Player): boolean
	local now = os.clock()
	local list = spotTimes[player] or {}
	for index = #list, 1, -1 do
		if now - list[index] > Config.Ping.SpotWindowSeconds then
			table.remove(list, index)
		end
	end
	if #list >= Config.Ping.SpotMaxPerWindow then
		spotTimes[player] = list
		return true
	end
	table.insert(list, now)
	spotTimes[player] = list
	return false
end

-- Places a SPOT ping. auto = automatic, by drone/camera (does not count towards the limit).
function PingService:Spot(player: Player, target: Instance?, position: Vector3?, auto: boolean?)
	if not auto and rateLimited(player) then
		return
	end
	local kind = "go"
	local root: Instance? = nil
	if target and target:IsDescendantOf(workspace) then
		root = spottableRoot(target)
		if root then
			local spotKind = root:GetAttribute(Tags.SpotKind)
			kind = if typeof(spotKind) == "string" then spotKind else "go"
		end
	end
	if root == nil and position == nil then
		return
	end
	if position and typeof(position) ~= "Vector3" then
		return
	end
	local tracked = kind == "guard"
	local duration = if tracked then Config.Ping.SpotDurationTracked else Config.Ping.SpotDurationDefault
	if kind == "lock" or kind == "loot" then
		duration = 10
	end
	nextPingId += 1
	Net.broadcast("Ping", {
		id = nextPingId,
		kind = kind,
		target = root,
		position = position,
		from = player.DisplayName,
		color = self:ColorOf(player),
		duration = duration,
		auto = auto == true,
	})
end

function PingService:Start()
	Net.onRequest("Spot", function(player: Player, target: any, position: any)
		local inst = if typeof(target) == "Instance" then target else nil
		local pos = if typeof(position) == "Vector3" then position else nil
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if pos and root and (pos - root.Position).Magnitude > Config.Ping.MaxRange then
			return
		end
		PingService:Spot(player, inst, pos, false)
	end)

	-- Automatic marking by the drone: the server checks for itself whether the drone really sees the target.
	Net.onRequest("DroneSpot", function(player: Player, target: any)
		if typeof(target) ~= "Instance" then
			return
		end
		local drone: BasePart? = nil
		for _, inst in CollectionService:GetTagged(Tags.Drone) do
			if inst:IsA("BasePart") and inst:GetAttribute(Tags.Owner) == player.UserId then
				drone = inst
			end
		end
		if not drone or drone:GetAttribute(Tags.Disabled) == true then
			return
		end
		local root = spottableRoot(target)
		if not root then
			return
		end
		local targetPosition = if root:IsA("Model")
			then root:GetPivot().Position
			elseif root:IsA("BasePart") then root.Position
			else nil
		if not targetPosition or (targetPosition - drone.Position).Magnitude > 70 then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { drone }
		local result = workspace:Raycast(drone.Position, targetPosition - drone.Position, params)
		if result and not result.Instance:IsDescendantOf(root) then
			return
		end
		PingService:Spot(player, root, nil, true)
	end)

	Net.onRequest("Quick", function(player: Player, preset: any)
		if typeof(preset) ~= "string" or not table.find(Config.Ping.QuickPresets, preset) then
			return
		end
		local now = os.clock()
		if (quickUntil[player] or 0) > now then
			return
		end
		quickUntil[player] = now + Config.Ping.QuickCooldown
		Net.broadcast("Quick", player.DisplayName, preset, PingService:ColorOf(player), player.UserId)
	end)

	Players.PlayerAdded:Connect(assignColors)
	Players.PlayerRemoving:Connect(function(player)
		spotTimes[player] = nil
		quickUntil[player] = nil
	end)
	assignColors()
end

return PingService
