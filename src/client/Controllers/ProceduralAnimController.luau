--!strict
--[[
	ProceduralAnimController — code-driven poses layered on top of the Animator, for EVERY
	character on this client (procedural poses do not replicate, so each client poses all
	characters from replicated attributes). No animation assets needed.

	Pose priority per character:
	  Dizzy       Player.Stunned == true
	  Dash        server time - Player.DashAt < DASH_TIME (local player: predicted instantly)
	  <holdAnim>  Character.AnimState mapped by Config.Animation.HOLD_ANIMS (e.g. RunInWheel)
	Downed / Eliminated keep their existing behaviour (no pose).

	How: PreAnimation resets the joints we touched last frame to identity; the Animator then
	writes its pose; PreSimulation blends our pose over it (Transform:Lerp(pose, weight)).
	Works on the hamster rig's kinematic AnimationConstraints and on classic Motor6Ds.

	Local player, toggle holds (running wheel, press E once):
	  * pins the HRP to Character.AnimStandCF while the hold runs,
	  * shows "Stop" as the prompt's ActionText (local only),
	  * move / jump input stops it by pressing the same prompt again (InputHoldBegin/End),
	    which the server treats exactly like a second E press.
	All clients: spins Models with attribute SpinFor (wheel art) while runners are inside.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local Attr = Contract.Attr
local A = Config.Animation
local PL = Config.Player

local ProceduralAnimController = {}

local JOINTS = {
	"Root", "Waist", "Neck",
	"LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftWrist", "RightWrist",
	"LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftAnkle", "RightAnkle",
}
local JOINT_SET: { [string]: boolean } = {}
for _, n in JOINTS do
	JOINT_SET[n] = true
end

type Pose = { [string]: CFrame }
type Rig = {
	char: Model,
	player: Player,
	joints: { [string]: any }, -- AnimationConstraint | Motor6D (both have .Transform)
	weight: number,
	pose: string?,
	touched: { any },
	conns: { RBXScriptConnection },
}

local player = Players.LocalPlayer
local rigs: { [Model]: Rig } = {}
local predictedDashAt = -math.huge -- local player only (server time)
local lastPrompt: ProximityPrompt? = nil
local pinnedSince: number? = nil
local exitRequestedAt: number? = nil
local stopPrompt: ProximityPrompt? = nil -- prompt whose ActionText we switched to "Stop"
local stopPromptText = ""

local rad = math.rad
local sin, cos, abs, max = math.sin, math.cos, math.abs, math.max
local ANG = CFrame.Angles

----------------------------------------------------------------------------
-- Poses (joint axes = part axes: +X rotation swings a hanging limb forward)
----------------------------------------------------------------------------

local POSES: { [string]: (t: number) -> Pose } = {}

POSES.Dizzy = function(t: number): Pose
	local s = A.DIZZY_SPEED * t
	local tor, head = rad(A.DIZZY_TORSO), rad(A.DIZZY_HEAD)
	local out, flail = A.DIZZY_ARM_OUT, A.DIZZY_ARM_FLAIL
	return {
		Root = ANG(tor * sin(s), 0, tor * cos(s)),
		Waist = ANG(tor * cos(s), 0, tor * sin(s)),
		Neck = ANG(head * sin(s + 1), head * 0.5 * sin(s * 0.5), head * cos(s + 1)),
		RightShoulder = ANG(rad(flail) * sin(t * 7), 0, rad(out + flail * sin(t * 6))),
		LeftShoulder = ANG(rad(flail) * sin(t * 7 + 2), 0, -rad(out + flail * sin(t * 6 + 1.5))),
		RightElbow = ANG(rad(30 + 20 * sin(t * 8)), 0, 0),
		LeftElbow = ANG(rad(30 + 20 * sin(t * 8 + 1)), 0, 0),
		RightHip = ANG(rad(12) * sin(t * 3), 0, rad(6)),
		LeftHip = ANG(-rad(12) * sin(t * 3), 0, -rad(6)),
		RightKnee = ANG(-rad(20 + 10 * sin(t * 3)), 0, 0),
		LeftKnee = ANG(-rad(20 - 10 * sin(t * 3)), 0, 0),
	}
end

POSES.Dash = function(t: number): Pose
	local lean, arms, stride = rad(A.DASH_LEAN), rad(A.DASH_ARMS_BACK), rad(A.DASH_STRIDE)
	local flutter = rad(4) * sin(t * 30)
	return {
		Root = ANG(-lean, 0, 0),
		Waist = ANG(-lean * 0.3, 0, 0),
		Neck = ANG(lean * 1.1, 0, 0),
		RightShoulder = ANG(-arms + flutter, 0, rad(15)),
		LeftShoulder = ANG(-arms - flutter, 0, -rad(15)),
		RightElbow = ANG(rad(15), 0, 0),
		LeftElbow = ANG(rad(15), 0, 0),
		RightHip = ANG(stride, 0, 0),
		RightKnee = ANG(-rad(15), 0, 0),
		LeftHip = ANG(-stride, 0, 0),
		LeftKnee = ANG(-rad(45), 0, 0),
		LeftAnkle = ANG(-rad(20), 0, 0),
	}
end

POSES.RunInWheel = function(t: number): Pose
	local p = 2 * math.pi * A.RUN_CYCLE_HZ * t
	local hip, knee = rad(A.RUN_HIP_SWING), rad(A.RUN_KNEE_BEND)
	local arm, elbow, lean = rad(A.RUN_ARM_SWING), rad(A.RUN_ELBOW_BEND), rad(A.RUN_LEAN)
	local sp, cp = sin(p), cos(p)
	return {
		Root = CFrame.new(0, A.RUN_BOB * abs(sp) - A.RUN_ROOT_DROP, 0) * ANG(-lean, 0, 0),
		Waist = ANG(-lean * 0.3, rad(8) * sp, 0),
		Neck = ANG(lean * 0.9, -rad(5) * sp, 0),
		RightHip = ANG(hip * sp, 0, 0),
		LeftHip = ANG(-hip * sp, 0, 0),
		RightKnee = ANG(-knee * (0.3 + 0.7 * max(0, cp)), 0, 0),
		LeftKnee = ANG(-knee * (0.3 + 0.7 * max(0, -cp)), 0, 0),
		RightAnkle = ANG(rad(20) * sp, 0, 0),
		LeftAnkle = ANG(-rad(20) * sp, 0, 0),
		RightShoulder = ANG(-arm * sp, 0, rad(8)),
		LeftShoulder = ANG(arm * sp, 0, -rad(8)),
		RightElbow = ANG(elbow, 0, 0),
		LeftElbow = ANG(elbow, 0, 0),
	}
end

----------------------------------------------------------------------------
-- Rig tracking
----------------------------------------------------------------------------

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function isJoint(d: Instance): boolean
	return (d:IsA("AnimationConstraint") or d:IsA("Motor6D")) and JOINT_SET[d.Name] == true
end

local function removeRig(char: Model)
	local rig = rigs[char]
	if not rig then
		return
	end
	rigs[char] = nil
	for _, c in rig.conns do
		c:Disconnect()
	end
end

local function addRig(owner: Player, char: Model)
	if rigs[char] then
		return
	end
	local rig: Rig = { char = char, player = owner, joints = {}, weight = 0, pose = nil, touched = {}, conns = {} }
	rigs[char] = rig
	for _, d in char:GetDescendants() do
		if isJoint(d) then
			rig.joints[d.Name] = d
		end
	end
	table.insert(rig.conns, char.DescendantAdded:Connect(function(d: Instance)
		if isJoint(d) then
			rig.joints[d.Name] = d
		end
	end))
	table.insert(rig.conns, char.AncestryChanged:Connect(function()
		if not char:IsDescendantOf(Workspace) then
			removeRig(char)
		end
	end))
end

local function poseFor(rig: Rig): string?
	local p = rig.player
	local state = p:GetAttribute(Attr.State)
	if state == Contract.State.Downed or state == Contract.State.Eliminated then
		return nil
	end
	if p:GetAttribute(Attr.Stunned) == true then
		return "Dizzy"
	end
	local dashAt = p:GetAttribute(Attr.DashAt)
	local at = if typeof(dashAt) == "number" then dashAt else -math.huge
	if p == player then
		at = max(at, predictedDashAt)
	end
	if now() - at < PL.DASH_TIME + 0.1 then
		return "Dash"
	end
	local hold = rig.char:GetAttribute(Attr.AnimState)
	if typeof(hold) == "string" then
		return A.HOLD_ANIMS[hold]
	end
	return nil
end

----------------------------------------------------------------------------
-- Frame steps
----------------------------------------------------------------------------

local function preAnimation()
	for _, rig in rigs do
		if #rig.touched > 0 then
			for _, j in rig.touched do
				if j.Parent then
					j.Transform = CFrame.identity
				end
			end
			table.clear(rig.touched)
		end
	end
end

local function applyPoses(dt: number, t: number)
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	for char, rig in rigs do
		local want = poseFor(rig)
		if want and POSES[want] then
			rig.pose = want
			rig.weight = math.min(1, rig.weight + dt * A.BLEND_IN)
		else
			rig.weight = math.max(0, rig.weight - dt * A.BLEND_OUT)
		end
		local poseId = rig.pose
		if rig.weight <= 0 or not poseId then
			rig.pose = nil
			continue
		end
		local pivot = char.PrimaryPart
		if pivot and (pivot.Position - camPos).Magnitude > A.MAX_DISTANCE then
			continue
		end
		local pose = POSES[poseId](t)
		local w = rig.weight
		for name, cf in pose do
			local j = rig.joints[name]
			if j and j.Parent then
				j.Transform = (j.Transform :: CFrame):Lerp(cf, w)
				table.insert(rig.touched, j)
			end
		end
	end
end

local function setStopText(prompt: ProximityPrompt?)
	if stopPrompt == prompt then
		return
	end
	if stopPrompt and stopPrompt.Parent then
		stopPrompt.ActionText = stopPromptText
	end
	stopPrompt = prompt
	if prompt then
		stopPromptText = prompt.ActionText
		prompt.ActionText = A.STOP_TEXT
	end
end

-- Same as a second E press: the server toggles the hold off.
local function pressPromptAgain()
	local prompt = lastPrompt
	if prompt and prompt.Parent then
		prompt:InputHoldBegin()
		task.defer(function()
			if prompt.Parent then
				prompt:InputHoldEnd()
			end
		end)
	end
end

-- Local player: stay on the stand point (e.g. inside the wheel) while the hold runs.
local function pinLocal()
	local char = player.Character
	local stand = char and char:GetAttribute(Attr.AnimStandCF)
	if typeof(stand) ~= "CFrame" then
		pinnedSince = nil
		exitRequestedAt = nil
		setStopText(nil)
		return
	end
	setStopText(lastPrompt)
	local t = os.clock()
	if exitRequestedAt then
		if t - exitRequestedAt < 1 then
			return -- free to walk off while the server confirms (range check is the fallback)
		end
		exitRequestedAt = nil
	end
	local hrp = (char :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = (char :: Model):FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then
		return
	end
	pinnedSince = pinnedSince or t
	-- move or jump input stops the run (after a short grace so the approach walk does not)
	if t - (pinnedSince :: number) > A.EXIT_GRACE and (hum.MoveDirection.Magnitude > 0.5 or hum.Jump) then
		exitRequestedAt = t
		pressPromptAgain()
		return
	end
	hrp.CFrame = stand
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

----------------------------------------------------------------------------
-- Wheel spin (visual)
----------------------------------------------------------------------------

type Spinner = { model: Model, base: CFrame, angle: number, speed: number }
local spinners: { [Model]: Spinner } = {}

local function trackSpinner(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute(A.SPIN_ATTR) ~= nil and not spinners[inst] then
		spinners[inst] = { model = inst, base = inst:GetPivot(), angle = 0, speed = 0 }
	end
end

local function spinWheels(dt: number)
	for model, s in spinners do
		if not model:IsDescendantOf(Workspace) then
			spinners[model] = nil
			continue
		end
		local bottomDir = s.base.RightVector:Cross(-s.base.UpVector) -- bottom-rim velocity for +angle
		local target = 0
		for char, rig in rigs do
			if rig.pose == "RunInWheel" and rig.weight > 0 then
				local stand = char:GetAttribute(Attr.AnimStandCF)
				if typeof(stand) == "CFrame" and (stand.Position - s.base.Position).Magnitude <= A.SPIN_RUNNER_RADIUS then
					-- the runner pushes the floor backwards
					local sign = if bottomDir:Dot(-stand.LookVector) >= 0 then 1 else -1
					target += sign * A.SPIN_PER_RUNNER
				end
			end
		end
		s.speed += (target - s.speed) * math.min(1, dt * A.SPIN_ACCEL)
		if abs(s.speed) > 0.01 then
			s.angle = (s.angle + s.speed * dt) % (2 * math.pi)
			model:PivotTo(s.base * ANG(s.angle, 0, 0))
		end
	end
end

----------------------------------------------------------------------------
-- API / lifecycle
----------------------------------------------------------------------------

-- DashController: show the local dash pose immediately (server echo follows).
function ProceduralAnimController.predictDash()
	predictedDashAt = now()
end

local function watchPlayer(p: Player)
	if p.Character then
		addRig(p, p.Character)
	end
	p.CharacterAdded:Connect(function(c: Model)
		addRig(p, c)
	end)
	p.CharacterRemoving:Connect(removeRig)
end

function ProceduralAnimController.start()
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(p: Player)
		if p.Character then
			removeRig(p.Character)
		end
	end)

	for _, d in Workspace:GetDescendants() do
		trackSpinner(d)
	end
	Workspace.DescendantAdded:Connect(trackSpinner)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who == player then
			lastPrompt = prompt
		end
	end)

	RunService.PreAnimation:Connect(preAnimation)
	RunService.PreSimulation:Connect(function(dt: number)
		pinLocal()
		applyPoses(dt, os.clock())
	end)
	RunService.Heartbeat:Connect(spinWheels)
end

return ProceduralAnimController
