--!strict
--[[
	LobbyStatus — lobby / intermission card (GDD 2.1). Top-center column.

	  Lobby phase         "Waiting for players (1/2)"  + "Need 2 hamsters to start. Invite a friend!"
	                      (solo start is OFF: with 1 player this stays forever on live)
	  Intermission        "Match starts in 0:25"       + "2/4 hamsters ready"
	  Match, I'm in lobby "Match in progress"          + "You'll join the next round (3:12)"
	  + AFK line when the local player is flagged Inactive in the lobby.
]]

local UI = script.Parent.Parent
local StateAdapter = require(UI.StateAdapter)
local Strings = require(UI.Strings)
local Style = require(UI.Style)
local UIUtil = require(UI.UIUtil)

type Snapshot = StateAdapter.Snapshot

export type LobbyStatus = {
	root: Frame,
	update: (snap: Snapshot) -> (),
}

local T = Strings.Text
local LobbyStatus = {}

function LobbyStatus.new(parent: Instance): LobbyStatus
	local root = UIUtil.panel({
		Name = "Lobby",
		Size = UDim2.fromOffset(Style.Size.BannerWidth - 40, 0),
		Visible = false,
		Parent = parent,
	})
	UIUtil.list(4, false, Enum.HorizontalAlignment.Center).Parent = root

	local title = UIUtil.label("", Style.Text.Large, {
		Name = "Title",
		LayoutOrder = 1,
		Font = Style.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.Accent,
		Parent = root,
	})
	local sub = UIUtil.label("", Style.Text.Body, {
		Name = "Sub",
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
	local afk = UIUtil.label(T.Afk, Style.Text.Body, {
		Name = "Afk",
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.Warn,
		Visible = false,
		Parent = root,
	})

	local function update(snap: Snapshot)
		local inLobbyState = snap.state == StateAdapter.VALUES.StateLobby
		local matchRunning = snap.phase == "Match" or snap.phase == "Ending"
		local show = snap.phase == "Lobby" or snap.phase == "Intermission" or (matchRunning and inLobbyState)
		root.Visible = show
		if not show then
			return
		end
		afk.Visible = snap.inactive

		if snap.phase == "Lobby" then
			title.Text = UIUtil.format(T.WaitingForPlayers, { n = snap.playersReady, need = snap.playersNeeded })
			sub.Text = UIUtil.format(T.NeedPlayers, { need = snap.playersNeeded })
		elseif snap.phase == "Intermission" then
			local remaining = if snap.phaseEndsAt then snap.phaseEndsAt - snap.now else nil
			title.Text = UIUtil.format(T.MatchStartsIn, { t = if remaining then UIUtil.clock(remaining) else "..." })
			sub.Text = UIUtil.format(T.ReadyCount, { n = snap.playersReady, max = snap.maxPlayers })
		else
			local remaining = if snap.matchEndsAt then snap.matchEndsAt - snap.now else nil
			title.Text = T.MatchInProgress
			sub.Text = UIUtil.format(T.JoinNextRound, { t = if remaining then UIUtil.clock(remaining) else "..." })
		end
	end

	return { root = root, update = update }
end

return LobbyStatus
