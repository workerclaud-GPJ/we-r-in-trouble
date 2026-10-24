--!strict
--[[
	Cleanup — collects connections / instances / threads / functions and
	releases them all at once (per round, per stage, per pulse).
]]

export type Item = RBXScriptConnection | Instance | thread | () -> ()

export type Cleanup = {
	add: (self: Cleanup, item: Item) -> (),
	clean: (self: Cleanup) -> (),
	alive: (self: Cleanup) -> boolean,
}

local Cleanup = {}

local function release(item: Item)
	if typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif typeof(item) == "Instance" then
		item:Destroy()
	elseif typeof(item) == "thread" then
		if coroutine.status(item) ~= "dead" and item ~= coroutine.running() then
			pcall(task.cancel :: any, item)
		end
	elseif typeof(item) == "function" then
		local ok, err = pcall(item :: any)
		if not ok then
			warn("[Cleanup] cleanup function failed:", err)
		end
	end
end

function Cleanup.new(): Cleanup
	local items: { Item } = {}
	local isAlive = true
	local self = {} :: any

	function self.add(_s: Cleanup, item: Item)
		if isAlive then
			table.insert(items, item)
		else
			release(item)
		end
	end

	function self.clean(_s: Cleanup)
		isAlive = false
		local list = items
		items = {}
		for i = #list, 1, -1 do
			release(list[i])
		end
	end

	function self.alive(_s: Cleanup): boolean
		return isAlive
	end

	return self :: Cleanup
end

return Cleanup
