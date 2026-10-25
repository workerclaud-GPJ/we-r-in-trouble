--!strict
--[[
	ItemBookController — B (gamepad: DPadUp, or the 📖 button) opens the hamster's item book:
	the item types in this round's kitchen and what each one can do. It never says which
	way out the round has — the players work that out from the items they find.
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local Attr = Contract.Attr
local player = Players.LocalPlayer

local ACTION = "WRIT_ItemBook"
local ORDER = { "ChargerCable", "Scissors", "Battery", "Bottlecap" }

local PAGES: { [string]: { icon: string, th: string, en: string } } = {
	ChargerCable = {
		icon = "🔌",
		th = "ยาวและเหนียว เสียบไฟได้ ถ้ายืนตรงจุดที่มีตะขอแล้วกด F ค้างจะปาไปเกี่ยวเป็นสะพานหรือเชือกปีน หรือจะผูกไว้โรยตัวลงที่ลึกก็ได้",
		en = "Power + Rope. Hold F near a hook to cast it into a bridge or climbing rope — or tie it to climb down somewhere deep.",
	},
	Scissors = {
		icon = "✂️",
		th = "คมและแข็งแรง ใช้ตัดหรืองัดของที่ล็อกหรือติดแน่นได้",
		en = "Cut + Pry. Opens things that are latched, screwed or stuck.",
	},
	Battery = {
		icon = "🔋",
		th = "เก็บพลังงานไฟฟ้า เอาไปใส่เครื่องที่ไฟหมด",
		en = "Power. Wakes up a machine that has run out of electricity.",
	},
	Bottlecap = {
		icon = "🥤",
		th = "เบาและลอยน้ำ ถ้าถือไว้แล้วเดินลงน้ำ จะนั่งล่องไปได้เร็วกว่าว่าย",
		en = "Floats. Hold it and walk into deep water to sail across faster.",
	},
}

local ItemBookController = {}

local gui: ScreenGui? = nil
local book: Frame? = nil
local list: Frame? = nil
local openBtn: TextButton? = nil

local function itemTypes(): { [string]: number }
	local out: { [string]: number } = {}
	local map = Workspace:FindFirstChild("Map")
	for _, inst in CollectionService:GetTagged(Contract.Tag.Item) do
		if map and inst:IsDescendantOf(map) then
			local t = inst:GetAttribute(Attr.ItemType)
			if typeof(t) == "string" then
				out[t] = (out[t] or 0) + 1
			end
		end
	end
	return out
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

local lastSig = ""
local function refreshPages(force: boolean?)
	local l = list
	if not l then
		return
	end
	local have0 = itemTypes()
	local parts: { string } = {}
	for _, t in ORDER do
		table.insert(parts, `{t}{have0[t] or 0}`)
	end
	local sig = table.concat(parts, ",")
	if sig == lastSig and not force then
		return
	end
	lastSig = sig
	for _, c in l:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local have = itemTypes()
	local n = 0
	for _, t in ORDER do
		local page = PAGES[t]
		if page and have[t] then
			n += 1
			local def = Config.Items[t]
			local row = make("Frame", { Name = t, LayoutOrder = n, Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.fromRGB(250, 240, 215), BackgroundTransparency = 0 }, l)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, row)
			make("TextLabel", { Size = UDim2.fromOffset(60, 74), BackgroundTransparency = 1, Text = page.icon, TextSize = 36, Font = Enum.Font.GothamBold }, row)
			make("TextLabel", {
				Position = UDim2.fromOffset(64, 4), Size = UDim2.new(1, -70, 0, 20), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.FredokaOne, TextSize = 19, TextColor3 = Color3.fromRGB(90, 55, 30),
				Text = `{if def then def.displayName else t}  ×{have[t]}`,
			}, row)
			make("TextLabel", {
				Position = UDim2.fromOffset(64, 24), Size = UDim2.new(1, -70, 0, 28), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(60, 45, 35), Text = page.th,
			}, row)
			make("TextLabel", {
				Position = UDim2.fromOffset(64, 52), Size = UDim2.new(1, -70, 0, 20), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(120, 95, 70), Text = page.en,
			}, row)
		end
	end
	if n == 0 then
		local row = make("Frame", { Name = "Empty", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, l)
		make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = Color3.fromRGB(90, 55, 30), Text = "ยังไม่มีไอเทมในครัว · No items here yet" }, row)
	end
end

function ItemBookController.toggle(force: boolean?)
	local b = book
	if not b then
		return
	end
	local open = if force ~= nil then force else not b.Visible
	if open then
		refreshPages(true)
	end
	b.Visible = open
end

local function build()
	local g = make("ScreenGui", { Name = "WRIT_ItemBook", ResetOnSpawn = false, DisplayOrder = 8, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
	local b = make("Frame", {
		Name = "Book", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 400),
		BackgroundColor3 = Color3.fromRGB(120, 70, 40), Visible = false,
	}, g)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, b)
	make("UIStroke", { Color = Color3.fromRGB(70, 40, 20), Thickness = 3 }, b)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -60, 0, 30), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.FredokaOne, TextSize = 24, TextColor3 = Color3.fromRGB(255, 225, 150), Text = "📖 Hamster's Item Book",
	}, b)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 18), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(255, 235, 200), Text = "ไอเทมในครัวรอบนี้ทำอะไรได้บ้าง — ทางออกต้องหาเอง!",
	}, b)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(230, 90, 80), Text = "✕", Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
	}, b)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, close)
	close.Activated:Connect(function()
		ItemBookController.toggle(false)
	end)
	local scroll = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 64), Size = UDim2.new(1, -24, 1, -76), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
	}, b)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	-- open button (touch + mouse), left of Drop / Dash
	local btn = make("TextButton", {
		Name = "BookButton", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -184, 1, -28), Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Color3.fromRGB(30, 30, 50), BackgroundTransparency = 0.1, Text = "📖", TextSize = 26, Font = Enum.Font.GothamBold,
		Visible = false,
	}, g)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, btn)
	make("UIStroke", { Color = Color3.fromRGB(255, 200, 80), Thickness = 2 }, btn)
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(20, 14), BackgroundTransparency = 1,
		Text = "B", TextSize = 13, Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 200, 80),
	}, btn)
	btn.Activated:Connect(function()
		ItemBookController.toggle()
	end)
	gui, book, list, openBtn = g, b, scroll, btn
end

function ItemBookController.start()
	build()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			ItemBookController.toggle()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B, Enum.KeyCode.DPadUp)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local inMatch = player:GetAttribute(Attr.State) ~= nil and player:GetAttribute(Attr.State) ~= Contract.State.Lobby and Workspace:FindFirstChild("Map") ~= nil
		if openBtn then
			openBtn.Visible = inMatch
		end
		if book and book.Visible then
			if not inMatch then
				book.Visible = false
			else
				refreshPages()
			end
		end
	end)
	local _ = gui
end

return ItemBookController
