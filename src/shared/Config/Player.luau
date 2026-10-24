--!strict
-- Player tunables (GDD §5, §9, §8.6 Deadline overrides: flat 15s respawn, no sprint).
return table.freeze({
	MAX_HP = 100,
	SPAWN_PROTECTION = 3,
	WALK_SPEED = 16,
	MIN_MOVE_SPEED = 6,
	JUMP_HEIGHT = 7.2,
	DOWNED_CRAWL_SPEED = 5,
	BLEED_OUT_TIME = 30,
	REVIVE_HOLD = 4,
	REVIVE_PROMPT_RANGE = 7,
	REVIVED_HP = 40,
	REVIVE_PROTECTION = 2,
	RESPAWN_BASE = 15,
	RESPAWN_STEP = 0,
	RESPAWN_MAX = 15,
	TEAM_WIPE_RULE = "AllDowned", -- "AllDowned" | "NoneStanding"
	SPAWN_HEIGHT_OFFSET = 3,
	POOF_DELAY = 0.4, -- character kept this long after Eliminated so clients can play "Poof" -- studs above spawn part top
})
