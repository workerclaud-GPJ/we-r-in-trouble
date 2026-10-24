--!strict
--[[
	EffectsController — basic client visuals for server hazard events (docs/ARCHITECTURE.md §2):
	  Impact       red warning ring for `telegraph` s + prop falling from +dropHeight, landing
	               exactly when the telegraph ends, then fading over `lifetime` (non-colliding).
	  ScreenEffect camera shake (amplitude = intensity * MAX_SHAKE_DEG), skipped while the
	               camera is Scriptable (win camera belongs to UI/CameraController).
	Rescue Moment (Art §3.7, §3.8, §4.3):
	  carrier      tagged ExitVehicle: lowered locally from +DescendHeight to its server spot between
	               DescendStartedAt..DescendEndsAt (Quad Out, ±3° sway) on a visible rope.
	  rescue light Map.Lights.RescueLight_Red/Blue on while ExitOpen: Y-sweep 180°/s (180° apart) + 2 Hz flash.
	  moonlight    Map.Lights.Moonlight off during Critical.
	UI/Art may restyle this; keep the remote handling here.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Attr = Contract.Attr
local Remotes = require(Shared.Remotes)

local MAX_SHAKE_DEG = 2.5 -- Art §3.6 Big Shake amplitude
local SHAKE_HZ = 18
local RING_COLOR = Color3.fromRGB(255, 70, 70)
local SWAY_DEG = 3
local ROPE_COLOR = Color3.fromRGB(205, 180, 130)
local SWEEP_DEG_PER_S = 180
local FLASH_HZ = 2
local FLASH_HIGH, FLASH_LOW = 6, 2
local FADE_TIME = 0.6

local EffectsController = {}

local fxFolder: Folder? = nil
local shakeUntil = 0
local shakeIntensity = 0

local function folder(): Folder
	local f = fxFolder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "ClientFx"
	nf.Parent = Workspace
	fxFolder = nf
	return nf
end

local function noCollide(inst: Instance)
	local list: { Instance } = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

local function makeProp(name: string?): Model
	local model = Instance.new("Model")
	local assets = ReplicatedStorage:FindFirstChild(Contract.Folder.Assets)
	local debris = assets and assets:FindFirstChild("Debris")
	local source = name and debris and debris:FindFirstChild(name)
	if source and (source:IsA("Model") or source:IsA("BasePart")) then
		source:Clone().Parent = model
	else
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(4, 4, 4)
		ball.Color = Color3.fromRGB(200, 40, 50)
		ball.Parent = model
	end
	noCollide(model)
	return model
end

local function fadeAndDestroy(inst: Instance, delayTime: number)
	task.delay(delayTime, function()
		if not inst.Parent then
			return
		end
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
			end
		end
		task.delay(FADE_TIME, function()
			inst:Destroy()
		end)
	end)
end

local function onImpact(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end
	local pos: Vector3 = payload.position
	local radius = if typeof(payload.radius) == "number" then payload.radius else 5
	local telegraph = if typeof(payload.telegraph) == "number" then payload.telegraph else 1.5
	local dropHeight = if typeof(payload.dropHeight) == "number" then payload.dropHeight else 30
	local lifetime = if typeof(payload.lifetime) == "number" then payload.lifetime else 3
	local prop = if typeof(payload.prop) == "string" then payload.prop else nil

	local ring = Instance.new("Part")
	ring.Name = "ImpactRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = RING_COLOR
	ring.Transparency = 0.5
	ring.Size = Vector3.new(0.15, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	noCollide(ring)
	ring.Parent = folder()
	TweenService:Create(ring, TweenInfo.new(telegraph, Enum.EasingStyle.Linear), { Transparency = 0.15 }):Play()
	task.delay(telegraph, function()
		ring:Destroy()
	end)

	local model = makeProp(prop)
	local spin = CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
	local startCf = CFrame.new(pos + Vector3.new(0, dropHeight, 0)) * spin
	local endCf = CFrame.new(pos + Vector3.new(0, 2, 0)) * spin
	model:PivotTo(startCf)
	model.Parent = folder()
	local driver = Instance.new("CFrameValue")
	driver.Value = startCf
	driver.Changed:Connect(function(cf: CFrame)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(driver, TweenInfo.new(telegraph, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = endCf })
	tween.Completed:Connect(function()
		driver:Destroy()
	end)
	tween:Play()
	fadeAndDestroy(model, telegraph + math.max(0, lifetime - FADE_TIME))
end

local function onScreenEffect(payload: any)
	if typeof(payload) ~= "table" or payload.effect ~= "Shake" then
		return
	end
	local intensity = if typeof(payload.intensity) == "number" then math.clamp(payload.intensity, 0, 1) else 0.5
	local duration = if typeof(payload.duration) == "number" then math.clamp(payload.duration, 0, 15) else 1
	local t = os.clock()
	if t >= shakeUntil then
		shakeIntensity = 0
	end
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeUntil = math.max(shakeUntil, t + duration)
end

local function shakeStep()
	local t = os.clock()
	if t >= shakeUntil then
		shakeIntensity = 0
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType == Enum.CameraType.Scriptable then
		return
	end
	local fade = math.clamp((shakeUntil - t) / 0.5, 0, 1) -- ease out over the last 0.5 s
	local amp = math.rad(MAX_SHAKE_DEG * shakeIntensity * fade)
	local rx = math.noise(t * SHAKE_HZ, 0.3) * amp
	local ry = math.noise(0.7, t * SHAKE_HZ) * amp
	camera.CFrame *= CFrame.Angles(rx, ry, 0)
end

----------------------------------------------------------------------------
-- Carrier descent (client visual; the server already placed it at the spot)
----------------------------------------------------------------------------

local function pivotOf(inst: Instance): CFrame?
	if inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("BasePart") then
		return inst.CFrame
	end
	return nil
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
end

local function onCarrier(carrier: Instance)
	local final = pivotOf(carrier)
	local startedAt = carrier:GetAttribute(Attr.DescendStartedAt)
	local endsAt = carrier:GetAttribute(Attr.DescendEndsAt)
	local heightAttr = carrier:GetAttribute(Attr.DescendHeight)
	if not final or typeof(startedAt) ~= "number" or typeof(endsAt) ~= "number" then
		return
	end
	local finalCf: CFrame = final
	local height = if typeof(heightAttr) == "number" then heightAttr else 60
	local span = math.max(0.1, endsAt - startedAt)

	-- rope from an invisible anchor above the spot to the carrier's RopeAttachment
	local ropeAnchor = Instance.new("Part")
	ropeAnchor.Name = "RopeAnchor"
	ropeAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	ropeAnchor.Transparency = 1
	ropeAnchor.CFrame = finalCf + Vector3.new(0, height, 0)
	noCollide(ropeAnchor)
	ropeAnchor.Parent = folder()
	local rope: RopeConstraint? = nil
	local ropeAttachment = carrier:FindFirstChild("RopeAttachment", true)
	if ropeAttachment and ropeAttachment:IsA("Attachment") then
		local top = Instance.new("Attachment")
		top.Parent = ropeAnchor
		local r = Instance.new("RopeConstraint")
		r.Attachment0, r.Attachment1 = top, ropeAttachment
		r.Visible = true
		r.Thickness = 0.35
		r.Color = BrickColor.new(ROPE_COLOR)
		r.Parent = ropeAnchor
		rope = r
	end
	carrier.AncestryChanged:Connect(function()
		if not carrier:IsDescendantOf(Workspace) then
			ropeAnchor:Destroy()
		end
	end)

	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not carrier.Parent then
			conn:Disconnect()
			return
		end
		local alpha = math.clamp((Workspace:GetServerTimeNow() - startedAt) / span, 0, 1)
		local eased = 1 - (1 - alpha) * (1 - alpha) -- Quad Out
		local sway = math.rad(SWAY_DEG) * math.sin(os.clock() * 2 * math.pi) * (1 - alpha)
		setPivot(carrier, finalCf * CFrame.new(0, height * (1 - eased), 0) * CFrame.Angles(0, 0, sway))
		local r = rope
		if r and r.Attachment0 and r.Attachment1 then
			r.Length = (r.Attachment0.WorldPosition - r.Attachment1.WorldPosition).Magnitude
		end
		if alpha >= 1 then
			setPivot(carrier, finalCf)
			conn:Disconnect()
		end
	end)
end

----------------------------------------------------------------------------
-- Rescue lights + moonlight
----------------------------------------------------------------------------

type RescueLight = { part: BasePart, base: CFrame, light: Light?, phase: number }

local rescueLights: { RescueLight } = {}
local rescueConn: RBXScriptConnection? = nil

local function roundState(): Instance?
	return ReplicatedStorage:FindFirstChild(Contract.Folder.RoundState)
end

local function lightsFolder(): Instance?
	local map = Workspace:FindFirstChild(Contract.Folder.Map)
	return map and map:FindFirstChild(Contract.Name.Lights, true)
end

local function stopRescueLights()
	if rescueConn then
		rescueConn:Disconnect()
		rescueConn = nil
	end
	for _, rl in rescueLights do
		if rl.part.Parent then
			rl.part.CFrame = rl.base
			rl.part.Transparency = 1
			if rl.light then
				rl.light.Enabled = false
			end
		end
	end
	table.clear(rescueLights)
end

local function startRescueLights()
	if rescueConn then
		return
	end
	local lights = lightsFolder()
	if not lights then
		return
	end
	for i, name in { Contract.Name.RescueLightRed, Contract.Name.RescueLightBlue } do
		local part = lights:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local light = part:FindFirstChildWhichIsA("Light")
			part.Transparency = 0
			if light then
				light.Enabled = true
			end
			table.insert(rescueLights, { part = part, base = part.CFrame, light = light, phase = (i - 1) * math.pi })
		end
	end
	if #rescueLights == 0 then
		return
	end
	rescueConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, rl in rescueLights do
			rl.part.CFrame = rl.base * CFrame.Angles(0, math.rad(SWEEP_DEG_PER_S) * t + rl.phase, 0)
			local light = rl.light
			if light then
				local on = math.sin(t * FLASH_HZ * 2 * math.pi + rl.phase) >= 0
				light.Brightness = if on then FLASH_HIGH else FLASH_LOW
			end
		end
	end)
end

local function refreshLights()
	local rs = roundState()
	local exitOpen = rs ~= nil and rs:GetAttribute(Attr.ExitOpen) == true
	local phase = if rs then rs:GetAttribute(Attr.Phase) else nil
	if exitOpen and (phase == Contract.Phase.Match or phase == Contract.Phase.Ending) then
		startRescueLights()
	else
		stopRescueLights()
	end
	local lights = lightsFolder()
	local moon = lights and lights:FindFirstChild(Contract.Name.Moonlight)
	local moonLight: Light? = nil
	if moon then
		moonLight = if moon:IsA("Light") then moon else moon:FindFirstChildWhichIsA("Light")
	end
	if moonLight then
		moonLight.Enabled = not (rs ~= nil and rs:GetAttribute(Attr.Stage) == Contract.Stage.Critical)
	end
end

function EffectsController.start()
	Remotes.get("Impact").OnClientEvent:Connect(onImpact)
	Remotes.get("ScreenEffect").OnClientEvent:Connect(onScreenEffect)
	RunService:BindToRenderStep("WRIT_Shake", Enum.RenderPriority.Camera.Value + 1, shakeStep)

	CollectionService:GetInstanceAddedSignal(Contract.Tag.ExitVehicle):Connect(onCarrier)
	for _, carrier in CollectionService:GetTagged(Contract.Tag.ExitVehicle) do
		task.spawn(onCarrier, carrier)
	end

	task.spawn(function()
		local rs = ReplicatedStorage:WaitForChild(Contract.Folder.RoundState, 30)
		if rs then
			for _, name in { Attr.ExitOpen, Attr.Phase, Attr.Stage } do
				rs:GetAttributeChangedSignal(name):Connect(refreshLights)
			end
			refreshLights()
		end
	end)
end

return EffectsController
