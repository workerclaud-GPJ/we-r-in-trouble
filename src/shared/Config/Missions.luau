--!strict
-- MissionDefs (GDD §8.4 Deadline mission). Theme content.
local Types = require(script.Parent.Parent.Types)

local MISSIONS: { [string]: Types.MissionDef } = {
	MidnightKitchen_CallForHelp = {
		id = "MidnightKitchen_CallForHelp",
		mapId = "MidnightKitchen",
		displayName = "Call for Help",
		disasters = { "Earthquake", "Flood" }, -- one random per match, no repeat twice in a row
		exitFlag = "WindowOpen",
		exitArrivalDelay = 60,
		exitVehicleAsset = "RescueCarrier",
		steps = {
			{
				id = "PowerUp",
				displayName = "Power up the charger",
				objectives = {
					{ id = "RunWheel", kind = "Repair", displayName = "obj.run_wheel", holdAnim = "RunInWheel", actionText = "Run", duration = 45, maxStack = 2 },
					{ id = "DeliverBatteries", kind = "Deliver", displayName = "obj.deliver_batteries", actionText = "Insert", itemType = "Battery", minCount = 1, maxCount = 3 },
				},
			},
			{
				id = "CallForHelp",
				displayName = "Call for help",
				objectives = {
					{ id = "CallForHelp", kind = "MultiHold", displayName = "obj.call_for_help", holdAnim = "ShoutRadio", actionText = "Shout", anchorCount = 4, mode = "Cumulative", holdTime = 45, assist = true },
				},
			},
		},
	},
}

-- Features.NewMission (default off): capability variant of the same mission. RoundService uses it
-- instead of Round.MISSION_ID when the switch is on (needs Features.CapabilitySpawn for the
-- capability Deliver to spawn mixed loot; without it Deliver falls back to spawning `itemType`).
MISSIONS.MidnightKitchen_CallForHelp_Capability = {
	id = "MidnightKitchen_CallForHelp_Capability",
	mapId = "MidnightKitchen",
	displayName = "Call for Help",
	disasters = { "Earthquake", "Flood" },
	exitFlag = "WindowOpen",
	exitArrivalDelay = 60,
	exitVehicleAsset = "RescueCarrier",
	steps = {
		{
			id = "PowerUp",
			displayName = "Power up the charger",
			objectives = {
				{ id = "RunWheel", kind = "Repair", displayName = "obj.run_wheel", holdAnim = "RunInWheel", actionText = "Run", duration = 45, maxStack = 2 },
				-- same anchor (ObjectiveId DeliverBatteries); any Power item counts (Battery or ChargerCable)
				{ id = "DeliverBatteries", kind = "Deliver", displayName = "obj.deliver_batteries", actionText = "Insert", capability = "Power", itemType = "Battery", minCount = 1, maxCount = 3 },
			},
		},
		{
			id = "CallForHelp",
			displayName = "Call for help",
			objectives = {
				{ id = "CallForHelp", kind = "MultiHold", displayName = "obj.call_for_help", holdAnim = "ShoutRadio", actionText = "Shout", anchorCount = 4, mode = "Cumulative", holdTime = 45, assist = true },
			},
		},
	},
}


-- Escape scenarios (Features.NewMission + Features.CapabilitySpawn, Config.Round.SCENARIO_IDS).
-- Map markup: tools/AddEscapeScenarios.luau (anchors, ScenarioOnly ItemSpawns, cable routes, drain).
-- The cookbook ramp (stack -> counter) is gone in every scenario: the counter is reached by
-- casting the charger cable at a hook (CableThrowService) or, in an Earthquake, a toppled board.
local NO_COOKBOOK_RAMP = { "Ramp2_Cookbooks_Collider", "Ramp2_Cookbooks_Visual" }
-- Items decide the exit: each scenario only spawns its own key items (fixedLoot) plus items that
-- do not belong to another exit, so the items you find tell you which way out this round is.
-- Bottlecaps are clutter for now (future: the bottle-cap raft escape).
local CLUTTER = { { itemType = "Bottlecap", weight = 1 } }
-- Key items hide in a random spot each round (tools/AddEscapeScenarios.luau Scn_* points).
-- Reachability: table-start rounds put cables on the table or the floor (never the counter: the
-- counter needs a cable first); the drain round (cage start) uses floor spots only.
local CABLE_SPOTS_TABLE = { "Scn_Table1", "Scn_Table2", "Scn_TableFruit", "Scn_TableEdge", "Scn_UnderTable2", "Scn_UnderChair", "Scn_BehindCurtain" }
local FLOOR_SPOTS = { "Scn_Pantry", "Scn_BackCorner", "Scn_UnderTable2", "Scn_UnderChair", "Scn_BehindCurtain", "Scn_ShoeRack", "Scn_CageTray" }
local COUNTER_OR_FLOOR = { "Scn_CounterW", "Scn_CounterE", "Scn_SinkSide", "Scn_ShoeRack", "Scn_Pantry", "Scn_BackCorner" }
local TABLE_CABLES = {
	{ itemType = "ChargerCable", spawn = CABLE_SPOTS_TABLE },
	{ itemType = "ChargerCable", spawn = CABLE_SPOTS_TABLE },
}

-- 1) Call for help, table start. Everyone starts on the dining table with two charger cables:
--    cast them to reach the counter (radios) and to climb back up; batteries + wheel on the floor.
--    Batteries only for the charger (a cable is never used up by the socket here).
MISSIONS.MidnightKitchen_CallForHelp_Table = {
	id = "MidnightKitchen_CallForHelp_Table",
	mapId = "MidnightKitchen",
	displayName = "Escape the kitchen!",
	explore = true,
	disasters = { "Earthquake", "Flood" },
	exitFlag = "WindowOpen",
	exitArrivalDelay = 60,
	exitVehicleAsset = "RescueCarrier",
	startFlag = "TableStart",
	cableThrow = true,
	hideParts = NO_COOKBOOK_RAMP,
	fixedLoot = TABLE_CABLES,
	-- 2 cables (fixed) + batteries (requirement, max team 3 + 1 spare) + clutter = 8
	loot = { budget = 8, entries = { { itemType = "Battery", weight = 1 }, { itemType = "Bottlecap", weight = 1 } } },
	steps = {
		{
			id = "PowerUp",
			displayName = "Power up the charger",
			objectives = {
				{ id = "RunWheel", kind = "Repair", displayName = "obj.run_wheel", holdAnim = "RunInWheel", actionText = "Run", duration = 45, maxStack = 2 },
				{ id = "DeliverBatteries", kind = "Deliver", displayName = "obj.deliver_batteries", actionText = "Insert", itemType = "Battery", minCount = 1, maxCount = 3 },
			},
		},
		{
			id = "CallForHelp",
			displayName = "Call for help",
			objectives = {
				{ id = "CallForHelp", kind = "MultiHold", displayName = "obj.call_for_help", holdAnim = "ShoutRadio", actionText = "Shout", anchorCount = 4, mode = "Cumulative", holdTime = 45, assist = true },
			},
		},
	},
}

-- 2) Window. Start on the table, cast a cable to the counter, take the scissors, pry the window
--    latch, push the window open together and jump out.
MISSIONS.MidnightKitchen_CableWindow = {
	id = "MidnightKitchen_CableWindow",
	mapId = "MidnightKitchen",
	displayName = "Escape the kitchen!",
	explore = true,
	disasters = { "Earthquake", "Flood" },
	exitFlag = "WindowOpen",
	exitArrivalDelay = 0,
	exitKind = "Window",
	exitId = "Window",
	startFlag = "TableStart",
	cableThrow = true,
	hideParts = NO_COOKBOOK_RAMP,
	fixedLoot = {
		TABLE_CABLES[1],
		TABLE_CABLES[2],
		{ itemType = "Scissors", spawn = COUNTER_OR_FLOOR },
	},
	loot = { budget = 6, entries = CLUTTER }, -- 2 cables + scissors + 3 bottlecaps
	steps = {
		{
			id = "CableBridge",
			displayName = "Cast the cable to the counter",
			objectives = {
				{ id = "CableToCounter", kind = "CableHook", displayName = "obj.cable_counter" },
			},
		},
		{
			id = "PryWindow",
			displayName = "Pry the window latch",
			objectives = {
				{ id = "PryLatch", kind = "Deliver", displayName = "obj.pry_latch", actionText = "Pry", capability = "Pry", itemType = "Scissors", count = 1, setsFlag = "LatchOpen" },
			},
		},
		{
			id = "PushWindow",
			displayName = "Push the window open",
			objectives = {
				{ id = "PushWindow", kind = "MultiHold", displayName = "obj.push_window", actionText = "Push", anchorCount = 2, mode = "Cumulative", holdTime = 12, assist = true },
			},
		},
	},
}

-- 3) Drain. Start in the cage (floor). Scissors pry the drain grate under the step chair, lift it
--    together, tie the charger cable to the drain and climb down into the pipe. No casting here:
--    the only cable is needed for the drain.
MISSIONS.MidnightKitchen_Drain = {
	id = "MidnightKitchen_Drain",
	mapId = "MidnightKitchen",
	displayName = "Escape the kitchen!",
	explore = true,
	disasters = { "Earthquake", "Flood" },
	exitFlag = "DrainOpen",
	exitArrivalDelay = 0,
	exitKind = "Drain",
	exitId = "Drain",
	winCamera = "DrainCameraPoint",
	hideParts = NO_COOKBOOK_RAMP,
	fixedLoot = {
		{ itemType = "Scissors", spawn = FLOOR_SPOTS },
		{ itemType = "ChargerCable", spawn = FLOOR_SPOTS },
	},
	loot = { budget = 5, entries = CLUTTER }, -- scissors + cable + 3 bottlecaps
	steps = {
		{
			id = "PryGrate",
			displayName = "Pry the drain grate",
			objectives = {
				{ id = "PryGrate", kind = "Deliver", displayName = "obj.pry_grate", actionText = "Pry", capability = "Pry", itemType = "Scissors", count = 1, setsFlag = "GrateLoose" },
			},
		},
		{
			id = "LiftGrate",
			displayName = "Lift the grate together",
			objectives = {
				{ id = "LiftGrate", kind = "MultiHold", displayName = "obj.lift_grate", actionText = "Lift", anchorCount = 2, mode = "Cumulative", holdTime = 10, assist = true },
			},
		},
		{
			id = "TieCable",
			displayName = "Tie the cable to the drain",
			objectives = {
				{ id = "TieDrainCable", kind = "Deliver", displayName = "obj.tie_cable", actionText = "Tie cable", capability = "Rope", itemType = "ChargerCable", count = 1 },
			},
		},
	},
}

return table.freeze(MISSIONS)
