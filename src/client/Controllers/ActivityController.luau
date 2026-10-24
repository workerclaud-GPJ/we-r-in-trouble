--!strict
-- ActivityController — sends ActivityPing on any input, throttled (GDD 5.9, Lobby AFK).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ActivityController = {}

function ActivityController.start()
	local remote = Remotes.get("ActivityPing")
	local last = -math.huge
	UserInputService.InputBegan:Connect(function()
		local t = os.clock()
		if t - last >= Config.Round.ACTIVITY_PING_CLIENT_INTERVAL then
			last = t
			remote:FireServer()
		end
	end)
end

return ActivityController
