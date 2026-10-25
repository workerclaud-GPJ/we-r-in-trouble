--!strict
--[[
	WantedItemController — floating marker over every item the open step needs
	(active objectives publish attribute Wants = capability or item type, Deliver.luau), seen
	through walls and water, so a cable lying under the flood can still be found.
	Also a small tip while you hold a bottle cap in a Flood: "walk into the water to sail".
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local Attr = Contract.Attr
local player = Players.LocalPlayer

local REFRESH = 0.3

local WantedItemController = {}

local marks: { [Instance]: BillboardGui } = {}

local function wants(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local rs = ReplicatedStorage:FindFirstChild("RoundState")
	local folder = rs and rs:FindFirstChild("Objectives")
	if not folder then
		return out
	end
	for _, cfg in folder:GetChildren() do
		local w = cfg:GetAttribute("Wants")
		if typeof(w) == "string" and cfg:GetAttribute("Active") == true and cfg:GetAttribute("Done") ~= true then
			out[w] = true
		end
	end
	return out
end

local function matches(itemType: string, w: { [string]: boolean }): boolean
	if w[itemType] then
		return true
	end
	local def = Config.Items[itemType]
	if def then
		for _, c in def.capabilities do
			if w[c] then
				return true
			end
		end
	end
	return false
end

local function makeMark(model: Model, label: string): BillboardGui
	local b = Instance.new("BillboardGui")
	b.Name = "WRIT_WantedMark"
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.MaxDistance = 260
	b.Size = UDim2.fromOffset(120, 46)
	b.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 0, 26)
	icon.Font = Enum.Font.FredokaOne
	icon.TextSize = 24
	icon.Text = "⭐"
	icon.TextColor3 = Color3.fromRGB(255, 220, 90)
	icon.Parent = b
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(0, 24)
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 16
	name.TextStrokeTransparency = 0.3
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = label
	name.Parent = b
	b.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	b.Parent = model
	return b
end

local tip: TextLabel? = nil
local function ensureTip(): TextLabel
	local t = tip
	if t and t.Parent then
		return t
	end
	local g = Instance.new("ScreenGui")
	g.Name = "WRIT_ItemTip"
	g.ResetOnSpawn = false
	g.DisplayOrder = 4
	g.Parent = player:WaitForChild("PlayerGui")
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(1, 1)
	l.Position = UDim2.new(1, -24, 1, -112)
	l.Size = UDim2.fromOffset(300, 26)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 18
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.TextColor3 = Color3.fromRGB(150, 220, 255)
	l.TextStrokeTransparency = 0.3
	l.Visible = false
	l.Parent = g
	tip = l
	return l
end

local function update()
	local w = wants()
	local seen: { [Instance]: boolean } = {}
	local map = Workspace:FindFirstChild("Map")
	for _, inst in CollectionService:GetTagged(Contract.Tag.Item) do
		if inst:IsA("Model") and map and inst:IsDescendantOf(map) then
			local itemType = inst:GetAttribute(Attr.ItemType)
			local carried = inst:GetAttribute(Attr.Carrier)
			if typeof(itemType) == "string" and (carried == 0 or carried == nil) and matches(itemType, w) then
				seen[inst] = true
				if not marks[inst] or not marks[inst].Parent then
					local def = Config.Items[itemType]
					marks[inst] = makeMark(inst, if def then def.displayName else itemType)
				end
			end
		end
	end
	for inst, b in marks do
		if not seen[inst] then
			b:Destroy()
			marks[inst] = nil
		end
	end

	-- boat tip
	local holding = player:GetAttribute(Attr.Holding)
	local flood = #CollectionService:GetTagged(Contract.Tag.RisingVolume) > 0
	local t = ensureTip()
	local show = holding == "Bottlecap" and flood and player:GetAttribute("Boating") ~= true
	t.Visible = show
	if show then
		t.Text = "🛶 Walk into the flood water to sail!"
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
