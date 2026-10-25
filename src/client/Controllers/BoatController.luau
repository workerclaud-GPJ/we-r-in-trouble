--!strict
--[[
	BoatController — client side of the bottle-cap boat (server: BoatService sets the player
	attribute Boating). Local rider: an invisible local platform follows you at the water
	surface so you sail on top of the flood (lifted up when you start riding below it).
	Every rider (any player): a bottle-cap boat drawn under their feet, bobbing on the water.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Volume = require(Shared.Util.Volume)

local player = Players.LocalPlayer

local BOAT_RADIUS = 3.6

local BoatController = {}

local platform: Part? = nil
local boats: { [Player]: Model } = {}

local function volumePart(): BasePart?
	for _, inst in CollectionService:GetTagged(Contract.Tag.RisingVolume) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			return inst
		end
	end
	return nil
end

-- running faucet streams (LauncherService switch Kind "Faucet"): StreamZone parts, Flow attr
local function streamAt(pos: Vector3): (number?, Vector3)
	local now = Workspace:GetServerTimeNow()
	for _, inst in CollectionService:GetTagged("Switch") do
		local u = inst:GetAttribute("ActiveUntil")
		if inst:IsDescendantOf(Workspace) and inst:GetAttribute("Kind") == "Faucet" and typeof(u) == "number" and u > now then
			for _, d in inst:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "StreamZone" and Volume.over(d, pos) then
					local flow = d:GetAttribute("Flow")
					return d.Position.Y + d.Size.Y / 2, if typeof(flow) == "Vector3" then flow else Vector3.zero
				end
			end
		end
	end
	return nil, Vector3.zero
end

-- water surface under pos: flood volume or stream (higher wins), plus the stream flow
local function surfaceAt(pos: Vector3): (number?, Vector3)
	local part = volumePart()
	local best: number? = if part and Volume.over(part, pos) then Volume.surfaceY(part) else nil
	local s, flow = streamAt(pos)
	if s and (best == nil or s > best) then
		return s, flow
	end
	return best, Vector3.zero
end

local function makeBoat(): Model
	local m = Instance.new("Model")
	m.Name = "WRIT_BottlecapBoat"
	local function p(name: string, size: Vector3, color: Color3, cf: CFrame, shape: Enum.PartType?, material: Enum.Material?): Part
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.CanCollide = false
		x.CanQuery = false
		x.CanTouch = false
		x.CastShadow = false
		x.Size = size
		x.Color = color
		x.Material = material or Enum.Material.SmoothPlastic
		if shape then
			x.Shape = shape
		end
		x:SetAttribute("Offset", cf)
		x.Parent = m
		return x
	end
	local red = Color3.fromRGB(215, 45, 45)
	-- cylinder axis = X: rotate so the flat faces point up
	local up = CFrame.Angles(0, 0, math.rad(90))
	p("Hull", Vector3.new(1.4, BOAT_RADIUS * 2, BOAT_RADIUS * 2), red, CFrame.new(0, -0.3, 0) * up, Enum.PartType.Cylinder)
	p("Inside", Vector3.new(0.2, BOAT_RADIUS * 2 - 0.8, BOAT_RADIUS * 2 - 0.8), Color3.fromRGB(240, 240, 235), CFrame.new(0, 0.45, 0) * up, Enum.PartType.Cylinder)
	for i = 0, 11 do
		local a = math.rad(i * 30)
		p(`Ridge{i}`, Vector3.new(0.35, 1.3, 0.35), Color3.fromRGB(190, 35, 35), CFrame.new(math.cos(a) * BOAT_RADIUS, -0.3, math.sin(a) * BOAT_RADIUS))
	end
	m.Parent = Workspace
	return m
end

local function placeBoat(m: Model, cf: CFrame)
	for _, x in m:GetChildren() do
		if x:IsA("BasePart") then
			local off = x:GetAttribute("Offset")
			if typeof(off) == "CFrame" then
				x.CFrame = cf * off
			end
		end
	end
end

local function update(dt: number)
	local t = os.clock()
	-- boats for every rider
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local surface = if hrp and hrp:IsA("BasePart") then surfaceAt(hrp.Position) else nil
		if surface and p:GetAttribute("Boating") == true and hrp and hrp:IsA("BasePart") then
			local m = boats[p]
			if not m or not m.Parent then
				m = makeBoat()
				boats[p] = m
			end
			local _, yaw, _ = hrp.CFrame:ToOrientation()
			local bob = math.sin(t * 2.2 + p.UserId % 7) * 0.15
			placeBoat(m, CFrame.new(hrp.Position.X, surface + bob, hrp.Position.Z) * CFrame.Angles(0, yaw, math.sin(t * 1.7) * 0.04))
		elseif boats[p] then
			boats[p]:Destroy()
			boats[p] = nil
		end
	end
	for p, m in boats do
		if p.Parent ~= Players then
			m:Destroy()
			boats[p] = nil
		end
	end

	-- local rider: stand on the surface
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local mySurface, myFlow = Vector3.zero.X, Vector3.zero
	local s0: number? = nil
	if hrp and hrp:IsA("BasePart") then
		s0, myFlow = surfaceAt(hrp.Position)
	end
	if s0 and player:GetAttribute("Boating") == true and hrp and hrp:IsA("BasePart") and hum then
		mySurface = s0
		local surface = mySurface
		local plat = platform
		if not plat or not plat.Parent then
			local n = Instance.new("Part")
			n.Name = "WRIT_BoatFloor"
			n.Anchored = true
			n.CanCollide = true
			n.CanQuery = false
			n.CanTouch = false
			n.Transparency = 1
			n.Size = Vector3.new(BOAT_RADIUS * 2, 1, BOAT_RADIUS * 2)
			n.Parent = Workspace
			plat = n
			platform = n
			-- starting below the surface: pop up onto it
			local feet = hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight
			if feet < surface - 0.3 then
				hrp.CFrame = hrp.CFrame + Vector3.new(0, surface - feet + 0.3, 0)
			end
		end
		if myFlow.Magnitude > 0 then
			hrp.CFrame = hrp.CFrame + myFlow * dt -- the stream carries the boat
		end
		(plat :: Part).CFrame = CFrame.new(hrp.Position.X, surface + 0.2 - 0.5, hrp.Position.Z)
	elseif platform then
		platform:Destroy()
		platform = nil
	end
end

function BoatController.start()
	RunService.Heartbeat:Connect(update)
end

return BoatController
