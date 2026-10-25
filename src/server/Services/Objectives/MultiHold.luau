--!strict
--[[
	MultiHold (Cumulative) — different players must hold different anchors at the
	same time (GDD §3.4 MultiHold, §3.5 fallback, §8.4). Each tick:
	  base     = min(anchorCount, activeCount)
	  override = assist and stepElapsed >= MULTIHOLD_ASSIST_AFTER and base >= 3 -> base - 1 (min MULTIHOLD_ASSIST_MIN)
	  activeCount <= 1 -> 1;   required = max(1, …)
	Progress += dt/holdTime while Held >= Required; otherwise it pauses (never decreases).
	Debug dummy holders (spawnDummyHolder) count as held anchors.
	needsPower = "<objective id>": progress also pauses while that objective's anchors have no power
	(Repair sustain Progress <= 0, e.g. nobody runs the wheel); ignored when only one hamster is
	active. Holders get noPowerHint every few seconds while it is paused for lack of power.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local PlayerStateService = require(script.Parent.Parent.PlayerStateService)
local HoldService = require(script.Parent.Parent.HoldService)
local Hud = require(script.Parent.Parent.Hud)
local Common = require(script.Parent.Common)

local Attr = Contract.Attr
local I = Config.Interaction

type Slot = { anchor: Model, letter: string, target: HoldService.HoldTarget }

local MultiHold = {}

function MultiHold.create(ctx: Common.Context): Common.Objective
	local def = ctx.def
	local holdTime = def.holdTime or 30
	local anchorCount = def.anchorCount or #ctx.anchors
	local progress = 0
	local slots: { Slot } = {}
	local dummies: { [string]: boolean } = {}
	local removeTicker: (() -> ())? = nil
	local keepAliveKey = "MultiHoldDummy:" .. def.id

	if #ctx.anchors < anchorCount then
		warn(`[Mission] {def.id}: {#ctx.anchors} anchors in map, data expects {anchorCount}`)
		anchorCount = math.max(1, #ctx.anchors)
	end

	local function computeRequired(): (number, number, boolean)
		local active = PlayerStateService.activeCount()
		-- needsPower: one hamster has to keep the generator running, so it never counts as a holder
		local holders = if def.needsPower and active >= 2 then active - 1 else active
		local base = math.min(anchorCount, holders)
		local required = base
		local override = false
		if def.assist and base >= 3 and Workspace:GetServerTimeNow() - ctx.stepOpenedAt() >= I.MULTIHOLD_ASSIST_AFTER then
			required = math.max(I.MULTIHOLD_ASSIST_MIN, base - 1)
			override = true
		end
		if holders <= 1 then
			required = 1
		end
		return math.max(1, required), math.max(1, base), override
	end

	local function heldCount(): number
		local held = 0
		for _, slot in slots do
			if #slot.target.holders > 0 or dummies[slot.letter] then
				held += 1
			end
		end
		return held
	end

	local function publish(): (number, number)
		local required, base, override = computeRequired()
		local held = heldCount()
		ctx.set(Attr.Held, held)
		ctx.set(Attr.Required, required)
		ctx.set(Attr.BaseRequired, base)
		ctx.set(Attr.Override, override)
		for _, slot in slots do
			ctx.setAnchor(slot.anchor, Attr.Occupied, #slot.target.holders > 0 or dummies[slot.letter] == true)
		end
		return held, required
	end

	local function clearDummies()
		table.clear(dummies)
		HoldService.setKeepAlive(keepAliveKey, false)
	end

	local lastHint: { [Player]: number } = {}
	local function powered(): boolean
		local src = def.needsPower
		if not src or PlayerStateService.activeCount() <= 1 then
			return true
		end
		for _, a in CollectionService:GetTagged(Contract.Tag.ObjectiveAnchor) do
			if a:GetAttribute(Attr.ObjectiveId) == src and a:IsDescendantOf(Workspace) then
				local pr = a:GetAttribute(Attr.Progress)
				if typeof(pr) == "number" and pr > 0 then
					return true
				end
			end
		end
		return false
	end

	local function tick(dt: number)
		if not ctx.isActive() then
			return
		end
		local held, required = publish()
		local hasPower = powered()
		ctx.set("NoPower", not hasPower)
		if not hasPower and held > 0 then
			local t = os.clock()
			for _, slot in slots do
				for _, p in slot.target.holders do
					if t - (lastHint[p] or 0) > 4 then
						lastHint[p] = t
						Hud.bannerTo(p, "NoPower" .. def.id, def.noPowerHint or "No power!", nil, "Warn", 2.5)
					end
				end
			end
		end
		if held >= required and hasPower then
			progress = math.min(1, progress + dt / holdTime)
			ctx.set(Attr.Progress, progress)
			for _, slot in slots do
				for _, p in slot.target.holders do
					ctx.credit(p)
				end
			end
			if progress >= 1 then
				clearDummies()
				ctx.complete()
			end
		end
	end

	for i, anchor in ctx.anchors do
		local letterAttr = anchor:GetAttribute(Attr.Part)
		local letter = if typeof(letterAttr) == "string" then string.upper(letterAttr) else string.char(64 + i)
		local prompt, part = Common.ensurePrompt(anchor, def.actionText or "Hold", nil)
		if prompt and part then
			local target = HoldService.register({
				part = part,
				prompt = prompt,
				isOpen = ctx.isActive,
				canHold = function(player: Player): boolean
					return Common.canInteract(player, part)
				end,
				onChanged = function()
					if ctx.isActive() then
						publish()
					end
				end,
			})
			table.insert(slots, { anchor = anchor, letter = letter, target = target })
		end
	end

	local self: Common.Objective = {
		open = function()
			removeTicker = HoldService.addTicker(tick)
			publish()
		end,
		update = function(_dt: number)
			if ctx.isActive() then
				publish()
			end
		end,
		forceComplete = function()
			progress = 1
			ctx.set(Attr.Progress, 1)
			clearDummies()
			ctx.complete()
		end,
		destroy = function()
			clearDummies()
			if removeTicker then
				removeTicker()
			end
			for _, slot in slots do
				HoldService.unregister(slot.target)
			end
		end,
		toggleDummy = function(letter: string): boolean
			local key = string.upper(letter)
			local exists = false
			for _, slot in slots do
				if slot.letter == key then
					exists = true
				end
			end
			if not exists or not ctx.isActive() then
				return false
			end
			if dummies[key] then
				dummies[key] = nil
			else
				dummies[key] = true
			end
			HoldService.setKeepAlive(keepAliveKey, next(dummies) ~= nil)
			publish()
			return true
		end,
	}
	return self
end

return MultiHold
