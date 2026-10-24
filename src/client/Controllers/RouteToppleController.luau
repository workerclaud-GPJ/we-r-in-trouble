--!strict
--[[
	RouteToppleController — client visuals for server RouteTopple pieces (Config.Features.RouteTopple).
	Separate from ToppleController (client-only decor topple, tag Toppleable): this one never moves
	anything for gameplay; the server owns the fall and the final pose.
	  ToppleWarning = true  -> local wobble about the hinge (towards the fall direction) + creak.
	                           Server does not move the piece during the warning, so the local
	                           offset is undone when the attribute turns false; the server's
	                           replicated fall frames take over from there.
	  ToppleLanded  = true  -> dust puffs along the PrimaryPart + thud (only on change, so a late
	                           joiner sees no stale effects).
	Sounds come from Config.Audio via Fx/Sound (id 0 = silent). Cheap: one Heartbeat per
	wobbling piece, only for WARNING_TIME s.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local RT = require(Shared.Config:WaitForChild("RouteTopple"))

local Sound = require(script.Parent:WaitForChild("Fx"):WaitForChild("Sound"))

local Attr = Contract.Attr

local DUST_COLOR = Color3.fromRGB(210, 195, 170)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local RouteToppleController = {}

-- weak keys: a map clone removed by replication without a client-side Destroying never leaks
local hooked: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function fallenPose(model: Model): CFrame?
	local pose = model:FindFirstChild(Contract.Name.FallenPose)
	if pose and pose:IsA("CFrameValue") then
		return pose.Value
	elseif pose and pose:IsA("Model") then
		return pose:GetPivot()
	elseif pose and pose:IsA("BasePart") then
		return pose.CFrame
	end
	return nil
end

local function dust(pos: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "RouteToppleDust"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = CFrame.new(pos)
	holder.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = SMOKE
	e.Color = ColorSequence.new(DUST_COLOR)
	e.Size = NumberSequence.new(2, 5)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Lifetime = NumberRange.new(0.5, 1)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 15)
	e.Drag = 5
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = holder
	e:Emit(RT.DUST)
	Debris:AddItem(holder, 2)
end

local function wobble(model: Model)
	local base = model:GetPivot()
	local target = fallenPose(model)
	local center = if model.PrimaryPart then model.PrimaryPart.Position else base.Position
	Sound.play(RT.CREAK_SOUND, center)
	if not target then
		return
	end
	-- hinge axis in pivot space (standing and fallen share the pivot point)
	local axis, _ = base:ToObjectSpace(target):ToAxisAngle()
	if axis.Magnitude < 1e-3 then
		return
	end
	local maxAngle = math.rad(RT.WOBBLE_DEG)
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		-- undo the local offset unless the fall already started (server frames then win anyway)
		if model.Parent and model:GetAttribute(Attr.ToppleFallAt) == nil then
			model:PivotTo(base)
		end
	end
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent or model:GetAttribute(Attr.ToppleWarning) ~= true then
			stop()
			return
		end
		local t = os.clock() - t0
		local ramp = math.clamp(t / RT.WARNING_TIME, 0, 1)
		-- leans towards the fall direction more and more, with a shiver on top
		local angle = maxAngle * ramp * (0.4 + 0.6 * math.sin(t * RT.WOBBLE_HZ * math.pi * 2))
		model:PivotTo(base * CFrame.fromAxisAngle(axis, angle))
	end)
	task.delay(RT.WARNING_TIME + 2, function()
		if conn then
			stop() -- safety: never wobble forever if the attribute is lost
		end
	end)
end

local function landed(model: Model)
	local main = model.PrimaryPart
	if not main then
		return
	end
	local half = main.Size.Z / 2
	for _, f in { -0.9, -0.3, 0.3, 0.9 } do
		dust(main.CFrame:PointToWorldSpace(Vector3.new(0, -main.Size.Y / 2, f * half)))
	end
	Sound.play(RT.LAND_SOUND, main.Position)
end

local function hook(inst: Instance)
	if not inst:IsA("Model") or hooked[inst] then
		return
	end
	local model = inst :: Model
	hooked[model] = true
	model:GetAttributeChangedSignal(Attr.ToppleWarning):Connect(function()
		if model:GetAttribute(Attr.ToppleWarning) == true then
			wobble(model)
		end
	end)
	model:GetAttributeChangedSignal(Attr.ToppleLanded):Connect(function()
		if model:GetAttribute(Attr.ToppleLanded) == true then
			landed(model)
		end
	end)
	model.Destroying:Connect(function()
		hooked[model] = nil
	end)
end

function RouteToppleController.start()
	if Config.Features.RouteTopple ~= true then
		return
	end
	CollectionService:GetInstanceAddedSignal(Contract.Tag.RouteTopple):Connect(hook)
	for _, inst in CollectionService:GetTagged(Contract.Tag.RouteTopple) do
		hook(inst)
	end
end

return RouteToppleController
