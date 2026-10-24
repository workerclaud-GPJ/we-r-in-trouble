--!strict
--[[
	Banner — short announcement in the upper middle of the screen
	("EARTHQUAKE!", "Step complete!", "The window is open!", "Last call!" ...).

	push(item)        queue a banner (identical text already queued/showing is ignored)
	pushUrgent(item)  drop the queue and show this now (e.g. exit unlocked)
	item.key          optional id (HudBanner keys: BannerStepComplete, Disaster, ...).
	                  A key shown in the last KEY_MEMORY seconds is ignored, so the
	                  server remote and the HUD's own state-derived banners never double up.
	Each banner shows for item.duration (default Style.Tuning.BannerTime = 3 s,
	>= WARNING_BANNER_MIN, GDD 4.1).
]]

local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

export type BannerItem = {
	key: string?,
	text: string,
	sub: string?,
	color: Color3?,
	duration: number?,
}

export type Banner = {
	root: Frame,
	push: (item: BannerItem) -> (),
	pushUrgent: (item: BannerItem) -> (),
	clear: () -> (),
}

local MAX_QUEUE = 4
local KEY_MEMORY = 8 -- s
local Banner = {}

function Banner.new(parent: Instance): Banner
	local root: Frame = UIUtil.make("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.fromOffset(Style.Size.BannerWidth, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Style.Color.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
		Parent = parent,
	}, {
		UIUtil.corner(),
		UIUtil.stroke(Style.Color.Accent, 4),
		UIUtil.padding(12),
		UIUtil.list(2, false, Enum.HorizontalAlignment.Center),
	} :: { Instance })
	local stroke = root:FindFirstChildWhichIsA("UIStroke") :: UIStroke
	local scale: UIScale = UIUtil.make("UIScale", { Parent = root })

	local title = UIUtil.label("", Style.Text.Title, {
		Name = "Title",
		LayoutOrder = 1,
		Font = Style.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.Accent,
		ZIndex = 4,
		Parent = root,
	})
	local sub = UIUtil.label("", Style.Text.Body, {
		Name = "Sub",
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = root,
	})

	local queue: { BannerItem } = {}
	local recentKeys: { [string]: number } = {}

	-- true if this key was already accepted recently (and remember it otherwise)
	local function seenKey(item: BannerItem): boolean
		local key = item.key
		if not key then
			return false
		end
		local now = os.clock()
		local last = recentKeys[key]
		if last and now - last < KEY_MEMORY then
			return true
		end
		recentKeys[key] = now
		return false
	end
	local current: BannerItem? = nil
	local token = 0

	local showNext: () -> ()

	local function display(item: BannerItem)
		current = item
		token += 1
		local myToken = token
		local color = item.color or Style.Color.Accent
		title.Text = item.text
		title.TextColor3 = color
		stroke.Color = color
		sub.Text = item.sub or ""
		sub.Visible = item.sub ~= nil and item.sub ~= ""
		root.Visible = true
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		task.delay(item.duration or Style.Tuning.BannerTime, function()
			if myToken ~= token then
				return
			end
			current = nil
			root.Visible = false
			showNext()
		end)
	end

	showNext = function()
		local nextItem = table.remove(queue, 1)
		if nextItem then
			display(nextItem)
		end
	end

	local function push(item: BannerItem)
		if seenKey(item) then
			return
		end
		if current and current.text == item.text then
			return
		end
		for _, q in queue do
			if q.text == item.text then
				return
			end
		end
		if #queue >= MAX_QUEUE then
			table.remove(queue, 1)
		end
		table.insert(queue, item)
		if not current then
			showNext()
		end
	end

	local function pushUrgent(item: BannerItem)
		if seenKey(item) then
			return
		end
		table.clear(queue)
		display(item)
	end

	local function clear()
		table.clear(queue)
		token += 1
		current = nil
		root.Visible = false
	end

	return { root = root, push = push, pushUrgent = pushUrgent, clear = clear }
end

return Banner
