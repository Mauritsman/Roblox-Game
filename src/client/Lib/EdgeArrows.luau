--!strict
-- Markers for important places: on screen a small marker with a label and distance, off screen an arrow
-- on the screen edge pointing at it (van, caught teammates, the Gouda, pings, hint beacons).
--
--   EdgeArrows.set(key, { target = function() return Vector3? end, glyph, color, label?, onScreen? })
--   EdgeArrows.clear(key)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lib = script.Parent
local Hud = require(Lib.Hud)
local Theme = require(Lib.Theme)
local UiScale = require(Lib.UiScale)

local EdgeArrows = {}

export type Spec = {
	target: () -> Vector3?,
	glyph: string,
	color: Color3,
	label: string?,
	onScreen: boolean?, -- also show a marker when the target is on screen (default true)
	priority: number?,
}

type Entry = { spec: Spec, frame: Frame, arrow: TextLabel, glyph: TextLabel, caption: TextLabel }

local entries: { [string]: Entry } = {}
local layer: ScreenGui? = nil
local connection: RBXScriptConnection? = nil

local MARGIN = 46

local function build(spec: Spec): Entry
	local root = layer :: ScreenGui
	local frame = Hud.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(120, 64),
		Visible = false,
	}, root)
	local arrow = Hud.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(34, 34),
		Text = "▲",
		TextColor3 = spec.color,
		Display = true,
		MaxTextSize = 30,
		Stroke = 2,
	}, frame)
	local glyph = Hud.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(30, 30),
		Text = spec.glyph,
		TextColor3 = spec.color,
		Display = true,
		MaxTextSize = 24,
		Stroke = 2,
	}, frame)
	local caption = Hud.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(1, 0, 0, 20),
		Text = spec.label or "",
		TextColor3 = Theme.Colors.Text,
		MaxTextSize = 16,
		Stroke = 1.5,
	}, frame)
	return { spec = spec, frame = frame, arrow = arrow, glyph = glyph, caption = caption }
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local scale = 1 -- the World layer has no UIScale
	local center = viewport / 2
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, entry in entries do
		local ok, position = pcall(entry.spec.target)
		if not ok or typeof(position) ~= "Vector3" then
			entry.frame.Visible = false
			continue
		end
		local point = camera:WorldToViewportPoint(position)
		local onScreen = point.Z > 0
			and point.X > MARGIN
			and point.X < viewport.X - MARGIN
			and point.Y > MARGIN
			and point.Y < viewport.Y - MARGIN
		local distance = if root then (position - root.Position).Magnitude else 0
		local label = entry.spec.label or ""
		local distanceText = if distance > 8 then `{math.floor(distance)}m` else ""
		entry.caption.Text = if label ~= "" and distanceText ~= ""
			then `{label} · {distanceText}`
			else label .. distanceText
		if onScreen then
			if entry.spec.onScreen == false then
				entry.frame.Visible = false
				continue
			end
			entry.frame.Visible = true
			entry.arrow.Visible = false
			entry.glyph.Position = UDim2.fromScale(0.5, 0.32)
			entry.frame.Position = UDim2.fromOffset(point.X / scale, (point.Y - 22) / scale)
		else
			-- Direction on the screen; behind the camera the projection is mirrored.
			local dir = Vector2.new(point.X, point.Y) - center
			if point.Z < 0 then
				dir = -dir
			end
			if dir.Magnitude < 1 then
				dir = Vector2.new(0, 1)
			end
			local unit = dir.Unit
			local half = center - Vector2.new(MARGIN, MARGIN)
			local t = math.min(
				if math.abs(unit.X) > 1e-4 then half.X / math.abs(unit.X) else math.huge,
				if math.abs(unit.Y) > 1e-4 then half.Y / math.abs(unit.Y) else math.huge
			)
			local edge = center + unit * t
			entry.frame.Visible = true
			entry.arrow.Visible = true
			entry.arrow.Rotation = math.deg(math.atan2(unit.Y, unit.X)) + 90
			entry.frame.Position = UDim2.fromOffset(edge.X / scale, edge.Y / scale)
		end
	end
end

function EdgeArrows.set(key: string, spec: Spec)
	if not layer then
		layer = UiScale.root("World")
	end
	local existing = entries[key]
	if existing then
		existing.frame:Destroy()
	end
	entries[key] = build(spec)
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

function EdgeArrows.has(key: string): boolean
	return entries[key] ~= nil
end

function EdgeArrows.clear(key: string)
	local entry = entries[key]
	if entry then
		entry.frame:Destroy()
		entries[key] = nil
	end
	if next(entries) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- Helpers for common targets.
function EdgeArrows.partTarget(part: Instance?): () -> Vector3?
	return function()
		if part and part.Parent then
			if part:IsA("BasePart") then
				return part.Position
			elseif part:IsA("Model") then
				return part:GetPivot().Position
			elseif part:IsA("Attachment") then
				return part.WorldPosition
			end
		end
		return nil
	end
end

function EdgeArrows.playerTarget(target: Player): () -> Vector3?
	return function()
		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root.Position else nil
	end
end

return EdgeArrows
