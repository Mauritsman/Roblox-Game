--!strict
-- Game feel (beta-spec-ux §4): pops, flying numbers, count-ups, hit-stop, slow-mo, edge flashes.
-- Respects reduce motion: no shake, no camera dips, no slow-mo zoom, static frames instead of sweeps.
-- The freeze and the slow-mo are client-only illusions; the server keeps running.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Lib = script.Parent
local Audio = require(Lib.Audio)
local Hud = require(Lib.Hud)
local Settings = require(Lib.Settings)
local Theme = require(Lib.Theme)
local UiScale = require(Lib.UiScale)

local Juice = {}

local player = Players.LocalPlayer

local alivePops: { BillboardGui } = {}

local function reduce(): boolean
	return Settings.reduceMotion()
end

-- Scale pop on a GuiObject (0 → 1.15 → 1). With reduce motion only a short fade.
function Juice.pop(gui: GuiObject, strength: number?)
	local scale = gui:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		local new = Instance.new("UIScale")
		new.Name = "PopScale"
		new.Parent = gui
		scale = new
	end
	local s = scale :: UIScale
	if reduce() then
		s.Scale = 1
		return
	end
	s.Scale = strength or 1.4
	TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- Gentle pulse loop until the returned function is called.
function Juice.pulse(gui: GuiObject, period: number?): () -> ()
	local scale = Instance.new("UIScale")
	scale.Name = "PulseScale"
	scale.Parent = gui
	local tween: Tween? = nil
	if not reduce() then
		local t = TweenService:Create(
			scale,
			TweenInfo.new((period or 1) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.08 }
		)
		t:Play()
		tween = t
	end
	return function()
		if tween then
			tween:Cancel()
		end
		scale:Destroy()
	end
end

local function adorneeFor(where: Instance | Vector3): (Instance?, Part?)
	if typeof(where) == "Vector3" then
		local anchor = Instance.new("Part")
		anchor.Name = "PopAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2
		anchor.Position = where
		anchor.Parent = workspace.CurrentCamera
		return anchor, anchor
	end
	if where:IsA("Model") then
		local head = where:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head, nil
		end
		return where.PrimaryPart or where:FindFirstChildWhichIsA("BasePart"), nil
	end
	return where, nil
end

export type PopOptions = { size: number?, rise: number?, hold: number?, offset: number?, big: boolean? }

-- World pop (BillboardGui, FredokaOne with a dark outline). Pooled: max 8 alive.
function Juice.worldPop(text: string, color: Color3, where: Instance | Vector3, opts: PopOptions?)
	local adornee, anchor = adorneeFor(where)
	if not adornee then
		return
	end
	local o: PopOptions = opts or {}
	if #alivePops >= Theme.UX.PopsAlive then
		local oldest = table.remove(alivePops, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local size = o.size or (if o.big then 56 else 36)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Pop"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(260, size + 10)
	gui.StudsOffset = Vector3.new(0, o.offset or 2.5, 0)
	gui.Adornee = adornee :: any
	gui.MaxDistance = 120
	local label = Hud.text({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		Display = true,
		MaxTextSize = size,
		Stroke = 2,
	}, gui)
	local scale = Instance.new("UIScale")
	scale.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(alivePops, gui)
	if reduce() then
		scale.Scale = 1
	else
		scale.Scale = 0
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.15 }):Play()
		task.delay(0.12, function()
			TweenService:Create(scale, TweenInfo.new(0.13), { Scale = 1 }):Play()
		end)
		TweenService:Create(gui, TweenInfo.new((o.hold or 0.6) + 0.55), {
			StudsOffset = Vector3.new(0, (o.offset or 2.5) + (o.rise or 1.5), 0),
		}):Play()
	end
	task.delay((o.hold or 0.6) + 0.25, function()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		local fade = TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		local index = table.find(alivePops, gui)
		if index then
			table.remove(alivePops, index)
		end
		gui:Destroy()
		if anchor then
			anchor:Destroy()
		end
	end)
end

-- Screen position (px, viewport) of a world point, or nil when behind the camera.
function Juice.screenPoint(position: Vector3): Vector2?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local point, onScreen = camera:WorldToViewportPoint(position)
	if point.Z < 0 then
		return nil
	end
	local _ = onScreen
	return Vector2.new(point.X, point.Y)
end

-- A label flies from a screen point to a GuiObject (e.g. "+150" from the van into the loot meter).
function Juice.flyTo(text: string, color: Color3, from: Vector2?, target: GuiObject?, seconds: number?)
	local layer = UiScale.root("Top")
	local scale = UiScale.get()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		or Vector2.new(1280, 720)
	local start = from or Vector2.new(viewport.X / 2, viewport.Y * 0.55)
	local label = Hud.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(start.X / scale, start.Y / scale),
		Size = UDim2.fromOffset(180, 40),
		Text = text,
		TextColor3 = color,
		Display = true,
		MaxTextSize = 34,
		Stroke = 2,
	}, layer)
	local duration = seconds or 0.5
	if target and target.Parent and not reduce() then
		local goal = target.AbsolutePosition + target.AbsoluteSize / 2
		-- Top layer ignores the GUI inset; target is in an inset layer. Add the inset back.
		local inset = (game:GetService("GuiService")):GetGuiInset()
		goal += inset
		TweenService:Create(label, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(goal.X / scale, goal.Y / scale),
		}):Play()
	end
	task.delay(duration, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
		if target and target.Parent then
			Juice.pop(target, 1.12)
		end
	end)
end

-- Counts a label's number up over `seconds` (format with Hud.formatNumber, plus prefix/suffix).
function Juice.countUp(
	label: TextLabel,
	from: number,
	to: number,
	seconds: number,
	prefix: string?,
	suffix: string?
)
	local p = prefix or ""
	local s = suffix or ""
	if reduce() or seconds <= 0 then
		label.Text = p .. Hud.formatNumber(to) .. s
		return
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - started) / seconds, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		label.Text = p .. Hud.formatNumber(from + (to - from) * eased) .. s
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

-- Camera offset applied after Roblox's camera every frame (dips, hit-stop hold). One owner at a time.
local cameraHold: CFrame? = nil
local cameraOffset = CFrame.identity
local bound = false

local function ensureCameraStep()
	if bound then
		return
	end
	bound = true
	RunService:BindToRenderStep("CC_Juice", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if cameraHold then
			camera.CFrame = cameraHold
		elseif cameraOffset ~= CFrame.identity then
			camera.CFrame = camera.CFrame * cameraOffset
		end
	end)
end

-- Short camera dip on a heavy pickup (none with reduce motion).
function Juice.cameraDip(depth: number?)
	if reduce() then
		return
	end
	ensureCameraStep()
	local d = depth or 0.35
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / 0.3
		if t >= 1 then
			cameraOffset = CFrame.identity
			connection:Disconnect()
			return
		end
		cameraOffset = CFrame.new(0, -d * math.sin(t * math.pi), 0)
	end)
end

local function eachTrack(fn: (AnimationTrack) -> ())
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			fn(track)
		end
	end
end

-- Hit-stop: freeze your own animations and hold the camera (0.08 s when caught).
function Juice.hitstop(seconds: number?)
	local duration = seconds or 0.08
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	ensureCameraStep()
	cameraHold = camera.CFrame
	local frozen: { AnimationTrack } = {}
	eachTrack(function(track)
		track:AdjustSpeed(0)
		table.insert(frozen, track)
	end)
	task.delay(duration, function()
		cameraHold = nil
		for _, track in frozen do
			track:AdjustSpeed(1)
		end
	end)
end

-- Slow-mo ("JUST MADE IT!"): FOV push-in, your animations at 0.4 speed, music pitch 0.8.
function Juice.slowmo(seconds: number?)
	local duration = seconds or 1.2
	local camera = workspace.CurrentCamera
	Audio.setMusicPitch(0.8)
	if not reduce() and camera then
		local fov = camera.FieldOfView
		TweenService:Create(camera, TweenInfo.new(duration * 0.4, Enum.EasingStyle.Quad), {
			FieldOfView = math.max(40, fov - 15),
		}):Play()
		eachTrack(function(track)
			track:AdjustSpeed(0.4)
		end)
		task.delay(duration, function()
			TweenService:Create(camera, TweenInfo.new(0.4), { FieldOfView = fov }):Play()
			eachTrack(function(track)
				track:AdjustSpeed(1)
			end)
		end)
	end
	task.delay(duration, function()
		Audio.setMusicPitch(1)
	end)
end

-- Screen edge frame (UIStroke inset on a full-screen frame).
local function edgeFrame(color: Color3, thickness: number): (Frame, UIStroke)
	local frame = Hud.frame({
		Name = "Edge",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}, UiScale.root("Fullscreen"))
	local inner = Hud.frame({
		Size = UDim2.new(1, -thickness * 2, 1, -thickness * 2),
		Position = UDim2.fromOffset(thickness, thickness),
	}, frame)
	local stroke = Hud.make("UIStroke", {
		Color = color,
		Thickness = thickness * 2,
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Name = "EdgeStroke",
	}, inner)
	return frame, stroke
end

-- Red edge flash when spotted (reduce motion: a static frame for 1 s).
function Juice.edgeFlash(color: Color3?, seconds: number?)
	local frame, stroke = edgeFrame(color or Theme.Colors.Danger, 14)
	local hold = if reduce() then 1 else (seconds or 0.3)
	task.delay(hold, function()
		local fade = TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		frame:Destroy()
	end)
end

-- Lockdown sweep: red/blue alternating edge until stopped (reduce motion: static red frame).
local sweepFrame: Frame? = nil
function Juice.edgeSweep(on: boolean)
	if not on then
		if sweepFrame then
			sweepFrame:Destroy()
			sweepFrame = nil
		end
		return
	end
	if sweepFrame then
		return
	end
	local frame, stroke = edgeFrame(Theme.Colors.Danger, 8)
	sweepFrame = frame
	if reduce() then
		return
	end
	task.spawn(function()
		local red = true
		while sweepFrame == frame do
			stroke.Color = if red then Theme.Colors.Danger else Theme.Colors.Police
			red = not red
			task.wait(0.45)
		end
	end)
end

-- Money shower on the payout screen (≤ 30 bills; none with reduce motion).
function Juice.moneyShower(parent: Instance, count: number?)
	if reduce() then
		return
	end
	local n = math.min(count or 24, 30)
	for i = 1, n do
		task.delay(i * 0.05, function()
			local bill = Hud.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(math.random(), -0.05),
				Size = UDim2.fromOffset(34, 18),
				BackgroundColor3 = Color3.fromRGB(110, 200, 120),
				BorderSizePixel = 0,
				Rotation = math.random(-40, 40),
				ZIndex = 20,
			}, parent)
			Hud.corner(bill, 3)
			Hud.make("UIStroke", { Color = Color3.fromRGB(40, 110, 60), Thickness = 2 }, bill)
			local fall = 1.6 + math.random() * 1.2
			TweenService:Create(bill, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(bill.Position.X.Scale + (math.random() - 0.5) * 0.2, 1.1),
				Rotation = bill.Rotation + math.random(-180, 180),
			}):Play()
			task.delay(fall, function()
				bill:Destroy()
			end)
		end)
	end
end

return Juice
