--!strict
--[[
	StageTimer — HUD #1: stage pill (Calm/Warning/Danger/CRITICAL, GDD 4.1 colors)
	+ time left until Collapse. Top-center. Blinks red in Critical under 30 s.
	Also shows the disaster name under the pill once Warning has started.
]]

local UI = script.Parent.Parent
local StateAdapter = require(UI.StateAdapter)
local Strings = require(UI.Strings)
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

type Snapshot = StateAdapter.Snapshot

export type StageTimer = {
	root: Frame,
	update: (snap: Snapshot) -> (),
}

local StageTimer = {}

function StageTimer.new(parent: Instance): StageTimer
	local root: Frame = UIUtil.make("Frame", {
		Name = "StageTimer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Style.Size.Margin),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	}, { UIUtil.list(4, false, Enum.HorizontalAlignment.Center) :: Instance })

	local pill: Frame = UIUtil.make("Frame", {
		Name = "Pill",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Style.Color.Panel,
		BorderSizePixel = 0,
		Parent = root,
	}, {
		UIUtil.corner(22),
		UIUtil.stroke(),
		UIUtil.list(8, true, Enum.HorizontalAlignment.Center),
		UIUtil.make("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 14),
		}),
	} :: { Instance })

	local stageChip: TextLabel = UIUtil.make("TextLabel", {
		Name = "Stage",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Style.Color.Good,
		Text = "",
		Font = Style.Font.Display,
		TextSize = Style.Text.Body,
		TextColor3 = Style.Color.Outline,
		Parent = pill,
	}, {
		UIUtil.corner(15),
		UIUtil.make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	} :: { Instance })

	local timer: TextLabel = UIUtil.make("TextLabel", {
		Name = "Timer",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(78, 36),
		BackgroundTransparency = 1,
		Text = "0:00",
		Font = Style.Font.Number,
		TextSize = Style.Text.Title,
		TextColor3 = Style.Color.Text,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.3,
		Parent = pill,
	})

	local disaster: TextLabel = UIUtil.label("", Style.Text.Small, {
		Name = "Disaster",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.TextDim,
		Parent = root,
	})

	local function update(snap: Snapshot)
		local show = snap.phase == "Match" and snap.state ~= StateAdapter.VALUES.StateLobby
		root.Visible = show
		if not show then
			return
		end
		local color = Style.StageColor[snap.stage] or Style.Color.Good
		stageChip.Text = string.upper(Strings.stage(snap.stage))
		stageChip.BackgroundColor3 = color

		local remaining = if snap.matchEndsAt then snap.matchEndsAt - snap.now else nil
		timer.Text = if remaining then UIUtil.clock(remaining) else "--:--"
		local blink = snap.stage == "Critical"
			and remaining ~= nil
			and remaining < Style.Tuning.CriticalBlinkUnder
			and (math.floor(snap.now * 2) % 2 == 0)
		timer.TextColor3 = if blink then Style.Color.Bad else Style.Color.Text

		local showDisaster = snap.disasterName ~= nil and snap.stage ~= "Calm"
		disaster.Visible = showDisaster
		if showDisaster then
			disaster.Text = snap.disasterName :: string
		end
	end

	return { root = root, update = update }
end

return StageTimer
