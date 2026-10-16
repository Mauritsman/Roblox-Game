--!strict
-- Playing sounds on the client: one-shots (2D or at a world position), named loops and crossfaded music.
-- Data lives in src/shared/Sounds.luau. Placeholder ids (0 or "") are skipped silently.
-- Three SoundGroups (Music, SFX, UI); the Settings sliders set their volumes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Settings = require(script.Parent.Settings)

local Audio = {}

export type PlayOptions = { pitch: number?, volume: number? }

local groups: { [string]: SoundGroup } = {}
local loops: { [string]: Sound } = {}
local musicSound: Sound? = nil
local musicKey: string? = nil
local musicPitch = 1
local duckToken = 0
local duckFactor = 1

local function soundId(id: number | string): string?
	if typeof(id) == "number" then
		return if id > 0 then "rbxassetid://" .. tostring(id) else nil
	end
	if id == "" or id == "0" then
		return nil
	end
	return id
end

-- True when the key exists and has a real id (handy for "is this sound filled in yet").
function Audio.has(key: string): boolean
	local def = Sounds[key]
	return def ~= nil and soundId(def.id) ~= nil
end

local function group(name: string): SoundGroup
	local existing = groups[name]
	if existing then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = "CC_" .. name
	g.Volume = 1
	g.Parent = SoundService
	groups[name] = g
	return g
end

local function applyVolumes()
	group("Music").Volume = Settings.volume("Music") * duckFactor
	local sfx = Settings.volume("Sfx")
	group("SFX").Volume = sfx
	group("UI").Volume = sfx * 0.9
end

local function create(key: string, opts: PlayOptions?): Sound?
	local def = Sounds[key]
	if not def then
		return nil
	end
	local id = soundId(def.id)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = id
	sound.Volume = def.volume * (if opts and opts.volume then opts.volume else 1)
	sound.PlaybackSpeed = (def.pitch or 1) * (if opts and opts.pitch then opts.pitch else 1)
	sound.Looped = def.looped == true
	sound.SoundGroup = group(def.group)
	return sound
end

local function cleanupLater(sound: Sound)
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(12, function()
		if sound.Parent and not sound.Looped then
			sound:Destroy()
		end
	end)
end

-- 2D one-shot (UI and "your own" sounds).
function Audio.play(key: string, opts: PlayOptions?): Sound?
	local sound = create(key, opts)
	if not sound then
		return nil
	end
	sound.Parent = SoundService
	sound:Play()
	cleanupLater(sound)
	return sound
end

-- 3D one-shot at a part, attachment or position.
function Audio.playAt(key: string, where: Instance | Vector3, opts: PlayOptions?): Sound?
	local sound = create(key, opts)
	if not sound then
		return nil
	end
	local holder: Instance
	if typeof(where) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = where
		attachment.Parent = workspace.Terrain
		holder = attachment
		task.delay(12, function()
			attachment:Destroy()
		end)
	else
		holder = where
	end
	sound.RollOffMaxDistance = 80
	sound.Parent = holder
	sound:Play()
	cleanupLater(sound)
	return sound
end

-- Named loop (siren, rumble): on = start if not running, off = stop.
function Audio.loop(key: string, on: boolean, parent: Instance?)
	local running = loops[key]
	if on then
		if running and running.Parent then
			return
		end
		local sound = create(key)
		if not sound then
			return
		end
		sound.Looped = true
		sound.Parent = parent or SoundService
		sound:Play()
		loops[key] = sound
	elseif running then
		loops[key] = nil
		local tween = TweenService:Create(running, TweenInfo.new(0.4), { Volume = 0 })
		tween:Play()
		tween.Completed:Once(function()
			running:Destroy()
		end)
	end
end

-- Crossfade to a music track (nil = silence). Same key again does nothing.
function Audio.music(key: string?, fadeSeconds: number?)
	if key == musicKey then
		return
	end
	musicKey = key
	local fade = fadeSeconds or 1
	local old = musicSound
	musicSound = nil
	if old then
		if fade <= 0 then
			old:Destroy()
		else
			local tween = TweenService:Create(old, TweenInfo.new(fade), { Volume = 0 })
			tween:Play()
			tween.Completed:Once(function()
				old:Destroy()
			end)
		end
	end
	if not key then
		return
	end
	local sound = create(key)
	if not sound then
		return
	end
	local target = sound.Volume
	sound.PlaybackSpeed *= musicPitch
	sound.Volume = if fade > 0 then 0 else target
	sound.Parent = SoundService
	sound:Play()
	if fade > 0 then
		TweenService:Create(sound, TweenInfo.new(fade), { Volume = target }):Play()
	end
	if not sound.Looped then
		sound.Ended:Once(function()
			if musicSound == sound then
				musicSound = nil
				musicKey = nil
			end
			sound:Destroy()
		end)
	end
	musicSound = sound
end

function Audio.currentMusic(): string?
	return musicKey
end

-- Hard stop (Gouda lift: silence, then a ding).
function Audio.stopMusic()
	Audio.music(nil, 0)
end

-- Music −40% for a moment (under banners).
function Audio.duck(seconds: number)
	duckToken += 1
	local token = duckToken
	duckFactor = 0.6
	applyVolumes()
	task.delay(seconds, function()
		if token == duckToken then
			duckFactor = 1
			applyVolumes()
		end
	end)
end

-- Music pitch (slow-mo): 1 = normal.
function Audio.setMusicPitch(pitch: number)
	local sound = musicSound
	if sound then
		local def = musicKey and Sounds[musicKey]
		local base = if def then def.pitch or 1 else 1
		TweenService:Create(sound, TweenInfo.new(0.2), { PlaybackSpeed = base * pitch }):Play()
	end
	musicPitch = pitch
end

local started = false
function Audio.init()
	if started then
		return
	end
	started = true
	applyVolumes()
	Settings.Changed:Connect(function(key)
		if key == "Music" or key == "Sfx" then
			applyVolumes()
		end
	end)
end

return Audio
