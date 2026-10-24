--!strict
--[[
	AddFloodMarkup.luau — adds Flood + random-event markup to ServerStorage.Maps.MidnightKitchen
	(run AFTER tools/BuildMidnightKitchen.luau). IDEMPOTENT: replaces the map's `FloodMarkup` folder.

	HOW TO RUN (Studio, EDIT mode): Command Bar → paste this file → Enter,
	  or require(game.ServerStorage.Tools.AddFloodMarkup) (Rojo syncs it as a ModuleScript).

	ADDS (contract: docs/ARCHITECTURE.md §6):
	  FloodLevel0     Part, tag VolumeLevel, Level = 0. Centre Y 0 (kitchen floor top) and X/Z =
	                  the kitchen interior 160 × 120 → the water footprint (VolumeService).
	  Spawn_Counter1-4  PlayerSpawn pads on the counter (+45), Priority 3, EnabledBy = "Flooding"
	                  (VolumeService sets that flag; never used in Earthquake matches). The respawn
	                  filter skips flooded floor pads, so these are picked once the floor floods.
	  WashingMachine  decor (SE corner, X 136..158, Z 86..104) + `VolumeSource` part at its hose
	                  outlet (client spray FX).
	  FridgeLane      Part, tag EventLane, EventId = "FridgeBurst": band in front of the fridge door
	                  (X 36 → 126, Z 55..81), LookVector = +X (slide direction).
	All markers: Anchored, CanCollide/CanQuery/CanTouch false, invisible.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MAP_NAME = "MidnightKitchen"
local FOLDER_NAME = "FloodMarkup"
local FLOOD_FLAG = "Flooding" -- Config.Disasters.Flood.volume.enableFlag
local COUNTER_TOP = 45
local COUNTER_SPAWNS = { Vector2.new(120, 20), Vector2.new(128, 22), Vector2.new(145, 72), Vector2.new(152, 72) }

local maps = ServerStorage:FindFirstChild("Maps")
local map = maps and maps:FindFirstChild(MAP_NAME)
if not (map and map:IsA("Model")) then
	warn(`[AddFloodMarkup] ServerStorage.Maps.{MAP_NAME} not found — run tools/BuildMidnightKitchen.luau first`)
	return true
end

local recording: string? = nil
local okRec, recOrErr = pcall(function()
	return ChangeHistoryService:TryBeginRecording("AddFloodMarkup")
end)
if okRec then
	recording = recOrErr
end

local old = map:FindFirstChild(FOLDER_NAME)
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = FOLDER_NAME
root.Parent = map

local function part(parent: Instance, name: string, cf: CFrame, size: Vector3, visible: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = if visible then 0 else 1
	p.Parent = parent
	return p
end

-- 1) Water reference level + footprint
local level0 = part(root, "FloodLevel0", CFrame.new(80, 0, 60), Vector3.new(160, 0.2, 120), false)
level0:SetAttribute("Level", 0)
CollectionService:AddTag(level0, "VolumeLevel")

-- 2) Counter spawns (Priority 3 > floor 2; sill 1 after WindowOpen)
for i, xz in COUNTER_SPAWNS do
	local pad = part(root, "Spawn_Counter" .. i, CFrame.new(xz.X, COUNTER_TOP + 0.1, xz.Y), Vector3.new(4, 0.2, 4), true)
	pad.Color = Color3.fromRGB(120, 200, 255)
	pad.Transparency = 0.5
	pad:SetAttribute("Priority", 3)
	pad:SetAttribute("EnabledBy", FLOOD_FLAG)
	CollectionService:AddTag(pad, "PlayerSpawn")
end

-- 3) Washing machine (decor, collides, CanQuery false like other props) + hose source
local washer = Instance.new("Model")
washer.Name = "WashingMachine"
washer.Parent = root
local body = part(washer, "Body", CFrame.new(147, 13, 95), Vector3.new(22, 26, 18), true)
body.CanCollide = true
body.Color = Color3.fromRGB(235, 238, 242)
local door = part(washer, "Door", CFrame.new(135.9, 12, 95), Vector3.new(0.4, 12, 12), true) -- cylinder axis X: faces west
door.Shape = Enum.PartType.Cylinder
door.Material = Enum.Material.Glass
door.Color = Color3.fromRGB(120, 160, 200)
door.Transparency = 0.3
local hose = part(washer, "Hose", CFrame.new(134.5, 3, 102), Vector3.new(3, 1.2, 1.2), true)
hose.Color = Color3.fromRGB(70, 70, 80)
-- spray points west (-X) out of the hose end; ParticleEmitter emits along the part's Front (-Z)
part(root, "VolumeSource", CFrame.lookAt(Vector3.new(132.8, 3, 102), Vector3.new(120, 4, 102)), Vector3.new(0.5, 0.5, 0.5), false)

-- 4) Fridge ice lane band
local laneCentre = Vector3.new(81, 0, 68)
local lane = part(root, "FridgeLane", CFrame.lookAt(laneCentre, laneCentre + Vector3.xAxis), Vector3.new(26, 0.2, 90), false)
lane:SetAttribute("EventId", "FridgeBurst")
CollectionService:AddTag(lane, "EventLane")

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print("================ AddFloodMarkup ================")
print(`  {map:GetFullName()}.{FOLDER_NAME}: VolumeLevel 0 @ Y 0 (160 × 120), {#COUNTER_SPAWNS} counter spawns (Priority 3, EnabledBy {FLOOD_FLAG}),`)
print("  WashingMachine + VolumeSource, EventLane FridgeBurst (X 36→126, Z 55..81)")
print("================================================")

return true
