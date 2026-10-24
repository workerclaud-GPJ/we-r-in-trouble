--!strict
--[[
	Feature switches for the 25 Oct build (item system plan, phase 0).
	Every new system checks its switch at round start. Default OFF: a switch is turned on
	only after it passes the stability checklist (4 players, 30 min, no red errors,
	old phone >= 30 FPS). Turning a switch off must restore the previous behaviour exactly.
]]
return table.freeze({
	RouteTopple = false, -- tagged scenery topples during disasters into a pre-authored, walkable pose
	ItemPhysics = false, -- dropped items are unanchored physics objects (custom material, KillY kept)
	CapabilitySpawn = false, -- items spawn by capability with a guaranteed-solvable per-round seed
	NewMission = false, -- capability-based mission step (needs the Boss's mission design)
})
