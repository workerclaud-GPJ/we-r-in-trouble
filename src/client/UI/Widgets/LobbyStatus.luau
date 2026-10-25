--!strict
--[[
	LobbyStatus — lobby / intermission card (GDD 2.1). Top-center column.

	  Lobby phase         "Waiting for players (1/2)"  + "Need 2 hamsters to start. Invite a friend!"
	                      (solo start is OFF: with 1 player this stays forever on live)
	  Intermission        "Match starts in 0:25"       + "2/4 hamsters ready"
	  Match/Result, I'm in lobby "Match in progress"   + "You'll join the next round (3:12)"
	  Always on top: game title, how to play (TH + EN), "Needs 2–4 players".
	  + AFK line when the local player is flagged Inactive in the lobby.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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

-- Lobby rooms (LobbyRoomService): the room the local hamster stands in, and the soonest room.
local function roomInfo(): (Model?, Model?)
	local lobby = Workspace:FindFirstChild("Lobby")
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local mine: Model? = nil
	local soonest: Model? = nil
	for _, inst in CollectionService:GetTagged("LobbyRoom") do
		if inst:IsA("Model") and lobby and inst:IsDescendantOf(lobby) then
			local zone = inst:FindFirstChild("Zone")
			if hrp and hrp:IsA("BasePart") and zone and zone:IsA("BasePart") then
				local lp = zone.CFrame:PointToObjectSpace(hrp.Position)
				local h = zone.Size / 2
				if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y + 3 and math.abs(lp.Z) <= h.Z then
					mine = inst
				end
			end
			local e = inst:GetAttribute("EndsAt")
			if typeof(e) == "number" then
				local se = soonest and soonest:GetAttribute("EndsAt")
				if not soonest or (typeof(se) == "number" and e < se) then
					soonest = inst
				end
			end
		end
	end
	return mine, soonest
end

function LobbyStatus.new(parent: Instance): LobbyStatus
	local root = UIUtil.panel({
		Name = "Lobby",
		Size = UDim2.fromOffset(Style.Size.BannerWidth - 40, 0),
		Visible = false,
		Parent = parent,
	})
	UIUtil.list(4, false, Enum.HorizontalAlignment.Center).Parent = root

	-- Game intro (always shown while the card is visible)
	UIUtil.label(T.GameTitle, Style.Text.Title, {
		Name = "GameTitle",
		LayoutOrder = -4,
		Font = Style.Font.Display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.Accent,
		Parent = root,
	})
	UIUtil.label(T.HowToPlayTh, Style.Text.Body, {
		Name = "HowToPlayTh",
		LayoutOrder = -3,
		Font = Enum.Font.Gotham, -- FredokaOne has no Thai glyphs
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
	UIUtil.label(T.HowToPlay, Style.Text.Body, {
		Name = "HowToPlay",
		LayoutOrder = -2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
	UIUtil.label(T.PlayerRange, Style.Text.Small, {
		Name = "PlayerRange",
		LayoutOrder = -1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Style.Color.TextDim,
		Parent = root,
	})
	UIUtil.make("Frame", {
		Name = "Divider",
		LayoutOrder = 0,
		Size = UDim2.new(0.8, 0, 0, 2),
		BackgroundColor3 = Style.Color.PanelLight,
		BorderSizePixel = 0,
		Parent = root,
	})

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
		-- Result counts as "match running" for players waiting in the lobby (review m8)
		local matchRunning = snap.phase == "Match" or snap.phase == "Ending" or snap.phase == "Result"
		local show = snap.phase == "Lobby" or snap.phase == "Intermission" or (matchRunning and inLobbyState)
		root.Visible = show
		if not show then
			return
		end
		afk.Visible = snap.inactive

		local hasRooms = #CollectionService:GetTagged("LobbyRoom") > 0
		-- rooms lobby: compact card (title + room line) so the houses stay visible
		for _, name in { "GameTitle", "HowToPlayTh", "HowToPlay", "PlayerRange", "Divider" } do
			local c = root:FindFirstChild(name)
			if c and c:IsA("GuiObject") then
				c.Visible = not hasRooms
			end
		end
		if hasRooms and (snap.phase == "Lobby" or snap.phase == "Intermission") then
			local mine, soonest = roomInfo()
			local room = mine or soonest
			local e = room and room:GetAttribute("EndsAt")
			local left = if typeof(e) == "number" then UIUtil.clock(math.max(0, e - snap.now)) else nil
			local count = room and room:GetAttribute("Count") or 0
			local cap = room and room:GetAttribute("Capacity") or 4
			if mine then
				title.Text = if left then `Room {mine:GetAttribute("RoomId")} starts in {left}` else `Room {mine:GetAttribute("RoomId")}`
				sub.Text = `{count}/{cap} hamsters · waiting for friends (full = start now)`
			elseif soonest and left then
				title.Text = `Room {soonest:GetAttribute("RoomId")} starts in {left}`
				sub.Text = `{count}/{cap} inside · walk into a hamster house to join!`
			else
				title.Text = "Walk into a hamster house to play!"
				sub.Text = "The game starts 30 s after the first hamster walks in"
			end
		elseif snap.phase == "Lobby" then
			title.Text = UIUtil.format(T.WaitingForPlayers, { n = snap.playersReady, need = snap.playersNeeded })
			sub.Text = UIUtil.format(T.NeedPlayers, { need = snap.playersNeeded })
		elseif snap.phase == "Intermission" then
			local remaining = if snap.phaseEndsAt then snap.phaseEndsAt - snap.now else nil
			title.Text = UIUtil.format(T.MatchStartsIn, { t = if remaining then UIUtil.clock(remaining) else "..." })
			sub.Text = UIUtil.format(T.ReadyCount, { n = snap.playersReady, max = snap.maxPlayers })
		else
			local endsAt = if snap.phase == "Result" then snap.phaseEndsAt else snap.matchEndsAt
			local remaining = if endsAt then endsAt - snap.now else nil
			title.Text = T.MatchInProgress
			sub.Text = UIUtil.format(T.JoinNextRound, { t = if remaining then UIUtil.clock(remaining) else "..." })
		end
	end

	return { root = root, update = update }
end

return LobbyStatus
