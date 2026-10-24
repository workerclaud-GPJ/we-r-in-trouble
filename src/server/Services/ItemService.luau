--!strict
--[[
	ItemService — small items (batteries): random spawn (max 1 per Zone), pickup (press),
	weld to RightHand, consume at socket, auto-drop on Downed/Eliminated/Left,
	anchored floor-raycast placement, KillY recovery after 3s, Deliver count reduction.
	GDD §3.4 Deliver, §5.7 (Deadline: no Drop button, no idle respawn).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local Attr = Contract.Attr
local I = Config.Interaction
local CARRY_KEY = "Carry"

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
}

local ItemService = {}

local items: { ItemRec } = {}
local pendingRemoval: { [string]: number } = {}
local serial = 0
local rng = Random.new()

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
	}
	setAnchored(item, true)
	model.Parent = runtime
	placeAt(item, origin.Position - Vector3.new(0, origin.Size.Y / 2, 0)) -- marker sits on the floor
	prompt.Triggered:Connect(function(player: Player)
		onPickup(item, player)
	end)
	table.insert(items, item)
	return item
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
	if carriedBy(player) then
		return
	end
	local char = player.Character
	local hrp = PlayerStateService.getHRP(player)
	if not (char and hrp) or (hrp.Position - item.handle.Position).Magnitude > I.INTERACT_SERVER_RANGE then
		return
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
	setAnchored(item, false)
	item.model:PivotTo(holdCFrame)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = item.handle, anchorPart
	weld.Parent = item.handle
	item.weld = weld
	item.model:SetAttribute(Attr.Carrier, player.UserId)
	player:SetAttribute(Attr.Holding, item.itemType)
	PlayerStateService.setPlayerSpeedModifier(player, CARRY_KEY, I.SMALL_CARRY_SPEED_MULT)
end

function ItemService.isHolding(player: Player, itemType: string?): boolean
	local item = carriedBy(player)
	return item ~= nil and (itemType == nil or item.itemType == itemType)
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

function ItemService.update(_dt: number)
	local killY = MapService.killY()
	local t = now()
	for _, item in items do
		if item.carrier == nil and item.model.Parent then
			if item.handle.Position.Y < killY then
				item.belowKillSince = item.belowKillSince or t
				if t - (item.belowKillSince :: number) >= I.ITEM_KILLY_RESPAWN_DELAY then
					item.belowKillSince = nil
					placeAt(item, item.origin.Position - Vector3.new(0, item.origin.Size.Y / 2, 0))
				end
			else
				item.belowKillSince = nil
			end
		end
	end
end

function ItemService.reset()
	for _, item in table.clone(items) do
		removeItem(item)
	end
	table.clear(pendingRemoval)
end

function ItemService.start()
	PlayerStateService.Downed:Connect(ItemService.drop)
	PlayerStateService.Eliminated:Connect(ItemService.drop)
	PlayerStateService.Left:Connect(ItemService.drop)
end

return ItemService
