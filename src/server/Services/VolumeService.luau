--!strict
--[[
	VolumeService — GDD §4.2 RisingVolume (+ Slowed / Submerged status effects), used by Flood.
	Theme-free: knows "volume", "level", "breath", never "water".

	Map markup (optional): Part tagged VolumeLevel with attribute Level = 0 — its centre Y is
	Level 0 and its X/Z box is the footprint. Without it: the map DropArea / floor PrimaryPart.

	The volume is ONE anchored Part in Map.Runtime (tag + name RisingVolume, CanCollide/CanQuery/
	CanTouch false). The server resizes it every `tick` s (and on every riseTo) and publishes the
	rise as attributes (BaseY, RiseFrom, RiseTo, RiseStartedAt, RiseEndsAt, SurfaceY); clients
	re-apply the same formula every frame for a smooth surface (HazardFxController). Server checks players every `tick` s against the same
	linear formula:
	  surface >= feet + wadeDepth -> SpeedMult x wadeSpeedMult
	  surface >= head top         -> Breath drains; at 0 -> drownDamage every drownInterval (quiet)
	  otherwise                   -> Breath refills
	Respawn: MapService spawn filter skips pads the (target) surface covers by >= spawnSafeDepth,
	and `enableFlag` turns on high-ground PlayerSpawns (EnabledBy = flag).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Types = require(Shared.Types)
local Cleanup = require(Shared.Util.Cleanup)
local Geometry = require(Shared.Util.Geometry)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local Attr = Contract.Attr
local SPEED_KEY = "VolumeWade"
local BREATH_PUBLISH_STEP = 1 -- only replicate Breath changes >= 1 (or at the bounds)

local VolumeService = {}

local def: Types.VolumeDef? = nil
local scope: Cleanup.Cleanup? = nil
local volumePart: Part? = nil
local baseY = 0
local footprintCF = CFrame.identity
local footprintSize = Vector3.zero
local riseFrom, riseTo, riseStart, riseEnd = 0, 0, 0, 0
local breath: { [Player]: number } = {}
local published: { [Player]: number } = {}
local drownTimer: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function insideFootprint(pos: Vector3): boolean
	local lp = footprintCF:PointToObjectSpace(pos)
	return math.abs(lp.X) <= footprintSize.X / 2 and math.abs(lp.Z) <= footprintSize.Z / 2
end

-- Current level (studs above Level 0).
function VolumeService.level(): number
	if riseEnd <= riseStart then
		return riseTo
	end
	local a = math.clamp((now() - riseStart) / (riseEnd - riseStart), 0, 1)
	return riseFrom + (riseTo - riseFrom) * a
end

function VolumeService.isActive(): boolean
	return def ~= nil
end

-- World Y of the surface now (nil when no volume runs).
function VolumeService.surfaceY(): number?
	if not def then
		return nil
	end
	return baseY + VolumeService.level()
end

-- GDD §4.2 isPointHazardous for the volume: `point` (e.g. a spawn pad top) is or will soon be
-- (current rise target) covered by >= depth studs.
function VolumeService.isPointHazardous(point: Vector3, depth: number?): boolean
	local d = def
	if not d or not insideFootprint(point) then
		return false
	end
	local surface = baseY + math.max(VolumeService.level(), riseTo)
	return surface >= point.Y + (depth or d.spawnSafeDepth)
end

-- Server-side transform of the volume Part (so the server/Studio view, raycast-free checks and
-- late joiners all match the current level); clients still smooth it locally every frame.
local function applyPart()
	local part = volumePart
	if not part or not part.Parent then
		return
	end
	local level = VolumeService.level()
	local top = baseY + math.max(level, 0.05)
	local bottom = baseY - 1
	local h = top - bottom
	local _, yaw, _ = footprintCF:ToOrientation()
	local centre = footprintCF.Position
	part.Size = Vector3.new(footprintSize.X, h, footprintSize.Z)
	part.CFrame = CFrame.new(centre.X, bottom + h / 2, centre.Z) * CFrame.Angles(0, yaw, 0)
end

local function publishRise()
	local part = volumePart
	if not part then
		return
	end
	part:SetAttribute(Attr.RiseFrom, riseFrom)
	part:SetAttribute(Attr.RiseTo, riseTo)
	part:SetAttribute(Attr.RiseStartedAt, riseStart)
	part:SetAttribute(Attr.RiseEndsAt, riseEnd)
	part:SetAttribute(Attr.SurfaceY, baseY + riseTo)
	applyPart()
end

-- Rise (or fall) linearly from the current level to `level` over `riseTime` s.
function VolumeService.riseTo(level: number, riseTime: number)
	local d = def
	if not d then
		return
	end
	local current = VolumeService.level()
	riseFrom = current
	riseTo = math.clamp(level, 0, d.maxLevel)
	riseStart = now()
	riseEnd = riseStart + math.max(0, riseTime)
	publishRise()
end

----------------------------------------------------------------------------
-- Player checks
----------------------------------------------------------------------------

local function setBreath(player: Player, value: number, maxValue: number)
	breath[player] = value
	local last = published[player]
	if last == nil or math.abs(last - value) >= BREATH_PUBLISH_STEP or value <= 0 or value >= maxValue then
		if last ~= value then
			published[player] = value
			player:SetAttribute(Attr.Breath, math.floor(value * 10 + 0.5) / 10)
		end
	end
end

local function headTopY(player: Player, footY: number, d: Types.VolumeDef): number
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position.Y + head.Size.Y / 2
	end
	return footY + d.headHeight
end

local function checkPlayer(player: Player, d: Types.VolumeDef, surface: number, dt: number)
	local current = breath[player] or d.breathMax
	local hrp = PlayerStateService.getHRP(player)
	if not (hrp and PlayerStateService.isStanding(player)) then
		PlayerStateService.setPlayerSpeedModifier(player, SPEED_KEY, nil)
		drownTimer[player] = 0
		setBreath(player, d.breathMax, d.breathMax)
		return
	end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local footY = Geometry.footY(hrp, humanoid)
	local inside = insideFootprint(hrp.Position)
	local wading = inside and surface >= footY + d.wadeDepth
	PlayerStateService.setPlayerSpeedModifier(player, SPEED_KEY, if wading then d.wadeSpeedMult else nil)

	if inside and surface >= headTopY(player, footY, d) then
		current = math.max(0, current - d.breathDrain * dt)
		if current <= 0 then
			local t = (drownTimer[player] or 0) + dt
			while t >= d.drownInterval do
				t -= d.drownInterval
				PlayerStateService.damage(player, d.drownDamage, true)
			end
			drownTimer[player] = t
		end
	else
		current = math.min(d.breathMax, current + d.breathRefill * dt)
		drownTimer[player] = 0
	end
	setBreath(player, current, d.breathMax)
end

local function tick(dt: number)
	local d = def
	applyPart()
	if not d or not PlayerStateService.isMatchActive() then
		return
	end
	local surface = baseY + VolumeService.level()
	for _, player in PlayerStateService.teamMembers() do
		checkPlayer(player, d, surface, dt)
	end
end

----------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------

local function findFootprint()
	for _, inst in MapService.tagged(Contract.Tag.VolumeLevel) do
		if inst:IsA("BasePart") and inst:GetAttribute(Attr.Level) == 0 then
			footprintCF, footprintSize = inst.CFrame, inst.Size
			baseY = inst.Position.Y
			return
		end
	end
	local cf, size, floorY = MapService.getDropArea()
	footprintCF, footprintSize, baseY = cf, size, floorY
end

local function createPart(d: Types.VolumeDef): Part?
	local runtime = MapService.getRuntime()
	if not runtime then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = Contract.Name.RisingVolume
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Glass
	p.Color = d.color
	p.Transparency = d.transparency
	-- parked just under Level 0 until the first applyPart()
	p.Size = Vector3.new(footprintSize.X, 0.2, footprintSize.Z)
	local _, yaw, _ = footprintCF:ToOrientation()
	local centre = footprintCF.Position
	p.CFrame = CFrame.new(centre.X, baseY - 0.5, centre.Z) * CFrame.Angles(0, yaw, 0)
	p:SetAttribute(Attr.BaseY, baseY)
	CollectionService:AddTag(p, Contract.Tag.RisingVolume)
	p.Parent = runtime
	return p
end

function VolumeService.begin(volumeDef: Types.VolumeDef)
	VolumeService.stop()
	def = volumeDef
	findFootprint()
	local s = Cleanup.new()
	scope = s
	riseFrom, riseTo, riseStart, riseEnd = 0, 0, now(), now()
	local part = createPart(volumeDef)
	volumePart = part
	if part then
		s:add(part)
	end
	publishRise()

	for _, player in PlayerStateService.teamMembers() do
		setBreath(player, volumeDef.breathMax, volumeDef.breathMax)
	end
	if volumeDef.enableFlag then
		MapService.setFlag(volumeDef.enableFlag)
	end
	MapService.setSpawnFilter(function(padTop: Vector3): boolean
		return VolumeService.isPointHazardous(padTop)
	end)
	s:add(function()
		MapService.setSpawnFilter(nil)
	end)

	s:add(task.spawn(function()
		local last = os.clock()
		while s:alive() do
			task.wait(volumeDef.tick)
			local t = os.clock()
			tick(t - last)
			last = t
		end
	end))
end

function VolumeService.stop()
	if scope then
		scope:clean()
		scope = nil
	end
	if def then
		for _, player in Players:GetPlayers() do
			PlayerStateService.setPlayerSpeedModifier(player, SPEED_KEY, nil)
			player:SetAttribute(Attr.Breath, nil)
		end
	end
	def = nil
	volumePart = nil
	table.clear(breath)
	table.clear(published)
	table.clear(drownTimer)
	riseFrom, riseTo, riseStart, riseEnd = 0, 0, 0, 0
end

Players.PlayerRemoving:Connect(function(player: Player)
	breath[player] = nil
	published[player] = nil
	drownTimer[player] = nil
end)

return VolumeService
