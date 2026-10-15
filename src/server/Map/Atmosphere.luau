--!strict
-- Nachtsfeer voor Polderdam: een leesbare "blauwe nacht" (§10.1). Donker genoeg voor sfeer,
-- licht genoeg dat kinderen op een gsm nog zien waar ze lopen. Warme lampen tegen koel maanlicht.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

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

function Atmosphere.apply()
	Lighting.ClockTime = 0.5
	Lighting.GeographicLatitude = 52 -- Nederland
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(34, 38, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 82, 120)
	Lighting.ColorShift_Top = Color3.fromRGB(120, 140, 200)
	Lighting.ColorShift_Bottom = Color3.fromRGB(20, 24, 40)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.7 -- natte kasseien glanzen een beetje
	Lighting.ExposureCompensation = 0.25
	Lighting.GlobalShadows = true

	local atmosphere = ensure("Atmosphere", "NightHaze") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(96, 112, 156)
	atmosphere.Decay = Color3.fromRGB(40, 48, 80)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.4

	local grade = ensure("ColorCorrectionEffect", "NightGrade") :: ColorCorrectionEffect
	grade.Brightness = 0.02
	grade.Contrast = 0.1
	grade.Saturation = 0.08
	grade.TintColor = Color3.fromRGB(232, 238, 255)

	local bloom = ensure("BloomEffect", "LampBloom") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 26
	bloom.Threshold = 1.5

	local sky = ensure("Sky", "NightSky") :: Sky
	sky.StarCount = 2500
	sky.MoonAngularSize = 14
	sky.CelestialBodiesShown = true
end

return Atmosphere
