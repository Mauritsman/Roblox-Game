--!strict
-- Gadget loadouts (beta-spec §5). Everyone carries the Crowbar plus the 2 gadgets they picked at meta's Garage
-- rack (ShopService:GetLoadout through Lib/Meta; meta's default when nothing is picked). Duplicates across a crew
-- are allowed. Charges belong to the player and reset every round.
--
-- Entry points (integration.md):
--   ResetRound(players, job)   Briefing and JUMP IN — ONLY the players passed in: picks, charges (perks), stats
--   StatsOf(player)            per-player numbers after difficulty and perks (Lib/PlayerStats)
--   Has(player, gadget) · UseCharge(player, gadget) · Charges(player, gadget) · Picks(player)
--   DevTake(player, gadget)    Studio: add a gadget with full charges (tests)
-- Panic Pack: at LOCKDOWN every crew member gets +1 charge on each picked gadget (Config.Features.LoudExtras).
-- Player attributes: `Gadgets` ("a,b,Crowbar"; empty outside a crew round), `Charges_<Gadget>` (-1 = unlimited).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Loadout = require(ReplicatedStorage.Shared.Logic.Loadout)

local Server = script.Parent.Parent
local Meta = require(Server.Lib.Meta)
local Optional = require(Server.Lib.Optional)
local PlayerStats = require(Server.Lib.PlayerStats)

local LoadoutService = {}

local CROWBAR = "Crowbar"

type Kit = {
	picks: { string },
	charges: { [string]: number },
	panic: boolean, -- Panic Pack already given this round
}

local kits: { [Player]: Kit } = {}

local function isPlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player") and value.Parent ~= nil
end

local function publish(player: Player)
	local kit = kits[player]
	player:SetAttribute(Tags.Gadgets, if kit then Loadout.list(kit.picks, CROWBAR) else "")
	player:SetAttribute(Tags.Slots, nil) -- DEPRECATED attribute (contracts §2.2)
	for _, name in Config.GadgetOrder do
		local value: number? = nil
		if kit and name == CROWBAR then
			value = -1
		elseif kit then
			value = kit.charges[name]
		end
		player:SetAttribute(Tags.Charges .. name, value)
	end
end

local function phase(): string?
	local value = ReplicatedStorage:GetAttribute(Tags.RoundPhase)
	return if type(value) == "string" then value else nil
end

local function givePanicPack(player: Player, announce: boolean)
	local kit = kits[player]
	if not kit or kit.panic or not Config.Features.LoudExtras then
		return
	end
	kit.panic = true
	kit.charges = Loadout.panic(kit.charges, kit.picks, Config.Objectives.PanicPackCharges)
	publish(player)
	if announce and #kit.picks > 0 then
		Net.send(player, "Toast", `PANIC PACK! +{Config.Objectives.PanicPackCharges} on each gadget`)
	end
end

-- Fresh picks, charges and stats for exactly these players (Briefing: the crew; JUMP IN: the newcomer).
-- Returns true so RoundService knows the beta loadout handled it.
function LoadoutService:ResetRound(players: { Player }, job: any?): boolean
	if type(players) ~= "table" then
		return false
	end
	local difficulty = if type(job) == "table" and type(job.difficulty) == "string"
		then job.difficulty
		else nil
	for _, player in players do
		if isPlayer(player) then
			local stats = PlayerStats.Refresh(player, difficulty)
			local raw = Meta.GetLoadout(player)
			local picks =
				Loadout.picks(raw, Config.Loadout.Pickable, Config.Loadout.Slots, Config.Loadout.Default)
			kits[player] = {
				picks = picks,
				charges = Loadout.charges(picks, Config.Gadgets :: any, stats :: any),
				panic = false,
			}
			publish(player)
			-- Joined during LOCKDOWN: the Panic Pack too.
			if phase() == "Lockdown" then
				givePanicPack(player, false)
			end
			Optional.call("MovementService", "Refresh", player)
		end
	end
	return true
end

function LoadoutService:StatsOf(player: Player): PlayerStats.Stats
	return PlayerStats.StatsOf(player)
end

-- Everyone has the Crowbar; the other gadgets only when picked for this round.
function LoadoutService:Has(player: Player, gadgetName: string): boolean
	if gadgetName == CROWBAR then
		return true
	end
	local kit = kits[player]
	return kit ~= nil and table.find(kit.picks, gadgetName) ~= nil
end

function LoadoutService:Picks(player: Player): { string }
	local kit = kits[player]
	return if kit then table.clone(kit.picks) else {}
end

function LoadoutService:Charges(player: Player, gadgetName: string): number
	if gadgetName == CROWBAR then
		return math.huge
	end
	local kit = kits[player]
	return if kit then kit.charges[gadgetName] or 0 else 0
end

-- Uses up one charge. Returns false when the player has none left (or does not carry the gadget).
function LoadoutService:UseCharge(player: Player, gadgetName: string): boolean
	if gadgetName == CROWBAR then
		return true
	end
	local kit = kits[player]
	if not kit or not table.find(kit.picks, gadgetName) then
		return false
	end
	local left = kit.charges[gadgetName] or 0
	if left <= 0 then
		return false
	end
	kit.charges[gadgetName] = left - 1
	publish(player)
	return true
end

-- Studio tests: carry this gadget (added to the picks) with full charges.
function LoadoutService:DevTake(player: Player, gadgetName: string): boolean
	if not RunService:IsStudio() or not table.find(Config.Loadout.Pickable, gadgetName) then
		return false
	end
	local kit = kits[player]
	if not kit then
		kit = { picks = {}, charges = {}, panic = false }
		kits[player] = kit
	end
	if not table.find(kit.picks, gadgetName) then
		table.insert(kit.picks, gadgetName)
	end
	local def = (Config.Gadgets :: any)[gadgetName]
	kit.charges[gadgetName] = if def then def.Charges else 1
	publish(player)
	Net.send(player, "Toast", `DEV: took the {Loadout.label(gadgetName, Config.Gadgets :: any)}`)
	return true
end

-- Leaving a crew round (Garage, mini-job): no gadgets outside a heist.
local function onActivity(player: Player)
	if player:GetAttribute(Tags.Activity) ~= "Crew" and kits[player] then
		kits[player] = nil
		publish(player)
	end
end

function LoadoutService:Start()
	local function onPlayer(player: Player)
		player:GetAttributeChangedSignal(Tags.Activity):Connect(function()
			onActivity(player)
		end)
		publish(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		kits[player] = nil
	end)

	-- Panic Pack at the start of the loud phase.
	local round = Optional.get("RoundService")
	if round and type(round.PhaseChanged) == "table" then
		round.PhaseChanged:Connect(function(newPhase: string)
			if newPhase == "Lockdown" then
				for player in kits do
					if player.Parent and player:GetAttribute(Tags.Activity) == "Crew" then
						givePanicPack(player, true)
					end
				end
			end
		end)
	end
end

return LoadoutService
