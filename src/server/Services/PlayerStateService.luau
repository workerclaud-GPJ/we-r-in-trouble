--!strict
--[[
	PlayerStateService — owns player attributes (State, HP, SpeedMult, MoveMode, …),
	character loading (CharacterAutoLoads = false), Roblox death/reset neutralisation,
	Downed + bleed-out, Eliminated + flat respawn, team counts and Wipe rule.
	GDD §5.1–5.5, §3.5 (solo fallback), §8.6 Player state / Speed rows.
	Revive holds live in ReviveService (depends on HoldService).
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local MapService = require(script.Parent.MapService)

local Attr = Contract.Attr
local State = Contract.State
local MoveMode = Contract.MoveMode
local P = Config.Player

type Record = {
	participant: boolean,
	bleedRemaining: number,
	beingRevived: boolean,
	eliminations: number,
	token: number, -- bumps on every state transition that invalidates pending timers/loads
	modifiers: { [string]: number },
	charConns: { RBXScriptConnection },
}

local PlayerStateService = {}

-- Fired synchronously-first (Signal uses task.spawn) so listeners can still read the character.
PlayerStateService.Downed = Signal.new() :: Signal.Signal<Player>
PlayerStateService.Eliminated = Signal.new() :: Signal.Signal<Player>
PlayerStateService.Left = Signal.new() :: Signal.Signal<Player>
PlayerStateService.Revived = Signal.new() :: Signal.Signal<Player>
PlayerStateService.Stunned = Signal.new() :: Signal.Signal<Player> -- fired when a stun starts (HoldService drops holds)

local records: { [Player]: Record } = {}
local stunToken: { [Player]: number } = {} -- bumps on every stun start/clear; stale timers no-op
local globalModifiers: { [string]: number } = {}
local matchActive = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rec(player: Player): Record?
	return records[player]
end

----------------------------------------------------------------------------
-- Speed (GDD 5.5): server owns SpeedMult/MoveMode, client writes WalkSpeed
----------------------------------------------------------------------------

local function recomputeSpeed(player: Player)
	local r = rec(player)
	if not r then
		return
	end
	local mult = 1
	for _, m in globalModifiers do
		mult *= m
	end
	for _, m in r.modifiers do
		mult *= m
	end
	player:SetAttribute(Attr.SpeedMult, mult)
end

function PlayerStateService.setGlobalSpeedModifier(key: string, mult: number?)
	if mult then
		globalModifiers[key] = mult
	else
		globalModifiers[key] = nil
	end
	for player in records do
		recomputeSpeed(player)
	end
end

function PlayerStateService.setPlayerSpeedModifier(player: Player, key: string, mult: number?)
	local r = rec(player)
	if r then
		if mult then
			r.modifiers[key] = mult
		else
			r.modifiers[key] = nil
		end
		recomputeSpeed(player)
	end
end

----------------------------------------------------------------------------
-- Queries
----------------------------------------------------------------------------

function PlayerStateService.getState(player: Player): string
	local s = player:GetAttribute(Attr.State)
	return if typeof(s) == "string" then s else State.Lobby
end

function PlayerStateService.isStanding(player: Player): boolean
	return PlayerStateService.getState(player) == State.Standing and player.Character ~= nil
end

function PlayerStateService.isParticipant(player: Player): boolean
	local r = rec(player)
	return r ~= nil and r.participant
end

function PlayerStateService.isMatchActive(): boolean
	return matchActive
end

-- Team members = participants still in the server (no in-match AFK in Deadline build).
function PlayerStateService.teamMembers(): { Player }
	local out: { Player } = {}
	for player, r in records do
		if r.participant and player.Parent == Players then
			table.insert(out, player)
		end
	end
	table.sort(out, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId
	end)
	return out
end

function PlayerStateService.teamCount(): number
	return #PlayerStateService.teamMembers()
end

-- Not Eliminated and has a character (Standing + Downed). GDD glossary `activeCount`.
function PlayerStateService.activeMembers(): { Player }
	local out: { Player } = {}
	for _, player in PlayerStateService.teamMembers() do
		local s = PlayerStateService.getState(player)
		if (s == State.Standing or s == State.Downed) and player.Character then
			table.insert(out, player)
		end
	end
	return out
end

function PlayerStateService.activeCount(): number
	return #PlayerStateService.activeMembers()
end

function PlayerStateService.standingMembers(): { Player }
	local out: { Player } = {}
	for _, player in PlayerStateService.teamMembers() do
		if PlayerStateService.isStanding(player) then
			table.insert(out, player)
		end
	end
	return out
end

-- GDD 5.8 lose #2. Never applies when teamCount = 1 (3.5).
function PlayerStateService.isWiped(): boolean
	local team = PlayerStateService.teamMembers()
	if #team < 2 then
		return false
	end
	for _, player in team do
		local s = PlayerStateService.getState(player)
		if P.TEAM_WIPE_RULE == "NoneStanding" then
			if s == State.Standing then
				return false
			end
		elseif s ~= State.Downed then -- AllDowned: someone Standing or waiting to respawn
			return false
		end
	end
	return true
end

function PlayerStateService.getHRP(player: Player): BasePart?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

function PlayerStateService.addStat(player: Player, attr: string, amount: number)
	local v = player:GetAttribute(attr)
	player:SetAttribute(attr, (if typeof(v) == "number" then v else 0) + amount)
end

----------------------------------------------------------------------------
-- Character loading
----------------------------------------------------------------------------

local function applyCollisionGroup(inst: Instance)
	if inst:IsA("BasePart") then
		inst.CollisionGroup = Contract.CollisionGroup.Players
	end
end

local onDied: (player: Player) -> () -- forward declaration

local function setupCharacter(player: Player, char: Model)
	local r = rec(player)
	if not r then
		return
	end
	for _, c in r.charConns do
		c:Disconnect()
	end
	table.clear(r.charConns)

	for _, d in char:GetDescendants() do
		applyCollisionGroup(d)
	end
	table.insert(r.charConns, char.DescendantAdded:Connect(applyCollisionGroup))

	local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.BreakJointsOnDeath = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid.Health = humanoid.MaxHealth
		table.insert(r.charConns, humanoid.Died:Connect(function()
			onDied(player)
		end))
	end
end

-- LoadCharacter + PivotTo. Stale loads (token changed meanwhile) are ignored.
local function loadCharacterAt(player: Player, cf: CFrame)
	local r = rec(player)
	if not r then
		return
	end
	local token = r.token
	-- safety net if StreamingEnabled is ever turned back on (lobby and map are 3000 studs apart)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position)
	end)
	if rec(player) ~= r or r.token ~= token then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok and string.find(tostring(err), "not a valid member", 1, true) then
		ok, err = pcall(function()
			(player :: any):LoadCharacter() -- engines without LoadCharacterAsync
		end)
	end
	if not ok then
		warn("[PlayerState] LoadCharacter failed:", err)
		return
	end
	if rec(player) ~= r or r.token ~= token then
		return
	end
	local char = player.Character
	if char then
		setupCharacter(player, char)
		char:PivotTo(cf)
	end
end

local function removeCharacter(player: Player)
	local char = player.Character
	if char then
		player.Character = nil
		char:Destroy()
	end
end

local function setProtection(player: Player, seconds: number)
	player:SetAttribute(Attr.ProtectedUntil, now() + seconds)
end

local function clearStun(player: Player)
	stunToken[player] = (stunToken[player] or 0) + 1
	if player:GetAttribute(Attr.Stunned) ~= nil then
		player:SetAttribute(Attr.Stunned, nil)
	end
end

local function resetAttributes(player: Player)
	clearStun(player)
	player:SetAttribute(Attr.HP, P.MAX_HP)
	player:SetAttribute(Attr.MaxHP, P.MAX_HP)
	player:SetAttribute(Attr.MoveMode, MoveMode.Normal)
	player:SetAttribute(Attr.Holding, "")
	player:SetAttribute(Attr.ReviveProgress, 0)
	player:SetAttribute(Attr.BleedOutEndsAt, nil)
	player:SetAttribute(Attr.RespawnAt, nil)
	player:SetAttribute(Attr.ProtectedUntil, nil)
end

local function resetStats(player: Player)
	player:SetAttribute(Attr.ReviveCount, 0)
	player:SetAttribute(Attr.DownedCount, 0)
	player:SetAttribute(Attr.Credits, 0)
end

----------------------------------------------------------------------------
-- Transitions
----------------------------------------------------------------------------

function PlayerStateService.setLobby(player: Player)
	local r = rec(player)
	if not r then
		return
	end
	r.token += 1
	r.participant = false
	r.beingRevived = false
	table.clear(r.modifiers)
	resetAttributes(player)
	player:SetAttribute(Attr.State, State.Lobby)
	recomputeSpeed(player)
	task.spawn(loadCharacterAt, player, MapService.lobbyCFrame())
end

function PlayerStateService.beginMatch(participants: { Player })
	matchActive = true
	table.clear(globalModifiers)
	for _, player in participants do
		local r = rec(player)
		if r then
			r.participant = true
			r.eliminations = 0
			resetStats(player)
		end
	end
end

-- Stops all match timers; players keep their characters until RoundService resets them.
function PlayerStateService.endMatch()
	matchActive = false
	table.clear(globalModifiers)
	for player, r in records do
		r.token += 1
		r.beingRevived = false
		table.clear(r.modifiers)
		clearStun(player)
		player:SetAttribute(Attr.RespawnAt, nil)
		player:SetAttribute(Attr.BleedOutEndsAt, nil)
		recomputeSpeed(player)
	end
end

function PlayerStateService.spawnInMatch(player: Player, cf: CFrame)
	local r = rec(player)
	if not r then
		return
	end
	r.token += 1
	r.beingRevived = false
	resetAttributes(player)
	player:SetAttribute(Attr.State, State.Standing)
	setProtection(player, P.SPAWN_PROTECTION)
	recomputeSpeed(player)
	task.spawn(loadCharacterAt, player, cf)
end

local function respawnDelay(r: Record, extra: number): number
	local base = math.min(P.RESPAWN_BASE + P.RESPAWN_STEP * (r.eliminations - 1), P.RESPAWN_MAX)
	return base + extra
end

function PlayerStateService.eliminate(player: Player, extraDelay: number?)
	local r = rec(player)
	if not (r and r.participant and matchActive) then
		return
	end
	local s = PlayerStateService.getState(player)
	if s ~= State.Standing and s ~= State.Downed then
		return
	end
	r.token += 1
	r.beingRevived = false
	r.eliminations += 1
	clearStun(player)
	player:SetAttribute(Attr.State, State.Eliminated)
	player:SetAttribute(Attr.MoveMode, MoveMode.Normal)
	player:SetAttribute(Attr.BleedOutEndsAt, nil)
	player:SetAttribute(Attr.ReviveProgress, 0)
	PlayerStateService.Eliminated:Fire(player) -- listeners drop items / release holds before the character goes
	local poofToken = r.token
	task.delay(P.POOF_DELAY, function()
		-- character stays POOF_DELAY s so clients can emit the Poof at UpperTorso.PoofAttachment
		if rec(player) == r and r.token == poofToken then
			removeCharacter(player)
		end
	end)

	local delay = respawnDelay(r, extraDelay or 0)
	player:SetAttribute(Attr.RespawnAt, now() + delay)
	local token = r.token
	task.delay(delay, function()
		if rec(player) == r and r.token == token and matchActive and r.participant and player.Parent == Players then
			PlayerStateService.spawnInMatch(player, MapService.pickSpawn())
		end
	end)
end

function PlayerStateService.down(player: Player)
	local r = rec(player)
	if not (r and r.participant and matchActive) or PlayerStateService.getState(player) ~= State.Standing then
		return
	end
	PlayerStateService.addStat(player, Attr.DownedCount, 1)
	-- Solo fallback (3.5): nobody can revive -> Eliminated immediately, no Wipe
	if PlayerStateService.teamCount() <= 1 then
		player:SetAttribute(Attr.HP, 0)
		PlayerStateService.eliminate(player)
		return
	end
	r.token += 1
	clearStun(player) -- Downed keeps its own behaviour; a stun never overrides it
	r.bleedRemaining = P.BLEED_OUT_TIME
	r.beingRevived = false
	player:SetAttribute(Attr.HP, 0)
	player:SetAttribute(Attr.State, State.Downed)
	player:SetAttribute(Attr.MoveMode, MoveMode.Downed)
	player:SetAttribute(Attr.ReviveProgress, 0)
	player:SetAttribute(Attr.BleedOutEndsAt, now() + r.bleedRemaining)
	PlayerStateService.Downed:Fire(player)
end

function PlayerStateService.revive(target: Player, reviver: Player?)
	local r = rec(target)
	if not (r and matchActive) or PlayerStateService.getState(target) ~= State.Downed then
		return
	end
	r.token += 1
	r.beingRevived = false
	target:SetAttribute(Attr.State, State.Standing)
	target:SetAttribute(Attr.HP, P.REVIVED_HP)
	target:SetAttribute(Attr.MoveMode, MoveMode.Normal)
	target:SetAttribute(Attr.BleedOutEndsAt, nil)
	target:SetAttribute(Attr.ReviveProgress, 0)
	setProtection(target, P.REVIVE_PROTECTION)
	if reviver then
		PlayerStateService.addStat(reviver, Attr.ReviveCount, 1)
	end
	PlayerStateService.Revived:Fire(target)
end

-- Called by ReviveService: pauses bleed-out and pins the downed player (GDD 5.3).
function PlayerStateService.setBeingRevived(player: Player, value: boolean)
	local r = rec(player)
	if not r or r.beingRevived == value or PlayerStateService.getState(player) ~= State.Downed then
		return
	end
	r.beingRevived = value
	player:SetAttribute(Attr.MoveMode, if value then MoveMode.Pinned else MoveMode.Downed)
	player:SetAttribute(Attr.BleedOutEndsAt, now() + r.bleedRemaining)
end

function PlayerStateService.setEscaped(player: Player)
	if PlayerStateService.isParticipant(player) then
		clearStun(player)
		player:SetAttribute(Attr.State, State.Escaped)
		player:SetAttribute(Attr.MoveMode, MoveMode.Normal)
		player:SetAttribute(Attr.BleedOutEndsAt, nil)
	end
end

----------------------------------------------------------------------------
-- Damage (GDD 5.2)
----------------------------------------------------------------------------

function PlayerStateService.isProtected(player: Player): boolean
	local untilT = player:GetAttribute(Attr.ProtectedUntil)
	return typeof(untilT) == "number" and now() < untilT
end

-- quiet = true: no PlayerHit ("Bonk!") broadcast (damage over time, e.g. drowning).
function PlayerStateService.damage(player: Player, amount: number, quiet: boolean?): boolean
	if not matchActive or amount <= 0 or not PlayerStateService.isParticipant(player) then
		return false
	end
	if not PlayerStateService.isStanding(player) or PlayerStateService.isProtected(player) then
		return false
	end
	local hp = player:GetAttribute(Attr.HP)
	local newHp = math.max(0, (if typeof(hp) == "number" then hp else P.MAX_HP) - amount)
	player:SetAttribute(Attr.HP, newHp)
	if not quiet then
		local hrp = PlayerStateService.getHRP(player)
		Remotes.get("PlayerHit"):FireAllClients({
			userId = player.UserId,
			amount = amount,
			position = if hrp then hrp.Position else Vector3.zero,
		})
	end
	if newHp <= 0 then
		PlayerStateService.down(player)
	end
	return true
end

-- Short "dizzy" stun (falling-object hit that did not down the player). Standing only;
-- a re-hit refreshes the timer (no stacking). MovementController slows + blocks jump,
-- dash is refused, CharacterFx shows the orbiting stars, ProceduralAnim plays Dizzy.
function PlayerStateService.stun(player: Player, duration: number?)
	if not matchActive or not PlayerStateService.isStanding(player) then
		return
	end
	local token = (stunToken[player] or 0) + 1
	stunToken[player] = token
	player:SetAttribute(Attr.Stunned, true)
	PlayerStateService.Stunned:Fire(player)
	task.delay(duration or P.STUN_DURATION, function()
		if stunToken[player] == token then
			clearStun(player)
		end
	end)
end

function PlayerStateService.isStunned(player: Player): boolean
	return player:GetAttribute(Attr.Stunned) == true
end

-- Debug: set HP directly (<= 0 downs the player).
function PlayerStateService.setHP(player: Player, value: number)
	if not PlayerStateService.isStanding(player) then
		return
	end
	local hp = math.clamp(value, 0, P.MAX_HP)
	player:SetAttribute(Attr.HP, hp)
	if hp <= 0 then
		PlayerStateService.down(player)
	end
end

----------------------------------------------------------------------------
-- Roblox death (reset / Health = 0 / falling into the void)
----------------------------------------------------------------------------

onDied = function(player: Player)
	local r = rec(player)
	if not r then
		return
	end
	local s = PlayerStateService.getState(player)
	if s == State.Standing then
		PlayerStateService.eliminate(player)
	elseif s == State.Downed then
		-- no advantage from dying while downed: remaining bleed-out is added to the delay
		PlayerStateService.eliminate(player, math.max(0, r.bleedRemaining))
	elseif s == State.Lobby then
		local token = r.token
		task.delay(Config.Round.LOBBY_RELOAD_DELAY, function()
			if rec(player) == r and r.token == token and PlayerStateService.getState(player) == State.Lobby then
				PlayerStateService.setLobby(player)
			end
		end)
	end
end

----------------------------------------------------------------------------
-- Match tick (called by RoundService every MATCH_TICK)
----------------------------------------------------------------------------

function PlayerStateService.update(dt: number)
	if not matchActive then
		return
	end
	local killY = MapService.killY()
	for _, player in PlayerStateService.teamMembers() do
		local r = records[player]
		local s = PlayerStateService.getState(player)
		if s == State.Downed and not r.beingRevived then
			r.bleedRemaining -= dt
			if r.bleedRemaining <= 0 then
				PlayerStateService.eliminate(player)
				continue
			end
		end
		if s == State.Standing or s == State.Downed then
			local hrp = PlayerStateService.getHRP(player)
			if hrp and hrp.Position.Y < killY then
				PlayerStateService.eliminate(player)
			end
		end
	end
end

----------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	records[player] = {
		participant = false,
		bleedRemaining = 0,
		beingRevived = false,
		eliminations = 0,
		token = 0,
		modifiers = {},
		charConns = {},
	}
	player:SetAttribute(Attr.Inactive, false)
	resetStats(player)
	PlayerStateService.setLobby(player)
end

local function onPlayerRemoving(player: Player)
	local r = records[player]
	if not r then
		return
	end
	PlayerStateService.Left:Fire(player) -- character still exists here
	r.participant = false
	r.token += 1
	for _, c in r.charConns do
		c:Disconnect()
	end
	records[player] = nil
	stunToken[player] = nil
end

function PlayerStateService.start()
	Players.CharacterAutoLoads = false
	pcall(function()
		PhysicsService:RegisterCollisionGroup(Contract.CollisionGroup.Players)
	end)
	PhysicsService:CollisionGroupSetCollidable(Contract.CollisionGroup.Players, Contract.CollisionGroup.Players, false)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerStateService
