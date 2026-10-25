--!strict
--[[
	Strings — every player-facing HUD text (English, GDD assumption 6).
	Theme words (kitchen, window, carrier...) live ONLY here so Theme B can swap
	this table without touching UI logic. Placeholders use {name} and are filled
	by UIUtil.format.
]]

local Strings = {}

local STAGE: { [string]: string } = {
	Calm = "Calm",
	Warning = "Warning!",
	Active = "Danger",
	Critical = "CRITICAL",
}

local REASON: { [string]: string } = {
	Escaped = "The rescue carrier got you out!",
	EscapedWindow = "You jumped out of the window!",
	EscapedDrain = "You escaped through the drain!",
	Collapse = "Time ran out. The kitchen collapsed!",
	Wipe = "Everyone got dizzy at the same time.",
	NoPlayers = "Not enough hamsters left.",
	Abandoned = "Not enough hamsters left.",
	Debug = "Match ended by a test command.",
}

-- Step hint banners (first seconds of each step). Keyed by step display name
-- (RoundState StepName); unknown steps use Text.HintFallback.
local STEP_HINT: { [string]: { text: string, sub: string } } = {
	["Power up the charger"] = {
		text = "Hint: Power up the charger",
		sub = "Run in the wheel and carry batteries to the charger (press E / tap)",
	},
	["Call for help"] = {
		text = "Hint: Call for help",
		sub = "Go up to the counter. Hold E at the radios together!",
	},
	["Cast the cable to the counter"] = {
		text = "Hint: Cast the charger cable!",
		sub = "Hold the cable, stand by a glowing hook spot, hold F (or CAST) and release in the green zone",
	},
	["Pry the window latch"] = {
		text = "Hint: Pry the window latch",
		sub = "Find the scissors on the counter and pry the latch on the window sill",
	},
	["Push the window open"] = {
		text = "Hint: Push together!",
		sub = "Hold E at both sides of the window",
	},
	["Pry the drain grate"] = {
		text = "Hint: There's a drain under the step chair",
		sub = "Find the scissors and pry the grate loose",
	},
	["Lift the grate together"] = {
		text = "Hint: Lift together!",
		sub = "Hold E at both sides of the grate",
	},
	["Tie the cable to the drain"] = {
		text = "Hint: Tie the cable",
		sub = "Bring the charger cable and tie it to the drain to climb down",
	},
}

-- Objective display names. Server may send a string key (ObjectiveDef.displayName,
-- e.g. "obj.run_wheel"), a plain objective id, or already-final text.
local OBJECTIVE: { [string]: string } = {
	["obj.run_wheel"] = "Run the wheel",
	["obj.deliver_batteries"] = "Plug in batteries",
	["obj.call_for_help"] = "Shout into the radios",
	RunWheel = "Run the wheel",
	DeliverBatteries = "Plug in batteries",
	CallForHelp = "Shout into the radios",
	["obj.hang_cable"] = "Hang the cable",
	["obj.cable_counter"] = "Cast a cable to the counter",
	["obj.pry_latch"] = "Pry the latch",
	["obj.push_window"] = "Push the window",
	["obj.pry_grate"] = "Pry the grate",
	["obj.lift_grate"] = "Lift the grate",
	["obj.tie_cable"] = "Tie the cable",
}

Strings.Text = table.freeze({
	-- Lobby
	GameTitle = "We R in Trouble",
	HowToPlayTh = "ช่วยกันทำภารกิจ แล้วหนีออกจากครัวให้ได้!",
	HowToPlay = "Work together and escape the kitchen!",
	PlayerRange = "Needs 2–4 players",
	WaitingForPlayers = "Waiting for players ({n}/{need})", -- GDD 2.1 exact wording
	NeedPlayers = "Need {need} hamsters to start. Invite a friend!",
	MatchStartsIn = "Match starts in {t}",
	ReadyCount = "{n}/{max} hamsters ready",
	MatchInProgress = "Match in progress",
	JoinNextRound = "You'll join the next round ({t})",
	Afk = "AFK: move to join the next match",

	-- Objectives
	StepHeader = "Step {i}/{n}",
	AllStepsDone = "All done. Escape!",
	FollowMarkers = "Follow the ⭐ markers",
	Done = "Done!",
	Held = "Held {held}/{required}",
	Override = "Override engaged: {required} of {base} needed",
	Bonus = "(bonus)",
	Locked = "Locked",
	Percent = "{p}%",
	DeliverCount = "{n}/{count}",
	StepLocked = "Step {i}: locked",
	LastChance = "Last chance! Finish the last step!",

	-- Player status
	Bonk = "Bonk!",
	DizzyTitle = "Dizzy!",
	DizzyKicker = "Bonk!",
	DownedHelp = "Wait for a friend to help you up!",
	BeingRevived = "A friend is helping you up!",
	PoofedTitle = "Poofed!",
	BackIn = "Back in",
	ComingBack = "Coming back soon...",
	Spectating = "Watching your friends",
	EscapedTitle = "You escaped!",
	EscapedSub = "Cheer on your friends!",
	InactiveTitle = "Are you there?",
	InactiveSub = "You are inactive. Move to rejoin!",

	-- Extraction
	RescueIn = "Rescue in {t}",
	RescueInSub = "Hold on! Stay near the window",
	CarrierHere = "Get in the carrier!",
	ExitHere = "Get out now!",
	InsideCount = "{n}/{need} inside",
	Paused = "Wait! Everyone back in!",
	PausedSub = "Leaving in {t}  ·  {n}/{need} inside",
	LeavingIn = "Leaving in {t}!",
	LastCall = "Last call! The carrier is leaving",

	-- Result
	ResultWin = "YOU WIN!",
	ResultLose = "YOU LOSE",
	ResultDisaster = "Disaster: {v}",
	ResultTime = "Time: {v}",
	ResultEscaped = "Escaped: {v}",
	ResultNobody = "nobody",
	ResultStats = "Your stats: revives {r} · dizzy {d}",
	BackToLobby = "Back to the lobby in {t}",

	-- Banners
	BannerStepComplete = "Step complete!",
	BannerWindowOpen = "The window is open!",
	BannerWindowOpenSub = "Rescue is coming. Get to the exit!",
	BannerWindowEscape = "The window is open!",
	BannerWindowEscapeSub = "Jump out of the window!",
	BannerDrainEscape = "The drain is open!",
	BannerDrainEscapeSub = "Climb down the cable into the drain!",
	BannerCarrier = "The rescue carrier is here!",
	BannerCarrierSub = "Everyone get inside!",
	BannerCritical = "It's getting worse!",
	BannerCriticalSub = "Watch the red circles!",
	BannerLastCall = "Last call!",
	BannerLastCallSub = "The carrier is leaving soon",
	BannerLastChance = "Last chance!",
	BannerLastChanceSub = "Finish the last step fast!",
	MissionFallback = "Escape together!",
	HintFallback = "Follow the ⭐ markers and press E (or tap) to help!",
	DisasterFallback = "DISASTER!",

	-- Markers
	MarkerExit = "Escape!",
	MarkerDowned = "{name} is dizzy!",
	MarkerHelp = "Help!",
	Distance = "{d} studs",
	SpotFree = "Spot {part}: free",
	SpotTaken = "Spot {part}: taken",

	-- Toggle
	HideHud = "Hide HUD",

	-- Match intro cinematic
	IntroTitleTh = "เจ้าของบ้านหนีไปแล้ว… แต่ลืมพวกเราไว้!",
	IntroTitle = "The humans fled… and forgot us!",
	IntroSkip = "Tap or press Space to skip",

	-- Lobby cosmetics
	StyleButton = "🎩 Style",
	StyleTitle = "Hamster style",
	StyleFur = "Fur",
	StyleHat = "Hat",
	StyleClose = "Close",
})

-- Cosmetic option labels (ids = Config.Cosmetics FUR_ORDER / HAT_ORDER)
local COSMETIC: { [string]: string } = {
	Golden = "Golden",
	WinterWhite = "Winter White",
	Chocolate = "Chocolate",
	Panda = "Panda",
	None = "None",
	PartyHat = "Party hat",
	Bow = "Bow",
	ChefHat = "Chef hat",
	Headphones = "Headphones",
}

function Strings.cosmetic(id: string): string
	return COSMETIC[id] or id
end

function Strings.stage(stageId: string): string
	return STAGE[stageId] or stageId
end

function Strings.reason(reasonId: string): string
	return REASON[reasonId] or reasonId
end

-- Returns (title, sub) for the step hint banner.
function Strings.stepHint(stepName: string?): (string, string)
	local h = stepName and STEP_HINT[stepName]
	if h then
		return h.text, h.sub
	end
	return if stepName then "Hint: " .. Strings.objective(stepName) else "Hint", Strings.Text.HintFallback
end

function Strings.objective(keyOrText: string): string
	return OBJECTIVE[keyOrText] or keyOrText
end

return Strings
