--!strict
--[[
	ToppleController — decor topples on Big Shake / Critical (client visual only, ARCHITECTURE §6).

	Candidates (inside Workspace.Map.<MapId>, never Map.Runtime):
	  * anything tagged `Toppleable` (Model = one unit; BasePart grouped with siblings that
	    share its `ToppleGroup` attribute, else alone), or
	  * if the map has no such tag: auto-tag at map load — BaseParts under Map.<MapId>.Decor whose
	    name prefix (before "_", digits stripped) is in Config.Presentation.TOPPLE_NAMES and that
	    are anchored + non-colliding (e.g. Kettle + Kettle_Knob = one group "Kettle").
	Trigger: ScreenEffect with intensity >= TOPPLE_BIG_SHAKE_INTENSITY, or Stage -> Critical
	(fallback, e.g. DevNoHazards). Once per MatchId. Items above empty air drop to the surface
	below (shelves are non-colliding decor, so shelf items fall to the counter/floor); others tilt
	over on their bottom edge. Toppled parts get CanCollide/CanQuery = false locally.
	Safe with zero candidates. The map is destroyed after Result, so nothing is restored.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)

local P = Config.Presentation
local Attr = Contract.Attr

local DUST_COLOR = Color3.fromRGB(210, 195, 170)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local GRAVITY = 196.2

type Group = { parts: { BasePart } }

local ToppleController = {}

local toppledMatch: number? = nil
local nameSet: { [string]: boolean } = {}
for _, n in P.TOPPLE_NAMES do
	nameSet[n] = true
end

local function roundState(): Instance?
	return ReplicatedStorage:FindFirstChild(Contract.Folder.RoundState)
end

local function mapModel(): Instance?
	local root = Workspace:FindFirstChild(Contract.Folder.Map)
	if not root then
		return nil
	end
	for _, c in root:GetChildren() do
		if c.Name ~= Contract.Folder.Runtime and c:IsA("Model") then
			return c
		end
	end
	return nil
end

local function prefixOf(name: string): string
	local base = string.match(name, "^([^_]+)") or name
	return (string.gsub(base, "%d+$", ""))
end

-- Auto-tag helper (local tags only). Skipped when the map already has Toppleable tags.
local function autoTag(map: Instance)
	for _, inst in CollectionService:GetTagged(P.TOPPLE_TAG) do
		if inst:IsDescendantOf(map) then
			return
		end
	end
	local decor = map:FindFirstChild(P.TOPPLE_DECOR_FOLDER)
	if not decor then
		return
	end
	for _, d in decor:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and not d.CanCollide then
			local prefix = prefixOf(d.Name)
			if nameSet[prefix] then
				-- group key: parent + full base name (Jar1 and Jar1_Lid together, Jar2 separate)
				local base = string.match(d.Name, "^([^_]+)") or d.Name
				d:SetAttribute(P.TOPPLE_GROUP_ATTR, base)
				d:AddTag(P.TOPPLE_TAG)
			end
		end
	end
end

local function collectGroups(map: Instance): { Group }
	local groups: { Group } = {}
	local byKey: { [Instance]: { [string]: Group } } = {}
	local runtime = map.Parent and map.Parent:FindFirstChild(Contract.Folder.Runtime)
	for _, inst in CollectionService:GetTagged(P.TOPPLE_TAG) do
		if not inst:IsDescendantOf(map) or (runtime and inst:IsDescendantOf(runtime)) then
			continue
		end
		if inst:IsA("Model") then
			local parts: { BasePart } = {}
			for _, d in inst:GetDescendants() do
				if d:IsA("BasePart") and d.Anchored then
					table.insert(parts, d)
				end
			end
			if #parts > 0 then
				table.insert(groups, { parts = parts })
			end
		elseif inst:IsA("BasePart") and inst.Anchored then
			local key = inst:GetAttribute(P.TOPPLE_GROUP_ATTR)
			local parent = inst.Parent :: Instance
			if typeof(key) == "string" then
				local perParent: { [string]: Group } = byKey[parent] or {}
				byKey[parent] = perParent
				local g: Group? = perParent[key]
				if g == nil then
					local ng: Group = { parts = {} }
					perParent[key] = ng
					table.insert(groups, ng)
					g = ng
				end
				table.insert((g :: Group).parts, inst)
			else
				table.insert(groups, { parts = { inst } })
			end
		end
	end
	return groups
end

local function bounds(parts: { BasePart }): (Vector3, Vector3)
	local minV = Vector3.one * math.huge
	local maxV = -minV
	for _, p in parts do
		local cf, s = p.CFrame, p.Size / 2
		-- world AABB of an oriented box
		local ext = Vector3.new(
			math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
			math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
			math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
		)
		minV = minV:Min(cf.Position - ext)
		maxV = maxV:Max(cf.Position + ext)
	end
	return minV, maxV
end

local function dust(pos: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "ToppleDust"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = CFrame.new(pos)
	holder.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = SMOKE
	e.Color = ColorSequence.new(DUST_COLOR)
	e.Size = NumberSequence.new(1, 3)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(4, 8)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Drag = 5
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = holder
	e:Emit(P.TOPPLE_DUST)
	Debris:AddItem(holder, 1.5)
end

local function topple(group: Group, map: Instance)
	local parts = group.parts
	for _, p in parts do
		if not p.Parent then
			return
		end
	end
	local minV, maxV = bounds(parts)
	local center = (minV + maxV) / 2
	local bottom = Vector3.new(center.X, minV.Y, center.Z)

	-- landing surface below (collidable only: non-colliding shelves/decor are ignored)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = table.clone(parts) :: { any }
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(exclude, plr.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(bottom + Vector3.new(0, 0.05, 0), Vector3.new(0, -P.TOPPLE_RAY, 0), params)
	local fall = if hit then math.max(0, bottom.Y - hit.Position.Y) else 0
	if fall < P.TOPPLE_DROP_MIN then
		fall = 0
	end

	-- tip over the bottom edge in a random horizontal direction
	local a = math.random() * math.pi * 2
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local half = (maxV - minV) / 2
	local edge = bottom + Vector3.new(dir.X * half.X, 0, dir.Z * half.Z)
	local axis = Vector3.yAxis:Cross(dir)
	local angle = math.rad(P.TOPPLE_TILT_MIN + math.random() * (P.TOPPLE_TILT_MAX - P.TOPPLE_TILT_MIN))
	local pivot0 = CFrame.new(edge)
	local rel: { CFrame } = {}
	for i, p in parts do
		rel[i] = pivot0:ToObjectSpace(p.CFrame)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end

	local fallTime = if fall > 0 then math.sqrt(2 * fall / GRAVITY) * 1.6 else 0
	local duration = math.max(P.TOPPLE_TILT_TIME, fallTime)
	local start = os.clock()
	local landed = false
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		if not map.Parent or not parts[1].Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local rot = TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out) * angle
		local drop = if fall > 0 then TweenService:GetValue(t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out) * fall else 0
		local pivot = CFrame.new(edge - Vector3.new(0, drop, 0)) * CFrame.fromAxisAngle(axis, rot)
		for i, p in parts do
			p.CFrame = pivot * rel[i]
		end
		if not landed and (t >= 0.45 or (fall > 0 and drop >= fall * 0.98)) then
			landed = true
			dust(edge - Vector3.new(0, fall, 0))
		end
		if t >= 1 and conn then
			conn:Disconnect()
		end
	end)
end

local function runTopple(matchId: number)
	if toppledMatch == matchId then
		return
	end
	local map = mapModel()
	if not map then
		return
	end
	toppledMatch = matchId
	autoTag(map)
	local groups = collectGroups(map)
	-- shuffle, cap
	for i = #groups, 2, -1 do
		local j = math.random(1, i)
		groups[i], groups[j] = groups[j], groups[i]
	end
	for i = 1, math.min(#groups, P.TOPPLE_MAX) do
		local g = groups[i]
		task.delay(math.random() * P.TOPPLE_STAGGER, function()
			local ok, err = pcall(function()
				topple(g, map)
			end)
			if not ok then
				warn("[Topple]", err)
			end
		end)
	end
end

local function currentMatchId(): number?
	local rs = roundState()
	local id = rs and rs:GetAttribute(Attr.MatchId)
	local phase = rs and rs:GetAttribute(Attr.Phase)
	if typeof(id) ~= "number" or phase ~= Contract.Phase.Match then
		return nil
	end
	return id
end

local function trigger()
	local id = currentMatchId()
	if id then
		runTopple(id)
	end
end

function ToppleController.start()
	Remotes.get("ScreenEffect").OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and typeof(payload.intensity) == "number"
			and payload.intensity >= P.TOPPLE_BIG_SHAKE_INTENSITY then
			trigger()
		end
	end)
	task.spawn(function()
		local rs = ReplicatedStorage:WaitForChild(Contract.Folder.RoundState)
		rs:GetAttributeChangedSignal(Attr.Stage):Connect(function()
			if rs:GetAttribute(Attr.Stage) == Contract.Stage.Critical then
				task.delay(0.5, trigger) -- Big Shake usually arrives first; this is the fallback
			end
		end)
	end)
	-- auto-tag as soon as a map shows up (so Level can inspect tags in a Play test)
	task.spawn(function()
		local root = Workspace:WaitForChild(Contract.Folder.Map, math.huge)
		local function onChild(c: Instance)
			if c:IsA("Model") and c.Name ~= Contract.Folder.Runtime then
				task.delay(1, function()
					if c.Parent then
						autoTag(c)
					end
				end)
			end
		end
		local function hook(r: Instance)
			r.ChildAdded:Connect(onChild)
			for _, c in r:GetChildren() do
				onChild(c)
			end
		end
		if root then
			hook(root)
		end
		Workspace.ChildAdded:Connect(function(c: Instance)
			if c.Name == Contract.Folder.Map then
				hook(c)
			end
		end)
	end)
end

return ToppleController
