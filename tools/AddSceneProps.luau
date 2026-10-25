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


-- 🚰 Faucet (north counter sink): "Turn on" once → water spills down the cabinet and runs across
-- the floor as a stream; a bottle-cap boat rides it (and the current carries you).
local faucet = Instance.new("Model")
faucet.Name = "Faucet"
faucet:SetAttribute("Kind", "Faucet")
faucet:SetAttribute("Action", "Turn on")
faucet:SetAttribute("Object", "Faucet")
faucet:SetAttribute("Flag", "FaucetOn")
faucet:SetAttribute("Banner", "The tap is running!")
faucet:SetAttribute("BannerSub", "Water is flowing across the floor…")
CollectionService:AddTag(faucet, "Switch")
faucet.Parent = f
local fp = P("PromptPart", Vector3.new(2, 2, 2), CFrame.new(96, 47, 25), Color3.new(1, 1, 1))
fp.Transparency = 1
fp.Parent = faucet
local water = Instance.new("Model")
water.Name = "Water"
water.Parent = faucet
local blue = Color3.fromRGB(90, 160, 230)
local function w(name: string, size: Vector3, cf: CFrame): Part
	local p = P(name, size, cf, blue, Enum.Material.Glass)
	p.Transparency = 0.35
	p.Parent = water
	return p
end
w("Spout", Vector3.new(1.2, 6, 1.2), CFrame.new(96, 48, 20))
w("Overflow", Vector3.new(10, 0.3, 2), CFrame.new(62, 45.2, 29.5))
w("Waterfall", Vector3.new(6, 45, 0.5), CFrame.new(62, 22.5, 30.6))
w("StreamA_Visual", Vector3.new(7, 0.25, 58), CFrame.new(62, 0.15, 60))
w("StreamB_Visual", Vector3.new(112, 0.25, 8), CFrame.new(96, 0.15, 88))
water:SetAttribute("RevealedBy", "FaucetOn")
CollectionService:AddTag(water, "FlagReveal")
-- invisible water zones (top = surface): A runs south (+Z), B runs east (+X)
local function zone(name: string, size: Vector3, cf: CFrame, flow: Vector3)
	local z = P("StreamZone", size, cf, blue)
	z.Transparency = 1
	z:SetAttribute("Flow", flow)
	z.Parent = faucet
end
zone("StreamZone", Vector3.new(7, 2.2, 58), CFrame.new(62, 1.1, 60), Vector3.new(0, 0, 9))
zone("StreamZone", Vector3.new(112, 2.2, 8), CFrame.new(96, 1.1, 88), Vector3.new(9, 0, 0))

-- 🌀 Fan (floor by the east counter): "Turn on" → 25 s of updraft that lifts you to the counter
local fan = Instance.new("Model")
fan.Name = "Fan"
fan:SetAttribute("Kind", "Fan")
fan:SetAttribute("Action", "Turn on")
fan:SetAttribute("Object", "Fan")
fan:SetAttribute("Duration", 25)
fan:SetAttribute("Banner", "Whoosh! The fan is on")
fan:SetAttribute("BannerSub", "Ride the wind up!")
CollectionService:AddTag(fan, "Switch")
fan.Parent = f
local base = Vector3.new(125.5, 0, 47) -- wind column x 121.5..129.5: clear of the step-chair back (x <= 121)
local function fpart(name: string, size: Vector3, cf: CFrame, c: Color3, mat: Enum.Material?, collide: boolean?): Part
	local p = P(name, size, cf, c, mat, collide)
	p.Parent = fan
	return p
end
local grey = Color3.fromRGB(70, 75, 85)
local cage = fpart("Base", Vector3.new(1, 9, 9), CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), grey, Enum.Material.Metal, true)
cage.Shape = Enum.PartType.Cylinder
local ring = fpart("Ring", Vector3.new(0.6, 8.6, 8.6), CFrame.new(base + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
ring.Shape = Enum.PartType.Cylinder
local hub = fpart("Hub", Vector3.new(1.4, 1.4, 1.4), CFrame.new(base + Vector3.new(0, 1.6, 0)), Color3.fromRGB(230, 90, 80))
hub.Shape = Enum.PartType.Ball
local blades = Instance.new("Model")
blades.Name = "Blades"
blades.Parent = fan
for i = 0, 2 do
	local b = P("Blade" .. i, Vector3.new(3.6, 0.2, 1.4), hub.CFrame * CFrame.Angles(0, math.rad(120 * i), 0) * CFrame.new(1.9, 0, 0) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(120, 200, 255))
	b.Parent = blades
end
blades.WorldPivot = hub.CFrame -- clients spin it round the hub
local fpp = fpart("PromptPart", Vector3.new(2, 2, 2), CFrame.new(base + Vector3.new(-5, 2, 0)), Color3.new(1, 1, 1))
fpp.Transparency = 1
local wind = fpart("Wind", Vector3.new(8, 50, 8), CFrame.new(base + Vector3.new(0, 26, 0)), Color3.fromRGB(200, 230, 255))
wind.Transparency = 1

print("[AddSceneProps] done: toaster launcher + sponge trampoline")
return true
