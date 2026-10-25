--!strict
--[[
	AddSceneProps.luau — interactive scene objects (LauncherService / LauncherController) in
	ServerStorage.Maps.MidnightKitchen. Idempotent: rebuilds the folder SceneProps.
	  🍞 Toaster: press "Pop up!" at the toaster lever (east counter) → you pop out of the slot
	     and fly onto the window sill.
	  🧽 Kitchen sponge on the south end of the east counter: jump on it → bounce along the
	     counter to the sink corner (a shortcut between places you can already walk to).
	  🚰 Faucet: turn on → water runs across the floor; ride the stream in a bottle cap.
	  🪨 Knife sharpener on the floor south of the table: sharpen the scissors before prying.
	  🌀 Standing fan on the floor east of the table: 25 s of sideways wind along the floor
	     (under the table, toward the west wall). Never lifts anyone: only speeds you up.
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

-- kitchen sponge trampoline (yellow foam + green scrub), east counter south end (top Y 45).
-- Shortcut only: both ends are on the counters, reachable on foot.
local spongeCF = CFrame.new(148, 46.2, 66) -- clear of the Scn_CounterE item spot (150, 45, 80)
local sponge = P("SpongeLauncher", Vector3.new(8, 2.4, 8), spongeCF, Color3.fromRGB(250, 220, 80), Enum.Material.Fabric, true)
sponge:SetAttribute("Mode", "Touch")
sponge:SetAttribute("Target", Vector3.new(100, 45.05, 14)) -- north counter, by the faucet
sponge:SetAttribute("Flight", 1.3)
CollectionService:AddTag(sponge, "Launcher")
P("SpongeScrub", Vector3.new(8, 0.8, 8), spongeCF * CFrame.new(0, -1.5, 0), Color3.fromRGB(70, 160, 80), Enum.Material.Fabric)


-- 🚰 Faucet (north counter sink): "Turn on" once → water spills down the cabinet and runs across
-- the floor as a stream; a bottle-cap boat rides it (and the current carries you).
local faucet = Instance.new("Model")
faucet.Name = "Faucet"
faucet:SetAttribute("Kind", "Faucet")
faucet:SetAttribute("Action", "Turn on")
faucet:SetAttribute("Object", "Faucet")
faucet:SetAttribute("Flag", "FaucetOn")
faucet:SetAttribute("ActionOff", "Turn off")
faucet:SetAttribute("Banner", "The tap is running!")
faucet:SetAttribute("BannerSub", "Water is flowing across the floor…")
faucet:SetAttribute("BannerOff", "🚰 The tap is off")
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
-- a third arm runs east along the cabinet into the drain under the step chair (drain round: the
-- tap is on from the start and must be turned off before tying the cable)
w("StreamC_Visual", Vector3.new(48, 0.25, 3), CFrame.new(86, 0.15, 34.5))
w("DrainSplash", Vector3.new(5, 2.5, 5), CFrame.new(110, 1.2, 37))
-- shown / hidden by LauncherService (faucet toggles on and off), not by a flag
-- invisible water zones (top = surface): A runs south (+Z), B runs east (+X)
local function zone(name: string, size: Vector3, cf: CFrame, flow: Vector3)
	local z = P("StreamZone", size, cf, blue)
	z.Transparency = 1
	z:SetAttribute("Flow", flow)
	z.Parent = faucet
end
zone("StreamZone", Vector3.new(7, 2.2, 58), CFrame.new(62, 1.1, 60), Vector3.new(0, 0, 9))
zone("StreamZone", Vector3.new(112, 2.2, 8), CFrame.new(96, 1.1, 88), Vector3.new(9, 0, 0))

-- 🪨 Knife sharpener (floor south of the table): hold "Sharpen" while holding the scissors →
-- flag ScissorsSharp (blunt scissors cannot pry the window latch or the drain grate). One-shot.
local sharp = Instance.new("Model")
sharp.Name = "Sharpener"
sharp:SetAttribute("Kind", "Sharpener")
sharp:SetAttribute("Action", "Sharpen")
sharp:SetAttribute("Object", "Knife sharpener")
sharp:SetAttribute("HoldDuration", 2)
sharp:SetAttribute("RequiresCapability", "Pry")
sharp:SetAttribute("MissingHint", "🪨 ต้องถือของมีคมมาลับ · Bring something sharp to sharpen")
sharp:SetAttribute("Flag", "ScissorsSharp")
sharp:SetAttribute("Banner", "✂️ กรรไกรคมแล้ว! · Scissors sharpened!")
CollectionService:AddTag(sharp, "Switch")
sharp.Parent = f
local sbase = Vector3.new(60, 0, 115)
local function spart(name: string, size: Vector3, cf: CFrame, c: Color3, mat: Enum.Material?, collide: boolean?): Part
	local p = P(name, size, cf, c, mat, collide)
	p.Parent = sharp
	return p
end
spart("Base", Vector3.new(8, 1.2, 4), CFrame.new(sbase + Vector3.new(0, 0.6, 0)), Color3.fromRGB(150, 100, 60), Enum.Material.Wood, true)
spart("Stone", Vector3.new(6.4, 1.4, 2.6), CFrame.new(sbase + Vector3.new(0, 1.9, 0)), Color3.fromRGB(120, 125, 135), Enum.Material.Slate, true)
spart("StoneTop", Vector3.new(6.4, 0.2, 2.6), CFrame.new(sbase + Vector3.new(0, 2.7, 0)), Color3.fromRGB(80, 150, 200), Enum.Material.Slate)
local spp = spart("PromptPart", Vector3.new(2, 2, 2), CFrame.new(sbase + Vector3.new(0, 3, 0)), Color3.new(1, 1, 1))
spp.Transparency = 1

-- 🌀 Standing fan (floor east of the table, facing west): "Turn on" → 25 s of wind blowing
-- along the floor under the table (Wind attr Push). It never lifts: only speeds you up.
local fan = Instance.new("Model")
fan.Name = "Fan"
fan:SetAttribute("Kind", "Fan")
fan:SetAttribute("Action", "Turn on")
fan:SetAttribute("Object", "Fan")
fan:SetAttribute("Duration", 25)
fan:SetAttribute("Banner", "Whoosh! The fan is on")
fan:SetAttribute("BannerSub", "The wind blows along the floor")
CollectionService:AddTag(fan, "Switch")
fan.Parent = f
local base = Vector3.new(124, 0, 72) -- floor; east counter cabinet starts at x 130
local function fpart(name: string, size: Vector3, cf: CFrame, c: Color3, mat: Enum.Material?, collide: boolean?): Part
	local p = P(name, size, cf, c, mat, collide)
	p.Parent = fan
	return p
end
local grey = Color3.fromRGB(70, 75, 85)
local foot = fpart("Base", Vector3.new(1, 7, 7), CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), grey, Enum.Material.Metal, true)
foot.Shape = Enum.PartType.Cylinder
fpart("Pole", Vector3.new(1, 8, 1), CFrame.new(base + Vector3.new(0, 4.5, 0)), grey, Enum.Material.Metal, true)
fpart("Motor", Vector3.new(2.4, 2, 2), CFrame.new(base + Vector3.new(0.8, 9, 0)), grey, Enum.Material.Metal, true)
local headPos = base + Vector3.new(-0.8, 9, 0)
local ring = fpart("Ring", Vector3.new(0.6, 8.6, 8.6), CFrame.new(headPos + Vector3.new(-0.6, 0, 0)), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
ring.Shape = Enum.PartType.Cylinder -- cylinder axis = X: the face looks west
local hub = fpart("Hub", Vector3.new(1.2, 1.2, 1.2), CFrame.new(headPos), Color3.fromRGB(230, 90, 80))
hub.Shape = Enum.PartType.Ball
local blades = Instance.new("Model")
blades.Name = "Blades"
blades.Parent = fan
for i = 0, 2 do
	local b = P("Blade" .. i, Vector3.new(0.2, 3.4, 1.4), hub.CFrame * CFrame.Angles(math.rad(120 * i), 0, 0) * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, math.rad(20), 0), Color3.fromRGB(120, 200, 255))
	b.Parent = blades
end
blades.WorldPivot = hub.CFrame -- clients spin it round the hub's X axis
local fpp = fpart("PromptPart", Vector3.new(2, 2, 2), CFrame.new(base + Vector3.new(3, 2, 3)), Color3.new(1, 1, 1))
fpp.Transparency = 1
-- wind: floor-level box from the fan west to x 30 (between the table legs at z 63 / 100)
local wind = fpart("Wind", Vector3.new(92, 12, 10), CFrame.new(76, 6, 72), Color3.fromRGB(200, 230, 255))
wind.Transparency = 1
wind:SetAttribute("Push", Vector3.new(-14, 0, 0))

print("[AddSceneProps] done: toaster, sponge, faucet, fan, sharpener")
return true
