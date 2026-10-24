--!strict
--[[
	BuildHamster.luau  —  run ONCE in Roblox Studio (Edit mode, NOT during Play).

	HOW TO RUN
	  1. View > Command Bar.
	  2. (Optional) change FUR_VARIANT below.
	  3. Paste this whole file into the Command Bar and press Enter.
	  4. Output window prints "[BuildHamster] Done ...". Press Play to test.

	WHAT IT DOES
	  * Creates StarterPlayer.StarterCharacter = a standard-size R15 rig
	    (from Players:CreateHumanoidModelFromDescription, default scales) so the
	    default Animate script, HumanoidRootPart, hitbox and WalkSpeed 16 stay
	    exactly as GDD 1.1 assumes (~5 studs tall, 1 stud = 2 cm).
	  * Adds cosmetic hamster parts (round fur body, belly, big round head,
	    ears, puffy cheeks, eyes with highlights, nose, buck teeth, tail).
	    Every cosmetic part is: CanCollide/CanQuery/CanTouch = false,
	    Massless = true, Anchored = false, joined with a Weld (explicit C0).
	    -> physics, hitbox, raycasts and animations are unaffected.
	  * Adds named Attachments other systems may use:
	      Head.StatusFxAttachment   (dizzy stars / "Bonk!" spawn point)
	      UpperTorso.PoofAttachment (Poofed! fluff burst)
	      UpperTorso.CarryAttachment(hug-in-front point for a held battery)
	  * Sets StarterPlayer.LoadCharacterAppearance = false so players' own
	    avatar clothes/hats are NOT glued onto the hamster.

	IDEMPOTENT
	  * A previous hamster (Attribute HamsterBuilder = true) is replaced.
	  * Any other existing StarterCharacter is kept, renamed
	    "StarterCharacter_Backup_<time>" (never deleted).
	  * Safe to run again after changing FUR_VARIANT.

	FALLBACK (if CreateHumanoidModelFromDescription errors in your Studio)
	  Avatar tab > Rig Builder > R15 > "Block Rig" (creates workspace.Rig),
	  or select any R15 rig model, then run this script again. The script
	  clones the selected rig / workspace.Rig and never modifies the original.

	Undo: Ctrl+Z (a ChangeHistory waypoint is set before and after).
]]

---------------------------------------------------------------------------
-- SETTINGS
---------------------------------------------------------------------------

-- "Golden" (Syrian golden hamster)  |  "WinterWhite" (grey-white dwarf hamster)
local FUR_VARIANT: string = "Golden"

-- true = also drop an anchored preview copy in Workspace (for screenshots /
-- icon shots). It is placed far from the map and replaced on every run.
local SPAWN_PREVIEW: boolean = false
local PREVIEW_POSITION = Vector3.new(0, 10, -3000)

---------------------------------------------------------------------------
-- PALETTES
---------------------------------------------------------------------------

type Palette = {
	Fur: Color3, -- body, head, arms, legs
	Belly: Color3, -- belly patch + cheeks
	Pink: Color3, -- hands, feet, nose, inner ears
	EarOuter: Color3,
	Eye: Color3,
	Highlight: Color3,
	Teeth: Color3,
	Tail: Color3,
}

local PALETTES: { [string]: Palette } = {
	Golden = {
		Fur = Color3.fromRGB(226, 158, 84),
		Belly = Color3.fromRGB(255, 240, 214),
		Pink = Color3.fromRGB(255, 170, 180),
		EarOuter = Color3.fromRGB(200, 128, 66),
		Eye = Color3.fromRGB(28, 20, 24),
		Highlight = Color3.fromRGB(255, 255, 255),
		Teeth = Color3.fromRGB(255, 252, 240),
		Tail = Color3.fromRGB(240, 196, 140),
	},
	WinterWhite = {
		Fur = Color3.fromRGB(176, 180, 196),
		Belly = Color3.fromRGB(250, 250, 255),
		Pink = Color3.fromRGB(255, 176, 192),
		EarOuter = Color3.fromRGB(120, 124, 142),
		Eye = Color3.fromRGB(24, 20, 30),
		Highlight = Color3.fromRGB(255, 255, 255),
		Teeth = Color3.fromRGB(255, 252, 240),
		Tail = Color3.fromRGB(236, 238, 246),
	},
}

---------------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------------

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

local TAG = "[BuildHamster]"
local BUILDER_ATTR = "HamsterBuilder"

if RunService:IsRunning() then
	error(TAG .. " Stop Play mode first; run this in Edit mode.")
end

local palette = PALETTES[FUR_VARIANT]
if palette == nil then
	error(TAG .. ' Unknown FUR_VARIANT "' .. FUR_VARIANT .. '" (use "Golden" or "WinterWhite").')
end

pcall(function()
	ChangeHistoryService:SetWaypoint("BuildHamster: before")
end)

---------------------------------------------------------------------------
-- 1. GET A STANDARD R15 RIG
---------------------------------------------------------------------------

local function isR15Rig(inst: Instance?): boolean
	if inst == nil or not inst:IsA("Model") then
		return false
	end
	local hum = inst:FindFirstChildOfClass("Humanoid")
	return hum ~= nil
		and hum.RigType == Enum.HumanoidRigType.R15
		and inst:FindFirstChild("HumanoidRootPart") ~= nil
		and inst:FindFirstChild("UpperTorso") ~= nil
		and inst:FindFirstChild("Head") ~= nil
end

local function makeRigFromDescription(): Model?
	local ok, result = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		-- Default scales (1.0) = standard Roblox size, as GDD 1.1 requires.
		desc.HeadColor = palette.Fur
		desc.TorsoColor = palette.Fur
		desc.LeftArmColor = palette.Fur
		desc.RightArmColor = palette.Fur
		desc.LeftLegColor = palette.Fur
		desc.RightLegColor = palette.Fur
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and typeof(result) == "Instance" and isR15Rig(result) then
		return result :: Model
	end
	warn(TAG, "CreateHumanoidModelFromDescription unavailable:", result)
	return nil
end

local function findFallbackRig(): Model?
	for _, inst in Selection:Get() do
		if isR15Rig(inst) and inst ~= StarterPlayer:FindFirstChild("StarterCharacter") then
			return (inst :: Model):Clone()
		end
	end
	local rig = workspace:FindFirstChild("Rig")
	if isR15Rig(rig) then
		return (rig :: Model):Clone()
	end
	return nil
end

local rig: Model? = makeRigFromDescription() or findFallbackRig()
if rig == nil then
	error(
		TAG
			.. " No R15 rig. Use Avatar tab > Rig Builder > R15 > Block Rig (creates workspace.Rig), "
			.. "or select an R15 rig, then run again."
	)
end
local character = rig :: Model

---------------------------------------------------------------------------
-- 2. CLEAN THE BASE RIG
---------------------------------------------------------------------------

local function getPart(name: string): BasePart
	local p = character:FindFirstChild(name)
	if p == nil or not p:IsA("BasePart") then
		error(TAG .. " Rig is missing part " .. name)
	end
	return p :: BasePart
end

-- Remove clothes, accessories, face and BodyColors (BodyColors would repaint
-- pink hands/feet back to the arm/leg colour).
for _, inst in character:GetDescendants() do
	if
		inst:IsA("Accessory")
		or inst:IsA("Shirt")
		or inst:IsA("Pants")
		or inst:IsA("ShirtGraphic")
		or inst:IsA("BodyColors")
		or inst:IsA("CharacterMesh")
	then
		inst:Destroy()
	end
end

local head = getPart("Head")
for _, inst in head:GetChildren() do
	if inst:IsA("Decal") then
		inst:Destroy() -- default face; replaced by our eyes
	end
end
head.Transparency = 1 -- covered by the round fur head (hitbox unchanged)

local hrp = getPart("HumanoidRootPart")
hrp.Transparency = 1

local FUR_LIMBS = {
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"RightUpperArm",
	"RightLowerArm",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"RightUpperLeg",
	"RightLowerLeg",
}
local PINK_LIMBS = { "LeftHand", "RightHand", "LeftFoot", "RightFoot" }

for _, inst in character:GetDescendants() do
	if inst:IsA("BasePart") then
		inst.Anchored = false
		inst.Material = Enum.Material.SmoothPlastic
	end
end
for _, name in FUR_LIMBS do
	local p = character:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		p.Color = palette.Fur
	end
end
for _, name in PINK_LIMBS do
	local p = character:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		p.Color = palette.Pink
	end
end
head.Color = palette.Fur

---------------------------------------------------------------------------
-- 3. COSMETIC PARTS
---------------------------------------------------------------------------

local cosmetics = Instance.new("Model")
cosmetics.Name = "HamsterCosmetics"
cosmetics.Parent = character

type Shape = "Ellipsoid" | "Ball" | "Block"

local function addCosmetic(
	name: string,
	attachTo: BasePart,
	shape: Shape,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	opts: { neon: boolean?, shadow: boolean? }?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = if opts and opts.shadow ~= nil then opts.shadow else true
	p.Material = if opts and opts.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth

	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
		p.Size = size
	elseif shape == "Ellipsoid" then
		-- Block + Sphere SpecialMesh = stretched ellipsoid that follows Part.Size.
		p.Shape = Enum.PartType.Block
		p.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	else
		p.Shape = Enum.PartType.Block
		p.Size = size
	end

	p.CFrame = attachTo.CFrame * offset

	local weld = Instance.new("Weld")
	weld.Name = "HamsterWeld"
	weld.Part0 = attachTo
	weld.Part1 = p
	weld.C0 = offset -- explicit offset: independent of where the rig sits
	weld.C1 = CFrame.identity
	weld.Parent = p

	p.Parent = cosmetics
	return p
end

local upperTorso = getPart("UpperTorso")
local rad = math.rad
type CosmeticOpts = { neon: boolean?, shadow: boolean? }
local NO_SHADOW: CosmeticOpts = { shadow = false }

-- Front of an R15 rig = -Z. Offsets below are tuned for default (scale 1.0)
-- R15 parts: UpperTorso 2 x 1.6 x 1, Head ~1.2. Head-fur is 2.3 x 2.0 x 2.0.

-- Body: one chubby ellipsoid over both torso parts (arms poke out = stubby paws)
addCosmetic("FurBody", upperTorso, "Ellipsoid", Vector3.new(2.9, 3.0, 2.3), CFrame.new(0, -0.45, 0.05), palette.Fur)
addCosmetic("FurBelly", upperTorso, "Ellipsoid", Vector3.new(2.0, 2.3, 0.9), CFrame.new(0, -0.5, -0.82), palette.Belly)
addCosmetic("Tail", upperTorso, "Ball", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -1.05, 1.2), palette.Tail)

-- Head
addCosmetic("FurHead", head, "Ellipsoid", Vector3.new(2.3, 2.0, 2.0), CFrame.new(0, 0.1, 0), palette.Fur)

for _, side in { -1, 1 } do
	local sideName = if side < 0 then "L" else "R"

	-- Ears: outer fur disc + pink inner, tilted outward
	local earCf = CFrame.new(0.72 * side, 0.95, 0.1) * CFrame.Angles(0, 0, rad(-20 * side))
	addCosmetic("Ear" .. sideName, head, "Ellipsoid", Vector3.new(0.75, 0.8, 0.3), earCf, palette.EarOuter)
	addCosmetic(
		"EarInner" .. sideName,
		head,
		"Ellipsoid",
		Vector3.new(0.5, 0.55, 0.12),
		earCf * CFrame.new(0, -0.02, -0.12),
		palette.Pink,
		NO_SHADOW
	)

	-- Puffy cheek pouches
	addCosmetic(
		"Cheek" .. sideName,
		head,
		"Ellipsoid",
		Vector3.new(0.95, 0.8, 0.85),
		CFrame.new(0.68 * side, -0.32, -0.55),
		palette.Belly
	)

	-- Eyes (big, glossy) + highlight dot
	addCosmetic(
		"Eye" .. sideName,
		head,
		"Ball",
		Vector3.new(0.42, 0.42, 0.42),
		CFrame.new(0.45 * side, 0.2, -0.85),
		palette.Eye,
		NO_SHADOW
	)
	addCosmetic(
		"EyeShine" .. sideName,
		head,
		"Ball",
		Vector3.new(0.14, 0.14, 0.14),
		CFrame.new(0.45 * side + 0.08, 0.3, -1.03),
		palette.Highlight,
		{ neon = true, shadow = false }
	)

	-- Buck teeth
	addCosmetic(
		"Tooth" .. sideName,
		head,
		"Block",
		Vector3.new(0.11, 0.16, 0.05),
		CFrame.new(0.06 * side, -0.38, -0.9),
		palette.Teeth,
		NO_SHADOW
	)
end

addCosmetic("Nose", head, "Ball", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, -0.12, -0.98), palette.Pink, NO_SHADOW)

---------------------------------------------------------------------------
-- 4. ATTACHMENTS FOR VFX / CARRY (names are a contract with UI/Systems)
---------------------------------------------------------------------------

local function addAttachment(name: string, parent: BasePart, pos: Vector3)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = parent
end

addAttachment("StatusFxAttachment", head, Vector3.new(0, 1.6, 0)) -- above the ears
addAttachment("PoofAttachment", upperTorso, Vector3.new(0, -0.45, 0)) -- body centre
addAttachment("CarryAttachment", upperTorso, Vector3.new(0, -0.3, -1.45)) -- hugged in front

---------------------------------------------------------------------------
-- 5. INSTALL AS StarterCharacter (idempotent)
---------------------------------------------------------------------------

local existing = StarterPlayer:FindFirstChild("StarterCharacter")
if existing then
	if existing:GetAttribute(BUILDER_ATTR) == true then
		existing:Destroy()
	else
		existing.Name = "StarterCharacter_Backup_" .. tostring(os.time())
		warn(TAG, "Kept the old StarterCharacter as", existing.Name)
	end
end

character.Name = "StarterCharacter"
character:SetAttribute(BUILDER_ATTR, true)
character:SetAttribute("FurVariant", FUR_VARIANT)
local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
humanoid.DisplayName = ""
humanoid.BreakJointsOnDeath = false -- GDD 5.2 (server also sets it)
character.PrimaryPart = hrp
character:PivotTo(CFrame.new(0, 3, 0))
character.Parent = StarterPlayer

StarterPlayer.LoadCharacterAppearance = false

---------------------------------------------------------------------------
-- 6. OPTIONAL PREVIEW IN WORKSPACE
---------------------------------------------------------------------------

local oldPreview = workspace:FindFirstChild("HamsterPreview")
if oldPreview and oldPreview:GetAttribute(BUILDER_ATTR) == true then
	oldPreview:Destroy()
end
if SPAWN_PREVIEW then
	local preview = character:Clone()
	preview.Name = "HamsterPreview"
	for _, inst in preview:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = true
		elseif inst:IsA("LocalScript") or inst:IsA("Script") then
			inst:Destroy()
		end
	end
	preview:PivotTo(CFrame.new(PREVIEW_POSITION))
	preview.Parent = workspace
end

pcall(function()
	ChangeHistoryService:SetWaypoint("BuildHamster: after")
end)

print(
	string.format(
		"%s Done. StarterPlayer.StarterCharacter = %s hamster (%d cosmetic parts). Press Play to test.",
		TAG,
		FUR_VARIANT,
		#cosmetics:GetChildren()
	)
)
