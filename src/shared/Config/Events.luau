--!strict
--[[ Random events (Lead 24 Oct): 1–2 per match, only during Active, independent of the disaster.
	Server-authoritative (EventService); clients draw them from the WorldEvent remote.
	  FridgeBurst (IceLane): ice cubes slide down a lane (EventLane marker by the fridge, else a
	    lane through a random standing player); 2 s floor telegraph; hit = 15 dmg + knockback.
	  SpilledOil (OilPatch): slippery floor patch near a random standing player for 20 s:
	    SpeedMult x1.35 inside and the client keeps you moving (no stopping).
]]
local Types = require(script.Parent.Parent.Types)

local DEFS: { [string]: Types.EventDef } = {
	FridgeBurst = {
		id = "FridgeBurst",
		kind = "IceLane",
		displayName = "FRIDGE BURST OPEN!",
		warningText = "Ice cubes incoming! Get out of the blue lane!",
		telegraph = 2,
		duration = 1.6, -- slide time over the lane
		damage = 15,
		knockback = 55,
		knockbackUp = 30,
		width = 8,
		length = 70, -- fallback lane only
		count = 6,
		cubeSize = 3,
	},
	SpilledOil = {
		id = "SpilledOil",
		kind = "OilPatch",
		displayName = "SPILLED OIL!",
		warningText = "Slippery floor! Once you start moving you can't stop!",
		telegraph = 2,
		duration = 20,
		radius = 14,
		speedMult = 1.35,
	},
}

return table.freeze({
	DEFS = table.freeze(DEFS),
	ORDER = table.freeze({ "FridgeBurst", "SpilledOil" }),
	STAGE = "Active", -- events are scheduled when this stage starts and cancelled when it ends
	PER_MATCH_MIN = 1,
	PER_MATCH_MAX = 2,
	FIRST_AT = 20, -- earliest s into the stage
	LAST_AT = 140, -- latest s into the stage (Active lasts 165 s)
	MIN_GAP = 35, -- s between two events
	BANNER_TIME = 3,
	TICK = 0.1, -- server hit / zone check interval
	HIT_DY = 4, -- max |feet - lane/patch floor| to count as inside
	FLOOR_RAY_START = 6,
	FLOOR_RAY_LENGTH = 20,
	PLACE_MIN_DIST = 3, -- oil patch centre offset from the targeted player
	PLACE_MAX_DIST = 8,
	PLACE_ATTEMPTS = 6,
})
