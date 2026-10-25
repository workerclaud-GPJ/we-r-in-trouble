--!strict
--[[
	CableHook — done when the team hooks a cable route that reaches the counter
	(CableThrowService, Contract.Attr.ReachesCounter). No prompt: the anchors are the hooks
	themselves (markers show where to cast). Already hooked when the step opens = done at once.
]]

local Common = require(script.Parent.Common)
local CableThrowService = require(script.Parent.Parent.CableThrowService)

local CableHook = {}

function CableHook.create(ctx: Common.Context): Common.Objective
	ctx.set("Wants", "Rope") -- cables get a marker while this step is open (WantedItemController)
	local conn = CableThrowService.Attached:Connect(function(_id: string, reaches: boolean)
		if reaches and ctx.isActive() then
			ctx.complete()
		end
	end)
	local self: Common.Objective = {
		open = function()
			if CableThrowService.counterReached() then
				ctx.complete()
			end
		end,
		update = function(_dt: number) end,
		forceComplete = function()
			ctx.complete()
		end,
		destroy = function()
			conn:Disconnect()
		end,
	}
	return self
end

return CableHook
