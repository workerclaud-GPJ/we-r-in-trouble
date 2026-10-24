--!strict
--[[
	Contract — every shared name (folders, tags, attributes, enum-like values).
	Mirrors docs/ARCHITECTURE.md. Require this instead of typing strings.
]]

local Contract = {}

Contract.Folder = table.freeze({
	RoundState = "RoundState", -- ReplicatedStorage.RoundState
	Objectives = "Objectives", -- ReplicatedStorage.RoundState.Objectives
	Remotes = "Remotes", -- ReplicatedStorage.Remotes
	Assets = "Assets", -- ReplicatedStorage.Assets / ServerStorage.Assets (optional)
	Maps = "Maps", -- ServerStorage.Maps
	Map = "Map", -- Workspace.Map (per match)
	Runtime = "Runtime", -- Workspace.Map.Runtime
	Lobby = "Lobby", -- Workspace.Lobby
	DebugInvoke = "DebugInvoke", -- ServerStorage.DebugInvoke (BindableFunction)
})

Contract.Tag = table.freeze({
	PlayerSpawn = "PlayerSpawn",
	ObjectiveAnchor = "ObjectiveAnchor",
	ItemSpawn = "ItemSpawn",
	LockedDoor = "LockedDoor",
	ExitZone = "ExitZone",
	ExitVehicleSpot = "ExitVehicleSpot",
	NoImpact = "NoImpact",
	NoBlockingProp = "NoBlockingProp",
	LobbySpawn = "LobbySpawn",
	Item = "Item",
	ExitVehicle = "ExitVehicle",
	Toppleable = "Toppleable", -- decor that topples on Big Shake (client visual; Level or auto-tag)
	VolumeLevel = "VolumeLevel", -- Part, attr Level (0 = volume reference height + X/Z footprint)
	EventLane = "EventLane", -- Part, attr EventId: lane band for IceLane events (LookVector = slide dir)
	RisingVolume = "RisingVolume", -- runtime: the volume (water) Part in Map.Runtime (server creates)
	RouteTopple = "RouteTopple", -- Model (PrimaryPart + FallenPose): server topples it into a new walkable route
})

Contract.Name = table.freeze({
	PromptPart = "PromptPart",
	WinCameraPoint = "WinCameraPoint",
	ObjectivePrompt = "ObjectivePrompt",
	PickupPrompt = "PickupPrompt",
	RevivePrompt = "RevivePrompt",
	DropArea = "DropArea", -- optional Part in the map: X/Z area + bottom Y for RandomPoint impacts
	Lights = "Lights", -- Folder in the map root
	RescueLightRed = "RescueLight_Red",
	RescueLightBlue = "RescueLight_Blue",
	Moonlight = "Moonlight",
	VolumeSource = "VolumeSource", -- optional Part in the map: where the water comes from (hose spray FX)
	RisingVolume = "RisingVolume", -- runtime water Part name
	FallenPose = "FallenPose", -- CFrameValue (or Model: its pivot) inside a RouteTopple model = final pivot
})

Contract.CollisionGroup = table.freeze({
	Players = "Players",
	Items = "Items", -- Features.ItemPhysics: lying items (collide with world, not with Players)
})

-- Attribute names (RoundState / objective / player / map)
Contract.Attr = table.freeze({
	-- RoundState
	Phase = "Phase",
	PhaseEndsAt = "PhaseEndsAt",
	PlayersReady = "PlayersReady",
	PlayersNeeded = "PlayersNeeded",
	MaxPlayers = "MaxPlayers",
	MatchId = "MatchId",
	MatchStartedAt = "MatchStartedAt",
	MatchEndsAt = "MatchEndsAt",
	Stage = "Stage",
	StageStartedAt = "StageStartedAt",
	DisasterId = "DisasterId",
	DisasterName = "DisasterName",
	DisasterHint = "DisasterHint",
	MissionName = "MissionName",
	StepIndex = "StepIndex",
	StepCount = "StepCount",
	StepName = "StepName",
	StepOpenedAt = "StepOpenedAt",
	LastChance = "LastChance",
	ExitOpen = "ExitOpen",
	CarrierArrivesAt = "CarrierArrivesAt",
	CarrierArrived = "CarrierArrived",
	CarrierArrivedAt = "CarrierArrivedAt",
	DepartureRunning = "DepartureRunning",
	DepartureEndsAt = "DepartureEndsAt",
	DepartureRemaining = "DepartureRemaining",
	ZoneCount = "ZoneCount",
	ZoneNeeded = "ZoneNeeded",
	LastCall = "LastCall",
	ResultWin = "ResultWin",
	ResultReason = "ResultReason",
	ResultTime = "ResultTime",
	ResultDisaster = "ResultDisaster",
	ResultEscaped = "ResultEscaped",

	-- Objective (Configuration + anchor)
	DisplayName = "DisplayName",
	Kind = "Kind",
	Step = "Step",
	Order = "Order",
	Optional = "Optional",
	Active = "Active",
	Done = "Done",
	Progress = "Progress",
	Held = "Held",
	Required = "Required",
	BaseRequired = "BaseRequired",
	Override = "Override",
	Occupied = "Occupied",
	Delivered = "Delivered",
	Count = "Count",

	-- Player
	State = "State",
	HP = "HP",
	MaxHP = "MaxHP",
	SpeedMult = "SpeedMult",
	MoveMode = "MoveMode",
	Inactive = "Inactive",
	Holding = "Holding",
	ProtectedUntil = "ProtectedUntil",
	BleedOutEndsAt = "BleedOutEndsAt",
	ReviveProgress = "ReviveProgress",
	RespawnAt = "RespawnAt",
	ReviveCount = "ReviveCount",
	DownedCount = "DownedCount",
	Credits = "Credits",
	Breath = "Breath", -- 0..100 while a RisingVolume runs (nil otherwise)
	FurColor = "FurColor", -- lobby cosmetic (Config.Cosmetics.FUR_ORDER)
	Hat = "Hat", -- lobby cosmetic (Config.Cosmetics.HAT_ORDER)
	Stunned = "Stunned", -- true while dizzy after a falling-object hit (server, PlayerStateService.stun)
	DashAt = "DashAt", -- server time of the last accepted dash (drives the dash pose on all clients)
	DashReadyAt = "DashReadyAt", -- server time the next dash is allowed (cooldown UI)
	-- Character (server sets, HoldService): procedural hold animation
	AnimState = "AnimState", -- Config.Animation.HOLD_ANIMS key, e.g. "RunInWheel" (nil = none)
	AnimStandCF = "AnimStandCF", -- CFrame the holder is pinned to (HRP), e.g. inside the wheel
	-- ProximityPrompt (server sets, HoldService): every stand-point slot is taken
	SlotsFull = "SlotsFull",

	-- Map markup (Level sets)
	Priority = "Priority",
	EnabledBy = "EnabledBy",
	ObjectiveId = "ObjectiveId",
	Part = "Part",
	ItemType = "ItemType",
	Zone = "Zone",
	SizeClass = "SizeClass", -- ItemSpawn: "Small" (default) | "Medium" (largest item size that fits)
	Fallback = "Fallback", -- ItemSpawn: true = guaranteed point for CapabilitySpawn force-spawns
	UnlockedBy = "UnlockedBy",
	KillY = "KillY",
	-- Map markup (server sets)
	Open = "Open",
	Unlocked = "Unlocked",
	Carrier = "Carrier",
	DescendStartedAt = "DescendStartedAt",
	DescendEndsAt = "DescendEndsAt",
	DescendHeight = "DescendHeight",
	-- Volumes / events
	Level = "Level", -- VolumeLevel marker
	EventId = "EventId", -- EventLane marker
	BaseY = "BaseY", -- RisingVolume part: world Y of Level 0
	RiseFrom = "RiseFrom", -- RisingVolume part: level (studs above BaseY) at RiseStartedAt
	RiseTo = "RiseTo",
	RiseStartedAt = "RiseStartedAt",
	RiseEndsAt = "RiseEndsAt",
	SurfaceY = "SurfaceY", -- RisingVolume part: world Y the surface is rising to (BaseY + RiseTo)
	-- RouteTopple model (Level sets TopplesOn; server sets the rest)
	TopplesOn = "TopplesOn", -- string: comma list of disaster ids, e.g. "Earthquake,Flood"
	ToppleWarning = "ToppleWarning", -- true while it creaks/wobbles before the fall
	ToppleFallAt = "ToppleFallAt", -- server time the fall starts (clients animate from it)
	ToppleFallTime = "ToppleFallTime", -- s the fall takes
	ToppleLanded = "ToppleLanded", -- true once it lies in its FallenPose (dust + thud on clients)
})

Contract.Phase = table.freeze({
	Lobby = "Lobby",
	Intermission = "Intermission",
	Match = "Match",
	Ending = "Ending",
	Result = "Result",
})

Contract.State = table.freeze({
	Lobby = "Lobby",
	Standing = "Standing",
	Downed = "Downed",
	Eliminated = "Eliminated",
	Escaped = "Escaped",
})

Contract.MoveMode = table.freeze({
	Normal = "Normal",
	Downed = "Downed",
	Pinned = "Pinned",
})

Contract.Stage = table.freeze({
	Calm = "Calm",
	Warning = "Warning",
	Active = "Active",
	Critical = "Critical",
})

Contract.Reason = table.freeze({
	Escaped = "Escaped",
	Collapse = "Collapse",
	Wipe = "Wipe",
	Abandoned = "Abandoned",
})

return table.freeze(Contract)
