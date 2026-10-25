--!strict
-- Interaction / item / MultiHold tunables (GDD §3.3–3.4, §5.6–5.7, §9).
return table.freeze({
	INTERACT_RANGE = 8,
	INTERACT_SERVER_RANGE = 10,
	HOLD_TICK = 0.1,
	SMALL_CARRY_SPEED_MULT = 0.9,
	MEDIUM_CARRY_SPEED_MULT = 0.75, -- ItemDef.size = "Medium" (e.g. Scissors)
	ITEM_KILLY_RESPAWN_DELAY = 3,
	ITEM_DROP_RAY_DISTANCE = 4,
	ITEM_TOSS_SPEED = 5, -- ItemPhysics drop: forward speed (studs/s) of the released item
	ITEM_TOSS_UP = 3, -- ...and its small upward pop
	ITEM_HINT_RADIUS = 30,
	MULTIHOLD_ASSIST_AFTER = 75,
	MULTIHOLD_ASSIST_MIN = 2,
	REPAIR_CREDIT_THRESHOLD = 0.25,

	-- Features.ItemPhysics (lying items are unanchored, server-owned physics objects)
	ITEM_PHYSICS_MAX = 20, -- more lying items than this stay anchored (perf cap)
	ITEM_DEFAULT_DENSITY = 1,
	ITEM_DEFAULT_FRICTION = 0.5,
	ITEM_DEFAULT_ELASTICITY = 0.1,
	ITEM_STUCK_CHECK_INTERVAL = 1, -- s between out-of-bounds / inside-geometry checks
	ITEM_STUCK_CONFIRM = 2, -- consecutive failed checks before returning the item to its origin
	ITEM_BOUNDS_MARGIN = 10, -- studs outside the map bounding box (X/Z/top) = out of bounds
	ITEM_SHAKE_MIN_INTERVAL = 1.5, -- s between Earthquake nudges (rate limit)
	ITEM_SHAKE_CHANCE = 0.6, -- per lying item per nudge
	ITEM_SHAKE_SPEED_MIN = 2, -- horizontal studs/s added per nudge (x shake intensity / 0.35, capped x2)
	ITEM_SHAKE_SPEED_MAX = 5,
	ITEM_SHAKE_UP = 1.5, -- small hop so items unstick from the surface
	ITEM_SHAKE_KICKS_MAX = 3, -- nudges per shake pulse (spread over its duration)
})
