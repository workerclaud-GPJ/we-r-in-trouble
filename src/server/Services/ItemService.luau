--!strict
--[[
	ItemService — small items (batteries): random spawn (max 1 per Zone), pickup (press),
	weld to RightHand, consume at socket, auto-drop on Downed/Eliminated/Left,
	anchored floor-raycast placement, KillY recovery after 3s, Deliver count reduction.
	GDD §3.4 Deliver, §5.7 (no idle respawn). Drop: G / Drop button (Remote DropItem);
	pressing pickup on another item while holding swaps (held item is put down in front).

	Features.ItemPhysics (default off = the behaviour above, unchanged):
	  lying items (spawned / dropped) are unanchored, CanCollide, CustomPhysicalProperties from
	  the ItemDef, CollisionGroup Items (collides with the world, NOT with Players) and server
	  network owner (clients cannot fling them). Held items stay welded + massless + non-colliding.
	  Safety: KillY (3 s) and out-of-bounds / inside-geometry checks return an item to its origin.
	  Earthquake shake pulses nudge lying items (DisasterService.Shake, rate-limited).
	  At most Interaction.ITEM_PHYSICS_MAX lying physics items; extra ones stay anchored.
	Capabilities (Config.Items[...].capabilities): consumeCapability / countCapability for
	capability Deliver objectives; Medium items use Interaction.MEDIUM_CARRY_SPEED_MULT.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local DisasterService = require(script.Parent.DisasterService)
local Geometry = require(Shared.Util.Geometry)

local Attr = Contract.Attr
local I = Config.Interaction
local CARRY_KEY = "Carry"
local PHYSICS = Config.Features.ItemPhysics
local ITEMS_GROUP = Contract.CollisionGroup.Items

type ItemRec = {
	model: Model,
	handle: BasePart,
	itemType: string,
	owner: string,
	isOpen: () -> boolean,
	origin: BasePart,
	prompt: ProximityPrompt,
	carrier: Player?,
	weld: WeldConstraint?,
	everPicked: boolean,
	firstPicker: Player?,
	droppedAt: number,
	belowKillSince: number?,
	physics: boolean, -- lying as an unanchored physics object (Features.ItemPhysics)
	stuckCount: number,
}

local ItemService = {}

local items: { ItemRec } = {}
local pendingRemoval: { [string]: number } = {}
local serial = 0
local rng = Random.new()
local lastStuckCheck = 0
local lastShakeKick = -math.huge

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function find(predicate: (ItemRec) -> boolean): ItemRec?
	for _, item in items do
		if predicate(item) then
			return item
		end
	end
	return nil
end

local function carriedBy(player: Player): ItemRec?
	return find(function(item: ItemRec): boolean
		return item.carrier == player
	end)
end

local function setAnchored(item: ItemRec, anchored: boolean)
	for _, d in item.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
		end
	end
end

local function hasCapability(itemType: string, capability: string): boolean
	local def = Config.Items[itemType]
	return def ~= nil and table.find(def.capabilities, capability) ~= nil
end

local function carrySpeedMult(itemType: string): number
	local def = Config.Items[itemType]
	return if def and def.size == "Medium" then I.MEDIUM_CARRY_SPEED_MULT else I.SMALL_CARRY_SPEED_MULT
end

local function physicsCount(): number
	local n = 0
	for _, item in items do
		if item.physics then
			n += 1
		end
	end
	return n
end

local function stopMotion(item: ItemRec)
	item.handle.AssemblyLinearVelocity = Vector3.zero
	item.handle.AssemblyAngularVelocity = Vector3.zero
end

-- Lying state. Legacy (feature off or physics cap reached): anchored, non-colliding.
-- ItemPhysics: unanchored, colliding with the world only, server-owned.
local function setLying(item: ItemRec)
	if not PHYSICS or (not item.physics and physicsCount() >= I.ITEM_PHYSICS_MAX) then
		item.physics = false
		setAnchored(item, true)
		return
	end
	local def = Config.Items[item.itemType]
	local props = PhysicalProperties.new(
		(def and def.density) or I.ITEM_DEFAULT_DENSITY,
		(def and def.friction) or I.ITEM_DEFAULT_FRICTION,
		(def and def.elasticity) or I.ITEM_DEFAULT_ELASTICITY
	)
	for _, d in item.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = true
			d.CanTouch = false
			d.Massless = false
			d.CollisionGroup = ITEMS_GROUP
			d.CustomPhysicalProperties = props
		end
	end
	item.physics = true
	item.stuckCount = 0
	stopMotion(item)
	if item.handle:IsDescendantOf(Workspace) then
		pcall(function()
			item.handle:SetNetworkOwner(nil) -- server simulates: no client can fling it
		end)
	end
end

local function raycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local runtime = MapService.getRuntime()
	if runtime then
		table.insert(exclude, runtime)
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

local function placeAt(item: ItemRec, floor: Vector3)
	local cf = CFrame.new(floor + Vector3.new(0, item.handle.Size.Y / 2 + 0.1, 0))
	item.model:PivotTo(cf)
end

local function removeItem(item: ItemRec)
	local i = table.find(items, item)
	if i then
		table.remove(items, i)
	end
	if item.carrier then
		local carrier = item.carrier
		item.carrier = nil
		carrier:SetAttribute(Attr.Holding, "")
		PlayerStateService.setPlayerSpeedModifier(carrier, CARRY_KEY, nil)
	end
	item.model:Destroy()
end

----------------------------------------------------------------------------
-- Creation
----------------------------------------------------------------------------

local function buildModel(itemType: string): (Model, BasePart)
	local def = Config.Items[itemType]
	local model = Instance.new("Model")
	serial += 1
	model.Name = `Item_{itemType}_{serial}`
	local asset = MapService.findAsset(def and def.model, "Items")
	local handle: BasePart
	local clone = if asset then asset:Clone() else nil
	local primary: BasePart? = nil
	if clone and clone:IsA("Model") then
		for _, child in clone:GetChildren() do
			child.Parent = model
		end
		clone:Destroy()
		primary = model:FindFirstChildWhichIsA("BasePart", true)
	elseif clone and clone:IsA("BasePart") then
		clone.Parent = model
		primary = clone
	end
	if primary then
		handle = primary
	else
		-- placeholder: AA battery 2.5 x 0.7 (GDD 1.1)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(2.5, 0.7, 0.7)
		part.Color = Color3.fromRGB(255, 200, 40)
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = model
		handle = part
	end
	model.PrimaryPart = handle
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = handle, d
			w.Parent = handle
		end
	end
	if not handle:FindFirstChildWhichIsA("Light") then
		local light = Instance.new("PointLight")
		light.Range = 10
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 220, 120)
		light.Parent = handle
	end
	return model, handle
end

local onPickup: (item: ItemRec, player: Player) -> () -- forward declaration

local function createItem(itemType: string, owner: string, isOpen: () -> boolean, origin: BasePart): ItemRec?
	local runtime = MapService.getRuntime()
	if not runtime then
		return nil
	end
	local model, handle = buildModel(itemType)
	local def = Config.Items[itemType]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Contract.Name.PickupPrompt
	prompt.ActionText = "Pick up"
	prompt.ObjectText = if def then def.displayName else itemType
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = I.INTERACT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = handle

	model:SetAttribute(Attr.ItemType, itemType)
	model:SetAttribute(Attr.Carrier, 0)
	CollectionService:AddTag(model, Contract.Tag.Item)

	local item: ItemRec = {
		model = model,
		handle = handle,
		itemType = itemType,
		owner = owner,
		isOpen = isOpen,
		origin = origin,
		prompt = prompt,
		carrier = nil,
		weld = nil,
		everPicked = false,
		firstPicker = nil,
		droppedAt = now(),
		belowKillSince = nil,
		physics = false,
		stuckCount = 0,
	}
	setAnchored(item, true)
	model.Parent = runtime
	placeAt(item, origin.Position - Vector3.new(0, origin.Size.Y / 2, 0)) -- marker sits on the floor
	if PHYSICS then
		setLying(item)
	end
	prompt.Triggered:Connect(function(player: Player)
		onPickup(item, player)
	end)
	table.insert(items, item)
	return item
end

-- Spawns one item at a given ItemSpawn marker (LootService). Returns true on success.
function ItemService.spawnAt(itemType: string, owner: string, isOpen: () -> boolean, origin: BasePart): boolean
	return createItem(itemType, owner, isOpen, origin) ~= nil
end

-- Spawns `count` items at random ItemSpawns of this type, max one per Zone.
function ItemService.spawnItems(itemType: string, count: number, owner: string, isOpen: () -> boolean): number
	local byZone: { [string]: { BasePart } } = {}
	local zones: { string } = {}
	for _, inst in MapService.tagged(Contract.Tag.ItemSpawn) do
		if inst:IsA("BasePart") and inst:GetAttribute(Attr.ItemType) == itemType then
			local zoneAttr = inst:GetAttribute(Attr.Zone)
			local zone = if typeof(zoneAttr) == "string" then zoneAttr else inst:GetFullName()
			if not byZone[zone] then
				byZone[zone] = {}
				table.insert(zones, zone)
			end
			table.insert(byZone[zone], inst)
		end
	end
	if #zones < count then
		warn(`[ItemService] only {#zones} {itemType} zones for {count} items`)
	end
	for i = #zones, 2, -1 do
		local j = rng:NextInteger(1, i)
		zones[i], zones[j] = zones[j], zones[i]
	end
	local spawned = 0
	for i = 1, math.min(count, #zones) do
		local list = byZone[zones[i]]
		if createItem(itemType, owner, isOpen, list[rng:NextInteger(1, #list)]) then
			spawned += 1
		end
	end
	return spawned
end

----------------------------------------------------------------------------
-- Pickup / drop / consume
----------------------------------------------------------------------------

onPickup = function(item: ItemRec, player: Player)
	if not table.find(items, item) or item.carrier or not item.isOpen() then
		return
	end
	if not PlayerStateService.isStanding(player) or not PlayerStateService.isParticipant(player) then
		return
	end
	local char = player.Character
	local hrp = PlayerStateService.getHRP(player)
	if not (char and hrp) or (hrp.Position - item.handle.Position).Magnitude > I.INTERACT_SERVER_RANGE then
		return
	end
	if carriedBy(player) then
		-- swap: put the held item down in front, then take this one
		ItemService.drop(player)
		if carriedBy(player) or item.carrier or not table.find(items, item) then
			return
		end
	end
	-- Art contract: UpperTorso.CarryAttachment (chest hug); fallback RightHand, then HRP
	local carryAttachment = char:FindFirstChild("CarryAttachment", true)
	local hand = char:FindFirstChild("RightHand")
	local anchorPart: BasePart = if hand and hand:IsA("BasePart") then hand else hrp
	local holdCFrame = anchorPart.CFrame * CFrame.new(0, -0.6, -0.4)
	if carryAttachment and carryAttachment:IsA("Attachment") and carryAttachment.Parent and carryAttachment.Parent:IsA("BasePart") then
		anchorPart = carryAttachment.Parent
		holdCFrame = carryAttachment.WorldCFrame
	end

	item.carrier = player
	item.belowKillSince = nil
	if not item.everPicked then
		item.everPicked = true
		item.firstPicker = player
	end
	item.prompt.Enabled = false
	item.physics = false
	setAnchored(item, false)
	if PHYSICS then
		stopMotion(item)
	end
	item.model:PivotTo(holdCFrame)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = item.handle, anchorPart
	weld.Parent = item.handle
	item.weld = weld
	item.model:SetAttribute(Attr.Carrier, player.UserId)
	player:SetAttribute(Attr.Holding, item.itemType)
	PlayerStateService.setPlayerSpeedModifier(player, CARRY_KEY, carrySpeedMult(item.itemType))
end

function ItemService.isHolding(player: Player, itemType: string?): boolean
	local item = carriedBy(player)
	return item ~= nil and (itemType == nil or item.itemType == itemType)
end

function ItemService.hasCapability(itemType: string, capability: string): boolean
	return hasCapability(itemType, capability)
end

-- Items in the map of this type (held or lying), optionally of one owner.
function ItemService.countType(itemType: string, owner: string?): number
	local n = 0
	for _, item in items do
		if (owner == nil or item.owner == owner) and item.itemType == itemType then
			n += 1
		end
	end
	return n
end

-- Items in the map with this capability (held or lying), optionally of one owner.
function ItemService.countCapability(capability: string, owner: string?): number
	local n = 0
	for _, item in items do
		if (owner == nil or item.owner == owner) and hasCapability(item.itemType, capability) then
			n += 1
		end
	end
	return n
end

-- First player who picked up the item the player holds (Deliver credit).
function ItemService.firstPickerOf(player: Player): Player?
	local item = carriedBy(player)
	return item and item.firstPicker
end

function ItemService.drop(player: Player)
	local item = carriedBy(player)
	if not item then
		return
	end
	local hrp = PlayerStateService.getHRP(player)
	local origin = if hrp then hrp.Position else item.handle.Position
	local look = if hrp then hrp.CFrame.LookVector * Vector3.new(1, 0, 1) else Vector3.zero
	if look.Magnitude > 0 then
		look = look.Unit * I.ITEM_DROP_RAY_DISTANCE
	end
	local params = raycastParams()
	local down = Vector3.new(0, -20, 0)
	local hit = Workspace:Raycast(origin + look, down, params) or Workspace:Raycast(origin, down, params)

	if item.weld then
		item.weld:Destroy()
		item.weld = nil
	end
	item.carrier = nil
	player:SetAttribute(Attr.Holding, "")
	PlayerStateService.setPlayerSpeedModifier(player, CARRY_KEY, nil)
	item.model:SetAttribute(Attr.Carrier, 0)
	setAnchored(item, true)
	placeAt(item, if hit then hit.Position else origin - Vector3.new(0, 2.5, 0))
	if PHYSICS then
		setLying(item)
	end
	item.droppedAt = now()

	local pending = pendingRemoval[item.owner] or 0
	if pending > 0 then
		pendingRemoval[item.owner] = pending - 1
		removeItem(item)
		return
	end
	item.prompt.Enabled = true
end

-- Removes the held item if it matches; returns true on success.
function ItemService.consume(player: Player, itemType: string): boolean
	local item = carriedBy(player)
	if not item or item.itemType ~= itemType then
		return false
	end
	removeItem(item)
	return true
end

-- Removes the held item if it has the capability; returns the consumed itemType or nil.
function ItemService.consumeCapability(player: Player, capability: string): string?
	local item = carriedBy(player)
	if not item or not hasCapability(item.itemType, capability) then
		return nil
	end
	local itemType = item.itemType
	removeItem(item)
	return itemType
end

-- Keep at most `keep` items of this owner (GDD 3.4: remove unheld never-picked first,
-- then unheld by earliest drop; if all are held, remove the next one dropped).
function ItemService.reduce(owner: string, keep: number)
	local mine: { ItemRec } = {}
	for _, item in items do
		if item.owner == owner then
			table.insert(mine, item)
		end
	end
	local excess = #mine - math.max(0, keep) - (pendingRemoval[owner] or 0)
	if excess <= 0 then
		return
	end
	table.sort(mine, function(a: ItemRec, b: ItemRec): boolean
		if (a.carrier == nil) ~= (b.carrier == nil) then
			return a.carrier == nil
		end
		if a.everPicked ~= b.everPicked then
			return not a.everPicked
		end
		return a.droppedAt < b.droppedAt
	end)
	for _, item in mine do
		if excess <= 0 then
			break
		end
		if item.carrier == nil then
			removeItem(item)
		else
			pendingRemoval[owner] = (pendingRemoval[owner] or 0) + 1
		end
		excess -= 1
	end
end

function ItemService.removeOwner(owner: string)
	for _, item in table.clone(items) do
		if item.owner == owner then
			removeItem(item)
		end
	end
	pendingRemoval[owner] = nil
end

----------------------------------------------------------------------------
-- Tick + lifecycle
----------------------------------------------------------------------------

local function returnToOrigin(item: ItemRec)
	item.belowKillSince = nil
	item.stuckCount = 0
	if item.physics then
		item.handle.Anchored = true -- freeze while teleporting, then hand back to physics
		placeAt(item, item.origin.Position - Vector3.new(0, item.origin.Size.Y / 2, 0))
		setLying(item)
	else
		placeAt(item, item.origin.Position - Vector3.new(0, item.origin.Size.Y / 2, 0))
	end
end

-- ItemPhysics: an unanchored item that fell below Workspace.FallenPartsDestroyHeight was deleted
-- by the engine. Rebuild it at its origin (same owner/isOpen) so Deliver never loses an item.
local function respawnLost(item: ItemRec)
	local i = table.find(items, item)
	if i then
		table.remove(items, i)
	end
	pcall(function()
		item.model:Destroy()
	end)
	local fresh = createItem(item.itemType, item.owner, item.isOpen, item.origin)
	if fresh then
		fresh.everPicked = item.everPicked
		fresh.firstPicker = item.firstPicker
	end
	warn(`[ItemService] {item.itemType} was destroyed (fell out of the world) — rebuilt at origin`)
end

-- Play area for the out-of-bounds check: map DropArea (full floor; the floor may be split
-- around the drain) or PrimaryPart footprint + exit zones (+ margin).
local function playArea(): (Vector3?, Vector3?)
	local map = MapService.getMap()
	local dropArea = map and map:FindFirstChild(Contract.Name.DropArea, true)
	local floor = if dropArea and dropArea:IsA("BasePart") then dropArea else map and map.PrimaryPart
	if not floor then
		return nil, nil
	end
	local lo = floor.Position - floor.Size / 2
	local hi = floor.Position + floor.Size / 2
	for _, zone in MapService.exitZones() do
		lo = lo:Min(zone.Position - zone.Size / 2)
		hi = hi:Max(zone.Position + zone.Size / 2)
	end
	local _, boundsSize = MapService.getBounds()
	local m = I.ITEM_BOUNDS_MARGIN
	return Vector3.new(lo.X - m, -math.huge, lo.Z - m), Vector3.new(hi.X + m, lo.Y + boundsSize.Y + m, hi.Z + m)
end

-- Centre of the item inside a solid queryable block (CanQuery = false props are not seen).
local function insideGeometry(item: ItemRec, params: OverlapParams): boolean
	local center = item.handle.Position
	for _, part in Workspace:GetPartsInPart(item.handle, params) do
		if part:IsA("Part") and part.Shape == Enum.PartType.Block and part.Anchored and Geometry.pointInPart(center, part, -0.05) then
			return true
		end
	end
	return false
end

local function checkStuck()
	local lo, hi = playArea()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local runtime = MapService.getRuntime()
	if runtime then
		table.insert(exclude, runtime)
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	for _, item in items do
		if item.physics and item.carrier == nil and item.model.Parent then
			local pos = item.handle.Position
			local out = false
			if lo and hi then
				out = pos.X < lo.X or pos.X > hi.X or pos.Z < lo.Z or pos.Z > hi.Z or pos.Y > hi.Y
			end
			if out or insideGeometry(item, params) then
				item.stuckCount += 1
				if item.stuckCount >= I.ITEM_STUCK_CONFIRM then
					warn(`[ItemService] {item.model.Name} out of bounds / stuck at {pos} — back to origin`)
					returnToOrigin(item)
				end
			else
				item.stuckCount = 0
			end
		end
	end
end

function ItemService.update(_dt: number)
	local killY = MapService.killY()
	local t = now()
	local lost: { ItemRec }? = nil
	for _, item in items do
		if PHYSICS and item.carrier == nil and not item.handle:IsDescendantOf(Workspace) then
			lost = lost or {}
			table.insert(lost :: { ItemRec }, item)
		elseif item.carrier == nil and item.model.Parent then
			if PHYSICS and item.physics and item.handle.Position.Y < killY then
				-- unanchored item keeps falling: FallenPartsDestroyHeight (-80) would delete it long
				-- before the 3 s delay, so return it on the first tick below KillY
				returnToOrigin(item)
			elseif item.handle.Position.Y < killY then
				item.belowKillSince = item.belowKillSince or t
				if t - (item.belowKillSince :: number) >= I.ITEM_KILLY_RESPAWN_DELAY then
					item.belowKillSince = nil
					if PHYSICS then
						returnToOrigin(item)
					else
						placeAt(item, item.origin.Position - Vector3.new(0, item.origin.Size.Y / 2, 0))
					end
				end
			else
				item.belowKillSince = nil
			end
		end
	end
	if lost then
		for _, item in lost do
			respawnLost(item)
		end
	end
	if PHYSICS and t - lastStuckCheck >= I.ITEM_STUCK_CHECK_INTERVAL then
		lastStuckCheck = t
		checkStuck()
	end
end

-- Earthquake: small random horizontal kicks to lying physics items (server-owned, so the
-- velocity change replicates). Rate-limited: at most one kick per ITEM_SHAKE_MIN_INTERVAL.
local function kickLyingItems(intensity: number)
	local t = now()
	if t - lastShakeKick < I.ITEM_SHAKE_MIN_INTERVAL then
		return
	end
	lastShakeKick = t
	local scale = math.clamp(intensity / 0.35, 0.5, 2)
	for _, item in items do
		if item.physics and item.carrier == nil and item.model.Parent and rng:NextNumber() < I.ITEM_SHAKE_CHANCE then
			local angle = rng:NextNumber(0, math.pi * 2)
			local speed = rng:NextNumber(I.ITEM_SHAKE_SPEED_MIN, I.ITEM_SHAKE_SPEED_MAX) * scale
			item.handle.AssemblyLinearVelocity += Vector3.new(math.cos(angle) * speed, I.ITEM_SHAKE_UP, math.sin(angle) * speed)
		end
	end
end

local function onShake(stageId: string, intensity: number, duration: number)
	if stageId ~= Contract.Stage.Active and stageId ~= Contract.Stage.Critical then
		return
	end
	local kicks = math.clamp(math.ceil(duration / I.ITEM_SHAKE_MIN_INTERVAL), 1, I.ITEM_SHAKE_KICKS_MAX)
	for i = 0, kicks - 1 do
		task.delay(i * (I.ITEM_SHAKE_MIN_INTERVAL + 0.1) + 0.05, function()
			if PlayerStateService.isMatchActive() then
				kickLyingItems(intensity)
			end
		end)
	end
end

function ItemService.reset()
	for _, item in table.clone(items) do
		removeItem(item)
	end
	table.clear(pendingRemoval)
end

function ItemService.start()
	if PHYSICS then
		pcall(function()
			PhysicsService:RegisterCollisionGroup(ITEMS_GROUP)
		end)
		pcall(function()
			-- Players group is registered by PlayerStateService.start (runs after this): register here too
			PhysicsService:RegisterCollisionGroup(Contract.CollisionGroup.Players)
		end)
		PhysicsService:CollisionGroupSetCollidable(ITEMS_GROUP, Contract.CollisionGroup.Players, false)
		DisasterService.Shake:Connect(onShake)
	end
	-- Drop button / G key (DropController): only a standing participant holding an item
	local lastDrop: { [Player]: number } = {}
	Remotes.get("DropItem").OnServerEvent:Connect(function(player: Player)
		local t = os.clock()
		if t - (lastDrop[player] or 0) < 0.3 then
			return
		end
		lastDrop[player] = t
		if PlayerStateService.isStanding(player) and PlayerStateService.isParticipant(player) then
			ItemService.drop(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastDrop[player] = nil
	end)
	PlayerStateService.Downed:Connect(ItemService.drop)
	PlayerStateService.Eliminated:Connect(ItemService.drop)
	PlayerStateService.Left:Connect(ItemService.drop)
end

return ItemService
