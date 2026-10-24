--!strict
--[[
	StateAdapter — the ONLY place in the UI that reads server state
	(RoundState / Player / objective attributes, CollectionService tags, Remotes).

	Follows docs/ARCHITECTURE.md v1 (Deadline contract) exactly. Every name comes
	from src/shared/Contract.luau; every gameplay number from src/shared/Config.
	Remotes come from src/shared/Remotes.luau (HudBanner only).

	Time model (contract): every attribute ending in "At" is a
	`workspace:GetServerTimeNow()` timestamp, so the client counts down locally.

	Everything is read on demand: HudController polls `snapshot()` at ~10 Hz.
	Missing values degrade gracefully (fallbacks noted per field).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Contract = require(Shared:WaitForChild("Contract"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local StateAdapter = {}

----------------------------------------------------------------------------
-- Contract names (docs/ARCHITECTURE.md §1, §3–§6) — local aliases only
----------------------------------------------------------------------------

local A = Contract.Attr
local NAMES = table.freeze({
	RoundStateFolder = Contract.Folder.RoundState,
	ObjectivesFolder = Contract.Folder.Objectives,
	MapFolder = Contract.Folder.Map, -- Workspace.Map

	-- RoundState (§3)
	Phase = A.Phase,
	PhaseEndsAt = A.PhaseEndsAt,
	PlayersReady = A.PlayersReady,
	PlayersNeeded = A.PlayersNeeded,
	MaxPlayers = A.MaxPlayers,
	MatchId = A.MatchId,
	MatchEndsAt = A.MatchEndsAt,
	Stage = A.Stage,
	DisasterName = A.DisasterName,
	DisasterHint = A.DisasterHint,
	MissionName = A.MissionName,
	StepIndex = A.StepIndex,
	StepCount = A.StepCount,
	StepName = A.StepName,
	LastChance = A.LastChance,
	ExitOpen = A.ExitOpen,
	CarrierArrivesAt = A.CarrierArrivesAt,
	CarrierArrived = A.CarrierArrived,
	DepartureRunning = A.DepartureRunning,
	DepartureEndsAt = A.DepartureEndsAt,
	DepartureRemaining = A.DepartureRemaining,
	ZoneCount = A.ZoneCount,
	ZoneNeeded = A.ZoneNeeded,
	LastCall = A.LastCall,
	ResultWin = A.ResultWin,
	ResultReason = A.ResultReason,
	ResultTime = A.ResultTime,
	ResultDisaster = A.ResultDisaster,
	ResultEscaped = A.ResultEscaped,

	-- Player (§5)
	State = A.State,
	HP = A.HP,
	MaxHP = A.MaxHP,
	Inactive = A.Inactive,
	MoveMode = A.MoveMode,
	BleedOutEndsAt = A.BleedOutEndsAt,
	ReviveProgress = A.ReviveProgress,
	RespawnAt = A.RespawnAt,
	ReviveCount = A.ReviveCount,
	DownedCount = A.DownedCount,

	-- Objective (§4)
	ObjDisplayName = A.DisplayName,
	ObjKind = A.Kind,
	ObjStep = A.Step,
	ObjOrder = A.Order,
	ObjOptional = A.Optional,
	ObjDone = A.Done,
	ObjActive = A.Active,
	Progress = A.Progress,
	Held = A.Held,
	Required = A.Required,
	BaseRequired = A.BaseRequired,
	Override = A.Override,
	Delivered = A.Delivered,
	Count = A.Count,
	Occupied = A.Occupied,

	-- Map markup (§6)
	TagObjectiveAnchor = Contract.Tag.ObjectiveAnchor,
	TagExitZone = Contract.Tag.ExitZone,
	AttrObjectiveId = A.ObjectiveId,
	AttrAnchorPart = A.Part,
	AttrExitOpen = A.Open,
	PromptPart = Contract.Name.PromptPart,
	WinCameraPoint = Contract.Name.WinCameraPoint,
})
StateAdapter.NAMES = NAMES

local VALUES = table.freeze({
	PhaseLobby = Contract.Phase.Lobby, -- waiting: not enough players
	PhaseIntermission = Contract.Phase.Intermission, -- counting down to match
	PhaseMatch = Contract.Phase.Match,
	PhaseEnding = Contract.Phase.Ending, -- 3 s win cinematic before Result (win only)
	PhaseResult = Contract.Phase.Result,

	StateLobby = Contract.State.Lobby,
	StateStanding = Contract.State.Standing,
	StateDowned = Contract.State.Downed,
	StateEliminated = Contract.State.Eliminated,
	StateEscaped = Contract.State.Escaped,

	MovePinned = Contract.MoveMode.Pinned,
})
StateAdapter.VALUES = VALUES

-- Gameplay numbers the HUD needs for bars/fallbacks (read-only, from Config).
StateAdapter.Tuning = table.freeze({
	bleedOutTime = Config.Player.BLEED_OUT_TIME,
	departureCountdown = Config.Extraction.DEPARTURE_COUNTDOWN,
	winCinematicTime = Config.Round.WIN_CINEMATIC_TIME,
	briefingTime = Config.Round.BRIEFING_TIME,
	warningBannerMin = Config.Stages.WARNING_BANNER_MIN,
})

local DEFAULT_PLAYERS_NEEDED = Config.Round.MIN_PLAYERS_TO_START -- only if attribute missing
local DEFAULT_MAX_PLAYERS = Config.Round.MAX_PLAYERS
local DEFAULT_MAX_HP = Config.Player.MAX_HP

----------------------------------------------------------------------------
-- Types
----------------------------------------------------------------------------

export type Phase = "Lobby" | "Intermission" | "Match" | "Ending" | "Result" -- ARCHITECTURE §3

export type Objective = {
	id: string,
	name: string, -- raw key / id / text; UI maps via Strings.objective
	kind: string, -- Repair / Deliver / MultiHold / ...
	step: number,
	order: number,
	optional: boolean,
	done: boolean,
	locked: boolean,
	progress: number,
	held: number?,
	required: number?,
	baseRequired: number?,
	override: boolean,
	delivered: number?,
	count: number?,
}

export type Snapshot = {
	now: number, -- server time
	phase: Phase,
	phaseEndsAt: number?,
	playersReady: number,
	playersNeeded: number,
	maxPlayers: number,

	matchEndsAt: number?,
	stage: string,
	disasterName: string?,
	disasterHint: string?,
	missionName: string?,
	stepIndex: number,
	stepCount: number,
	stepName: string?,
	lastChance: boolean?, -- nil = server does not publish it (UI uses fallback)
	objectives: { Objective },

	exitOpen: boolean,
	carrierArrivesAt: number?,
	carrierArrived: boolean,
	departureRunning: boolean,
	departureEndsAt: number?,
	departureRemaining: number?,
	zoneCount: number,
	zoneNeeded: number,
	lastCall: boolean,

	matchId: number?,
	resultWin: boolean?,
	resultReason: string?, -- Escaped / Collapse / Wipe / Abandoned
	resultTime: number?,
	resultDisaster: string?,
	resultEscaped: { string },

	-- local player
	state: string,
	hp: number,
	maxHp: number,
	inactive: boolean,
	beingRevived: boolean,
	reviveProgress: number,
	bleedOutEndsAt: number?,
	respawnAt: number?,
	reviveCount: number?,
	downedCount: number?,
}

export type MarkerKind = "Objective" | "Exit" | "Downed"

export type MarkerTarget = {
	key: Instance, -- stable identity for pooling (anchor model / exit part / player)
	kind: MarkerKind,
	adornee: BasePart,
	label: string, -- objective name key, or player display name
	objectiveKind: string?,
	anchorPart: string?, -- "A".."D"
	progress: number?,
	held: number?,
	required: number?,
	baseRequired: number?,
	override: boolean,
	occupied: boolean?,
	delivered: number?,
	count: number?,
}

export type BannerPayload = Remotes.BannerPayload -- { key, text, sub?, color?, duration? }

----------------------------------------------------------------------------
-- Low-level readers
----------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer

local function num(inst: Instance?, name: string): number?
	if not inst then
		return nil
	end
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else nil
end

local function str(inst: Instance?, name: string): string?
	if not inst then
		return nil
	end
	local v = inst:GetAttribute(name)
	return if typeof(v) == "string" and v ~= "" then v else nil
end

local function bool(inst: Instance?, name: string): boolean?
	if not inst then
		return nil
	end
	local v = inst:GetAttribute(name)
	return if typeof(v) == "boolean" then v else nil
end

local function roundState(): Instance?
	return ReplicatedStorage:FindFirstChild(NAMES.RoundStateFolder)
end

local PHASE_MAP: { [string]: Phase } = {
	[VALUES.PhaseLobby] = "Lobby",
	[VALUES.PhaseIntermission] = "Intermission",
	[VALUES.PhaseMatch] = "Match",
	[VALUES.PhaseEnding] = "Ending",
	[VALUES.PhaseResult] = "Result",
}

local function normalizePhase(raw: string?): Phase
	local phase: Phase = if raw then PHASE_MAP[raw] or "Lobby" else "Lobby"
	return phase
end

function StateAdapter.serverNow(): number
	return workspace:GetServerTimeNow()
end

function StateAdapter.getMap(): Instance?
	return workspace:FindFirstChild(NAMES.MapFolder)
end

function StateAdapter.getWinCameraPoint(): BasePart?
	local map = StateAdapter.getMap()
	local found = map and map:FindFirstChild(NAMES.WinCameraPoint, true)
	return if found and found:IsA("BasePart") then found else nil
end

function StateAdapter.getPlayerState(player: Player): string
	return str(player, NAMES.State) or VALUES.StateLobby
end

function StateAdapter.isDowned(player: Player): boolean
	return StateAdapter.getPlayerState(player) == VALUES.StateDowned
end

function StateAdapter.isEliminated(player: Player): boolean
	return StateAdapter.getPlayerState(player) == VALUES.StateEliminated
end

----------------------------------------------------------------------------
-- Objectives
----------------------------------------------------------------------------

local function anchorPromptEnabled(anchor: Instance): boolean?
	local promptPart = anchor:FindFirstChild(NAMES.PromptPart)
	local prompt = promptPart and promptPart:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		return prompt.Enabled
	end
	return nil
end

local function inMap(inst: Instance): boolean
	local map = StateAdapter.getMap()
	return map ~= nil and inst:IsDescendantOf(map)
end

local function objectiveFromConfig(cfg: Instance, index: number): Objective
	local progress = num(cfg, NAMES.Progress) or 0
	local delivered = num(cfg, NAMES.Delivered)
	local count = num(cfg, NAMES.Count)
	local done = bool(cfg, NAMES.ObjDone)
	if done == nil then
		done = progress >= 1 or (delivered ~= nil and count ~= nil and count > 0 and delivered >= count)
	end
	local active = bool(cfg, NAMES.ObjActive)
	return {
		id = cfg.Name,
		name = str(cfg, NAMES.ObjDisplayName) or cfg.Name,
		kind = str(cfg, NAMES.ObjKind) or "Repair",
		step = num(cfg, NAMES.ObjStep) or 1,
		order = num(cfg, NAMES.ObjOrder) or index,
		optional = bool(cfg, NAMES.ObjOptional) or false,
		done = done :: boolean,
		locked = active == false and not done,
		progress = progress,
		held = num(cfg, NAMES.Held),
		required = num(cfg, NAMES.Required),
		baseRequired = num(cfg, NAMES.BaseRequired),
		override = bool(cfg, NAMES.Override) or false,
		delivered = delivered,
		count = count,
	}
end

-- Fallback: aggregate objective state from tagged anchors in Workspace.Map
-- (GDD 3.3 puts Progress/Held/Required/Override on anchor models).
local function objectivesFromAnchors(): { Objective }
	local byId: { [string]: Objective } = {}
	local list: { Objective } = {}
	for _, anchor in CollectionService:GetTagged(NAMES.TagObjectiveAnchor) do
		if not inMap(anchor) then
			continue
		end
		local id = str(anchor, NAMES.AttrObjectiveId)
		if not id then
			continue
		end
		local obj = byId[id]
		if not obj then
			local newObj: Objective = {
				id = id,
				name = str(anchor, NAMES.ObjDisplayName) or id,
				kind = str(anchor, NAMES.ObjKind) or "Repair",
				step = num(anchor, NAMES.ObjStep) or 1,
				order = #list + 1,
				optional = bool(anchor, NAMES.ObjOptional) or false,
				done = false,
				locked = true,
				progress = 0,
				override = false,
			}
			byId[id] = newObj
			table.insert(list, newObj)
			obj = newObj
		end
		local o = obj :: Objective
		o.progress = math.max(o.progress, num(anchor, NAMES.Progress) or 0)
		local held, required = num(anchor, NAMES.Held), num(anchor, NAMES.Required)
		if held then
			o.held = math.max(o.held or 0, held)
			o.kind = str(anchor, NAMES.ObjKind) or "MultiHold"
		end
		if required then
			o.required = required
		end
		o.baseRequired = num(anchor, NAMES.BaseRequired) or o.baseRequired
		o.override = o.override or (bool(anchor, NAMES.Override) or false)
		local delivered, count = num(anchor, NAMES.Delivered), num(anchor, NAMES.Count)
		if count then
			o.delivered = delivered or 0
			o.count = count
			o.kind = str(anchor, NAMES.ObjKind) or "Deliver"
		end
		local enabled = anchorPromptEnabled(anchor)
		local activeAttr = bool(anchor, NAMES.ObjActive)
		if activeAttr == true or enabled == true or (activeAttr == nil and enabled == nil) then
			o.locked = false
		end
		if bool(anchor, NAMES.ObjDone) then
			o.done = true
		end
	end
	for _, o in list do
		if o.progress >= 1 or (o.count ~= nil and o.count > 0 and (o.delivered or 0) >= o.count) then
			o.done = true
		end
		if o.done then
			o.locked = false
		end
	end
	return list
end

local function readObjectives(rs: Instance?): { Objective }
	local folder = rs and rs:FindFirstChild(NAMES.ObjectivesFolder)
	local list: { Objective }
	if folder and #folder:GetChildren() > 0 then
		list = {}
		for i, cfg in folder:GetChildren() do
			table.insert(list, objectiveFromConfig(cfg, i))
		end
	else
		list = objectivesFromAnchors()
	end
	table.sort(list, function(a: Objective, b: Objective): boolean
		if a.step ~= b.step then
			return a.step < b.step
		end
		return a.order < b.order
	end)
	return list
end

----------------------------------------------------------------------------
-- Snapshot
----------------------------------------------------------------------------

local function splitNames(raw: string?): { string }
	local out: { string } = {}
	if raw then
		for name in string.gmatch(raw, "[^,]+") do
			local trimmed = string.match(name, "^%s*(.-)%s*$")
			if trimmed and trimmed ~= "" then
				table.insert(out, trimmed)
			end
		end
	end
	return out
end

local function countReadyFallback(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if not (bool(p, NAMES.Inactive) or false) then
			n += 1
		end
	end
	return n
end

function StateAdapter.snapshot(): Snapshot
	local rs = roundState()
	local lp = localPlayer
	local phase: Phase = normalizePhase(str(rs, NAMES.Phase))
	local inMatchPhase = phase == "Match" or phase == "Ending"
	local stepIndex = num(rs, NAMES.StepIndex) or 1
	local stepCount = num(rs, NAMES.StepCount) or 0

	local objectives: { Objective } = if inMatchPhase then readObjectives(rs) else {}
	if stepCount == 0 then
		for _, o in objectives do
			stepCount = math.max(stepCount, o.step)
		end
	end

	local moveMode = str(lp, NAMES.MoveMode)
	local reviveProgress = num(lp, NAMES.ReviveProgress) or 0

	return {
		now = StateAdapter.serverNow(),
		phase = phase,
		phaseEndsAt = num(rs, NAMES.PhaseEndsAt),
		playersReady = num(rs, NAMES.PlayersReady) or countReadyFallback(),
		playersNeeded = num(rs, NAMES.PlayersNeeded) or DEFAULT_PLAYERS_NEEDED,
		maxPlayers = num(rs, NAMES.MaxPlayers) or DEFAULT_MAX_PLAYERS,

		matchEndsAt = num(rs, NAMES.MatchEndsAt),
		stage = str(rs, NAMES.Stage) or "Calm",
		disasterName = str(rs, NAMES.DisasterName),
		disasterHint = str(rs, NAMES.DisasterHint),
		missionName = str(rs, NAMES.MissionName),
		stepIndex = stepIndex,
		stepCount = stepCount,
		stepName = str(rs, NAMES.StepName),
		lastChance = bool(rs, NAMES.LastChance),
		objectives = objectives,

		exitOpen = bool(rs, NAMES.ExitOpen) or false,
		carrierArrivesAt = num(rs, NAMES.CarrierArrivesAt),
		carrierArrived = bool(rs, NAMES.CarrierArrived) or false,
		departureRunning = bool(rs, NAMES.DepartureRunning) or false,
		departureEndsAt = num(rs, NAMES.DepartureEndsAt),
		departureRemaining = num(rs, NAMES.DepartureRemaining),
		zoneCount = num(rs, NAMES.ZoneCount) or 0,
		zoneNeeded = num(rs, NAMES.ZoneNeeded) or 0,
		lastCall = bool(rs, NAMES.LastCall) or false,

		matchId = num(rs, NAMES.MatchId),
		resultWin = bool(rs, NAMES.ResultWin),
		resultReason = str(rs, NAMES.ResultReason),
		resultTime = num(rs, NAMES.ResultTime),
		resultDisaster = str(rs, NAMES.ResultDisaster),
		resultEscaped = splitNames(str(rs, NAMES.ResultEscaped)),

		state = str(lp, NAMES.State) or VALUES.StateLobby,
		hp = num(lp, NAMES.HP) or (num(lp, NAMES.MaxHP) or DEFAULT_MAX_HP),
		maxHp = num(lp, NAMES.MaxHP) or DEFAULT_MAX_HP,
		inactive = bool(lp, NAMES.Inactive) or false,
		beingRevived = moveMode == VALUES.MovePinned or reviveProgress > 0,
		reviveProgress = reviveProgress,
		bleedOutEndsAt = num(lp, NAMES.BleedOutEndsAt),
		respawnAt = num(lp, NAMES.RespawnAt),
		reviveCount = num(lp, NAMES.ReviveCount),
		downedCount = num(lp, NAMES.DownedCount),
	}
end

----------------------------------------------------------------------------
-- Marker targets (GDD 8.6 HUD #3): current-step anchors, exit after unlock,
-- downed teammates. Items (batteries) intentionally have NO marker (GDD §12.11).
----------------------------------------------------------------------------

local function anchorAdornee(anchor: Instance): BasePart?
	local promptPart = anchor:FindFirstChild(NAMES.PromptPart)
	if promptPart and promptPart:IsA("BasePart") then
		return promptPart
	end
	if anchor:IsA("Model") then
		return anchor.PrimaryPart or anchor:FindFirstChildWhichIsA("BasePart", true)
	elseif anchor:IsA("BasePart") then
		return anchor
	end
	return nil
end

function StateAdapter.markerTargets(snap: Snapshot): { MarkerTarget }
	local out: { MarkerTarget } = {}
	if snap.phase ~= "Match" then
		return out
	end

	-- objective anchors that are open and not done
	local objById: { [string]: Objective } = {}
	for _, o in snap.objectives do
		objById[o.id] = o
	end
	for _, anchor in CollectionService:GetTagged(NAMES.TagObjectiveAnchor) do
		if not inMap(anchor) then
			continue
		end
		local id = str(anchor, NAMES.AttrObjectiveId)
		local obj = id and objById[id]
		if not obj or obj.done or obj.locked then
			continue
		end
		-- per-anchor prompt says "not for me / closed" (e.g. socket shown only to carrier): still mark it
		local adornee = anchorAdornee(anchor)
		if not adornee then
			continue
		end
		table.insert(out, {
			key = anchor,
			kind = "Objective",
			adornee = adornee,
			label = obj.name,
			objectiveKind = obj.kind,
			anchorPart = str(anchor, NAMES.AttrAnchorPart),
			progress = num(anchor, NAMES.Progress) or obj.progress,
			held = num(anchor, NAMES.Held) or obj.held,
			required = num(anchor, NAMES.Required) or obj.required,
			baseRequired = num(anchor, NAMES.BaseRequired) or obj.baseRequired,
			override = bool(anchor, NAMES.Override) or obj.override,
			occupied = bool(anchor, NAMES.Occupied),
			delivered = num(anchor, NAMES.Delivered) or obj.delivered,
			count = num(anchor, NAMES.Count) or obj.count,
		})
	end

	-- exit zone after unlock (GDD 5.8 step 1)
	for _, zone in CollectionService:GetTagged(NAMES.TagExitZone) do
		if zone:IsA("BasePart") and inMap(zone) and (snap.exitOpen or bool(zone, NAMES.AttrExitOpen) == true) then
			table.insert(out, {
				key = zone,
				kind = "Exit",
				adornee = zone,
				label = "",
				override = false,
			})
		end
	end

	-- downed teammates (GDD 5.3: visible through walls with distance)
	for _, p in Players:GetPlayers() do
		if p ~= localPlayer and StateAdapter.isDowned(p) then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				table.insert(out, {
					key = p,
					kind = "Downed",
					adornee = hrp,
					label = p.DisplayName,
					progress = num(p, NAMES.ReviveProgress),
					override = false,
				})
			end
		end
	end
	return out
end

-- Teammates eligible as spectate targets: in match, not eliminated, has a character.
-- Ordered by UserId (GDD 5.4).
function StateAdapter.spectateCandidates(): { Player }
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		local s = StateAdapter.getPlayerState(p)
		if p ~= localPlayer and (s == VALUES.StateStanding or s == VALUES.StateDowned) and p.Character then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId
	end)
	return list
end

----------------------------------------------------------------------------
-- Remotes: HudBanner S->C (ARCHITECTURE §2)
--   { key: string, text: string, sub: string?, color: string?, duration: number? }
-- The remote is created by the server at boot; we wait for it off-thread so the
-- HUD never blocks. Returns a disconnect function.
----------------------------------------------------------------------------

function StateAdapter.onBanner(callback: (BannerPayload) -> ()): () -> ()
	local connection: RBXScriptConnection? = nil
	local cancelled = false
	task.spawn(function()
		local remote = Remotes.get("HudBanner")
		if cancelled then
			return
		end
		connection = remote.OnClientEvent:Connect(function(payload: any)
			if typeof(payload) ~= "table" or typeof(payload.text) ~= "string" then
				return
			end
			callback({
				key = if typeof(payload.key) == "string" then payload.key else "",
				text = payload.text,
				sub = if typeof(payload.sub) == "string" then payload.sub else nil,
				color = if typeof(payload.color) == "string" then payload.color else nil,
				duration = if typeof(payload.duration) == "number" then payload.duration else nil,
			})
		end)
	end)
	return function()
		cancelled = true
		if connection then
			connection:Disconnect()
		end
	end
end

return StateAdapter
