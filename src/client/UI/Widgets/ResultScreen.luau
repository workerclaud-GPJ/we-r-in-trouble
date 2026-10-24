--!strict
--[[
	ResultScreen — HUD #8 (GDD 2.4): win/lose + reason, disaster, time, escaped list,
	my revives / dizzy count, "Back to the lobby in 12". Center, dimmed background.
	No buttons (auto-returns to lobby), so no touch targets needed.

	`update(snap, holdBack)`: holdBack = true while the win camera cinematic plays,
	so the panel appears only after the 3 s shot (GDD 8.6.1).
]]

local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local StateAdapter = require(UI.StateAdapter)
local Strings = require(UI.Strings)
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

type Snapshot = StateAdapter.Snapshot

export type ResultScreen = {
	root: Frame,
	update: (snap: Snapshot, holdBack: boolean) -> (),
}

local T = Strings.Text
local ResultScreen = {}

function ResultScreen.new(backParent: Instance, hudParent: Instance): ResultScreen
	local dim: Frame = UIUtil.make("Frame", {
		Name = "ResultDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Style.Color.Shade,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = false,
		Parent = backParent,
	})

	local root = UIUtil.panel({
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Style.Size.ResultWidth, 0),
		Visible = false,
		ZIndex = 5,
		Parent = hudParent,
	})
	UIUtil.list(Style.Size.Gap, false, Enum.HorizontalAlignment.Center).Parent = root
	local stroke = root:FindFirstChildWhichIsA("UIStroke")

	local function line(name: string, order: number, size: number, color: Color3?): TextLabel
		return UIUtil.label("", size, {
			Name = name,
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color or Style.Color.Text,
			Parent = root,
		})
	end

	local title = line("Title", 1, Style.Text.Huge)
	title.Font = Style.Font.Display
	local reason = line("Reason", 2, Style.Text.Body)
	UIUtil.make("Frame", {
		Name = "Divider",
		LayoutOrder = 3,
		Size = UDim2.new(0.8, 0, 0, 2),
		BackgroundColor3 = Style.Color.PanelLight,
		BorderSizePixel = 0,
		Parent = root,
	})
	local disaster = line("Disaster", 4, Style.Text.Body, Style.Color.TextDim)
	local timeLine = line("Time", 5, Style.Text.Body, Style.Color.TextDim)
	local escaped = line("Escaped", 6, Style.Text.Body)
	local stats = line("Stats", 7, Style.Text.Body, Style.Color.Accent)
	local back = line("Back", 8, Style.Text.Small, Style.Color.TextDim)

	local shown = false

	local function update(snap: Snapshot, holdBack: boolean)
		local show = snap.phase == "Result" and not holdBack
		dim.Visible = show
		root.Visible = show
		if not show then
			shown = false
			return
		end
		if not shown then
			shown = true
			root.Position = UDim2.fromScale(0.5, 0.56)
			TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5, 0.5),
			}):Play()
		end

		local win = snap.resultWin == true
		title.Text = if win then T.ResultWin else T.ResultLose
		title.TextColor3 = if win then Style.Color.Good else Style.Color.Bad
		if stroke then
			stroke.Color = if win then Style.Color.Good else Style.Color.Bad
		end
		reason.Text = if snap.resultReason then Strings.reason(snap.resultReason) else ""
		reason.Visible = snap.resultReason ~= nil

		local disasterName = snap.resultDisaster or snap.disasterName
		disaster.Visible = disasterName ~= nil
		disaster.Text = UIUtil.format(T.ResultDisaster, { v = disasterName or "" })

		timeLine.Visible = snap.resultTime ~= nil
		timeLine.Text = UIUtil.format(T.ResultTime, { v = UIUtil.clock(snap.resultTime or 0) })

		local names = if #snap.resultEscaped > 0 then table.concat(snap.resultEscaped, ", ") else T.ResultNobody
		escaped.Text = UIUtil.format(T.ResultEscaped, { v = names })

		stats.Visible = snap.reviveCount ~= nil or snap.downedCount ~= nil
		stats.Text = UIUtil.format(T.ResultStats, { r = snap.reviveCount or 0, d = snap.downedCount or 0 })

		local remaining = if snap.phaseEndsAt then snap.phaseEndsAt - snap.now else nil
		back.Visible = remaining ~= nil
		back.Text = UIUtil.format(T.BackToLobby, { t = UIUtil.secs(remaining or 0) })
	end

	return { root = root, update = update }
end

return ResultScreen
