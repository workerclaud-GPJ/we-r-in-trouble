--!strict
--[[
	Remotes — the single declaration point for every RemoteEvent (CONVENTIONS.md).
	The server creates ReplicatedStorage.Remotes.<Name> at boot; clients wait for them.

	Payloads (validated by the receiver; see docs/ARCHITECTURE.md §2):
	  ActivityPing  C->S  ()                                   Lobby AFK refresh
	  Dash          C->S  ()                                   dash request (server checks state + cooldown)
	  DebugCommand  C->S  (text: string)                       Studio / dev allowlist only
	  HudBanner     S->C  { key, text, sub?, color?, duration? }
	  Impact        S->C  { position: Vector3, radius, telegraph, damage, prop: string?, dropHeight, lifetime }
	  ScreenEffect  S->C  { effect: "Shake", intensity: number, duration: number }
	  PlayerHit     S->C  { userId: number, amount: number, position: Vector3 }
	  SetCosmetic   C->S  (kind: "FurColor" | "Hat", id: string)  Lobby only, validated vs Config.Cosmetics
	  WorldEvent    S->C  { kind = "IceLane" | "OilPatch" | "Knockback", ... } (see WorldEventPayload)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Contract = require(script.Parent.Contract)

export type RemoteName = "ActivityPing" | "Dash" | "DebugCommand" | "DropItem" | "CastCable" | "HudBanner" | "Impact" | "ScreenEffect" | "PlayerHit" | "SetCosmetic" | "WorldEvent"

export type BannerPayload = {
	key: string,
	text: string,
	sub: string?,
	color: string?,
	duration: number?,
}

export type ImpactPayload = {
	position: Vector3,
	radius: number,
	telegraph: number,
	damage: number,
	prop: string?,
	dropHeight: number,
	lifetime: number,
}

export type ScreenEffectPayload = {
	effect: string,
	intensity: number,
	duration: number,
}

export type PlayerHitPayload = {
	userId: number,
	amount: number,
	position: Vector3,
}

-- Random events (Config/Events) + knockback. Fields per kind:
--   IceLane   cframe (lane start on the floor, LookVector = slide dir), length, width, count,
--             telegraph, duration (slide time), startsAt (server time the telegraph began)
--   OilPatch  position (floor point), radius, telegraph, duration, startsAt
--   Knockback velocity (sent only to the hit player; client owns its character physics)
export type WorldEventPayload = {
	kind: string,
	id: string?,
	cframe: CFrame?,
	position: Vector3?,
	length: number?,
	width: number?,
	radius: number?,
	count: number?,
	telegraph: number?,
	duration: number?,
	startsAt: number?,
	velocity: Vector3?,
}

local NAMES: { RemoteName } = { "ActivityPing", "Dash", "DebugCommand", "DropItem", "CastCable", "HudBanner", "Impact", "ScreenEffect", "PlayerHit", "SetCosmetic", "WorldEvent" }

local Remotes = {}
Remotes.NAMES = NAMES

local function folder(): Instance
	local existing = ReplicatedStorage:FindFirstChild(Contract.Folder.Remotes)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local f = Instance.new("Folder")
		f.Name = Contract.Folder.Remotes
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild(Contract.Folder.Remotes)
end

-- Server: creates every remote (call once at boot).
function Remotes.createAll()
	assert(RunService:IsServer(), "Remotes.createAll is server-only")
	local f = folder()
	for _, name in NAMES do
		if not f:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = f
		end
	end
end

-- Both sides: returns the RemoteEvent (client yields until it replicates).
function Remotes.get(name: RemoteName): RemoteEvent
	local f = folder()
	local remote = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(remote and remote:IsA("RemoteEvent"), "Remote missing: " .. name)
	return remote
end

return Remotes
