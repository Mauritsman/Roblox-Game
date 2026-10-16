--!strict
-- Client cache of meta's data (beta-spec-meta §2.6 and §8.2): the profile view (`ProfileSync`), the heist
-- board (`JobBoard`) and the latest `MetaResult`. Screens read from here and listen to Changed
-- ("profile" | "board" | "result"). Everything may be missing: callers must show placeholders.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Profile = {}

Profile.view = nil :: { [string]: any }?
Profile.board = nil :: { [string]: any }?
Profile.result = nil :: { [string]: any }?
Profile.saveStatus = "Ok"
Profile.Changed = Signal.new() :: Signal.Signal<string>

local lastRequest = 0

-- Asks the server for a fresh profile (max once per 2 s).
function Profile.request()
	if os.clock() - lastRequest < 2 then
		return
	end
	lastRequest = os.clock()
	Net.request("ProfileRequest")
end

function Profile.get(key: string): any
	local view = Profile.view
	return if view then view[key] else nil
end

-- Cash / Rank / Rep: player attributes first (always fresh), then the profile view.
function Profile.number(key: string, attribute: string?): number
	local player = Players.LocalPlayer
	local fromAttribute = attribute and player:GetAttribute(attribute)
	if typeof(fromAttribute) == "number" then
		return fromAttribute
	end
	local value = Profile.get(key)
	return if typeof(value) == "number" then value else 0
end

-- Splits a comma list attribute ("Noisemaker,BubbleBlaster").
function Profile.list(value: any): { string }
	local out = {}
	if typeof(value) == "string" then
		for item in string.gmatch(value, "[^,]+") do
			table.insert(out, item)
		end
	elseif typeof(value) == "table" then
		for _, item in value do
			if typeof(item) == "string" then
				table.insert(out, item)
			end
		end
	end
	return out
end

function Profile.loadout(): { string }
	local fromView = Profile.list(Profile.get("loadout"))
	if #fromView > 0 then
		return fromView
	end
	local fromAttribute = Profile.list(Players.LocalPlayer:GetAttribute("Loadout"))
	if #fromAttribute > 0 then
		return fromAttribute
	end
	return { "Noisemaker", "BubbleBlaster" }
end

-- Best stars for a heist and tier.
function Profile.stars(heistId: string, tier: string): number
	local heists = Profile.get("heists")
	local entry = if typeof(heists) == "table" then heists[heistId] else nil
	local stars = if typeof(entry) == "table" then entry.stars else nil
	local value = if typeof(stars) == "table" then stars[tier] else nil
	return if typeof(value) == "number" then value else 0
end

local started = false
function Profile.init()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(view: any)
		if typeof(view) == "table" then
			Profile.view = view
			Profile.Changed:Fire("profile")
		end
	end)
	Net.on("JobBoard", function(board: any)
		if typeof(board) == "table" then
			Profile.board = board
			Profile.Changed:Fire("board")
		end
	end)
	Net.on("MetaResult", function(action: any, ok: any, id: any, reason: any)
		Profile.result = { action = action, ok = ok == true, id = id, reason = reason }
		Profile.Changed:Fire("result")
	end)
	Net.on("SaveStatus", function(status: any)
		if typeof(status) == "string" then
			Profile.saveStatus = status
			Profile.Changed:Fire("save")
		end
	end)
	task.delay(1, Profile.request)
end

return Profile
