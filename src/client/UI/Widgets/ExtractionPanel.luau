--!strict
--[[
	ExtractionPanel — HUD #7: rescue ETA, "get in" + inside count, departure countdown,
	pause, Last call (GDD 5.8). Lives in the top-center column under StageTimer.

	  exit open, carrier not here  -> "🚒 Rescue in 0:42" + ETA bar
	  carrier here, not counting   -> "Get in the carrier!"  "1/2 inside"
	  departure running            -> "Leaving in 7!"        "2/2 inside"
	  departure paused             -> "Wait! Everyone back in!"  "Leaving in 6 · 1/2 inside"
	  last call                    -> extra red line
	Pause is detected as: carrier here, not running, and DepartureRemaining > 0
	(ARCHITECTURE §3: valid once started, frozen while paused).
]]

local UI = script.Parent.Parent
local StateAdapter = require(UI.StateAdapter)
local Strings = require(UI.Strings)
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

type Snapshot = StateAdapter.Snapshot

export type ExtractionPanel = {
	root: Frame,
	update: (snap: Snapshot) -> (),
}

local T = Strings.Text
local ExtractionPanel = {}

function ExtractionPanel.new(parent: Instance): ExtractionPanel
	local root = UIUtil.panel({
		Name = "Extraction",
		Size = UDim2.fromOffset(Style.Size.PanelWidth + 40, 0),
		Visible = false,
		Parent = parent,
	})
	UIUtil.list(4, false, Enum.HorizontalAlignment.Center).Parent = root

	local title = UIUtil.label("", Style.Text.Large, {
		Name = "Title",
		LayoutOrder = 1,
		Font = Style.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.Exit,
		Parent = root,
	})
	local sub = UIUtil.label("", Style.Text.Body, {
		Name = "Sub",
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
	local barHolder: Frame = UIUtil.make("Frame", {
		Name = "BarHolder",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local bar = UIUtil.bar(12, Style.Color.Exit)
	bar.root.Parent = barHolder
	local lastCall = UIUtil.label(T.LastCall, Style.Text.Body, {
		Name = "LastCall",
		LayoutOrder = 4,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.Bad,
		Visible = false,
		Parent = root,
	})

	local etaTotal: number? = nil -- first ETA seen (ETA length lives in the mission def)
	local departTotal = math.max(StateAdapter.Tuning.departureCountdown, 1)

	local function insideText(snap: Snapshot): string
		return UIUtil.format(T.InsideCount, { n = snap.zoneCount, need = math.max(snap.zoneNeeded, 1) })
	end

	local function update(snap: Snapshot)
		local show = snap.phase == "Match" and snap.exitOpen and snap.state ~= StateAdapter.VALUES.StateLobby
		root.Visible = show
		if not show then
			etaTotal = nil
			return
		end

		lastCall.Visible = snap.lastCall

		if not snap.carrierArrived then
			local remaining = if snap.carrierArrivesAt then math.max(0, snap.carrierArrivesAt - snap.now) else nil
			title.Text = Style.Icon.Rescue
				.. " "
				.. UIUtil.format(T.RescueIn, { t = if remaining then UIUtil.clock(remaining) else "..." })
			title.TextColor3 = Style.Color.Exit
			sub.Text = T.RescueInSub
			barHolder.Visible = remaining ~= nil
			if remaining then
				if etaTotal == nil or remaining > (etaTotal :: number) then
					etaTotal = math.max(remaining, 1)
				end
				bar.set(1 - remaining / (etaTotal :: number), Style.Color.Exit)
			end
			return
		end

		if snap.departureRunning and snap.departureEndsAt then
			local remaining = math.max(0, snap.departureEndsAt - snap.now)
			title.Text = UIUtil.format(T.LeavingIn, { t = UIUtil.secs(remaining) })
			title.TextColor3 = Style.Color.Good
			sub.Text = insideText(snap)
			barHolder.Visible = true
			bar.set(1 - remaining / departTotal, Style.Color.Good)
		elseif snap.departureRemaining and snap.departureRemaining > 0 then
			title.Text = T.Paused
			title.TextColor3 = Style.Color.Warn
			sub.Text = UIUtil.format(T.PausedSub, {
				t = UIUtil.secs(snap.departureRemaining),
				n = snap.zoneCount,
				need = math.max(snap.zoneNeeded, 1),
			})
			barHolder.Visible = true
			bar.set(1 - snap.departureRemaining / departTotal, Style.Color.Warn)
		else
			title.Text = T.CarrierHere
			title.TextColor3 = Style.Color.Exit
			sub.Text = insideText(snap)
			barHolder.Visible = false
		end
	end

	return { root = root, update = update }
end

return ExtractionPanel
