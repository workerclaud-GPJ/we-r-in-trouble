--!strict
--[[
	VisualFxController — client-only polish, nothing gameplay-relevant (safe to switch off: ENABLED).
	  Water   faucet water (SceneProps.Faucet.Water): flowing beams on the spout, waterfall and the
	          floor streams, splash droplets + mist where it lands (only while the water is shown);
	          flood (RisingVolume): sparkles on the surface and a splash ring under anyone moving in it.
	  Ambient slow dust motes drifting in the kitchen and a faint moonbeam from the window.
	  Motion  little dust puffs from running feet (not in water); a puff where a dropped item lands.
	Budgets: every emitter has a low fixed rate; per-player puffs are throttled; one shared emitter
	per effect (moved, then :Emit) instead of one per player.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Sound = require(script.Parent.Fx.Sound)

local ENABLED = true
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local WATER = Color3.fromRGB(170, 215, 255)
local FX_RANGE = 90 -- studs from the camera for per-player puffs

local VisualFxController = {}

local folder: Folder? = nil
local conns: { RBXScriptConnection } = {}

local function holder(name: string, cf: CFrame, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = folder
	return p
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

----------------------------------------------------------------------------
-- faucet water
----------------------------------------------------------------------------

type WaterFx = { parts: { BasePart }, beams: { Beam }, emitters: { ParticleEmitter }, soundAt: Part?, sound: Sound? }
local water: WaterFx? = nil

-- a beam lying along `from` -> `to`, `width` wide; flat = lies on the floor (else faces the camera)
local function flowBeam(from: Vector3, to: Vector3, width: number, flat: boolean, speed: number): Beam
	local dir = (to - from).Unit
	local h = holder("FlowBeam", CFrame.new(from))
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	if flat then
		-- attachment X axis = flow direction, Y axis = up: the ribbon then lies flat on the floor
		local cf0 = CFrame.fromMatrix(from, dir, Vector3.yAxis)
		a0.CFrame = h.CFrame:ToObjectSpace(cf0)
		a1.CFrame = h.CFrame:ToObjectSpace(cf0 + (to - from))
	else
		a0.WorldPosition = from
		a1.WorldPosition = to
	end
	a0.Parent = h
	a1.Parent = h
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = SMOKE
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 6
	b.TextureSpeed = speed
	b.Width0 = width
	b.Width1 = width
	b.FaceCamera = not flat
	b.LightEmission = 0.6
	b.LightInfluence = 0.4
	b.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255), WATER)
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	b.Segments = 4
	b.Enabled = false
	b.Parent = h
	return b
end

local function splash(pos: Vector3, size: number, rate: number): { ParticleEmitter }
	local h = holder("Splash", CFrame.new(pos))
	local drops = emitter(h, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.new(1, 1, 1), WATER),
		Size = seq(0.35 * size, 0.1),
		Transparency = seq(0.1, 1),
		LightEmission = 0.4,
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(6 * size, 11 * size),
		SpreadAngle = Vector2.new(55, 55),
		Acceleration = Vector3.new(0, -60, 0),
		EmissionDirection = Enum.NormalId.Top,
		Rate = rate,
		Enabled = false,
	})
	local mist = emitter(h, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(225, 240, 255)),
		Size = seq(1.2 * size, 3.5 * size),
		Transparency = seq(0.75, 1),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(80, 80),
		Drag = 2,
		Rate = math.max(2, rate * 0.25),
		Enabled = false,
	})
	return { drops, mist }
end

local function buildWater(map: Instance)
	water = nil
	local faucet: Instance? = nil
	for _, inst in CollectionService:GetTagged("Switch") do
		if inst:IsDescendantOf(map) and inst:GetAttribute("Kind") == "Faucet" then
			faucet = inst
		end
	end
	local w = faucet and faucet:FindFirstChild("Water")
	if not w then
		return
	end
	local fx: WaterFx = { parts = {}, beams = {}, emitters = {}, soundAt = nil, sound = nil }
	local function part(name: string): BasePart?
		local p = w:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	-- vertical sheets: flow from top to bottom
	for _, name in { "Spout", "Waterfall" } do
		local p = part(name)
		if p then
			table.insert(fx.parts, p)
			local top = p.Position + Vector3.new(0, p.Size.Y / 2, 0)
			local bottom = p.Position - Vector3.new(0, p.Size.Y / 2, 0)
			table.insert(fx.beams, flowBeam(top, bottom, math.max(p.Size.X, p.Size.Z) * 0.95, false, 4))
			if name == "Waterfall" then
				fx.soundAt = holder("WaterSound", CFrame.new(bottom + Vector3.new(0, 2, 0)))
			end
			for _, e in splash(bottom + Vector3.new(0, 0.3, 0), if name == "Spout" then 0.5 else 1, if name == "Spout" then 18 else 30) do
				table.insert(fx.emitters, e)
			end
		end
	end
	-- floor streams: flow along the long axis (direction as in tools/AddSceneProps StreamZone Flow)
	local streams = {
		StreamA_Visual = Vector3.new(0, 0, 1),
		StreamB_Visual = Vector3.new(1, 0, 0),
		StreamC_Visual = Vector3.new(1, 0, 0),
	}
	for name, dir in streams do
		local p = part(name)
		if p then
			table.insert(fx.parts, p)
			local half = if dir.X ~= 0 then p.Size.X / 2 else p.Size.Z / 2
			local width = if dir.X ~= 0 then p.Size.Z else p.Size.X
			local y = p.Position.Y + p.Size.Y / 2 + 0.05
			local c = Vector3.new(p.Position.X, y, p.Position.Z)
			table.insert(fx.beams, flowBeam(c - dir * half, c + dir * half, width * 0.9, true, 3))
		end
	end
	local drain = part("DrainSplash")
	if drain then
		table.insert(fx.parts, drain)
		for _, e in splash(drain.Position - Vector3.new(0, drain.Size.Y / 2 - 0.3, 0), 0.8, 20) do
			table.insert(fx.emitters, e)
		end
	end
	water = fx
end

local function updateWater()
	local fx = water
	if not fx then
		return
	end
	local on = false
	for _, p in fx.parts do
		if p.Parent and p.Transparency < 1 then
			on = true
			break
		end
	end
	for _, b in fx.beams do
		b.Enabled = on
	end
	for _, e in fx.emitters do
		e.Enabled = on
	end
	-- running-water loop (3D, at the foot of the waterfall) while the tap is on
	if on and not fx.sound and fx.soundAt then
		fx.sound = Sound.loop("WaterRun", fx.soundAt)
	elseif not on and fx.sound then
		fx.sound:Destroy()
		fx.sound = nil
	end
end

----------------------------------------------------------------------------
-- flood surface + splashes, footstep dust, item puffs
----------------------------------------------------------------------------

local shimmer: Part? = nil
local shimmerEmitter: ParticleEmitter? = nil
local splashEmitter: ParticleEmitter? = nil
local splashHolder: Part? = nil
local dustEmitter: ParticleEmitter? = nil
local dustHolder: Part? = nil
local lastPuff: { [Player]: number } = {}

local function volumePart(): BasePart?
	for _, inst in CollectionService:GetTagged(Contract.Tag.RisingVolume) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			return inst
		end
	end
	return nil
end

local function emitAt(h: Part?, e: ParticleEmitter?, pos: Vector3, n: number)
	if h and e then
		h.CFrame = CFrame.new(pos)
		e:Emit(n)
	end
end

local function buildShared()
	shimmer = holder("FloodShimmer", CFrame.new(0, -500, 0), Vector3.new(4, 0.2, 4))
	shimmerEmitter = emitter(shimmer :: Part, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(210, 235, 255)),
		Size = seq(0.5, 0),
		Transparency = seq(0.2, 1),
		LightEmission = 0.8,
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(0, 0.3),
		Rate = 0,
		Enabled = true,
	})
	splashHolder = holder("WaterSplash", CFrame.new(0, -500, 0))
	splashEmitter = emitter(splashHolder :: Part, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.new(1, 1, 1), WATER),
		Size = seq(0.4, 0.1),
		Transparency = seq(0.1, 1),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -55, 0),
		EmissionDirection = Enum.NormalId.Top,
		Enabled = false,
	})
	dustHolder = holder("FootDust", CFrame.new(0, -500, 0))
	dustEmitter = emitter(dustHolder :: Part, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(225, 215, 200)),
		Size = seq(0.5, 1.6),
		Transparency = seq(0.55, 1),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 3,
		EmissionDirection = Enum.NormalId.Top,
		Enabled = false,
	})
end

local function updateMotion(dt: number)
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local vol = volumePart()
	local surface: number? = nil
	if vol then
		surface = vol.Position.Y + vol.Size.Y / 2
		local s = shimmer
		if s and shimmerEmitter then
			-- sparkles over the water surface (rate scales with area, capped)
			if vol.Size.Y > 0.6 then
				s.Size = Vector3.new(vol.Size.X, 0.2, vol.Size.Z)
				s.CFrame = CFrame.new(vol.Position.X, (surface :: number) + 0.15, vol.Position.Z)
				shimmerEmitter.Rate = math.clamp(vol.Size.X * vol.Size.Z / 400, 4, 25)
			else
				shimmerEmitter.Rate = 0
			end
		end
	elseif shimmerEmitter then
		shimmerEmitter.Rate = 0
	end
	local t = os.clock()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hrp:IsA("BasePart") and hum and (hrp.Position - camPos).Magnitude < FX_RANGE then
			local v = hrp.AssemblyLinearVelocity
			local flat = Vector3.new(v.X, 0, v.Z).Magnitude
			local feet = hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight
			local inWater = surface ~= nil and vol ~= nil and feet < (surface :: number) + 0.3 and hrp.Position.Y > (surface :: number) - 6
				and math.abs(hrp.Position.X - vol.Position.X) < vol.Size.X / 2 and math.abs(hrp.Position.Z - vol.Position.Z) < vol.Size.Z / 2
			if flat > 4 and t - (lastPuff[p] or 0) > 0.2 then
				if inWater then
					lastPuff[p] = t
					emitAt(splashHolder, splashEmitter, Vector3.new(hrp.Position.X, (surface :: number) + 0.2, hrp.Position.Z), 4)
				elseif hum.FloorMaterial ~= Enum.Material.Air and p:GetAttribute("Boating") ~= true then
					lastPuff[p] = t
					emitAt(dustHolder, dustEmitter, Vector3.new(hrp.Position.X, feet + 0.2, hrp.Position.Z), 1)
				end
			end
		end
	end
	for p in lastPuff do
		if p.Parent ~= Players then
			lastPuff[p] = nil
		end
	end
	local _ = dt
end

-- a puff where a dropped item lands (Carrier attribute goes back to 0)
local function watchItem(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	table.insert(conns, inst:GetAttributeChangedSignal(Contract.Attr.Carrier):Connect(function()
		if inst:GetAttribute(Contract.Attr.Carrier) == 0 then
			task.delay(0.2, function()
				if inst.Parent then
					local pos = inst:GetPivot().Position
					emitAt(dustHolder, dustEmitter, pos, 6)
				end
			end)
		end
	end))
end

----------------------------------------------------------------------------
-- ambient: dust motes + moonbeam
----------------------------------------------------------------------------

local function buildAmbient(map: Instance)
	local _ = map
	-- dust motes drifting through the whole kitchen (kitchen ~ X 0..170, Z 0..125, Y 0..70)
	local motes = holder("DustMotes", CFrame.new(85, 35, 62), Vector3.new(160, 60, 120))
	emitter(motes, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 210), Color3.fromRGB(200, 215, 255)),
		Size = seq(0.18, 0.12),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.45),
			NumberSequenceKeypoint.new(0.7, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightEmission = 1,
		Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(0.2, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Rate = 14,
		Enabled = true,
	})
	-- faint moonbeam from the window over the sink down to the floor
	local win = map:FindFirstChild("WindowSill_Inner", true)
	if win and win:IsA("BasePart") then
		local top = Vector3.new(win.Position.X, 82, -1)
		local bottom = Vector3.new(win.Position.X + 6, 0.5, 70)
		local beam = flowBeam(top, bottom, 34, false, 0.15)
		beam.Width1 = 52
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(Color3.fromRGB(190, 210, 255))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.93),
			NumberSequenceKeypoint.new(0.5, 0.95),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.TextureLength = 40
		beam.Enabled = true
	end
end

----------------------------------------------------------------------------
-- lifecycle: rebuilt for every match map (Workspace.Map)
----------------------------------------------------------------------------

local function teardown()
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	if folder then
		folder:Destroy()
	end
	folder = nil
	water = nil
	shimmer, shimmerEmitter, splashHolder, splashEmitter, dustHolder, dustEmitter = nil, nil, nil, nil, nil, nil
end

local function setup(map: Instance)
	teardown()
	local f = Instance.new("Folder")
	f.Name = "WRIT_VisualFx"
	f.Parent = Workspace
	folder = f
	buildShared()
	local ok, err = pcall(function()
		buildWater(map)
		buildAmbient(map)
	end)
	if not ok then
		warn("[VisualFx]", err)
	end
	for _, inst in CollectionService:GetTagged(Contract.Tag.Item) do
		watchItem(inst)
	end
	table.insert(conns, CollectionService:GetInstanceAddedSignal(Contract.Tag.Item):Connect(watchItem))
end

function VisualFxController.start()
	if not ENABLED then
		return
	end
	local function onChild(child: Instance)
		if child.Name == "Map" then
			-- let the map stream in (SceneProps, tags) before building
			task.delay(1, function()
				if child.Parent == Workspace then
					setup(child)
				end
			end)
		end
	end
	Workspace.ChildAdded:Connect(onChild)
	Workspace.ChildRemoved:Connect(function(child: Instance)
		if child.Name == "Map" then
			teardown()
		end
	end)
	local m = Workspace:FindFirstChild("Map")
	if m then
		onChild(m)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		if not folder then
			return
		end
		updateMotion(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			updateWater()
		end
	end)
end

return VisualFxController
