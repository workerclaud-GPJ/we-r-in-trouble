--!strict
-- Geometry helpers shared by server and client.

local Geometry = {}

-- True if `point` is inside the oriented box of `part` (cylinders/balls approximated as boxes).
function Geometry.pointInPart(point: Vector3, part: BasePart, padding: number?): boolean
	local localPos = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.one * (padding or 0)
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

function Geometry.horizontalDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Foot Y of an R15 character from its HumanoidRootPart.
function Geometry.footY(hrp: BasePart, humanoid: Humanoid?): number
	local hip = if humanoid then humanoid.HipHeight else 2
	return hrp.Position.Y - hrp.Size.Y / 2 - hip
end

return Geometry
