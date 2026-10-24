--!strict
--[[
	RouteTopple tunables (Config.Features.RouteTopple). Server: RouteToppleService.
	Client: RouteToppleController. Map pieces: ServerStorage/Tools/AddRouteTopples.lua.
	Timeline per round: when the disaster reaches Active, 1..MAX_PER_ROUND eligible pieces are
	picked with a per-round seed; the first starts FIRST_DELAY s into Active, the next one
	STAGGER_MIN..STAGGER_MAX s later. Per piece: WARNING_TIME creak/wobble -> FALL_TIME fall
	(ease-in) -> snap to FallenPose + damage players inside the landed piece.
]]
return table.freeze({
	MAX_PER_ROUND = 2,
	FIRST_DELAY = 12, -- s after Active starts (Active lasts 165 s)
	STAGGER_MIN = 5,
	STAGGER_MAX = 9,
	WARNING_TIME = 3,
	FALL_TIME = 1.2,
	DAMAGE = 20, -- (Big Shake hits for 15) -- standing player inside the landed piece (+ stun if still standing)
	-- landing hit test, in each collider's local space (HRP position):
	HIT_PADDING = 1, -- studs added on the board's sides/ends
	HIT_BELOW = 6, -- studs under the board's underside (hamster ~5.5 tall standing under it)
	HIT_ABOVE = 3, -- studs over its top surface
	-- client visuals
	WOBBLE_DEG = 2.5, -- max wobble angle about the hinge during the warning
	WOBBLE_HZ = 5,
	DUST = 14, -- particles per dust puff on landing
	CREAK_SOUND = "RopeCreak", -- Config.Audio name (id 0 = silent until filled)
	LAND_SOUND = "CarrierLand",
})
