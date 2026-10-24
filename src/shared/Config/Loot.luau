--!strict
--[[
	Loot tables per map (Features.CapabilitySpawn, ServerScriptService.Server.Services.LootService).
	At round start: for every capability a Deliver objective requires, spawn count + 1 items that
	have it (weighted among those items), then fill up to `budget` with weighted random items.
	Placement: ItemSpawn points (any ItemType attribute), max one item per Zone where possible,
	SizeClass "Medium" points take any item, "Small" points (default) only Small items.
	Keep budget <= Interaction.ITEM_PHYSICS_MAX (20) and <= the number of ItemSpawn points.
]]
local Types = require(script.Parent.Parent.Types)

local LOOT: { [string]: Types.LootTableDef } = {
	MidnightKitchen = {
		budget = 8,
		entries = {
			{ itemType = "Battery", weight = 4 },
			{ itemType = "ChargerCable", weight = 2 },
			{ itemType = "Scissors", weight = 1 },
			{ itemType = "Bottlecap", weight = 3 },
		},
	},
}

for _, def in LOOT do
	for _, e in def.entries do
		table.freeze(e)
	end
	table.freeze(def.entries)
	table.freeze(def)
end

return table.freeze(LOOT)
