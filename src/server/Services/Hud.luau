--!strict
-- Hud — server helper for HudBanner (docs/ARCHITECTURE.md §2). Sent to match
-- participants while a match runs, otherwise to everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local PlayerStateService = require(script.Parent.PlayerStateService)

local Hud = {}

function Hud.recipients(): { Player }
	if PlayerStateService.isMatchActive() then
		return PlayerStateService.teamMembers()
	end
	return Players:GetPlayers()
end

function Hud.banner(key: string, text: string, sub: string?, color: string?, duration: number?)
	local payload: Remotes.BannerPayload = { key = key, text = text, sub = sub, color = color, duration = duration }
	local remote = Remotes.get("HudBanner")
	for _, player in Hud.recipients() do
		remote:FireClient(player, payload)
	end
end

-- One player only (hints for the presser: "too blunt", "turn off the tap first", ...).
function Hud.bannerTo(player: Player, key: string, text: string, sub: string?, color: string?, duration: number?)
	local payload: Remotes.BannerPayload = { key = key, text = text, sub = sub, color = color, duration = duration }
	Remotes.get("HudBanner"):FireClient(player, payload)
end

return Hud
