--!strict
--[[
	HealthBar — HUD #5: game HP (Player attribute HP, NOT Humanoid.Health; GDD 5.2).
	Bottom-center, between the mobile thumbstick (left) and jump button (right).
	On damage: the bar wobbles + a "Bonk!" pop (no red screen, no blood; GDD 5.2).
]]

local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local StateAdapter = require(UI.StateAdapter)
local Strings = require(UI.Strings)
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

type Snapshot = StateAdapter.Snapshot

export type HealthBar = {
	root: Frame,
	update: (snap: Snapshot) -> (),
}

local HealthBar = {}

local BOTTOM_OFFSET = 24 -- base px above the bottom safe edge

function HealthBar.new(parent: Instance): HealthBar
	local root: Frame = UIUtil.make("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET),
		Size = UDim2.fromOffset(Style.Size.HpWidth, 40),
		BackgroundColor3 = Style.Color.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
	}, { UIUtil.corner(20), UIUtil.stroke() } :: { Instance })

	UIUtil.make("TextLabel", {
		Name = "Icon",
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.fromOffset(32, 40),
		BackgroundTransparency = 1,
		Text = Style.Icon.Hp,
		TextSize = Style.Text.Large,
		Font = Style.Font.Body,
		TextColor3 = Style.Color.Text,
		Parent = root,
	})
	local bar = UIUtil.bar(16, Style.Color.Good)
	bar.root.AnchorPoint = Vector2.new(0, 0.5)
	bar.root.Position = UDim2.new(0, 42, 0.5, 0)
	bar.root.Size = UDim2.new(1, -96, 0, 16)
	bar.root.Parent = root

	local value: TextLabel = UIUtil.make("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(44, 40),
		BackgroundTransparency = 1,
		Text = "100",
		Font = Style.Font.Number,
		TextSize = Style.Text.Body,
		TextColor3 = Style.Color.Text,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = root,
	})

	local pop: TextLabel = UIUtil.make("TextLabel", {
		Name = "Bonk",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(160, 36),
		BackgroundTransparency = 1,
		Text = Strings.Text.Bonk,
		Font = Style.Font.Display,
		TextSize = Style.Text.Title,
		TextColor3 = Style.Color.Warn,
		TextStrokeColor3 = Style.Color.Outline,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})

	local lastHp: number? = nil
	local shakeToken = 0

	local function onDamage()
		shakeToken += 1
		local token = shakeToken
		task.spawn(function()
			for i = 1, 6 do
				if token ~= shakeToken then
					return
				end
				local dx = (if i % 2 == 0 then 1 else -1) * (7 - i)
				root.Position = UDim2.new(0.5, dx, 1, -BOTTOM_OFFSET)
				task.wait(0.03)
			end
			root.Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET)
		end)
		pop.TextTransparency = 0
		pop.TextStrokeTransparency = 0
		pop.Position = UDim2.new(0.5, 0, 0, -4)
		TweenService:Create(pop, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, -28),
		}):Play()
	end

	local function update(snap: Snapshot)
		local show = snap.phase == "Match" and snap.state == StateAdapter.VALUES.StateStanding
		root.Visible = show
		if not show then
			lastHp = nil
			return
		end
		local maxHp = math.max(snap.maxHp, 1)
		local alpha = snap.hp / maxHp
		local color = if alpha > 0.5 then Style.Color.Good elseif alpha > 0.25 then Style.Color.Warn else Style.Color.Bad
		bar.set(alpha, color)
		value.Text = tostring(math.max(0, math.ceil(snap.hp)))
		if lastHp and snap.hp < lastHp - 0.5 then
			onDamage()
		end
		lastHp = snap.hp
	end

	return { root = root, update = update }
end

return HealthBar
