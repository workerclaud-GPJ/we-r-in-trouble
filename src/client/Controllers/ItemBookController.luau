--!strict
--[[
	ItemBookController — B (gamepad: DPadUp, or the 📖 button) opens the hamster's book.
	  Page 1 · Items: only the items your team has picked up this round (RoundState SeenItems)
	    and what each can do. No counts, no unknown slots: players search the kitchen themselves.
	  Page 2 · Exits: every way out of the kitchen with the items it takes (✅ = found this
	    round). The secret exit stays "???" until you have escaped through it (ExitsFound).
	  Page 3 · Hints: vague riddles for each found item (what it might work with), plus a rumor
	    about the secret exit. Nudges only, never the answer.
	It never says which exit this round has: players work it out from what they find.
]]

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
		th = "ใช้ตัดหรืองัดของที่ล็อกหรือติดแน่นได้ แต่ตอนนี้ทื่ออยู่ ต้องเอาไปลับให้คมก่อน 🪨",
		en = "Cut + Pry. Blunt at first: sharpen it before prying anything.",
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

-- page 3: riddles, deliberately vague (a nudge, never the answer); shown only for items found
local RIDDLES: { [string]: { string } } = {
	ChargerCable = {
		"ที่ใดมีตะขอรอคอย ที่นั่นมีทางข้ามฟ้า",
		"จะลงไปในความมืดลึก ต้องมีอะไรให้เกาะไว้ก่อน",
		"แต่สายน้ำที่ไหลลงไม่หยุด จะไม่ยอมให้ใครลงไปง่ายๆ",
	},
	Scissors = {
		"สิ่งที่ถูกตรึงด้วยเกลียวเหล็ก แพ้ทางปลายแหลม",
		"ใบมีดที่ไม่คม ต้องไปทักทายหินสักก้อนก่อน",
		"ลมข้างนอกรออยู่หลังกระจก เหนือที่ที่น้ำไหลลง",
	},
	Battery = {
		"เสียงที่จะไปถึงคนไกล ต้องมีประกายไฟเริ่มต้น",
		"วงกลมที่หมุนวน ยิ่งวิ่งยิ่งสว่าง… และต้องไม่หยุด",
	},
	Bottlecap = {
		"ของเล็กที่ไม่ยอมจม รู้จักทางของน้ำดี",
		"เมื่อพื้นกลายเป็นแม่น้ำ อย่าว่าย… จงล่อง",
	},
}
local RUMOR = "ข่าวลือ: หนูตัวเก่ารู้ทางลับ ซ่อนอยู่หลังสิ่งที่มีกลิ่นเท้า…"

local SHORT = { ChargerCable = "สายชาร์จ", Scissors = "กรรไกร", Battery = "แบตเตอรี่", Bottlecap = "ฝาขวด" }

-- page 2: every way out of the kitchen and the items it takes (✅ = your team found one)
local EXITS = {
	{
		id = "Window", icon = "🌙", color = Color3.fromRGB(70, 90, 170),
		th = "หน้าต่างเหนือซิงก์", en = "The window",
		items = { "ChargerCable", "Scissors" },
		how = "ลับกรรไกร ขึ้นเคาน์เตอร์ แงะน็อตกลอนให้ครบ (1 ตัวต่อ 1 คน) แล้วช่วยกันดันหน้าต่าง",
	},
	{
		id = "Drain", icon = "💧", color = Color3.fromRGB(60, 140, 170),
		th = "ท่อระบายน้ำใต้ซิงก์", en = "The drain",
		items = { "Scissors", "ChargerCable" },
		how = "ลับกรรไกร แงะตะแกรง ช่วยกันยก ปิดก๊อกน้ำ แล้วผูกเชือกโรยตัวลงไป",
	},
	{
		id = "Carrier", icon = "📞", color = Color3.fromRGB(190, 110, 50),
		th = "ขอความช่วยเหลือทางวิทยุ", en = "Call for help",
		items = { "Battery" },
		how = "ใส่แบตให้เครื่อง แล้วให้คนหนึ่งวิ่งวงล้อไว้ ขณะที่คนอื่นตะโกนที่วิทยุ",
	},
	{
		id = "MouseHole", icon = "🐭", color = Color3.fromRGB(110, 80, 60), secret = true,
		th = "ทางลับ: รูหนู", en = "SECRET: the mouse hole",
		items = {},
		how = "ไม่ต้องใช้ไอเทม — ช่วยกันดันชั้นวางรองเท้าออก",
	},
}

local ItemBookController = {}

local gui: ScreenGui? = nil
local book: Frame? = nil
local list: ScrollingFrame? = nil
local subtitle: TextLabel? = nil
local tabs: { [string]: TextButton } = {}
local page = "Items"
local openBtn: TextButton? = nil

local function csvSet(csv: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if typeof(csv) == "string" then
		for _, t in string.split(csv, ",") do
			if t ~= "" then
				out[t] = true
			end
		end
	end
	return out
end

local function seenItems(): { [string]: boolean }
	local rs = ReplicatedStorage:FindFirstChild("RoundState")
	return csvSet(rs and rs:GetAttribute("SeenItems"))
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

local function clear(l: Instance)
	for _, c in l:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
end

-- page 1: only the items your team has picked up this round (no counts: go and look!)
local function buildItems(l: ScrollingFrame)
	local seen = seenItems()
	local n = 0
	for _, t in ORDER do
		local pg = PAGES[t]
		if pg and seen[t] then
			n += 1
			local def = Config.Items[t]
			local row = make("Frame", { Name = t, LayoutOrder = n, Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.fromRGB(250, 240, 215) }, l)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, row)
			make("TextLabel", { Size = UDim2.fromOffset(60, 74), BackgroundTransparency = 1, Text = pg.icon, TextSize = 36, Font = Enum.Font.GothamBold }, row)
			make("TextLabel", {
				Position = UDim2.fromOffset(64, 4), Size = UDim2.new(1, -70, 0, 20), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.FredokaOne, TextSize = 19, TextColor3 = Color3.fromRGB(90, 55, 30), Text = if def then def.displayName else t,
			}, row)
			make("TextLabel", {
				Position = UDim2.fromOffset(64, 24), Size = UDim2.new(1, -70, 0, 28), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(60, 45, 35), Text = pg.th,
			}, row)
			make("TextLabel", {
				Position = UDim2.fromOffset(64, 52), Size = UDim2.new(1, -70, 0, 20), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(120, 95, 70), Text = pg.en,
			}, row)
		end
	end
	local hint = make("Frame", { Name = "Hint", LayoutOrder = 999, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, l)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = Color3.fromRGB(255, 235, 200),
		Text = if n == 0 then "ยังไม่เจอไอเทมเลย — ออกไปค้นในครัว แล้วหยิบขึ้นมาดูว่าใช้ทำอะไรได้\nNo items found yet. Search the kitchen!"
			else "ยังมีของซ่อนอยู่อีกไหม? ลองค้นดูให้ทั่ว · Anything else hiding?",
	}, hint)
end

-- page 2: exit checklist
local function buildExits(l: ScrollingFrame)
	local seen = seenItems()
	local found = csvSet(player:GetAttribute("ExitsFound"))
	for i, e in EXITS do
		local locked = e.secret == true and not found[e.id]
		local row = make("Frame", { Name = e.id, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = Color3.fromRGB(250, 240, 215) }, l)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, row)
		-- the exit's "picture"
		local pic = make("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = if locked then Color3.fromRGB(70, 60, 55) else e.color }, row)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, pic)
		make("UIStroke", { Color = Color3.fromRGB(70, 40, 20), Thickness = 2 }, pic)
		make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = if locked then "❓" else e.icon, TextSize = 46, Font = Enum.Font.GothamBold }, pic)
		if found[e.id] then
			make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, -6, 0, 16), BackgroundColor3 = Color3.fromRGB(60, 170, 90),
				Text = "ESCAPED", TextSize = 11, Font = Enum.Font.FredokaOne, TextColor3 = Color3.new(1, 1, 1),
			}, pic)
		end
		make("TextLabel", {
			Position = UDim2.fromOffset(96, 6), Size = UDim2.new(1, -102, 0, 20), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = Color3.fromRGB(90, 55, 30),
			Text = if locked then "???  ทางลับ" else `{e.th} · {e.en}`,
		}, row)
		-- item chips
		local chips = make("Frame", { Position = UDim2.fromOffset(96, 30), Size = UDim2.new(1, -102, 0, 26), BackgroundTransparency = 1 }, row)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, chips)
		if locked then
			make("TextLabel", { Size = UDim2.fromOffset(240, 26), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(90, 75, 60), Text = "ว่ากันว่ามีทางออกลับซ่อนอยู่ในครัว…" }, chips)
		elseif #e.items == 0 then
			make("TextLabel", { Size = UDim2.fromOffset(200, 26), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(60, 45, 35), Text = "ไม่ต้องใช้ไอเทม · No items" }, chips)
		else
			for k, t in e.items do
				local have = seen[t] == true
				local pg = PAGES[t]
				local chip = make("TextLabel", {
					LayoutOrder = k, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26),
					BackgroundColor3 = if have then Color3.fromRGB(120, 210, 130) else Color3.fromRGB(215, 205, 190),
					Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(40, 35, 30),
					Text = ` {if pg then pg.icon else ""} {SHORT[t] or t} {if have then "✅" else "⬜"} `,
				}, chips)
				make("UICorner", { CornerRadius = UDim.new(0, 8) }, chip)
				make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, chip)
			end
		end
		make("TextLabel", {
			Position = UDim2.fromOffset(96, 60), Size = UDim2.new(1, -102, 0, 32), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(60, 45, 35),
			Text = if locked then "หาให้เจอเองนะ · Find it yourself" else e.how,
		}, row)
	end
end

-- page 3: hints (riddles) for the items your team has found
local function buildHints(l: ScrollingFrame)
	local seen = seenItems()
	local n = 0
	for _, t in ORDER do
		local lines = RIDDLES[t]
		local pg = PAGES[t]
		if lines and pg and seen[t] then
			n += 1
			local text = ""
			for _, line in lines do
				text ..= "• " .. line .. "\n"
			end
			local row = make("Frame", { Name = t, LayoutOrder = n, Size = UDim2.new(1, 0, 0, 30 + #lines * 22), BackgroundColor3 = Color3.fromRGB(245, 232, 205) }, l)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, row)
			make("TextLabel", { Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, Text = pg.icon, TextSize = 32, Font = Enum.Font.GothamBold }, row)
			make("TextLabel", {
				Position = UDim2.fromOffset(60, 6), Size = UDim2.new(1, -66, 0, 20), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.FredokaOne, TextSize = 17, TextColor3 = Color3.fromRGB(90, 55, 30), Text = SHORT[t] or t,
			}, row)
			make("TextLabel", {
				Position = UDim2.fromOffset(60, 28), Size = UDim2.new(1, -66, 1, -30), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Font = Enum.Font.GothamMedium, TextSize = 13, LineHeight = 1.15,
				TextColor3 = Color3.fromRGB(70, 50, 40), Text = text,
			}, row)
		end
	end
	local foot = make("Frame", { Name = "Foot", LayoutOrder = 999, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, l)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextWrapped = true, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(255, 225, 170),
		Text = (if n == 0 then "ยังไม่มีคำใบ้ — หาไอเทมให้เจอก่อนนะ\n" else "") .. "🐭 " .. RUMOR,
	}, foot)
end

local lastSig = ""
local function refreshPages(force: boolean?)
	local l = list
	if not l then
		return
	end
	local rs = ReplicatedStorage:FindFirstChild("RoundState")
	local sig = `{page}|{tostring(rs and rs:GetAttribute("SeenItems"))}|{tostring(player:GetAttribute("ExitsFound"))}`
	if sig == lastSig and not force then
		return
	end
	lastSig = sig
	clear(l)
	if page == "Exits" then
		buildExits(l)
	elseif page == "Hints" then
		buildHints(l)
	else
		buildItems(l)
	end
	if subtitle then
		subtitle.Text = if page == "Exits" then "ทางออกทั้งหมด และไอเทมที่ต้องใช้ — ✅ = ทีมเจอแล้ว"
			elseif page == "Hints" then "คำใบ้ลึกลับของไอเทมที่เจอแล้ว… ลองตีความดู"
			else "ไอเทมที่ทีมเจอแล้ว ใช้ทำอะไรได้บ้าง"
	end
	for id, b in tabs do
		b.BackgroundColor3 = if id == page then Color3.fromRGB(255, 210, 110) else Color3.fromRGB(150, 95, 60)
	end
end

local function setPage(p: string)
	page = p
	refreshPages(true)
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
	local g = make("ScreenGui", { Name = "WRIT_ItemBook", ResetOnSpawn = false, DisplayOrder = 30, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
	local b = make("Frame", {
		Name = "Book", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(480, 460),
		BackgroundColor3 = Color3.fromRGB(120, 70, 40), Visible = false,
	}, g)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, b)
	make("UIStroke", { Color = Color3.fromRGB(70, 40, 20), Thickness = 3 }, b)
	make("UISizeConstraint", { MaxSize = Vector2.new(480, 460) }, b)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -60, 0, 30), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.FredokaOne, TextSize = 24, TextColor3 = Color3.fromRGB(255, 225, 150), Text = "📖 Hamster's Book",
	}, b)
	-- tabs
	for i, def in { { id = "Items", text = "1 · ไอเทม" }, { id = "Exits", text = "2 · ทางออก" }, { id = "Hints", text = "3 · คำใบ้" } } do
		local t = make("TextButton", {
			Position = UDim2.fromOffset(16 + (i - 1) * 132, 44), Size = UDim2.fromOffset(124, 30), BackgroundColor3 = Color3.fromRGB(150, 95, 60),
			Font = Enum.Font.FredokaOne, TextSize = 16, TextColor3 = Color3.fromRGB(50, 30, 15), Text = def.text,
		}, b)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, t)
		t.Activated:Connect(function()
			setPage(def.id)
		end)
		tabs[def.id] = t
	end
	subtitle = make("TextLabel", {
		Position = UDim2.fromOffset(16, 78), Size = UDim2.new(1, -32, 0, 18), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(255, 235, 200), Text = "",
	}, b)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(230, 90, 80), Text = "X", Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
	}, b)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, close)
	close.Activated:Connect(function()
		ItemBookController.toggle(false)
	end)
	local scroll = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 102), Size = UDim2.new(1, -24, 1, -114), BackgroundTransparency = 1, BorderSizePixel = 0,
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
