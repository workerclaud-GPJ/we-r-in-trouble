--!strict
--[[
	DashController — Dash input + local prediction + trail FX.
	Input: Q (keyboard), ButtonB (gamepad; ButtonX is the ProximityPrompt key), and the
	on-screen UI.Widgets.DashButton (touch + mouse) which calls DashController.request().
	The client checks the same rules as DashService, applies a short LinearVelocity burst on
	the HRP (horizontal only, walls stop it), shows the pose at once, and fires Remotes.Dash.
	The server owns the cooldown (Player.DashReadyAt); readyAt() merges it with the local
	prediction so the UI starts counting immediately.
	Trail FX for every player's dash comes from Player.DashAt changes.
]]

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ProceduralAnimController = require(script.Parent.ProceduralAnimController)

local Attr = Contract.Attr
local P = Config.Player
local A = Config.Animation

local ACTION = "WRIT_Dash"

local DashController = {}

local player = Players.LocalPlayer
local predictedReadyAt = 0
local lastLocalFx = -math.huge
local dashing = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

function DashController.readyAt(): number
	local r = player:GetAttribute(Attr.DashReadyAt)
	return math.max(if typeof(r) == "number" then r else 0, predictedReadyAt)
end

-- Same rules as DashService.canDash (cooldown excluded).
function DashController.allowedNow(): boolean
	local state = player:GetAttribute(Attr.State)
	if state ~= Contract.State.Standing and state ~= Contract.State.Lobby then
		return false
	end
	local mode = player:GetAttribute(Attr.MoveMode)
	if mode ~= nil and mode ~= Contract.MoveMode.Normal then
		return false
	end
	if player:GetAttribute(Attr.Stunned) == true then
		return false
	end
	local char = player.Character
	if not char or char:GetAttribute(Attr.AnimState) ~= nil or char:GetAttribute(Attr.AnimStandCF) ~= nil then
		return false -- in a hold (wheel)
	end
	return true
end

local function trail(char: Model)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "DashTrailTop"
	a0.Position = Vector3.new(0, 1.2, 0.4)
	local a1 = Instance.new("Attachment")
	a1.Name = "DashTrailBottom"
	a1.Position = Vector3.new(0, -1.6, 0.4)
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.25
	tr.Color = ColorSequence.new(A.DASH_TRAIL_COLOR)
	tr.Transparency = NumberSequence.new(0.35, 1)
	tr.LightEmission = 0.4
	tr.FaceCamera = true
	tr.Parent = hrp
	a0.Parent, a1.Parent = hrp, hrp
	task.delay(P.DASH_TIME + 0.1, function()
		tr.Enabled = false
	end)
	Debris:AddItem(tr, P.DASH_TIME + 0.5)
	Debris:AddItem(a0, P.DASH_TIME + 0.5)
	Debris:AddItem(a1, P.DASH_TIME + 0.5)
end

local function burst(char: Model)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then
		return
	end
	local dir = hum.MoveDirection * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then
		dir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit
	local speed = P.DASH_DISTANCE / P.DASH_TIME
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir)

	local att = Instance.new("Attachment")
	att.Name = "DashAttachment"
	att.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Name = "DashVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(P.DASH_MAX_FORCE, 0, P.DASH_MAX_FORCE) -- gravity untouched
	lv.VectorVelocity = dir * speed
	lv.Parent = hrp
	dashing = true
	task.delay(P.DASH_TIME, function()
		dashing = false
		lv:Destroy()
		att:Destroy()
		if hrp.Parent then
			local v = hrp.AssemblyLinearVelocity
			local keep = math.min(hum.WalkSpeed, Vector3.new(v.X, 0, v.Z).Magnitude)
			hrp.AssemblyLinearVelocity = dir * keep + Vector3.new(0, v.Y, 0)
		end
	end)
end

-- Returns true if a dash was started locally.
function DashController.request(): boolean
	if dashing or now() < DashController.readyAt() or not DashController.allowedNow() then
		return false
	end
	local char = player.Character
	if not char then
		return false
	end
	predictedReadyAt = now() + P.DASH_COOLDOWN
	ProceduralAnimController.predictDash()
	lastLocalFx = os.clock()
	trail(char)
	burst(char)
	Remotes.get("Dash"):FireServer()
	-- server refused (e.g. state changed): drop the prediction so the UI matches the server
	task.delay(2, function()
		local r = player:GetAttribute(Attr.DashReadyAt)
		if typeof(r) ~= "number" or r < predictedReadyAt - P.DASH_COOLDOWN_GRACE - 2 then
			predictedReadyAt = 0
		end
	end)
	return true
end

local function watch(p: Player)
	p:GetAttributeChangedSignal(Attr.DashAt):Connect(function()
		if p == player and os.clock() - lastLocalFx < 1.5 then
			return -- already shown by the prediction
		end
		if p.Character then
			trail(p.Character)
		end
	end)
end

function DashController.start()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			DashController.request()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
end

return DashController
