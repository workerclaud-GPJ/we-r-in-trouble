--!strict
--[[
	LauncherService — interactive scene objects that throw a hamster (tools/AddSceneProps.luau).
	Part tagged "Launcher" in the map, attributes:
	  Mode    "Prompt" (press E, e.g. the toaster lever) | "Touch" (client-only bounce, e.g. sponge)
	  Target  Vector3 where the throw lands, Flight number s, From Vector3? (start point, e.g. slot)
	  Action  prompt text, Object prompt object text
	Prompt launchers: a standing participant presses → Remote Launch to that player (the client
	owns its character and applies the throw, LauncherController). 3 s cooldown per player.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local TAG = "Launcher"
local COOLDOWN = 3

local LauncherService = {}

local conns: { RBXScriptConnection } = {}
local last: { [Player]: number } = {}

function LauncherService.begin()
	LauncherService.reset()
	for _, inst in MapService.tagged(TAG) do
		if inst:IsA("BasePart") and inst:GetAttribute("Mode") == "Prompt" then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "LauncherPrompt"
			prompt.ActionText = tostring(inst:GetAttribute("Action") or "Use")
			prompt.ObjectText = tostring(inst:GetAttribute("Object") or "")
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = inst
			table.insert(conns, prompt.Triggered:Connect(function(player: Player)
				local t = os.clock()
				if t - (last[player] or 0) < COOLDOWN then
					return
				end
				if not (PlayerStateService.isStanding(player) and PlayerStateService.isParticipant(player)) then
					return
				end
				local hrp = PlayerStateService.getHRP(player)
				if not hrp or (hrp.Position - inst.Position).Magnitude > 14 then
					return
				end
				local to = inst:GetAttribute("Target")
				if typeof(to) ~= "Vector3" then
					return
				end
				last[player] = t
				local from = inst:GetAttribute("From")
				local flight = inst:GetAttribute("Flight")
				Remotes.get("Launch"):FireClient(player, {
					from = if typeof(from) == "Vector3" then from else nil,
					to = to,
					time = if typeof(flight) == "number" then flight else 1.2,
				})
			end))
		end
	end
end

function LauncherService.reset()
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
end

function LauncherService.start()
	game:GetService("Players").PlayerRemoving:Connect(function(p: Player)
		last[p] = nil
	end)
	local _ = CollectionService
end

return LauncherService
