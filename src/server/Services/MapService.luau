--!strict
--[[
	MapService — map clone/cleanup, tag queries inside the current map, exit flags,
	spawn selection, NoImpact queries and the Lobby platform.
	GDD §2.1, §4.2 (NoImpact), §5.4 (spawn selector, Deadline: no hazard check), §7.6, §8.3.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Geometry = require(Shared.Util.Geometry)

local Attr = Contract.Attr
local Tag = Contract.Tag

local MapService = {}

local mapFolder: Folder? = nil
local mapModel: Model? = nil
local runtime: Folder? = nil
local flags: { [string]: boolean } = {}
local noImpactParts: { BasePart } = {}
local exitZones: { BasePart } = {}
local safeSpawns: { BasePart } = {} -- PlayerSpawns without EnabledBy (auto NoImpact radius)
local boundsCFrame = CFrame.identity
local boundsSize = Vector3.zero
local dropCFrame = CFrame.identity
local dropSize = Vector3.zero
local dropFloorY = 0
local lobbySpawns: { BasePart } = {}

local rng = Random.new()

local function asBasePart(inst: Instance): BasePart?
	return if inst:IsA("BasePart") then inst else nil
end

-- Finds an optional art asset: Assets.<sub>.<name>, then Assets.<name>
-- (ReplicatedStorage.Assets first, then ServerStorage.Assets).
function MapService.findAsset(name: string?, sub: string?): Instance?
	if not name then
		return nil
	end
	for _, root in { ReplicatedStorage, ServerStorage } do
		local assets = root:FindFirstChild(Contract.Folder.Assets)
		if assets then
			local folder = if sub then assets:FindFirstChild(sub) else nil
			local found = (folder and folder:FindFirstChild(name)) or assets:FindFirstChild(name)
			if found then
				return found
			end
		end
	end
	return nil
end

----------------------------------------------------------------------------
-- Map lifecycle
----------------------------------------------------------------------------

function MapService.loadMap(mapId: string): Model?
	MapService.unloadMap()
	local maps = ServerStorage:FindFirstChild(Contract.Folder.Maps)
	local source = maps and maps:FindFirstChild(mapId)
	if not (source and source:IsA("Model")) then
		warn(`[MapService] ServerStorage.{Contract.Folder.Maps}.{mapId} (Model) not found — build/publish the map first`)
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = Contract.Folder.Map
	local clone = source:Clone()
	clone.Parent = folder
	local rt = Instance.new("Folder")
	rt.Name = Contract.Folder.Runtime
	rt.Parent = folder
	folder.Parent = Workspace

	mapFolder, mapModel, runtime = folder, clone, rt
	table.clear(flags)
	boundsCFrame, boundsSize = clone:GetBoundingBox()
	-- RandomPoint area: Part named DropArea (bottom = floor), else the map PrimaryPart floor (top = floor)
	local dropArea = clone:FindFirstChild(Contract.Name.DropArea, true)
	if dropArea and dropArea:IsA("BasePart") then
		dropCFrame, dropSize = dropArea.CFrame, dropArea.Size
		dropFloorY = dropArea.Position.Y - dropArea.Size.Y / 2
	elseif clone.PrimaryPart then
		dropCFrame, dropSize = clone.PrimaryPart.CFrame, clone.PrimaryPart.Size
		dropFloorY = clone.PrimaryPart.Position.Y + clone.PrimaryPart.Size.Y / 2
	else
		dropCFrame, dropSize = boundsCFrame, boundsSize
		dropFloorY = boundsCFrame.Position.Y - boundsSize.Y / 2
	end

	noImpactParts, exitZones, safeSpawns = {}, {}, {}
	for _, inst in MapService.tagged(Tag.NoImpact) do
		local part = asBasePart(inst)
		if part then
			table.insert(noImpactParts, part)
		end
	end
	for _, inst in MapService.tagged(Tag.ExitZone) do
		local part = asBasePart(inst)
		if part then
			part:SetAttribute(Attr.Open, false)
			table.insert(exitZones, part)
		end
	end
	for _, inst in MapService.tagged(Tag.PlayerSpawn) do
		local part = asBasePart(inst)
		if part and inst:GetAttribute(Attr.EnabledBy) == nil then
			table.insert(safeSpawns, part)
		end
	end
	return clone
end

function MapService.unloadMap()
	if mapFolder then
		mapFolder:Destroy()
	end
	-- Also remove any stray Workspace.Map (e.g. left in the place file)
	local stray = Workspace:FindFirstChild(Contract.Folder.Map)
	while stray do
		stray:Destroy()
		stray = Workspace:FindFirstChild(Contract.Folder.Map)
	end
	mapFolder, mapModel, runtime = nil, nil, nil
	table.clear(flags)
	noImpactParts, exitZones, safeSpawns = {}, {}, {}
end

function MapService.getMap(): Model?
	return mapModel
end

function MapService.getRuntime(): Folder?
	return runtime
end

function MapService.getBounds(): (CFrame, Vector3)
	return boundsCFrame, boundsSize
end

-- Area for RandomPoint impacts: (centre CFrame, size — only X/Z used, floor Y).
function MapService.getDropArea(): (CFrame, Vector3, number)
	return dropCFrame, dropSize, dropFloorY
end

function MapService.killY(): number
	local model = mapModel
	if not model then
		return -math.huge
	end
	local v = model:GetAttribute(Attr.KillY)
	if typeof(v) == "number" then
		return v
	end
	return boundsCFrame.Position.Y - boundsSize.Y / 2 - 30
end

-- Tagged instances inside the current map only.
function MapService.tagged(tag: string): { Instance }
	local out: { Instance } = {}
	local folder = mapFolder
	if not folder then
		return out
	end
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(folder) then
			table.insert(out, inst)
		end
	end
	return out
end

function MapService.exitZones(): { BasePart }
	return exitZones
end

----------------------------------------------------------------------------
-- Flags (exitFlag etc.)
----------------------------------------------------------------------------

function MapService.setFlag(name: string)
	flags[name] = true
end

function MapService.hasFlag(name: string): boolean
	return flags[name] == true
end

----------------------------------------------------------------------------
-- Spawns
----------------------------------------------------------------------------

local function spawnCFrame(part: BasePart): CFrame
	local _, yaw, _ = part.CFrame:ToOrientation()
	local top = part.Position + Vector3.new(0, part.Size.Y / 2 + Config.Player.SPAWN_HEIGHT_OFFSET, 0)
	return CFrame.new(top) * CFrame.Angles(0, yaw, 0)
end

local function enabledSpawns(): { BasePart }
	local out: { BasePart } = {}
	for _, inst in MapService.tagged(Tag.PlayerSpawn) do
		local part = asBasePart(inst)
		local by = inst:GetAttribute(Attr.EnabledBy)
		if part and (by == nil or by == "" or (typeof(by) == "string" and flags[by])) then
			table.insert(out, part)
		end
	end
	return out
end

local function priorityOf(part: BasePart): number
	local p = part:GetAttribute(Attr.Priority)
	return if typeof(p) == "number" then p else math.huge
end

-- Lowest Priority among enabled spawns (Deadline: no hazard check).
local function bestSpawns(): { BasePart }
	local best: { BasePart } = {}
	local bestPriority = math.huge
	for _, part in enabledSpawns() do
		local p = priorityOf(part)
		if p < bestPriority then
			bestPriority = p
			best = { part }
		elseif p == bestPriority then
			table.insert(best, part)
		end
	end
	return best
end

local function fallbackCFrame(): CFrame
	warn("[MapService] no enabled PlayerSpawn in map — using map centre")
	return CFrame.new(boundsCFrame.Position + Vector3.new(0, boundsSize.Y / 2 + 5, 0))
end

function MapService.pickSpawn(): CFrame
	local list = bestSpawns()
	if #list == 0 then
		return fallbackCFrame()
	end
	return spawnCFrame(list[rng:NextInteger(1, #list)])
end

-- n spawn CFrames spread over the best spawns (match start).
function MapService.matchSpawns(n: number): { CFrame }
	local list = bestSpawns()
	local out: { CFrame } = {}
	if #list == 0 then
		for _ = 1, n do
			table.insert(out, fallbackCFrame())
		end
		return out
	end
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	for i = 1, n do
		table.insert(out, spawnCFrame(list[(i - 1) % #list + 1]))
	end
	return out
end

----------------------------------------------------------------------------
-- NoImpact
----------------------------------------------------------------------------

function MapService.isNoImpact(point: Vector3): boolean
	for _, part in noImpactParts do
		if Geometry.pointInPart(point, part, 0.5) then
			return true
		end
	end
	for _, zone in exitZones do
		if zone:GetAttribute(Attr.Open) == true and Geometry.pointInPart(point, zone, 2) then
			return true
		end
	end
	local radius = Config.Impact.NO_IMPACT_SPAWN_RADIUS
	for _, part in safeSpawns do
		if
			Geometry.horizontalDistance(point, part.Position) <= radius
			and math.abs(point.Y - part.Position.Y) <= Config.Impact.MAX_HIT_DY
		then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------------
-- Lobby (built in code unless Workspace.Lobby has LobbySpawn parts)
----------------------------------------------------------------------------

local function buildLobby(): Model
	local R = Config.Round
	local model = Instance.new("Model")
	model.Name = Contract.Folder.Lobby
	local center = Vector3.new(R.LOBBY_OFFSET_X, R.LOBBY_Y, 0)
	local size, height = R.LOBBY_SIZE, R.LOBBY_WALL_HEIGHT

	local function part(name: string, cf: CFrame, sz: Vector3, visible: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = sz
		p.CFrame = cf
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(240, 214, 160)
		if not visible then
			p.Transparency = 1
			p.CanQuery = false
		end
		p.Parent = model
		return p
	end

	local floor = part("Floor", CFrame.new(center - Vector3.new(0, 1, 0)), Vector3.new(size, 2, size), true)
	floor.Color = Color3.fromRGB(196, 160, 110)
	local half, t = size / 2, 2
	part("WallN", CFrame.new(center + Vector3.new(0, height / 2, -half - t / 2)), Vector3.new(size + 2 * t, height, t), false)
	part("WallS", CFrame.new(center + Vector3.new(0, height / 2, half + t / 2)), Vector3.new(size + 2 * t, height, t), false)
	part("WallE", CFrame.new(center + Vector3.new(half + t / 2, height / 2, 0)), Vector3.new(t, height, size), false)
	part("WallW", CFrame.new(center + Vector3.new(-half - t / 2, height / 2, 0)), Vector3.new(t, height, size), false)
	part("Ceiling", CFrame.new(center + Vector3.new(0, height + t / 2, 0)), Vector3.new(size + 2 * t, t, size + 2 * t), false)

	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2
		local pos = center + Vector3.new(math.cos(angle) * 8, 0.1, math.sin(angle) * 8)
		local spawnPart = part("LobbySpawn" .. i, CFrame.new(pos), Vector3.new(4, 0.2, 4), false)
		spawnPart.CanCollide = false
		CollectionService:AddTag(spawnPart, Tag.LobbySpawn)
	end
	model.Parent = Workspace
	return model
end

function MapService.ensureLobby()
	local lobby = Workspace:FindFirstChild(Contract.Folder.Lobby)
	if not lobby then
		lobby = buildLobby()
	end
	lobbySpawns = {}
	for _, inst in CollectionService:GetTagged(Tag.LobbySpawn) do
		local part = asBasePart(inst)
		if part and lobby and inst:IsDescendantOf(lobby) then
			table.insert(lobbySpawns, part)
		end
	end
	if #lobbySpawns == 0 then
		warn("[MapService] Workspace.Lobby has no Part tagged LobbySpawn — using lobby offset")
	end
end

function MapService.lobbyCFrame(): CFrame
	if #lobbySpawns > 0 then
		local part = lobbySpawns[rng:NextInteger(1, #lobbySpawns)]
		local jitter = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		return CFrame.new(part.Position + jitter + Vector3.new(0, part.Size.Y / 2 + Config.Player.SPAWN_HEIGHT_OFFSET, 0))
	end
	local R = Config.Round
	return CFrame.new(R.LOBBY_OFFSET_X, R.LOBBY_Y + Config.Player.SPAWN_HEIGHT_OFFSET + 2, 0)
end

return MapService
