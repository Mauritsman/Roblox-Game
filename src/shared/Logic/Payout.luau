--!strict
-- Round payout per crew member (docs/beta-spec-meta.md §3.4, advisor decisions). Pure.
--   1. cut = V / n × (1 + 0.15 × (n − 1)); Busted: V × 0.5.
--   2. Escaped but this player not in the van at the end → × 0.5 (the lost half goes to nobody).
--   3. × difficulty multiplier.
--   4. Not Busted → × (1 + bonuses): Quiet Job, No One Left Behind (crews of 2+), Hot Job, Fresh, objectives.
--   5. First ESCAPED job of the UTC day and this player escaped → Cash × 2.
--   6. Round half up once per amount; Rep = Cash before ×2 + 100 × tier; clamp Cash.
--   7. Aborted → nothing. Shutdown → step 1 only + 100 Rep (no bonuses, stars, ×2 or contracts).

local Payout = {}

export type Config = {
	CrewBonusPerExtra: number,
	BustedFactor: number,
	CaughtAtEndFactor: number,
	QuietJobBonus: number,
	QuietJobMaxTier: number,
	NoOneLeftBehindBonus: number,
	HotJobBonus: number,
	FreshBonus: number,
	FirstJobMultiplier: number,
	RepPerRound: number,
	MaxPayoutPerRound: number,
	DifficultyPayout: { [string]: number },
}

export type Objective = { id: string, bonusPct: number }

export type Input = {
	outcome: string, -- "Escaped" | "Busted" | "Aborted" | "Shutdown"
	vanLoot: number,
	crewSize: number,
	inVanAtEnd: boolean, -- this player
	allInVan: boolean, -- the whole crew
	difficulty: string,
	isHotJob: boolean,
	maxAlarmTier: number,
	objectives: { Objective }?,
	fresh: boolean, -- heist not in this player's recent history (and the history is full)
	firstJobAvailable: boolean, -- daily ×2 not used yet today
}

export type Bonus = { id: string, label: string, pct: number }

export type Result = {
	cash: number,
	rep: number,
	share: number, -- step 1 (unrounded)
	crewBonusPct: number,
	tierMultiplier: number,
	bonuses: { Bonus },
	bonusPct: number,
	escaped: boolean, -- this player got away in an Escaped round
	busted: boolean,
	caughtHalf: boolean,
	firstJobToday: boolean, -- the daily ×2 was applied (and is now used up)
	clamped: boolean,
}

function Payout.roundHalfUp(x: number): number
	return math.floor(x + 0.5)
end

local function empty(tierMultiplier: number): Result
	return {
		cash = 0,
		rep = 0,
		share = 0,
		crewBonusPct = 0,
		tierMultiplier = tierMultiplier,
		bonuses = {},
		bonusPct = 0,
		escaped = false,
		busted = false,
		caughtHalf = false,
		firstJobToday = false,
		clamped = false,
	}
end

function Payout.compute(input: Input, cfg: Config): Result
	local n = math.max(1, math.floor(input.crewSize))
	local tierMultiplier = cfg.DifficultyPayout[input.difficulty] or 1
	local outcome = input.outcome
	local result = empty(tierMultiplier)
	if outcome ~= "Escaped" and outcome ~= "Busted" and outcome ~= "Shutdown" then
		return result -- Aborted or unknown: nothing
	end

	local busted = outcome == "Busted"
	local vanLoot = math.max(0, input.vanLoot)
	local value = if busted then vanLoot * cfg.BustedFactor else vanLoot
	local crewBonusPct = cfg.CrewBonusPerExtra * (n - 1)
	local share = value / n * (1 + crewBonusPct)
	result.share = share
	result.crewBonusPct = crewBonusPct
	result.busted = busted

	if outcome == "Shutdown" then
		result.tierMultiplier = 1
		result.cash = math.min(Payout.roundHalfUp(share), cfg.MaxPayoutPerRound)
		result.clamped = share > cfg.MaxPayoutPerRound
		result.rep = Payout.roundHalfUp(share + cfg.RepPerRound)
		return result
	end

	local amount = share
	local escaped = outcome == "Escaped" and input.inVanAtEnd
	result.escaped = escaped
	if outcome == "Escaped" and not input.inVanAtEnd then
		amount *= cfg.CaughtAtEndFactor
		result.caughtHalf = true
	end
	amount *= tierMultiplier

	if not busted then
		local bonuses: { Bonus } = {}
		if input.maxAlarmTier <= cfg.QuietJobMaxTier then
			table.insert(bonuses, { id = "QuietJob", label = "Quiet Job", pct = cfg.QuietJobBonus })
		end
		if n >= 2 and input.allInVan then
			table.insert(
				bonuses,
				{ id = "NoOneLeftBehind", label = "No One Left Behind", pct = cfg.NoOneLeftBehindBonus }
			)
		end
		if input.isHotJob then
			table.insert(bonuses, { id = "HotJob", label = "Hot Job", pct = cfg.HotJobBonus })
		end
		if input.fresh then
			table.insert(bonuses, { id = "Fresh", label = "Fresh", pct = cfg.FreshBonus })
		end
		local objectives: { Objective } = input.objectives or {}
		for _, objective in objectives do
			if type(objective.bonusPct) == "number" and objective.bonusPct > 0 then
				table.insert(
					bonuses,
					{ id = `Objective:{objective.id}`, label = "Objective", pct = objective.bonusPct }
				)
			end
		end
		local total = 0
		for _, bonus in bonuses do
			total += bonus.pct
		end
		result.bonuses = bonuses
		result.bonusPct = total
		amount *= 1 + total
	end

	-- Rep uses the amount before the daily ×2 (and keeps counting when Busted).
	result.rep = Payout.roundHalfUp(amount + cfg.RepPerRound * tierMultiplier)
	if escaped and input.firstJobAvailable then
		amount *= cfg.FirstJobMultiplier
		result.firstJobToday = true
	end
	local cash = Payout.roundHalfUp(amount)
	if cash > cfg.MaxPayoutPerRound then
		cash = cfg.MaxPayoutPerRound
		result.clamped = true
	end
	result.cash = cash
	return result
end

-- Fresh: the history holds `window` rounds and this heist is not among them.
function Payout.isFresh(recentHeists: { string }, heistId: string, window: number): boolean
	if #recentHeists < window then
		return false
	end
	for i = math.max(1, #recentHeists - window + 1), #recentHeists do
		if recentHeists[i] == heistId then
			return false
		end
	end
	return true
end

return Payout
