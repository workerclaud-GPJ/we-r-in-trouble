--!strict
--[[
	AddKitchenWalls.luau — visible walls on the 3 sides that only had invisible walls
	(west / east / south) of ServerStorage.Maps.MidnightKitchen, matching the north wall
	(plaster colour), with baseboards, a top trim, door frames round the pantry door and the
	back door, and a few picture frames. Decoration only: the walls sit just outside the play
	space, behind the existing InvisWall_* (which still do the blocking).

	HOW TO RUN (Studio, EDIT mode): require(game.ServerStorage.Tools.AddKitchenWalls). Idempotent:
	rebuilds the folder Structure.VisibleWalls.
]]

local ServerStorage = game:GetService("ServerStorage")

local map = ServerStorage:FindFirstChild("Maps") and (ServerStorage :: any).Maps:FindFirstChild("MidnightKitchen")
if not map then
	warn("[AddKitchenWalls] map not found")
	return true
end
local structure = map:FindFirstChild("Structure")
local north = structure and structure:FindFirstChild("NorthWall_Lower")
local color = if north and north:IsA("BasePart") then north.Color else Color3.fromRGB(150, 160, 185)
local material = if north and north:IsA("BasePart") then north.Material else Enum.Material.Plaster

local old = structure:FindFirstChild("VisibleWalls")
if old then
	old:Destroy()
end
local f = Instance.new("Folder")
f.Name = "VisibleWalls"
f.Parent = structure

local H = 124 -- floor (0) to the invisible ceiling
local function P(name: string, size: Vector3, cf: CFrame, c: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = c
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = f
	return p
end

local white = Color3.fromRGB(238, 234, 226)
local wood = Color3.fromRGB(170, 115, 75)

-- walls (inner faces: west x = -0.1, east x = 160.1, south z = 120.6 — just behind doors / props)
P("Wall_W", Vector3.new(1, H, 128), CFrame.new(-0.6, H / 2, 60), color, material)
P("Wall_E", Vector3.new(1, H, 128), CFrame.new(160.6, H / 2, 60), color, material)
P("Wall_S", Vector3.new(168, H, 1), CFrame.new(80, H / 2, 121.1), color, material)
-- baseboards + top trim
P("Base_W", Vector3.new(0.6, 4, 128), CFrame.new(0.2, 2, 60), white)
P("Base_E", Vector3.new(0.6, 4, 128), CFrame.new(159.8, 2, 60), white)
P("Base_S", Vector3.new(168, 4, 0.6), CFrame.new(80, 2, 120.3), white)
P("Trim_W", Vector3.new(0.8, 2, 128), CFrame.new(0.2, H - 1, 60), white)
P("Trim_E", Vector3.new(0.8, 2, 128), CFrame.new(159.8, H - 1, 60), white)
P("Trim_S", Vector3.new(168, 2, 0.8), CFrame.new(80, H - 1, 120.3), white)
-- a darker band at mid height (wainscot line)
P("Rail_W", Vector3.new(0.5, 1.2, 128), CFrame.new(0.15, 34, 60), white)
P("Rail_E", Vector3.new(0.5, 1.2, 128), CFrame.new(159.85, 34, 60), white)
P("Rail_S", Vector3.new(168, 1.2, 0.5), CFrame.new(80, 34, 120.35), white)

-- door frames
local props = map:FindFirstChild("Props")
local function frameAround(door: BasePart?, axis: string)
	if not door then
		return
	end
	local c, s = door.Position, door.Size
	local t = 2.2
	if axis == "X" then -- door in the west wall (thin in X, wide in Z)
		P("Frame_L", Vector3.new(0.8, s.Y + t, t), CFrame.new(c.X + 0.2, (s.Y + t) / 2, c.Z - s.Z / 2 - t / 2), white)
		P("Frame_R", Vector3.new(0.8, s.Y + t, t), CFrame.new(c.X + 0.2, (s.Y + t) / 2, c.Z + s.Z / 2 + t / 2), white)
		P("Frame_T", Vector3.new(0.8, t, s.Z + 2 * t), CFrame.new(c.X + 0.2, s.Y + t / 2, c.Z), white)
	else -- door in the south wall (thin in Z, wide in X)
		P("Frame_L", Vector3.new(t, s.Y + t, 0.8), CFrame.new(c.X - s.X / 2 - t / 2, (s.Y + t) / 2, c.Z - 0.2), white)
		P("Frame_R", Vector3.new(t, s.Y + t, 0.8), CFrame.new(c.X + s.X / 2 + t / 2, (s.Y + t) / 2, c.Z - 0.2), white)
		P("Frame_T", Vector3.new(s.X + 2 * t, t, 0.8), CFrame.new(c.X, s.Y + t / 2, c.Z - 0.2), white)
	end
end
local pantry = props and props:FindFirstChild("PantryDoor")
local back = props and props:FindFirstChild("BackDoor")
frameAround(if pantry and pantry:IsA("BasePart") then pantry else nil, "X")
frameAround(if back and back:IsA("BasePart") then back else nil, "Z")

-- picture frames (giant, from a hamster's view)
local function picture(name: string, cf: CFrame, w: number, h: number, art: Color3)
	P(name .. "_Frame", Vector3.new(w + 2, h + 2, 0.6), cf, wood, Enum.Material.Wood)
	P(name .. "_Art", Vector3.new(w, h, 0.3), cf * CFrame.new(0, 0, -0.35), art)
end
-- south wall faces -Z (into the kitchen): offset toward -Z
picture("Picture_S1", CFrame.new(60, 70, 120.2) * CFrame.Angles(0, math.rad(180), 0), 26, 18, Color3.fromRGB(120, 170, 220))
picture("Picture_S2", CFrame.new(100, 66, 120.2) * CFrame.Angles(0, math.rad(180), 0), 16, 22, Color3.fromRGB(230, 180, 110))
-- east wall faces -X
picture("Picture_E1", CFrame.new(159.9, 72, 100) * CFrame.Angles(0, math.rad(90), 0), 24, 16, Color3.fromRGB(160, 210, 150))
-- west wall faces +X (north of the pantry door)
picture("Picture_W1", CFrame.new(0.1, 72, 100) * CFrame.Angles(0, math.rad(-90), 0), 20, 16, Color3.fromRGB(220, 140, 160))

print("[AddKitchenWalls] done: visible west / east / south walls")
return true
