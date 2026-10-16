--!strict
-- Lighting presets per area, as plain data (beta-spec-maps §1 and §9; name reserved in docs/contracts.md §3).
-- Lighting is global, but the crew can be in a heist while a newcomer plays the mini-job and others wait in the
-- Garage, so the ux client applies the preset of the player's own area (by Activity, or by position for
-- spectators). The server keeps applying the heist's preset (heist definition `Atmosphere`) as a fallback.
--
-- Field names are exactly those of Map/Common/Atmosphere.Settings, so `Atmosphere.apply(preset)` works on the
-- server and the same fields map 1:1 onto Lighting, Atmosphere, ColorCorrection, Bloom and Sky on the client.
-- Every preset fills every field.

local Config = require(script.Parent.Config)

export type Preset = {
	ClockTime: number?,
	GeographicLatitude: number?,
	Brightness: number?,
	Ambient: Color3?,
	OutdoorAmbient: Color3?,
	ColorShiftTop: Color3?,
	ColorShiftBottom: Color3?,
	EnvironmentDiffuseScale: number?,
	EnvironmentSpecularScale: number?,
	ExposureCompensation: number?,
	HazeDensity: number?,
	HazeOffset: number?,
	HazeColor: Color3?,
	HazeDecay: Color3?,
	HazeGlare: number?,
	Haze: number?,
	GradeBrightness: number?,
	GradeContrast: number?,
	GradeSaturation: number?,
	GradeTint: Color3?,
	BloomIntensity: number?,
	BloomSize: number?,
	BloomThreshold: number?,
	StarCount: number?,
	MoonAngularSize: number?,
}

local rgb = Color3.fromRGB

-- A copy of `base` with some fields changed (frozen, so nobody edits a shared preset by accident).
local function with(base: Preset, changes: Preset): Preset
	local copy = table.clone(base) :: any
	for key, value in changes :: any do
		copy[key] = value
	end
	return table.freeze(copy)
end

-- The Golden Wheel: Polderdam's "blue night" (identical to Common/Atmosphere.BlueNight). Warm lamps against cool
-- moonlight; dark enough for mood, bright enough to see on a phone.
local BLUE_NIGHT: Preset = table.freeze({
	ClockTime = 0.5,
	GeographicLatitude = 52,
	Brightness = 1.6,
	Ambient = rgb(34, 38, 58),
	OutdoorAmbient = rgb(70, 82, 120),
	ColorShiftTop = rgb(120, 140, 200),
	ColorShiftBottom = rgb(20, 24, 40),
	EnvironmentDiffuseScale = 0.45,
	EnvironmentSpecularScale = 0.7,
	ExposureCompensation = 0.25,
	HazeDensity = 0.32,
	HazeOffset = 0.15,
	HazeColor = rgb(96, 112, 156),
	HazeDecay = rgb(40, 48, 80),
	HazeGlare = 0,
	Haze = 1.4,
	GradeBrightness = 0.02,
	GradeContrast = 0.1,
	GradeSaturation = 0.08,
	GradeTint = rgb(232, 238, 255),
	BloomIntensity = 0.7,
	BloomSize = 26,
	BloomThreshold = 1.5,
	StarCount = 2500,
	MoonAngularSize = 14,
})

-- The Garage: a warm workshop under the arches (tungsten 255, 180, 110), night outside.
local GARAGE = with(BLUE_NIGHT, {
	ClockTime = 0.8,
	Brightness = 1.2,
	Ambient = rgb(70, 52, 40),
	OutdoorAmbient = rgb(92, 82, 96),
	ColorShiftTop = rgb(255, 196, 140),
	ColorShiftBottom = rgb(44, 30, 22),
	EnvironmentDiffuseScale = 0.4,
	EnvironmentSpecularScale = 0.5,
	ExposureCompensation = 0.35,
	HazeDensity = 0.22,
	HazeOffset = 0.1,
	HazeColor = rgb(130, 104, 92),
	HazeDecay = rgb(70, 50, 46),
	Haze = 1.1,
	GradeBrightness = 0.03,
	GradeContrast = 0.08,
	GradeSaturation = 0.14,
	GradeTint = rgb(255, 238, 218),
	BloomIntensity = 0.8,
	BloomSize = 24,
	BloomThreshold = 1.4,
	StarCount = 1800,
	MoonAngularSize = 12,
})

-- The mini-job: dusk on the canal, a little brighter than the heists (first minutes of a new player).
local MINI_JOB = with(BLUE_NIGHT, {
	ClockTime = 18.7,
	Brightness = 1.9,
	Ambient = rgb(64, 58, 84),
	OutdoorAmbient = rgb(118, 104, 140),
	ColorShiftTop = rgb(255, 168, 128),
	ColorShiftBottom = rgb(44, 38, 72),
	EnvironmentDiffuseScale = 0.5,
	ExposureCompensation = 0.35,
	HazeDensity = 0.3,
	HazeOffset = 0.2,
	HazeColor = rgb(196, 146, 156),
	HazeDecay = rgb(96, 74, 128),
	HazeGlare = 0.25,
	Haze = 1.6,
	GradeBrightness = 0.03,
	GradeContrast = 0.08,
	GradeSaturation = 0.1,
	GradeTint = rgb(255, 238, 236),
	StarCount = 600,
})

-- Praline Palace: a warm chocolate night at blue hour (ClockTime 20.2), glossy surfaces, gold highlights.
local PRALINE = with(BLUE_NIGHT, {
	ClockTime = 20.2,
	Brightness = 1.5,
	Ambient = rgb(60, 42, 36),
	OutdoorAmbient = rgb(98, 80, 100),
	ColorShiftTop = rgb(255, 200, 150),
	ColorShiftBottom = rgb(52, 32, 26),
	EnvironmentSpecularScale = 0.8,
	ExposureCompensation = 0.3,
	HazeDensity = 0.3,
	HazeColor = rgb(120, 88, 84),
	HazeDecay = rgb(64, 42, 52),
	Haze = 1.3,
	GradeContrast = 0.12,
	GradeSaturation = 0.12,
	GradeTint = rgb(255, 236, 214),
	BloomIntensity = 0.8,
	BloomSize = 28,
	BloomThreshold = 1.4,
	StarCount = 2000,
})

-- Tulip Auction: pre-dawn (ClockTime 5.4), indigo sky with a magenta glow low on the horizon.
local TULIP = with(BLUE_NIGHT, {
	ClockTime = 5.4,
	Brightness = 1.4,
	Ambient = rgb(40, 44, 72),
	OutdoorAmbient = rgb(78, 90, 138),
	ColorShiftTop = rgb(150, 170, 255),
	ColorShiftBottom = rgb(34, 30, 62),
	ExposureCompensation = 0.2,
	HazeDensity = 0.34,
	HazeOffset = 0.2,
	HazeColor = rgb(92, 98, 162),
	HazeDecay = rgb(128, 72, 140),
	HazeGlare = 0.1,
	Haze = 1.5,
	GradeTint = rgb(232, 236, 255),
	StarCount = 1500,
	MoonAngularSize = 12,
})

local LightingPresets = {}

-- Preset per area name: the heist ids (GoldenWheel, PralinePalace, TulipAuction), "Garage" and "MiniJob".
LightingPresets.Presets = table.freeze({
	GoldenWheel = BLUE_NIGHT,
	Garage = GARAGE,
	MiniJob = MINI_JOB,
	PralinePalace = PRALINE,
	TulipAuction = TULIP,
}) :: { [string]: Preset }

-- Tulip Auction's 5:00 event (MorningLight Step 1–3): the sky brightens in three steps towards sunrise.
LightingPresets.TulipMorning = table.freeze({
	with(TULIP, {
		ClockTime = 5.7,
		Brightness = 1.7,
		OutdoorAmbient = rgb(100, 108, 150),
		ColorShiftTop = rgb(200, 180, 230),
		ExposureCompensation = 0.3,
		HazeColor = rgb(150, 130, 180),
		StarCount = 800,
	}),
	with(TULIP, {
		ClockTime = 6,
		Brightness = 2.1,
		Ambient = rgb(56, 56, 80),
		OutdoorAmbient = rgb(124, 124, 156),
		ColorShiftTop = rgb(255, 196, 190),
		ExposureCompensation = 0.4,
		HazeColor = rgb(196, 160, 176),
		StarCount = 200,
	}),
	with(TULIP, {
		ClockTime = 6.3,
		Brightness = 2.5,
		Ambient = rgb(70, 66, 84),
		OutdoorAmbient = rgb(146, 140, 156),
		ColorShiftTop = rgb(255, 214, 170),
		ExposureCompensation = 0.45,
		HazeDensity = 0.28,
		HazeColor = rgb(226, 190, 172),
		StarCount = 0,
	}),
}) :: { Preset }

LightingPresets.Default = "GoldenWheel"

-- The preset with that name (unknown or nil → the default, The Golden Wheel's blue night).
function LightingPresets.get(name: string?): Preset
	local preset = if name then LightingPresets.Presets[name] else nil
	return preset or LightingPresets.Presets[LightingPresets.Default]
end

-- Name and preset for a player's Activity ("Garage" → Garage, "Tutorial" → MiniJob, "Crew" → the heist).
function LightingPresets.forActivity(activity: string?, heistId: string?): (string, Preset)
	local name = if activity == "Garage"
		then "Garage"
		elseif activity == "Tutorial" then "MiniJob"
		elseif heistId and LightingPresets.Presets[heistId] then heistId
		else LightingPresets.Default
	return name, LightingPresets.get(name)
end

local function near(position: Vector3, point: Config.WorldPoint): boolean
	local dx, dz = position.X - point.X, position.Z - point.Z
	return dx * dx + dz * dz <= Config.World.AreaRadius * Config.World.AreaRadius
end

-- Which area a world position is in: "Garage", "MiniJob" (any slot) or "Heist" (the origin).
function LightingPresets.areaAt(position: Vector3): string
	if near(position, Config.World.GarageOrigin) then
		return "Garage"
	end
	for _, origin in Config.World.MiniJobOrigins do
		if near(position, origin) then
			return "MiniJob"
		end
	end
	return "Heist"
end

-- Name and preset for a world position (spectating cameras, free-roaming players); heistId for the heist area.
function LightingPresets.presetAt(position: Vector3, heistId: string?): (string, Preset)
	local area = LightingPresets.areaAt(position)
	if area == "Heist" then
		return LightingPresets.forActivity("Crew", heistId)
	end
	return area, LightingPresets.get(area)
end

return LightingPresets
