--!strict
--[[
	HudToggle — hide/show the whole HUD for video recording (GDD 8.6.1).

	  PC:     H key (Style.Tuning.HudToggleKey = HUD_TOGGLE_KEY). Ignored while typing in chat.
	  Mobile: small round 👁 button, top-right, Style.Size.Touch (52 base px -> >= 44 px).
	          While the HUD is hidden the button fades to almost invisible so it does
	          not show up in recordings, but it stays tappable to bring the HUD back.

	Client only. Markers follow the same flag (MarkerController.setVisible).
]]

local UserInputService = game:GetService("UserInputService")

local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))
local Strings = require(script.Parent.Strings)
local Style = require(script.Parent.Style)
local UIUtil = require(script.Parent.UIUtil)

export type HudToggle = {
	isVisible: () -> boolean,
	setVisible: (visible: boolean) -> (),
	changed: Signal.Signal<boolean>,
	destroy: () -> (),
}

local HudToggle = {}

function HudToggle.new(topGui: ScreenGui): HudToggle
	local visible = true
	local changed = Signal.new() :: Signal.Signal<boolean>
	local connections: { RBXScriptConnection } = {}

	local button: TextButton = UIUtil.make("TextButton", {
		Name = "HudToggle",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Style.Size.Margin, 0, Style.Size.Margin),
		Size = UDim2.fromOffset(Style.Size.Touch, Style.Size.Touch),
		BackgroundColor3 = Style.Color.Panel,
		BackgroundTransparency = 0.2,
		AutoButtonColor = true,
		Text = Style.Icon.Eye,
		TextSize = Style.Text.Large,
		Font = Style.Font.Body,
		TextColor3 = Style.Color.Text,
		Visible = UserInputService.TouchEnabled,
		Parent = topGui,
	}, { UIUtil.corner(Style.Size.Touch // 2), UIUtil.stroke() } :: { Instance })
	-- Screen readers / tooltips on PC with touch screens.
	button:SetAttribute("Label", Strings.Text.HideHud)
	local buttonStroke = button:FindFirstChildWhichIsA("UIStroke")

	local function apply()
		button.BackgroundTransparency = if visible then 0.2 else 0.9
		button.TextTransparency = if visible then 0 else 0.75
		if buttonStroke then
			buttonStroke.Transparency = if visible then 0 else 0.85
		end
	end

	local function setVisible(v: boolean)
		if v == visible then
			return
		end
		visible = v
		apply()
		changed:Fire(visible)
	end

	table.insert(
		connections,
		button.Activated:Connect(function()
			setVisible(not visible)
		end)
	)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			if input.KeyCode == Style.Tuning.HudToggleKey then
				setVisible(not visible)
			end
		end)
	)
	-- Show the button if the device turns out to be touch-capable later (e.g. emulator switch).
	table.insert(
		connections,
		UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
			if inputType == Enum.UserInputType.Touch then
				button.Visible = true
			end
		end)
	)
	apply()

	return {
		isVisible = function(): boolean
			return visible
		end,
		setVisible = setVisible,
		changed = changed,
		destroy = function()
			for _, c in connections do
				c:Disconnect()
			end
			changed:DisconnectAll()
			button:Destroy()
		end,
	}
end

return HudToggle
