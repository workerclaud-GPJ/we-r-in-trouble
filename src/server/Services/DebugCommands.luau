--!strict
--[[
	DebugCommands — Studio / dev-allowlist only (GDD §8.6, QA E8). Server checks
	permission on EVERY call; non-dev players on live get no effect and no error text.

	Channels:
	  chat:        /dbg <command> [args]   (TextChatCommand -> DebugCommand remote, plus server Triggered)
	  Command Bar: game.ServerStorage.DebugInvoke:Invoke("setHP 0 PlayerName")

	Commands (case-insensitive): skipStep | setStage <Calm|Warning|Active|Critical> | unlockExit |
	  setHP <n> [player] | spawnDummyHolder <A-D> | endMatch <win|lose> | startNow
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerStateService = require(script.Parent.PlayerStateService)
local DisasterService = require(script.Parent.DisasterService)
local MissionService = require(script.Parent.MissionService)
local RoundService = require(script.Parent.RoundService)

local D = Config.Debug

local DebugCommands = {}

local recent: { [Player]: { number } } = {}
local lastText: { [Player]: { text: string, at: number } } = {}

local function allowed(player: Player?): boolean
	if player == nil then
		return true -- server-side BindableFunction (Command Bar); clients cannot invoke it
	end
	if D.ENABLE_IN_STUDIO and RunService:IsStudio() then
		return true
	end
	return table.find(D.DEV_USER_IDS, player.UserId) ~= nil
end

local function rateOk(player: Player): boolean
	local t = os.clock()
	local list = recent[player] or {}
	recent[player] = list
	while list[1] and t - list[1] > 1 do
		table.remove(list, 1)
	end
	if #list >= D.MAX_PER_SECOND then
		return false
	end
	table.insert(list, t)
	return true
end

local function findPlayer(name: string?, caller: Player?): Player?
	if name and name ~= "" then
		local lower = string.lower(name)
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
				return p
			end
		end
		return nil
	end
	if caller then
		return caller
	end
	return PlayerStateService.teamMembers()[1]
end

local function stageId(arg: string?): string?
	if not arg then
		return nil
	end
	for _, id in Config.Stages.ORDER do
		if string.lower(id) == string.lower(arg) then
			return id
		end
	end
	return nil
end

-- Parses and runs one command line. Returns a short status string (for Command Bar).
function DebugCommands.run(text: string, caller: Player?): string
	if not allowed(caller) then
		return "denied"
	end
	local words: { string } = {}
	for w in string.gmatch(text, "%S+") do
		table.insert(words, w)
	end
	if words[1] and string.lower(words[1]) == D.CHAT_PREFIX then
		table.remove(words, 1)
	end
	local cmd = string.lower(words[1] or "")
	local a1, a2 = words[2], words[3]

	if cmd == "skipstep" then
		MissionService.completeCurrentStep()
	elseif cmd == "setstage" then
		local id = stageId(a1)
		if not id then
			return "usage: setStage <Calm|Warning|Active|Critical>"
		end
		DisasterService.setStage(id)
	elseif cmd == "unlockexit" then
		MissionService.completeAllSteps()
	elseif cmd == "sethp" then
		local n = tonumber(a1)
		local target = findPlayer(a2, caller)
		if not (n and target) then
			return "usage: setHP <n> [player]"
		end
		PlayerStateService.setHP(target, n)
	elseif cmd == "spawndummyholder" then
		if not a1 or not MissionService.toggleDummyHolder(a1) then
			return "no active MultiHold anchor " .. tostring(a1)
		end
	elseif cmd == "endmatch" then
		local mode = string.lower(a1 or "")
		if mode ~= "win" and mode ~= "lose" then
			return "usage: endMatch <win|lose>"
		end
		RoundService.forceEnd(mode == "win")
	elseif cmd == "startnow" then
		RoundService.forceStart()
	else
		return "unknown command"
	end
	print(`[Debug] {if caller then caller.Name else "server"}: {text}`)
	return "ok"
end

local function fromPlayer(player: Player, text: any)
	if typeof(text) ~= "string" or #text > D.MAX_LENGTH or not allowed(player) or not rateOk(player) then
		return
	end
	-- the same chat line can arrive via both the client remote and the server Triggered event
	local prev = lastText[player]
	local t = os.clock()
	if prev and prev.text == text and t - prev.at < 1 then
		return
	end
	lastText[player] = { text = text, at = t }
	DebugCommands.run(text, player)
end

function DebugCommands.start()
	Remotes.get("DebugCommand").OnServerEvent:Connect(fromPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		recent[player] = nil
		lastText[player] = nil
	end)

	local bindable = Instance.new("BindableFunction")
	bindable.Name = Contract.Folder.DebugInvoke
	bindable.OnInvoke = function(text: any): string
		if typeof(text) ~= "string" then
			return "usage: Invoke(\"command args\")"
		end
		return DebugCommands.run(text, nil)
	end
	bindable.Parent = ServerStorage

	-- Chat command exists only where debug can work (Studio, or a dev allowlist is configured)
	if (D.ENABLE_IN_STUDIO and RunService:IsStudio()) or #D.DEV_USER_IDS > 0 then
		local ok, err = pcall(function()
			local commands = TextChatService:FindFirstChild("TextChatCommands")
			if not commands then
				commands = Instance.new("Folder")
				commands.Name = "TextChatCommands"
				commands.Parent = TextChatService
			end
			local command = Instance.new("TextChatCommand")
			command.Name = "DebugCommand"
			command.PrimaryAlias = D.CHAT_PREFIX
			command.Triggered:Connect(function(source: TextSource, unfilteredText: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					fromPlayer(player, unfilteredText)
				end
			end)
			command.Parent = commands
		end)
		if not ok then
			warn("[Debug] chat command unavailable:", err)
		end
	end
end

return DebugCommands
