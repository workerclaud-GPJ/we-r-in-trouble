--!strict
--[[
	RoundState — server writer for ReplicatedStorage.RoundState attributes and the
	per-match Objectives folder (docs/ARCHITECTURE.md §3–4).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local Attr = Contract.Attr

local RoundState = {}

local folder: Folder = (function(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Contract.Folder.RoundState)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = Contract.Folder.RoundState
	f.Parent = ReplicatedStorage
	return f
end)()

-- Attributes cleared between matches (everything except lobby counters).
local MATCH_ATTRS = {
	Attr.MatchStartedAt, Attr.MatchEndsAt, Attr.StageStartedAt, Attr.DisasterId, Attr.DisasterName,
	Attr.DisasterHint, Attr.MissionName, Attr.StepName, Attr.StepOpenedAt, Attr.CarrierArrivesAt,
	Attr.CarrierArrivedAt, Attr.DepartureEndsAt, Attr.DepartureRemaining, Attr.ResultWin, Attr.ResultReason,
	Attr.ResultTime, Attr.ResultDisaster, Attr.ResultEscaped,
}

function RoundState.set(name: string, value: any)
	if folder:GetAttribute(name) ~= value then
		folder:SetAttribute(name, value)
	end
end

function RoundState.get(name: string): any
	return folder:GetAttribute(name)
end

function RoundState.objectivesFolder(): Folder
	local existing = folder:FindFirstChild(Contract.Folder.Objectives)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = Contract.Folder.Objectives
	f.Parent = folder
	return f
end

-- Resets every match attribute to its idle value and removes objective configs.
function RoundState.clearMatch()
	for _, name in MATCH_ATTRS do
		folder:SetAttribute(name, nil)
	end
	RoundState.set(Attr.Stage, Contract.Stage.Calm)
	RoundState.set(Attr.StepIndex, 0)
	RoundState.set(Attr.StepCount, 0)
	RoundState.set(Attr.LastChance, false)
	RoundState.set(Attr.ExitOpen, false)
	RoundState.set(Attr.CarrierArrived, false)
	RoundState.set(Attr.DepartureRunning, false)
	RoundState.set(Attr.ZoneCount, 0)
	RoundState.set(Attr.ZoneNeeded, 0)
	RoundState.set(Attr.LastCall, false)
	local objectives = folder:FindFirstChild(Contract.Folder.Objectives)
	if objectives then
		objectives:ClearAllChildren()
	end
end

RoundState.set(Attr.Phase, Contract.Phase.Lobby)
RoundState.set(Attr.MatchId, 0)
RoundState.clearMatch()

return RoundState
