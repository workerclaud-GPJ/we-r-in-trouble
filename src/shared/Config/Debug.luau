--!strict
-- Debug command access (GDD §8.6). Commands work only in Studio or for these UserIds.
-- Live safety (server-checked): DebugCommands.allowed() needs RunService:IsStudio() or an
-- allowlisted UserId on EVERY call; DevMinPlayers / DevNoHazards are read only inside
-- RunService:IsStudio() branches (RoundService.playersNeeded, DisasterService.start), so on
-- live they are ignored even if the attributes exist. Keep DEV_USER_IDS empty for release.
return table.freeze({
	ENABLE_IN_STUDIO = true,
	DEV_USER_IDS = table.freeze({} :: { number }), -- add the Boss's UserId here if live debugging is needed
	CHAT_PREFIX = "/dbg",
	CHAT_ENABLED_ATTR = "DebugEnabled", -- bool on the TextChatCommand: false on live (command is a silent no-op)
	-- Studio-only switches, set as attributes on ServerStorage (ignored on live):
	DEV_MIN_PLAYERS_ATTR = "DevMinPlayers", -- number: overrides MIN_PLAYERS_TO_START (e.g. 1 for solo automation)
	DEV_NO_HAZARDS_ATTR = "DevNoHazards", -- bool: stages tick for the HUD but no hazards/damage run
	MAX_PER_SECOND = 5,
	MAX_LENGTH = 64,
})
