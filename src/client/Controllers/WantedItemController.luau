--!strict
--[[
	WantedItemController — items are findable, not pointed at: every item lying in the map
	gives off a soft sparkle (normal particles: hidden by walls like the item itself, but they
	rise out of flood water). No markers, no hints about which item the round needs: players
	read the item book (B) and figure out the way out themselves.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local Attr = Contract.Attr
local REFRESH = 0.5

local WantedItemController = {}

local sparkles: { [Instance]: ParticleEmitter } = {}

local function makeSparkle(model: Model): ParticleEmitter?
	local base = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not base then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "WRIT_ItemSparkle"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 245, 200))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Lifetime = NumberRange.new(1.2, 1.8)
	e.Rate = 2.5
	e.Speed = NumberRange.new(1.5, 2.5)
	e.SpreadAngle = Vector2.new(25, 25)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = base
	return e
end

local function update()
	local map = Workspace:FindFirstChild("Map")
	local seen: { [Instance]: boolean } = {}
	for _, inst in CollectionService:GetTagged(Contract.Tag.Item) do
		if inst:IsA("Model") and map and inst:IsDescendantOf(map) then
			local carried = inst:GetAttribute(Attr.Carrier)
			if carried == 0 or carried == nil then
				seen[inst] = true
				local e = sparkles[inst]
				if not e or not e.Parent then
					local n = makeSparkle(inst)
					if n then
						sparkles[inst] = n
					end
				end
			end
		end
	end
	for inst, e in sparkles do
		if not seen[inst] then
			e:Destroy()
			sparkles[inst] = nil
		end
	end
end

function WantedItemController.start()
	local acc = REFRESH
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= REFRESH then
			acc = 0
			update()
		end
	end)
end

return WantedItemController
