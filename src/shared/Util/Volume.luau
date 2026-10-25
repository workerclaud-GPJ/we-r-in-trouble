--!strict
--[[
	Volume — shared RisingVolume surface formula (server VolumeService publishes the attributes
	on the volume Part; HazardFxController + BoatController + BoatService read them).
	surfaceY = BaseY + level, level = linear RiseFrom -> RiseTo over RiseStartedAt..RiseEndsAt.
]]

local Workspace = game:GetService("Workspace")

local Contract = require(script.Parent.Parent.Contract)

local Attr = Contract.Attr

local Volume = {}

local function num(inst: Instance, name: string): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

function Volume.surfaceY(part: BasePart): number
	local from, to = num(part, Attr.RiseFrom), num(part, Attr.RiseTo)
	local s, e = num(part, Attr.RiseStartedAt), num(part, Attr.RiseEndsAt)
	local level = to
	if e > s then
		level = from + (to - from) * math.clamp((Workspace:GetServerTimeNow() - s) / (e - s), 0, 1)
	end
	return num(part, Attr.BaseY) + level
end

-- X/Z footprint test (the volume part's box, any height)
function Volume.over(part: BasePart, pos: Vector3): boolean
	local lp = part.CFrame:PointToObjectSpace(pos)
	return math.abs(lp.X) <= part.Size.X / 2 and math.abs(lp.Z) <= part.Size.Z / 2
end

return Volume
