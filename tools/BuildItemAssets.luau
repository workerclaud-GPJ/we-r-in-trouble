--!strict
--[[
	BuildItemAssets.luau — procedural hamster-scale models for the capability items
	(Config/Items: ChargerCable, Scissors, Bottlecap). Battery stays in tools/BuildProps.

	HOW TO RUN (Studio, EDIT mode — not while playing), after tools/BuildProps.luau:
	  require(game.ServerStorage.Tools.BuildItemAssets)   (Rojo syncs it as a ModuleScript)
	  or paste the whole file into the Command Bar → Enter. Ctrl+Z undoes it.

	IDEMPOTENT: replaces ReplicatedStorage.Assets.Items.{ChargerCable, Scissors, Bottlecap} only.

	CONTRACT (ItemService.buildModel): the FIRST BasePart child is the handle (gets the
	ProximityPrompt + welds). Each handle is an UNROTATED Block at the bottom of the model
	(placeAt uses handle.Size.Y as its height; a rotated cylinder would float), every other part
	sits inside or above the handle's Y range, so the placement never sinks parts into the floor.
	Built around the origin, PrimaryPart = handle. Highlight is parented to the model.
	Plain Parts only (no MeshParts) so CustomPhysicalProperties + collisions are predictable.
	Scale: AA battery = 2.5 × 0.7 × 0.7 (1 stud = 2 cm).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local rgb = Color3.fromRGB
local M = Enum.Material

local recording: string? = nil
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("BuildItemAssets")
end)

local assets = ReplicatedStorage:FindFirstChild("Assets")
if not assets then
	local f = Instance.new("Folder")
	f.Name = "Assets"
	f.Parent = ReplicatedStorage
	assets = f
end
local itemsFolder = (assets :: Instance):FindFirstChild("Items")
if not itemsFolder then
	local f = Instance.new("Folder")
	f.Name = "Items"
	f.Parent = assets
	itemsFolder = f
end
local items = itemsFolder :: Instance

local partCount = 0

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true -- ItemService sets anchoring/collision at runtime
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.Parent = parent
	partCount += 1
	return p
end

-- vertical cylinder (Roblox cylinders run along X) with its bottom at y0
local function cylY(parent: Instance, name: string, x: number, y0: number, z: number, height: number, d: number, color: Color3, material: Enum.Material?): Part
	local cf = CFrame.new(x, y0 + height / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	return part(parent, name, Vector3.new(height, d, d), cf, color, material, Enum.PartType.Cylinder)
end

local function replace(name: string): Model
	local existing = items:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function glow(handle: BasePart, color: Color3)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.2
	light.Range = 8
	light.Shadows = false
	light.Parent = handle
	local hl = Instance.new("Highlight")
	hl.OutlineColor = color
	hl.FillColor = color
	hl.FillTransparency = 0.85
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = handle.Parent
end

-- invisible flat block handle (collision + prompt), bottom at y0
local function baseBlock(parent: Instance, size: Vector3, y0: number): Part
	local p = part(parent, "Base", size, CFrame.new(0, y0 + size.Y / 2, 0), Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CastShadow = false
	return p
end

local function finish(m: Model, handle: BasePart, glowColor: Color3)
	glow(handle, glowColor)
	m.PrimaryPart = handle
	m.Parent = items
end

----------------------------------------------------------------------------
-- ChargerCable {Power, Rope}: flat white coil Ø3.2 × 0.5 with a USB plug sticking out (Small)
----------------------------------------------------------------------------
do
	local m = replace("ChargerCable")
	local WHITE = rgb(240, 240, 238)
	local coil = baseBlock(m, Vector3.new(3, 0.5, 3), -0.25) -- handle (first part), Y -0.25..0.25
	cylY(m, "Coil", 0, -0.25, 0, 0.5, 3.2, WHITE)
	cylY(m, "CoilHole", 0, -0.2, 0, 0.55, 1.4, rgb(70, 70, 76)) -- dark centre reads as a loop
	for i = 1, 3 do
		cylY(m, "Turn" .. i, 0, 0.25, 0, 0.06, 3.2 - i * 0.45, rgb(215, 215, 212))
	end
	-- cable tail + plug lying on the base plane (Y within the coil's range)
	part(m, "Tail", Vector3.new(1.6, 0.25, 0.25), CFrame.new(2.2, -0.12, 0), WHITE)
	part(m, "PlugBody", Vector3.new(1, 0.45, 0.6), CFrame.new(3.4, 0, 0), WHITE)
	part(m, "PlugTip", Vector3.new(0.5, 0.2, 0.45), CFrame.new(4.15, 0, 0), rgb(200, 200, 210), M.Metal)
	finish(m, coil, rgb(255, 230, 140))
end

----------------------------------------------------------------------------
-- Scissors {Cut, Pry}: 8 long, lying flat; steel blades + red finger loops (Medium)
----------------------------------------------------------------------------
do
	local m = replace("Scissors")
	local STEEL = rgb(200, 205, 215)
	local RED = rgb(220, 55, 60)
	-- handle = pivot plate (flat base, Y -0.2..0.2)
	local pivot = part(m, "Pivot", Vector3.new(1.2, 0.4, 1.4), CFrame.new(0, 0, 0), STEEL, M.Metal)
	-- blades: two thin wedges-as-blocks fanned 6° apart, towards +X
	part(m, "BladeA", Vector3.new(4.2, 0.18, 0.6), CFrame.new(2.6, 0.05, 0) * CFrame.Angles(0, math.rad(3), 0) * CFrame.new(0, 0, 0.18), STEEL, M.Metal)
	part(m, "BladeB", Vector3.new(4.2, 0.18, 0.6), CFrame.new(2.6, -0.1, 0) * CFrame.Angles(0, math.rad(-3), 0) * CFrame.new(0, 0, -0.18), STEEL, M.Metal)
	cylY(m, "Screw", 0, 0.15, 0, 0.1, 0.45, rgb(90, 90, 100), M.Metal)
	-- finger loops towards -X (rings = flat red cylinders with a dark hole)
	for i, z in { 0.75, -0.75 } do
		part(m, "Shank" .. i, Vector3.new(1.2, 0.3, 0.35), CFrame.new(-1.1, 0, z * 0.6), RED)
		cylY(m, "Loop" .. i, -2.6, -0.15, z, 0.3, 1.6, RED)
		cylY(m, "LoopHole" .. i, -2.6, -0.12, z, 0.32, 0.9, rgb(40, 40, 45))
	end
	finish(m, pivot, rgb(200, 230, 255))
end

----------------------------------------------------------------------------
-- Bottlecap {Contain}: blue plastic cap Ø2.4 × 1.1, open side up (Small)
----------------------------------------------------------------------------
do
	local m = replace("Bottlecap")
	local BLUE = rgb(60, 130, 230)
	local base = baseBlock(m, Vector3.new(2, 0.25, 2), -0.55) -- handle, Y -0.55..-0.3
	cylY(m, "Bottom", 0, -0.55, 0, 0.25, 2.4, BLUE)
	-- wall: 12 thin staves around the rim (keeps the cup open so it "contains")
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local cf = CFrame.new(math.cos(a) * 1.08, 0, math.sin(a) * 1.08) * CFrame.Angles(0, -a, 0)
		part(m, "Rim", Vector3.new(0.22, 1.1, 0.62), cf, BLUE)
	end
	cylY(m, "Liner", 0, -0.3, 0, 0.05, 2.0, rgb(235, 235, 240))
	finish(m, base, rgb(150, 200, 255))
end

local rec = recording
if rec then
	pcall(function()
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end)
end

print(`[BuildItemAssets] ReplicatedStorage.Assets.Items: ChargerCable, Scissors, Bottlecap ({partCount} parts)`)

return true
