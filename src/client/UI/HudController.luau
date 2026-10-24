--!strict
--[[
	HudController — builds the HUD and refreshes it from StateAdapter.snapshot()
	every Style.Tuning.UiTick (0.1 s). Also derives the banners from state changes
	(so the server does not need a banner remote; HudBanner remote is optional extra).

	Screen layout (base px, scaled by HudRoot's UIScale; anchors use Scale):
	  top-left      ObjectiveList (#2)
	  top-center    StageTimer (#1) -> ExtractionPanel (#7) / LobbyStatus
	  top-right     HUD toggle button (touch devices)
	  upper-middle  Banner
	  center        StatusOverlay (#6) / ResultScreen (#8)
	  bottom-center HealthBar (#5)      (thumbstick = bottom-left, jump = bottom-right)
	  world         MarkerController (#3, #4)
]]

local RunService = game:GetService("RunService")

local CameraController = require(script.Parent.CameraController)
local HudRoot = require(script.Parent.HudRoot)
local HudToggle = require(script.Parent.HudToggle)
local IntroCinematic = require(script.Parent.IntroCinematic)
local MarkerController = require(script.Parent.MarkerController)
local StateAdapter = require(script.Parent.StateAdapter)
local Strings = require(script.Parent.Strings)
local Style = require(script.Parent.Style)
local UIUtil = require(script.Parent.UIUtil)

local Widgets = script.Parent.Widgets
local Banner = require(Widgets.Banner)
local CosmeticsPanel = require(Widgets.CosmeticsPanel)
local ExtractionPanel = require(Widgets.ExtractionPanel)
local HealthBar = require(Widgets.HealthBar)
local LobbyStatus = require(Widgets.LobbyStatus)
local ObjectiveList = require(Widgets.ObjectiveList)
local ResultScreen = require(Widgets.ResultScreen)
local StageTimer = require(Widgets.StageTimer)
local StatusOverlay = require(Widgets.StatusOverlay)

type Snapshot = StateAdapter.Snapshot

export type HudController = {
	destroy: () -> (),
}

local T = Strings.Text
local STAGE_ORDER: { [string]: number } = { Calm = 1, Warning = 2, Active = 3, Critical = 4 }

local HudController = {}

type BannerMemory = {
	phase: string,
	stage: string,
	stepIndex: number,
	exitOpen: boolean,
	carrierArrived: boolean,
	lastCall: boolean,
	lastChance: boolean,
	inMatch: boolean,
}

function HudController.new(): HudController
	local root = HudRoot.new()
	local toggle = HudToggle.new(root.top)
	local markers = MarkerController.new()
	local camera = CameraController.new()
	local intro = IntroCinematic.new(toggle.isVisible)

	local topColumn: Frame = UIUtil.make("Frame", {
		Name = "TopCenter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Style.Size.Margin),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = root.hud,
	}, { UIUtil.list(Style.Size.Gap, false, Enum.HorizontalAlignment.Center) :: Instance })

	local stageTimer = StageTimer.new(topColumn)
	stageTimer.root.LayoutOrder = 1
	local extraction = ExtractionPanel.new(topColumn)
	extraction.root.LayoutOrder = 2
	local lobby = LobbyStatus.new(topColumn)
	lobby.root.LayoutOrder = 3

	local objectives = ObjectiveList.new(root.hud)
	local health = HealthBar.new(root.hud)
	local status = StatusOverlay.new(root.back, root.hud)
	local result = ResultScreen.new(root.back, root.hud)
	local banner = Banner.new(root.hud)
	local cosmetics = CosmeticsPanel.new(root.hud)

	-- Visibility = player toggle AND not during the win camera shot.
	local cinematicHidden = false
	local function applyVisibility()
		local v = toggle.isVisible() and not cinematicHidden
		root.setHudVisible(v)
		markers.setVisible(v)
	end
	local toggleConn = toggle.changed:Connect(function()
		applyVisibility()
	end)

	-- Optional server banner remote. Held back while the match intro plays (HUD hidden).
	local heldBanners: { StateAdapter.BannerPayload } = {}
	local function showRemoteBanner(payload: StateAdapter.BannerPayload)
		local color: Color3? = nil
		if payload.color then
			color = (Style.Color :: any)[payload.color]
		end
		-- Prefer our own (themeable) text for known keys; server text is the fallback.
		local text = payload.text
		local own = (T :: any)[payload.key]
		if typeof(own) == "string" then
			text = own
			local ownSub = (T :: any)[payload.key .. "Sub"]
			payload.sub = if typeof(ownSub) == "string" then ownSub else payload.sub
		end
		banner.push({
			key = if payload.key ~= "" then payload.key else nil,
			text = text,
			sub = payload.sub,
			color = color,
			duration = payload.duration,
		})
	end
	local stopRemote = StateAdapter.onBanner(function(payload: StateAdapter.BannerPayload)
		if intro.isPlaying() then
			table.insert(heldBanners, payload)
		else
			showRemoteBanner(payload)
		end
	end)

	----------------------------------------------------------------------
	-- Banners derived from state transitions
	----------------------------------------------------------------------
	local memory: BannerMemory? = nil
	local disasterBannerShown = false
	local warningSeenAt: number? = nil -- wait briefly for DisasterName to replicate

	local function stepSub(snap: Snapshot): string
		local header = UIUtil.format(T.StepHeader, { i = snap.stepIndex, n = math.max(snap.stepCount, 1) })
		return if snap.stepName then header .. ": " .. Strings.objective(snap.stepName) else header
	end

	-- Step hint: requested on match start / step change, pushed once StepName has
	-- replicated (or after 2 s with the generic hint).
	local hintPendingSince: number? = nil
	local function pushStepHint(_snap: Snapshot)
		hintPendingSince = os.clock()
	end
	local function flushStepHint(snap: Snapshot)
		local since = hintPendingSince
		if not since or (snap.stepName == nil and os.clock() - since < 2) then
			return
		end
		hintPendingSince = nil
		local text, sub = Strings.stepHint(snap.stepName)
		banner.push({
			key = "StepHint" .. snap.stepIndex,
			text = text,
			sub = sub,
			color = Style.Color.Accent,
			duration = Style.Tuning.HintTime,
		})
	end

	local function deriveBanners(snap: Snapshot)
		local inMatch = snap.phase == "Match" and snap.state ~= StateAdapter.VALUES.StateLobby
		local lastChance = inMatch and not snap.exitOpen and ObjectiveList.lastChanceActive(snap)
		local now: BannerMemory = {
			phase = snap.phase,
			stage = snap.stage,
			stepIndex = snap.stepIndex,
			exitOpen = snap.exitOpen,
			carrierArrived = snap.carrierArrived,
			lastCall = snap.lastCall,
			lastChance = lastChance,
			inMatch = inMatch,
		}
		local prev = memory
		memory = now
		if not inMatch then
			if prev and prev.inMatch then
				banner.clear()
			end
			disasterBannerShown = false
			warningSeenAt = nil
			hintPendingSince = nil
			return
		end
		if prev == nil then
			-- first tick (e.g. script reload mid-match): no retroactive banners,
			-- but the disaster name still has to be seen once (GDD 4.1 rule 4),
			-- which the disasterBannerShown check below takes care of.
			prev = now
		end
		local p = prev :: BannerMemory

		if not p.inMatch then
			banner.push({
				key = "Briefing",
				text = if snap.missionName then Strings.objective(snap.missionName) else T.MissionFallback,
				sub = stepSub(snap),
				color = Style.Color.Accent,
				duration = StateAdapter.Tuning.briefingTime,
			})
			pushStepHint(snap) -- queued: shows right after the briefing, inside the first 10 s
		end

		local pastCalm = (STAGE_ORDER[snap.stage] or 1) >= STAGE_ORDER.Warning
		if pastCalm and warningSeenAt == nil then
			warningSeenAt = os.clock()
		end
		local nameReady = snap.disasterName ~= nil or (warningSeenAt ~= nil and os.clock() - warningSeenAt > 1)
		if not disasterBannerShown and pastCalm and nameReady then
			disasterBannerShown = true
			banner.push({
				key = "Disaster",
				text = snap.disasterName or T.DisasterFallback,
				sub = snap.disasterHint,
				color = Style.Color.Warn,
				duration = math.max(Style.Tuning.BannerTime, StateAdapter.Tuning.warningBannerMin),
			})
		end

		if snap.exitOpen and not p.exitOpen then
			banner.pushUrgent({
				key = "BannerWindowOpen",
				text = T.BannerWindowOpen,
				sub = T.BannerWindowOpenSub,
				color = Style.Color.Exit,
				duration = Style.Tuning.BriefingTime,
			})
		elseif snap.stepIndex > p.stepIndex and p.inMatch and not snap.exitOpen then
			banner.push({ key = "BannerStepComplete", text = T.BannerStepComplete, sub = stepSub(snap), color = Style.Color.Good })
			pushStepHint(snap)
		end

		if snap.stage == "Critical" and p.stage ~= "Critical" and not snap.exitOpen and p.inMatch then
			banner.push({ key = "BannerCritical", text = T.BannerCritical, sub = T.BannerCriticalSub, color = Style.Color.Bad })
		end
		if snap.carrierArrived and not p.carrierArrived then
			banner.pushUrgent({ key = "BannerCarrier", text = T.BannerCarrier, sub = T.BannerCarrierSub, color = Style.Color.Exit })
		end
		if snap.lastCall and not p.lastCall then
			banner.push({ key = "BannerLastCall", text = T.BannerLastCall, sub = T.BannerLastCallSub, color = Style.Color.Bad })
		end
		if lastChance and not p.lastChance then
			banner.push({ key = "BannerLastChance", text = T.BannerLastChance, sub = T.BannerLastChanceSub, color = Style.Color.Bad })
		end
		if snap.exitOpen then
			hintPendingSince = nil
		end
		flushStepHint(snap)
	end

	----------------------------------------------------------------------
	-- Tick
	----------------------------------------------------------------------
	local function refresh()
		local snap = StateAdapter.snapshot()

		intro.update(snap)
		camera.update(snap)
		local cinematic = camera.isCinematicPlaying()
		local introPlaying = intro.isPlaying()
		if (cinematic or introPlaying) ~= cinematicHidden then
			cinematicHidden = cinematic or introPlaying
			applyVisibility()
		end
		if not introPlaying and #heldBanners > 0 then
			local held = heldBanners
			heldBanners = {}
			for _, payload in held do
				showRemoteBanner(payload)
			end
		end

		stageTimer.update(snap)
		extraction.update(snap)
		lobby.update(snap)
		objectives.update(snap)
		health.update(snap)
		status.update(snap)
		result.update(snap, cinematic)
		cosmetics.update(snap)
		if not introPlaying then
			deriveBanners(snap) -- deferred during the intro: Briefing + hint show right after it
		end

		markers.setScale(root.getScale())
		markers.update(snap)
	end

	local accumulator = Style.Tuning.UiTick -- run on the first frame
	local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < Style.Tuning.UiTick then
			return
		end
		accumulator = 0
		-- one bad frame (e.g. a half-built map) must not kill the HUD loop
		-- (table.pack form: avoids a false positive in luau-lsp's pcall typing)
		local outcome = table.pack(xpcall(refresh, debug.traceback))
		if not outcome[1] then
			warn("[HUD] refresh failed:", outcome[2])
		end
	end)

	applyVisibility()

	return {
		destroy = function()
			heartbeat:Disconnect()
			toggleConn:Disconnect()
			stopRemote()
			camera.destroy()
			intro.destroy()
			cosmetics.destroy()
			markers.destroy()
			toggle.destroy()
			root.destroy()
		end,
	}
end

return HudController
