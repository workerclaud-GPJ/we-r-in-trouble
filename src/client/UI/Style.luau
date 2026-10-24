--!strict
--[[
	Style — colors, fonts, sizes and UI-only tuning for the HUD.

	Look: "cute but readable". Dark plum panels + cream text + hamster-gold accent,
	thick outlines, rounded corners, one rounded display font (FredokaOne).
	All sizes are BASE pixels; HudRoot applies a UIScale (Style.Scale) so the
	same numbers work on phone and PC. Touch targets use Size.Touch (52) on a layer
	whose scale never drops below Scale.TouchMin (0.85), so they stay >= 44 px.

	NOTE: values under Tuning are UI presentation timings only. Gameplay numbers
	(bleed-out, departure, cinematic length...) come from src/shared/Config via
	StateAdapter.Tuning; deadlines come from the server as timestamps.
]]

local Style = {}

Style.Color = table.freeze({
	Panel = Color3.fromRGB(38, 30, 58),
	PanelLight = Color3.fromRGB(62, 50, 92),
	Outline = Color3.fromRGB(18, 12, 30),
	Text = Color3.fromRGB(255, 248, 232),
	TextDim = Color3.fromRGB(210, 198, 232),
	Accent = Color3.fromRGB(255, 196, 84), -- hamster gold
	Good = Color3.fromRGB(118, 226, 140),
	Warn = Color3.fromRGB(255, 212, 72),
	Hot = Color3.fromRGB(255, 150, 64),
	Bad = Color3.fromRGB(255, 104, 118),
	Dizzy = Color3.fromRGB(176, 140, 255),
	Poof = Color3.fromRGB(150, 176, 210),
	Exit = Color3.fromRGB(110, 230, 200),
	BarBack = Color3.fromRGB(24, 18, 38),
	Shade = Color3.fromRGB(10, 6, 20),
})

-- Stage pill colors (GDD 4.1: green / yellow / orange / red).
Style.StageColor = table.freeze({
	Calm = Style.Color.Good,
	Warning = Style.Color.Warn,
	Active = Style.Color.Hot,
	Critical = Style.Color.Bad,
}) :: { [string]: Color3 }

Style.Font = table.freeze({
	Display = Enum.Font.FredokaOne,
	Body = Enum.Font.FredokaOne,
	Number = Enum.Font.GothamBlack,
})

Style.Text = table.freeze({
	Huge = 48,
	Title = 32,
	Large = 26,
	Body = 22,
	Small = 18,
})

Style.Size = table.freeze({
	Margin = 10,
	Corner = 14,
	CornerSmall = 8,
	Stroke = 3,
	TextStroke = 2,
	Pad = 10,
	Gap = 6,
	Touch = 52, -- 52 * Scale.TouchMin(0.85) = 44.2 px >= 44 px minimum touch target
	BarHeight = 14,
	PanelWidth = 280,
	HpWidth = 210,
	OverlayWidth = 360,
	ResultWidth = 440,
	BannerWidth = 460,
	Badge = 48,
	BillboardWidth = 190,
	BillboardHeight = 78,
})

-- HUD UIScale = clamp(min(shortSide / RefShortSide, width / RefWidth), Min, Max)
-- Phone landscape 844x390 -> 0.75, small phone 667x375 -> 0.7, 720p+ -> 1.35 (cap).
-- The layer with touch buttons never goes below TouchMin (so 52 base px >= 44 px).
Style.Scale = table.freeze({
	RefShortSide = 520,
	RefWidth = 1000,
	Min = 0.7,
	TouchMin = 0.85,
	Max = 1.35,
})

-- Emoji render through Roblox's emoji fallback font; no image assets needed.
Style.Icon = table.freeze({
	Repair = "🔧",
	Deliver = "📦",
	MultiHold = "🤝",
	Objective = "⭐",
	Exit = "🏁",
	Downed = "💫",
	Hp = "🐹",
	Done = "✅",
	Todo = "⬜",
	Star = "⭐",
	Eye = "👁",
	Rescue = "🚒",
}) :: { [string]: string }

Style.Tuning = table.freeze({
	UiTick = 0.1, -- HUD refresh period (s)
	MarkerRefresh = 0.25, -- marker list/text refresh period (s)
	BannerTime = 3, -- default banner duration (>= WARNING_BANNER_MIN, GDD 4.1)
	HintTime = 5, -- step hint banner (queued after the briefing -> visible ~5-10 s into the match)
	BriefingTime = 4, -- "window open" banner length (briefing itself uses Config BRIEFING_TIME)
	CriticalBlinkUnder = 30, -- timer blinks in Critical when < 30 s left (GDD 4.1)
	MarkerNearDistance = 9, -- closer than this, the ProximityPrompt takes over; marker goes compact
	OverlayTint = 0.8, -- background transparency of Downed/Poofed tint
	HudToggleKey = Enum.KeyCode.H, -- HUD_TOGGLE_KEY (GDD 8.6.1)
})

return Style
