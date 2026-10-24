--!strict
-- ItemDefs (GDD §3.6). Theme content.
local Types = require(script.Parent.Parent.Types)

local ITEMS: { [string]: Types.ItemDef } = {
	Battery = { id = "Battery", displayName = "Battery", size = "Small", model = "Battery" },
}

return table.freeze(ITEMS)
