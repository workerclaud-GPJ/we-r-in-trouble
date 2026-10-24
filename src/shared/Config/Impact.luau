--!strict
-- TelegraphedImpact rules (GDD §4.2 floor-aware rules, §8.6.1 Big Shake, §9).
return table.freeze({
	FLOOR_RAY_START = 6, -- ray origin above target foot
	FLOOR_RAY_LENGTH = 20,
	MAX_FLOOR_DY = 4, -- landing floor vs target floor
	MAX_HIT_DY = 6, -- player foot vs landing point
	REROLL_ATTEMPTS = 5,
	DROP_HEIGHT = 30, -- visual drop start height
	RANDOM_POINT_RAY_TOP = 120, -- RandomPoint ray origin above map floor
	NO_IMPACT_SPAWN_RADIUS = 6,
	BIG_SHAKE_DURATION = 4,
	BIG_SHAKE_DAMAGE = 15,
})
