--!strict
--[[
	AddRouteTopples.luau — adds the 2 RouteTopple pieces to ServerStorage.Maps.MidnightKitchen
	(run AFTER tools/BuildMidnightKitchen + tools/AddFloodMarkup). IDEMPOTENT: replaces the map's
	`RouteTopples` folder. Feature: Config.Features.RouteTopple (server RouteToppleService).

	HOW TO RUN (Studio, EDIT mode): Command Bar →  require(game.ServerStorage.Tools.AddRouteTopples)
	  (Rojo syncs it as a ModuleScript), or paste this file into the Command Bar → Enter.
	  Ctrl+Z undoes it. A require() result is cached per Studio session: to run it again in the
	  same session, paste the file into the Command Bar instead.

	CONTRACT per piece (Contract.Tag.RouteTopple): Model, PrimaryPart = the walk board,
	  attr TopplesOn = "Earthquake,Flood", child CFrameValue `FallenPose` = final pivot (WorldPivot).
	  Standing pivot (WorldPivot) and FallenPose share the SAME point (the hinge on the bottom
	  face at the low end), so the server's CFrame:Lerp is a pure rotation about the hinge.
	  Every part Anchored. ONLY the `Board` part collides (CanCollide/CanQuery true: walkable surfaces
	  are queryable — BuildMidnightKitchen CanQuery policy); rims, nose, legs, end grain and tabs
	  are decor (CanCollide/CanQuery false), so the verified board box below is exactly what
	  players walk on and what the landing hit test uses.

	FRAME CONVENTION: pivot P sits on the board's BOTTOM face, centred across its width, at its
	  low (hinge) end. Board centre = P * (0, T/2, -L/2): local -Z runs up the board.
	  Fallen pose authored from the top-surface line: low point a → high point b,
	  D = unit(b - a), right = unit(D × Y), up = right × D, P = a - up·T, pivot = fromMatrix(P, right, up).

	HAMSTER: R15 hamster ~5.5 tall (Disasters.Flood headHeight), JumpHeight 7.2 (Config.Player),
	  Humanoid.MaxSlopeAngle default 89° (no override anywhere in the code) — design target ≤ 35°
	  like the existing ramps (BuildMidnightKitchen WALKABILITY).

	=====================================================================================
	PIECE 1 — IroningBoard  (floor Y 0 → CounterN_Top Y 45, its south edge at X 122..129)
	  A tall ironing board stands upright on the floor at X 122..129, Z ≈ 88.6..98.6, leaning
	  6° north (tips 84° up). It falls NORTH (towards -Z) about its foot, landing with its top
	  surface flush with CounterN_Top's south edge (Z 30) just west of the east counter: a NEW
	  ramp floor → counter (Radio C/D side, east counter) that skips Ramp1 + Ramp2 (X 64..100).
	  Corridor: X 122..129 is free floor between the StepChair (X ≤ 121.5) and CounterE
	  (X ≥ 130) and east of the RunWheel (X ≤ 121) — verified with an oriented-box (SAT) test
	  against every part in midnightkitchen_map.json: no overlap standing, fallen or at any of
	  40 steps of the fall sweep.
	  Math (top surface): width W 7, thickness T 1.5, slope α 33.5° (tan = 0.6619).
	    Top line a = (125.5, 0.05, 97.912) → b = (125.5, 45, 30): rise 44.95, run 67.912
	      (a.Z = 30 + 44.95 / tan 33.5° = 97.912) → L = √(44.95² + 67.912²) = 81.44.
	    The board's high end stops exactly at the counter's south edge Z 30 with its top face at
	    Y 45.0 = counter top → zero step onto the counter. Low end top face Y 0.05 (flush with floor).
	    The high end's lower corner tucks 0.83 studs (T·sin α) into the counter's top edge (Z 29.17,
	    Y ≥ 43.75) — intended, hides the seam; both are anchored. CounterE (X ≥ 130) is untouched.
	    Slope 33.5° ≤ 35°, width 7 ≥ 6, no gap → no jump needed.
	    Standing: same pivot, up = (0, sin 6°, cos 6°) → top at Y ≈ 80, not touching anything.
	  Pivot P = a - up·T = (125.5, -1.2008, 97.0841) (hinge 1.2 studs under the floor top so the
	    low end's top face is flush; the floor part is solid, the board is anchored — fine).
	  Does NOT overlap: PlayerSpawns, ItemSpawns (nearest Battery_T2 X 93..95, S1 X 110..112 Z 111),
	    ObjectiveAnchors (RunWheel X ≤ 121, Radio C/D X ≥ 143.5), ExitZone, NoImpact (cage X ≤ 32),
	    Routes (Ramp1/Ramp2 X ≤ 100, Ramp3 X ≤ 80), FridgeLane (X ≤ 126 but floor marker only),
	    WashingMachine (X ≥ 136). Floor routes around it: 1-stud grid walk test (hamster radius 1.2,
	    height 5.5) from the cage reaches RunWheel, shoe rack, table, charger, washing machine with
	    the board standing and fallen.
	    The fallen board is a 7-wide strip on open floor (X 122..129): hamsters walk around its low
	    end or under it where headroom ≥ 5.5 (Z ≤ 87); the floor walk test needs neither.

	PIECE 2 — BreadBoard  (north counter Y 45 → window sill WindowSill_Inner Y 61)
	  A tall wooden bread/cutting board stands upright on CounterN_Top at ≈ (120, 45, 26),
	  leaning 4° south-east (tips 86° up). It falls NORTH-WEST about its foot onto the sill's
	  front edge (Z 10, X ≈ 102..107): a NEW ramp counter → sill (window exit / Sill spawns) that
	  skips Ramp3 (the dish rack, far west at X 54..80). Both are counter → sill, so it is a
	  shortcut for players coming from the east counter / RadioC/D side.
	  Math (top surface): W 6, T 1. Top line a = (120.5, 45.05, 26.5) → b = (104.7, 61, 10).
	    Horizontal run √(15.8² + 16.5²) = 22.845, rise 15.95 → slope atan(15.95/22.845) = 34.92°,
	    L = √(15.95² + 22.845²) = 27.862. High end top face Y 61.0 at the sill front edge Z 10 =
	    sill top → zero step. Low end top face 45.05 (flush with counter).
	    Pivot P = a - up·T = (120.1041, 44.2301, 26.0865).
	  Clearances (SAT test vs every map part, standing / fallen / 40-step sweep): no overlap.
	    StepChair art mesh (non-colliding) and Radio_B (X 98.5..101.5, Z 25..27) are clear;
	    Faucet (X 95..100.5) clear; BreadBin (X ≥ 115, Z ≤ 11, Y ≥ 45 — decor, non-colliding)
	    clear of the board (board is at Z ≥ 12.6 where X ≥ 115). Spawn_Counter1 (X 118..122,
	    Z 18..22, Flood only) clear at 0 padding (board passes ~1 stud west of it).
	  Counter walk test (1-stud grid, hamster radius 1.2 / height 5.5) from the Ramp2 top
	    (70, 25) reaches RadioB (100, 22), Radio C (140, 15) and RadioD (140, 55) with the board
	    standing AND fallen: the board's foot (≈ 3 × 4 studs at Z 23..29) leaves the counter
	    free around it; headroom under the fallen board ≥ 5.5 for Z ≤ 18.

	Standing poses never block an existing route: A stands on open floor east of the chair,
	B stands in the counter's south-east part away from the radios (walk test above).
	=====================================================================================
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MAP_NAME = "MidnightKitchen"
local FOLDER_NAME = "RouteTopples"
local TAG = "RouteTopple" -- Contract.Tag.RouteTopple
local ATTR_TOPPLES_ON = "TopplesOn" -- Contract.Attr.TopplesOn
local FALLEN_POSE = "FallenPose" -- Contract.Name.FallenPose
local TOPPLES_ON = "Earthquake" -- Flood excluded: fallen BreadBoard clips Flood spawn Spawn_Counter1, IroningBoard would be a flood escape

local maps = ServerStorage:FindFirstChild("Maps")
local map = maps and maps:FindFirstChild(MAP_NAME)
if not (map and map:IsA("Model")) then
	warn(`[AddRouteTopples] ServerStorage.Maps.{MAP_NAME} not found — run tools/BuildMidnightKitchen.luau first`)
	return true
end

local recording: string? = nil
local okRec, recOrErr = pcall(function()
	return ChangeHistoryService:TryBeginRecording("AddRouteTopples")
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

-- Board-local helper: offset in pivot space where X = across, Y = up from the bottom face,
-- Z = along the board (negative = towards the high end).
local function part(model: Model, name: string, pivot: CFrame, offset: Vector3, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	-- standing boards are not solid (players could jump up a near-vertical board onto the
	-- counter); RouteToppleService.land makes the Board solid once it has fallen
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = pivot * CFrame.new(offset)
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

type Spec = {
	name: string,
	standing: CFrame,
	fallen: CFrame,
	width: number,
	thickness: number,
	length: number,
	build: (model: Model, pivot: CFrame, w: number, t: number, l: number) -> Part, -- returns PrimaryPart
}

local WOOD = Enum.Material.Wood
local PLASTIC = Enum.Material.SmoothPlastic

local SPECS: { Spec } = {
	{
		name = "IroningBoard",
		-- pivot (125.5, -1.2008, 97.0841); right = +X; up = (0, sin 6°, cos 6°) standing,
		-- (0, cos 33.5°, sin 33.5°) fallen; back = right × up
		standing = CFrame.new(125.5, -1.2008, 97.0841, 1, 0, 0, 0, 0.10453, -0.99452, 0, 0.99452, 0.10453),
		fallen = CFrame.new(125.5, -1.2008, 97.0841, 1, 0, 0, 0, 0.83389, -0.55194, 0, 0.55194, 0.83389),
		width = 7,
		thickness = 1.5,
		length = 81.44,
		build = function(model: Model, pivot: CFrame, w: number, t: number, l: number): Part
			-- walk board: padded cover (light grey-blue) — the only collider that matters
			local board = part(model, "Board", pivot, Vector3.new(0, t / 2, -l / 2), Vector3.new(w, t, l), Color3.fromRGB(170, 190, 215), PLASTIC)
			-- metal rim strips along both long edges (decor)
			for _, sx in { -1, 1 } do
				part(model, if sx < 0 then "Rim_W" else "Rim_E", pivot, Vector3.new(sx * (w / 2 + 0.2), t / 2, -l / 2), Vector3.new(0.4, t, l), Color3.fromRGB(200, 200, 210), PLASTIC)
			end
			-- tapered nose past the high end (decor, no collision: rests visually over the counter)
			part(model, "Nose", pivot, Vector3.new(0, t / 2, -l - 1), Vector3.new(w * 0.6, t, 2), Color3.fromRGB(170, 190, 215), PLASTIC)
			-- folded legs under the board (decor)
			part(model, "LegFolded", pivot, Vector3.new(0, -0.3, -l * 0.45), Vector3.new(w * 0.7, 0.6, l * 0.5), Color3.fromRGB(150, 150, 160), PLASTIC)
			return board
		end,
	},
	{
		name = "BreadBoard",
		-- pivot (120.1041, 44.2301, 26.0865); right = (0.72226, 0, -0.69162)
		standing = CFrame.new(120.1041, 44.2301, 26.0865, 0.72226, 0.68994, 0.04824, 0, 0.06976, -0.99756, -0.69162, 0.72050, 0.05038),
		fallen = CFrame.new(120.1041, 44.2301, 26.0865, 0.72226, 0.39593, 0.56708, 0, 0.81993, -0.57246, -0.69162, 0.41347, 0.59220),
		width = 6,
		thickness = 1,
		length = 27.862,
		build = function(model: Model, pivot: CFrame, w: number, t: number, l: number): Part
			local board = part(model, "Board", pivot, Vector3.new(0, t / 2, -l / 2), Vector3.new(w, t, l), Color3.fromRGB(196, 150, 98), WOOD)
			-- darker end-grain strips at both ends (decor)
			part(model, "EndGrain_Low", pivot, Vector3.new(0, t / 2, -0.5), Vector3.new(w + 0.1, t + 0.05, 1), Color3.fromRGB(150, 105, 60), WOOD)
			part(model, "EndGrain_High", pivot, Vector3.new(0, t / 2, -l + 0.5), Vector3.new(w + 0.1, t + 0.05, 1), Color3.fromRGB(150, 105, 60), WOOD)
			-- hanging-hole handle tab sticking out past the high end (decor only)
			part(model, "HandleTab", pivot, Vector3.new(0, t / 2, -l - 1.5), Vector3.new(3, t, 3), Color3.fromRGB(196, 150, 98), WOOD)
			return board
		end,
	},
}

local made: { string } = {}
for _, spec in SPECS do
	local model = Instance.new("Model")
	model.Name = spec.name
	model.Parent = root
	local primary = spec.build(model, spec.standing, spec.width, spec.thickness, spec.length)
	model.PrimaryPart = primary
	-- With a PrimaryPart set, Model.WorldPivot is ignored: the model pivot is
	-- PrimaryPart.CFrame * PrimaryPart.PivotOffset. Put the hinge there explicitly.
	primary.PivotOffset = primary.CFrame:ToObjectSpace(spec.standing)
	model.WorldPivot = spec.standing -- pivot = hinge (PivotTo/GetPivot use this, not PrimaryPart.CFrame)
	model:SetAttribute(ATTR_TOPPLES_ON, TOPPLES_ON)
	local pose = Instance.new("CFrameValue")
	pose.Name = FALLEN_POSE
	pose.Value = spec.fallen
	pose.Parent = model
	CollectionService:AddTag(model, TAG)
	table.insert(made, spec.name)
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print("================ AddRouteTopples ================")
print(`  {map:GetFullName()}.{FOLDER_NAME}: {table.concat(made, ", ")} (tag {TAG}, TopplesOn {TOPPLES_ON})`)
print("  IroningBoard: floor (125.5, 0, 97.9) → CounterN_Top south edge (125.5, 45, 30), 33.5°")
print("  BreadBoard:   CounterN_Top (120.5, 45, 26.5) → WindowSill_Inner edge (104.7, 61, 10), 34.9°")
print("  Turn on Config.Features.RouteTopple to use them (/dbg topple to test).")
print("=================================================")

return true -- lets Rojo sync this as a ModuleScript (ServerStorage.Tools) so it can be run via require()
