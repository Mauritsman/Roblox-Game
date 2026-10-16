--!strict
-- All sounds of Crowbar Crew in one place (owner: ux; beta-spec-ux §5).
--
-- Rules for `id`:
--   * Only audio uploaded by the Roblox account in the Creator Store (licensed library) or audio we upload
--     ourselves may get an "rbxassetid://..." id. Record the source and "free to use" in `note`.
--   * Engine sounds ("rbxasset://sounds/...") ship with every Roblox client and are free to use; they are
--     placeholders until real sounds are chosen.
--   * `id = 0` is a PLACEHOLDER: playback skips it silently. Fill these in Studio (Creator Store → Audio →
--     creator "Roblox") and update the note.
--
-- Groups: "Music", "SFX", "UI" (SoundGroups; the Settings sliders set their volumes).

export type Group = "Music" | "SFX" | "UI"
export type SoundDef = {
	id: number | string,
	volume: number,
	group: Group,
	looped: boolean?,
	pitch: number?,
	note: string,
}

local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
local WATER = "rbxasset://sounds/impact_water.mp3"
local ENGINE = "Engine sound (ships with the Roblox client, free to use); placeholder"
local TODO = "PLACEHOLDER (id 0 = silent): pick a Roblox-uploaded Creator Store sound"

local Sounds: { [string]: SoundDef } = {
	-- Music (looped, crossfaded by AudioController)
	MusicGarage = {
		id = 0,
		volume = 0.5,
		group = "Music",
		looped = true,
		note = TODO .. "; funky groove ~90 bpm",
	},
	MusicSneak = {
		id = 0,
		volume = 0.45,
		group = "Music",
		looped = true,
		note = TODO .. "; pizzicato stealth loop",
	},
	MusicChase = {
		id = 0,
		volume = 0.5,
		group = "Music",
		looped = true,
		note = TODO .. "; fast brass + drums",
	},
	MusicPayout = {
		id = 0,
		volume = 0.5,
		group = "Music",
		looped = true,
		note = TODO .. "; triumphant sting + loop",
	},
	MusicBusted = { id = 0, volume = 0.6, group = "Music", note = TODO .. "; sad trombone (one-shot)" },

	-- Loot
	PickupCube = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; squish" },
	PickupCoins = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; tip-jar coins" },
	PickupDrawer = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; drawer slide + bills" },
	PickupWheel = { id = LAND, volume = 0.5, group = "SFX", pitch = 0.8, note = ENGINE },
	PickupGouda = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; sparkle" },
	Grunt = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; cartoon grunt" },
	WaddleStep = { id = STEP, volume = 0.35, group = "SFX", pitch = 0.7, note = ENGINE },
	RollRumble = { id = 0, volume = 0.5, group = "SFX", looped = true, note = TODO .. "; rolling wheel loop" },
	Throw = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; whoosh" },
	Catch = { id = LAND, volume = 0.6, group = "SFX", pitch = 1.4, note = ENGINE },
	DropLight = { id = LAND, volume = 0.5, group = "SFX", pitch = 1.2, note = ENGINE },
	DropHeavy = { id = LAND, volume = 0.8, group = "SFX", pitch = 0.6, note = ENGINE },
	FragileCrack = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; crack" },
	KaChing = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; cash register" },
	Splash = { id = WATER, volume = 0.6, group = "SFX", note = ENGINE },

	-- Stealth
	Spotted = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; stinger 'dun!'" },
	GuardHuh = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; '?'" },
	AlarmBeep = { id = PING, volume = 0.5, group = "SFX", pitch = 0.9, note = ENGINE },
	SirenLoop = { id = 0, volume = 0.4, group = "SFX", looped = true, note = TODO .. "; police siren loop" },
	ShiftChime = { id = PING, volume = 0.5, group = "SFX", pitch = 0.7, note = ENGINE },
	CountdownTick = { id = CLICK, volume = 0.6, group = "UI", note = ENGINE },
	Captured = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; boing + whistle" },
	CellDoor = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; cell door clank" },
	Rescue = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; 'yay'" },
	GrateCrawl = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; grate scrape" },
	BarrelIn = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; lid bonk" },
	BarrelOut = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; pop" },
	Sniff = { id = 0, volume = 0.5, group = "SFX", note = TODO .. "; sniff" },
	Sneeze = { id = 0, volume = 0.8, group = "SFX", note = TODO .. "; sneeze" },

	-- NPCs
	KarelShout = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; grumble, no words" },
	DoorSlam = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; door slam" },
	KarelTsk = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; 'tsk tsk'" },
	BoefBark = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; small dog bark" },
	BoefSniff = { id = 0, volume = 0.5, group = "SFX", note = TODO .. "; sniffing loop" },
	BoefMunch = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; munch" },
	GuardSnore = { id = 0, volume = 0.5, group = "SFX", looped = true, note = TODO .. "; snore" },

	-- Events
	GoudaDing = { id = PING, volume = 0.8, group = "SFX", pitch = 0.5, note = ENGINE },
	JustMadeIt = { id = 0, volume = 0.8, group = "SFX", note = TODO .. "; choir 'aah'" },
	StarChime = { id = PING, volume = 0.6, group = "UI", pitch = 1.2, note = ENGINE },
	RankUpFanfare = { id = 0, volume = 0.8, group = "UI", note = TODO .. "; fanfare" },
	MoneyShower = { id = 0, volume = 0.6, group = "UI", note = TODO .. "; bills rustle" },
	Shing = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; mask on 'shing'" },

	-- Gadgets
	Bzzt = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; EMP bzzt" },
	NoisemakerRing = { id = 0, volume = 0.7, group = "SFX", note = TODO .. "; alarm clock" },
	BubbleShoot = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; bubble blow" },
	BubblePop = { id = 0, volume = 0.6, group = "SFX", note = TODO .. "; pop" },
	DroneHum = { id = 0, volume = 0.4, group = "SFX", looped = true, note = TODO .. "; drone hum" },
	CrowbarCreak = { id = 0, volume = 0.6, group = "SFX", looped = true, note = TODO .. "; creak loop" },
	Crack = { id = LAND, volume = 0.9, group = "SFX", pitch = 1.8, note = ENGINE },

	-- UI
	UiTap = { id = CLICK, volume = 0.4, group = "UI", pitch = 1.2, note = ENGINE },
	UiBack = { id = CLICK, volume = 0.4, group = "UI", pitch = 0.8, note = ENGINE },
	HintBlip = { id = PING, volume = 0.35, group = "UI", pitch = 1.4, note = ENGINE },
	PingSpot = { id = PING, volume = 0.5, group = "UI", pitch = 1.0, note = ENGINE },
	PingGuard = { id = PING, volume = 0.5, group = "UI", pitch = 1.3, note = ENGINE },
	PingQuick = { id = PING, volume = 0.5, group = "UI", pitch = 1.1, note = ENGINE },
	ToastSoft = { id = CLICK, volume = 0.25, group = "UI", pitch = 1.5, note = ENGINE },
}

return Sounds
