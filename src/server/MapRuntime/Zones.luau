--!strict
-- Zone volumes (contracts §3): parts (or models/folders of parts) the map tags; the runtime reads them once at setup.
--   ColdZone    melting loot (loot type `Melts`, or a loot model attribute Melts = true) loses
--               Config.MapRuntime.Melt.RatePerSecond × base value per second outside every ColdZone once it has
--               left its display, never below MinFactor × base (Logic/Melt; LootService:ApplyDamage "melting").
--               The loot model gets `Melting` = true while it melts (clients: drips, a falling value).
--   GooZone     wading: character attribute `InGoo` (MovementService caps walk/jump at Config.Movement.Goo/GooJump),
--               a "splosh" noise on entering and every SploshEvery s while moving.
--   StaffZone   entering puts the mask on (`Masked` = true, Mask Up) during a heist.
--   SecureZone  innermost ring. Every crew character carries `Ring` ("Public" | "Staff" | "Secure") and `Area`
--               (the zone's Zone attribute, else its name); the first entry per ring is a round stat
--               (EnteredStaff / EnteredSecure).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Melt = require(ReplicatedStorage.Shared.Logic.Melt)

local Util = require(script.Parent.Util)
local LootService = require(script.Parent.Parent.Services.LootService)

local Zones = {}

local M = Config.MapRuntime.Melt
local G = Config.MapRuntime.Goo

type Zone = { inst: Instance, volume: Util.Volume, name: string }

type PlayerState = {
	character: Model,
	inGoo: boolean,
	nextSplosh: number,
	ring: string,
	entered: { [string]: boolean },
}

local ctx: Util.Context? = nil
local cold: { Zone } = {}
local goo: { Zone } = {}
local staff: { Zone } = {}
local secure: { Zone } = {}
local states: { [Player]: PlayerState } = {}
local pending: { [string]: number } = {}
local melting: { [string]: boolean } = {}
local meltTimer = 0

local function read(tag: string, root: Instance): { Zone }
	local list: { Zone } = {}
	for _, inst in Util.tagged(tag, root) do
		local volume = Util.volume(inst)
		if #volume.boxes > 0 then
			table.insert(
				list,
				{ inst = inst, volume = volume, name = Util.str(inst, Tags.Zone) or inst.Name }
			)
		end
	end
	return list
end

local function find(list: { Zone }, position: Vector3): Zone?
	for _, zone in list do
		if Util.inVolume(zone.volume, position) then
			return zone
		end
	end
	return nil
end

local function inRound(): boolean
	local c = ctx
	return c ~= nil and (c.phase == "Heist" or c.phase == "Lockdown")
end

-- Is this position inside a ColdZone?
function Zones.inCold(position: Vector3): boolean
	return find(cold, position) ~= nil
end

--------------------------------------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------------------------------------

local function stateOf(view: Util.View): PlayerState
	local old = states[view.player]
	if old and old.character == view.character then
		return old
	end
	local state: PlayerState = {
		character = view.character,
		inGoo = false,
		nextSplosh = 0,
		ring = "",
		entered = if old then old.entered else {},
	}
	states[view.player] = state
	return state
end

local function stepPlayers(now: number)
	local round = inRound()
	for _, view in Util.crewViews() do
		local state = stateOf(view)
		local character = view.character
		local position = view.root.Position
		local feet = position - Vector3.new(0, 2.5, 0)

		-- Goo
		local wading = round
			and #goo > 0
			and Util.isFree(character)
			and (find(goo, position) ~= nil or find(goo, feet) ~= nil)
		if wading ~= state.inGoo then
			state.inGoo = wading
			character:SetAttribute(Tags.InGoo, if wading then true else nil)
			Util.refresh(view.player)
			if wading then
				state.nextSplosh = now + G.SploshEvery
				Util.hearNoise(position, G.SploshRadius, G.SploshSearch, "splosh", view.player)
			end
		elseif wading and now >= state.nextSplosh then
			local v = view.root.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > 1 then
				state.nextSplosh = now + G.SploshEvery
				Util.hearNoise(position, G.SploshRadius, G.SploshSearch, "splosh", view.player)
			end
		end

		-- Rings
		local zone = find(secure, position)
		local ring = "Secure"
		if not zone then
			zone = find(staff, position)
			ring = if zone then "Staff" else "Public"
		end
		if ring ~= state.ring then
			state.ring = ring
			Util.set(character, Tags.Ring, ring)
		end
		Util.set(character, Tags.Area, if zone then zone.name else nil)
		if round and ring ~= "Public" then
			if Config.Features.MaskUp and character:GetAttribute(Tags.Masked) ~= true then
				character:SetAttribute(Tags.Masked, true)
			end
			if not state.entered[ring] then
				state.entered[ring] = true
				Util.event(`Entered{ring}`, view.player)
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------
-- Melting
--------------------------------------------------------------------------------------------------------------

local function lootPosition(loot: LootService.Loot): Vector3?
	local handle = loot.handle
	if handle and handle.Parent then
		return handle.Position
	end
	if loot.carrierId then
		local player = Players:GetPlayerByUserId(loot.carrierId)
		local view = player and Util.view(player)
		return if view then view.root.Position else nil
	end
	return nil
end

local function stepMelting(dt: number)
	local round = inRound()
	for id, loot in LootService:All() do
		local def = Config.Loot.Types[loot.type]
		local model = loot.model
		local melts = (def ~= nil and def.Melts == true)
			or (model ~= nil and model:GetAttribute("Melts") == true)
		if not melts or loot.session ~= "Crew" then
			continue
		end
		local position = lootPosition(loot)
		local handle = loot.handle
		local moved = loot.state ~= "Placed"
			or (handle ~= nil and (handle.Position - loot.home.Position).Magnitude > 2) == true
		local isMelting = round
			and position ~= nil
			and Melt.melting({
				melts = true,
				state = loot.state,
				inCold = Zones.inCold(position :: Vector3),
				moved = moved,
			})
		if isMelting ~= (melting[id] == true) then
			if isMelting then
				melting[id] = true
			else
				melting[id] = nil
			end
			if model then
				model:SetAttribute(Tags.Melting, if isMelting then true else nil)
			end
		end
		if isMelting then
			local loss, rest =
				Melt.step(pending[id] or 0, loot.value, loot.baseValue, dt, M.RatePerSecond, M.MinFactor)
			pending[id] = rest
			if loss > 0 and loot.baseValue > 0 then
				LootService:ApplyDamage(loot.id, loss / loot.baseValue, "melting")
			end
		end
	end
	for id in table.clone(pending) do
		if LootService:Get(id) == nil then
			pending[id] = nil
			melting[id] = nil
		end
	end
end

--------------------------------------------------------------------------------------------------------------

function Zones.setup(c: Util.Context)
	Zones.clear()
	ctx = c
	cold = read(Tags.ColdZone, c.level)
	goo = read(Tags.GooZone, c.level)
	staff = read(Tags.StaffZone, c.level)
	secure = read(Tags.SecureZone, c.level)
end

function Zones.phase(c: Util.Context)
	ctx = c
end

function Zones.step(now: number, dt: number)
	if not ctx then
		return
	end
	stepPlayers(now)
	meltTimer += dt
	if meltTimer >= M.Interval then
		local elapsed = meltTimer
		meltTimer = 0
		stepMelting(elapsed)
	end
end

-- The ring ("Public" | "Staff" | "Secure") this player is in, or nil without a character.
function Zones.ringOf(player: Player): string?
	local state = states[player]
	return if state and state.character == player.Character then state.ring else nil
end

function Zones.clear()
	for player, state in states do
		local character = state.character
		if character.Parent then
			if state.inGoo then
				character:SetAttribute(Tags.InGoo, nil)
				Util.refresh(player)
			end
			character:SetAttribute(Tags.Ring, nil)
			character:SetAttribute(Tags.Area, nil)
		end
	end
	table.clear(states)
	for id in melting do
		local loot = LootService:Get(id)
		if loot and loot.model then
			loot.model:SetAttribute(Tags.Melting, nil)
		end
	end
	table.clear(melting)
	table.clear(pending)
	cold, goo, staff, secure = {}, {}, {}, {}
	meltTimer = 0
	ctx = nil
end

return Zones
