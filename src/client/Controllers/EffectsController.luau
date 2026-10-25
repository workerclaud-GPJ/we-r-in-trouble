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
	Art pass (docs/assets/ArtAudio-deadline.md §3–§5):
	  impact       white outline + red disc + growing timer core, blink in the last 0.4 s (≤ 24 rings),
	               debris from Assets.Debris spins 180° while falling, bounces, dust puff, FallWhistle
	               when near the local player, Bonk/ImpactThud on landing.
	  PlayerHit    "BONK!" + stars (Fx/CharacterFx); Downed → dizzy stars; Eliminated → Poof.
	  lighting     Lobby / Calm / Warning / Active / Critical preset tween (Fx/Lighting).
	  audio        SoundService.Audio from Config.Audio (Fx/Sound) — rumble during shake, sirens,
	               music per phase/stage, step / hero / win / lose stingers. id 0 = silent.
	  objectives   wheel spin, dynamo bulb, radio lights, charger LEDs (Fx/MapFx).
	UI/Art may restyle this; keep the remote handling here.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Attr = Contract.Attr
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)

local Fx = script.Parent:WaitForChild("Fx")
local Sound = require(Fx:WaitForChild("Sound"))
local Lighting = require(Fx:WaitForChild("Lighting"))
local CharacterFx = require(Fx:WaitForChild("CharacterFx"))
local MapFx = require(Fx:WaitForChild("MapFx"))

local MAX_SHAKE_DEG = 2.5 -- Art §3.6 Big Shake amplitude
local SHAKE_HZ = 18
local RING_OUTLINE = Color3.fromRGB(255, 255, 255)
local RING_COLOR = Color3.fromRGB(255, 60, 60)
local RING_CORE = Color3.fromRGB(255, 40, 40)
local MAX_RINGS = 24
local DUST_COLOR = Color3.fromRGB(210, 195, 170)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local NEAR_SHAKE_RADIUS = 15
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

local MAX_DEBRIS_SPEED = 22 -- studs/s cap for landed debris under physics

local function makeProp(name: string?): Model
	local model = Instance.new("Model")
	local assets = ReplicatedStorage:FindFirstChild(Contract.Folder.Assets)
	local debris = assets and assets:FindFirstChild("Debris")
	local source = if name and debris then debris:FindFirstChild(name) else nil
	if not source and debris then
		local pool = debris:GetChildren()
		source = if #pool > 0 then pool[math.random(1, #pool)] else nil
	end
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

local function disc(name: string, diameter: number, thickness: number, y: number, pos: Vector3, color: Color3, material: Enum.Material, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Material = material
	p.Color = color
	p.Transparency = transparency
	p.CastShadow = false
	p.Size = Vector3.new(thickness, diameter, diameter)
	p.CFrame = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
	noCollide(p)
	p.Parent = folder()
	return p
end

local function dustPuff(pos: Vector3, count: number)
	local holder = Instance.new("Part")
	holder.Name = "Dust"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CastShadow = false
	holder.CFrame = CFrame.new(pos)
	noCollide(holder)
	holder.Parent = folder()
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = SMOKE
	e.Color = ColorSequence.new(DUST_COLOR)
	e.Size = NumberSequence.new(1, 3)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(6, 10)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Drag = 5
	e.Acceleration = Vector3.new(0, 2, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, 1.5)
end

local function localRootPos(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character.PrimaryPart
	return if root then root.Position else nil
end

local activeRings = 0

local function onImpact(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end
	local pos: Vector3 = payload.position
	local radius = if typeof(payload.radius) == "number" then payload.radius else 5
	local telegraph = if typeof(payload.telegraph) == "number" then math.max(0.1, payload.telegraph) else 1.5
	local dropHeight = if typeof(payload.dropHeight) == "number" then payload.dropHeight else 30
	local lifetime = if typeof(payload.lifetime) == "number" then payload.lifetime else 3
	local prop = if typeof(payload.prop) == "string" then payload.prop else nil

	-- warning ring (Art §3.1): outline + red disc + core growing 0 → 2r over the telegraph
	if activeRings < MAX_RINGS then
		activeRings += 1
		local d = radius * 2
		local outline = disc("ImpactRing_Outline", d + 0.6, 0.15, 0.08, pos, RING_OUTLINE, Enum.Material.Neon, 0.35)
		local red = disc("ImpactRing", d, 0.2, 0.12, pos, RING_COLOR, Enum.Material.SmoothPlastic, 0.45)
		local core = disc("ImpactRing_Core", 0.05, 0.22, 0.16, pos, RING_CORE, Enum.Material.Neon, 0.25)
		TweenService:Create(core, TweenInfo.new(telegraph, Enum.EasingStyle.Linear), { Size = Vector3.new(0.22, d, d) }):Play()
		task.delay(math.max(0, telegraph - 0.4), function()
			local blink = false
			while red.Parent do
				blink = not blink
				red.Transparency = if blink then 0.2 else 0.55
				task.wait(0.1)
			end
		end)
		task.delay(telegraph, function()
			activeRings -= 1
			outline:Destroy()
			red:Destroy()
			core:Destroy()
		end)
	end

	if prop == nil then
		return
	end

	local rootPos = localRootPos()
	local near = rootPos ~= nil and (rootPos - pos).Magnitude <= Config.Audio.FALL_WHISTLE_RADIUS
	if near then
		Sound.play("FallWhistle", pos + Vector3.new(0, dropHeight * 0.5, 0))
	end

	-- debris (Art §3.2): random spin, +180° while falling (Quad In, lands exactly on the telegraph),
	-- then local physics takes over (bounce / roll / tumble), dust, fade
	local model = makeProp(prop)
	local spin = CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
	local _, size = model:GetBoundingBox()
	local restY = math.max(1, size.Y * 0.5)
	local startCf = CFrame.new(pos + Vector3.new(0, dropHeight, 0)) * spin
	local endCf = CFrame.new(pos + Vector3.new(0, restY, 0)) * spin * CFrame.Angles(math.rad(178), 0, 0)
	model:PivotTo(startCf)
	model.Parent = folder()
	local driver = Instance.new("CFrameValue")
	driver.Value = startCf
	driver.Changed:Connect(function(cf: CFrame)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local fall = TweenService:Create(driver, TweenInfo.new(telegraph, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = endCf })
	fall.Completed:Connect(function()
		dustPuff(pos + Vector3.new(0, 0.3, 0), 12)
		Sound.play(if prop == "Apple" then "Bonk" else "ImpactThud", pos)
		local rp = localRootPos()
		if rp and (rp - pos).Magnitude <= NEAR_SHAKE_RADIUS then
			EffectsController.shake(0.12, 0.2)
		end
		driver:Destroy()
		-- hand the prop to real (local) physics: it bounces, rolls and tumbles where it landed
		-- instead of freezing. Items collision group: the world and items only, never players.
		local parts: { BasePart } = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		local root = parts[1]
		if not root or not model.Parent then
			return
		end
		model:PivotTo(endCf + Vector3.new(0, 0.4, 0))
		-- landed inside solid geometry (counter edge, table leg…)? physics would shoot it out:
		-- keep the old still landing for this one
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		local exclude: { Instance } = { model }
		for _, plr in Players:GetPlayers() do
			if plr.Character then
				table.insert(exclude, plr.Character)
			end
		end
		overlap.FilterDescendantsInstances = exclude
		overlap.RespectCanCollide = true
		for _, part in parts do
			if #Workspace:GetPartsInPart(part, overlap) > 0 then
				model:PivotTo(endCf)
				return
			end
		end
		for i, part in parts do
			if i > 1 then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = root
			end
		end
		for _, part in parts do
			part.CanQuery = false
			part.CanTouch = false
			pcall(function()
				part.CollisionGroup = Contract.CollisionGroup.Items
			end)
			part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.35, 0.45, 1, 1)
			part.CanCollide = true
			part.Anchored = false
		end
		local rng = Random.new()
		root.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-7, 7), rng:NextNumber(9, 15), rng:NextNumber(-7, 7))
		root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-9, 9), rng:NextNumber(-9, 9))
		-- safety: never let a prop get launched (depenetration, stacked debris)
		local t0 = os.clock()
		local clamp: RBXScriptConnection
		clamp = RunService.Heartbeat:Connect(function()
			if not root.Parent or os.clock() - t0 > 2 then
				clamp:Disconnect()
				return
			end
			local v = root.AssemblyLinearVelocity
			if v.Magnitude > MAX_DEBRIS_SPEED then
				root.AssemblyLinearVelocity = v.Unit * MAX_DEBRIS_SPEED
			end
		end)
	end)
	fall:Play()
	fadeAndDestroy(model, telegraph + math.max(0, lifetime - FADE_TIME))
end

-- QuakeRumble volume per shake level (Art §5.2): 0.3 / 0.6 / 0.8 / 1.0
local function rumbleVolume(intensity: number): number
	if intensity >= 0.95 then
		return 1
	elseif intensity >= 0.5 then
		return 0.8
	elseif intensity >= 0.3 then
		return 0.6
	end
	return 0.3
end

function EffectsController.shake(intensity: number, duration: number)
	local t = os.clock()
	if t >= shakeUntil then
		shakeIntensity = 0
	end
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeUntil = math.max(shakeUntil, t + duration)
end

local function onScreenEffect(payload: any)
	if typeof(payload) ~= "table" or payload.effect ~= "Shake" then
		return
	end
	local intensity = if typeof(payload.intensity) == "number" then math.clamp(payload.intensity, 0, 1) else 0.5
	local duration = if typeof(payload.duration) == "number" then math.clamp(payload.duration, 0, 15) else 1
	if intensity >= 0.95 then
		Sound.play("BigShakeBoom")
	end
	EffectsController.shake(intensity, duration)
	if intensity >= 0.1 then
		Sound.setPlaying("QuakeRumble", true, rumbleVolume(intensity))
		Sound.setPlaying("DishRattle", true)
	end
end

local function onPlayerHit(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end
	local player = if typeof(payload.userId) == "number" then Players:GetPlayerByUserId(payload.userId) else nil
	CharacterFx.bonk(player, payload.position)
end

local function shakeStep()
	local t = os.clock()
	if t >= shakeUntil then
		if shakeIntensity > 0 then
			Sound.setPlaying("QuakeRumble", false)
			Sound.setPlaying("DishRattle", false)
		end
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

	local carrierPos = finalCf.Position
	if Workspace:GetServerTimeNow() < endsAt then
		Sound.play("HeroArrive")
		Sound.play("RopeCreak", carrierPos + Vector3.new(0, height * 0.5, 0))
	end
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
			conn:Disconnect()
			-- landing (Art §3.8): dip −0.5 and back in 0.25 s, dust, clunk
			dustPuff(carrierPos + Vector3.new(0, 0.3, 0), 20)
			Sound.play("CarrierLand", carrierPos)
			local t0 = os.clock()
			local land: RBXScriptConnection
			land = RunService.RenderStepped:Connect(function()
				local k = math.clamp((os.clock() - t0) / 0.25, 0, 1)
				if not carrier.Parent or k >= 1 then
					land:Disconnect()
					if carrier.Parent then
						setPivot(carrier, finalCf)
					end
					return
				end
				setPivot(carrier, finalCf * CFrame.new(0, -0.5 * math.sin(k * math.pi), 0))
			end)
		end
	end)
end

----------------------------------------------------------------------------
-- Rescue lights + moonlight
----------------------------------------------------------------------------

type RescueLight = { part: BasePart, base: CFrame, light: Light?, phase: number }

local rescueLights: { RescueLight } = {}
local rescueConn: RBXScriptConnection? = nil
local siren: Sound? = nil

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
	if siren then
		siren:Destroy()
		siren = nil
	end
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
	siren = Sound.loop("SirenNear", rescueLights[1].part)
	rescueConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local s = siren
		local rs = ReplicatedStorage:FindFirstChild(Contract.Folder.RoundState)
		local eta = rs and rs:GetAttribute(Attr.CarrierArrivesAt)
		if s then -- Art §3.7: 0.3 → 0.8 over the 60 s ETA
			local remaining = if typeof(eta) == "number" then eta - Workspace:GetServerTimeNow() else 0
			s.Volume = 0.3 + 0.5 * (1 - math.clamp(remaining / 60, 0, 1))
		end
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

----------------------------------------------------------------------------
-- Stage / phase mood: lighting preset, music, stingers
----------------------------------------------------------------------------

local lastStage: string? = nil
local lastPhase: string? = nil
local lastStep = 0

local function inMatchView(rs: Instance): boolean
	local phase = rs:GetAttribute(Attr.Phase)
	local state = Players.LocalPlayer:GetAttribute(Attr.State)
	if state == Contract.State.Lobby or state == nil then
		return false
	end
	return phase == Contract.Phase.Match or phase == Contract.Phase.Ending or phase == Contract.Phase.Result
end

local function refreshMood()
	local rs = roundState()
	if not rs then
		Lighting.apply("Lobby", true)
		return
	end
	local phase = rs:GetAttribute(Attr.Phase)
	local stage = rs:GetAttribute(Attr.Stage)
	local stageName = if typeof(stage) == "string" then stage else Contract.Stage.Calm
	local matchView = inMatchView(rs)

	Lighting.apply(if matchView then stageName else "Lobby")

	local critical = matchView and stageName == Contract.Stage.Critical
	local inMatch = matchView and phase ~= Contract.Phase.Result
	Sound.setPlaying("MusicLobby", not matchView)
	Sound.setPlaying("MusicMatch", inMatch and not critical)
	Sound.setPlaying("MusicCritical", inMatch and critical)
	Sound.setPlaying("AlarmLoop", inMatch and critical)
	Sound.setPlaying("KitchenNight", inMatch and stageName == Contract.Stage.Calm)

	if matchView and stageName == Contract.Stage.Warning and lastStage ~= Contract.Stage.Warning then
		Sound.play("SirenFar")
	end
	if phase == Contract.Phase.Result and lastPhase ~= Contract.Phase.Result and matchView then
		Sound.play(if rs:GetAttribute(Attr.ResultWin) == true then "WinStinger" else "LoseStinger")
	end
	local step = rs:GetAttribute(Attr.StepIndex)
	local stepN = if typeof(step) == "number" then step else 0
	if phase == Contract.Phase.Match and matchView and stepN > lastStep and lastStep > 0 then
		Sound.play("StepComplete")
	end
	lastStep = if phase == Contract.Phase.Match then stepN else 0
	lastStage = if matchView then stageName else nil
	lastPhase = if typeof(phase) == "string" then phase else nil
end

function EffectsController.start()
	Sound.init()
	CharacterFx.start()
	MapFx.start()
	Lighting.apply("Lobby", true)
	Remotes.get("Impact").OnClientEvent:Connect(onImpact)
	Remotes.get("ScreenEffect").OnClientEvent:Connect(onScreenEffect)
	Remotes.get("PlayerHit").OnClientEvent:Connect(onPlayerHit)
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
			for _, name in { Attr.Phase, Attr.Stage, Attr.StepIndex, Attr.ResultWin } do
				rs:GetAttributeChangedSignal(name):Connect(refreshMood)
			end
			Players.LocalPlayer:GetAttributeChangedSignal(Attr.State):Connect(refreshMood)
			refreshLights()
			refreshMood()
		end
	end)
end

return EffectsController
