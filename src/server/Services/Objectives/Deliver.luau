--!strict
--[[
	Deliver — items spawn at random ItemSpawns (max 1 per Zone) when the step opens;
	press "Insert" at the socket anchor while holding the right item (GDD §3.4 Deliver).
	count = clamp(teamCount, minCount, maxCount); if teamCount drops:
	needed = max(delivered, min(count, max(1, teamCount))) — only ever decreases.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local PlayerStateService = require(script.Parent.Parent.PlayerStateService)
local ItemService = require(script.Parent.Parent.ItemService)
local Common = require(script.Parent.Common)

local Attr = Contract.Attr

local Deliver = {}

function Deliver.create(ctx: Common.Context): Common.Objective
	local def = ctx.def
	local itemType = def.itemType or "Battery"
	local owner = def.id
	local count = 0
	local delivered = 0
	local conns: { RBXScriptConnection } = {}

	local function publish()
		ctx.set(Attr.Delivered, delivered)
		ctx.set(Attr.Count, count)
		ctx.set(Attr.Progress, if count > 0 then math.min(1, delivered / count) else 0)
	end

	local function checkDone()
		if count > 0 and delivered >= count then
			ItemService.removeOwner(owner)
			ctx.complete()
		end
	end

	local function onInsert(player: Player, part: BasePart)
		if not ctx.isActive() or not Common.canInteract(player, part) then
			return
		end
		local firstPicker = ItemService.firstPickerOf(player)
		if not ItemService.consume(player, itemType) then
			return
		end
		delivered += 1
		ctx.credit(player)
		if firstPicker and firstPicker ~= player and firstPicker.Parent then
			ctx.credit(firstPicker)
		end
		publish()
		checkDone()
	end

	for _, anchor in ctx.anchors do
		local prompt, part = Common.ensurePrompt(anchor, def.actionText or "Insert", nil)
		if prompt and part then
			table.insert(conns, prompt.Triggered:Connect(function(player: Player)
				onInsert(player, part)
			end))
		end
	end

	local self: Common.Objective = {
		open = function()
			local minC, maxC = def.minCount or 1, def.maxCount or 4
			count = math.clamp(PlayerStateService.teamCount(), minC, math.max(minC, maxC))
			local spawned = ItemService.spawnItems(itemType, count, owner, ctx.isActive)
			if spawned < count then
				count = math.max(1, spawned) -- never require more items than exist
			end
			publish()
		end,
		update = function(_dt: number)
			if not ctx.isActive() or count == 0 then
				return
			end
			local team = PlayerStateService.teamCount()
			local needed = math.max(delivered, math.min(count, math.max(1, team)))
			if needed < count then
				count = needed
				ItemService.reduce(owner, count - delivered)
				publish()
				checkDone()
			end
		end,
		forceComplete = function()
			delivered = math.max(delivered, count)
			publish()
			ItemService.removeOwner(owner)
			ctx.complete()
		end,
		destroy = function()
			for _, c in conns do
				c:Disconnect()
			end
			ItemService.removeOwner(owner)
		end,
	}
	return self
end

return Deliver
