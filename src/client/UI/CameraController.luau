--!strict
--[[
	CameraController — client camera moments owned by UI (GDD 8.6.1, 5.4).

	1) Win cinematic ("Rescue Moment"): when the match is won, tween the camera to
	   the map Part `WinCameraPoint` over WIN_CINEMATIC_TIME (3 s) and hold there
	   through Result. Camera goes back to normal when the player is back in the
	   lobby (phase Lobby/Intermission) or gets a new character.
	   Trigger: Phase "Ending" (win only, ARCHITECTURE §3), or Result phase with
	   ResultWin = true if the shot has not played yet (e.g. joined late).
	2) Spectate: while the local player is Eliminated (no character) the camera
	   follows the first teammate still in play, ordered by UserId (GDD 5.4).

	isCinematicPlaying() is true during the 3 s tween; the HUD hides meanwhile.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local StateAdapter = require(script.Parent.StateAdapter)

type Snapshot = StateAdapter.Snapshot

export type CameraController = {
	update: (snap: Snapshot) -> (),
	isCinematicPlaying: () -> boolean,
	destroy: () -> (),
}

local CameraController = {}
local localPlayer = Players.LocalPlayer

local function ownHumanoid(): Humanoid?
	local char = localPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function CameraController.new(): CameraController
	local scripted = false -- camera currently held by the cinematic
	local playedThisRound = false
	local cinematicUntil = 0
	local tween: Tween? = nil
	local spectating: Player? = nil
	local connections: { RBXScriptConnection } = {}

	local function restoreCamera()
		local camera = workspace.CurrentCamera
		if tween then
			tween:Cancel()
			tween = nil
		end
		if camera and scripted then
			camera.CameraType = Enum.CameraType.Custom
			local hum = ownHumanoid()
			if hum then
				camera.CameraSubject = hum
			end
		end
		scripted = false
		cinematicUntil = 0
	end

	local function playWinCinematic()
		playedThisRound = true
		local camera = workspace.CurrentCamera
		local point = StateAdapter.getWinCameraPoint()
		if not (camera and point) then
			return -- no WinCameraPoint in the map: skip the shot, Result still shows
		end
		scripted = true
		camera.CameraType = Enum.CameraType.Scriptable
		cinematicUntil = os.clock() + StateAdapter.Tuning.winCinematicTime
		tween = TweenService:Create(
			camera,
			TweenInfo.new(StateAdapter.Tuning.winCinematicTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = point.CFrame }
		)
		;(tween :: Tween):Play()
	end

	local function updateSpectate(snap: Snapshot)
		local camera = workspace.CurrentCamera
		if not camera or scripted then
			return
		end
		local eliminated = snap.phase == "Match"
			and snap.state == StateAdapter.VALUES.StateEliminated
			and localPlayer.Character == nil
		if not eliminated then
			if spectating then
				spectating = nil
				local hum = ownHumanoid()
				if hum then
					camera.CameraSubject = hum
				end
			end
			return
		end
		local candidates = StateAdapter.spectateCandidates()
		local target = candidates[1]
		if target ~= spectating then
			spectating = target
		end
		local char = target and target.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and camera.CameraSubject ~= hum then
			camera.CameraSubject = hum
		end
	end

	local function update(snap: Snapshot)
		if snap.phase == "Lobby" or snap.phase == "Intermission" then
			playedThisRound = false
			if scripted then
				restoreCamera()
			end
			updateSpectate(snap)
			return
		end

		local inMatch = snap.state ~= StateAdapter.VALUES.StateLobby
		if inMatch and not playedThisRound then
			if snap.phase == "Ending" or (snap.phase == "Result" and snap.resultWin == true) then
				playWinCinematic()
			end
		end
		updateSpectate(snap)
	end

	table.insert(
		connections,
		localPlayer.CharacterAdded:Connect(function()
			-- new character = back in the lobby or respawned: release the camera
			if scripted then
				task.defer(restoreCamera)
			end
		end)
	)

	return {
		update = update,
		isCinematicPlaying = function(): boolean
			return scripted and os.clock() < cinematicUntil
		end,
		destroy = function()
			for _, c in connections do
				c:Disconnect()
			end
			restoreCamera()
		end,
	}
end

return CameraController
