--!strict
--[[
	Shared type definitions for the Deadline contract (see docs/ARCHITECTURE.md).
	Theme content lives in data tables of these shapes (src/shared/Config);
	code never names theme things.
]]

export type Phase = "Lobby" | "Intermission" | "Match" | "Ending" | "Result"
export type StageId = "Calm" | "Warning" | "Active" | "Critical"
export type PlayerState = "Lobby" | "Standing" | "Downed" | "Eliminated" | "Escaped"
export type MoveMode = "Normal" | "Downed" | "Pinned"
export type EndReason = "Escaped" | "Collapse" | "Wipe" | "Abandoned"
export type TeamWipeRule = "AllDowned" | "NoneStanding"
export type ObjectiveKind = "Repair" | "Deliver" | "MultiHold"

-- GDD §4.2 hazard component. One loose shape; DisasterService reads fields by `type`.
export type HazardComponent = {
	type: string, -- "Pulse" | "MoveModifier" | "ScreenEffect" | "TelegraphedImpact"
	-- Pulse
	firstDelay: number?,
	interval: number?,
	duration: number?,
	children: { HazardComponent }?,
	-- MoveModifier
	multiplier: number?,
	-- ScreenEffect
	effect: string?,
	intensity: number?,
	-- TelegraphedImpact
	targeting: string?, -- "NearPlayer" | "RandomPoint"
	rate: number?, -- seconds between waves
	count: (number | string)?, -- number or "HalfStanding" (ceil(standing/2))
	radius: number?,
	damage: number?,
	telegraph: number?,
	lifetime: number?,
	minDist: number?,
	maxDist: number?,
	propCollides: boolean?,
	propPool: { string }?,
}

export type DisasterDef = {
	id: string,
	displayName: string,
	warningText: string,
	stages: { [string]: { HazardComponent } },
	stageOverrides: { [string]: number }?, -- stage id -> duration
	propPool: { string }?,
}

export type ObjectiveDef = {
	id: string,
	kind: ObjectiveKind,
	displayName: string, -- string key, e.g. "obj.run_wheel"
	holdAnim: string?,
	actionText: string?, -- ProximityPrompt ActionText (theme text)
	optional: boolean?,
	-- Repair
	duration: number?,
	maxStack: number?,
	-- Deliver
	itemType: string?,
	minCount: number?,
	maxCount: number?,
	-- MultiHold
	anchorCount: number?,
	mode: string?, -- "Cumulative" (Continuous is post-deadline)
	holdTime: number?,
	assist: boolean?,
}

export type StepDef = {
	id: string,
	displayName: string,
	objectives: { ObjectiveDef },
}

export type MissionDef = {
	id: string,
	mapId: string,
	displayName: string,
	disasters: { string },
	exitFlag: string,
	exitArrivalDelay: number,
	exitVehicleAsset: string?,
	steps: { StepDef },
}

export type ItemDef = {
	id: string,
	displayName: string,
	size: string, -- "Small" (Heavy is post-deadline)
	model: string?, -- asset name under Assets
}

return {}
