--!strict
-- Global StageDefs (GDD §4.1). DisasterDef.stageOverrides may override `duration`.
-- Critical has no duration: it lasts until Collapse (Round.MATCH_HARD_LIMIT).
export type StageDef = {
	duration: number?,
	lightingPreset: string,
	audioPreset: string,
	uiColor: string, -- Style.Color key
}

local DEFS: { [string]: StageDef } = {
	Calm = { duration = 30, lightingPreset = "Calm", audioPreset = "Calm", uiColor = "Good" },
	Warning = { duration = 15, lightingPreset = "Warning", audioPreset = "Warning", uiColor = "Warn" },
	Active = { duration = 165, lightingPreset = "Active", audioPreset = "Active", uiColor = "Hot" },
	Critical = { duration = nil, lightingPreset = "Critical", audioPreset = "Critical", uiColor = "Bad" },
}

return table.freeze({
	ORDER = table.freeze({ "Calm", "Warning", "Active", "Critical" }),
	DEFS = table.freeze(DEFS),
	WARNING_BANNER_MIN = 3,
})
