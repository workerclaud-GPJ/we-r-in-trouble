--!strict
--[[
	ObjectiveList — HUD #2: "Step 1/2" header + one row per objective with progress.
	Top-left panel.

	Row status text by kind (GDD 3.4):
	  Repair     "62%"           + bar
	  Deliver    "2/3"           + bar   (batteries x/N)
	  MultiHold  "Held 1/2"      + bar   (+ "Override engaged: 3 of 4 needed")
	  done       "Done!" (green ✅), locked (future step) "Locked" (dim 🔒)
	After the last step: "All done. Escape!". "Last chance!" line while the server's
	LastChance attribute is true (5:20+, last step not done; ARCHITECTURE §3).
]]

local UI = script.Parent.Parent
local StateAdapter = require(UI.StateAdapter)
local Strings = require(UI.Strings)
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

type Snapshot = StateAdapter.Snapshot
type Objective = StateAdapter.Objective

export type ObjectiveList = {
	root: Frame,
	update: (snap: Snapshot) -> (),
}

type Row = {
	frame: Frame,
	icon: TextLabel,
	name: TextLabel,
	status: TextLabel,
	bar: UIUtil.Bar,
	barHolder: Frame,
	extra: TextLabel,
}

local T = Strings.Text
local ObjectiveList = {}

local function newRow(parent: Instance): Row
	local frame: Frame = UIUtil.make("Frame", {
		Name = "Row",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	}, { UIUtil.list(3) :: Instance })

	local top: Frame = UIUtil.make("Frame", {
		Name = "Top",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local icon: TextLabel = UIUtil.make("TextLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = Style.Text.Body,
		Font = Style.Font.Body,
		TextColor3 = Style.Color.Text,
		Parent = top,
	})
	local name: TextLabel = UIUtil.label("", Style.Text.Body, {
		Name = "Name",
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -110, 1, 0),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = top,
	})
	local status: TextLabel = UIUtil.label("", Style.Text.Body, {
		Name = "Status",
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 80, 1, 0),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Style.Font.Number,
		Parent = top,
	})

	local bar = UIUtil.bar(10, Style.Color.Accent)
	bar.root.Size = UDim2.new(1, -30, 0, 10)
	local barHolder: Frame = UIUtil.make("Frame", {
		Name = "BarHolder",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	bar.root.Position = UDim2.fromOffset(30, 0)
	bar.root.Parent = barHolder

	local extra: TextLabel = UIUtil.label("", Style.Text.Small, {
		Name = "Extra",
		LayoutOrder = 3,
		TextColor3 = Style.Color.Warn,
		Visible = false,
		Parent = frame,
	})
	return { frame = frame, icon = icon, name = name, status = status, bar = bar, barHolder = barHolder, extra = extra }
end

local function kindIcon(kind: string): string
	return Style.Icon[kind] or Style.Icon.Objective
end

local function fillRow(row: Row, o: Objective)
	local displayName = Strings.objective(o.name)
	if o.optional then
		displayName ..= " " .. T.Bonus
	end
	row.name.Text = displayName
	row.extra.Visible = false

	if o.done then
		row.icon.Text = Style.Icon.Done
		row.status.Text = T.Done
		row.status.TextColor3 = Style.Color.Good
		row.name.TextColor3 = Style.Color.TextDim
		row.barHolder.Visible = false
		return
	end
	if o.locked then
		row.icon.Text = "🔒"
		row.status.Text = T.Locked
		row.status.TextColor3 = Style.Color.TextDim
		row.name.TextColor3 = Style.Color.TextDim
		row.barHolder.Visible = false
		return
	end

	row.icon.Text = kindIcon(o.kind)
	row.name.TextColor3 = Style.Color.Text
	row.status.TextColor3 = Style.Color.Accent
	row.barHolder.Visible = true

	if o.count ~= nil and o.count > 0 then
		local delivered = o.delivered or 0
		row.status.Text = UIUtil.format(T.DeliverCount, { n = delivered, count = o.count })
		row.bar.set(delivered / o.count, Style.Color.Accent)
	elseif o.required ~= nil then
		local held = o.held or 0
		row.status.Text = UIUtil.format(T.Held, { held = held, required = o.required })
		row.status.TextColor3 = if held >= o.required then Style.Color.Good else Style.Color.Warn
		row.bar.set(o.progress, if held >= o.required then Style.Color.Good else Style.Color.Accent)
		if o.override and o.baseRequired then
			row.extra.Text = UIUtil.format(T.Override, { required = o.required, base = o.baseRequired })
			row.extra.Visible = true
		end
	else
		row.status.Text = UIUtil.format(T.Percent, { p = math.floor(o.progress * 100 + 0.5) })
		row.bar.set(o.progress, Style.Color.Accent)
	end
end

-- GDD 2.2: warn when the last step is still open close to the unlock deadline.
local function lastChanceActive(snap: Snapshot): boolean
	return snap.lastChance == true and not snap.exitOpen
end
ObjectiveList.lastChanceActive = lastChanceActive

function ObjectiveList.new(parent: Instance): ObjectiveList
	local root = UIUtil.panel({
		Name = "Objectives",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(Style.Size.Margin, Style.Size.Margin),
		Size = UDim2.fromOffset(Style.Size.PanelWidth, 0),
		Visible = false,
		Parent = parent,
	})
	UIUtil.list(Style.Size.Gap).Parent = root

	local header = UIUtil.label("", Style.Text.Large, {
		Name = "Header",
		LayoutOrder = 1,
		Font = Style.Font.Display,
		TextColor3 = Style.Color.Accent,
		Parent = root,
	})
	local sub = UIUtil.label("", Style.Text.Small, {
		Name = "Sub",
		LayoutOrder = 2,
		TextColor3 = Style.Color.TextDim,
		Parent = root,
	})
	local rowsHolder: Frame = UIUtil.make("Frame", {
		Name = "Rows",
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { UIUtil.list(8) :: Instance })
	local warning = UIUtil.label(T.LastChance, Style.Text.Body, {
		Name = "LastChance",
		LayoutOrder = 4,
		TextColor3 = Style.Color.Bad,
		Visible = false,
		Parent = root,
	})

	local rows: { [string]: Row } = {}

	local function update(snap: Snapshot)
		local show = snap.phase == "Match" and snap.state ~= StateAdapter.VALUES.StateLobby
		root.Visible = show
		if not show then
			return
		end

		local allDone = snap.exitOpen or (snap.stepCount > 0 and snap.stepIndex > snap.stepCount)
		rowsHolder.Visible = not snap.explore
		if snap.explore and not allDone then
			header.Text = "Escape the kitchen!"
			sub.Text = "Explore and find a way out · B = item book"
			return
		elseif allDone then
			header.Text = T.AllStepsDone
			sub.Text = T.FollowMarkers
		else
			local stepText = UIUtil.format(T.StepHeader, { i = snap.stepIndex, n = math.max(snap.stepCount, 1) })
			header.Text = if snap.stepName then stepText .. ": " .. Strings.objective(snap.stepName) else stepText
			sub.Text = T.FollowMarkers
		end

		-- Show current-step objectives in full; future steps as locked rows.
		-- Completed earlier steps are dropped to keep the panel short on phones.
		local seen: { [string]: boolean } = {}
		local order = 0
		for _, o in snap.objectives do
			local isPast = o.done and o.step < snap.stepIndex
			if isPast or allDone then
				continue
			end
			order += 1
			local row = rows[o.id]
			if not row then
				row = newRow(rowsHolder)
				rows[o.id] = row
			end
			local r = row :: Row
			r.frame.LayoutOrder = order
			fillRow(r, o)
			seen[o.id] = true
		end
		for id, row in rows do
			if not seen[id] then
				row.frame:Destroy()
				rows[id] = nil
			end
		end

		warning.Visible = not allDone and lastChanceActive(snap)
	end

	return { root = root, update = update }
end

return ObjectiveList
