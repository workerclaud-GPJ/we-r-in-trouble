--!strict
--[[
	HudRoot — creates the ScreenGuis the HUD lives in and keeps the UIScale
	matched to the screen size (mobile scaling).

	Layers (DisplayOrder):
	  WRIT_HudBack (5)   full-screen tints (Downed / Poofed / Result dim), ignores insets
	  WRIT_Hud     (10)  all HUD widgets, inside CoreUISafeInsets (clear of topbar + notch)
	  WRIT_HudTop  (20)  the hide/show toggle button (never hidden by the toggle itself)

	Layout uses Scale anchors (AnchorPoint + UDim2 scale positions) so elements stick
	to screen edges; element sizes are base pixels multiplied by a UIScale:
	  hud scale = clamp(min(shortSide / RefShortSide, width / RefWidth), Min, Max)
	  top scale = max(hud scale, TouchMin)   -- toggle button stays >= 44 px
	Phone landscape 844x390 -> 0.75; small phone 667x375 -> 0.7; PC 720p+ -> 1.35.
]]

local Players = game:GetService("Players")

local Style = require(script.Parent.Style)
local UIUtil = require(script.Parent.UIUtil)

export type HudRoot = {
	back: ScreenGui,
	hud: ScreenGui,
	top: ScreenGui,
	scales: { UIScale },
	getScale: () -> number,
	setHudVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local HudRoot = {}

local function screenGui(name: string, order: number, fullScreen: boolean, parent: Instance): ScreenGui
	local gui: ScreenGui = UIUtil.make("ScreenGui", {
		Name = name,
		DisplayOrder = order,
		ResetOnSpawn = false, -- CharacterAutoLoads is off; LoadCharacter must not wipe the HUD
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = fullScreen,
		ScreenInsets = if fullScreen then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets,
		Parent = parent,
	})
	return gui
end

function HudRoot.new(): HudRoot
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Remove leftovers if the controller is ever restarted (Studio hot reload).
	for _, name in { "WRIT_HudBack", "WRIT_Hud", "WRIT_HudTop" } do
		local old = playerGui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local back = screenGui("WRIT_HudBack", 5, true, playerGui)
	local hud = screenGui("WRIT_Hud", 10, false, playerGui)
	local top = screenGui("WRIT_HudTop", 20, false, playerGui)

	local hudScale: UIScale = UIUtil.make("UIScale", { Parent = hud })
	local topScale: UIScale = UIUtil.make("UIScale", { Parent = top })
	local scales: { UIScale } = { hudScale, topScale }

	local current = 1
	local function computeScale(): number
		local camera = workspace.CurrentCamera
		if not camera then
			return 1
		end
		local size = camera.ViewportSize
		local shortest = math.min(size.X, size.Y)
		if shortest <= 0 then
			return 1
		end
		local raw = math.min(shortest / Style.Scale.RefShortSide, size.X / Style.Scale.RefWidth)
		return math.clamp(raw, Style.Scale.Min, Style.Scale.Max)
	end
	local function applyScale()
		current = computeScale()
		hudScale.Scale = current
		topScale.Scale = math.max(current, Style.Scale.TouchMin)
	end

	local connections: { RBXScriptConnection } = {}
	local viewportConn: RBXScriptConnection? = nil
	local function bindCamera()
		if viewportConn then
			viewportConn:Disconnect()
			viewportConn = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
		end
		applyScale()
	end
	table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	bindCamera()

	local self: HudRoot = {
		back = back,
		hud = hud,
		top = top,
		scales = scales,
		getScale = function(): number
			return current
		end,
		setHudVisible = function(visible: boolean)
			back.Enabled = visible
			hud.Enabled = visible
		end,
		destroy = function()
			for _, c in connections do
				c:Disconnect()
			end
			if viewportConn then
				viewportConn:Disconnect()
			end
			back:Destroy()
			hud:Destroy()
			top:Destroy()
		end,
	}
	return self
end

return HudRoot
