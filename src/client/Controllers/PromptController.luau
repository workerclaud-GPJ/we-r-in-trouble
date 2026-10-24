--!strict
--[[
	PromptController — local-only prompt visibility (docs/ARCHITECTURE.md §6).
	The server owns prompt.Enabled; the client hides a prompt by setting its local
	MaxActivationDistance to 0 and restores the server value otherwise.
	Hidden: own RevivePrompt · PickupPrompt while holding · Deliver socket while not holding ·
	every prompt while not Standing. The server re-validates everything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local Attr = Contract.Attr

local PromptController = {}

local player = Players.LocalPlayer
local baseRange: { [ProximityPrompt]: number } = setmetatable({}, { __mode = "k" }) :: any

local function kindOf(prompt: ProximityPrompt): string?
	local node: Instance? = prompt.Parent
	while node and node ~= Workspace do
		local kind = node:GetAttribute(Attr.Kind)
		if typeof(kind) == "string" then
			return kind
		end
		node = node.Parent
	end
	return nil
end

local function visible(prompt: ProximityPrompt): boolean
	if player:GetAttribute(Attr.State) ~= Contract.State.Standing then
		return false
	end
	local holding = player:GetAttribute(Attr.Holding)
	local isHolding = typeof(holding) == "string" and holding ~= ""
	if prompt.Name == Contract.Name.RevivePrompt then
		local char = player.Character
		return not (char and prompt:IsDescendantOf(char))
	elseif prompt.Name == Contract.Name.PickupPrompt then
		return not isHolding
	elseif kindOf(prompt) == "Deliver" then
		return isHolding
	end
	return true
end

local function refresh(prompt: ProximityPrompt)
	if not prompt.Parent then
		baseRange[prompt] = nil
		return
	end
	local base = baseRange[prompt]
	if not base then
		return
	end
	local target = if visible(prompt) then base else 0
	if prompt.MaxActivationDistance ~= target then
		prompt.MaxActivationDistance = target
	end
end

-- Only game prompts: anything in Workspace.Map, plus RevivePrompts on characters.
-- Ranges come from Config (the server sets the same values), never from a captured property.
local function track(inst: Instance)
	if not inst:IsA("ProximityPrompt") or baseRange[inst] ~= nil then
		return
	end
	if inst.Name == Contract.Name.RevivePrompt then
		baseRange[inst] = Config.Player.REVIVE_PROMPT_RANGE
	else
		local map = Workspace:FindFirstChild(Contract.Folder.Map)
		if not (map and inst:IsDescendantOf(map)) then
			return
		end
		baseRange[inst] = Config.Interaction.INTERACT_RANGE
	end
	refresh(inst)
end

local function refreshAll()
	for prompt in baseRange do
		refresh(prompt)
	end
end

function PromptController.start()
	for _, d in Workspace:GetDescendants() do
		track(d)
	end
	Workspace.DescendantAdded:Connect(track)
	player:GetAttributeChangedSignal(Attr.State):Connect(refreshAll)
	player:GetAttributeChangedSignal(Attr.Holding):Connect(refreshAll)
	player.CharacterAdded:Connect(function()
		task.defer(refreshAll)
	end)
end

return PromptController
