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

return table.freeze(MISSIONS)
