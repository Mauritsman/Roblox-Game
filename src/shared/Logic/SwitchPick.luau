--!strict
-- Which LOCKDOWN switches act this round (beta-spec-maps §7 MELTDOWN: "fire shutters close 2 of {North Bridge,
-- South Bridge, Staff Door, Yard Door}: seeded, never both bridges"). Map attributes on each `LockdownSwitch`:
--   Group      switches sharing a Group are chosen from together (none = always acts)
--   Pick       how many of the group act (the lowest Pick in the group counts; none = all)
--   Exclusive  at most one chosen switch per Exclusive value ("Bridge")
-- Same seed and same members → same choice (DevJob replays a round).

local Rng = if script then require(script.Parent.Rng) else require("./Rng")

local SwitchPick = {}

export type Member = {
	id: string,
	group: string?,
	pick: number?,
	exclusive: string?,
}

-- A small deterministic string hash (seeds one random stream per group).
function SwitchPick.hash(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 2147483629
	end
	return h
end

-- {[id] = true} for every member that acts at LOCKDOWN.
function SwitchPick.choose(members: { Member }, seed: number): { [string]: boolean }
	local chosen: { [string]: boolean } = {}
	local groups: { [string]: { Member } } = {}
	local names: { string } = {}
	for _, member in members do
		local group = member.group
		if group == nil or group == "" then
			chosen[member.id] = true
		else
			local list = groups[group]
			if not list then
				list = {}
				groups[group] = list
				table.insert(names, group)
			end
			table.insert(list, member)
		end
	end
	table.sort(names)
	for _, name in names do
		local list = groups[name]
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		local pick = #list
		for _, member in list do
			if member.pick and member.pick >= 0 then
				pick = math.min(pick, math.floor(member.pick))
			end
		end
		-- Mix the seed so neighbouring seeds give different streams (the LCG's first draws are close otherwise).
		local mixed = ((math.floor(math.abs(seed)) % 2147483629) * 69621 + SwitchPick.hash(name)) % 2147483629
		local rng = Rng.new(mixed)
		rng:next()
		local usedExclusive: { [string]: boolean } = {}
		local count = 0
		for _, member in rng:shuffle(list) do
			if count >= pick then
				break
			end
			local exclusive = member.exclusive
			if not (exclusive and usedExclusive[exclusive]) then
				chosen[member.id] = true
				count += 1
				if exclusive then
					usedExclusive[exclusive] = true
				end
			end
		end
	end
	return chosen
end

return SwitchPick
