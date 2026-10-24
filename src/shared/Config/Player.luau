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

	-- Stun ("dizzy") after a falling-object hit that does not down the player
	STUN_DURATION = 1.5, -- s; a re-hit refreshes the timer (no stacking)
	STUN_WALK_SPEED = 4, -- WalkSpeed while stunned (no jump)

	-- Dash (Q / ButtonB / on-screen button). Server owns the cooldown.
	DASH_COOLDOWN = 30, -- s
	DASH_DISTANCE = 20, -- studs (approx., horizontal)
	DASH_TIME = 0.25, -- s the burst lasts
	DASH_MAX_FORCE = 60000, -- LinearVelocity horizontal force cap (walls still stop the dash)
	DASH_COOLDOWN_GRACE = 0.5, -- s of clock-skew tolerance on the server cooldown check
})
