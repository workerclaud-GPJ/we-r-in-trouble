--!strict
--[[
	StatusOverlay — HUD #6: big center card for the local player's state (GDD 5.1–5.4).

	  Downed      purple tint, "Bonk!" / "Dizzy!", bleed-out bar; when a friend holds
	              revive: "A friend is helping you up!" + revive progress bar
	  Eliminated  grey-blue tint, "Poofed!", "Back in 12" respawn countdown
	  Escaped     small card "You escaped! Cheer on your friends!" (no tint)
	  Inactive    "Are you there? Move to rejoin!" (no tint)

	The card sits above screen center so it never covers the mobile thumbstick/jump.
]]

local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local StateAdapter = require(UI.StateAdapter)
local Strings = require(UI.Strings)
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

type Snapshot = StateAdapter.Snapshot

export type StatusOverlay = {
	root: Frame,
	update: (snap: Snapshot) -> (),
}

type Mode = "None" | "Downed" | "Poofed" | "Escaped" | "Inactive"

local T = Strings.Text
local V = StateAdapter.VALUES
local StatusOverlay = {}

function StatusOverlay.new(backParent: Instance, hudParent: Instance): StatusOverlay
	local tint: Frame = UIUtil.make("Frame", {
		Name = "StatusTint",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Style.Color.Dizzy,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = backParent,
	})

	local root = UIUtil.panel({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(Style.Size.OverlayWidth, 0),
		Visible = false,
		Parent = hudParent,
	})
	UIUtil.list(Style.Size.Gap, false, Enum.HorizontalAlignment.Center).Parent = root

	local kicker = UIUtil.label("", Style.Text.Body, {
		Name = "Kicker",
		LayoutOrder = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.TextDim,
		Parent = root,
	})
	local title = UIUtil.label("", Style.Text.Huge, {
		Name = "Title",
		LayoutOrder = 2,
		Font = Style.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.Accent,
		Parent = root,
	})
	local sub = UIUtil.label("", Style.Text.Body, {
		Name = "Sub",
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
	local bigNumber: TextLabel = UIUtil.make("TextLabel", {
		Name = "Countdown",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Text = "",
		Font = Style.Font.Number,
		TextSize = Style.Text.Huge,
		TextColor3 = Style.Color.Text,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = root,
	})
	local barHolder: Frame = UIUtil.make("Frame", {
		Name = "BarHolder",
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	local bar = UIUtil.bar(18, Style.Color.Warn)
	bar.root.Parent = barHolder

	local mode: Mode = "None"
	local bleedTotal = math.max(StateAdapter.Tuning.bleedOutTime, 1)

	local function setMode(newMode: Mode)
		if newMode == mode then
			return
		end
		mode = newMode
		local tinted = newMode == "Downed" or newMode == "Poofed"
		tint.Visible = tinted
		if tinted then
			tint.BackgroundColor3 = if newMode == "Downed" then Style.Color.Dizzy else Style.Color.Poof
			tint.BackgroundTransparency = 1
			TweenService:Create(tint, TweenInfo.new(0.35), { BackgroundTransparency = Style.Tuning.OverlayTint }):Play()
		end
		root.Visible = newMode ~= "None"
		if newMode ~= "None" then
			-- little pop-in so the state change is noticed
			root.Position = UDim2.fromScale(0.5, 0.32)
			TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5, 0.36),
			}):Play()
		end
	end

	local function updateDowned(snap: Snapshot)
		kicker.Text = T.DizzyTitle
		title.Text = T.Bonk
		title.TextColor3 = Style.Color.Dizzy
		bigNumber.Visible = false
		barHolder.Visible = true
		if snap.beingRevived then
			sub.Text = T.BeingRevived
			sub.TextColor3 = Style.Color.Good
			bar.set(snap.reviveProgress, Style.Color.Good)
			-- bleed-out is paused while Pinned; server re-publishes BleedOutEndsAt after
			return
		end
		sub.Text = T.DownedHelp
		sub.TextColor3 = Style.Color.Text
		if snap.bleedOutEndsAt then
			local remaining = math.max(0, snap.bleedOutEndsAt - snap.now)
			local alpha = remaining / bleedTotal
			bar.set(alpha, if alpha > 0.35 then Style.Color.Warn else Style.Color.Bad)
		else
			bar.set(1, Style.Color.Warn)
		end
	end

	local function updatePoofed(snap: Snapshot)
		kicker.Text = ""
		title.Text = T.PoofedTitle
		title.TextColor3 = Style.Color.Poof
		barHolder.Visible = false
		if snap.respawnAt then
			local remaining = snap.respawnAt - snap.now
			sub.Text = T.BackIn
			bigNumber.Text = UIUtil.secs(remaining)
			bigNumber.Visible = true
		else
			sub.Text = T.ComingBack
			bigNumber.Visible = false
		end
		sub.TextColor3 = Style.Color.Text
		kicker.Text = if #StateAdapter.spectateCandidates() > 0 then Style.Icon.Eye .. " " .. T.Spectating else ""
	end

	local function updateSimple(kick: string, titleText: string, subText: string, color: Color3)
		kicker.Text = kick
		title.Text = titleText
		title.TextColor3 = color
		sub.Text = subText
		sub.TextColor3 = Style.Color.Text
		bigNumber.Visible = false
		barHolder.Visible = false
	end

	local function update(snap: Snapshot)
		local newMode: Mode = "None"
		if snap.phase == "Match" then
			if snap.state == V.StateDowned then
				newMode = "Downed"
			elseif snap.state == V.StateEliminated then
				newMode = "Poofed"
			elseif snap.state == V.StateEscaped then
				newMode = "Escaped"
			elseif snap.inactive and snap.state == V.StateStanding then
				newMode = "Inactive"
			end
		end
		setMode(newMode)
		if newMode == "Downed" then
			updateDowned(snap)
		elseif newMode == "Poofed" then
			updatePoofed(snap)
		elseif newMode == "Escaped" then
			updateSimple("", T.EscapedTitle, T.EscapedSub, Style.Color.Good)
		elseif newMode == "Inactive" then
			updateSimple("", T.InactiveTitle, T.InactiveSub, Style.Color.Warn)
		end
		kicker.Visible = kicker.Text ~= ""
	end

	return { root = root, update = update }
end

return StatusOverlay
