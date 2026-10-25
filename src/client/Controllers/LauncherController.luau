--!strict
--[[
	LauncherController — applies scene-object throws to the local hamster (LauncherService).
	  Remote Launch {from?, to, time}: (toaster) start at `from`, fly a ballistic arc to `to`.
	  Touch launchers (Mode "Touch", e.g. the sponge): landing on top bounces you to Target.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local Attr = Contract.Attr

local LauncherController = {}

local lastBounce = 0

local function launch(from: Vector3?, to: Vector3, t: number)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hrp:IsA("BasePart") and hum) then
		return
	end
	if from then
		hrp.CFrame = CFrame.new(from) * (hrp.CFrame - hrp.CFrame.Position)
	end
	local start = hrp.Position
	local g = Workspace.Gravity
	local d = to + Vector3.new(0, 3, 0) - start -- aim the root ~3 studs above the landing surface
	local v = Vector3.new(d.X / t, (d.Y + 0.5 * g * t * t) / t, d.Z / t)
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	hrp.AssemblyLinearVelocity = v
	-- keep the arc honest for the flight (air control would bend it)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - t0
		if e >= t or not hrp.Parent then
			conn:Disconnect()
			return
		end
		local want = Vector3.new(v.X, v.Y - g * e, v.Z)
		local cur = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(want.X, cur.Y, want.Z)
	end)
end

local function checkTouch()
	if os.clock() - lastBounce < 1 then
		return
	end
	if player:GetAttribute(Attr.State) ~= Contract.State.Standing then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end
	for _, inst in CollectionService:GetTagged("Launcher") do
		if inst:IsA("BasePart") and inst:GetAttribute("Mode") == "Touch" and inst:IsDescendantOf(Workspace) then
			local lp = inst.CFrame:PointToObjectSpace(hrp.Position)
			local h = inst.Size / 2
			if math.abs(lp.X) <= h.X + 0.5 and math.abs(lp.Z) <= h.Z + 0.5 and lp.Y > h.Y - 0.5 and lp.Y < h.Y + 4.5 then
				local to = inst:GetAttribute("Target")
				if typeof(to) == "Vector3" then
					lastBounce = os.clock()
					local flight = inst:GetAttribute("Flight")
					launch(nil, to, if typeof(flight) == "number" then flight else 1)
					-- squish
					local orig = inst.Size
					inst.Size = Vector3.new(orig.X, orig.Y * 0.5, orig.Z)
					task.delay(0.15, function()
						inst.Size = orig
					end)
				end
				return
			end
		end
	end
end

-- Fans (Switch Kind "Fan"): while running, the Wind part (attr Push) blows you sideways; blades spin.
local spin = 0
local function updateFans(dt: number)
	local now = Workspace:GetServerTimeNow()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	spin += dt
	for _, inst in CollectionService:GetTagged("Switch") do
		if inst:IsA("Model") and inst:GetAttribute("Kind") == "Fan" and inst:IsDescendantOf(Workspace) then
			local u = inst:GetAttribute("ActiveUntil")
			local on = typeof(u) == "number" and u > now
			local blades = inst:FindFirstChild("Blades")
			local hub = inst:FindFirstChild("Hub")
			if on and blades and blades:IsA("Model") and hub and hub:IsA("BasePart") then
				blades:PivotTo(hub.CFrame * CFrame.Angles(spin * 14, 0, 0)) -- standing fan: spins round its facing (X) axis
			end
			-- horizontal wind along the floor: pushes you (bottle-cap boats harder) the way it blows.
			-- Never lifts: it only speeds up a trip you could walk anyway.
			local wind = inst:FindFirstChild("Wind")
			local push = wind and wind:GetAttribute("Push")
			if on and wind and wind:IsA("BasePart") and typeof(push) == "Vector3" and hrp and hrp:IsA("BasePart") and player:GetAttribute(Attr.State) == Contract.State.Standing then
				local lp = wind.CFrame:PointToObjectSpace(hrp.Position)
				local h = wind.Size / 2
				if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z then
					local mult = if player:GetAttribute("Boating") == true then 1.6 else 1
					hrp.CFrame = hrp.CFrame + Vector3.new(push.X, 0, push.Z) * mult * dt
				end
			end
		end
	end
end

function LauncherController.start()
	Remotes.get("Launch").OnClientEvent:Connect(function(p: any)
		if typeof(p) == "table" and typeof(p.to) == "Vector3" then
			launch(if typeof(p.from) == "Vector3" then p.from else nil, p.to, if typeof(p.time) == "number" then p.time else 1.2)
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		checkTouch()
		updateFans(dt)
	end)
end

return LauncherController
