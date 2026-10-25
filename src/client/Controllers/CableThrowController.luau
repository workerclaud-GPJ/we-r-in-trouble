--!strict
--[[
	CableThrowController — the charger-cable cast mini game (server: CableThrowService).

	While you hold a Rope item (charger cable) and stand on a cable ThrowSpot (glowing hook in
	front of you), a cast meter appears. HOLD F (gamepad Y, or the CAST button on screen) to
	charge: power swings 0 → 1 → 0 like a fishing rod; RELEASE inside the green zone to hook it.
	Too weak / too strong = the cable lands short / long and you have to go get it.
	Every client also animates every cast (CableRoute attributes CastAt/CastFrom/CastTo/CastOk).
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Attr = Contract.Attr
local player = Players.LocalPlayer

local ACTION = "WRIT_CastCable"
local SWING_TIME = 1.1 -- s from 0 to full power (then back down)
local FLIGHT_TIME = 0.6 -- matches CableThrowService
local SPOT_PADDING = 1

local CableThrowController = {}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local fill: Frame? = nil
local zone: Frame? = nil
local needle: Frame? = nil
local hint: TextLabel? = nil
local result: TextLabel? = nil

local route: Model? = nil
local charging = false
local chargeStart = 0
local resultUntil = 0

----------------------------------------------------------------------------
-- state helpers
----------------------------------------------------------------------------

local function roundState(): Instance?
	return ReplicatedStorage:FindFirstChild("RoundState")
end

local function holdingRope(): boolean
	local h = player:GetAttribute(Attr.Holding)
	if typeof(h) ~= "string" or h == "" then
		return false
	end
	local def = Config.Items[h]
	return def ~= nil and table.find(def.capabilities, "Rope") ~= nil
end

local function inside(point: Vector3, p: BasePart, pad: number): boolean
	local lp = p.CFrame:PointToObjectSpace(point)
	local h = p.Size / 2 + Vector3.new(pad, pad, pad)
	return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
end

local function findRoute(): Model?
	local rs = roundState()
	if not (rs and rs:GetAttribute(Attr.CableThrow) == true) then
		return nil
	end
	if player:GetAttribute(Attr.State) ~= Contract.State.Standing or not holdingRope() then
		return nil
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return nil
	end
	for _, inst in CollectionService:GetTagged(Contract.Tag.CableRoute) do
		if inst:IsA("Model") and inst:IsDescendantOf(Workspace) and inst:GetAttribute(Attr.Attached) ~= true then
			local spot = inst:FindFirstChild("ThrowSpot")
			if spot and spot:IsA("BasePart") and inside(hrp.Position, spot, SPOT_PADDING) then
				return inst
			end
		end
	end
	return nil
end

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function powerNow(): number
	local e = (os.clock() - chargeStart) % (SWING_TIME * 2)
	return if e <= SWING_TIME then e / SWING_TIME else (SWING_TIME * 2 - e) / SWING_TIME
end

----------------------------------------------------------------------------
-- UI
----------------------------------------------------------------------------

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

local function corner(parent: Instance, r: number)
	make("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function buildUi()
	local g = make("ScreenGui", { Name = "WRIT_CableCast", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))
	local p = make("Frame", {
		Name = "Panel",
		-- right side, above the Dash / Drop buttons: keeps the centre (your hamster) clear
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -300),
		Size = UDim2.fromOffset(300, 96),
		BackgroundColor3 = Color3.fromRGB(25, 28, 40),
		BackgroundTransparency = 0.15,
		Visible = false,
	}, g)
	corner(p, 14)
	make("UIStroke", { Color = Color3.fromRGB(255, 220, 120), Thickness = 2 }, p)
	hint = make("TextLabel", {
		Name = "Hint",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		Text = "",
	}, p)
	local bar = make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundColor3 = Color3.fromRGB(60, 64, 80),
	}, p)
	corner(bar, 8)
	zone = make("Frame", {
		Name = "Zone",
		BackgroundColor3 = Color3.fromRGB(90, 220, 110),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(0.2, 1),
	}, bar)
	fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.fromRGB(255, 200, 70),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
	}, bar)
	corner(fill :: Frame, 8)
	needle = make("Frame", {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 4, 1, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, bar)
	result = make("TextLabel", {
		Name = "Result",
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 230, 120),
		TextStrokeTransparency = 0.3,
		Text = "",
	}, p)
	-- touch / mouse: hold this button to charge
	local btn = make("TextButton", {
		Name = "Cast",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -12, 0.5, 0), -- left of the meter
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Color3.fromRGB(255, 200, 70),
		Text = "CAST",
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(40, 30, 10),
		AutoButtonColor = true,
	}, p)
	corner(btn, 38)
	btn.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			CableThrowController.beginCharge()
		end
	end)
	btn.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			CableThrowController.release()
		end
	end)
	gui, panel = g, p
end

----------------------------------------------------------------------------
-- cast input
----------------------------------------------------------------------------

function CableThrowController.beginCharge()
	if charging or not route then
		return
	end
	charging = true
	chargeStart = os.clock()
end

function CableThrowController.release()
	if not charging then
		return
	end
	charging = false
	local r = route
	if not r then
		return
	end
	local power = powerNow()
	local need = num(r, Attr.RequiredPower, 0.6)
	local window = num(r, Attr.PowerWindow, 0.1)
	local id = r:GetAttribute(Attr.RouteId)
	if typeof(id) ~= "string" then
		return
	end
	Remotes.get("CastCable"):FireServer(id, power)
	if result then
		result.Text = if math.abs(power - need) <= window then "Nice cast! 🎣" elseif power < need then "Too weak! The cable fell short" else "Too strong! It flew past the hook"
		result.TextColor3 = if math.abs(power - need) <= window then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 140, 120)
	end
	resultUntil = os.clock() + 2
end

local function update()
	local r = findRoute()
	if r ~= route then
		route = r
		charging = false
	end
	local p = panel
	if not p then
		return
	end
	local showResult = os.clock() < resultUntil
	p.Visible = route ~= nil or showResult
	if not showResult and result then
		result.Text = ""
	end
	local cur = route
	if not cur then
		return
	end
	local need = num(cur, Attr.RequiredPower, 0.6)
	local window = num(cur, Attr.PowerWindow, 0.1)
	local z = zone
	if z then
		z.Position = UDim2.fromScale(math.clamp(need - window, 0, 1), 0)
		z.Size = UDim2.fromScale(math.clamp(window * 2, 0, 1), 1)
	end
	local power = if charging then powerNow() else 0
	if fill then
		fill.Size = UDim2.fromScale(power, 1)
	end
	if needle then
		needle.Position = UDim2.fromScale(power, 0.5)
	end
	if hint then
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		hint.Text = if charging then "Release in the green zone!" elseif touch then "Hold CAST to charge the cable" else "Hold F to charge · release to cast"
	end
end

----------------------------------------------------------------------------
-- throw animation (every client, every cast)
----------------------------------------------------------------------------

local function animateCast(r: Model)
	local from, to, at = r:GetAttribute(Attr.CastFrom), r:GetAttribute(Attr.CastTo), r:GetAttribute(Attr.CastAt)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or typeof(at) ~= "number" then
		return
	end
	local plug = Instance.new("Part")
	plug.Name = "CastPlug"
	plug.Anchored = true
	plug.CanCollide = false
	plug.CanQuery = false
	plug.CanTouch = false
	plug.Size = Vector3.new(1.4, 1.2, 1.2)
	plug.Color = Color3.fromRGB(245, 245, 240)
	plug.Material = Enum.Material.SmoothPlastic
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = plug
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = plug
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(245, 245, 240))
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = plug
	plug.CFrame = CFrame.new(from)
	plug.Parent = Workspace
	local dist = (to - from).Magnitude
	local peak = math.max(from.Y, to.Y) + 5 + dist * 0.12
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - t0) / FLIGHT_TIME, 0, 1)
		local flat = from:Lerp(to, t)
		-- quadratic arc through `peak`
		local y0, y1 = from.Y, to.Y
		local hMid = peak - (y0 + y1) / 2
		local y = y0 + (y1 - y0) * t + 4 * hMid * t * (1 - t)
		plug.CFrame = CFrame.new(flat.X, y, flat.Z)
		if t >= 1 then
			conn:Disconnect()
			task.delay(0.3, function()
				plug:Destroy()
			end)
		end
	end)
end

local watched: { [Instance]: boolean } = {}
local function watch(inst: Instance)
	if watched[inst] or not inst:IsA("Model") then
		return
	end
	watched[inst] = true
	inst:GetAttributeChangedSignal(Attr.CastAt):Connect(function()
		if inst:IsDescendantOf(Workspace) then
			animateCast(inst :: Model)
		end
	end)
	inst.Destroying:Connect(function()
		watched[inst] = nil
	end)
end

function CableThrowController.start()
	buildUi()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState): Enum.ContextActionResult
		if not route then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			CableThrowController.beginCharge()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			CableThrowController.release()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	for _, inst in CollectionService:GetTagged(Contract.Tag.CableRoute) do
		watch(inst)
	end
	CollectionService:GetInstanceAddedSignal(Contract.Tag.CableRoute):Connect(watch)
	RunService.RenderStepped:Connect(update)
end

return CableThrowController
