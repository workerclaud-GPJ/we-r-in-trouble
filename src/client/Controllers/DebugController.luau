--!strict
-- DebugController — forwards "/dbg ..." chat commands to the server (DebugCommand remote).
-- The TextChatCommand exists only when the server enabled debug (Studio / dev allowlist);
-- the server re-checks permission on every call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DebugController = {}

function DebugController.start()
	task.spawn(function()
		local commands = TextChatService:WaitForChild("TextChatCommands", 15)
		local command = commands and commands:WaitForChild("DebugCommand", 15)
		if command and command:IsA("TextChatCommand") then
			local remote = Remotes.get("DebugCommand")
			command.Triggered:Connect(function(_source: TextSource, text: string)
				remote:FireServer(text)
			end)
		end
	end)
end

return DebugController
