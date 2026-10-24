--!strict
--[[
	EventService — random events (Config/Events): 1–2 per match during Active, independent
	of the disaster. Server decides placement, timing, hits and speed; clients draw them
	from the WorldEvent remote (HazardFxController) and own their knockback / no-stop movement.

	  IceLane  (FridgeBurst): lane = Part tagged EventLane with EventId (LookVector = slide
	           direction, Size.X = band width, Size.Z = length, centre Y = floor); the ice
	           sub-lane is aimed at a standing player inside the band when there is one.
	           No marker -> a lane through a random standing player in a random direction.
	           After `telegraph` s the cubes sweep the lane in `duration` s; each player is hit
	           once: damage + knockback (Knockback payload to that player).
	  OilPatch (SpilledOil): floor point near a random standing player; after `telegraph` s,
	           players inside get SpeedMult x speedMult for `duration` s (client: no stopping).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Cleanup = require(Shared.Util.Cleanup)
local Geometry = require(Shared.Util.Geometry)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local Hud = require(script.Parent.Hud)

local E = Config.Events
local Attr = Contract.Attr

local EventService = {}

local eventScope: Cleanup.Cleanup? = nil
local serial = 0
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function scopeNow(): Cleanup.Cleanup
	local existing = eventScope
	if existing then
		return existing
	end
	local s = Cleanup.new()
	eventScope = s
	return s
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local runtime = MapService.getRuntime()
	if runtime then
		table.insert(exclude, runtime)
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

local function footOf(player: Player): (BasePart?, number)
	local hrp = PlayerStateService.getHRP(player)
	if not hrp then
		return nil, 0
	end
	local char = player.Character
	return hrp, Geometry.footY(hrp, char and char:FindFirstChildOfClass("Humanoid"))
end

local function floorUnder(x: number, y: number, z: number, params: RaycastParams): Vector3?
	local hit = Workspace:Raycast(Vector3.new(x, y + E.FLOOR_RAY_START, z), Vector3.new(0, -E.FLOOR_RAY_LENGTH, 0), params)
	return if hit then hit.Position else nil
end

local function randomStanding(): Player?
	local list = PlayerStateService.standingMembers()
	return if #list > 0 then list[rng:NextInteger(1, #list)] else nil
end

local function broadcast(payload: Remotes.WorldEventPayload)
	local remote = Remotes.get("WorldEvent")
	for _, player in PlayerStateService.teamMembers() do
		remote:FireClient(player, payload)
	end
end

----------------------------------------------------------------------------
-- IceLane
----------------------------------------------------------------------------

-- Returns the lane start CFrame (on the floor, facing the slide direction) and its length.
local function pickLane(def: Types.EventDef): (CFrame?, number)
	local width = def.width or 8
	local markers: { BasePart } = {}
	for _, inst in MapService.tagged(Contract.Tag.EventLane) do
		if inst:IsA("BasePart") and inst:GetAttribute(Attr.EventId) == def.id then
			table.insert(markers, inst)
		end
	end
	if #markers > 0 then
		local band = markers[rng:NextInteger(1, #markers)]
		local half = math.max(0, band.Size.X / 2 - width / 2)
		local offset = rng:NextNumber(-half, half)
		-- aim at a standing player inside the band (if any)
		local candidates: { number } = {}
		for _, player in PlayerStateService.standingMembers() do
			local hrp, footY = footOf(player)
			if hrp then
				local lp = band.CFrame:PointToObjectSpace(hrp.Position)
				if math.abs(lp.X) <= band.Size.X / 2 and math.abs(lp.Z) <= band.Size.Z / 2 and math.abs(footY - band.Position.Y) <= E.HIT_DY then
					table.insert(candidates, math.clamp(lp.X, -half, half))
				end
			end
		end
		if #candidates > 0 then
			offset = candidates[rng:NextInteger(1, #candidates)]
		end
		local start = band.CFrame * CFrame.new(offset, 0, band.Size.Z / 2)
		return start, band.Size.Z
	end
	-- fallback: lane through a random standing player
	local target = randomStanding()
	if not target then
		return nil, 0
	end
	local hrp, footY = footOf(target)
	if not hrp then
		return nil, 0
	end
	local length = def.length or 70
	local angle = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local centre = Vector3.new(hrp.Position.X, footY, hrp.Position.Z)
	local startPos = centre - dir * (length / 2)
	return CFrame.lookAt(startPos, startPos + dir), length
end

local function runIceLane(def: Types.EventDef, s: Cleanup.Cleanup): boolean
	local start, length = pickLane(def)
	if not start then
		return false
	end
	local width = def.width or 8
	local cube = def.cubeSize or 3
	local telegraph, slide = def.telegraph, math.max(0.1, def.duration)
	broadcast({
		kind = "IceLane",
		id = def.id,
		cframe = start,
		length = length,
		width = width,
		count = def.count or 6,
		telegraph = telegraph,
		duration = slide,
		startsAt = now(),
	})
	s:add(task.spawn(function()
		task.wait(telegraph)
		local hit: { [Player]: boolean } = {}
		local t0 = os.clock()
		local dir = start.LookVector
		while s:alive() do
			local front = math.min(1, (os.clock() - t0) / slide) * length
			for _, player in PlayerStateService.standingMembers() do
				if not hit[player] then
					local hrp, footY = footOf(player)
					if hrp then
						local lp = start:PointToObjectSpace(hrp.Position)
						local along = -lp.Z -- forward = -Z in object space
						if
							math.abs(lp.X) <= width / 2 + 1
							and along <= front + 1
							and along >= front - cube - 2
							and math.abs(footY - start.Position.Y) <= E.HIT_DY
						then
							hit[player] = true
							PlayerStateService.damage(player, def.damage or 0)
							local payload: Remotes.WorldEventPayload = {
								kind = "Knockback",
								velocity = dir * (def.knockback or 0) + Vector3.new(0, def.knockbackUp or 0, 0),
							}
							Remotes.get("WorldEvent"):FireClient(player, payload)
						end
					end
				end
			end
			if front >= length then
				break
			end
			task.wait(E.TICK)
		end
	end))
	return true
end

----------------------------------------------------------------------------
-- OilPatch
----------------------------------------------------------------------------

local function pickPatchPoint(): Vector3?
	local params = rayParams()
	local target = randomStanding()
	if not target then
		return nil
	end
	local hrp, footY = footOf(target)
	if not hrp then
		return nil
	end
	for _ = 1, E.PLACE_ATTEMPTS do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(E.PLACE_MIN_DIST, E.PLACE_MAX_DIST)
		local p = floorUnder(hrp.Position.X + math.cos(angle) * dist, footY, hrp.Position.Z + math.sin(angle) * dist, params)
		if p and math.abs(p.Y - footY) <= E.HIT_DY then
			return p
		end
	end
	return floorUnder(hrp.Position.X, footY, hrp.Position.Z, params)
end

local function runOilPatch(def: Types.EventDef, s: Cleanup.Cleanup): boolean
	local pos = pickPatchPoint()
	if not pos then
		return false
	end
	serial += 1
	local key = "Event" .. serial
	local radius = def.radius or 12
	broadcast({
		kind = "OilPatch",
		id = def.id,
		position = pos,
		radius = radius,
		telegraph = def.telegraph,
		duration = def.duration,
		startsAt = now(),
	})
	local affected: { [Player]: boolean } = {}
	local function clear()
		for player in affected do
			PlayerStateService.setPlayerSpeedModifier(player, key, nil)
		end
		table.clear(affected)
	end
	s:add(clear)
	s:add(task.spawn(function()
		task.wait(def.telegraph)
		local endsAt = os.clock() + def.duration
		while s:alive() and os.clock() < endsAt do
			for _, player in PlayerStateService.teamMembers() do
				local hrp, footY = footOf(player)
				local inside = hrp ~= nil
					and PlayerStateService.isStanding(player)
					and Geometry.horizontalDistance(hrp.Position, pos) <= radius
					and math.abs(footY - pos.Y) <= E.HIT_DY
				if inside and not affected[player] then
					affected[player] = true
					PlayerStateService.setPlayerSpeedModifier(player, key, def.speedMult or 1)
				elseif not inside and affected[player] then
					affected[player] = nil
					PlayerStateService.setPlayerSpeedModifier(player, key, nil)
				end
			end
			task.wait(E.TICK)
		end
		clear()
	end))
	return true
end

----------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------

function EventService.ids(): { string }
	return table.clone(E.ORDER)
end

-- Runs one event now. Returns (ok, reason).
function EventService.trigger(id: string): (boolean, string?)
	local def = E.DEFS[id]
	if not def then
		return false, "unknown event " .. id
	end
	if not PlayerStateService.isMatchActive() then
		return false, "no match running"
	end
	local s = scopeNow()
	local ok = false
	if def.kind == "IceLane" then
		ok = runIceLane(def, s)
	elseif def.kind == "OilPatch" then
		ok = runOilPatch(def, s)
	else
		return false, "unsupported kind " .. def.kind
	end
	if not ok then
		return false, "no place for it (no standing player?)"
	end
	Hud.banner("Event", def.displayName, def.warningText, "Warn", E.BANNER_TIME)
	return true, nil
end

-- Schedules PER_MATCH_MIN..MAX distinct random events inside `stageScope` (cancelled with it).
function EventService.schedule(stageScope: Cleanup.Cleanup)
	local pool = table.clone(E.ORDER)
	local count = math.min(#pool, rng:NextInteger(E.PER_MATCH_MIN, E.PER_MATCH_MAX))
	local latestFirst = math.max(E.FIRST_AT, E.LAST_AT - E.MIN_GAP * (count - 1))
	local at = rng:NextNumber(E.FIRST_AT, latestFirst)
	for i = 1, count do
		local id = table.remove(pool, rng:NextInteger(1, #pool)) :: string
		stageScope:add(task.delay(at, function()
			if stageScope:alive() then
				local ok, reason = EventService.trigger(id)
				if not ok then
					warn(`[Event] {id} skipped: {reason}`)
				end
			end
		end))
		if i < count then
			local remaining = count - i - 1
			at += E.MIN_GAP + rng:NextNumber(0, math.max(0, E.LAST_AT - at - E.MIN_GAP * (remaining + 1)))
		end
	end
end

-- Ends running events (speed modifiers removed). Called when the disaster/match stops.
function EventService.stop()
	if eventScope then
		eventScope:clean()
		eventScope = nil
	end
end

return EventService
