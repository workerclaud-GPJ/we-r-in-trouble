--!strict
--[[
	DisasterService — stage system (Calm → Warning → Active → Critical, fast-forward
	rules GDD §4.1) and data-driven hazard components (§4.2): Pulse, MoveModifier,
	ScreenEffect, TelegraphedImpact (floor-aware, NearPlayer / RandomPoint), RisingVolume
	(VolumeService; DisasterDef.volume). Random events (EventService, Config/Events) are
	scheduled when Events.STAGE starts and cancelled when it ends.
	Server decides impacts and damage; clients draw rings/debris/shake (Impact /
	ScreenEffect remotes).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Cleanup = require(Shared.Util.Cleanup)
local Geometry = require(Shared.Util.Geometry)
local Signal = require(Shared.Util.Signal)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RoundState = require(script.Parent.RoundState)
local Hud = require(script.Parent.Hud)
local VolumeService = require(script.Parent.VolumeService)
local EventService = require(script.Parent.EventService)
local RouteToppleService = require(script.Parent.RouteToppleService)

local Attr = Contract.Attr
local ORDER = Config.Stages.ORDER
local IMP = Config.Impact

local DisasterService = {}

-- Fired for every server ScreenEffect "Shake" (stageId, intensity, duration). ItemService
-- nudges lying physics items with it (Features.ItemPhysics); no listener = no effect.
DisasterService.Shake = Signal.new() :: Signal.Signal<string, number, number>

local disaster: Types.DisasterDef? = nil
local matchScope: Cleanup.Cleanup? = nil
local stageScope: Cleanup.Cleanup? = nil
local stageIndex = 0
local revealed = false
local hazardsEnabled = true
local modifierSerial = 0
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function indexOf(stageId: string): number?
	return table.find(ORDER, stageId)
end

local function stageDuration(def: Types.DisasterDef, stageId: string): number?
	local overrides = def.stageOverrides
	if overrides and overrides[stageId] then
		return overrides[stageId]
	end
	return Config.Stages.DEFS[stageId].duration
end

----------------------------------------------------------------------------
-- TelegraphedImpact (GDD 4.2 rules 1–4, 6–7; Deadline: visual debris only)
----------------------------------------------------------------------------

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
	params.RespectCanCollide = true -- volumes (ExitZone/NoImpact) are not floors
	return params
end

local function footOf(player: Player): (BasePart?, number)
	local hrp = PlayerStateService.getHRP(player)
	if not hrp then
		return nil, 0
	end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	return hrp, Geometry.footY(hrp, humanoid)
end

local function pointNear(player: Player, comp: Types.HazardComponent, params: RaycastParams): Vector3?
	local hrp, footY = footOf(player)
	if not hrp then
		return nil
	end
	local under = Workspace:Raycast(hrp.Position, Vector3.new(0, -IMP.FLOOR_RAY_LENGTH, 0), params)
	local floorY = if under then under.Position.Y else footY
	local minD, maxD = comp.minDist or 3, comp.maxDist or 10
	for _ = 1, IMP.REROLL_ATTEMPTS do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(minD, maxD)
		local origin = Vector3.new(hrp.Position.X + math.cos(angle) * dist, footY + IMP.FLOOR_RAY_START, hrp.Position.Z + math.sin(angle) * dist)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -IMP.FLOOR_RAY_LENGTH, 0), params)
		if hit and math.abs(hit.Position.Y - floorY) <= IMP.MAX_FLOOR_DY and not MapService.isNoImpact(hit.Position) then
			return hit.Position
		end
	end
	return nil -- skip (does not land)
end

-- Random x,z inside the map's drop area, ray down from floor + RANDOM_POINT_RAY_TOP
-- (first CanQuery+CanCollide surface: floor, ramps, counters, sill). §8.6.1
local function randomPoint(params: RaycastParams): Vector3?
	local cf, size, floorY = MapService.getDropArea()
	if size.Magnitude == 0 then
		return nil
	end
	local top = floorY + IMP.RANDOM_POINT_RAY_TOP
	for _ = 1, IMP.REROLL_ATTEMPTS do
		local localPos = Vector3.new(rng:NextNumber(-size.X / 2, size.X / 2), 0, rng:NextNumber(-size.Z / 2, size.Z / 2))
		local world = cf:PointToWorldSpace(localPos)
		local origin = Vector3.new(world.X, top, world.Z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -IMP.RANDOM_POINT_RAY_TOP - 5, 0), params)
		if hit and not MapService.isNoImpact(hit.Position) then
			return hit.Position
		end
	end
	return nil
end

local function resolveImpact(point: Vector3, radius: number, damage: number)
	for _, player in PlayerStateService.standingMembers() do
		local hrp, footY = footOf(player)
		if hrp and Geometry.horizontalDistance(hrp.Position, point) <= radius and math.abs(footY - point.Y) <= IMP.MAX_HIT_DY then
			-- falling object: if the hit does not down them, they are dizzy for a moment
			if PlayerStateService.damage(player, damage) and PlayerStateService.isStanding(player) then
				PlayerStateService.stun(player)
			end
		end
	end
end

local function launchImpact(point: Vector3, comp: Types.HazardComponent, scope: Cleanup.Cleanup)
	local pool = comp.propPool or (disaster and disaster.propPool)
	local prop = if pool and #pool > 0 then pool[rng:NextInteger(1, #pool)] else nil
	local telegraph = comp.telegraph or 1.5
	local radius = comp.radius or 5
	local damage = comp.damage or 0
	local payload: Remotes.ImpactPayload = {
		position = point,
		radius = radius,
		telegraph = telegraph,
		damage = damage,
		prop = prop,
		dropHeight = IMP.DROP_HEIGHT,
		lifetime = comp.lifetime or 3,
	}
	local remote = Remotes.get("Impact")
	for _, player in PlayerStateService.teamMembers() do
		remote:FireClient(player, payload)
	end
	if damage > 0 then
		-- an impact already telegraphed still lands after a stage change; only match end cancels it
		task.delay(telegraph, function()
			if scope:alive() then
				resolveImpact(point, radius, damage)
			end
		end)
	end
end

local function impactWave(comp: Types.HazardComponent)
	local scope = matchScope
	if not scope then
		return
	end
	local params = rayParams()
	if comp.targeting == "RandomPoint" then
		local n = if typeof(comp.count) == "number" then comp.count else 1
		for _ = 1, n do
			local p = randomPoint(params)
			if p then
				launchImpact(p, comp, scope)
			end
		end
		return
	end
	-- NearPlayer
	local standing = PlayerStateService.standingMembers()
	local n = if typeof(comp.count) == "number" then comp.count else math.ceil(#standing / 2)
	for i = #standing, 2, -1 do
		local j = rng:NextInteger(1, i)
		standing[i], standing[j] = standing[j], standing[i]
	end
	for i = 1, math.min(n, #standing) do
		local p = pointNear(standing[i], comp, params)
		if p then
			launchImpact(p, comp, scope)
		end
	end
end

----------------------------------------------------------------------------
-- Components
----------------------------------------------------------------------------

local runComponent: (comp: Types.HazardComponent, scope: Cleanup.Cleanup, duration: number?) -> ()

local function runPulse(comp: Types.HazardComponent, scope: Cleanup.Cleanup)
	scope:add(task.spawn(function()
		task.wait(comp.firstDelay or 0)
		local duration = comp.duration or 1
		local interval = comp.interval or 999
		while scope:alive() do
			local pulseScope = Cleanup.new()
			scope:add(function()
				pulseScope:clean()
			end)
			local children: { Types.HazardComponent } = comp.children or {}
			for _, child in children do
				runComponent(child, pulseScope, duration)
			end
			task.wait(duration)
			pulseScope:clean()
			if interval >= 999 then
				break
			end
			task.wait(math.max(0, interval - duration))
		end
	end))
end

runComponent = function(comp: Types.HazardComponent, scope: Cleanup.Cleanup, duration: number?)
	if comp.type == "Pulse" then
		runPulse(comp, scope)
	elseif comp.type == "MoveModifier" then
		modifierSerial += 1
		local key = "Hazard" .. modifierSerial
		PlayerStateService.setGlobalSpeedModifier(key, comp.multiplier or 1)
		scope:add(function()
			PlayerStateService.setGlobalSpeedModifier(key, nil)
		end)
	elseif comp.type == "ScreenEffect" then
		local payload: Remotes.ScreenEffectPayload = {
			effect = comp.effect or "Shake",
			intensity = comp.intensity or 0.5,
			duration = duration or comp.duration or 1,
		}
		local remote = Remotes.get("ScreenEffect")
		for _, player in PlayerStateService.teamMembers() do
			remote:FireClient(player, payload)
		end
		if payload.effect == "Shake" then
			DisasterService.Shake:Fire(DisasterService.currentStage(), payload.intensity, payload.duration)
		end
	elseif comp.type == "RisingVolume" then
		local steps: { Types.VolumeStep } = comp.steps or {}
		for _, step in steps do
			scope:add(task.delay(step.delay, function()
				if scope:alive() then
					VolumeService.riseTo(step.level, step.riseTime)
				end
			end))
		end
	elseif comp.type == "TelegraphedImpact" then
		scope:add(task.spawn(function()
			local rate = math.max(0.05, comp.rate or 1)
			while scope:alive() do
				impactWave(comp)
				task.wait(rate)
			end
		end))
	else
		warn(`[Disaster] hazard component {comp.type} not supported in Deadline build`)
	end
end

----------------------------------------------------------------------------
-- Stages
----------------------------------------------------------------------------

local function reveal(def: Types.DisasterDef)
	if revealed then
		return
	end
	revealed = true
	RoundState.set(Attr.DisasterId, def.id)
	RoundState.set(Attr.DisasterName, def.displayName)
	RoundState.set(Attr.DisasterHint, def.warningText)
	Hud.banner("Disaster", def.displayName, def.warningText, "Warn", math.max(Config.Stages.WARNING_BANNER_MIN, 3))
end

local function enterStage(index: number, final: boolean)
	local def = disaster
	if not def then
		return
	end
	local stageId = ORDER[index]
	stageIndex = index
	RoundState.set(Attr.Stage, stageId)
	RoundState.set(Attr.StageStartedAt, now())
	if index >= (indexOf(Contract.Stage.Warning) or 2) then
		reveal(def) -- banner always shown, even when Warning is skipped
	end
	if not final then
		return -- skipped stages: on-enter only, no hazard rhythm
	end
	if stageId == Contract.Stage.Critical then
		Hud.banner("BannerCritical", "It's getting worse!", "Watch the red circles!", "Bad", 3)
	end
	if stageScope then
		stageScope:clean()
	end
	local scope = Cleanup.new()
	stageScope = scope
	if matchScope then
		matchScope:add(function()
			scope:clean()
		end)
	end
	if not hazardsEnabled then
		return -- DevNoHazards (Studio): stage/HUD only
	end
	local components: { Types.HazardComponent } = def.stages[stageId] or {}
	for _, comp in components do
		runComponent(comp, scope, nil)
	end
	if stageId == Config.Events.STAGE then
		EventService.schedule(scope)
	end
	RouteToppleService.onStage(stageId) -- no-op unless Config.Features.RouteTopple
end

-- Moves to `stageId`. Forward jumps fast-forward through skipped stages (§4.1);
-- backward jumps (debug only) enter the target directly.
function DisasterService.setStage(stageId: string)
	local target = indexOf(stageId)
	if not disaster or not target or target == stageIndex then
		return
	end
	if target < stageIndex then
		enterStage(target, true)
		return
	end
	for i = stageIndex + 1, target do
		enterStage(i, i == target)
	end
end

function DisasterService.currentStage(): string
	return ORDER[stageIndex] or Contract.Stage.Calm
end

function DisasterService.current(): Types.DisasterDef?
	return disaster
end

function DisasterService.start(def: Types.DisasterDef, startedAt: number)
	DisasterService.stop()
	disaster = def
	revealed = false
	hazardsEnabled = not (RunService:IsStudio() and ServerStorage:GetAttribute(Config.Debug.DEV_NO_HAZARDS_ATTR) == true)
	if not hazardsEnabled then
		warn("[Disaster] DevNoHazards is set: stages run, hazards disabled (Studio only)")
	end
	local scope = Cleanup.new()
	matchScope = scope
	RouteToppleService.begin(def.id, hazardsEnabled) -- no-op unless Config.Features.RouteTopple
	if def.volume and hazardsEnabled then
		VolumeService.begin(def.volume)
		scope:add(VolumeService.stop)
	end
	stageIndex = 0
	enterStage(1, true)

	-- timeline: each later stage starts after the previous stage's duration
	scope:add(task.spawn(function()
		local at = startedAt
		for i = 2, #ORDER do
			local d = stageDuration(def, ORDER[i - 1])
			if not d then
				break
			end
			at += d
			task.wait(math.max(0, at - now()))
			if stageIndex < i then
				DisasterService.setStage(ORDER[i])
			end
		end
	end))
end

-- Debug: replace the running disaster, keeping the current stage (fast-forward from Calm).
function DisasterService.swap(def: Types.DisasterDef, startedAt: number)
	local stageId = DisasterService.currentStage()
	DisasterService.start(def, startedAt)
	DisasterService.setStage(stageId)
end

function DisasterService.stop()
	RouteToppleService.reset()
	EventService.stop()
	VolumeService.stop()
	if stageScope then
		stageScope:clean()
		stageScope = nil
	end
	if matchScope then
		matchScope:clean()
		matchScope = nil
	end
	disaster = nil
	stageIndex = 0
end

return DisasterService
