--!strict
--[[
	UIController — single entry point for all client UI.

	Usage (src/client/Main.client.luau):
		require(script.Parent.UI.UIController).start()

	start() is safe to call more than once (second call is ignored). It:
	  1. hides Roblox's default health bar (we show game HP from the HP attribute)
	     and disables the Reset button (GDD 5.2; retried with pcall until SetCore is ready),
	  2. builds the HUD (HudController: widgets, banners, markers, H-key toggle,
	     win camera, spectate camera) and starts its 10 Hz refresh.
	All server state is read through StateAdapter (names listed there).
]]

local StarterGui = game:GetService("StarterGui")

local HudController = require(script.Parent.HudController)
local BreathBar = require(script.Parent.Widgets.BreathBar)
local DashButton = require(script.Parent.Widgets.DashButton)

local UIController = {}

local started = false
local breathBar: BreathBar.BreathBar? = nil
local dashButton: DashButton.DashButton? = nil
local hud: HudController.HudController? = nil

local SETCORE_RETRIES = 20
local SETCORE_RETRY_WAIT = 0.5

local function setupCoreGui()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	-- SetCore may not be registered yet right after join: retry until it works.
	task.spawn(function()
		for _ = 1, SETCORE_RETRIES do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
			if ok then
				return
			end
			task.wait(SETCORE_RETRY_WAIT)
		end
		warn("[UI] could not disable the Reset button")
	end)
end

function UIController.start()
	if started then
		return
	end
	started = true
	setupCoreGui()
	hud = HudController.new()
	local hudGui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("WRIT_Hud")
	breathBar = if hudGui then BreathBar.new(hudGui) else nil
	dashButton = if hudGui then DashButton.new(hudGui) else nil
end

-- For tests / Studio hot reload only.
function UIController.stop()
	if hud then
		hud.destroy()
		hud = nil
	end
	if breathBar then
		breathBar.destroy()
		breathBar = nil
	end
	if dashButton then
		dashButton.destroy()
		dashButton = nil
	end
	started = false
end

return UIController
