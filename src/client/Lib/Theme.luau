--!strict
-- Theme (ux): colours, fonts, sizes and UI constants for every screen. Design rules: beta-spec-ux §6.
-- Gameplay numbers stay in Config; only presentation lives here.

local Theme = {}

local rgb = Color3.fromRGB
local hex = Color3.fromHex

Theme.Colors = {
	Panel = rgb(16, 18, 26),
	PanelLight = rgb(36, 40, 56),
	Backdrop = rgb(6, 7, 12),
	Text = rgb(245, 245, 250),
	Muted = rgb(170, 175, 190),
	Dim = rgb(70, 72, 84),
	Stroke = rgb(8, 9, 14),
	Accent = rgb(255, 128, 32), -- crew orange
	Danger = rgb(255, 70, 70),
	Warn = rgb(255, 200, 60),
	Good = rgb(90, 210, 120),
	Info = rgb(80, 160, 255),
	Gold = hex("FFC21A"),
	Police = rgb(60, 110, 255),
	Bubble = rgb(150, 220, 255),
}

Theme.PanelTransparency = 0.25

export type Style = { color: Color3, glyph: string, label: string }

-- Loot classes: colour + shape (beta-spec-ux §6), used on the carry chip, crew list and pings.
Theme.Loot = {
	Small = { color = hex("5EE6A8"), glyph = "●", label = "SMALL" },
	Medium = { color = hex("FFD23F"), glyph = "■", label = "MEDIUM" },
	Heavy = { color = hex("B98CFF"), glyph = "⬢", label = "HEAVY" },
	Main = { color = hex("FFC21A"), glyph = "♛", label = "GOLDEN" },
	Rare = { color = hex("6FD3FF"), glyph = "✦", label = "RARE" },
} :: { [string]: Style }

function Theme.loot(class: any): Style
	return Theme.Loot[if typeof(class) == "string" then class else "Small"] or Theme.Loot.Small
end

-- Guard states (drawn by the server today; kept here so UI and pings use the same language).
Theme.Guard = {
	Suspicious = { color = rgb(255, 210, 60), glyph = "?", label = "SUSPICIOUS" },
	Alert = { color = rgb(255, 70, 70), glyph = "!", label = "ALERT" },
	Search = { color = rgb(255, 150, 40), glyph = "?!", label = "SEARCHING" },
	Stunned = { color = rgb(150, 220, 255), glyph = "zZ", label = "BUBBLED" },
} :: { [string]: Style }

-- Alarm ladder: QUIET green · SUSPICIOUS yellow · SEARCHING orange · LOCKDOWN red.
Theme.Alarm = {
	[0] = { color = rgb(90, 210, 120), glyph = "○", label = "QUIET" },
	[1] = { color = rgb(255, 200, 60), glyph = "●", label = "SUSPICIOUS" },
	[2] = { color = rgb(255, 150, 40), glyph = "●●", label = "SEARCHING" },
	[3] = { color = rgb(255, 70, 70), glyph = "●●●", label = "LOCKDOWN" },
} :: { [number]: Style }

-- Crew: colour from the CrewColor attribute (same order as PingService) plus a fixed shape per slot.
Theme.CrewColors = { rgb(80, 160, 255), rgb(255, 150, 40), rgb(90, 210, 120), rgb(240, 110, 200) }
Theme.CrewShapes = { "●", "■", "▲", "◆" }

function Theme.crew(player: Player?): Style
	local index = if player then player:GetAttribute("CrewColor") else nil
	local i = if typeof(index) == "number" and Theme.CrewColors[index] then index else 1
	return {
		color = Theme.CrewColors[i],
		glyph = Theme.CrewShapes[i] or "●",
		label = if player then player.DisplayName else "",
	}
end

Theme.Fonts = {
	Display = Font.fromEnum(Enum.Font.FredokaOne), -- banners, pops, numbers
	Ui = Font.fromEnum(Enum.Font.BuilderSansBold), -- UI text
	UiHeavy = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	UiMedium = Font.fromEnum(Enum.Font.BuilderSansMedium),
}

-- Sizes in px at UIScale 1 (designed for a 640 × 360 phone).
Theme.Size = {
	MinButton = 48,
	MainButton = 64,
	MinText = 12,
	BodyText = 14,
	ActionText = 18,
	Gutter = 8,
	Radius = 10,
	-- Touch cluster (beta-spec-ux §2.2): size and offset (right, bottom) from the bottom-right corner.
	Touch = {
		Context = { size = 72, right = 110, bottom = 22 },
		Gadget = { size = 64, right = 28, bottom = 108 },
		Crouch = { size = 56, right = 196, bottom = 22 },
		Ping = { size = 52, right = 110, bottom = 112 },
	},
}

Theme.Motion = {
	Fast = 0.15,
	Normal = 0.25,
	Slow = 0.5,
	PopScale = 1.15,
}

-- UI constants (would be Config.UX; Config belongs to mechanics/meta, so they live here).
Theme.UX = {
	LastSecond = 5, -- "JUST MADE IT!" when the escape happens with ≤ this many seconds left
	PingHoldSeconds = 0.3, -- holding PING this long opens the quick wheel
	QuickCooldown = 10, -- shared quick-wheel cooldown (advisor: one preset per 10 s)
	HintIdlePulse = 20,
	HintRepeat = 60,
	TipCooldown = 30,
	TipMaxShows = 2,
	FeedbackAutoSend = 4,
	FeedbackHideAfterSkips = 3,
	PayoutSeconds = 30,
	PopsAlive = 8,
	ToastsAlive = 4,
	ThrowRange = 10,
	CatchFlight = 3.5,
	CatchLanding = 5,
	ThrowArc = 0.35,
	ShiftWarning = 60,
}

-- Quick wheel presets (fixed words, no punctuation). The key is what the client sends with `Quick`;
-- if Config.Ping.QuickPresets lists other keys, those keys are sent and shown by their label below.
export type Preset = { key: string, label: string, glyph: string, pitch: number }
Theme.QuickPresets = {
	{ key = "GO", label = "GO", glyph = "▲", pitch = 1.5 },
	{ key = "TO THE VAN", label = "TO THE VAN", glyph = "➜", pitch = 1.3 },
	{ key = "THROW TO ME", label = "THROW TO ME", glyph = "↷", pitch = 1.15 },
	{ key = "WAIT", label = "WAIT", glyph = "✋", pitch = 0.8 },
	{ key = "LIFT WITH ME", label = "LIFT WITH ME", glyph = "⬢", pitch = 0.95 },
	{ key = "HELP", label = "HELP", glyph = "!", pitch = 1.7 },
} :: { Preset }

function Theme.preset(key: string): Preset
	for _, preset in Theme.QuickPresets do
		if preset.key == key then
			return preset
		end
	end
	return { key = key, label = string.upper(key), glyph = "●", pitch = 1 }
end

return Theme
