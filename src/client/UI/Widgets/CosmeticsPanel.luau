--!strict
--[[
	CosmeticsPanel — lobby fur color + hat picker (no saving).

	Shown only in the Lobby (phase Lobby/Intermission and local State = Lobby).
	A "Style" button (left-middle, touch size) opens a small panel: 4 fur swatches and
	5 hat buttons. Clicking sends SetCosmetic(kind, id); the server validates and writes
	the player attributes FurColor / Hat, which drive the selected outline here.
	Lives on the HUD layer, so the H toggle hides it too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Contract = require(Shared:WaitForChild("Contract"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local StateAdapter = require(script.Parent.Parent.StateAdapter)
local Strings = require(script.Parent.Parent.Strings)
local Style = require(script.Parent.Parent.Style)
local UIUtil = require(script.Parent.Parent.UIUtil)

type Snapshot = StateAdapter.Snapshot

export type CosmeticsPanel = {
	root: Frame,
	update: (snap: Snapshot) -> (),
	destroy: () -> (),
}

local C = Config.Cosmetics
local T = Strings.Text
local BUTTON_W = 104 -- base px; height = Style.Size.Touch (>= 44 px after scale)

local CosmeticsPanel = {}

function CosmeticsPanel.new(parent: Instance): CosmeticsPanel
	local localPlayer = Players.LocalPlayer
	local remote: RemoteEvent? = nil
	task.spawn(function()
		remote = Remotes.get("SetCosmetic")
	end)
	local connections: { RBXScriptConnection } = {}

	local root: Frame = UIUtil.make("Frame", {
		Name = "CosmeticsPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Style.Size.Margin, 0.5, 0),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	}, { UIUtil.list(Style.Size.Gap) :: Instance })

	local function button(text: string, width: number, p: Instance): TextButton
		local b: TextButton = UIUtil.make("TextButton", {
			Size = UDim2.fromOffset(width, Style.Size.Touch),
			BackgroundColor3 = Style.Color.PanelLight,
			AutoButtonColor = true,
			Text = text,
			TextWrapped = true,
			TextSize = Style.Text.Small,
			Font = Style.Font.Body,
			TextColor3 = Style.Color.Text,
			TextStrokeColor3 = Style.Color.Outline,
			TextStrokeTransparency = 0.35,
			Parent = p,
		}, { UIUtil.corner(Style.Size.CornerSmall), UIUtil.stroke() } :: { Instance })
		return b
	end

	local toggle = button(T.StyleButton, BUTTON_W, root)
	toggle.LayoutOrder = 1
	toggle.BackgroundColor3 = Style.Color.Panel

	local panel = UIUtil.panel({ Name = "Panel", Size = UDim2.fromOffset(4 * BUTTON_W + 3 * Style.Size.Gap + 2 * Style.Size.Pad, 0), Visible = false, LayoutOrder = 2, Parent = root })
	UIUtil.list(Style.Size.Gap).Parent = panel
	UIUtil.label(T.StyleTitle, Style.Text.Large, { LayoutOrder = 1, TextColor3 = Style.Color.Accent, Parent = panel })

	local function row(order: number): Frame
		local f: Frame = UIUtil.make("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = panel,
		}, { UIUtil.list(Style.Size.Gap, true) :: Instance })
		local grid = f:FindFirstChildOfClass("UIListLayout")
		if grid then
			grid.Wraps = true
		end
		return f
	end

	local selected: { [string]: { [string]: TextButton } } = { [Contract.Attr.FurColor] = {}, [Contract.Attr.Hat] = {} }

	local function send(kind: string, id: string)
		local r = remote
		if r then
			r:FireServer(kind, id)
		end
	end

	UIUtil.label(T.StyleFur, Style.Text.Body, { LayoutOrder = 2, Parent = panel })
	local furRow = row(3)
	for i, id in C.FUR_ORDER do
		local b = button(Strings.cosmetic(id), BUTTON_W, furRow)
		b.LayoutOrder = i
		b.BackgroundColor3 = C.FUR[id].Fur
		selected[Contract.Attr.FurColor][id] = b
		table.insert(connections, b.Activated:Connect(function()
			send(Contract.Attr.FurColor, id)
		end))
	end

	UIUtil.label(T.StyleHat, Style.Text.Body, { LayoutOrder = 4, Parent = panel })
	local hatRow = row(5)
	for i, id in C.HAT_ORDER do
		local b = button(Strings.cosmetic(id), BUTTON_W, hatRow)
		b.LayoutOrder = i
		selected[Contract.Attr.Hat][id] = b
		table.insert(connections, b.Activated:Connect(function()
			send(Contract.Attr.Hat, id)
		end))
	end

	local function refreshSelection()
		for kind, buttons in selected do
			local current = localPlayer:GetAttribute(kind)
			for id, b in buttons do
				local stroke = b:FindFirstChildOfClass("UIStroke")
				if stroke then
					local on = current == id
					stroke.Color = if on then Style.Color.Accent else Style.Color.Outline
					stroke.Thickness = if on then Style.Size.Stroke + 2 else Style.Size.Stroke
				end
			end
		end
	end

	table.insert(connections, toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		toggle.Text = if panel.Visible then T.StyleClose else T.StyleButton
	end))
	table.insert(connections, localPlayer.AttributeChanged:Connect(function(name: string)
		if name == Contract.Attr.FurColor or name == Contract.Attr.Hat then
			refreshSelection()
		end
	end))
	refreshSelection()

	return {
		root = root,
		update = function(snap: Snapshot)
			local inLobby = (snap.phase == StateAdapter.VALUES.PhaseLobby or snap.phase == StateAdapter.VALUES.PhaseIntermission)
				and snap.state == StateAdapter.VALUES.StateLobby
			if root.Visible ~= inLobby then
				root.Visible = inLobby
				if not inLobby then
					panel.Visible = false
					toggle.Text = T.StyleButton
				end
			end
		end,
		destroy = function()
			for _, c in connections do
				c:Disconnect()
			end
			root:Destroy()
		end,
	}
end

return CosmeticsPanel
