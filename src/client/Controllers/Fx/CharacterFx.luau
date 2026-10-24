--!strict
--[[
	CharacterFx — per-player status visuals (docs/assets/ArtAudio-deadline.md §3.3–3.5):
	  bonk(player, pos)  "BONK!" billboard at Head.StatusFxAttachment + star burst + Bonk/SqueakHurt
	  Downed             3 orbiting ★ (DizzyRing welded to Head) + DizzyLoop; on revive → burst + Revive
	  Stunned            same orbiting ★ while the short post-hit stun lasts (Player attr Stunned)
	  Eliminated         fur-coloured smoke Poof + "POOF!" at UpperTorso.PoofAttachment (before the
	                     server removes the character POOF_DELAY later)
	Missing attachments fall back to Head / HumanoidRootPart offsets, so the default rig works too.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Sound = require(script.Parent.Sound)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local YELLOW = Color3.fromRGB(255, 230, 90)
local STAR = Color3.fromRGB(255, 225, 80)
local OUTLINE = Color3.fromRGB(38, 30, 58)
local POOF_COLOR = Color3.fromRGB(150, 176, 210) -- Style.Color.Poof
local MINT = Color3.fromRGB(118, 226, 140)
local DEFAULT_FUR = Color3.fromRGB(235, 180, 120)
local FONT = Enum.Font.FredokaOne

local CharacterFx = {}

local function rng(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function fxPart(name: string, pos: Vector3, life: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Position = pos
	local f = Workspace:FindFirstChild("ClientFx") or Workspace
	p.Parent = f
	Debris:AddItem(p, life)
	return p
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function headOf(character: Model?): BasePart?
	local h = character and character:FindFirstChild("Head")
	return if h and h:IsA("BasePart") then h else nil
end

-- world position for status fx above the head
local function statusPos(character: Model?): Vector3?
	local head = headOf(character)
	if head then
		local att = head:FindFirstChild("StatusFxAttachment")
		if att and att:IsA("Attachment") then
			return att.WorldPosition
		end
		return head.Position + Vector3.new(0, head.Size.Y, 0)
	end
	return nil
end

local function furColor(character: Model?): Color3
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	return if torso and torso:IsA("BasePart") then torso.Color else DEFAULT_FUR
end

local function popText(at: Vector3, text: string, color: Color3)
	local holder = fxPart("PopText", at, 1.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 2)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0, 0)
	label.Text = text
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = color
	label.Rotation = rng(-12, 12)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = OUTLINE
	stroke.Parent = label
	local pop = TweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1.2, 1.2) })
	pop:Play()
	pop.Completed:Connect(function()
		TweenService:Create(label, TweenInfo.new(0.08), { Size = UDim2.fromScale(1, 1) }):Play()
		TweenService:Create(gui, TweenInfo.new(0.6), { StudsOffset = Vector3.new(0, 2, 0) }):Play()
		TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	end)
end

local function starBurst(at: Vector3, count: number, c0: Color3, c1: Color3)
	local p = fxPart("StarBurst", at, 1.5)
	emitter(p, {
		Texture = SPARKLE,
		Color = ColorSequence.new(c0, c1),
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.5),
		Speed = NumberRange.new(8),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.5,
		RotSpeed = NumberRange.new(180),
	}):Emit(count)
end

function CharacterFx.bonk(player: Player?, position: Vector3)
	local character = player and player.Character
	local at = statusPos(character) or (position + Vector3.new(0, 3, 0))
	popText(at, "BONK!", YELLOW)
	starBurst(at, 8, YELLOW, Color3.new(1, 1, 1))
	Sound.play("Bonk", at)
	Sound.play("SqueakHurt", at)
end

----------------------------------------------------------------------------
-- Dizzy ring
----------------------------------------------------------------------------

type Dizzy = { ring: BasePart, conn: RBXScriptConnection, loop: Sound? }
local dizzy: { [Player]: Dizzy } = {}

local function stopDizzy(player: Player, revived: boolean)
	local d = dizzy[player]
	if not d then
		return
	end
	dizzy[player] = nil
	d.conn:Disconnect()
	if d.loop then
		d.loop:Destroy()
	end
	if revived and d.ring.Parent then
		local pos = d.ring.Position
		starBurst(pos, 10, YELLOW, MINT)
		Sound.play("Revive", pos)
	end
	d.ring:Destroy()
end

local function startDizzy(player: Player)
	if dizzy[player] then
		return
	end
	local character = player.Character
	local head = headOf(character)
	if not head then
		return
	end
	local att = head:FindFirstChild("StatusFxAttachment")
	local base = if att and att:IsA("Attachment") then att.CFrame else CFrame.new(0, head.Size.Y * 0.5 + 1.6, 0)

	local ring = Instance.new("Part")
	ring.Name = "DizzyRing"
	ring.Size = Vector3.new(0.2, 0.2, 0.2)
	ring.Transparency = 1
	ring.Massless = true
	ring.CanCollide, ring.CanQuery, ring.CanTouch = false, false, false
	ring.CastShadow = false
	ring.CFrame = head.CFrame * base
	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = ring
	weld.C0 = base
	weld.Parent = ring
	local stars: { Attachment } = {}
	for i = 1, 3 do
		local a = Instance.new("Attachment")
		local ang = (i - 1) * math.pi * 2 / 3
		a.Position = Vector3.new(math.cos(ang) * 0.9, 0, math.sin(ang) * 0.9)
		a.Parent = ring
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(0.9, 0.9)
		gui.LightInfluence = 0
		gui.Adornee = a
		gui.Parent = a
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = "★"
		label.Font = FONT
		label.TextScaled = true
		label.TextColor3 = STAR
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(120, 80, 20)
		stroke.Parent = label
		local trail = emitter(a, {
			Texture = SPARKLE,
			Color = ColorSequence.new(STAR),
			Size = NumberSequence.new(0.4, 0),
			Lifetime = NumberRange.new(0.3),
			Speed = NumberRange.new(0),
			LightEmission = 0.6,
			Rate = 12,
		})
		trail.Enabled = true
		table.insert(stars, a)
	end
	ring.Parent = character

	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		if not ring.Parent then
			return
		end
		weld.C0 *= CFrame.Angles(0, dt * 4, 0)
		local t = os.clock() - t0
		for i, a in stars do
			local ang = (i - 1) * math.pi * 2 / 3
			a.Position = Vector3.new(math.cos(ang) * 0.9, math.sin(t * 4 + ang) * 0.15, math.sin(ang) * 0.9)
		end
	end)
	dizzy[player] = { ring = ring, conn = conn, loop = Sound.loop("DizzyLoop", ring) }
end

----------------------------------------------------------------------------
-- Poof
----------------------------------------------------------------------------

function CharacterFx.poof(player: Player)
	local character = player.Character
	local pos: Vector3? = nil
	local torso = character and character:FindFirstChild("UpperTorso")
	local att = torso and torso:FindFirstChild("PoofAttachment")
	if att and att:IsA("Attachment") then
		pos = att.WorldPosition
	elseif character and character.PrimaryPart then
		pos = character.PrimaryPart.Position
	end
	if not pos then
		return
	end
	local fur = furColor(character)
	local p = fxPart("Poof", pos, 2.5)
	emitter(p, {
		Texture = SMOKE,
		Color = ColorSequence.new(fur, Color3.new(1, 1, 1)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(0.3, 3.5),
			NumberSequenceKeypoint.new(1, 4.5),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(8, 14),
		Drag = 6,
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	}):Emit(30)
	emitter(p, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.new(1, 1, 1), fur),
		Size = NumberSequence.new(0.5),
		Lifetime = NumberRange.new(1.5, 2),
		Speed = NumberRange.new(4),
		Acceleration = Vector3.new(0, -3, 0),
		Drag = 2,
		SpreadAngle = Vector2.new(180, 180),
	}):Emit(12)
	popText(pos + Vector3.new(0, 2.5, 0), "POOF!", POOF_COLOR)
	Sound.play("Poof", pos)
end

----------------------------------------------------------------------------
-- State watcher
----------------------------------------------------------------------------

local function watch(player: Player)
	local last = player:GetAttribute(Contract.Attr.State)
	local function wantsDizzy(): boolean
		return player:GetAttribute(Contract.Attr.State) == Contract.State.Downed
			or player:GetAttribute(Contract.Attr.Stunned) == true
	end
	player:GetAttributeChangedSignal(Contract.Attr.Stunned):Connect(function()
		if wantsDizzy() then
			startDizzy(player)
		else
			stopDizzy(player, false)
		end
	end)
	local function onState()
		local state = player:GetAttribute(Contract.Attr.State)
		if wantsDizzy() then
			startDizzy(player)
		else
			stopDizzy(player, last == Contract.State.Downed and state == Contract.State.Standing)
		end
		if state == Contract.State.Eliminated and last ~= Contract.State.Eliminated then
			CharacterFx.poof(player)
		end
		last = state
	end
	player:GetAttributeChangedSignal(Contract.Attr.State):Connect(onState)
	player.CharacterAdded:Connect(function()
		stopDizzy(player, false)
		task.defer(function()
			if wantsDizzy() then
				startDizzy(player)
			end
		end)
	end)
	if wantsDizzy() then
		startDizzy(player)
	end
end

function CharacterFx.start()
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		stopDizzy(p, false)
	end)
end

return CharacterFx
