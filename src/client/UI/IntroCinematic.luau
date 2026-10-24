--!strict
--[[
	IntroCinematic — ~5 s match intro (client only, GDD 8.6.1 polish).

	When Phase goes Lobby/Intermission -> Match and the local player is a participant,
	the camera sweeps from the window over the kitchen down to the cage, with letterbox
	bars and the title (Strings.Text.IntroTitleTh / IntroTitle). Movement is disabled
	meanwhile and control returns at the end. Skip: tap / click / Space / gamepad A.
	HUD hide (H): the HUD stays hidden during the shot (HudController); the skip hint
	only shows when the player has the HUD visible, so recordings stay clean.

	Camera markers (map, all optional): Parts `IntroCamStart` / `IntroCamEnd` (CFrame used
	as-is); else window = ExitVehicleSpot / ExitZone tag, cage = average of PlayerSpawn
	parts without EnabledBy. Missing markers after INTRO_WAIT_FOR_MAP s -> intro skipped.
	Joining mid-match (first phase seen is Match) never plays it.
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Contract = require(Shared:WaitForChild("Contract"))

local StateAdapter = require(script.Parent.StateAdapter)
local Strings = require(script.Parent.Strings)
local Style = require(script.Parent.Style)
local UIUtil = require(script.Parent.UIUtil)

type Snapshot = StateAdapter.Snapshot

export type IntroCinematic = {
	update: (snap: Snapshot) -> (),
	isPlaying: () -> boolean,
	destroy: () -> (),
}

type Path = { p0: Vector3, p1: Vector3, p2: Vector3, look0: Vector3, look1: Vector3, endCf: CFrame? }

local P = Config.Presentation
local T = Strings.Text
local RENDER_NAME = "WRIT_IntroCamera"
local SKIP_ACTION = "WRIT_IntroSkip"
local localPlayer = Players.LocalPlayer

local IntroCinematic = {}

local function setControls(enabled: boolean)
	pcall(function()
		local ps = localPlayer:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if pm then
			local controls = ((require :: any)(pm) :: any):GetControls()
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
end

local function inMap(map: Instance, tag: string): { BasePart }
	local out: { BasePart } = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
			table.insert(out, inst)
		end
	end
	return out
end

local function namedPart(map: Instance, name: string): BasePart?
	local p = map:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function findPath(): Path?
	local map = StateAdapter.getMap()
	if not map then
		return nil
	end
	local startPart = namedPart(map, "IntroCamStart")
	local endPart = namedPart(map, "IntroCamEnd")

	local window: Vector3? = startPart and startPart.Position
	if not window then
		local w = inMap(map, Contract.Tag.ExitVehicleSpot)[1] or inMap(map, Contract.Tag.ExitZone)[1]
		window = w and w.Position
	end
	local cage: Vector3? = endPart and endPart.Position
	if not cage then
		local sum, n = Vector3.zero, 0
		for _, sp in inMap(map, Contract.Tag.PlayerSpawn) do
			if sp:GetAttribute(Contract.Attr.EnabledBy) == nil then
				sum += sp.Position
				n += 1
			end
		end
		cage = if n > 0 then sum / n else nil
	end
	if not (window and cage) then
		return nil
	end
	local w, c = window :: Vector3, cage :: Vector3
	local flat = Vector3.new(c.X - w.X, 0, c.Z - w.Z)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	local mid = (w + c) / 2
	local midFloor = Vector3.new(mid.X, c.Y, mid.Z)
	local p0 = if startPart then startPart.Position else w + dir * 6 + Vector3.new(0, P.INTRO_WINDOW_HEIGHT, 0)
	local p2 = if endPart then endPart.Position else c - dir * P.INTRO_CAGE_BACK + Vector3.new(0, P.INTRO_CAGE_HEIGHT, 0)
	return {
		p0 = p0,
		p1 = Vector3.new(mid.X, math.max(p0.Y, p2.Y) + P.INTRO_MID_HEIGHT * 0.5, mid.Z),
		p2 = p2,
		look0 = if startPart then p0 + startPart.CFrame.LookVector * 20 else midFloor,
		look1 = if endPart then p2 + endPart.CFrame.LookVector * 20 else c,
		endCf = if endPart then endPart.CFrame else nil,
	}
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	local u = 1 - t
	return a * (u * u) + b * (2 * u * t) + c * (t * t)
end

function IntroCinematic.new(isHudVisible: () -> boolean): IntroCinematic
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("WRIT_Intro")
	if old then
		old:Destroy()
	end
	local gui: ScreenGui = UIUtil.make("ScreenGui", {
		Name = "WRIT_Intro",
		DisplayOrder = 30,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		Enabled = false,
		Parent = playerGui,
	})
	local function bar(top: boolean): Frame
		return UIUtil.make("Frame", {
			Name = if top then "BarTop" else "BarBottom",
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	local barTop, barBottom = bar(true), bar(false)
	local function title(text: string, y: number, h: number, maxSize: number): TextLabel
		return UIUtil.label(text, maxSize, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(0.9, h),
			AutomaticSize = Enum.AutomaticSize.None,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Style.Color.Accent,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Font = Style.Font.Display,
			Parent = gui,
		})
	end
	local titleTh = title(T.IntroTitleTh, 0.7, 0.08, Style.Text.Huge)
	local titleEn = title(T.IntroTitle, 0.78, 0.055, Style.Text.Title)
	titleEn.TextColor3 = Style.Color.Text
	for _, l in { titleTh, titleEn } do
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = l.TextSize
		c.MinTextSize = 14
		c.Parent = l
	end
	local skipHint = UIUtil.label(T.IntroSkip, Style.Text.Small, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 1 - P.INTRO_LETTERBOX / 2, 0),
		Size = UDim2.fromScale(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Style.Color.TextDim,
		Parent = gui,
	})

	local playing = false
	local playedMatch: number? = nil
	local sawPreMatch = false
	local pendingSince: number? = nil
	local startedAt = 0
	local path: Path? = nil
	local inputConn: RBXScriptConnection? = nil

	local function tween(inst: Instance, props: { [string]: any })
		TweenService:Create(inst, TweenInfo.new(P.INTRO_FADE, Enum.EasingStyle.Quad), props):Play()
	end

	local function stop()
		if not playing then
			return
		end
		playing = false
		pcall(function()
			RunService:UnbindFromRenderStep(RENDER_NAME)
		end)
		ContextActionService:UnbindAction(SKIP_ACTION)
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			local char = localPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				camera.CameraSubject = hum
			end
		end
		setControls(true)
		tween(barTop, { Size = UDim2.fromScale(1, 0) })
		tween(barBottom, { Size = UDim2.fromScale(1, 0) })
		for _, l in { titleTh, titleEn } do
			tween(l, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
		skipHint.Visible = false
		task.delay(P.INTRO_FADE, function()
			if not playing then
				gui.Enabled = false
			end
		end)
	end

	local function play(p: Path)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		playing = true
		path = p
		startedAt = os.clock()
		gui.Enabled = true
		skipHint.Visible = isHudVisible()
		tween(barTop, { Size = UDim2.fromScale(1, P.INTRO_LETTERBOX) })
		tween(barBottom, { Size = UDim2.fromScale(1, P.INTRO_LETTERBOX) })
		task.delay(0.6, function()
			if playing then
				for _, l in { titleTh, titleEn } do
					tween(l, { TextTransparency = 0, TextStrokeTransparency = 0.35 })
				end
			end
		end)
		setControls(false)
		camera.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
			local pp = path
			local cam = workspace.CurrentCamera
			if not (playing and pp and cam) then
				return
			end
			local t = math.clamp((os.clock() - startedAt) / P.INTRO_TIME, 0, 1)
			local s = TweenService:GetValue(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			cam.CameraType = Enum.CameraType.Scriptable
			if t >= 1 and pp.endCf then
				cam.CFrame = pp.endCf :: CFrame
			else
				cam.CFrame = CFrame.lookAt(bezier(pp.p0, pp.p1, pp.p2, s), pp.look0:Lerp(pp.look1, s))
			end
			if t >= 1 then
				stop()
			end
		end)
		-- Skip: Space / ButtonA through ContextActionService (sinks the jump), tap/click via input.
		ContextActionService:BindActionAtPriority(SKIP_ACTION, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				stop()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		inputConn = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return -- e.g. the HUD toggle button
			end
			local ty = input.UserInputType
			if ty == Enum.UserInputType.Touch or ty == Enum.UserInputType.MouseButton1 then
				stop()
			end
		end)
	end

	local function update(snap: Snapshot)
		if playing then
			skipHint.Visible = isHudVisible()
			if snap.phase ~= StateAdapter.VALUES.PhaseMatch then
				stop()
			end
			return
		end
		if snap.phase ~= StateAdapter.VALUES.PhaseMatch then
			pendingSince = nil
			sawPreMatch = snap.phase == StateAdapter.VALUES.PhaseLobby
				or snap.phase == StateAdapter.VALUES.PhaseIntermission
			return
		end
		if not sawPreMatch or snap.matchId == playedMatch then
			return
		end
		if snap.state == StateAdapter.VALUES.StateLobby then
			-- participant state may lag the phase by a frame; spectators never play it
			pendingSince = pendingSince or os.clock()
			if os.clock() - (pendingSince :: number) > P.INTRO_WAIT_FOR_MAP then
				playedMatch = snap.matchId
			end
			return
		end
		pendingSince = pendingSince or os.clock()
		local p = findPath()
		if p then
			playedMatch = snap.matchId
			play(p)
		elseif os.clock() - (pendingSince :: number) > P.INTRO_WAIT_FOR_MAP then
			playedMatch = snap.matchId -- markers never showed up: skip
		end
	end

	return {
		update = update,
		isPlaying = function(): boolean
			return playing
		end,
		destroy = function()
			stop()
			gui:Destroy()
		end,
	}
end

return IntroCinematic
