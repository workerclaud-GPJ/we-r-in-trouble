--!strict
--[[
	MissionService — mission runner: steps in order, objectives in a step in parallel,
	next step opens in the same tick the previous completes (GDD §3.1), Last chance
	warning (§2.2), ExitUnlocked when the final step completes (§5.8 step 1).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Signal = require(Shared.Util.Signal)

local MapService = require(script.Parent.MapService)
local RoundState = require(script.Parent.RoundState)
local Hud = require(script.Parent.Hud)
local Common = require(script.Parent.Objectives.Common)

local Attr = Contract.Attr

local FACTORIES: { [string]: (ctx: Common.Context) -> Common.Objective } = {
	Repair = require(script.Parent.Objectives.Repair).create,
	Deliver = require(script.Parent.Objectives.Deliver).create,
	MultiHold = require(script.Parent.Objectives.MultiHold).create,
}

type Runtime = {
	def: Types.ObjectiveDef,
	step: number,
	anchors: { Model },
	config: Configuration,
	impl: Common.Objective?,
	done: boolean,
	credited: { [Player]: boolean },
}

local MissionService = {}

MissionService.ExitUnlocked = Signal.new() :: Signal.Signal<()>

local mission: Types.MissionDef? = nil
local runtimes: { Runtime } = {}
local currentStep = 0
local stepOpenedAt = 0
local matchStartedAt = 0
local exitUnlocked = false
local lastChanceShown = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function setOn(rt: Runtime, name: string, value: any)
	if rt.config:GetAttribute(name) ~= value then
		rt.config:SetAttribute(name, value)
	end
	for _, anchor in rt.anchors do
		if anchor:GetAttribute(name) ~= value then
			anchor:SetAttribute(name, value)
		end
	end
end

local function isActive(rt: Runtime): boolean
	return mission ~= nil and not rt.done and rt.step == currentStep
end

local function setPromptsEnabled(rt: Runtime, enabled: boolean)
	for _, anchor in rt.anchors do
		local part = Common.promptPart(anchor)
		local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt.Enabled = enabled
		end
	end
end

local advance: () -> () -- forward declaration

local function openStep(index: number)
	local m = mission
	if not m then
		return
	end
	currentStep = index
	stepOpenedAt = now()
	RoundState.set(Attr.StepIndex, index)
	RoundState.set(Attr.StepOpenedAt, stepOpenedAt)
	local stepDef = m.steps[index]
	RoundState.set(Attr.StepName, if stepDef then stepDef.displayName else nil)
	if not stepDef then
		return
	end
	for _, rt in runtimes do
		if rt.step == index then
			setOn(rt, Attr.Active, true)
			setPromptsEnabled(rt, true)
			if rt.impl then
				rt.impl.open()
			end
		end
	end
	advance() -- a step whose objectives are all missing/done completes immediately
end

local function stepComplete(index: number): boolean
	for _, rt in runtimes do
		if rt.step == index and not rt.done and not rt.def.optional then
			return false
		end
	end
	return true
end

advance = function()
	local m = mission
	if not m or exitUnlocked or not stepComplete(currentStep) then
		return
	end
	if currentStep >= #m.steps then
		exitUnlocked = true
		currentStep = #m.steps + 1
		RoundState.set(Attr.StepIndex, currentStep)
		RoundState.set(Attr.StepName, nil)
		RoundState.set(Attr.LastChance, false)
		MissionService.ExitUnlocked:Fire()
		return
	end
	Hud.banner("BannerStepComplete", "Step complete!", nil, "Good", 2)
	openStep(currentStep + 1)
end

local function markDone(rt: Runtime)
	if rt.done then
		return
	end
	rt.done = true
	setOn(rt, Attr.Done, true)
	setOn(rt, Attr.Active, false)
	setOn(rt, Attr.Progress, 1)
	setPromptsEnabled(rt, false)
	advance()
end

local function buildRuntime(def: Types.ObjectiveDef, stepIndex: number, order: number): Runtime
	local anchors: { Model } = {}
	for _, inst in MapService.tagged(Contract.Tag.ObjectiveAnchor) do
		if inst:IsA("Model") and inst:GetAttribute(Attr.ObjectiveId) == def.id then
			table.insert(anchors, inst)
		end
	end
	table.sort(anchors, function(a: Model, b: Model): boolean
		return tostring(a:GetAttribute(Attr.Part) or a.Name) < tostring(b:GetAttribute(Attr.Part) or b.Name)
	end)
	if #anchors == 0 then
		warn(`[Mission] no ObjectiveAnchor with ObjectiveId = {def.id} in map`)
	end

	local config = Instance.new("Configuration")
	config.Name = def.id
	local rt: Runtime = { def = def, step = stepIndex, anchors = anchors, config = config, impl = nil, done = false, credited = {} }
	setOn(rt, Attr.DisplayName, def.displayName)
	setOn(rt, Attr.Kind, def.kind)
	setOn(rt, Attr.Step, stepIndex)
	setOn(rt, Attr.Order, order)
	setOn(rt, Attr.Optional, def.optional == true)
	setOn(rt, Attr.Active, false)
	setOn(rt, Attr.Done, false)
	setOn(rt, Attr.Progress, 0)
	config.Parent = RoundState.objectivesFolder()

	local factory = FACTORIES[def.kind]
	if factory and #anchors > 0 then
		rt.impl = factory({
			def = def,
			anchors = anchors,
			config = config,
			set = function(name: string, value: any)
				setOn(rt, name, value)
			end,
			setAnchor = function(anchor: Model, name: string, value: any)
				if anchor:GetAttribute(name) ~= value then
					anchor:SetAttribute(name, value)
				end
			end,
			isActive = function(): boolean
				return isActive(rt)
			end,
			stepOpenedAt = function(): number
				return stepOpenedAt
			end,
			complete = function()
				markDone(rt)
			end,
			credit = function(player: Player)
				if not rt.credited[player] then
					rt.credited[player] = true
					local v = player:GetAttribute(Attr.Credits)
					player:SetAttribute(Attr.Credits, (if typeof(v) == "number" then v else 0) + 1)
				end
			end,
		})
	elseif not factory then
		warn(`[Mission] objective kind {def.kind} not supported in Deadline build`)
	end
	if not rt.impl then
		rt.done = true -- never softlock on a missing anchor/kind
		setOn(rt, Attr.Done, true)
	end
	return rt
end

----------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------

function MissionService.start(def: Types.MissionDef, startedAt: number)
	MissionService.stop()
	mission = def
	matchStartedAt = startedAt
	exitUnlocked = false
	lastChanceShown = false
	currentStep = 0
	RoundState.set(Attr.MissionName, def.displayName)
	RoundState.set(Attr.StepCount, #def.steps)
	RoundState.set(Attr.LastChance, false)
	for stepIndex, step in def.steps do
		for order, objDef in step.objectives do
			table.insert(runtimes, buildRuntime(objDef, stepIndex, order))
		end
	end
	openStep(1)
end

function MissionService.update(dt: number)
	if not mission then
		return
	end
	for _, rt in runtimes do
		if rt.impl and isActive(rt) then
			rt.impl.update(dt)
		end
	end
	if not exitUnlocked and not lastChanceShown and now() - matchStartedAt >= Config.Round.LAST_CHANCE_WARNING_AT then
		lastChanceShown = true
		RoundState.set(Attr.LastChance, true)
		Hud.banner("BannerLastChance", "Last chance!", "Finish the last step fast!", "Bad", 3)
	end
end

function MissionService.isExitUnlocked(): boolean
	return exitUnlocked
end

-- Debug: complete every objective in the current step.
function MissionService.completeCurrentStep()
	if not mission or exitUnlocked then
		return
	end
	local index = currentStep
	for _, rt in runtimes do
		if rt.step == index and not rt.done then
			if rt.impl then
				rt.impl.forceComplete()
			else
				markDone(rt)
			end
		end
	end
	advance()
end

-- Debug: complete all remaining steps (unlocks the exit).
function MissionService.completeAllSteps()
	local m = mission
	if not m then
		return
	end
	local guard = 0
	while not exitUnlocked and guard <= #m.steps do
		guard += 1
		MissionService.completeCurrentStep()
	end
end

-- Debug: toggle a dummy holder on anchor letter (A-D) of the active MultiHold.
function MissionService.toggleDummyHolder(letter: string): boolean
	for _, rt in runtimes do
		local impl = rt.impl
		if impl and impl.toggleDummy and isActive(rt) then
			return impl.toggleDummy(letter)
		end
	end
	return false
end

function MissionService.stop()
	for _, rt in runtimes do
		setPromptsEnabled(rt, false)
		if rt.impl then
			rt.impl.destroy()
		end
		rt.config:Destroy()
	end
	table.clear(runtimes)
	mission = nil
	currentStep = 0
end

return MissionService
