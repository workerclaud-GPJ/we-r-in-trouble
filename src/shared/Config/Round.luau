--!strict
-- Round flow tunables (GDD §2, §9, §8.6 Deadline overrides).
return table.freeze({
	MAX_PLAYERS = 4,
	MIN_PLAYERS_TO_START = 2, -- Boss decision: no solo start on live
	-- Studio override: ServerStorage attribute Config.Debug.DEV_MIN_PLAYERS_ATTR (number), Studio only.
	INTERMISSION_TIME = 30,
	BRIEFING_TIME = 5,
	RESULT_TIME = 15,
	WIN_CINEMATIC_TIME = 3,
	MATCH_HARD_LIMIT = 420, -- 7:00 Collapse
	LAST_CHANCE_WARNING_AT = 320, -- 5:20
	MATCH_TICK = 0.25, -- match loop (departure, win/lose, KillY, bleed-out)

	LOBBY_OFFSET_X = 3000,
	LOBBY_Y = 0,
	LOBBY_SIZE = 60,
	LOBBY_WALL_HEIGHT = 40,
	LOBBY_RELOAD_DELAY = 2,
	LOBBY_AFK_AFTER = 60,
	ACTIVITY_MOVE_THRESHOLD = 2,
	ACTIVITY_SAMPLE_INTERVAL = 1,
	ACTIVITY_PING_CLIENT_INTERVAL = 10,
	ACTIVITY_PING_SERVER_MIN_INTERVAL = 5,

	DISASTER_NO_REPEAT = true,
	MISSION_ID = "MidnightKitchen_CallForHelp",
	NEW_MISSION_ID = "MidnightKitchen_CallForHelp_Capability", -- fallback when SCENARIO_IDS is empty
	-- Features.NewMission: escape scenarios, one per match (equal odds, no repeat twice in a row)
	SCENARIO_IDS = {
		"MidnightKitchen_CallForHelp_Capability", -- 1: batteries + wheel + radios -> rescue carrier
		"MidnightKitchen_CableWindow", -- 2: cable bridge up to the counter, scissors pry the window
		"MidnightKitchen_Drain", -- 3: scissors pry the drain grate, cable down the drain
	},
})
