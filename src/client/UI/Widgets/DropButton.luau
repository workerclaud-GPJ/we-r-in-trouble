--!strict
--[[
	DropButton — round "drop" button (left of the Dash button), visible only while you hold an
	item and are Standing. Click / tap = DropController.request(). Key hint "G" on keyboards.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UI = script.Parent.Parent
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)
local DropController = require(UI.Parent.Controllers.DropController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local Attr = Contract.Attr

export type DropButton = {
	root: TextButton,
	destroy: () -> (),
}

local DropButton = {}

local SIZE = 56
local DASH_SIZE = 64
-- same rows as DashButton, one button further left
local SMALL_SCREEN_MAX = 500
local TOUCH_Y_SMALL = -100
local TOUCH_Y_LARGE = -220
local DESKTOP_Y = -28
local X = -24 - DASH_SIZE - 14
local REFRESH = 0.1
local ICON = "⬇"

function DropButton.new(parent: Instance): DropButton
	local player = Players.LocalPlayer
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local root: TextButton = UIUtil.make("TextButton", {
		Name = "Drop",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, X, 1, DESKTOP_Y),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Style.Color.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		Visible = false,
		Parent = parent,
	}, { UIUtil.corner(SIZE // 2), UIUtil.stroke(Style.Color.Accent, Style.Size.Stroke) } :: { Instance })

	UIUtil.make("TextLabel", {
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = ICON,
		TextSize = 26,
		Font = Style.Font.Body,
		TextColor3 = Style.Color.Text,
		Parent = root,
	})
	UIUtil.make("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(SIZE, 14),
		BackgroundTransparency = 1,
		Text = "Drop",
		TextSize = 12,
		Font = Style.Font.Display,
		TextColor3 = Style.Color.Text,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.2,
		Parent = root,
	})
	UIUtil.make("TextLabel", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(20, 16),
		BackgroundTransparency = 1,
		Text = "G",
		TextSize = 14,
		Font = Style.Font.Display,
		TextColor3 = Style.Color.Accent,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.2,
		Visible = not touch,
		ZIndex = 4,
		Parent = root,
	})

	local pressConn = root.Activated:Connect(function()
		DropController.request()
	end)

	local function update()
		local y = DESKTOP_Y
		if touch then
			local cam = Workspace.CurrentCamera
			local vp = if cam then cam.ViewportSize else Vector2.new(1000, 1000)
			y = if math.min(vp.X, vp.Y) <= SMALL_SCREEN_MAX then TOUCH_Y_SMALL else TOUCH_Y_LARGE
			y -= (DASH_SIZE - SIZE) // 2
		end
		local pos = UDim2.new(1, X, 1, y)
		if root.Position ~= pos then
			root.Position = pos
		end
		root.Visible = player:GetAttribute(Attr.State) == Contract.State.Standing and DropController.isHolding()
	end

	local acc = REFRESH
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
			pressConn:Disconnect()
			root:Destroy()
		end,
	}
end

return DropButton
