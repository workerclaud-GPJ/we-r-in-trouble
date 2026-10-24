--!strict
--[[
	HazardFxController — client visuals for RisingVolume (Flood) and random events.
	  RisingVolume  the server's Part (tag RisingVolume in Map.Runtime) is resized locally every
	                frame from its rise attributes (BaseY, RiseFrom/To, RiseStartedAt/EndsAt) so the
	                surface moves smoothly; camera under the surface -> blue tint + blur (effects
	                parented to the camera so Fx/Lighting presets never touch them); spray particles
	                at the map's optional `VolumeSource` part while the volume rises.
	  WorldEvent    IceLane: flashing lane for the telegraph, then ice cubes slide down it.
	                OilPatch: dark glossy disc; while the local player stands in it after the
	                telegraph, movement never stops (last direction is re-applied, server adds speed).
	                Knockback: sets the local HRP velocity (client owns its character physics).
	Server stays authoritative for damage, Breath and speed (VolumeService / EventService).
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
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Attr = Contract.Attr
local player = Players.LocalPlayer

local DEFAULT_TINT = Color3.fromRGB(140, 190, 255)
local DEFAULT_BLUR = 6
local FX_LERP = 8 -- per s, underwater effect fade speed
local MIN_VISIBLE_LEVEL = 0.02
local ICE_COLOR = Color3.fromRGB(200, 235, 255)
local LANE_COLOR = Color3.fromRGB(120, 200, 255)
local OIL_COLOR = Color3.fromRGB(70, 52, 14)
local SPRAY_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local HazardFxController = {}

type VolumeView = { x: number, z: number, yaw: number, sizeX: number, sizeZ: number, transparency: number }
type Patch = { position: Vector3, radius: number, from: number, to: number }

local volumes: { [BasePart]: VolumeView } = {}
local patches: { Patch } = {}
local fxFolder: Folder? = nil
local tint: ColorCorrectionEffect? = nil
local blur: BlurEffect? = nil
local underwaterAlpha = 0
local spray: { source: BasePart?, attachment: Attachment?, emitter: ParticleEmitter? } = {}
local slideDir: Vector3? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function num(inst: Instance, name: string): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local function folder(): Folder
	local f = fxFolder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "WRIT_HazardFx"
	nf.Parent = Workspace
	fxFolder = nf
	return nf
end

local function fxPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency
	p.Parent = folder()
	return p
end

local function volumeDef(): any
	local rs = ReplicatedStorage:FindFirstChild(Contract.Folder.RoundState)
	local id = rs and rs:GetAttribute(Attr.DisasterId)
	local def = if typeof(id) == "string" then (Config.Disasters :: any)[id] else nil
	return def and def.volume
end

----------------------------------------------------------------------------
-- RisingVolume
----------------------------------------------------------------------------

local function track(inst: Instance)
	if not inst:IsA("BasePart") or volumes[inst] then
		return
	end
	local _, yaw, _ = inst.CFrame:ToOrientation()
	volumes[inst] = {
		x = inst.Position.X,
		z = inst.Position.Z,
		yaw = yaw,
		sizeX = inst.Size.X,
		sizeZ = inst.Size.Z,
		transparency = inst.Transparency,
	}
end

local function levelOf(part: BasePart): number
	local from, to = num(part, Attr.RiseFrom), num(part, Attr.RiseTo)
	local s, e = num(part, Attr.RiseStartedAt), num(part, Attr.RiseEndsAt)
	if e <= s then
		return to
	end
	return from + (to - from) * math.clamp((now() - s) / (e - s), 0, 1)
end

local function ensureEffects(): (ColorCorrectionEffect?, BlurEffect?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	local cc, bl = tint, blur
	if not (cc and cc.Parent == camera) then
		if cc then
			cc:Destroy()
		end
		local n = Instance.new("ColorCorrectionEffect")
		n.Name = "WRIT_UnderwaterTint"
		n.Enabled = false
		n.Parent = camera
		cc = n
		tint = n
	end
	if not (bl and bl.Parent == camera) then
		if bl then
			bl:Destroy()
		end
		local n = Instance.new("BlurEffect")
		n.Name = "WRIT_UnderwaterBlur"
		n.Size = 0
		n.Enabled = false
		n.Parent = camera
		bl = n
		blur = n
	end
	return cc, bl
end

local function updateSpray(active: boolean)
	local map = Workspace:FindFirstChild(Contract.Folder.Map)
	local source = if active and map then map:FindFirstChild(Contract.Name.VolumeSource, true) else nil
	if source and not source:IsA("BasePart") then
		source = nil
	end
	if spray.source ~= source then
		if spray.attachment then
			spray.attachment:Destroy()
		end
		spray.source, spray.attachment, spray.emitter = nil, nil, nil
		if source and source:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Name = "WRIT_Spray"
			att.Parent = source
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = SPRAY_TEXTURE
			pe.Color = ColorSequence.new(Color3.fromRGB(170, 215, 255))
			pe.Transparency = NumberSequence.new(0.3, 1)
			pe.Size = NumberSequence.new(0.6, 1.6)
			pe.Lifetime = NumberRange.new(0.5, 0.9)
			pe.Rate = 40
			pe.Speed = NumberRange.new(12, 18)
			pe.SpreadAngle = Vector2.new(15, 15)
			pe.Acceleration = Vector3.new(0, -40, 0)
			pe.EmissionDirection = Enum.NormalId.Front
			pe.Parent = att
			spray.source, spray.attachment, spray.emitter = source, att, pe
		end
	end
end

local function updateVolumes(dt: number)
	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local submerged = false
	local anyActive = false
	for part, v in volumes do
		if not part.Parent then
			volumes[part] = nil
			continue
		end
		local base = num(part, Attr.BaseY)
		local level = levelOf(part)
		if level < MIN_VISIBLE_LEVEL then
			part.Transparency = 1
			continue
		end
		anyActive = true
		part.Transparency = v.transparency
		local top, bottom = base + level, base - 1
		local h = top - bottom
		local cf = CFrame.new(v.x, bottom + h / 2, v.z) * CFrame.Angles(0, v.yaw, 0)
		part.Size = Vector3.new(v.sizeX, h, v.sizeZ)
		part.CFrame = cf
		local lp = cf:PointToObjectSpace(camPos)
		if math.abs(lp.X) <= v.sizeX / 2 and math.abs(lp.Z) <= v.sizeZ / 2 and camPos.Y < top then
			submerged = true
		end
	end
	updateSpray(anyActive)

	local target = if submerged then 1 else 0
	underwaterAlpha += (target - underwaterAlpha) * math.min(1, dt * FX_LERP)
	if underwaterAlpha < 0.01 and target == 0 then
		underwaterAlpha = 0
	end
	if underwaterAlpha == 0 and not tint then
		return
	end
	local cc, bl = ensureEffects()
	if not (cc and bl) then
		return
	end
	local vd = volumeDef()
	local tintColor: Color3 = if vd then vd.underwaterTint else DEFAULT_TINT
	local blurSize: number = if vd then vd.underwaterBlur else DEFAULT_BLUR
	cc.Enabled = underwaterAlpha > 0
	cc.TintColor = Color3.new(1, 1, 1):Lerp(tintColor, underwaterAlpha)
	cc.Saturation = -0.15 * underwaterAlpha
	cc.Brightness = -0.05 * underwaterAlpha
	bl.Enabled = underwaterAlpha > 0
	bl.Size = blurSize * underwaterAlpha
end

----------------------------------------------------------------------------
-- WorldEvent visuals
----------------------------------------------------------------------------

local function fadeOut(part: BasePart, time: number)
	TweenService:Create(part, TweenInfo.new(time), { Transparency = 1 }):Play()
	Debris:AddItem(part, time + 0.1)
end

local function onIceLane(payload: Remotes.WorldEventPayload)
	local cf, length, width = payload.cframe, payload.length or 0, payload.width or 8
	if not cf or length <= 0 then
		return
	end
	local telegraph = math.max(0, (payload.telegraph or 2) - (now() - (payload.startsAt or now())))
	local slide = payload.duration or 1.5
	local lane = fxPart("IceLane", Vector3.new(width, 0.15, length), cf * CFrame.new(0, 0.1, -length / 2), LANE_COLOR, Enum.Material.Neon, 0.6)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < telegraph and lane.Parent do
			lane.Transparency = 0.45 + 0.35 * (0.5 + 0.5 * math.sin((os.clock() - t0) * 14))
			task.wait()
		end
		lane.Transparency = 0.6
		local count = payload.count or 6
		for i = 1, count do
			local size = 2.5 + math.random() * 1
			local x = (math.random() - 0.5) * (width - size)
			local back = (i - 1) * 1.5
			local start = cf * CFrame.new(x, size / 2, back)
			local finish = cf * CFrame.new(x, size / 2, -length - 2 + back)
			local cube = fxPart("IceCube", Vector3.one * size, start, ICE_COLOR, Enum.Material.Ice, 0.25)
			cube.Reflectance = 0.2
			local spin = CFrame.Angles(math.rad(math.random(180, 540)), math.rad(math.random(0, 360)), 0)
			TweenService:Create(cube, TweenInfo.new(slide, Enum.EasingStyle.Linear), { CFrame = finish * spin }):Play()
			task.delay(slide, fadeOut, cube, 0.5)
		end
		task.wait(slide)
		fadeOut(lane, 0.4)
	end)
end

local function onOilPatch(payload: Remotes.WorldEventPayload)
	local pos, radius = payload.position, payload.radius or 12
	if not pos then
		return
	end
	local startsAt = payload.startsAt or now()
	local telegraph = payload.telegraph or 2
	local duration = payload.duration or 20
	local from = startsAt + telegraph
	table.insert(patches, { position = pos, radius = radius, from = from, to = from + duration })
	local flat = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local disc = fxPart("OilPatch", Vector3.new(0.1, 1, 1), flat, OIL_COLOR, Enum.Material.Glass, 0.15)
	disc.Shape = Enum.PartType.Cylinder
	disc.Reflectance = 0.35
	local grow = math.max(0.1, from - now())
	TweenService:Create(disc, TweenInfo.new(grow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, radius * 2, radius * 2),
	}):Play()
	task.delay(math.max(0, from + duration - now()), fadeOut, disc, 1)
end

local function onKnockback(payload: Remotes.WorldEventPayload)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local velocity = payload.velocity
	if hrp and hrp:IsA("BasePart") and velocity then
		hrp.AssemblyLinearVelocity = velocity
	end
end

local function onWorldEvent(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" then
		return
	end
	if payload.kind == "IceLane" then
		onIceLane(payload)
	elseif payload.kind == "OilPatch" then
		onOilPatch(payload)
	elseif payload.kind == "Knockback" then
		onKnockback(payload)
	end
end

-- Oil: no stopping. Runs right after the default control script has set this frame's move.
local function oilSlide()
	local t = now()
	for i = #patches, 1, -1 do
		if t > patches[i].to then
			table.remove(patches, i)
		end
	end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if
		#patches == 0
		or not (humanoid and hrp and hrp:IsA("BasePart"))
		or player:GetAttribute(Attr.MoveMode) ~= Contract.MoveMode.Normal
		or player:GetAttribute(Attr.State) ~= Contract.State.Standing
	then
		slideDir = nil
		return
	end
	local feet = hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + humanoid.HipHeight, 0)
	local inside = false
	for _, p in patches do
		local d = Vector3.new(feet.X - p.position.X, 0, feet.Z - p.position.Z).Magnitude
		if t >= p.from and d <= p.radius and math.abs(feet.Y - p.position.Y) <= Config.Events.HIT_DY then
			inside = true
			break
		end
	end
	if not inside then
		slideDir = nil
		return
	end
	local move = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	if move.Magnitude > 0.1 then
		slideDir = move.Unit
	elseif slideDir then
		humanoid:Move(slideDir, false)
	end
end

function HazardFxController.start()
	for _, inst in CollectionService:GetTagged(Contract.Tag.RisingVolume) do
		track(inst)
	end
	CollectionService:GetInstanceAddedSignal(Contract.Tag.RisingVolume):Connect(track)
	RunService.RenderStepped:Connect(updateVolumes)
	RunService:BindToRenderStep("WRIT_OilSlide", Enum.RenderPriority.Input.Value + 1, oilSlide)
	Remotes.get("WorldEvent").OnClientEvent:Connect(onWorldEvent)
end

return HazardFxController
