--!strict
-- DebugController — forwards "/dbg ..." chat commands to the server (DebugCommand remote).
-- The server always registers the TextChatCommand (so "/dbg" never leaks into public chat)
-- and marks it DebugEnabled only in Studio / for a dev allowlist; the server re-checks
-- permission on every call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DebugController = {}

function DebugController.start()
	task.spawn(function()
		local commands = TextChatService:WaitForChild("TextChatCommands", 15)
		local command = commands and commands:WaitForChild("DebugCommand", 15)
		-- DebugEnabled = false on live: the command only swallows the chat line, nothing is sent
		if command and command:IsA("TextChatCommand") and command:GetAttribute(Config.Debug.CHAT_ENABLED_ATTR) == true then
			local remote = Remotes.get("DebugCommand")
			command.Triggered:Connect(function(_source: TextSource, text: string)
				remote:FireServer(text)
			end)
		end
	end)
end

return DebugController
