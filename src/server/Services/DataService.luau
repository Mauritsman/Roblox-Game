--!strict
-- M0 STUB (meta): player data kept in memory only. The real DataStore layer replaces this file.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local Signal = require(ReplicatedStorage.Shared.Signal)

export type PlayerData = DataSchema.PlayerData

local DataService = {}
DataService.Loaded = Signal.new() :: Signal.Signal<Player, PlayerData>
DataService.Changed = Signal.new() :: Signal.Signal<Player, string>

local profiles: { [Player]: PlayerData } = {}
local hooks: { () -> () } = {}

function DataService:WaitForData(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService:Get(player: Player): PlayerData?
	return profiles[player]
end

function DataService:Update(player: Player, reason: string, fn: (PlayerData) -> ()): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	local ok = pcall(fn, data)
	if ok then
		DataService.Changed:Fire(player, reason)
	end
	return ok
end

function DataService:SaveNowAsync(_player: Player, _reason: string): boolean
	return true
end

function DataService:ReleaseAsync(_player: Player): boolean
	return true
end

function DataService:OnBeforeShutdown(fn: () -> ())
	table.insert(hooks, fn)
end

function DataService:Start()
	local function added(player: Player)
		local starter = { equipped = Catalog.DefaultEquipped, loadout = Catalog.DefaultLoadout }
		profiles[player] = DataSchema.defaults(os.time(), starter)
		DataService.Loaded:Fire(player, profiles[player])
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for _, fn in hooks do
			pcall(fn)
		end
	end)
end

return DataService
