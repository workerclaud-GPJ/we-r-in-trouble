--!strict
--[[
	BuildProps.luau — art pass for "Midnight Kitchen — Deadline cut" (docs/assets/ArtAudio-deadline.md §2, §4)

	HOW TO RUN (Studio, EDIT mode — not while playing), AFTER tools/BuildMidnightKitchen.luau:
	  a) put this file in a ModuleScript (e.g. ServerStorage.BuildProps) and in the Command Bar:
	       require(game.ServerStorage.BuildProps)
	  b) or paste the whole file into the Command Bar → Enter.
	  Output prints a part count. Ctrl+Z undoes the whole pass.

	WHAT IT DOES (idempotent — re-running replaces its own output only)
	  1. ServerStorage.Maps.MidnightKitchen.Decor  (Folder) — visual props: floor grout + rug, fridge
	     details, table set, wheel spokes/stand/dynamo bulb + wires, charger slots/LEDs, radio grilles/
	     lights/letters, fallen-cage bars + tissue + sawdust, dish-rack plates, curtain pleats, window
	     trim, exterior wall + night backdrop + fire truck & ladder, flower-box flowers, shelves with
	     jars/cereal/plates, kettle/toaster/bread bin, faucet, door trims, shoe shells, cabinet seams,
	     cookbook spines, midnight clock.
	     Every Decor part: Anchored, CanCollide = false, CanQuery = false, CanTouch = false.
	     Existing gameplay parts, tags and attributes are NOT touched (no move/resize/recolour).
	     Names read by the client (Controllers/Fx/MapFx.luau): Wheel_Spokes (Model), Dynamo_Bulb,
	     Radio_Light_A..D, Charger_LED1..3.
	  2. ReplicatedStorage.Assets: Debris.{Apple, SoupCan, Sponge}, Items.Battery,
	     RescueCarrier (26 × 17 × 18, PrimaryPart Base, pivot = bottom centre, RopeAttachment on the
	     handle, all parts non-colliding). Other children of Assets are left alone.
	  3. Lighting base setup (§4.1) + Calm preset (§4.2) so Edit mode looks like the game.

	COORDINATES: same as BuildMidnightKitchen (map-local = world, +X east, +Z south, floor top Y 0).
	The offset is re-derived from Structure.Floor so the pass still lines up if the map was moved.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local LightingService = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MAP_NAME = "MidnightKitchen"
local DECOR_NAME = "Decor"
local FLOOR_CENTER = Vector3.new(80, -1, 60) -- Structure.Floor centre in BuildMidnightKitchen

local rgb = Color3.fromRGB
local M = Enum.Material

----------------------------------------------------------------------------
-- Locate the map
----------------------------------------------------------------------------

local maps = ServerStorage:FindFirstChild("Maps")
local map = maps and maps:FindFirstChild(MAP_NAME)
assert(map and map:IsA("Model"), "[BuildProps] ServerStorage.Maps.MidnightKitchen not found — run tools/BuildMidnightKitchen.luau first")
local structure = map:FindFirstChild("Structure")
local floorPart = structure and structure:FindFirstChild("Floor")
local origin = Vector3.zero
if floorPart and floorPart:IsA("BasePart") then
	origin = floorPart.Position - FLOOR_CENTER
end

local recording: string? = nil
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("BuildProps")
end)

local partCount = 0

----------------------------------------------------------------------------
-- Helpers (all decor: anchored, no collide / query / touch; parts < 1 stud cast no shadow)
----------------------------------------------------------------------------

local function at(v: Vector3): Vector3
	return origin + v
end

local function setup(p: BasePart, color: Color3, material: Enum.Material?)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local s = p.Size
	p.CastShadow = math.min(s.X, s.Y, s.Z) >= 1
	partCount += 1
end

-- generic part with world CFrame (already offset)
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	setup(p, color, material)
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- axis-aligned box from map-local min/max corners
local function box(parent: Instance, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, material: Enum.Material?): Part
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local center = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return part(parent, name, size, CFrame.new(at(center)), color, material)
end

-- cylinder along X / Y / Z (Roblox cylinders run along X)
local function cylX(parent: Instance, name: string, center: Vector3, length: number, d: number, color: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(length, d, d), CFrame.new(at(center)), color, material, Enum.PartType.Cylinder)
end

local function cylY(parent: Instance, name: string, x: number, y0: number, z: number, height: number, d: number, color: Color3, material: Enum.Material?): Part
	local cf = CFrame.new(at(Vector3.new(x, y0 + height / 2, z))) * CFrame.Angles(0, 0, math.rad(90))
	return part(parent, name, Vector3.new(height, d, d), cf, color, material, Enum.PartType.Cylinder)
end

local function cylZ(parent: Instance, name: string, center: Vector3, length: number, d: number, color: Color3, material: Enum.Material?): Part
	local cf = CFrame.new(at(center)) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, name, Vector3.new(length, d, d), cf, color, material, Enum.PartType.Cylinder)
end

-- cylinder between two map-local points
local function cylBetween(parent: Instance, name: string, a: Vector3, b: Vector3, d: number, color: Color3, material: Enum.Material?): Part
	local wa, wb = at(a), at(b)
	local len = (wb - wa).Magnitude
	local cf = CFrame.lookAt((wa + wb) / 2, wb) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, name, Vector3.new(len, d, d), cf, color, material, Enum.PartType.Cylinder)
end

local function ball(parent: Instance, name: string, center: Vector3, d: number, color: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(d, d, d), CFrame.new(at(center)), color, material, Enum.PartType.Ball)
end

local function ellipsoid(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, size, CFrame.new(at(center)), color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function letterGui(p: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.3
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = rgb(30, 30, 35)
	stroke.Parent = label
end

local function pointLight(p: BasePart, color: Color3, brightness: number, range: number, enabled: boolean)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Enabled = enabled
	l.Shadows = false
	l.Parent = p
end

----------------------------------------------------------------------------
-- 1. Decor folder
----------------------------------------------------------------------------

local old = map:FindFirstChild(DECOR_NAME)
if old then
	old:Destroy()
end
local decor = Instance.new("Folder")
decor.Name = DECOR_NAME

local WHITE = rgb(240, 240, 240)
local METAL = rgb(190, 195, 205)
local DARK = rgb(45, 45, 52)
local WOOD_DARK = rgb(150, 105, 70)

-- Floor: grout lines every 10 studs (20 cm tiles) + rug under the table
do
	local f = Instance.new("Folder")
	f.Name = "FloorTiles"
	f.Parent = decor
	local grout = rgb(200, 190, 170)
	for x = 10, 150, 10 do
		box(f, "GroutX", x - 0.12, 0, 0, x + 0.12, 0.04, 120, grout)
	end
	for z = 10, 110, 10 do
		box(f, "GroutZ", 0, 0, z - 0.12, 160, 0.04, z + 0.12, grout)
	end
	box(f, "Rug", 34, 0, 57, 106, 0.07, 107, rgb(185, 95, 85), M.Fabric)
	-- skirting boards mark the invisible walls without blocking the camera
	box(f, "Skirting_W", 0, 0, 0, 0.6, 3, 120, rgb(240, 236, 228))
	box(f, "Skirting_S", 0, 0, 119.4, 160, 3, 120, rgb(240, 236, 228))
	box(f, "Skirting_E", 159.4, 0, 84, 160, 3, 120, rgb(240, 236, 228))
end

-- Fridge [B] (X 0..35, Y 0..90, Z 50..85; door face X 35)
do
	local m = model(decor, "FridgeDetails")
	box(m, "FreezerGap", 35, 55, 50.5, 35.15, 55.4, 84.5, rgb(170, 175, 185))
	box(m, "Grille", 35, 1, 52, 35.15, 4, 83, DARK)
	cylY(m, "Handle_Freezer", 36.2, 60, 53.5, 22, 1.5, METAL, M.Metal)
	cylY(m, "Handle_Fridge", 36.2, 22, 53.5, 28, 1.5, METAL, M.Metal)
	box(m, "Magnet1", 35, 68.5, 60.5, 35.5, 71.5, 63.5, rgb(255, 90, 90))
	box(m, "Magnet2", 35, 73.5, 68.5, 35.5, 76.5, 71.5, rgb(255, 205, 60))
	box(m, "Magnet3", 35, 64.5, 75.5, 35.5, 67.5, 78.5, rgb(80, 150, 255))
	box(m, "Magnet4", 35, 46.5, 63.5, 35.5, 49.5, 66.5, rgb(90, 210, 120))
	-- kid's drawing (house + sun + grass)
	box(m, "Drawing", 35, 32, 69.5, 35.2, 44, 78.5, rgb(250, 248, 240))
	box(m, "Drawing_Grass", 35.2, 32.5, 70, 35.3, 34, 78, rgb(90, 190, 90))
	box(m, "Drawing_House", 35.2, 34, 71, 35.3, 38.5, 75, rgb(230, 90, 80))
	box(m, "Drawing_Sun", 35.2, 40, 76, 35.3, 42.5, 78, rgb(255, 210, 60))
end

-- Dining table [T] (top X 40..100, Y 36.75..38.25, Z 62..102)
do
	local m = model(decor, "TableSet")
	box(m, "Apron_N", 41.5, 34, 62.5, 98.5, 36.75, 63.5, WOOD_DARK, M.Wood)
	box(m, "Apron_S", 41.5, 34, 100.5, 98.5, 36.75, 101.5, WOOD_DARK, M.Wood)
	box(m, "Apron_W", 40.5, 34, 63.5, 41.5, 36.75, 100.5, WOOD_DARK, M.Wood)
	box(m, "Apron_E", 98.5, 34, 63.5, 99.5, 36.75, 100.5, WOOD_DARK, M.Wood)
	box(m, "Runner", 40, 38.25, 77, 100, 38.4, 87, rgb(235, 120, 105), M.Fabric)
	cylY(m, "Plate", 58, 38.4, 80, 0.5, 13, WHITE)
	cylY(m, "Cup", 74, 38.4, 76, 6, 4.5, rgb(150, 220, 200))
	cylY(m, "FruitBowl", 86, 38.4, 92, 3, 12.5, rgb(240, 200, 120))
	ball(m, "Apple1", Vector3.new(84, 42.4, 91), 4, rgb(200, 40, 50))
	ball(m, "Apple2", Vector3.new(88, 42.4, 92.5), 4, rgb(120, 200, 70))
	ball(m, "Apple3", Vector3.new(86, 43.6, 94.5), 4, rgb(200, 40, 50))
end

-- Hamster wheel + dynamo [C] (drum centre (116, 7.5, 72), axle along X, Ø14 × 7; dynamo (116, 2, 82))
do
	local m = model(decor, "WheelDetails")
	local c = Vector3.new(116, 7.5, 72)
	cylX(m, "BackPlate", Vector3.new(112.3, c.Y, c.Z), 0.4, 14, rgb(110, 210, 200))
	cylX(m, "Hub", Vector3.new(111.6, c.Y, c.Z), 1, 2, DARK)
	for _, side in { -1, 1 } do
		local cf = CFrame.new(at(Vector3.new(111.4, 4, c.Z + side * 1.1))) * CFrame.Angles(math.rad(-side * 15), 0, 0)
		part(m, "Stand", Vector3.new(1, 8, 1), cf, DARK)
	end
	local spokes = model(decor, "Wheel_Spokes")
	for i = 0, 23 do
		local a = math.rad(i * 15)
		cylX(spokes, "Spoke", Vector3.new(c.X, c.Y + 6.8 * math.sin(a), c.Z + 6.8 * math.cos(a)), 7, 0.35, WHITE)
	end
	spokes.WorldPivot = CFrame.new(at(c))
	-- dynamo: yellow band + bulb (grey until Progress > 0) + red/black wires to the charger
	box(m, "Dynamo_Band", 112.95, 1.6, 79.95, 119.05, 2.4, 84.05, rgb(255, 205, 60))
	local bulb = ball(decor, "Dynamo_Bulb", Vector3.new(116, 4.6, 82), 1.2, rgb(90, 90, 100))
	pointLight(bulb, rgb(255, 220, 90), 2, 0, false)
	cylBetween(m, "Wire_Red", Vector3.new(113, 0.15, 82.4), Vector3.new(46.2, 0.15, 53.4), 0.3, rgb(220, 50, 50))
	cylBetween(m, "Wire_Black", Vector3.new(113, 0.15, 81.6), Vector3.new(46.2, 0.15, 52.6), 0.3, rgb(30, 30, 30))
end

-- Battery charger [B] (box X 36..46 Z 48.5..55.5 Y 0..2; unit top Y 3.75, X 37.75..44.25, Z 50..54)
do
	local m = model(decor, "ChargerDetails")
	for i, z in { 51, 52, 53 } do
		box(m, "Slot" .. i, 39.15, 3.75, z - 0.4, 41.85, 3.9, z + 0.4, rgb(20, 20, 24))
		local led = ball(decor, "Charger_LED" .. i, Vector3.new(43.4, 3.95, z), 0.4, rgb(255, 70, 70), M.Neon)
		led.CastShadow = false
	end
	box(m, "KitLabel", 37, 0.6, 55.5, 45, 1.4, 55.6, WHITE)
	-- white cable: charger → up the counter front → radio A ("power for the radios")
	cylBetween(m, "Cable1", Vector3.new(41, 0.2, 48.4), Vector3.new(41, 0.2, 30.4), 0.4, WHITE)
	cylBetween(m, "Cable2", Vector3.new(41, 0.2, 30.4), Vector3.new(41, 45.2, 30.4), 0.4, WHITE)
	cylBetween(m, "Cable3", Vector3.new(41, 45.2, 30.4), Vector3.new(41.5, 45.2, 21.2), 0.4, WHITE)
end

-- Toy radios A–D (bases on the counter +45; must match BuildMidnightKitchen radioPositions)
do
	local m = model(decor, "RadioDetails")
	type RadioInfo = { base: Vector3, color: Color3, faceZ: boolean }
	local radios: { [string]: RadioInfo } = {
		A = { base = Vector3.new(42, 45, 20), color = rgb(255, 90, 90), faceZ = true },
		B = { base = Vector3.new(100, 45, 26), color = rgb(80, 150, 255), faceZ = true },
		C = { base = Vector3.new(145, 45, 15), color = rgb(255, 205, 60), faceZ = true },
		D = { base = Vector3.new(145, 45, 55), color = rgb(90, 210, 120), faceZ = false }, -- faces west
	}
	for letter, info in radios do
		local b = info.base
		for i, h in { 6.2, 6.7, 7.2 } do
			if info.faceZ then
				part(m, "Grille" .. i, Vector3.new(2.2, 0.25, 0.1), CFrame.new(at(b + Vector3.new(0, h, 1.05))), DARK)
			else
				part(m, "Grille" .. i, Vector3.new(0.1, 0.25, 1.6), CFrame.new(at(b + Vector3.new(-1.55, h, 0))), DARK)
			end
		end
		if info.faceZ then
			cylZ(m, "PTT", b + Vector3.new(0, 2.6, 1.2), 0.4, 1.6, WHITE)
			local plate = part(m, "Letter_" .. letter, Vector3.new(2.4, 2.4, 0.1), CFrame.new(at(b + Vector3.new(0, 4.2, 1.05))), info.color:Lerp(Color3.new(0, 0, 0), 0.25))
			letterGui(plate, Enum.NormalId.Back, letter, WHITE)
		else
			cylX(m, "PTT", b + Vector3.new(-1.7, 2.6, 0), 0.4, 1.6, WHITE)
			local plate = part(m, "Letter_" .. letter, Vector3.new(0.1, 2.4, 1.8), CFrame.new(at(b + Vector3.new(-1.55, 4.2, 0))), info.color:Lerp(Color3.new(0, 0, 0), 0.25))
			letterGui(plate, Enum.NormalId.Left, letter, WHITE)
		end
		local light = ball(decor, "Radio_Light_" .. letter, b + Vector3.new(-0.6, 8.4, 0), 0.8, rgb(60, 60, 70))
		pointLight(light, info.color, 2, 12, false)
		ball(m, "AntennaTip", b + Vector3.new(1, 12.3, 0), 0.6, rgb(30, 30, 35))
	end
end

-- Fallen hamster cage [A] (X 4..34, Y 0..20, Z 98..118, open side north) + tissue + sawdust
do
	local m = model(decor, "CageDetails")
	local bar = rgb(230, 230, 240)
	for x = 6, 32, 2 do
		cylZ(m, "TopBar", Vector3.new(x, 19.8, 107.5), 19, 0.3, bar, M.Metal)
	end
	for z = 100, 116, 2 do
		cylY(m, "BarW", 4.2, 0, z, 20, 0.3, bar, M.Metal)
		cylY(m, "BarE", 33.8, 0, z, 20, 0.3, bar, M.Metal)
	end
	for i, p in { Vector3.new(7.5, 1.2, 108), Vector3.new(19, 1.2, 100.5), Vector3.new(30.5, 1.2, 108), Vector3.new(19, 1.2, 115.5), Vector3.new(6.5, 1.2, 115.5), Vector3.new(31, 1.2, 100.5) } do
		ellipsoid(m, "Tissue" .. i, p, Vector3.new(4 + (i % 2), 2.6, 3.6 + (i % 3) * 0.5), rgb(250, 250, 252), M.Fabric)
	end
	local rngDust = Random.new(7)
	for i = 1, 8 do
		local x, z = rngDust:NextNumber(6, 40), rngDust:NextNumber(94, 117)
		local s = rngDust:NextNumber(1, 2)
		box(m, "Sawdust" .. i, x, 0, z, x + s, 0.35, z + s * 0.7, rgb(235, 210, 160))
	end
	cylY(m, "FoodBowl", 10, 0, 95, 1.5, 6, rgb(240, 120, 140))
	for i = 1, 6 do
		local x, z = 13 + i * 0.9, 95 + (i % 3) * 0.8
		box(m, "Seed" .. i, x, 0, z, x + 0.6, 0.3, z + 0.35, rgb(70, 70, 75))
	end
	local bottle = cylX(m, "WaterBottle", Vector3.new(20, 1.5, 114.5), 10, 3, rgb(150, 200, 255), M.Glass)
	bottle.Transparency = 0.4
end

-- Dish rack: plates beside the ramp + rails (ramp X 54..80 Z 10..20; keep X 54..66 clear for walking)
do
	local m = model(decor, "DishRackDetails")
	local colors = { WHITE, rgb(255, 220, 230), rgb(210, 235, 255), WHITE }
	for i, x in { 70, 72.5, 75, 77.5 } do
		cylX(m, "Plate" .. i, Vector3.new(x, 49.2, 25), 0.6, 8, colors[i])
	end
	box(m, "Rail_S", 68, 45, 28.4, 79.5, 47.5, 28.8, rgb(215, 215, 222), M.Metal)
	box(m, "Post_W", 68, 45, 20.6, 68.4, 50, 28.8, rgb(215, 215, 222), M.Metal)
	box(m, "Post_E", 79.1, 45, 20.6, 79.5, 50, 28.8, rgb(215, 215, 222), M.Metal)
end

-- Curtain: 3 darker pleats between the existing 4 + valance
do
	local m = model(decor, "CurtainDetails")
	for i, x in { 19.75, 25.25, 30.75 } do
		cylY(m, "Pleat" .. i, x, 0, 21.5, 114, 5, rgb(100, 150, 210), M.Fabric)
	end
	box(m, "Valance", 9, 110, 22.6, 41, 115.2, 23.6, rgb(100, 150, 210), M.Fabric)
end

-- Window trim (opening X 46..106, Y 61..111 in the north wall Z -4..0)
do
	local m = model(decor, "WindowTrim")
	local trim = rgb(245, 245, 240)
	box(m, "Trim_Top", 44, 111, 0, 108, 113.5, 0.8, trim, M.Wood)
	box(m, "Trim_W", 44, 61, 0, 46, 111, 0.8, trim, M.Wood)
	box(m, "Trim_E", 106, 61, 0, 108, 111, 0.8, trim, M.Wood)
	box(m, "Mullion", 85.7, 61, -2.6, 86.3, 111, -1.4, trim, M.Wood)
	box(m, "Trim_TopOut", 44, 111, -4.8, 108, 113.5, -4, trim, M.Wood)
end

-- Outside: house wall, ground, night backdrop with lit windows, fire truck + ladder under the rescue lights
do
	local m = model(decor, "Exterior")
	local brick = rgb(175, 110, 90)
	box(m, "Wall_Below", -4, 0, -4.4, 164, 59, -4, brick)
	box(m, "Wall_Above", -4, 113.5, -4.4, 164, 125, -4, brick)
	box(m, "Wall_W", -4, 59, -4.4, 46, 113.5, -4, brick)
	box(m, "Wall_E", 106, 59, -4.4, 164, 113.5, -4, brick)
	box(m, "Ground", -124, -1, -200, 284, 0, -4.4, rgb(40, 58, 48), M.Grass)
	box(m, "Backdrop", -124, -1, -156, 284, 200, -155, rgb(20, 25, 45))
	local rngWin = Random.new(3)
	for i = 1, 8 do
		local x = -90 + (i - 1) * 45 + rngWin:NextNumber(-8, 8)
		local y = rngWin:NextNumber(25, 90)
		box(m, "LitWindow" .. i, x, y, -155.6, x + 10, y + 12, -155, rgb(255, 210, 140), M.Neon)
	end
	-- fire truck (far, on the street) with an aerial ladder up to the rescue-light platform
	local red = rgb(200, 40, 40)
	box(m, "Truck_Body", 40, 2, -122, 100, 22, -102, red)
	box(m, "Truck_Cab", 100, 2, -122, 116, 20, -102, red)
	box(m, "Truck_Windshield", 116, 10, -120, 116.3, 18, -104, rgb(60, 80, 110), M.Glass)
	box(m, "Truck_Stripe", 40, 9, -101.8, 116, 11, -101.6, WHITE)
	for i, p in { Vector3.new(50, 4, -122.5), Vector3.new(106, 4, -122.5), Vector3.new(50, 4, -101.5), Vector3.new(106, 4, -101.5) } do
		cylZ(m, "Wheel" .. i, p, 2, 8, rgb(25, 25, 28))
	end
	box(m, "Lightbar_R", 103, 20, -116, 108, 21.2, -112, rgb(255, 40, 40), M.Neon)
	box(m, "Lightbar_B", 103, 20, -112, 108, 21.2, -108, rgb(40, 90, 255), M.Neon)
	local a, b = at(Vector3.new(76, 23, -106)), at(Vector3.new(76, 48.5, -47))
	part(m, "Ladder", Vector3.new(3, 1, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), rgb(200, 200, 210), M.Metal)
	box(m, "Ladder_Platform", 69, 48.2, -47, 83, 49.4, -41, red)
end

-- Flower box flowers (soil top +61; centre 20 × 20 kept clear for the carrier)
do
	local m = model(decor, "Flowers")
	local petalColors = { rgb(255, 150, 190), WHITE, rgb(190, 140, 255), rgb(255, 150, 190) }
	for i, p in { Vector2.new(63.5, -27), Vector2.new(88.5, -27), Vector2.new(63.5, -7), Vector2.new(88.5, -7) } do
		local h = 8 + (i % 3) * 2
		local top = Vector3.new(p.X, 61 + h, p.Y)
		cylY(m, "Stem", p.X, 61, p.Y, h, 0.5, rgb(80, 170, 80))
		for k = 0, 4 do
			local a = math.rad(k * 72)
			ball(m, "Petal", top + Vector3.new(math.cos(a) * 1.1, 0, math.sin(a) * 1.1), 1.6, petalColors[i])
		end
		ball(m, "Centre", top + Vector3.new(0, 0.3, 0), 1.2, rgb(255, 205, 60))
		ellipsoid(m, "Leaf", Vector3.new(p.X + 1, 61 + h * 0.45, p.Y), Vector3.new(2, 0.3, 1), rgb(80, 170, 80))
	end
end

-- Open shelves above the east part of the north counter (+85 / +105) + under-shelf light
do
	local m = model(decor, "Shelves")
	local items = model(decor, "ShelfItems") -- may wobble during pulses (client, optional)
	local plank = rgb(210, 170, 120)
	box(m, "Shelf_Low", 112, 84.5, 0, 152, 85.5, 12.5, plank, M.Wood)
	box(m, "Shelf_High", 112, 104.5, 0, 152, 105.5, 12.5, plank, M.Wood)
	for _, y in { 80, 100 } do
		box(m, "Bracket", 115, y, 0, 116, y + 4.5, 8, WOOD_DARK)
		box(m, "Bracket", 148, y, 0, 149, y + 4.5, 8, WOOD_DARK)
	end
	local strip = box(m, "UnderShelfLight", 114, 84.2, 9, 150, 84.5, 11, rgb(255, 235, 200), M.Neon)
	local sl = Instance.new("SurfaceLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Color = rgb(255, 220, 170)
	sl.Brightness = 1.2
	sl.Range = 16
	sl.Angle = 90
	sl.Shadows = false
	sl.Parent = strip
	-- low shelf: cereal box, two jars, two glasses
	box(items, "Cereal", 114, 85.5, 3, 124, 100.5, 6.5, rgb(255, 150, 50))
	box(items, "Cereal_Band", 114.2, 91.5, 6.5, 123.8, 95, 6.6, rgb(255, 230, 90))
	local jar1 = cylY(items, "Jar1", 130, 85.5, 6, 7.5, 5, rgb(220, 235, 255), M.Glass)
	jar1.Transparency = 0.4
	cylY(items, "Jar1_Lid", 130, 93, 6, 1, 5.2, rgb(230, 80, 70))
	local jar2 = cylY(items, "Jar2", 137, 85.5, 6, 7.5, 5, rgb(220, 235, 255), M.Glass)
	jar2.Transparency = 0.4
	cylY(items, "Jar2_Lid", 137, 93, 6, 1, 5.2, rgb(255, 205, 60))
	for i, x in { 144, 148.5 } do
		local g = cylY(items, "Glass" .. i, x, 85.5, 6, 5, 4, rgb(210, 230, 255), M.Glass)
		g.Transparency = 0.5
	end
	-- high shelf: plate stack, bowl, mug
	cylY(items, "PlateStack", 121, 105.5, 6, 3, 11, WHITE)
	cylY(items, "Bowl", 134, 105.5, 6, 3, 8, rgb(150, 220, 200))
	cylY(items, "Mug", 145, 105.5, 6, 4, 4, rgb(255, 170, 190))
end

-- Counter clutter against the walls (never on the radio path): bread bin, kettle, toaster
do
	local m = model(decor, "CounterItems")
	box(m, "BreadBin", 115, 45, 1, 135, 57, 11, rgb(240, 225, 200))
	ellipsoid(m, "BreadBin_Lid", Vector3.new(125, 57, 6), Vector3.new(20, 4, 10), rgb(240, 225, 200))
	cylY(m, "Kettle", 154, 45, 74, 12.5, 9, rgb(150, 220, 200))
	ball(m, "Kettle_Knob", Vector3.new(154, 58, 74), 2, DARK)
	box(m, "Kettle_Handle", 158.4, 48, 72.5, 159.6, 57, 75.5, DARK)
	box(m, "Kettle_Spout", 147.6, 50.5, 73, 149.6, 53, 75, rgb(150, 220, 200))
	box(m, "Toaster", 151, 45, 36, 159, 55, 50, rgb(200, 200, 210), M.Metal)
	box(m, "Toaster_Slot1", 152.5, 55, 38, 157.5, 55.1, 41, rgb(20, 20, 24))
	box(m, "Toaster_Slot2", 152.5, 55, 45, 157.5, 55.1, 48, rgb(20, 20, 24))
	box(m, "Toaster_Lever", 150.4, 49, 42, 151, 50, 44, DARK)
end

-- Sink: inner basin plate + faucet (sink X 84..109 Z 10..28 at +45)
do
	local m = model(decor, "Faucet")
	box(m, "Basin", 86, 45.1, 12, 107, 45.35, 26, rgb(60, 65, 75), M.Metal)
	cylY(m, "Base", 96.5, 45, 11.6, 2, 3, METAL, M.Metal)
	cylY(m, "Riser", 96.5, 47, 11.6, 13, 1.5, METAL, M.Metal)
	cylZ(m, "Spout", Vector3.new(96.5, 59.3, 15.2), 7.5, 1.3, METAL, M.Metal)
	box(m, "Lever", 97.5, 57.6, 11, 100.5, 58.2, 12.2, METAL, M.Metal)
end

-- Doors: pantry (X 0..2, Z 4..44) and back door (X 128..156, Z 119..120)
do
	local m = model(decor, "DoorDetails")
	local trim = rgb(235, 230, 220)
	box(m, "Pantry_TrimN", 2, 0, 3, 2.6, 102, 4, trim, M.Wood)
	box(m, "Pantry_TrimS", 2, 0, 44, 2.6, 102, 45, trim, M.Wood)
	box(m, "Pantry_TrimTop", 2, 100, 4, 2.6, 102, 44, trim, M.Wood)
	box(m, "Pantry_Panel1", 2, 10, 8, 2.2, 45, 40, WOOD_DARK, M.Wood)
	box(m, "Pantry_Panel2", 2, 55, 8, 2.2, 92, 40, WOOD_DARK, M.Wood)
	ball(m, "Pantry_Knob", Vector3.new(3.2, 45, 38), 3, rgb(220, 190, 90), M.Metal)
	ball(m, "Back_Knob", Vector3.new(132, 45, 118.2), 3, rgb(220, 190, 90), M.Metal)
	local glass = box(m, "Back_Window", 134, 60, 118.7, 150, 88, 119, rgb(120, 140, 190), M.Glass)
	glass.Transparency = 0.3
end

-- Shoe rack [S]: canvas shells + white soles over the grey shoe blocks, fluffy slipper on top
do
	local m = model(decor, "Shoes")
	type Shoe = { x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3 }
	local shoes: { Shoe } = {
		{ x0 = 98, y0 = 0, z0 = 106, x1 = 103, y1 = 5, z1 = 120, color = rgb(230, 80, 80) },
		{ x0 = 119, y0 = 0, z0 = 106, x1 = 124, y1 = 5, z1 = 120, color = rgb(80, 130, 220) },
		{ x0 = 100, y0 = 11, z0 = 106, x1 = 108, y1 = 15, z1 = 120, color = rgb(250, 200, 70) },
	}
	for i, s in shoes do
		box(m, "Sole" .. i, s.x0 - 0.1, s.y0, s.z0 - 0.1, s.x1 + 0.1, s.y0 + 0.8, s.z1, WHITE)
		box(m, "Canvas" .. i, s.x0 - 0.05, s.y0 + 0.8, s.z0 - 0.05, s.x1 + 0.05, s.y1 + 0.05, s.z1, s.color, M.Fabric)
		box(m, "Laces" .. i, s.x0 + 0.5, s.y1 + 0.05, s.z0 + 1, s.x1 - 0.5, s.y1 + 0.25, s.z0 + 6, WHITE)
	end
	ellipsoid(m, "Slipper", Vector3.new(111, 24.5, 112), Vector3.new(6, 4, 13), rgb(255, 180, 210), M.Fabric)
end

-- Cabinet seams, handles, toe kicks (north front Z 30, east front X 130)
do
	local m = model(decor, "CabinetDetails")
	local seam = rgb(150, 105, 70)
	for _, x in { 56, 116 } do
		box(m, "Seam", x - 0.15, 5, 30, x + 0.15, 42.5, 30.25, seam)
		cylY(m, "Handle", x - 2, 30, 30.6, 6, 0.8, METAL, M.Metal)
		cylY(m, "Handle", x + 2, 30, 30.6, 6, 0.8, METAL, M.Metal)
	end
	for _, z in { 50, 70 } do
		box(m, "Seam", 129.75, 5, z - 0.15, 130, 42.5, z + 0.15, seam)
		cylY(m, "Handle", 129.4, 30, z - 2, 6, 0.8, METAL, M.Metal)
		cylY(m, "Handle", 129.4, 30, z + 2, 6, 0.8, METAL, M.Metal)
	end
	box(m, "ToeKick_N", 36, 0, 30, 130, 5, 30.3, rgb(60, 45, 40))
	box(m, "ToeKick_E", 129.7, 0, 30, 130, 5, 84, rgb(60, 45, 40))
end

-- Cookbook spines on the stack's south face (stack X 66..100, Y 0..23, Z 30..42)
do
	local m = model(decor, "CookbookSpines")
	local colors = { rgb(220, 80, 70), rgb(70, 130, 200), rgb(240, 190, 60), rgb(90, 170, 110), rgb(220, 80, 70) }
	for i = 1, 5 do
		local y0 = (i - 1) * 4.6
		local dx = if i % 2 == 0 then 1 else -1
		box(m, "Book" .. i, 66 + dx, y0, 42, 100 + dx, y0 + 4.3, 42.25, colors[i])
	end
end

-- Midnight clock on the backsplash (both hands on 12)
do
	local m = model(decor, "Clock")
	cylZ(m, "Face", Vector3.new(130, 70, 0.4), 0.8, 12, WHITE)
	box(m, "HourHand", 129.8, 70, 0.8, 130.2, 73, 1, DARK)
	box(m, "MinuteHand", 129.85, 70, 1, 130.15, 75, 1.2, DARK)
end

decor.Parent = map
local decorParts = partCount

----------------------------------------------------------------------------
-- 2. ReplicatedStorage.Assets (names = ARCHITECTURE §1 / DisasterDef propPool / ItemDef model)
----------------------------------------------------------------------------

origin = Vector3.zero -- assets are built around the world origin

local assets = ReplicatedStorage:FindFirstChild("Assets")
if not assets then
	local f = Instance.new("Folder")
	f.Name = "Assets"
	f.Parent = ReplicatedStorage
	assets = f
end
local assetsRoot = assets :: Instance

local function subFolder(name: string): Instance
	local f = assetsRoot:FindFirstChild(name)
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = name
		nf.Parent = assetsRoot
		f = nf
	end
	return f :: Instance
end

local function replace(parent: Instance, name: string): Model
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- Debris (visual only; cast shadows so the growing shadow marks the landing spot)
do
	local debris = subFolder("Debris")

	local apple = replace(debris, "Apple")
	local body = ball(apple, "Body", Vector3.zero, 4, rgb(200, 40, 50))
	cylY(apple, "Stem", 0, 1.9, 0, 0.8, 0.25, rgb(110, 70, 40))
	ellipsoid(apple, "Leaf", Vector3.new(0.5, 2.3, 0), Vector3.new(1, 0.15, 0.6), rgb(80, 170, 80))
	apple.PrimaryPart = body
	apple.Parent = debris

	local can = replace(debris, "SoupCan")
	local canBody = cylY(can, "Body", 0, -2.5, 0, 5, 3.75, rgb(200, 205, 212), M.Metal)
	cylY(can, "Label", 0, -1.5, 0, 3, 3.8, rgb(210, 60, 50))
	can.PrimaryPart = canBody
	can.Parent = debris

	local sponge = replace(debris, "Sponge")
	local spongeBody = box(sponge, "Body", -2.5, -1, -1.75, 2.5, 0.5, 1.75, rgb(255, 220, 70))
	box(sponge, "Scrub", -2.5, 0.5, -1.75, 2.5, 1, 1.75, rgb(60, 150, 70))
	sponge.PrimaryPart = spongeBody
	sponge.Parent = debris

	for _, m in { apple, can, sponge } do
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = true
			end
		end
	end
end

-- Battery (ItemService takes the first BasePart as the handle → Body is created first)
do
	local items = subFolder("Items")
	local bat = replace(items, "Battery")
	local body = cylX(bat, "Body", Vector3.zero, 2.5, 0.7, rgb(255, 150, 40))
	cylX(bat, "NegativeEnd", Vector3.new(-1, 0, 0), 0.5, 0.72, rgb(25, 25, 28))
	cylX(bat, "PositiveNub", Vector3.new(1.31, 0, 0), 0.12, 0.25, rgb(210, 210, 220), M.Metal)
	pointLight(body, rgb(255, 210, 110), 1.2, 8, true)
	local hl = Instance.new("Highlight")
	hl.OutlineColor = rgb(255, 220, 120)
	hl.FillColor = rgb(255, 220, 120)
	hl.FillTransparency = 0.85
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = body
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 3
	sparkle.Lifetime = NumberRange.new(1)
	sparkle.Size = NumberSequence.new(0.4)
	sparkle.Color = ColorSequence.new(rgb(255, 220, 120))
	sparkle.LightEmission = 1
	sparkle.Speed = NumberRange.new(1)
	sparkle.Parent = body
	bat.PrimaryPart = body
	bat.Parent = items
end

-- RescueCarrier 26 (X) × 17 (Y) × 18 (Z); door on the +Z face (towards the house/sill)
do
	local carrier = replace(assetsRoot, "RescueCarrier")
	local base = box(carrier, "Base", -13, 0, -9, 13, 6, 9, rgb(70, 150, 230))
	base.PivotOffset = CFrame.new(0, -3, 0) -- pivot = bottom centre
	local lid = box(carrier, "Lid", -13, 6, -9, 13, 14, 9, rgb(240, 240, 235))
	ellipsoid(carrier, "Dome", Vector3.new(0, 14.5, 0), Vector3.new(24, 5, 16), rgb(240, 240, 235))
	box(carrier, "DoorOpening", -6.5, 3, 9, 6.5, 14, 9.15, rgb(40, 40, 50))
	for _, sx in { -1, 1 } do
		for _, y in { 8.5, 10.5, 12.5 } do
			box(carrier, "Vent", sx * 13 - 0.1, y - 0.5, -2, sx * 13 + 0.1, y + 0.5, 2, rgb(60, 64, 76))
		end
	end
	-- grate door hinged at x = +6.5 on the +Z face, swung open 110°
	local hinge = CFrame.new(6.5, 0, 9.2) * CFrame.Angles(0, math.rad(110), 0)
	local grey = rgb(180, 185, 195)
	local function doorPart(name: string, size: Vector3, local_: Vector3, shapeCyl: boolean)
		local cf = hinge * CFrame.new(local_)
		if shapeCyl then
			cf *= CFrame.Angles(0, 0, math.rad(90))
		end
		part(carrier, name, size, cf, grey, M.Metal, if shapeCyl then Enum.PartType.Cylinder else nil)
	end
	doorPart("Door_Top", Vector3.new(13, 0.6, 0.6), Vector3.new(-6.5, 13.7, 0), false)
	doorPart("Door_Bottom", Vector3.new(13, 0.6, 0.6), Vector3.new(-6.5, 3.3, 0), false)
	doorPart("Door_Hinge", Vector3.new(0.6, 11, 0.6), Vector3.new(0, 8.5, 0), false)
	doorPart("Door_Latch", Vector3.new(0.6, 11, 0.6), Vector3.new(-13, 8.5, 0), false)
	for i = 1, 7 do
		doorPart("Door_Bar" .. i, Vector3.new(10, 0.5, 0.5), Vector3.new(-13 * i / 8, 8.5, 0), true)
	end
	-- handle + rope attachment
	box(carrier, "Handle_PostW", -4.5, 16, -0.75, -3.5, 18.5, 0.75, rgb(60, 64, 76))
	box(carrier, "Handle_PostE", 3.5, 16, -0.75, 4.5, 18.5, 0.75, rgb(60, 64, 76))
	local grip = box(carrier, "Handle", -4.5, 18.5, -0.75, 4.5, 19.5, 0.75, rgb(60, 64, 76))
	local ropeAtt = Instance.new("Attachment")
	ropeAtt.Name = "RopeAttachment"
	ropeAtt.Position = Vector3.new(0, 0.5, 0)
	ropeAtt.Parent = grip
	-- heart + paw stickers (no real agency logos)
	letterGui(lid, Enum.NormalId.Right, "♥", rgb(255, 120, 160))
	letterGui(lid, Enum.NormalId.Left, "♥", rgb(255, 120, 160))
	for _, d in carrier:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		end
	end
	carrier.PrimaryPart = base
	carrier.Parent = assetsRoot
end

----------------------------------------------------------------------------
-- 3. Lighting base (§4.1) + Calm preset (§4.2)
----------------------------------------------------------------------------

do
	local L = LightingService
	pcall(function()
		(L :: any).Technology = Enum.Technology.ShadowMap
	end)
	L.GlobalShadows = true
	L.ShadowSoftness = 0.3
	L.GeographicLatitude = 20
	L.ClockTime = 0
	L.Brightness = 1.2
	L.Ambient = rgb(82, 90, 128)
	L.OutdoorAmbient = rgb(95, 105, 145)
	L.ColorShift_Top = rgb(170, 190, 255)
	L.ColorShift_Bottom = rgb(40, 40, 70)
	L.EnvironmentDiffuseScale = 0.25
	L.EnvironmentSpecularScale = 0.4
	L.ExposureCompensation = 0.35
	local function ensure(className: string): Instance
		local e = L:FindFirstChildOfClass(className :: any)
		if e then
			return e
		end
		local n = Instance.new(className :: any)
		n.Parent = L
		return n
	end
	local atmo = ensure("Atmosphere") :: Atmosphere
	atmo.Density, atmo.Offset = 0.25, 0.15
	atmo.Color, atmo.Decay = rgb(120, 135, 190), rgb(60, 60, 110)
	atmo.Glare, atmo.Haze = 0, 0.8
	local cc = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect
	cc.Brightness, cc.Contrast, cc.Saturation = 0.04, 0.12, -0.05
	cc.TintColor = rgb(225, 232, 255)
	local bloom = ensure("BloomEffect") :: BloomEffect
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.5, 24, 1.6
end

local rec = recording
if rec then
	pcall(function()
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end)
end

print(`[BuildProps] Decor: {decorParts} parts · Assets: {partCount - decorParts} parts · Lighting: Calm preset applied`)

return true
