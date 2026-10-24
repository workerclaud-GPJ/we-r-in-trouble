--!strict
--[[
	CableThrowService — cast the held charger cable (any Rope item) at a cable hook, like a
	fishing cast (MissionDef.cableThrow; client: CableThrowController hold-to-charge meter).

	Map markup (tools/AddEscapeScenarios.luau): Model tagged CableRoute with attributes
	RouteId, RequiredPower (0..1), PowerWindow (+-), ReachesCounter; children
	  ThrowSpot  Part  — stand inside it to cast (invisible)
	  HookPoint  Part  — where the cable ties (the hook)
	  Cable      Model — FlagReveal "Cable_<RouteId>": the bridge plank / climbing truss + visuals

	Cast (Remote CastCable, routeId, power): standing participant holding a Rope item, inside the
	route's ThrowSpot, route not hooked yet, max 1 cast per second.
	  |power - RequiredPower| <= PowerWindow → the cable is used up, the route is hooked
	  (CastAt/CastOk/CastFrom/CastTo for the client throw animation), its Cable appears after
	  the flight, Attached fires.
	  otherwise → miss: the cable lands short / long along the throw line (ItemService.drop at).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local Geometry = require(Shared.Util.Geometry)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local ItemService = require(script.Parent.ItemService)
local RoundState = require(script.Parent.RoundState)
local Hud = require(script.Parent.Hud)

local Attr = Contract.Attr

local FLIGHT_TIME = 0.6 -- s the cable flies before the bridge appears (client animates the same)
local CAST_COOLDOWN = 1
local SPOT_PADDING = 2

local CableThrowService = {}

-- (routeId, reachesCounter)
CableThrowService.Attached = Signal.new() :: Signal.Signal<string, boolean>

local enabled = false
local generation = 0
local lastCast: { [Player]: number } = {}

local function routes(): { Model }
	local out: { Model } = {}
	for _, inst in MapService.tagged(Contract.Tag.CableRoute) do
		if inst:IsA("Model") then
			table.insert(out, inst)
		end
	end
	return out
end

local function findRoute(id: string): Model?
	for _, r in routes() do
		if r:GetAttribute(Attr.RouteId) == id then
			return r
		end
	end
	return nil
end

local function part(route: Model, name: string): BasePart?
	local p = route:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

function CableThrowService.isHooked(id: string): boolean
	local r = findRoute(id)
	return r ~= nil and r:GetAttribute(Attr.Attached) == true
end

-- true when any hooked route reaches the counter (CableHook objective opened late)
function CableThrowService.counterReached(): boolean
	for _, r in routes() do
		if r:GetAttribute(Attr.Attached) == true and r:GetAttribute(Attr.ReachesCounter) == true then
			return true
		end
	end
	return false
end

local function onCast(player: Player, routeId: any, power: any)
	if not enabled or typeof(routeId) ~= "string" or typeof(power) ~= "number" or power ~= power then
		return
	end
	local t = os.clock()
	if t - (lastCast[player] or 0) < CAST_COOLDOWN then
		return
	end
	if not (PlayerStateService.isStanding(player) and PlayerStateService.isParticipant(player)) then
		return
	end
	local held = player:GetAttribute(Attr.Holding)
	if not (typeof(held) == "string" and held ~= "" and ItemService.hasCapability(held, "Rope")) then
		return
	end
	local route = findRoute(routeId)
	if not route or route:GetAttribute(Attr.Attached) == true then
		return
	end
	local spot, hook = part(route, "ThrowSpot"), part(route, "HookPoint")
	local hrp = PlayerStateService.getHRP(player)
	if not (spot and hook and hrp) or not Geometry.pointInPart(hrp.Position, spot, SPOT_PADDING) then
		return
	end
	lastCast[player] = t
	power = math.clamp(power, 0, 1)
	local need = num(route, Attr.RequiredPower, 0.6)
	local window = num(route, Attr.PowerWindow, 0.1)
	local from = hrp.Position + Vector3.new(0, 1, 0)
	local now = Workspace:GetServerTimeNow()

	if math.abs(power - need) <= window then
		if not ItemService.consumeCapability(player, "Rope") then
			return
		end
		route:SetAttribute(Attr.Attached, true)
		route:SetAttribute(Attr.CastFrom, from)
		route:SetAttribute(Attr.CastTo, hook.Position)
		route:SetAttribute(Attr.CastOk, true)
		route:SetAttribute(Attr.CastAt, now)
		local gen = generation
		task.delay(FLIGHT_TIME, function()
			if gen ~= generation or not route.Parent then
				return
			end
			MapService.setFlag(`Cable_{routeId}`)
			local reaches = route:GetAttribute(Attr.ReachesCounter) == true
			Hud.banner("BannerCableHooked", "Cable hooked!", if reaches then "A new way up to the counter!" else "A new way across!", "Good", 2)
			CableThrowService.Attached:Fire(routeId, reaches)
		end)
	else
		-- miss: lands along the throw line, short (weak) or past the hook (strong)
		local frac = math.clamp(power / math.max(need, 0.05), 0.15, 1.35)
		local flat = Vector3.new(hook.Position.X - from.X, 0, hook.Position.Z - from.Z)
		local land = from + flat * frac
		route:SetAttribute(Attr.CastFrom, from)
		route:SetAttribute(Attr.CastTo, land)
		route:SetAttribute(Attr.CastOk, false)
		route:SetAttribute(Attr.CastAt, now)
		local gen = generation
		task.delay(FLIGHT_TIME, function()
			if gen ~= generation then
				return
			end
			if player.Parent and ItemService.isHolding(player) then
				ItemService.drop(player, land)
			end
		end)
	end
end

-- Match start (after loadMap): casting on only if the mission asks for it.
function CableThrowService.begin(mission: Types.MissionDef)
	generation += 1
	enabled = mission.cableThrow == true
	RoundState.set(Attr.CableThrow, if enabled then true else nil)
	table.clear(lastCast)
	if enabled and #routes() == 0 then
		warn("[CableThrow] mission wants cableThrow but the map has no CableRoute models")
	end
end

function CableThrowService.reset()
	generation += 1
	enabled = false
	RoundState.set(Attr.CableThrow, nil)
	table.clear(lastCast)
end

-- Debug: hook a route without a cable (`/dbg cable <id>`).
function CableThrowService.debugHook(id: string): boolean
	local route = findRoute(id)
	if not route or route:GetAttribute(Attr.Attached) == true then
		return false
	end
	route:SetAttribute(Attr.Attached, true)
	MapService.setFlag(`Cable_{id}`)
	CableThrowService.Attached:Fire(id, route:GetAttribute(Attr.ReachesCounter) == true)
	return true
end

function CableThrowService.start()
	Remotes.get("CastCable").OnServerEvent:Connect(onCast)
	game:GetService("Players").PlayerRemoving:Connect(function(p: Player)
		lastCast[p] = nil
	end)
end

return CableThrowService
