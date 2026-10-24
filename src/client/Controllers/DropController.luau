--!strict
--[[
	DropController — put the held item down: G (keyboard), ButtonX (gamepad), or the on-screen
	UI.Widgets.DropButton (touch + mouse) which calls DropController.request().
	The server (ItemService, Remote DropItem) re-checks state and places the item in front.
	Swapping is done by the item's own prompt ("Swap" while holding, PromptController).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Remotes = require(Shared.Remotes)

local Attr = Contract.Attr
local ACTION = "WRIT_DropItem"
local COOLDOWN = 0.3

local DropController = {}

local lastSent = 0

function DropController.isHolding(): boolean
	local h = Players.LocalPlayer:GetAttribute(Attr.Holding)
	return typeof(h) == "string" and h ~= ""
end

function DropController.request(): boolean
	local t = os.clock()
	if t - lastSent < COOLDOWN or not DropController.isHolding() then
		return false
	end
	if Players.LocalPlayer:GetAttribute(Attr.State) ~= Contract.State.Standing then
		return false
	end
	lastSent = t
	Remotes.get("DropItem"):FireServer()
	return true
end

function DropController.start()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin and DropController.isHolding() then
			DropController.request()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonX)
end

return DropController
