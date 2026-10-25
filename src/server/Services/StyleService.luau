--!strict
--[[
	StyleService — coins + character styles (Config.Styles; client: StyleShopController).
	Player attributes (replicated): Coins (number), OwnedStyles ("Ninja,Gym"), Style (equipped id
	or ""), DamageTakenMult (number, PlayerStateService.damage), NoCarrySlow (bool, ItemService).
	Saved in a DataStore when API access works (published game / Studio with API access);
	otherwise coins live for the session only (warned once). First visit: START_COINS.
	Shop (Remote StyleShop): only in the lobby; "buy" deducts coins and equips, "equip" any owned
	style or "" (none). Rewards: RoundService calls reward() at match end.
	Perks: speed x (SpeedMult modifier "Style") while standing in a match; double jump is
	client-side (StyleShopController) for styles with doubleJump; a head band shows the style.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerStateService = require(script.Parent.PlayerStateService)

local S = Config.Styles
local State = Contract.State

local StyleService = {}

local store: DataStore? = nil
local loaded: { [Player]: boolean } = {}
local lastAction: { [Player]: number } = {}
local warnedNoStore = false

local function owned(player: Player): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local csv = player:GetAttribute("OwnedStyles")
	if typeof(csv) == "string" then
		for _, id in string.split(csv, ",") do
			if S.STYLES[id] then
				out[id] = true
			end
		end
	end
	return out
end

local function setOwned(player: Player, set: { [string]: boolean })
	local list: { string } = {}
	for _, id in S.ORDER do
		if set[id] then
			table.insert(list, id)
		end
	end
	player:SetAttribute("OwnedStyles", table.concat(list, ","))
end

local function save(player: Player)
	local ds = store
	if not ds or not loaded[player] then
		return
	end
	local data = {
		coins = player:GetAttribute("Coins"),
		owned = player:GetAttribute("OwnedStyles"),
		style = player:GetAttribute("Style"),
		exits = player:GetAttribute("ExitsFound"),
	}
	task.spawn(function()
		local ok, err = pcall(function()
			ds:SetAsync(tostring(player.UserId), data)
		end)
		if not ok then
			warn("[Style] save failed:", err)
		end
	end)
end

local function applyPerks(player: Player)
	local def = S.STYLES[player:GetAttribute("Style") or ""]
	player:SetAttribute("DamageTakenMult", if def and def.damageTakenMult then def.damageTakenMult else nil)
	player:SetAttribute("NoCarrySlow", if def and def.noCarrySlow then true else nil)
	player:SetAttribute("DoubleJump", if def and def.doubleJump then true else nil)
end

-- head band in the style colour (visual only)
local BAND: { [string]: { Color3 } } = {
	Ninja = { Color3.fromRGB(25, 25, 30), Color3.fromRGB(220, 40, 40) },
	Gym = { Color3.fromRGB(230, 50, 50), Color3.fromRGB(255, 255, 255) },
}
local function applyLook(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not (char and head and head:IsA("BasePart")) then
		return
	end
	local old = char:FindFirstChild("WRIT_StyleBand")
	if old then
		old:Destroy()
	end
	local id = player:GetAttribute("Style")
	local colors = typeof(id) == "string" and BAND[id]
	if not colors then
		return
	end
	local m = Instance.new("Model")
	m.Name = "WRIT_StyleBand"
	local function part(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.Fabric
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		if shape then
			p.Shape = shape
		end
		p.CFrame = head.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = p, head
		w.Parent = p
		p.Parent = m
		return p
	end
	-- band around the forehead (cylinder axis X -> rotate to Y)
	part(Vector3.new(0.45, 2.15, 2.15), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), colors[1], Enum.PartType.Cylinder)
	part(Vector3.new(0.25, 0.9, 0.25), CFrame.new(0.25, 0.55, 1.05) * CFrame.Angles(math.rad(40), 0, math.rad(20)), colors[2])
	part(Vector3.new(0.25, 0.9, 0.25), CFrame.new(-0.25, 0.55, 1.05) * CFrame.Angles(math.rad(40), 0, math.rad(-20)), colors[2])
	if id == "Ninja" then
		part(Vector3.new(2.0, 0.55, 0.3), CFrame.new(0, 0.15, -0.95), Color3.fromRGB(25, 25, 30)) -- mask over the eyes line
	end
	m.Parent = char
end

local function load(player: Player)
	local data: any = nil
	local ds = store
	if ds then
		local ok, res = pcall(function()
			return ds:GetAsync(tostring(player.UserId))
		end)
		if ok then
			data = res
		else
			warn("[Style] load failed (coins are session-only):", res)
			store = nil
		end
	end
	if player.Parent ~= Players then
		return
	end
	local coins = if typeof(data) == "table" and typeof(data.coins) == "number" then data.coins else S.START_COINS
	player:SetAttribute("Coins", coins)
	player:SetAttribute("OwnedStyles", if typeof(data) == "table" and typeof(data.owned) == "string" then data.owned else "")
	local style = if typeof(data) == "table" and typeof(data.style) == "string" then data.style else ""
	player:SetAttribute("Style", if owned(player)[style] then style else "")
	player:SetAttribute("ExitsFound", if typeof(data) == "table" and typeof(data.exits) == "string" then data.exits else "")
	loaded[player] = true
	applyPerks(player)
	applyLook(player)
end

local function onShop(player: Player, action: any, id: any)
	if not S.ENABLED or not loaded[player] or typeof(action) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local t = os.clock()
	if t - (lastAction[player] or 0) < 0.4 then
		return
	end
	lastAction[player] = t
	if PlayerStateService.getState(player) ~= State.Lobby then
		return
	end
	local set = owned(player)
	if action == "buy" then
		local def = S.STYLES[id]
		local coins = player:GetAttribute("Coins")
		if not def or set[id] or typeof(coins) ~= "number" or coins < def.price then
			return
		end
		player:SetAttribute("Coins", coins - def.price)
		set[id] = true
		setOwned(player, set)
		player:SetAttribute("Style", id)
	elseif action == "equip" then
		if id ~= "" and not set[id] then
			return
		end
		player:SetAttribute("Style", id)
	else
		return
	end
	applyPerks(player)
	applyLook(player)
	save(player)
end

-- RoundService, end of a match: everyone who played gets coins, escapers more.
function StyleService.reward(participants: { Player }, escaped: { Player }, exitId: string?)
	if not S.ENABLED then
		return
	end
	local esc: { [Player]: boolean } = {}
	for _, p in escaped do
		esc[p] = true
	end
	for _, p in participants do
		if p.Parent == Players and loaded[p] then
			local add = if esc[p] then S.ESCAPE_REWARD else S.PLAY_REWARD
			local c = p:GetAttribute("Coins")
			p:SetAttribute("Coins", (if typeof(c) == "number" then c else 0) + add)
			p:SetAttribute("LastReward", nil)
			p:SetAttribute("LastReward", add)
			-- escape journal: which ways out this hamster has found
			if esc[p] and exitId then
				local found = p:GetAttribute("ExitsFound")
				local f = if typeof(found) == "string" then found else ""
				if not string.find("," .. f .. ",", "," .. exitId .. ",", 1, true) then
					p:SetAttribute("ExitsFound", if f == "" then exitId else f .. "," .. exitId)
					p:SetAttribute("NewExit", nil)
					p:SetAttribute("NewExit", exitId)
				end
			end
			save(p)
		end
	end
end

function StyleService.start()
	if not S.ENABLED then
		return
	end
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(S.DATASTORE)
	end)
	if ok then
		store = res
	elseif not warnedNoStore then
		warnedNoStore = true
		warn("[Style] DataStore unavailable (coins are session-only):", res)
	end
	Remotes.get("StyleShop").OnServerEvent:Connect(onShop)
	local function added(player: Player)
		task.spawn(load, player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			applyLook(player)
		end)
	end
	for _, p in Players:GetPlayers() do
		added(p)
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(p: Player)
		save(p)
		loaded[p] = nil
		lastAction[p] = nil
	end)
	-- speed perk while standing in a match
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in Players:GetPlayers() do
				local def = S.STYLES[p:GetAttribute("Style") or ""]
				local mult = if def and def.speedMult and PlayerStateService.getState(p) == State.Standing then def.speedMult else nil
				if p:GetAttribute("StyleSpeedOn") ~= (mult ~= nil) then
					p:SetAttribute("StyleSpeedOn", mult ~= nil)
				end
				pcall(PlayerStateService.setPlayerSpeedModifier, p, "Style", mult)
			end
		end
	end)
end

return StyleService
