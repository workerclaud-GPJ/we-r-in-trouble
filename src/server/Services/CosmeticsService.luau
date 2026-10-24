--!strict
--[[
	CosmeticsService — lobby cosmetics, no saving (ARCHITECTURE §2 SetCosmetic, §5 FurColor/Hat).

	Client sends SetCosmetic(kind, id). Server validates (types, id in Config.Cosmetics,
	player State = Lobby, rate limit), writes the player attribute and re-applies it.
	Every new character (lobby, match spawn, respawn) gets fur recolor + hat welded to Head.
	Visual only: hat parts are Massless / no collide / no query / no touch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local CosmeticsConfig = require(Shared.Config.Cosmetics)

local C = Config.Cosmetics
local Attr = Contract.Attr

local CosmeticsService = {}

local rate: { [Player]: { count: number, windowStart: number } } = {}

local function validFur(id: any): boolean
	return typeof(id) == "string" and C.FUR[id] ~= nil
end

local function validHat(id: any): boolean
	return typeof(id) == "string" and C.HATS[id] ~= nil
end

local function findPart(character: Model, name: string): BasePart?
	local cosmetics = character:FindFirstChild(C.COSMETICS_MODEL)
	local p = character:FindFirstChild(name) or (cosmetics and cosmetics:FindFirstChild(name))
	return if p and p:IsA("BasePart") then p else nil
end

local function paint(character: Model, names: { string }, color: Color3)
	for _, name in names do
		local p = findPart(character, name)
		if p then
			p.Color = color
		end
	end
end

local function applyFur(character: Model, furId: string)
	local pal = C.FUR[furId] or C.FUR[C.DEFAULT_FUR]
	paint(character, C.FUR_PARTS, pal.Fur)
	paint(character, C.LIMB_PARTS, pal.Limb or pal.Fur)
	paint(character, C.BELLY_PARTS, pal.Belly)
	paint(character, C.EAR_PARTS, pal.EarOuter)
	paint(character, C.TAIL_PARTS, pal.Tail)
end

local function makeHatPart(spec: CosmeticsConfig.HatPart, head: BasePart, index: number): BasePart
	local p = Instance.new("Part")
	p.Name = "HatPart" .. index
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Material = spec.material or Enum.Material.SmoothPlastic
	p.Color = spec.color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = spec.size
	local offset = spec.offset
	if spec.shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif spec.shape == "CylinderY" then
		p.Shape = Enum.PartType.Cylinder
		offset = offset * CFrame.Angles(0, 0, math.rad(90)) -- Roblox cylinders run along X
	elseif spec.shape == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = head.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Name = "HatWeld"
	weld.Part0 = head
	weld.Part1 = p
	weld.C0 = offset
	weld.C1 = CFrame.identity
	weld.Parent = p
	return p
end

local function applyHat(character: Model, hatId: string)
	local old = character:FindFirstChild(C.HAT_MODEL)
	if old then
		old:Destroy()
	end
	local specs = C.HATS[hatId]
	local head = character:FindFirstChild("Head")
	if not specs or #specs == 0 or not (head and head:IsA("BasePart")) then
		return
	end
	local model = Instance.new("Model")
	model.Name = C.HAT_MODEL
	for i, spec in specs do
		makeHatPart(spec, head, i).Parent = model
	end
	model.Parent = character
end

local function furOf(player: Player): string
	local v = player:GetAttribute(Attr.FurColor)
	return if validFur(v) then v :: string else C.DEFAULT_FUR
end

local function hatOf(player: Player): string
	local v = player:GetAttribute(Attr.Hat)
	return if validHat(v) then v :: string else C.DEFAULT_HAT
end

function CosmeticsService.apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	applyFur(character, furOf(player))
	applyHat(character, hatOf(player))
end

local function rateOk(player: Player): boolean
	local t = os.clock()
	local r = rate[player]
	if not r or t - r.windowStart >= 1 then
		rate[player] = { count = 1, windowStart = t }
		return true
	end
	r.count += 1
	return r.count <= C.SET_RATE_PER_SECOND
end

local function onSetCosmetic(player: Player, kind: any, id: any)
	if not rateOk(player) then
		return
	end
	local state = player:GetAttribute(Attr.State)
	if state ~= nil and state ~= Contract.State.Lobby then
		return -- lobby only
	end
	if kind == Attr.FurColor and validFur(id) then
		player:SetAttribute(Attr.FurColor, id)
	elseif kind == Attr.Hat and validHat(id) then
		player:SetAttribute(Attr.Hat, id)
	else
		return
	end
	CosmeticsService.apply(player)
end

local function onPlayer(player: Player)
	if not validFur(player:GetAttribute(Attr.FurColor)) then
		player:SetAttribute(Attr.FurColor, C.DEFAULT_FUR)
	end
	if not validHat(player:GetAttribute(Attr.Hat)) then
		player:SetAttribute(Attr.Hat, C.DEFAULT_HAT)
	end
	player.CharacterAdded:Connect(function(character: Model)
		-- StarterCharacter parts are present on add; defer one step so the rig is parented
		task.defer(function()
			if character.Parent and player.Character == character then
				CosmeticsService.apply(player)
			end
		end)
	end)
	if player.Character then
		CosmeticsService.apply(player)
	end
end

function CosmeticsService.start()
	Remotes.get("SetCosmetic").OnServerEvent:Connect(onSetCosmetic)
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		rate[p] = nil
	end)
end

return CosmeticsService
