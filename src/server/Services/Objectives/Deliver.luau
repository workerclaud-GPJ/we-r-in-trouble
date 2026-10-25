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
	Escape-scenario extras:
	  keepItem       the held item is a tool (scissors): each press counts once and keeps the item;
	                 count = clamp(teamCount, minCount, maxCount) e.g. one screw per hamster.
	  holdDuration   prompt hold time per press.
	  requiresFlag   MapService flag needed first (e.g. "ScissorsSharp"), else blockedHint.
	  blockedWhileOn Switch Kind that must be off (e.g. "Faucet"), else blockedHint.
	  progressBanner team banner per press while not done ("{n}" / "{count}").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local PlayerStateService = require(script.Parent.Parent.PlayerStateService)
local ItemService = require(script.Parent.Parent.ItemService)
local MapService = require(script.Parent.Parent.MapService)
local LauncherService = require(script.Parent.Parent.LauncherService)
local Hud = require(script.Parent.Parent.Hud)
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
		-- WantedItemController: items with this capability / type get a marker while the step is open
		ctx.set("Wants", capability or itemType)
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
		local held = player:GetAttribute(Attr.Holding)
		local holdsRight = typeof(held) == "string" and held ~= ""
			and (if capability then ItemService.hasCapability(held, capability) else held == itemType)
		-- requirement hints only for a hamster holding the right item (others just get nothing)
		if holdsRight and def.requiresFlag and not MapService.hasFlag(def.requiresFlag) then
			Hud.bannerTo(player, "Blocked" .. def.id, def.blockedHint or "Not yet…", nil, "Warn", 2.5)
			return
		end
		if holdsRight and def.blockedWhileOn and LauncherService.isOn(def.blockedWhileOn) then
			Hud.bannerTo(player, "Blocked" .. def.id, def.blockedHint or "Not yet…", nil, "Warn", 2.5)
			return
		end
		local firstPicker = ItemService.firstPickerOf(player)
		if def.keepItem then
			if not holdsRight then
				return
			end
		elseif capability then
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
		if def.progressBanner and delivered < count then
			local text = string.gsub(string.gsub(def.progressBanner, "{n}", tostring(delivered)), "{count}", tostring(count))
			Hud.banner("Progress" .. def.id, text, nil, "Good", 1.6)
		end
		checkDone()
	end

	for _, anchor in ctx.anchors do
		local prompt, part = Common.ensurePrompt(anchor, def.actionText or "Insert", nil)
		if prompt and def.holdDuration then
			prompt.HoldDuration = def.holdDuration
		end
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
			if def.keepItem then
				spawned = count -- a tool is reused for every press: never spawn extra copies
			elseif lootSpawned then
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
