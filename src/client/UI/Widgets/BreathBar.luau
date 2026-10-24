--!strict
--[[
	BreathBar — small air bar above the HealthBar (Flood / RisingVolume, GDD §4.3.2).
	Reads the Player attribute Breath (0..100, server-owned; nil when no volume runs).
	Visible only in a Match while Standing and Breath < full. Low air -> red + blinking label.
	Self-contained (own 10 Hz refresh) so it hooks into UIController with one line.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UI = script.Parent.Parent
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local Attr = Contract.Attr

export type BreathBar = {
	root: Frame,
	destroy: () -> (),
}

local BreathBar = {}

local BOTTOM_OFFSET = 72 -- HealthBar sits at 24 px with height 40
local BREATH_MAX = 100
local LOW = 0.3
local REFRESH = 0.1
local AIR_COLOR = Color3.fromRGB(120, 200, 255)
local ICON = "🫧"

function BreathBar.new(parent: Instance): BreathBar
	local player = Players.LocalPlayer
	local root: Frame = UIUtil.make("Frame", {
		Name = "Breath",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET),
		Size = UDim2.fromOffset(Style.Size.HpWidth - 40, 28),
		BackgroundColor3 = Style.Color.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
	}, { UIUtil.corner(14), UIUtil.stroke() } :: { Instance })

	UIUtil.make("TextLabel", {
		Name = "Icon",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.fromOffset(26, 28),
		BackgroundTransparency = 1,
		Text = ICON,
		TextSize = Style.Text.Body,
		Font = Style.Font.Body,
		TextColor3 = Style.Color.Text,
		Parent = root,
	})
	local bar = UIUtil.bar(10, AIR_COLOR)
	bar.root.AnchorPoint = Vector2.new(0, 0.5)
	bar.root.Position = UDim2.new(0, 32, 0.5, 0)
	bar.root.Size = UDim2.new(1, -40, 0, 10)
	bar.root.Parent = root

	local label: TextLabel = UIUtil.make("TextLabel", {
		Name = "Warn",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.fromOffset(200, 22),
		BackgroundTransparency = 1,
		Text = "GET OUT OF THE WATER!",
		Font = Style.Font.Display,
		TextSize = Style.Text.Body,
		TextColor3 = Style.Color.Bad,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = root,
	})

	local function update()
		local rs = ReplicatedStorage:FindFirstChild(Contract.Folder.RoundState)
		local breath = player:GetAttribute(Attr.Breath)
		local show = typeof(breath) == "number"
			and breath < BREATH_MAX - 0.5
			and rs ~= nil
			and rs:GetAttribute(Attr.Phase) == Contract.Phase.Match
			and player:GetAttribute(Attr.State) == Contract.State.Standing
		root.Visible = show
		if not show then
			return
		end
		local alpha = (breath :: number) / BREATH_MAX
		local low = alpha <= LOW
		bar.set(alpha, if low then Style.Color.Bad else AIR_COLOR)
		label.Visible = low and (os.clock() % 0.6) < 0.4
	end

	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= REFRESH then
			acc = 0
			update()
		end
	end)

	return {
		root = root,
		destroy = function()
			conn:Disconnect()
			root:Destroy()
		end,
	}
end

return BreathBar
