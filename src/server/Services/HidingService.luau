--!strict
-- Hiding spots (beta-spec §4.1, advisor §13): barrels, crates, lockers tagged `HideSpot` (Model, `HideKind`,
-- PrimaryPart Attachments `Inside` and `Exit`).
--   * "Hide" prompt (0.5 s), one player per spot, empty hands or pocket loot only.
--   * Inside: invisible, parked at `Inside`, `Hidden = true`, `HideEndsAt` = when you sneeze. Guards, cameras and
--     snitches ignore you.
--   * `HideExit` (≥ 0.5 s inside) puts you at `Exit`. Shake at 15 s (client), ACHOO at 20 s (perk Barrel Lungs:
--     warn 20 / sneeze 25): `Sneeze` + noise radius 15, you tumble out. 5 s before you can hide again.
--   * A guard who saw you get in (meter ≥ 0.35 or chasing you) walks over and pulls you out = a normal grab.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hiding = require(ReplicatedStorage.Shared.Logic.Hiding)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local CaptureService = require(script.Parent.CaptureService)
local GuardService = require(script.Parent.GuardService)

local Npc = script.Parent.Parent:WaitForChild("Npc")
local Peers = require(Npc.Peers)
local Targets = require(Npc.Targets)

local HidingService = {}

type Spot = {
	model: Model,
	primary: BasePart,
	prompt: ProximityPrompt,
	occupant: Player?,
}

type Hider = {
	player: Player,
	spot: Spot,
	enteredAt: number,
	warnAt: number,
	sneezeAt: number,
	saved: { [Instance]: number },
}

local H = Config.Hiding

local spots: { [Model]: Spot } = {}
local hiders: { [Player]: Hider } = {}
local lockout: { [Player]: number } = {}

local function attachment(spot: Spot, name: string): Attachment?
	local found = spot.primary:FindFirstChild(name) or spot.model:FindFirstChild(name, true)
	return if found and found:IsA("Attachment") then found else nil
end

-- Where a player stands after leaving: on the floor at the Exit attachment (or in front of the spot).
local function exitCFrame(spot: Spot, character: Model?): CFrame
	local exit = attachment(spot, "Exit")
	local base = if exit
		then exit.WorldPosition
		else (spot.primary.CFrame * CFrame.new(0, 0, -(spot.primary.Size.Z / 2 + 2.5))).Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { spot.model }
	if character then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(base + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
	local position = if hit then hit.Position + Vector3.new(0, 3, 0) else base + Vector3.new(0, 3, 0)
	local away = Vector3.new(position.X - spot.primary.Position.X, 0, position.Z - spot.primary.Position.Z)
	if away.Magnitude < 0.1 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + away)
end

local function setVisible(character: Model, hider: Hider, visible: boolean)
	if visible then
		for inst, transparency in hider.saved do
			if inst.Parent then
				(inst :: any).Transparency = transparency
			end
		end
		table.clear(hider.saved)
		return
	end
	for _, inst in character:GetDescendants() do
		if inst:IsA("BasePart") or inst:IsA("Decal") then
			hider.saved[inst] = (inst :: any).Transparency;
			(inst :: any).Transparency = 1
		end
	end
end

local function setRootAnchored(character: Model, anchored: boolean, owner: Player?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = anchored
		if not anchored and owner and owner.Parent then
			pcall(function()
				root:SetNetworkOwner(owner)
			end)
		end
	end
end

-- Takes a player out of their spot. reason: "exit" | "sneeze" | "pulled" | "capture" | "reset" | "leave" | "death"
local function unhide(player: Player, reason: string)
	local hider = hiders[player]
	if not hider then
		return
	end
	hiders[player] = nil
	local spot = hider.spot
	if spot.occupant == player then
		spot.occupant = nil
	end
	if spot.model.Parent then
		spot.prompt.Enabled = true
	end
	lockout[player] = Targets.now() + H.Reentry
	local character = player.Character
	if not character then
		return
	end
	setVisible(character, hider, true)
	character:SetAttribute(Tags.Hidden, nil)
	character:SetAttribute(Tags.HideEndsAt, nil)
	if reason ~= "leave" and reason ~= "death" then
		setRootAnchored(character, false, player)
		if reason ~= "reset" and spot.model.Parent then
			character:PivotTo(exitCFrame(spot, character))
		end
	end
	Peers.refreshMovement(player)
end

local function pullOut(player: Player, guardModel: Model)
	if not hiders[player] then
		return
	end
	unhide(player, "pulled")
	CaptureService:Grab(player, guardModel)
end

local function hide(player: Player, spot: Spot)
	local view = Targets.view(player)
	if not view then
		return
	end
	local character = view.character
	local now = Targets.now()
	local carryClass = character:GetAttribute(Tags.CarryClass)
	local called, handsFull = Peers.call("CarryService", "HandsFull", player)
	local ok, reason = Hiding.canHide({
		activity = Targets.activity(player),
		caught = character:GetAttribute(Tags.Caught) == true,
		hidden = hiders[player] ~= nil or character:GetAttribute(Tags.Hidden) == true,
		carryClass = if called and handsFull == true
			then "Medium"
			elseif typeof(carryClass) == "string" then carryClass
			else nil,
		operating = character:GetAttribute(Tags.Operating) == true,
		lockoutUntil = lockout[player],
		occupied = spot.occupant ~= nil,
	}, now)
	if not ok then
		Net.send(player, "Toast", Hiding.REFUSALS[reason or ""] or "Not now")
		return
	end
	if (view.root.Position - spot.primary.Position).Magnitude > H.PromptRange + 4 then
		return
	end

	-- Who saw this? Asked before hiding (once hidden, guards stop seeing you).
	local witnesses = GuardService:WitnessesOf(player)
	local noticed = GuardService:MeterOn(player) > 0

	local stats = Peers.stats(player)
	local hider: Hider = {
		player = player,
		spot = spot,
		enteredAt = now,
		warnAt = stats.WarnAt,
		sneezeAt = stats.SneezeAt,
		saved = {},
	}
	hiders[player] = hider
	spot.occupant = player
	spot.prompt.Enabled = false
	character:SetAttribute(Tags.Crouching, false)
	character:SetAttribute(Tags.Hidden, true)
	character:SetAttribute(Tags.HideEndsAt, now + hider.sneezeAt)
	setVisible(character, hider, false)
	local inside = attachment(spot, "Inside")
	local parkAt = if inside then inside.WorldCFrame else spot.primary.CFrame
	setRootAnchored(character, true, nil)
	character:PivotTo(CFrame.new(parkAt.Position) * parkAt.Rotation)
	Peers.refreshMovement(player)

	if #witnesses > 0 then
		-- The nearest witness walks over to pull you out.
		local best: Model? = nil
		local bestDistance = math.huge
		for _, guard in witnesses do
			local distance = (guard:GetPivot().Position - spot.primary.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = guard, distance
			end
		end
		if best then
			local guardModel = best
			GuardService:PullOut(guardModel, player, spot.primary.Position, function()
				pullOut(player, guardModel)
			end)
		end
	elseif noticed then
		Peers.event("HidFromChase", player)
	end
end

local function sneeze(player: Player, hider: Hider)
	local position = hider.spot.primary.Position
	Net.broadcast("Sneeze", player.UserId, position)
	Peers.event("Sneeze", player)
	unhide(player, "sneeze")
	GuardService:HearNoise(position, H.SneezeRadius, nil, "sneeze", player)
end

local function setupSpot(inst: Instance)
	if not inst:IsA("Model") or spots[inst] then
		return
	end
	local primary = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	if not primary or not primary:IsA("BasePart") then
		return
	end
	local kind = inst:GetAttribute(Tags.HideKind)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.ActionText = "Hide"
	prompt.ObjectText = if typeof(kind) == "string" then kind else "Barrel"
	prompt.HoldDuration = H.Enter
	prompt.MaxActivationDistance = H.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("ContextIcon", "Hide")
	prompt.Parent = primary
	local spot: Spot = { model = inst, primary = primary, prompt = prompt, occupant = nil }
	spots[inst] = spot
	prompt.Triggered:Connect(function(player)
		hide(player, spot)
	end)
end

local function removeSpot(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local spot = spots[inst]
	if not spot then
		return
	end
	spots[inst] = nil
	if spot.occupant then
		unhide(spot.occupant, "reset")
	end
end

--------------------------------------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------------------------------------

function HidingService:IsHidden(player: Player): boolean
	return hiders[player] ~= nil
end

-- Hidden players and the position of their spot (Boef barks at smelly ones).
function HidingService:HiddenPlayers(): { [Player]: Vector3 }
	local list = {}
	for player, hider in hiders do
		list[player] = hider.spot.primary.Position
	end
	return list
end

-- Takes a player out (other services: capture, teleports).
function HidingService:ForceExit(player: Player)
	unhide(player, "exit")
end

-- Everyone out, lockouts cleared (round start/end).
function HidingService:Reset()
	for player in hiders do
		unhide(player, "reset")
	end
	table.clear(lockout)
end

function HidingService:Spawn(_plan: any, _heistInfo: any, _job: any)
	for _, inst in CollectionService:GetTagged(Tags.HideSpot) do
		setupSpot(inst)
	end
end

function HidingService:Clear()
	HidingService:Reset()
end

function HidingService:Start()
	CaptureService:SetUnhideHook(function(player)
		unhide(player, "capture")
	end)
	for _, inst in CollectionService:GetTagged(Tags.HideSpot) do
		setupSpot(inst)
	end
	CollectionService:GetInstanceAddedSignal(Tags.HideSpot):Connect(setupSpot)
	CollectionService:GetInstanceRemovedSignal(Tags.HideSpot):Connect(removeSpot)

	Net.onRequest("HideExit", function(player: Player)
		local hider = hiders[player]
		if hider and Hiding.canExit(hider.enteredAt, Targets.now(), H.Exit) then
			unhide(player, "exit")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = Targets.now()
			for player, hider in hiders do
				if Hiding.phase(hider.enteredAt, now, hider.warnAt, hider.sneezeAt) == "Sneeze" then
					sneeze(player, hider)
				end
			end
		end
	end)

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				if hiders[player] and player.Character == character then
					unhide(player, "death")
				end
			end)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			if hiders[player] then
				unhide(player, "death")
			end
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		unhide(player, "leave")
		lockout[player] = nil
	end)
end

return HidingService
