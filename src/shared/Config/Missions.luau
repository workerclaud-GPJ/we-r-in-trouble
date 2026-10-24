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
-- Map markup: tools/AddEscapeScenarios.luau (anchors, ScenarioOnly ItemSpawns, cable bridge, drain).

-- 2) Cable bridge -> window. The cookbook ramp is gone (books fell): hang the charger cable from
--    the cookbook stack to the counter, climb up, pry the window latch with scissors, push it open
--    together and jump out. Earthquake: the toppled boards are a second way up.
MISSIONS.MidnightKitchen_CableWindow = {
	id = "MidnightKitchen_CableWindow",
	mapId = "MidnightKitchen",
	displayName = "Escape: The Window",
	disasters = { "Earthquake", "Flood" },
	exitFlag = "WindowOpen",
	exitArrivalDelay = 0,
	exitKind = "Window",
	exitId = "Window",
	hideParts = { "Ramp2_Cookbooks_Collider", "Ramp2_Cookbooks_Visual" },
	fixedLoot = {
		{ itemType = "ChargerCable", spawn = "Scn_UnderTable" },
		{ itemType = "Scissors", spawn = "Scn_CounterW" },
	},
	steps = {
		{
			id = "CableBridge",
			displayName = "Build a cable bridge",
			objectives = {
				{ id = "HangCable", kind = "Deliver", displayName = "obj.hang_cable", actionText = "Hang cable", capability = "Rope", itemType = "ChargerCable", count = 1, setsFlag = "CableBridge" },
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

-- 3) Drain. Scissors pry the drain grate under the step chair, lift it together, tie the charger
--    cable to the drain and climb down into the pipe that leads outside.
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
