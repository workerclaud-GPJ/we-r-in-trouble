--!strict
--[[
	LobbyRoomService — waiting rooms in the lobby (tools/BuildLobby.luau: hamster houses).
	Walk into a house (Model tag LobbyRoom, Zone part) = you are in that room. The first hamster
	starts its countdown (ROOM_WAIT s); a full room (Capacity) jumps to ROOM_FULL_WAIT s. When a
	countdown ends, RoundService.runLobby takes that room's hamsters into the match (one match per
	server at a time: other rooms keep counting and show "Next game" while it runs).
	Each room model publishes Count / Capacity / EndsAt / Status and its Sign SurfaceGui text.
	Used only when Features.NewMission is on and Workspace.Lobby has LobbyRoom models.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local PlayerStateService = require(script.Parent.PlayerStateService)

local Attr = Contract.Attr

local TAG = "LobbyRoom"
local ROOM_WAIT = 30
local ROOM_FULL_WAIT = 5

local LobbyRoomService = {}

type RoomState = { endsAt: number?, joined: { [Player]: number } }
local state: { [Model]: RoomState } = {}
local busy = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

function LobbyRoomService.rooms(): { Model }
	local out: { Model } = {}
	local lobby = Workspace:FindFirstChild(Contract.Folder.Lobby)
	for _, inst in CollectionService:GetTagged(TAG) do
		if inst:IsA("Model") and lobby and inst:IsDescendantOf(lobby) and inst:FindFirstChild("Zone") then
			table.insert(out, inst)
		end
	end
	table.sort(out, function(a: Model, b: Model): boolean
		return (tonumber(a:GetAttribute("RoomId")) or 0) < (tonumber(b:GetAttribute("RoomId")) or 0)
	end)
	return out
end

function LobbyRoomService.enabled(): boolean
	return #LobbyRoomService.rooms() > 0
end

local function inside(pos: Vector3, p: BasePart): boolean
	local lp = p.CFrame:PointToObjectSpace(pos)
	local h = p.Size / 2
	return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y + 3 and math.abs(lp.Z) <= h.Z
end

local function setSign(room: Model, count: string, status: string)
	local sign = room:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("SignGui")
	if not gui then
		return
	end
	local c = gui:FindFirstChild("Count")
	local s = gui:FindFirstChild("Status")
	if c and c:IsA("TextLabel") and c.Text ~= count then
		c.Text = count
	end
	if s and s:IsA("TextLabel") and s.Text ~= status then
		s.Text = status
	end
end

-- members in join order (first come first served when over capacity)
local function members(room: Model, st: RoomState): { Player }
	local list: { Player } = {}
	for p in st.joined do
		table.insert(list, p)
	end
	table.sort(list, function(a: Player, b: Player): boolean
		return st.joined[a] < st.joined[b]
	end)
	local cap = tonumber(room:GetAttribute("Capacity")) or 4
	while #list > cap do
		table.remove(list)
	end
	return list
end

-- One tick (RoundService lobby loop and the busy loop): who is where, timers, signs.
function LobbyRoomService.update(eligible: (Player) -> boolean)
	local t = now()
	for _, room in LobbyRoomService.rooms() do
		local st = state[room]
		if not st then
			st = { endsAt = nil, joined = {} }
			state[room] = st
		end
		local zone = room:FindFirstChild("Zone") :: BasePart
		for _, p in Players:GetPlayers() do
			local hrp = PlayerStateService.getHRP(p)
			local isIn = hrp ~= nil and eligible(p) and inside(hrp.Position, zone)
			if isIn and not st.joined[p] then
				st.joined[p] = os.clock()
			elseif not isIn and st.joined[p] then
				st.joined[p] = nil
			end
		end
		for p in st.joined do
			if p.Parent ~= Players then
				st.joined[p] = nil
			end
		end
		local list = members(room, st)
		local cap = tonumber(room:GetAttribute("Capacity")) or 4
		if #list == 0 then
			st.endsAt = nil
		elseif not st.endsAt then
			st.endsAt = t + ROOM_WAIT
		end
		if st.endsAt and #list >= cap then
			st.endsAt = math.min(st.endsAt :: number, t + ROOM_FULL_WAIT)
		end
		local status: string
		if #list == 0 then
			status = "Walk in!"
		elseif busy then
			status = "Next game soon…"
		else
			local left = math.max(0, math.ceil((st.endsAt :: number) - t))
			status = if #list >= cap then `FULL! Starting in {left}` else `Starting in {left}s`
		end
		room:SetAttribute("Count", #list)
		room:SetAttribute("Capacity", cap)
		room:SetAttribute("EndsAt", if busy then nil else st.endsAt)
		room:SetAttribute("Status", status)
		setSign(room, `{#list}/{cap} 🐹`, status)
	end
end

-- Soonest counting room: (endsAt, members) or nil.
function LobbyRoomService.soonest(): (number?, { Player })
	local bestT: number? = nil
	local bestList: { Player } = {}
	for _, room in LobbyRoomService.rooms() do
		local st = state[room]
		if st and st.endsAt then
			local list = members(room, st)
			if #list > 0 and (bestT == nil or (st.endsAt :: number) < (bestT :: number)) then
				bestT, bestList = st.endsAt, list
			end
		end
	end
	return bestT, bestList
end

-- A room whose countdown ended: its members (room resets). Empty when none is ready.
function LobbyRoomService.takeReady(): { Player }
	local t = now()
	for _, room in LobbyRoomService.rooms() do
		local st = state[room]
		if st and st.endsAt and t >= (st.endsAt :: number) then
			local list = members(room, st)
			st.endsAt = nil
			table.clear(st.joined)
			if #list > 0 then
				print(`[Lobby] room {room:GetAttribute("RoomId")} starts with {#list} hamster(s)`)
				return list
			end
		end
	end
	return {}
end

-- While a match runs: signs keep counting players but show "Next game soon".
function LobbyRoomService.setBusy(on: boolean)
	busy = on
	if not on then
		-- give rooms that waited through the match a fresh short countdown
		for _, st in state do
			if st.endsAt then
				st.endsAt = math.max(st.endsAt :: number, now() + 10)
			end
		end
	end
end

function LobbyRoomService.start()
	-- signs stay live during matches (RoundService only ticks rooms between matches)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if busy then
				pcall(LobbyRoomService.update, function(p: Player): boolean
					return PlayerStateService.getState(p) == Contract.State.Lobby
				end)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		for _, st in state do
			st.joined[p] = nil
		end
	end)
	local _ = Attr
end

return LobbyRoomService
