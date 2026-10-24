--!strict
-- Debug command access (GDD §8.6). Commands work only in Studio or for these UserIds.
return table.freeze({
	ENABLE_IN_STUDIO = true,
	DEV_USER_IDS = table.freeze({} :: { number }), -- add the Boss's UserId here if live debugging is needed
	CHAT_PREFIX = "/dbg",
	-- Studio-only switches, set as attributes on ServerStorage (ignored on live):
	DEV_MIN_PLAYERS_ATTR = "DevMinPlayers", -- number: overrides MIN_PLAYERS_TO_START (e.g. 1 for solo automation)
	DEV_NO_HAZARDS_ATTR = "DevNoHazards", -- bool: stages tick for the HUD but no hazards/damage run
	MAX_PER_SECOND = 5,
	MAX_LENGTH = 64,
})
