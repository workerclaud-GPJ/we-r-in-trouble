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
export type ObjectiveKind = "Repair" | "Deliver" | "MultiHold" | "CableHook"

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
	sustain: boolean?, -- never completes: Progress = power charge (up while someone runs, drains when nobody does)
	-- Deliver
	itemType: string?,
	minCount: number?,
	maxCount: number?,
	capability: string?, -- Features.CapabilitySpawn: accept any item with this capability (alternative to itemType)
	count: number?, -- fixed item count (overrides the team-size clamp when set)
	keepItem: boolean?, -- the held item is a tool: it is not used up (each press counts once, e.g. one screw)
	holdDuration: number?, -- ProximityPrompt hold time (s) per press
	requiresFlag: string?, -- MapService flag needed first (e.g. "ScissorsSharp"); else blockedHint to the presser
	blockedWhileOn: string?, -- Switch Kind that must be OFF (e.g. "Faucet"); else blockedHint
	blockedHint: string?,
	progressBanner: string?, -- banner per press: "{n}" / "{count}" replaced (keepItem multi-press feedback)
	-- MultiHold
	anchorCount: number?,
	mode: string?, -- "Cumulative" (Continuous is post-deadline)
	holdTime: number?,
	assist: boolean?,
	needsPower: string?, -- objective id whose anchors must have power (Repair sustain Progress > 0); ignored when solo
	noPowerHint: string?,
	-- Escape scenarios: MapService.setFlag(setsFlag) when this objective completes
	-- (reveals FlagReveal parts with RevealedBy = flag, e.g. the cable bridge)
	setsFlag: string?,
	-- CableHook: done when a cable route with ReachesCounter = true is hooked (CableThrowService)
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
	-- Escape scenarios (Features.NewMission, Config.Round.SCENARIO_IDS):
	exitKind: string?, -- nil = rescue carrier (default); "Window" | "Drain" = direct exit, no carrier
	exitId: string?, -- ExitZone attr ExitId to use (zones without ExitId count as "Window"); others are untagged
	hideParts: { string }?, -- map parts (names, searched recursively) removed for this scenario
	fixedLoot: { FixedLoot }?, -- items placed on named ScenarioOnly ItemSpawns before the random loot
	winCamera: string?, -- map part whose CFrame replaces WinCameraPoint for this scenario
	startFlag: string?, -- MapService flag set before players spawn (e.g. "TableStart": spawn on the table)
	cableThrow: boolean?, -- CableThrowService: Rope items can be cast at the map's cable hooks
	explore: boolean?, -- HUD hides steps / markers / hints: players find the way out themselves (item book: B)
	switchesOn: { string }?, -- Switch Kinds turned on at match start (e.g. the drain round's running faucet)
	loot: LootTableDef?, -- this scenario's random loot (instead of Config.Loot[mapId]); fixedLoot counts toward budget
}

-- spawn: one ScenarioOnly ItemSpawn name, or a list (one is picked per round from the seed; two
-- fixed items never share a point)
export type FixedLoot = { itemType: string, spawn: string | { string } }

export type ItemSize = "Small" | "Medium"

-- Capabilities: "Power" | "Cut" | "Span" | "Pry" | "Contain" | "Rope"
export type ItemDef = {
	id: string,
	displayName: string,
	size: ItemSize, -- "Small" | "Medium" (Medium: slower carry; Heavy is post-deadline)
	model: string?, -- asset name under Assets
	capabilities: { string },
	-- Features.ItemPhysics: CustomPhysicalProperties (nil = Config.Interaction defaults)
	density: number?,
	friction: number?,
	elasticity: number?,
}

-- Config/Loot (Features.CapabilitySpawn)
export type LootEntry = { itemType: string, weight: number }
export type LootTableDef = {
	budget: number, -- total items spawned per round (raised if requirements need more)
	entries: { LootEntry },
}

return {}
