--!strict
--[[
	DashService — server-authoritative dash cooldown.
	Client (DashController) predicts the burst locally (it owns its character physics) and
	fires Remotes.Dash. The server checks state + cooldown and, if accepted, sets
	  Player.DashAt      = server time (all clients play the dash pose + trail)
	  Player.DashReadyAt = DashAt + DASH_COOLDOWN (cooldown UI)
	Refused: not Lobby/Standing, MoveMode ~= Normal, Stunned, in a hold, cooldown running.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerStateService = require(script.Parent.PlayerStateService)
local HoldService = require(script.Parent.HoldService)

local Attr = Contract.Attr
local P = Config.Player

local DashService = {}

function DashService.canDash(player: Player): boolean
	local state = PlayerStateService.getState(player)
	if state ~= Contract.State.Standing and state ~= Contract.State.Lobby then
		return false
	end
	local mode = player:GetAttribute(Attr.MoveMode)
	if mode ~= nil and mode ~= Contract.MoveMode.Normal then
		return false
	end
	if PlayerStateService.isStunned(player) or HoldService.isHolding(player) or not PlayerStateService.getHRP(player) then
		return false
	end
	local readyAt = player:GetAttribute(Attr.DashReadyAt)
	if typeof(readyAt) == "number" and Workspace:GetServerTimeNow() < readyAt - P.DASH_COOLDOWN_GRACE then
		return false
	end
	return true
end

local function onDash(player: Player)
	if not DashService.canDash(player) then
		return
	end
	local t = Workspace:GetServerTimeNow()
	player:SetAttribute(Attr.DashReadyAt, t + P.DASH_COOLDOWN)
	player:SetAttribute(Attr.DashAt, t)
end

function DashService.start()
	Remotes.get("Dash").OnServerEvent:Connect(onDash)
	Players.PlayerAdded:Connect(function(player: Player)
		player:SetAttribute(Attr.DashReadyAt, 0)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(Attr.DashReadyAt, 0)
	end
end

return DashService
