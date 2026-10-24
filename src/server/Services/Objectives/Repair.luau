--!strict
--[[
	Repair — hold at any anchor until Progress = 1 (GDD §3.4 Repair).
	Rate +1/duration per counted holder per second; counted = first `maxStack`
	holders by start time across all anchors; progress is kept on release;
	credit when a holder's share reaches REPAIR_CREDIT_THRESHOLD.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local HoldService = require(script.Parent.Parent.HoldService)
local Common = require(script.Parent.Common)

local Attr = Contract.Attr

local Repair = {}

function Repair.create(ctx: Common.Context): Common.Objective
	local def = ctx.def
	local duration = def.duration or 45
	local maxStack = def.maxStack or 2
	local progress = 0
	local share: { [Player]: number } = {}
	local targets: { HoldService.HoldTarget } = {}
	local removeTicker: (() -> ())? = nil

	local function tick(dt: number)
		if not ctx.isActive() then
			return
		end
		local holders: { Player } = {}
		for _, target in targets do
			for _, p in target.holders do
				table.insert(holders, p)
			end
		end
		if #holders == 0 then
			return
		end
		table.sort(holders, function(a: Player, b: Player): boolean
			return HoldService.holdStartedAt(a) < HoldService.holdStartedAt(b)
		end)
		local counted = math.min(#holders, maxStack)
		local step = dt / duration
		progress = math.min(1, progress + step * counted)
		for i = 1, counted do
			local p = holders[i]
			share[p] = (share[p] or 0) + step
			if share[p] >= Config.Interaction.REPAIR_CREDIT_THRESHOLD then
				ctx.credit(p)
			end
		end
		ctx.set(Attr.Progress, progress)
		if progress >= 1 then
			ctx.complete()
		end
	end

	for _, anchor in ctx.anchors do
		local prompt, part = Common.ensurePrompt(anchor, def.actionText or "Hold", nil)
		if prompt and part then
			table.insert(targets, HoldService.register({
				part = part,
				prompt = prompt,
				isOpen = ctx.isActive,
				canHold = function(player: Player): boolean
					return Common.canInteract(player, part)
				end,
			}))
		end
	end

	local self: Common.Objective = {
		open = function()
			removeTicker = HoldService.addTicker(tick)
		end,
		update = function(_dt: number) end,
		forceComplete = function()
			progress = 1
			ctx.set(Attr.Progress, 1)
			ctx.complete()
		end,
		destroy = function()
			if removeTicker then
				removeTicker()
			end
			for _, target in targets do
				HoldService.unregister(target)
			end
		end,
	}
	return self
end

return Repair
