--!strict
--[[
	HoldService — the single server-timed hold mechanism (GDD §3.3) used by
	Repair, MultiHold and Revive.

	- Prompt Triggered = start holding, TriggerEnded = release (HoldDuration = 0).
	- One player is in at most one holder set map-wide (starting a new hold releases the old one).
	- Every HOLD_TICK the tick validates holders (Standing, within INTERACT_SERVER_RANGE,
	  target open, canHold) and then runs the registered tickers with dt.
	- The tick loop only runs while someone holds (or a keep-alive is set, e.g. debug dummies).
	- spec.toggle (holds with a hold animation, e.g. the running wheel): Triggered toggles
	  start/stop and TriggerEnded is ignored, so the player presses E once instead of holding.
	  The same TICK validation still ends it (Standing, range, open, canHold, same character).
	- Optional procedural hold animation: spec.holdAnim sets character attribute AnimState
	  while holding; spec.standPoints (Attachments) gives each holder a free slot whose
	  WorldCFrame goes to AnimStandCF (the owning client pins its HRP there). Toggle holds
	  refuse to start when every slot is taken (prompt attribute SlotsFull = true); plain
	  holds beyond the slot count still hold without animation. Cleared on every release path.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Contract = require(Shared.Contract)

local PlayerStateService = require(script.Parent.PlayerStateService)

export type HoldSpec = {
	part: BasePart, -- distance reference
	prompt: ProximityPrompt,
	isOpen: () -> boolean,
	canHold: ((player: Player) -> boolean)?,
	onChanged: (() -> ())?, -- holder set changed
	range: number?, -- server range (default INTERACT_SERVER_RANGE)
	toggle: boolean?, -- press once to start, again to stop (TriggerEnded ignored)
	holdAnim: string?, -- Contract.Attr.AnimState value while holding (Config.Animation.HOLD_ANIMS)
	standPoints: { Attachment }?, -- holder slots (HRP CFrame); must lie within range of `part`
}

export type HoldTarget = {
	spec: HoldSpec,
	holders: { Player }, -- ordered by start time
	conns: { RBXScriptConnection },
}

local HoldService = {}

local targets: { [HoldTarget]: boolean } = {}
local holderOf: { [Player]: HoldTarget } = {}
local startedAt: { [Player]: number } = {}
local tickers: { [number]: (dt: number) -> () } = {}
local nextTickerId = 0
local keepAlive: { [string]: boolean } = {}
local loopThread: thread? = nil
local animOf: { [Player]: { char: Model, slot: number, target: HoldTarget } } = {}

-- First free stand-point slot of a target (nil = full), ignoring `except`.
local function freeSlot(target: HoldTarget, except: Player?): (number?, Attachment?)
	local points = target.spec.standPoints
	if not points then
		return nil, nil
	end
	local used: { [number]: boolean } = {}
	for p, a in animOf do
		if p ~= except and a.target == target then
			used[a.slot] = true
		end
	end
	for i, att in points do
		if not used[i] and att.Parent then
			return i, att
		end
	end
	return nil, nil
end

local function hasSlots(target: HoldTarget): boolean
	local points = target.spec.standPoints
	return target.spec.holdAnim ~= nil and points ~= nil and #points > 0
end

local function refreshFull(target: HoldTarget)
	if hasSlots(target) and target.spec.prompt.Parent then
		local full = freeSlot(target, nil) == nil
		if target.spec.prompt:GetAttribute(Contract.Attr.SlotsFull) ~= full then
			target.spec.prompt:SetAttribute(Contract.Attr.SlotsFull, full)
		end
	end
end

local function clearAnim(player: Player)
	local a = animOf[player]
	if not a then
		return
	end
	animOf[player] = nil
	if a.char.Parent then
		a.char:SetAttribute(Contract.Attr.AnimState, nil)
		a.char:SetAttribute(Contract.Attr.AnimStandCF, nil)
	end
	refreshFull(a.target)
end

local function applyAnim(player: Player, target: HoldTarget)
	local spec = target.spec
	local char = player.Character
	if not (spec.holdAnim and char) then
		return
	end
	local slot, stand = 0, nil :: Attachment?
	if hasSlots(target) then
		local s, att = freeSlot(target, player)
		if not s then
			return -- every slot taken: (plain hold) counts without animation
		end
		slot, stand = s, att
	end
	animOf[player] = { char = char, slot = slot, target = target }
	char:SetAttribute(Contract.Attr.AnimStandCF, if stand then stand.WorldCFrame else nil)
	char:SetAttribute(Contract.Attr.AnimState, spec.holdAnim)
	refreshFull(target)
end

local function notify(target: HoldTarget)
	local cb = target.spec.onChanged
	if cb then
		task.spawn(cb)
	end
end

local function removeHolder(player: Player)
	local target = holderOf[player]
	if not target then
		return
	end
	holderOf[player] = nil
	startedAt[player] = nil
	clearAnim(player)
	local i = table.find(target.holders, player)
	if i then
		table.remove(target.holders, i)
	end
	notify(target)
end

local function inRange(player: Player, target: HoldTarget): boolean
	local hrp = PlayerStateService.getHRP(player)
	local part = target.spec.part
	if not hrp or not part.Parent then
		return false
	end
	local range = target.spec.range or Config.Interaction.INTERACT_SERVER_RANGE
	return (hrp.Position - part.Position).Magnitude <= range
end

local function valid(player: Player, target: HoldTarget): boolean
	if not targets[target] or not PlayerStateService.isStanding(player) or not target.spec.isOpen() then
		return false
	end
	local canHold = target.spec.canHold
	if canHold and not canHold(player) then
		return false
	end
	local a = animOf[player]
	if a and a.char ~= player.Character then
		return false -- respawned / new character
	end
	return inRange(player, target)
end

local function shouldRun(): boolean
	return next(holderOf) ~= nil or next(keepAlive) ~= nil
end

local function tick(dt: number)
	for player, target in holderOf do
		if not valid(player, target) then
			removeHolder(player)
		end
	end
	for _, fn in tickers do
		local ok, err = pcall(fn :: any, dt)
		if not ok then
			warn("[HoldService] ticker error:", err)
		end
	end
end

local function ensureLoop()
	if loopThread or not shouldRun() then
		return
	end
	loopThread = task.spawn(function()
		local last = os.clock()
		while shouldRun() do
			task.wait(Config.Interaction.HOLD_TICK)
			local t = os.clock()
			tick(t - last)
			last = t
		end
		loopThread = nil
	end)
end

function HoldService.begin(player: Player, target: HoldTarget)
	if holderOf[player] == target then
		return
	end
	if not valid(player, target) then
		return
	end
	if target.spec.toggle and hasSlots(target) and freeSlot(target, player) == nil then
		return -- wheel full (maxStack)
	end
	removeHolder(player)
	holderOf[player] = target
	startedAt[player] = os.clock()
	table.insert(target.holders, player)
	applyAnim(player, target)
	notify(target)
	ensureLoop()
end

function HoldService.release(player: Player)
	removeHolder(player)
end

function HoldService.holdStartedAt(player: Player): number
	return startedAt[player] or math.huge
end

function HoldService.isHolding(player: Player): boolean
	return holderOf[player] ~= nil
end

function HoldService.register(spec: HoldSpec): HoldTarget
	local target: HoldTarget = { spec = spec, holders = {}, conns = {} }
	targets[target] = true
	table.insert(target.conns, spec.prompt.Triggered:Connect(function(player: Player)
		if spec.toggle and holderOf[player] == target then
			removeHolder(player) -- second press stops a toggle hold
		else
			HoldService.begin(player, target)
		end
	end))
	table.insert(target.conns, spec.prompt.TriggerEnded:Connect(function(player: Player)
		if not spec.toggle and holderOf[player] == target then
			removeHolder(player)
		end
	end))
	refreshFull(target)
	return target
end

function HoldService.unregister(target: HoldTarget)
	if not targets[target] then
		return
	end
	targets[target] = nil
	for _, c in target.conns do
		c:Disconnect()
	end
	for _, player in table.clone(target.holders) do
		removeHolder(player)
	end
	if target.spec.prompt.Parent then
		target.spec.prompt:SetAttribute(Contract.Attr.SlotsFull, nil)
	end
end

function HoldService.addTicker(fn: (dt: number) -> ()): () -> ()
	nextTickerId += 1
	local id = nextTickerId
	tickers[id] = fn
	return function()
		tickers[id] = nil
	end
end

function HoldService.setKeepAlive(key: string, value: boolean)
	if value then
		keepAlive[key] = true
	else
		keepAlive[key] = nil
	end
	ensureLoop()
end

-- Round cleanup: drop every target, holder, ticker and keep-alive.
function HoldService.reset()
	for target in table.clone(targets) do
		HoldService.unregister(target)
	end
	for player in table.clone(animOf) do
		clearAnim(player)
	end
	table.clear(holderOf)
	table.clear(startedAt)
	table.clear(tickers)
	table.clear(keepAlive)
end

function HoldService.start()
	local function drop(player: Player)
		removeHolder(player)
	end
	PlayerStateService.Downed:Connect(drop)
	PlayerStateService.Eliminated:Connect(drop)
	PlayerStateService.Left:Connect(drop)
	PlayerStateService.Stunned:Connect(drop) -- a bonk knocks you off the wheel / radio
end

return HoldService
