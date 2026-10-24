--!strict
-- Client presentation tuning: match intro cinematic + toppling decor (visual only).

return table.freeze({
	-- Match intro (Phase -> Match). Camera: window -> over the kitchen -> cage.
	INTRO_TIME = 5,
	INTRO_WAIT_FOR_MAP = 1.5, -- s to wait for Workspace.Map markers to replicate, else skip
	INTRO_WINDOW_HEIGHT = 18, -- start camera above the window marker
	INTRO_MID_HEIGHT = 55, -- arc height over the room centre
	INTRO_CAGE_BACK = 34, -- end camera distance back from the cage (towards the window)
	INTRO_CAGE_HEIGHT = 20,
	INTRO_LETTERBOX = 0.12, -- bar height (screen fraction)
	INTRO_FADE = 0.4,
	-- Optional Level overrides: Parts named IntroCamStart / IntroCamEnd anywhere in the map

	-- Toppling props on Big Shake / Critical
	TOPPLE_TAG = "Toppleable",
	TOPPLE_GROUP_ATTR = "ToppleGroup",
	TOPPLE_DECOR_FOLDER = "Decor", -- auto-tag only searches Map.<MapId>.Decor
	-- name prefixes (text before the first "_", digits stripped) that are auto-tagged
	TOPPLE_NAMES = table.freeze({
		"Plate",
		"PlateStack",
		"Cup",
		"Mug",
		"Jar",
		"Kettle",
		"Toaster",
		"Book",
		"WaterBottle",
		"FruitBowl",
		"Bottle",
		"Vase",
		"Can",
		"Bowl",
		"Pot",
		"Glass",
	}),
	TOPPLE_BIG_SHAKE_INTENSITY = 0.95, -- ScreenEffect intensity that counts as Big Shake
	TOPPLE_MAX = 30, -- groups animated per match
	TOPPLE_STAGGER = 1.2, -- random start delay 0..N s
	TOPPLE_RAY = 120, -- downward ray for the landing surface
	TOPPLE_DROP_MIN = 1.5, -- fall at least this far = "drops from shelf", else tilts in place
	TOPPLE_TILT_MIN = 65, -- degrees
	TOPPLE_TILT_MAX = 88,
	TOPPLE_TILT_TIME = 0.7,
	TOPPLE_DUST = 10, -- particles on landing
})
