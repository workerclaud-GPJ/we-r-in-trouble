--!strict
--[[
	HoldService — the single server-timed hold mechanism (GDD §3.3) used by
	Repair, MultiHold and Revive.

	- Prompt Triggered = start holding, TriggerEnded = release (HoldDuration = 0).
	- One player is in at most one holder set map-wide (starting a new hold releases the old one).
	- Every HOLD_TICK the tick validates holders (Standing, within INTERACT_SERVER_RANGE,
	  target open, canHold) and then runs the registered tickers with dt.
	- The tick loop only runs while someone holds (or a keep-alive is set, e.g. debug dummies).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local PlayerStateService = require(script.Parent.PlayerStateService)

export type HoldSpec = {
	part: BasePart, -- distance reference
	prompt: ProximityPrompt,
	isOpen: () -> boolean,
	canHold: ((player: Player) -> boolean)?,
	onChanged: (() -> ())?, -- holder set changed
	range: number?, -- server range (default INTERACT_SERVER_RANGE)
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
	removeHolder(player)
	holderOf[player] = target
	startedAt[player] = os.clock()
	table.insert(target.holders, player)
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
		HoldService.begin(player, target)
	end))
	table.insert(target.conns, spec.prompt.TriggerEnded:Connect(function(player: Player)
		if holderOf[player] == target then
			removeHolder(player)
		end
	end))
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
end

return HoldService
