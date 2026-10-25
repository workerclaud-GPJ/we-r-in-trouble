--!strict
--[[
	BuildMidnightKitchen.luau — grey-box blockout of "Midnight Kitchen — Deadline cut" (GDD v0.5 §8.3)

	HOW TO RUN (Studio, EDIT mode — not while playing):
	  View > Command Bar → paste this whole file → Enter.   (or run it through MCP execute_luau)
	  Output prints a verification report. Ctrl+Z undoes the whole build.

	WHAT IT BUILDS
	  ServerStorage.Maps.MidnightKitchen  (Model)  ← MapService.loadMap clones it into Workspace.Map.<MapId>
	  Workspace.Lobby                     (Model)  ← platform 60×60 at X = 3000 with invisible walls + LobbySpawn pads
	  Workspace.FallenPartsDestroyHeight = -80  (GDD §7.2 safety net under KillY = -30)

	IDEMPOTENT: deletes the previous ServerStorage.Maps.MidnightKitchen, Workspace.Lobby and any
	leftover Workspace.MidnightKitchen_BUILD before building.

	COORDINATES: map-local = world (map built at the world origin).
	  +X = east, +Z = south (north wall at Z = 0, south wall at Z = 120). Floor top Y = 0.
	  Scale 1 stud = 2 cm (GDD §1.1). Kitchen 160 × 120 studs.

	WALKABILITY (default R15 rig: WalkSpeed 16, JumpHeight 7.2) — NO route needs a jump:
	  Ramp1  "cutting board"  floor 0  → chair seat +23   run 36, width 14  → 32.6°
	  Ramp2  "cookbooks"      seat +23 → counter +45      run 34, width 12  → 32.9°
	  Ramp3  "dish rack"      counter +45 → window sill +61  run 26, width 10 → 31.6°
	  All ramps ≤ 35° (GDD §8.3). Every ramp's low edge is flush with the surface it starts on and its
	  high edge is flush with the surface it ends on (step at the joins < 1 stud).
	  Curtain = hidden TrussPart 22 × 62 × 8 (floor → +61). Climbable from the floor (south face) AND
	  from the counter top (its east face rises 16 studs above the counter's west end) → sill +61.
	  Flower box soil, exterior sill and interior sill are all exactly +61 (flat walk, no rim).
	  Only optional drops: counter edge → floor (45, no fall damage in this game).

	CanQuery policy (GDD §8.3, Art handoff): walkable surfaces CanQuery = true; decorative props,
	invisible walls/ceiling, volumes and markers CanQuery = false. Ramps: invisible WedgePart
	(CanQuery = true, Transparency 1) + non-colliding visual plank laid on the slope.
	Exception: the visible NORTH wall (window wall) keeps CanQuery = true so Roblox camera occlusion
	does not push the camera behind it; it is vertical so downward impact rays never land on it.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

----------------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------------

local MAP_NAME = "MidnightKitchen"
local ORIGIN = Vector3.new(0, 0, 0)
local KILL_Y = -30
local FALLEN_PARTS_DESTROY_HEIGHT = -80
local LOBBY_CENTER = Vector3.new(3000, 0, 0) -- Config.Round.LOBBY_OFFSET_X / LOBBY_Y
local LOBBY_SIZE = 60 -- Config.Round.LOBBY_SIZE
local LOBBY_WALL_HEIGHT = 40 -- Config.Round.LOBBY_WALL_HEIGHT

-- true = hidden helpers (ramp wedges, truss, volumes, item/prompt markers) drawn semi-transparent
-- for layout review. Keep false for the real build.
local SHOW_HIDDEN = false
-- true = leave the built map in Workspace (named MidnightKitchen_BUILD) instead of moving it to
-- ServerStorage.Maps. Review only — re-run with false before playtesting.
local PREVIEW_IN_WORKSPACE = false

-- Contract names (src/shared/Contract.luau, docs/ARCHITECTURE.md §6)
local TAG = {
	PlayerSpawn = "PlayerSpawn",
	ObjectiveAnchor = "ObjectiveAnchor",
	ItemSpawn = "ItemSpawn",
	LockedDoor = "LockedDoor",
	ExitZone = "ExitZone",
	ExitVehicleSpot = "ExitVehicleSpot",
	NoImpact = "NoImpact",
	LobbySpawn = "LobbySpawn",
}
local EXIT_FLAG = "WindowOpen"
local ITEM_TYPE = "Battery"

----------------------------------------------------------------------------
-- Styles (color per object type)
----------------------------------------------------------------------------

type Style = {
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean,
	query: boolean,
	touch: boolean?,
	shadow: boolean?,
}

local HIDDEN_T = if SHOW_HIDDEN then 0.7 else 1

local ST: { [string]: Style } = {
	-- walkable surfaces (CanQuery = true)
	floor = { color = Color3.fromRGB(225, 215, 195), collide = true, query = true },
	cabinet = { color = Color3.fromRGB(190, 140, 95), collide = true, query = true },
	counterTop = { color = Color3.fromRGB(230, 225, 215), material = Enum.Material.Marble, collide = true, query = true },
	sill = { color = Color3.fromRGB(245, 245, 240), collide = true, query = true },
	soil = { color = Color3.fromRGB(90, 60, 40), material = Enum.Material.Ground, collide = true, query = true },
	planter = { color = Color3.fromRGB(200, 110, 70), collide = true, query = true },
	walkProp = { color = Color3.fromRGB(170, 115, 75), material = Enum.Material.Wood, collide = true, query = true },
	rampCollider = { color = Color3.fromRGB(255, 140, 40), transparency = HIDDEN_T, collide = true, query = true, shadow = false },
	truss = { color = Color3.fromRGB(120, 220, 90), transparency = HIDDEN_T, collide = true, query = true, shadow = false },
	-- structure
	northWall = { color = Color3.fromRGB(150, 160, 185), collide = true, query = true },
	invisibleWall = { color = Color3.fromRGB(255, 0, 255), transparency = 1, collide = true, query = false, touch = false, shadow = false },
	glass = { color = Color3.fromRGB(180, 210, 255), material = Enum.Material.Glass, transparency = 0.55, collide = true, query = false, shadow = false },
	-- blocking props, not walkable (CanQuery = false)
	prop = { color = Color3.fromRGB(120, 120, 130), collide = true, query = false },
	propWhite = { color = Color3.fromRGB(240, 244, 248), collide = true, query = false },
	propWood = { color = Color3.fromRGB(170, 115, 75), material = Enum.Material.Wood, collide = true, query = false },
	propTray = { color = Color3.fromRGB(90, 200, 180), collide = true, query = false },
	-- visuals only (no collision, no query)
	decor = { color = Color3.fromRGB(200, 200, 205), collide = false, query = false, touch = false },
	plankWood = { color = Color3.fromRGB(205, 160, 110), material = Enum.Material.Wood, collide = false, query = false, touch = false },
	plankBooks = { color = Color3.fromRGB(220, 80, 70), collide = false, query = false, touch = false },
	plankTray = { color = Color3.fromRGB(200, 200, 210), material = Enum.Material.Metal, collide = false, query = false, touch = false },
	curtain = { color = Color3.fromRGB(120, 170, 230), material = Enum.Material.Fabric, collide = false, query = false, touch = false },
	bars = { color = Color3.fromRGB(230, 230, 240), material = Enum.Material.Metal, transparency = 0.6, collide = false, query = false, touch = false },
	sink = { color = Color3.fromRGB(190, 195, 205), material = Enum.Material.Metal, collide = false, query = false, touch = false },
	-- gameplay objects
	wheel = { color = Color3.fromRGB(110, 210, 200), transparency = 0.4, collide = false, query = false, touch = false },
	wheelBase = { color = Color3.fromRGB(110, 210, 200), collide = true, query = true },
	charger = { color = Color3.fromRGB(240, 140, 60), collide = true, query = false },
	chargerUnit = { color = Color3.fromRGB(60, 64, 76), collide = true, query = false },
	dynamo = { color = Color3.fromRGB(70, 180, 90), collide = true, query = false },
	radioA = { color = Color3.fromRGB(255, 90, 90), collide = true, query = false },
	radioB = { color = Color3.fromRGB(80, 150, 255), collide = true, query = false },
	radioC = { color = Color3.fromRGB(255, 205, 60), collide = true, query = false },
	radioD = { color = Color3.fromRGB(90, 210, 120), collide = true, query = false },
	antenna = { color = Color3.fromRGB(30, 30, 35), collide = false, query = false, touch = false },
	-- markers / volumes (no collision, no query)
	promptPart = { color = Color3.fromRGB(0, 170, 255), transparency = HIDDEN_T, collide = false, query = false, shadow = false },
	spawnPad = { color = Color3.fromRGB(255, 255, 255), transparency = 0.5, collide = false, query = false, touch = false, shadow = false },
	spawnPadLate = { color = Color3.fromRGB(255, 120, 200), transparency = 0.5, collide = false, query = false, touch = false, shadow = false },
	itemSpawn = { color = Color3.fromRGB(60, 230, 60), transparency = HIDDEN_T, collide = false, query = false, touch = false, shadow = false },
	noImpact = { color = Color3.fromRGB(255, 40, 40), transparency = HIDDEN_T, collide = false, query = false, touch = false, shadow = false },
	exitZone = { color = Color3.fromRGB(60, 255, 120), transparency = HIDDEN_T, collide = false, query = false, touch = false, shadow = false },
	marker = { color = Color3.fromRGB(255, 255, 0), transparency = HIDDEN_T, collide = false, query = false, touch = false, shadow = false },
	lightMount = { color = Color3.fromRGB(255, 255, 255), transparency = 1, collide = false, query = false, touch = false, shadow = false },
	-- lobby
	lobbyFloor = { color = Color3.fromRGB(230, 200, 150), collide = true, query = true },
	lobbyToy = { color = Color3.fromRGB(255, 205, 60), collide = true, query = true },
}

----------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------

local function at(v: Vector3): Vector3
	return ORIGIN + v
end

local function applyStyle(p: BasePart, st: Style)
	p.Anchored = true
	p.Color = st.color
	p.Material = st.material or Enum.Material.SmoothPlastic
	p.Transparency = st.transparency or 0
	p.CanCollide = st.collide
	p.CanQuery = st.query
	p.CanTouch = if st.touch == nil then true else st.touch
	p.CastShadow = if st.shadow == nil then true else st.shadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function tag(inst: Instance, name: string)
	CollectionService:AddTag(inst, name)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Axis-aligned block from min corner (x0,y0,z0) to max corner (x1,y1,z1), map-local studs.
local function box(parent: Instance, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, st: Style): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = CFrame.new(at(Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)))
	applyStyle(p, st)
	p.Parent = parent
	return p
end

-- Block by centre + size (optionally facing a point, for markers / lights).
local function block(parent: Instance, name: string, center: Vector3, size: Vector3, st: Style, lookAt: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if lookAt then
		p.CFrame = CFrame.lookAt(at(center), at(lookAt))
	else
		p.CFrame = CFrame.new(at(center))
	end
	applyStyle(p, st)
	p.Parent = parent
	return p
end

-- Vertical cylinder (axis = world Y), base on y0.
local function vCylinder(parent: Instance, name: string, x: number, y0: number, z: number, height: number, diameter: number, st: Style): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(at(Vector3.new(x, y0 + height / 2, z))) * CFrame.Angles(0, 0, math.rad(90))
	applyStyle(p, st)
	p.Parent = parent
	return p
end

-- Cylinder with its axis along world X.
local function xCylinder(parent: Instance, name: string, center: Vector3, length: number, diameter: number, st: Style): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, diameter, diameter)
	p.CFrame = CFrame.new(at(center))
	applyStyle(p, st)
	p.Parent = parent
	return p
end

----------------------------------------------------------------------------
-- Ramps: invisible WedgePart + visual plank. Orientation is verified with a raycast and flipped if
-- needed (the wedge slope is expected to descend toward the part's Front / -Z face).
----------------------------------------------------------------------------

local report: { string } = {}
local problems: { string } = {}

local function note(line: string)
	table.insert(report, line)
end

local function problem(line: string)
	table.insert(problems, line)
end

local function rayDownOnly(part: BasePart, x: number, z: number, fromY: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { part }
	local result = Workspace:Raycast(at(Vector3.new(x, fromY, z)), Vector3.new(0, -400, 0), params)
	if result then
		return result.Position.Y - ORIGIN.Y
	end
	return nil
end

-- low / high = centre of the ramp's low edge (Y = surface it starts on) and high edge (Y = surface it ends on)
local function ramp(parent: Instance, name: string, low: Vector3, high: Vector3, width: number, plankStyle: Style): WedgePart
	local flat = Vector3.new(high.X - low.X, 0, high.Z - low.Z)
	local run = flat.Magnitude
	local rise = high.Y - low.Y
	local dir = flat.Unit
	local center = Vector3.new((low.X + high.X) / 2, low.Y + rise / 2, (low.Z + high.Z) / 2)
	local angle = math.deg(math.atan2(rise, run))

	local wedge = Instance.new("WedgePart")
	wedge.Name = name .. "_Collider"
	wedge.Size = Vector3.new(width, rise, run)
	wedge.CFrame = CFrame.lookAt(at(center), at(center) - dir) -- Front (-Z) toward the low end
	applyStyle(wedge, ST.rampCollider)
	wedge.Parent = parent

	-- verify: surface at 85 % of the way up must be ~85 % of the rise
	local function check(): boolean
		local probe = low:Lerp(high, 0.85)
		local y = rayDownOnly(wedge, probe.X, probe.Z, high.Y + 50)
		return y ~= nil and math.abs(y - (low.Y + rise * 0.85)) < 1
	end
	local flipped = false
	if not check() then
		wedge.CFrame = CFrame.lookAt(at(center), at(center) + dir)
		flipped = true
		if not check() then
			problem(`{name}: ramp surface not where expected even after flip — inspect manually`)
		end
	end
	if angle > 35 then
		problem(`{name}: slope {string.format("%.1f", angle)}° > 35°`)
	end
	note(string.format("%-14s rise %4.1f run %4.1f width %2d → %.1f°%s", name, rise, run, width, angle, if flipped then " (wedge flipped)" else ""))

	-- visual plank on the slope (no collision / query)
	local slopeLen = math.sqrt(run * run + rise * rise)
	local thickness = 0.6
	local plank = Instance.new("Part")
	plank.Name = name .. "_Visual"
	plank.Size = Vector3.new(width, thickness, slopeLen)
	plank.CFrame = CFrame.lookAt(at(center), at(high)) * CFrame.new(0, thickness / 2 + 0.05, 0)
	applyStyle(plank, plankStyle)
	plank.Parent = parent
	return wedge
end

----------------------------------------------------------------------------
-- Gameplay markup helpers (contract: docs/ARCHITECTURE.md §6)
----------------------------------------------------------------------------

local function anchorModel(parent: Instance, name: string, objectiveId: string, partLetter: string?, promptPos: Vector3): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local pp = block(m, "PromptPart", promptPos, Vector3.new(2, 2, 2), ST.promptPart)
	m.PrimaryPart = pp
	m:SetAttribute("ObjectiveId", objectiveId)
	if partLetter then
		m:SetAttribute("Part", partLetter)
	end
	tag(m, TAG.ObjectiveAnchor)
	return m
end

local floorSpawnParts: { BasePart } = {}
local lateSpawnParts: { BasePart } = {}
local noImpactParts: { BasePart } = {}

-- Spawn pad: 4 × 0.2 × 4, top flush with the floor + 0.2; faces north (-Z). MapService spawns at
-- pad top + SPAWN_HEIGHT_OFFSET (3).
local function playerSpawn(parent: Instance, name: string, x: number, y: number, z: number, priority: number, enabledBy: string?): Part
	local p = block(parent, name, Vector3.new(x, y + 0.1, z), Vector3.new(4, 0.2, 4), if enabledBy then ST.spawnPadLate else ST.spawnPad)
	p:SetAttribute("Priority", priority)
	if enabledBy then
		p:SetAttribute("EnabledBy", enabledBy)
		table.insert(lateSpawnParts, p)
	else
		table.insert(floorSpawnParts, p)
	end
	tag(p, TAG.PlayerSpawn)
	return p
end

-- NoImpact volume: 12 × 30 × 12 box centred on a floor spawn (covers radius 6, GDD §8.3).
local function noImpactAround(parent: Instance, name: string, x: number, y: number, z: number): Part
	local p = block(parent, name, Vector3.new(x, y + 13, z), Vector3.new(12, 30, 12), ST.noImpact)
	tag(p, TAG.NoImpact)
	table.insert(noImpactParts, p)
	return p
end

-- ItemSpawn: 2 × 1 × 2 marker whose bottom sits on the floor (item placed at its centre).
local function itemSpawn(parent: Instance, name: string, x: number, y: number, z: number, zone: string): Part
	local p = block(parent, name, Vector3.new(x, y + 0.5, z), Vector3.new(2, 1, 2), ST.itemSpawn)
	p:SetAttribute("ItemType", ITEM_TYPE)
	p:SetAttribute("Zone", zone)
	tag(p, TAG.ItemSpawn)
	return p
end

----------------------------------------------------------------------------
-- Clean previous build (idempotent)
----------------------------------------------------------------------------

local recording: string? = nil
local okRec, recOrErr = pcall(function()
	return ChangeHistoryService:TryBeginRecording("BuildMidnightKitchen")
end)
if okRec then
	recording = recOrErr
end

local mapsFolder = ServerStorage:FindFirstChild("Maps")
if mapsFolder and not mapsFolder:IsA("Folder") then
	warn("[BuildMidnightKitchen] ServerStorage.Maps exists but is not a Folder — it will be used anyway")
end
if not mapsFolder then
	local f = Instance.new("Folder")
	f.Name = "Maps"
	f.Parent = ServerStorage
	mapsFolder = f
end
local mapsParent = mapsFolder :: Instance

for _, old in { mapsParent:FindFirstChild(MAP_NAME), Workspace:FindFirstChild(MAP_NAME .. "_BUILD"), Workspace:FindFirstChild("Lobby") } do
	if old then
		old:Destroy()
	end
end
if Workspace:FindFirstChild("Map") then
	warn("[BuildMidnightKitchen] Workspace.Map exists in edit mode (left over from a play session?) — not touched; delete it manually")
end

----------------------------------------------------------------------------
-- MAP ROOT
----------------------------------------------------------------------------

local map = Instance.new("Model")
map.Name = MAP_NAME .. "_BUILD" -- renamed to MAP_NAME when moved to ServerStorage.Maps
map:SetAttribute("KillY", KILL_Y)
map.Parent = Workspace -- temporarily, so verification raycasts can hit it

local fStructure = folder(map, "Structure")
local fRoutes = folder(map, "Routes")
local fProps = folder(map, "Props")
local fObjectives = folder(map, "Objectives")
local fSpawns = folder(map, "Spawns")
local fItems = folder(map, "ItemSpawns")
local fVolumes = folder(map, "Volumes")
local fExit = folder(map, "Exit")
local fLights = folder(map, "Lights")

----------------------------------------------------------------------------
-- Structure: floor, boundary, counters, sill, exterior
----------------------------------------------------------------------------

local floor = box(fStructure, "Floor", -4, -2, -4, 164, 0, 124, ST.floor) -- top Y 0
map.PrimaryPart = floor

-- Invisible boundary (CanCollide true, CanQuery false — GDD §8.3 / D9)
box(fStructure, "InvisWall_W", -4, 0, -4, 0, 125, 124, ST.invisibleWall)
box(fStructure, "InvisWall_E", 160, 0, -4, 164, 125, 124, ST.invisibleWall)
box(fStructure, "InvisWall_S", -4, 0, 120, 164, 125, 124, ST.invisibleWall)
box(fStructure, "InvisCeiling", -4, 125, -4, 164, 127, 124, ST.invisibleWall)

-- North (window) wall, visible, Z -4..0. Window opening X 46..106, Y 61..111 (60 × 50, Art §2 #6).
-- The lower piece's top (Y 61) is the sill through the wall thickness.
box(fStructure, "NorthWall_Lower", -4, 0, -4, 164, 61, 0, ST.northWall)
box(fStructure, "NorthWall_Upper", -4, 111, -4, 164, 125, 0, ST.northWall)
box(fStructure, "NorthWall_West", -4, 61, -4, 46, 111, 0, ST.northWall)
box(fStructure, "NorthWall_East", 106, 61, -4, 164, 111, 0, ST.northWall)

-- L counter: north arm X 36..160 Z 0..30, east arm X 130..160 Z 30..84. Top surface Y 45.
box(fStructure, "CounterN_Cabinet", 36, 0, 0, 160, 43, 30, ST.cabinet)
box(fStructure, "CounterN_Top", 36, 43, 0, 160, 45, 30, ST.counterTop)
box(fStructure, "CounterE_Cabinet", 130, 0, 30, 160, 43, 84, ST.cabinet)
box(fStructure, "CounterE_Top", 130, 43, 30, 160, 45, 84, ST.counterTop)

-- Interior window sill +61, depth 10 (Z 0..10): solid block above the counter (X 36..110),
-- a wall shelf over the NW nook (X 0..36) that joins the curtain top to the sill.
box(fStructure, "WindowSill_Inner", 36, 45, 0, 110, 61, 10, ST.sill)
box(fStructure, "WindowSill_WestShelf", 0, 58, 0, 36, 61, 10, ST.sill)

-- Exterior: sill strip + flower box, both top +61; invisible fence so nobody walks into the void.
box(fStructure, "ExteriorSill", 42, 59, -12, 110, 61, -4, ST.sill)
box(fStructure, "FlowerBox", 61, 52, -30, 91, 61, -4, ST.planter) -- 30 × 26 outer (Art §2 #7)
local soil = box(fStructure, "FlowerBox_Soil", 62, 61, -29, 90, 61.05, -5, ST.soil) -- colour plate only
soil.CanCollide = false
soil.CanQuery = false
box(fStructure, "Fence_SillNW", 42, 61, -13, 61, 125, -12, ST.invisibleWall)
box(fStructure, "Fence_SillNE", 91, 61, -13, 110, 125, -12, ST.invisibleWall)
box(fStructure, "Fence_BoxW", 60, 61, -31, 61, 125, -12, ST.invisibleWall)
box(fStructure, "Fence_BoxE", 91, 61, -31, 92, 125, -12, ST.invisibleWall)
box(fStructure, "Fence_BoxN", 60, 61, -31, 92, 125, -30, ST.invisibleWall)
box(fStructure, "Fence_SillW", 41, 61, -12, 42, 125, -4, ST.invisibleWall)
box(fStructure, "Fence_SillE", 110, 61, -12, 111, 125, -4, ST.invisibleWall)

----------------------------------------------------------------------------
-- Routes
----------------------------------------------------------------------------

-- Main climb (floor → counter), switchback along the north counter's south face:
--   Ramp1 floor (X 64) → seat (X 100) at Z 42..56; seat X 100..121 Z 30..56 at +23;
--   Ramp2 seat (X 100) → counter (X 66) at Z 30..42, resting on a cookbook stack (+23).
--   At Ramp2's top the counter edge (Z 30) is right beside it: step north onto the counter.
ramp(fRoutes, "Ramp1_CuttingBoard", Vector3.new(64, 0, 49), Vector3.new(100, 23, 49), 14, ST.plankWood)
box(fRoutes, "CookbookStack", 66, 0, 30, 100, 23, 42, ST.walkProp)
ramp(fRoutes, "Ramp2_Cookbooks", Vector3.new(100, 23, 36), Vector3.new(66, 45, 36), 12, ST.plankBooks)

-- Step chair (seat +23 is a walk surface). Legs/back are props.
box(fRoutes, "StepChair_Seat", 100, 21, 30, 121, 23, 56, ST.walkProp)
for i, pos in { Vector2.new(101, 31), Vector2.new(120, 31), Vector2.new(101, 55), Vector2.new(120, 55) } do
	box(fProps, "StepChair_Leg" .. i, pos.X - 1, 0, pos.Y - 1, pos.X + 1, 21, pos.Y + 1, ST.propWood)
end
box(fProps, "StepChair_Back", 119.5, 23, 30, 121, 45, 56, ST.propWood)

-- Dish rack (main exit route): counter +45 (X 54) → sill +61 (X 80) at Z 10..20, rising east.
-- Top end is in front of the CENTER pane (X 66..86): step north onto the sill, walk out.
ramp(fRoutes, "Ramp3_DishRack", Vector3.new(54, 45, 15), Vector3.new(80, 61, 15), 10, ST.plankTray)
-- dish-rack basket frame (visual)
box(fProps, "DishRack_Basket", 57, 45, 20.2, 79.5, 52, 20.6, ST.decor)

-- Curtain (fallback route, never collapses): hidden TrussPart in the NW nook, X 14..36 Z 10..18,
-- Y -1..61. South face climbable from the floor; east face (X 36) rises 16 above the counter top,
-- so it is also climbable from the counter. Top (Y 61) joins the west shelf / sill (Z 0..10).
local truss = Instance.new("TrussPart")
truss.Name = "Curtain_Truss"
truss.Size = Vector3.new(22, 62, 8)
truss.CFrame = CFrame.new(at(Vector3.new(25, 30, 14)))
applyStyle(truss, ST.truss)
truss.Parent = fRoutes

-- curtain visuals (pleats + rod), non-colliding
for i = 0, 3 do
	vCylinder(fProps, "Curtain_Pleat" .. (i + 1), 17 + i * 5.5, 0, 20.5, 115, 5, ST.curtain)
end
local rod = xCylinder(fProps, "Curtain_Rod", Vector3.new(25, 116, 20.5), 30, 1.5, ST.propWood)
rod.CanCollide = false

----------------------------------------------------------------------------
-- Props (blocking, CanQuery = false unless walked on)
----------------------------------------------------------------------------

-- Fridge [B] against the west wall: 35 × 90 × 35 (Art §2 #13)
box(fProps, "Fridge", 0, 0, 50, 35, 90, 85, ST.propWhite)
-- Pantry door [P] on the west wall of the NW nook (closed): 40 wide × 100 tall
box(fProps, "PantryDoor", 0, 0, 4, 2, 100, 44, ST.propWood)

-- Dining table [T]: top 60 × 1.5 × 40 at +37.5, legs 2.5 (walk under it)
box(fProps, "Table_Top", 40, 36.75, 62, 100, 38.25, 102, ST.propWood)
for i, pos in { Vector2.new(41.25, 63.25), Vector2.new(98.75, 63.25), Vector2.new(41.25, 100.75), Vector2.new(98.75, 100.75) } do
	box(fProps, "Table_Leg" .. i, pos.X - 1.25, 0, pos.Y - 1.25, pos.X + 1.25, 36.75, pos.Y + 1.25, ST.propWood)
end

-- Fallen hamster cage [A] (SW corner) 30 × 20 × 20, open side faces north (into the room)
box(fProps, "Cage_TrayWall", 4, 0, 117, 34, 20, 118, ST.propTray)
box(fProps, "Cage_BarsW", 4, 0, 98, 4.4, 20, 117, ST.bars)
box(fProps, "Cage_BarsE", 33.6, 0, 98, 34, 20, 117, ST.bars)
box(fProps, "Cage_BarsTop", 4, 19.6, 98, 34, 20, 117, ST.bars)

-- Shoe rack [S] on the south wall: 30 × 22.5 × 15, two compartments; batteries between shoes
box(fProps, "ShoeRack_SideW", 96, 0, 105, 97, 22.5, 120, ST.propWood)
box(fProps, "ShoeRack_SideE", 125, 0, 105, 126, 22.5, 120, ST.propWood)
box(fProps, "ShoeRack_Shelf", 97, 10, 105, 125, 11, 120, ST.propWood)
box(fProps, "ShoeRack_Top", 96, 21.5, 105, 126, 22.5, 120, ST.propWood)
box(fProps, "Shoe_1", 98, 0, 106, 103, 5, 120, ST.prop)
box(fProps, "Shoe_2", 119, 0, 106, 124, 5, 120, ST.prop)
box(fProps, "Shoe_3", 100, 11, 106, 108, 15, 120, ST.prop)

-- Back door (decor on the south wall, closed)
box(fProps, "BackDoor", 128, 0, 119, 156, 100, 120, ST.propWood)

-- Sink under the window (flat, no hole — Art §2 #19), decor plate on the counter
box(fProps, "Sink", 84, 45, 10, 109, 45.1, 28, ST.sink)

----------------------------------------------------------------------------
-- Objectives (ObjectiveAnchor models, child PromptPart)
----------------------------------------------------------------------------

-- RunWheel [C] — floor, centre-east. Wheel Ø14 × 7, axle +7.5, all wheel parts non-colliding.
do
	local m = anchorModel(fObjectives, "RunWheel", "RunWheel", nil, Vector3.new(116, 2, 72)) -- PromptPart inside the wheel, +2
	box(m, "Wheel_Base", 111, 0, 67.5, 121, 0.5, 76.5, ST.wheelBase)
	xCylinder(m, "Wheel_Drum", Vector3.new(116, 7.5, 72), 7, 14, ST.wheel)
	block(m, "Dynamo", Vector3.new(116, 2, 82), Vector3.new(6, 4, 4), ST.dynamo)
end

-- DeliverBatteries socket (charger) [B] — floor, beside the fridge's north-east corner.
do
	local m = anchorModel(fObjectives, "Charger", "DeliverBatteries", nil, Vector3.new(41, 3.5, 52))
	box(m, "Charger_Box", 36, 0, 48.5, 46, 2, 55.5, ST.charger)
	block(m, "Charger_Unit", Vector3.new(41, 2.875, 52), Vector3.new(6.5, 1.75, 4), ST.chargerUnit)
end

-- CallForHelp radios A–D on the counter (+45). Straight-line spacing ≥ 40 (GDD §8.3).
local radioPositions: { [string]: Vector3 } = {
	A = Vector3.new(42, 45, 20), -- north arm, west end (next to the curtain top)
	B = Vector3.new(100, 45, 26), -- north arm, by the sink
	C = Vector3.new(145, 45, 15), -- L corner
	D = Vector3.new(145, 45, 55), -- east arm, 40 south of C
}
local radioStyles: { [string]: Style } = { A = ST.radioA, B = ST.radioB, C = ST.radioC, D = ST.radioD }
for _, letter in { "A", "B", "C", "D" } do
	local base = radioPositions[letter]
	local m = anchorModel(fObjectives, "Radio_" .. letter, "CallForHelp", letter, base + Vector3.new(0, 2.6, 0))
	block(m, "Radio_Body", base + Vector3.new(0, 4, 0), Vector3.new(3, 8, 2), radioStyles[letter])
	vCylinder(m, "Radio_Antenna", base.X + 1, base.Y + 8, base.Z, 4, 0.3, ST.antenna)
end

----------------------------------------------------------------------------
-- Spawns + NoImpact
----------------------------------------------------------------------------

-- Floor spawns ×4 inside the fallen cage, Priority 2, no EnabledBy → NoImpact r6 each.
for i, pos in { Vector2.new(12, 104), Vector2.new(26, 104), Vector2.new(12, 112), Vector2.new(26, 112) } do
	playerSpawn(fSpawns, "Spawn_Cage" .. i, pos.X, 0, pos.Y, 2, nil)
	noImpactAround(fVolumes, "NoImpact_Cage" .. i, pos.X, 0, pos.Y)
end
-- Sill spawns ×2 (inside the window, in front of the two opening panes), Priority 1,
-- EnabledBy = WindowOpen, deliberately WITHOUT NoImpact (GDD §8.3 / D2).
playerSpawn(fSpawns, "Spawn_Sill1", 56, 61, 5, 1, EXIT_FLAG)
playerSpawn(fSpawns, "Spawn_Sill2", 76, 61, 5, 1, EXIT_FLAG)

----------------------------------------------------------------------------
-- Battery ItemSpawns: 3 zones × 2 (T = table, S = shoe rack, P = pantry nook)
----------------------------------------------------------------------------

itemSpawn(fItems, "Battery_T1", 52, 0, 90, "T") -- under the table, south-west
itemSpawn(fItems, "Battery_T2", 94, 0, 68, "T") -- under the table, north-east
itemSpawn(fItems, "Battery_S1", 104, 0, 100, "S") -- floor in front of the shoe rack (was inside it: unreachable)
itemSpawn(fItems, "Battery_S2", 90, 0, 94, "S") -- floor under the table, east side (was inside a shoe)
itemSpawn(fItems, "Battery_P1", 8, 0, 40, "P") -- by the pantry door
itemSpawn(fItems, "Battery_P2", 6, 0, 8, "P") -- behind the curtain, under the west shelf

----------------------------------------------------------------------------
-- Exit: window panes (LockedDoor), Exit Zone, vehicle spot, win camera
----------------------------------------------------------------------------

-- Three panes 20 wide (Art §2 #6). West + centre open on WindowOpen (server hides every BasePart
-- in a LockedDoor model), east pane is fixed glass.
do
	local west = Instance.new("Model")
	west.Name = "Window_West"
	west.Parent = fExit
	box(west, "Pane", 46, 61, -2.2, 66, 111, -1.8, ST.glass)
	west:SetAttribute("UnlockedBy", EXIT_FLAG)
	tag(west, TAG.LockedDoor)

	local centre = Instance.new("Model")
	centre.Name = "Window_Center"
	centre.Parent = fExit
	box(centre, "Pane", 66, 61, -2.2, 86, 111, -1.8, ST.glass)
	centre:SetAttribute("UnlockedBy", EXIT_FLAG)
	tag(centre, TAG.LockedDoor)

	box(fExit, "Window_East_Fixed", 86, 61, -2.2, 106, 111, -1.8, ST.glass)
end

-- Exit Zone 24 × 12 × 24 over the flower-box soil (X 64..88, Z -28..-4, Y 61..73)
local exitZone = block(fExit, "ExitZone", Vector3.new(76, 67, -16), Vector3.new(24, 12, 24), ST.exitZone)
exitZone:SetAttribute("Open", false)
tag(exitZone, TAG.ExitZone)

-- RescueCarrier (26 × 17 × 18, PrimaryPart Base) lands with Base centre on this spot (soil +61).
local vehicleSpot = block(fExit, "ExitVehicleSpot", Vector3.new(76, 61.5, -16), Vector3.new(4, 1, 4), ST.marker)
tag(vehicleSpot, TAG.ExitVehicleSpot)

-- Win camera: outside, looking back at the flower box with the shaking kitchen behind it.
block(map, "WinCameraPoint", Vector3.new(76, 72, -54), Vector3.new(1, 1, 1), ST.marker, Vector3.new(76, 63, -8))

----------------------------------------------------------------------------
-- Map lights (Art §4.3) — mounts only; rescue lights start disabled (UI/Art enable on WindowOpen)
----------------------------------------------------------------------------

do
	local moon = block(fLights, "Moonlight", Vector3.new(76, 90, -30), Vector3.new(1, 1, 1), ST.lightMount, Vector3.new(76, 0, 40))
	local s = Instance.new("SpotLight")
	s.Color = Color3.fromRGB(170, 190, 255)
	s.Brightness = 2
	s.Range = 60 -- SpotLight Range max is 60
	s.Angle = 60
	s.Face = Enum.NormalId.Front
	s.Shadows = true
	s.Parent = moon

	type RescueLight = { name: string, color: Color3, x: number, shadows: boolean }
	local rescueLights: { RescueLight } = {
		{ name = "RescueLight_Red", color = Color3.fromRGB(255, 40, 40), x = 73, shadows = true },
		{ name = "RescueLight_Blue", color = Color3.fromRGB(40, 90, 255), x = 79, shadows = false },
	}
	for i, info in rescueLights do
		local name, color, x, shadows = info.name, info.color, info.x, info.shadows
		local mount = block(fLights, name, Vector3.new(x, 50, -44), Vector3.new(2, 1, 2), ST.decor, Vector3.new(76, 58, 30))
		mount.Material = Enum.Material.Neon
		mount.Color = color
		mount.Transparency = 1 -- shown by the client when the exit unlocks
		local spot = Instance.new("SpotLight")
		spot.Color = color
		spot.Brightness = 6
		spot.Range = 60
		spot.Angle = 50
		spot.Face = Enum.NormalId.Front
		spot.Shadows = shadows
		spot.Enabled = false
		spot.Parent = mount
		mount:SetAttribute("Order", i)
	end

	local fridgeLight = block(fLights, "FridgeLight", Vector3.new(38, 3, 50), Vector3.new(1, 1, 1), ST.lightMount)
	local fl = Instance.new("PointLight")
	fl.Color = Color3.fromRGB(200, 230, 255)
	fl.Brightness = 0.8
	fl.Range = 20
	fl.Parent = fridgeLight

	local nightLight = block(fLights, "CageNightLight", Vector3.new(36, 2, 96), Vector3.new(2, 2, 2), ST.decor)
	nightLight.Shape = Enum.PartType.Ball
	nightLight.Material = Enum.Material.Neon
	nightLight.Color = Color3.fromRGB(255, 200, 140)
	local nl = Instance.new("PointLight")
	nl.Color = Color3.fromRGB(255, 200, 140)
	nl.Brightness = 1
	nl.Range = 30
	nl.Parent = nightLight
end

----------------------------------------------------------------------------
-- Verification (map is in Workspace right now)
----------------------------------------------------------------------------

local function pointInPart(point: Vector3, part: BasePart): boolean
	local lp = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
end

-- 1) Grid raycast over the kitchen: every column must find a collidable, queryable surface.
do
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.RespectCanCollide = true
	local misses, total = 0, 0
	for x = 2, 158, 4 do
		for z = 2, 118, 4 do
			total += 1
			local r = Workspace:Raycast(at(Vector3.new(x, 120, z)), Vector3.new(0, -200, 0), params)
			if not r then
				misses += 1
			end
		end
	end
	note(`grid floor rays: {total - misses}/{total} hit a walkable surface`)
	if misses > 0 then
		problem(`{misses} grid columns found no floor`)
	end
end

-- 2) Radio spacing (≥ 30 required by §3.4, ≥ 40 target in §8.3)
do
	local letters = { "A", "B", "C", "D" }
	local minD, minPair = math.huge, ""
	for i = 1, #letters do
		for j = i + 1, #letters do
			local a = radioPositions[letters[i]]
			local b = radioPositions[letters[j]]
			local d = (a - b).Magnitude
			if d < minD then
				minD, minPair = d, letters[i] .. "-" .. letters[j]
			end
			if d < 30 then
				problem(`radio {letters[i]}-{letters[j]} only {string.format("%.1f", d)} apart (< 30)`)
			elseif d < 40 then
				note(`radio {letters[i]}-{letters[j]} {string.format("%.1f", d)} (below the 40 target)`)
			end
		end
	end
	note(`radio spacing: min straight-line {string.format("%.1f", minD)} ({minPair})`)
end

-- 3) Every floor spawn inside a NoImpact volume; sill spawns NOT inside one.
do
	for _, sp in floorSpawnParts do
		local covered = false
		for _, v in noImpactParts do
			if pointInPart(sp.Position, v) then
				covered = true
			end
		end
		if not covered then
			problem(`{sp.Name} has no NoImpact volume`)
		end
	end
	for _, sp in lateSpawnParts do
		for _, v in noImpactParts do
			if pointInPart(sp.Position, v) then
				problem(`{sp.Name} (EnabledBy) is inside NoImpact — must not be (GDD D2)`)
			end
		end
	end
	note(`spawns: {#floorSpawnParts} floor (Priority 2, NoImpact) + {#lateSpawnParts} sill (Priority 1, EnabledBy={EXIT_FLAG})`)
end

-- 4) Surface heights at key points
do
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.RespectCanCollide = true
	local checks = {
		{ "counter (north arm)", Vector3.new(120, 0, 20), 45 },
		{ "counter (east arm)", Vector3.new(145, 0, 70), 45 },
		{ "inner sill", Vector3.new(80, 0, 5), 61 },
		{ "west shelf", Vector3.new(8, 0, 5), 61 },
		{ "curtain truss top", Vector3.new(25, 0, 14), 61 },
		{ "exterior sill", Vector3.new(50, 0, -8), 61 },
		{ "flower box soil", Vector3.new(76, 0, -16), 61 },
		{ "step chair seat", Vector3.new(110, 0, 50), 23 },
		{ "floor under table", Vector3.new(70, 0, 80), 0 },
	}
	for _, c in checks do
		local label = c[1] :: string
		local p = c[2] :: Vector3
		local expected = c[3] :: number
		local r = Workspace:Raycast(at(Vector3.new(p.X, 120, p.Z)), Vector3.new(0, -200, 0), params)
		local y = if r then r.Position.Y - ORIGIN.Y else nil
		if not y or math.abs(y - expected) > 0.15 then
			problem(`surface '{label}' expected Y {expected}, got {if y then string.format("%.2f", y) else "nil"}`)
		end
	end
	note("surface heights: counter 45 / sills + flower box 61 / seat 23 / floor 0 checked")
end

-- 5) No SpawnLocation inside the map (it would hijack LoadCharacter)
for _, d in map:GetDescendants() do
	if d:IsA("SpawnLocation") then
		problem(`SpawnLocation inside the map: {d:GetFullName()}`)
	end
end

----------------------------------------------------------------------------
-- Move map into ServerStorage.Maps (or keep the preview)
----------------------------------------------------------------------------

map.WorldPivot = CFrame.new(ORIGIN)
if PREVIEW_IN_WORKSPACE then
	warn("[BuildMidnightKitchen] PREVIEW: map left in Workspace as MidnightKitchen_BUILD — re-run with PREVIEW_IN_WORKSPACE = false before playtesting")
else
	map.Name = MAP_NAME
	map.Parent = mapsParent
end

----------------------------------------------------------------------------
-- LOBBY (Workspace.Lobby) — 60 × 60 platform at X 3000, invisible walls + ceiling (CanQuery false)
----------------------------------------------------------------------------

do
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local half = LOBBY_SIZE / 2
	local c = LOBBY_CENTER
	local function lbox(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, st: Style): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
		p.CFrame = CFrame.new(c + Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
		applyStyle(p, st)
		p.Parent = lobby
		return p
	end
	local lfloor = lbox("Floor", -half, -2, -half, half, 0, half, ST.lobbyFloor)
	lobby.PrimaryPart = lfloor
	local t, h = 2, LOBBY_WALL_HEIGHT
	lbox("InvisWall_N", -half - t, 0, -half - t, half + t, h, -half, ST.invisibleWall)
	lbox("InvisWall_S", -half - t, 0, half, half + t, h, half + t, ST.invisibleWall)
	lbox("InvisWall_W", -half - t, 0, -half, -half, h, half, ST.invisibleWall)
	lbox("InvisWall_E", half, 0, -half, half + t, h, half, ST.invisibleWall)
	lbox("InvisCeiling", -half - t, h, -half - t, half + t, h + t, half + t, ST.invisibleWall)
	-- toy blocks to hop on while waiting (3 and 5.5 tall: each step < JumpHeight 7.2)
	lbox("ToyBlock_Low", 12, 0, 12, 20, 3, 20, ST.lobbyToy)
	lbox("ToyBlock_High", 12, 0, 20, 20, 5.5, 28, ST.lobbyToy)

	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2
		local pos = Vector3.new(math.cos(angle) * 8, 0.1, math.sin(angle) * 8)
		local pad = lbox("LobbySpawn" .. i, pos.X - 2, 0, pos.Z - 2, pos.X + 2, 0.2, pos.Z + 2, ST.spawnPad)
		tag(pad, TAG.LobbySpawn)
	end
	-- Neutral SpawnLocation so LoadCharacter() lands in the Lobby before any PivotTo.
	local sl = Instance.new("SpawnLocation")
	sl.Name = "LobbySpawnLocation"
	sl.Size = Vector3.new(4, 0.2, 4)
	sl.CFrame = CFrame.new(c + Vector3.new(0, 0.1, 0))
	applyStyle(sl, ST.spawnPad)
	sl.Neutral = true
	sl.Duration = 0
	sl.AllowTeamChangeOnTouch = false
	sl.Parent = lobby
	lobby.Parent = Workspace
end

Workspace.FallenPartsDestroyHeight = FALLEN_PARTS_DESTROY_HEIGHT

----------------------------------------------------------------------------
-- Report
----------------------------------------------------------------------------

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

local partCount = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end

print("================ BuildMidnightKitchen ================")
print(`map: {map:GetFullName()}  parts: {partCount}  KillY: {KILL_Y}`)
for _, line in report do
	print("  " .. line)
end
if #problems == 0 then
	print("  RESULT: OK — no problems found")
else
	for _, line in problems do
		warn("  PROBLEM: " .. line)
	end
	warn(`  RESULT: {#problems} problem(s) — see above`)
end
print("=======================================================")

return true -- lets Rojo sync this as a ModuleScript (ServerStorage.Tools) so it can be run via require()
