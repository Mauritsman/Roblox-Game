--!strict
-- Wie draagt welk gadget (§3.7). Er is één exemplaar van elk gadget; je neemt het aan het rek bij het busje.
-- Het aantal vakken hangt af van de crewgrootte. Ladingen horen bij het gadget, niet bij de speler.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tags = require(ReplicatedStorage.Shared.Tags)

local LoadoutService = {}

local owners: { [string]: Player? } = {} -- gadget -> speler
local charges: { [string]: number } = {}
local lastTouch: { [Player]: number } = {}

local function gadgetsOf(player: Player): { string }
	local list = {}
	for _, gadgetName in Config.GadgetOrder do
		if owners[gadgetName] == player then
			table.insert(list, gadgetName)
		end
	end
	return list
end

local function publish()
	local slots = Config.slotsFor(#Players:GetPlayers())
	for _, player in Players:GetPlayers() do
		local list = gadgetsOf(player)
		player:SetAttribute(Tags.Gadgets, table.concat(list, ","))
		player:SetAttribute(Tags.Slots, slots)
		for _, gadgetName in Config.GadgetOrder do
			local value = if owners[gadgetName] == player then charges[gadgetName] else nil
			player:SetAttribute(Tags.Charges .. gadgetName, if value == math.huge then -1 else value)
		end
	end
	-- Sokkels tonen of het gadget nog vrij is.
	for _, pedestal in CollectionService:GetTagged(Tags.GadgetPedestal) do
		if pedestal:IsA("BasePart") then
			local gadgetName = pedestal:GetAttribute("Gadget")
			pedestal.Transparency = if typeof(gadgetName) == "string" and owners[gadgetName] then 0.75 else 0
		end
	end
end

function LoadoutService:Has(player: Player, gadgetName: string): boolean
	return owners[gadgetName] == player
end

function LoadoutService:Charges(gadgetName: string): number
	return charges[gadgetName] or 0
end

-- Verbruikt één lading. Geeft false terug als er geen meer zijn.
function LoadoutService:UseCharge(player: Player, gadgetName: string): boolean
	if owners[gadgetName] ~= player then
		return false
	end
	local left = charges[gadgetName] or 0
	if left <= 0 then
		return false
	end
	charges[gadgetName] = left - 1
	publish()
	return true
end

function LoadoutService:ResetRun()
	for _, gadgetName in Config.GadgetOrder do
		owners[gadgetName] = nil
		charges[gadgetName] = Config.Gadgets[gadgetName].Charges
	end
	publish()
end

local function onPedestalTouched(pedestal: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local now = os.clock()
	if lastTouch[player] and now - lastTouch[player] < 1.5 then
		return
	end
	lastTouch[player] = now

	local gadgetName = pedestal:GetAttribute("Gadget")
	if typeof(gadgetName) ~= "string" then
		return
	end

	if owners[gadgetName] == player then
		owners[gadgetName] = nil
		Net.send(player, "Toast", `Returned the {gadgetName:upper()}`)
	elseif owners[gadgetName] ~= nil then
		local owner = owners[gadgetName] :: Player
		Net.send(player, "Toast", `{owner.DisplayName} has the {gadgetName:upper()}`)
		return
	else
		local slots = Config.slotsFor(#Players:GetPlayers())
		if #gadgetsOf(player) >= slots then
			Net.send(player, "Toast", `All {slots} slots full. Return a gadget first.`)
			return
		end
		owners[gadgetName] = player
		Net.send(player, "Toast", `Took the {gadgetName:upper()} ({Config.Gadgets[gadgetName].Step})`)
	end
	publish()
end

local function hookPedestal(pedestal: Instance)
	if pedestal:IsA("BasePart") then
		pedestal.Touched:Connect(function(hit)
			onPedestalTouched(pedestal, hit)
		end)
	end
end

function LoadoutService:Init()
	for _, gadgetName in Config.GadgetOrder do
		charges[gadgetName] = Config.Gadgets[gadgetName].Charges
	end
end

function LoadoutService:Start()
	for _, pedestal in CollectionService:GetTagged(Tags.GadgetPedestal) do
		hookPedestal(pedestal)
	end
	CollectionService:GetInstanceAddedSignal(Tags.GadgetPedestal):Connect(function(pedestal)
		hookPedestal(pedestal)
		task.defer(publish)
	end)
	Players.PlayerAdded:Connect(function()
		publish()
	end)
	Players.PlayerRemoving:Connect(function(player)
		for gadgetName, owner in owners do
			if owner == player then
				owners[gadgetName] = nil
			end
		end
		lastTouch[player] = nil
		task.defer(publish)
	end)
	publish()
end

return LoadoutService
