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
})

Contract.CollisionGroup = table.freeze({
	Players = "Players",
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

	-- Map markup (Level sets)
	Priority = "Priority",
	EnabledBy = "EnabledBy",
	ObjectiveId = "ObjectiveId",
	Part = "Part",
	ItemType = "ItemType",
	Zone = "Zone",
	UnlockedBy = "UnlockedBy",
	KillY = "KillY",
	-- Map markup (server sets)
	Open = "Open",
	Unlocked = "Unlocked",
	Carrier = "Carrier",
	DescendStartedAt = "DescendStartedAt",
	DescendEndsAt = "DescendEndsAt",
	DescendHeight = "DescendHeight",
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
