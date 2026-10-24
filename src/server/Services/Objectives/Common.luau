--!strict
--[[
	Objectives/Common — shared objective plumbing: the context every objective kind
	receives, prompt setup on anchors, and attribute mirroring (Configuration + anchors).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local PlayerStateService = require(script.Parent.Parent.PlayerStateService)

export type Context = {
	def: Types.ObjectiveDef,
	anchors: { Model },
	config: Configuration,
	set: (name: string, value: any) -> (), -- mirror attribute on config + every anchor
	setAnchor: (anchor: Model, name: string, value: any) -> (),
	isActive: () -> boolean, -- step open and not done
	stepOpenedAt: () -> number, -- server time
	complete: () -> (), -- mark done (idempotent); MissionService advances the step
	credit: (player: Player) -> (), -- +1 Credits once per objective
}

export type Objective = {
	open: () -> (), -- step opened
	update: (dt: number) -> (), -- match tick (refresh counts/attributes)
	forceComplete: () -> (), -- debug skipStep
	destroy: () -> (),
	toggleDummy: ((letter: string) -> boolean)?, -- MultiHold only
}

local Common = {}

function Common.promptPart(anchor: Model): BasePart?
	local part = anchor:FindFirstChild(Contract.Name.PromptPart, true)
	if part and part:IsA("BasePart") then
		return part
	end
	return anchor.PrimaryPart or anchor:FindFirstChildWhichIsA("BasePart", true)
end

-- Reuses a Level-placed ProximityPrompt in PromptPart or creates one; Deadline settings.
function Common.ensurePrompt(anchor: Model, actionText: string, objectText: string?): (ProximityPrompt?, BasePart?)
	local part = Common.promptPart(anchor)
	if not part then
		warn(`[Mission] anchor {anchor:GetFullName()} has no PromptPart`)
		return nil, nil
	end
	local existing = part:FindFirstChildWhichIsA("ProximityPrompt")
	local prompt: ProximityPrompt
	if existing then
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = Contract.Name.ObjectivePrompt
		prompt.RequiresLineOfSight = false -- PromptParts often sit inside props
		prompt.Parent = part
	end
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Interaction.INTERACT_RANGE
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.Enabled = false
	return prompt, part
end

-- Server-side checks shared by every press/hold (GDD 5.6).
function Common.canInteract(player: Player, part: BasePart): boolean
	if not PlayerStateService.isParticipant(player) or not PlayerStateService.isStanding(player) then
		return false
	end
	local hrp = PlayerStateService.getHRP(player)
	return hrp ~= nil and (hrp.Position - part.Position).Magnitude <= Config.Interaction.INTERACT_SERVER_RANGE
end

return Common
