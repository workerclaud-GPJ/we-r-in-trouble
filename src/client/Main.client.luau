--!strict
--[[
	Client entry point. Core controllers (movement, prompts, effects, activity, debug chat)
	then the UI (UIController hides the health bar and disables Reset — not duplicated here).
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local function start(module: Instance)
	local ok, err = pcall(function()
		(require(module :: ModuleScript) :: any).start()
	end)
	if not ok then
		warn(`[Client] {module.Name} failed to start:`, err)
	end
end

start(Controllers:WaitForChild("MovementController"))
start(Controllers:WaitForChild("PromptController"))
start(Controllers:WaitForChild("EffectsController"))
start(Controllers:WaitForChild("ToppleController"))
start(Controllers:WaitForChild("HazardFxController"))
start(Controllers:WaitForChild("ActivityController"))
start(Controllers:WaitForChild("DebugController"))
start(Controllers:WaitForChild("ProceduralAnimController"))
start(Controllers:WaitForChild("DashController"))

local ui = script.Parent:FindFirstChild("UI")
local uiController = ui and ui:FindFirstChild("UIController")
if uiController then
	start(uiController)
else
	warn("[Client] UI.UIController missing — HUD not started")
end
