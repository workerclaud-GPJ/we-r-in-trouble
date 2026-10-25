--!strict
--[[
	StyleShopController — lobby style shop (server: StyleService) + Ninja double jump.
	  🛒 Shop button (lobby only, under the Style button) shows your coins; the panel lists the
	  styles (Config.Styles) with Buy / Equip / Equipped. Coins come from playing matches.
	  Double jump: styles with doubleJump get one extra jump in the air (client-owned character).
	  "+50 💰" toast when a match reward arrives (attribute LastReward).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local S = Config.Styles
local Attr = Contract.Attr
local player = Players.LocalPlayer

local StyleShopController = {}

local panel: Frame? = nil
local shopBtn: TextButton? = nil
local listFrame: ScrollingFrame? = nil
local coinsLabel: TextLabel? = nil
local toast: TextLabel? = nil
local journalBtn: TextButton? = nil
local journalPanel: Frame? = nil

local EXITS = {
	{ id = "Carrier", name = "🚗 Rescue carrier" },
	{ id = "Window", name = "🌙 The window" },
	{ id = "Drain", name = "💧 The drain" },
	{ id = "MouseHole", name = "🐭 SECRET: the mouse hole", secret = true },
}

local function foundSet(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local csv = player:GetAttribute("ExitsFound")
	if typeof(csv) == "string" then
		for _, id in string.split(csv, ",") do
			out[id] = true
		end
	end
	return out
end

local function refreshJournal()
	local f = foundSet()
	local n = 0
	for _, e in EXITS do
		if f[e.id] then
			n += 1
		end
	end
	if journalBtn then
		journalBtn.Text = `📔 Escapes {n}/{#EXITS}`
	end
	local jp = journalPanel
	if not jp then
		return
	end
	for _, c in jp:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, -12, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 225, 150)
	title.Text = `Escape journal  {n}/{#EXITS}`
	title.Parent = jp
	for i, e in EXITS do
		local l = Instance.new("TextLabel")
		l.LayoutOrder = i
		l.Size = UDim2.new(1, -12, 0, 22)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextSize = 16
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = if f[e.id] then Color3.fromRGB(140, 240, 150) else Color3.fromRGB(170, 170, 190)
		l.Text = if f[e.id] then `✅ {e.name}` elseif (e :: any).secret then "❔ ??? (secret — very rare)" else "❔ ??? (not found yet)"
		l.Parent = jp
	end
	local hint = Instance.new("TextLabel")
	hint.LayoutOrder = 10
	hint.Size = UDim2.new(1, -12, 0, 30)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Color3.fromRGB(200, 200, 220)
	hint.Text = "ทุกรอบทางออกไม่เหมือนกัน — หาให้ครบ!"
	hint.Parent = jp
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(className)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function coins(): number
	local c = player:GetAttribute("Coins")
	return if typeof(c) == "number" then c else 0
end

local function ownedSet(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local csv = player:GetAttribute("OwnedStyles")
	if typeof(csv) == "string" then
		for _, id in string.split(csv, ",") do
			out[id] = true
		end
	end
	return out
end

local function refresh()
	local l = listFrame
	if not l then
		return
	end
	for _, c in l:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local owned = ownedSet()
	local equipped = player:GetAttribute("Style")
	for i, id in S.ORDER do
		local def = S.STYLES[id]
		local row = make("Frame", { Name = id, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = Color3.fromRGB(250, 240, 215) }, l)
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, row)
		make("TextLabel", { Size = UDim2.fromOffset(70, 92), BackgroundTransparency = 1, Text = def.icon, TextSize = 42, Font = Enum.Font.GothamBold }, row)
		make("TextLabel", {
			Position = UDim2.fromOffset(72, 6), Size = UDim2.new(1, -190, 0, 24), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.FredokaOne, TextSize = 21, TextColor3 = Color3.fromRGB(90, 55, 30), Text = def.displayName,
		}, row)
		make("TextLabel", {
			Position = UDim2.fromOffset(72, 30), Size = UDim2.new(1, -190, 0, 36), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(60, 45, 35), Text = def.th,
		}, row)
		make("TextLabel", {
			Position = UDim2.fromOffset(72, 68), Size = UDim2.new(1, -190, 0, 18), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(120, 95, 70), Text = def.en,
		}, row)
		local text: string
		local color: Color3
		local action: string?
		if equipped == id then
			text, color, action = "Equipped ✓", Color3.fromRGB(110, 190, 110), "unequip"
		elseif owned[id] then
			text, color, action = "Equip", Color3.fromRGB(80, 150, 235), "equip"
		elseif coins() >= def.price then
			text, color, action = `Buy {def.price} 💰`, Color3.fromRGB(240, 180, 60), "buy"
		else
			text, color, action = `{def.price} 💰`, Color3.fromRGB(150, 150, 150), nil
		end
		local b = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(108, 40),
			BackgroundColor3 = color, Text = text, Font = Enum.Font.FredokaOne, TextSize = 17, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = action ~= nil,
		}, row)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
		b.Activated:Connect(function()
			if action == "buy" then
				Remotes.get("StyleShop"):FireServer("buy", id)
			elseif action == "equip" then
				Remotes.get("StyleShop"):FireServer("equip", id)
			elseif action == "unequip" then
				Remotes.get("StyleShop"):FireServer("equip", "")
			end
		end)
	end
	if coinsLabel then
		coinsLabel.Text = `💰 {coins()} coins  ·  escape = +{S.ESCAPE_REWARD}, play = +{S.PLAY_REWARD}`
	end
end

local function build()
	local g = make("ScreenGui", { Name = "WRIT_StyleShop", ResetOnSpawn = false, DisplayOrder = 25, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
	local btn = make("TextButton", {
		Name = "ShopButton", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 10, 0.5, 80), Size = UDim2.fromOffset(150, 46),
		BackgroundColor3 = Color3.fromRGB(240, 180, 60), Text = "🛒 Shop", Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = Color3.fromRGB(60, 35, 10), Visible = false,
	}, g)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, btn)
	make("UIStroke", { Color = Color3.fromRGB(120, 70, 20), Thickness = 2 }, btn)
	local p = make("Frame", {
		Name = "Shop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(480, 330),
		BackgroundColor3 = Color3.fromRGB(120, 70, 40), Visible = false,
	}, g)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, p)
	make("UIStroke", { Color = Color3.fromRGB(70, 40, 20), Thickness = 3 }, p)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -60, 0, 30), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.FredokaOne, TextSize = 24, TextColor3 = Color3.fromRGB(255, 225, 150), Text = "🛒 Hamster Style Shop",
	}, p)
	coinsLabel = make("TextLabel", {
		Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 18), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255, 235, 200), Text = "",
	}, p)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(230, 90, 80), Text = "X", Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
	}, p)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, close)
	local scroll = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 1, -78), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
	}, p)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	toast = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(520, 40), BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, TextSize = 30, TextColor3 = Color3.fromRGB(255, 220, 90), TextStrokeTransparency = 0.2, Text = "", Visible = false,
	}, g)
	-- escape journal (which ways out you have found; names hidden until found)
	local jBtn = make("TextButton", {
		Name = "JournalButton", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 10, 0.5, 134), Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = Color3.fromRGB(70, 110, 170), Text = "📔 Escapes 0/3", Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Visible = false,
	}, g)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, jBtn)
	local jPanel = make("Frame", {
		Name = "Journal", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 168, 0.5, 80), Size = UDim2.fromOffset(270, 185),
		BackgroundColor3 = Color3.fromRGB(40, 50, 80), BackgroundTransparency = 0.05, Visible = false,
	}, g)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, jPanel)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, jPanel)
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 8) }, jPanel)
	jBtn.Activated:Connect(function()
		jPanel.Visible = not jPanel.Visible
	end)
	journalBtn, journalPanel = jBtn, jPanel
	btn.Activated:Connect(function()
		p.Visible = not p.Visible
		if p.Visible then
			refresh()
		end
	end)
	close.Activated:Connect(function()
		p.Visible = false
	end)
	panel, shopBtn, listFrame = p, btn, scroll
end

----------------------------------------------------------------------------
-- double jump
----------------------------------------------------------------------------

local airJumpUsed = false
local function hookCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if not (hum and hum:IsA("Humanoid")) then
		return
	end
	airJumpUsed = false
	hum.StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			airJumpUsed = false
		end
	end)
end

local function onJumpRequest()
	if player:GetAttribute("DoubleJump") ~= true or player:GetAttribute(Attr.State) ~= Contract.State.Standing then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp and hrp:IsA("BasePart")) or airJumpUsed or hum.JumpHeight <= 0 then
		return
	end
	local st = hum:GetState()
	if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping then
		return
	end
	airJumpUsed = true
	local v = math.sqrt(2 * Workspace.Gravity * hum.JumpHeight)
	hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, v, hrp.AssemblyLinearVelocity.Z)
	-- small puff
	local puff = Instance.new("Part")
	puff.Anchored, puff.CanCollide, puff.CanQuery, puff.CanTouch = true, false, false, false
	puff.Shape = Enum.PartType.Ball
	puff.Size = Vector3.new(2.5, 2.5, 2.5)
	puff.Material = Enum.Material.Neon
	puff.Color = Color3.fromRGB(230, 230, 255)
	puff.Transparency = 0.4
	puff.CFrame = hrp.CFrame * CFrame.new(0, -2.5, 0)
	puff.Parent = Workspace
	task.delay(0.25, function()
		puff:Destroy()
	end)
end

function StyleShopController.start()
	if not S.ENABLED then
		return
	end
	build()
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)
	UserInputService.JumpRequest:Connect(onJumpRequest)
	for _, a in { "Coins", "OwnedStyles", "Style" } do
		player:GetAttributeChangedSignal(a):Connect(function()
			if panel and panel.Visible then
				refresh()
			end
		end)
	end
	refreshJournal()
	player:GetAttributeChangedSignal("ExitsFound"):Connect(refreshJournal)
	player:GetAttributeChangedSignal("NewExit"):Connect(function()
		local id = player:GetAttribute("NewExit")
		local t = toast
		if typeof(id) == "string" and t then
			local name = id
			for _, e in EXITS do
				if e.id == id then
					name = e.name
				end
			end
			task.delay(3.2, function()
				t.Text = `🎉 New escape found: {name}!`
				t.Visible = true
				task.delay(4, function()
					t.Visible = false
				end)
			end)
		end
	end)
	player:GetAttributeChangedSignal("LastReward"):Connect(function()
		local r = player:GetAttribute("LastReward")
		local t = toast
		if typeof(r) == "number" and t then
			t.Text = `+{r} 💰`
			t.Visible = true
			task.delay(3, function()
				t.Visible = false
			end)
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.3 then
			return
		end
		acc = 0
		local inLobby = player:GetAttribute(Attr.State) == Contract.State.Lobby
		local b = shopBtn
		if journalBtn then
			journalBtn.Visible = inLobby
		end
		if journalPanel and not inLobby then
			journalPanel.Visible = false
		end
		if b then
			b.Visible = inLobby
			b.Text = `🛒 Shop · {coins()} 💰`
		end
		if panel and panel.Visible and not inLobby then
			panel.Visible = false
		end
	end)
end

return StyleShopController
