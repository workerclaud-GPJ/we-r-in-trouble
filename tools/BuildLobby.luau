--!strict
--[[
	BuildLobby.luau — the lobby: a kid's bedroom at night seen from a hamster (giant bed, moonlit
	window, fairy lights, toys) with 3 hamster houses = waiting rooms (LobbyRoomService).

	HOW TO RUN (Studio, EDIT mode): require(game.ServerStorage.Tools.BuildLobby)
	  or paste into the Command Bar. Ctrl+Z undoes it.
	IDEMPOTENT: the old Workspace.Lobby is moved to ServerStorage._OldLobby once (backup), then
	Workspace.Lobby is rebuilt from scratch every run.

	Markup used by code:
	  LobbySpawn parts (tag) on the rug       — MapService.lobbyCFrame (players face the houses, -Z)
	  Model tag LobbyRoom, attrs RoomId, Capacity — LobbyRoomService
	    Zone  Part  (invisible) = inside the house; standing in it = in the room
	    Sign  Part  SurfaceGui "SignGui" with labels Title / Count / Status (server writes them)
	Centre (3000, 0, 0) = Config.Round.LOBBY_OFFSET_X / LOBBY_Y. Floor top Y 0.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local O = Vector3.new(3000, 0, 0)
local W, D = 170, 120 -- floor X, Z
local H = 78 -- wall height
local ROOM_COLORS = { Color3.fromRGB(235, 90, 90), Color3.fromRGB(80, 150, 235), Color3.fromRGB(110, 200, 110) }
local ROOM_X = { -44, 0, 44 }
local ROOM_Z = -38

local recording: string? = nil
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("BuildLobby")
end)

local existing = Workspace:FindFirstChild("Lobby")
if existing then
	if not ServerStorage:FindFirstChild("_OldLobby") then
		existing.Name = "_OldLobby"
		existing.Parent = ServerStorage
	else
		existing:Destroy()
	end
end

local lobby = Instance.new("Model")
lobby.Name = "Lobby"

local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(O + Vector3.new(x, y, z))
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	return p
end

local function light(parent: Instance, kind: string, color: Color3, range: number, brightness: number): Light
	local l = Instance.new(kind) :: any
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	if kind == "PointLight" then
		l.Shadows = false
	end
	l.Parent = parent
	return l
end

local function surfaceText(part: BasePart, face: Enum.NormalId, lines: { { name: string, text: string, size: number, color: Color3 } }, ppstuds: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppstuds or 30
	gui.LightInfluence = 0
	gui.Parent = part
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	for i, l in lines do
		local t = Instance.new("TextLabel")
		t.Name = l.name
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, l.size * 1.25)
		t.Font = Enum.Font.FredokaOne
		t.TextSize = l.size
		t.TextColor3 = l.color
		t.TextStrokeTransparency = 0.4
		t.Text = l.text
		t.Parent = gui
	end
end

----------------------------------------------------------------------------
-- room shell
----------------------------------------------------------------------------

local shell = Instance.new("Folder")
shell.Name = "Room"
shell.Parent = lobby

local wood = Color3.fromRGB(150, 105, 70)
P(shell, "Floor", Vector3.new(W, 2, D), at(0, -1, 0), Color3.fromRGB(128, 88, 58), Enum.Material.WoodPlanks)
local wall = Color3.fromRGB(46, 52, 92)
-- north wall with a window opening (x -26..26, y 30..62)
P(shell, "Wall_N_L", Vector3.new(W / 2 - 26, H, 2), at(-(26 + (W / 2 - 26) / 2), H / 2, -D / 2), wall, Enum.Material.Fabric)
P(shell, "Wall_N_R", Vector3.new(W / 2 - 26, H, 2), at(26 + (W / 2 - 26) / 2, H / 2, -D / 2), wall, Enum.Material.Fabric)
P(shell, "Wall_N_Low", Vector3.new(52, 30, 2), at(0, 15, -D / 2), wall, Enum.Material.Fabric)
P(shell, "Wall_N_High", Vector3.new(52, H - 62, 2), at(0, 62 + (H - 62) / 2, -D / 2), wall, Enum.Material.Fabric)
P(shell, "Wall_W", Vector3.new(2, H, D), at(-W / 2, H / 2, 0), wall, Enum.Material.Fabric)
P(shell, "Wall_E", Vector3.new(2, H, D), at(W / 2, H / 2, 0), wall, Enum.Material.Fabric)
P(shell, "Wall_S", Vector3.new(W, H, 2), at(0, H / 2, D / 2), wall, Enum.Material.Fabric)
P(shell, "Ceiling", Vector3.new(W, 2, D), at(0, H + 1, 0), Color3.fromRGB(30, 34, 60))
-- baseboards
for _, b in { { Vector3.new(W, 3, 1), at(0, 1.5, -D / 2 + 1.4) }, { Vector3.new(1, 3, D), at(-W / 2 + 1.4, 1.5, 0) }, { Vector3.new(1, 3, D), at(W / 2 - 1.4, 1.5, 0) }, { Vector3.new(W, 3, 1), at(0, 1.5, D / 2 - 1.4) } } do
	deco(P(shell, "Baseboard", b[1], b[2], Color3.fromRGB(235, 230, 220)))
end

-- window: frame, night sky, moon, stars, curtains, moonlight
local win = Instance.new("Model")
win.Name = "Window"
win.Parent = lobby
local frameC = Color3.fromRGB(240, 236, 228)
P(win, "Sill", Vector3.new(58, 2, 6), at(0, 29, -D / 2 + 2), frameC)
deco(P(win, "FrameTop", Vector3.new(56, 2, 2), at(0, 62, -D / 2 + 0.5), frameC))
deco(P(win, "FrameL", Vector3.new(2, 32, 2), at(-27, 46, -D / 2 + 0.5), frameC))
deco(P(win, "FrameR", Vector3.new(2, 32, 2), at(27, 46, -D / 2 + 0.5), frameC))
deco(P(win, "FrameMidV", Vector3.new(1, 32, 1.5), at(0, 46, -D / 2 + 0.5), frameC))
deco(P(win, "FrameMidH", Vector3.new(52, 1, 1.5), at(0, 46, -D / 2 + 0.5), frameC))
local sky = deco(P(win, "Sky", Vector3.new(80, 50, 1), at(0, 46, -D / 2 - 14), Color3.fromRGB(14, 20, 52), Enum.Material.Neon))
sky.Transparency = 0.15
local moon = deco(P(win, "Moon", Vector3.new(1, 12, 12), at(12, 52, -D / 2 - 12) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 244, 205), Enum.Material.Neon))
moon.Shape = Enum.PartType.Cylinder
local rng = Random.new(7)
for i = 1, 26 do
	local s = deco(P(win, `Star{i}`, Vector3.new(0.5, 0.5, 0.5), at(rng:NextNumber(-34, 34), rng:NextNumber(32, 66), -D / 2 - 12.5), Color3.fromRGB(255, 255, 230), Enum.Material.Neon))
	s.Shape = Enum.PartType.Ball
end
-- glass glow + moonbeam
local glass = deco(P(win, "Glass", Vector3.new(52, 32, 0.3), at(0, 46, -D / 2 + 0.2), Color3.fromRGB(150, 180, 255), Enum.Material.Glass))
glass.Transparency = 0.8
local beam = deco(P(win, "MoonLightSource", Vector3.new(1, 1, 1), at(0, 58, -D / 2 + 3), Color3.new(1, 1, 1)))
beam.Transparency = 1
local spot = light(beam, "SpotLight", Color3.fromRGB(170, 190, 255), 90, 3) :: SpotLight
spot.Face = Enum.NormalId.Front
spot.Angle = 70
beam.CFrame = CFrame.lookAt(beam.Position, O + Vector3.new(0, 0, 15))
-- curtains
for side = -1, 1, 2 do
	for k = 0, 3 do
		local c = deco(P(win, "Curtain", Vector3.new(3.2, 40, 3.2), at(side * (31 + k * 2.6), 44, -D / 2 + 3), Color3.fromRGB(120, 70, 140), Enum.Material.Fabric))
		c.Shape = Enum.PartType.Cylinder
		c.CFrame = c.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end
end
deco(P(win, "CurtainRod", Vector3.new(76, 1, 1), at(0, 65, -D / 2 + 3), Color3.fromRGB(200, 170, 90), Enum.Material.Metal))

-- fairy lights along the top of the north wall (drooping)
local fairy = Instance.new("Model")
fairy.Name = "FairyLights"
fairy.Parent = lobby
local bulbs = { Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 140, 170), Color3.fromRGB(140, 220, 255), Color3.fromRGB(170, 255, 150) }
for i = 0, 40 do
	local x = -W / 2 + 6 + i * ((W - 12) / 40)
	local sag = math.sin((i % 8) / 8 * math.pi) * 3
	local b = deco(P(fairy, `Bulb{i}`, Vector3.new(1.1, 1.1, 1.1), at(x, H - 8 - sag, -D / 2 + 2.5), bulbs[i % 4 + 1], Enum.Material.Neon))
	b.Shape = Enum.PartType.Ball
	if i % 5 == 0 then
		light(b, "PointLight", bulbs[i % 4 + 1], 16, 0.8)
	end
end

----------------------------------------------------------------------------
-- giant furniture & toys
----------------------------------------------------------------------------

local furn = Instance.new("Folder")
furn.Name = "Furniture"
furn.Parent = lobby

-- bed (west): frame, legs, mattress, blanket, pillow
local bx, bz = -W / 2 + 22, 30
P(furn, "BedFrame", Vector3.new(40, 6, 56), at(bx, 14, bz), Color3.fromRGB(110, 75, 50), Enum.Material.Wood)
for _, l in { { -18, -26 }, { 18, -26 }, { -18, 26 }, { 18, 26 } } do
	P(furn, "BedLeg", Vector3.new(4, 11, 4), at(bx + l[1], 5.5, bz + l[2]), Color3.fromRGB(95, 65, 45), Enum.Material.Wood)
end
P(furn, "Mattress", Vector3.new(38, 6, 54), at(bx, 20, bz), Color3.fromRGB(240, 240, 245), Enum.Material.Fabric)
deco(P(furn, "Blanket", Vector3.new(39, 1.5, 36), at(bx, 23.5, bz + 9), Color3.fromRGB(90, 120, 200), Enum.Material.Fabric))
deco(P(furn, "BlanketDrape", Vector3.new(1.5, 14, 36), at(bx + 19.6, 17, bz + 9), Color3.fromRGB(90, 120, 200), Enum.Material.Fabric))
P(furn, "Pillow", Vector3.new(26, 5, 12), at(bx, 25, bz - 19), Color3.fromRGB(255, 250, 240), Enum.Material.Fabric)
P(furn, "Headboard", Vector3.new(40, 30, 3), at(bx, 22, bz - 29), Color3.fromRGB(110, 75, 50), Enum.Material.Wood)
-- teddy bear on the bed (simple balls)
local teddy = Color3.fromRGB(180, 120, 70)
for _, b in { { Vector3.new(10, 10, 10), Vector3.new(bx - 6, 29, bz - 14) }, { Vector3.new(7, 7, 7), Vector3.new(bx - 6, 37, bz - 14) }, { Vector3.new(3, 3, 3), Vector3.new(bx - 9, 40.5, bz - 14) }, { Vector3.new(3, 3, 3), Vector3.new(bx - 3, 40.5, bz - 14) } } do
	local t = deco(P(furn, "Teddy", b[1], CFrame.new(O + b[2]), teddy, Enum.Material.Fabric))
	t.Shape = Enum.PartType.Ball
end

-- bookshelf (east wall)
local sx = W / 2 - 7
P(furn, "Shelf", Vector3.new(10, 60, 40), at(sx, 30, 22), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
local bookColors = { Color3.fromRGB(200, 70, 70), Color3.fromRGB(70, 130, 200), Color3.fromRGB(230, 190, 70), Color3.fromRGB(90, 170, 110), Color3.fromRGB(160, 90, 180) }
for row = 0, 3 do
	local y = 8 + row * 14
	local z = 4
	local i = 0
	while z < 40 do
		i += 1
		local w = 2 + (i * 7 % 3)
		local h = 8 + (i * 5 % 4)
		deco(P(furn, "Book", Vector3.new(2, h, w), at(sx - 5.6, y + h / 2, z + w / 2), bookColors[(i + row) % #bookColors + 1]))
		z += w + 0.3
	end
end

-- night lamp on a stool (warm light), south-east
local lx, lz = 50, 40
P(furn, "Stool", Vector3.new(14, 16, 14), at(lx, 8, lz), Color3.fromRGB(240, 200, 120), Enum.Material.Wood)
local lampBase = P(furn, "LampBase", Vector3.new(2, 6, 6), at(lx, 17.5, lz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(80, 80, 90), Enum.Material.Metal)
lampBase.Shape = Enum.PartType.Cylinder
local shade = deco(P(furn, "LampShade", Vector3.new(9, 9, 9), at(lx, 26, lz), Color3.fromRGB(255, 220, 150), Enum.Material.Neon))
shade.Shape = Enum.PartType.Ball
shade.Transparency = 0.15
light(shade, "PointLight", Color3.fromRGB(255, 200, 130), 60, 2)

-- toy blocks (ABC) + ball, scattered
local blockColors = { Color3.fromRGB(230, 80, 80), Color3.fromRGB(80, 150, 230), Color3.fromRGB(240, 200, 60), Color3.fromRGB(100, 200, 120) }
local letters = { "A", "B", "C", "H", "M", "S" }
for i, b in { { -30, 30, 0 }, { -22, 36, 20 }, { -26, 30, 8 + 8 }, { 28, 18, -15 }, { 34, 26, 30 }, { 62, 10, 15 } } do
	local size = 8
	local blk = P(furn, `ToyBlock{i}`, Vector3.new(size, size, size), at(b[1], size / 2 + (if i == 3 then 8 else 0), b[2]) * CFrame.Angles(0, math.rad(b[3]), 0), blockColors[i % 4 + 1], Enum.Material.Wood)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top } do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 20
		g.Parent = blk
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = letters[i]
		t.Parent = g
	end
end
local ball = P(furn, "ToyBall", Vector3.new(12, 12, 12), at(-45, 6, 45), Color3.fromRGB(240, 90, 120))
ball.Shape = Enum.PartType.Ball

-- rug + spawn pads
local rug = deco(P(furn, "Rug", Vector3.new(0.3, 52, 52), at(0, 0.15, 12) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 80, 160), Enum.Material.Fabric))
rug.Shape = Enum.PartType.Cylinder
local rugIn = deco(P(furn, "RugInner", Vector3.new(0.32, 36, 36), at(0, 0.16, 12) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(160, 120, 200), Enum.Material.Fabric))
rugIn.Shape = Enum.PartType.Cylinder

local spawns = Instance.new("Folder")
spawns.Name = "Spawns"
spawns.Parent = lobby
for i, off in { Vector3.new(-6, 0, 18), Vector3.new(6, 0, 18), Vector3.new(-6, 0, 28), Vector3.new(6, 0, 28) } do
	local s = P(spawns, `LobbySpawn{i}`, Vector3.new(4, 0.2, 4), at(off.X, 0.1, off.Z), Color3.new(1, 1, 1), nil, false)
	s.Transparency = 1
	CollectionService:AddTag(s, "LobbySpawn")
end
local sl = Instance.new("SpawnLocation")
sl.Name = "LobbySpawnLocation"
sl.Anchored = true
sl.Size = Vector3.new(4, 0.2, 4)
sl.CFrame = at(0, 0.1, 24)
sl.Transparency = 1
sl.CanCollide = false
sl.Neutral = true
sl.Duration = 0
sl.Parent = spawns

-- title board on the north wall
local board = P(lobby, "TitleBoard", Vector3.new(60, 12, 1), at(0, 70, -D / 2 + 1.6), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
surfaceText(board, Enum.NormalId.Back, {
	{ name = "Title", text = "WE R IN TROUBLE", size = 150, color = Color3.fromRGB(255, 215, 90) },
}, 12)
-- standing signpost on the rug's north edge (readable from the spawn, not hidden by the houses)
P(lobby, "HintPost", Vector3.new(1.2, 9, 1.2), at(22, 4.5, -6), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
local hint = P(lobby, "HintBoard", Vector3.new(24, 7, 0.8), at(22, 11, -6) * CFrame.Angles(0, math.rad(-15), 0), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
surfaceText(hint, Enum.NormalId.Back, {
	{ name = "Hint", text = "Walk into a hamster house to play! 🐹", size = 34, color = Color3.new(1, 1, 1) },
	{ name = "HintTh", text = "เดินเข้าบ้านหนูเพื่อเริ่มเล่น", size = 30, color = Color3.fromRGB(255, 230, 160) },
}, 20)
for _, d in hint:GetDescendants() do
	if d:IsA("TextLabel") and d.Name == "HintTh" then
		d.Font = Enum.Font.Gotham -- Thai glyphs
	end
end

----------------------------------------------------------------------------
-- hamster houses = rooms
----------------------------------------------------------------------------

local rooms = Instance.new("Folder")
rooms.Name = "Rooms"
rooms.Parent = lobby

local HW, HD, HH = 28, 24, 18 -- house width, depth, wall height
for i = 1, 3 do
	local cx, cz = ROOM_X[i], ROOM_Z
	local color = ROOM_COLORS[i]
	local m = Instance.new("Model")
	m.Name = `Room{i}`
	m:SetAttribute("RoomId", i)
	m:SetAttribute("Capacity", 4)
	CollectionService:AddTag(m, "LobbyRoom")
	m.Parent = rooms

	local plank = Color3.fromRGB(205, 160, 105)
	P(m, "Base", Vector3.new(HW + 4, 1, HD + 4), at(cx, 0.5, cz), Color3.fromRGB(170, 125, 80), Enum.Material.Wood)
	deco(P(m, "Bedding", Vector3.new(HW - 2, 0.4, HD - 2), at(cx, 1.2, cz), Color3.fromRGB(235, 215, 150), Enum.Material.Sand))
	P(m, "Wall_Back", Vector3.new(HW, HH, 1.5), at(cx, 1 + HH / 2, cz - HD / 2), plank, Enum.Material.WoodPlanks)
	P(m, "Wall_L", Vector3.new(1.5, HH, HD), at(cx - HW / 2, 1 + HH / 2, cz), plank, Enum.Material.WoodPlanks)
	P(m, "Wall_R", Vector3.new(1.5, HH, HD), at(cx + HW / 2, 1 + HH / 2, cz), plank, Enum.Material.WoodPlanks)
	-- front wall with a 10-wide, 12-high door
	local side = (HW - 10) / 2
	P(m, "Front_L", Vector3.new(side, HH, 1.5), at(cx - 5 - side / 2, 1 + HH / 2, cz + HD / 2), plank, Enum.Material.WoodPlanks)
	P(m, "Front_R", Vector3.new(side, HH, 1.5), at(cx + 5 + side / 2, 1 + HH / 2, cz + HD / 2), plank, Enum.Material.WoodPlanks)
	P(m, "Front_Top", Vector3.new(10, HH - 12, 1.5), at(cx, 1 + 12 + (HH - 12) / 2, cz + HD / 2), plank, Enum.Material.WoodPlanks)
	local arch = deco(P(m, "DoorArch", Vector3.new(1.6, 10, 10), at(cx, 13, cz + HD / 2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(40, 25, 20)))
	arch.Shape = Enum.PartType.Cylinder
	-- roof (two slopes) in the room colour
	local roofY = 1 + HH
	local span, rise = HW / 2 + 2, 9
	local len, ang = math.sqrt(span * span + rise * rise), math.atan2(rise, span)
	for s = -1, 1, 2 do
		P(m, "Roof", Vector3.new(len, 1.4, HD + 4), at(cx + s * span / 2, roofY + rise / 2, cz) * CFrame.Angles(0, 0, -s * ang), color, Enum.Material.SmoothPlastic)
	end
	P(m, "RoofRidge", Vector3.new(2, 2, HD + 5), at(cx, roofY + rise, cz), color:Lerp(Color3.new(0, 0, 0), 0.25))
	-- round window on the side + warm light inside
	local rw = deco(P(m, "RoundWindow", Vector3.new(0.4, 5, 5), at(cx + HW / 2 + 0.2, 11, cz) , Color3.fromRGB(255, 220, 140), Enum.Material.Neon))
	rw.Shape = Enum.PartType.Cylinder
	local glow = deco(P(m, "InnerGlow", Vector3.new(1, 1, 1), at(cx, 15, cz), color))
	glow.Transparency = 1
	light(glow, "PointLight", color:Lerp(Color3.new(1, 1, 1), 0.4), 26, 1.6)
	-- food bowl + tiny wheel inside
	local bowl = deco(P(m, "Bowl", Vector3.new(1.4, 6, 6), at(cx - 8, 2, cz - 6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 120, 60)))
	bowl.Shape = Enum.PartType.Cylinder
	local wheel = deco(P(m, "Wheel", Vector3.new(1.5, 12, 12), at(cx + 8, 7, cz - 7) , Color3.fromRGB(120, 200, 255)))
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Transparency = 0.3

	-- lantern above the door (warm, welcoming)
	local lantern = deco(P(m, "Lantern", Vector3.new(2.2, 2.2, 2.2), at(cx, 16.5, cz + HD / 2 + 1.6), Color3.fromRGB(255, 210, 120), Enum.Material.Neon))
	lantern.Shape = Enum.PartType.Ball
	light(lantern, "PointLight", Color3.fromRGB(255, 200, 130), 30, 2.2)
	-- zone = inside the house
	local zone = P(m, "Zone", Vector3.new(HW - 2, 14, HD - 2), at(cx, 1 + 7, cz), Color3.fromRGB(0, 255, 0), nil, false)
	zone.Transparency = 1
	-- welcome mat (shows the room colour at the door)
	deco(P(m, "Mat", Vector3.new(12, 0.3, 6), at(cx, 0.2, cz + HD / 2 + 5), color, Enum.Material.Fabric))

	-- sign above the door (server writes Count / Status)
	local sign = P(m, "Sign", Vector3.new(16, 7, 0.6), at(cx, roofY + 13, cz + HD / 2 + 1), Color3.fromRGB(60, 40, 28), Enum.Material.Wood)
	sign.CanCollide = false
	surfaceText(sign, Enum.NormalId.Back, {
		{ name = "Title", text = `ROOM {i}`, size = 52, color = color:Lerp(Color3.new(1, 1, 1), 0.3) },
		{ name = "Count", text = "0/4 🐹", size = 44, color = Color3.new(1, 1, 1) },
		{ name = "Status", text = "Walk in!", size = 36, color = Color3.fromRGB(255, 230, 150) },
	}, 14)
	local post = P(m, "SignPost", Vector3.new(1, 6, 1), at(cx, roofY + 8.5, cz + HD / 2 + 1), Color3.fromRGB(60, 40, 28), Enum.Material.Wood)
	post.CanCollide = false
end

-- soft fill lights so the room reads at night (no shadows: cheap)
for _, f in { Vector3.new(-50, 50, 10), Vector3.new(50, 50, 10), Vector3.new(0, 50, 35) } do
	local fp = deco(P(lobby, "FillLight", Vector3.new(1, 1, 1), CFrame.new(O + f), Color3.new(1, 1, 1)))
	fp.Transparency = 1
	light(fp, "PointLight", Color3.fromRGB(150, 160, 230), 70, 0.9)
end

-- invisible ceiling guard over the bed / shelf tops is the real ceiling; keep players inside
lobby.Parent = Workspace

local rec = recording
if rec then
	pcall(function()
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end)
end
print("[BuildLobby] done: bedroom lobby with 3 hamster-house rooms")
return true
