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
	Collapse = "Time ran out. The kitchen collapsed!",
	Wipe = "Everyone got dizzy at the same time.",
	NoPlayers = "Not enough hamsters left.",
	Abandoned = "Not enough hamsters left.",
	Debug = "Match ended by a test command.",
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
}

Strings.Text = table.freeze({
	-- Lobby
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
	InsideCount = "{n}/{need} inside",
	Paused = "Wait! Everyone back in!",
	PausedSub = "Leaving in {t}  ·  {n}/{need} inside",
	LeavingIn = "Leaving in {t}!",
	LastCall = "Last call! The carrier is leaving",

	-- Result
	ResultWin = "You escaped!",
	ResultLose = "Oh no!",
	ResultDisaster = "Disaster: {v}",
	ResultTime = "Time: {v}",
	ResultEscaped = "Escaped: {v}",
	ResultNobody = "nobody",
	ResultStats = "Revives: {r}   Dizzy: {d}",
	BackToLobby = "Back to the lobby in {t}",

	-- Banners
	BannerStepComplete = "Step complete!",
	BannerWindowOpen = "The window is open!",
	BannerWindowOpenSub = "Rescue is coming. Get to the exit!",
	BannerCarrier = "The rescue carrier is here!",
	BannerCarrierSub = "Everyone get inside!",
	BannerCritical = "It's getting worse!",
	BannerCriticalSub = "Watch the red circles!",
	BannerLastCall = "Last call!",
	BannerLastCallSub = "The carrier is leaving soon",
	BannerLastChance = "Last chance!",
	BannerLastChanceSub = "Finish the last step fast!",
	MissionFallback = "Escape together!",
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
})

function Strings.stage(stageId: string): string
	return STAGE[stageId] or stageId
end

function Strings.reason(reasonId: string): string
	return REASON[reasonId] or reasonId
end

function Strings.objective(keyOrText: string): string
	return OBJECTIVE[keyOrText] or keyOrText
end

return Strings
