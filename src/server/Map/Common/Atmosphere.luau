--!strict
-- Lighting mood per heist: time of day, light colours, fog, colour correction, glow (bloom) and sky.
-- Each heist passes its own settings (field `Atmosphere` in the definition); whatever it leaves out
-- comes from BlueNight.
--
-- BlueNight = the "blue night" of Polderdam (§10.1). Dark enough for mood, bright enough that kids
-- on a phone can still see where they are walking. Warm lamps against cool moonlight.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

-- All fields are optional. Names with Haze/Grade/Bloom belong to the effects in Lighting.
export type Settings = {
	ClockTime: number?, -- time of day, 0..24 (0.5 = half past midnight)
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

local BLUE_NIGHT = {
	ClockTime = 0.5,
	GeographicLatitude = 52, -- the Netherlands
	Brightness = 1.6,
	Ambient = Color3.fromRGB(34, 38, 58),
	OutdoorAmbient = Color3.fromRGB(70, 82, 120),
	ColorShiftTop = Color3.fromRGB(120, 140, 200),
	ColorShiftBottom = Color3.fromRGB(20, 24, 40),
	EnvironmentDiffuseScale = 0.45,
	EnvironmentSpecularScale = 0.7, -- wet cobblestones shine a little
	ExposureCompensation = 0.25,
	HazeDensity = 0.32,
	HazeOffset = 0.15,
	HazeColor = Color3.fromRGB(96, 112, 156),
	HazeDecay = Color3.fromRGB(40, 48, 80),
	HazeGlare = 0,
	Haze = 1.4,
	GradeBrightness = 0.02,
	GradeContrast = 0.1,
	GradeSaturation = 0.08,
	GradeTint = Color3.fromRGB(232, 238, 255),
	BloomIntensity = 0.7,
	BloomSize = 26,
	BloomThreshold = 1.5,
	StarCount = 2500,
	MoonAngularSize = 14,
}

Atmosphere.BlueNight = table.freeze(table.clone(BLUE_NIGHT)) :: Settings

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

-- Applies a heist's mood. Without settings: BlueNight.
function Atmosphere.apply(settings: Settings?)
	local s: Settings = settings or {}
	local d = BLUE_NIGHT

	Lighting.ClockTime = s.ClockTime or d.ClockTime
	Lighting.GeographicLatitude = s.GeographicLatitude or d.GeographicLatitude
	Lighting.Brightness = s.Brightness or d.Brightness
	Lighting.Ambient = s.Ambient or d.Ambient
	Lighting.OutdoorAmbient = s.OutdoorAmbient or d.OutdoorAmbient
	Lighting.ColorShift_Top = s.ColorShiftTop or d.ColorShiftTop
	Lighting.ColorShift_Bottom = s.ColorShiftBottom or d.ColorShiftBottom
	Lighting.EnvironmentDiffuseScale = s.EnvironmentDiffuseScale or d.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = s.EnvironmentSpecularScale or d.EnvironmentSpecularScale
	Lighting.ExposureCompensation = s.ExposureCompensation or d.ExposureCompensation
	Lighting.GlobalShadows = true

	-- The effect names stay the same, so the next heist reuses them instead of duplicating them.
	local atmosphere = ensure("Atmosphere", "NightHaze") :: Atmosphere
	atmosphere.Density = s.HazeDensity or d.HazeDensity
	atmosphere.Offset = s.HazeOffset or d.HazeOffset
	atmosphere.Color = s.HazeColor or d.HazeColor
	atmosphere.Decay = s.HazeDecay or d.HazeDecay
	atmosphere.Glare = s.HazeGlare or d.HazeGlare
	atmosphere.Haze = s.Haze or d.Haze

	local grade = ensure("ColorCorrectionEffect", "NightGrade") :: ColorCorrectionEffect
	grade.Brightness = s.GradeBrightness or d.GradeBrightness
	grade.Contrast = s.GradeContrast or d.GradeContrast
	grade.Saturation = s.GradeSaturation or d.GradeSaturation
	grade.TintColor = s.GradeTint or d.GradeTint

	local bloom = ensure("BloomEffect", "LampBloom") :: BloomEffect
	bloom.Intensity = s.BloomIntensity or d.BloomIntensity
	bloom.Size = s.BloomSize or d.BloomSize
	bloom.Threshold = s.BloomThreshold or d.BloomThreshold

	local sky = ensure("Sky", "NightSky") :: Sky
	sky.StarCount = s.StarCount or d.StarCount
	sky.MoonAngularSize = s.MoonAngularSize or d.MoonAngularSize
	sky.CelestialBodiesShown = true
end

return Atmosphere
