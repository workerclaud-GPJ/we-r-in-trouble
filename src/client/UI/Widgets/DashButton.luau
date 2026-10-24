--!strict
--[[
	DashButton — round dash button + cooldown (bottom-right; above the jump button on touch).
	Click / tap = DashController.request(). Cooldown: dark fill shrinking from the top +
	seconds left; gold ring when ready. Key hint "Q" on keyboard devices.
	Visible in Lobby and while Standing. Self-contained 10 Hz refresh (like BreathBar).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UI = script.Parent.Parent
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)
local DashController = require(UI.Parent.Controllers.DashController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local Attr = Contract.Attr

export type DashButton = {
	root: TextButton,
	destroy: () -> (),
}

local DashButton = {}

local SIZE = 64
-- Touch layout: keep clear of Roblox's jump button (tablets: jump covers y -210..-90).
local SMALL_SCREEN_MAX = 500 -- viewport short side (px) at or below = small phone
local TOUCH_Y_SMALL = -100
local TOUCH_Y_LARGE = -220
local DESKTOP_Y = -24
local REFRESH = 0.1
local ICON = "💨"

function DashButton.new(parent: Instance): DashButton
	local player = Players.LocalPlayer
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local ring = UIUtil.stroke(Style.Color.Accent, Style.Size.Stroke)
	local root: TextButton = UIUtil.make("TextButton", {
		Name = "Dash",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, DESKTOP_Y),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Style.Color.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		Visible = false,
		Parent = parent,
	}, { UIUtil.corner(SIZE // 2), ring } :: { Instance })

	UIUtil.make("TextLabel", {
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = ICON,
		TextSize = 30,
		Font = Style.Font.Body,
		TextColor3 = Style.Color.Text,
		Parent = root,
	})
	local shade: Frame = UIUtil.make("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Style.Color.Shade,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = root,
	}, { UIUtil.corner(SIZE // 2) :: Instance })
	local secs: TextLabel = UIUtil.make("TextLabel", {
		Name = "Secs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = Style.Text.Large,
		Font = Style.Font.Number,
		TextColor3 = Style.Color.Text,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.2,
		ZIndex = 3,
		Parent = root,
	})
	UIUtil.make("TextLabel", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(20, 16),
		BackgroundTransparency = 1,
		Text = "Q",
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
		DashController.request()
	end)

	local function place()
		local y = DESKTOP_Y
		if touch then
			local cam = Workspace.CurrentCamera
			local vp = if cam then cam.ViewportSize else Vector2.new(1000, 1000)
			y = if math.min(vp.X, vp.Y) <= SMALL_SCREEN_MAX then TOUCH_Y_SMALL else TOUCH_Y_LARGE
		end
		local pos = UDim2.new(1, -24, 1, y)
		if root.Position ~= pos then
			root.Position = pos
		end
	end

	local function update()
		place()
		local state = player:GetAttribute(Attr.State)
		local show = state == Contract.State.Standing or state == Contract.State.Lobby
		root.Visible = show
		if not show then
			return
		end
		local left = DashController.readyAt() - Workspace:GetServerTimeNow()
		if left > 0 then
			shade.Size = UDim2.fromScale(1, math.clamp(left / Config.Player.DASH_COOLDOWN, 0, 1))
			secs.Text = UIUtil.secs(left)
			ring.Color = Style.Color.Outline
		else
			shade.Size = UDim2.fromScale(1, 0)
			secs.Text = ""
			ring.Color = if DashController.allowedNow() then Style.Color.Accent else Style.Color.Outline
		end
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

return DashButton
