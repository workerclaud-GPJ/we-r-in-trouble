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
	-- RisingVolume: level steps run when the stage starts (levels in studs above Level 0)
	steps: { VolumeStep }?,
}

export type VolumeStep = {
	delay: number, -- s after the stage starts
	level: number, -- target level (studs above the VolumeLevel 0 marker), clamped to maxLevel
	riseTime: number, -- s to reach it (linear) from wherever the surface is
}

-- GDD §4.2 RisingVolume + Slowed / Submerged status effects (theme-free: "volume", not "water").
export type VolumeDef = {
	maxLevel: number,
	tick: number, -- server check interval (s)
	wadeDepth: number, -- surface >= feet + wadeDepth -> Slowed
	wadeSpeedMult: number,
	headHeight: number, -- head top above feet when the character has no Head part
	breathMax: number,
	breathDrain: number, -- per s while the head is under the surface
	breathRefill: number, -- per s above the surface
	drownDamage: number, -- per drownInterval once Breath = 0
	drownInterval: number,
	spawnSafeDepth: number, -- spawn pads with surface >= top + this are skipped by respawn
	enableFlag: string?, -- MapService flag set while the volume runs (enables high-ground PlayerSpawns)
	color: Color3,
	transparency: number,
	underwaterTint: Color3,
	underwaterBlur: number,
}

-- Random events (Config/Events), independent of the disaster.
export type EventDef = {
	id: string,
	kind: string, -- "IceLane" | "OilPatch"
	displayName: string,
	warningText: string,
	telegraph: number,
	duration: number, -- IceLane: slide time; OilPatch: how long the patch stays
	-- IceLane
	damage: number?,
	knockback: number?, -- horizontal speed (studs/s)
	knockbackUp: number?,
	width: number?,
	length: number?, -- fallback lane length (no EventLane marker)
	count: number?,
	cubeSize: number?,
	-- OilPatch
	radius: number?,
	speedMult: number?,
}

export type DisasterDef = {
	id: string,
	displayName: string,
	warningText: string,
	stages: { [string]: { HazardComponent } },
	stageOverrides: { [string]: number }?, -- stage id -> duration
	propPool: { string }?,
	volume: VolumeDef?, -- RisingVolume settings (only disasters that use RisingVolume)
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
