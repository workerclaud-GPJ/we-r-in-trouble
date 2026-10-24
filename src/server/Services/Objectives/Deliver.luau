--!strict
--[[
	Deliver — items spawn at random ItemSpawns (max 1 per Zone) when the step opens;
	press "Insert" at the socket anchor while holding the right item (GDD §3.4 Deliver).
	count = clamp(teamCount, minCount, maxCount); if teamCount drops:
	needed = max(delivered, min(count, max(1, teamCount))) — only ever decreases.
	Optional `count` (fixed count instead of the team clamp) and `capability`: any held item
	with that capability is accepted (ItemService.consumeCapability); the itemType path is unchanged.
	Features.CapabilitySpawn: items come from LootService (owner "Loot") at round start, so
	open() does not spawn; count is capped by the matching items present in the map.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local PlayerStateService = require(script.Parent.Parent.PlayerStateService)
local ItemService = require(script.Parent.Parent.ItemService)
local Common = require(script.Parent.Common)

local Attr = Contract.Attr

local Deliver = {}

function Deliver.create(ctx: Common.Context): Common.Objective
	local def = ctx.def
	local itemType = def.itemType or "Battery"
	local capability = def.capability
	local lootSpawned = Config.Features.CapabilitySpawn
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
		if capability then
			if not ItemService.consumeCapability(player, capability) then
				return
			end
		elseif not ItemService.consume(player, itemType) then
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
			if def.count then
				count = math.max(1, def.count)
			end
			local spawned: number
			if lootSpawned then
				spawned = if capability then ItemService.countCapability(capability) else ItemService.countType(itemType)
				if spawned < count and (capability == nil or ItemService.hasCapability(itemType, capability)) then
					-- safety net (no Config.Loot entry for the map, LootService failed): legacy spawn tops
					-- up so the step can never require items that do not exist
					spawned += ItemService.spawnItems(itemType, count - spawned, owner, ctx.isActive)
				end
			else
				spawned = ItemService.spawnItems(itemType, count, owner, ctx.isActive)
			end
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
