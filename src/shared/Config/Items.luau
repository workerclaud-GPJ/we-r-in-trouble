--!strict
-- ItemDefs (GDD §3.6). Theme content.
-- capabilities: "Power" | "Cut" | "Span" | "Pry" | "Contain" | "Rope" (Deliver `capability`, Config/Loot).
-- density / friction / elasticity: CustomPhysicalProperties while lying (Features.ItemPhysics).
-- Models: ReplicatedStorage.Assets.Items.<model> (Battery: tools/BuildProps; others: tools/BuildItemAssets).
-- Hamster scale: AA battery 2.5 × 0.7 × 0.7.
local Types = require(script.Parent.Parent.Types)

local ITEMS: { [string]: Types.ItemDef } = {
	Battery = {
		id = "Battery",
		displayName = "Battery",
		size = "Small",
		model = "Battery",
		capabilities = { "Power" },
		density = 2.5, -- metal can, heavy for its size
		friction = 0.4,
		elasticity = 0.05,
	},
	ChargerCable = {
		id = "ChargerCable",
		displayName = "Charger Cable",
		size = "Small",
		model = "ChargerCable",
		capabilities = { "Power", "Rope" },
		density = 1.2, -- coiled rubber cable
		friction = 0.8,
		elasticity = 0.1,
	},
	Scissors = {
		id = "Scissors",
		displayName = "Scissors",
		size = "Medium",
		model = "Scissors",
		capabilities = { "Cut", "Pry" },
		density = 3, -- steel blades
		friction = 0.35,
		elasticity = 0.05,
	},
	Bottlecap = {
		id = "Bottlecap",
		displayName = "Bottle Cap",
		size = "Small",
		model = "Bottlecap",
		capabilities = { "Contain" },
		density = 0.9, -- plastic
		friction = 0.5,
		elasticity = 0.3,
	},
}

for _, def in ITEMS do
	table.freeze(def.capabilities)
	table.freeze(def)
end

return table.freeze(ITEMS)
