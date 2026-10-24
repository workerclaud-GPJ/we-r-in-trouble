--!strict
--[[
	AddItemSpawns.luau — extra ItemSpawn points for Features.CapabilitySpawn (LootService)
	in ServerStorage.Maps.MidnightKitchen (run AFTER tools/BuildMidnightKitchen.luau).

	HOW TO RUN (Studio, EDIT mode): require(game.ServerStorage.Tools.AddItemSpawns)
	  or paste this file into the Command Bar → Enter. Ctrl+Z undoes it.

	IDEMPOTENT: replaces ItemSpawns.Loot_* parts it created earlier; re-sets SizeClass on the
	existing Battery_* points. Nothing else is touched.

	NEW POINTS have ItemType = "Loot" so the legacy Battery spawn (ItemService.spawnItems,
	filters ItemType == "Battery") never uses them: with every Features switch off the game is
	unchanged. LootService ignores ItemType and uses every ItemSpawn.
	  Attributes: Zone (max one item per zone where possible), SizeClass "Small" | "Medium",
	  Fallback = true on 2 open, always-reachable floor points (force-spawns land there).
	Coordinates (map-local = world, floor top Y 0, counter tops Y 45; inner window sill block
	covers counter Z 0..10, so counter points sit at Z >= 20). The dining table top (+38.25) is NOT
	used: no ramp reaches it (chair seat +23 is 15 studs lower and 6 studs away).
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MAP_NAME = "MidnightKitchen"
local PREFIX = "Loot_"
local LOOT_ITEM_TYPE = "Loot"

type SpawnDef = { name: string, pos: Vector3, zone: string, size: string, fallback: boolean, note: string }

local NEW: { SpawnDef } = {
	{ name = "Loot_CounterW", pos = Vector3.new(52, 45, 24), zone = "CW", size = "Medium", fallback = false, note = "north counter, between radio A and the dish rack" },
	{ name = "Loot_CounterNE", pos = Vector3.new(138, 45, 24), zone = "CNE", size = "Small", fallback = false, note = "north counter, east of the bread bin" },
	{ name = "Loot_CounterE", pos = Vector3.new(140, 45, 42), zone = "CE", size = "Medium", fallback = false, note = "east counter, west of the toaster" },
	{ name = "Loot_FloorWheel", pos = Vector3.new(117, 0, 92), zone = "W", size = "Small", fallback = false, note = "floor, south of the wheel (west of the IroningBoard strip X 122..129)" },
	{ name = "Loot_FallbackMid", pos = Vector3.new(56, 0, 40), zone = "M", size = "Medium", fallback = true, note = "open floor between charger and cookbooks" },
	{ name = "Loot_FallbackBack", pos = Vector3.new(132, 0, 112), zone = "B", size = "Medium", fallback = true, note = "open floor by the back door" },
}

-- SizeClass of the existing Battery points (BuildMidnightKitchen)
local EXISTING_SIZE: { [string]: string } = {
	Battery_T1 = "Medium", -- under the table, open floor
	Battery_T2 = "Medium",
	Battery_S1 = "Small", -- between the shoes (tight)
	Battery_S2 = "Medium",
	Battery_P1 = "Medium",
	Battery_P2 = "Small", -- behind the curtain, under the shelf
}

local maps = ServerStorage:FindFirstChild("Maps")
local map = maps and maps:FindFirstChild(MAP_NAME)
if not (map and map:IsA("Model")) then
	warn(`[AddItemSpawns] ServerStorage.Maps.{MAP_NAME} not found — run tools/BuildMidnightKitchen.luau first`)
	return true
end
local folder = map:FindFirstChild("ItemSpawns")
if not folder then
	warn("[AddItemSpawns] map has no ItemSpawns folder — run tools/BuildMidnightKitchen.luau first")
	return true
end

local recording: string? = nil
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("AddItemSpawns")
end)

-- same offset logic as BuildProps (map may have been moved)
local origin = Vector3.zero
local structure = map:FindFirstChild("Structure")
local floorPart = structure and structure:FindFirstChild("Floor")
if floorPart and floorPart:IsA("BasePart") then
	origin = floorPart.Position - Vector3.new(80, -1, 60)
end

for _, child in folder:GetChildren() do
	if string.sub(child.Name, 1, #PREFIX) == PREFIX then
		child:Destroy()
	end
end

-- 2 × 1 × 2 marker whose bottom sits on the surface (same as BuildMidnightKitchen.itemSpawn)
for _, def in NEW do
	local p = Instance.new("Part")
	p.Name = def.name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(2, 1, 2)
	p.CFrame = CFrame.new(origin + def.pos + Vector3.new(0, 0.5, 0))
	p.Color = if def.fallback then Color3.fromRGB(255, 170, 40) else Color3.fromRGB(60, 230, 60)
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 1
	p:SetAttribute("ItemType", LOOT_ITEM_TYPE)
	p:SetAttribute("Zone", def.zone)
	p:SetAttribute("SizeClass", def.size)
	if def.fallback then
		p:SetAttribute("Fallback", true)
	end
	CollectionService:AddTag(p, "ItemSpawn")
	p.Parent = folder
end

local updated = 0
for name, size in EXISTING_SIZE do
	local p = folder:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		p:SetAttribute("SizeClass", size)
		updated += 1
	else
		warn(`[AddItemSpawns] existing ItemSpawn {name} not found`)
	end
end

local rec = recording
if rec then
	pcall(function()
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end)
end

print("================ AddItemSpawns ================")
for _, def in NEW do
	print(`  {def.name} @ {def.pos} Zone {def.zone} {def.size}{if def.fallback then " Fallback" else ""} — {def.note}`)
end
print(`  SizeClass set on {updated} existing Battery_* points`)
print("===============================================")

return true
