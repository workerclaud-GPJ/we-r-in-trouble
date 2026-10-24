--!strict
--[[
	MovementController — the ONLY writer of Humanoid.WalkSpeed / JumpHeight (GDD 5.5,
	Deadline: no sprint). Also disables the Dead state locally (GDD 5.2: the client owns
	its humanoid state).
	  Normal -> max(MIN_MOVE_SPEED, WALK_SPEED * SpeedMult) · Downed -> DOWNED_CRAWL_SPEED, no jump · Pinned -> 0
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)

local Attr = Contract.Attr
local P = Config.Player

local MovementController = {}

local player = Players.LocalPlayer

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function apply()
	local h = humanoid()
	if not h then
		return
	end
	local mode = player:GetAttribute(Attr.MoveMode)
	local multAttr = player:GetAttribute(Attr.SpeedMult)
	local mult = if typeof(multAttr) == "number" then multAttr else 1
	h.UseJumpPower = false
	if mode == Contract.MoveMode.Pinned then
		h.WalkSpeed = 0
		h.JumpHeight = 0
	elseif mode == Contract.MoveMode.Downed then
		h.WalkSpeed = P.DOWNED_CRAWL_SPEED
		h.JumpHeight = 0
	else
		h.WalkSpeed = math.max(P.MIN_MOVE_SPEED, P.WALK_SPEED * mult)
		h.JumpHeight = P.JUMP_HEIGHT
	end
end

local function onCharacter(char: Model)
	local h = char:WaitForChild("Humanoid", 10)
	if h and h:IsA("Humanoid") then
		h.BreakJointsOnDeath = false
		h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		apply()
	end
end

function MovementController.start()
	player:GetAttributeChangedSignal(Attr.MoveMode):Connect(apply)
	player:GetAttributeChangedSignal(Attr.SpeedMult):Connect(apply)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return MovementController
