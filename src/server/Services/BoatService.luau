--!strict
--[[
	BoatService — bottle-cap boat (Features.NewMission rounds with a Flood).
	A standing participant HOLDING a Bottlecap whose spot is flooded at least RIDE_DEPTH deep
	rides it: player attribute Boating = true + SpeedMult x SPEED (faster than walking).
	Clients (BoatController) keep the rider on the water surface (local platform) and draw the
	boat for every rider; while riding the head is above water, so no wading slow and no
	breath loss. Stops when the water gets shallow (< STOP_DEPTH), the cap is dropped/used or
	the player is not Standing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Volume = require(Shared.Util.Volume)
local Geometry = require(Shared.Util.Geometry)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local Attr = Contract.Attr

local BOAT_ITEM = "Bottlecap"
local RIDE_DEPTH = 1.2 -- water over the ground under you (studs) to start riding (= wading depth)
local STOP_DEPTH = 0.7
local MAX_ABOVE = 4 -- feet more than this above the surface (on a counter) = not riding
local SPEED = 1.7
local SPEED_KEY = "Boat"
local TICK = 0.2

local BoatService = {}

local riding: { [Player]: boolean } = {}

local function volumePart(): BasePart?
	for _, inst in MapService.tagged(Contract.Tag.RisingVolume) do
		if inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

-- running faucet streams (Switch model Kind "Faucet", parts named StreamZone): top = surface
local function streamZones(): { BasePart }
	local out: { BasePart } = {}
	local now = workspace:GetServerTimeNow()
	for _, inst in MapService.tagged("Switch") do
		local u = inst:GetAttribute("ActiveUntil")
		if inst:GetAttribute("Kind") == "Faucet" and typeof(u) == "number" and u > now then
			for _, d in inst:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "StreamZone" then
					table.insert(out, d)
				end
			end
		end
	end
	return out
end

-- surface Y of water under `pos` (flood or stream), or nil
local function waterSurface(part: BasePart?, pos: Vector3): number?
	local best: number? = nil
	if part and Volume.over(part, pos) then
		best = Volume.surfaceY(part)
	end
	for _, z in streamZones() do
		if Volume.over(z, pos) then
			local top = z.Position.Y + z.Size.Y / 2
			if best == nil or top > best then
				best = top
			end
		end
	end
	return best
end

local function setRiding(player: Player, on: boolean)
	if (riding[player] == true) == on then
		return
	end
	riding[player] = if on then true else nil
	player:SetAttribute("Boating", if on then true else nil)
	PlayerStateService.setPlayerSpeedModifier(player, SPEED_KEY, if on then SPEED else nil)
	if on then
		Remotes.get("HudBanner"):FireClient(player, {
			key = "BannerBoat",
			text = "Bottle-cap boat! 🛶",
			sub = "Sail across the flood — faster than wading",
			color = "Good",
			duration = 2.5,
		})
	end
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function groundY(pos: Vector3, exclude: { Instance }): number?
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(pos, Vector3.new(0, -60, 0), params)
	return hit and hit.Position.Y
end

local function step()
	local part = volumePart()
	if not Config.Features.NewMission then
		return
	end
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local runtime = MapService.getRuntime()
	if runtime then
		table.insert(exclude, runtime)
	end
	for _, player in Players:GetPlayers() do
		local on = false
		local hrp = PlayerStateService.getHRP(player)
		local surface = hrp and waterSurface(part, hrp.Position)
		if surface and hrp and player:GetAttribute(Attr.Holding) == BOAT_ITEM and PlayerStateService.isStanding(player) and PlayerStateService.isParticipant(player) then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local feet = Geometry.footY(hrp, hum)
			local ground = groundY(hrp.Position, exclude) or feet
			local depth = surface - ground
			local need = if riding[player] then STOP_DEPTH else RIDE_DEPTH
			on = depth >= need and feet <= surface + MAX_ABOVE
		end
		setRiding(player, on)
	end
end

function BoatService.start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(step)
			if not ok then
				warn("[Boat]", err)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		riding[p] = nil
	end)
end

return BoatService
