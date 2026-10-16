--!strict
-- M0 STUB (meta): prints analytics calls. Not called AnalyticsService so it can't be mixed up with Roblox's.

local AnalyticsTracker = {}

function AnalyticsTracker:OnboardingStep(player: Player, name: string)
	print(`[Analytics] (stub) onboarding {player.Name} {name}`)
end

function AnalyticsTracker:RoundStep(player: Player, roundId: string, name: string)
	print(`[Analytics] (stub) round {player.Name} {roundId} {name}`)
end

function AnalyticsTracker:Custom(player: Player?, name: string, value: number?, _fields: { string }?)
	print(`[Analytics] (stub) {name} {if player then player.Name else "-"} {value or 1}`)
end

return AnalyticsTracker
