--!strict
-- Lobby cosmetics (no saving). Player attributes `FurColor` / `Hat` (ARCHITECTURE §5).
-- Fur parts follow tools/BuildHamster.luau names. Hats are built from simple Parts
-- welded to `Head` (offsets relative to Head; FurHead top ≈ Head + 1.1).

export type FurPalette = {
	Fur: Color3, -- Head, FurHead, FurBody, torso + arm/leg parts
	Belly: Color3, -- FurBelly, CheekL/R
	EarOuter: Color3, -- EarL/R
	Tail: Color3,
	Limb: Color3?, -- optional override for arms/legs (Panda)
}

export type HatShape = "Block" | "Ball" | "Ellipsoid" | "CylinderY"
export type HatPart = {
	shape: HatShape,
	size: Vector3, -- for CylinderY: (height, diameter, diameter) like a Roblox cylinder before rotation
	offset: CFrame, -- relative to Head
	color: Color3,
	material: Enum.Material?,
}

local rgb = Color3.fromRGB
local rad = math.rad

local FUR_ORDER = { "Golden", "WinterWhite", "Chocolate", "Panda" }

local FUR: { [string]: FurPalette } = {
	Golden = {
		Fur = rgb(226, 158, 84),
		Belly = rgb(255, 240, 214),
		EarOuter = rgb(200, 128, 66),
		Tail = rgb(240, 196, 140),
	},
	WinterWhite = {
		Fur = rgb(176, 180, 196),
		Belly = rgb(250, 250, 255),
		EarOuter = rgb(120, 124, 142),
		Tail = rgb(236, 238, 246),
	},
	Chocolate = {
		Fur = rgb(122, 74, 44),
		Belly = rgb(222, 192, 160),
		EarOuter = rgb(88, 52, 30),
		Tail = rgb(150, 100, 64),
	},
	Panda = {
		Fur = rgb(245, 245, 245),
		Belly = rgb(255, 255, 255),
		EarOuter = rgb(30, 30, 34),
		Tail = rgb(245, 245, 245),
		Limb = rgb(36, 36, 40),
	},
}

local HAT_ORDER = { "None", "PartyHat", "Bow", "ChefHat", "Headphones" }

local HATS: { [string]: { HatPart } } = {
	None = {},
	PartyHat = {
		{ shape = "CylinderY", size = Vector3.new(0.4, 1.1, 1.1), offset = CFrame.new(0, 1.2, 0), color = rgb(255, 90, 150) },
		{ shape = "CylinderY", size = Vector3.new(0.4, 0.78, 0.78), offset = CFrame.new(0, 1.58, 0), color = rgb(90, 200, 255) },
		{ shape = "CylinderY", size = Vector3.new(0.4, 0.46, 0.46), offset = CFrame.new(0, 1.96, 0), color = rgb(255, 214, 72) },
		{ shape = "Ball", size = Vector3.new(0.38, 0.38, 0.38), offset = CFrame.new(0, 2.3, 0), color = rgb(255, 255, 255) },
	},
	Bow = {
		{
			shape = "Ellipsoid",
			size = Vector3.new(0.7, 0.55, 0.3),
			offset = CFrame.new(-0.42, 1.12, -0.35) * CFrame.Angles(0, 0, rad(15)),
			color = rgb(255, 80, 120),
		},
		{
			shape = "Ellipsoid",
			size = Vector3.new(0.7, 0.55, 0.3),
			offset = CFrame.new(0.42, 1.12, -0.35) * CFrame.Angles(0, 0, rad(-15)),
			color = rgb(255, 80, 120),
		},
		{ shape = "Ball", size = Vector3.new(0.32, 0.32, 0.32), offset = CFrame.new(0, 1.12, -0.38), color = rgb(255, 160, 190) },
	},
	ChefHat = {
		{ shape = "CylinderY", size = Vector3.new(0.5, 1.5, 1.5), offset = CFrame.new(0, 1.2, 0), color = rgb(250, 250, 250) },
		{ shape = "Ellipsoid", size = Vector3.new(1.9, 1.1, 1.9), offset = CFrame.new(0, 1.85, 0), color = rgb(255, 255, 255) },
	},
	Headphones = {
		{ shape = "Block", size = Vector3.new(2.3, 0.2, 0.35), offset = CFrame.new(0, 1.22, 0.1), color = rgb(40, 40, 48) },
		{ shape = "Block", size = Vector3.new(0.2, 0.8, 0.35), offset = CFrame.new(-1.15, 0.85, 0.1), color = rgb(40, 40, 48) },
		{ shape = "Block", size = Vector3.new(0.2, 0.8, 0.35), offset = CFrame.new(1.15, 0.85, 0.1), color = rgb(40, 40, 48) },
		{
			shape = "CylinderY",
			size = Vector3.new(0.35, 0.85, 0.85),
			offset = CFrame.new(-1.18, 0.35, 0.1) * CFrame.Angles(0, 0, rad(90)),
			color = rgb(90, 200, 255),
		},
		{
			shape = "CylinderY",
			size = Vector3.new(0.35, 0.85, 0.85),
			offset = CFrame.new(1.18, 0.35, 0.1) * CFrame.Angles(0, 0, rad(90)),
			color = rgb(90, 200, 255),
		},
	},
}

return table.freeze({
	DEFAULT_FUR = "Golden",
	DEFAULT_HAT = "None",
	FUR_ORDER = table.freeze(FUR_ORDER),
	HAT_ORDER = table.freeze(HAT_ORDER),
	FUR = table.freeze(FUR),
	HATS = table.freeze(HATS),
	-- Part names (tools/BuildHamster.luau)
	FUR_PARTS = table.freeze({ "Head", "FurHead", "FurBody", "UpperTorso", "LowerTorso" }),
	LIMB_PARTS = table.freeze({
		"LeftUpperArm",
		"LeftLowerArm",
		"RightUpperArm",
		"RightLowerArm",
		"LeftUpperLeg",
		"LeftLowerLeg",
		"RightUpperLeg",
		"RightLowerLeg",
	}),
	BELLY_PARTS = table.freeze({ "FurBelly", "CheekL", "CheekR" }),
	EAR_PARTS = table.freeze({ "EarL", "EarR" }),
	TAIL_PARTS = table.freeze({ "Tail" }),
	COSMETICS_MODEL = "HamsterCosmetics",
	HAT_MODEL = "HamsterHat",
	SET_RATE_PER_SECOND = 8, -- SetCosmetic requests accepted per player per second
})
