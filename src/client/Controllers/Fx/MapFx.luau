--!strict
--[[
	MapFx — objective feedback on the decor that tools/BuildProps.luau adds under <map>.Decor
	(docs/assets/ArtAudio-deadline.md §3.9). Reads the live attributes mirrored on ObjectiveAnchor
	models (ARCHITECTURE §4); purely visual, missing decor parts are ignored.
	  Decor.Wheel_Spokes (Model)   spins 1.5 rev/s about the wheel axle while RunWheel Progress rises
	  Decor.Dynamo_Bulb            grey → yellow Neon + PointLight Range 0 → 14 with Progress
	  Decor.Radio_Light_<A-D>      Neon + PointLight while that radio is Occupied (+ RadioStatic loop);
	                               all four flash 3× when CallForHelp is Done
	  Decor.Charger_LED<1-3>       red → green per Delivered battery
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Sound = require(script.Parent.Sound)
local Attr = Contract.Attr

local SPIN_RPS = 1.5
local SPIN_HOLD = 0.6 -- keep spinning this long after the last Progress increase
local BULB_OFF = Color3.fromRGB(90, 90, 100)
local BULB_ON = Color3.fromRGB(255, 220, 90)
local LED_OFF = Color3.fromRGB(255, 70, 70)
local LED_ON = Color3.fromRGB(90, 230, 120)
local RADIO_OFF = Color3.fromRGB(60, 60, 70)
local RADIO_COLORS: { [string]: Color3 } = {
	A = Color3.fromRGB(255, 90, 90),
	B = Color3.fromRGB(80, 150, 255),
	C = Color3.fromRGB(255, 205, 60),
	D = Color3.fromRGB(90, 210, 120),
}

local MapFx = {}

type Bound = {
	map: Instance,
	decor: Instance?,
	spokes: Model?,
	spokesBase: CFrame?,
	angle: number,
	lastProgress: number,
	spinUntil: number,
	statics: { [string]: Sound },
	radioDone: boolean,
	flashing: boolean,
}

local bound: Bound? = nil

local function currentMap(): Instance?
	local folder = Workspace:FindFirstChild(Contract.Folder.Map)
	if not folder then
		return nil
	end
	for _, c in folder:GetChildren() do
		if c:IsA("Model") then
			return c
		end
	end
	return nil
end

local function bind(map: Instance): Bound
	local decor = map:FindFirstChild("Decor")
	local spokes = decor and decor:FindFirstChild("Wheel_Spokes")
	local spokesModel = if spokes and spokes:IsA("Model") then spokes else nil
	return {
		map = map,
		decor = decor,
		spokes = spokesModel,
		spokesBase = if spokesModel then spokesModel:GetPivot() else nil,
		angle = 0,
		lastProgress = 0,
		spinUntil = 0,
		statics = {},
		radioDone = false,
		flashing = false,
	}
end

local function unbind(b: Bound)
	for _, s in b.statics do
		s:Destroy()
	end
	table.clear(b.statics)
end

local function decorPart(b: Bound, name: string): BasePart?
	local d = b.decor
	local p = d and d:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function setLight(part: BasePart, on: boolean, color: Color3, range: number?)
	part.Color = if on then color else RADIO_OFF
	part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local light = part:FindFirstChildWhichIsA("PointLight")
	if light then
		light.Enabled = on
		light.Color = color
		if range then
			light.Range = range
		end
	end
end

local function anchors(b: Bound): { Instance }
	local list = {}
	for _, a in CollectionService:GetTagged(Contract.Tag.ObjectiveAnchor) do
		if a:IsDescendantOf(b.map) then
			table.insert(list, a)
		end
	end
	return list
end

local function flashRadios(b: Bound)
	if b.flashing then
		return
	end
	b.flashing = true
	task.spawn(function()
		for _ = 1, 3 do
			for letter, color in RADIO_COLORS do
				local p = decorPart(b, "Radio_Light_" .. letter)
				if p then
					setLight(p, true, color)
				end
			end
			task.wait(0.15)
			for letter, color in RADIO_COLORS do
				local p = decorPart(b, "Radio_Light_" .. letter)
				if p then
					setLight(p, false, color)
				end
			end
			task.wait(0.15)
		end
		b.flashing = false
	end)
end

local function update(b: Bound)
	local now = os.clock()
	for _, a in anchors(b) do
		local id = a:GetAttribute(Attr.ObjectiveId)
		if id == "RunWheel" then
			local progress = a:GetAttribute(Attr.Progress)
			local pr = if typeof(progress) == "number" then progress else 0
			if pr > b.lastProgress + 1e-4 then
				b.spinUntil = now + SPIN_HOLD
			end
			b.lastProgress = pr
			local bulb = decorPart(b, "Dynamo_Bulb")
			if bulb then
				bulb.Color = BULB_OFF:Lerp(BULB_ON, pr)
				bulb.Material = if pr > 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				local light = bulb:FindFirstChildWhichIsA("PointLight")
				if light then
					light.Enabled = pr > 0
					light.Range = 14 * pr
				end
			end
		elseif id == "CallForHelp" then
			local letter = a:GetAttribute(Attr.Part)
			if typeof(letter) == "string" and RADIO_COLORS[letter] then
				local occupied = a:GetAttribute(Attr.Occupied) == true
				local p = decorPart(b, "Radio_Light_" .. letter)
				if p and not b.flashing then
					setLight(p, occupied, RADIO_COLORS[letter])
				end
				local s = b.statics[letter]
				if occupied and not s and p then
					local loop = Sound.loop("RadioStatic", p)
					if loop then
						b.statics[letter] = loop
					end
				elseif not occupied and s then
					s:Destroy()
					b.statics[letter] = nil
				end
			end
			if a:GetAttribute(Attr.Done) == true and not b.radioDone then
				b.radioDone = true
				flashRadios(b)
			end
		elseif id == "DeliverBatteries" then
			local delivered = a:GetAttribute(Attr.Delivered)
			local n = if typeof(delivered) == "number" then delivered else 0
			for i = 1, 3 do
				local led = decorPart(b, "Charger_LED" .. i)
				if led then
					led.Color = if i <= n then LED_ON else LED_OFF
				end
			end
		end
	end
end

function MapFx.start()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local map = currentMap()
		local b = bound
		if b and b.map ~= map then
			unbind(b)
			bound = nil
			b = nil
		end
		if not map then
			return
		end
		if not b then
			b = bind(map)
			bound = b
		end
		local bb = b :: Bound
		-- wheel spin every frame (cheap: one PivotTo)
		local spokes, base = bb.spokes, bb.spokesBase
		if spokes and base and os.clock() < bb.spinUntil then
			bb.angle = (bb.angle + dt * SPIN_RPS * 2 * math.pi) % (2 * math.pi)
			spokes:PivotTo(base * CFrame.Angles(bb.angle, 0, 0))
		end
		accum += dt
		if accum >= 0.1 then
			accum = 0
			update(bb)
		end
	end)
end

return MapFx
