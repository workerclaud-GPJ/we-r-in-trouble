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
local ItemService = require(script.Parent.ItemService)

local TAG = "Launcher"
local SWITCH_TAG = "Switch" -- Model: Kind "Faucet" | "Fan", PromptPart, Duration? (s, nil = stays on), Flag?
local Hud = require(script.Parent.Hud)
local Workspace = game:GetService("Workspace")
local COOLDOWN = 3

local LauncherService = {}

local conns: { RBXScriptConnection } = {}
local last: { [Player]: number } = {}

local beginSwitches: (startOn: { string }?) -> ()

-- startOn: Switch Kinds running from the start (MissionDef.switchesOn, e.g. the drain round's faucet)
function LauncherService.begin(startOn: { string }?)
	LauncherService.reset()
	beginSwitches(startOn)
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

-- Switches: Model tagged "Switch" with a PromptPart; model attribute ActiveUntil (server time) is what
-- clients read (BoatController streams, LauncherController wind) together with BoatService.
--   Kind "Faucet"    toggles on / off (water model shown / hidden; Flag set when turned on)
--   Kind "Fan"       Duration s, then off again (press again later)
--   Kind "Sharpener" one-shot; RequiresCapability = the held item must have it (scissors: "Pry")
-- Attributes: Action / ActionOff, Object, Duration?, Flag?, Banner / BannerSub, BannerOff,
--   HoldDuration?, RequiresCapability?, MissingHint?
local function isRunning(inst: Instance): boolean
	local u = inst:GetAttribute("ActiveUntil")
	return typeof(u) == "number" and u > Workspace:GetServerTimeNow()
end

-- true when any Switch of this Kind in the current map is running (Deliver.blockedWhileOn)
function LauncherService.isOn(kind: string): boolean
	for _, inst in MapService.tagged(SWITCH_TAG) do
		if inst:GetAttribute("Kind") == kind and isRunning(inst) then
			return true
		end
	end
	return false
end

local function showWater(inst: Instance, on: boolean)
	local water = inst:FindFirstChild("Water")
	if not water then
		return
	end
	for _, d in water:GetDescendants() do
		if d:IsA("BasePart") then
			local base = d:GetAttribute("OnTransparency")
			if typeof(base) ~= "number" then
				base = if d.Transparency < 1 then d.Transparency else 0.35
				d:SetAttribute("OnTransparency", base)
			end
			d.Transparency = if on then base :: number else 1
		end
	end
end

local function turnOn(inst: Model, prompt: ProximityPrompt?)
	local now = Workspace:GetServerTimeNow()
	local dur = inst:GetAttribute("Duration")
	inst:SetAttribute("ActiveUntil", if typeof(dur) == "number" then now + dur else math.huge)
	local flag = inst:GetAttribute("Flag")
	if typeof(flag) == "string" then
		MapService.setFlag(flag)
	end
	if inst:GetAttribute("Kind") == "Faucet" then
		showWater(inst, true)
		if prompt then
			prompt.ActionText = tostring(inst:GetAttribute("ActionOff") or "Turn off")
		end
	end
end

local function turnOff(inst: Model, prompt: ProximityPrompt?)
	inst:SetAttribute("ActiveUntil", 0)
	if inst:GetAttribute("Kind") == "Faucet" then
		showWater(inst, false)
		if prompt then
			prompt.ActionText = tostring(inst:GetAttribute("Action") or "Turn on")
		end
	end
end

beginSwitches = function(startOn: { string }?)
	for _, inst in MapService.tagged(SWITCH_TAG) do
		if inst:IsA("Model") then
			local pp = inst:FindFirstChild("PromptPart")
			if pp and pp:IsA("BasePart") then
				local kind = inst:GetAttribute("Kind")
				inst:SetAttribute("ActiveUntil", 0)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "SwitchPrompt"
				prompt.ActionText = tostring(inst:GetAttribute("Action") or "Turn on")
				prompt.ObjectText = tostring(inst:GetAttribute("Object") or inst.Name)
				local hd = inst:GetAttribute("HoldDuration")
				prompt.HoldDuration = if typeof(hd) == "number" then hd else 0.4
				prompt.MaxActivationDistance = 9
				prompt.RequiresLineOfSight = false
				prompt.Parent = pp
				if kind == "Faucet" then
					showWater(inst, false)
				end
				if startOn and typeof(kind) == "string" and table.find(startOn, kind) then
					turnOn(inst, prompt)
				end
				table.insert(conns, prompt.Triggered:Connect(function(player: Player)
					if not (PlayerStateService.isStanding(player) and PlayerStateService.isParticipant(player)) then
						return
					end
					local need = inst:GetAttribute("RequiresCapability")
					if typeof(need) == "string" then
						local held = player:GetAttribute("Holding")
						if not (typeof(held) == "string" and held ~= "" and ItemService.hasCapability(held, need)) then
							local hint = inst:GetAttribute("MissingHint")
							Hud.bannerTo(player, "Switch" .. inst.Name, if typeof(hint) == "string" then hint else "You need something for this", nil, "Warn", 2.5)
							return
						end
					end
					if isRunning(inst) then
						if kind == "Faucet" then
							turnOff(inst, prompt)
							local off = inst:GetAttribute("BannerOff")
							if typeof(off) == "string" then
								Hud.banner("Switch" .. inst.Name, off, nil, "Good", 2)
							end
						end
						return -- fans run their time out; one-shots stay done
					end
					turnOn(inst, prompt)
					if kind ~= "Faucet" and typeof(inst:GetAttribute("Duration")) ~= "number" then
						prompt.Enabled = false -- one-shot (e.g. the sharpener)
					end
					local msg = inst:GetAttribute("Banner")
					if typeof(msg) == "string" then
						Hud.banner("Switch" .. inst.Name, msg, inst:GetAttribute("BannerSub") :: string?, "Good", 2.5)
					end
				end))
			end
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
