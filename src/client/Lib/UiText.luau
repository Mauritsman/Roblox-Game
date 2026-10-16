--!strict
-- Player-facing words for ids that come from the server (gadgets, perks, awards, modifiers, heists, tags).
-- Unknown ids fall back to a readable version of the id, so new content never shows as blank.

local UiText = {}

export type Entry = { name: string, line: string, glyph: string? }

-- "BubbleBlaster" → "Bubble Blaster"
function UiText.pretty(id: any): string
	if typeof(id) ~= "string" or id == "" then
		return "?"
	end
	local spaced = id:gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
	return spaced
end

local function lookup(map: { [string]: Entry }, id: any): Entry
	local entry = if typeof(id) == "string" then map[id] else nil
	return entry or { name = UiText.pretty(id), line = "", glyph = "●" }
end

UiText.Gadgets = {
	Drone = { name = "Drone", line = "Fly and spot guards", glyph = "✈" },
	Noisemaker = { name = "Noisemaker", line = "Lures one guard away", glyph = "♪" },
	EMP = { name = "EMP", line = "Kills cameras and lamps", glyph = "ϟ" },
	BubbleBlaster = { name = "Bubble Blaster", line = "Bubbles a guard 8 s", glyph = "◎" },
	Crowbar = { name = "Crowbar", line = "Always with you", glyph = "⚒" },
	Periscope = { name = "Periscope", line = "Peek around corners", glyph = "⌕" },
	LockpickSet = { name = "Lockpick Set", line = "Silent doors, slower", glyph = "⚿" },
	FakeDelivery = { name = "Fake Delivery", line = "Walk in as a courier", glyph = "▣" },
} :: { [string]: Entry }

function UiText.gadget(id: any): Entry
	return lookup(UiText.Gadgets, id)
end

-- Short label for the touch GADGET button.
UiText.GadgetShort = {
	Drone = "DRONE",
	Noisemaker = "NOISE",
	EMP = "EMP",
	BubbleBlaster = "BUBBLE",
	Crowbar = "BAR",
} :: { [string]: string }

UiText.Perks = {
	SoftShoes = { name = "Soft Shoes", line = "Crouch faster (8 → 9)" },
	BarrelLungs = { name = "Barrel Lungs", line = "Sneeze later (25 s)" },
	QuietCrowbar = { name = "Quiet Crowbar", line = "Quieter CRACK (25 → 18)" },
	LongArm = { name = "Long Arm", line = "Throw further (10 → 12)" },
	DeepPockets = { name = "Deep Pockets", line = "4 pocket slots" },
	StrongBack = { name = "Strong Back", line = "Heavy loot faster (7 → 8)" },
	QuickHands = { name = "Quick Hands", line = "Free crew faster (1.5 s)" },
	EscapeArtist = { name = "Escape Artist", line = "Crawl out after 12 s" },
	SpareBatteries = { name = "Spare Batteries", line = "+1 charge, first gadget" },
} :: { [string]: Entry }

function UiText.perk(id: any): Entry
	return lookup(UiText.Perks, id)
end

-- Default 3×3 tree (advisor); Config.PerkTree wins when meta defines it.
UiText.PerkBranches = {
	{ id = "Sneak", name = "SNEAK", perks = { "SoftShoes", "BarrelLungs", "QuietCrowbar" } },
	{ id = "Muscle", name = "MUSCLE", perks = { "LongArm", "DeepPockets", "StrongBack" } },
	{ id = "Crew", name = "CREW", perks = { "QuickHands", "EscapeArtist", "SpareBatteries" } },
}

UiText.Awards = {
	GoudaGetter = { name = "Gouda Getter", line = "Banked the Golden Gouda", glyph = "♛" },
	Jailbreaker = { name = "Jailbreaker", line = "Freed the most crew", glyph = "⚿" },
	BubbleHero = { name = "Bubble Hero", line = "Popped a friend loose", glyph = "◎" },
	JustMadeIt = { name = "Just Made It", line = "Last-second van dive", glyph = "⏱" },
	SelfEMP = { name = "Self-EMP Award", line = "Zapped your own drone", glyph = "ϟ" },
	SelfEMPAward = { name = "Self-EMP Award", line = "Zapped your own drone", glyph = "ϟ" },
	Achoo = { name = "Achoo!", line = "Sneezed out of hiding", glyph = "✱" },
	KarelsNemesis = { name = "Karel's Nemesis", line = "Karel cleaned up after you", glyph = "⌂" },
	Butterfingers = { name = "Butterfingers", line = "Dropped it. Twice.", glyph = "✋" },
	OopsBubbled = { name = "Oops, Bubbled", line = "Bubbled a teammate", glyph = "◎" },
	CheeseCannon = { name = "Cheese Cannon", line = "Throws that got caught", glyph = "↷" },
	DogWhisperer = { name = "Dog Whisperer", line = "Fed Boef a snack", glyph = "♥" },
	Safecracker = { name = "Safecracker", line = "Kept the grater going", glyph = "⚙" },
	CellRegular = { name = "Cell Regular", line = "Caught a few times", glyph = "▦" },
	Ghost = { name = "Ghost", line = "Never fully seen", glyph = "◌" },
	PackMule = { name = "Pack Mule", line = "Banked the most loot", glyph = "⬢" },
	Hero = { name = "Hero", line = "Saved the crew", glyph = "★" },
	Ninja = { name = "Ninja", line = "Quiet as a mouse", glyph = "◆" },
	Sneezy = { name = "Sneezy", line = "Bless you", glyph = "✱" },
	GoldenHands = { name = "Golden Hands", line = "Grabbed the good stuff", glyph = "♛" },
	FreshCrook = { name = "Fresh Crook", line = "Your first job!", glyph = "✦" },
	Sightseer = { name = "Sightseer", line = "Enjoyed the view", glyph = "◉" },
} :: { [string]: Entry }

function UiText.award(id: any): Entry
	return lookup(UiText.Awards, id)
end

UiText.Modifiers = {
	PowerCut = { name = "Power Cut", line = "Lights and cameras off" },
	HealthInspector = { name = "Health Inspector", line = "A snitch walks around" },
	WetFloor = { name = "Wet Floor", line = "Puddles: walk, don't run" },
	RushJob = { name = "Rush Job", line = "Only 6 minutes" },
	SleepyGuards = { name = "Sleepy Guards", line = "Guards notice slower" },
	DoubleShift = { name = "Double Shift", line = "One extra guard" },
} :: { [string]: Entry }

function UiText.modifier(id: any): Entry
	return lookup(UiText.Modifiers, id)
end

UiText.Heists = {
	GoldenWheel = { name = "The Golden Wheel", line = "Cheese shop by the canal", glyph = "◉" },
	PralinePalace = { name = "Praline Palace", line = "A fancy chocolaterie", glyph = "◆" },
	TulipAuction = { name = "Tulip Auction", line = "Flowers, fragile and fast", glyph = "✿" },
	MiniJob = { name = "First Job", line = "Learn the ropes", glyph = "✦" },
} :: { [string]: Entry }

function UiText.heist(id: any): Entry
	return lookup(UiText.Heists, id)
end

UiText.Tiers = {
	Easy = { name = "EASY", line = "Young", mult = 0.8 },
	Normal = { name = "NORMAL", line = "Aged", mult = 1.0 },
	Hard = { name = "HARD", line = "Extra Aged", mult = 1.4 },
}
UiText.TierOrder = { "Easy", "Normal", "Hard" }

-- Feedback tags: id (sent) → label (shown).
UiText.FeedbackTags = {
	Fun = "Fun",
	TooHard = "Too hard",
	TooEasy = "Too easy",
	Confusing = "Confusing",
	Bug = "Bug",
	Laggy = "Laggy",
} :: { [string]: string }
UiText.FeedbackOrder = { "Fun", "TooHard", "TooEasy", "Confusing", "Bug", "Laggy" }

-- First-time tips (max 2 times ever each).
UiText.Tips = {
	LiftTogether = "Too heavy? Lift together",
	ThrowIt = "Hands full: throw it",
	HideBarrel = "Hide in a barrel",
	DropOrRun = "Spotted! Drop or run",
	FreeAtCell = "Hold FREE at the cell",
	DroneLook = "Drone: look at guards",
	BubbleHim = "Crew can bubble him",
} :: { [string]: string }

-- Short words for MetaResult refusals.
UiText.Reasons = {
	NotEnoughCash = "Not enough Cash",
	Locked = "Locked",
	Owned = "Already yours",
	NotOwned = "You don't own that",
	NoPoints = "No skill points left",
	TooMany = "Max 3 equipped",
	Busy = "One moment…",
	InRound = "Not during a job",
} :: { [string]: string }

return UiText
