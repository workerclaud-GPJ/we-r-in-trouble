--!strict
--[[
	RoundService — Lobby → Intermission → Match → (Ending) → Result → Lobby.
	GDD §2.1, §2.4, §5.8 (win/lose order), §8.6 Round flow (min 2 players; Studio behaves
	like live unless ServerStorage has the DevMinPlayers attribute), Lobby AFK filter (60s).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Cleanup = require(Shared.Util.Cleanup)

local RoundState = require(script.Parent.RoundState)
local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local HoldService = require(script.Parent.HoldService)
local ReviveService = require(script.Parent.ReviveService)
local ItemService = require(script.Parent.ItemService)
local DisasterService = require(script.Parent.DisasterService)
local MissionService = require(script.Parent.MissionService)
local ExtractionService = require(script.Parent.ExtractionService)
local Hud = require(script.Parent.Hud)
local LootService = require(script.Parent.LootService)
local CableThrowService = require(script.Parent.CableThrowService)
local LobbyRoomService = require(script.Parent.LobbyRoomService)
local StyleService = require(script.Parent.StyleService)
local LauncherService = require(script.Parent.LauncherService)

local Attr = Contract.Attr
local Phase = Contract.Phase
local R = Config.Round

type Activity = { lastActivity: number, lastPos: Vector3?, lastPing: number, lastSample: number }
type Result = { win: boolean, reason: Types.EndReason, escaped: { Player } }

local RoundService = {}

local activity: { [Player]: Activity } = {}
local forceStartRequested = false
local forcedResult: Result? = nil
local lastDisasterId: string? = nil
local nextDisasterId: string? = nil -- debug override for the next match (setDisaster)
local lastScenarioId: string? = nil
local nextScenarioId: string? = nil -- debug override for the next match (scenario)
local matchRunning = false
local matchScope: Cleanup.Cleanup? = nil
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function playersNeeded(): number
	if RunService:IsStudio() then
		local override = ServerStorage:GetAttribute(Config.Debug.DEV_MIN_PLAYERS_ATTR)
		if typeof(override) == "number" then
			return math.max(1, math.floor(override))
		end
	end
	return R.MIN_PLAYERS_TO_START
end

----------------------------------------------------------------------------
-- Lobby AFK (GDD 2.1 / 5.9: movement > 2 studs or ActivityPing)
----------------------------------------------------------------------------

local function activityOf(player: Player): Activity
	local a = activity[player]
	if not a then
		a = { lastActivity = os.clock(), lastPos = nil, lastPing = -math.huge, lastSample = 0 }
		activity[player] = a
	end
	return a
end

local function markActive(player: Player)
	activityOf(player).lastActivity = os.clock()
	if player:GetAttribute(Attr.Inactive) == true then
		player:SetAttribute(Attr.Inactive, false)
	end
end

local function updateAfk()
	local t = os.clock()
	for _, player in Players:GetPlayers() do
		local a = activityOf(player)
		if t - a.lastSample >= R.ACTIVITY_SAMPLE_INTERVAL then
			a.lastSample = t
			local hrp = PlayerStateService.getHRP(player)
			if hrp then
				if not a.lastPos or (hrp.Position - a.lastPos).Magnitude > R.ACTIVITY_MOVE_THRESHOLD then
					a.lastPos = hrp.Position
					markActive(player)
				end
			end
		end
		local afk = t - a.lastActivity >= R.LOBBY_AFK_AFTER
		if player:GetAttribute(Attr.Inactive) ~= afk then
			player:SetAttribute(Attr.Inactive, afk)
		end
	end
end

local function readyPlayers(): { Player }
	local out: { Player } = {}
	for _, player in Players:GetPlayers() do
		if PlayerStateService.getState(player) == Contract.State.Lobby and player:GetAttribute(Attr.Inactive) ~= true then
			table.insert(out, player)
		end
	end
	return out
end

-- Features.NewMission + lobby rooms: walk into a hamster house; a room's countdown ending
-- starts the match with that room (LobbyRoomService).
local function runRoomLobby(): { Player }
	LobbyRoomService.setBusy(false)
	RoundState.set(Attr.MaxPlayers, R.MAX_PLAYERS)
	while true do
		updateAfk()
		local eligible = function(p: Player): boolean
			return PlayerStateService.getState(p) == Contract.State.Lobby and p:GetAttribute(Attr.Inactive) ~= true
		end
		LobbyRoomService.update(eligible)
		local endsAt, list = LobbyRoomService.soonest()
		RoundState.set(Attr.Phase, if endsAt then Phase.Intermission else Phase.Lobby)
		RoundState.set(Attr.PhaseEndsAt, endsAt)
		RoundState.set(Attr.PlayersReady, #list)
		RoundState.set(Attr.PlayersNeeded, 1)
		if forceStartRequested then
			forceStartRequested = false
			local ready = if #list > 0 then list else readyPlayers()
			if #ready >= 1 then
				return ready
			end
		end
		local go = LobbyRoomService.takeReady()
		if #go > 0 then
			return go
		end
		task.wait(R.MATCH_TICK)
	end
end

-- Returns the participants once the intermission completes.
local function runLobby(): { Player }
	if Config.Features.NewMission and LobbyRoomService.enabled() then
		return runRoomLobby()
	end
	RoundState.set(Attr.Phase, Phase.Lobby)
	RoundState.set(Attr.PhaseEndsAt, nil)
	RoundState.set(Attr.MaxPlayers, R.MAX_PLAYERS)
	local endsAt: number? = nil
	while true do
		updateAfk()
		local ready = readyPlayers()
		local needed = playersNeeded()
		RoundState.set(Attr.PlayersReady, #ready)
		RoundState.set(Attr.PlayersNeeded, needed)

		if forceStartRequested and #ready >= 1 then
			forceStartRequested = false
			return ready
		end
		if #ready >= needed then
			if not endsAt then
				endsAt = now() + R.INTERMISSION_TIME
				RoundState.set(Attr.Phase, Phase.Intermission)
				RoundState.set(Attr.PhaseEndsAt, endsAt)
			elseif now() >= (endsAt :: number) then
				return ready
			end
		elseif endsAt then
			endsAt = nil -- dropped below the minimum: stop counting
			RoundState.set(Attr.Phase, Phase.Lobby)
			RoundState.set(Attr.PhaseEndsAt, nil)
		end
		task.wait(R.MATCH_TICK)
	end
end

----------------------------------------------------------------------------
-- Match
----------------------------------------------------------------------------

local function pickDisaster(mission: Types.MissionDef): Types.DisasterDef?
	local forced = nextDisasterId and Config.Disasters[nextDisasterId]
	nextDisasterId = nil
	if forced then
		lastDisasterId = forced.id
		return forced
	end
	local pool: { Types.DisasterDef } = {}
	for _, id in mission.disasters do
		local def = Config.Disasters[id]
		if def then
			table.insert(pool, def)
		else
			warn(`[Round] disaster {id} has no DisasterDef`)
		end
	end
	if R.DISASTER_NO_REPEAT and #pool >= 2 and lastDisasterId then
		for i = #pool, 1, -1 do
			if pool[i].id == lastDisasterId then
				table.remove(pool, i)
			end
		end
	end
	if #pool == 0 then
		return nil
	end
	local def = pool[rng:NextInteger(1, #pool)]
	lastDisasterId = def.id
	return def
end

local function displayNames(list: { Player }): string
	local names: { string } = {}
	for _, p in list do
		table.insert(names, p.DisplayName)
	end
	return table.concat(names, ", ")
end

local function checkResult(startedAt: number, departed: boolean, inZone: { Player }): Result?
	if forcedResult then
		local r = forcedResult
		forcedResult = nil
		return r
	end
	if departed then
		return { win = true, reason = "Escaped", escaped = inZone }
	end
	if PlayerStateService.isWiped() then
		return { win = false, reason = "Wipe", escaped = {} }
	end
	if PlayerStateService.teamCount() == 0 then
		return { win = false, reason = "Abandoned", escaped = {} }
	end
	if now() - startedAt >= R.MATCH_HARD_LIMIT then
		local zone = ExtractionService.playersInZone()
		if ExtractionService.isCarrierArrived() and #zone >= 1 then
			return { win = true, reason = "Escaped", escaped = zone }
		end
		return { win = false, reason = "Collapse", escaped = {} }
	end
	return nil
end

local function cleanupMatch(scope: Cleanup.Cleanup)
	MissionService.stop()
	ExtractionService.stop()
	DisasterService.stop()
	ReviveService.reset()
	HoldService.reset()
	ItemService.reset()
	LootService.reset()
	CableThrowService.reset()
	LauncherService.reset()
	PlayerStateService.endMatch()
	scope:clean()
	MapService.unloadMap()
	RoundState.clearMatch()
	RoundState.set("Explore", nil)
	for _, player in Players:GetPlayers() do
		PlayerStateService.setLobby(player)
		markActive(player)
		activityOf(player).lastPos = nil
	end
end

-- Features.NewMission: one escape scenario per match, equal odds, never the same twice in a row.
local function pickMission(): Types.MissionDef?
	if not Config.Features.NewMission then
		return Config.Missions[R.MISSION_ID]
	end
	if not Config.Features.CapabilitySpawn then
		-- scenarios place their items with LootService; without it only the capability mission is safe
		return Config.Missions[R.NEW_MISSION_ID]
	end
	local forced = nextScenarioId and Config.Missions[nextScenarioId]
	nextScenarioId = nil
	if forced then
		lastScenarioId = forced.id
		return forced
	end
	local secret = R.SECRET_SCENARIO_ID and Config.Missions[R.SECRET_SCENARIO_ID]
	if secret and lastScenarioId ~= secret.id and rng:NextNumber() < (R.SECRET_CHANCE or 0) then
		lastScenarioId = secret.id
		print("[Round] SECRET scenario rolled!")
		return secret
	end
	local pool: { string } = {}
	for _, id in R.SCENARIO_IDS do
		if Config.Missions[id] and (id ~= lastScenarioId or #R.SCENARIO_IDS == 1) then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		return Config.Missions[R.NEW_MISSION_ID]
	end
	local id = pool[rng:NextInteger(1, #pool)]
	lastScenarioId = id
	return Config.Missions[id]
end

-- Escape scenario map setup (after loadMap, before loot/mission).
local function applyScenario(mission: Types.MissionDef, map: Model)
	MapService.hideParts(mission.hideParts)
	MapService.keepExitZones(mission.exitId)
	local camName = mission.winCamera
	if camName then
		local cam = map:FindFirstChild(camName, true)
		local point = map:FindFirstChild(Contract.Name.WinCameraPoint, true)
		if cam and cam:IsA("BasePart") and point and point:IsA("BasePart") then
			point.CFrame = cam.CFrame
		end
	end
	if mission.startFlag then
		MapService.setFlag(mission.startFlag) -- e.g. TableStart: the table spawn pads win
	end
	CableThrowService.begin(mission)
	LauncherService.begin()
	RoundState.set("Explore", if mission.explore then true else nil)
	RoundState.set("SeenItems", "")
	RoundState.set(Attr.ExitKind, mission.exitKind)
	RoundState.set(Attr.ScenarioId, mission.id)
	print(`[Round] scenario {mission.id} (exit {mission.exitKind or "Carrier"})`)
end

local function runMatch(candidates: { Player })
	local mission = pickMission()
	local disaster = mission and pickDisaster(mission)
	if not (mission and disaster) then
		warn("[Round] mission/disaster config missing")
		task.wait(5)
		return
	end
	local map = MapService.loadMap(mission.mapId)
	if not map then
		task.wait(5)
		return
	end
	applyScenario(mission, map)

	local participants: { Player } = {}
	for _, p in candidates do
		if p.Parent == Players and #participants < R.MAX_PLAYERS then
			table.insert(participants, p)
		end
	end

	local scope = Cleanup.new()
	matchScope = scope
	local matchId = (RoundState.get(Attr.MatchId) or 0) + 1
	local startedAt = now()
	matchRunning = true
	forcedResult = nil
	RoundState.set(Attr.MatchId, matchId)
	RoundState.set(Attr.Phase, Phase.Match)
	RoundState.set(Attr.PhaseEndsAt, nil)
	RoundState.set(Attr.MatchStartedAt, startedAt)
	RoundState.set(Attr.MatchEndsAt, startedAt + R.MATCH_HARD_LIMIT)

	PlayerStateService.beginMatch(participants)
	local spawns = MapService.matchSpawns(#participants)
	for i, p in participants do
		PlayerStateService.spawnInMatch(p, spawns[i])
	end

	local exitConn = MissionService.ExitUnlocked:Connect(function()
		ExtractionService.begin(mission)
		if Config.Extraction.EXIT_UNLOCK_FORCES_CRITICAL then
			DisasterService.setStage(Contract.Stage.Critical)
		end
	end)
	scope:add(function()
		exitConn:Disconnect()
	end)

	if Config.Features.CapabilitySpawn then
		LootService.spawnRound(mission) -- before MissionService.start: Deliver.open counts these items
	end
	MissionService.start(mission, startedAt)
	DisasterService.start(disaster, startedAt)
	local firstStep = mission.steps[1]
	local briefSub = if mission.id == R.SECRET_SCENARIO_ID then "🐭 Something is squeaking behind the shoe rack…" elseif mission.explore then "Find your own way out · press B for the item book" elseif firstStep then firstStep.displayName else nil
	Hud.banner("Briefing", mission.displayName, briefSub, "Good", R.BRIEFING_TIME)

	-- match loop
	local result: Result
	local last = os.clock()
	while true do
		task.wait(R.MATCH_TICK)
		local t = os.clock()
		local dt = t - last
		last = t
		PlayerStateService.update(dt)
		ItemService.update(dt)
		MissionService.update(dt)
		local departed, inZone = ExtractionService.update(dt)
		local r = checkResult(startedAt, departed, inZone)
		if r then
			result = r
			break
		end
	end

	-- end of match: stop gameplay (no more damage/bleed/respawn), keep visuals for the cinematic
	PlayerStateService.endMatch()
	MissionService.stop()
	for _, p in result.escaped do
		PlayerStateService.setEscaped(p)
	end
	pcall(StyleService.reward, participants, result.escaped, if result.win then (mission.exitKind or "Carrier") else nil) -- coins + escape journal
	RoundState.set(Attr.ResultWin, result.win)
	RoundState.set(Attr.ResultReason, if result.win and mission.exitKind then `Escaped{mission.exitKind}` else result.reason)
	RoundState.set(Attr.ResultTime, math.floor(math.min(now() - startedAt, R.MATCH_HARD_LIMIT)))
	RoundState.set(Attr.ResultDisaster, (DisasterService.current() or disaster).displayName)
	RoundState.set(Attr.ResultEscaped, displayNames(result.escaped))
	if result.win then
		RoundState.set(Attr.Phase, Phase.Ending)
		RoundState.set(Attr.PhaseEndsAt, now() + R.WIN_CINEMATIC_TIME)
		task.wait(R.WIN_CINEMATIC_TIME) -- kitchen keeps shaking behind the carrier
	end
	DisasterService.stop()
	RoundState.set(Attr.Phase, Phase.Result)
	RoundState.set(Attr.PhaseEndsAt, now() + R.RESULT_TIME)
	task.wait(R.RESULT_TIME)

	matchRunning = false
	matchScope = nil
	cleanupMatch(scope)
end

----------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------

function RoundService.isMatchRunning(): boolean
	return matchRunning
end

-- Debug: force the disaster of the next match (nil = random again).
function RoundService.setNextDisaster(id: string?)
	nextDisasterId = id
end

-- Debug: force the escape scenario of the next match (Features.NewMission). Accepts a mission
-- id, a 1-based index into Config.Round.SCENARIO_IDS, or a unique part of an id ("drain").
function RoundService.setNextScenario(key: string): string?
	local n = tonumber(key)
	if n and R.SCENARIO_IDS[n] then
		nextScenarioId = R.SCENARIO_IDS[n]
		return nextScenarioId
	end
	local found: string? = nil
	if R.SECRET_SCENARIO_ID and (string.lower(key) == "secret" or string.find(string.lower(R.SECRET_SCENARIO_ID), string.lower(key), 1, true)) then
		nextScenarioId = R.SECRET_SCENARIO_ID
		return nextScenarioId
	end
	for _, id in R.SCENARIO_IDS do
		if string.lower(id) == string.lower(key) then
			found = id
			break
		elseif string.find(string.lower(id), string.lower(key), 1, true) then
			found = id
		end
	end
	nextScenarioId = found
	return found
end

-- Debug: skip the intermission wait (needs >= 1 ready player).
function RoundService.forceStart()
	forceStartRequested = true
end

-- Debug: end the running match. Win = everyone active counts as escaped.
function RoundService.forceEnd(win: boolean)
	if not matchRunning then
		return
	end
	if win then
		local zone = ExtractionService.playersInZone()
		local escaped = if #zone > 0 then zone else PlayerStateService.activeMembers()
		forcedResult = { win = true, reason = "Escaped", escaped = escaped }
	else
		forcedResult = { win = false, reason = "Collapse", escaped = {} }
	end
end

function RoundService.start()
	MapService.ensureLobby()
	MapService.unloadMap()

	Remotes.get("ActivityPing").OnServerEvent:Connect(function(player: Player)
		local a = activityOf(player)
		local t = os.clock()
		if t - a.lastPing < R.ACTIVITY_PING_SERVER_MIN_INTERVAL then
			return
		end
		a.lastPing = t
		markActive(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		activity[player] = nil
	end)

	task.spawn(function()
		while true do
			local participants = runLobby()
			LobbyRoomService.setBusy(true)
			local ok, err = pcall(runMatch :: any, participants)
			LobbyRoomService.setBusy(false)
			if not ok then
				warn("[Round] match error:", err)
				matchRunning = false
				pcall(cleanupMatch, matchScope or Cleanup.new())
			end
		end
	end)
end

return RoundService
