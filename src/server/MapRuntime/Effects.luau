--!strict
-- Particle and light effects for the map runtime: steam, mist, sprinklers, the fountain, the mixer's thump and the
-- wrapper's sparkle. Phone-friendly: one emitter per machine, low rates (Config.MapRuntime.Particles), short
-- lifetimes, no extra lights. A map object that already holds ParticleEmitters keeps its own look; the runtime only
-- switches them on and off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Util = require(script.Parent.Util)

local Effects = {}

local P = Config.MapRuntime.Particles

type Style = {
	color: Color3,
	size: { number }, -- start, end
	transparency: { number },
	lifetime: { number },
	speed: { number },
	rate: number,
	accel: Vector3,
	spread: number,
	texture: string,
}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local STYLES: { [string]: Style } = {
	Mist = {
		color = Color3.fromRGB(235, 240, 245),
		size = { 5, 9 },
		transparency = { 0.55, 1 },
		lifetime = { 2.5, 3.5 },
		speed = { 0.5, 1.5 },
		rate = P.Mist,
		accel = Vector3.new(0, 0.3, 0),
		spread = 180,
		texture = SMOKE,
	},
	Steam = {
		color = Color3.fromRGB(230, 225, 220),
		size = { 3, 8 },
		transparency = { 0.4, 1 },
		lifetime = { 1.5, 2.5 },
		speed = { 6, 9 },
		rate = P.Steam,
		accel = Vector3.new(0, 2, 0),
		spread = 15,
		texture = SMOKE,
	},
	Sprinkler = {
		color = Color3.fromRGB(150, 200, 255),
		size = { 0.25, 0.15 },
		transparency = { 0.2, 0.6 },
		lifetime = { 0.8, 1.2 },
		speed = { 2, 4 },
		rate = P.Sprinkler,
		accel = Vector3.new(0, -30, 0),
		spread = 25,
		texture = SPARK,
	},
	Fountain = {
		color = Color3.fromRGB(110, 60, 30),
		size = { 0.5, 0.3 },
		transparency = { 0, 0.4 },
		lifetime = { 0.8, 1.2 },
		speed = { 10, 14 },
		rate = P.Fountain,
		accel = Vector3.new(0, -35, 0),
		spread = 20,
		texture = SPARK,
	},
	Dust = {
		color = Color3.fromRGB(150, 110, 80),
		size = { 1, 3 },
		transparency = { 0.4, 1 },
		lifetime = { 0.6, 1 },
		speed = { 4, 8 },
		rate = 0,
		accel = Vector3.zero,
		spread = 180,
		texture = SMOKE,
	},
	Sparkle = {
		color = Color3.fromRGB(255, 210, 80),
		size = { 0.6, 0.1 },
		transparency = { 0, 0.5 },
		lifetime = { 0.6, 1 },
		speed = { 2, 4 },
		rate = 10,
		accel = Vector3.new(0, 2, 0),
		spread = 180,
		texture = SPARK,
	},
}

local function numberSequence(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- The ParticleEmitters already inside the object (the map's own look).
function Effects.existing(inst: Instance): { ParticleEmitter }
	local list = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			table.insert(list, d)
		end
	end
	return list
end

-- The object's own emitters, or a new one in `style` filling its volume (parts made in `folder`). Starts off.
function Effects.emitters(inst: Instance, styleName: string, folder: Instance): { ParticleEmitter }
	local own = Effects.existing(inst)
	if #own > 0 then
		for _, e in own do
			e.Enabled = false
		end
		return own
	end
	local style = STYLES[styleName] or STYLES.Mist
	local host: BasePart? = if inst:IsA("BasePart") then inst else nil
	if not host then
		local cf, size = Util.box(inst)
		if not cf or not size then
			return {}
		end
		local part = Util.part(`{inst.Name}Fx`, size, cf, folder)
		part.Transparency = 1
		host = part
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RuntimeFx"
	emitter.Texture = style.texture
	emitter.Color = ColorSequence.new(style.color)
	emitter.Size = numberSequence(style.size[1], style.size[2])
	emitter.Transparency = numberSequence(style.transparency[1], style.transparency[2])
	emitter.Lifetime = NumberRange.new(style.lifetime[1], style.lifetime[2])
	emitter.Speed = NumberRange.new(style.speed[1], style.speed[2])
	emitter.Rate = style.rate
	emitter.Acceleration = style.accel
	emitter.SpreadAngle = Vector2.new(style.spread, style.spread)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.LightEmission = 0
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Enabled = false
	emitter.Parent = host
	return { emitter }
end

function Effects.set(emitters: { ParticleEmitter }, on: boolean)
	for _, e in emitters do
		if e.Parent and e.Enabled ~= on then
			e.Enabled = on
		end
	end
end

function Effects.burst(emitters: { ParticleEmitter }, count: number)
	for _, e in emitters do
		if e.Parent then
			e:Emit(count)
		end
	end
end

-- Switches the "on" effects inside an object: lights, sounds (play/stop), beams, particles, fire, smoke.
function Effects.power(inst: Instance, on: boolean)
	for _, d in inst:GetDescendants() do
		local switchable = d:IsA("Light")
			or d:IsA("Beam")
			or d:IsA("ParticleEmitter")
			or d:IsA("Trail")
			or d:IsA("Fire")
			or d:IsA("Smoke")
			or d:IsA("Sparkles")
		if switchable then
			(d :: any).Enabled = on
		elseif d:IsA("Sound") then
			if on then
				d:Play()
			else
				d:Stop()
			end
		end
	end
end

return Effects
