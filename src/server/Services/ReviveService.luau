--!strict
--[[
	ReviveService — revive prompt on a downed player's HRP, server-timed hold
	(REVIVE_HOLD s), progress resets to 0 when released, downed player Pinned while
	someone revives (GDD §5.3).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local PlayerStateService = require(script.Parent.PlayerStateService)
local HoldService = require(script.Parent.HoldService)

local Attr = Contract.Attr

type Entry = {
	prompt: ProximityPrompt,
	target: HoldService.HoldTarget,
	progress: number,
	removeTicker: () -> (),
}

local ReviveService = {}

local entries: { [Player]: Entry } = {}

local function clear(player: Player)
	local e = entries[player]
	if not e then
		return
	end
	entries[player] = nil
	e.removeTicker()
	HoldService.unregister(e.target)
	e.prompt:Destroy()
	player:SetAttribute(Attr.ReviveProgress, 0)
	PlayerStateService.setBeingRevived(player, false)
end

local function onDowned(player: Player)
	clear(player)
	local hrp = PlayerStateService.getHRP(player)
	if not hrp then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Contract.Name.RevivePrompt
	prompt.ActionText = "Help up"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Player.REVIVE_PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = hrp

	local entry: Entry
	local target = HoldService.register({
		part = hrp,
		prompt = prompt,
		isOpen = function(): boolean
			return PlayerStateService.getState(player) == Contract.State.Downed
		end,
		canHold = function(reviver: Player): boolean
			return reviver ~= player
		end,
		onChanged = function()
			local e = entries[player]
			if e ~= entry then
				return
			end
			local reviving = #e.target.holders > 0
			if not reviving then
				e.progress = 0 -- released early: progress resets
				player:SetAttribute(Attr.ReviveProgress, 0)
			end
			PlayerStateService.setBeingRevived(player, reviving)
		end,
	})

	entry = {
		prompt = prompt,
		target = target,
		progress = 0,
		removeTicker = HoldService.addTicker(function(dt: number)
			local e = entries[player]
			if e ~= entry or #e.target.holders == 0 then
				return
			end
			e.progress = math.min(1, e.progress + dt / Config.Player.REVIVE_HOLD)
			player:SetAttribute(Attr.ReviveProgress, e.progress)
			if e.progress >= 1 then
				local reviver = e.target.holders[1]
				clear(player)
				PlayerStateService.revive(player, reviver)
			end
		end),
	}
	entries[player] = entry
end

function ReviveService.reset()
	for player in table.clone(entries) do
		clear(player)
	end
end

function ReviveService.start()
	PlayerStateService.Downed:Connect(onDowned)
	PlayerStateService.Eliminated:Connect(clear)
	PlayerStateService.Left:Connect(clear)
	PlayerStateService.Revived:Connect(clear)
end

return ReviveService
