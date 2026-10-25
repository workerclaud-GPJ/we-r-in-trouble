--!strict
--[[
	AddSceneProps.luau — interactive scene objects (LauncherService / LauncherController) in
	ServerStorage.Maps.MidnightKitchen. Idempotent: rebuilds the folder SceneProps.
	  🍞 Toaster: press "Pop up!" at the toaster lever (east counter) → you pop out of the slot
	     and fly onto the window sill.
	  🧽 Kitchen sponge on the floor south of the table: land on it → bounce up onto the table.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local map = ServerStorage:FindFirstChild("Maps") and (ServerStorage :: any).Maps:FindFirstChild("MidnightKitchen")
if not map then
	warn("[AddSceneProps] map not found")
	return true
end
local old = map:FindFirstChild("SceneProps")
if old then
	old:Destroy()
end
local f = Instance.new("Folder")
f.Name = "SceneProps"
f.Parent = map

local function P(name: string, size: Vector3, cf: CFrame, c: Color3, mat: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = c
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = f
	return p
end

-- toaster lever (art already in Decor.CounterItems: Toaster at (155, 50, 43), lever (151, 49.5, 43))
local lever = P("ToasterLauncher", Vector3.new(2, 3, 3), CFrame.new(150.6, 49.5, 43), Color3.new(1, 1, 1))
lever.Transparency = 1
lever:SetAttribute("Mode", "Prompt")
lever:SetAttribute("Action", "Pop up!")
lever:SetAttribute("Object", "Toaster")
lever:SetAttribute("From", Vector3.new(155, 58, 40))
lever:SetAttribute("Target", Vector3.new(78, 61, 5)) -- inner window sill top
lever:SetAttribute("Flight", 1.5)
CollectionService:AddTag(lever, "Launcher")
local glow = P("ToasterSlotGlow", Vector3.new(4.6, 0.2, 2.6), CFrame.new(155, 55.15, 40), Color3.fromRGB(255, 140, 60), Enum.Material.Neon)
glow.Transparency = 0.3

-- kitchen sponge trampoline (yellow foam + green scrub), floor south of the table
local spongeCF = CFrame.new(62, 1.2, 110)
local sponge = P("SpongeLauncher", Vector3.new(10, 2.4, 7), spongeCF, Color3.fromRGB(250, 220, 80), Enum.Material.Fabric, true)
sponge:SetAttribute("Mode", "Touch")
sponge:SetAttribute("Target", Vector3.new(62, 38.25, 93)) -- table top
sponge:SetAttribute("Flight", 0.9)
CollectionService:AddTag(sponge, "Launcher")
P("SpongeScrub", Vector3.new(10, 0.8, 7), spongeCF * CFrame.new(0, -1.5, 0), Color3.fromRGB(70, 160, 80), Enum.Material.Fabric)

print("[AddSceneProps] done: toaster launcher + sponge trampoline")
return true
