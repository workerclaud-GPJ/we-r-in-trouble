--!strict
--[[
	UIUtil — tiny helpers to build GUI in code (no hand-made ScreenGuis).

	make(className, props, children?) creates an Instance, applies props
	(Parent is applied last) and parents children to it.
]]

local Style = require(script.Parent.Style)

local UIUtil = {}

function UIUtil.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst: any = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				inst[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIUtil.corner(radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Style.Size.Corner)
	return c
end

function UIUtil.stroke(color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Style.Color.Outline
	s.Thickness = thickness or Style.Size.Stroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

function UIUtil.padding(px: number?): UIPadding
	local p = Instance.new("UIPadding")
	local u = UDim.new(0, px or Style.Size.Pad)
	p.PaddingTop = u
	p.PaddingBottom = u
	p.PaddingLeft = u
	p.PaddingRight = u
	return p
end

function UIUtil.list(gap: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap or Style.Size.Gap)
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return l
end

-- Rounded dark panel that grows with its content (AutomaticSize Y).
function UIUtil.panel(props: { [string]: any }?): Frame
	local frame: Frame = UIUtil.make("Frame", {
		BackgroundColor3 = Style.Color.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { UIUtil.corner(), UIUtil.stroke(), UIUtil.padding() } :: { Instance })
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(frame :: any)[key] = value
			end
		end
		if props.Parent then
			frame.Parent = props.Parent
		end
	end
	return frame
end

-- Outlined text label. High-contrast cream text with a dark text stroke.
function UIUtil.label(text: string, size: number?, props: { [string]: any }?): TextLabel
	local lbl: TextLabel = UIUtil.make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = Style.Font.Body,
		TextSize = size or Style.Text.Body,
		TextColor3 = Style.Color.Text,
		TextStrokeColor3 = Style.Color.Outline,
		TextStrokeTransparency = 0.35,
		TextWrapped = true,
		RichText = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(lbl :: any)[key] = value
			end
		end
		if props.Parent then
			lbl.Parent = props.Parent
		end
	end
	return lbl
end

export type Bar = {
	root: Frame,
	fill: Frame,
	set: (alpha: number, color: Color3?) -> (),
}

-- Horizontal progress bar (0..1). Width fills parent; height in px.
function UIUtil.bar(height: number?, color: Color3?): Bar
	local fill: Frame = UIUtil.make("Frame", {
		Name = "Fill",
		BackgroundColor3 = color or Style.Color.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, { UIUtil.corner(Style.Size.CornerSmall) :: Instance })
	local root: Frame = UIUtil.make("Frame", {
		Name = "Bar",
		BackgroundColor3 = Style.Color.BarBack,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or Style.Size.BarHeight),
	}, { UIUtil.corner(Style.Size.CornerSmall), UIUtil.stroke(Style.Color.Outline, 2), fill } :: { Instance })
	local function set(alpha: number, newColor: Color3?)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		if newColor then
			fill.BackgroundColor3 = newColor
		end
	end
	return { root = root, fill = fill, set = set }
end

-- "{name}" placeholder replacement.
function UIUtil.format(template: string, values: { [string]: any }): string
	return (string.gsub(template, "{(%w+)}", function(key: string): string
		local v = values[key]
		if v == nil then
			return "{" .. key .. "}"
		end
		return tostring(v)
	end))
end

-- 75 -> "1:15", 9.2 -> "0:10" (ceil so the timer never shows 0:00 while time remains)
function UIUtil.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- 9.2 -> "10" (big countdown digits)
function UIUtil.secs(seconds: number): string
	return tostring(math.max(0, math.ceil(seconds)))
end

return UIUtil
