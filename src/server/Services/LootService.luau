--!strict
--[[
	LootService — Features.CapabilitySpawn: per-round seeded item spawn by capability.

	Round start (RoundService, before MissionService.start):
	  1. seed = random (or the /dbg loot override); prints "[Loot] seed=N".
	  2. requirements = every Deliver objective of the mission: `capability` (any item with it)
	     or `itemType`; need = def.count or maxCount or minCount or 1 (worst case: max team).
	  3. plan: per requirement need + 1 items (weighted among loot entries that match), then
	     weighted random items up to Config.Loot[mapId].budget.
	  4. placement on ItemSpawn points (ItemType attribute ignored): Medium items only on
	     SizeClass "Medium" points; Small items prefer "Small" points; a point in an unused Zone
	     is preferred (max one per Zone where possible); Fallback points are used last.
	  5. verify every requirement has >= need items placed; otherwise force-spawn matching items
	     at Fallback points (reused if all are taken) and warn.
	select() is pure (Random.new(seed), no instances) so /dbg lootcheck can simulate seeds.
	Items are owned by "Loot" and pickable for the whole match.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local ItemService = require(script.Parent.ItemService)

local Attr = Contract.Attr
local OWNER = "Loot"
local MAX_SEED = 2 ^ 31 - 1

export type Requirement = { capability: string?, itemType: string?, need: number, label: string }
export type Point = { name: string, zone: string, size: string, fallback: boolean, scenarioOnly: boolean, part: BasePart? }
export type Pick = { itemType: string, point: Point, forced: boolean }
export type Selection = { picks: { Pick }, unmetBeforeForce: { string }, unmet: { string } }

local LootService = {}

local nextSeed: number? = nil -- /dbg loot <seed> before a match
local lastSeed: number? = nil
local lastMission: Types.MissionDef? = nil

----------------------------------------------------------------------------
-- Pure selection
----------------------------------------------------------------------------

local function sizeOf(itemType: string): string
	local def = Config.Items[itemType]
	return if def then def.size else "Small"
end

local function matches(req: Requirement, itemType: string): boolean
	if req.capability then
		return ItemService.hasCapability(itemType, req.capability)
	end
	return itemType == req.itemType
end

local function weightedPick(rng: Random, entries: { Types.LootEntry }): string?
	local total = 0
	for _, e in entries do
		if e.weight > 0 and Config.Items[e.itemType] then
			total += e.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	local last: string? = nil
	for _, e in entries do
		if e.weight > 0 and Config.Items[e.itemType] then
			roll -= e.weight
			last = e.itemType
			if roll <= 0 then
				return e.itemType
			end
		end
	end
	return last
end

local function fits(itemSize: string, point: Point): boolean
	return itemSize == "Small" or point.size == "Medium"
end

-- Best free point for an item: non-fallback before fallback, unused zone before used zone,
-- Small items prefer Small points (keeps Medium points for Medium items). Random among ties.
local function choosePoint(rng: Random, points: { Point }, used: { [Point]: boolean }, zonesUsed: { [string]: boolean }, itemSize: string): Point?
	local best: { Point } = {}
	local bestScore = math.huge
	for _, p in points do
		if not used[p] and fits(itemSize, p) then
			local score = (if p.fallback then 4 else 0) + (if zonesUsed[p.zone] then 2 else 0) + (if itemSize == "Small" and p.size == "Medium" then 1 else 0)
			if score < bestScore then
				bestScore = score
				best = { p }
			elseif score == bestScore then
				table.insert(best, p)
			end
		end
	end
	if #best == 0 then
		return nil
	end
	return best[rng:NextInteger(1, #best)]
end

local function unmetOf(reqs: { Requirement }, picks: { Pick }): { string }
	local out: { string } = {}
	for _, req in reqs do
		local n = 0
		for _, pick in picks do
			if matches(req, pick.itemType) then
				n += 1
			end
		end
		if n < req.need then
			table.insert(out, `{req.label} {n}/{req.need}`)
		end
	end
	return out
end

-- Pure: same (seed, loot, reqs, points) -> same result. `points` must be in a stable order.
function LootService.select(seed: number, loot: Types.LootTableDef, reqs: { Requirement }, points: { Point }): Selection
	local rng = Random.new(seed)
	type Planned = { itemType: string, required: boolean }
	local plan: { Planned } = {}
	for _, req in reqs do
		local candidates: { Types.LootEntry } = {}
		for _, e in loot.entries do
			if matches(req, e.itemType) then
				table.insert(candidates, e)
			end
		end
		local reqType = req.itemType
		if #candidates == 0 and reqType and Config.Items[reqType] then
			candidates = { { itemType = reqType, weight = 1 } }
		end
		for _ = 1, req.need + 1 do
			local t = weightedPick(rng, candidates)
			if t then
				table.insert(plan, { itemType = t, required = true })
			end
		end
	end
	while #plan < loot.budget do
		local t = weightedPick(rng, loot.entries)
		if not t then
			break
		end
		table.insert(plan, { itemType = t, required = false })
	end

	-- placement order: required before fill; Medium before Small within each group (stable)
	local order: { number } = {}
	for i in plan do
		table.insert(order, i)
	end
	table.sort(order, function(a: number, b: number): boolean
		local pa, pb = plan[a], plan[b]
		if pa.required ~= pb.required then
			return pa.required
		end
		local ma, mb = sizeOf(pa.itemType) == "Medium", sizeOf(pb.itemType) == "Medium"
		if ma ~= mb then
			return ma
		end
		return a < b
	end)

	local used: { [Point]: boolean } = {}
	local zonesUsed: { [string]: boolean } = {}
	local picks: { Pick } = {}
	for _, i in order do
		local planned = plan[i]
		local point = choosePoint(rng, points, used, zonesUsed, sizeOf(planned.itemType))
		if point then
			used[point] = true
			zonesUsed[point.zone] = true
			table.insert(picks, { itemType = planned.itemType, point = point, forced = false })
		end
	end

	-- verify + force-spawn at Fallback points
	local unmetBefore = unmetOf(reqs, picks)
	if #unmetBefore > 0 then
		local fallbacks: { Point } = {}
		for _, p in points do
			if p.fallback then
				table.insert(fallbacks, p)
			end
		end
		for _, req in reqs do
			local have = 0
			for _, pick in picks do
				if matches(req, pick.itemType) then
					have += 1
				end
			end
			-- smallest matching item type (fits any fallback point)
			local forcedType: string? = nil
			for _, e in loot.entries do
				if matches(req, e.itemType) and (forcedType == nil or (sizeOf(forcedType) == "Medium" and sizeOf(e.itemType) == "Small")) then
					forcedType = e.itemType
				end
			end
			local reqType = req.itemType
			if not forcedType and reqType and Config.Items[reqType] then
				forcedType = reqType
			end
			local ft = forcedType
			while ft and have < req.need and #fallbacks > 0 do
				local free: Point? = nil
				for _, p in fallbacks do
					if not used[p] and fits(sizeOf(ft), p) then
						free = p
						break
					end
				end
				local point = free or fallbacks[(have % #fallbacks) + 1] -- all taken: stack on a fallback
				used[point] = true
				table.insert(picks, { itemType = ft, point = point, forced = true })
				have += 1
			end
		end
	end
	return { picks = picks, unmetBeforeForce = unmetBefore, unmet = unmetOf(reqs, picks) }
end

----------------------------------------------------------------------------
-- Map / mission inputs
----------------------------------------------------------------------------

function LootService.requirements(mission: Types.MissionDef): { Requirement }
	local out: { Requirement } = {}
	for _, step in mission.steps do
		for _, obj in step.objectives do
			if obj.kind == "Deliver" then
				local need = obj.count or obj.maxCount or obj.minCount or 1
				if obj.capability then
					table.insert(out, { capability = obj.capability, itemType = nil, need = need, label = `{obj.id}:{obj.capability}` })
				elseif obj.itemType then
					table.insert(out, { capability = nil, itemType = obj.itemType, need = need, label = `{obj.id}:{obj.itemType}` })
				end
			end
		end
	end
	return out
end

local function toPoint(part: BasePart): Point
	local zone = part:GetAttribute(Attr.Zone)
	local size = part:GetAttribute(Attr.SizeClass)
	return {
		name = part:GetFullName(),
		zone = if typeof(zone) == "string" and zone ~= "" then zone else part:GetFullName(),
		size = if size == "Medium" then "Medium" else "Small",
		fallback = part:GetAttribute(Attr.Fallback) == true,
		scenarioOnly = part:GetAttribute(Attr.ScenarioOnly) == true,
		part = part,
	}
end

local function sortPoints(points: { Point }): { Point }
	table.sort(points, function(a: Point, b: Point): boolean
		return a.name < b.name
	end)
	return points
end

-- ItemSpawn points of the loaded map (live parts).
local function livePoints(): { Point }
	local out: { Point } = {}
	for _, inst in MapService.tagged(Contract.Tag.ItemSpawn) do
		if inst:IsA("BasePart") then
			table.insert(out, toPoint(inst))
		end
	end
	return sortPoints(out)
end

-- ItemSpawn points read from ServerStorage.Maps.<mapId> (no clone; lootcheck outside a match).
-- Sorted by full name: same relative order as livePoints() (only the map prefix differs).
local function sourcePoints(mapId: string): { Point }
	local out: { Point } = {}
	local maps = ServerStorage:FindFirstChild(Contract.Folder.Maps)
	local source = maps and maps:FindFirstChild(mapId)
	if not source then
		return out
	end
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, Contract.Tag.ItemSpawn) then
			table.insert(out, toPoint(d))
		end
	end
	return sortPoints(out)
end

local function currentMission(): Types.MissionDef?
	if lastMission then
		return lastMission
	end
	local id = if Config.Features.NewMission then Config.Round.NEW_MISSION_ID else Config.Round.MISSION_ID
	return Config.Missions[id]
end


-- Escape scenarios: MissionDef.fixedLoot goes on its named ScenarioOnly points first; the
-- requirements it covers are dropped and the random loot uses the remaining budget on the
-- normal (non-ScenarioOnly) points. Same seed -> same result (pure, like select()).
function LootService.plan(seed: number, mission: Types.MissionDef, loot: Types.LootTableDef, points: { Point }): Selection
	local fixed: { Pick } = {}
	local missing: { string } = {}
	for _, f in mission.fixedLoot or {} do
		local point: Point? = nil
		for _, p in points do
			if p.scenarioOnly and (p.name == f.spawn or string.sub(p.name, -(#f.spawn + 1)) == "." .. f.spawn) then
				point = p
				break
			end
		end
		if point and Config.Items[f.itemType] then
			table.insert(fixed, { itemType = f.itemType, point = point, forced = false })
		else
			table.insert(missing, `{f.itemType}@{f.spawn}`)
		end
	end
	local reqs: { Requirement } = {}
	for _, req in LootService.requirements(mission) do
		local have = 0
		for _, pick in fixed do
			if matches(req, pick.itemType) then
				have += 1
			end
		end
		if have < req.need then
			table.insert(reqs, { capability = req.capability, itemType = req.itemType, need = req.need - have, label = req.label })
		end
	end
	local open: { Point } = {}
	for _, p in points do
		if not p.scenarioOnly then
			table.insert(open, p)
		end
	end
	local budget = math.max(0, loot.budget - #fixed)
	local rest = LootService.select(seed, { budget = budget, entries = loot.entries }, reqs, open)
	local picks = table.clone(fixed)
	for _, pick in rest.picks do
		table.insert(picks, pick)
	end
	local unmet = table.clone(rest.unmet)
	for _, m in missing do
		table.insert(unmet, `fixed {m} (no ScenarioOnly ItemSpawn)`)
	end
	return { picks = picks, unmetBeforeForce = rest.unmetBeforeForce, unmet = unmet }
end

----------------------------------------------------------------------------
-- Spawning
----------------------------------------------------------------------------

local function spawnWithSeed(mission: Types.MissionDef, seed: number): number
	local loot = mission.loot or Config.Loot[mission.mapId]
	if not loot then
		warn(`[Loot] no Config.Loot entry for map {mission.mapId}`)
		return 0
	end
	ItemService.removeOwner(OWNER)
	lastSeed = seed
	print(`[Loot] seed={seed}`)
	local reqs = LootService.requirements(mission)
	local result = LootService.plan(seed, mission, loot, livePoints())
	local isOpen = function(): boolean
		return PlayerStateService.isMatchActive()
	end
	local spawned = 0
	for _, pick in result.picks do
		local part = pick.point.part
		if part and ItemService.spawnAt(pick.itemType, OWNER, isOpen, part) then
			spawned += 1
		end
		if pick.forced then
			warn(`[Loot] seed={seed}: force-spawned {pick.itemType} at Fallback {pick.point.name}`)
		end
	end
	if #result.unmet > 0 then
		warn(`[Loot] seed={seed}: requirements NOT met: {table.concat(result.unmet, ", ")} (add Fallback ItemSpawns)`)
	end
	print(`[Loot] spawned {spawned}/{#result.picks} items for {#reqs} requirement(s)`)
	return spawned
end

-- RoundService, after the map loaded and before MissionService.start (Deliver.open counts items).
function LootService.spawnRound(mission: Types.MissionDef): number
	lastMission = mission
	local seed = nextSeed or Random.new():NextInteger(1, MAX_SEED)
	nextSeed = nil
	return spawnWithSeed(mission, seed)
end

-- Debug: re-roll the running round's loot with `seed` (or use it for the next round).
function LootService.reroll(seed: number): string
	seed = math.clamp(math.floor(seed), 1, MAX_SEED)
	local mission = lastMission
	if mission and MapService.getRuntime() then
		local n = spawnWithSeed(mission, seed)
		return `re-rolled: seed={seed}, {n} items`
	end
	nextSeed = seed
	return `next round seed={seed}`
end

-- Debug: run select() for seeds 1..n (no instances). Returns a summary line.
function LootService.check(n: number, missionOverride: Types.MissionDef?): string
	local mission = missionOverride or currentMission()
	if not mission then
		return "no mission"
	end
	local loot = mission.loot or Config.Loot[mission.mapId]
	if not loot then
		return `no Config.Loot for {mission.mapId}`
	end
	local points = if MapService.getRuntime() then livePoints() else sourcePoints(mission.mapId)
	local reqs = LootService.requirements(mission)
	local failed, forcedSeeds = 0, 0
	for seed = 1, math.clamp(math.floor(n), 1, 10000) do
		local result = LootService.plan(seed, mission, loot, points)
		if #result.unmet > 0 then
			failed += 1
			warn(`[Loot] lootcheck seed={seed} FAILED: {table.concat(result.unmet, ", ")}`)
		elseif #result.unmetBeforeForce > 0 then
			forcedSeeds += 1
		end
	end
	local line = `[Loot] lootcheck {mission.id}: {n} seeds, {#points} points, {#reqs} requirement(s): failed={failed}, needed fallback force-spawn={forcedSeeds}`
	print(line)
	return line
end

function LootService.lastSeed(): number?
	return lastSeed
end

function LootService.reset()
	lastMission = nil
end

return LootService
