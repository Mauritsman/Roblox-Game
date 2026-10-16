--!strict
-- Shared pieces for the Garage screens: scrolling rows, cards, empty states, footers.

local Lib = script.Parent.Parent.Lib
local Hud = require(Lib.Hud)
local Theme = require(Lib.Theme)

local Common = {}

local C = Theme.Colors

-- A horizontal (or vertical) scrolling area with a list layout.
function Common.scroller(parent: Instance, horizontal: boolean, props: Hud.Props?): ScrollingFrame
	local frame = Hud.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Muted,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		Selectable = false,
	}, nil)
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	Hud.list(
		frame,
		if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		8,
		if horizontal then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Top
	)
	Hud.padding(frame, 4, 4)
	frame.Parent = parent
	return frame
end

function Common.card(parent: Instance, props: Hud.Props): Frame
	local card = Hud.panel({
		BackgroundColor3 = C.PanelLight,
		BackgroundTransparency = 0.05,
		Radius = 12,
	}, parent)
	for key, value in props do
		(card :: any)[key] = value
	end
	return card
end

function Common.outline(card: GuiObject, color: Color3, thickness: number?): UIStroke
	local existing = card:FindFirstChild("Outline")
	if existing and existing:IsA("UIStroke") then
		existing.Color = color
		existing.Thickness = thickness or 3
		return existing
	end
	local stroke = Hud.make("UIStroke", {
		Name = "Outline",
		Color = color,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, card)
	return stroke
end

-- Centered message for missing data ("Loading jobs…").
function Common.empty(parent: Instance, text: string, sub: string?)
	local box = Hud.frame({ Size = UDim2.fromScale(1, 1) }, parent)
	Hud.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.9, 0, 0, 36),
		Text = text,
		Display = true,
		TextColor3 = C.Muted,
		MaxTextSize = 26,
	}, box)
	if sub then
		Hud.text({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.42, 22),
			Size = UDim2.new(0.9, 0, 0, 22),
			Text = sub,
			TextColor3 = C.Muted,
			MaxTextSize = 17,
		}, box)
	end
end

-- Footer bar at the bottom of a screen body (returns the frame; children laid out right to left).
function Common.footer(parent: Instance, height: number?): Frame
	local footer = Hud.frame({
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, height or 56),
	}, parent)
	Hud.list(
		footer,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Right,
		Enum.VerticalAlignment.Center
	)
	return footer
end

-- The area above the footer.
function Common.content(parent: Instance, footerHeight: number?): Frame
	return Hud.frame({
		Name = "Content",
		Size = UDim2.new(1, 0, 1, -((footerHeight or 56) + 4)),
	}, parent)
end

function Common.stars(count: number, max: number?): string
	local m = max or 3
	return string.rep("★", math.clamp(count, 0, m)) .. string.rep("☆", m - math.clamp(count, 0, m))
end

-- Reads an id-keyed table where keys may have been turned into strings over the network.
function Common.byUserId(map: any): { [number]: any }
	local out: { [number]: any } = {}
	if typeof(map) ~= "table" then
		return out
	end
	for key, value in map do
		local id = tonumber(key)
		if id then
			out[id] = value
		end
	end
	return out
end

return Common
