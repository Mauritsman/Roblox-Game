--!strict
-- Lichtsfeer per heist: tijdstip, kleuren van het licht, nevel, kleurcorrectie, gloed (bloom) en lucht.
-- Elke heist geeft zijn eigen instellingen mee (veld `Atmosphere` in de definitie); wat hij niet invult,
-- komt uit BlueNight.
--
-- BlueNight = de "blauwe nacht" van Polderdam (§10.1). Donker genoeg voor sfeer, licht genoeg dat kinderen
-- op een gsm nog zien waar ze lopen. Warme lampen tegen koel maanlicht.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

-- Alle velden zijn optioneel. Namen met Haze/Grade/Bloom horen bij de effecten in Lighting.
export type Settings = {
	ClockTime: number?, -- tijdstip, 0..24 (0.5 = half één 's nachts)
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
	GeographicLatitude = 52, -- Nederland
	Brightness = 1.6,
	Ambient = Color3.fromRGB(34, 38, 58),
	OutdoorAmbient = Color3.fromRGB(70, 82, 120),
	ColorShiftTop = Color3.fromRGB(120, 140, 200),
	ColorShiftBottom = Color3.fromRGB(20, 24, 40),
	EnvironmentDiffuseScale = 0.45,
	EnvironmentSpecularScale = 0.7, -- natte kasseien glanzen een beetje
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

-- Zet de sfeer van een heist. Zonder instellingen: BlueNight.
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

	-- De namen van de effecten blijven dezelfde, zodat een volgende heist ze hergebruikt i.p.v. verdubbelt.
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
