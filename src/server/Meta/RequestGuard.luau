--!strict
-- Shared guard for every meta request (owner: meta): per-player token-bucket rate limits, type checks for
-- client values, and the "not during a round" rule. Clients only ever send ids, tiers and indices.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local MetaTags = require(ReplicatedStorage.Shared.MetaTags)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Logic.RateLimit)

local RequestGuard = {}

export type Limit = { burst: number?, perSecond: number? }

local buckets: { [Player]: { [string]: RateLimit.Bucket } } = {}

function RequestGuard.allow(player: Player, name: string, limit: Limit?): boolean
	local burst = (limit and limit.burst) or MetaConfig.RateLimit.Burst
	local perSecond = (limit and limit.perSecond) or MetaConfig.RateLimit.PerSecond
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local bucket = mine[name]
	if not bucket then
		bucket = RateLimit.new(burst, now)
		mine[name] = bucket
	end
	return RateLimit.take(bucket, now, burst, perSecond)
end

-- Net.onRequest with a rate limit in front of it.
function RequestGuard.on(name: string, handler: (player: Player, ...any) -> (), limit: Limit?)
	Net.onRequest(name, function(player: Player, ...: any)
		if RequestGuard.allow(player, name, limit) then
			handler(player, ...)
		end
	end)
end

-- A short id from the client: string, 1–40 characters, letters, digits and _ only.
function RequestGuard.id(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	if #value == 0 or #value > MetaConfig.RateLimit.MaxStringLength then
		return nil
	end
	if string.find(value, "[^%w_]") then
		return nil
	end
	return value
end

-- A whole number in [min, max].
function RequestGuard.int(value: any, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value or value ~= math.floor(value) then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return value
end

-- True while the player is on a job or in the mini-job (mechanics sets InRound / Activity).
function RequestGuard.inRound(player: Player): boolean
	if player:GetAttribute(MetaTags.InRound) == true then
		return true
	end
	local activity = player:GetAttribute(MetaTags.Activity)
	return activity == "Crew" or activity == "Tutorial"
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RequestGuard
