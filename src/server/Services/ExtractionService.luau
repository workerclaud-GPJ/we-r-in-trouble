--!strict
--[[
	ExtractionService — exit unlock → ETA → carrier descends → Exit Zone Open →
	Departure countdown (pauses, never resets) with Last call quorum (GDD §5.8, §8.6.1).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Geometry = require(Shared.Util.Geometry)
local Cleanup = require(Shared.Util.Cleanup)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RoundState = require(script.Parent.RoundState)
local Hud = require(script.Parent.Hud)

local Attr = Contract.Attr
local X = Config.Extraction

local ExtractionService = {}

local scope: Cleanup.Cleanup? = nil
local begun = false
local arrived = false
local arrivedAt = 0
local running = false
local remaining = 0
local lastCallShown = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function unlockDoors(flag: string)
	for _, inst in MapService.tagged(Contract.Tag.LockedDoor) do
		if inst:GetAttribute(Attr.UnlockedBy) == flag then
			inst:SetAttribute(Attr.Unlocked, true)
			local parts: { Instance } = if inst:IsA("BasePart") then { inst } else inst:GetDescendants()
			for _, d in parts do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanQuery = false
					d.Transparency = 1
				end
			end
		end
	end
end

local function spawnCarrier(assetName: string?): Instance?
	local spots = MapService.tagged(Contract.Tag.ExitVehicleSpot)
	local spot = spots[1]
	local runtime = MapService.getRuntime()
	if not (spot and spot:IsA("BasePart") and runtime) then
		warn("[Extraction] no ExitVehicleSpot part in map — carrier is invisible")
		return nil
	end
	local carrier: Instance
	local asset = MapService.findAsset(assetName)
	if asset and asset:IsA("Model") then
		local model = asset:Clone()
		local base = model:FindFirstChild("Base")
		if base and base:IsA("BasePart") then
			model.PrimaryPart = base
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		-- bottom of Base on the ground = bottom face of ExitVehicleSpot (+61)
		local ground = spot.CFrame * CFrame.new(0, -spot.Size.Y / 2, 0)
		if model.PrimaryPart then
			local basePart = model.PrimaryPart
			model:PivotTo(ground * CFrame.new(0, basePart.Size.Y / 2, 0) * basePart.PivotOffset)
		else
			local cf, size = model:GetBoundingBox()
			model:PivotTo(ground * CFrame.new(0, size.Y / 2, 0) * cf:ToObjectSpace(model:GetPivot()))
		end
		carrier = model
	else
		local part = Instance.new("Part") -- placeholder cage
		part.Name = assetName or "RescueCarrier"
		part.Size = Vector3.new(26, 17, 18)
		part.Transparency = 0.6
		part.Color = Color3.fromRGB(70, 150, 230)
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.CFrame = spot.CFrame * CFrame.new(0, -spot.Size.Y / 2 + part.Size.Y / 2, 0)
		carrier = part
	end
	local t = now()
	carrier:SetAttribute(Attr.DescendStartedAt, t)
	carrier:SetAttribute(Attr.DescendEndsAt, t + X.CARRIER_DESCEND_TIME)
	carrier:SetAttribute(Attr.DescendHeight, X.CARRIER_DESCEND_HEIGHT)
	CollectionService:AddTag(carrier, Contract.Tag.ExitVehicle)
	carrier.Parent = runtime
	return carrier
end

local function onArrived(direct: boolean)
	arrived = true
	arrivedAt = now()
	for _, zone in MapService.exitZones() do
		zone:SetAttribute(Attr.Open, true)
	end
	RoundState.set(Attr.CarrierArrived, true)
	RoundState.set(Attr.CarrierArrivedAt, arrivedAt)
	if not direct then
		Hud.banner("BannerCarrier", "The rescue carrier is here!", "Everyone get inside!", "Good", 3)
	end
end

local DIRECT_BANNER: { [string]: { string } } = {
	Window = { "BannerWindowEscape", "The window is open!", "Jump out of the window!" },
	Drain = { "BannerDrainEscape", "The drain is open!", "Climb down the cable into the drain!" },
}

-- Exit unlocked (final step complete).
function ExtractionService.begin(def: Types.MissionDef)
	if begun then
		return
	end
	ExtractionService.stop()
	begun = true
	local s = Cleanup.new()
	scope = s
	MapService.setFlag(def.exitFlag)
	unlockDoors(def.exitFlag)
	if def.exitKind then
		-- escape scenario: no carrier, the exit zone opens right away (Departure as usual)
		RoundState.set(Attr.ExitOpen, true)
		RoundState.set(Attr.CarrierArrivesAt, nil)
		local b = DIRECT_BANNER[def.exitKind] or DIRECT_BANNER.Window
		Hud.banner(b[1], b[2], b[3], "Good", 3)
		onArrived(true)
		return
	end
	local eta = now() + def.exitArrivalDelay
	RoundState.set(Attr.ExitOpen, true)
	RoundState.set(Attr.CarrierArrivesAt, eta)
	Hud.banner("BannerWindowOpen", "The window is open!", "Rescue is coming. Get to the exit!", "Good", 3)

	s:add(task.delay(def.exitArrivalDelay, function()
		spawnCarrier(def.exitVehicleAsset)
		s:add(task.delay(X.CARRIER_DESCEND_TIME, onArrived, false))
	end))
end

-- Team members (Standing or Downed, with a character) inside any Exit Zone.
function ExtractionService.playersInZone(): { Player }
	local out: { Player } = {}
	local zones = MapService.exitZones()
	for _, player in PlayerStateService.activeMembers() do
		local hrp = PlayerStateService.getHRP(player)
		if hrp then
			for _, zone in zones do
				if Geometry.pointInPart(hrp.Position, zone, 1) then
					table.insert(out, player)
					break
				end
			end
		end
	end
	return out
end

function ExtractionService.isCarrierArrived(): boolean
	return arrived
end

-- Returns true when Departure completes, plus who is in the zone.
function ExtractionService.update(dt: number): (boolean, { Player })
	if not arrived then
		return false, {}
	end
	local inZone = ExtractionService.playersInZone()
	local active = PlayerStateService.activeCount()
	local lastCall = now() - arrivedAt >= X.LAST_CALL_AFTER
	local needed = if lastCall then math.max(1, math.ceil(active * X.LAST_CALL_QUORUM)) else active
	if lastCall and not lastCallShown then
		lastCallShown = true
		RoundState.set(Attr.LastCall, true)
		Hud.banner("BannerLastCall", "Last call!", "The carrier is leaving soon", "Warn", 3)
	end
	RoundState.set(Attr.ZoneCount, #inZone)
	RoundState.set(Attr.ZoneNeeded, needed)

	local ok = active >= 1 and #inZone >= 1 and #inZone >= needed
	if ok then
		if not running then
			running = true
			RoundState.set(Attr.DepartureRunning, true)
			RoundState.set(Attr.DepartureEndsAt, now() + remaining)
		end
		remaining = math.max(0, remaining - dt)
		RoundState.set(Attr.DepartureRemaining, math.ceil(remaining))
		if remaining <= 0 then
			return true, inZone
		end
	elseif running then
		running = false
		RoundState.set(Attr.DepartureRunning, false)
		RoundState.set(Attr.DepartureEndsAt, nil)
		RoundState.set(Attr.DepartureRemaining, math.ceil(remaining))
	end
	return false, inZone
end

function ExtractionService.stop()
	if scope then
		scope:clean()
		scope = nil
	end
	begun = false
	arrived = false
	arrivedAt = 0
	running = false
	remaining = X.DEPARTURE_COUNTDOWN
	lastCallShown = false
end

ExtractionService.stop()

return ExtractionService
