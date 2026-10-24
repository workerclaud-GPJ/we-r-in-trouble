--!strict
--[[
	Server entry point: creates remotes, then starts services in dependency order.
	See docs/ARCHITECTURE.md §8.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

Remotes.createAll()

local Services = script.Parent:WaitForChild("Services")
local MapService = require(Services.MapService)
local PlayerStateService = require(Services.PlayerStateService)
local HoldService = require(Services.HoldService)
local ReviveService = require(Services.ReviveService)
local ItemService = require(Services.ItemService)
local DebugCommands = require(Services.DebugCommands)
local CosmeticsService = require(Services.CosmeticsService)
local RoundService = require(Services.RoundService)
local DashService = require(Services.DashService)
local RouteToppleService = require(Services.RouteToppleService)
local CableThrowService = require(Services.CableThrowService)

MapService.ensureLobby()
HoldService.start()
ReviveService.start()
ItemService.start()
CosmeticsService.start() -- before PlayerStateService so lobby characters get fur/hat
PlayerStateService.start() -- connects PlayerAdded last so every listener above is ready
DebugCommands.start()
DashService.start()
RouteToppleService.start() -- boot check only; no-op while Config.Features.RouteTopple is false
CableThrowService.start()
RoundService.start()
