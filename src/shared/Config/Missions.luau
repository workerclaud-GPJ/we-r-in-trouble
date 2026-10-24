--!strict
-- MissionDefs (GDD §8.4 Deadline mission). Theme content.
local Types = require(script.Parent.Parent.Types)

local MISSIONS: { [string]: Types.MissionDef } = {
	MidnightKitchen_CallForHelp = {
		id = "MidnightKitchen_CallForHelp",
		mapId = "MidnightKitchen",
		displayName = "Call for Help",
		disasters = { "Earthquake" }, -- add "Flood" here if the stretch ships
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

return table.freeze(MISSIONS)
