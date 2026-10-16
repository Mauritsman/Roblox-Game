--!strict
-- Meta block of tag and attribute names (owner: meta). Kept apart from Tags.luau to avoid merge conflicts.

return table.freeze({
	-- Garage station tags (placed by the map agent; LobbyService adds the prompts)
	JobBoard = "JobBoard",
	GadgetRack = "GadgetRack",
	Workbench = "Workbench",
	Mirror = "Mirror",
	TrophyWall = "TrophyWall",
	TrophySlot = "TrophySlot", -- 12 children of the trophy wall (ux draws your trophies on them)
	CollectionBook = "CollectionBook",
	VanPaint = "VanPaint", -- every part painted in the first boarder's van colour

	-- Player attributes written by meta
	DataLoaded = "DataLoaded",
	Cash = "Cash",
	Rep = "Rep",
	Rank = "Rank",
	Title = "Title",
	SkillPoints = "SkillPoints",
	RepIntoRank = "RepIntoRank",
	RepForNext = "RepForNext",
	IsNewPlayer = "IsNewPlayer",
	RoundsPlayed = "RoundsPlayed",
	HeistsUnlocked = "HeistsUnlocked", -- comma list
	Loadout = "Loadout", -- comma list of the 2 picks (the Crowbar is implied)
	Perks = "Perks", -- comma list of equipped perks
	MaskId = "MaskId",
	HatId = "HatId",
	VanId = "VanId",
	SaveStatus = "SaveStatus", -- "Ok" | "Trouble" | "Memory"
	Teleporting = "Teleporting",

	-- Attributes meta reads (written by mechanics)
	Activity = "Activity", -- player: "Garage" | "Crew" | "Tutorial"
	InRound = "InRound", -- player: Activity ~= "Garage"
	Masked = "Masked", -- character: mask is on

	-- ReplicatedStorage attributes written by meta
	HotJobHeist = "HotJobHeist",
	HotJobModifier = "HotJobModifier",
	HotJobEndsAt = "HotJobEndsAt", -- os.time() seconds
	MostWantedHeist = "MostWantedHeist",
	TrophyLeaders = "TrophyLeaders", -- "Sam 4 · Alex 2" (main loot banked, players in this server)
})
