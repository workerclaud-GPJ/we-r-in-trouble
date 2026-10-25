--!strict
--[[
	PolishMap.luau — small material upgrades on ServerStorage.Maps.MidnightKitchen (idempotent:
	sets absolute values by part name; colours and sizes are never touched, Ctrl+Z undoes it).
	Run in Studio EDIT mode after the build tools:  require(game.ServerStorage.Tools.PolishMap)
]]

local ServerStorage = game:GetService("ServerStorage")

local map = ServerStorage:FindFirstChild("Maps") and (ServerStorage :: any).Maps:FindFirstChild("MidnightKitchen")
if not map then
	warn("[PolishMap] map not found")
	return true
end

-- name → { material, reflectance? }
local RULES: { [string]: { any } } = {
	-- padded ironing-board cover
	Board = { Enum.Material.Fabric },
	-- brushed tin bread bin
	BreadBin = { Enum.Material.Metal, 0.05 },
	-- exterior brick wall below / above the window
	Wall_Below = { Enum.Material.Brick },
	Wall_Above = { Enum.Material.Brick },
	-- toy truck: glossy plastic
	Truck_Body = { Enum.Material.Plastic, 0.05 },
	Truck_Cab = { Enum.Material.Plastic, 0.05 },
	Truck_Stripe = { Enum.Material.Plastic },
	-- enamel washing machine: a little shine
	Body = { Enum.Material.SmoothPlastic, 0.06 },
}

local n = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		local rule = RULES[d.Name]
		-- "Board" also names the bread board (wood): only the ironing board gets fabric
		if rule and not (d.Name == "Board" and d.Parent and d.Parent.Name ~= "IroningBoard") then
			d.Material = rule[1]
			if rule[2] then
				d.Reflectance = rule[2]
			end
			n += 1
		elseif d.Material == Enum.Material.Glass and d.Transparency < 1 and d.Reflectance < 0.1 then
			d.Reflectance = 0.15 -- windows / jars catch the moonlight
			n += 1
		end
	end
end
print(`[PolishMap] done: {n} part(s) updated`)
return true
