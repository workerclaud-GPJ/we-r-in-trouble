--!strict
--[[
	RouteToppleService — server-authoritative "route topple" (Config.Features.RouteTopple).
	Scenery Models tagged `RouteTopple` (Contract.Tag) fall during a disaster into a pre-authored,
	walkable pose (child `FallenPose`: CFrameValue, or a Model whose pivot is used) that opens a
	NEW route. Map pieces: ServerStorage/Tools/AddRouteTopples.lua.

	Per round (DisasterService calls onStage): when the disaster reaches Active, pick
	1..MAX_PER_ROUND eligible pieces (attr TopplesOn lists the disaster id) with a per-round
	Random seed (printed), staggered a few seconds apart. Per piece:
	  1) warning  ToppleWarning = true for WARNING_TIME s (clients wobble + creak).
	  2) fall     ToppleFallAt / ToppleFallTime set; all parts CanCollide = false (nobody gets
	              flung); the SERVER drives Model:PivotTo every Heartbeat along a rotation about
	              the shared pivot (standing pivot -> FallenPose, Quad ease-in). Clients just see
	              the replicated CFrames (anchored parts: no physics involved).
	  3) land     PivotTo(FallenPose) exactly, every part restored to its authored CanCollide,
	              ToppleLanded = true (clients: dust + thud); standing players whose
	              HumanoidRootPart is inside a collider box (+HIT_PADDING) take DAMAGE through
	              PlayerStateService.damage (+ stun if still standing, like TelegraphedImpact),
	              except inside NoImpact volumes (MapService.isNoImpact). Then they are pushed up
	              on top of the piece so they are never stuck inside it.
	Once per piece per round. The map is re-cloned every round (MapService.loadMap), so all
	attributes/poses live on the clone; reset() only drops connections/threads.
	DevNoHazards (Studio) -> nothing topples (DisasterService passes hazardsEnabled).
	Feature off -> MapService.loadMap strips every RouteTopple model from the round's map clone
	(the map plays exactly as before) and every entry point here returns immediately.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Cleanup = require(Shared.Util.Cleanup)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local Attr = Contract.Attr
local Tag = Contract.Tag
local RT = require(Shared.Config.RouteTopple) -- child ModuleScript of Config (not in the Config table)

local RouteToppleService = {}

local roundScope: Cleanup.Cleanup? = nil
local disasterId: string? = nil
local scheduled = false -- Active already scheduled this round
local done: { [Model]: boolean } = {} -- started this round (once per piece)
local rng = Random.new()

local function enabled(): boolean
	return Config.Features.RouteTopple == true
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- FallenPose: CFrameValue.Value, or the pivot of a Model / CFrame of a BasePart.
local function fallenPose(model: Model): CFrame?
	local pose = model:FindFirstChild(Contract.Name.FallenPose)
	if pose == nil then
		return nil
	end
	if pose:IsA("CFrameValue") then
		return pose.Value
	elseif pose:IsA("Model") then
		return pose:GetPivot()
	elseif pose:IsA("BasePart") then
		return pose.CFrame
	end
	return nil
end

local function topplesOn(model: Model, id: string?): boolean
	if not id then
		return false
	end
	local list = model:GetAttribute(Attr.TopplesOn)
	if typeof(list) ~= "string" then
		return false
	end
	for entry in string.gmatch(list, "[^,]+") do
		if string.lower((string.gsub(entry, "%s", ""))) == string.lower(id) then
			return true
		end
	end
	return false
end

-- Parts that move with the model (never the FallenPose helper).
local function bodyParts(model: Model): { BasePart }
	local out: { BasePart } = {}
	local pose = model:FindFirstChild(Contract.Name.FallenPose)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not (pose and d:IsDescendantOf(pose)) then
			table.insert(out, d)
		end
	end
	return out
end

-- Untoppled pieces in the current map; `id` = disaster filter (nil = any, debug).
local function eligible(id: string?): { Model }
	local out: { Model } = {}
	for _, inst in MapService.tagged(Tag.RouteTopple) do
		-- ToppleFallAt survives a disaster swap (debug) on the same map clone: never topple twice
		if
			inst:IsA("Model")
			and not done[inst]
			and inst:GetAttribute(Attr.ToppleWarning) == nil
			and inst:GetAttribute(Attr.ToppleFallAt) == nil
			and inst.PrimaryPart
			and fallenPose(inst)
		then
			if id == nil or topplesOn(inst, id) then
				table.insert(out, inst)
			end
		end
	end
	table.sort(out, function(a: Model, b: Model): boolean
		return a:GetFullName() < b:GetFullName() -- stable order -> the seed reproduces the pick
	end)
	return out
end

-- Landing hit (TelegraphedImpact rules: PlayerStateService.damage, stun if still standing,
-- NoImpact volumes respected). Anyone (standing or downed) left inside a collider is lifted on
-- top of it so no character is ever stuck inside the landed piece.
local function hitPlayers(colliders: { BasePart }, doDamage: boolean)
	for _, player in PlayerStateService.teamMembers() do
		local hrp = PlayerStateService.getHRP(player)
		local char = player.Character
		if not (hrp and char) then
			continue
		end
		local inside: BasePart? = nil
		for _, part in colliders do
			-- footprint test in the part's space: side padding, and from HIT_BELOW studs under the
			-- board (a hamster under it gets squashed) to HIT_ABOVE over its top surface
			local lp = part.CFrame:PointToObjectSpace(hrp.Position)
			local half = part.Size / 2
			if
				math.abs(lp.X) <= half.X + RT.HIT_PADDING
				and math.abs(lp.Z) <= half.Z + RT.HIT_PADDING
				and lp.Y >= -half.Y - RT.HIT_BELOW
				and lp.Y <= half.Y + RT.HIT_ABOVE
			then
				inside = part
				break
			end
		end
		if not inside then
			continue
		end
		if doDamage and not MapService.isNoImpact(hrp.Position) then
			if PlayerStateService.damage(player, RT.DAMAGE) and PlayerStateService.isStanding(player) then
				PlayerStateService.stun(player)
			end
		end
		local part = inside :: BasePart
		local localPos = part.CFrame:PointToObjectSpace(hrp.Position)
		local half = part.Size / 2
		local onTop = part.CFrame:PointToWorldSpace(
			Vector3.new(math.clamp(localPos.X, -half.X, half.X), half.Y, math.clamp(localPos.Z, -half.Z, half.Z))
		)
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local hip = if humanoid then humanoid.HipHeight else 2
		char:PivotTo(CFrame.new(onTop + Vector3.new(0, hrp.Size.Y / 2 + hip + 0.5, 0)) * hrp.CFrame.Rotation)
	end
end

-- Snaps to the exact FallenPose, restores authored collisions. Safe to call twice.
local function land(model: Model, target: CFrame, parts: { BasePart }, collide: { [BasePart]: boolean }): { BasePart }
	model:PivotTo(target)
	local colliders: { BasePart } = {}
	for _, p in parts do
		p.Anchored = true
		-- the walk board is never solid while standing (a near-vertical board is climbable by
		-- jumping); it becomes the ramp only once fallen
		local solid = collide[p] == true or p == model.PrimaryPart
		p.CanCollide = solid
		p.CanQuery = solid
		if solid then
			table.insert(colliders, p)
		end
	end
	model:SetAttribute(Attr.ToppleWarning, false)
	model:SetAttribute(Attr.ToppleLanded, true)
	return colliders
end

-- Full sequence for one piece. Runs inside `scope`; if the scope is cleaned mid-way (round end,
-- debug disaster swap) the piece is snapped to its FallenPose without damage, never left half-way.
local function topple(model: Model, scope: Cleanup.Cleanup)
	local target = fallenPose(model)
	if not target or done[model] then
		return
	end
	done[model] = true
	local parts = bodyParts(model)
	local collide: { [BasePart]: boolean } = {}
	for _, p in parts do
		collide[p] = p.CanCollide
	end
	local landed = false
	local falling = false
	scope:add(function()
		if landed or not model.Parent then
			return
		end
		landed = true
		if not falling then
			-- interrupted during the warning: it never moved, leave it standing (never teleport
			-- a board onto players); clients undo their local wobble when Warning turns false
			model:SetAttribute(Attr.ToppleWarning, nil)
			return
		end
		-- interrupted mid-fall: snap, and lift anyone left inside it (no damage)
		hitPlayers(land(model, target, parts, collide), false)
	end)

	-- 1) warning (clients wobble + creak)
	model:SetAttribute(Attr.ToppleWarning, true)
	task.wait(RT.WARNING_TIME)
	if not (scope:alive() and model.Parent) or landed then
		return
	end

	-- 2) fall: rotation about the shared pivot (standing and FallenPose share the hinge point,
	-- so CFrame:Lerp = pure rotation about the hinge). No collisions while moving: never flings.
	local start = model:GetPivot()
	local fallTime = RT.FALL_TIME
	falling = true
	for _, p in parts do
		p.Anchored = true
		p.CanCollide = false
	end
	model:SetAttribute(Attr.ToppleFallTime, fallTime)
	model:SetAttribute(Attr.ToppleFallAt, now()) -- set before Warning = false (client wobble check)
	model:SetAttribute(Attr.ToppleWarning, false)
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		if landed or not model.Parent then
			return
		end
		local t = math.clamp((os.clock() - t0) / fallTime, 0, 1)
		local a = TweenService:GetValue(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In) -- gravity feel
		model:PivotTo(start:Lerp(target, a))
	end)
	scope:add(conn)
	task.wait(fallTime)
	conn:Disconnect()
	if not (scope:alive() and model.Parent) or landed then
		return
	end

	-- 3) land: exact pose, collisions back, then damage whoever is inside it
	landed = true
	local colliders = land(model, target, parts, collide)
	hitPlayers(colliders, true)
	print(`[RouteTopple] {model.Name} landed`)
end

local function launch(model: Model)
	local scope = roundScope
	if not scope then
		return
	end
	scope:add(task.spawn(function()
		local ok, err = pcall(topple, model, scope)
		if not ok then
			warn("[RouteTopple]", model.Name, err)
		end
	end))
end

local function scheduleActive()
	local scope = roundScope
	if scheduled or not scope then
		return
	end
	scheduled = true
	local pool = eligible(disasterId)
	local seed = rng:NextInteger(1, 2 ^ 30)
	print(`[RouteTopple] seed={seed} disaster={disasterId} eligible={#pool}`)
	if #pool == 0 then
		return
	end
	local roundRng = Random.new(seed)
	for i = #pool, 2, -1 do
		local j = roundRng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local count = math.min(#pool, roundRng:NextInteger(1, RT.MAX_PER_ROUND))
	local at = RT.FIRST_DELAY
	for i = 1, count do
		local model = pool[i]
		print(`[RouteTopple] {model.Name} in {at} s`)
		scope:add(task.delay(at, function()
			if scope:alive() and model.Parent then
				launch(model)
			end
		end))
		at += roundRng:NextNumber(RT.STAGGER_MIN, RT.STAGGER_MAX)
	end
end

----------------------------------------------------------------------------
-- Lifecycle (DisasterService drives it; no-ops while the feature is off)
----------------------------------------------------------------------------

-- New disaster for this round. hazardsEnabled = false (DevNoHazards) -> nothing topples.
function RouteToppleService.begin(id: string, hazardsEnabled: boolean)
	RouteToppleService.reset()
	if not enabled() or not hazardsEnabled then
		return
	end
	roundScope = Cleanup.new()
	disasterId = id
end

-- Called on every stage entered with its hazard rhythm (final = true). Critical also schedules
-- when Active was fast-forwarded (e.g. exit unlocked early); `scheduled` keeps it once per round.
function RouteToppleService.onStage(stageId: string)
	if roundScope and disasterId and (stageId == Contract.Stage.Active or stageId == Contract.Stage.Critical) then
		scheduleActive()
	end
end

-- Stops every pending/running topple (pieces stay where they are; the map is about to go).
function RouteToppleService.reset()
	if roundScope then
		roundScope:clean()
		roundScope = nil
	end
	disasterId = nil
	scheduled = false
	table.clear(done)
end

-- Debug (/dbg topple [all]): topple the next eligible piece now (any disaster, ignores
-- TopplesOn and DevNoHazards), or every one left. Still requires the feature switch.
function RouteToppleService.debugTopple(all: boolean): (boolean, string?)
	if not enabled() then
		return false, "Config.Features.RouteTopple is off"
	end
	if not MapService.getMap() then
		return false, "no map loaded"
	end
	if not roundScope then
		roundScope = Cleanup.new()
	end
	local pool = eligible(nil)
	if #pool == 0 then
		return false, "no eligible RouteTopple piece left"
	end
	local n = if all then #pool else 1
	for i = 1, n do
		launch(pool[i])
	end
	return true, nil
end

-- Boot check only (all round work is driven by DisasterService). Warns when the switch is on
-- but the source map has no pieces (tools/AddRouteTopples not run).
function RouteToppleService.start()
	if not enabled() then
		return
	end
	local maps = ServerStorage:FindFirstChild(Contract.Folder.Maps)
	local count = 0
	if maps then
		for _, inst in CollectionService:GetTagged(Tag.RouteTopple) do
			if inst:IsDescendantOf(maps) and inst:IsA("Model") then
				count += 1
				local pose = fallenPose(inst)
				if not (inst.PrimaryPart and pose) then
					warn(`[RouteTopple] {inst:GetFullName()} needs a PrimaryPart and a {Contract.Name.FallenPose}`)
				elseif (inst:GetPivot().Position - pose.Position).Magnitude > 0.05 then
					-- pivot must be the hinge shared with FallenPose (PrimaryPart.PivotOffset), else
					-- the fall is not a rotation and the landed pose is wrong: re-run AddRouteTopples
					warn(`[RouteTopple] {inst:GetFullName()} pivot is not the FallenPose hinge — re-run AddRouteTopples`)
				end
			end
		end
	end
	print(`[RouteTopple] enabled, {count} piece(s) in ServerStorage.{Contract.Folder.Maps}`)
end

return RouteToppleService
