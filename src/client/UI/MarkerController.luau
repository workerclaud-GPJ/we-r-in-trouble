--!strict
--[[
	MarkerController — HUD #3 + #4 (GDD 8.6): world markers drawn as BillboardGuis
	(AlwaysOnTop, visible through walls) with distance.

	Targets come from StateAdapter.markerTargets(snap):
	  Objective  anchors/sockets of the CURRENT step that are open and not done.
	             Shows progress bar, "Held 1/2", "2/3", "Override engaged", and for
	             MultiHold spots "Spot A: free/taken" (HUD #4 anchor billboard).
	  Exit       Exit Zone after the exit unlocks ("Escape!").
	  Downed     teammates who are dizzy ("Mochi is dizzy!" + revive progress).
	Items (batteries) intentionally have no marker (GDD 3.4 Deliver: search by light/sound).

	When the player is closer than Style.Tuning.MarkerNearDistance the marker goes
	compact (icon + bar only) so it does not cover the ProximityPrompt.
	setVisible(false) hides every marker (H key / HUD toggle).
]]

local Players = game:GetService("Players")

local StateAdapter = require(script.Parent.StateAdapter)
local Strings = require(script.Parent.Strings)
local Style = require(script.Parent.Style)
local UIUtil = require(script.Parent.UIUtil)

type Snapshot = StateAdapter.Snapshot
type MarkerTarget = StateAdapter.MarkerTarget

export type MarkerController = {
	update: (snap: Snapshot) -> (),
	setVisible: (visible: boolean) -> (),
	setScale: (scale: number) -> (),
	destroy: () -> (),
}

type Marker = {
	gui: BillboardGui,
	scale: UIScale,
	icon: TextLabel,
	iconBg: Frame,
	label: TextLabel,
	detail: TextLabel,
	bar: UIUtil.Bar,
	barHolder: Frame,
	textHolder: Frame,
	target: MarkerTarget,
}

local T = Strings.Text
local MarkerController = {}

local localPlayer = Players.LocalPlayer

local function kindColor(target: MarkerTarget): Color3
	if target.kind == "Exit" then
		return Style.Color.Exit
	elseif target.kind == "Downed" then
		return Style.Color.Dizzy
	end
	return Style.Color.Accent
end

local function kindIcon(target: MarkerTarget): string
	if target.kind == "Exit" then
		return Style.Icon.Exit
	elseif target.kind == "Downed" then
		return Style.Icon.Downed
	end
	return Style.Icon[target.objectiveKind or ""] or Style.Icon.Objective
end

local function newMarker(parent: Instance, target: MarkerTarget, scaleValue: number, visible: boolean): Marker
	local w, h = Style.Size.BillboardWidth, Style.Size.BillboardHeight
	local gui: BillboardGui = UIUtil.make("BillboardGui", {
		Name = "Marker_" .. target.kind,
		Adornee = target.adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = math.huge,
		Size = UDim2.fromOffset(w * scaleValue, h * scaleValue),
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
		ResetOnSpawn = false,
		ClipsDescendants = false,
		Enabled = visible,
		Parent = parent,
	})
	-- Billboard content is laid out at base size inside a frame scaled by UIScale.
	local content: Frame = UIUtil.make("Frame", {
		Name = "Content",
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local scale: UIScale = UIUtil.make("UIScale", { Scale = scaleValue, Parent = content })

	local iconBg: Frame = UIUtil.make("Frame", {
		Name = "IconBg",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(Style.Size.Badge - 8, Style.Size.Badge - 8),
		BackgroundColor3 = Style.Color.Panel,
		BorderSizePixel = 0,
		Parent = content,
	}, { UIUtil.corner(20), UIUtil.stroke(kindColor(target), 3) } :: { Instance })
	local icon: TextLabel = UIUtil.make("TextLabel", {
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = kindIcon(target),
		TextSize = Style.Text.Large,
		Font = Style.Font.Body,
		TextColor3 = Style.Color.Text,
		Parent = iconBg,
	})

	local textHolder: Frame = UIUtil.make("Frame", {
		Name = "Text",
		Position = UDim2.fromOffset(0, Style.Size.Badge - 6),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local label: TextLabel = UIUtil.make("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "",
		Font = Style.Font.Display,
		TextSize = Style.Text.Small,
		TextColor3 = kindColor(target),
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = textHolder,
	})
	local detail: TextLabel = UIUtil.make("TextLabel", {
		Name = "Detail",
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		Font = Style.Font.Body,
		TextSize = 15,
		TextColor3 = Style.Color.Text,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = textHolder,
	})

	local barHolder: Frame = UIUtil.make("Frame", {
		Name = "BarHolder",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.7, 0, 0, 8),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = content,
	})
	local bar = UIUtil.bar(8, kindColor(target))
	bar.root.Parent = barHolder

	return {
		gui = gui,
		scale = scale,
		icon = icon,
		iconBg = iconBg,
		label = label,
		detail = detail,
		bar = bar,
		barHolder = barHolder,
		textHolder = textHolder,
		target = target,
	}
end

local function observerPosition(): Vector3?
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

local function fill(marker: Marker, target: MarkerTarget, observer: Vector3?)
	marker.target = target
	marker.gui.Adornee = target.adornee
	marker.icon.Text = kindIcon(target)

	local distance = if observer then (target.adornee.Position - observer).Magnitude else nil
	local near = distance ~= nil and distance < Style.Tuning.MarkerNearDistance
	local distText = if distance then UIUtil.format(T.Distance, { d = math.floor(distance + 0.5) }) else ""

	local parts: { string } = {}
	local barAlpha: number? = nil
	local barColor = kindColor(target)

	if target.kind == "Exit" then
		marker.label.Text = T.MarkerExit
	elseif target.kind == "Downed" then
		marker.label.Text = UIUtil.format(T.MarkerDowned, { name = target.label })
		table.insert(parts, T.MarkerHelp)
		if target.progress and target.progress > 0 then
			barAlpha = target.progress
			barColor = Style.Color.Good
		end
	else
		marker.label.Text = Strings.objective(target.label)
		if target.count ~= nil and target.count > 0 then
			local delivered = target.delivered or 0
			table.insert(parts, UIUtil.format(T.DeliverCount, { n = delivered, count = target.count }))
			barAlpha = delivered / target.count
		elseif target.required ~= nil then
			local held = target.held or 0
			table.insert(parts, UIUtil.format(T.Held, { held = held, required = target.required }))
			if target.anchorPart and target.occupied ~= nil then
				table.insert(
					parts,
					UIUtil.format(if target.occupied then T.SpotTaken else T.SpotFree, { part = target.anchorPart })
				)
			end
			barAlpha = target.progress or 0
			if held >= target.required then
				barColor = Style.Color.Good
			end
		else
			barAlpha = target.progress or 0
		end
		if target.override and target.baseRequired and target.required then
			table.insert(parts, UIUtil.format(T.Override, { required = target.required, base = target.baseRequired }))
		end
	end
	if distText ~= "" then
		table.insert(parts, distText)
	end

	marker.detail.Text = table.concat(parts, "  ·  ")
	marker.textHolder.Visible = not near
	marker.barHolder.Visible = barAlpha ~= nil
	if barAlpha then
		marker.bar.set(barAlpha, barColor)
	end
end

function MarkerController.new(): MarkerController
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("WRIT_Markers")
	if old then
		old:Destroy()
	end
	-- Plain Folder in PlayerGui: BillboardGuis render from here (each has
	-- ResetOnSpawn = false, so LoadCharacter does not wipe them).
	local holder: Folder = UIUtil.make("Folder", {
		Name = "WRIT_Markers",
		Parent = playerGui,
	})

	local markers: { [Instance]: Marker } = {}
	local visible = true
	local currentScale = 1
	local lastRefresh = -math.huge
	local targets: { MarkerTarget } = {}

	local function update(snap: Snapshot)
		local now = os.clock()
		if now - lastRefresh >= Style.Tuning.MarkerRefresh then
			lastRefresh = now
			targets = StateAdapter.markerTargets(snap)
		end
		local observer = observerPosition()
		local seen: { [Instance]: boolean } = {}
		for _, target in targets do
			if not target.adornee.Parent then
				continue
			end
			local marker = markers[target.key]
			if not marker then
				marker = newMarker(holder, target, currentScale, visible)
				markers[target.key] = marker
			end
			fill(marker :: Marker, target, observer)
			seen[target.key] = true
		end
		for key, marker in markers do
			if not seen[key] then
				marker.gui:Destroy()
				markers[key] = nil
			end
		end
	end

	local function setVisible(v: boolean)
		visible = v
		for _, marker in markers do
			marker.gui.Enabled = v
		end
	end

	local function setScale(s: number)
		if s == currentScale then
			return
		end
		currentScale = s
		for _, marker in markers do
			marker.scale.Scale = s
			marker.gui.Size = UDim2.fromOffset(Style.Size.BillboardWidth * s, Style.Size.BillboardHeight * s)
		end
	end

	local function destroy()
		holder:Destroy()
		table.clear(markers)
	end

	return { update = update, setVisible = setVisible, setScale = setScale, destroy = destroy }
end

return MarkerController
