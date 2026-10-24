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
local TABLE_CABLES = {
	{ itemType = "ChargerCable", spawn = "Scn_Table1" },
	{ itemType = "ChargerCable", spawn = "Scn_Table2" },
}

-- 1) Call for help, table start. Everyone starts on the dining table with two charger cables:
--    cast them to reach the counter (radios) and to climb back up; batteries + wheel on the floor.
--    Batteries only for the charger (a cable is never used up by the socket here).
MISSIONS.MidnightKitchen_CallForHelp_Table = {
	id = "MidnightKitchen_CallForHelp_Table",
	mapId = "MidnightKitchen",
	displayName = "Call for Help",
	disasters = { "Earthquake", "Flood" },
	exitFlag = "WindowOpen",
	exitArrivalDelay = 60,
	exitVehicleAsset = "RescueCarrier",
	startFlag = "TableStart",
	cableThrow = true,
	hideParts = NO_COOKBOOK_RAMP,
	fixedLoot = TABLE_CABLES,
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
	displayName = "Escape: The Window",
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
		{ itemType = "Scissors", spawn = "Scn_CounterW" },
	},
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
	displayName = "Escape: The Drain",
	disasters = { "Earthquake", "Flood" },
	exitFlag = "DrainOpen",
	exitArrivalDelay = 0,
	exitKind = "Drain",
	exitId = "Drain",
	winCamera = "DrainCameraPoint",
	hideParts = NO_COOKBOOK_RAMP,
	fixedLoot = {
		{ itemType = "Scissors", spawn = "Scn_Pantry" },
		{ itemType = "ChargerCable", spawn = "Scn_BackCorner" },
	},
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
