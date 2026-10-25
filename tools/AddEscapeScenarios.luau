--!strict
--[[
	AddEscapeScenarios.luau — map markup for the escape scenarios (Config.Missions
	MidnightKitchen_CableWindow / MidnightKitchen_Drain, Features.NewMission) in
	ServerStorage.Maps.MidnightKitchen. Run AFTER BuildMidnightKitchen + AddItemSpawns.

	HOW TO RUN (Studio, EDIT mode): require(game.ServerStorage.Tools.AddEscapeScenarios)
	  or paste this file into the Command Bar → Enter. Ctrl+Z undoes it.

	IDEMPOTENT: rebuilds the map folder "Scenarios" and the Scn_* ItemSpawns; the floor is
	split around the drain hole only once (Structure.Floor_DrainE exists = already split).

	Adds (map-local coords = world; floor top Y 0, counter tops Y 45, inner window sill top Y 61):
	  * ItemSpawns Scn_* (ScenarioOnly = true, ItemType "Scenario"): used only by
	    MissionDef.fixedLoot, never by random loot or the legacy Battery spawn.
	  * Window scenario anchors: PryLatch (window latch), PushWindow A/B (sill).
	  * Table start: 4 PlayerSpawn pads on the dining table (EnabledBy "TableStart", Priority 0).
	  * Cable routes (CableThrowService, tag CableRoute): TN table->north counter bridge,
	    TE table->east counter bridge, FC floor->north counter climbing cable, TF floor<->table
	    climbing cable. Each: ThrowSpot, HookPoint + hook art, Cable (FlagReveal "Cable_<id>")
	    = walkable plank or invisible TrussPart + the visible cable. Anchors ObjectiveId
	    "CableToCounter" on the counter hooks (markers for the CableHook objective).
	  * Drain scenario: 8x8 hole in the floor under the step chair (DRAIN_CENTER), a metal
	    shaft down to Y -16, DrainGrate (LockedDoor, UnlockedBy "DrainOpen"), drain cable
	    (FlagReveal "DrainOpen"), popped screws (FlagReveal "GrateLoose"), anchors PryGrate,
	    LiftGrate A/B, TieDrainCable, ExitZone (ExitId "Drain"), DrainCameraPoint.
	  * Structure.DropArea = the old full floor (RandomPoint impacts keep the same area).
	With Features.NewMission off nothing here is used: FlagReveal parts stay hidden, the grate
	stays closed, the Drain ExitZone is untagged at match start (MapService.keepExitZones).
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MAP_NAME = "MidnightKitchen"
local DRAIN_CENTER = Vector3.new(110, 0, 37) -- floor point under the step chair, next to the sink cabinet
local HOLE = 8 -- hole width (X and Z)
local SHAFT_DEPTH = 16

local maps = ServerStorage:FindFirstChild("Maps")
local map = maps and maps:FindFirstChild(MAP_NAME)
if not (map and map:IsA("Model")) then
	warn(`[AddEscapeScenarios] ServerStorage.Maps.{MAP_NAME} not found`)
	return true
end
local structure = map:FindFirstChild("Structure") :: Folder
local routes = map:FindFirstChild("Routes") :: Folder
local itemSpawns = map:FindFirstChild("ItemSpawns") :: Folder
local floor = structure and structure:FindFirstChild("Floor")
if not (structure and routes and itemSpawns and floor and floor:IsA("BasePart")) then
	warn("[AddEscapeScenarios] map is missing Structure/Routes/ItemSpawns/Floor")
	return true
end

local recording: string? = nil
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("AddEscapeScenarios")
end)

----------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function invisible(p: BasePart)
	p.Transparency = 1
	p.CastShadow = false
end

-- ObjectiveAnchor model with a 2x2x2 invisible PromptPart at `pos`
local function anchor(parent: Instance, name: string, objectiveId: string, pos: Vector3, letter: string?): Model
	local m = Instance.new("Model")
	m.Name = name
	local pp = part(m, "PromptPart", Vector3.new(2, 2, 2), CFrame.new(pos), Color3.new(1, 1, 1))
	invisible(pp)
	m.PrimaryPart = pp
	m:SetAttribute("ObjectiveId", objectiveId)
	if letter then
		m:SetAttribute("Part", letter)
	end
	CollectionService:AddTag(m, "ObjectiveAnchor")
	m.Parent = parent
	return m
end

local function reveal(inst: Instance, flag: string)
	inst:SetAttribute("RevealedBy", flag)
	CollectionService:AddTag(inst, "FlagReveal")
end

-- cylinder between two points (Part.Shape Cylinder runs along local X)
local function cable(parent: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3): Part
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	local p = part(parent, name, Vector3.new(len, thick, thick), cf, color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

----------------------------------------------------------------------------
-- reset previous run
----------------------------------------------------------------------------

local old = map:FindFirstChild("Scenarios")
if old then
	old:Destroy()
end
for _, c in itemSpawns:GetChildren() do
	if string.sub(c.Name, 1, 4) == "Scn_" then
		c:Destroy()
	end
end

local root = Instance.new("Folder")
root.Name = "Scenarios"
root.Parent = map

----------------------------------------------------------------------------
-- ScenarioOnly item spawns (fixedLoot)
----------------------------------------------------------------------------

local SPAWNS: { { name: string, pos: Vector3, note: string } } = {
	{ name = "Scn_Table1", pos = Vector3.new(62, 38.25, 68), note = "table start: charger cable 1 (dining table top)" },
	{ name = "Scn_Table2", pos = Vector3.new(78, 38.25, 97), note = "table start: charger cable 2 (dining table top)" },
	{ name = "Scn_CounterW", pos = Vector3.new(58, 45, 25), note = "window: scissors, north counter west of the dish rack" },
	{ name = "Scn_Pantry", pos = Vector3.new(12, 0, 28), note = "drain: scissors, floor by the pantry door" },
	{ name = "Scn_BackCorner", pos = Vector3.new(150, 0, 100), note = "drain: charger cable, floor corner by the back door" },
	-- hiding spots (MissionDef.fixedLoot spawn lists pick one per round)
	{ name = "Scn_TableFruit", pos = Vector3.new(94, 38.25, 99), note = "table top, behind the fruit bowl" },
	{ name = "Scn_TableEdge", pos = Vector3.new(44, 38.25, 99), note = "table top, far west corner" },
	{ name = "Scn_UnderTable2", pos = Vector3.new(52, 0, 98), note = "floor under the table, by a leg" },
	{ name = "Scn_UnderChair", pos = Vector3.new(104, 0, 50), note = "floor under the step chair" },
	{ name = "Scn_BehindCurtain", pos = Vector3.new(14, 0, 14), note = "floor behind the curtain" },
	{ name = "Scn_ShoeRack", pos = Vector3.new(115, 0, 110), note = "floor under the shoe rack shelf" },
	{ name = "Scn_CageTray", pos = Vector3.new(19, 0, 115), note = "in the cage, by the tray wall" },
	{ name = "Scn_CounterE", pos = Vector3.new(150, 45, 80), note = "east counter, south end" },
	{ name = "Scn_SinkSide", pos = Vector3.new(114, 45, 24), note = "north counter, east of the sink" },
}
for _, def in SPAWNS do
	local p = part(itemSpawns, def.name, Vector3.new(2, 1, 2), CFrame.new(def.pos + Vector3.new(0, 0.5, 0)), Color3.fromRGB(80, 160, 255))
	invisible(p)
	p:SetAttribute("ItemType", "Scenario")
	p:SetAttribute("ScenarioOnly", true)
	p:SetAttribute("SizeClass", "Medium")
	p:SetAttribute("Zone", def.name)
	p:SetAttribute("Note", def.note)
	CollectionService:AddTag(p, "ItemSpawn")
end

----------------------------------------------------------------------------
-- Window scenario: cable bridge + window anchors
----------------------------------------------------------------------------

local win = Instance.new("Folder")
win.Name = "Window"
win.Parent = root

-- window latch on the inner face of the centre pane, bottom edge (sill top Y 61)
local latch = anchor(win, "PryLatch", "PryLatch", Vector3.new(76, 63, 2.5))
part(latch, "Latch", Vector3.new(4, 1.2, 0.8), CFrame.new(76, 62.4, -1.4), Color3.fromRGB(205, 175, 90), Enum.Material.Metal)
part(latch, "LatchTongue", Vector3.new(1.4, 0.6, 1.2), CFrame.new(77.4, 62.4, -0.4), Color3.fromRGB(180, 150, 70), Enum.Material.Metal)
local latchOpen = part(win, "LatchOpen_Mark", Vector3.new(1.4, 0.6, 1.2), CFrame.new(77.4, 63.6, -0.4) * CFrame.Angles(0, 0, math.rad(60)), Color3.fromRGB(180, 150, 70), Enum.Material.Metal)
reveal(latchOpen, "LatchOpen")
anchor(win, "PushWindow_A", "PushWindow", Vector3.new(56, 63, 3), "A")
anchor(win, "PushWindow_B", "PushWindow", Vector3.new(80, 63, 3), "B")


----------------------------------------------------------------------------
-- Table start pads + cable routes (CableThrowService)
----------------------------------------------------------------------------

local TABLE_Y = 38.25
local spawnsFolder = map:FindFirstChild("Spawns") or root
for i, pos in { Vector3.new(48, TABLE_Y, 70), Vector3.new(48, TABLE_Y, 95), Vector3.new(68, TABLE_Y, 96), Vector3.new(94, TABLE_Y, 68) } do
	local old = spawnsFolder:FindFirstChild(`Spawn_Table{i}`)
	if old then
		old:Destroy()
	end
	local pad = part(spawnsFolder, `Spawn_Table{i}`, Vector3.new(4, 0.2, 4), CFrame.new(pos + Vector3.new(0, 0.1, 0)), Color3.fromRGB(80, 200, 255))
	invisible(pad)
	pad:SetAttribute("EnabledBy", "TableStart")
	pad:SetAttribute("Priority", 0)
	CollectionService:AddTag(pad, "PlayerSpawn")
end

local cablesFolder = Instance.new("Folder")
cablesFolder.Name = "CableRoutes"
cablesFolder.Parent = root

local CABLE_WHITE = Color3.fromRGB(242, 242, 236)
local HOOK_GOLD = Color3.fromRGB(215, 170, 60)

-- a small hook / ring art at `pos`
local function hookArt(parent: Instance, pos: Vector3)
	local base = part(parent, "HookBase", Vector3.new(2.4, 0.6, 2.4), CFrame.new(pos + Vector3.new(0, -0.2, 0)), Color3.fromRGB(90, 90, 96), Enum.Material.Metal)
	base.CanQuery = false
	local ring = part(parent, "HookRing", Vector3.new(0.5, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 1, 0)), HOOK_GOLD, Enum.Material.Metal)
	ring.Shape = Enum.PartType.Cylinder
	local glow = part(parent, "HookGlow", Vector3.new(0.3, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 1, 0)), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.Transparency = 0.3
end

type RouteDef = {
	id: string,
	kind: string, -- "Bridge" | "Climb"
	spot: CFrame,
	spotSize: Vector3,
	hook: Vector3,
	a: Vector3, -- bridge: low end on the plank top / climb: truss bottom
	b: Vector3, -- bridge: high end / climb: truss top
	visualFrom: Vector3,
	visualTo: Vector3,
	power: number,
	window: number,
	counter: boolean,
}

local ROUTES: { RouteDef } = {
	{
		id = "TN", kind = "Bridge", counter = true, power = 0.7, window = 0.09,
		spot = CFrame.new(76, TABLE_Y + 3, 68), spotSize = Vector3.new(10, 6, 10),
		hook = Vector3.new(76, 45.5, 29.5),
		a = Vector3.new(76, TABLE_Y, 63), b = Vector3.new(76, 45, 29.5),
		visualFrom = Vector3.new(76, TABLE_Y + 0.4, 63), visualTo = Vector3.new(76, 45.6, 29.5),
	},
	{
		id = "TE", kind = "Bridge", counter = true, power = 0.7, window = 0.09,
		spot = CFrame.new(92, TABLE_Y + 3, 82), spotSize = Vector3.new(10, 6, 10),
		hook = Vector3.new(131.5, 45.5, 82),
		a = Vector3.new(99, TABLE_Y, 82), b = Vector3.new(131.5, 45, 82),
		visualFrom = Vector3.new(99, TABLE_Y + 0.4, 82), visualTo = Vector3.new(131.5, 45.6, 82),
	},
	{
		id = "FC", kind = "Climb", counter = true, power = 0.82, window = 0.08,
		spot = CFrame.new(62, 3, 38), spotSize = Vector3.new(7, 6, 9),
		hook = Vector3.new(62, 45.5, 29.5),
		a = Vector3.new(62, 0, 31), b = Vector3.new(62, 45, 31),
		visualFrom = Vector3.new(62, 45.6, 29.8), visualTo = Vector3.new(62, 0.4, 31.3),
	},
	{
		id = "TF", kind = "Climb", counter = false, power = 0.35, window = 0.1,
		spot = CFrame.new(46, TABLE_Y + 3, 88), spotSize = Vector3.new(8, 6, 10),
		hook = Vector3.new(37, 0.5, 90),
		a = Vector3.new(40, 0, 88), b = Vector3.new(40, TABLE_Y, 88),
		visualFrom = Vector3.new(40.6, TABLE_Y + 0.3, 88), visualTo = Vector3.new(37, 0.6, 90),
	},
}

for _, r in ROUTES do
	local m = Instance.new("Model")
	m.Name = `Route_{r.id}`
	m:SetAttribute("RouteId", r.id)
	m:SetAttribute("RequiredPower", r.power)
	m:SetAttribute("PowerWindow", r.window)
	m:SetAttribute("ReachesCounter", r.counter)
	m:SetAttribute("RouteKind", r.kind)
	m:SetAttribute("Attached", false)
	CollectionService:AddTag(m, "CableRoute")
	m.Parent = cablesFolder

	local spot = part(m, "ThrowSpot", r.spotSize, r.spot, Color3.fromRGB(80, 200, 255))
	invisible(spot)
	local hp = part(m, "HookPoint", Vector3.new(1, 1, 1), CFrame.new(r.hook), HOOK_GOLD)
	invisible(hp)
	m.PrimaryPart = hp

	-- hook art (always visible: tells players where to cast) — anchor for the CableHook marker
	local hookModel = Instance.new("Model")
	hookModel.Name = "Hook"
	hookModel.Parent = m
	hookArt(hookModel, r.hook)
	if r.counter then
		local anc = anchor(m, `HookMarker_{r.id}`, "CableToCounter", r.hook + Vector3.new(0, 2, 0))
		anc:SetAttribute("Part", r.id)
	end

	-- the cable that appears when hooked
	local cableModel = Instance.new("Model")
	cableModel.Name = "Cable"
	cableModel.Parent = m
	if r.kind == "Bridge" then
		local dir = r.b - r.a
		local len = dir.Magnitude
		local cf = CFrame.lookAt((r.a + r.b) / 2, r.b) * CFrame.new(0, -0.5, 0)
		local plank = part(cableModel, "Walk", Vector3.new(4, 1, len + 1), cf, CABLE_WHITE, nil, true)
		plank.Transparency = 1
		local ribbon = part(cableModel, "Ribbon", Vector3.new(3.2, 0.45, len), cf * CFrame.new(0, 0.3, 0), CABLE_WHITE)
		ribbon.CanQuery = false
		part(cableModel, "Stripe", Vector3.new(0.6, 0.5, len), cf * CFrame.new(0, 0.32, 0), Color3.fromRGB(70, 70, 76)).CanQuery = false
		cable(cableModel, "Strand", r.visualFrom + Vector3.new(1.9, 0.2, 0), r.visualTo + Vector3.new(1.9, 0.2, 0), 0.5, CABLE_WHITE)
	else
		local truss = Instance.new("TrussPart")
		truss.Name = "Climb"
		truss.Anchored = true
		truss.Size = Vector3.new(2, (r.b.Y - r.a.Y), 2)
		truss.CFrame = CFrame.new((r.a + r.b) / 2)
		truss.Transparency = 1
		truss.Parent = cableModel
		cable(cableModel, "Strand", r.visualFrom, r.visualTo, 0.7, CABLE_WHITE)
		-- knots every few studs (grip look)
		local steps = math.floor((r.visualFrom - r.visualTo).Magnitude / 5)
		for k = 1, steps - 1 do
			local p = r.visualFrom:Lerp(r.visualTo, k / steps)
			part(cableModel, `Knot{k}`, Vector3.new(1.1, 1.1, 1.1), CFrame.new(p), CABLE_WHITE).Shape = Enum.PartType.Ball
		end
	end
	part(cableModel, "Plug", Vector3.new(2.2, 1.6, 1.8), CFrame.new(r.hook + Vector3.new(0, 0.6, 0)), Color3.fromRGB(235, 235, 235))
	reveal(cableModel, `Cable_{r.id}`)
end

----------------------------------------------------------------------------
-- Drain scenario
----------------------------------------------------------------------------

local drain = Instance.new("Folder")
drain.Name = "Drain"
drain.Parent = root

local c = DRAIN_CENTER
local h = HOLE / 2
local x0, x1, z0, z1 = c.X - h, c.X + h, c.Z - h, c.Z + h

-- split the floor once (keep "Floor" = PrimaryPart as the west piece)
if not structure:FindFirstChild("Floor_DrainE") then
	local fp = floor :: BasePart
	local fMin = fp.Position - fp.Size / 2
	local fMax = fp.Position + fp.Size / 2
	-- DropArea keeps RandomPoint impacts on the whole old floor (bottom = floor top)
	if not structure:FindFirstChild("DropArea") then
		local da = part(structure, "DropArea", Vector3.new(fp.Size.X, 1, fp.Size.Z), CFrame.new(fp.Position.X, fMax.Y + 0.5, fp.Position.Z), Color3.new(1, 0, 0))
		invisible(da)
	end
	local function piece(name: string, ax: number, bx: number, az: number, bz: number): BasePart
		local p = if name == "Floor" then fp else fp:Clone()
		p.Name = name
		p.Size = Vector3.new(bx - ax, fp.Size.Y, bz - az)
		p.CFrame = CFrame.new((ax + bx) / 2, fp.Position.Y, (az + bz) / 2)
		p.Parent = structure
		return p
	end
	piece("Floor_DrainE", x1, fMax.X, fMin.Z, fMax.Z)
	piece("Floor_DrainN", x0, x1, fMin.Z, z0)
	piece("Floor_DrainS", x0, x1, z1, fMax.Z)
	piece("Floor", fMin.X, x0, fMin.Z, fMax.Z)

	-- floor decor lines crossing the hole: cut them
	local tiles = map:FindFirstChild("Decor") and (map :: any).Decor:FindFirstChild("FloorTiles")
	if tiles then
		for _, t in tiles:GetChildren() do
			if t:IsA("BasePart") then
				local tMin, tMax = t.Position - t.Size / 2, t.Position + t.Size / 2
				local overlaps = tMax.X > x0 and tMin.X < x1 and tMax.Z > z0 and tMin.Z < z1
				if overlaps then
					if t.Size.X >= t.Size.Z then
						if tMin.X < x0 then
							local a = t:Clone()
							a.Size = Vector3.new(x0 - tMin.X, t.Size.Y, t.Size.Z)
							a.Position = Vector3.new((tMin.X + x0) / 2, t.Position.Y, t.Position.Z)
							a.Parent = tiles
						end
						if tMax.X > x1 then
							local b = t:Clone()
							b.Size = Vector3.new(tMax.X - x1, t.Size.Y, t.Size.Z)
							b.Position = Vector3.new((x1 + tMax.X) / 2, t.Position.Y, t.Position.Z)
							b.Parent = tiles
						end
					else
						if tMin.Z < z0 then
							local a = t:Clone()
							a.Size = Vector3.new(t.Size.X, t.Size.Y, z0 - tMin.Z)
							a.Position = Vector3.new(t.Position.X, t.Position.Y, (tMin.Z + z0) / 2)
							a.Parent = tiles
						end
						if tMax.Z > z1 then
							local b = t:Clone()
							b.Size = Vector3.new(t.Size.X, t.Size.Y, tMax.Z - z1)
							b.Position = Vector3.new(t.Position.X, t.Position.Y, (z1 + tMax.Z) / 2)
							b.Parent = tiles
						end
					end
					t:Destroy()
				end
			end
		end
	end
end

-- shaft (metal box under the hole)
local metal = Color3.fromRGB(88, 90, 96)
local d = SHAFT_DEPTH
local shaft = Instance.new("Model")
shaft.Name = "DrainShaft"
shaft.Parent = drain
part(shaft, "Wall_W", Vector3.new(1, d, HOLE + 2), CFrame.new(x0 - 0.5, -d / 2, c.Z), metal, Enum.Material.Metal, true)
part(shaft, "Wall_E", Vector3.new(1, d, HOLE + 2), CFrame.new(x1 + 0.5, -d / 2, c.Z), metal, Enum.Material.Metal, true)
part(shaft, "Wall_N", Vector3.new(HOLE, d, 1), CFrame.new(c.X, -d / 2, z0 - 0.5), metal, Enum.Material.Metal, true)
part(shaft, "Wall_S", Vector3.new(HOLE, d, 1), CFrame.new(c.X, -d / 2, z1 + 0.5), metal, Enum.Material.Metal, true)
part(shaft, "Bottom", Vector3.new(HOLE + 2, 1, HOLE + 2), CFrame.new(c.X, -d - 0.5, c.Z), Color3.fromRGB(55, 58, 62), Enum.Material.Metal, true)
-- pipe mouth on the north wall (leads outside) with a faint daylight glow
local mouth = part(shaft, "PipeMouth", Vector3.new(0.2, 6, 6), CFrame.new(c.X, -d + 3.5, z0 + 0.05) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(15, 15, 18))
mouth.Shape = Enum.PartType.Cylinder
local glow = part(shaft, "PipeGlow", Vector3.new(0.2, 4.5, 4.5), CFrame.new(c.X, -d + 3.5, z0 + 0.15) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(170, 210, 255), Enum.Material.Neon)
glow.Shape = Enum.PartType.Cylinder
glow.Transparency = 0.5
local light = Instance.new("PointLight")
light.Color = Color3.fromRGB(170, 210, 255)
light.Range = 14
light.Brightness = 1.5
light.Parent = glow

-- grate: closed until the exit unlocks (ExtractionService.unlockDoors(DrainOpen))
local grate = Instance.new("Model")
grate.Name = "DrainGrate"
grate:SetAttribute("UnlockedBy", "DrainOpen")
CollectionService:AddTag(grate, "LockedDoor")
grate.Parent = drain
local steel = Color3.fromRGB(150, 155, 162)
local blocker = part(grate, "GrateCollider", Vector3.new(HOLE + 0.8, 0.4, HOLE + 0.8), CFrame.new(c.X, 0.2, c.Z), steel, Enum.Material.Metal, true)
invisible(blocker)
local frameT = 0.8
part(grate, "Frame_N", Vector3.new(HOLE + 1.6, 0.3, frameT), CFrame.new(c.X, 0.15, z0 - 0.4), steel, Enum.Material.DiamondPlate)
part(grate, "Frame_S", Vector3.new(HOLE + 1.6, 0.3, frameT), CFrame.new(c.X, 0.15, z1 + 0.4), steel, Enum.Material.DiamondPlate)
part(grate, "Frame_W", Vector3.new(frameT, 0.3, HOLE), CFrame.new(x0 - 0.4, 0.15, c.Z), steel, Enum.Material.DiamondPlate)
part(grate, "Frame_E", Vector3.new(frameT, 0.3, HOLE), CFrame.new(x1 + 0.4, 0.15, c.Z), steel, Enum.Material.DiamondPlate)
for i = 1, 7 do
	local x = x0 + i * (HOLE / 8)
	part(grate, `Bar_{i}`, Vector3.new(0.45, 0.25, HOLE), CFrame.new(x, 0.13, c.Z), steel, Enum.Material.Metal)
end
-- dark hole under the bars (looks deep while closed)
local dark = part(grate, "Dark", Vector3.new(HOLE, 0.05, HOLE), CFrame.new(c.X, -0.3, c.Z), Color3.fromRGB(10, 10, 12))
dark.CanCollide = false

-- popped screws after prying (GrateLoose)
local screws = Instance.new("Model")
screws.Name = "PoppedScrews"
screws.Parent = drain
for i, off in { Vector3.new(-h - 1.8, 0, -h + 0.5), Vector3.new(h + 1.6, 0, -h + 1.2), Vector3.new(-h - 1.2, 0, h - 0.8), Vector3.new(h + 2, 0, h - 1.5) } do
	local s = part(screws, `Screw_{i}`, Vector3.new(0.9, 0.4, 0.4), CFrame.new(c + off + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(37 * i), 0), Color3.fromRGB(190, 190, 195), Enum.Material.Metal)
	s.Shape = Enum.PartType.Cylinder
end
reveal(screws, "GrateLoose")

-- cable tied to the step-chair leg and hanging down the shaft (DrainOpen)
local rope = Instance.new("Model")
rope.Name = "DrainCable"
rope.Parent = drain
local white = Color3.fromRGB(240, 240, 236)
local tie = Vector3.new(101.6, 1.2, 32)
local lip = Vector3.new(x0 + 0.8, 0.4, z0 + 1)
cable(rope, "Cable_Tie", tie, lip, 0.6, white)
cable(rope, "Cable_Down", lip, Vector3.new(x0 + 0.8, -d + 1, z0 + 1), 0.6, white)
part(rope, "Knot", Vector3.new(1.2, 1.2, 1.2), CFrame.new(tie), white)
reveal(rope, "DrainOpen")

-- objectives
anchor(drain, "PryGrate", "PryGrate", c + Vector3.new(0, 1.5, 0))
anchor(drain, "LiftGrate_A", "LiftGrate", Vector3.new(x0 - 1.5, 1.5, c.Z), "A")
anchor(drain, "LiftGrate_B", "LiftGrate", Vector3.new(x1 + 1.5, 1.5, c.Z), "B")
anchor(drain, "TieDrainCable", "TieDrainCable", Vector3.new(c.X, 1.5, z1 + 1.5))

-- exit zone inside the shaft (only kept when the mission's exitId is "Drain")
local zone = part(drain, "DrainExitZone", Vector3.new(HOLE, d - 2, HOLE), CFrame.new(c.X, -d / 2 - 1, c.Z), Color3.fromRGB(80, 255, 120))
invisible(zone)
zone:SetAttribute("ExitId", "Drain")
zone:SetAttribute("Open", false)
CollectionService:AddTag(zone, "ExitZone")

-- win camera for this exit (MissionDef.winCamera)
local cam = part(drain, "DrainCameraPoint", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(c.X - 6, 16, c.Z + 26), c + Vector3.new(0, -3, 0)), Color3.new(1, 1, 1))
invisible(cam)


----------------------------------------------------------------------------
-- SECRET: mouse hole behind the shoe rack (MidnightKitchen_MouseHole, 5 %)
----------------------------------------------------------------------------

local secret = Instance.new("Folder")
secret.Name = "Secret"
secret.Parent = root
local RACK_SHIFT = Vector3.new(-14, 0, 0) -- pushed 14 studs west (clear of the table: z >= 105)
local props = map:FindFirstChild("Props")
local decor = map:FindFirstChild("Decor")
local rackNames = { "ShoeRack_SideW", "ShoeRack_SideE", "ShoeRack_Shelf", "ShoeRack_Top", "Shoe_1", "Shoe_2", "Shoe_3" }
local movedRack = Instance.new("Model")
movedRack.Name = "RackPushedAside"
movedRack.Parent = secret
local function pushable(inst: Instance?)
	if not inst then
		return
	end
	-- original: hidden when the exit unlocks (ExtractionService.unlockDoors(RackPushed))
	inst:SetAttribute("UnlockedBy", "RackPushed")
	CollectionService:AddTag(inst, "LockedDoor")
	-- copy shown at the pushed position
	local copy = inst:Clone()
	CollectionService:RemoveTag(copy, "LockedDoor")
	copy:SetAttribute("UnlockedBy", nil)
	for _, d in copy:GetDescendants() do
		CollectionService:RemoveTag(d, "LockedDoor")
	end
	if copy:IsA("BasePart") then
		copy.CFrame = copy.CFrame + RACK_SHIFT
	elseif copy:IsA("Model") then
		copy:PivotTo(copy:GetPivot() + RACK_SHIFT)
	end
	copy.Parent = movedRack
end
for _, n in rackNames do
	pushable(props and props:FindFirstChild(n))
end
pushable(decor and decor:FindFirstChild("Shoes"))
reveal(movedRack, "RackPushed")

-- the mouse hole in the south wall (shows when the rack is pushed)
local hole = Instance.new("Model")
hole.Name = "MouseHole"
hole.Parent = secret
local hz = 119.8 -- just in front of the visible south wall (tools/AddKitchenWalls.luau, face z 120.6)
local arch = part(hole, "Hole", Vector3.new(0.4, 9, 9), CFrame.new(111, 3.2, hz) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(12, 10, 10))
arch.Shape = Enum.PartType.Cylinder
part(hole, "HoleFloor", Vector3.new(9, 0.2, 1), CFrame.new(111, 0.1, hz - 0.2), Color3.fromRGB(12, 10, 10))
local trim = part(hole, "Trim", Vector3.new(0.3, 10, 10), CFrame.new(111, 3.2, hz + 0.1) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(140, 95, 60), Enum.Material.Wood)
trim.Shape = Enum.PartType.Cylinder
local glowH = part(hole, "Glow", Vector3.new(1, 1, 1), CFrame.new(111, 3, hz - 1), Color3.fromRGB(255, 220, 140))
glowH.Transparency = 1
local hl = Instance.new("PointLight")
hl.Color = Color3.fromRGB(255, 210, 140)
hl.Range = 16
hl.Brightness = 2
hl.Parent = glowH
reveal(hole, "RackPushed")

anchor(secret, "PushRack_A", "PushRack", Vector3.new(101, 2, 103.5), "A")
anchor(secret, "PushRack_B", "PushRack", Vector3.new(121, 2, 103.5), "B")
local mz = part(secret, "MouseHoleExitZone", Vector3.new(10, 8, 8), CFrame.new(111, 4, 117), Color3.fromRGB(80, 255, 120))
invisible(mz)
mz:SetAttribute("ExitId", "MouseHole")
mz:SetAttribute("Open", false)
CollectionService:AddTag(mz, "ExitZone")

local rec = recording
if rec then
	pcall(function()
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end)
end
print("[AddEscapeScenarios] done: Scenarios folder, 4 Scn_* ItemSpawns, drain at " .. tostring(DRAIN_CENTER))
return true
