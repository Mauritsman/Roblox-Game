--!strict
-- Player settings on the client: a local cache with a Changed signal.
-- Values arrive from meta (`Settings` message or `ProfileSync.settings`); changes are sent back with
-- `SaveSettings(table)`, debounced 2 s. Keys (meta's Config.Data.SettingsKeys):
--   MusicVolume (0–1), SfxVolume (0–1), ReduceMotion (boolean), Hints (boolean), MutedPings (comma list of UserIds)

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Settings = {}

Settings.Keys = { "MusicVolume", "SfxVolume", "ReduceMotion", "Hints", "MutedPings" }

local values: { [string]: any } = {
	MusicVolume = 0.6,
	SfxVolume = 0.8,
	ReduceMotion = GuiService.ReducedMotionEnabled,
	Hints = true,
	MutedPings = "",
}
local userTouched: { [string]: boolean } = {}

Settings.Changed = Signal.new() :: Signal.Signal<string>

local SAVE_DELAY = 2
local saveToken = 0

local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(SAVE_DELAY, function()
		if token ~= saveToken then
			return
		end
		local out = {}
		for _, key in Settings.Keys do
			out[key] = values[key]
		end
		Net.request("SaveSettings", out)
	end)
end

function Settings.get(key: string): any
	return values[key]
end

function Settings.number(key: string, default: number): number
	local value = values[key]
	return if typeof(value) == "number" then value else default
end

function Settings.set(key: string, value: any)
	if values[key] == value then
		return
	end
	values[key] = value
	userTouched[key] = true
	Settings.Changed:Fire(key)
	scheduleSave()
end

function Settings.reduceMotion(): boolean
	return values.ReduceMotion == true
end

function Settings.hints(): boolean
	return values.Hints ~= false
end

function Settings.isMuted(userId: number): boolean
	local list = values.MutedPings
	if typeof(list) ~= "string" or list == "" then
		return false
	end
	for id in string.gmatch(list, "[^,]+") do
		if tonumber(id) == userId then
			return true
		end
	end
	return false
end

function Settings.setMuted(userId: number, muted: boolean)
	local ids = {}
	local list = values.MutedPings
	if typeof(list) == "string" then
		for id in string.gmatch(list, "[^,]+") do
			local n = tonumber(id)
			if n and n ~= userId then
				table.insert(ids, tostring(n))
			end
		end
	end
	if muted then
		table.insert(ids, tostring(userId))
	end
	Settings.set("MutedPings", table.concat(ids, ","))
end

-- Values from the server. Keys the player changed this session are not overwritten.
function Settings.apply(incoming: any)
	if typeof(incoming) ~= "table" then
		return
	end
	for _, key in Settings.Keys do
		local value = incoming[key]
		if value ~= nil and not userTouched[key] and values[key] ~= value then
			local expected = typeof(values[key])
			if typeof(value) == expected then
				values[key] = value
				Settings.Changed:Fire(key)
			end
		end
	end
end

local started = false
function Settings.init()
	if started then
		return
	end
	started = true
	Net.on("Settings", function(incoming: any)
		Settings.apply(incoming)
	end)
	Net.on("ProfileSync", function(view: any)
		if typeof(view) == "table" then
			Settings.apply(view.settings)
		end
	end)
end

return Settings
