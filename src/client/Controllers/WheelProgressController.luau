--!strict
--[[
	WheelProgressController — a progress bar over the running wheel (RunWheel, Repair objective)
	so runners can see how much power is left to make. Reads the anchor attribute Progress
	(0..1, set by Objectives/Repair). Shown only when this round uses the wheel (the anchor has
	its prompt) and you are within SHOW_DIST studs; hides a few seconds after it is full.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local Attr = Contract.Attr
local player = Players.LocalPlayer

local SHOW_DIST = 40
local DONE_LINGER = 3

local WheelProgressController = {}

type Bar = { gui: BillboardGui, fill: Frame, label: TextLabel }
local bars: { [Instance]: Bar } = {}
local doneAt: { [Instance]: number } = {} -- when each wheel filled up (bar hides after DONE_LINGER)

local function anchorPart(a: Instance): BasePart?
	if a:IsA("BasePart") then
		return a
	end
	if a:IsA("Model") and a.PrimaryPart then
		return a.PrimaryPart
	end
	return a:FindFirstChildWhichIsA("BasePart", true)
end

local function makeBar(part: BasePart): Bar
	local g = Instance.new("BillboardGui")
	g.Name = "WRIT_WheelProgress"
	g.Size = UDim2.fromOffset(260, 46)
	g.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = SHOW_DIST + 10
	g.Adornee = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "Power 0%"
	label.Parent = g
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.new(1, 0, 0, 18)
	back.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
	back.BackgroundTransparency = 0.2
	back.Parent = g
	local c1 = Instance.new("UICorner")
	c1.CornerRadius = UDim.new(0, 9)
	c1.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 220, 120)
	stroke.Thickness = 2
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 210, 70)
	fill.Parent = back
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 9)
	c2.Parent = fill
	g.Parent = player:WaitForChild("PlayerGui")
	return { gui = g, fill = fill, label = label }
end

local function update()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local alive: { [Instance]: boolean } = {}
	for _, a in CollectionService:GetTagged(Contract.Tag.ObjectiveAnchor) do
		local prompt = a:FindFirstChildWhichIsA("ProximityPrompt", true)
		local pr0 = a:GetAttribute(Attr.Progress)
		-- open now (prompt enabled), or just filled (keep "Power full!" for a moment)
		local relevant = prompt ~= nil and (prompt.Enabled or (typeof(pr0) == "number" and pr0 >= 1))
		if a:GetAttribute(Attr.ObjectiveId) == "RunWheel" and a:IsDescendantOf(Workspace) and relevant then
			local part = anchorPart(a)
			if part then
				local pr = a:GetAttribute(Attr.Progress)
				local progress = if typeof(pr) == "number" then math.clamp(pr, 0, 1) else 0
				local near = hrp ~= nil and hrp:IsA("BasePart") and (hrp.Position - part.Position).Magnitude <= SHOW_DIST
				local sustain = a:GetAttribute("Sustain") == true -- generator: never "done", shows power on / off
				if progress >= 1 and not sustain then
					doneAt[a] = doneAt[a] or os.clock()
				else
					doneAt[a] = nil
				end
				local finished = doneAt[a] ~= nil and os.clock() - (doneAt[a] :: number) > DONE_LINGER
				local b = bars[a]
				if near and not finished and not b then
					b = makeBar(part)
					bars[a] = b
				end
				if b then
					if not near or finished then
						b.gui:Destroy()
						bars[a] = nil
					else
						alive[a] = true
						b.fill.Size = UDim2.fromScale(progress, 1)
						if sustain then
							b.fill.BackgroundColor3 = if progress > 0 then Color3.fromRGB(110, 230, 120) else Color3.fromRGB(230, 90, 80)
							b.label.Text = if progress > 0 then "⚡ Power ON" else "⚡ No power"
						else
							b.fill.BackgroundColor3 = if progress >= 1 then Color3.fromRGB(110, 230, 120) else Color3.fromRGB(255, 210, 70)
							b.label.Text = if progress >= 1 then "Power full! ⚡" else `Power {math.floor(progress * 100)}%`
						end
					end
				end
			end
		end
	end
	for a, b in bars do
		if not alive[a] then
			b.gui:Destroy()
			bars[a] = nil
		end
	end
end

function WheelProgressController.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			update()
		end
	end)
end

return WheelProgressController
